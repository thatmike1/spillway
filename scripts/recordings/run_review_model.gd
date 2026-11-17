extends RefCounted
## read-only analysis of validated recordings. no config or recording writes.
const READER := preload("res://scripts/recordings/reader.gd")

static func load_attempt(path: String) -> Dictionary:
	var run := READER.read(path, true)
	if not run.ok:
		return {"ok": false, "error": "Cannot review this %s recording: %s" % [run.status, str(run.errors)], "status": run.status}
	if not run.header.get("identity") is Dictionary:
		return {"ok": false, "error": "The recording has no motion identity."}
	var c: Dictionary = run.columns
	var marks: Array = []
	var series: Array = []
	var previous := -1
	var last_time := -1.0
	for i: int in c.tick.size():
		if c.flags[i] & 1 == 0:
			continue
		var t := float(c.elapsed[i])
		var velocity: Vector3 = c.v[i]
		if not is_finite(t) or t < last_time or not velocity.is_finite() or not (c.p[i] as Vector3).is_finite():
			return {"ok": false, "error": "The recorded course clock or pose is invalid; this attempt cannot be compared."}
		last_time = t
		series.append(Vector2(t, Vector2(velocity.x, velocity.z).length()))
		var checkpoint := int(c.checkpoint[i])
		if previous >= 0 and checkpoint != previous:
			marks.append({"key": "checkpoint-%d" % checkpoint, "label": "Checkpoint %d" % checkpoint, "time": t})
		previous = checkpoint
		if c.flags[i] & 2 != 0:
			marks.append({"key": "finish", "label": "Finish", "time": t})
			break
	if series.is_empty():
		return {"ok": false, "error": "This attempt ended before its timer started."}
	return {"ok": true, "path": path, "run": run, "identity": run.header.get("identity", {}), "marks": marks, "speed": series, "duration": last_time}

static func compare(attempt: Dictionary, best: Dictionary) -> Dictionary:
	if not attempt.get("ok", false):
		return attempt
	if not best.get("ok", false):
		return best
	for identity: Dictionary in [attempt.identity, best.identity]:
		for key: String in ["map", "geometry", "preset", "motor", "timing", "physics_hz", "runner"]:
			if not identity.has(key):
				return {"ok": false, "error": "The recording has no %s motion identity; comparison is unavailable." % key}
	var why := READER.identity_matches(attempt.identity, best.identity)
	if not why.is_empty():
		var fields: Array[String] = []
		for key: String in attempt.identity:
			if not best.identity.has(key) or attempt.identity[key] != best.identity[key]:
				fields.append(key)
		for key: String in best.identity:
			if not attempt.identity.has(key): fields.append(key)
		return {"ok": false, "error": "These runs differ in %s; choose recordings with the same motion identity." % ", ".join(fields)}
	var clean := READER.clean_finish(best.run)
	if not clean.ok:
		return {"ok": false, "error": "The comparison run is not a clean personal best: " + str(clean.error)}
	var splits: Array = []
	var previous_a := 0.0
	var previous_b := 0.0
	var start := "Start"
	var b_marks: Array = best.marks
	for i: int in attempt.marks.size():
		var a: Dictionary = attempt.marks[i]
		if i >= b_marks.size() or a.key != b_marks[i].key:
			return {"ok": false, "error": "The checkpoint order differs; segment comparisons would be misleading."}
		var b: Dictionary = b_marks[i]
		splits.append({"label": a.label, "from": start, "time": a.time, "best_time": b.time, "delta": a.time - b.time, "loss": (a.time - previous_a) - (b.time - previous_b), "start_time": previous_a})
		previous_a = a.time
		previous_b = b.time
		start = a.label
	return {"ok": true, "attempt": attempt, "best": best, "splits": splits, "duration": maxf(attempt.duration, best.duration)}

## summary scans validate the digest chain without retaining hundreds of decoded tracks.
static func begin_scan(directory: String) -> Dictionary:
	var files := DirAccess.get_files_at(directory) if DirAccess.dir_exists_absolute(directory) else PackedStringArray()
	return {"directory": directory, "files": files, "index": 0, "entries": []}

static func step_scan(scan: Dictionary, budget_usec: int = 4000) -> bool:
	var start := Time.get_ticks_usec()
	while scan.index < scan.files.size():
		var filename: String = scan.files[scan.index]
		scan.index += 1
		if filename.ends_with(".r16run"):
			scan.entries.append(read_summary(scan.directory.path_join(filename)))
		if Time.get_ticks_usec() - start >= budget_usec:
			return false
	scan.entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.created > b.created if a.created != b.created else a.name > b.name)
	return true

static func read_summary(path: String) -> Dictionary:
	var run := READER.read(path, false)
	var identity: Variant = run.header.get("identity", {})
	var outcome: Variant = run.seal.get("outcome", {})
	var created: Variant = run.header.get("created_unix", 0)
	return {"path": path, "name": path.get_file(), "ok": run.ok, "status": run.status, "identity": identity if identity is Dictionary else {}, "created": float(created) if created is float or created is int else 0.0, "outcome": outcome if outcome is Dictionary else {}}

static func list_attempts(directory: String) -> Array:
	var scan := begin_scan(directory)
	while not step_scan(scan):
		pass
	return scan.entries

static func matching_best(entries: Array, attempt: Dictionary) -> Dictionary:
	var candidates: Array = []
	for entry: Dictionary in entries:
		if entry.ok and READER.identity_matches(entry.identity, attempt.identity).is_empty() and entry.outcome.get("kind") == "finish" and entry.outcome.get("clean") == true and (entry.outcome.get("time") is int or entry.outcome.get("time") is float):
			candidates.append(entry)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.outcome.get("time", INF)) < float(b.outcome.get("time", INF)))
	for candidate: Dictionary in candidates:
		if candidate.path == attempt.path and READER.clean_finish(attempt.run).ok:
			return attempt
		var decoded := load_attempt(candidate.path)
		if decoded.ok and READER.clean_finish(decoded.run).ok:
			return decoded
	return {"ok": false, "error": "No clean finished personal best matches this attempt's motion identity."}
static func biggest_loss(comparison: Dictionary) -> String:
	if not comparison.get("ok", false):
		return ""
	var worst: Dictionary = {}
	for split: Dictionary in comparison.splits:
		if float(split.loss) > float(worst.get("loss", 0.0)):
			worst = split
	if worst.is_empty():
		return "No time lost against the best across the completed segments." if not comparison.splits.is_empty() else "Reach a checkpoint to compare a complete segment."
	return "Biggest loss: %.3f s between %s and %s." % [worst.loss, worst.from, worst.label]

static func practice_request(pair: Dictionary) -> Dictionary:
	if not pair.get("ok", false):
		return {"ok": false, "error": "Choose a comparable attempt first."}
	var worst := -1
	for i: int in pair.splits.size():
		if float(pair.splits[i].loss) > (float(pair.splits[worst].loss) if worst >= 0 else 0.0):
			worst = i
	if worst < 0:
		return {"ok": false, "error": "No completed segment lost time against this best."}
	var stage := 0
	if worst > 0:
		stage = int(str(pair.best.marks[worst - 1].key).trim_prefix("checkpoint-"))
	return {"ok": true, "stage": stage, "pb_start": 0.0 if worst == 0 else float(pair.best.marks[worst - 1].time),
		"pb_end": float(pair.best.marks[worst].time), "best_path": str(pair.best.path),
		"identity": pair.attempt.identity.duplicate(true), "label": "%s to %s" % [pair.splits[worst].from, pair.splits[worst].label]}

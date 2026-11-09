extends "res://tests/r17_parity.gd"
## verification only: retain the accepted input executor and controls, load the configured host.
var observations: FileAccess
var last_observation := ""
var host_scene := ""
var host_script := ""
var reader_results: Array = []

func _build_world() -> Array:
	variant = str(opts.get("variant", "r18"))
	host_scene = str(opts.get("host-scene", ProjectSettings.get_setting("application/run/main_scene")))
	var scene := load(host_scene) as PackedScene
	if scene == null:
		return ["configured host is not a PackedScene: " + host_scene]
	game = scene.instantiate()
	host_script = (game.get_script() as Script).resource_path
	if opts.has("host-script") and host_script != str(opts["host-script"]):
		game.free()
		return ["configured host script differs from requested script"]
	game.map_id = str(opts.get("map", "breakwater"))
	game.motor = str(opts.get("preset", "server128"))
	game.source_sensitivity_override = float(opts.get("sensitivity", "2.5"))
	game.persist = false
	game.seed_from_r15 = false
	game.record_runs = true
	game.recordings_dir = out_dir.path_join("runs")
	root.add_child(game)
	player = game.player
	if opts.has("ghost"):
		check(game.session.ghost.loaded, "same golden ghost discovered before moving tape")
		check(FileAccess.get_sha256(game.session.ghost_path) == FileAccess.get_sha256(str(opts.ghost)), "discovered golden ghost bytes match baseline")
	if opts.has("incompatible-ghost"):
		check(not game.session.ghost.loaded, "old map revision ghost rejected at startup")
		var rejected: Dictionary = game.session.ghost.load_run(str(opts["incompatible-ghost"]), game.motion_identity())
		check(not bool(rejected.ok) and not str(rejected.get("error", "")).is_empty(), "old revision ghost returns an explicit incompatibility reason")
	ghost_trace = FileAccess.open(out_dir.path_join("evaluator/ghost.jsonl"), FileAccess.WRITE)
	observations = FileAccess.open(out_dir.path_join("evaluator/observations.jsonl"), FileAccess.WRITE)
	world_kind = "lab"
	movie_ticks = int(opts.get("movie-ticks", "-1"))
	setup_writes.append("normal authored spawn via configured PackedScene; map/preset/sensitivity and isolated recording output configured before ready; no body/progress writes")
	return []

func gameplay() -> Dictionary:
	var state := super()
	state["physics"] = {"preset": READER.json_safe(game.preset), "fingerprint": game.physics_fingerprint(), "hull": game.hull_identity(), "mechanics": game.mechanics()}
	state["live_hull"] = _hull_origin_snapshot()
	var camera := player.get("camera") as Camera3D
	state["view"] = {"p": _v3(camera.global_position), "yaw": camera.global_rotation.y, "pitch": camera.global_rotation.x, "fov": camera.fov}
	return state

func late_step(delta: float) -> void:
	# independently retain all actual post-step observations, including warmup and lifecycle attempts.
	player = game.player
	var session: Node = game.session
	if session.tick > 0 and int(session.last_sample.get("tick", -1)) == session.tick - 1:
		var run_id := str(session.last_begin.get("run_id", ""))
		var key := run_id + ":" + str(session.last_sample.tick)
		if key != last_observation:
			last_observation = key
			var scored: Array = []
			for event: Dictionary in session.style.events:
				if int(event.tick) == int(session.last_sample.tick):
					scored.append(event)
			var observed_sample: Dictionary = READER.json_safe(session.last_sample)
			observed_sample["input_events"] = READER.json_safe(session.describe_all(session.last_sample.input_events))
			observations.store_line(JSON.stringify({"run_id": run_id, "sample": observed_sample,
				"actual": gameplay(), "style_events": scored}, "", false, true))
	super(delta)

func _write_summary() -> void:
	# request_quit seals the real host's final attempt synchronously before its frame-awaited exit.
	game.request_quit(0 if checks.all(func(c: Dictionary) -> bool: return c.ok) else 1)
	observations.flush()
	observations.close()
	for name: String in DirAccess.get_files_at(out_dir.path_join("runs")):
		if name == "golden.r16run":
			continue
		var path := out_dir.path_join("runs").path_join(name)
		var run := READER.read(path, true)
		check(bool(run.ok), "Godot reader validates lifecycle recording " + name)
		if not bool(run.ok):
			continue
		var columns := {}
		for column: String in run.columns:
			var values: Variant = run.columns[column]
			columns[column] = _bytes_hash(values.to_byte_array())
		var inputs := {}
		for column: String in run.inputs:
			var values: Variant = run.inputs[column]
			inputs[column] = _bytes_hash(values.to_byte_array())
		reader_results.append({"file": name, "sha256": FileAccess.get_sha256(path), "columns_sha256": columns,
			"inputs_sha256": inputs, "header": run.header, "events": run.events, "seal": run.seal})
	# check every motion identity key independently, rather than testing only an invented key.
	var good := str(opts.get("ghost", frozen.record_path))
	var identity: Dictionary = frozen.identity
	var rejects := []
	for field: String in identity:
		var bad := identity.duplicate(true)
		bad[field] = "deliberately incompatible " + str(identity[field])
		var outcome: Dictionary = game.session.ghost.load_run(good, bad)
		var ok: bool = not bool(outcome.ok) and not game.session.ghost.loaded and not str(outcome.get("error", "")).is_empty()
		check(ok, "ghost rejects changed motion identity field " + field)
		rejects.append({"field": field, "ok": ok, "error": outcome.get("error", "")})
	_write_json("readers.json", reader_results)
	_write_json("summary.json", {"scope": "headless actual configured host; source-only, no visual/package/Windows/enjoyment claim",
		"variant": variant, "host_scene": host_scene, "host_script": host_script, "finish": frozen,
		"checks": checks, "toggles": toggle_rows, "tour": tour_rows, "setup_writes": setup_writes, "identity_rejections": rejects})

func _bytes_hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		context.update(bytes)
	return context.finish().hex_encode()

func _write_json(relative: String, value: Variant) -> void:
	var file := FileAccess.open(out_dir.path_join(relative), FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t", true, true))
	file.close()

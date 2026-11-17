extends SceneTree
## suspension can receive session ticks without advancing style or replacing placement evidence.
const STYLE := preload("res://scripts/scoring/style.gd")
const HOLD_TICKS := 205
var output := ""
var baseline_path := ""
var checks: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg.begins_with("--baseline-style="):
			baseline_path = arg.trim_prefix("--baseline-style=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	if not ok:
		push_error(label)

func sample(tick: int, position := Vector3.ZERO, delta := Vector3.ZERO) -> Dictionary:
	return {"tick": tick, "dt": 1.0 / 128, "physics_hz": 128, "p": position, "reference_p": position,
		"grounded": true, "ducked": false, "clean": true, "started": false, "finished": false,
		"motion": {"origin_delta": delta}, "stats": {"hops": 0}}

func seeded(script: Script) -> RefCounted:
	var style: RefCounted = script.new()
	style.step(sample(0), null)
	style.combo = 1
	style.set("_last_combo_time", style.get("_time"))
	return style

func ordinary(script: Script, pause: bool) -> PackedByteArray:
	var style := seeded(script)
	var transcript: Array = []
	for tick: int in range(1, 110):
		if pause and tick == 2:
			# tree pause emits no samples and consumes no session ticks.
			style.discontinuity("pause")
			style.discontinuity("resume")
		transcript.append(style.step(sample(tick), null))
		transcript.append(style.snapshot())
	return var_to_bytes(transcript)

func run() -> void:
	var style := seeded(STYLE)
	# include pending direction evidence: a hold must not consume or replace it.
	style.set("_direction_chain", 2)
	style.set("_direction_pending", 160)
	style.set("_direction_flight", {"from": Vector3(1, 2, 3), "ticks": 4})
	style.discontinuity("pause")
	var frozen := var_to_bytes(style.snapshot())
	var previous: Dictionary = style.get("_prev").duplicate(true)
	var last_sample := var_to_bytes(style.get("_last_sample"))
	var silent := true
	for tick: int in range(1, HOLD_TICKS + 1):
		# deliberately different evidence would expose an accidental whole-sample update.
		var held := sample(tick, Vector3(50, 0, 0), Vector3(10, 0, 0))
		held.grounded = false
		held.ducked = true
		held.finished = true
		silent = style.step(held, null).is_empty() and silent
	check(silent, "all 205 held samples emit no events")
	check(var_to_bytes(style.snapshot()) == frozen, "hold freezes score, combo, clock and direction evidence")
	previous.tick = HOLD_TICKS
	check(var_to_bytes(style.get("_prev")) == var_to_bytes(previous), "only previous tick advances")
	check(var_to_bytes(style.get("_last_sample")) == last_sample, "hold preserves last motion sample")
	style.discontinuity("resume")
	style.step(sample(HOLD_TICKS + 1, Vector3(0.1, 0, 0), Vector3(0.1, 0, 0)), null)
	check(style.combo == 1 and style.snapshot().diag.auto_breaks == 0, "resume accepts actual origin delta and preserves combo")
	check(style.snapshot().time_s == 2.0 / 128, "only physical scoring steps advance style time")
	var moved := seeded(STYLE)
	moved.discontinuity("pause")
	moved.step(sample(1, Vector3(50, 0, 0)), null)
	moved.discontinuity("resume")
	moved.step(sample(2, Vector3(50, 0, 0)), null)
	check(moved.combo == 0 and "auto:teleport" in moved.snapshot().diag.discontinuities, "placement during hold is still rejected on resume")
	var empty: RefCounted = STYLE.new()
	empty.discontinuity("pause")
	empty.step(sample(10), null)
	check(empty.get("_prev").is_empty(), "hold before first sample creates no evidence")
	empty.discontinuity("resume")
	empty.step(sample(11), null)
	check(empty.snapshot().diag.auto_breaks == 0, "resume without earlier evidence starts normally")
	var sealed := seeded(STYLE)
	var finish := sample(1)
	finish.finished = true
	sealed.step(finish, null)
	sealed.discontinuity("pause")
	var sealed_prev := var_to_bytes(sealed.get("_prev"))
	var sealed_snapshot := var_to_bytes(sealed.snapshot())
	sealed.step(sample(99), null)
	check(var_to_bytes(sealed.get("_prev")) == sealed_prev and var_to_bytes(sealed.snapshot()) == sealed_snapshot, "sealed state takes precedence over suspension")
	check(ordinary(STYLE, false) == ordinary(STYLE, true), "tree pause matches uninterrupted stepping byte for byte")
	var normal := seeded(STYLE)
	normal.step(sample(1), null)
	check(normal.combo == 1 and normal.snapshot().diag.auto_breaks == 0, "ordinary consecutive samples preserve combo")
	normal.step(sample(3), null)
	check(normal.combo == 0 and "auto:tick_gap" in normal.snapshot().diag.discontinuities, "ordinary missing tick still breaks continuity")
	if not baseline_path.is_empty():
		var baseline: Script = load(baseline_path)
		check(ordinary(STYLE, false) == ordinary(baseline, false), "ordinary stepping bytes match untouched scorer")
		check(ordinary(STYLE, true) == ordinary(baseline, true), "tree pause bytes match untouched scorer")
		check(STYLE.identity() == baseline.identity(), "style identity remains unchanged")
		var original := seeded(baseline)
		original.discontinuity("pause")
		for tick: int in range(1, HOLD_TICKS + 1):
			original.step(sample(tick), null)
		original.discontinuity("resume")
		original.step(sample(HOLD_TICKS + 1), null)
		check(original.combo == 0 and "auto:tick_gap" in original.snapshot().diag.discontinuities, "untouched scorer reproduces streamed-hold failure")
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("suspension.json"), FileAccess.WRITE).store_string(JSON.stringify({"ok": ok, "checks": checks}, "\t"))
	print("Style suspension: ", ok, " checks=", checks.size())
	quit(0 if ok else 1)

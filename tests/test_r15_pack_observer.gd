extends SceneTree
## source-only exercise of the exact packed probe's early/late capture and input injector.
## fixture cases are labelled. the optional course case starts at its normal authored spawn.
## no movement, progress or records are written after the main builds its own runner.

const MAIN := preload("res://scripts/r15_main.gd")
const FIXTURE := preload("res://tests/r15_loop_fixture_level.gd")

class Observer:
	extends "res://tools/r15-pack-probe.gd"
	func _ready() -> void:
		# the test supplies its game/spec; release admission and clean-finish checks stay separate.
		pass
	func _end_tape() -> void:
		tape_done = true
		for key: String in KEYS:
			_key(KEYS[key], false)
		held.clear()

var out := ""
var cases: Array = []
var results: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--spec="):
			var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--spec=")))
			out = str(spec.out)
			cases = spec.cases
	_run.call_deferred()

func _run() -> void:
	for item: Dictionary in cases:
		var main := MAIN.new()
		if item.get("fixture", true):
			FIXTURE.params = {"roof": bool(item.get("roof", false))}
			main.level_script = FIXTURE
		else:
			main.map_id = str(item.get("map", "breakwater"))
		main.motor = str(item.preset)
		main.source_sensitivity_override = float(item.get("sensitivity", 2.5))
		root.add_child(main)
		var probe := Observer.new()
		probe.game = main
		probe.spec = {"tape": item.tape, "arm_motor_steps": int(item.get("warmup", 32)), "capture_ticks": []}
		probe.report["mode"] = "source-observer-test"
		root.add_child(probe)
		probe._arm_tape()
		var deadline := Time.get_ticks_msec() + 180000
		while not probe.tape_done and Time.get_ticks_msec() < deadline:
			await process_frame
		var dir := out.path_join(str(item.name))
		DirAccess.make_dir_recursive_absolute(dir)
		var stream := FileAccess.open(dir.path_join("trace.jsonl"), FileAccess.WRITE)
		for row: Dictionary in probe.trace:
			stream.store_line(JSON.stringify(row, "", false, true))
		stream.close()
		var player: Node = main.player
		var summary := {"name": item.name, "completed": probe.tape_done, "checks": probe.checks,
			"rows": probe.trace.size(), "preset": main.preset_id, "map": main.map_id, "persist": main.persist,
			"input_settings": {"mouse_sensitivity": player.get("tape_radians_per_count") if "tape_radians_per_count" in player else player.get("mouse_sensitivity"),
				"pitch_limit": player.get("pitch_limit") if "pitch_limit" in player else 1.4},
			"finished": main.finished, "finish_kind": main.finish_kind, "elapsed": main.elapsed,
			"respawns": main.respawn_count, "engine_hz": Engine.physics_ticks_per_second,
			"neutral": probe._input_observation().actions.is_empty() and probe._input_observation().physical.is_empty(),
			"scope": "source editor, exact packed capture methods; fixture or normal spawn as declared in case"}
		results.append(summary)
		for name: String in ["ProbeEarly", "ProbeLate"]:
			var child := root.get_node_or_null(name)
			if child != null:
				child.queue_free()
		probe.queue_free()
		main.queue_free()
		await process_frame
		await process_frame
	# run the same UI-control coroutine the release probe will use, on the actual default map.
	var control_main := MAIN.new()
	root.add_child(control_main)
	var control_probe := Observer.new()
	control_probe.game = control_main
	control_probe.report["mode"] = "source-controls-test"
	root.add_child(control_probe)
	control_probe.expect = {"identity": {"registry": control_probe._registry()}}
	await control_probe._crouch_controls()
	var controls := FileAccess.open(out.path_join("crouch-controls.json"), FileAccess.WRITE)
	controls.store_string(JSON.stringify(control_probe.checks, "  ", false, true))
	controls.close()
	control_probe.queue_free()
	control_main.queue_free()
	await process_frame
	await process_frame
	var file := FileAccess.open(out.path_join("runs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  ", false, true))
	file.close()
	print("r15 packed-observer source exercises: ", results.size())
	quit(0 if results.all(func(r: Dictionary) -> bool: return r.completed and r.neutral and r.checks.all(func(c: Dictionary) -> bool: return c.ok)) else 1)

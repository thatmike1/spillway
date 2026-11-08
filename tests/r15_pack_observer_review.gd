extends SceneTree
## review harness, source mode only: the exact packed probe capture with labelled input
## reductions. "variant" changes only how the harness injects input, never the game or motor.
## a forced respawn calls the game's own respawn() before the motor and is labelled as such.

const MAIN := preload("res://scripts/r15_main.gd")
const FIXTURE := preload("res://tests/r15_loop_fixture_level.gd")

class Observer:
	extends "res://tools/r15-pack-probe.gd"
	var variant: Dictionary = {}
	var _late: Dictionary = {}
	var _late_mouse: Variant = null

	func _ready() -> void:
		pass

	func _end_tape() -> void:
		tape_done = true
		for key: String in KEYS:
			_key(KEYS[key], false)
		held.clear()

	func _key(code: int, pressed: bool) -> void:
		match str(variant.get("key_mode", "")):
			"logical_only":
				var event := InputEventKey.new()
				event.keycode = code
				event.pressed = pressed
				Input.parse_input_event(event)
				Input.flush_buffered_events()
			"action_only":
				for key: String in KEYS:
					if KEYS[key] == code:
						if pressed:
							Input.action_press(ACTIONS[key])
						else:
							Input.action_release(ACTIONS[key])
			_:
				super(code, pressed)

	func _deliver_keys(tick: int) -> void:
		var drop := int(variant.get("drop_tick", -1))
		var late := int(variant.get("late_tick", -1))
		var early := int(variant.get("early_tick", -1))
		if tick == early - 1 and keys_at.has(early):
			# the regression: next tick's edges also go out now, logged under their own tick.
			_send_logged(early)
		if tick != drop and tick != late and tick != early:
			super(tick)
			return
		if tick == early:
			return
		_log(tick)
		if tick == late:
			_late[tick] = true

	func _log(tick: int) -> void:
		for edge: Dictionary in keys_at.get(tick, []):
			if not delivered_keys.has(tick):
				delivered_keys[tick] = []
			delivered_keys[tick].append({"key": edge.key, "edge": edge.edge, "motor_steps": game.get("player").get("tape_step_count"),
				"physics_frame": Engine.get_physics_frames(), "in_physics": Engine.is_in_physics_frame()})
			if edge.edge == "press":
				held[edge.key] = true
			else:
				held.erase(edge.key)

	func _send_logged(tick: int) -> void:
		_log(tick)
		for edge: Dictionary in keys_at.get(tick, []):
			_key(KEYS[edge.key], edge.edge == "press")

	func early_step(delta: float) -> void:
		if armed and not tape_done and bool(variant.get("mouse_after_motor", false)) and mouse_at.has(next_tick):
			_late_mouse = mouse_at[next_tick]
			mouse_at.erase(next_tick)
		super(delta)
		if armed and not tape_done and next_tick == int(variant.get("respawn_tick", -1)):
			game.call("respawn")

	func late_step(delta: float) -> void:
		if not _row.is_empty():
			var tick := int(_row.tick)
			if _late.has(tick):
				# one tick late: the edges reach Input after this tick's motor step.
				_late.erase(tick)
				for edge: Dictionary in keys_at.get(tick, []):
					_key(KEYS[edge.key], edge.edge == "press")
			if _late_mouse != null:
				var event := InputEventMouseMotion.new()
				event.relative = _late_mouse
				event.screen_relative = _late_mouse
				Input.parse_input_event(event)
				Input.flush_buffered_events()
				_late_mouse = null
		super(delta)

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
		probe.variant = item.get("variant", {})
		probe.game = main
		probe.spec = {"tape": item.tape, "arm_motor_steps": int(item.get("warmup", 32)), "capture_ticks": []}
		probe.report["mode"] = "source-observer-review"
		root.add_child(probe)
		probe._arm_tape()
		var deadline := Time.get_ticks_msec() + 120000
		while not probe.tape_done and Time.get_ticks_msec() < deadline:
			await process_frame
		var dir := out.path_join(str(item.name))
		DirAccess.make_dir_recursive_absolute(dir)
		var stream := FileAccess.open(dir.path_join("trace.jsonl"), FileAccess.WRITE)
		for row: Dictionary in probe.trace:
			stream.store_line(JSON.stringify(row, "", false, true))
		stream.close()
		var player: Node = main.player
		results.append({"name": item.name, "completed": probe.tape_done, "rows": probe.trace.size(), "preset": main.preset_id,
			"map": main.map_id, "persist": main.persist, "respawns": main.respawn_count,
			"input_settings": {"mouse_sensitivity": player.get("tape_radians_per_count") if "tape_radians_per_count" in player else player.get("mouse_sensitivity"),
				"pitch_limit": player.get("pitch_limit") if "pitch_limit" in player else 1.4},
			"neutral": probe._input_observation().actions.is_empty() and probe._input_observation().physical.is_empty()})
		for name: String in ["ProbeEarly", "ProbeLate"]:
			var child := root.get_node_or_null(name)
			if child != null:
				child.queue_free()
		# action_only leaves no key state; release actions so the next case starts neutral.
		for action: String in ["move_forward", "move_left", "move_back", "move_right", "jump", "crouch"]:
			Input.action_release(action)
		probe.queue_free()
		main.queue_free()
		await process_frame
		await process_frame
	var file := FileAccess.open(out.path_join("runs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  ", false, true))
	file.close()
	print("r15 pack observer review exercises: ", results.size())
	quit(0)

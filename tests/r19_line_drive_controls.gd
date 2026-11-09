extends "res://tests/r19_line_drive_route.gd"
## actual input negatives and host lifecycle checks, separate from the clean earned course.
const RUNNER := preload("res://scripts/r19_line_drive_player.gd")
var checks: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var mode := ""
var running_controls := false
var saw_support := false
var saw_wrong_fast_support := false
var max_walk_u := 0.0
var repeated_pad := false
var once_turn := false
var spent_tick := -1

func _start() -> void:
	super()
	mode = str(opts.get("mode", "lifecycle"))
	if mode in ["standing", "walking"]:
		# a labelled checkpoint-fixture start on a real pad; velocity begins at zero.
		level.checkpoints[0].pose = Transform3D(Basis.IDENTITY, Vector3(0, 6.04, -36))
		game.practise_stage(0)
		nodes = []
	elif mode == "wrong-way":
		# ordinary checkpoint practice, then real hops back across the west pad.
		game.practise_stage(1)
		node_from = Vector2(player.position.x, player.position.z)
		nodes = [{"p": Vector2(0, -20), "hop": true, "vt": 450.0}]
	_unit_laws()

func _unit_laws() -> void:
	_check(RUNNER.response(Vector3.ZERO, Vector3.FORWARD, false).is_empty(), "pure response: standing cannot launch")
	_check(RUNNER.response(Vector3(0, 0, -299.9), Vector3.FORWARD, false).is_empty(), "pure response: below 300 cannot launch")
	_check(RUNNER.response(Vector3(400, 0, 0), Vector3.FORWARD, false).is_empty(), "pure response: perpendicular travel cannot launch")
	_check(RUNNER.response(Vector3(0, 0, -400), Vector3.FORWARD, true).is_empty(), "pure response: spent pad cannot launch")
	var fast := RUNNER.response(Vector3(0, 0, -1100), Vector3.FORWARD, false)
	_check(is_equal_approx(Vector2(fast.after_u.x, fast.after_u.z).length(), 1100.0), "pure response: faster entry is preserved")
	_check(not RUNNER.response(Vector3(0, 0, -300), Vector3.FORWARD, false).is_empty(), "pure response: exactly 300 aligned is eligible")

func _control_source(tick: int) -> void:
	if mode == "standing":
		_want({}, tick)
	elif mode == "walking":
		_want({"w": true} if tick < 18 else {}, tick)
	else:
		super(tick)

func _observe(tick: int) -> void:
	var probes := pad_probes()
	var speed_u := Vector2(player.velocity.x, player.velocity.z).length() / U
	max_walk_u = maxf(max_walk_u, speed_u)
	for probe: Dictionary in probes:
		if probe.grounded and not probe.support.is_empty():
			saw_support = true
			if probe.speed_u >= 300 and probe.alignment < 0.94:
				saw_wrong_fast_support = true
	observations.append({"tick": tick, "p": plain(player.position), "v": plain(player.velocity), "probes": probes,
		"used": player.used_pads.keys(), "grounded": player.is_grounded(), "checkpoint": game.checkpoint_index})
	if mode in ["standing", "walking"] and tick >= 160:
		_check(saw_support and player.launch_events.is_empty(), "real input: " + mode + " on actual pad support earns no launch")
		_check(max_walk_u < 300, "real input negative remains below launch threshold")
		_finish_controls()
	elif mode == "wrong-way" and (saw_wrong_fast_support or tick >= 900):
		_check(saw_wrong_fast_support and player.launch_events.is_empty(), "real hops: 300+ wrong-way pad support earns no launch")
		_finish_controls()
	elif mode == "once" and not once_turn and game.checkpoint_index == 1 and player.is_grounded() and player.used_pads.has("LaunchWest"):
		once_turn = true
		node_from = Vector2(player.position.x, player.position.z)
		node_index = 0
		nodes = [{"p": Vector2(0, -40), "fall": 1.0}, {"p": Vector2(10, -40)},
			{"p": Vector2(10, 32)}, {"p": Vector2(0, 32)}, {"p": Vector2(0, 12)},
			{"p": Vector2(0, -43), "hop": true, "vt": 450.0}]
	elif mode == "once" and once_turn:
		for probe: Dictionary in probes:
			if probe.id == "LaunchWest" and probe.used and probe.grounded and not probe.support.is_empty() and probe.speed_u >= 300 and probe.alignment >= 0.94:
				repeated_pad = true
				if spent_tick < 0:
					spent_tick = tick
		if repeated_pad and tick >= spent_tick + 8:
			_check(player.launch_events.size() == 1, "real input: revisiting spent pad with aligned 300+ support never launches twice")
			_finish_controls()
	elif mode == "lifecycle" and game.checkpoint_index == 1 and player.is_grounded() and player.used_pads.has("LaunchWest"):
		if not running_controls:
			running_controls = true
			_lifecycle(tick)
	if tick >= 7000 and not closing:
		_check(false, "controls budget")
		_finish_controls()

func _check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})

func _key_control(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _lifecycle(tick: int) -> void:
	done = true
	_want({}, tick)
	_check(player.launch_events.size() == 1, "lifecycle starts after earned west launch and destination support")
	_key_control(KEY_ESCAPE)
	var before: Dictionary = {"p": player.position, "v": player.velocity, "motion": player.get_motion_state(), "time": game.elapsed,
		"checks": game.session.actual_v_checks, "pads": player.used_pads.duplicate(), "tick": player.motion_tick}
	for i: int in 24:
		await physics_frame
	_check(game.paused and player.position == before.p and player.velocity == before.v and player.motion_tick == before.tick and player.get_motion_state().line_drive == before.motion.line_drive and game.elapsed == before.time and game.session.actual_v_checks == before.checks and player.used_pads == before.pads, "Esc pause freezes body, launch state, clock and recorder samples")
	_key_control(KEY_ESCAPE)
	_check(not game.paused, "Esc resumes")
	_key_control(KEY_F)
	_check(game.checkpoint_index == 1 and not game.clean_eligible and game.practice_reason == "practice" and player.used_pads.is_empty() and player.launch_events.is_empty(), "F checkpoint practice clears launch usage and events and stays practice")
	_check(player.position.distance_to(level.checkpoints[1].pose.origin) < 0.001, "F uses authored reached checkpoint pose")
	_key_control(KEY_R)
	_check(game.checkpoint_index == 0 and game.clean_eligible and player.used_pads.is_empty() and player.last_launch.is_empty() and game.elapsed == 0, "R restores clean spawn and fresh launch state")
	_check(player.position.distance_to(level.spawn.origin) < 0.001, "R uses authored spawn")
	game.select_map("breakwater")
	player = game.player
	_check(player.get_script().resource_path == "res://scripts/r15_source_player.gd" and not player.has_method("experiment_status") and not game.is_lab(), "map exit restores pure R15 body with no launch status")
	game.select_map("line-drive")
	player = game.player
	_check(player.get_script().resource_path == "res://scripts/r19_line_drive_player.gd" and player.used_pads.is_empty() and player.launch_events.is_empty(), "returning creates fresh scoped experiment body")
	_finish_controls()

func _finish_controls() -> void:
	if closing:
		return
	closing = true
	done = true
	_want({}, step - arm_step)
	var ok := checks.all(func(c: Dictionary) -> bool: return c.ok)
	_write("controls.json", {"ok": ok, "mode": mode, "checks": checks, "observations": observations,
		"max_speed_u": max_walk_u, "fixture": "practice start on pad" if mode in ["standing", "walking"] else "ordinary host/session and input"})
	print("line drive controls: ", mode, " ok=", ok, " checks=", checks)
	await game.request_quit(0 if ok else 1)

func _route_finished(_tick: int) -> bool:
	return false

func _end(reason: String, _tick: int) -> void:
	_check(false, "unexpected controls termination: " + reason)
	_finish_controls()

extends Node
## real-input player-view route playback. No pose, velocity, camera or run-state writes.
## attach(main, route, seed), then use --bot-quit for an exit status. Native PNGs
## require --screenshots and a real display; --capture-every=N throttles them.

const ACTIONS: Array[String] = ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch"]
var main: Node
var player: CharacterBody3D
var level: Node3D
var route_name: String = "safe"
var seed_value: int = 0
var index: int = 0
var time: float = 0
var done: bool = false
var succeeded: bool = false
var failure_reason: String = ""
var log_lines: PackedStringArray = PackedStringArray()
var quit_at_end: bool = false
var _route: Array = []
var _rng := RandomNumberGenerator.new()
var _held: Dictionary = {}
var _trace: FileAccess
var _evidence_dir: String
var _sample_age: float = 0
var _capture_age: float = 0
var _capture_every: float = 2.0
var _screenshots: bool = false
var _capture_pending: bool = false
var _capture_index: int = 0
var _jump_release_at: float = -1
var _progress_at: float = 0
var _best_distance: float = INF
var _initial_respawns: int = 0
var _previous: Vector3
var _max_step: float = 0
var _yaw_bias: float = 0
var _radius_bias: float = 0
var _finish_wait: float = 0
var _sensitivity: float = .0022
var _run_id: String = ""

func attach(owner_main: Node, route: String = "safe", seed: int = 0) -> void:
	main = owner_main
	player = main.get("player") as CharacterBody3D
	level = main.get("level") as Node3D
	route_name = route
	seed_value = seed
	_evidence_dir = OS.get_user_data_dir().path_join("spillway-evidence")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--route="):
			route_name = arg.trim_prefix("--route=")
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--evidence-dir="):
			_evidence_dir = arg.trim_prefix("--evidence-dir=")
		elif arg.begins_with("--capture-every="):
			_capture_every = maxf(.25, float(arg.trim_prefix("--capture-every=")))
		elif arg == "--screenshots":
			_screenshots = true
		elif arg == "--bot-quit":
			quit_at_end = true
	process_physics_priority = -100
	if player == null or level == null:
		_fail_setup("main must expose player and level")
		return
	var main_script: Script = main.get_script() as Script
	if main_script != null and main_script.has_method("bind_inputs"):
		main_script.call("bind_inputs")
	for action_name: String in ACTIONS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, .1)
	_evidence_dir = _evidence_dir.simplify_path()
	if not evidence_path_allowed(_evidence_dir):
		_fail_setup("--evidence-dir must be an absolute directory outside Git")
		return
	if DirAccess.make_dir_recursive_absolute(_evidence_dir) != OK:
		_fail_setup("cannot create evidence directory " + _evidence_dir)
		return
	_run_id = "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var basename: String = "route-%s-seed-%d-%s" % [route_name.validate_filename(), seed_value, _run_id]
	_trace = FileAccess.open(_evidence_dir.path_join(basename + ".jsonl"), FileAccess.WRITE)
	if _trace == null:
		_fail_setup("cannot create JSONL trace")
		return
	_screenshots = _screenshots and DisplayServer.get_name() != "headless"
	_rng.seed = seed_value
	var routes: Dictionary = level.get("routes")
	if not routes.has(route_name) or not routes[route_name] is Array or routes[route_name].is_empty():
		_fail_setup("missing/nonempty route: " + route_name)
		return
	_route = routes[route_name].duplicate(true)
	for entry: Variant in _route:
		if not entry is Dictionary or not entry.get("pos") is Vector3 or float(entry.get("radius", 0)) <= 0:
			_fail_setup("route points require pos:Vector3 and radius>0")
			return
	for property: Dictionary in player.get_property_list():
		if property.name == "mouse_sensitivity":
			_sensitivity = float(player.get("mouse_sensitivity"))
	if _sensitivity <= 0:
		_fail_setup("mouse sensitivity must be positive")
		return
	_initial_respawns = int(main.get("respawn_count"))
	_previous = player.global_position
	_set_perturbation()
	_write({"event": "start", "input": "InputEventAction + InputEventMouseMotion.screen_relative",
		"route": route_name, "seed": seed_value, "attempts": 1, "points": _route.size(),
		"timing_radius_perturbation_m": .08 if seed_value != 0 else 0,
		"aim_perturbation_rad": .012 if seed_value != 0 else 0,
		"display": DisplayServer.get_name(), "screenshots": _screenshots,
		"fixture": false, "trace_path": _trace.get_path_absolute()})
	print("spillway driver: route=%s seed=%d trace=%s" % [route_name, seed_value, _trace.get_path_absolute()])

func _fail_setup(reason: String) -> void:
	failure_reason = reason
	done = true
	printerr("spillway driver setup: ", reason)
	if _trace != null:
		_write({"event": "result", "successes": 0, "attempts": 1, "reason": reason, "route": route_name, "seed": seed_value})
	if quit_at_end:
		get_tree().quit(2)

func _physics_process(delta: float) -> void:
	if done:
		_finish_wait += delta
		if quit_at_end and _finish_wait >= .25:
			get_tree().quit(0 if succeeded else 1)
		return
	if player == null or _trace == null:
		return
	time += delta
	_sample_age += delta
	_capture_age += delta
	_max_step = maxf(_max_step, player.global_position.distance_to(_previous))
	_previous = player.global_position
	if _sample_age >= .05:
		_sample_age = fmod(_sample_age, .05)
		_write(_sample("sample"))
	if _screenshots and _capture_age >= _capture_every and not _capture_pending:
		_capture_age = 0
		_capture_pending = true
		_capture.call_deferred()
	if not player.global_position.is_finite():
		_complete(false, "non-finite position")
		return
	if int(main.get("respawn_count")) > _initial_respawns:
		_complete(false, "respawn interrupted continuous playback")
		return
	if bool(main.get("finished")):
		# the authored finish volume may trigger before the last point radius.
		if index == _route.size() - 1:
			_advance("finish volume")
		_complete(index >= _route.size(), "finish" if index >= _route.size() else "finish before all waypoints")
		return
	if time > 150:
		_complete(false, "150s timeout")
		return
	if time - _progress_at > 14:
		_complete(false, "14s without waypoint progress")
		return
	if _jump_release_at > 0 and time >= _jump_release_at:
		_action("jump", false)
		_jump_release_at = -1
	if index >= _route.size():
		_action("move_forward", false)
		_action("crouch", false)
		return
	var step: Dictionary = _route[index]
	var target: Vector3 = step["pos"]
	var offset: Vector3 = target - player.global_position
	var flat: Vector3 = offset.slide(Vector3.UP)
	var distance: float = flat.length()
	var radius: float = maxf(.15, float(step["radius"]) + _radius_bias)
	if distance < _best_distance - .15:
		_best_distance = distance
		_progress_at = time
	_look(flat, delta)
	var angle: float = 0
	if distance > .001:
		angle = absf(angle_difference(float(player.get("yaw")), atan2(-flat.x, -flat.z)))
	_action("move_forward", angle < deg_to_rad(65) or not player.is_on_floor())
	_action("crouch", bool(step.get("crouch", false)))
	if distance <= radius and absf(offset.y) <= maxf(radius, .8):
		if bool(step.get("jump", false)):
			if not player.is_on_floor():
				return
			_action("jump", true)
			_jump_release_at = time + .16
		_advance("takeoff" if bool(step.get("jump", false)) else "reached")

func _look(flat: Vector3, delta: float) -> void:
	if flat.length_squared() < .00001:
		return
	var desired_yaw: float = atan2(-flat.x, -flat.z) + _yaw_bias
	var change: float = clampf(angle_difference(float(player.get("yaw")), desired_yaw) * 9 * delta, -4.0 * delta, 4.0 * delta)
	# a normal forward view, with a slight downward angle to expose the landing.
	var pitch_change: float = clampf((-.08 - float(player.get("pitch"))) * 6 * delta, -1.5 * delta, 1.5 * delta)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-change, -pitch_change) / _sensitivity
	motion.screen_relative = motion.relative
	Input.parse_input_event(motion)
	Input.flush_buffered_events()

func _action(action_name: String, pressed: bool) -> void:
	if bool(_held.get(action_name, false)) == pressed:
		return
	_held[action_name] = pressed
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_write({"event": "input", "time": time, "action": action_name, "pressed": pressed, "waypoint": index})

func _advance(reason: String) -> void:
	var row: Dictionary = _sample("waypoint")
	row["reason"] = reason
	_write(row)
	log_lines.append("t=%.3f point=%d/%d %s position=%s" % [time, index + 1, _route.size(), reason, player.global_position])
	index += 1
	_progress_at = time
	_best_distance = INF
	_set_perturbation()

func _set_perturbation() -> void:
	_yaw_bias = _rng.randf_range(-.012, .012) if seed_value != 0 else 0
	_radius_bias = _rng.randf_range(-.08, .08) if seed_value != 0 else 0

func _sample(kind: String) -> Dictionary:
	var p: Vector3 = player.global_position
	var v: Vector3 = player.velocity
	return {"event": kind, "time": time, "route": route_name, "seed": seed_value,
		"waypoint": index, "waypoint_count": _route.size(), "position": [p.x, p.y, p.z],
		"velocity": [v.x, v.y, v.z], "speed": player.get_speed(), "mode": player.get("mode"),
		"yaw": player.get("yaw"), "pitch": player.get("pitch"), "grounded": player.is_on_floor(),
		"crouched": player.get("crouched"), "jumps": player.get("jump_count"), "mantles": player.get("mantle_count"),
		"landings": player.get("land_count"), "last_impact": player.get("last_impact"),
		"elapsed": main.get("elapsed"), "checkpoint": main.get("checkpoint_index"),
		"respawns": main.get("respawn_count"), "clean_eligible": main.get("clean_eligible"),
		"max_step_m": _max_step, "held": _held.duplicate()}

func _write(row: Dictionary) -> void:
	if _trace != null:
		_trace.store_line(JSON.stringify(row))
		if row.get("event") != "sample":
			_trace.flush()

func _complete(success: bool, reason: String) -> void:
	done = true
	succeeded = success
	failure_reason = "" if success else reason
	for action_name: String in ACTIONS:
		_action(action_name, false)
	var row: Dictionary = _sample("result")
	if not success:
		var collisions: Array = []
		for collision_index: int in player.get_slide_collision_count():
			var collision: KinematicCollision3D = player.get_slide_collision(collision_index)
			var collider: Object = collision.get_collider()
			var normal: Vector3 = collision.get_normal()
			collisions.append({"collider": str((collider as Node).get_path()) if collider is Node else str(collider),
				"normal": [normal.x, normal.y, normal.z]})
		row["collisions"] = collisions
	row.merge({"success": success, "successes": 1 if success else 0, "attempts": 1, "reason": reason,
		"trace_path": _trace.get_path_absolute()}, true)
	_write(row)
	print("spillway route: %d/1 successful route=%s seed=%d time=%.3f waypoint=%d/%d position=%s reason=%s trace=%s" % [
		1 if success else 0, route_name, seed_value, time, index, _route.size(), player.global_position, reason, _trace.get_path_absolute()])
	if _screenshots and not _capture_pending:
		_capture_pending = true
		_capture.call_deferred()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		var filename: String = "route-%s-seed-%d-%s-frame-%05d.png" % [route_name.validate_filename(), seed_value, _run_id, _capture_index]
		var path: String = _evidence_dir.path_join(filename)
		var error: Error = get_viewport().get_texture().get_image().save_png(path)
		_write({"event": "screenshot", "time": time, "path": path, "error": error})
		_capture_index += 1
	_capture_pending = false

func _exit_tree() -> void:
	for action_name: String in ACTIONS:
		if bool(_held.get(action_name, false)):
			var event := InputEventAction.new()
			event.action = action_name
			event.pressed = false
			Input.parse_input_event(event)
	Input.flush_buffered_events()
	if _trace != null:
		_trace.close()

static func evidence_path_allowed(path: String) -> bool:
	if not path.is_absolute_path():
		return false
	var project: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var repo: String = project
	var candidate: String = project
	while not candidate.is_empty():
		if FileAccess.file_exists(candidate.path_join(".git")) or DirAccess.dir_exists_absolute(candidate.path_join(".git")):
			repo = candidate
			break
		var parent: String = candidate.get_base_dir()
		if parent == candidate:
			break
		candidate = parent
	var clean: String = path.simplify_path().trim_suffix("/")
	return clean != repo and not clean.begins_with(repo + "/")

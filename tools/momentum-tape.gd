extends SceneTree
## p / r13 momentum tape executor. plays a finite, already expanded input tape through
## ordinary InputEvents and records what the motor actually did after it ran. it never
## reads state to choose input, and writes no pose, velocity, camera or progress after the
## labelled setup. tools/momentum-tape.py drives it; docs/momentum/TAPE.md is the protocol.
##
## per physics step N: Early (priority -1000) samples the pre-step body and delivers tick N's
## mouse motion; the game and the motor run; Late (priority 1000) samples the post-step body,
## then delivers tick N+1's key edges. measured on 4.7.2: an action parsed inside step N is
## pressed in N but only "just pressed" in N+1, while one parsed between steps is both in the
## next step. so key edges for tick N go in at the end of step N-1 (or, for tick 0 and in
## process injection, from SceneTree._process), where device input would also arrive.

const MAIN := preload("res://scripts/spillway_main.gd")
const FIXTURE := preload("res://tools/momentum-tape-fixture.gd")
const MOTORS := {"flow": "res://scripts/momentum_flow_player.gd", "r12": "res://scripts/spillway_player.gd"}
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL}
const ACTIONS := {"w": "move_forward", "a": "move_left", "s": "move_back", "d": "move_right", "space": "jump", "ctrl": "crouch"}
const FORMAT := "spillway-momentum-tape"
const PROFILES := {"tick120": 1, "render30": 4}
# p / a finite simulation budget: no tape may run longer than ten simulated minutes.
const MAX_TICKS := 120 * 600

class Early:
	extends Node
	var run: Variant
	func _physics_process(_delta: float) -> void:
		run.early_step()

class Late:
	extends Node
	var run: Variant
	func _physics_process(_delta: float) -> void:
		run.late_step()

var opts: Dictionary = {}
var out_dir := ""
var world_kind := "lab"
var game: Node
var player: CharacterBody3D
var keys_at: Dictionary = {}
var mouse_at: Dictionary = {}
var duration := 0
var period := 1
var inject := "tick"
var warmup := 8
var step := 0
var arm_step := -1
var armed := false
var finished := false
var held: Dictionary = {}
var delivered: Dictionary = {}
var trace: FileAccess
var frames_log: FileAccess
var row: Dictionary = {}
var pending: Dictionary = {}
var pre_p := Vector3.ZERO
var pre_cur := Vector3.ZERO
var last_tick := -1
var draws := 0
var frame_mode := "movie"
var readback_every := 4
var wall_start_us := 0
var wall_budget_us := 0
var setup_writes: Array = []
var dt := 1.0 / 120.0

func _initialize() -> void:
	wall_start_us = Time.get_ticks_usec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			opts[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	out_dir = str(opts.get("out", ""))
	if out_dir == "" or not out_dir.is_absolute_path() or DirAccess.make_dir_recursive_absolute(out_dir.path_join("evaluator")) != OK:
		printerr("momentum-tape: pass --out=<absolute evidence directory>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("control"))
	var errors := _load_tape(str(opts.get("tape", "")))
	inject = str(opts.get("inject", "tick"))
	warmup = int(opts.get("warmup", "8"))
	frame_mode = str(opts.get("frames", "movie"))
	readback_every = maxi(1, int(opts.get("readback-every", "4")))
	wall_budget_us = int(float(opts.get("wall-budget-s", "120")) * 1000000.0)
	if inject == "process" and period == 1:
		errors.append("process injection is only defined for the render30 cadence")
	if inject not in ["tick", "process"]:
		errors.append("unknown --inject " + inject)
	# count draws from the first frame, so movie frame i is draw i.
	RenderingServer.frame_post_draw.connect(_on_draw)
	_start.call_deferred(errors)

func _start(errors: Array) -> void:
	# the tree is live only after _initialize; the world and runner are built here.
	if errors.is_empty():
		errors = _build_world()
	if not errors.is_empty():
		_write_json("end.json", {"reason": "rejected", "errors": errors})
		printerr("momentum-tape: rejected: ", errors)
		quit(2)
		return
	trace = FileAccess.open(out_dir.path_join("evaluator/trace.jsonl"), FileAccess.WRITE)
	frames_log = FileAccess.open(out_dir.path_join("evaluator/frames.jsonl"), FileAccess.WRITE)
	var early := Early.new()
	early.name = "TapeEarly"
	early.run = self
	early.process_physics_priority = -1000
	early.process_mode = Node.PROCESS_MODE_ALWAYS
	var late := Late.new()
	late.name = "TapeLate"
	late.run = self
	late.process_physics_priority = 1000
	late.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(early)
	root.add_child(late)
	_write_json("evaluator/engine.json", _engine_metadata())
	print("momentum-tape: world=%s motor=%s ticks=%d profile=%s inject=%s" % [world_kind, opts.get("motor", "flow"), duration, tape_profile, inject])

var tape_profile := "tick120"

func _load_tape(path: String) -> Array:
	var errors: Array = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if path != "" else null
	if not parsed is Dictionary:
		return ["tape is missing or not a JSON object: " + path]
	var tape: Dictionary = parsed
	if tape.get("format") != FORMAT or int(tape.get("version", 0)) != 1:
		errors.append("not a %s version 1 tape" % FORMAT)
	if not tape.get("expanded", false) or tape.has("curves"):
		errors.append("tape must be expanded by momentum-tape.py before it runs")
	if int(tape.get("physics_hz", 0)) != Engine.physics_ticks_per_second:
		errors.append("tape physics_hz %s does not match the engine's %d" % [tape.get("physics_hz"), Engine.physics_ticks_per_second])
	dt = 1.0 / float(Engine.physics_ticks_per_second)
	tape_profile = str(tape.get("input_profile", ""))
	if not PROFILES.has(tape_profile):
		errors.append("unknown input_profile " + tape_profile)
	period = PROFILES.get(tape_profile, 1)
	duration = int(tape.get("duration_ticks", 0))
	if duration <= 0 or duration > MAX_TICKS:
		errors.append("duration_ticks must be 1..%d" % MAX_TICKS)
	var down: Dictionary = {}
	var previous := -1
	for event: Dictionary in tape.get("events", []):
		var tick := int(event.get("tick", -1))
		if tick < previous or tick < 0 or tick >= duration or tick % period != 0:
			errors.append("event tick %d is out of order, outside the tape or off the %s cadence" % [tick, tape_profile])
			continue
		previous = tick
		if event.has("key"):
			var key := str(event.key)
			var press := str(event.get("edge")) == "press"
			if not KEYS.has(key) or str(event.get("edge")) not in ["press", "release"] or press == down.has(key):
				errors.append("tick %d: invalid edge %s %s" % [tick, key, event.get("edge")])
				continue
			if press:
				down[key] = true
			else:
				down.erase(key)
			if not keys_at.has(tick):
				keys_at[tick] = []
			keys_at[tick].append({"key": key, "edge": event.edge})
		elif event.has("mouse"):
			var motion: Array = event.mouse
			if mouse_at.has(tick) or motion.size() != 2 or not (is_finite(float(motion[0])) and is_finite(float(motion[1]))):
				errors.append("tick %d: one finite [dx, dy] mouse event per tick" % tick)
				continue
			mouse_at[tick] = Vector2(float(motion[0]), float(motion[1]))
		else:
			errors.append("tick %d: event is neither key nor mouse" % tick)
	return errors

func _build_world() -> Array:
	var motor := str(opts.get("motor", "flow"))
	var sensitivity := float(opts.get("sensitivity", "1.0"))
	var fixture := str(opts.get("fixture", ""))
	world_kind = "fixture" if fixture != "" else "lab"
	if world_kind == "lab":
		# the game factory hook: any Node script, or an inner class of one, that builds its own
		# world in _ready and exposes `player`. default: the r13 lab (real course, hud, audio,
		# normal spawn, records and settings writes off). an optional `motor` string is passed in.
		var game_script := str(opts.get("game-script", "res://scripts/momentum_flow_lab.gd"))
		var game_class := str(opts.get("game-class", "LabMain" if game_script == "res://scripts/momentum_flow_lab.gd" else ""))
		var factory: Variant = load(game_script)
		if factory is Script and game_class != "":
			factory = (factory as Script).get_script_constant_map().get(game_class)
		if not factory is Script:
			return ["cannot load game %s %s" % [game_script, game_class]]
		game = (factory as Script).new() as Node
		if game == null:
			return ["game %s %s is not a Node" % [game_script, game_class]]
		game.name = "TapeGame"
		if "motor" in game:
			game.set("motor", motor)
		root.add_child(game)
		player = game.get("player") as CharacterBody3D
		if player == null:
			return ["game %s %s exposes no CharacterBody3D `player` after _ready" % [game_script, game_class]]
		setup_writes.append("%s%s._ready: builds its world and places the runner at its normal spawn (game code)" % [game_script, ":" + game_class if game_class != "" else ""])
		if not is_equal_approx(sensitivity, 1.0):
			if not ("settings" in game and game.has_method("_apply_settings")):
				return ["game has no settings/_apply_settings for a sensitivity change"]
			var settings: Dictionary = game.get("settings")
			settings["sensitivity"] = sensitivity
			game.call("_apply_settings")
			setup_writes.append("settings.sensitivity = %s through the game's _apply_settings" % sensitivity)
	else:
		var world := FIXTURE.new()
		world.name = "TapeFixture"
		root.add_child(world)
		if not world.build(fixture):
			return ["unknown fixture " + fixture]
		game = world
		MAIN.bind_inputs()
		var path: String = MOTORS.get(motor, motor)
		var script: Variant = load(path)
		if not script is Script:
			return ["cannot load motor " + path]
		player = (script as Script).new()
		player.name = "Runner"
		world.add_child(player)
		player.call("reset_to", world.spawn)
		setup_writes.append("fixture %s: reset_to(%s) once before tick 0" % [fixture, world.spawn.origin])
		# the game's own settings mapping and defaults, from an unattached main instance.
		var main: Node = MAIN.new()
		main.set("player", player)
		var settings: Dictionary = main.get("settings")
		settings["sensitivity"] = sensitivity
		main.call("_apply_settings")
		main.free()
		setup_writes.append("main defaults through main._apply_settings, sensitivity %s" % sensitivity)
		current_scene = world
	return []

func _engine_metadata() -> Dictionary:
	var script := get_script() as Script
	return {"engine": Engine.get_version_info(), "executable": OS.get_executable_path(),
		"executor_script": script.resource_path if script != null else "",
		"renderer": RenderingServer.get_current_rendering_method(), "rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"display_server": DisplayServer.get_name(), "window_size": _v2(DisplayServer.window_get_size()),
		"viewport_size": _v2(root.get_visible_rect().size), "physics_hz": Engine.physics_ticks_per_second,
		"max_physics_steps_per_frame": Engine.max_physics_steps_per_frame, "physics_engine": str(ProjectSettings.get_setting("physics/3d/physics_engine")),
		"accumulated_input": Input.use_accumulated_input, "cmdline": OS.get_cmdline_args(), "user_args": OS.get_cmdline_user_args(),
		"user_data_dir": OS.get_user_data_dir(), "world": world_kind, "start": "fixture" if world_kind == "fixture" else "normal_spawn",
		"fixture": opts.get("fixture", ""),
		"motor": player.get("air_policy") if "air_policy" in player else (player.get("air_profile") if "air_profile" in player else opts.get("motor", "flow")),
		"motor_requested": opts.get("motor", "flow"),
		"game": {"script": opts.get("game-script", "res://scripts/momentum_flow_lab.gd"), "class": opts.get("game-class", ""), "node_script": (game.get_script() as Script).resource_path if game.get_script() != null else ""}, "motor_script": (player.get_script() as Script).resource_path,
		"settings": {"sensitivity": float(opts.get("sensitivity", "1.0")), "mouse_sensitivity": player.get("mouse_sensitivity"),
			"fov_horizontal": player.get("fov_horizontal"), "comfort": player.get("comfort"), "autohop": player.get("autohop")},
		"setup_writes": setup_writes, "input_profile": tape_profile, "cadence_ticks": period, "inject": inject, "warmup_steps": warmup,
		"frames": frame_mode, "readback_every": readback_every, "wall_budget_s": wall_budget_us / 1000000.0,
		"requested_velocity": "motor tape_requested_velocity()" if player.has_method("tape_requested_velocity") else "unavailable: motor exposes no pre-collision velocity",
		"motion_state": "motor get_motion_state(), recorded only" if player.has_method("get_motion_state") else "unavailable"}

# --- per step -------------------------------------------------------------------------------

func early_step() -> void:
	var index := step
	step += 1
	if finished:
		return
	var tick := index - arm_step if armed else -1
	pre_p = player.global_position
	pre_cur = player.get("_current_position") if "_current_position" in player else pre_p
	row = {"phase": "tape" if armed else "warmup", "tick": tick, "step": index,
		"physics_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(),
		"sim_s": tick * dt if armed else null, "wall_us_pre": Time.get_ticks_usec() - wall_start_us,
		"pre": {"p": _v3(pre_p), "v": _v3(player.velocity), "yaw": player.get("yaw"), "pitch": player.get("pitch"),
			"grounded": player.call("is_grounded"), "mode": player.get("mode"),
			"tape_step_count": player.get("tape_step_count") if "tape_step_count" in player else null},
		"keys": pending.get(tick, []), "mouse": {}}
	pending.erase(tick)
	if armed and inject == "tick":
		row["mouse"] = _deliver_mouse(tick, "early_physics")
	elif armed:
		row["mouse"] = pending.get("mouse_%d" % tick, {})
		pending.erase("mouse_%d" % tick)
	if world_kind == "lab":
		row["game_pre"] = {"respawns": game.get("respawn_count")}

func late_step() -> void:
	if finished or row.is_empty():
		return
	var p := player.global_position
	var contacts: Array = []
	for i: int in player.get_slide_collision_count():
		var contact := player.get_slide_collision(i)
		for j: int in contact.get_collision_count():
			var collider := contact.get_collider(j) as Node
			var normal := contact.get_normal(j)
			contacts.append({"body": str(collider.name) if collider != null else "", "normal": _v3(normal),
				"point": _v3(contact.get_position(j)), "v_dot_normal": player.velocity.dot(normal)})
	var camera: Camera3D = player.get("camera")
	var actions: Array = []
	var just_pressed: Array = []
	var just_released: Array = []
	for key: String in ACTIONS:
		if Input.is_action_pressed(ACTIONS[key]):
			actions.append(key)
		if Input.is_action_just_pressed(ACTIONS[key]):
			just_pressed.append(key)
		if Input.is_action_just_released(ACTIONS[key]):
			just_released.append(key)
	row["post"] = {"p": _v3(p), "v": _v3(player.velocity), "real_v": _v3(player.get_real_velocity()),
		"position_delta": _v3(player.get_position_delta()), "disp_v": _v3((p - pre_p) / dt),
		"requested_v": _v3(player.call("tape_requested_velocity")) if player.has_method("tape_requested_velocity") else null,
		# the motor's own report, kept apart: movement is judged from displacement, not from this.
		"motion_state": _plain(player.call("get_motion_state")) if player.has_method("get_motion_state") else null,
		"speed_reported": player.call("get_speed"), "yaw": player.get("yaw"), "pitch": player.get("pitch"),
		"motor_rotation_y": player.rotation.y, "grounded": player.call("is_grounded"), "mode": player.get("mode"),
		"crouched": player.get("crouched"), "jumps": player.get("jump_count"), "lands": player.get("land_count"),
		"in_water": player.get("in_water"), "contacts": contacts,
		"camera": {"p": _v3(camera.global_position), "pitch": camera.global_rotation.x, "yaw": camera.global_rotation.y, "fov": camera.fov, "drawn": "last _process, before this step"},
		"actions": actions, "just_pressed": just_pressed, "just_released": just_released}
	row["order"] = {"same_physics_frame": Engine.get_physics_frames() == int(row.physics_frame), "in_physics": Engine.is_in_physics_frame(),
		"motor_prev_matches_pre": player.get("_previous_position") == pre_cur if "_previous_position" in player else null,
		"motor_cur_matches_body": player.get("_current_position") == p if "_current_position" in player else null,
		"step_count": player.get("tape_step_count") if "tape_step_count" in player else null,
		"step_count_delta": int(player.get("tape_step_count")) - int(row.pre.tape_step_count) if row.pre.tape_step_count != null else null}
	if world_kind == "lab":
		row["game"] = {"respawns": game.get("respawn_count"), "checkpoint": game.get("checkpoint_index"), "elapsed": game.get("elapsed"),
			"finished": game.get("finished"), "finish_kind": game.get("finish_kind"), "paused": game.get("paused")}
	row["wall_us_post"] = Time.get_ticks_usec() - wall_start_us
	trace.store_line(JSON.stringify(row, "", false, true))
	var tick := int(row.tick)
	var was_armed := str(row.phase) == "tape"
	row = {}
	if was_armed:
		last_tick = tick
		if tick + 1 >= duration:
			_finish("completed", 0)
			return
		if inject == "tick":
			_deliver_keys(tick + 1, "late_physics")
	_check_control()

func _process(_delta: float) -> bool:
	if finished or player == null:
		return false
	if not armed and step >= warmup:
		# tape tick 0 is the first physics step after this process frame, in either injection.
		armed = true
		arm_step = step
		_deliver_keys(0, "process_arm")
		if inject == "process":
			pending["mouse_0"] = _deliver_mouse(0, "process")
	elif armed and inject == "process":
		var next := step - arm_step
		if next < duration:
			_deliver_keys(next, "process")
			var motion := _deliver_mouse(next, "process")
			if not motion.is_empty():
				pending["mouse_%d" % next] = motion
	_check_control()
	return false

# --- delivery --------------------------------------------------------------------------------

func _deliver_keys(tick: int, point: String) -> void:
	if not keys_at.has(tick) or delivered.has("k%d" % tick):
		return
	delivered["k%d" % tick] = true
	var log: Array = pending.get(tick, [])
	for edge: Dictionary in keys_at[tick]:
		var pressed: bool = edge.edge == "press"
		_send_key(edge.key, pressed)
		if pressed:
			held[edge.key] = true
		else:
			held.erase(edge.key)
		log.append({"key": edge.key, "edge": edge.edge, "action": ACTIONS[edge.key], "source": "tape", "point": point,
			"steps_started": step, "physics_frame": Engine.get_physics_frames(), "in_physics": Engine.is_in_physics_frame(),
			"wall_us": Time.get_ticks_usec() - wall_start_us})
	pending[tick] = log

func _send_key(key: String, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEYS[key]
	event.physical_keycode = KEYS[key]
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _deliver_mouse(tick: int, point: String) -> Dictionary:
	if not mouse_at.has(tick) or delivered.has("m%d" % tick):
		return {}
	delivered["m%d" % tick] = true
	var delta: Vector2 = mouse_at[tick]
	var yaw_before := float(player.get("yaw"))
	var pitch_before := float(player.get("pitch"))
	var event := InputEventMouseMotion.new()
	event.relative = delta
	event.screen_relative = delta
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	return {"dx": delta.x, "dy": delta.y, "relative": _v2(event.relative), "screen_relative": _v2(event.screen_relative),
		"source": "tape", "point": point, "steps_started": step, "in_physics": Engine.is_in_physics_frame(),
		"yaw_before": yaw_before, "yaw_after": player.get("yaw"), "pitch_before": pitch_before, "pitch_after": player.get("pitch"),
		"wall_us": Time.get_ticks_usec() - wall_start_us}

# --- end, cancellation and evidence ----------------------------------------------------------

func _check_control() -> void:
	if finished:
		return
	if FileAccess.file_exists(out_dir.path_join("control/cancel")):
		_finish("cancelled", 4)
	elif Time.get_ticks_usec() - wall_start_us > wall_budget_us:
		_finish("wall_timeout", 3)

func _finish(reason: String, code: int) -> void:
	finished = true
	# neutral input: release every key the tape still holds, as ordinary release events.
	var released: Array = []
	for key: String in held.keys():
		_send_key(key, false)
		released.append(key)
	held.clear()
	Input.flush_buffered_events()
	var still: Array = []
	for key: String in ACTIONS:
		if Input.is_action_pressed(ACTIONS[key]):
			still.append(key)
			# last-resort cleanup so nothing stays held; the report marks it as a delivery fault.
			Input.action_release(ACTIONS[key])
	var missed: Array = []
	for tick: int in keys_at:
		if not delivered.has("k%d" % tick):
			missed.append({"tick": tick, "keys": keys_at[tick]})
	for tick: int in mouse_at:
		if not delivered.has("m%d" % tick):
			missed.append({"tick": tick, "mouse": _v2(mouse_at[tick])})
	var end := {"reason": reason, "exit_code": code, "last_tick": last_tick, "steps": step, "arm_step": arm_step,
		"draws": draws, "wall_s": (Time.get_ticks_usec() - wall_start_us) / 1000000.0,
		"neutralized": released, "still_pressed_after_release": still, "neutral": still.is_empty(),
		"undelivered": missed}
	if reason == "cancelled":
		_write_json("control/cancel-ack.json", {"tick": last_tick, "wall_s": end.wall_s, "neutral": still.is_empty()})
	_write_json("end.json", end)
	if trace != null:
		trace.close()
	if frames_log != null:
		frames_log.close()
	print("momentum-tape: %s at tick %d (%d steps, %d draws)" % [reason, last_tick, step, draws])
	if world_kind == "lab" and game.has_method("request_quit"):
		game.call("request_quit", code)
	else:
		quit(code)

func _on_draw() -> void:
	var index := draws
	draws += 1
	if finished or frames_log == null:
		return
	var camera: Camera3D = player.get("camera")
	var entry := {"draw": index, "process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames(),
		"steps": step, "last_tick": last_tick, "sim_s": (last_tick + 1) * dt if armed else null,
		"wall_us": Time.get_ticks_usec() - wall_start_us, "feet": _v3(player.global_position),
		"camera": {"p": _v3(camera.global_position), "pitch": camera.global_rotation.x, "yaw": camera.global_rotation.y}}
	if frame_mode == "readback" and armed and index % readback_every == 0:
		var file := out_dir.path_join("frames/draw_%06d.png" % index)
		DirAccess.make_dir_recursive_absolute(out_dir.path_join("frames"))
		root.get_texture().get_image().save_png(file)
		entry["png"] = file
		entry["readback_wall_us"] = Time.get_ticks_usec() - wall_start_us
	frames_log.store_line(JSON.stringify(entry, "", false, true))

func _write_json(relative: String, value: Variant) -> void:
	var file := FileAccess.open(out_dir.path_join(relative), FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  ", false, true))
	file.close()

func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _v2(value: Vector2) -> Array:
	return [value.x, value.y]

func _plain(value: Variant) -> Variant:
	# vectors as arrays so a motor's report stays numeric json.
	if value is Vector3:
		return _v3(value)
	if value is Vector2:
		return _v2(value)
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[str(key)] = _plain(value[key])
		return out
	if value is Array:
		return (value as Array).map(_plain)
	return value

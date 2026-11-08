extends SceneTree
## p / r13 momentum tape executor. plays a finite, already expanded input tape through
## ordinary InputEvents and records what the motor actually did after it ran. it never
## reads state to choose input, and writes no pose, velocity, camera or progress after the
## labelled setup. tools/momentum-tape.py drives it; docs/momentum/TAPE.md is the protocol,
## docs/r14/REPLAY.md the rate-aware version 2 (64, 120 or 128 hz, one event slot per tick).
##
## the physics rate is a run input, not a header label: --physics-hz is applied to the engine
## before the tape is validated and the world is built, the game must not change or contradict
## it in _ready, and any later rate, delta or time-scale change ends the run as rate_changed.
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
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL, "shift": KEY_SHIFT, "e": KEY_E}
const ACTIONS := {"w": "move_forward", "a": "move_left", "s": "move_back", "d": "move_right", "space": "jump", "ctrl": "crouch",
	"shift": "r15_slide", "e": "r15_grapple"}
# p / r15 movement lab keys: version 2 tapes only, and only against a game that binds their actions.
const V2_ONLY_KEYS := ["shift", "e"]
const FORMAT := "spillway-momentum-tape"
const PROFILES := {"tick120": 1, "render30": 4}
# p / a finite simulation budget: no tape may run longer than ten simulated minutes.
const MAX_TICKS := 120 * 600
const MAX_SECONDS := 600
# p / r14: vanilla 64, server-style 128 and r13's original 120 hz; v2 events sit on any tick.
const RATES := [64, 120, 128]
const V2_PROFILE := "physics_tick"

class Early:
	extends Node
	var run: Variant
	func _physics_process(delta: float) -> void:
		run.early_step(delta)

class Late:
	extends Node
	var run: Variant
	func _physics_process(delta: float) -> void:
		run.late_step(delta)

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
var tape_version := 1
var tape_hz := 120
var project_hz := 120
var requested_hz := 0
var rate_declared: Dictionary = {}
var rate_fault: Dictionary = {}
# sum of the deltas the engine actually handed to tape ticks so far.
var tape_dt_sum := 0.0

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
	project_hz = int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))
	# the requested rate goes into the engine before anything is validated or built.
	var errors := _request_rate(str(opts.get("physics-hz", "")))
	errors.append_array(_load_tape(str(opts.get("tape", ""))))
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
	if errors.is_empty():
		errors = _rate_after_ready()
	if errors.is_empty():
		errors = _actions_bound()
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
	print("momentum-tape: world=%s motor=%s ticks=%d profile=%s hz=%d inject=%s" % [world_kind, opts.get("motor", "flow"), duration, tape_profile, tape_hz, inject])

var tape_profile := "tick120"

func _load_tape(path: String) -> Array:
	var errors: Array = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if path != "" else null
	if not parsed is Dictionary:
		return ["tape is missing or not a JSON object: " + path]
	var tape: Dictionary = parsed
	var version: Variant = tape.get("version")
	if tape.get("format") != FORMAT or not (version is float and (version == 1.0 or version == 2.0)):
		errors.append("not a %s version 1 or 2 tape" % FORMAT)
		return errors
	tape_version = int(version)
	if not tape.get("expanded", false) or tape.has("curves"):
		errors.append("tape must be expanded by momentum-tape.py before it runs")
	var hz: Variant = tape.get("physics_hz")
	var whole_hz: bool = hz is float and hz == floorf(hz)
	tape_hz = int(hz) if whole_hz else 0
	if tape_version == 1 and tape_hz != 120:
		errors.append("a version 1 tape is a 120 hz claim; physics_hz %s needs a version 2 tape" % [hz])
	if tape_version == 2 and tape_hz not in RATES:
		errors.append("version 2 physics_hz %s is not one of %s" % [hz, RATES])
	if tape_hz != Engine.physics_ticks_per_second:
		errors.append("tape physics_hz %s does not match the engine's %d" % [hz, Engine.physics_ticks_per_second])
	dt = 1.0 / float(Engine.physics_ticks_per_second)
	tape_profile = str(tape.get("input_profile", ""))
	if tape_version == 1 and not PROFILES.has(tape_profile):
		errors.append("unknown input_profile " + tape_profile)
	if tape_version == 2 and tape_profile != V2_PROFILE:
		errors.append("version 2 input_profile must be %s, not %s" % [V2_PROFILE, tape_profile])
	period = PROFILES.get(tape_profile, 1) if tape_version == 1 else 1
	duration = int(tape.get("duration_ticks", 0))
	var max_ticks := MAX_TICKS if tape_version == 1 else maxi(tape_hz, 1) * MAX_SECONDS
	if duration <= 0 or duration > max_ticks:
		errors.append("duration_ticks must be 1..%d" % max_ticks)
	if tape_version == 2:
		# the redundant duration makes a header-only rate edit fail instead of retiming input.
		var seconds: Variant = tape.get("duration_s")
		if not seconds is float or tape_hz == 0 or absf(float(seconds) - float(duration) / float(tape_hz)) > 1e-9:
			errors.append("duration_s %s is not duration_ticks / physics_hz" % [seconds])
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
			if not KEYS.has(key) or (tape_version == 1 and key in V2_ONLY_KEYS) or str(event.get("edge")) not in ["press", "release"] or press == down.has(key):
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

## every key the tape uses has its action in the game's input map, so no edge goes undelivered.
func _actions_bound() -> Array:
	var errors: Array = []
	for tick: int in keys_at:
		for edge: Dictionary in keys_at[tick]:
			var action: String = ACTIONS[edge.key]
			if not InputMap.has_action(action) and not errors.has("tape key %s needs the %s action, which this game does not bind" % [edge.key, action]):
				errors.append("tape key %s needs the %s action, which this game does not bind" % [edge.key, action])
	return errors

func _request_rate(value: String) -> Array:
	if value == "":
		return []
	if not value.is_valid_int() or int(value) not in RATES:
		return ["requested --physics-hz %s is not one of %s" % [value, RATES]]
	requested_hz = int(value)
	Engine.physics_ticks_per_second = requested_hz
	return []

func _declared_rate() -> Dictionary:
	# the rate the game or its runner says it is built for, wherever it is exposed.
	for owner: Object in [game, player]:
		if "physics_hz" in owner and owner.get("physics_hz") != null:
			return {"source": "%s.physics_hz" % ("game" if owner == game else "player"), "hz": owner.get("physics_hz")}
	if player.has_method("get_motion_state"):
		var state: Variant = player.call("get_motion_state")
		if state is Dictionary and (state as Dictionary).has("physics_hz"):
			return {"source": "player.get_motion_state().physics_hz", "hz": state["physics_hz"]}
	return {"source": "none"}

func _rate_after_ready() -> Array:
	var errors: Array = []
	if Engine.physics_ticks_per_second != tape_hz:
		errors.append("the engine runs at %d hz after the game's _ready; the tape declares %d hz" % [Engine.physics_ticks_per_second, tape_hz])
	if Engine.time_scale != 1.0:
		errors.append("engine time_scale is %s after _ready; a tick tape needs 1.0" % Engine.time_scale)
	rate_declared = _declared_rate()
	if rate_declared.has("hz") and int(rate_declared.hz) != tape_hz:
		errors.append("%s declares %s hz; the tape declares %d hz" % [rate_declared.source, rate_declared.hz, tape_hz])
	elif not rate_declared.has("hz") and tape_hz != project_hz and str(opts.get("undeclared-rate", "")) != "allow":
		errors.append("nothing declares physics_hz and %d hz is not the project's %d hz; pass --undeclared-rate=allow for an off-design probe" % [tape_hz, project_hz])
	return errors

func _rate_ok(point: String, delta: float) -> bool:
	# a tape is a tick sequence at one rate: any change of rate, delta or time scale ends it.
	var hz := Engine.physics_ticks_per_second
	if hz == tape_hz and delta == dt and Engine.time_scale == 1.0:
		return true
	rate_fault = {"point": point, "step": step, "tick": last_tick + 1 if armed else -1, "engine_hz": hz, "tape_hz": tape_hz,
		"delta": delta, "expected_delta": dt, "time_scale": Engine.time_scale}
	return false

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
		setup_writes.append("%s%s._ready: builds its world and places the runner at %s (game code)" % [game_script, ":" + game_class if game_class != "" else "", _start_label()])
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

func _start_label() -> String:
	if world_kind == "fixture":
		return "fixture"
	# a labelled test game can say it is not a normal spawn; real games leave this unset.
	return str(game.get("tape_start")) if "tape_start" in game else "normal_spawn"

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
		"user_data_dir": OS.get_user_data_dir(), "world": world_kind, "start": _start_label(),
		"tape_version": tape_version, "physics_hz_requested": requested_hz if requested_hz else null, "physics_hz_project": project_hz,
		"rate_declared": rate_declared, "rate_policy": "declared" if rate_declared.has("hz") else ("project rate, undeclared" if tape_hz == project_hz else "undeclared off-design probe (--undeclared-rate=allow)"),
		"time_scale": Engine.time_scale, "physics_dt": dt,
		"priorities": {"early": -1000, "late": 1000, "game": game.process_physics_priority if game != null else null, "motor": player.process_physics_priority},
		"body_yaw_policy": player.get("tape_body_yaw_policy") if "tape_body_yaw_policy" in player else "view_yaw",
		"fixture": opts.get("fixture", ""),
		"motor": player.get("air_policy") if "air_policy" in player else (player.get("air_profile") if "air_profile" in player else opts.get("motor", "flow")),
		"motor_requested": opts.get("motor", "flow"),
		"game": {"script": opts.get("game-script", "res://scripts/momentum_flow_lab.gd"), "class": opts.get("game-class", ""), "node_script": (game.get_script() as Script).resource_path if game.get_script() != null else ""}, "motor_script": (player.get_script() as Script).resource_path,
		"settings": {"sensitivity": float(opts.get("sensitivity", "1.0")), "mouse_sensitivity": player.get("tape_radians_per_count") if "tape_radians_per_count" in player else player.get("mouse_sensitivity"),
			"pitch_limit": player.get("pitch_limit") if "pitch_limit" in player else 1.4,
			"fov_horizontal": player.get("fov_horizontal"), "comfort": player.get("comfort"), "autohop": player.get("autohop")},
		"setup_writes": setup_writes, "input_profile": tape_profile, "cadence_ticks": period, "inject": inject, "warmup_steps": warmup,
		"frames": frame_mode, "readback_every": readback_every, "wall_budget_s": wall_budget_us / 1000000.0,
		"requested_velocity": "motor tape_requested_velocity()" if player.has_method("tape_requested_velocity") else "unavailable: motor exposes no pre-collision velocity",
		"motion_state": "motor get_motion_state(), recorded only" if player.has_method("get_motion_state") else "unavailable"}

# --- per step -------------------------------------------------------------------------------

## observe the real box separately from the motor's report. r15 moves its interpolation
## origin when duck changes hull; the evaluator must prove that exception, not ignore it.
func _hull_origin_snapshot() -> Dictionary:
	if not player.has_method("hull_height_u") or not player.has_method("air_lift_u"):
		return {}
	var shape_node: Variant = player.get("collision")
	var cvars: Variant = player.get("settings")
	if not shape_node is CollisionShape3D or not (shape_node as CollisionShape3D).shape is BoxShape3D or not cvars is Dictionary:
		return {}
	var box := (shape_node as CollisionShape3D).shape as BoxShape3D
	return {"box_size_m": _v3(box.size), "box_center_m": _v3(shape_node.position),
		"scale": _v3(shape_node.global_transform.basis.get_scale()), "ducked": player.get("ducked"),
		"standing_u": cvars.get("hull_height"), "duck_u": cvars.get("duck_hull_height"),
		"anchor": cvars.get("duck_air_anchor"), "interp_current": _v3(pre_cur)}

func early_step(delta: float) -> void:
	var index := step
	step += 1
	if finished:
		return
	var tick := index - arm_step if armed else -1
	var ok := _rate_ok("early", delta)
	pre_p = player.global_position
	pre_cur = player.get("_current_position") if "_current_position" in player else pre_p
	row = {"phase": "tape" if armed else "warmup", "tick": tick, "step": index,
		"physics_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(),
		"sim_s": tick * dt if armed else null, "wall_us_pre": Time.get_ticks_usec() - wall_start_us,
		"pre": {"p": _v3(pre_p), "v": _v3(player.velocity), "yaw": player.get("yaw"), "pitch": player.get("pitch"),
			"grounded": player.call("is_grounded"), "mode": player.get("mode"),
			"tape_step_count": player.get("tape_step_count") if "tape_step_count" in player else null},
		"keys": pending.get(tick, []), "mouse": {},
		"rate": {"dt": delta, "engine_hz": Engine.physics_ticks_per_second, "time_scale": Engine.time_scale, "sim_dt_sum_s": tape_dt_sum if armed else null}}
	var hull := _hull_origin_snapshot()
	if not hull.is_empty():
		row["hull_origin"] = {"before": hull}
	pending.erase(tick)
	if not ok:
		row["rate_fault"] = rate_fault
		trace.store_line(JSON.stringify(row, "", false, true))
		row = {}
		_finish("rate_changed", 5)
		return
	if armed and inject == "tick":
		row["mouse"] = _deliver_mouse(tick, "early_physics")
	elif armed:
		row["mouse"] = pending.get("mouse_%d" % tick, {})
		pending.erase("mouse_%d" % tick)
	if world_kind == "lab":
		row["game_pre"] = {"respawns": game.get("respawn_count")}

func late_step(delta: float) -> void:
	if finished or row.is_empty():
		return
	var ok := _rate_ok("late", delta)
	row.rate["dt_late"] = delta
	row.rate["engine_hz_late"] = Engine.physics_ticks_per_second
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
		if not InputMap.has_action(ACTIONS[key]):
			continue
		if Input.is_action_pressed(ACTIONS[key]):
			actions.append(key)
		if Input.is_action_just_pressed(ACTIONS[key]):
			just_pressed.append(key)
		if Input.is_action_just_released(ACTIONS[key]):
			just_released.append(key)
	row["post"] = {"p": _v3(p), "v": _v3(player.velocity), "real_v": _v3(player.get_real_velocity()),
		"position_delta": _v3(player.get_position_delta()), "disp_v": _v3((p - pre_p) / delta),
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
	if row.has("hull_origin"):
		row.hull_origin["after"] = _hull_origin_snapshot()
		row.hull_origin["motor_previous"] = _v3(player.get("_previous_position"))
	if world_kind == "lab":
		row["game"] = {"respawns": game.get("respawn_count"), "checkpoint": game.get("checkpoint_index"), "elapsed": game.get("elapsed"),
			"finished": game.get("finished"), "finish_kind": game.get("finish_kind"), "paused": game.get("paused")}
	row["wall_us_post"] = Time.get_ticks_usec() - wall_start_us
	if not ok:
		row["rate_fault"] = rate_fault
	trace.store_line(JSON.stringify(row, "", false, true))
	var tick := int(row.tick)
	var was_armed := str(row.phase) == "tape"
	row = {}
	if not ok:
		if was_armed:
			last_tick = tick
		_finish("rate_changed", 5)
		return
	if was_armed:
		tape_dt_sum += delta
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
		if not InputMap.has_action(ACTIONS[key]):
			continue
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
		"undelivered": missed, "tape_version": tape_version, "physics_hz": tape_hz, "sim_dt_sum_s": tape_dt_sum}
	if not rate_fault.is_empty():
		end["rate_fault"] = rate_fault
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
		"camera": {"p": _v3(camera.global_position), "pitch": camera.global_rotation.x, "yaw": camera.global_rotation.y},
		# what the presentation interpolates between, so the evaluator can check the camera
		# follows the physical body rather than only staying near it.
		"interp_fraction": Engine.get_physics_interpolation_fraction(),
		"motor_prev": _v3(player.get("_previous_position")) if "_previous_position" in player else null,
		"motor_cur": _v3(player.get("_current_position")) if "_current_position" in player else null}
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

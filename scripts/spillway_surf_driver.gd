extends Node
## p / r12 fast-line bot: one continuous run from the normal spawn through all three surf
## banks, by engine input only (InputEventAction keys, InputEventMouseMotion yaw). it reads
## runner physics and authored geometry to choose inputs; this is a state-aware controller,
## not a human recording. it never writes a pose, velocity, camera or run state. attach(main), then watch done / succeeded /
## failure_reason. --evidence-dir=<abs path> writes per-tick state and explicit input/result events.

const GEOMETRY := preload("res://scripts/spillway_surf_geometry.gd")
const ACTIONS: Array[String] = ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch"]
const TICK := 1.0 / 120.0
# p / a run that has not finished in this much physics time is a failure, not a slow pass.
const TIME_LIMIT := 45.0
# p / bhop waypoints between banks; each is a floor position reached within 2 m.
const CREST_TO_YARD: Array[Vector3] = [Vector3(11, 4, -40), Vector3(10, 4, -47), Vector3(10, 4, -57), Vector3(10, 4, -66)]
# p / aim along the hall toward its wheel, so arrival footage shows the actual finish.
const FINISH_AIM := Vector3(24, -3, -68.8)

var main: Node
var player: CharacterBody3D
var level: Node3D
var done := false
var succeeded := false
var failure_reason := ""
## one line per entry, exit, stage and speed kill, in order; also printed.
var events: PackedStringArray = PackedStringArray()
## per surf section: entry/exit speed and contact ticks, for reports and tests.
var surf_report: Dictionary = {}
## every single-tick horizontal speed loss above 1 m/s, with what was touched.
var speed_drops: Array[Dictionary] = []
var tick := 0
var phase := "crest_runup"

var _held: Dictionary = {}
var _section: Dictionary = {}
var _entry_y := 0.0
var _entry_theta := 0.0
var _waypoint := 0
var _trace: FileAccess
var _initial_respawns := 0
# the runner moves after this node each tick, so a speed loss shows up between callbacks.
var _last_speed := -1.0
var _quit_at_end := false
var _finish_wait := 0.0
var _seed := 0
var _aim_bias := 0.0
var _aim_range := 0.0
var _jump_delay := 0.0
var _peak_speed := 0.0
var _stages: Array[int] = [0]
var _trace_path := ""

func attach(owner_main: Node) -> void:
	main = owner_main
	player = main.get("player") as CharacterBody3D
	level = main.get("level") as Node3D
	# run before the runner so this tick's input is the input it moves with.
	process_physics_priority = -100
	_initial_respawns = int(main.get("respawn_count"))
	_quit_at_end = OS.get_cmdline_user_args().has("--bot-quit")
	var directory := ""
	var explicit_aim := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			directory = arg.trim_prefix("--evidence-dir=").simplify_path()
		elif arg == "--bot-quit":
			_quit_at_end = true
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--aim-deg=") or arg.begins_with("--jump-delay="):
			var value := arg.get_slice("=", 1)
			if not value.is_valid_float() or not is_finite(float(value)) or (arg.begins_with("--aim-deg=") and float(value) < 0):
				_complete(false, "perturbation requires a finite value; aim range must be nonnegative")
				return
			if arg.begins_with("--aim-deg="):
				explicit_aim = true
				_aim_range = deg_to_rad(float(value))
			else:
				_jump_delay = float(value)
	if player == null or level == null or level.get("surf_sections").size() < 5:
		_complete(false, "main must expose player, level and the five surf sections")
		return
	if not explicit_aim and _seed != 0:
		_aim_range = .012
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	_aim_bias = rng.randf_range(-_aim_range, _aim_range)
	if not directory.is_empty():
		if not preload("res://scripts/spillway_driver.gd").evidence_path_allowed(directory) or DirAccess.make_dir_recursive_absolute(directory) != OK:
			_complete(false, "evidence must be an absolute writable directory outside Git")
			return
		_trace_path = directory.path_join("route-fast-seed-%d-%d-%d.jsonl" % [_seed, OS.get_process_id(), Time.get_ticks_usec()])
		_trace = FileAccess.open(_trace_path, FileAccess.WRITE)
		if _trace == null:
			_complete(false, "cannot create input trace")
			return
	_write({"event":"start", "route":"fast", "seed":_seed, "fixture":false,
		"input":"action and mouse events only; state-aware controller, not a human recording",
		"aim_bias_deg":rad_to_deg(_aim_bias), "jump_delay_s":_jump_delay,
		"timing_scope":"initial crest takeoff; held landing hops stay automatic",
		"sample_interval_s":TICK, "trace_path":_trace_path})

func section_named(label: String) -> Dictionary:
	for section: Dictionary in level.get("surf_sections"):
		if section.name == label:
			return section
	return {}

func _physics_process(_delta: float) -> void:
	if done:
		_finish_wait += _delta
		if _quit_at_end and _finish_wait >= .25:
			main.call("request_quit", 0 if succeeded else 1)
		return
	if main == null:
		return
	tick += 1
	var stage := int(main.get("checkpoint_index"))
	if stage != _stages.back():
		_stages.append(stage)
		_write(_sample("checkpoint"))
	var now := float(player.call("get_speed"))
	_record(_last_speed if _last_speed >= 0.0 else now)
	_last_speed = now
	_drive()
	if bool(main.get("finished")):
		var ordered: bool = str(main.get("finish_kind")) == "clean" and main.get("splits").size() == 3
		_complete(ordered, "" if ordered else "finished without ordered splits: %s" % main.get("finish_kind"))
	elif int(main.get("respawn_count")) > _initial_respawns:
		_complete(false, "respawned at %s in phase %s" % [player.global_position, phase])
	elif tick * TICK > TIME_LIMIT:
		_complete(false, "time limit in phase %s at %s" % [phase, player.global_position])

func _drive() -> void:
	var stage := int(main.get("checkpoint_index"))
	match phase:
		"crest_runup":
			# p / run off the crest lip and drop onto the dam face.
			_keys(["move_forward"])
			if player.global_position.z < .15 - float(player.call("get_speed")) * _jump_delay:
				_keys(["move_forward", "jump"])
				phase = "crest_takeoff"
		"crest_takeoff":
			# p / a single jump off the lip; nothing is held while falling onto the face.
			_keys([])
			_begin_drop("CrestSurf")
		"drop":
			# keys stay as the takeoff left them: a held jump keeps hopping any deck on the way.
			_catch_surf()
		"surf":
			_ride()
		"crest_bhop":
			var at: Vector3 = CREST_TO_YARD[_waypoint]
			if not _hold_for_edge(-49.0, -56.0, 4.0):
				_strafe_toward(at, 2.4, ["jump"])
			elif player.is_grounded():
				# p / slide (2 m/s² on the flat, against 8 for running overspeed) to the lip.
				_keys(["crouch"])
				_face(_yaw_toward(at - player.global_position))
			else:
				_strafe_toward(at, 2.4, ["crouch"])
			if _flat_distance(at) < 2.0:
				_waypoint = mini(_waypoint + 1, CREST_TO_YARD.size() - 1)
			if stage >= 1:
				_note("STAGE 1")
				phase = "yard_approach"
		"yard_approach":
			_strafe_toward(Vector3(10, 4, -72), 2.4, ["jump"])
			if player.global_position.z < -71.0:
				phase = "yard_turn"
		"yard_turn":
			# p / a left strafe turn on the entry deck lines the hop up with the bank tangent.
			_strafe(-1, 2.4, ["jump"])
			if _velocity_yaw() >= 1.25:
				_keys(["jump"])
				_begin_drop("YardSurf")
		"roof_uturn":
			# p / the bank leaves the runner heading away from the finish over the roof;
			# a held right strafe u-turn (about 150 degrees) lines up with the run-up.
			_strafe(1, 3.6, ["jump"])
			if absf(angle_difference(_velocity_yaw(), _runup_yaw())) < .12:
				phase = "outflow_seek"
		"outflow_seek":
			_strafe_toward(_outflow_entry(), 4.0, ["jump"])
			for label: String in ["OutflowLead", "OutflowSweep"]:
				if phase == "outflow_seek" and _on_section(label):
					_enter(section_named(label))
		"finish_bhop":
			# p / round the hall's front corner, then straight along the front to the wheel.
			var corner := Vector3(12.5, -3, -67.2)
			var aim := corner if player.global_position.x < corner.x - 1.5 else FINISH_AIM
			_strafe_toward(aim, 3.0, ["jump"])

## the terrace gap toward the yard is cleared by a hop taken late enough; a hop chain lands
## wherever its phase falls. like a player, release jump when the next takeoff would land in
## the gap, slide on along the deck, and jump out of the slide at the right spot.
func _hold_for_edge(edge_z: float, far_z: float, floor_y: float) -> bool:
	var p := player.global_position
	var speed := -player.velocity.z
	if p.z < edge_z or p.z > edge_z + 14.0 or speed < 1.0:
		return false
	var constants := (player.get_script() as GDScript).get_script_constant_map()
	var gravity := float(constants.get("GRAVITY", 20.0))
	var reach := speed * 2.0 * float(constants.get("JUMP_SPEED", 7.2)) / gravity
	var takeoff := p.z
	if not player.is_grounded():
		var vy := player.velocity.y
		takeoff += player.velocity.z * (vy + sqrt(vy * vy + 2.0 * gravity * maxf(p.y - floor_y, 0.0))) / gravity
	if takeoff < edge_z + .5:
		return false
	# a takeoff here is bad only when its landing falls short of the far deck, yet past the lip.
	var landing := takeoff - reach
	return landing > far_z - .8 and landing < edge_z + .3

func _begin_drop(label: String) -> void:
	_section = section_named(label)
	phase = "drop"

func _catch_surf() -> void:
	if _on_section(str(_section.name)):
		_enter(_section)

func _enter(section: Dictionary) -> void:
	_section = section
	_entry_y = player.global_position.y
	_entry_theta = GEOMETRY.angle_at(section, player.global_position)
	surf_report[section.name] = {"entry_speed": float(player.call("get_speed")), "entry_y": _entry_y,
		"entry_theta_deg": rad_to_deg(_entry_theta), "contact_ticks": 0, "ride_ticks": 0}
	_note("ENTRY %s pos=%s speed=%.2f theta=%.1f" % [section.name, _v(player.global_position), player.call("get_speed"), rad_to_deg(_entry_theta)])
	phase = "surf"

func _ride() -> void:
	var section := _section
	var theta := GEOMETRY.angle_at(section, player.global_position)
	var report: Dictionary = surf_report[section.name]
	report.ride_ticks += 1
	if player.get("surf_normal") != Vector3.ZERO and _on_section(str(section.name)):
		report.contact_ticks += 1
	if theta > section.arc + .01:
		report["exit_speed"] = float(player.call("get_speed"))
		report["exit_y"] = player.global_position.y
		_note("EXIT %s pos=%s speed=%.2f contacts=%d" % [section.name, _v(player.global_position), player.call("get_speed"), report.contact_ticks])
		match str(section.name):
			"CrestSurf":
				_waypoint = 0
				phase = "crest_bhop"
			"YardSurf":
				phase = "roof_uturn"
			"OutflowLead", "OutflowSweep":
				# the outflow pieces share their edges; the ride simply continues.
				_enter(section_named("OutflowSweep" if section.name == "OutflowLead" else "OutflowSurf"))
				_ride_tick(_section, GEOMETRY.angle_at(_section, player.global_position))
				return
			_:
				phase = "finish_bhop"
		# the next phase acts on this same tick, so leaving a bank costs no idle input.
		_drive()
		return
	_ride_tick(section, theta)

func _ride_tick(section: Dictionary, theta: float) -> void:
	var target_y: float
	match str(section.name):
		# p / proven crest and yard heights: descend gently to the exit deck height.
		"CrestSurf":
			target_y = lerpf(_entry_y, 5.2, clampf((theta - _entry_theta) / maxf(section.arc - _entry_theta, .01), 0, 1))
		"YardSurf":
			target_y = lerpf(_entry_y, 4.0, clampf((theta - _entry_theta) / maxf(section.arc - _entry_theta, .01), 0, 1))
		_:
			# p / outflow keeps a 1.8 m lane under its coping, so the line tracks the profile.
			target_y = _top_y(section, theta) - 1.8 * tan(deg_to_rad(60.0))
	var side := int(section.get("side", 1.0))
	if player.get("surf_normal") == Vector3.ZERO and int(section.bend) == side and player.global_position.y > target_y:
		# p / airborne over a curve that bends toward its face: strafe-turn with the curve
		# (A with the mouse left here) and let gravity put the runner back on the face.
		_strafe(side, 1.5 * float(player.call("get_speed")) / section.radius)
		return
	_surf(side, GEOMETRY.tangent_yaw(section, theta), target_y)

static func _top_y(section: Dictionary, theta: float) -> float:
	var t := clampf(theta / section.arc, 0, 1)
	return section.origin.y + lerpf(section.height, section.height_end, t) + lerpf(section.drop_start, section.drop_end, t)

func _runup_yaw() -> float:
	var course := preload("res://scripts/spillway_course.gd")
	return _yaw_toward(course.OUTFLOW_RUNUP_END - course.OUTFLOW_RUNUP_START)

func _outflow_entry() -> Vector3:
	# p / steer into the banked wall: a point 1.2 m under the coping, 14 degrees into the bank.
	var sweep := section_named("OutflowSweep")
	return GEOMETRY.point(sweep, deg_to_rad(6.0), sweep.radius - 0.7, sweep.height - 1.2)

func _on_section(label: String) -> bool:
	for i: int in player.get_slide_collision_count():
		var contact := player.get_slide_collision(i)
		for j: int in contact.get_collision_count():
			var body := contact.get_collider(j) as Node
			if body != null and str(body.get_meta("surf_section", "")) == label:
				return true
	return false

func _contact_sections() -> Array[String]:
	var labels: Array[String] = []
	for i: int in player.get_slide_collision_count():
		var contact := player.get_slide_collision(i)
		for j: int in contact.get_collision_count():
			var body := contact.get_collider(j) as Node
			var label := str(body.get_meta("surf_section", "")) if body != null else ""
			if not label.is_empty() and not labels.has(label):
				labels.append(label)
	return labels

# --- input -------------------------------------------------------------------

func _keys(names: Array) -> void:
	for action_name: String in ACTIONS:
		var want := names.has(action_name)
		if want != bool(_held.get(action_name, false)):
			var event := InputEventAction.new()
			event.action = action_name
			event.pressed = want
			event.strength = 1.0 if want else 0.0
			Input.parse_input_event(event)
			_held[action_name] = want
			_write({"event":"input", "time":tick * TICK, "action":action_name, "pressed":want})
	Input.flush_buffered_events()

func _face(target_yaw: float) -> void:
	var delta := angle_difference(float(player.get("yaw")), target_yaw + _aim_bias)
	if is_zero_approx(delta):
		return
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-delta / float(player.get("mouse_sensitivity")), 0)
	event.screen_relative = event.relative
	_write({"event":"mouse", "time":tick * TICK, "screen_relative":[event.screen_relative.x,event.screen_relative.y]})
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _velocity_yaw() -> float:
	return atan2(-player.velocity.x, -player.velocity.z)

static func _yaw_toward(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)

func _flat_distance(at: Vector3) -> float:
	return Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()

func _wish_cap() -> float:
	return float((player.get_script() as GDScript).get_script_constant_map().get("AIR_WISH_CAP", 0.75))

## side +1 holds D and curves right; the view lags the velocity just enough to turn at
## turn_rate rad/s, so the remaining wish adds speed.
func _strafe(side: int, turn_rate: float, extra: Array = []) -> void:
	var names := extra.duplicate()
	names.append("move_right" if side > 0 else "move_left")
	_keys(names)
	var speed := float(player.call("get_speed"))
	var lag := 0.0
	if speed > .1:
		lag = asin(clampf((_wish_cap() - turn_rate * speed * TICK) / speed, 0.0, 1.0))
	_face(_velocity_yaw() + side * lag)

func _strafe_toward(target: Vector3, turn_rate: float, extra: Array = []) -> void:
	var error := angle_difference(_velocity_yaw(), _yaw_toward(target - player.global_position))
	var side := -1 if error > 0.0 else 1
	if absf(error) < .06:
		# inside the dead band a slow zigzag keeps gaining instead of holding W.
		side = 1 if int(tick / 30.0) % 2 == 0 else -1
	_strafe(side, turn_rate, extra)

## hold the strafe key into the face and look along it, opened away from the face by the
## neutral angle plus a height correction; more opening sinks and trades height for speed.
func _surf(side: int, along_yaw: float, target_y: float) -> void:
	var along := Vector3(-sin(along_yaw), 0.0, -cos(along_yaw))
	var forward_speed := maxf(player.velocity.dot(along), 0.5)
	var neutral := asin(clampf(_wish_cap() / forward_speed, 0.0, 1.0))
	var lead := clampf(neutral + 0.08 * (player.global_position.y - target_y) + 0.03 * player.velocity.y, 0.0, 0.6)
	_keys(["move_right" if side > 0 else "move_left"])
	_face(along_yaw + side * lead)

# --- evidence ----------------------------------------------------------------

func _note(text: String) -> void:
	var line := "t=%.3f %s" % [tick * TICK, text]
	events.append(line)
	print("surf driver: ", line)

func _record(before: float) -> void:
	var speed := float(player.call("get_speed"))
	if before - speed > 1.0:
		var hits: Array = []
		for i: int in player.get_slide_collision_count():
			var contact := player.get_slide_collision(i)
			for j: int in contact.get_collision_count():
				var name := str((contact.get_collider(j) as Node).name)
				if not hits.has(name):
					hits.append(name)
		speed_drops.append({"tick": tick, "phase": phase, "position": player.global_position, "from": before, "to": speed, "hits": hits})
		_note("DROP phase=%s pos=%s %.2f->%.2f hits=%s" % [phase, _v(player.global_position), before, speed, hits])
	_peak_speed = maxf(_peak_speed, speed)
	_write(_sample("sample"))

func _sample(kind: String) -> Dictionary:
	var p := player.global_position
	var v := player.velocity
	return {"event":kind, "route":"fast", "seed":_seed, "time":tick * TICK, "tick":tick, "phase":phase,
		"held":_held.duplicate(), "yaw":float(player.get("yaw")), "pitch":float(player.get("pitch")),
		"position":[p.x,p.y,p.z], "velocity":[v.x,v.y,v.z], "speed":float(player.call("get_speed")),
		"grounded":player.is_grounded(), "surf":player.get("surf_normal") != Vector3.ZERO,
		"contact_sections":_contact_sections(),
		"mode":str(player.get("mode")), "crouched":bool(player.get("crouched")), "water":bool(player.get("in_water")),
		"jumps":int(player.get("jump_count")), "checkpoint":int(main.get("checkpoint_index")),
		"ordered_checkpoints":_stages.duplicate(), "respawns":int(main.get("respawn_count")),
		"clean_eligible":bool(main.get("clean_eligible")), "finish_kind":str(main.get("finish_kind")),
		"elapsed":float(main.get("elapsed")), "max_speed_mps":_peak_speed}

func _write(row: Dictionary) -> void:
	if _trace != null:
		_trace.store_line(JSON.stringify(row))
		if row.get("event") != "sample":
			_trace.flush()

static func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]

func _complete(success: bool, reason: String) -> void:
	if done:
		return
	done = true
	succeeded = success
	failure_reason = reason
	_keys([])
	var splits: Array = main.get("splits") if main != null else []
	_note("%s splits=%s jumps=%s reason=%s" % ["SUCCESS" if success else "FAILURE", splits,
		player.get("jump_count") if player != null else -1, reason])
	if player != null and main != null:
		var result := _sample("result")
		result.merge({"success":success, "successes":1 if success else 0, "attempts":1,
			"reason":reason, "trace_path":_trace_path, "surf_report":surf_report, "speed_drops":speed_drops}, true)
		_write(result)
	if _trace != null:
		_trace.close()
		_trace = null

func _exit_tree() -> void:
	_keys([])

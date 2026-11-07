extends SceneTree
## p / r13 controller lab probe: the retained r12 motor and the flow lab motor under the same
## key and mouse input. each episode builds a fresh runner and places it once with reset_to;
## after that only InputEventKey and InputEventMouseMotion reach it. closed-loop steps read
## exact world position to pick when to press or where to aim; they are privileged fixtures,
## not screenshot discovery or human recordings.
## nothing writes a pose or velocity after placement. traces stay outside git.
## godot --headless --fixed-fps 120 --path . --script res://tests/momentum_flow_probe.gd [-- --out=DIR]

const MAIN := preload("res://scripts/spillway_main.gd")
const MOTORS := {"r12": preload("res://scripts/spillway_player.gd"), "flow": preload("res://scripts/momentum_flow_player.gd")}
const DEFAULT_OUT := "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/controller-lab"
const TICK: float = 1.0 / 120.0
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "jump": KEY_SPACE, "crouch": KEY_CTRL}
# p / an imperfect human rhythm: press intervals jitter around the ~0.72 s hop airtime.
const HOP_INTERVALS: Array[float] = [0.0, 0.80, 0.70, 0.86, 0.74, 0.92, 0.78, 0.83, 0.76, 0.88]

var out_dir: String = DEFAULT_OUT
var world: Node3D
var level: Node3D
var player: CharacterBody3D
var held: Dictionary = {}
var samples: Array[Dictionary] = []
var marks: Dictionary = {}
var tick: int = 0
var summary: Dictionary = {}
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	_run.call_deferred()

func _run() -> void:
	MAIN.bind_inputs()
	DirAccess.make_dir_recursive_absolute(out_dir)
	summary["engine"] = {"godot": Engine.get_version_info().string, "physics_3d": str(ProjectSettings.get_setting("physics/3d/physics_engine")), "ticks": Engine.physics_ticks_per_second}
	world = Node3D.new()
	root.add_child(world)
	_build_fixtures()
	await physics_frame
	for motor: String in MOTORS:
		await _episode("e1_start_release_reverse", motor, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 20)), _e1)
		await _episode("e2a_downhill_run_turn", motor, Transform3D(Basis.IDENTITY, Vector3(200, _ramp_top + 0.02, 6)), _e2.bind(false, "turn"))
		await _episode("e2b_downhill_slide_turn", motor, Transform3D(Basis.IDENTITY, Vector3(200, _ramp_top + 0.02, 6)), _e2.bind(true, "turn"))
		await _episode("e2c_downhill_slide_brake", motor, Transform3D(Basis.IDENTITY, Vector3(200, _ramp_top + 0.02, 6)), _e2.bind(true, "brake"))
		await _episode("e3a_casual_w_hops", motor, Transform3D(Basis.IDENTITY, Vector3(-200, 0.02, 20)), _e3.bind("w"))
		await _episode("e3b_offbeat_strafe_hops", motor, Transform3D(Basis.IDENTITY, Vector3(-200, 0.02, 20)), _e3.bind("strafe"))
		await _episode("e3c_held_space_hops", motor, Transform3D(Basis.IDENTITY, Vector3(-200, 0.02, 20)), _e3.bind("held"))
		await _episode("e3d_overspeed_casual_hops", motor, Transform3D(Basis.IDENTITY, Vector3(200, _ramp_top + 0.02, 6)), _e3d)
		await _episode("e6a_air_w_mouse_turn", motor, Transform3D(Basis.IDENTITY, Vector3(-230, 0.02, 20)), _e6.bind(["w"]))
		await _episode("e6b_air_strafe_mouse_turn", motor, Transform3D(Basis.IDENTITY, Vector3(-230, 0.02, 20)), _e6.bind(["a"]))
		await _episode("e4a_kicker_jump_downslope", motor, Transform3D(Basis.IDENTITY, Vector3(400, 0.02, 6)), _e4.bind("jump"))
		await _episode("e4b_kicker_run_off", motor, Transform3D(Basis.IDENTITY, Vector3(400, 0.02, 6)), _e4.bind("run"))
		await _episode("e4c_kicker_jump_slide_landing", motor, Transform3D(Basis.IDENTITY, Vector3(400, 0.02, 6)), _e4.bind("slide"))
	world.queue_free()
	await physics_frame
	# the real course, without main: water regions are applied the way main applies them.
	level = preload("res://scripts/spillway_level.gd").new()
	root.add_child(level)
	level.call("build")
	await physics_frame
	for motor: String in MOTORS:
		await _episode("e5_course_dry_chute", motor, level.get("spawn"), _e5)
	_hypothesis_checks()
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	file.close()
	_print_table()
	print("probe: %d checks, %d failed; traces in %s" % [checks, failures, out_dir])
	quit(1 if failures > 0 else 0)

# --- fixtures -----------------------------------------------------------------------------

var _ramp_top: float = 0.0

func _box(center: Vector3, size: Vector3, tilt: float = 0.0) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.transform = Transform3D(Basis(Vector3.RIGHT, tilt), center)
	world.add_child(body)

## a slab whose top face runs from a to b (b lower or higher along -z), width w.
func _ramp(a: Vector3, b: Vector3, width: float) -> void:
	var along := b - a
	var tilt := atan2(along.y, -along.z)
	var normal := Basis(Vector3.RIGHT, tilt) * Vector3.UP
	_box((a + b) * 0.5 - normal * 0.5, Vector3(width, 1.0, along.length()), tilt)

func _build_fixtures() -> void:
	_box(Vector3(0, -40.5, -100), Vector3(1400, 1, 800))
	# e1 flat pad.
	_box(Vector3(0, -0.5, 0), Vector3(60, 1, 60))
	# e2: a 16 degree, 50 m ramp from a short top deck down onto a wide flat field.
	var length := 50.0
	var angle := deg_to_rad(16.0)
	_ramp_top = length * sin(angle)
	_box(Vector3(200, _ramp_top - 0.5, 6), Vector3(14, 1, 12))
	_ramp(Vector3(200, _ramp_top, 0), Vector3(200, 0, -length * cos(angle)), 14)
	_box(Vector3(200, -0.5, -48 - 80), Vector3(200, 1, 162))
	# e3 long flat hop field.
	_box(Vector3(-200, -0.5, -100), Vector3(120, 1, 260))
	# e4: flat approach, a 20 degree kicker ending in an edge, a gap, a 22 degree landing
	# slope and a flat runout below it.
	_box(Vector3(400, -0.5, -5), Vector3(40, 1, 30))
	var kick := deg_to_rad(20.0)
	_ramp(Vector3(400, 0, -20), Vector3(400, 6.0 * sin(kick), -20 - 6.0 * cos(kick)), 8)
	var land := deg_to_rad(22.0)
	var land_end := Vector3(400, 1.0 - 14.0 * sin(land), -31 - 14.0 * cos(land))
	_ramp(Vector3(400, 1.0, -31), land_end, 16)
	_box(Vector3(400, land_end.y - 0.5, land_end.z - 49.5), Vector3(80, 1, 100))
	summary["fixtures"] = {"e2_ramp": "16 deg, 50 m, top y %.2f" % _ramp_top, "e4_kicker": "20 deg, 6 m, lip y %.2f z %.2f" % [6.0 * sin(kick), -20 - 6.0 * cos(kick)], "e4_landing": "22 deg, 14 m from z -31 y 1.0 to y %.2f" % land_end.y}

# --- input --------------------------------------------------------------------------------

func _key(name: String, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEYS[name]
	event.keycode = KEYS[name]
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed:
		held[name] = true
	else:
		held.erase(name)

func hold(names: Array) -> void:
	for name: String in KEYS:
		if names.has(name) and not held.has(name):
			_key(name, true)
		elif not names.has(name) and held.has(name):
			_key(name, false)

## turn the view by mouse motion; positive radians turn left, like the motors' yaw.
func mouse(radians: float) -> void:
	if is_zero_approx(radians):
		return
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-radians / float(player.get("mouse_sensitivity")), 0.0)
	event.screen_relative = event.relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

## one physics tick with an optional mouse turn sent before it.
func step(turn: float = 0.0) -> void:
	mouse(turn)
	await physics_frame
	_record()

func steps(count: int, turn_per_tick: float = 0.0) -> void:
	for i: int in count:
		await step(turn_per_tick)

## aim the view at a world point at a human-ish mouse rate (rad/s), reading position only.
func aim_turn(target: Vector3, rate: float = 3.0) -> float:
	var to := target - player.global_position
	var want := atan2(-to.x, -to.z)
	return clampf(angle_difference(float(player.get("yaw")), want), -rate * TICK, rate * TICK)

func yaw_turn(want: float, rate: float = 3.0) -> float:
	return clampf(angle_difference(float(player.get("yaw")), want), -rate * TICK, rate * TICK)

func mark(name: String) -> void:
	marks[name] = samples.size()

# --- episodes -----------------------------------------------------------------------------

func _episode(name: String, motor: String, pose: Transform3D, body: Callable) -> void:
	hold([])
	samples.clear()
	marks.clear()
	tick = 0
	player = MOTORS[motor].new()
	player.name = "Runner"
	(level if name.begins_with("e5") else world).add_child(player)
	player.call("reset_to", pose)
	# the only placement; physics owns the runner from here.
	await steps(30)
	mark("start")
	await body.call()
	hold([])
	await steps(2)
	mark("end")
	var trace := FileAccess.open(out_dir.path_join("%s.%s.jsonl" % [name, motor]), FileAccess.WRITE)
	for entry: Dictionary in samples:
		trace.store_line(JSON.stringify(entry))
	trace.close()
	var metrics := _metrics(name, motor)
	metrics["stall_ticks"] = _stalls()
	metrics["jumps"] = int(player.get("jump_count"))
	if motor == "flow":
		metrics["carve_gain"] = snappedf(float(player.get("carve_gain_total")), 0.01)
		metrics["launches"] = int(player.get("launch_count"))
	if not summary.has(name):
		summary[name] = {}
	summary[name][motor] = metrics
	player.queue_free()
	await physics_frame

func _e1() -> void:
	mark("accel")
	hold(["w"])
	await steps(90)
	mark("release")
	hold([])
	await steps(90)
	mark("restart")
	hold(["w"])
	await steps(90)
	mark("reverse")
	hold(["s"])
	await steps(120)
	hold([])
	await steps(60)
	mark("strafe_a")
	hold(["a"])
	await steps(72)
	mark("strafe_d")
	hold(["d"])
	await steps(72)
	hold([])
	await steps(30)

func _e2(crouch: bool, finish: String) -> void:
	hold(["w"])
	for i: int in 900:
		if player.global_position.z < 0.0 and crouch:
			hold(["w", "crouch"])
		if player.global_position.z < -50.0:
			break
		await step()
	mark("flat")
	if finish == "turn":
		hold(["w"])
		await steps(24)
		mark("turn")
		# a 90 degree right turn by mouse over 0.3 s, holding w.
		await steps(36, -PI * 0.5 / 36.0)
		await steps(108)
		mark("turn_end")
	else:
		mark("brake")
		hold(["s"])
		await steps(180)
		mark("brake_end")

func _e3(style: String) -> void:
	hold(["w"])
	await steps(96)
	await _hops(style)

func _e3d() -> void:
	# earn speed with a slide down the e2 ramp, stand up on the flat, then hop casually.
	hold(["w"])
	for i: int in 900:
		if player.global_position.z < 0.0:
			hold(["w", "crouch"])
		if player.global_position.z < -50.0:
			break
		await step()
	hold(["w"])
	await steps(12)
	await _hops("w")

func _hops(style: String) -> void:
	mark("hops")
	var start_tick := samples.size()
	var press_ticks: Array[int] = []
	var cumulative := 0.0
	for interval: float in HOP_INTERVALS:
		cumulative += interval
		press_ticks.append(start_tick + roundi(cumulative / TICK))
	var total := press_ticks[-1] + 96 - start_tick
	var segment := -1
	for i: int in total:
		var now := samples.size()
		var t := float(now - start_tick) * TICK
		if style == "held":
			hold(["w", "jump"])
			await step(0.6 * cos(TAU * t / 1.3) * TICK)
			continue
		var pressing := false
		for p: int in press_ticks:
			if now >= p and now < p + 7:
				pressing = true
			if now == p:
				segment += 1
		var names: Array = []
		var turn := 0.0
		if style == "w":
			names = ["w"]
			turn = 0.6 * cos(TAU * t / 1.3) * TICK
		else:
			# alternate a with a left mouse sweep and d with a right one, one per press, at
			# a fixed 1.8 rad/s that is not matched to speed; w only for the first takeoff.
			if segment <= 0 and now < press_ticks[0] + 6:
				names = ["w"]
			else:
				var left := segment % 2 == 0
				names = ["a" if left else "d"]
				turn = (1.8 if left else -1.8) * TICK
		if pressing:
			names.append("jump")
		hold(names)
		await step(turn)
	mark("hops_end")

func _e4(style: String) -> void:
	hold(["w"])
	var jumped := false
	for i: int in 1200:
		var z := player.global_position.z
		if style != "run" and not jumped and z < -24.8:
			hold(["w", "jump"])
			jumped = true
			mark("press")
		elif jumped and held.has("jump") and samples.size() - int(marks["press"]) > 8:
			hold(["w"])
		if style == "slide" and jumped and player.velocity.y < 0.0 and not held.has("crouch"):
			hold(["w", "crouch"])
		if z < -70.0:
			break
		await step()
	mark("runout")
	await steps(30)

func _e6(air_keys: Array) -> void:
	# run, jump, then turn the view 60 degrees left over 0.25 s in the air with these keys.
	hold(["w"])
	await steps(96)
	mark("takeoff")
	hold(["w", "jump"])
	await steps(6)
	hold(air_keys)
	await steps(30, deg_to_rad(60.0) / 30.0)
	for i: int in 120:
		if bool(player.call("is_grounded")):
			break
		await step()
	mark("landed")
	hold(["w"])
	await steps(30)

func _e5() -> void:
	# aim at the dry chute mouth, then down it, slide, jump at the launch, aim the terrace.
	hold(["w"])
	for i: int in 240:
		if player.global_position.z < 0.5:
			break
		await step(aim_turn(Vector3(-3.5, 12, -1.0)))
	mark("chute")
	hold(["w", "crouch"])
	for i: int in 600:
		if player.global_position.z < -24.3 or player.global_position.y < 3.0:
			break
		await step(yaw_turn(0.0))
	mark("launch")
	hold(["w", "jump"])
	await steps(8)
	hold(["w"])
	for i: int in 240:
		await step(aim_turn(Vector3(-3.0, 4, -46.0), 2.0))
	mark("after")

# --- measurement --------------------------------------------------------------------------

func _record() -> void:
	tick += 1
	var p := player.global_position
	var v := player.velocity
	var real: Vector3 = player.get_real_velocity()
	var previous: Dictionary = samples[-1] if not samples.is_empty() else {}
	var disp := 0.0
	if not previous.is_empty():
		var q: Array = previous["p"]
		disp = Vector2(p.x - float(q[0]), p.z - float(q[2])).length() / TICK
	var names: Array = held.keys()
	names.sort()
	samples.append({"t": tick, "keys": names, "yaw": snappedf(float(player.get("yaw")), 0.0001),
		"p": [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)],
		"v": [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)],
		"real_v": [snappedf(real.x, 0.001), snappedf(real.y, 0.001), snappedf(real.z, 0.001)],
		"speed": snappedf(Vector2(v.x, v.z).length(), 0.001), "disp_speed": snappedf(disp, 0.001),
		"mode": str(player.get("mode")), "grounded": bool(player.call("is_grounded")), "floor": player.is_on_floor(),
		"water": bool(player.get("in_water")), "jumps": int(player.get("jump_count")), "body": _floor_body()})
	if level != null and is_instance_valid(level):
		var water := false
		for region: Dictionary in level.get("water_regions"):
			if (region["bounds"] as AABB).has_point(p):
				water = true
		player.set("in_water", water)

func _floor_body() -> String:
	for i: int in player.get_slide_collision_count():
		var contact := player.get_slide_collision(i)
		if contact.get_normal().y > 0.7 and contact.get_collider() is Node:
			return str((contact.get_collider() as Node).name)
	return ""

func _stalls() -> int:
	# authoritative velocity that the body does not actually travel: kept speed hiding a stall.
	var count := 0
	for i: int in range(int(marks.get("start", 1)) + 1, samples.size()):
		var s: Dictionary = samples[i]
		if float(s["speed"]) > 2.0 and float(s["disp_speed"]) < 0.5 * float(s["speed"]):
			count += 1
	return count

func _speed(i: int) -> float:
	return float(samples[clampi(i, 0, samples.size() - 1)]["speed"])

func _pos(i: int) -> Vector3:
	var p: Array = samples[clampi(i, 0, samples.size() - 1)]["p"]
	return Vector3(p[0], p[1], p[2])

func _vel(i: int) -> Vector3:
	var v: Array = samples[clampi(i, 0, samples.size() - 1)]["v"]
	return Vector3(v[0], v[1], v[2])

func _first(from: int, to: int, condition: Callable) -> int:
	for i: int in range(from, mini(to, samples.size())):
		if condition.call(samples[i]):
			return i - from
	return -1

func _ms(ticks: int) -> Variant:
	return -1 if ticks < 0 else roundi(ticks * TICK * 1000.0)

func _path(from: int, to: int) -> float:
	var total := 0.0
	for i: int in range(from + 1, mini(to, samples.size())):
		var a := _pos(i - 1)
		var b := _pos(i)
		total += Vector2(b.x - a.x, b.z - a.z).length()
	return total

func _metrics(name: String, motor: String) -> Dictionary:
	var run: float = 9.0 if motor == "flow" else 8.5
	var m: Dictionary = {}
	if name.begins_with("e1"):
		var a: int = marks["accel"]
		m["accel_ms_to_90pct_run"] = _ms(_first(a, marks["release"], func(s: Dictionary) -> bool: return float(s["speed"]) >= 0.9 * run))
		m["accel_dist_075s_m"] = snappedf(_pos(marks["release"]).distance_to(_pos(a)), 0.01)
		var r: int = marks["release"]
		m["release_speed"] = snappedf(_speed(r), 0.01)
		m["release_ms_to_stop"] = _ms(_first(r, marks["restart"], func(s: Dictionary) -> bool: return float(s["speed"]) < 0.3))
		m["release_slide_m"] = snappedf(_pos(marks["restart"]).distance_to(_pos(r)), 0.01)
		var v: int = marks["reverse"]
		m["reverse_ms_to_zero_forward"] = _ms(_first(v, marks["strafe_a"], func(s: Dictionary) -> bool: return -float(s["v"][2]) <= 0.0))
		m["reverse_ms_to_90pct_back"] = _ms(_first(v, marks["strafe_a"], func(s: Dictionary) -> bool: return float(s["v"][2]) >= 0.9 * run))
		m["reverse_overshoot_m"] = snappedf(_pos(v).z - _minz(v, marks["strafe_a"]), 0.01)
		var d: int = marks["strafe_d"]
		m["strafe_switch_ms_to_flip"] = _ms(_first(d, d + 72, func(s: Dictionary) -> bool: return float(s["v"][0]) >= 0.0))
		m["strafe_switch_ms_to_90pct"] = _ms(_first(d, d + 72, func(s: Dictionary) -> bool: return float(s["v"][0]) >= 0.9 * run))
	elif name.begins_with("e2"):
		var f: int = marks["flat"]
		m["ramp_s"] = snappedf((f - int(marks["start"])) * TICK, 0.01)
		m["speed_at_flat"] = snappedf(_speed(f), 0.01)
		var peak := 0.0
		for i: int in range(marks["start"], f):
			peak = maxf(peak, _speed(i))
		m["peak_on_ramp"] = snappedf(peak, 0.01)
		if marks.has("turn"):
			var t: int = marks["turn"]
			var e: int = marks["turn_end"]
			m["speed_turn_in"] = snappedf(_speed(t), 0.01)
			var low := INF
			for i: int in range(t, e):
				low = minf(low, _speed(i))
			m["speed_turn_min"] = snappedf(low, 0.01)
			m["speed_turn_out"] = snappedf(_speed(e), 0.01)
			# heading of actual travel, from displacement, 90 degrees is a full right turn.
			var go := _pos(e) - _pos(e - 12)
			m["travel_heading_deg_after"] = snappedf(rad_to_deg(atan2(go.x, -go.z)), 0.1)
			m["ms_travel_heading_80deg"] = _ms(_first(t + 1, e, func(s: Dictionary) -> bool: return float(s["v"][0]) > 0.0 and rad_to_deg(atan2(float(s["v"][0]), -float(s["v"][2]))) >= 80.0))
			m["turn_window_path_m"] = snappedf(_path(t, e), 0.01)
			m["turn_forward_overshoot_m"] = snappedf(_pos(t).z - _minz(t, e), 0.01)
		else:
			var b: int = marks["brake"]
			m["brake_speed_in"] = snappedf(_speed(b), 0.01)
			m["brake_ms_to_stop"] = _ms(_first(b, marks["brake_end"], func(s: Dictionary) -> bool: return float(s["speed"]) < 0.3 or float(s["v"][2]) > 0.0))
			m["brake_dist_m"] = snappedf(_pos(b).z - _minz(b, marks["brake_end"]), 0.01)
	elif name.begins_with("e3"):
		var h: int = marks["hops"]
		var e: int = marks["hops_end"]
		var takeoffs: Array[float] = []
		var grounded_between := 0
		var low := INF
		var total := 0.0
		for i: int in range(h, e):
			var s: Dictionary = samples[i]
			if i > h and int(s["jumps"]) > int(samples[i - 1]["jumps"]):
				takeoffs.append(snappedf(_speed(i), 0.01))
			if bool(s["grounded"]):
				grounded_between += 1
			low = minf(low, _speed(i))
			total += _speed(i)
		m["speed_entry"] = snappedf(_speed(h), 0.01)
		m["takeoff_speeds"] = takeoffs
		m["speed_mean"] = snappedf(total / maxf(1.0, e - h), 0.01)
		m["speed_min"] = snappedf(low, 0.01)
		m["speed_final"] = snappedf(_speed(e - 1), 0.01)
		m["grounded_ticks"] = grounded_between
		m["net_displacement_m"] = snappedf(Vector2(_pos(e).x - _pos(h).x, _pos(e).z - _pos(h).z).length(), 0.01)
		m["path_m"] = snappedf(_path(h, e), 0.01)
		m["window_s"] = snappedf((e - h) * TICK, 0.01)
	elif name.begins_with("e6"):
		var t: int = marks["takeoff"]
		var l: int = marks["landed"]
		var v0 := _vel(t + 2)
		var v1 := _vel(l - 1)
		m["speed_takeoff"] = snappedf(Vector2(v0.x, v0.z).length(), 0.01)
		m["speed_before_land"] = snappedf(Vector2(v1.x, v1.z).length(), 0.01)
		# positive is left, as the view turned.
		m["velocity_turn_in_air_deg"] = snappedf(rad_to_deg(Vector2(v0.x, v0.z).angle_to(Vector2(v1.x, v1.z)) * -1.0), 0.1)
		var go := _pos(l) - _pos(l - 12)
		m["travel_heading_at_land_deg"] = snappedf(rad_to_deg(atan2(-go.x, -go.z)), 0.1)
		m["view_yaw_deg"] = snappedf(rad_to_deg(float(samples[l]["yaw"])), 0.1)
		m["lateral_offset_m"] = snappedf(_pos(t).x - _pos(l).x, 0.01)
	elif name.begins_with("e4"):
		var leave := _first(marks["start"], marks["runout"], func(s: Dictionary) -> bool: return not bool(s["grounded"]) and float(s["p"][2]) < -20.0)
		var li := int(marks["start"]) + leave if leave >= 0 else -1
		m["speed_at_leave"] = snappedf(_speed(li), 0.01) if li >= 0 else -1
		m["vy_after_leave"] = snappedf(_vel(li).y, 0.01) if li >= 0 else -1
		var peak := -INF
		var landed := -1
		for i: int in range(maxi(li, 0), int(marks["runout"])):
			peak = maxf(peak, _pos(i).y)
			if landed < 0 and i > li + 2 and bool(samples[i]["grounded"]):
				landed = i
		m["peak_y"] = snappedf(peak, 0.01)
		m["airtime_ms"] = _ms(landed - li) if landed >= 0 else -1
		m["land_z"] = snappedf(_pos(landed).z, 0.01) if landed >= 0 else 0
		m["speed_before_land"] = snappedf(_speed(landed - 1), 0.01) if landed >= 0 else -1
		m["speed_after_land"] = snappedf(_speed(landed), 0.01) if landed >= 0 else -1
		m["speed_land_plus_05s"] = snappedf(_speed(landed + 60), 0.01) if landed >= 0 else -1
		m["speed_runout"] = snappedf(_speed(marks["runout"]), 0.01)
		m["ms_start_to_runout"] = _ms(int(marks["runout"]) - int(marks["start"]))
	elif name.begins_with("e5"):
		var c: int = marks["chute"]
		var l: int = marks["launch"]
		var peak := 0.0
		for i: int in range(c, l):
			peak = maxf(peak, _speed(i))
		m["chute_peak"] = snappedf(peak, 0.01)
		m["speed_at_launch"] = snappedf(_speed(l), 0.01)
		m["launch_pos"] = [snappedf(_pos(l).x, 0.01), snappedf(_pos(l).y, 0.01), snappedf(_pos(l).z, 0.01)]
		var landed := -1
		for i: int in range(l + 3, samples.size()):
			if bool(samples[i]["grounded"]):
				landed = i
				break
		m["land_pos"] = [snappedf(_pos(landed).x, 0.01), snappedf(_pos(landed).y, 0.01), snappedf(_pos(landed).z, 0.01)] if landed >= 0 else []
		var lp := _pos(landed)
		m["landed_past_channel"] = landed >= 0 and lp.y > 3.5 and lp.z < -34.8
		m["water_ticks"] = samples.filter(func(s: Dictionary) -> bool: return bool(s["water"])).size()
		m["ms_spawn_to_launch"] = _ms(l - int(marks["start"]))
		var last := samples.size() - 1
		m["final_pos"] = [snappedf(_pos(last).x, 0.01), snappedf(_pos(last).y, 0.01), snappedf(_pos(last).z, 0.01)]
		m["land_body"] = samples[landed]["body"] if landed >= 0 else ""
	return m

func _minz(from: int, to: int) -> float:
	var low := INF
	for i: int in range(from, mini(to, samples.size())):
		low = minf(low, _pos(i).z)
	return low

# --- hypothesis checks --------------------------------------------------------------------

func check(ok: bool, label: String) -> void:
	checks += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1

func _hypothesis_checks() -> void:
	# these test the flow hypothesis targets and the probe's own integrity, not fun.
	for name: String in summary:
		if not name.is_valid_identifier() or name == "engine" or name == "fixtures":
			continue
		for motor: String in summary[name]:
			check(int(summary[name][motor]["stall_ticks"]) == 0, "%s %s: no kept-speed stall ticks" % [name, motor])
	var e1: Dictionary = summary["e1_start_release_reverse"]["flow"]
	check(int(e1["accel_ms_to_90pct_run"]) >= 0 and int(e1["accel_ms_to_90pct_run"]) <= 350, "flow reaches 90% run within 0.35 s")
	check(int(e1["release_ms_to_stop"]) >= 0 and int(e1["release_ms_to_stop"]) <= 450, "flow stops from run within 0.45 s of release")
	check(int(e1["reverse_ms_to_90pct_back"]) >= 0 and int(e1["reverse_ms_to_90pct_back"]) <= 650, "flow reverses to 90% run within 0.65 s")
	var turn: Dictionary = summary["e2b_downhill_slide_turn"]["flow"]
	check(float(turn["speed_turn_min"]) >= 0.85 * float(turn["speed_turn_in"]), "flow keeps 85% of entry speed through a fast 90 degree mouse turn")
	check(float(turn["travel_heading_deg_after"]) > 70.0, "flow actually travels the new heading after the fast turn")
	var brake: Dictionary = summary["e2c_downhill_slide_brake"]["flow"]
	check(int(brake["brake_ms_to_stop"]) >= 0 and int(brake["brake_ms_to_stop"]) <= 700, "flow S-brake stops a fast run within 0.7 s")
	var casual: Dictionary = summary["e3a_casual_w_hops"]["flow"]
	check(float(casual["speed_min"]) >= 0.9 * 9.0, "flow casual hop chain never drops below 90% run")
	var fast_hops: Dictionary = summary["e3d_overspeed_casual_hops"]["flow"]
	check(float(fast_hops["speed_mean"]) >= 0.75 * float(fast_hops["speed_entry"]), "flow casual hops after a downhill keep 75% of earned speed on average")
	var offbeat: Dictionary = summary["e3b_offbeat_strafe_hops"]["flow"]
	check(float(offbeat["speed_final"]) <= 17.5, "flow strafe carve stays under its cap")
	var kicker: Dictionary = summary["e4a_kicker_jump_downslope"]["flow"]
	check(float(kicker["speed_after_land"]) >= float(kicker["speed_before_land"]), "flow landing on the downslope does not cost speed")

func _print_table() -> void:
	for name: String in summary:
		if not name.is_valid_identifier() or name == "engine" or name == "fixtures":
			continue
		print("== %s" % name)
		var keys: Array = (summary[name]["r12"] as Dictionary).keys()
		for key: String in keys:
			print("  %-28s r12 %-22s flow %s" % [key, str(summary[name]["r12"].get(key)), str(summary[name]["flow"].get(key))])
	print("engine: %s" % JSON.stringify(summary["engine"]))

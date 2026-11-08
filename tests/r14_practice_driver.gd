extends SceneTree
## p / r14 practice route driver. CLOSED LOOP, STATE AWARE: an execution proof that a line
## exists for the hosted runner, not imperfect play and not discovery. after the lab's own
## restart or stage practice it writes no pose, velocity or camera; it reads the runner and
## answers only with key edges and relative mouse motion. a jump node taps space when the
## landing target is one predicted flight away at the runner's actual speed, or at its edge.
## the trace is jsonl (gzip it after the run: godot's own compressed files are not gzip); the
## applied events are saved as a tape.
## godot --headless --path . --script res://tests/r14_practice_driver.gd --
##   --out=DIR --route=basic|block_miss|g1_miss|g3_miss [--runner=res://...] [--max-ticks=N]
##   [--late=TICKS] [--jitter=PX --seed=N]: imperfect input, every jump pressed TICKS late (after
##   the edge too, so a late press can run off), seeded mouse noise of up to PX per tick.

const LAB := preload("res://scripts/r14_practice_lab.gd")
const LEVEL := preload("res://scripts/r14_practice_level.gd")
const KEYS := {"w": KEY_W, "space": KEY_SPACE}
const PX := 0.0022
const WARMUP := 8
const SOURCES := ["res://scripts/r14_practice_level.gd", "res://scripts/r14_practice_lab.gd", "res://tests/r14_practice_driver.gd"]

## route nodes, world (x, z). p: steer to and pass; land: jump to this landing point (drop m
## below the take-off), e: the latest take-off point, past which it jumps anyway; fall: walk
## on with no jump until the runner is below y; w: hold or release forward on entering. W is
## let go when the last node is reached.
const BASIC := [
	{"p": Vector2(-1, -100)},
	{"land": Vector2(-2.5, -131.5), "e": Vector2(-2.5, -127.7)},
	{"land": Vector2(-2.5, -137.0), "e": Vector2(-2.5, -132.7)},
	{"land": Vector2(-2.5, -143.0), "e": Vector2(-2.5, -138.2)},
	{"land": Vector2(-2.5, -149.5), "e": Vector2(-2.5, -144.2)},
	{"land": Vector2(-2.5, -156.5), "e": Vector2(-2.5, -150.7)},
	{"land": Vector2(1.0, -162.0), "e": Vector2(0.5, -157.7)},
	{"land": Vector2(-5.0, -167.5), "e": Vector2(-0.5, -163.3)},
	{"land": Vector2(1.0, -173.0), "e": Vector2(-3.5, -168.8)},
	{"land": Vector2(-2.12, -179.17), "e": Vector2(1.0, -174.3)},
	{"land": Vector2(-6.29, -186.69), "e": Vector2(-3.04, -182.38)},
	{"land": Vector2(-12.54, -189.41), "e": Vector2(-7.29, -187.45)},
	{"p": Vector2(-22, -186.0)},
	{"land": Vector2(-35.5, -186.0), "e": Vector2(-30.0, -186.0)},
	{"p": Vector2(-50, -197.0)},
	{"land": Vector2(-59.5, -198.0), "e": Vector2(-53.9, -198.0)},
	{"p": Vector2(-68, -196.5)},
	{"p": Vector2(-76.74, -195.98)},
	{"p": Vector2(-79.66, -197.84)},
	{"p": Vector2(-81.52, -200.76)},
	{"p": Vector2(-81, -212)},
	{"land": Vector2(-80.5, -233.0), "drop": 1.5, "e": Vector2(-80.5, -226.1)},
	{"p": Vector2(-81, -238)},
	{"p": Vector2(-82, -244)},
]
## the misses walk each return's flush top, not across its sloping side: the r13 body has no
## step-up, where source's 18 u step would take the side's lower few centimetres.
## a walk off the first block into the pit, then the lane and its ramp back to the runway.
const BLOCK_MISS := [
	{"land": Vector2(-2.5, -131.5), "e": Vector2(-2.5, -127.7)},
	{"p": Vector2(-2.5, -136.0), "fall": -2.0},
	{"p": Vector2(3.5, -141.2), "r": 0.8},
	{"p": Vector2(6.0, -140.5), "r": 0.8},
	{"p": Vector2(6.0, -128.5)},
	{"p": Vector2(0.0, -123.0)},
]
## the 7.7 m wide end of the first weir gauge at run speed: short into the pit, then the
## south lane and its ramp back to the run-in.
const G1_MISS := [
	{"p": Vector2(-20, -198.2)},
	{"land": Vector2(-36.0, -198.2), "e": Vector2(-26.7, -198.2)},
	{"p": Vector2(-30, -198.5), "fall": -2.0},
	{"p": Vector2(-29, -201.6), "r": 0.8},
	{"p": Vector2(-15.0, -201.6)},
	{"p": Vector2(-15.0, -197.0)},
]
## the 13 m west end of the tail gauge at run speed: short into the pit, east to the lane.
const G3_MISS := [
	{"p": Vector2(-92.5, -212)},
	{"land": Vector2(-92.5, -234.0), "drop": 1.5, "e": Vector2(-92.5, -218.4)},
	{"p": Vector2(-90, -229.5), "fall": -3.5, "r": 0.8},
	{"p": Vector2(-76, -229.5), "r": 0.8},
	{"p": Vector2(-76, -210.0)},
	{"p": Vector2(-80.5, -209.5)},
]
const ROUTES := {"basic": [0, BASIC], "block_miss": [1, BLOCK_MISS], "g1_miss": [3, G1_MISS], "g3_miss": [5, G3_MISS]}

var opts := {}
var lab: Node3D
var player: CharacterBody3D
var nodes: Array = []
var node_index := 0
var step := 0
var tick := -1
var armed := false
var arm_step := 0
var done := false
var held := {}
var events: Array = []
var trace: FileAccess
var rows := 0
var out_dir := ""
var max_ticks := 9000
var jump_wait := false
var was_grounded := true
var airborne_seen := false
var tap_release := -1
var finish_tick := -1
var min_y := INF
var max_speed := 0.0
var node_ticks: Array = []
var checkpoint_ticks: Array = []
var last_checkpoint := -1
var jump_flight := {}
var radians_per_count := PX
var late := 0
var jitter := 0.0
var rng := RandomNumberGenerator.new()
var press_at := -1

class Hook:
	extends Node
	var driver: Object
	func _physics_process(_delta: float) -> void:
		driver.call("late_step")

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			opts[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	out_dir = str(opts.get("out", ""))
	assert(out_dir.is_absolute_path(), "practice driver: pass --out=<absolute directory outside git>")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_start.call_deferred()

func _start() -> void:
	max_ticks = int(opts.get("max-ticks", "9000"))
	late = int(opts.get("late", "0"))
	jitter = float(opts.get("jitter", "0"))
	rng.seed = int(opts.get("seed", "1"))
	var route := str(opts.get("route", "basic"))
	lab = LAB.Lab.new()
	lab.name = "PracticeLab"
	lab.set("set_window_title", false)
	if opts.has("runner"):
		lab.set("runner_path", str(opts.runner))
	root.add_child(lab)
	player = lab.get("player")
	# the driver taps every jump itself.
	if "autohop" in player:
		player.set("autohop", false)
	var plan: Array = ROUTES[route]
	if int(plan[0]) > 0:
		lab.call("practise", int(plan[0]))
	nodes = plan[1]
	var constants := {}
	var script := player.get_script() as Script
	while script != null:
		var own := script.get_script_constant_map()
		for key: String in own:
			if not constants.has(key):
				constants[key] = own[key]
		script = script.get_base_script()
	jump_flight = {"jump": float(constants.get("JUMP_SPEED", float(LEVEL.VANILLA.jump_ups) * LEVEL.U)), "gravity": float(constants.get("GRAVITY", float(LEVEL.VANILLA.gravity_ups) * LEVEL.U))}
	# source inherits old constant names for compatibility; its active cvars own ballistics.
	if "settings" in player and (player.get("settings") as Dictionary).has("sv_jump_impulse"):
		var source: Dictionary = player.get("settings")
		jump_flight = {"jump": float(source.sv_jump_impulse) * LEVEL.U, "gravity": float(source.sv_gravity) * LEVEL.U}
	if "tape_radians_per_count" in player:
		radians_per_count = float(player.get("tape_radians_per_count"))
	trace = FileAccess.open(out_dir.path_join("trace.jsonl"), FileAccess.WRITE)
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("practice driver: CLOSED LOOP route=%s runner=%s start_stage=%d geometry=%s flight=%s" % [route, lab.get("runner_label"), plan[0], str((lab.get("level") as Node).call("geometry_hash")).left(12), jump_flight])

func _flight(drop: float) -> float:
	var v0: float = jump_flight.jump
	var g: float = jump_flight.gravity
	return (v0 + sqrt(v0 * v0 + 2.0 * g * drop)) / g

func late_step() -> void:
	if player == null or done:
		return
	step += 1
	if not armed:
		if step >= WARMUP:
			armed = true
			arm_step = step
			_key("w", true)
		return
	tick = step - arm_step
	var p := player.global_position
	var speed := float(lab.get("display_speed"))
	var grounded: bool = player.call("is_grounded")
	min_y = minf(min_y, p.y)
	max_speed = maxf(max_speed, speed)
	var cp := int(lab.get("checkpoint_index"))
	if cp != last_checkpoint:
		checkpoint_ticks.append({"checkpoint": cp, "tick": tick, "elapsed": snappedf(float(lab.get("elapsed")), 0.001)})
		last_checkpoint = cp
	if bool(lab.get("finished")) and finish_tick < 0:
		finish_tick = tick
	trace.store_line(JSON.stringify({"t": tick, "p": _v(p), "v": _v(player.velocity), "speed": snappedf(speed, 0.001), "g": grounded, "cp": cp, "node": node_index, "yaw": snappedf(float(player.get("yaw")) if "yaw" in player else 0.0, 0.0001)}))
	rows += 1
	if press_at >= 0 and tick >= press_at:
		_key("space", true)
		tap_release = tick + 8
		press_at = -1
	if tap_release >= 0 and tick >= tap_release:
		_key("space", false)
		tap_release = -1
	_control(p, grounded, speed)
	was_grounded = grounded
	if tick + 1 >= max_ticks or (node_index >= nodes.size() and (finish_tick >= 0 or tick > 60 + int(node_ticks[-1].tick if not node_ticks.is_empty() else 0))):
		_end("finished" if finish_tick >= 0 else ("route_done" if node_index >= nodes.size() else "budget"))

func _control(p: Vector3, grounded: bool, speed: float) -> void:
	if node_index >= nodes.size():
		return
	var node: Dictionary = nodes[node_index]
	var here := Vector2(p.x, p.z)
	if jump_wait:
		# in flight: steer on toward the landing; done on the first grounded tick after air.
		if not grounded:
			airborne_seen = true
		if airborne_seen and grounded:
			jump_wait = false
			airborne_seen = false
			_next(p)
			return
		# within 1.5 m of the landing, look toward what comes after it, as a player would.
		var look: Vector2 = node.land
		if here.distance_to(node.land) < 1.5 and node_index + 1 < nodes.size():
			var after: Dictionary = nodes[node_index + 1]
			look = after.land if after.has("land") else after.p
		_steer(here, look)
		return
	var target: Vector2 = node.land if node.has("land") else node.p
	if node.has("land"):
		var reach := Vector2(player.velocity.x, player.velocity.z).length() * _flight(float(node.get("drop", 0.0)))
		var edge: Vector2 = node.e
		var to_edge := (edge - here).dot((target - edge).normalized())
		# the deck ending two ticks ahead along the actual travel counts as the edge too.
		var ahead := p + Vector3(player.velocity.x, 0, player.velocity.z) * (2.0 / Engine.physics_ticks_per_second) + Vector3.UP * 0.3
		var under := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3.DOWN * 0.7))
		if grounded and (here.distance_to(target) <= reach or to_edge <= 0.05 or under.is_empty()):
			if late > 0:
				press_at = tick + late
			else:
				_key("space", true)
				tap_release = tick + 8
			jump_wait = true
			airborne_seen = false
		_steer(here, target)
		return
	if node.has("fall"):
		_steer(here, target)
		if p.y < float(node.fall) and grounded:
			_next(p)
		return
	if here.distance_to(target) < float(node.get("r", 1.2)):
		_next(p)
		return
	_steer(here, target)

func _next(p: Vector3) -> void:
	node_ticks.append({"node": node_index, "tick": tick, "p": _v(p)})
	node_index += 1
	if node_index < nodes.size():
		var node: Dictionary = nodes[node_index]
		if node.has("w"):
			_key("w", bool(node.w))
	else:
		_key("w", false)

func _steer(here: Vector2, target: Vector2) -> void:
	# proportional and rate limited like a hand on a mouse: at most 30 px (0.066 rad) a tick.
	var to := target - here
	if to.length() < 0.05 or not "yaw" in player:
		return
	var desired := atan2(-to.x, -to.y)
	var error := wrapf(desired - float(player.get("yaw")), -PI, PI)
	var px := clampf(-error * 0.4 / radians_per_count, -30.0, 30.0) + (rng.randf_range(-jitter, jitter) if jitter > 0.0 else 0.0)
	if absf(px) < 0.05:
		return
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(px, 0.0)
	motion.screen_relative = motion.relative
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	events.append({"tick": tick, "mouse": [snappedf(px, 0.001), 0.0]})

func _key(key: String, pressed: bool) -> void:
	if pressed == held.has(key):
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEYS[key]
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed:
		held[key] = true
	else:
		held.erase(key)
	events.append({"tick": tick, "key": key, "edge": "press" if pressed else "release"})

func _end(reason: String) -> void:
	done = true
	for key: String in held.keys():
		_key(key, false)
	trace.close()
	var sources := {}
	for path: String in SOURCES:
		sources[path] = FileAccess.get_sha256(path)
	sources[str(lab.get("runner_path"))] = FileAccess.get_sha256(str(lab.get("runner_path")))
	var jumps: Array = []
	for jump: Dictionary in lab.get("jumps"):
		jumps.append({"from": _v(jump.from), "to": _v(jump.to), "distance_m": snappedf(jump.distance_m, 0.001), "distance_u": roundi(jump.distance_u),
			"takeoff_ups": roundi(jump.takeoff_ups), "landing_ups": roundi(jump.landing_ups), "air_s": snappedf(jump.air_s, 0.001), "gap": jump.gap, "surface": jump.surface})
	var final := player.global_position
	var support := ""
	var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(final + Vector3.UP * 0.3, final + Vector3.DOWN * 0.5))
	if not hit.is_empty():
		support = str((hit.collider as Node).name)
	var summary := {"label": "CLOSED LOOP state-aware execution proof on the hosted runner; not imperfect input, not discovery, not Source unless the runner is",
		"reason": reason, "route": opts.get("route", "basic"), "late_ticks": late, "jitter_px": jitter, "seed": rng.seed, "runner": lab.get("runner_path"), "runner_label": lab.get("runner_label"),
		"physics_hz": Engine.physics_ticks_per_second, "geometry_hash": (lab.get("level") as Node).call("geometry_hash"), "sources_sha256": sources,
		"ticks": tick + 1, "finish_tick": finish_tick, "finish_time_s": lab.get("elapsed") if finish_tick >= 0 else null, "finish_kind": lab.get("finish_kind"),
		"respawns": lab.get("respawn_count"), "checkpoints": checkpoint_ticks, "nodes_reached": node_ticks.size(), "nodes": nodes.size(), "node_ticks": node_ticks,
		"min_y": snappedf(min_y, 0.001), "max_display_speed_mps": snappedf(max_speed, 0.001), "jumps": jumps, "final": _v(final), "final_support": support,
		"setup_writes": ["lab._ready -> restart() or practise(stage): the lab's own pose reset"]}
	_write("summary.json", summary)
	_write("events.tape.json", {"format": "r14-practice-events", "physics_hz": Engine.physics_ticks_per_second, "events": events})
	print("practice driver: %s finish=%s time=%s kind=%s respawns=%s nodes=%d/%d min_y=%.2f final=%s on %s jumps=%d" % [reason, finish_tick, summary.finish_time_s, summary.finish_kind, summary.respawns, node_ticks.size(), nodes.size(), min_y, final, support, jumps.size()])
	quit(0)

func _write(name: String, data: Variant) -> void:
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, " "))
	file.close()

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]

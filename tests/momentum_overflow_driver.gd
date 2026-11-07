extends SceneTree
## p / overflow route driver. CLOSED LOOP, STATE AWARE: an execution proof that a line exists
## for the real motor from the normal spawn, not imperfect play and not discovery. after the
## game's own restart_run it writes no pose, velocity or camera; it reads the runner and
## answers only with ordinary key edges and relative mouse motion, on the tape executor's
## schedule (mouse early in step N, key edges after step N-1), so its applied events are saved
## as a spillway-momentum-tape that tools/momentum-tape.py replays open loop.
## godot --headless --fixed-fps 30 --path . --script res://tests/momentum_overflow_driver.gd --
##   --out=DIR [--world=course|block|block_mirror|block_offset] [--air=candidate|broad|narrow]
##   [--route=ordinary|tight|mastery|miss|pool_miss|slot_miss|wide_turn on the course;
##    ordinary|tight|corner|hop|stutter|mastery|miss on the block]
##   [--nodes=JSON] [--max-ticks=N]

const GAME := preload("res://scripts/momentum_overflow_game.gd")
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL}
const PX := 0.0022
const WARMUP := 8
const SOURCES := ["res://scripts/momentum_overflow_level.gd", "res://scripts/momentum_overflow_game.gd", "res://scripts/momentum_carry_game.gd", "res://scripts/momentum_carry_player.gd", "res://scripts/momentum_carry_air_candidate.gd", "res://scripts/spillway_player.gd", "res://scripts/spillway_main.gd", "res://scripts/momentum_materials.gd", "res://tests/momentum_overflow_driver.gd"]

## route nodes in design coordinates (the course frame; the block shares it). keys:
## p target (x, z), r pass radius, jump: tap space on reaching, hop: hold space on/off,
## w: hold or release forward, side: "a"/"d"/"" strafe key, sweep: mouse px/tick added while
## the side key is held, tap: ticks to hold a tapped jump, s: hold or release brake, brake: hold
## S instead of W while this node is the target and faster than the given m/s. node keys act
## when the node becomes the target, not when it is reached.
const ORDINARY_PIER := [
	{"p": Vector2(0, -27.3), "jump": true},
	{"p": Vector2(0, -50)},
	{"p": Vector2(-1.5, -57.0), "r": 2.5},
	{"p": Vector2(-12, -57.5)},
	{"p": Vector2(-26, -56)},
]
## the ordinary line run well: no jump on the pier, hugging the pier head's inside corner.
const TIGHT_PIER := [
	{"p": Vector2(0, -27.3), "jump": true},
	{"p": Vector2(-3.2, -47.5)},
	{"p": Vector2(-5.8, -53.2), "r": 0.8},
	{"p": Vector2(-12, -55.5)},
	{"p": Vector2(-26, -56)},
]
## held hopping all the way: the last landing on the pier's open edge launches the diagonal.
const HOP_PIER := [
	{"p": Vector2(0, -23.0), "hop": false},
	{"p": Vector2(0, -27.4), "jump": true, "hold": true},
	{"p": Vector2(-4.4, -44.5), "ground": true},
	{"p": Vector2(-15, -54.5), "r": 3.0},
	{"p": Vector2(-27, -56)},
]
## a stutter: land the slot hop running, run a few metres, then one hop that lands by the
## pier's corner and launches the diagonal from that landing.
const STUTTER_PIER := [
	{"p": Vector2(0, -23.0), "hop": false},
	{"p": Vector2(0, -27.4), "jump": true},
	{"p": Vector2(-1.5, -41.0), "jump": true, "hold": true},
	{"p": Vector2(-4.5, -48.5), "ground": true},
	{"p": Vector2(-18.5, -54.0), "r": 3.0},
	{"p": Vector2(-27, -56)},
]
## the corner hop: run, then jump off the pier's bay edge just before the pier head.
const CORNER_PIER := [
	{"p": Vector2(0, -27.3), "jump": true},
	{"p": Vector2(-3.5, -46.0)},
	{"p": Vector2(-4.6, -50.0), "jump": true, "r": 0.5},
	{"p": Vector2(-10, -55.5), "r": 2.0},
	{"p": Vector2(-26, -56)},
]
## the W-run diagonal attempt from the pier's nosing that falls short into the bay.
const MISS_PIER := [
	{"p": Vector2(0, -27.3), "jump": true},
	{"p": Vector2(-4.5, -45.3), "jump": true, "r": 0.5},
	{"p": Vector2(-15, -54.5), "air_only": true},
	{"p": Vector2(-24, -38.5), "r": 2.0},
	{"p": Vector2(-25, -48.5)},
	{"p": Vector2(-30, -55)},
]
## course (revision 2): after slot 2 the ordinary line runs the pier, veers onto the platform
## and takes the slipway down through the spill bay and over the crest, then the chute.
const COURSE_ORDINARY_PIER := [
	{"p": Vector2(0, -27.3), "jump": true},
	{"p": Vector2(-6, -44)},
	{"p": Vector2(-18, -54)},
	{"p": Vector2(-18, -74)},
	{"p": Vector2(-15, -86)},
	{"p": Vector2(-6, -98)},
]
## the earned line: held hops from slot 1 carry speed down the pier; the hop stops on a landing
## past the pier's middle and the runner jumps the bay's wide end straight on from its edge.
const COURSE_MASTERY_PIER := [
	{"p": Vector2(0, -23.0), "hop": false},
	{"p": Vector2(0, -27.4), "jump": true, "hold": true},
	{"p": Vector2(0, -54.0), "ground": true},
	{"p": Vector2(0, -65.4), "jump": true, "r": 0.6, "hop": false},
	{"p": Vector2(0, -90)},
	{"p": Vector2(-0.5, -100)},
]
## the ordinary line run well, the payoff the earned jump is measured against: held hops from
## slot 1, a tap over slot 2, then a run down the pier and onto the slipway. hopping the pier
## into the turn was slower (26.4 to 26.6 s): the 17 m/s runner swings wide of the slipway.
const COURSE_TIGHT_PIER := [
	{"p": Vector2(0, -23.0), "hop": false},
	{"p": Vector2(0, -27.4), "jump": true},
	{"p": Vector2(-3, -44)},
	{"p": Vector2(-17, -55)},
	{"p": Vector2(-18, -74)},
	{"p": Vector2(-15, -86)},
	{"p": Vector2(-6, -98)},
]
## a plain W run that tries the wide end anyway: it falls short onto the apron and climbs out.
const COURSE_MISS_PIER := [
	{"p": Vector2(0, -27.3), "jump": true},
	{"p": Vector2(0, -65.4), "jump": true, "r": 0.6},
	{"p": Vector2(0, -88)},
	{"p": Vector2(-0.5, -100)},
]
## the bends and the finish: W is let go past the line, on the sluice deck.
const COURSE_ARRIVAL := [
	{"p": Vector2(-36, -145)},
	{"p": Vector2(-50, -152)},
	{"p": Vector2(-52, -168)},
	{"p": Vector2(-52, -194)},
	{"p": Vector2(-52, -200), "w": false},
	{"p": Vector2(-52, -202)},
]
## the bucket and the tail race. the ordinary line brakes to 12 m/s for the first bend.
const COURSE_TAIL := [
	{"p": Vector2(-1, -108)},
	{"p": Vector2(-1, -114.3), "jump": true, "r": 0.8},
	{"p": Vector2(-3, -141), "r": 2.0, "brake": 12.0},
	{"p": Vector2(-14, -146)},
]
## the fast line keeps its speed through the tail race and swings wide instead of braking.
const COURSE_WIDE_TAIL := [
	{"p": Vector2(-0.5, -108)},
	{"p": Vector2(-0.5, -114.3), "jump": true, "r": 0.8},
	{"p": Vector2(-2, -142), "r": 2.0},
	{"p": Vector2(-12, -150)},
]
## a deliberately slow bucket: brake on the chute and run off the lip without a jump; the
## run-off drops onto the pool apron, which climbs ahead.
const COURSE_POOL_MISS_TAIL := [
	{"p": Vector2(-1, -100), "brake": 8.6},
	{"p": Vector2(-1, -121)},
	{"p": Vector2(-3, -141), "r": 2.0},
	{"p": Vector2(-14, -146)},
]

var opts := {}
var game: Node
var player: CharacterBody3D
var level: Node3D
var nodes: Array = []
var node_index := 0
var node_ticks: Array = []
var step := 0
var armed := false
var arm_step := 0
var tick := -1
var max_ticks := 7200
var held := {}
var events: Array = []
var pending_mouse := 0.0
var scheduled := {}
var hop := false
var finish_tick := -1
var trace: FileAccess
var rows := 0
var pre_p := Vector3.ZERO
var stalls: Array = []
var stall_run := 0
var checkpoint_ticks: Array = []
var last_checkpoint := 0
var min_y := INF
var max_speed := 0.0
var air_ticks := 0
var out_dir := ""
var done := false

class Hook:
	extends Node
	var driver: Object
	var early: bool
	func _physics_process(_delta: float) -> void:
		driver.call("early_step" if early else "late_step")

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			opts[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	out_dir = str(opts.get("out", ""))
	assert(out_dir.is_absolute_path(), "overflow driver: pass --out=<absolute directory outside git>")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_start.call_deferred()

func _start() -> void:
	max_ticks = int(opts.get("max-ticks", "7200"))
	var world := str(opts.get("world", "course"))
	var classes := {"course": GAME, "block": GAME.Block, "block_mirror": GAME.BlockMirror, "block_offset": GAME.BlockOffset}
	game = (classes[world] as Script).new()
	game.name = "OverflowGame"
	game.set("motor", str(opts.get("air", "broad")))
	game.set("set_window_title", false)
	root.add_child(game)
	player = game.get("player")
	level = game.get("level")
	nodes = _route(str(opts.get("route", "ordinary")), world)
	trace = FileAccess.open(out_dir.path_join("trace.jsonl"), FileAccess.WRITE)
	for early: bool in [true, false]:
		var hook := Hook.new()
		hook.driver = self
		hook.early = early
		hook.process_physics_priority = -1000 if early else 1000
		hook.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(hook)
	print("overflow driver: CLOSED LOOP world=%s air=%s route=%s nodes=%d geometry=%s" % [world, opts.get("air", "broad"), opts.get("route", "ordinary"), nodes.size(), level.call("geometry_hash")])

func _route(route: String, world: String) -> Array:
	var plan: Array = []
	var course := world == "course"
	if course:
		plan.append({"p": Vector2(0, 40)})
		if route in ["mastery", "wide_turn", "tight"]:
			plan.append({"p": Vector2(0, 16.0), "hop": false})
			plan.append({"p": Vector2(0, 11.6), "jump": true, "hold": true})
		elif route == "slot_miss":
			plan.append({"p": Vector2(0, 11.6), "w": true})
		else:
			plan.append({"p": Vector2(0, 11.7), "jump": true})
		plan.append({"p": Vector2(0, -5)})
	else:
		plan.append({"p": Vector2(0, -6), "hop": route in ["mastery", "hop", "stutter", "sweep"]})
	if course:
		if route == "slot_miss":
			plan.append_array([{"p": Vector2(0, -27.0)}, {"p": Vector2(6.5, -31.5), "r": 1.5}, {"p": Vector2(6.5, -41.0)}, {"p": Vector2(1.5, -44.0)}])
			plan.append_array(COURSE_ORDINARY_PIER.slice(1))
		else:
			plan.append_array({"mastery": COURSE_MASTERY_PIER, "wide_turn": COURSE_MASTERY_PIER, "tight": COURSE_TIGHT_PIER, "miss": COURSE_MISS_PIER}.get(route, COURSE_ORDINARY_PIER))
		plan.append_array({"wide_turn": COURSE_WIDE_TAIL, "pool_miss": COURSE_POOL_MISS_TAIL}.get(route, COURSE_TAIL))
		plan.append_array(COURSE_ARRIVAL)
	elif opts.has("nodes"):
		# a sweep: pier nodes as json [[x, z, flags...]], flags jump/hold/ground/hop0/hop1/w0/w1.
		for item: Array in JSON.parse_string(str(opts.nodes)):
			var node := {"p": Vector2(float(item[0]), float(item[1]))}
			for flag: String in item.slice(2):
				match flag:
					"jump": node.jump = true
					"hold": node.hold = true
					"ground": node.ground = true
					"hop0": node.hop = false
					"hop1": node.hop = true
					"w0": node.w = false
					"w1": node.w = true
					"r3": node.r = 3.0
					"r05": node.r = 0.5
			plan.append(node)
		plan.append_array([{"p": Vector2(-36, -55)}, {"p": Vector2(-42, -55), "w": false}, {"p": Vector2(-44, -55)}])
	else:
		plan.append_array({"mastery": HOP_PIER, "hop": HOP_PIER, "stutter": STUTTER_PIER, "corner": CORNER_PIER, "tight": TIGHT_PIER, "miss": MISS_PIER}.get(route, ORDINARY_PIER))
		plan.append_array([{"p": Vector2(-36, -55)}, {"p": Vector2(-42, -55), "w": false}, {"p": Vector2(-44, -55)}])
	# map into the variant's world: the landing-offset holdout shifts the pier section.
	var mirror: float = -1.0 if world == "block_mirror" else 1.0
	var mapped: Array = []
	for node: Dictionary in plan:
		var copy := node.duplicate()
		var p: Vector2 = node.p
		if world == "block_offset" and p.y < -28.5:
			p.x += level.get("OFFSET")
		copy.p = Vector2(p.x * mirror, p.y)
		mapped.append(copy)
	return mapped

func _process(_delta: float) -> bool:
	if player != null and not armed and step >= WARMUP:
		armed = true
		arm_step = step
		_key("w", true, 0)
		_enter_node(0)
	return false

func early_step() -> void:
	if player == null:
		return
	var index := step
	step += 1
	if not armed or done:
		return
	tick = index - arm_step
	pre_p = player.global_position
	if pending_mouse != 0.0:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(pending_mouse, 0.0)
		motion.screen_relative = motion.relative
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		events.append({"tick": tick, "mouse": [motion.relative.x, 0.0]})
	pending_mouse = 0.0

func late_step() -> void:
	if not armed or done or tick < 0:
		return
	var p := player.global_position
	var dt := 1.0 / Engine.physics_ticks_per_second
	var disp := (p - pre_p) / dt
	var requested: Vector3 = player.call("tape_requested_velocity") if player.has_method("tape_requested_velocity") else Vector3.ZERO
	var req_h := Vector2(requested.x, requested.z).length()
	var disp_h := Vector2(disp.x, disp.z).length()
	var grounded: bool = player.call("is_grounded")
	min_y = minf(min_y, p.y)
	max_speed = maxf(max_speed, disp_h)
	air_ticks += 0 if grounded else 1
	# a stall: the motor asks for real horizontal motion and the body does not travel.
	if req_h > 3.0 and disp_h < 0.5 * req_h and int(game.get("respawn_count")) == 0:
		stall_run += 1
	else:
		if stall_run >= 6:
			stalls.append({"end_tick": tick, "ticks": stall_run, "p": _v(p)})
		stall_run = 0
	var cp := int(game.get("checkpoint_index"))
	if cp != last_checkpoint:
		checkpoint_ticks.append({"checkpoint": cp, "tick": tick, "elapsed": game.get("elapsed")})
		last_checkpoint = cp
	if bool(game.get("finished")) and finish_tick < 0:
		finish_tick = tick
	trace.store_line(JSON.stringify({"t": tick, "p": _v(p), "req": _v(requested), "post": _v(player.velocity), "disp": _v(disp),
		"speed": snappedf(disp_h, 0.001), "g": grounded, "mode": player.get("mode"), "yaw": snappedf(float(player.get("yaw")), 0.0001),
		"cp": cp, "fin": game.get("finished"), "node": node_index, "held": held.keys()}))
	rows += 1
	_control(p, grounded, disp_h)
	if tick + 1 >= max_ticks or (finish_tick >= 0 and node_index >= nodes.size()) or (finish_tick >= 0 and tick > finish_tick + 360):
		_end("finished" if finish_tick >= 0 else "budget")

func _control(p: Vector3, grounded: bool, speed: float) -> void:
	var next := tick + 1
	for edge: Array in scheduled.get(next, []):
		_key(edge[0], edge[1], next)
	scheduled.erase(next)
	if node_index >= nodes.size():
		pending_mouse = 0.0
		return
	var node: Dictionary = nodes[node_index]
	var target: Vector2 = node.p
	var here := Vector2(p.x, p.z)
	var previous: Vector2 = nodes[node_index - 1].p if node_index > 0 else here
	var along := (target - previous).normalized() if target.distance_to(previous) > 0.01 else Vector2.ZERO
	var reached := here.distance_to(target) < float(node.get("r", 1.2)) or (along != Vector2.ZERO and (here - target).dot(along) >= 0.0)
	if node.get("ground", false):
		# a hop-through launch: switch targets only on a landing tick past the plane.
		reached = grounded and (along == Vector2.ZERO or (here - target).dot(along) >= 0.0)
	if node.get("air_only", false):
		# a recovery node: done once the runner has come down below the pier decks.
		reached = grounded and p.y < 2.5
	if reached:
		node_ticks.append({"node": node_index, "tick": tick, "p": _v(p)})
		node_index += 1
		if node.get("jump", false):
			# a tap: a fresh press now (after a release if hopping held space), then let go
			# unless held hopping continues from this take-off.
			var at := next
			if held.has("space"):
				_key("space", false, next)
				at = next + 1
				_schedule(at, "space", true)
			else:
				_key("space", true, next)
			hop = bool(node.get("hold", false))
			if not hop:
				_schedule(at + int(node.get("tap", 8)), "space", false)
		if node_index >= nodes.size():
			return
		_enter_node(next)
		node = nodes[node_index]
		target = node.p
	if node.has("brake"):
		# a speed check: S instead of W while faster than the node's brake speed.
		var slow := speed > float(node.brake)
		_key("w", not slow, next)
		_key("s", slow, next)
	# steer the view toward the target: proportional, rate-limited like a hand on a mouse. a
	# hop-through node already passed in the air steers on toward the node after it.
	if node.get("ground", false) and along != Vector2.ZERO and (here - target).dot(along) >= 0.0 and node_index + 1 < nodes.size():
		target = nodes[node_index + 1].p
	var to := target - here
	var desired := atan2(-to.x, -to.y)
	var error := wrapf(desired - float(player.get("yaw")), -PI, PI)
	var px := clampf(-error * 0.2 / (PX * float((game.get("settings") as Dictionary).sensitivity)), -9.0, 9.0)
	pending_mouse = px if absf(px) > 0.05 else 0.0

func _schedule(at: int, key: String, pressed: bool) -> void:
	if not scheduled.has(at):
		scheduled[at] = []
	scheduled[at].append([key, pressed])

func _enter_node(at: int) -> void:
	var node: Dictionary = nodes[node_index]
	if nodes[node_index - 1].has("brake") and not node.has("brake"):
		# leaving a speed check: back to running.
		_key("s", false, at)
		_key("w", true, at)
	if node.has("w") and bool(node.w) != held.has("w"):
		_key("w", bool(node.w), at)
	if node.has("s") and bool(node.s) != held.has("s"):
		_key("s", bool(node.s), at)
	if node.has("hop"):
		hop = bool(node.hop)
	# held hopping: keep space down unless a tapped take-off is still being released.
	var busy := false
	for t: int in scheduled:
		busy = busy or t >= at
	if not busy:
		if hop and not held.has("space"):
			_key("space", true, at)
		elif not hop and held.has("space"):
			_key("space", false, at)

func _key(key: String, pressed: bool, at: int) -> void:
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
	events.append({"tick": at, "key": key, "edge": "press" if pressed else "release"})

func _end(reason: String) -> void:
	done = true
	var last := tick + 1
	for key: String in held.keys():
		_key(key, false, last)
	trace.close()
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.tick) < int(b.tick) or (int(a.tick) == int(b.tick) and a.has("key") and b.has("mouse")))
	var tape := {"format": "spillway-momentum-tape", "version": 1, "name": "overflow-%s-%s-%s" % [opts.get("world", "course"), opts.get("route", "ordinary"), opts.get("air", "broad")],
		"description": "recorded from the CLOSED-LOOP overflow driver (state-aware execution proof). replaying it is open loop.",
		"physics_hz": Engine.physics_ticks_per_second, "input_profile": "tick120", "duration_ticks": last + 1, "mouse_quantize": "float32", "events": events}
	_write("events.tape.json", tape)
	var sources := {}
	for path: String in SOURCES:
		sources[path] = FileAccess.get_sha256(path)
	var summary := {"label": "CLOSED LOOP state-aware execution proof; not imperfect input, not discovery",
		"reason": reason, "world": opts.get("world", "course"), "air": opts.get("air", "broad"), "route": opts.get("route", "ordinary"),
		"geometry_hash": level.call("geometry_hash"), "sources_sha256": sources, "ticks": last, "finish_tick": finish_tick,
		"finish_time_s": game.get("elapsed") if finish_tick >= 0 else null, "finish_kind": game.get("finish_kind"),
		"respawns": game.get("respawn_count"), "checkpoints": checkpoint_ticks, "nodes_reached": node_ticks.size(), "nodes": nodes.size(),
		"node_ticks": node_ticks, "stalls": stalls, "min_y": min_y, "max_actual_speed": max_speed, "air_fraction": float(air_ticks) / maxf(1.0, rows),
		"jumps": player.get("jump_count"), "final": _v(player.global_position), "setup_writes": ["game._ready -> restart_run(): normal spawn (game code)"]}
	_write("summary.json", summary)
	print("overflow driver: %s finish=%s time=%s respawns=%s stalls=%d nodes=%d/%d final=%s" % [reason, finish_tick, summary.finish_time_s, summary.respawns, stalls.size(), node_ticks.size(), nodes.size(), player.global_position])
	game.call("request_quit")

func _write(name: String, data: Variant) -> void:
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, " "))
	file.close()

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]

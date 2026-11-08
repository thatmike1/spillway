extends SceneTree
## p / r14 practice route driver. CLOSED LOOP, STATE AWARE: an execution proof that a line
## exists for the hosted runner, not imperfect play and not discovery. after the lab's own
## restart it writes no pose, velocity, camera or progress; it reads the runner and answers
## only with key edges and relative mouse counts, which it also saves as a version 2 momentum
## tape at the runner's actual rate (docs/r14/REPLAY.md). --tape= plays such a tape back open
## loop: the same events on the same ticks, with no state read to choose them.
##
## source runners are driven the way a cs player moves: w on the ground only, released in
## the air; a/d with the mouse turning the same way at the best wish angle for the actual
## velocity and surface, capped to a human turn rate; held jump on autohop profiles, a fresh
## press on the first ground tick on vanilla. nothing here rescues the motor: no w in the air,
## no view-only steering, no wall pushes (wall contacts are counted and reported).
## the r13 stand-in keeps its own policy (w held, mouse steering), labelled as such.
##
## godot --headless --fixed-fps <hz> --path . --script res://tests/r14_practice_driver.gd --
##   --out=DIR --route=NAME [--preset=csgo_server|csgo_vanilla] [--runner=res://...]
##   [--turn-cap=DEG_PER_S] [--amp=DEG] [--max-ticks=N] [--warmup=N] [--tape=PLAN.json]

const LAB := preload("res://scripts/r14_practice_lab.gd")
const LEVEL := preload("res://scripts/r14_practice_level.gd")
const MOTION := preload("res://scripts/r14_source_motion.gd")
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE}
const KEY_ORDER := ["w", "a", "s", "d", "space"]
const SOURCES := ["res://scripts/r14_practice_level.gd", "res://scripts/r14_practice_lab.gd", "res://tests/r14_practice_driver.gd", "res://scripts/r14_source_motion.gd"]
const U := 0.0254

## route nodes, world (x, z). land: jump to this landing point (drop m below the take-off),
## e the latest take-off point; p: pass this point (hop: chain hops toward it); fall: walk on
## until the runner is grounded below y; vt: air speed target in u/s (0 holds speed and only
## steers, more strafes for gain up to it); chain: on landing, jump again at once.
## the stop logs, shared by every line from the spawn: the run-in, blocks 1-3, blocks 4-5 and
## the zig blocks with the jump onto the valve bend (constants only add, so split in four).
const RUNIN := [{"p": Vector2(-1, -14)}]
const BLOCKS_1_3 := [
	{"land": Vector2(-2.5, -24.0), "e": Vector2(-2.5, -20.0)},
	{"land": Vector2(-2.5, -31.0), "e": Vector2(-2.5, -26.5)},
	{"land": Vector2(-2.5, -38.5), "e": Vector2(-2.5, -33.5)},
]
const BLOCKS_4_5 := [
	{"land": Vector2(-2.5, -46.5), "e": Vector2(-2.5, -41.0)},
	{"land": Vector2(-2.0, -55.0), "e": Vector2(-2.5, -49.0)},
]
const ZIG := [
	{"land": Vector2(0.3, -61.8), "e": Vector2(-1.0, -57.5)},
	{"land": Vector2(-4.6, -67.6), "e": Vector2(-2.2, -64.0)},
	{"land": Vector2(0.0, -74.8), "e": Vector2(-4.2, -70.5)},
	{"land": Vector2(-2.16, -82.23), "e": Vector2(0.0, -77.0)},
]
const FRONT := RUNIN + BLOCKS_1_3 + BLOCKS_4_5 + ZIG
const BEND_INSIDE := [
	{"land": Vector2(-9.64, -89.96), "e": Vector2(-6.32, -85.70)},
	{"land": Vector2(-16.19, -92.87), "e": Vector2(-11.11, -91.02)},
]
## the valve bend's outside line (r 21 to 22): two 6.4 m gaps, strafing for speed on the way.
const BEND_OUTSIDE := [
	{"land": Vector2(1.18, -88.54), "e": Vector2(2.67, -90.08), "chain": true, "fit": true, "win": 2.0, "vt": 600.0},
	{"land": Vector2(-3.0, -96.0), "e": Vector2(2.67, -90.08), "chain": true, "vt": 600.0},
	{"land": Vector2(-13.43, -101.52), "e": Vector2(-5.81, -99.51), "chain": true, "vt": 600.0},
]
## the pump bend's inside band, then the tail gauge's 4.2 m east end and the finish band.
const PUMP_INSIDE := [
	{"p": Vector2(-226.74, -102.48)},
	{"p": Vector2(-229.66, -104.34)},
	{"p": Vector2(-231.52, -107.26)},
	{"p": Vector2(-230.0, -116.0)},
]
const TAIL_EAST := [
	{"land": Vector2(-230.0, -141.0), "e": Vector2(-230.0, -132.8), "drop": 1.5},
	{"p": Vector2(-230.0, -146.0)},
]
const BACK_BASIC := PUMP_INSIDE + TAIL_EAST
const ROUTES := {
	# trial 1, version 1 geometry (kept for the record): the zig blocks and the runway's
	# order failed; see docs/r14/PRACTICE.md.
	# version 2 basic: no strafing for speed (vt 0): run and jump, steering in the air only.
	"basic": FRONT + BEND_INSIDE + [
		{"p": Vector2(-60, -98), "hop": true},
		{"p": Vector2(-140, -92.0), "hop": true},
		{"land": Vector2(-168.5, -91.5), "e": Vector2(-162.2, -91.5)},
		{"p": Vector2(-196, -104.5)},
		{"land": Vector2(-210.5, -105.0), "e": Vector2(-204.0, -105.0)},
	] + BACK_BASIC,
	# server: speed down the straight, then the wide ends: g1 south, g2 north, the pump bend's
	# outer band over the notch, g3 west. every landing is a take-off (chain); fit nodes land
	# on their point by strafing when short and one-tick s when long.
	"advanced": FRONT + BEND_OUTSIDE + [
		{"p": Vector2(-92, -100.0), "hop": true, "vt": 3000.0},
		{"land": Vector2(-158.1, -104.5), "e": Vector2(-158.3, -104.8), "chain": true, "fit": true, "win": 2.0, "vt": 3000.0},
		{"land": Vector2(-174, -104.0), "e": Vector2(-158.3, -104.8), "chain": true},
		{"land": Vector2(-196.2, -92.6), "e": Vector2(-196.6, -92.6), "chain": true, "fit": true, "win": 1.0, "vt": 3000.0},
		{"land": Vector2(-215, -92.0), "e": Vector2(-196.6, -92.6), "chain": true},
		{"p": Vector2(-224.0, -100.0), "hop": true, "vt": 3000.0},
		{"p": Vector2(-233.0, -110.0), "hop": true, "vt": 3000.0},
		{"land": Vector2(-236.5, -127.6), "e": Vector2(-236.5, -128.9), "chain": true, "fit": true, "win": 6.0, "vt": 3000.0},
		{"land": Vector2(-236.5, -146.0), "e": Vector2(-236.5, -128.9), "clear": Vector2(-236.5, -139.5), "drop": 1.5, "chain": true, "vt": 3000.0},
		{"p": Vector2(-236.0, -150.0)},
	],
	# deliberate misses: a jump pressed too early drops into the pit, the runner walks the
	# return to the deck the jump left from (no respawn, no teleport) and tries again.
	# block 4: pressed on landing on block 3, 4.8 m short of the far side of a 3.5 m gap.
	"block_miss": RUNIN + BLOCKS_1_3 + [
		{"land": Vector2(-2.5, -43.0), "e": Vector2(-2.5, -37.0), "miss": true},
		{"p": Vector2(5.8, -43.0)},
		{"p": Vector2(6.0, -33.0)},
		{"p": Vector2(6.0, -21.0)},
		{"p": Vector2(2.0, -14.0)},
		{"p": Vector2(-1.0, -17.0)},
	] + BLOCKS_1_3 + BLOCKS_4_5,
	# g1's 7.7 m south end at run speed: short into the pit, the south lane and its ramp back
	# to the run-in, then the 3.3 m north end.
	"g1_miss": FRONT + BEND_INSIDE + [
		{"p": Vector2(-60, -98), "hop": true},
		{"p": Vector2(-140, -102.0), "hop": true},
		{"p": Vector2(-150, -104.5)},
		{"land": Vector2(-163.2, -104.5), "e": Vector2(-158.3, -104.8), "miss": true},
		# the lane's centre line. the pre-repair source runner snagged on this ramp near x -151
		# (trial 35) and walked z -108.8 instead; the repaired one climbs it in 1.6 s (trial 37).
		{"p": Vector2(-162.0, -108.0)},
		{"p": Vector2(-150.0, -108.0)},
		{"p": Vector2(-147.0, -108.0)},
		{"p": Vector2(-147.5, -101.0)},
		{"p": Vector2(-152.0, -92.5)},
		{"land": Vector2(-168.5, -91.5), "e": Vector2(-162.2, -91.5)},
	],
	# g3's 14 m west end at run speed: short into the tail pit, east to the lane and up its
	# ramp to the run-in, then the narrow east end and the finish.
	"g3_miss": FRONT + BEND_INSIDE + [
		{"p": Vector2(-60, -98), "hop": true},
		{"p": Vector2(-140, -92.0), "hop": true},
		{"land": Vector2(-168.5, -91.5), "e": Vector2(-162.2, -91.5)},
		{"p": Vector2(-196, -104.5)},
		{"land": Vector2(-210.5, -105.0), "e": Vector2(-204.0, -105.0)},
	] + PUMP_INSIDE + [
		{"p": Vector2(-240.0, -119.0)},
		{"land": Vector2(-240.0, -131.2), "e": Vector2(-240.0, -126.4), "miss": true},
		{"p": Vector2(-226.0, -136.3)},
		{"p": Vector2(-226.0, -119.0)},
		{"p": Vector2(-226.0, -115.5)},
		{"p": Vector2(-231.0, -115.0)},
		{"p": Vector2(-230.0, -120.0)},
	] + TAIL_EAST,
	# vanilla attempt, kept as the record of its limit: the valve bend's 6.4 m outside gaps as
	# long jumps (run up, strafe in the air), then the basic line. it lands short of the first
	# (trial 34): from the 250 u/s ground clamp and the 275 u/s take-off clamp a flat jump
	# covers about 5.3 m, and the gap asks about 5.9 m of flight past the hull.
	"advanced_vanilla": FRONT + [
		{"p": Vector2(3.42, -87.80)},
		{"land": Vector2(-3.0, -96.0), "e": Vector2(2.67, -90.08), "vt": 600.0},
		{"p": Vector2(-4.15, -97.73)},
		{"land": Vector2(-13.43, -101.52), "e": Vector2(-5.81, -99.51), "vt": 600.0},
		{"p": Vector2(-60, -98), "hop": true},
		{"p": Vector2(-140, -92.0), "hop": true},
		{"land": Vector2(-168.5, -91.5), "e": Vector2(-162.2, -91.5)},
		{"p": Vector2(-196, -104.5)},
		{"land": Vector2(-210.5, -105.0), "e": Vector2(-204.0, -105.0)},
	] + BACK_BASIC,
}

## routes whose stop-log nodes from an index on strafe for speed up to vt in the air
## (the shared FRONT holds speed): route -> [first node, vt].
const STRAFE_FRONT := {"advanced": [9, 400.0]}

var opts := {}
var lab: Node3D
var level: Node3D
var player: CharacterBody3D
var source := false
var hz := 120
var nodes: Array = []
var node_index := 0
var node_from := Vector2.ZERO
var step := 0
## p / settle steps before tape tick 0, by default the step momentum-tape.py run --warmup 32
## arms on: the first process frame at or after step 32 under its --fixed-fps 30, which is
## step 33 at 128 hz and step 32 at 64 hz (read from its traces). off by one, the resting
## hull's 2 mm bob starts in the other phase and a replay drifts by millimetres.
var warmup := 32
const EXECUTOR_ARM_STEP := {128: 33, 64: 32}
var armed := false
var arm_step := 0
var done := false
var held := {}
var events: Array = []
var trace_lines := PackedStringArray()
var out_dir := ""
var max_ticks := 12000
var turn_cap := 0.0
var amp := 0.0
var radians_per_count := 0.0022
var jump_wait := false
var airborne_seen := false
var flight_side := 1.0
var pressed_tick := -100
var land_y := 0.0
var finish_tick := -1
var min_y := INF
var max_speed := 0.0
var node_ticks: Array = []
var checkpoint_ticks: Array = []
var last_checkpoint := -1
var hops: Array = []
var wall_ticks := 0
var wall_bodies := {}
var supports: Array = []
## every flight from one support piece to another: the honest record of which deck it left
## and which it reached (the lab's gap labels only match flights near a declared line).
var flights: Array = []
var flight: Dictionary = {}
var ground_piece := ""
## grounded ticks whose feet sat more than 3 cm below the face under the hull, by piece.
var sinks := {}
var replay: Dictionary = {}
var replay_keys := {}
var replay_mouse := {}
var tick_mouse := 0.0
var ground_ticks := 0
var hops_left := 1
var hop_win := 0.0
var missed := {}
var hop_aim := Vector2.ZERO

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
	max_ticks = int(opts.get("max-ticks", "12000"))
	amp = deg_to_rad(float(opts.get("amp", "30")))
	lab = LAB.Lab.new()
	lab.name = "PracticeLab"
	lab.set("set_window_title", false)
	if opts.has("runner"):
		lab.set("runner_path", str(opts.runner))
	if opts.has("preset"):
		lab.set("motor", str(opts.preset))
	root.add_child(lab)
	level = lab.get("level")
	player = lab.get("player")
	source = "settings" in player and (player.get("settings") as Dictionary).has("sv_airaccelerate")
	hz = Engine.physics_ticks_per_second
	# the runner has set the engine rate by now.
	warmup = int(opts.get("warmup", str(EXECUTOR_ARM_STEP.get(hz, 32))))
	if "tape_radians_per_count" in player:
		radians_per_count = float(player.get("tape_radians_per_count"))
	elif "mouse_sensitivity" in player:
		radians_per_count = float(player.get("mouse_sensitivity"))
	# p / a human turn-rate cap: 600 deg/s by default, as a per-tick limit at the actual rate.
	turn_cap = deg_to_rad(float(opts.get("turn-cap", "600"))) / hz
	if opts.has("tape"):
		_load_tape(str(opts.tape))
	else:
		var route := str(opts.get("route", "basic"))
		assert(ROUTES.has(route), "practice driver: unknown route " + route)
		nodes = []
		for i: int in (ROUTES[route] as Array).size():
			var node: Dictionary = (ROUTES[route][i] as Dictionary).duplicate()
			if STRAFE_FRONT.has(route) and i >= int(STRAFE_FRONT[route][0]) and i < FRONT.size():
				node["vt"] = float(STRAFE_FRONT[route][1])
			nodes.append(node)
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("practice driver: %s route=%s runner=%s hz=%d geometry=%s turn_cap=%.0f deg/s amp=%.0f deg" % ["OPEN LOOP tape" if not replay.is_empty() else "CLOSED LOOP", opts.get("route", replay.get("name", "")), lab.get("runner_label"), hz,
		str(level.call("geometry_hash")).left(12), rad_to_deg(turn_cap * hz), rad_to_deg(amp)])

func _load_tape(path: String) -> void:
	replay = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(int(replay.get("version", 0)) == 2 and int(replay.physics_hz) == hz, "practice driver: tape is not version 2 at the engine's %d hz" % hz)
	for event: Dictionary in replay.events:
		var t := int(event.tick)
		if event.has("key"):
			if not replay_keys.has(t):
				replay_keys[t] = []
			replay_keys[t].append(event)
		else:
			replay_mouse[t] = float(event.mouse[0]) + float(replay_mouse.get(t, 0.0))
	max_ticks = int(replay.duration_ticks)

## after motor step `step`: observe it, then send the input the runner reads on the next step.
## events sent here belong to tape tick step - arm_step; the observed step is that tick - 1.
func late_step() -> void:
	if player == null or done:
		return
	step += 1
	if not armed:
		if step < warmup:
			return
		armed = true
		arm_step = step
	var tick := step - arm_step
	tick_mouse = 0.0
	if tick > 0:
		_observe(tick - 1)
	if done:
		return
	if tick >= max_ticks or _route_finished(tick):
		_end("finished" if finish_tick >= 0 else ("route_done" if node_index >= nodes.size() and replay.is_empty() else ("tape_done" if not replay.is_empty() else "budget")), tick)
		return
	if not replay.is_empty():
		for event: Dictionary in replay_keys.get(tick, []):
			_key(str(event.key), str(event.edge) == "press", tick)
		if replay_mouse.has(tick):
			_mouse(float(replay_mouse[tick]), tick)
		return
	if source:
		_control_source(tick)
	else:
		_control_legacy(tick)

func _route_finished(tick: int) -> bool:
	if not replay.is_empty():
		return false
	if node_index < nodes.size():
		return false
	return finish_tick >= 0 or tick > (int(node_ticks[-1].tick) if not node_ticks.is_empty() else 0) + hz

# --- observation ---------------------------------------------------------------------------

func _observe(tick: int) -> void:
	var p := player.global_position
	var speed := float(lab.get("display_speed"))
	var grounded: bool = player.call("is_grounded")
	ground_ticks = ground_ticks + 1 if grounded else 0
	min_y = minf(min_y, p.y)
	max_speed = maxf(max_speed, speed)
	var cp := int(lab.get("checkpoint_index"))
	if cp != last_checkpoint:
		checkpoint_ticks.append({"checkpoint": cp, "tick": tick, "elapsed": snappedf(float(lab.get("elapsed")), 0.001)})
		last_checkpoint = cp
	if bool(lab.get("finished")) and finish_tick < 0:
		finish_tick = tick
	var state: Dictionary = player.call("get_motion_state") if player.has_method("get_motion_state") else {}
	var wall := false
	for contact: Dictionary in state.get("contacts", []):
		var body := level.get_node_or_null(NodePath(str(contact.body)))
		if body != null and str(body.get_meta("surface", "")) == "wall":
			wall = true
			wall_bodies[str(contact.body)] = int(wall_bodies.get(str(contact.body), 0)) + 1
	wall_ticks += 1 if wall else 0
	var evs: Array = state.get("events", [])
	if "land" in evs and not (state.get("last_hop", {}) as Dictionary).is_empty():
		var hop: Dictionary = state.last_hop
		hops.append({"tick": tick, "takeoff_ups": snappedf(float(hop.takeoff), 0.01), "landing_ups": snappedf(float(hop.landing), 0.01), "gain_ups": snappedf(float(hop.gain), 0.01),
			"air_ticks": hop.air_ticks, "sync": snappedf(float(hop.sync), 0.001) if hop.sync != null else null, "at": _v(p)})
	if grounded:
		var support := _support(p)
		# p / a grounded hull's feet below the face under its centre: sunk into the deck (a
		# box on a slope rests up to half its width times the slope above it, never below).
		var under := _ground_hit(p)
		var sink := float(under.position.y) - p.y if not under.is_empty() else 0.0
		if sink > 0.03:
			var entry: Dictionary = sinks.get(support, {"ticks": 0, "max_m": 0.0, "first_tick": tick, "at": _v(p)})
			entry.ticks = int(entry.ticks) + 1
			if sink > float(entry.max_m):
				entry.max_m = snappedf(sink, 0.001)
				entry.at = _v(p)
			sinks[support] = entry
		if supports.is_empty() or supports[-1].piece != support:
			supports.append({"piece": support, "tick": tick})
		if not flight.is_empty():
			flight.merge({"to": _v(p), "to_piece": support, "land_tick": tick, "landing_ups": snappedf(Vector2(player.velocity.x, player.velocity.z).length() / U, 0.1)})
			if str(flight.to_piece) != str(flight.from_piece):
				flights.append(flight)
			flight = {}
		ground_piece = support
	elif flight.is_empty():
		flight = {"from": _v(p), "from_piece": ground_piece, "tick": tick, "takeoff_ups": snappedf(Vector2(player.velocity.x, player.velocity.z).length() / U, 0.1)}
	var keys := ""
	for key: String in KEY_ORDER:
		if held.has(key):
			keys += "j" if key == "space" else key
	trace_lines.append(JSON.stringify({"t": tick, "p": _v(p), "v": _v(player.velocity / U), "spd": snappedf(speed / U, 0.01), "g": grounded, "k": keys,
		"yaw": snappedf(float(player.get("yaw")), 0.000001), "st": snappedf(float(state.get("stamina", 0.0)), 0.01), "cp": cp, "n": node_index, "e": evs, "wall": wall, "resp": lab.get("respawn_count")}))

func _support(p: Vector3) -> String:
	var hit := _ground_hit(p)
	return str((hit.collider as Node).name) if not hit.is_empty() else ""

## the face under the hull's centre, looked for from 0.6 m above the feet so a hull sunk into
## the deck still finds the deck it sank into.
func _ground_hit(p: Vector3) -> Dictionary:
	return player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p + Vector3.DOWN * 0.6))

# --- source control ------------------------------------------------------------------------

func _control_source(tick: int) -> void:
	if node_index >= nodes.size():
		_want({}, tick)
		return
	var node: Dictionary = nodes[node_index]
	var p := player.global_position
	var here := Vector2(p.x, p.z)
	var grounded: bool = player.call("is_grounded")
	var autohop := bool((player.get("settings") as Dictionary).sv_autobunnyhopping)
	var want := {}
	var target: Vector2 = node.land if node.has("land") else node.p
	if node.has("land"):
		if jump_wait:
			if not grounded:
				airborne_seen = true
			elif airborne_seen:
				jump_wait = false
				airborne_seen = false
				var short := bool(node.get("fit", false)) and here.distance_to(target) > maxf(float(node.get("win", 0.0)) + 2.0, 0.6 * _reach(float(node.get("drop", 0.0)))) and (target - here).dot(target - node_from) > 0.0
				if hops_left > 1 or short:
					# a fit node's intermediate hop, or one that fell short: chain again toward it.
					_control_source(tick)
					return
				_next(here, tick)
				if p.y < land_y - 1.0 and not bool(node.get("miss", false)):
					missed = {"node": node_index - 1, "tick": tick, "at": _v(p), "support": _support(p)}
					_end("missed", tick + 1)
					return
				if node_index < nodes.size() and bool(node.get("chain", false)):
					# a chained landing goes straight into the next node's jump.
					_control_source(tick)
					return
				_want({}, tick)
				return
			if not grounded:
				want = _air(here, hop_aim if bool(node.get("fit", false)) else target, float(node.get("vt", 0.0)), true)
			else:
				# still on the deck after pressing: keep running at the target.
				want = {"w": true}
				_look(here, target)
			_want(want, tick)
			return
		if not grounded:
			# falling into this node's take-off (a previous chain): steer only.
			_want(_air(here, target, float(node.get("vt", 0.0)), false), tick)
			return
		var after: Dictionary = nodes[node_index + 1] if node_index + 1 < nodes.size() else {}
		# "clear": the first point past the next gap's landing edge that serves as a landing.
		var direct := after.has("land") and _reach(float(after.get("drop", 0.0))) >= here.distance_to(after.get("clear", after.land)) + 1.0
		if bool(node.get("fit", false)) and (here.distance_to(target) <= float(node.get("win", 0.0)) + 0.5 or direct):
			# already standing in the window (a hop that began under the previous node), or the
			# gap after it is in reach from here: the approach hop is not needed.
			_next(here, tick)
			_control_source(tick)
			return
		var reach := _reach(float(node.get("drop", 0.0)))
		var edge: Vector2 = node.e
		var along := (target - edge).normalized()
		var to_edge := (edge - here).dot(along)
		var distance := here.distance_to(target)
		var ahead := p + Vector3(player.velocity.x, 0, player.velocity.z) * (2.0 / hz) + Vector3.UP * 0.3
		var under := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3.DOWN * 0.7))
		want = {"w": true}
		_look(here, target)
		var chained := ground_ticks <= 1 and bool(node.get("chain", false))
		if reach >= distance or to_edge <= 0.05 or under.is_empty() or chained:
			want["space"] = true
			jump_wait = true
			# p / a fit node splits the distance left into whole hops at the take-off speed (a hop
			# can stretch about a tenth by strafing, and shrink a lot by braking) and aims this
			# one at its share.
			# a window ("win" m before the point) is a landing that serves: any spot from which the
			# next hop still clears. hops are whole: the nearest count for the window's middle.
			var win := float(node.get("win", 0.0))
			hops_left = maxi(1, roundi((distance - win * 0.5) / maxf(reach, 0.1))) if bool(node.get("fit", false)) else 1
			hop_aim = here + (target - here) / hops_left
			hop_win = win if hops_left == 1 else 0.25 * reach
			airborne_seen = false
			land_y = p.y - float(node.get("drop", 0.0))
			flight_side = 0.0
		elif reach > distance + float(node.get("over", 99.0)):
			# overshoot: let ground friction take speed off before the edge.
			want.erase("w")
		_want(want, tick)
		return
	if node.has("fall"):
		if grounded and p.y < float(node.fall):
			_next(here, tick)
			_want({}, tick)
			return
		want = {"w": true} if grounded else _air(here, target, 0.0, false)
		if grounded:
			_look(here, target)
		_want(want, tick)
		return
	var dir := (target - node_from).normalized() if target.distance_to(node_from) > 0.01 else Vector2.ZERO
	if here.distance_to(target) < float(node.get("r", 1.2)) or (dir != Vector2.ZERO and (here - target).dot(dir) > 0.0):
		_next(here, tick)
		_control_source(tick)
		return
	if bool(node.get("hop", false)):
		if grounded:
			want = {"w": true}
			_look(here, target)
			var speed_u := Vector2(player.velocity.x, player.velocity.z).length() / U
			# p / the first jump of a chain leaves at run speed; later ones on the first ground tick.
			if speed_u >= float(node.get("runup", 240.0)) or (ground_ticks <= 1 and speed_u >= 200.0):
				want["space"] = true
				land_y = p.y
				flight_side = 0.0
		else:
			want = _air(here, target, float(node.get("vt", 0.0)), false)
			if autohop and Vector2(player.velocity.x, player.velocity.z).length() / U >= 200.0:
				want["space"] = true
		_want(want, tick)
		return
	if grounded:
		want = {"w": true}
		_look(here, target)
	else:
		want = _air(here, target, 0.0, false)
	_want(want, tick)

## air control toward `aim` at speed target vt (u/s): a/d with the mouse at the best wish
## angle for the side, alternating round the wanted heading while below vt, else only
## correcting the heading. near the landing it lets go of everything.
func _air(here: Vector2, aim: Vector2, vt_in: float, landing: bool) -> Dictionary:
	var settings: Dictionary = player.get("settings")
	var state: Dictionary = player.call("get_motion_state")
	var h := Vector3(player.velocity.x, 0, player.velocity.z) / U
	var speed := h.length()
	var to := aim - here
	var vt := vt_in
	if speed < 1.0 or to.length() < 0.05:
		return {}
	var heading := atan2(-h.x, -h.z)
	var wanted := atan2(-to.x, -to.y)
	var error := wrapf(wanted - heading, -PI, PI)
	if landing:
		var vy := player.velocity.y
		var height := player.global_position.y - land_y
		var g := float(settings.sv_gravity) * U
		var t_land := (vy + sqrt(maxf(0.0, vy * vy + 2.0 * g * height))) / g
		if t_land < float(nodes[node_index].get("coast", 0.1)):
			_turn_to(wanted)
			return {}
	var side := flight_side
	if landing and bool(nodes[node_index].get("fit", false)):
		# land at the target: predicted straight-line landing against the distance left.
		var vy := player.velocity.y
		var g := float(settings.sv_gravity) * U
		var t_land := (vy + sqrt(maxf(0.0, vy * vy + 2.0 * g * (player.global_position.y - land_y)))) / g
		var predicted := speed * U * t_land
		var left := to.length()
		if opts.has("debug"):
			print("fit n=%d spd=%.0f pred=%.2f left=%.2f err=%.1f vy=%.2f h=%.2f" % [node_index, speed, predicted, left, rad_to_deg(error), vy, player.global_position.y - land_y])
		# one tick of s takes up to the full air budget off; never brake below the distance.
		var brake := minf(MOTION.air_budget(float(settings.player_maxspeed), settings, 1.0 / hz, float(state.air_surface)), speed + float(settings.sv_air_max_wishspeed))
		if predicted > left + float(nodes[node_index].get("over", 0.5)) and (speed - brake) * U * t_land >= left - hop_win and absf(error) < deg_to_rad(60.0):
			# p / long: one tick of s, looking along the travel, takes speed straight off.
			flight_side = 0.0
			_turn_to(heading)
			return {"s": true}
		if predicted > left - hop_win - 0.3:
			vt = 0.0
	if speed < vt:
		if side == 0.0:
			side = -1.0 if error > 0.0 else 1.0
		elif side < 0.0 and error < -amp:
			side = 1.0
		elif side > 0.0 and error > amp:
			side = -1.0
	elif absf(error) > deg_to_rad(4.0):
		side = -1.0 if error > 0.0 else 1.0
	else:
		flight_side = 0.0
		_turn_to(wanted)
		return {}
	flight_side = side
	var dt := 1.0 / hz
	var c := float(settings.sv_air_max_wishspeed)
	var b := minf(MOTION.air_budget(float(settings.player_maxspeed), settings, dt, float(state.air_surface)), c)
	var along := h / speed
	var dir := along if speed < c - b else along.rotated(Vector3.UP, -side * acos(clampf((c - b) / speed, -1.0, 1.0)))
	var yaw_after := _turn_to(MOTION.yaw_for_side(dir, side))
	# p / no overstrafe: while the view still lags its target, the key waits for any tick
	# whose wish would point behind the travel (a speed loss a player avoids too).
	if (MOTION.right_of(yaw_after) * side).dot(along) < -0.035:
		return {}
	return {"a": true} if side < 0.0 else {"d": true}

## flight reach on a jump now: actual horizontal speed (clamped as the profile clamps it at
## take-off) times the flight time of the impulse the current stamina leaves.
func _reach(drop: float) -> float:
	var settings: Dictionary = player.get("settings")
	var state: Dictionary = player.call("get_motion_state")
	var speed := Vector2(player.velocity.x, player.velocity.z).length() / U
	if not bool(settings.sv_enablebunnyhopping):
		speed = minf(speed, float(settings.jump_clamp_factor) * float(settings.player_maxspeed))
	var stamina := maxf(0.0, float(state.stamina) - float(settings.sv_staminarecoveryrate) / hz)
	var impulse := float(settings.sv_jump_impulse) * MOTION.stamina_factor(stamina, settings)
	var g := float(settings.sv_gravity)
	var t := (impulse + sqrt(impulse * impulse + 2.0 * g * drop / U)) / g
	return speed * t * U

## turn the view toward a yaw, at most turn_cap this tick; returns the yaw it leaves.
func _turn_to(yaw_target: float) -> float:
	var error := wrapf(float(player.get("yaw")) - yaw_target, -PI, PI)
	var turn := clampf(error, -turn_cap, turn_cap)
	if absf(turn) > 1e-6:
		_mouse(turn / radians_per_count, -1)
	return float(player.get("yaw"))

## on the ground: proportional, rate limited, like a hand on a mouse.
func _look(here: Vector2, target: Vector2) -> void:
	var to := target - here
	if to.length() < 0.05:
		return
	var desired := atan2(-to.x, -to.y)
	var error := wrapf(float(player.get("yaw")) - desired, -PI, PI)
	var turn := clampf(error * 0.4, -turn_cap, turn_cap)
	if absf(turn) > 1e-6:
		_mouse(turn / radians_per_count, -1)

## space: autohop profiles hold it while wanted; press-edge profiles release it the tick
## after a press, so the next wanted press is a fresh edge.
func _want(want: Dictionary, tick: int) -> void:
	var autohop := source and bool((player.get("settings") as Dictionary).sv_autobunnyhopping)
	if want.has("space") and held.has("space") and tick - pressed_tick >= 1 and not autohop:
		want.erase("space")
	for key: String in KEY_ORDER:
		var on := want.has(key)
		if on != held.has(key):
			_key(key, on, tick)
			if key == "space" and on:
				pressed_tick = tick

func _next(here: Vector2, tick: int) -> void:
	node_ticks.append({"node": node_index, "tick": tick, "p": _v(player.global_position), "speed_ups": snappedf(Vector2(player.velocity.x, player.velocity.z).length() / U, 0.01)})
	node_index += 1
	node_from = here
	flight_side = 0.0

# --- r13 stand-in control (labelled comparison only) -----------------------------------------

func _control_legacy(tick: int) -> void:
	if node_index >= nodes.size():
		_want({}, tick)
		return
	var node: Dictionary = nodes[node_index]
	var p := player.global_position
	var here := Vector2(p.x, p.z)
	var grounded: bool = player.call("is_grounded")
	var want := {"w": true}
	var target: Vector2 = node.land if node.has("land") else node.p
	if node.has("land"):
		if jump_wait:
			if not grounded:
				airborne_seen = true
			elif airborne_seen:
				jump_wait = false
				_next(here, tick)
				if p.y < land_y - 1.0 and not bool(node.get("miss", false)):
					missed = {"node": node_index - 1, "tick": tick, "at": _v(p), "support": _support(p)}
					_end("missed", tick + 1)
					return
			_look(here, target)
			_want(want, tick)
			return
		var flight := (float(LEVEL.VANILLA.jump_ups) + sqrt(pow(float(LEVEL.VANILLA.jump_ups), 2) + 2.0 * float(LEVEL.VANILLA.gravity_ups) * float(node.get("drop", 0.0)) / U)) / float(LEVEL.VANILLA.gravity_ups)
		var reach := Vector2(player.velocity.x, player.velocity.z).length() * flight
		var edge: Vector2 = node.e
		if grounded and (here.distance_to(target) <= reach or (edge - here).dot((target - edge).normalized()) <= 0.05):
			want["space"] = true
			jump_wait = true
			airborne_seen = false
			land_y = p.y - float(node.get("drop", 0.0))
		_look(here, target)
		_want(want, tick)
		return
	if node.has("fall"):
		if grounded and p.y < float(node.fall):
			_next(here, tick)
	elif here.distance_to(target) < float(node.get("r", 1.2)):
		_next(here, tick)
	_look(here, target)
	_want(want, tick)

# --- input ---------------------------------------------------------------------------------

func _key(key: String, pressed: bool, tick: int) -> void:
	if pressed == held.has(key):
		return
	var event := InputEventKey.new()
	event.keycode = KEYS[key]
	event.physical_keycode = KEYS[key]
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed:
		held[key] = true
	else:
		held.erase(key)
	events.append({"tick": tick, "key": key, "edge": "press" if pressed else "release"})

## relative mouse counts, delivered as one float32 event; the applied value is what the tape
## records, at full precision.
func _mouse(px: float, _tick: int) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(px, 0.0)
	motion.screen_relative = motion.relative
	if motion.relative.x == 0.0:
		return
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	tick_mouse += motion.relative.x
	var tick := step - arm_step
	if not events.is_empty() and events[-1].has("mouse") and int(events[-1].tick) == tick:
		events[-1].mouse[0] = float(events[-1].mouse[0]) + motion.relative.x
	else:
		events.append({"tick": tick, "mouse": [motion.relative.x, 0.0]})

# --- end -------------------------------------------------------------------------------------

func _end(reason: String, tick: int) -> void:
	done = true
	for key: String in held.keys():
		_key(key, false, tick)
	var sources := {}
	for path: String in SOURCES:
		sources[path] = FileAccess.get_sha256(path)
	sources[str(lab.get("runner_path"))] = FileAccess.get_sha256(str(lab.get("runner_path")))
	var jumps: Array = []
	for jump: Dictionary in lab.get("jumps"):
		jumps.append({"from": _v(jump.from), "to": _v(jump.to), "distance_m": snappedf(jump.distance_m, 0.001), "distance_u": roundi(jump.distance_u),
			"takeoff_ups": roundi(jump.takeoff_ups), "landing_ups": roundi(jump.landing_ups), "air_s": snappedf(jump.air_s, 0.001), "gap": jump.gap, "surface": jump.surface})
	var final := player.global_position
	var mode := "OPEN LOOP replay of a fixed tape: no state was read to choose input" if not replay.is_empty() else "CLOSED LOOP state-aware execution proof; not imperfect input, not discovery"
	var summary := {"label": mode + ("" if source else "; R13 stand-in policy (W held, mouse steering), NOT Source"),
		"reason": reason, "route": opts.get("route", ""), "tape": opts.get("tape", ""), "runner": lab.get("runner_path"), "runner_label": lab.get("runner_label"),
		"preset": (player.get("settings") as Dictionary).get("preset", "") if source else "", "physics_hz": hz, "engine_hz": Engine.physics_ticks_per_second,
		"turn_cap_deg_s": snappedf(rad_to_deg(turn_cap * hz), 0.1), "amp_deg": snappedf(rad_to_deg(amp), 0.1), "warmup_steps": warmup,
		"level_id": level.get("level_id"), "level_version": level.get("level_version"), "geometry_hash": level.call("geometry_hash"), "sources_sha256": sources,
		"ticks": tick, "finish_tick": finish_tick, "finish_time_s": lab.get("elapsed") if finish_tick >= 0 else null, "finish_kind": lab.get("finish_kind"),
		"respawns": lab.get("respawn_count"), "checkpoints": checkpoint_ticks, "nodes_reached": node_ticks.size(), "nodes": nodes.size(), "node_ticks": node_ticks,
		"min_y": snappedf(min_y, 0.001), "max_display_speed_ups": snappedf(max_speed / U, 0.1), "missed": missed, "wall_contact_ticks": wall_ticks, "wall_bodies": wall_bodies,
		"hops": hops, "jumps": jumps, "flights": flights, "sinks": sinks, "supports": supports, "final": _v(final), "final_support": _support(final), "events": events.size(),
		"setup_writes": ["lab._ready -> restart(): the lab's own pose reset at the gatehouse"]}
	_write("summary.json", summary)
	var tape := {"format": "spillway-momentum-tape", "version": 2, "name": "r14-practice-%s-%s" % [opts.get("route", "tape"), summary.preset],
		"description": "%s; driver-applied events, physics tick %d Hz, warmup %d steps" % [mode, hz, warmup], "physics_hz": hz, "input_profile": "physics_tick",
		"duration_ticks": tick + 1, "duration_s": float(tick + 1) / hz, "mouse_quantize": "float32", "events": events}
	var file := FileAccess.open(out_dir.path_join("events.tape.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(tape, " ", false, true))
	file.close()
	file = FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(trace_lines) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("practice driver: %s finish=%s time=%s kind=%s respawns=%s nodes=%d/%d min_y=%.2f max=%.0f u/s walls=%d final=%s on %s jumps=%d" % [reason, finish_tick, summary.finish_time_s, summary.finish_kind,
		summary.respawns, node_ticks.size(), nodes.size(), min_y, max_speed / U, wall_ticks, final, summary.final_support, jumps.size()])
	quit(0)

func _write(name: String, data: Variant) -> void:
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, " "))
	file.close()

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]

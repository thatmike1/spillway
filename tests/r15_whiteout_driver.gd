extends "res://tests/r14_practice_driver.gd"
## p / Whiteout Relay route driver on the actual r15 main. CLOSED LOOP, STATE AWARE: an execution
## proof that a line exists for the approved source runner with real crouch, not imperfect play
## and not discovery. it builds r15_main.gd on the registry's `whiteout-relay` map, lets the
## main's own restart_run() place the runner at the labelled hangar spawn, and after that writes
## no pose, velocity, camera or progress: it reads the runner and answers with key edges (w a s d
## space ctrl) and relative mouse counts, saved as a version 2 tape at the runner's actual rate.
## --tape= plays a tape back OPEN LOOP: the same events on the same ticks, no state read.
## the controller is r14_practice_driver.gd's, unchanged; this adds the routes, two node kinds
## ("respawn": run off an edge until the main respawns the runner; "duckjump": a jump timed to
## the gantry face with crouch pressed in flight and released on landing) and the summary.
## each trace row keeps the raw feet (`p`), the runner's cumulative duck compensation (`comp`,
## u) and the main's body reference (`ref`) apart.
##
## godot --headless --audio-driver Dummy --path . --script res://tests/r15_whiteout_driver.gd --
##   --out=DIR --route=NAME [--preset=server128|server128_aa1000] [--turn-cap=DEG_PER_S] [--tape=PLAN.json]

const MAIN := preload("res://scripts/r15_main.gd")
const REGISTRY := preload("res://scripts/r15_presets.gd")
const MAP_ID := "whiteout-relay"
const WO_SOURCES := ["res://scripts/r15_whiteout_level.gd", "res://scripts/r15_whiteout_art.gd", "res://tests/r15_whiteout_driver.gd",
	"res://tests/r14_practice_driver.gd", "res://scripts/r15_main.gd", "res://scripts/r15_presets.gd", "res://scripts/r15_maps.gd",
	"res://scripts/r15_source_player.gd", "res://scripts/r14_source_player.gd", "res://scripts/r14_source_motion.gd"]

## route nodes, world (x, z), with r14_practice_driver.gd's meanings: land/e/drop/chain/fit/vt/hop/p.
## stage 0: out of the hangar, over the two hurdles and the two trenches, to the ridge foot.
const HANGAR := [{"p": Vector2(0.0, -34.0)}]
const ROAD := [
	{"land": Vector2(0.0, -58.5), "e": Vector2(0.0, -54.4)},
	{"land": Vector2(0.0, -70.5), "e": Vector2(0.0, -66.4)},
	{"land": Vector2(0.0, -84.0), "e": Vector2(0.0, -79.6)},
	{"land": Vector2(0.0, -101.0), "e": Vector2(0.0, -94.6)},
	{"p": Vector2(0.0, -117.0)},
]
## stage 1: the four pylons and the saddle, each 0.4 m up (drop -0.4).
const PYLONS := [
	{"land": Vector2(-1.2, -129.0), "e": Vector2(-0.6, -123.6), "drop": -0.4},
	{"land": Vector2(1.2, -137.5), "e": Vector2(-0.6, -131.6), "drop": -0.4},
	{"land": Vector2(-1.2, -146.5), "e": Vector2(0.6, -140.1), "drop": -0.4},
	{"land": Vector2(1.2, -155.5), "e": Vector2(-0.6, -149.1), "drop": -0.4},
	{"land": Vector2(0.5, -165.0), "e": Vector2(0.6, -158.1), "drop": -0.4},
]
## the pylons on the earned line: the same take-offs, strafing in the air for speed.
const PYLONS_FAST := [
	{"land": Vector2(-1.2, -129.0), "e": Vector2(-0.6, -123.6), "drop": -0.4, "vt": 3000.0},
	{"land": Vector2(1.2, -137.5), "e": Vector2(-0.6, -131.6), "drop": -0.4, "vt": 3000.0},
	{"land": Vector2(-1.2, -146.5), "e": Vector2(0.6, -140.1), "drop": -0.4, "vt": 3000.0},
	{"land": Vector2(1.2, -155.5), "e": Vector2(-0.6, -149.1), "drop": -0.4, "vt": 3000.0},
	{"land": Vector2(0.5, -165.0), "e": Vector2(0.6, -158.1), "drop": -0.4, "vt": 3000.0},
]
## stage 2, ordinary: the service catwalk round the chasm, run without hops between the rails.
const CATWALK := [
	{"p": Vector2(-2.0, -172.0)},
	{"p": Vector2(-17.0, -172.0)},
	{"p": Vector2(-17.0, -198.0)},
	{"p": Vector2(-6.0, -198.0)},
]
## stage 2, earned: line-up hops strafed down the saddle into a window at the lip, then the
## 6.5 m chasm 1 m down.
const CHASM := [
	{"land": Vector2(0.0, -176.2), "e": Vector2(0.0, -176.6), "chain": true, "fit": true, "win": 0.8, "vt": 3000.0},
	{"land": Vector2(0.0, -189.0), "e": Vector2(0.0, -176.9), "clear": Vector2(0.0, -184.5), "drop": 1.0, "chain": true, "vt": 0.0},
]
## stage 3: round the receiver deck's middle (r 22), hopping.
const RING := [
	{"p": Vector2(-0.48, -199.71), "hop": true},
	{"p": Vector2(6.44, -209.43), "hop": true},
	{"p": Vector2(16.31, -205.25), "hop": true},
	{"p": Vector2(27.69, -204.75), "hop": true},
	{"p": Vector2(37.56, -199.06), "hop": true},
	{"p": Vector2(42.67, -190.18), "hop": true},
	{"p": Vector2(44.5, -183.0), "hop": true},
]
## the earned line round the deck: the same middle points, strafing up to 420 u/s.
const RING_FAST := [
	{"p": Vector2(-0.48, -199.71), "hop": true, "vt": 420.0},
	{"p": Vector2(6.44, -209.43), "hop": true, "vt": 420.0},
	{"p": Vector2(16.31, -205.25), "hop": true, "vt": 420.0},
	{"p": Vector2(27.69, -204.75), "hop": true, "vt": 420.0},
	{"p": Vector2(37.56, -199.06), "hop": true, "vt": 420.0},
	{"p": Vector2(42.67, -190.18), "hop": true, "vt": 420.0},
	{"p": Vector2(45.0, -182.0), "hop": true},
]
## stage 4: the drum weave on the shed floor (east, west, east passages), then the relay road.
const WEAVE := [
	{"p": Vector2(49.5, -172.0)},
	{"p": Vector2(49.5, -165.0)},
	{"p": Vector2(44.5, -157.0)},
	{"p": Vector2(44.5, -150.0)},
	{"p": Vector2(49.5, -143.0)},
	{"p": Vector2(49.5, -136.0)},
	{"p": Vector2(45.0, -130.0)},
]
const RELAY := [
	{"land": Vector2(45.0, -104.5), "e": Vector2(45.0, -110.4)},
	{"land": Vector2(45.0, -92.0), "e": Vector2(45.0, -98.0), "drop": -0.8},
	{"land": Vector2(45.0, -84.0), "e": Vector2(45.0, -90.0), "drop": -0.8},
	{"p": Vector2(45.0, -79.0)},
]
## the gantry: run in along x 40, duck-jump the 1.5 m face, run its length, drop off its end.
const GANTRY := [
	{"p": Vector2(40.0, -181.0)},
	{"duckjump": true, "p": Vector2(40.0, -171.0), "face": -177.0},
	{"p": Vector2(40.0, -139.0), "hop": true},
	{"p": Vector2(44.0, -130.0)},
]
## a deliberate miss: pylon 2 pressed from the middle of pylon 1, short into the basin; the walk
## to the lit stair, up to the ridge foot, and the pylons again.
const BASIN_MISS := [
	{"land": Vector2(-1.2, -129.0), "e": Vector2(-0.6, -123.6), "drop": -0.4},
	{"land": Vector2(1.2, -139.5), "e": Vector2(-1.2, -128.4), "drop": -0.4, "miss": true},
	{"p": Vector2(6.0, -135.0)},
	{"p": Vector2(10.5, -135.0)},
	{"p": Vector2(10.5, -119.0)},
	{"p": Vector2(5.0, -115.0)},
	{"p": Vector2(0.0, -118.0)},
]
## a fall off the receiver deck's open outer edge at about 70 degrees, the respawn at the
## receiver checkpoint, and the deck again from there.
const CLOUD_FALL := [
	{"p": Vector2(12.0, -215.0), "respawn": true},
]
var wo_routes := {
	"ordinary": HANGAR + ROAD + PYLONS + CATWALK + RING + WEAVE + RELAY,
	"earned": HANGAR + ROAD + PYLONS_FAST + CHASM + RING_FAST + WEAVE + RELAY,
	"gantry": HANGAR + ROAD + PYLONS + CATWALK + RING.slice(0, 6) + GANTRY + RELAY,
	"basin_recovery": HANGAR + ROAD + BASIN_MISS + PYLONS + CATWALK + RING + WEAVE + RELAY,
	"cloud_recovery": HANGAR + ROAD + PYLONS + CATWALK + RING.slice(0, 2) + CLOUD_FALL + RING.slice(1) + WEAVE + RELAY,
}

var game: Node3D
var respawns_seen := 0
var respawn_events: Array = []
var ducks: Array = []
var duck_jumped := false
var duck_air := false

func _initialize() -> void:
	var id := "server128"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="):
			id = REGISTRY.resolve(arg.trim_prefix("--preset="))
	Engine.physics_ticks_per_second = int(REGISTRY.entry(id).rate)
	super._initialize()

func _start() -> void:
	max_ticks = int(opts.get("max-ticks", "24000"))
	amp = deg_to_rad(float(opts.get("amp", "30")))
	game = MAIN.new()
	game.name = "R15"
	game.set("motor", str(opts.get("preset", "server128")))
	game.set("map_id", MAP_ID)
	game.set("set_window_title", false)
	root.add_child(game)
	# the base controller reads the game through `lab`; r15_main has the same run fields.
	lab = game
	level = game.get("level")
	player = game.get("player")
	assert(str(game.get("map_id")) == MAP_ID and str(level.get("level_id")) == "r15-whiteout-relay", "whiteout driver: the r15 main did not load whiteout-relay")
	source = "settings" in player and (player.get("settings") as Dictionary).has("sv_airaccelerate")
	hz = Engine.physics_ticks_per_second
	warmup = int(opts.get("warmup", str(EXECUTOR_ARM_STEP.get(hz, 32))))
	radians_per_count = float(player.get("tape_radians_per_count"))
	turn_cap = deg_to_rad(float(opts.get("turn-cap", "600"))) / hz
	if opts.has("tape"):
		_load_tape(str(opts.tape))
	else:
		var route := str(opts.get("route", "ordinary"))
		assert(wo_routes.has(route), "whiteout driver: unknown route " + route)
		nodes = []
		for node: Dictionary in wo_routes[route]:
			nodes.append(node.duplicate())
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("whiteout driver: %s route=%s preset=%s hz=%d geometry=%s turn_cap=%.0f deg/s rad/count=%s" % ["OPEN LOOP tape" if not replay.is_empty() else "CLOSED LOOP",
		opts.get("route", replay.get("name", "")), game.get("preset_id"), hz, str(level.call("geometry_hash")).left(12), rad_to_deg(turn_cap * hz), radians_per_count])

## the crouch key joins the base controller's keys as "ctrl", the momentum-tape schema's name for
## it (C is the same action; the checks test that binding); everything else is the base's.
func _key(key: String, pressed: bool, tick: int) -> void:
	if key != "ctrl":
		super._key(key, pressed, tick)
		return
	if pressed == held.has(key):
		return
	var event := InputEventKey.new()
	event.keycode = KEY_CTRL
	event.physical_keycode = KEY_CTRL
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed:
		held[key] = true
	else:
		held.erase(key)
	events.append({"tick": tick, "key": key, "edge": "press" if pressed else "release"})

func _want(want: Dictionary, tick: int) -> void:
	# the base releases every key not wanted; crouch is held only while a duck-jump asks for it.
	var crouch := want.has("ctrl")
	want.erase("ctrl")
	super._want(want, tick)
	if crouch != held.has("ctrl"):
		_key("ctrl", crouch, tick)

func _observe(tick: int) -> void:
	super._observe(tick)
	# raw feet, the runner's own duck compensation and the main's body reference, kept apart.
	var row: Dictionary = JSON.parse_string(trace_lines[-1])
	var comp: Variant = player.get("_duck_compensation_u")
	row["comp"] = _v(comp if comp is Vector3 else Vector3.ZERO)
	row["ref"] = _v(game.call("body_reference"))
	row["duck"] = bool(player.get("ducked"))
	row["c"] = held.has("ctrl")
	trace_lines[-1] = JSON.stringify(row)

func _control_source(tick: int) -> void:
	if node_index < nodes.size() and (nodes[node_index] as Dictionary).has("duckjump"):
		_duck_jump(tick)
		return
	if node_index < nodes.size() and (nodes[node_index] as Dictionary).has("respawn"):
		var node: Dictionary = nodes[node_index]
		var p := player.global_position
		var here := Vector2(p.x, p.z)
		if int(game.get("respawn_count")) > respawns_seen:
			respawns_seen = int(game.get("respawn_count"))
			respawn_events.append({"tick": tick, "checkpoint": int(game.get("checkpoint_index")), "at": _v(p)})
			_next(here, tick)
			_want({}, tick)
			return
		# run at the point and on past it, off the edge; only steer in the air.
		var want := {}
		if player.call("is_grounded"):
			want = {"w": true}
			_look(here, node.p)
		_want(want, tick)
		return
	super._control_source(tick)

## run at the gantry face; jump when the face is a mid-window distance away for the speed (the
## feet must clear 1.5 m while crossing it: a jump with crouch in flight is above 1.27 m from
## 0.245 s to 0.509 s), press crouch in the air, release it on the first ground tick.
func _duck_jump(tick: int) -> void:
	var node: Dictionary = nodes[node_index]
	var p := player.global_position
	var here := Vector2(p.x, p.z)
	var grounded: bool = player.call("is_grounded")
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var face := float(node.face)
	if duck_jumped:
		if not grounded:
			duck_air = true
			_want({"ctrl": true}, tick)
			return
		if duck_air:
			var on_top := p.y > 2.2
			ducks.append({"tick": tick, "landed_on_gantry": on_top, "at": _v(p), "speed_ups": snappedf(speed / U, 0.1)})
			duck_jumped = false
			duck_air = false
			_next(here, tick)
			_want({}, tick)
			return
		_want({"w": true, "ctrl": true}, tick)
		return
	if not grounded:
		_want(_air(here, node.p, 0.0, false), tick)
		return
	var want := {"w": true}
	_look(here, node.p)
	var to_face := absf(face - p.z)
	if to_face <= 0.38 * speed + 0.41 or to_face < 1.0:
		want["space"] = true
		duck_jumped = true
		duck_air = false
		ducks.append({"tick": tick, "takeoff_to_face_m": snappedf(to_face, 0.001), "speed_ups": snappedf(speed / U, 0.1)})
	_want(want, tick)

func _end(reason: String, tick: int) -> void:
	done = true
	for key: String in held.keys():
		_key(key, false, tick)
	var sources := {}
	for path: String in WO_SOURCES:
		sources[path] = FileAccess.get_sha256(path)
	var mode := "OPEN LOOP replay of a fixed tape: no state was read to choose input" if not replay.is_empty() else "CLOSED LOOP state-aware execution proof; not imperfect input, not discovery"
	var final := player.global_position
	var summary := {"label": "P actual R15 main on map whiteout-relay; normal spawn; " + mode,
		"reason": reason, "route": opts.get("route", ""), "tape": opts.get("tape", ""), "preset": game.get("preset_id"), "physics_hz": hz,
		"engine_hz": Engine.physics_ticks_per_second, "runner": (player.get_script() as Script).resource_path, "motor_version": player.get("MOTOR_VERSION"),
		"turn_cap_deg_s": snappedf(rad_to_deg(turn_cap * hz), 0.1), "amp_deg": snappedf(rad_to_deg(amp), 0.1), "warmup_steps": warmup,
		"radians_per_count": radians_per_count, "sensitivity_source_units": (player.get("settings") as Dictionary).get("sensitivity"),
		"sv_airaccelerate": (player.get("settings") as Dictionary).get("sv_airaccelerate"), "sv_air_max_wishspeed": (player.get("settings") as Dictionary).get("sv_air_max_wishspeed"),
		"map_id": game.get("map_id"), "level_id": level.get("level_id"), "level_version": level.get("level_version"), "geometry_hash": level.call("geometry_hash"),
		"record_key": game.get("course_key"), "sources_sha256": sources,
		"ticks": tick, "finish_tick": finish_tick, "finish_time_s": game.get("elapsed") if finish_tick >= 0 else null, "finish_kind": game.get("finish_kind"),
		"clean_eligible": game.get("clean_eligible"), "practice_reason": game.get("practice_reason"),
		"respawns": game.get("respawn_count"), "respawn_events": respawn_events, "checkpoints": checkpoint_ticks, "ducks": ducks,
		"nodes_reached": node_ticks.size(), "nodes": nodes.size(), "node_ticks": node_ticks,
		"min_y": snappedf(min_y, 0.001), "max_display_speed_ups": snappedf(max_speed / U, 0.1), "missed": missed,
		"wall_contact_ticks": wall_ticks, "wall_bodies": wall_bodies, "cast_guards": player.get("cast_guards"), "hops": hops, "flights": flights, "sinks": sinks, "supports": supports,
		"final": _v(final), "final_support": _support(final), "events": events.size(),
		"setup_writes": ["r15_main._ready -> restart_run(): the main's own reset to the level's labelled hangar spawn"]}
	_write("summary.json", summary)
	# p / the strict version 2 schema: radians per count lives in the description and summary only.
	var tape := {"format": "spillway-momentum-tape", "version": 2, "name": "r15-whiteout-%s-%s" % [opts.get("route", "tape"), game.get("preset_id")],
		"description": "%s; driver-applied events on the actual r15 main on whiteout-relay, physics tick %d Hz, warmup %d steps, runner sensitivity %s (%.9f rad per count)" % [mode, hz, warmup,
			(player.get("settings") as Dictionary).get("sensitivity"), radians_per_count],
		"physics_hz": hz, "input_profile": "physics_tick", "duration_ticks": tick + 1, "duration_s": float(tick + 1) / hz, "mouse_quantize": "float32", "events": events}
	var file := FileAccess.open(out_dir.path_join("events.tape.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(tape, " ", false, true))
	file.close()
	file = FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(trace_lines) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("whiteout driver: %s finish=%s time=%s kind=%s respawns=%s nodes=%d/%d min_y=%.2f max=%.0f u/s walls=%d ducks=%s final=%s on %s" % [reason, finish_tick, summary.finish_time_s, summary.finish_kind,
		summary.respawns, node_ticks.size(), nodes.size(), min_y, max_speed / U, wall_ticks, ducks, final, summary.final_support])
	game.call("request_quit", 0)
	quit(0)

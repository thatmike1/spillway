extends "res://tests/r14_practice_driver.gd"
## p / Sunken Court route driver on the actual r15 main. CLOSED LOOP, STATE AWARE: an execution
## proof that a line exists for the approved source runner with real crouch, not imperfect play and
## not discovery. it builds r15_main.gd with map_id "sunken-court", lets the main's own
## restart_run() place the runner at the labelled spawn, and after that writes no pose, velocity,
## camera or progress: it reads the runner and answers with key edges (w a s d space ctrl, the tape executor's names) and
## relative mouse counts, saved as a version 2 tape at the runner's actual rate. --tape= plays a
## tape back open loop. the controller is r14_practice_driver.gd's, unchanged; this adds the
## routes, crouch (Control pressed a few ticks after a "duck" node's take-off, released on the first
## grounded tick of a "stand" node), one node kind ("respawn": run at a point until the main
## respawns the runner) and a trace that keeps the raw feet and the duck compensation apart.
##
## godot --headless --audio-driver Dummy --path . --script res://tests/r15_sunken_driver.gd --
##   --out=DIR --route=NAME [--preset=server128|server128_aa1000] [--turn-cap=DEG_PER_S] [--tape=PLAN.json]

const MAIN := preload("res://scripts/r15_main.gd")
const R15_PRESETS := preload("res://scripts/r15_presets.gd")
const MAP_ID := "sunken-court"
const SK_SOURCES := ["res://scripts/r15_sunken_level.gd", "res://scripts/r15_sunken_art.gd", "res://tests/r15_sunken_driver.gd", "res://tests/r14_practice_driver.gd",
	"res://scripts/r15_main.gd", "res://scripts/r15_presets.gd", "res://scripts/r15_maps.gd", "res://scripts/r15_source_player.gd", "res://scripts/r14_source_player.gd", "res://scripts/r14_source_motion.gd"]

## route nodes, world (x, z), with r14_practice_driver.gd's meanings (land/e/drop/chain/fit/vt/hop/p),
## plus duck (press Control this many ticks after the take-off), stand (release it when grounded) and respawn.
## the gate arch and the three falling steps.
const GATE := [{"p": Vector2(0.0, -4.0)}]
const STEPS := [
	{"land": Vector2(0.0, -19.0), "e": Vector2(0.0, -13.6), "drop": 1.2},
	{"land": Vector2(0.0, -31.5), "e": Vector2(0.0, -25.6), "drop": 1.2},
	{"land": Vector2(0.0, -45.0), "e": Vector2(0.0, -38.1), "drop": 1.2},
]
## the six pavilion tops, each landing near its centre, then the aqueduct head.
const COURT := [
	{"land": Vector2(0.0, -56.6), "e": Vector2(0.0, -51.6), "drop": -0.6},
	{"land": Vector2(-2.5, -64.0), "e": Vector2(-0.6, -58.7), "drop": 0.8},
	{"land": Vector2(-4.5, -71.5), "e": Vector2(-2.9, -66.2), "drop": -0.8},
	{"land": Vector2(-2.5, -79.0), "e": Vector2(-4.0, -73.7), "drop": 0.8},
	{"land": Vector2(0.0, -86.5), "e": Vector2(-1.9, -81.2), "drop": -0.8},
	{"land": Vector2(0.5, -94.0), "e": Vector2(0.1, -88.7), "drop": 0.6},
	{"land": Vector2(0.3, -102.0), "e": Vector2(0.5, -96.2), "drop": -0.6},
]
## round the aqueduct bend on hops, the castellum, and up the leg to the cloister.
const ARC := [
	{"p": Vector2(0.4, -109.0), "hop": true},
	{"p": Vector2(2.6, -117.4), "hop": true},
	{"p": Vector2(8.1, -124.6), "hop": true},
	{"p": Vector2(16.2, -128.4), "hop": true},
	{"p": Vector2(25.0, -127.9), "hop": true},
	{"p": Vector2(33.0, -123.4), "hop": true},
	{"p": Vector2(38.4, -115.0), "hop": true},
	{"p": Vector2(40.0, -106.0), "hop": true},
	{"p": Vector2(40.0, -80.0), "hop": true},
]
## the cloister's walks: east along the south walk, north up the east walk, out of the gate.
const WALKS := [
	{"p": Vector2(41.0, -60.0), "hop": true},
	{"p": Vector2(53.0, -59.0), "hop": true},
	{"p": Vector2(53.5, -38.0), "hop": true},
]
## the fallen architrave, taught line: walk onto the south walk, line up at 2.6 m from the lip and
## jump, crouch 6 ticks into the flight, stand on the first ground tick up there, then hop along
## its diagonal and off its north end by the exit.
const CAUSEWAY := [
	{"p": Vector2(40.0, -60.0)},
	{"p": Vector2(41.4, -61.0)},
	{"land": Vector2(44.5, -50.5), "e": Vector2(41.9, -59.6), "drop": -1.3, "duck": 6},
	{"p": Vector2(48.6, -40.0), "hop": true, "stand": true},
	{"p": Vector2(53.5, -35.5), "hop": true},
]
## the same architrave at hop speed: no stop on the walk, the crouch jump taken out of a hop and
## speed strafed back along its top.
const CAUSEWAY_HOP := [
	{"p": Vector2(41.2, -61.0), "hop": true},
	{"land": Vector2(44.5, -50.5), "e": Vector2(41.9, -59.6), "drop": -1.3, "duck": 6},
	{"p": Vector2(48.6, -40.0), "hop": true, "stand": true, "vt": 340.0},
	{"p": Vector2(53.5, -35.5), "hop": true, "vt": 340.0},
]
const CAUSEWAY_CHAIN := [
	{"p": Vector2(41.0, -63.2), "hop": true},
	{"land": Vector2(44.5, -50.5), "e": Vector2(41.9, -59.6), "drop": -1.3, "duck": 6, "chain": true},
	{"p": Vector2(48.6, -40.0), "hop": true, "stand": true, "vt": 340.0},
	{"p": Vector2(53.5, -35.5), "hop": true, "vt": 340.0},
]
## the rising steps to the sanctuary, west through the arch to the finish band.
const RISE := [
	{"p": Vector2(53.5, -32.0)},
	{"land": Vector2(53.5, -23.0), "e": Vector2(53.5, -28.3), "drop": -0.8},
	{"land": Vector2(53.5, -15.0), "e": Vector2(53.5, -20.3), "drop": -0.8},
	{"land": Vector2(53.5, -7.0), "e": Vector2(53.5, -12.3), "drop": -0.8},
	{"land": Vector2(53.5, 1.5), "e": Vector2(53.5, -4.3), "drop": -0.8},
	{"p": Vector2(51.5, 2.5)},
	{"land": Vector2(43.5, 2.5), "e": Vector2(50.3, 2.5), "drop": -0.8},
	{"land": Vector2(34.0, 3.0), "e": Vector2(39.3, 2.8), "drop": -0.8},
	{"p": Vector2(23.0, 3.0)},
]
## the speed line: strafe for speed through the court, then the cistern towers straight across.
const COURT_FAST := [
	{"land": Vector2(0.0, -56.6), "e": Vector2(0.0, -51.6), "drop": -0.6, "vt": 300.0},
	{"land": Vector2(-2.5, -64.0), "e": Vector2(-0.6, -58.7), "drop": 0.8, "vt": 330.0, "chain": true},
	{"land": Vector2(-4.5, -71.5), "e": Vector2(-2.9, -66.2), "drop": -0.8, "vt": 360.0, "chain": true},
	{"land": Vector2(-2.5, -79.0), "e": Vector2(-4.0, -73.7), "drop": 0.8, "vt": 390.0, "chain": true},
	{"land": Vector2(0.0, -86.5), "e": Vector2(-1.9, -81.2), "drop": -0.8, "vt": 410.0, "chain": true},
	{"land": Vector2(0.5, -94.0), "e": Vector2(0.1, -88.7), "drop": 0.6, "vt": 420.0, "chain": true},
	{"land": Vector2(1.5, -102.0), "e": Vector2(0.5, -96.2), "drop": -0.6, "vt": 420.0, "chain": true},
]
## the head landing bends the line east; one chained hop per tower, then the castellum and the leg.
const CHORD := [
	{"land": Vector2(8.0, -105.5), "e": Vector2(1.5, -102.0), "chain": true, "vt": 420.0},
	{"land": Vector2(16.0, -108.0), "e": Vector2(8.0, -105.5), "chain": true, "vt": 420.0},
	{"land": Vector2(24.0, -109.0), "e": Vector2(16.0, -108.0), "chain": true, "vt": 420.0},
	{"land": Vector2(30.5, -109.0), "e": Vector2(24.0, -109.0), "chain": true, "vt": 420.0},
	{"land": Vector2(38.0, -108.5), "e": Vector2(30.5, -109.0), "chain": true, "vt": 0.0},
	{"p": Vector2(40.0, -100.0), "hop": true},
	{"p": Vector2(40.0, -80.0), "hop": true},
]
## a deliberate short hop off pavilion 1 into the court pool, the walk to the west ramp, up to the
## balcony, and the court again.
const COURT_MISS := [
	{"land": Vector2(0.0, -56.6), "e": Vector2(0.0, -51.6), "drop": -0.6},
	{"land": Vector2(-2.5, -64.5), "e": Vector2(-0.3, -55.0), "drop": 0.8, "miss": true},
	{"p": Vector2(-10.0, -66.0)},
	{"p": Vector2(-10.0, -93.0)},
	{"p": Vector2(-20.0, -97.5)},
	{"p": Vector2(-20.0, -75.0)},
	{"p": Vector2(-20.0, -53.5)},
	{"p": Vector2(-20.0, -48.5)},
	{"p": Vector2(-6.0, -48.5)},
	{"p": Vector2(0.0, -51.0)},
]
## off the head's east edge into the river: the respawn at the aqueduct head, then the bend.
const RIVER := [
	{"p": Vector2(9.0, -104.0), "respawn": true},
]
## a walk into the cistern's west pool from the south walk, up the west ramp, then the walks.
const CISTERN := [
	{"p": Vector2(38.5, -60.5)},
	{"p": Vector2(37.5, -50.0), "fall": 4.0},
	{"p": Vector2(34.5, -42.5)},
	{"p": Vector2(34.5, -59.0)},
	{"p": Vector2(41.0, -60.0)},
]

var sk_routes := {
	"ordinary": GATE + STEPS + COURT + ARC + WALKS + RISE,
	"causeway": GATE + STEPS + COURT + ARC + CAUSEWAY + RISE,
	"causeway_hop": GATE + STEPS + COURT + ARC + CAUSEWAY_HOP + RISE,
	"causeway_chain": GATE + STEPS + COURT + ARC + CAUSEWAY_CHAIN + RISE,
	"earned": GATE + STEPS + COURT_FAST + CHORD + WALKS + RISE,
	"court_recovery": GATE + STEPS + COURT_MISS + COURT + ARC + WALKS + RISE,
	"river_recovery": GATE + STEPS + COURT + RIVER + ARC + WALKS + RISE,
	"cistern_recovery": GATE + STEPS + COURT + ARC + CISTERN + WALKS.slice(1) + RISE,
}

var game: Node3D
var respawns_seen := 0
var respawn_events: Array = []
var crouch_events: Array = []
var air_ticks := 0

func _initialize() -> void:
	var id := "server128"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="):
			id = R15_PRESETS.resolve(arg.trim_prefix("--preset="))
	Engine.physics_ticks_per_second = int(R15_PRESETS.entry(id).rate)
	super._initialize()

func _start() -> void:
	max_ticks = int(opts.get("max-ticks", "20000"))
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
	assert(str(game.get("map_id")) == MAP_ID, "sunken driver: the main did not load " + MAP_ID)
	source = "settings" in player and (player.get("settings") as Dictionary).has("sv_airaccelerate")
	hz = Engine.physics_ticks_per_second
	warmup = int(opts.get("warmup", str(EXECUTOR_ARM_STEP.get(hz, 32))))
	radians_per_count = float(player.get("tape_radians_per_count"))
	turn_cap = deg_to_rad(float(opts.get("turn-cap", "600"))) / hz
	if opts.has("tape"):
		_load_tape(str(opts.tape))
	else:
		var route := str(opts.get("route", "ordinary"))
		assert(sk_routes.has(route), "sunken driver: unknown route " + route)
		nodes = []
		for node: Dictionary in sk_routes[route]:
			nodes.append(node.duplicate())
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("sunken driver: %s route=%s preset=%s hz=%d geometry=%s turn_cap=%.0f deg/s" % ["OPEN LOOP tape" if not replay.is_empty() else "CLOSED LOOP",
		opts.get("route", replay.get("name", "")), game.get("preset_id"), hz, str(level.call("geometry_hash")).left(12), rad_to_deg(turn_cap * hz)])

func _control_source(tick: int) -> void:
	if node_index < nodes.size():
		var node: Dictionary = nodes[node_index]
		var grounded: bool = player.call("is_grounded")
		air_ticks = 0 if grounded else air_ticks + 1
		# crouch: pressed a few ticks into a duck node's flight, released on a stand node's ground.
		if node.has("duck") and jump_wait and not grounded and air_ticks >= int(node.duck) and not held.has("ctrl"):
			_key("ctrl", true, tick)
		if node.has("stand") and grounded and held.has("ctrl"):
			_key("ctrl", false, tick)
		if node.has("respawn"):
			var p := player.global_position
			var here := Vector2(p.x, p.z)
			if int(game.get("respawn_count")) > respawns_seen:
				respawns_seen = int(game.get("respawn_count"))
				respawn_events.append({"tick": tick, "checkpoint": int(game.get("checkpoint_index")), "at": _v(p)})
				_next(here, tick)
				_want({}, tick)
				return
			var want := {}
			if grounded:
				want = {"w": true}
				_look(here, node.p)
			_want(want, tick)
			return
	super._control_source(tick)

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
	crouch_events.append({"tick": tick, "edge": "press" if pressed else "release", "grounded": player.call("is_grounded"), "at": _v(player.global_position)})

func _observe(tick: int) -> void:
	super._observe(tick)
	# the raw feet stay in "p"; the main's duck compensation and the reference it times with are
	# kept beside them, never folded in.
	var row: Dictionary = JSON.parse_string(trace_lines[-1])
	var comp: Vector3 = game.call("hull_origin_offset")
	row["comp"] = _v(comp / U)
	row["ref"] = _v(game.call("body_reference"))
	row["duck"] = player.get("ducked") == true
	row["sb"] = player.get("stand_blocked") == true
	if held.has("ctrl"):
		row["k"] = str(row.k) + "c"
	trace_lines[-1] = JSON.stringify(row)

func _end(reason: String, tick: int) -> void:
	done = true
	for key: String in held.keys():
		_key(key, false, tick)
	var sources := {}
	for path: String in SK_SOURCES:
		sources[path] = FileAccess.get_sha256(path)
	var mode := "OPEN LOOP replay of a fixed tape: no state was read to choose input" if not replay.is_empty() else "CLOSED LOOP state-aware execution proof; not imperfect input, not discovery"
	var final := player.global_position
	var summary := {"label": "P actual R15 main hosting map %s; normal spawn; %s" % [MAP_ID, mode],
		"reason": reason, "route": opts.get("route", ""), "tape": opts.get("tape", ""), "preset": game.get("preset_id"), "physics_hz": hz,
		"engine_hz": Engine.physics_ticks_per_second, "runner": (player.get_script() as Script).resource_path, "motor_version": player.get("MOTOR_VERSION"),
		"turn_cap_deg_s": snappedf(rad_to_deg(turn_cap * hz), 0.1), "amp_deg": snappedf(rad_to_deg(amp), 0.1), "warmup_steps": warmup,
		"radians_per_count": radians_per_count, "sensitivity_source_units": (player.get("settings") as Dictionary).get("sensitivity"),
		"sv_airaccelerate": (player.get("settings") as Dictionary).get("sv_airaccelerate"), "sv_accelerate": (player.get("settings") as Dictionary).get("sv_accelerate"),
		"map_id": game.get("map_id"), "level_id": level.get("level_id"), "level_version": level.get("level_version"), "geometry_hash": level.call("geometry_hash"),
		"record_key": game.get("course_key"), "sources_sha256": sources,
		"ticks": tick, "finish_tick": finish_tick, "finish_time_s": game.get("elapsed") if finish_tick >= 0 else null, "finish_kind": game.get("finish_kind"),
		"clean_eligible": game.get("clean_eligible"), "practice_reason": game.get("practice_reason"),
		"respawns": game.get("respawn_count"), "respawn_events": respawn_events, "checkpoints": checkpoint_ticks, "crouch_events": crouch_events,
		"nodes_reached": node_ticks.size(), "nodes": nodes.size(), "node_ticks": node_ticks,
		"min_y": snappedf(min_y, 0.001), "max_display_speed_ups": snappedf(max_speed / U, 0.1), "missed": missed,
		"wall_contact_ticks": wall_ticks, "wall_bodies": wall_bodies, "cast_guards": player.get("cast_guards"), "hops": hops, "flights": flights, "sinks": sinks, "supports": supports,
		"final": _v(final), "final_support": _support(final), "events": events.size(),
		"setup_writes": ["r15_main._ready -> restart_run(): the main's own reset to the level's labelled spawn"]}
	_write("summary.json", summary)
	# p / the strict version 2 schema: the mouse scale lives in the description and the summary only.
	var tape := {"format": "spillway-momentum-tape", "version": 2, "name": "r15-sunken-%s-%s" % [opts.get("route", "tape"), game.get("preset_id")],
		"description": "%s; driver-applied events on the actual r15 main hosting %s, physics tick %d Hz, warmup %d steps, %.9f rad per mouse count (source sensitivity %s)" % [mode, MAP_ID, hz, warmup,
			radians_per_count, (player.get("settings") as Dictionary).get("sensitivity")],
		"physics_hz": hz, "input_profile": "physics_tick", "duration_ticks": tick + 1, "duration_s": float(tick + 1) / hz, "mouse_quantize": "float32", "events": events}
	var file := FileAccess.open(out_dir.path_join("events.tape.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(tape, " ", false, true))
	file.close()
	file = FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(trace_lines) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("sunken driver: %s finish=%s time=%s kind=%s respawns=%s nodes=%d/%d min_y=%.2f max=%.0f u/s walls=%d crouch=%d final=%s on %s" % [reason, finish_tick, summary.finish_time_s, summary.finish_kind,
		summary.respawns, node_ticks.size(), nodes.size(), min_y, max_speed / U, wall_ticks, crouch_events.size(), final, summary.final_support])
	game.call("request_quit", 0)
	quit(0)

extends "res://tests/r14_practice_driver.gd"
## p / Breakwater route driver on the actual r15 main. CLOSED LOOP, STATE AWARE: an execution
## proof that a line exists for the approved source runner, not imperfect play and not discovery.
## it builds r15_main.gd with the named Breakwater map, lets the main's own
## restart_run() place the runner at the labelled spawn, and after that writes no pose, velocity,
## camera or progress: it reads the runner and answers with key edges and relative mouse counts,
## saved as a version 2 tape at the runner's actual rate. --tape= plays a tape back open loop.
## the controller is r14_practice_driver.gd's, unchanged; this adds the routes, one node kind
## ("respawn": walk at a point until the main respawns the runner) and the summary.
##
## godot --headless --audio-driver Dummy --path . --script res://tests/r15_breakwater_driver.gd --
##   --out=DIR --route=NAME [--preset=server128|server128_aa1000] [--turn-cap=DEG_PER_S] [--tape=PLAN.json]
## --fixed-fps 128 (one draw per tick) is optional headless; native recordings pass their own.

const MAIN := preload("res://scripts/r15_main.gd")
const REGISTRY := preload("res://scripts/r15_presets.gd")
const BW_SOURCES := ["res://scripts/r15_breakwater_level.gd", "res://scripts/r15_breakwater_art.gd", "res://tests/r15_breakwater_driver.gd",
	"res://tests/r14_practice_driver.gd", "res://scripts/r15_main.gd", "res://scripts/r15_presets.gd", "res://scripts/r15_source_player.gd", "res://scripts/r14_source_player.gd", "res://scripts/r14_source_motion.gd"]

## route nodes, world (x, z), with r14_practice_driver.gd's meanings: land/e/drop/chain/fit/vt/hop/p.
const GATE := [{"p": Vector2(-3.0, -18.0)}]
const ROWS := [
	{"land": Vector2(-3.0, -33.0), "e": Vector2(-3.0, -27.8)},
	{"land": Vector2(-3.0, -41.6), "e": Vector2(-3.0, -35.9)},
	{"land": Vector2(-3.0, -51.6), "e": Vector2(-3.0, -44.5)},
	{"land": Vector2(-4.0, -66.3), "e": Vector2(-4.0, -59.7)},
	{"land": Vector2(-4.0, -76.0), "e": Vector2(-4.0, -69.2)},
]
## bend 1 on the middle line (r 16), the chicane (south passage, then north), bend 2 (r 18).
const QUAY := [
	{"p": Vector2(-1.49, -77.84), "hop": true},
	{"p": Vector2(-5.22, -83.68), "hop": true},
	{"p": Vector2(-11.06, -87.40), "hop": true},
	{"p": Vector2(-18.0, -92.6), "hop": true},
	{"p": Vector2(-30.0, -93.2), "hop": true},
	{"p": Vector2(-41.0, -85.4), "hop": true},
	{"p": Vector2(-52.0, -84.6), "hop": true},
	{"p": Vector2(-65.53, -91.84), "hop": true},
	{"p": Vector2(-72.12, -98.43), "hop": true},
	{"p": Vector2(-74.6, -106.0), "hop": true},
]
## the ordinary end: down the runway holding speed, over to the gangway, round the tower's east.
const ORDINARY_END := [
	{"p": Vector2(-74.0, -140.0), "hop": true},
	{"p": Vector2(-69.5, -205.0), "hop": true},
	{"p": Vector2(-68.3, -232.0)},
	{"p": Vector2(-68.3, -246.0)},
	{"p": Vector2(-65.5, -256.0)},
	{"p": Vector2(-69.5, -267.0)},
]
## the earned end: strafe for speed down the runway, jump the breach on the main line, round the
## tower's west. one fit hop lines up the take-off near the lip.
const EARNED_END := [
	{"p": Vector2(-76.0, -125.0), "hop": true, "vt": 3000.0},
	{"p": Vector2(-78.5, -200.0), "hop": true, "vt": 3000.0},
	{"land": Vector2(-78.5, -232.5), "e": Vector2(-78.5, -235.0), "chain": true, "fit": true, "win": 3.0, "vt": 3000.0},
	{"land": Vector2(-78.5, -248.0), "e": Vector2(-78.5, -235.3), "clear": Vector2(-78.5, -244.6), "drop": 1.0, "chain": true, "vt": 0.0},
	{"p": Vector2(-84.5, -256.0)},
	{"p": Vector2(-80.5, -267.0)},
]
## the earned end with the line-up hop aimed 1 m from the lip in a 1 m window: AA 1000's stronger
## air braking made the first version land 6 m short and leave early (failure kept in evidence).
const EARNED_LIP_END := [
	{"p": Vector2(-76.0, -125.0), "hop": true, "vt": 3000.0},
	{"p": Vector2(-78.5, -200.0), "hop": true, "vt": 3000.0},
	{"land": Vector2(-78.5, -234.2), "e": Vector2(-78.5, -235.0), "chain": true, "fit": true, "win": 1.0, "vt": 3000.0},
	{"land": Vector2(-78.5, -248.0), "e": Vector2(-78.5, -235.3), "clear": Vector2(-78.5, -244.6), "drop": 1.0, "chain": true, "vt": 0.0},
	{"p": Vector2(-84.5, -256.0)},
	{"p": Vector2(-80.5, -267.0)},
]
## a deliberate alley miss: block 2 pressed on landing on block 1, too early by about 3 m, then
## the alley walk back up the return ramp and the rows again.
const ALLEY_MISS := [
	{"land": Vector2(-3.0, -33.0), "e": Vector2(-3.0, -27.8)},
	{"land": Vector2(-3.0, -43.5), "e": Vector2(-3.0, -31.0), "miss": true},
	{"p": Vector2(7.3, -37.5)},
	{"p": Vector2(7.3, -29.0)},
	{"p": Vector2(7.3, -14.5)},
	{"p": Vector2(3.0, -12.0)},
	{"p": Vector2(-3.0, -18.0)},
]
## a fall into the harbour off bend 2's open inside edge, the respawn at the crane-line
## checkpoint, and the quay again from there.
const HARBOUR := [
	{"p": Vector2(-62.0, -104.0), "respawn": true},
]
var bw_routes := {
	"ordinary": GATE + ROWS + QUAY + ORDINARY_END,
	"earned": GATE + ROWS + QUAY + EARNED_END,
	"earned_lip": GATE + ROWS + QUAY + EARNED_LIP_END,
	"alley_recovery": GATE + ALLEY_MISS + ROWS + QUAY + ORDINARY_END,
	"harbour_recovery": GATE + ROWS + QUAY.slice(0, 7) + HARBOUR + QUAY.slice(1) + ORDINARY_END,
}

var game: Node3D
var respawns_seen := 0
var respawn_events: Array = []

func _initialize() -> void:
	var id := "server128"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="):
			id = REGISTRY.resolve(arg.trim_prefix("--preset="))
	Engine.physics_ticks_per_second = int(REGISTRY.entry(id).rate)
	super._initialize()

func _start() -> void:
	max_ticks = int(opts.get("max-ticks", "20000"))
	amp = deg_to_rad(float(opts.get("amp", "30")))
	game = MAIN.new()
	game.name = "R15"
	game.set("motor", str(opts.get("preset", "server128")))
	game.set("map_id", "breakwater")
	game.set("set_window_title", false)
	root.add_child(game)
	# the base controller reads the game through `lab`; r15_main preserves the same run fields.
	lab = game
	level = game.get("level")
	player = game.get("player")
	source = "settings" in player and (player.get("settings") as Dictionary).has("sv_airaccelerate")
	hz = Engine.physics_ticks_per_second
	warmup = int(opts.get("warmup", str(EXECUTOR_ARM_STEP.get(hz, 32))))
	radians_per_count = float(player.get("tape_radians_per_count"))
	turn_cap = deg_to_rad(float(opts.get("turn-cap", "600"))) / hz
	if opts.has("tape"):
		_load_tape(str(opts.tape))
	else:
		var route := str(opts.get("route", "ordinary"))
		assert(bw_routes.has(route), "breakwater driver: unknown route " + route)
		nodes = []
		for node: Dictionary in bw_routes[route]:
			nodes.append(node.duplicate())
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("breakwater driver: %s route=%s preset=%s hz=%d geometry=%s turn_cap=%.0f deg/s" % ["OPEN LOOP tape" if not replay.is_empty() else "CLOSED LOOP",
		opts.get("route", replay.get("name", "")), game.get("preset_id"), hz, str(level.call("geometry_hash")).left(12), rad_to_deg(turn_cap * hz)])

func _control_source(tick: int) -> void:
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

func _end(reason: String, tick: int) -> void:
	done = true
	for key: String in held.keys():
		_key(key, false, tick)
	var sources := {}
	for path: String in BW_SOURCES:
		sources[path] = FileAccess.get_sha256(path)
	var mode := "OPEN LOOP replay of a fixed tape: no state was read to choose input" if not replay.is_empty() else "CLOSED LOOP state-aware execution proof; not imperfect input, not discovery"
	var final := player.global_position
	var summary := {"label": "P actual R15 main hosting the named Breakwater map; normal spawn; " + mode,
		"reason": reason, "route": opts.get("route", ""), "tape": opts.get("tape", ""), "preset": game.get("preset_id"), "physics_hz": hz,
		"engine_hz": Engine.physics_ticks_per_second, "runner": (player.get_script() as Script).resource_path,
		"turn_cap_deg_s": snappedf(rad_to_deg(turn_cap * hz), 0.1), "amp_deg": snappedf(rad_to_deg(amp), 0.1), "warmup_steps": warmup,
		"radians_per_count": radians_per_count, "sensitivity_source_units": (player.get("settings") as Dictionary).get("sensitivity"),
		"level_id": level.get("level_id"), "level_version": level.get("level_version"), "geometry_hash": level.call("geometry_hash"),
		"record_key": game.get("course_key"), "sources_sha256": sources,
		"ticks": tick, "finish_tick": finish_tick, "finish_time_s": game.get("elapsed") if finish_tick >= 0 else null, "finish_kind": game.get("finish_kind"),
		"respawns": game.get("respawn_count"), "respawn_events": respawn_events, "checkpoints": checkpoint_ticks,
		"nodes_reached": node_ticks.size(), "nodes": nodes.size(), "node_ticks": node_ticks,
		"min_y": snappedf(min_y, 0.001), "max_display_speed_ups": snappedf(max_speed / U, 0.1), "missed": missed,
		"wall_contact_ticks": wall_ticks, "wall_bodies": wall_bodies, "cast_guards": player.get("cast_guards"), "hops": hops, "flights": flights, "sinks": sinks, "supports": supports,
		"final": _v(final), "final_support": _support(final), "events": events.size(),
		"setup_writes": ["r15_main._ready -> restart_run(): the main's own reset to the level's labelled spawn"]}
	_write("summary.json", summary)
	var tape := {"format": "spillway-momentum-tape", "version": 2, "name": "r15-breakwater-%s-%s" % [opts.get("route", "tape"), game.get("preset_id")],
		"description": "%s; driver-applied events on the actual r15 main hosting Breakwater, physics tick %d Hz, warmup %d steps, look %.17f rad/count" % [mode, hz, warmup, radians_per_count],
		"physics_hz": hz, "input_profile": "physics_tick", "duration_ticks": tick + 1, "duration_s": float(tick + 1) / hz, "mouse_quantize": "float32",
		"events": events}
	var file := FileAccess.open(out_dir.path_join("events.tape.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(tape, " ", false, true))
	file.close()
	file = FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(trace_lines) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("breakwater driver: %s finish=%s time=%s kind=%s respawns=%s nodes=%d/%d min_y=%.2f max=%.0f u/s walls=%d final=%s on %s" % [reason, finish_tick, summary.finish_time_s, summary.finish_kind,
		summary.respawns, node_ticks.size(), nodes.size(), min_y, max_speed / U, wall_ticks, final, summary.final_support])
	game.call("request_quit", 0)
	quit(0)

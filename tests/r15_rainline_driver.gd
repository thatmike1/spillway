extends "res://tests/r14_practice_driver.gd"
## p / Rainline route driver on the actual r15 main. CLOSED LOOP, STATE AWARE: an execution proof
## that a line exists for the approved source runner with real crouch, not imperfect play and not
## discovery. it builds r15_main.gd with the named map `rainline`; the main's own restart_run()
## places the runner at the labelled spawn, and after that the driver writes no pose, velocity,
## camera or progress. it reads the runner and answers with key edges (w a s d space, ctrl to crouch,
## f for checkpoint practice) and relative mouse counts, saved as a version 2 tape at the runner's
## actual rate. --tape= plays a tape back open loop: the same events on the same ticks.
##
## the controller is r14_practice_driver.gd's, unchanged. this adds the routes and three node
## fields: "duck" (crouch held through this node; pressed and released only on a ground tick, so
## the route never ducks or stands in flight), "respawn" (walk at a point until the main respawns
## the runner) and "practice" (tap F at this point: the main's checkpoint practice).
## the trace keeps raw feet, the main's body reference and the runner's duck compensation apart.
##
## godot --headless --audio-driver Dummy --path . --script res://tests/r15_rainline_driver.gd --
##   --out=DIR --route=NAME [--preset=server128|server128_aa1000] [--turn-cap=DEG_PER_S] [--tape=PLAN.json]

const MAIN := preload("res://scripts/r15_main.gd")
const REGISTRY := preload("res://scripts/r15_presets.gd")
const RL_SOURCES := ["res://scripts/r15_rainline_level.gd", "res://scripts/r15_rainline_art.gd", "res://tests/r15_rainline_driver.gd",
	"res://tests/r14_practice_driver.gd", "res://scripts/r15_main.gd", "res://scripts/r15_presets.gd", "res://scripts/r15_maps.gd",
	"res://scripts/r15_source_player.gd", "res://scripts/r14_source_player.gd", "res://scripts/r14_source_motion.gd"]
const EXTRA_KEYS := {"ctrl": KEY_CTRL, "f": KEY_F}

## route nodes, world (x, z), with r14_practice_driver.gd's meanings: land/e/drop/chain/fit/vt/hop/p.
## the tannery roof and the terraces, then a curve right onto the gantry line.
const TANNERY := [
	{"p": Vector2(0.0, -20.0), "hop": true},
	{"p": Vector2(1.0, -38.0), "hop": true},
	{"p": Vector2(5.5, -48.0), "hop": true},
]
## the gantry: two missing panels, jumped from the deck before each.
const GANTRY := [
	{"land": Vector2(14.6, -49.0), "e": Vector2(11.2, -49.0)},
	{"land": Vector2(20.8, -49.0), "e": Vector2(15.8, -49.0), "chain": true},
]
## the print works, the scaffold round the tower and into the lamp room.
const SCAFFOLD := [
	{"p": Vector2(26.0, -56.0), "hop": true},
	{"p": Vector2(27.5, -68.0), "hop": true},
	{"p": Vector2(27.5, -112.0), "hop": true},
	{"p": Vector2(28.5, -120.6), "hop": true},
	{"p": Vector2(39.0, -120.6), "hop": true},
	{"p": Vector2(49.6, -119.6), "hop": true},
	{"p": Vector2(50.5, -108.0), "hop": true},
	{"p": Vector2(50.5, -68.0), "hop": true},
	{"p": Vector2(51.5, -58.0), "hop": true},
]
## ordinary: out of the north door, round the plant room on the east strip, down the ramp, over
## the footbridge and up to the finish.
const ROUND := [
	{"p": Vector2(52.0, -50.5), "hop": true},
	{"p": Vector2(63.3, -42.5), "hop": true},
	{"p": Vector2(63.0, -18.0), "hop": true},
	{"p": Vector2(63.0, 6.0), "hop": true},
	{"p": Vector2(63.0, 24.0), "hop": true},
	{"p": Vector2(63.0, 34.5), "hop": true},
	{"p": Vector2(57.0, 38.5)},
]
## the duct: crouch on a ground tick inside the lamp room, crouch-hop out of the door and through
## the 12 m duct, stand on the first ground tick on the runway, then on as the ordinary line.
const DUCT := [
	{"p": Vector2(51.5, -56.0), "hop": true},
	{"p": Vector2(51.5, -31.0), "hop": true, "duck": true},
	{"p": Vector2(60.5, -29.0), "hop": true},
	{"p": Vector2(63.0, -18.0), "hop": true},
	{"p": Vector2(63.0, 6.0), "hop": true},
	{"p": Vector2(63.0, 24.0), "hop": true},
	{"p": Vector2(63.0, 34.5), "hop": true},
	{"p": Vector2(57.0, 38.5)},
]
## duct_earned: the duct, then strafing for speed down the runway, one fit hop to the lip and the
## jump over the second street onto the comms roof. the duct leaves the runner at 240 u/s, and the
## runway is too short to win back what the jump needs; kept as a recorded attempt.
const DUCT_EARNED := [
	{"p": Vector2(51.5, -56.0), "hop": true},
	{"p": Vector2(51.5, -31.0), "hop": true, "duck": true},
	{"p": Vector2(52.0, -22.0), "hop": true, "vt": 3000.0},
	{"land": Vector2(52.0, -1.2), "e": Vector2(52.0, -0.3), "chain": true, "fit": true, "win": 1.0, "vt": 3000.0},
	{"land": Vector2(52.0, 13.0), "e": Vector2(52.0, -0.3), "clear": Vector2(52.0, 10.0), "drop": 2.0, "chain": true, "vt": 0.0},
	{"p": Vector2(45.0, 23.5), "hop": true},
	{"p": Vector2(45.0, 34.5), "hop": true},
	{"p": Vector2(49.0, 38.5)},
]
## earned: the speed line from the round path, over the link onto the runway and the jump over the
## second street (no crouch at all).
const EARNED := [
	{"p": Vector2(52.0, -50.5), "hop": true},
	{"p": Vector2(63.0, -42.0), "hop": true, "vt": 3000.0},
	{"p": Vector2(61.5, -31.5), "hop": true, "vt": 3000.0},
	{"p": Vector2(52.0, -20.0), "hop": true, "vt": 3000.0},
	{"land": Vector2(52.0, -1.2), "e": Vector2(52.0, -0.3), "chain": true, "fit": true, "win": 1.0, "vt": 3000.0},
	{"land": Vector2(52.0, 13.0), "e": Vector2(52.0, -0.3), "clear": Vector2(52.0, 10.0), "drop": 2.0, "chain": true, "vt": 0.0},
	{"p": Vector2(45.0, 23.5), "hop": true},
	{"p": Vector2(45.0, 34.5), "hop": true},
	{"p": Vector2(49.0, 38.5)},
]
## recovery: past the first gap, stop on the middle deck and walk into the second gap, fall to the
## street, respawn at the gantry checkpoint and cross again.
const GANTRY_FALL := [
	{"land": Vector2(14.0, -49.0), "e": Vector2(11.2, -49.0)},
	{"p": Vector2(19.5, -49.0), "respawn": true},
]
## practice: on the east strip, F: the main's checkpoint practice from the lamp room, then the duct.
const PRACTICE := [
	{"p": Vector2(52.0, -50.5), "hop": true},
	{"p": Vector2(63.3, -42.5), "practice": true},
]
var rl_routes := {
	"ordinary": TANNERY + GANTRY + SCAFFOLD + ROUND,
	"duct": TANNERY + GANTRY + SCAFFOLD + DUCT,
	"earned": TANNERY + GANTRY + SCAFFOLD + EARNED,
	"duct_earned": TANNERY + GANTRY + SCAFFOLD + DUCT_EARNED,
	"gantry_recovery": TANNERY + GANTRY_FALL + GANTRY + SCAFFOLD + ROUND,
	"practice": TANNERY + GANTRY + SCAFFOLD + PRACTICE + DUCT,
}

var game: Node3D
var respawns_seen := 0
var respawn_events: Array = []
var practice_events: Array = []
var practice_wait := -1
var duck_presses: Array = []

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
	game.set("map_id", "rainline")
	game.set("set_window_title", false)
	root.add_child(game)
	# the base controller reads the game through `lab`; r15_main has the same run fields.
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
		assert(rl_routes.has(route), "rainline driver: unknown route " + route)
		nodes = []
		for node: Dictionary in rl_routes[route]:
			nodes.append(node.duplicate())
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("rainline driver: %s route=%s preset=%s hz=%d map=%s geometry=%s turn_cap=%.0f deg/s rad/count=%.8f" % ["OPEN LOOP tape" if not replay.is_empty() else "CLOSED LOOP",
		opts.get("route", replay.get("name", "")), game.get("preset_id"), hz, game.get("map_id"), str(level.call("geometry_hash")).left(12), rad_to_deg(turn_cap * hz), radians_per_count])

func _control_source(tick: int) -> void:
	var node: Dictionary = nodes[node_index] if node_index < nodes.size() else {}
	var grounded: bool = player.call("is_grounded")
	# crouch follows the node, changed only on a ground tick: no duck or stand in flight.
	var duck := bool(node.get("duck", false))
	if grounded and duck != held.has("ctrl"):
		_key("ctrl", duck, tick)
		duck_presses.append({"tick": tick, "press": duck, "at": _v(player.global_position)})
	if node.has("practice"):
		var here := Vector2(player.global_position.x, player.global_position.z)
		if practice_wait < 0:
			if here.distance_to(node.p) < 1.5 or (node.p - node_from).dot(here - node.p) > 0.0:
				_want({}, tick)
				_key("f", true, tick)
				practice_wait = tick
				return
		elif held.has("f"):
			_key("f", false, tick)
			return
		elif int(game.get("practice_stage")) >= 0:
			practice_events.append({"tick": tick, "stage": game.get("practice_stage"), "at": _v(player.global_position), "elapsed": game.get("elapsed")})
			practice_wait = -1
			_next(here, tick)
			_want({}, tick)
			return
	if node.has("respawn"):
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
		if grounded:
			want = {"w": true}
			_look(here, node.p)
		_want(want, tick)
		return
	super._control_source(tick)

func _key(key: String, pressed: bool, tick: int) -> void:
	if not EXTRA_KEYS.has(key):
		super._key(key, pressed, tick)
		return
	if pressed == held.has(key):
		return
	var event := InputEventKey.new()
	event.keycode = EXTRA_KEYS[key]
	event.physical_keycode = EXTRA_KEYS[key]
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed:
		held[key] = true
	else:
		held.erase(key)
	events.append({"tick": tick, "key": key, "edge": "press" if pressed else "release"})

func _observe(tick: int) -> void:
	super._observe(tick)
	# raw feet stay in "p"; the main's progress reference and the runner's cumulative duck
	# compensation (u) ride alongside, never folded into the feet.
	var row: Dictionary = JSON.parse_string(trace_lines[-1])
	var comp: Variant = player.get("_duck_compensation_u")
	row["ref"] = _v(game.call("body_reference"))
	row["comp_u"] = _v(comp) if comp is Vector3 else [0, 0, 0]
	row["duck"] = player.get("ducked") == true
	row["sb"] = player.get("stand_blocked") == true
	row["pr"] = game.get("practice_stage")
	trace_lines[-1] = JSON.stringify(row)

func _end(reason: String, tick: int) -> void:
	done = true
	for key: String in held.keys():
		_key(key, false, tick)
	var sources := {}
	for path: String in RL_SOURCES:
		sources[path] = FileAccess.get_sha256(path)
	var mode := "OPEN LOOP replay of a fixed tape: no state was read to choose input" if not replay.is_empty() else "CLOSED LOOP state-aware execution proof; not imperfect input, not discovery"
	var final := player.global_position
	var state: Dictionary = player.call("get_motion_state")
	var duck_state: Dictionary = state.get("duck", {})
	var summary := {"label": "P actual R15 main hosting map rainline; normal spawn; " + mode,
		"reason": reason, "route": opts.get("route", ""), "tape": opts.get("tape", ""), "preset": game.get("preset_id"), "physics_hz": hz,
		"engine_hz": Engine.physics_ticks_per_second, "runner": (player.get_script() as Script).resource_path, "motor_version": player.get("MOTOR_VERSION"),
		"turn_cap_deg_s": snappedf(rad_to_deg(turn_cap * hz), 0.1), "amp_deg": snappedf(rad_to_deg(amp), 0.1), "warmup_steps": warmup,
		"radians_per_count": radians_per_count, "sensitivity_source_units": (player.get("settings") as Dictionary).get("sensitivity"),
		"map_id": game.get("map_id"), "level_id": level.get("level_id"), "level_version": level.get("level_version"), "geometry_hash": level.call("geometry_hash"),
		"record_key": game.get("course_key"), "sources_sha256": sources,
		"ticks": tick, "finish_tick": finish_tick, "finish_time_s": game.get("elapsed") if finish_tick >= 0 else null, "finish_kind": game.get("finish_kind"),
		"clean_eligible": game.get("clean_eligible"), "practice_reason": game.get("practice_reason"),
		"respawns": game.get("respawn_count"), "respawn_events": respawn_events, "practice_events": practice_events, "checkpoints": checkpoint_ticks,
		"duck_counts": duck_state.get("counts", {}), "duck_key_edges": duck_presses,
		"nodes_reached": node_ticks.size(), "nodes": nodes.size(), "node_ticks": node_ticks,
		"min_y": snappedf(min_y, 0.001), "max_display_speed_ups": snappedf(max_speed / U, 0.1), "missed": missed,
		"wall_contact_ticks": wall_ticks, "wall_bodies": wall_bodies, "cast_guards": player.get("cast_guards"), "hops": hops, "flights": flights, "sinks": sinks, "supports": supports,
		"final": _v(final), "final_support": _support(final), "events": events.size(),
		"setup_writes": ["r15_main._ready -> restart_run(): the main's own reset to the level's labelled spawn"]}
	_write("summary.json", summary)
	# p / strict version 2 header: the look scale and warmup live in the description, not as fields.
	var tape := {"format": "spillway-momentum-tape", "version": 2, "name": "r15-rainline-%s-%s" % [opts.get("route", "tape"), game.get("preset_id")],
		"description": "%s; driver-applied events on the actual r15 main hosting map rainline, physics tick %d Hz, warmup %d steps, %.10f rad per mouse count at runner sensitivity %s" % [mode, hz, warmup, radians_per_count, (player.get("settings") as Dictionary).get("sensitivity")],
		"physics_hz": hz, "input_profile": "physics_tick", "duration_ticks": tick + 1, "duration_s": float(tick + 1) / hz, "mouse_quantize": "float32", "events": events}
	var file := FileAccess.open(out_dir.path_join("events.tape.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(tape, " ", false, true))
	file.close()
	file = FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(trace_lines) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("rainline driver: %s finish=%s time=%s kind=%s respawns=%s nodes=%d/%d min_y=%.2f max=%.0f u/s walls=%d ducks=%s final=%s on %s" % [reason, finish_tick, summary.finish_time_s, summary.finish_kind,
		summary.respawns, node_ticks.size(), nodes.size(), min_y, max_speed / U, wall_ticks, summary.duck_counts, final, summary.final_support])
	game.call("request_quit", 0)
	quit(0)

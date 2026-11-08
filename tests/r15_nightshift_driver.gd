extends "res://tests/r14_practice_driver.gd"
## p / Night Shift route driver on the actual r15 main. CLOSED LOOP, STATE AWARE: an execution
## proof that a line exists for the approved source runner with real crouch, not imperfect play
## and not discovery. it builds r15_main.gd with the named night-shift map, lets the main's own
## restart_run() place the runner at the labelled spawn, and after that writes no pose, velocity,
## camera or progress: it reads the runner and answers with key edges (w a s d space ctrl) and
## relative mouse counts, saved as a version 2 tape at the runner's actual rate. --tape= plays a
## tape back open loop: the same events on the same ticks, no state read to choose them.
## the controller is r14_practice_driver.gd's, unchanged; this adds the routes, a "respawn" node
## (walk at a point until the main respawns the runner), crouch zones (hold the real crouch key
## while the feet are inside a box) and the summary.
##
## godot --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/r15_nightshift_driver.gd --
##   --out=DIR --route=NAME [--preset=server128|server128_aa1000] [--turn-cap=DEG_PER_S] [--tape=PLAN.json]

const MAIN := preload("res://scripts/r15_main.gd")
const REGISTRY := preload("res://scripts/r15_presets.gd")
const NS := preload("res://scripts/r15_nightshift_level.gd")
const NS_SOURCES := ["res://scripts/r15_nightshift_level.gd", "res://scripts/r15_nightshift_art.gd", "res://tests/r15_nightshift_driver.gd",
	"res://tests/r14_practice_driver.gd", "res://scripts/r15_main.gd", "res://scripts/r15_presets.gd", "res://scripts/r15_source_player.gd", "res://scripts/r14_source_player.gd", "res://scripts/r14_source_motion.gd"]
const ROUTE_NAMES := ["ordinary", "earned", "pit_recovery", "canal_recovery", "crouch"]

var game: Node3D
var respawns_seen := 0
var respawn_events: Array = []
## boxes (x0, z0, x1, z1) in which the route holds the crouch key, and the ticks it changed.
var duck_zones: Array = []
var duck_edges: Array = []
var ducked_ticks := 0
var stand_blocked_ticks := 0

func _initialize() -> void:
	var id := "server128"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="):
			id = REGISTRY.resolve(arg.trim_prefix("--preset="))
	Engine.physics_ticks_per_second = int(REGISTRY.entry(id).rate)
	super._initialize()

# --- routes ----------------------------------------------------------------------------------

static func _ring(r: float, degrees: float) -> Vector2:
	# a point on the turning loop: radius from its centre, degrees round from the mouth.
	var d := Vector3.LEFT.rotated(Vector3.UP, -deg_to_rad(degrees))
	return Vector2(NS.LOOP.x + d.x * r, NS.LOOP.z + d.z * r)

static func _knuckle(r: float, degrees: float) -> Vector2:
	var d := Vector3.RIGHT.rotated(Vector3.UP, -deg_to_rad(degrees))
	return Vector2(NS.KNUCKLE.x + d.x * r, NS.KNUCKLE.z + d.z * r)

func _routes() -> Dictionary:
	var fly_z := (NS.FLY_S + NS.FLY_N) * 0.5
	# platform 1 and the throat's three cabinets onto the loop approach, at run speed.
	var platform := [{"p": Vector2(0.0, -34.0), "hop": true}]
	var throat := [
		{"land": Vector2(-1.5, -49.0), "e": Vector2(-0.5, -43.8)},
		{"land": Vector2(1.5, -57.5), "e": Vector2(-0.5, -51.8)},
		{"land": Vector2(-1.5, -67.0), "e": Vector2(0.5, -60.8)},
		{"land": Vector2(1.0, -76.5), "e": Vector2(-0.5, -69.8)},
	]
	# the sweep on its middle line (r 21), out to the shed door.
	var sweep: Array = []
	for a: float in [12.0, 40.0, 70.0, 100.0, 130.0, 160.0]:
		sweep.append({"p": _ring(21.0, a), "hop": true})
	sweep.append({"p": Vector2(43.0, -89.5), "hop": true})
	# the doorway detour (heading north, west is on the right): right through door 1, up the
	# west bay, out its north end and left along the forecourt to the ramp's foot.
	var chicane := [
		{"p": Vector2(42.5, -86.5)},
		{"p": Vector2(39.25, -84.5)},
		{"p": Vector2(36.0, -82.0)},
		{"p": Vector2(35.8, -45.0), "hop": true},
		{"p": Vector2(36.5, -38.0)},
		{"p": Vector2(40.0, -36.5)},
		{"p": Vector2(45.5, -36.5)},
	]
	# the ramp, the knuckle round the signal box and the flyover back over platform 1.
	var climb := [{"p": Vector2(49.0, -33.0)}, {"p": Vector2(49.0, -8.0), "hop": true}]
	for a: float in [25.0, 55.0, 80.0]:
		climb.append({"p": _knuckle(9.0, a), "hop": true})
	var flyover := [{"p": Vector2(20.0, fly_z), "hop": true}, {"p": Vector2(-25.0, fly_z), "hop": true}]
	var steps := [
		{"land": Vector2(-35.5, fly_z), "e": Vector2(-29.7, fly_z), "drop": 1.6},
		{"land": Vector2(-42.0, fly_z), "e": Vector2(-37.2, fly_z), "drop": 1.6, "chain": true},
		{"land": Vector2(-50.0, fly_z), "e": Vector2(-43.7, fly_z), "drop": 1.8, "chain": true},
		{"p": Vector2(-61.0, fly_z)},
	]
	var tail: Array = climb + flyover + steps
	# the earned line: strafe for speed down platform 1, the throat as one chained rhythm, a
	# right turn on the approach and the 6.5 m jump onto the traverser bridge, then the doors.
	var earned_front := [
		{"p": Vector2(0.0, -20.0), "hop": true, "vt": 470.0},
		{"p": Vector2(0.0, -40.0), "hop": true, "vt": 470.0},
		{"land": Vector2(-1.0, -49.5), "e": Vector2(-0.5, -43.8), "chain": true, "vt": 0.0},
		{"land": Vector2(1.0, -58.0), "e": Vector2(0.5, -60.8), "chain": true, "vt": 0.0},
		{"land": Vector2(-1.0, -67.0), "e": Vector2(0.0, -69.8), "chain": true, "vt": 0.0},
		{"land": Vector2(1.0, -77.0), "e": Vector2(0.0, -69.8), "chain": true, "vt": 0.0},
		{"land": Vector2(3.5, -86.5), "e": Vector2(1.0, -80.0), "chain": true, "vt": 0.0},
		{"land": Vector2(15.5, -91.5), "e": Vector2(5.8, -90.5), "chain": true, "vt": 0.0},
		{"p": Vector2(35.0, -91.5), "hop": true},
		{"p": Vector2(43.0, -88.0)},
	]
	# a deliberate fall off the sweep's open inside into the pit, the walk round the traverser's
	# west end to the pit ramp, up to the mouth, and the sweep again.
	var pit := [
		{"p": _ring(21.0, 12.0), "hop": true},
		{"p": _ring(21.0, 40.0), "hop": true},
		{"p": _ring(11.0, 62.0), "fall": NS.DECK_Y - 0.6},
		{"p": Vector2(9.5, -98.0)},
		{"p": Vector2(8.0, -88.0)},
		{"p": Vector2(7.75, -76.0)},
		{"p": Vector2(7.75, -73.6)},
		{"p": Vector2(3.0, -75.5)},
		{"p": Vector2(1.0, -79.0)},
	]
	# a deliberate walk off the flyover's end into the canal, the respawn at the flyover
	# checkpoint, and the flyover and the steps again from there.
	var canal := [{"p": Vector2(-33.0, fly_z), "respawn": true}]
	# the crouch shortcut: the sweep's last third on its outside lane, a drift east on the exit,
	# a jump about 2 m before the east road door with crouch pressed in the air, through the
	# hatch, then the east bay's lane straight across the forecourt onto the ramp.
	var shutter := [
		{"p": _ring(24.5, 150.0), "hop": true},
		{"p": _ring(24.5, 172.0), "hop": true},
		{"land": Vector2(48.8, -85.8), "e": Vector2(48.0, -90.7)},
		{"p": Vector2(48.7, -80.0)},
		{"p": Vector2(48.7, -46.0), "hop": true},
		{"p": Vector2(48.9, -38.0)},
	]
	return {
		"ordinary": platform + throat + sweep + chicane + tail,
		"earned": earned_front + chicane + tail,
		"pit_recovery": platform + throat + pit + sweep + chicane + tail,
		"canal_recovery": platform + throat + sweep + chicane + tail.slice(0, tail.size() - steps.size()) + canal + flyover + steps,
		"crouch": platform + throat + sweep.slice(0, 4) + shutter + tail,
	}

func _start() -> void:
	max_ticks = int(opts.get("max-ticks", "20000"))
	amp = deg_to_rad(float(opts.get("amp", "30")))
	game = MAIN.new()
	game.name = "R15"
	game.set("motor", str(opts.get("preset", "server128")))
	game.set("map_id", "night-shift")
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
		var all := _routes()
		assert(all.has(route), "night shift driver: unknown route " + route)
		nodes = []
		for node: Dictionary in all[route]:
			nodes.append(node.duplicate())
		if route == "crouch":
			# p / through the hatch: crouch goes down only in flight, from just after a take-off
			# 1.8 m or more before the wall, and comes up once the hull is past it.
			var sh: Array = NS.SHUTTER
			duck_zones = [[float(sh[0]) - 0.6, NS.SHED_S - 1.9, NS.EXIT_E, NS.SHED_S + 1.25]]
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("night shift driver: %s route=%s preset=%s hz=%d geometry=%s turn_cap=%.0f deg/s" % ["OPEN LOOP tape" if not replay.is_empty() else "CLOSED LOOP",
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
	if not duck_zones.is_empty():
		var p := player.global_position
		var inside := false
		for zone: Array in duck_zones:
			inside = inside or (p.x >= float(zone[0]) and p.x <= float(zone[2]) and p.z >= float(zone[1]) and p.z <= float(zone[3]))
		# crouch goes down in flight only; it is never pressed on the floor.
		if inside and not held.has("ctrl") and player.call("is_grounded"):
			inside = false
		if inside != held.has("ctrl"):
			_key("ctrl", inside, tick)
			duck_edges.append({"tick": tick, "edge": "press" if inside else "release", "at": _v(p)})

func _observe(tick: int) -> void:
	super._observe(tick)
	if bool(player.get("ducked")):
		ducked_ticks += 1
	if bool(player.get("stand_blocked")):
		stand_blocked_ticks += 1

## the base mapping plus the real crouch key.
func _key(key: String, pressed: bool, tick: int) -> void:
	if pressed == held.has(key):
		return
	var event := InputEventKey.new()
	var code: Key = KEY_CTRL if key == "ctrl" else KEYS[key]
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed:
		held[key] = true
	else:
		held.erase(key)
	events.append({"tick": tick, "key": key, "edge": "press" if pressed else "release"})

func _end(reason: String, tick: int) -> void:
	done = true
	for key: String in held.keys():
		_key(key, false, tick)
	var sources := {}
	for path: String in NS_SOURCES:
		sources[path] = FileAccess.get_sha256(path)
	var mode := "OPEN LOOP replay of a fixed tape: no state was read to choose input" if not replay.is_empty() else "CLOSED LOOP state-aware execution proof; not imperfect input, not discovery"
	var final := player.global_position
	var settings: Dictionary = player.get("settings")
	var summary := {"label": "P actual R15 main hosting the named Night Shift map; normal spawn; " + mode,
		"reason": reason, "route": opts.get("route", ""), "tape": opts.get("tape", ""), "preset": game.get("preset_id"), "physics_hz": hz,
		"engine_hz": Engine.physics_ticks_per_second, "runner": (player.get_script() as Script).resource_path, "motor_version": (player.get_script() as Script).get_script_constant_map().get("MOTOR_VERSION"),
		"turn_cap_deg_s": snappedf(rad_to_deg(turn_cap * hz), 0.1), "amp_deg": snappedf(rad_to_deg(amp), 0.1), "warmup_steps": warmup,
		"radians_per_count": radians_per_count, "sensitivity_source_units": settings.get("sensitivity"),
		"air": {"sv_airaccelerate": settings.get("sv_airaccelerate"), "sv_air_max_wishspeed": settings.get("sv_air_max_wishspeed"), "sv_autobunnyhopping": settings.get("sv_autobunnyhopping"), "preset": settings.get("preset")},
		"level_id": level.get("level_id"), "level_version": level.get("level_version"), "geometry_hash": level.call("geometry_hash"),
		"record_key": game.get("course_key"), "sources_sha256": sources,
		"ticks": tick, "finish_tick": finish_tick, "finish_time_s": game.get("elapsed") if finish_tick >= 0 else null, "finish_kind": game.get("finish_kind"),
		"respawns": game.get("respawn_count"), "respawn_events": respawn_events, "checkpoints": checkpoint_ticks,
		"nodes_reached": node_ticks.size(), "nodes": nodes.size(), "node_ticks": node_ticks,
		"min_y": snappedf(min_y, 0.001), "max_display_speed_ups": snappedf(max_speed / U, 0.1), "missed": missed,
		"duck_edges": duck_edges, "ducked_ticks": ducked_ticks, "stand_blocked_ticks": stand_blocked_ticks,
		"wall_contact_ticks": wall_ticks, "wall_bodies": wall_bodies, "cast_guards": player.get("cast_guards"), "hops": hops, "flights": flights, "sinks": sinks, "supports": supports,
		"final": _v(final), "final_support": _support(final), "events": events.size(),
		"setup_writes": ["r15_main._ready -> restart_run(): the main's own reset to the level's labelled spawn"]}
	_write("summary.json", summary)
	# p / the strict version 2 header: look sensitivity and warmup go in the description only.
	var tape := {"format": "spillway-momentum-tape", "version": 2, "name": "r15-night-shift-%s-%s" % [opts.get("route", "tape"), game.get("preset_id")],
		"description": "%s; driver-applied events on the actual r15 main hosting Night Shift, physics tick %d Hz, warmup %d steps, source sensitivity %s, look %.17f rad/count" % [mode, hz, warmup, settings.get("sensitivity"), radians_per_count],
		"physics_hz": hz, "input_profile": "physics_tick", "duration_ticks": tick + 1, "duration_s": float(tick + 1) / hz, "mouse_quantize": "float32",
		"events": events}
	var file := FileAccess.open(out_dir.path_join("events.tape.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(tape, " ", false, true))
	file.close()
	file = FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(trace_lines) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("night shift driver: %s finish=%s time=%s kind=%s respawns=%s nodes=%d/%d min_y=%.2f max=%.0f u/s walls=%d ducked=%d final=%s on %s" % [reason, finish_tick, summary.finish_time_s, summary.finish_kind,
		summary.respawns, node_ticks.size(), nodes.size(), min_y, max_speed / U, wall_ticks, ducked_ticks, final, summary.final_support])
	game.call("request_quit", 0)
	quit(0)

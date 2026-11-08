extends "res://tests/r15_whiteout_driver.gd"
## p / independent input/contact challenge on the actual r15 host, not release acceptance.
## inherited controllers are explicitly state aware. diagnostic episodes alone seed one pose
## and velocity before tick zero; no episode writes movement state after that setup.

const BW := preload("res://tests/r15_breakwater_driver.gd")
var review_rows := PackedStringArray()
var actions: Array = []
var setup: Dictionary = {}
var initial: Dictionary = {}
var side_ticks := 0
var blocking_side_ticks := 0
var overlap_ticks := 0
var blocked_ticks := 0
var duck_lands := 0
var phase := 0
var phase_tick := -1
var review_case := ""
var selected_map := ""
var diagnostic := false
var seed_pose := Transform3D.IDENTITY
var seed_velocity := Vector3.ZERO

func _start() -> void:
	review_case = str(opts.get("case", "ordinary"))
	selected_map = str(opts.get("map", "whiteout-relay"))
	max_ticks = int(opts.get("max-ticks", "14000"))
	amp = deg_to_rad(30.0)
	game = MAIN.new()
	game.name = "R15"
	game.map_id = selected_map
	game.set_window_title = false
	game.persist = true
	game.seed_from_r14 = false
	game.profile_path = out_dir.path_join("review-profile.cfg")
	root.add_child(game)
	lab = game
	level = game.level
	player = game.player
	source = true
	hz = Engine.physics_ticks_per_second
	warmup = 33
	radians_per_count = float(player.tape_radians_per_count)
	turn_cap = deg_to_rad(600.0) / hz
	if str(opts.get("preset", "server128")) == "server128_aa1000":
		_tap("f5", -1)
	else:
		_tap("f2", -1)
	initial = _attempt()
	setup = {"kind": "normal spawn", "movement_writes_after_setup": 0}
	if selected_map == "breakwater":
		var bw := BW.new()
		var route := review_case if review_case in ["ordinary", "earned", "alley_recovery", "harbour_recovery"] else "ordinary"
		nodes = bw.bw_routes[route].duplicate(true)
		bw.free()
	else:
		var route := review_case if wo_routes.has(review_case) else "ordinary"
		nodes = wo_routes[route].duplicate(true)
		if review_case == "chasm_miss":
			nodes = HANGAR + ROAD + PYLONS + [{"p": Vector2(0, -185), "respawn": true}] + CATWALK + RING + WEAVE + RELAY
		if review_case in ["gantry_stand", "gantry_hold", "gantry_practice", "practice_finish"]:
			game.practise_stage(4)
			setup = {"kind": "authored checkpoint practice", "stage": 4, "movement_writes_after_setup": 0}
			nodes = GANTRY + RELAY if review_case != "practice_finish" else WEAVE + RELAY
		if review_case.begins_with("under_pylon"):
			diagnostic = true
			max_ticks = 140
			var x := 7.0 if review_case.ends_with("open") else 1.0
			var pose := Transform3D(Basis.IDENTITY, Vector3(x, -2.5, -129))
			seed_pose = pose
			seed_velocity = Vector3(0, 150.0 * U, 0)
			setup = {"kind": "seeded diagnostic, not reachable route proof", "pose_m": _vec(pose.origin), "velocity_u_s": [0,150,0], "movement_writes_after_setup": 0}
			nodes = [{"p": Vector2(x, -129)}]
	if review_case == "crown_contact" or review_case == "crown_open":
		diagnostic = true
		max_ticks = 150
		var pose := Transform3D(Basis.IDENTITY, Vector3(-81.0 if review_case == "crown_contact" else -75.0, 0.6, -150))
		seed_pose = pose
		seed_velocity = Vector3(-300.0 * U, 0, -400.0 * U)
		setup = {"kind": "seeded diagonal airborne diagnostic", "pose_m": _vec(pose.origin), "velocity_u_s": [-300,0,-400], "movement_writes_after_setup": 0}
		nodes = [{"p": Vector2(-75,-155)}]
	initial = _attempt()
	node_from = Vector2(player.global_position.x, player.global_position.z)
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)

func late_step() -> void:
	# p / seed after warmup, just before the first controlled tick.
	if diagnostic and not armed and step + 1 == warmup:
		player.reset_to(seed_pose)
		player.velocity = seed_velocity
	super.late_step()

func _key(key: String, pressed: bool, tick: int) -> void:
	var utility := {"f2": KEY_F2, "f5": KEY_F5, "f": KEY_F, "r": KEY_R}
	if not utility.has(key):
		super._key(key, pressed, tick)
		return
	var e := InputEventKey.new()
	e.keycode = utility[key]
	e.physical_keycode = utility[key]
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	events.append({"tick": tick, "key": key, "edge": "press" if pressed else "release"})

func _tap(key: String, tick: int) -> void:
	var before := _attempt()
	_key(key, true, tick)
	_key(key, false, tick)
	actions.append({"tick": tick, "key": key, "before": before, "after": _attempt()})

func _control_source(tick: int) -> void:
	if diagnostic:
		var want := {}
		if review_case.begins_with("under_pylon"):
			if review_case.contains("hold") or tick < 18:
				want["ctrl"] = true
		_want(want, tick)
		return
	if review_case == "preset_taint":
		if phase == 0 and game.checkpoint_index >= 1:
			_tap("f5", tick)
			phase = 1
			phase_tick = tick
		elif phase == 1 and tick - phase_tick > 64:
			_tap("f2", tick)
			phase = 2
	if review_case == "map_reset" and phase == 0 and game.checkpoint_index >= 1:
		_want({}, tick)
		_tap("f", tick)
		var before := _attempt()
		game.select_map("breakwater")
		var other := _attempt()
		game.select_map("whiteout-relay")
		level = game.level
		player = game.player
		actions.append({"tick": tick, "menu": "select_map breakwater, then whiteout-relay", "before": before, "other": other, "after": _attempt()})
		nodes = wo_routes.ordinary.duplicate(true)
		node_index = 0
		node_from = Vector2.ZERO
		jump_wait = false
		airborne_seen = false
		phase = 1
		return
	super._control_source(tick)

func _want(want: Dictionary, tick: int) -> void:
	if review_case == "gantry_stand":
		want.erase("ctrl")
	if review_case == "gantry_hold" and duck_jumped:
		want["ctrl"] = true
	super._want(want, tick)

func _route_finished(tick: int) -> bool:
	if diagnostic:
		return false
	if review_case == "gantry_stand" and not ducks.is_empty() and ducks[-1].has("landed_on_gantry"):
		return true
	return super._route_finished(tick)

func _observe(tick: int) -> void:
	super._observe(tick)
	var s: Dictionary = player.get_motion_state()
	var contacts: Array = []
	var side := false
	var blocking := false
	for c: Dictionary in s.contacts:
		var normal: Vector3 = c.normal
		var body := level.get_node_or_null(NodePath(str(c.body)))
		var row := c.duplicate()
		row.normal = _vec(normal)
		row.position = _vec(c.position)
		row["role"] = str(body.get_meta("surface", "")) if body != null else ""
		contacts.append(row)
		if absf(normal.y) < 0.7:
			side = true
			blocking = blocking or bool(c.blocking)
	side_ticks += int(side)
	blocking_side_ticks += int(blocking)
	blocked_ticks += int(s.duck.stand_blocked)
	duck_lands += int("land" in s.events and bool(s.hull.ducked))
	# p / shrink by 6 mm per face to exclude ordinary 2 mm contact margins.
	var box := BoxShape3D.new()
	var height := float(s.hull.height_u) * U
	box.size = Vector3(32.0 * U - 0.012, height - 0.012, 32.0 * U - 0.012)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP * height * 0.5)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var overlaps: Array = []
	for hit: Dictionary in game.get_world_3d().direct_space_state.intersect_shape(query, 8):
		overlaps.append(str(hit.collider.name))
	overlap_ticks += int(not overlaps.is_empty())
	var duck: Dictionary = s.duck.duplicate(true)
	duck.shift_u = _vec(duck.shift_u)
	duck.compensation_u = _vec(duck.compensation_u)
	if duck.stand_probe.has("target_u"):
		duck.stand_probe.target_u = _vec(duck.stand_probe.target_u)
	review_rows.append(JSON.stringify({"t": tick, "p": _vec(player.global_position), "v_u": _vec(player.velocity / U), "yaw": player.yaw,
		"start_v_m": _vec(s.start_velocity), "requested_v_m": _vec(s.requested_velocity), "actual_v_m": _vec(s.actual_velocity), "displacement": _vec(s.displacement),
		"ledger": _pack(s.ledger), "g": s.grounded, "support": _support(player.global_position), "contacts": contacts,
		"hull": s.hull, "duck": duck, "e": s.events, "held": held.keys(),
		"overlaps": overlaps, "game": _attempt(), "steps": s.step_ups, "rate_matches": s.rate_matches}))

func _attempt() -> Dictionary:
	return {"map": game.map_id, "preset": game.preset_id, "key": game.course_key, "attempt": game.attempts,
		"elapsed": game.elapsed, "checkpoint": game.checkpoint_index, "clean": game.clean_eligible, "reason": game.practice_reason,
		"practice_stage": game.practice_stage, "respawns": game.respawn_count, "finished": game.finished, "kind": game.finish_kind,
		"best": game.best_time, "open_best": game.open_best_time, "splits": game.stage_times.duplicate(), "persist": game.persist}

func _end(reason: String, tick: int) -> void:
	done = true
	_want({}, tick)
	var summary := {"case": review_case, "map": selected_map, "label": "independent state-aware input challenge; headless source, not acceptance",
		"setup": setup, "initial": initial, "final": _attempt(), "reason": reason, "ticks": tick,
		"actual_settings": player.settings, "engine_hz": Engine.physics_ticks_per_second, "warmup": warmup, "radians_per_count": radians_per_count,
		"runner": player.get_script().resource_path, "motor_version": player.MOTOR_VERSION,
		"geometry": level.geometry_hash(), "side_contact_ticks_abs_ny_lt_0_7": side_ticks, "blocking_side_ticks": blocking_side_ticks,
		"inherited_wall_role_ticks": wall_ticks, "interior_overlap_ticks": overlap_ticks, "stand_blocked_ticks": blocked_ticks,
		"duck_landings": duck_lands, "ducks": ducks, "actions": actions, "respawn_events": respawn_events,
		"flights": flights, "supports": supports, "hops": hops, "sinks": sinks, "nodes_reached": node_index, "nodes": nodes.size(), "checkpoints": checkpoint_ticks}
	_write("summary.json", summary)
	_write("input.json", {"events": events, "note": "utility setup ticks -1 and menu/practice actions are labelled in summary; not a strict replay tape"})
	var f := FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	f.store_buffer(("\n".join(review_rows) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	f.close()
	print("maps review: %s/%s %s %s sides=%d overlap=%d blocked=%d ticks=%d" % [selected_map, review_case, reason, game.finish_kind, side_ticks, overlap_ticks, blocked_ticks, tick])
	quit(0)

static func _vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func _pack(value: Variant) -> Variant:
	if value is Vector3:
		return _vec(value)
	if value is Dictionary:
		var out := {}
		for k: Variant in value:
			out[k] = _pack(value[k])
		return out
	return value

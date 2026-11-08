extends "res://tests/r15_sunken_driver.gd"
## p / independent input/contact challenge on the actual r15 host, not release acceptance.
## inherited controllers are explicitly state aware. diagnostic episodes alone seed one pose
## and velocity before tick zero; no episode writes movement state after that setup.

const RL := preload("res://tests/r15_rainline_driver.gd")
const NT := preload("res://tests/r15_nightshift_driver.gd")
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
	selected_map = str(opts.get("map", "sunken-court"))
	max_ticks = int(opts.get("max-ticks", "16000"))
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
	_tap("f5" if str(opts.get("preset", "server128")) == "server128_aa1000" else "f2", -1)
	setup = {"kind": "normal spawn", "movement_writes_after_setup": 0}
	if selected_map == "sunken-court":
		nodes = sk_routes.get(review_case, sk_routes.ordinary).duplicate(true)
		if review_case.begins_with("causeway_") and review_case != "causeway_chain":
			nodes = (GATE + STEPS + COURT + ARC + CAUSEWAY + RISE).duplicate(true)
		if review_case == "east_cistern":
			nodes = (GATE + STEPS + COURT + ARC + [{"p": Vector2(49,-59)}, {"p": Vector2(47,-49), "fall": 4.0}, {"p": Vector2(49.8,-47)}, {"p": Vector2(49.8,-59)}, {"p": Vector2(53.5,-59)}] + WALKS.slice(2) + RISE).duplicate(true)
		if review_case == "arch_return":
			nodes = (GATE + STEPS + [{"p":Vector2(10,-57),"fall":0.0},{"p":Vector2(0,-56.8)},{"p":Vector2(0,-59.5)},{"p":Vector2(10,-59.5)},{"p":Vector2(10,-68)},{"p":Vector2(-12,-68)},{"p":Vector2(-20,-97)},{"p":Vector2(-20,-53)},{"p":Vector2(-6,-48.5)},{"p":Vector2(0,-51)}] + COURT + ARC + WALKS + RISE).duplicate(true)
	elif selected_map == "rainline":
		var driver := RL.new()
		nodes = driver.rl_routes.get("duct" if review_case.begins_with("duct") else "ordinary").duplicate(true)
		driver.free()
		if review_case == "reverse_duct":
			game.practise_stage(4)
			setup.kind = "authored checkpoint practice 4, reverse duct"
			nodes = [{"p":Vector2(51.5,-35),"duck_hold":true},{"p":Vector2(51.5,-49),"duck_hold":true},{"p":Vector2(51.5,-56)}]
		for node: Dictionary in nodes:
			if node.has("duck"):
				node.erase("duck")
				node.duck_hold = true
	else:
		var driver := NT.new()
		var routes := driver._routes()
		nodes = routes.get("crouch" if review_case.begins_with("hatch") else "ordinary").duplicate(true)
		driver.free()
		if review_case == "throat_return":
			nodes = [{"p":Vector2(0,-34),"hop":true},{"p":Vector2(8,-49),"fall":-0.7},{"p":Vector2(9,-56)},{"p":Vector2(9,-43)},{"p":Vector2(0,-43)}] + nodes.slice(1)
	if review_case in ["air_checkpoint", "wrong_deck", "side_contact", "side_open"]:
		diagnostic = true
		max_ticks = 180
		var pos := Vector3.ZERO
		if review_case == "air_checkpoint":
			pos = (level.checkpoints[1].pose as Transform3D).origin + Vector3.UP * 1.0
			if selected_map == "rainline":
				pos.x = 14.5
			seed_velocity = Vector3(0,150.0*U,0)
		elif review_case == "wrong_deck":
			pos = {"sunken-court":Vector3(0,-1.96,-56.8), "rainline":Vector3(51.5,0.64,-38), "night-shift":Vector3(0,0.04,6.5)}[selected_map]
		else:
			pos = {"sunken-court":Vector3(6.9,7.4,-20), "rainline":Vector3(28.9,-3.8,-99), "night-shift":Vector3(4.9,0.6,-20)}[selected_map]
			if review_case == "side_open":
				pos.x -= 3.0
			seed_velocity = Vector3(300*U,0,-400*U)
		seed_pose = Transform3D(Basis.IDENTITY,pos)
		setup = {"kind":"seeded diagnostic only", "pose_m":_vec(pos), "velocity_u_s":_vec(seed_velocity/U), "movement_writes_after_setup":0}
		nodes = [{"p":Vector2(pos.x,pos.z)}]
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
		if review_case == "air_checkpoint":
			_key("ctrl", tick < 18, tick)
		_want({}, tick)
		return
	if review_case == "practice_finish" and phase == 0 and game.checkpoint_index >= 3:
		_want({},tick)
		_tap("f",tick)
		if selected_map == "sunken-court":
			nodes = (WALKS + RISE).duplicate(true)
		elif selected_map == "rainline":
			nodes = RL.ROUND.duplicate(true)
		else:
			var driver := NT.new()
			nodes = driver._routes().ordinary.slice(12).duplicate(true)
			driver.free()
		node_index = 0
		node_from = Vector2(player.global_position.x,player.global_position.z)
		jump_wait = false
		airborne_seen = false
		phase = 1
		return
	if review_case == "restart" and phase == 0 and game.checkpoint_index >= 1:
		_want({},tick)
		_tap("f",tick)
		_tap("r",tick)
		phase = 1
		_end("utility",tick)
		return
	if review_case == "map_keys" and tick == 20:
		_want({},tick)
		for id: String in ["sunken-court","rainline","night-shift",selected_map]:
			var before := _attempt()
			game.select_map(id)
			level = game.level
			player = game.player
			actions.append({"tick":tick,"menu_map":id,"before":before,"after":_attempt(),"identity":game.record_identity()})
		_tap("f5",tick)
		_tap("f2",tick)
		_end("utility",tick)
		return
	if selected_map == "rainline":
		var node: Dictionary = nodes[node_index] if node_index < nodes.size() else {}
		if player.is_grounded():
			_key("ctrl",bool(node.get("duck_hold",false)),tick)
		if review_case == "duct_release" and player.global_position.z > -42 and player.global_position.z < -32:
			_key("ctrl",false,tick)
		if review_case == "duct_stand":
			_key("ctrl",false,tick)
	if selected_map == "night-shift" and review_case.begins_with("hatch"):
		var p := player.global_position
		var inside := p.x >= 46.4 and p.x <= 52.0 and p.z >= -90.4 and p.z <= -87.25
		if inside and not held.has("ctrl") and player.is_grounded():
			inside = false
		if review_case == "hatch_release" and p.z > -88.45:
			inside = false
		if review_case == "hatch_stand":
			inside = false
		_key("ctrl",inside,tick)
	super._control_source(tick)
	if selected_map == "sunken-court" and review_case == "causeway_release" and player.ducked and player.global_position.y > 6.3:
		_key("ctrl",false,tick)
	if selected_map == "sunken-court" and review_case == "causeway_stand":
		_key("ctrl",false,tick)

func _route_finished(tick: int) -> bool:
	if diagnostic:
		return false
	if review_case in ["duct_stand","hatch_stand","hatch_release","causeway_stand","causeway_release"] and side_ticks > 16:
		return true
	return super._route_finished(tick)

func _observe(tick: int) -> void:
	super._observe(tick)
	trace_lines.clear()
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
		"ledger": _pack(s.ledger), "delivered": _delivered(), "n": node_index, "ref": _vec(game.body_reference()), "g": s.grounded, "support": _support(player.global_position), "contacts": contacts,
		"hull": s.hull, "duck": duck, "e": s.events, "held": held.keys(),
		"overlaps": overlaps, "game": _attempt(), "steps": s.step_ups, "rate_matches": s.rate_matches}))

func _delivered() -> Array:
	var out: Array = []
	for k: String in {"w":KEY_W,"a":KEY_A,"s":KEY_S,"d":KEY_D,"space":KEY_SPACE,"ctrl":KEY_CTRL}:
		if Input.is_physical_key_pressed({"w":KEY_W,"a":KEY_A,"s":KEY_S,"d":KEY_D,"space":KEY_SPACE,"ctrl":KEY_CTRL}[k]):
			out.append(k)
	return out

func _attempt() -> Dictionary:
	return {"map": game.map_id, "preset": game.preset_id, "key": game.course_key, "attempt": game.attempts,
		"elapsed": game.elapsed, "checkpoint": game.checkpoint_index, "clean": game.clean_eligible, "reason": game.practice_reason,
		"practice_stage": game.practice_stage, "respawns": game.respawn_count, "finished": game.finished, "kind": game.finish_kind,
		"best": game.best_time, "open_best": game.open_best_time, "splits": game.stage_times.duplicate(), "persist": game.persist}

func _end(reason: String, tick: int) -> void:
	done = true
	_want({}, tick)
	var summary := {"case": review_case, "map": selected_map, "label": "independent state-aware input challenge; headless source, not acceptance",
		"setup": setup, "initial": initial, "final": _attempt(), "reason": reason, "ticks": review_rows.size(), "caller_end_tick": tick,
		"actual_settings": player.settings, "engine_hz": Engine.physics_ticks_per_second, "warmup": warmup, "radians_per_count": radians_per_count,
		"runner": player.get_script().resource_path, "motor_version": player.MOTOR_VERSION,
		"geometry": level.geometry_hash(), "side_contact_ticks_abs_ny_lt_0_7": side_ticks, "blocking_side_ticks": blocking_side_ticks,
		"inherited_wall_role_ticks": wall_ticks, "interior_overlap_ticks": overlap_ticks, "stand_blocked_ticks": blocked_ticks,
		"duck_landings": duck_lands, "crouch_events": crouch_events, "actions": actions, "respawn_events": respawn_events,
		"flights": flights, "supports": supports, "hops": hops, "sinks": sinks, "nodes_reached": node_index, "nodes": nodes.size(), "checkpoints": checkpoint_ticks}
	_write("summary.json", summary)
	_write("input.json", {"events": events, "note": "utility setup ticks -1 and menu/practice actions are labelled in summary; not a strict replay tape"})
	var f := FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	f.store_buffer(("\n".join(review_rows) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	f.close()
	print("courses review: %s/%s %s %s sides=%d overlap=%d blocked=%d ticks=%d" % [selected_map, review_case, reason, game.finish_kind, side_ticks, overlap_ticks, blocked_ticks, tick])
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

extends "res://tests/r14_practice_driver.gd"
## independent imperfect feedback controller on the actual product main. inherited route goals
## and takeoff planner are author information, not discovery. air decisions use a fixed bank
## angle, delayed coarse steering and bounded mouse noise, not the author's optimal wish law.
const GAME := preload("res://scripts/r14_main.gd")
var rng := RandomNumberGenerator.new()
var policy_tick := 0
var mouse_credit := 0.0
var last_air_keys := {}
var last_air_update := -100
var extra := {}
var noise := 0.5
var feedback_hz := 32
var bank := 1.5
var edge_stall_tick := -1
var edge_observation := {}
var edge_aligned := false
var edge_rescued := false

func _start() -> void:
	max_ticks = int(opts.get("max-ticks", "12000"))
	rng.seed = int(opts.get("seed", "1"))
	noise = float(opts.get("noise", "0.5"))
	feedback_hz = int(opts.get("feedback-hz", "32"))
	bank = float(opts.get("bank", "1.5"))
	amp = deg_to_rad(18.0)
	lab = GAME.new()
	lab.set("set_window_title", false)
	lab.set("motor", str(opts.get("preset", "server128")))
	root.add_child(lab)
	level = lab.get("level")
	player = lab.get("player")
	source = true
	hz = Engine.physics_ticks_per_second
	warmup = int(EXECUTOR_ARM_STEP.get(hz, 32))
	radians_per_count = float(player.get("tape_radians_per_count"))
	turn_cap = deg_to_rad(360.0) / hz
	var route := str(opts.get("route", "basic"))
	var itinerary: Array = (ROUTES.basic as Array).slice(0, 12) + (ROUTES.advanced as Array).slice(13) if route == "gauges" else ROUTES[route]
	for i: int in itinerary.size():
		var node: Dictionary = (itinerary[i] as Dictionary).duplicate()
		if STRAFE_FRONT.has(route) and i >= int(STRAFE_FRONT[route][0]) and i < FRONT.size():
			node["vt"] = float(STRAFE_FRONT[route][1])
		nodes.append(node)
	if opts.has("tail-edge"):
		for node: Dictionary in nodes:
			if node.has("p") and node.p == Vector2(-226.0, -136.3):
				node.p = Vector2(-227.8, -136.3)
				node.r = 0.15
			elif node.has("p") and node.p == Vector2(-226.0, -119.0):
				node.p = Vector2(-227.8, -119.0)
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	root.add_child(hook)
	print("review policy product=%s route=%s seed=%s noise=%s feedback=%d bank=%s geometry=%s" % [lab.get("preset_id"), route, rng.seed, noise, feedback_hz, bank, level.call("geometry_hash")])

func _control_source(tick: int) -> void:
	policy_tick = tick
	var p := player.global_position
	if opts.has("tail-edge") and p.y < -3.5 and p.z > -135.0 and p.z < -134.8 and absf(p.x + 227.8) < 0.15 and Vector2(player.velocity.x, player.velocity.z).length() < 0.2:
		if edge_stall_tick < 0:
			edge_stall_tick = tick
		if tick - edge_stall_tick == 2 * hz:
			edge_observation = {"stall_start": edge_stall_tick, "at": _v(p), "tick": tick, "node": node_index}
			if opts["tail-edge"] == "block":
				_end("tail_inner_edge_stall", tick)
				return
			# input-only escape: turn toward the centre of the lane, then continue climbing.
			nodes.insert(node_index, {"p": Vector2(-226.4, -135.5), "r": 0.3})
			nodes[node_index + 1]["p"] = Vector2(-226.4, -119.0)
			edge_rescued = true
	if opts.has("tail-edge") and node_index == 24 and not edge_rescued:
		_turn_to(PI)
		var dx := -227.8 - p.x
		var want := {}
		var correction := dx * 8.0 - player.velocity.x * 2.0
		if absf(correction) > 0.12:
			want["d" if correction < 0.0 else "a"] = true
		if absf(dx) < 0.04 and absf(player.velocity.x) < 0.12 and absf(wrapf(float(player.get("yaw")) - PI, -PI, PI)) < 0.05:
			edge_aligned = true
		if edge_aligned:
			want.w = true
		_want(want, tick)
		return
	super._control_source(tick)

func _air(here: Vector2, aim: Vector2, vt: float, landing: bool) -> Dictionary:
	if policy_tick - last_air_update < maxi(1, hz / feedback_hz):
		return last_air_keys.duplicate()
	last_air_update = policy_tick
	var to := aim - here
	var vel := Vector2(player.velocity.x, player.velocity.z)
	if vel.length() < 0.5 or to.length() < 0.15:
		last_air_keys = {}
		return {}
	var heading := atan2(-vel.x, -vel.y)
	var desired := atan2(-to.x, -to.y)
	var err := wrapf(desired - heading, -PI, PI)
	var side := -1.0 if err > 0.0 else 1.0
	if vt > vel.length() / U:
		if flight_side == 0.0:
			flight_side = side
		if err > deg_to_rad(18.0):
			flight_side = -1.0
		elif err < deg_to_rad(-18.0):
			flight_side = 1.0
		side = flight_side
	elif absf(err) < deg_to_rad(2.0):
		_turn_to(desired)
		last_air_keys = {}
		return {}
	if landing and player.velocity.y < -4.0 and absf(err) < deg_to_rad(4.0):
		_turn_to(desired)
		last_air_keys = {}
		return {}
	# a fixed small bank toward the desired turn; no air-budget or optimal-angle helper.
	_turn_to(heading + side * deg_to_rad(bank))
	last_air_keys = {"a": true} if side < 0.0 else {"d": true}
	# avoid blindly holding the side key while the view is still rotating across the travel.
	var yaw := float(player.get("yaw"))
	var right := Vector2(cos(yaw), -sin(yaw)) * side
	if right.dot(vel.normalized()) < -0.06:
		last_air_keys = {}
	return last_air_keys.duplicate()

func _turn_to(target: float) -> float:
	var err := wrapf(float(player.get("yaw")) - target, -PI, PI)
	var turn := clampf(err * 0.32 + deg_to_rad(rng.randf_range(-noise, noise)), -turn_cap, turn_cap)
	_noisy_mouse(turn)
	return float(player.get("yaw"))

func _look(here: Vector2, target: Vector2) -> void:
	var to := target - here
	if to.length() < 0.05:
		return
	_turn_to(atan2(-to.x, -to.y))

func _noisy_mouse(turn: float) -> void:
	mouse_credit += turn / radians_per_count
	var count := roundf(mouse_credit)
	mouse_credit -= count
	if count != 0.0:
		_mouse(count, -1)

func _observe(tick: int) -> void:
	super._observe(tick)
	if opts.get("visual", "0") == "1" and edge_stall_tick >= 0 and tick == edge_stall_tick + hz:
		_capture_review.call_deferred("tail-edge-product.png")
	var s: Dictionary = player.call("get_motion_state")
	if not (s.contacts as Array).is_empty():
		var contacts: Array = []
		for c: Dictionary in s.contacts:
			contacts.append({"body": c.body, "phase": c.phase, "normal": _v(c.normal), "fraction": c.fraction})
		extra[str(tick)] = {"p": _v(player.global_position), "contacts": contacts, "depenetration": _v(s.depenetration)}

func _end(reason: String, tick: int) -> void:
	done = true
	for key: String in held.keys():
		_key(key, false, tick)
	var summary := {"reason": reason, "route": opts.get("route", "basic"), "seed": opts.get("seed", "1"), "noise_deg_bounded": noise, "feedback_hz": feedback_hz, "bank_deg": bank,
		"information_access": "author waypoint/takeoff planner inherited; independent fixed-bank feedback air policy; exact position/velocity/grounded; not discovery, not human play",
		"game": "r14_main.gd actual product default look scale", "setup": "main normal spawn only; no subsequent pose/velocity/view writes", "physics_hz": hz,
		"look_radians_per_count": radians_per_count, "geometry": level.call("geometry_hash"), "player_sha256": FileAccess.get_sha256("res://scripts/r14_source_player.gd"),
		"motion_sha256": FileAccess.get_sha256("res://scripts/r14_source_motion.gd"), "finished": lab.get("finished"), "finish_kind": lab.get("finish_kind"), "elapsed": lab.get("elapsed"),
		"respawns": lab.get("respawn_count"), "stages": checkpoint_ticks, "nodes": node_ticks, "min_y": min_y, "max_speed_ups": max_speed / U, "sinks": sinks, "walls": wall_bodies,
		"final": _v(player.global_position), "support": _support(player.global_position), "missed": missed, "flights": flights, "edge_observation": edge_observation}
	_write("summary.json", summary)
	var tape := {"format": "spillway-momentum-tape", "version": 2, "name": "review-%s-%s" % [opts.get("route", "basic"), rng.seed], "description": "state-aware noisy feedback; product Source default sensitivity 2.5",
		"physics_hz": hz, "input_profile": "physics_tick", "duration_ticks": tick + 1, "duration_s": float(tick + 1) / hz, "mouse_quantize": "float32", "events": events}
	_write("events.tape.json", tape)
	var f := FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	f.store_buffer(("\n".join(trace_lines) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	f.close()
	f = FileAccess.open(out_dir.path_join("contacts.json.gz"), FileAccess.WRITE)
	f.store_buffer(JSON.stringify(extra).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	f.close()
	print("review policy result=%s finish=%s time=%s nodes=%d/%d sinks=%s at=%s" % [reason, lab.get("finished"), lab.get("elapsed"), node_ticks.size(), nodes.size(), sinks, player.global_position])
	quit()

func _capture_review(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name))

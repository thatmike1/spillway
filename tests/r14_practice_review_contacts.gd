extends SceneTree
## independent production-adapter diagnostics and input-only local recovery probes.
## every episode gets exactly one labelled setup. raw-cast seeds are not gameplay.
const LEVEL := preload("res://scripts/r14_practice_level.gd")
const PLAYER := preload("res://scripts/r14_source_player.gd")
const MAIN := preload("res://scripts/spillway_main.gd")
const U := 0.0254
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE}
signal episode_done
var opts := {}
var out := ""
var level: Node3D
var player: CharacterBody3D
var rows: Array = []
var results: Array = []
var active := false
var frame := 0
var limit := 0
var spec := {}
var held := {}
var before := Vector3.ZERO
var before_v := Vector3.ZERO
var hz := 128
var rng := RandomNumberGenerator.new()
var goal_index := 0
var peak_sink := 0.0
var start := Vector3.ZERO
var visual := false
var captures: Array = []

class Hook:
	extends Node
	var suite: Object
	var early := false
	func _physics_process(dt: float) -> void:
		suite.call("pre" if early else "post", dt)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			opts[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	out = str(opts.get("out", ""))
	assert(out.is_absolute_path())
	visual = opts.get("visual", "0") == "1"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	MAIN.bind_inputs()
	level = LEVEL.new()
	root.add_child(level)
	level.call("build")
	for early: bool in [true, false]:
		var hook := Hook.new()
		hook.suite = self
		hook.early = early
		hook.process_physics_priority = -1000 if early else 1000
		root.add_child(hook)
	await physics_frame
	await physics_frame
	if opts.get("mode", "local") == "casts":
		await _casts()
	elif opts.get("mode", "local") == "earned":
		await _earned()
	else:
		await _locals()
	var f := FileAccess.open(out.path_join("summary.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"geometry": level.call("geometry_hash"), "player_sha256": FileAccess.get_sha256("res://scripts/r14_source_player.gd"), "motion_sha256": FileAccess.get_sha256("res://scripts/r14_source_motion.gd"), "episodes": results}, "\t"))
	f.close()
	print("review contacts: %d episodes saved %s" % [results.size(), out])
	quit()

func run_episode(s: Dictionary) -> void:
	active = false
	for k: String in KEYS:
		key(k, false)
	if player != null:
		player.queue_free()
		await process_frame
	player = PLAYER.new()
	player.input_enabled = false
	root.add_child(player)
	hz = int(s.get("hz", 128))
	player.call("apply_preset", "csgo_server" if hz == 128 else "csgo_vanilla")
	player.settings.tickrate = hz
	player.call("apply_engine_rate")
	var pose := Transform3D(Basis(Vector3.UP, float(s.get("yaw", 0.0))), s.p)
	player.call("reset_to", pose)
	player.velocity = s.get("velocity", Vector3.ZERO)
	player.state.grounded = bool(s.get("grounded", false))
	player.state.ground_normal = Vector3.UP if player.state.grounded else Vector3.ZERO
	player.state.ground_ticks = 100 if player.state.grounded else 0
	if visual:
		root.size = Vector2i(640, 360)
		player.set("pitch", -0.20)
	# the only setup block ends here; from here the production motor owns all motion.
	spec = s
	start = player.global_position
	frame = 0
	limit = int(s.get("ticks", hz * 5))
	rows = []
	goal_index = 0
	peak_sink = 0.0
	rng.seed = int(s.get("seed", 1))
	await physics_frame
	var query := PhysicsShapeQueryParameters3D.new()
	var hull := BoxShape3D.new()
	hull.size = Vector3(32, 72, 32) * U
	query.shape = hull
	query.transform = Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP * 36.0 * U)
	query.collision_mask = 1
	query.margin = 0.0001
	query.exclude = [player.get_rid()]
	s["setup_overlaps"] = []
	for h: Dictionary in level.get_world_3d().direct_space_state.intersect_shape(query, 16):
		(s["setup_overlaps"] as Array).append(str((h.collider as Node).name))
	player.input_enabled = true
	active = true
	await episode_done
	var path := out.path_join(str(s.name) + ".jsonl.gz")
	var f := FileAccess.open(path, FileAccess.WRITE)
	var lines := PackedStringArray()
	for row: Dictionary in rows:
		lines.append(JSON.stringify(row))
	f.store_buffer(("\n".join(lines) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	f.close()
	var end := player.global_position
	var result := {"name": s.name, "setup": plain(s), "end": plain(end), "peak_sink_m": peak_sink, "goals_reached": goal_index, "ticks": frame,
		"min_y": rows.map(func(r: Dictionary) -> float: return float(r.p[1])).min(), "final_grounded": player.call("is_grounded")}
	results.append(result)
	print("review contact episode %s end=%s sink=%.4f goals=%d" % [s.name, end, peak_sink, goal_index])

func pre(_dt: float) -> void:
	if not active:
		return
	before = player.global_position
	before_v = player.velocity
	var want := {}
	if spec.get("policy", "release") == "goals":
		var goals: Array = spec.goals
		var p := player.global_position
		if goal_index < goals.size() and Vector2(p.x, p.z).distance_to(goals[goal_index]) < 0.6:
			goal_index += 1
		if goal_index < goals.size():
			var to: Vector2 = goals[goal_index] - Vector2(p.x, p.z)
			var desired := atan2(-to.x, -to.y)
			var err := wrapf(float(player.get("yaw")) - desired, -PI, PI)
			var turn := clampf(err * 0.25 + deg_to_rad(rng.randf_range(-0.12, 0.12)), -deg_to_rad(360.0) / hz, deg_to_rad(360.0) / hz)
			mouse(roundf(turn / float(player.get("tape_radians_per_count"))))
			if player.call("is_grounded"):
				if absf(err) < 0.8:
					want.w = true
			elif frame % 8 < 6:
				want["a" if err < 0.0 else "d"] = true
	elif spec.get("policy", "release") == "earned":
		var jt := int(spec.jump_at)
		if frame < jt:
			want.w = true
		elif frame == jt:
			want.w = true
			want.space = true
		elif frame < jt + int(hz * 0.55):
			var side := float(spec.get("side", -1.0))
			want["a" if side < 0.0 else "d"] = true
			mouse(side * float(spec.get("mouse", 0.8)))
	elif spec.get("policy", "release") == "run":
		want.w = true
		if spec.get("jump_at", -1) == frame:
			want.space = true
	elif spec.get("policy", "release") == "hop":
		if player.call("is_grounded"):
			want.w = true
			if frame >= int(spec.get("jump_at", 96)):
				want.space = true
		else:
			var side := -1.0 if (frame / 32) % 2 == 0 else 1.0
			mouse(side * float(spec.get("mouse", 0.6)))
			want["a" if side < 0 else "d"] = true
	for k: String in KEYS:
		key(k, want.has(k))

func post(dt: float) -> void:
	if not active:
		return
	var s: Dictionary = player.call("get_motion_state")
	var p := player.global_position
	var hit := ray(p + Vector3.UP * 0.8, p + Vector3.DOWN * 6.0)
	var top := float(hit.position.y) if not hit.is_empty() else -INF
	var body := str((hit.collider as Node).name) if not hit.is_empty() else ""
	var sink := top - p.y
	if sink > 0 and sink < 1.0:
		peak_sink = maxf(peak_sink, sink)
	rows.append({"t": frame, "p": plain(p), "before": plain(before), "before_v": plain(before_v / U), "v": plain(player.velocity / U), "requested": plain(s.requested_velocity / U),
		"fd": plain((p - before) / dt / U), "g": player.call("is_grounded"), "e": s.events, "contacts": plain(s.contacts), "under": body, "top": top if is_finite(top) else null,
		"depenetration": plain(s.depenetration), "standoff": plain(s.standoff), "keys": held.keys(), "goal": goal_index, "yaw": float(player.get("yaw"))})
	if visual and frame in [0, 48, 96, 144, 192, 240, 320, 448, 576]:
		_capture.call_deferred(str(spec.name) + "-%04d.png" % frame)
	frame += 1
	if frame >= limit:
		active = false
		episode_done.emit()

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name))

func _locals() -> void:
	var only := str(opts.get("only", ""))
	var cases: Array = []
	for rate: int in [128, 64]:
		# approach side edges of both weir ramps from a real pit, earning run speed.
		for z: float in [-106.12, -106.35, -106.55, -107.0, -108.0, -109.45, -109.72]:
			for x: float in [-161.0, -189.0]:
				var top_x := -147.0 if x > -180.0 else -174.0
				cases.append({"name": "ramp%d_x%d_z%s" % [rate, -x, str(z).replace(".", "p")], "hz": rate, "p": Vector3(x, -2.4988, z), "yaw": -PI / 2, "grounded": true,
					"policy": "goals", "goals": [Vector2(top_x, z), Vector2(top_x, -103.5)], "ticks": rate * 5})
		# low valve arrivals are zero-speed pose-only falls, not normal-spawn play.
		for a: float in [25.8, 26.2, 41.8, 42.2, 57.8, 58.2, 67.8, 68.2]:
			for r: float in [10.1, 23.7, 24.3, 25.0]:
				var p: Vector3 = level.call("_ring_point", LEVEL.BEND_L, Vector3.RIGHT, 1.0, r, a)
				p.y = 0.08
				var target: Vector3 = level.call("_ring_point", LEVEL.BEND_L, Vector3.RIGHT, 1.0, 25.0, a)
				var goals: Array = [Vector2(target.x, target.z)]
				var arc := a - 8.0
				while arc > 2.0:
					var pt: Vector3 = level.call("_ring_point", LEVEL.BEND_L, Vector3.RIGHT, 1.0, 25.0, arc)
					goals.append(Vector2(pt.x, pt.z))
					arc -= 8.0
				var end: Vector3 = level.call("_ring_point", LEVEL.BEND_L, Vector3.RIGHT, 1.0, 25.0, 2.0)
				goals.append(Vector2(end.x, end.z))
				goals.append_array([Vector2(6, -40), Vector2(6, -18), Vector2(0, -16)])
				cases.append({"name": "valve%d_a%s_r%s" % [rate, a, r], "hz": rate, "p": p, "yaw": a * PI / 180.0, "policy": "goals",
					"goals": goals, "ticks": rate * 22})
		# tail return ramp inner side versus its centre.
		for x: float in [-228.28, -228.05, -227.8, -227.4, -226.0, -224.4]:
			cases.append({"name": "tail%d_x%s" % [rate, x], "hz": rate, "p": Vector3(x, -3.9988, -136.0), "yaw": PI, "grounded": true, "policy": "goals",
				"goals": [Vector2(x, -116.5), Vector2(-230, -116.0)], "ticks": rate * 6})
		# earned low arrivals at slanted gauge edges and coarse no-view-perfect runway hops.
		for z: float in [-91.0, -98.0, -105.0]:
			for jump_at: int in [96, 128, 160, 192]:
				cases.append({"name": "gauge%d_z%s_jump%d" % [rate, z, jump_at], "hz": rate, "p": Vector3(-154, 0.0012, z), "yaw": PI / 2, "grounded": true,
					"policy": "run", "jump_at": jump_at * rate / 128, "ticks": rate * 3})
		for z: float in [-92.0, -98.0, -104.0]:
			cases.append({"name": "runway%d_z%s" % [rate, z], "hz": rate, "p": Vector3(-23, 0.0012, z), "yaw": PI / 2, "grounded": true, "policy": "hop", "ticks": rate * 14})
	for c: Dictionary in cases:
		if only.is_empty() or only in str(c.name):
			await run_episode(c)

func _earned() -> void:
	var chooser := RandomNumberGenerator.new()
	chooser.seed = 817361
	for i: int in int(opts.get("cases", "1000")):
		var rate := 64 if i % 2 == 0 else 128
		var p := Vector3(chooser.randf_range(-120.0, -30.0), 0.0012, chooser.randf_range(-102, -94))
		await run_episode({"name": "earned_%04d_%d" % [i, rate], "hz": rate, "p": p, "yaw": PI / 2 + chooser.randf_range(-0.25, 0.25), "grounded": true,
			"policy": "earned", "jump_at": int(rate * chooser.randf_range(0.60, 0.8)), "side": -1.0 if i % 4 < 2 else 1.0,
			"mouse": chooser.randf_range(0.2, 1.2), "ticks": int(rate * 1.8)})

func _casts() -> void:
	# locate exact original-grid raw misses before testing the production tick from each seed.
	var motions := {"review64": Vector3(24.8896732, -298.0066223, -299.7286072) / 64.0, "review128": Vector3(24.8896732, -298.0066223, -299.7286072) / 128.0}
	for i: int in 8:
		var h := Vector3(cos(deg_to_rad(45.0 * i)), 0, -sin(deg_to_rad(45.0 * i)))
		for rate: int in [64, 128]:
			motions["dir%d_%d" % [i * 45, rate]] = (h * (300.0 if rate == 64 else 1100.0) + Vector3(0, -298.0, 0)) / rate
	player = PLAYER.new()
	player.input_enabled = false
	root.add_child(player)
	await physics_frame
	var seeds: Array = []
	for entry: Dictionary in level.get("manifest"):
		if opts.get("scope", "selected") != "all" and not (str(entry.name).begins_with("s3_runway_") or str(entry.name) in ["s0_pad", "s4_middle"]):
			continue
		if (entry.get("points", []) as Array).is_empty():
			continue
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var top := -INF
		for p: Vector3 in entry.points:
			top = maxf(top, p.y)
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		var spacing := maxf(0.5, sqrt((hi.x-lo.x) * (hi.y-lo.y) / 600.0))
		var x := lo.x + 0.6
		while x <= hi.x - 0.6:
			var z := lo.y + 0.6
			while z <= hi.y - 0.6:
				var hit := ray(Vector3(x, top + 1.0, z), Vector3(x, top - 30.0, z))
				var interior: bool = not hit.is_empty() and str((hit.collider as Node).name) == str(entry.name) and hit.normal.y >= 0.7
				for offset: Vector2 in [Vector2(0.6, 0), Vector2(-0.6, 0), Vector2(0, 0.6), Vector2(0, -0.6)]:
					var side_hit := ray(Vector3(x + offset.x, top + 1.0, z + offset.y), Vector3(x + offset.x, top - 30.0, z + offset.y))
					interior = interior and not side_hit.is_empty() and str((side_hit.collider as Node).name) == str(entry.name) and side_hit.normal.y >= 0.7
				if interior:
					for name: String in motions:
						var m: Vector3 = motions[name]
						var pos: Vector3 = hit.position + Vector3.UP * (2.97 / (298.0066223 / 64.0)) * -m.y * U
						player.global_position = pos
						if player.move_and_collide(m * U, true, 0.001, true, 4) == null:
							var rate := 64 if name.ends_with("64") else 128
							seeds.append({"name": "%s_%s_%d" % [entry.name, name, seeds.size()], "p": pos, "hz": rate, "velocity": m * U * rate + Vector3.UP * 800.0 * U * 0.5 / rate,
								"grounded": false, "raw_motion_m": m * U, "policy": "release", "ticks": 8})
				z += spacing
			x += spacing
	print("review seeded exact-grid misses selected=", seeds.size())
	for s: Dictionary in seeds:
		if opts.get("only", "") == "" or str(opts["only"]) == str(s.name):
			await run_episode(s)

func key(k: String, down: bool) -> void:
	if held.has(k) == down:
		return
	var e := InputEventKey.new()
	e.keycode = KEYS[k]
	e.physical_keycode = KEYS[k]
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	if down:
		held[k] = true
	else:
		held.erase(k)

func mouse(count: float) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(count, 0)
	e.screen_relative = e.relative
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	if player != null:
		q.exclude = [player.get_rid()]
	return level.get_world_3d().direct_space_state.intersect_ray(q)

static func plain(v: Variant) -> Variant:
	if v is Vector3:
		return [v.x, v.y, v.z]
	if v is Vector2:
		return [v.x, v.y]
	if v is Dictionary:
		var d := {}
		for k in v:
			d[str(k)] = plain(v[k])
		return d
	if v is Array:
		return v.map(plain)
	return v

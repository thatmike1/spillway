extends "res://tests/r14_contact_guard.gd"
## independent guard diagnostics: actual adapter, with seeded setup distinct from earned input.
var review := {}
var candidates: Array = []

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out.path_join("traces"))
	MAIN.bind_inputs()
	trace_budget = 100
	for early: bool in [true, false]:
		var hook := Hook.new()
		hook.suite = self
		hook.early = early
		hook.process_physics_priority = -1000 if early else 1000
		root.add_child(hook)
	world = _fixture()
	root.add_child(world)
	await _settle()
	player = PLAYER.new()
	player.input_enabled = false
	root.add_child(player)
	await _settle()
	_mixed_decisions()
	await _mixed_ticks()
	await _drop_world()
	world = LEVEL.new()
	root.add_child(world)
	world.call("build")
	await _settle()
	player = PLAYER.new()
	player.input_enabled = false
	root.add_child(player)
	await _settle()
	_map_scan()
	player.queue_free()
	player = null
	await process_frame
	var selected := candidates.slice(0, 32)
	var episodes := []
	for s: Dictionary in selected:
		var r := await pair(s)
		save_trace(str(s.name), r)
		var first: Dictionary = r.on.rows[0]
		var good_support := bool(first.g) and (first.support as Vector3).y >= 0.7
		var requested: Vector3 = s.v_u
		var moved: Vector3 = first.p - s.p
		var planar_error := Vector2(moved.x - requested.x * U / float(s.hz), moved.z - requested.z * U / float(s.hz)).length()
		var speed_error := Vector2(first.v.x - requested.x, first.v.z - requested.z).length()
		var guarded_contacts: Array = (first.contacts as Array).filter(func(c: Dictionary) -> bool: return bool(c.get("guard", false)))
		check(str(s.name) + "_horizontal", speed_error < 0.002 and planar_error < 0.0001, {"speed_error_u": speed_error, "travel_error_m": planar_error})
		check(str(s.name) + "_landing_order", "land" in first.e and float(first.v.y) == 0.0 and int(r.on.guards.slide) >= 1 and not guarded_contacts.is_empty(), "first tick clips descent, lands and keeps horizontal travel")
		var detail := {"spec": plain(s), "guards": r.on.guards, "tick0": plain(first), "off_tick0": plain(r.off.rows[0]), "support_walkable": good_support}
		episodes.append(detail)
		check(str(s.name) + "_support", good_support, "guarded tick support is walkable")
	review["seeded_episodes"] = episodes
	await _drop_world()
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.pass)
	var f := FileAccess.open(out.path_join("summary.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(plain({"engine": Engine.get_version_info(), "player_sha256": FileAccess.get_sha256("res://scripts/r14_source_player.gd"), "review": review, "checks": checks, "failed": failed.size()}), "\t"))
	f.close()
	print("independent guard review: ", checks.size(), " checks, ", failed.size(), " failed; ", out)
	quit(1 if not failed.is_empty() else 0)

func _hit_plain(hit: KinematicCollision3D) -> Array:
	var result := []
	if hit != null:
		for i: int in hit.get_collision_count():
			var body := hit.get_collider(i) as Node
			result.append({"body": str(body.name) if body != null else "", "normal": hit.get_normal(i), "depth": hit.get_depth()})
	return result

func _overlap(p: Vector3) -> bool:
	return player.test_move(Transform3D(Basis.IDENTITY, p), Vector3.ZERO, null, 0.0001, true, 4)

## sample the entire segment before refining its earliest occupied interval. unlike whole-line
## bisection, this does not assume occupancy is monotone across multiple solids.
func _first_interval(p: Vector3, motion: Vector3, subdivisions := 128) -> Dictionary:
	var lo := 0.0
	for i: int in range(1, subdivisions + 1):
		var hi := float(i) / subdivisions
		if _overlap(p + motion * hi):
			var hit := KinematicCollision3D.new()
			for j: int in 20:
				var mid := (lo + hi) * 0.5
				if _overlap(p + motion * mid):
					hi = mid
				else:
					lo = mid
			player.test_move(Transform3D(Basis.IDENTITY, p + motion * hi), Vector3.ZERO, hit, 0.0001, true, 4)
			return {"fraction": lo, "contacts": _hit_plain(hit)}
		lo = hi
	return {}

func _mixed_decisions() -> void:
	var cases := []
	# floor at y=0, block starts at x=2. the floor and wall touch at adjacent times.
	for timing: float in [-0.02, -0.002, -0.0002, 0.0, 0.0002, 0.002, 0.02]:
		for horizontal: float in [0.1, 0.4, 1.0, 2.0]:
			var p := Vector3(2.0 - 16.0 * U - horizontal * (0.5 + timing), 0.1, 0)
			var motion := Vector3(horizontal, -0.2, 0)
			cases.append({"name": "floor_wall_h%s_t%s" % [horizontal, timing], "p": p, "m": motion})
	# a wall occupies an earlier interval, but the midpoint is clear and a later floor overlaps.
	# this is a helper diagnostic; the real engine's sweep is recorded as a reachability gate.
	cases.append({"name": "disjoint_wall_then_floor", "p": Vector3(0, 1.0, 0), "m": Vector3(10, -1.25, 0)})
	var results := []
	for c: Dictionary in cases:
		player.global_position = c.p
		var raw := player.move_and_collide(c.m, true, 0.001, true, 4)
		var start_clear := not _overlap(c.p)
		var got: Dictionary = player.call("_missed_support", c.p, c.m, "slide")
		var earliest := _first_interval(c.p, c.m)
		var item := {"name": c.name, "from": c.p, "motion": c.m, "clear_start": start_clear, "raw_hit": _hit_plain(raw), "accepted": not got.is_empty(), "earliest": earliest}
		if not got.is_empty():
			item["guard_fraction"] = got.fraction
			item["guard_contacts"] = _hit_plain(got.hit)
			item["skipped_distance_m"] = (float(got.fraction) - float(earliest.fraction)) * (c.m as Vector3).length()
		results.append(item)
	review["mixed_decisions"] = results
	check("mixed_valid_starts", results.all(func(c: Dictionary) -> bool: return c.clear_start), "29 seeded diagnostics")

func _mixed_ticks() -> void:
	player.queue_free()
	player = null
	await process_frame
	var results := []
	for timing: float in [-0.02, -0.002, -0.0002, 0.0, 0.0002, 0.002, 0.02]:
		for horizontal: float in [0.1, 0.4, 1.0]:
			for hz: int in [64, 128]:
				var p := Vector3(2.0 - 16.0 * U - horizontal * (0.5 + timing), 0.1, 0)
				var motion := Vector3(horizontal, -0.2, 0)
				var s := {"name": "mixed_%d_h%s_t%s" % [hz, horizontal, timing], "p": p, "hz": hz, "v_u": motion * hz / U + Vector3.UP * 400.0 / hz, "ticks": 8}
				var r := await pair(s, 2)
				var same := matches_any(r.on.rows, r.off_runs)
				var no_lift := (r.on.rows as Array).all(func(row: Dictionary) -> bool: return float(row.v.y) <= 0.001)
				var ok := same and guard_total(r.on.guards) == 0 and no_lift
				results.append({"name": s.name, "same": same, "no_upward_velocity": no_lift, "guards": r.on.guards, "off_runs_agree": runs_agree(r.off_runs)})
				save_trace(s.name, r)
				check(s.name, ok, results.back())
	review["mixed_full_ticks"] = results

func _map_scan() -> void:
	var stats := {"attempts": 0, "start_overlaps": 0, "raw_hits": 0, "raw_misses": 0, "accepted": 0, "declined_or_clear_end": 0, "earlier_interval": 0}
	var exceptions := []
	var accepted := []
	var per_piece := {}
	for piece: Dictionary in world.get("manifest"):
		if not piece.role in ["route", "recovery", "catch"]:
			continue
		var top: Array = (piece.points as Array).slice(0, 4)
		var n: Vector3 = ((top[1] as Vector3) - (top[0] as Vector3)).cross((top[2] as Vector3) - (top[0] as Vector3)).normalized()
		if n.y < 0:
			n = -n
		if n.y < 0.7:
			continue
		var hits := 0
		for e: int in 4:
			var a: Vector3 = top[e]
			var b: Vector3 = top[(e + 1) % 4]
			for t: float in [0.05, 0.25, 0.5, 0.75, 0.95]:
				var anchor := a.lerp(b, t)
				for angle: float in [0, 45, 90, 135, 180, 225, 270, 315]:
					var dir := Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle)))
					for hz: int in [64, 128]:
						for speed: float in [300, 1100, 3500]:
							var m := (dir * speed + Vector3.DOWN * 298.0) * U / hz
							# support the axis-aligned hull on this plane, then place it near an edge.
							var p := anchor - Vector3(m.x, 0, m.z) * 0.5
							p.y = anchor.y - (n.x * (p.x - anchor.x) + n.z * (p.z - anchor.z)) / n.y + (absf(n.x) + absf(n.z)) * 16.0 * U / n.y + -m.y * 0.6
							stats.attempts += 1
							player.global_position = p
							if _overlap(p):
								stats.start_overlaps += 1
								continue
							var raw := player.move_and_collide(m, true, 0.001, true, 4)
							if raw != null:
								stats.raw_hits += 1
								continue
							stats.raw_misses += 1
							var got: Dictionary = player.call("_missed_support", p, m, "slide")
							if got.is_empty():
								stats.declined_or_clear_end += 1
								continue
							stats.accepted += 1
							hits += 1
							var earliest := _first_interval(p, m)
							var skipped := (float(got.fraction) - float(earliest.get("fraction", got.fraction))) * m.length()
							var detail := {"piece": piece.name, "from": p, "motion": m, "hz": hz, "speed_u": speed, "fraction": got.fraction, "contacts": _hit_plain(got.hit), "earliest": earliest, "skipped_m": skipped}
							accepted.append(detail)
							if skipped > 0.0005:
								stats.earlier_interval += 1
								exceptions.append(detail)
							if hits <= 2 or skipped > 0.0005:
								candidates.append({"name": "seam_%s_%d" % [piece.name, stats.accepted], "hz": hz, "p": p, "v_u": m * hz / U + Vector3.UP * 400.0 / hz, "ticks": 12})
		per_piece[piece.name] = hits
	review["map_scan"] = {"counts": stats, "per_piece_accepts": per_piece, "accepted": accepted, "exceptions": exceptions, "subdivisions": 128}
	check("map_accepted_no_skipped_interval", int(stats.earlier_interval) == 0, stats)

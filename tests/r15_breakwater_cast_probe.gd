extends "res://tests/r14_practice_cast_probe.gd"
## p / the r14 landing-cast diagnostic (tests/r14_practice_cast_probe.gd) on Breakwater's pieces:
## for each piece with a walkable top it samples interior points 0.6 m clear of the edges and
## casts the source hull down through the face along the r14 motions (the review fixture's
## landing at 64 and 128 hz, and eight headings at 300 u/s 64 hz and 1100 u/s 128 hz). a cast
## that reports no collision would tunnel. a diagnostic of this map's pieces, not a gate on the
## engine: docs/r14/CONTACT-GUARD.md. same sampling and output as the r14 probe; only the level differs.
## godot --headless --audio-driver Dummy --path . --script res://tests/r15_breakwater_cast_probe.gd -- --out=DIR

const BREAKWATER := preload("res://scripts/r15_breakwater_level.gd")

func _run() -> void:
	var level: Node3D = BREAKWATER.new()
	root.add_child(level)
	level.call("build")
	var player: CharacterBody3D = P.new()
	player.input_enabled = false
	root.add_child(player)
	await physics_frame
	await physics_frame
	var space := level.get_world_3d().direct_space_state
	var rows: Array = []
	var total := {}
	for entry: Dictionary in level.get("manifest"):
		var points: Array = entry.get("points", [])
		if points.is_empty():
			continue
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var top := -INF
		for p: Vector3 in points:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
			top = maxf(top, p.y)
		var body := level.get_node_or_null(NodePath(str(entry.name))) as CollisionObject3D
		if body == null:
			continue
		var area := (hi.x - lo.x) * (hi.y - lo.y)
		var step := maxf(0.5, sqrt(area / MAX_SAMPLES))
		var samples := 0
		var misses := {}
		var first := {}
		var x := lo.x + CLEAR
		while x <= hi.x - CLEAR:
			var z := lo.y + CLEAR
			while z <= hi.y - CLEAR:
				var hit := _face(space, body, x, z, top)
				# interior only: the same walkable face 0.6 m out on all four sides.
				if not hit.is_empty() and not _face(space, body, x + CLEAR, z, top).is_empty() and not _face(space, body, x - CLEAR, z, top).is_empty() \
						and not _face(space, body, x, z + CLEAR, top).is_empty() and not _face(space, body, x, z - CLEAR, top).is_empty():
					samples += 1
					for name: String in MOTIONS:
						var m: Vector3 = MOTIONS[name]
						player.global_position = hit.position + Vector3.UP * START * -m.y * U
						if player.move_and_collide(MOTIONS[name] * U, true, 0.001, true, 4) == null:
							misses[name] = int(misses.get(name, 0)) + 1
							if not first.has(name):
								first[name] = [snappedf(x, 0.01), snappedf(hit.position.y, 0.001), snappedf(z, 0.01)]
				z += step
			x += step
		if samples == 0:
			continue
		var size_u := [roundi((hi.x - lo.x) / U), roundi((hi.y - lo.y) / U)]
		rows.append({"piece": entry.name, "role": entry.get("role", ""), "size_m": [snappedf(hi.x - lo.x, 0.01), snappedf(hi.y - lo.y, 0.01)], "size_u": size_u,
			"samples": samples, "misses": misses, "first_miss": first})
		for name: String in MOTIONS:
			total[name] = int(total.get(name, 0)) + int(misses.get(name, 0))
		if not misses.is_empty():
			print("cast probe: %s %s u: %d samples, misses %s" % [entry.name, size_u, samples, misses])
	var sweeps := 0
	for row: Dictionary in rows:
		sweeps += int(row.samples)
	print("cast probe: %d pieces, %d sample points x %d motions, misses %s" % [rows.size(), sweeps, MOTIONS.size(), total])
	DirAccess.make_dir_recursive_absolute(out)
	var motions := {}
	for name: String in MOTIONS:
		var m: Vector3 = MOTIONS[name]
		motions[name] = [m.x, m.y, m.z]
	var f := FileAccess.open(out.path_join("cast_probe.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine": Engine.get_version_info(), "geometry_hash": level.call("geometry_hash"), "player_sha256": FileAccess.get_sha256("res://scripts/r14_source_player.gd"), "level": "res://scripts/r15_breakwater_level.gd",
		"start_fraction_of_drop": START, "motions_u_per_tick": motions, "clear_m": CLEAR, "total_misses": total, "rows": rows}, "\t"))
	f.close()
	quit()

extends "res://tests/r14_practice_review_contacts.gd"
## input-only local return checks after one labelled pose; no seeded velocity or rescue.
var checks: Array = []

func _run() -> void:
	await super._run()
	if checks.is_empty():
		printerr("FAIL independent returns: no case matched --case")
		checks.append({"name": "nonempty_selection", "ok": false, "reason": "no case matched --case"})
	var f := FileAccess.open(out.path_join("CHECKS.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": checks.filter(func(c: Dictionary) -> bool: return not c.ok).size()}, "\t"))
	f.close()
	quit(1 if checks.any(func(c: Dictionary) -> bool: return not c.ok) else 0)

func _locals() -> void:
	if opts.get("geometry", "new") == "old":
		level.queue_free()
		await process_frame
		var old := GDScript.new()
		old.source_code = FileAccess.get_file_as_string(str(opts.old_source))
		assert(old.reload() == OK)
		level = old.new()
		root.add_child(level)
		level.call("build")
		await physics_frame
		await physics_frame
	for rate: int in [64, 128]:
		for x: float in [-228.28, -228.05, -227.8, -227.4, -226.0, -225.0, -224.5]:
			for heading: float in [-5, 0, 5]:
				var name := "tail_%d_x%s_yaw%s" % [rate, x, heading]
				if opts.has("case") and str(opts.case) != name:
					continue
				await run_episode({"name": name, "hz": rate, "p": Vector3(x, -3.9988, -137.4), "yaw": PI + deg_to_rad(heading), "grounded": true, "policy": "run", "ticks": rate * 7})
				var clear: bool = (results.back().setup.setup_overlaps as Array).is_empty()
				var climbed: bool = rows.any(func(r: Dictionary) -> bool: return float(r.p[1]) > -0.05 and float(r.p[2]) > -118.6)
				var forward: bool = rows.all(func(r: Dictionary) -> bool: return (r.keys as Array) == ["w"])
				checks.append({"name": name, "ok": clear and climbed and forward, "clear": clear, "climbed": climbed, "only_w": forward, "end": results.back().end})
		for route: String in ["block_recovery", "bend_recovery", "g1_recovery", "g2_recovery", "notch_recovery", "g3_recovery"]:
			var points: Array = ((level.get("routes") as Dictionary)[route] as Array).duplicate()
			if route == "block_recovery":
				points[0] = Vector3(-2, -2.5, -50.5)
				points[1] = Vector3(6, -2.5, -50.5)
			var goals := []
			for p: Vector3 in points:
				goals.append(Vector2(p.x, p.z))
			var start_p: Vector3 = points[0]
			# support the whole hull, including the uphill corner of the notch's ramp.
			var support_y := -INF
			for dx: float in [-16.0 * U, 0.0, 16.0 * U]:
				for dz: float in [-16.0 * U, 0.0, 16.0 * U]:
					var hit := ray(Vector3(start_p.x + dx, 14, start_p.z + dz), Vector3(start_p.x + dx, -7, start_p.z + dz))
					if not hit.is_empty():
						support_y = maxf(support_y, (hit.position as Vector3).y)
			start_p.y = support_y + 0.0012
			var toward: Vector3 = (points[1] as Vector3) - points[0]
			for seed_value: int in [1, 2]:
				var name := "%s_%d_seed%d" % [route, rate, seed_value]
				if opts.has("case") and str(opts.case) != name:
					continue
				await run_episode({"name": name, "hz": rate, "p": start_p, "yaw": atan2(-toward.x, -toward.z), "grounded": true, "policy": "goals", "goals": goals, "seed": seed_value, "ticks": rate * 18})
				var result: Dictionary = results.back()
				var clear: bool = (result.setup.setup_overlaps as Array).is_empty()
				checks.append({"name": name, "ok": clear and int(result.goals_reached) == goals.size(), "clear": clear, "reached": result.goals_reached, "total": goals.size(), "end": result.end})
	print("independent return checks: ", checks.size(), " cases, ", checks.filter(func(c: Dictionary) -> bool: return not c.ok).size(), " failed")

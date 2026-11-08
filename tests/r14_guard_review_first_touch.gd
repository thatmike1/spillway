extends "res://tests/r14_contact_guard.gd"
## reduced corner-graze probe within the production per-axis velocity bound.
## the helper is called diagnostically even when the real cast detects the wall.
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out.path_join("traces"))
	MAIN.bind_inputs()
	for early: bool in [true, false]:
		var hook := Hook.new()
		hook.suite = self
		hook.early = early
		hook.process_physics_priority = -1000 if early else 1000
		root.add_child(hook)
	world = _fixture()
	root.add_child(world)
	await _settle()
	var results := []
	for repeat_index: int in 2:
		for hz: int in [64, 128]:
			if player != null:
				player.queue_free()
				await process_frame
			player = PLAYER.new()
			player.input_enabled = false
			root.add_child(player)
			await _settle()
			var scale := 64.0 / hz
			var p := Vector3(1.4, 0.1 * scale, 5.2)
			var m := Vector3(1.0, -0.125, 1.0) * scale
			player.global_position = p
			var clear := not player.test_move(Transform3D(Basis.IDENTITY, p), Vector3.ZERO, null, 0.0001, true, 4)
			var raw := player.move_and_collide(m, true, 0.001, true, 4)
			var got: Dictionary = player.call("_missed_support", p, m, "slide")
			var raw_contacts := []
			if raw != null:
				for i: int in raw.get_collision_count():
					raw_contacts.append({"body": str(raw.get_collider(i).name), "normal": raw.get_normal(i)})
			var detail := {"repeat": repeat_index, "hz": hz, "clear_start": clear, "p": p, "motion": m, "raw_contacts": raw_contacts,
				"wall_interval_analytic": [0.1936 / scale, 0.2064 / scale], "helper_accepted": not got.is_empty()}
			if not got.is_empty():
				detail["helper_fraction"] = got.fraction
				detail["helper_normal_y"] = player.call("_best_up", got.hit)
			var s := {"name": "corner_%d_repeat%d" % [hz, repeat_index], "hz": hz, "p": p, "v_u": m * hz / U + Vector3.UP * 400.0 / hz, "ticks": 12}
			var r := await pair(s, 2)
			save_trace(s.name, r)
			detail["guards"] = r.on.guards
			detail["matches_unguarded"] = matches_any(r.on.rows, r.off_runs)
			detail["guarded_tick0"] = r.on.rows[0]
			results.append(detail)
			check(s.name + "_cast_reachability", clear and raw != null and int(r.on.guards.slide) == 0 and bool(detail.matches_unguarded), detail)
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.pass)
	var f := FileAccess.open(out.path_join("summary.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(plain({"checks": checks, "failed": failed.size(), "cases": results}), "\t"))
	f.close()
	print("reduced first-touch probe: ", checks.size(), " checks, ", failed.size(), " failed")
	quit(1 if not failed.is_empty() else 0)

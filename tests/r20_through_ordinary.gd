extends "res://tests/r20_through_component.gd"
## same real key/mouse script through sequential R19/R20 hosts on every original map.
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.render_loop_enabled = false
	Engine.physics_ticks_per_second = 128
	hook = Post.new()
	hook.driver = self
	hook.process_physics_priority = 1001
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	for map: String in ["breakwater", "whiteout-relay", "sunken-court", "rainline", "night-shift", "practice", "overflow", "experiment"]:
		var prior: Array = []
		for reference: bool in [true, false]:
			scene = R19 if reference else SCENE
			new_case(("r19_" if reference else "r20_") + map, Vector3(0, 4.04, 12), Vector3.ZERO, map)
			await ticks(33)
			observations.clear()
			key(KEY_W, true)
			await ticks(50)
			key(KEY_SPACE, true)
			await ticks(2)
			key(KEY_W, false)
			for tick: int in 160:
				var side: bool = tick % 80 < 40
				key(KEY_A, side)
				key(KEY_D, not side)
				var event := InputEventMouseMotion.new()
				event.relative = Vector2(-5 if side else 5, 0)
				event.screen_relative = event.relative
				inputs.append({"t": counter, "event": SESSION.describe(event)})
				Input.parse_input_event(event)
				Input.flush_buffered_events()
				await ticks(1)
			key(KEY_A, false)
			key(KEY_D, false)
			key(KEY_SPACE, false)
			await ticks(30)
			if reference:
				prior = observations.duplicate(true)
			else:
				check(prior.size() == observations.size(), "paired sample count: " + map)
				check(prior == observations, "every physical and detailed motion observation exactly matches R19 F2: " + map)
			close_case()
	var ok := checks.all(func(row: Dictionary) -> bool: return bool(row.ok))
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks, "episodes": episodes, "limits": "242 real input ticks per map at F2; final full-course matrix stays with parent"}, "\t"))
	file.close()
	quit(0 if ok else 1)

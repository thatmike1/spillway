extends SceneTree
## physical dimensions, default startup and actual input paths for the feel yard.
var failures: int = 0
var checks: int = 0
var main: Node3D

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func ticks(n: int) -> void:
	for i: int in n:
		await physics_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await ticks(2)

func ray(from: Vector3, to: Vector3) -> Dictionary:
	return main.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, [main.player.get_rid()]))

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._persist = false
	await ticks(3)
	check(not main.city_mode and main.level.get_script().resource_path.ends_with("yard.gd"), "default main scene opens training yard")
	var s: Dictionary = main.level.stations
	check(s.straight.length >= 70 and s.straight.length <= 80, "straight lane is 70–80 m")
	for i: int in 5:
		var obstacle: Dictionary = s["obstacle%d" % i]
		var body: StaticBody3D = obstacle.body
		var hit: Dictionary = ray(body.position + Vector3.UP * 4, body.position - Vector3.UP * 4)
		check(not hit.is_empty() and absf(hit.position.y - obstacle.height) < .001, "physical obstacle height %s" % obstacle.height)
		check(not ray(obstacle.bypass + Vector3.UP * 2, obstacle.bypass - Vector3.UP).is_empty(), "obstacle bypass has floor")
	for gap: int in range(2, 7):
		var station: Dictionary = s["gap%d" % gap]
		check(absf(station.front.z - station.landing.z - gap) < .001, "gap dimensions %d" % gap)
		check(ray((station.front + station.landing) / 2 + Vector3.UP * 2, (station.front + station.landing) / 2 - Vector3.UP * 4).is_empty(), "gap is actually open %d" % gap)
		check(not ray(station.bypass + Vector3.UP * 2, station.bypass - Vector3.UP).is_empty(), "gap has a walking bypass")
	for drop: int in [1, 3, 6]:
		var station: Dictionary = s["drop%d" % drop]
		var high: Dictionary = ray(station.front + Vector3(0, 1, 1), station.front - Vector3(0, 8, -1))
		var low: Dictionary = ray(station.front + Vector3(0, 1, -2), station.front + Vector3(0, -8, -2))
		check(not high.is_empty() and not low.is_empty() and absf(high.position.y - low.position.y - drop) < .001, "physical drop %d" % drop)
	check(s.grab.height == 2.8 and s.has("climb") and s.has("wallrun") and s.has("springboard") and s.has("loop"), "grab, climb, wall run, springboard and chain loop exist")
	check(ray(Vector3(6, 2.09, 4), Vector3(6, 2.09, 2)).is_empty() and not ray(Vector3(6, 2.11, 4), Vector3(6, 2.11, 2)).is_empty(), "door opening physically clears 2.1 m")
	Input.action_press("move_forward")
	await ticks(50)
	Input.action_release("move_forward")
	check(main.player.position.distance_to(main.level.spawn.origin) > .7, "runner can leave spawn")
	await key(KEY_R)
	check(main.player.position.distance_to(main.level.spawn.origin) < .02 and main.elapsed == 0, "R resets instantly without fade")
	await key(KEY_F3)
	check(main.hud._metrics.visible, "F3 shows metrics")
	await key(KEY_F3)
	check(not main.hud._metrics.visible, "F3 hides metrics")
	# verify the actual 6m yard station, beyond the dimension raycast.
	main.player.reset_to(Transform3D(Basis.IDENTITY, s.drop6.start))
	Input.action_press("move_forward")
	for i: int in 700:
		await ticks(1)
		if main.player.move == main.player.Move.LANDING:
			break
	Input.action_release("move_forward")
	check(main.player.landing.kind == "hard" and absf(main.player.landing.height - 6) < .03, "actual yard 6m station gives a hard landing: %s %.4fm at %s state=%s" % [main.player.landing.kind, main.player.landing.height, main.player.position, main.player.move])
	await key(KEY_R)
	check(main.player.position.distance_to(main.level.spawn.origin) < .02, "R also resets directly out of hard landing")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			var output: String = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(output)
			main.player.set_physics_process(false)
			main.set_physics_process(false)
			main.player.reset_to(Transform3D(Basis.IDENTITY, Vector3(28, 65, 45)))
			main.player.look(0, -.78)
			main.hud.hide()
			for i: int in 10:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("yard-overview.png"))
			main.player.reset_to(main.level.spawn)
			main.player.look(-.28, -.06)
			for i: int in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("yard-start.png"))
	# course switch is exercised through the actual Tab input and scene reload.
	await key(KEY_TAB)
	for i: int in 20:
		await process_frame
	main = current_scene
	check(main.city_mode and main.level.folds.size() == 3, "Tab switches to city")
	main._persist = false
	await key(KEY_TAB)
	for i: int in 20:
		await process_frame
	main = current_scene
	check(not main.city_mode and main.level.get_script().resource_path.ends_with("yard.gd"), "Tab returns to yard")
	print("yard: %d/%d checks passed" % [checks - failures, checks])
	main.audio.stop_all()
	for i: int in 8:
		await process_frame
	quit(1 if failures else 0)

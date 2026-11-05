extends SceneTree
## port choice (P): matching fixed views, never completion evidence. output stays outside the repo.
var main: Node3D
var output: String = "/tmp/foldrunner-review"

func _initialize() -> void:
	_run.call_deferred()

func pose(point: Vector3, yaw: float = 0, pitch: float = -.08) -> void:
	main.player.reset_to(Transform3D(Basis.IDENTITY, point))
	main.player.controls_enabled = true
	main.player.look(yaw, pitch)
	main.player.controls_enabled = false
	main.player.grounded = true
	main.player.set_physics_process(false)

func save_frame(name: String, seconds: float = .4) -> void:
	for i: int in ceili(seconds * 10):
		main.level.vision.step(main.player.position, 1.0 / 10)
		await process_frame
	await RenderingServer.frame_post_draw
	var file: String = output.path_join(name + ".png")
	root.get_texture().get_image().save_png(file)
	print("saved ", file)

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	main = load("res://scenes/main.tscn").instantiate()
	main.city_mode = true
	root.add_child(main)
	main._persist = false
	main.hud.hide()
	main.set_physics_process(false)
	for entry: Dictionary in main.level.fold_triggers:
		entry.area.set_deferred("monitoring", false)
	main.player.controls_enabled = false
	if OS.get_cmdline_user_args().has("--skyline-only"):
		pose(Vector3(-80, 25.9, -220), .21, .52)
		await save_frame("curved-tower", 1.2)
		main.audio.stop_all()
		for i: int in 8:
			await process_frame
		quit()
		return
	if OS.get_cmdline_user_args().has("--front-only"):
		pose(Vector3(7.8, -2.1, -138), .45, .25)
		await save_frame("front-before", 1.2)
		main.level.folds[1].start_fold()
		await save_frame("front-during", 2.3)
		await save_frame("front-after", 2)
		main.audio.stop_all()
		for i: int in 8:
			await process_frame
		quit()
		return
	if OS.get_cmdline_user_args().has("--finish-only"):
		pose(Vector3(30, 30.7, -365), 0, -.08)
		await save_frame("finish", 1.2)
		main.audio.stop_all()
		for i: int in 8:
			await process_frame
		quit()
		return
	if OS.get_cmdline_user_args().has("--district-only"):
		pose(Vector3(0, 25.9, -205), 0, .10)
		await save_frame("district-before")
		main.level.folds[2].start_fold()
		await save_frame("district-during", 3.8)
		await save_frame("district-after", 5)
		main.audio.stop_all()
		for i: int in 8:
			await process_frame
		quit()
		return
	pose(Vector3(0, .9, -10), 0, .06)
	await save_frame("start", 1.2)
	pose(Vector3(0, .9, -30), 0, .20)
	await save_frame("fold-before")
	main.level.folds[0].start_fold()
	await save_frame("fold-during", 3.5)
	await save_frame("fold-after", 3)
	main.level.folds[1].finish_now()
	pose(Vector3(0, 25.9, -205), 0, .10)
	await save_frame("district-before")
	main.level.folds[2].start_fold()
	await save_frame("district-during", 3.8)
	await save_frame("district-after", 5)
	pose(Vector3(0, 31.7, -284), 0, -.08)
	main.player.move = main.player.Move.WALLRUN
	main.player._wall_side = -1
	main.player._wall_normal = Vector3.RIGHT
	await save_frame("wall-run", 1.2)
	pose(Vector3(30, 30.7, -365), 0, -.08)
	await save_frame("finish", 1.2)
	pose(Vector3(0, 30.7, -230.5), 0, -.06)
	await save_frame("high-rail", 1.2)
	pose(Vector3(1.5, 30.7, -319), PI, -.08)
	await save_frame("tank-turn", 1.2)
	pose(Vector3(5, 30.7, -305), -PI / 2, -.08)
	await save_frame("east-continuation", 1.2)
	main.audio.stop_all()
	for i: int in 8:
		await process_frame
	quit()

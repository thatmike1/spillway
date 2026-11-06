extends SceneTree
## labelled native rendering fixtures, not route or desktop frame-rate proof.
## --views=<json array of name/eye/at> --evidence-dir=<fresh absolute directory>.

func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	run.call_deferred()

func run() -> void:
	var output := ""
	var views_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			output = arg.trim_prefix("--evidence-dir=")
		elif arg.begins_with("--views="):
			views_path = arg.trim_prefix("--views=")
	if DisplayServer.get_name() == "headless" or not preload("res://scripts/spillway_driver.gd").evidence_path_allowed(output) or not FileAccess.file_exists(views_path):
		printerr("profile-views needs native rendering, an external evidence directory and --views JSON")
		quit(2)
		return
	var views: Variant = JSON.parse_string(FileAccess.get_file_as_string(views_path))
	if not views is Array or views.is_empty() or FileAccess.file_exists(output.path_join("metrics.json")):
		printerr("profile-views needs nonempty views and fresh evidence")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	game.set("_persist", false)
	game.set_physics_process(false)
	game.get("player").set_physics_process(false)
	game.get("player").set_process(false)
	game.get("hud").hide()
	var camera := Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 90
	camera.near = .06
	camera.far = 600
	root.add_child(camera)
	camera.make_current()
	var rows: Array = []
	for view: Dictionary in views:
		var eye: Array = view.eye
		var at: Array = view.at
		camera.position = Vector3(eye[0], eye[1], eye[2])
		camera.look_at(Vector3(at[0], at[1], at[2]), Vector3.UP)
		RenderingServer.render_loop_enabled = true
		for i: int in 4:
			await RenderingServer.frame_post_draw
		var samples: Array = []
		for i: int in 5:
			var before := Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			samples.append({"host_frame_ms": (Time.get_ticks_usec() - before) / 1000.0,
				"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)})
		var name := str(view.name).validate_filename()
		var saved := root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK
		rows.append({"name": name, "eye": eye, "at": at, "samples": samples, "frame_saved": saved})
		RenderingServer.render_loop_enabled = false
	var result := {"build": game.BUILD_ID, "fixture": true,
		"method": "fixed cameras, ordinary built scene; four warmup and five measured rendered frames per view",
		"limits": "host timings include software rendering and concurrent work; no desktop GPU frame-rate claim",
		"display": DisplayServer.get_name(), "renderer": RenderingServer.get_video_adapter_name(),
		"viewport": [root.size.x, root.size.y], "views": rows}
	var passed := rows.all(func(row: Dictionary) -> bool:
		return row.frame_saved and row.samples.size() == 5 and row.samples.all(func(sample: Dictionary) -> bool:
			return sample.draw_calls > 0 and sample.objects > 0 and sample.host_frame_ms > 0))
	result["passed"] = passed
	var file := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	RenderingServer.render_loop_enabled = true
	game.call("request_quit", 0 if passed else 1)

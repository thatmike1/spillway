extends SceneTree
## native-only presentation fixture: public pause controls, no body/view posing or movement claim.

var output := ""
var size := Vector2i(1280, 720)
var game: Node3D
var checks: Array = []
var frames: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "name": label})
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	if not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		push_error("this fixture needs an explicit native display and external output")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Engine.physics_ticks_per_second = 128
	root.mode = Window.MODE_WINDOWED
	root.size = size
	RenderingServer.render_loop_enabled = true
	game = load("res://scenes/r21.tscn").instantiate()
	game.map_id = "tether-yard"
	game.motor = "server128"
	game.seed_from_r15 = false
	game.persist = false
	game.record_runs = false
	root.add_child(game)
	game.hud.dismiss_title()
	game.set_paused(true)
	await process_frame
	await process_frame
	check(game.get_script().resource_path == "res://scripts/r21_main.gd", "actual R21 host")
	check(game.hud.get_script().resource_path == "res://scripts/r21_hud.gd", "actual R21 HUD")
	check(game.hud.tether_models.keys() == game.R21_MODELS, "all six real model controls")
	for model: String in game.R21_MODELS:
		game.hud.tether_models[model].pressed.emit()
		check(game.player.model == model and game.paused, "public model handler: " + model)
		var control: Control = game.hud.tether_models[model]
		game.hud._pause_scroll.ensure_control_visible(control)
		await capture("model-" + model, control)
	game.hud.anchor_assist_switch.toggled.emit(false)
	check(not game.settings.tether_anchor_assist and game.paused, "public assist handler persists paused state")
	game.hud._pause_scroll.ensure_control_visible(game.hud.anchor_assist_switch)
	await capture("assist-off", game.hud.anchor_assist_switch)
	game.hud.anchor_assist_switch.toggled.emit(true)
	check(game.settings.tether_anchor_assist and game.paused, "public assist on handler")
	await capture("assist-on", game.hud.anchor_assist_switch)
	var result := {"pass": checks.all(func(row: Dictionary) -> bool: return row.ok), "checks": checks,
		"frames": frames, "elapsed": game.elapsed, "viewport": [root.size.x, root.size.y],
		"host": game.get_script().resource_path, "hud": game.hud.get_script().resource_path,
		"scope": "native paused presentation only; no route, replay, persistence or input-feel acceptance"}
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	game.request_quit(0 if result["pass"] else 1)

func capture(label: String, control: Control) -> void:
	# preference handlers restore pause focus; let its deferred scroll settle first.
	await process_frame
	await process_frame
	game.hud._pause_scroll.ensure_control_visible(control)
	await process_frame
	await RenderingServer.frame_post_draw
	var bounds := control.get_global_rect()
	var clip: Rect2 = game.hud._pause_scroll.get_global_rect()
	check(bounds.intersection(clip).size.y >= bounds.size.y - 1.0, label + ": selected control visible in scroll viewport")
	var image := root.get_texture().get_image()
	check(image.save_png(output.path_join(label + ".png")) == OK, label + ": actual viewport image saved")
	frames.append({"name": label, "pixels": [image.get_width(), image.get_height()],
		"control_rect": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"clip_rect": [clip.position.x, clip.position.y, clip.size.x, clip.size.y], "model": game.player.model})

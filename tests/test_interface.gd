extends SceneTree
## actual Godot input/layout checks; finish is forced only for interface layout.
var checks: int = 0
var failures: int = 0
var main: Node3D

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	print("%s %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		failures += 1

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func click(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("interface checks require a rendered engine, for example xvfb-run")
		quit(2)
		return
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._persist = false
	await process_frame
	await process_frame
	key(KEY_ESCAPE, true)
	await process_frame
	key(KEY_ESCAPE, false)
	await process_frame
	check(paused, "escape opens pause")
	var pause_ui: Control = main.hud._pause
	var panel: Control = pause_ui.get_child(1)
	var viewport: Rect2 = root.get_visible_rect()
	check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= viewport.end.y, "settings panel stays inside viewport")
	var column: Control = panel.get_child(0)
	var scroll: ScrollContainer = column.get_child(2)
	check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "long settings have a usable scroll area")
	var assist: CheckButton = main.hud._controls.assists
	scroll.ensure_control_visible(assist)
	await process_frame
	await process_frame
	var before: bool = main.player.assists_enabled
	var point: Vector2 = assist.get_global_rect().get_center()
	click(point, true)
	await process_frame
	click(point, false)
	await process_frame
	check(main.player.assists_enabled != before, "real checkbox click toggles jump-grace extension")
	var quit_button: Control = column.get_child(3)
	check(quit_button.get_global_rect().end.y <= viewport.end.y, "quit stays reachable below scroll area")
	var output: String = "/tmp/foldrunner-interface.png"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--image="):
			output = arg.trim_prefix("--image=")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output)
	(main.hud._controls.resume as Button).grab_focus()
	key(KEY_ENTER, true)
	await process_frame
	key(KEY_ENTER, false)
	await process_frame
	check(not paused, "keyboard accepts focused resume")
	main._on_finish(main.player)
	await process_frame
	check(main.hud._finish.visible, "finish card is visible")
	check(main.hud._finish.get_global_rect().position.x >= 0, "finish card stays inside viewport")
	key(KEY_R, true)
	await process_frame
	key(KEY_R, false)
	await process_frame
	check(not main.finished and not main.hud._finish.visible, "restart from finish restores play")
	print("interface: %d/%d checks passed" % [checks - failures, checks])
	main.audio.stop_all()
	for i: int in 8:
		await process_frame
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)

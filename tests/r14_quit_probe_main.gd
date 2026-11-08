extends "res://scripts/r14_main.gd"
## p / r14 quit investigation only: the real r14 main with shutdown markers. production
## request_quit runs unchanged through super; this only appends one line per stage to the
## file named by --r14-quit-markers, so a hung process shows how far it got. with
## --r14-quit-route=menu the tape's own quit is replaced by actual input: Escape opens the
## pause menu and a mouse click on its Quit button calls the production request_quit.

var _marker_path := ""
var _quit_frames := 0
var _route := "tape"
var _menu_started := false

func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--r14-quit-markers="):
			_marker_path = arg.trim_prefix("--r14-quit-markers=")
		elif arg.begins_with("--r14-map=") and map_id.is_empty():
			map_id = arg.trim_prefix("--r14-map=")
		elif arg.begins_with("--r14-quit-route="):
			_route = arg.trim_prefix("--r14-quit-route=")
		elif arg.begins_with("--r14-look-scale="):
			source_sensitivity_override = float(arg.trim_prefix("--r14-look-scale="))

func marker(stage: String) -> void:
	if _marker_path.is_empty():
		return
	var file := FileAccess.open(_marker_path, FileAccess.READ_WRITE if FileAccess.file_exists(_marker_path) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("%d %d %s" % [Time.get_ticks_usec(), Engine.get_process_frames(), stage])
	file.close()

func request_quit(exit_code: int = 0) -> void:
	if _route == "menu" and not _menu_started:
		_menu_started = true
		marker("tape quit replaced by menu input")
		_quit_through_menu(exit_code)
		return
	marker("request_quit %d quitting=%s paused=%s" % [exit_code, _quitting, paused])
	await super(exit_code)
	marker("tree.quit called")

func _quit_through_menu(exit_code: int) -> void:
	for i: int in 4:
		await get_tree().process_frame
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_ESCAPE
		key.keycode = KEY_ESCAPE
		key.pressed = pressed
		Input.parse_input_event(key)
		await get_tree().process_frame
	for i: int in 8:
		await get_tree().process_frame
	var button: Button = hud.get("quit_button")
	if not paused or button == null or not button.is_visible_in_tree():
		marker("menu quit unavailable paused=%s" % paused)
		await super.request_quit(exit_code)
		return
	var at := button.get_global_rect().get_center()
	marker("menu open; clicking Quit at %s" % at)
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await get_tree().process_frame
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = at
		click.global_position = at
		click.pressed = pressed
		Input.parse_input_event(click)
		await get_tree().process_frame
	for i: int in 30:
		if _quitting:
			return
		await get_tree().process_frame
	marker("menu click did not quit")
	await super.request_quit(exit_code)

func _process(_delta: float) -> void:
	if _quitting:
		_quit_frames += 1
		marker("quit wait frame %d" % _quit_frames)

func _exit_tree() -> void:
	marker("main exit_tree")

func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		marker("wm close request")
	elif what == NOTIFICATION_PREDELETE:
		marker("main predelete")

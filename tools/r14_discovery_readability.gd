extends SceneTree
## screenshot-only batches with ordinary input and engine pause between decisions.
var inbox := ""
var active: Dictionary = {}
var remaining := 0
var capturing := true
var held: Array[String] = []
var menu_visible := false
var automatic_pause := false
var transcript: FileAccess

func _initialize() -> void:
	start.call_deferred()

func input_key(name: String, pressed: bool) -> void:
	var codes := {"w": KEY_W, "s": KEY_S, "a": KEY_A, "d": KEY_D,
		"space": KEY_SPACE, "ctrl": KEY_CTRL, "r": KEY_R, "f": KEY_F,
		"esc": KEY_ESCAPE, "f1": KEY_F1, "f2": KEY_F2, "f3": KEY_F3,
		"f4": KEY_F4, "f5": KEY_F5}
	var event := InputEventKey.new()
	event.keycode = codes[name]
	event.physical_keycode = codes[name]
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = delta
	event.screen_relative = delta
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func start() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--inbox="):
			inbox = arg.trim_prefix("--inbox=")
	DirAccess.make_dir_recursive_absolute(inbox)
	transcript = FileAccess.open(inbox.path_join("inputs.jsonl"), FileAccess.WRITE)
	var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	for i: int in 6:
		await process_frame
	active = {"id": "initial"}
	await snapshot()

func _process(_delta: float) -> bool:
	if capturing:
		return false
	if remaining > 0:
		var delta: Array = active.get("mouse", [0, 0])
		motion(Vector2(float(delta[0]), float(delta[1])) / float(active.frames))
		remaining -= 1
		if remaining == 0:
			snapshot.call_deferred()
		return false
	var request := inbox.path_join("request.json")
	if not FileAccess.file_exists(request):
		OS.delay_msec(20)
		return false
	active = JSON.parse_string(FileAccess.get_file_as_string(request))
	DirAccess.remove_absolute(request)
	if active.get("quit", false):
		quit()
		return false
	RenderingServer.render_loop_enabled = true
	if automatic_pause:
		input_key("esc", true)
		input_key("esc", false)
		automatic_pause = false
	var next_held: Array[String] = []
	for name: String in active.get("keys", []):
		next_held.append(name)
	for name: String in held:
		if not name in next_held:
			input_key(name, false)
	for name: String in next_held:
		if not name in held:
			input_key(name, true)
	held = next_held
	if active.has("menu_visible"):
		menu_visible = bool(active.menu_visible)
	for name: String in active.get("tap", []):
		input_key(name, true)
		input_key(name, false)
	if active.has("click"):
		var position := Vector2(active.click[0], active.click[1])
		Input.warp_mouse(position)
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = position
			event.global_position = position
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			Input.parse_input_event(event)
			Input.flush_buffered_events()
	remaining = clampi(int(active.get("frames", 1)), 1, 90)
	active.frames = remaining
	transcript.store_line(JSON.stringify(active))
	transcript.flush()
	return false

func snapshot() -> void:
	capturing = true
	await RenderingServer.frame_post_draw
	var id := str(active.get("id", "initial"))
	var path := inbox.path_join(id + ".jpg")
	root.get_texture().get_image().save_jpg(path, 0.86)
	if not menu_visible:
		input_key("esc", true)
		input_key("esc", false)
		automatic_pause = true
	var file := FileAccess.open(inbox.path_join("response.json.tmp"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"id": id, "image": path}))
	file.close()
	DirAccess.rename_absolute(inbox.path_join("response.json.tmp"), inbox.path_join("response.json"))
	remaining = 0
	active = {}
	capturing = false
	RenderingServer.render_loop_enabled = false

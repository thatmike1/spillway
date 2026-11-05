extends SceneTree
## native visual exploration: input batches, with real pause input between decisions.
## no player pose, velocity, camera or progress writes. screenshots are decision views.
var game: Node
var inbox := "/tmp/spillway-visual-play"
var active: Dictionary = {}
var remaining := 0
var capturing := false
var held: Array[String] = []
var transcript: FileAccess
var player: Node3D

func _initialize() -> void:
	start.call_deferred()

func key(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(action: String) -> void:
	key(action, true)
	key(action, false)

func mouse(delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.screen_relative = delta
	event.relative = delta
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func start() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--inbox="):
			inbox = arg.trim_prefix("--inbox=")
	DirAccess.make_dir_recursive_absolute(inbox)
	transcript = FileAccess.open(inbox.path_join("input-and-state.jsonl"), FileAccess.WRITE)
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	game.set("_persist", false)
	player = game.get("player")
	for i: int in 3:
		await process_frame
	active = {"id": "initial", "keys": [], "frames": 0}
	await snapshot()
	print("visual play ready: ", inbox)

func _process(_delta: float) -> bool:
	if game == null or capturing:
		return false
	if remaining > 0:
		var motion: Array = active.get("mouse", [0, 0])
		mouse(Vector2(float(motion[0]), float(motion[1])) / float(active.frames))
		remaining -= 1
		if remaining == 0:
			snapshot.call_deferred()
		return false
	var request := inbox.path_join("request.json")
	if not FileAccess.file_exists(request):
		OS.delay_msec(20)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(request))
	DirAccess.remove_absolute(request)
	if not parsed is Dictionary:
		return false
	active = parsed
	if active.get("quit", false):
		game.call("request_quit")
		return false
	var next_held: Array[String] = []
	for action: String in active.get("keys", []):
		if action in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch"]:
			next_held.append(action)
	for action: String in held:
		if not action in next_held:
			key(action, false)
	for action: String in next_held:
		if not action in held:
			key(action, true)
	held = next_held
	if bool(game.get("paused")):
		tap("pause")
	if active.get("restart", false):
		tap("restart")
	if active.get("practice", false):
		tap("practice")
	remaining = clampi(int(active.get("frames", 1)), 1, 90)
	active.frames = remaining
	Engine.max_fps = 30
	transcript.store_line(JSON.stringify({"event": "command", "request": active}))
	transcript.flush()
	return false

func snapshot() -> void:
	capturing = true
	await RenderingServer.frame_post_draw
	var id := str(active.get("id", "initial"))
	var frame := inbox.path_join(id + ".png")
	root.get_texture().get_image().save_png(frame)
	var record := {"event": "view", "id": id, "image": frame,
		"feet": [player.global_position.x, player.global_position.y, player.global_position.z],
		"velocity": [player.get("velocity").x, player.get("velocity").y, player.get("velocity").z],
		"yaw": player.get("yaw"), "pitch": player.get("pitch"),
		"speed": player.call("get_speed"), "mode": player.get("mode"),
		"finished": game.get("finished"), "finish_kind": game.get("finish_kind"),
		"respawns": game.get("respawn_count"), "stage": game.get("checkpoint_index"),
		"elapsed": game.get("elapsed")}
	transcript.store_line(JSON.stringify(record))
	transcript.flush()
	if not bool(game.get("paused")):
		tap("pause")
	Engine.max_fps = 2
	var file := FileAccess.open(inbox.path_join("response.json.tmp"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record))
	file.close()
	DirAccess.rename_absolute(inbox.path_join("response.json.tmp"), inbox.path_join("response.json"))
	remaining = 0
	active = {}
	capturing = false

extends SceneTree
## normal configured scene, native keyboard pause/resume and build-identity evidence.
## no player pose, velocity, camera, settings or run-state overrides.
var journal: FileAccess
var game: Node
var output := ""

func _initialize() -> void:
	run.call_deferred()

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	journal.store_line(JSON.stringify({"event":"key","physical_keycode":code,
		"pressed":pressed,"physics_frame":Engine.get_physics_frames()}))
	journal.flush()

func tap(code: Key) -> void:
	key(code,true)
	key(code,false)

func view(name: String) -> bool:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(output.path_join(name)) == OK

func run() -> void:
	var expected := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			output = arg.trim_prefix("--evidence-dir=").simplify_path()
		elif arg.begins_with("--expected-build="):
			expected = arg.trim_prefix("--expected-build=")
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--bot") or expected.is_empty() or not preload("res://scripts/spillway_driver.gd").evidence_path_allowed(output) or OS.get_environment("XDG_DATA_HOME").simplify_path() != output.path_join("profile"):
		printerr("capture-launch needs a native display, no bot, expected build, and isolated <evidence-dir>/profile")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	if FileAccess.file_exists(output.path_join("start.png")):
		printerr("use a fresh launch evidence directory")
		quit(2)
		return
	journal = FileAccess.open(output.path_join("inputs.jsonl"),FileAccess.WRITE)
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	for i: int in 4:
		await process_frame
	var images_ok := await view("start.png")
	tap(KEY_ESCAPE)
	for i: int in 3:
		await process_frame
	var paused: bool = game.get("paused") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	var visible_identity := false
	for node: Node in game.get("hud").find_children("*","Label",true,false):
		if node is Label and node.is_visible_in_tree() and node.text == expected:
			visible_identity = true
	var player: CharacterBody3D = game.get("player")
	var before := player.global_position
	key(KEY_W,true)
	await create_timer(.2).timeout
	key(KEY_W,false)
	var pause_stopped_w := player.global_position.distance_to(before) < .00001
	images_ok = await view("pause.png") and images_ok
	tap(KEY_ESCAPE)
	var resumed: bool = not game.get("paused") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	before = player.global_position
	key(KEY_W,true)
	await create_timer(.25).timeout
	key(KEY_W,false)
	var movement := Vector2(player.global_position.x-before.x,player.global_position.z-before.z).length()
	images_ok = await view("resume.png") and images_ok
	var passed: bool = game.BUILD_ID == expected and visible_identity and paused and pause_stopped_w and resumed and movement > .25 and images_ok and int(game.get("respawn_count")) == 0
	var result := {"passed":passed,"build":game.BUILD_ID,"visible_identity":visible_identity,
		"paused":paused,"pause_stopped_w":pause_stopped_w,"resumed":resumed,
		"resume_movement_m":movement,"images_ok":images_ok,"respawns":game.get("respawn_count"),
		"runtime":OS.get_executable_path(),"profile":OS.get_user_data_dir(),
		"method":"normal configured scene and native keyboard input; no state or pose overrides"}
	var file := FileAccess.open(output.path_join("launch-verification.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	journal.store_line(JSON.stringify({"event":"result","result":result}))
	journal.close()
	print("native launch: ",JSON.stringify(result))
	game.call("request_quit",0 if passed else 1)

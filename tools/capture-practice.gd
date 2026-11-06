extends SceneTree
## actual-input practice/restart views after reaching a stage on the fast controller.
## this is a partial-route control fixture, not uninterrupted full-route evidence.
var game: Node
var driver: Node
var output := ""
var stage := 1

func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	run.call_deferred()

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	driver.call("_write", {"event":"control_fixture_input", "action":name, "pressed":pressed,
		"engine_frame":Engine.get_physics_frames()})

func ticks(count: int) -> void:
	for i: int in count:
		await physics_frame

func view(name: String) -> bool:
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	return root.get_texture().get_image().save_png(output.path_join(name)) == OK

func state() -> Dictionary:
	var player: CharacterBody3D = game.get("player")
	var pos := player.global_position
	return {"checkpoint":game.get("checkpoint_index"), "clean":game.get("clean_eligible"),
		"respawns":game.get("respawn_count"), "finished":game.get("finished"),
		"position":[pos.x,pos.y,pos.z], "yaw":player.get("yaw"), "pitch":player.get("pitch"),
		"speed":player.call("get_speed"), "elapsed":game.get("elapsed")}

func run() -> void:
	var args := OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--evidence-dir="):
			output = arg.trim_prefix("--evidence-dir=")
		elif arg.begins_with("--practice-stage="):
			stage = int(arg.trim_prefix("--practice-stage="))
	if DisplayServer.get_name() == "headless" or not args.has("--bot") or not args.has("--route=fast") or args.has("--bot-quit") or stage < 1 or stage > 2:
		printerr("capture-practice needs a native display, --bot --route=fast, stage1/2 and no --bot-quit")
		quit(2)
		return
	if not preload("res://scripts/spillway_driver.gd").evidence_path_allowed(output):
		printerr("evidence must be absolute and outside Git")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	if FileAccess.file_exists(output.path_join("practice.png")):
		printerr("use a fresh practice evidence directory")
		quit(2)
		return
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	driver = game.get("bot")
	var elapsed_ticks := 0
	while int(game.get("checkpoint_index")) < stage and not bool(driver.get("done")) and elapsed_ticks < 7200:
		await physics_frame
		elapsed_ticks += 1
	var reached := int(game.get("checkpoint_index")) == stage and int(game.get("respawn_count")) == 0 and bool(game.get("clean_eligible"))
	# stop the automated input source, never the player or its physics.
	driver.set_physics_process(false)
	driver.call("_keys", [])
	var before := state()
	action("practice",true)
	await ticks(1)
	action("practice",false)
	await ticks(8)
	var practiced := state()
	var pose: Transform3D = game.get("level").get("checkpoints")[stage].pose
	var practice_ok := reached and not bool(game.get("clean_eligible")) and not bool(game.get("finished")) and int(game.get("checkpoint_index")) == stage and int(game.get("respawn_count")) == 0
	practice_ok = practice_ok and game.get("player").global_position.distance_to(pose.origin) < .12
	practice_ok = await view("practice.png") and practice_ok
	action("restart",true)
	await ticks(1)
	action("restart",false)
	await ticks(8)
	var restarted := state()
	var spawn: Transform3D = game.get("level").get("spawn")
	var restart_ok: bool = bool(game.get("clean_eligible")) and not bool(game.get("finished")) and int(game.get("checkpoint_index")) == 0 and game.get("splits").is_empty() and int(game.get("respawn_count")) == 0
	restart_ok = restart_ok and game.get("player").global_position.distance_to(spawn.origin) < .12
	restart_ok = await view("restart.png") and restart_ok
	var result := {"fixture":"actual F then R after partial input-driven stage traversal, not full-route proof",
		"build":game.BUILD_ID,"stage":stage,"reached_by_input":reached,"practice_passed":practice_ok,
		"restart_passed":restart_ok,"before":before,"practice":practiced,"restart":restarted}
	driver.call("_write", {"event":"control_fixture_end","result":result})
	var file := FileAccess.open(output.path_join("summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print(JSON.stringify(result))
	# native audio needs actual rendering frames to release while the game shuts down.
	RenderingServer.render_loop_enabled = true
	game.call("request_quit",0 if practice_ok and restart_ok else 1)

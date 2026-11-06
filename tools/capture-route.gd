extends SceneTree
## native input route capture, including the wheel's reaction after arrival.
## use an exported pack, --write-movie and --bot; this wrapper never moves the player.
func _initialize() -> void:
	run.call_deferred()

func finish_hold(main: Node, output: String, look_at_wheel: bool) -> bool:
	# p / recording input only: after braking, turn the head to watch the wheel start.
	# this is ordinary mouse input in the capture, never automatic camera behavior in play.
	var journal := FileAccess.open(output.path_join("post-finish-inputs.jsonl"), FileAccess.WRITE)
	var player: CharacterBody3D = main.get("player")
	var camera: Camera3D = player.get("camera")
	var wheel: Node3D = main.get("level").get("_hero_wheel")
	var previous := player.global_position
	var elapsed := 0.0
	var worst_step := 0.0
	var wheel_contact := false
	var machinery_contact := false
	var views := 0
	while elapsed < 3.0:
		var delta: float = main.get_process_delta_time()
		if look_at_wheel and elapsed > .75 and player.is_grounded() and float(player.call("get_speed")) < 1.0 and wheel != null:
			var offset := wheel.global_position + Vector3.UP * .25 - camera.global_position
			var yaw := atan2(-offset.x, -offset.z)
			var pitch := atan2(offset.y, Vector2(offset.x, offset.z).length())
			var turn := clampf(angle_difference(float(player.get("yaw")), yaw), -2.0 * delta, 2.0 * delta)
			var tilt := clampf(pitch - float(player.get("pitch")), -delta, delta)
			var motion := InputEventMouseMotion.new()
			motion.screen_relative = Vector2(-turn, -tilt) / float(player.get("mouse_sensitivity"))
			motion.relative = motion.screen_relative
			Input.parse_input_event(motion)
			Input.flush_buffered_events()
			journal.store_line(JSON.stringify({"event":"mouse","post_finish_s":elapsed,"screen_relative":[motion.screen_relative.x,motion.screen_relative.y]}))
		await process_frame
		elapsed += main.get_process_delta_time()
		worst_step = maxf(worst_step, player.global_position.distance_to(previous))
		previous = player.global_position
		for i: int in player.get_slide_collision_count():
			var hit := player.get_slide_collision(i)
			for j: int in hit.get_collision_count():
				var body := hit.get_collider(j) as Node
				wheel_contact = wheel_contact or (body != null and str(body.name) == "FinishWheelEnvelope")
				machinery_contact = machinery_contact or (body != null and (str(body.name) == "FinishWheelEnvelope" or str(body.name).begins_with("WheelMaintenanceGuard")))
		journal.store_line(JSON.stringify({"event":"state","post_finish_s":elapsed,"position":[previous.x,previous.y,previous.z],"speed":player.call("get_speed"),"finished":main.get("finished"),"respawns":main.get("respawn_count")}))
		views += 1
	journal.close()
	var passed: bool = bool(main.get("finished")) and int(main.get("respawn_count")) == 0 and worst_step < 2.0
	var result := {"passed":passed,"seconds":elapsed,"samples":views,"max_step_m":worst_step,
		"wheel_contact":wheel_contact,"machinery_contact":machinery_contact,"scripted_mouse_look_after_braking":look_at_wheel,
		"method":"three seconds of live player physics after input-driven finish; optional ordinary mouse input, no camera or body writes"}
	var file := FileAccess.open(output.path_join("post-finish-summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	return passed

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--bot") or args.has("--bot-quit"):
		printerr("capture-route requires --bot and must omit --bot-quit")
		quit(2)
		return
	var save_records := args.has("--save-records")
	var output := ""
	for arg: String in args:
		if arg.begins_with("--evidence-dir="):
			output = arg.trim_prefix("--evidence-dir=").simplify_path()
	if not preload("res://scripts/spillway_driver.gd").evidence_path_allowed(output) or DirAccess.make_dir_recursive_absolute(output) != OK or FileAccess.file_exists(output.path_join("post-finish-summary.json")):
		printerr("capture-route needs a fresh absolute evidence directory outside Git")
		quit(2)
		return
	if save_records:
		# the normal bot never saves. this optional acceptance mode uses only a fresh,
		# isolated profile below the evidence folder, never the player's personal bests.
		var isolated := OS.get_environment("XDG_DATA_HOME").simplify_path()
		if DisplayServer.get_name() == "headless" or not preload("res://scripts/spillway_driver.gd").evidence_path_allowed(output) or isolated != output.path_join("profile") or FileAccess.file_exists("user://spillway_r12.cfg") or FileAccess.file_exists("user://spillway_v1.cfg"):
			printerr("--save-records needs a native display and fresh XDG_DATA_HOME=<evidence-dir>/profile")
			quit(2)
			return
	var main: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(main)
	current_scene = main
	if save_records:
		main.set("_persist", true)
	var driver: Node = main.get("bot")
	while not bool(driver.get("done")):
		await process_frame
	var success: bool = driver.get("succeeded")
	# p / evidence hold only: show the real finish machinery respond before closing the movie.
	success = await finish_hold(main, output, args.has("--finish-look")) and success
	if save_records:
		# read what the ordinary physical finish actually wrote; never seed a result or clock.
		var config := ConfigFile.new()
		var loaded := config.load("user://spillway_r12.cfg") == OK
		var full_best := float(config.get_value("records_r12", "clean_best", -1.0))
		var open_best := float(config.get_value("records_r12", "open_best", -1.0))
		var saved: Array = config.get_value("records_r12", "clean_splits", [])
		var measured: Array = main.get("splits")
		var matches := saved.size() == 3 and measured.size() == 3
		if matches:
			for i: int in 3:
				matches = matches and absf(float(saved[i]) - float(measured[i])) < .000001
		var verified: bool = loaded and success and str(main.get("finish_kind")) == "clean" and bool(main.get("clean_eligible")) and int(main.get("respawn_count")) == 0 and full_best > 0.0 and absf(full_best - float(main.get("elapsed"))) < .000001 and open_best == full_best and matches
		var result := {"verified":verified, "build":main.BUILD_ID,
			"method":"actual normal-spawn input route and ordinary finish save; no clock/result seeding",
			"profile":OS.get_user_data_dir(), "full_best":full_best,"open_best":open_best,
			"saved_splits":saved,"measured_splits":measured,"elapsed":main.get("elapsed")}
		var file := FileAccess.open(output.path_join("record-verification.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "  "))
		file.close()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("records-finish.png"))
		print("capture-route records: ", JSON.stringify(result))
		success = success and verified
	print("capture-route: success=", success, "; held three simulation seconds after the result")
	main.call("request_quit", 0 if success else 1)

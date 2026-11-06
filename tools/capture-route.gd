extends SceneTree
## native input route capture, including the wheel's reaction after arrival.
## use an exported pack, --write-movie and --bot; this wrapper never moves the player.
func _initialize() -> void:
	run.call_deferred()

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
	await create_timer(3.0).timeout
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

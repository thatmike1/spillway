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
	var main: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(main)
	current_scene = main
	var driver: Node = main.get("bot")
	while not bool(driver.get("done")):
		await process_frame
	var success: bool = driver.get("succeeded")
	# p / evidence hold only: show the real finish machinery respond before closing the movie.
	await create_timer(3.0).timeout
	print("capture-route: success=", success, "; held three simulation seconds after the result")
	main.call("request_quit", 0 if success else 1)

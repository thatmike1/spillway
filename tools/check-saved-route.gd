extends SceneTree
## reload a profile produced by capture-route --save-records in a second engine process.
## this reads the ordinary game's loaded records; no clock, result or save fields are seeded.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if DisplayServer.get_name() != "headless" or OS.get_cmdline_user_args().has("--bot"):
		printerr("saved-route reload needs --headless and no bot")
		quit(2)
		return
	var expected_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--expected="):
			expected_path = arg.trim_prefix("--expected=")
	if not expected_path.is_absolute_path() or not FileAccess.file_exists(expected_path):
		printerr("--expected must name capture-route's record-verification.json")
		quit(2)
		return
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	if not expected is Dictionary or not bool(expected.get("verified", false)) or OS.get_user_data_dir() != str(expected.get("profile", "")):
		printerr("expected record must pass and name the current isolated profile")
		quit(2)
		return
	var game: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	var actual_splits: Array = game.get("best_splits")
	var expected_splits: Array = expected.get("saved_splits", [])
	var matches := actual_splits.size() == expected_splits.size() and actual_splits.size() == 3
	if matches:
		for i: int in 3:
			matches = matches and absf(float(actual_splits[i]) - float(expected_splits[i])) < .000001
	var full_best := float(game.get("best_time"))
	var open_best := float(game.get("open_best_time"))
	var passed: bool = matches and game.BUILD_ID == str(expected.get("build", "")) and full_best > 0.0 and absf(full_best - float(expected.get("full_best", -1.0))) < .000001 and absf(open_best - float(expected.get("open_best", -1.0))) < .000001 and bool(game.get("clean_eligible")) and not bool(game.get("finished")) and int(game.get("checkpoint_index")) == 0 and game.get("splits").is_empty()
	var result := {"verified":passed,"build":game.BUILD_ID,"full_best":full_best,
		"open_best":open_best,"saved_splits":actual_splits,
		"settings":game.get("settings"),"profile":OS.get_user_data_dir(),
		"method":"fresh game instance in a second process, normal load, no record/state writes"}
	var file := FileAccess.open(expected_path.get_base_dir().path_join("reload-verification.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("saved route reload: ",JSON.stringify(result))
	game.call("request_quit",0 if passed else 1)

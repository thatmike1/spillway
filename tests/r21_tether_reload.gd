extends SceneTree
## independent process reload of the production profile, with no preference rewriting.
var output := ""
var profile := ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
	run.call_deferred()
func run() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile))
	var before := FileAccess.get_sha256(expected.path)
	var game: Node3D = load("res://scenes/r21.tscn").instantiate()
	game.map_id = "tether-yard"
	game.motor = "server128"
	game.seed_from_r15 = false
	game.profile_path = expected.path
	game.persist = true
	game.record_runs = false
	game.set_window_title = false
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("share.cfg")
	root.add_child(game)
	await physics_frame
	await physics_frame
	var ok: bool = game.player.model == expected.model and game.player.auto_reel == expected.automatic and game.settings.tether_anchor_assist == expected.assist and FileAccess.get_sha256(expected.path) == before
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":ok,"expected":expected,"model":game.player.model,"automatic":game.player.auto_reel,"assist":game.settings.tether_anchor_assist,"profile_unchanged":FileAccess.get_sha256(expected.path)==before}))
	file.close()
	game.request_quit(0 if ok else 1)

extends SceneTree
## source-side probe check; exported verification uses the opt-in host hook instead.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	current_scene = game
	for child: Node in game.get_children():
		if child.get_script() == preload("res://scripts/persistence/package_probe.gd"):
			return
	var probe := preload("res://scripts/persistence/package_probe.gd").new()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--r22-package-check="):
			probe.output_path = arg.trim_prefix("--r22-package-check=")
	game.add_child(probe)

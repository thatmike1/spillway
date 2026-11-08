extends SceneTree
## p / launches the r14 game without changing the project's main scene. the physics rate of
## the starting preset is set here, before the world is built, so the first steps already run
## at it; records persist exactly as when the scene is the main scene.
## godot --path . --script res://scripts/r14_launch.gd [-- --no-records] [-- --r14-preset=ID]

const SCENE := "res://scenes/r14.tscn"
const PRESETS := preload("res://scripts/r14_presets.gd")
const MAIN := preload("res://scripts/r14_main.gd")

func _initialize() -> void:
	var id: String = MAIN.DEFAULT_PRESET
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--r14-preset="):
			var named := PRESETS.resolve(arg.trim_prefix("--r14-preset="))
			if PRESETS.available(named):
				id = named
	Engine.physics_ticks_per_second = int(PRESETS.entry(id).rate)
	var game: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game

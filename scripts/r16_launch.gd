extends SceneTree
## p / launches the r16 game without changing the project's main scene. the physics rate of
## the starting preset is set here, before the world is built, so the first steps already run
## at it; records persist and attempts are recorded exactly as when the scene is the main scene.
## godot --path . --script res://scripts/r16_launch.gd [-- --no-records] [-- --no-run-recordings]
##   [-- --r16-recordings=DIR] [-- --r16-preset=ID] [-- --r16-map=ID]

const SCENE := "res://scenes/r16.tscn"
const PRESETS := preload("res://scripts/r15_presets.gd")
const MAIN := preload("res://scripts/r16_main.gd")

func _initialize() -> void:
	var id: String = MAIN.DEFAULT_PRESET
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--r16-preset="):
			var named := PRESETS.resolve(arg.trim_prefix("--r16-preset="))
			if PRESETS.available(named):
				id = named
	Engine.physics_ticks_per_second = int(PRESETS.entry(id).rate)
	var game: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game

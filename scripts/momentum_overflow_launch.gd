extends SceneTree
## p / launches the r13 overflow game without changing the project's main scene. records
## persist exactly as when the scene is the main scene.
## godot --path . --script res://scripts/momentum_overflow_launch.gd [-- --no-records]

const SCENE := "res://scenes/momentum_overflow.tscn"

func _initialize() -> void:
	var game: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game

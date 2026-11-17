extends SceneTree
## exercises the actual r21 host writer without starting the game.
func _initialize() -> void:
	Engine.print_error_messages = false
	var host: Node = load("res://scripts/r16_main.gd").new()
	var path := "user://legacy.cfg"
	host.profile_path = path
	var corrupt := "[broken\nx=\"unterminated"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(corrupt)
	file.close()
	var config := ConfigFile.new()
	# r21 _save ignores this error and continues with a partial/empty config.
	config.load(path)
	config.set_value("settings", "volume", 0.5)
	var error: int = host._write_config(config)
	var preserved := FileAccess.get_file_as_string(path) == corrupt
	print("unreadable profile preserved: ", preserved, "; write result: ", error)
	host.free()
	quit(0 if preserved else 1)

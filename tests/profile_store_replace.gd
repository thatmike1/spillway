extends SceneTree
## the caller supplies a non-writable directory with writable primary and temporary files.
func _initialize() -> void:
	Engine.print_error_messages = false
	var args := OS.get_cmdline_user_args()
	var path := args[0]
	var host_path := "res://scripts/r16_main.gd"
	for arg: String in args:
		if arg.begins_with("--test-host="):
			host_path = arg.trim_prefix("--test-host=")
	var host: Node = load(host_path).new()
	host.profile_path = path
	var original := FileAccess.get_file_as_bytes(path)
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("current-map", "clean_best_ticks", 200)
	var error: int = host._write_config(config)
	var preserved := FileAccess.get_file_as_bytes(path) == original
	print("failed rename refuses direct overwrite: ", error != OK and preserved, "; original preserved: ", preserved)
	host.free()
	quit(0 if error != OK and preserved else 1)

extends SceneTree
## the caller supplies a mode-000 primary beside a readable, older backup.
func _initialize() -> void:
	Engine.print_error_messages = false
	var args := OS.get_cmdline_user_args()
	var host_path := "res://scripts/r16_main.gd"
	for arg: String in args:
		if arg.begins_with("--test-host="):
			host_path = arg.trim_prefix("--test-host=")
	var host: Node = load(host_path).new()
	host.profile_path = args[0]
	var config := ConfigFile.new()
	var unreadable := config.load(args[0]) != OK
	config.set_value("settings", "volume", 0.37)
	var error: int = host._write_config(config)
	var refused := unreadable and error != OK
	print("unreadable profile refused: ", refused)
	host.free()
	quit(0 if refused else 1)

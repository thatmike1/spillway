extends SceneTree
## the r21 host cannot recover a corrupt primary from a last-good sibling.
func _initialize() -> void:
	Engine.print_error_messages = false
	var path := "user://recovery.cfg"
	var backup := ConfigFile.new()
	backup.set_value("settings", "volume", 0.37)
	backup.set_value("other-map", "clean_best_ticks", 1234567890123)
	backup.save(path + ".bak")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[broken\nx=\"unterminated")
	file.close()
	var host: Node = load("res://scripts/r16_main.gd").new()
	host.profile_path = path
	host.persist = true
	host._load_settings()
	var restored := ConfigFile.new()
	var ok := restored.load(path) == OK and is_equal_approx(float(host.settings.volume), 0.37)
	if ok:
		ok = restored.get_value("other-map", "clean_best_ticks", -1) == 1234567890123
	print("host restores last-good profile: ", ok)
	host.free()
	quit(0 if ok else 1)

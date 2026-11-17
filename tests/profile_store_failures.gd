extends SceneTree

const STORE = preload("res://scripts/persistence/profile_store.gd")
class FaultStore extends "res://scripts/persistence/profile_store.gd":
	var deny_write := false
	var deny_replace := false
	var deny_backup := false
	var denied_read_path := ""
	func _load_checked(path: String, config: ConfigFile) -> Error:
		return ERR_FILE_NO_PERMISSION if path == denied_read_path else super(path, config)
	func _save(config: ConfigFile, path: String) -> Error:
		return ERR_FILE_NO_PERMISSION if deny_write else super(config, path)
	func _replace(source: String, target: String) -> Error:
		return ERR_FILE_CANT_WRITE if (deny_replace and not target.ends_with(".bak")) or (deny_backup and target.ends_with(".bak")) else super(source, target)

var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Engine.print_error_messages = false
	var path := "user://profile.cfg"
	var store := FaultStore.new()
	var config := ConfigFile.new()
	config.set_value("other-map", "clean_best_ticks", 1234567890123)
	config.set_value("other-map", "clean_split_ticks", [12, 1234567890123])
	config.set_value("settings", "volume", 0.7)
	check(store.write_profile(path, config) == OK, "first save")
	check(store.read_profile(path).config.get_value("other-map", "clean_split_ticks") == [12, 1234567890123], "integer split array unchanged")
	var original := FileAccess.get_file_as_bytes(path)
	config.set_value("current-map", "clean_best_ticks", 345)
	store.deny_write = true
	check(store.write_profile(path, config) != OK, "denied write reported")
	check(FileAccess.get_file_as_bytes(path) == original, "denied write preserves every byte")
	store.deny_write = false
	store.deny_replace = true
	check(store.write_profile(path, config) != OK, "failed replacement reported")
	check(FileAccess.get_file_as_bytes(path) == original, "failed replacement preserves every byte")
	store.deny_replace = false
	store.deny_backup = true
	check(store.write_profile(path, config) != OK, "backup replacement failure reported")
	check(FileAccess.get_file_as_bytes(path) == original, "failed backup preserves primary")
	store.deny_backup = false
	check(store.write_profile(path, config) == OK, "retry succeeds")
	var corrupt := "[broken\nx=\"unterminated"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(corrupt)
	file.close()
	store.deny_replace = true
	check(store.read_profile(path).error != OK, "failed recovery reported")
	check(FileAccess.get_file_as_string(path) == corrupt, "failed recovery keeps unreadable primary")
	store.deny_replace = false
	var loaded: Dictionary = store.read_profile(path)
	check(loaded.error == OK and loaded.state == "restored backup", "corrupt profile restored")
	check(loaded.config.get_value("other-map", "clean_best_ticks", -1) == 1234567890123, "other map integer best survives recovery")
	var dir := DirAccess.open("user://")
	var preserved := false
	for name: String in dir.get_files():
		if name.begins_with("profile.cfg.unreadable-"):
			preserved = FileAccess.get_file_as_string("user://" + name) == corrupt
	check(preserved, "unreadable original kept aside")
	DirAccess.remove_absolute(path)
	store.denied_read_path = path
	check(store.read_profile(path).error != OK, "unreadable primary is not absent")
	check(not FileAccess.file_exists(path), "uncertain primary is not replaced without preserving bytes")
	store.denied_read_path = ""
	check(store.read_profile(path).state == "restored backup", "missing primary restored")
	DirAccess.remove_absolute(path + ".bak")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(corrupt)
	file.close()
	check(store.read_profile(path).error != OK, "corrupt without backup is not new")
	check(store.write_profile(path, config) != OK, "refuse save over unreadable profile")
	check(FileAccess.get_file_as_string(path) == corrupt, "unrecoverable original unchanged")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.close()
	check(store.read_profile(path).error != OK, "zero-byte profile is not a new profile")
	check(store.write_profile(path, config) != OK, "zero-byte original is preserved")
	DirAccess.remove_absolute(path)
	store.denied_read_path = path + ".bak"
	check(store.read_profile(path).error != OK, "unreadable backup is not absent")
	check(store.write_profile(path, config) != OK, "refuse a new profile while backup status is unknown")
	store.denied_read_path = ""
	Engine.print_error_messages = true
	for message: String in failures:
		printerr(message)
	print("profile store: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)

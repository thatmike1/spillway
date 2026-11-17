extends SceneTree

const STORE = preload("res://scripts/persistence/profile_store.gd")
const PROBE = preload("res://scripts/persistence/package_probe.gd")
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

class ProbeGame extends Node:
	var profile_path := ""
	var startup_error := ""
	var settings := {"volume": 1.0}
	var last_save_ok := true
	var map_callbacks := 0
	var harness: Object
	func map_ids() -> Array:
		map_callbacks += 1
		return []
	func change_setting(key: String, value: Variant) -> void:
		settings[key] = value
	func request_quit(code: int) -> void:
		harness.call("_finish_probe_seed_check", code, map_callbacks)

var failures: Array[String] = []
var seed_path := ""
var seed_receipt := ""
var seed_original := ""
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
	_start_probe_seed_check()

func _start_probe_seed_check() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--r16-profile="):
			seed_path = arg.trim_prefix("--r16-profile=")
		elif arg.begins_with("--r22-package-check="):
			seed_receipt = arg.trim_prefix("--r22-package-check=")
	var valid_args := seed_path.is_absolute_path() and seed_receipt.is_absolute_path() and seed_path.get_base_dir() == seed_receipt.get_base_dir()
	check(valid_args, "probe regression requires private fixture paths")
	if not valid_args:
		_finish_checks()
		return
	var fresh := not FileAccess.file_exists(seed_path) and not FileAccess.file_exists(seed_receipt)
	check(fresh, "probe regression requires new fixture files")
	if not fresh:
		_finish_checks()
		return
	seed_original = "[other-map]\nclean_best_ticks=1234567890123\nbroken_value=@@@\n"
	var file := FileAccess.open(seed_path, FileAccess.WRITE)
	check(file != null, "private probe fixture created")
	if file == null:
		_finish_checks()
		return
	file.store_string(seed_original)
	file.close()
	var unreadable := ConfigFile.new()
	check(unreadable.load(seed_path) != OK, "private probe fixture must fail ConfigFile.load")
	var host := ProbeGame.new()
	host.profile_path = seed_path
	host.harness = self
	get_root().add_child(host)
	var probe := PROBE.new()
	probe.output_path = seed_receipt
	host.add_child(probe)

func _finish_probe_seed_check(code: int, map_callbacks: int) -> void:
	var preserved := FileAccess.get_file_as_string(seed_path) == seed_original
	check(code == 1, "probe reports an unreadable seed")
	check(preserved, "probe preserves unreadable seed bytes")
	check(map_callbacks == 0, "probe stops before map callbacks after a seed failure")
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(seed_receipt))
	check(receipt is Dictionary and not bool(receipt.get("ok", true)), "probe writes a failed receipt")
	var report := FileAccess.open(seed_receipt + ".test.json", FileAccess.WRITE)
	check(report != null, "probe fixture result recorded")
	if report != null:
		report.store_string(JSON.stringify({"exit": code, "primary_bytes_preserved": preserved, "map_callbacks": map_callbacks}))
		report.close()
	_finish_checks()

func _finish_checks() -> void:
	Engine.print_error_messages = true
	for message: String in failures:
		printerr(message)
	print("profile store: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)

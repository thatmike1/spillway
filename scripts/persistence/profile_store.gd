extends RefCounted
## preserves the existing ConfigFile schema; failed writes never fall back to truncation.

func read_profile(path: String) -> Dictionary:
	var config := ConfigFile.new()
	var error := _load_checked(path, config)
	if error == OK:
		return {"error": OK, "config": config, "state": "loaded"}
	var backup := ConfigFile.new()
	if _load_checked(path + ".bak", backup) == OK:
		# preserve unreadable bytes before replacing them, including syntactically damaged files.
		if FileAccess.file_exists(path):
			var aside := path + ".unreadable-" + str(Time.get_unix_time_from_system()) + "-" + str(Time.get_ticks_usec())
			var preserved := _copy(path, aside)
			if preserved != OK:
				return {"error": preserved, "config": ConfigFile.new(), "state": "unreadable"}
		var restored := _copy(path + ".bak", path + ".tmp")
		if restored == OK:
			restored = _replace(path + ".tmp", path)
		if restored != OK:
			DirAccess.remove_absolute(path + ".tmp")
			return {"error": restored, "config": ConfigFile.new(), "state": "recovery failed"}
		return {"error": OK, "config": backup, "state": "restored backup"}
	# only a genuinely absent profile, with no backup artifact, may start empty.
	if error == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(path + ".bak") and not DirAccess.dir_exists_absolute(path):
		return {"error": OK, "config": ConfigFile.new(), "state": "new"}
	return {"error": error, "config": ConfigFile.new(), "state": "unreadable"}

func write_profile(path: String, config: ConfigFile) -> Error:
	var previous := read_profile(path)
	if previous.error != OK:
		return previous.error
	var temp := path + ".tmp"
	var error := _save(config, temp)
	if error != OK:
		DirAccess.remove_absolute(temp)
		return error
	var checked := ConfigFile.new()
	if checked.load(temp) != OK or checked.encode_to_text() != config.encode_to_text():
		DirAccess.remove_absolute(temp)
		return ERR_FILE_CORRUPT
	# a first save also has a recovery copy. later saves retain the previous good generation.
	var backup_temp := path + ".bak.tmp"
	error = _copy(path if previous.state != "new" else temp, backup_temp)
	if error == OK:
		error = _replace(backup_temp, path + ".bak")
	if error == OK:
		error = _replace(temp, path)
	DirAccess.remove_absolute(temp)
	DirAccess.remove_absolute(backup_temp)
	return error

func _save(config: ConfigFile, path: String) -> Error:
	return config.save(path)

func _copy(source: String, target: String) -> Error:
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(target))

func _replace(source: String, target: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(target))

func _load_checked(path: String, config: ConfigFile) -> Error:
	var error := config.load(path)
	return ERR_FILE_CORRUPT if error == OK and config.get_sections().is_empty() else error

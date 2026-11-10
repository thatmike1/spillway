extends SceneTree
## posix file-size-limit fixture: source is prepared before the engine receives the limit.
const EXPORT := preload("res://scripts/r20_run_export.gd")
var output := ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	call_deferred("run")
func run() -> void:
	var source := output.path_join("runs/random.r16run")
	var before := FileAccess.get_sha256(source)
	var service := EXPORT.new()
	service.folder_opener = func(_folder: String) -> int: return OK
	var result := service.collect(output.path_join("runs"), output, "", {}, output.path_join("exports"), "Disk IO fixture", "r20")
	var ok: bool = not result.ok and DirAccess.get_files_at(output.path_join("exports")).is_empty() and before == FileAccess.get_sha256(source)
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "result": result, "source_unchanged": before == FileAccess.get_sha256(source), "os_limit_bytes": 65536}, "\t"))
	file.close()
	quit(0 if ok else 1)

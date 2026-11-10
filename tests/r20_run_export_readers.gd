extends SceneTree
## original strict Godot reader sees every fixture state; never filters empty valid attempts.
const READER := preload("res://scripts/r16_run_reader.gd")
var directory := ""
var output := ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--root="):
			directory = arg.trim_prefix("--root=")
		elif arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var results: Array = []
	for name: String in DirAccess.get_files_at(directory):
		var path := directory.path_join(name)
		var rec := READER.read(path)
		var target := output.path_join(FileAccess.get_sha256(path) + ".json.gz")
		var file := FileAccess.open(target, FileAccess.WRITE)
		file.store_buffer(JSON.stringify(READER.json_safe(rec), "", false, true).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
		file.close()
		results.append({"path": path, "wire": target, "ok": rec.ok, "status": rec.status, "errors": rec.errors})
	var index := FileAccess.open(output.path_join("index.json"), FileAccess.WRITE)
	index.store_string(JSON.stringify(results, "\t"))
	index.close()
	quit(0 if results.size() > 0 else 1)

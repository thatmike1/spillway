extends SceneTree
## read sealed gameplay bytes with the original Godot reader, preserving every packed vector column.
const READER := preload("res://scripts/r16_run_reader.gd")
var directory := ""
var output := ""
var results: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--root="):
			directory = arg.trim_prefix("--root=")
		elif arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func run() -> void:
	assert(directory.is_absolute_path() and output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	walk(directory)
	var file := FileAccess.open(output.path_join("index.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	print("original Godot strict reader: ", results.size(), " complete gameplay files")
	quit(0 if results.size() > 0 and results.all(func(r: Dictionary) -> bool: return r.ok) else 1)

func walk(at: String) -> void:
	for name: String in DirAccess.get_directories_at(at):
		if name in ["source", "profiles", "readers", "format-python"] or name.begins_with("record_format"):
			continue
		walk(at.path_join(name))
	for name: String in DirAccess.get_files_at(at):
		if not name.ends_with(".r16run"):
			continue
		var path := at.path_join(name)
		var hash := FileAccess.get_sha256(path)
		var rec := READER.read(path)
		var target := output.path_join(hash + ".json.gz")
		var file := FileAccess.open(target, FileAccess.WRITE)
		file.store_buffer(JSON.stringify(READER.json_safe(rec), "", false, true).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
		file.close()
		results.append({"path": path, "sha256": hash, "wire": target, "ok": rec.ok, "errors": rec.errors})

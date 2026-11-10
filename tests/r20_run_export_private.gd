extends SceneTree
## read-only collection source seam: never constructs a game or a recorder on private inputs.
const EXPORT := preload("res://scripts/r20_run_export.gd")
var source := ""
var output := ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			source = arg.trim_prefix("--source=")
		elif arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	call_deferred("run")
func run() -> void:
	assert(source.is_absolute_path() and output.is_absolute_path())
	var service := EXPORT.new()
	service.folder_opener = func(_path: String) -> int: return OK
	var result := service.collect(source.path_join("r16_runs"), source, source.path_join("spillway_r16.cfg"), {}, output.path_join("exports"), "Private completeness check", "r20-private-collection-proof")
	DirAccess.make_dir_recursive_absolute(output)
	var f := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "\t"))
	f.close()
	quit(0 if result.ok else 1)

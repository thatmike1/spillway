extends SceneTree
## copied-run reductions exercise the production reader, selector and ghost without a game.

const READER := preload("res://scripts/r16_run_reader.gd")
const GHOST := preload("res://scripts/r16_ghost.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manifest_path := ""
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--manifest="):
			manifest_path = arg.trim_prefix("--manifest=")
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var rows: Array = []
	var ghost := GHOST.new()
	root.add_child(ghost)
	for spec: Dictionary in manifest.cases:
		var run := READER.read(str(spec.path), true)
		var clean := READER.clean_finish(run)
		var loaded := ghost.load_run(str(spec.path), manifest.identity)
		rows.append({"name": spec.name, "read_ok": run.get("ok", false), "status": run.get("status", ""),
			"errors": run.get("errors", []), "clean": clean, "ghost": loaded})
	var fastest := READER.fastest_clean(str(manifest.folder), manifest.identity)
	ghost.free()
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"cases": rows, "fastest": fastest}, "  "))
	file.close()
	quit(0)

extends SceneTree
## inspect real whole-run recordings with the production reader and ghost, without a game.
const READER := preload("res://scripts/r16_run_reader.gd")
const GHOST := preload("res://scripts/r16_ghost.gd")

func _initialize() -> void:
	_main.call_deferred()

func _main() -> void:
	var opts := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			opts[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	var directory := str(opts.directory)
	var reports: Array = []
	for name: String in DirAccess.get_files_at(directory):
		if not name.ends_with(".r16run"):
			continue
		var path := directory.path_join(name)
		var run := READER.read(path)
		var eligible := READER.clean_finish(run)
		var identity: Dictionary = run.header.identity
		var ghost := GHOST.new()
		root.add_child(ghost)
		var loaded: Dictionary = ghost.load_run(path, identity)
		var pose_checks := 0
		var pose_failures: Array = []
		if bool(loaded.ok):
			var columns: Dictionary = run.columns
			for index: int in range(int(run.seal.timer_start_tick), columns.tick.size(), 17):
				var pose: Dictionary = ghost.pose_at(float(columns.elapsed[index]))
				pose_checks += 1
				if (pose.feet as Vector3).distance_to(columns.p[index]) > 0.000001:
					pose_failures.append(index)
		var fastest := READER.fastest_clean(directory, identity)
		var report := {"path": path, "ok": run.ok, "errors": run.errors, "status": run.status, "clean_finish": eligible,
			"ghost_load": loaded, "ghost_pose_checks": pose_checks, "ghost_pose_failures": pose_failures, "fastest": fastest,
			"seal": run.seal, "columns": _plain(run.columns), "inputs": _plain(run.inputs), "events": run.events}
		reports.append(report)
		ghost.free()
	var file := FileAccess.open(str(opts.out), FileAccess.WRITE)
	file.store_buffer(JSON.stringify(reports, "", false, true).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("r16 whole-run reader inspected ", reports.size(), " recording(s)")
	quit(0)

static func _plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = _plain(value[key])
		return result
	if value is Array or value is PackedInt32Array or value is PackedInt64Array or value is PackedFloat64Array or value is PackedVector3Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_plain(item))
		return result
	return value

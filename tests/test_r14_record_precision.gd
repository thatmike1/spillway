extends "res://tests/test_r14_loop.gd"
## record serialization fixtures are seeded explicitly. the process checks below instead
## play the fixture twice with W, without writing player state or calling finish.

func _main() -> void:
	if not phase.is_empty():
		await _played_phase()
		return
	_group = "serialization fixture"
	for alias: String in ["vanilla64", "server128", "r13_original120"]:
		await _serialization(alias)
		await _drop_game()
	_group = "played fresh processes"
	for alias: String in ["vanilla64", "server128", "r13_original120"]:
		_played_processes(alias)
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": results.size(), "failed": failed.size(), "results": results}, "  "))
	file.close()
	print("r14 record precision: %d checks, %d failed" % [results.size(), failed.size()])
	quit(1 if not failed.is_empty() else 0)

func _serialization(alias: String) -> void:
	await make_game({}, alias)
	game.profile_path = out_dir.path_join(alias + "-seeded.cfg")
	game.persist = true
	var hz := int(game.physics_hz)
	var total := 5865 if hz == 128 else (2933 if hz == 64 else 5499)
	var splits: Array[float] = [float(total / 3) / hz, float(total * 2 / 3) / hz, float(total) / hz]
	var segments: Array[float] = [float(total / 3) / hz, float(total * 2 / 3 - total / 3) / hz, float(total - total * 2 / 3) / hz]
	game.best_time = float(total) / hz
	game.open_best_time = float(total - 1) / hz
	game.best_splits.assign(splits)
	game.best_segments.assign(segments)
	game.call("_save")
	var config := ConfigFile.new()
	config.load(game.profile_path)
	var section := str(game.call("_section"))
	check(alias + " writes an integer best", typeof(config.get_value(section, "clean_best_ticks")) == TYPE_INT and config.get_value(section, "clean_best_ticks") == total)
	check(alias + " writes complete exact split/segment arrays", config.get_value(section, "clean_split_ticks") == game.call("_record_tick_array", splits) and config.get_value(section, "clean_segment_ticks") == game.call("_record_tick_array", segments))
	_clear_records()
	game.call("_load_records")
	check(alias + " restores best/open without float-format loss", game.best_time == float(total) / hz and game.open_best_time == float(total - 1) / hz, [game.best_time, game.open_best_time])
	check(alias + " restores all splits and segments exactly", game.best_splits == splits and game.best_segments == segments, [game.best_splits, game.best_segments])
	check(alias + " equal replay is not faster", not game.call("_record_faster", float(total) / hz, game.best_time))
	check(alias + " sub-tick summation noise is not a best", not game.call("_record_faster", float(total) / hz - 0.000000001, game.best_time))
	check(alias + " one whole tick faster wins", game.call("_record_faster", float(total - 1) / hz, game.best_time))
	# a recognised but damaged exact payload must not silently fall back to rounded summaries.
	for mutation: Array in [["physics_hz", hz * 2], ["time_ticks_version", 99], ["clean_best_ticks", float(total)], ["clean_split_ticks", [1, 2]], ["clean_split_ticks", [1, total + 1, total]], ["clean_segment_ticks", [1, -1, 2]]]:
		var original: Variant = config.get_value(section, mutation[0])
		config.set_value(section, mutation[0], mutation[1])
		config.save(game.profile_path)
		_clear_records()
		game.call("_load_records")
		check(alias + " rejects damaged " + str(mutation[0]), game.best_time < 0.0 and game.open_best_time < 0.0 and game.best_splits.is_empty())
		config.set_value(section, mutation[0], original)
	config.erase_section_key(section, "time_ticks_version")
	config.save(game.profile_path)
	_clear_records()
	game.call("_load_records")
	check(alias + " recovers legacy float values to the right tick", game.best_time == float(total) / hz and game.best_splits == splits and game.best_segments == segments, [game.best_time, game.best_splits])

func _clear_records() -> void:
	game.best_time = -1.0
	game.open_best_time = -1.0
	game.best_splits.clear()
	game.best_segments.clear()

func _played_processes(alias: String) -> void:
	var base := out_dir.path_join("played-" + alias)
	DirAccess.make_dir_recursive_absolute(base)
	var reports: Array[Dictionary] = []
	for pass_id: int in 2:
		var output: Array = []
		var path := base.path_join("pass-%d" % pass_id)
		var args := PackedStringArray(["XDG_DATA_HOME=" + base.path_join("data"), "XDG_CONFIG_HOME=" + base.path_join("config"), "XDG_CACHE_HOME=" + base.path_join("cache"), OS.get_executable_path(), "--headless", "--audio-driver", "Dummy", "--fixed-fps", "128", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/test_r14_record_precision.gd", "--", "--phase=" + alias, "--out=" + path, "--r14-profile=" + base.path_join("spillway_r14.cfg")])
		var code := OS.execute("env", args, output, true)
		var log := FileAccess.open(base.path_join("pass-%d.log" % pass_id), FileAccess.WRITE)
		log.store_string("\n".join(output))
		log.close()
		var report_path := path.path_join("report.json")
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path)) if FileAccess.file_exists(report_path) else {}
		reports.append(report)
		check(alias + " process %d plays a clean recorded finish" % pass_id, code == 0 and report.get("kind") == "clean" and report.get("saved") == true and report.get("respawns") == 0, report)
	var first: Dictionary = reports[0]
	var second: Dictionary = reports[1]
	check(alias + " fresh process restores exact records", second.get("loaded_best") == first.get("best") and second.get("loaded_splits") == first.get("splits") and second.get("loaded_segments") == first.get("segments"), [first, second])
	check(alias + " repeated real-input time is equal", second.get("elapsed") == first.get("elapsed"), [first.get("elapsed"), second.get("elapsed")])
	check(alias + " repeated finish reports no new best", not str(second.get("finish_text", "New best")).contains("New best") and str(second.get("finish_text", "")).contains("vs best"), second.get("finish_text"))
	check(alias + " repeated finish leaves exact record payload unchanged", second.get("profile_hash") == first.get("profile_hash"), [first.get("profile_hash"), second.get("profile_hash")])

func _played_phase() -> void:
	await make_game({}, phase, true, true)
	var report := {"loaded_best": game.best_time, "loaded_splits": game.best_splits.duplicate(), "loaded_segments": game.best_segments.duplicate()}
	key(KEY_W, true)
	await until(func() -> bool: return bool(game.finished), 3000)
	key(KEY_W, false)
	report.merge({"kind": game.finish_kind, "elapsed": game.elapsed, "best": game.best_time, "splits": game.best_splits.duplicate(), "segments": game.best_segments.duplicate(), "saved": game.last_save_ok, "respawns": game.respawn_count, "finish_text": game.hud.finish_body.text, "profile_hash": FileAccess.get_sha256(game.profile_path)})
	var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	await _drop_game()
	quit(0)

extends "res://tests/test_r14_loop.gd"
## seeded record-contract review, separate from the existing input-driven fixture suite.
## calls finish with explicit tick-derived splits; this is not movement or course evidence.

func _main() -> void:
	_group = "record contract review"
	var profile := out_dir.path_join("shared.cfg")
	var sections: Array[String] = []
	for alias: String in ["vanilla64", "server128", "r13_original120"]:
		await make_game({}, alias)
		game.profile_path = profile
		game.persist = true
		var hz := int(game.physics_hz)
		var total := 5865 if hz == 128 else (2933 if hz == 64 else 5499)
		var section := str(game.call("_section"))
		sections.append(section)
		_finish_ticks([1000, 2000, total])
		check(alias + " first seeded clean finish saves", game.last_save_ok and game.finish_kind == "clean")
		var hash := FileAccess.get_sha256(profile)
		await _drop_game()
		await make_game({}, alias)
		game.profile_path = profile
		game.persist = true
		game.call("_load_records")
		check(alias + " fresh node restores all exact values", game.best_time == float(total) / hz and game.open_best_time == float(total) / hz and game.best_splits == [1000.0 / hz, 2000.0 / hz, float(total) / hz] and game.best_segments == [1000.0 / hz, 1000.0 / hz, float(total - 2000) / hz])
		_finish_ticks([1000, 2000, total])
		check(alias + " equal finish has no new-best message or payload change", not game.hud.finish_body.text.contains("New best") and FileAccess.get_sha256(profile) == hash, game.hud.finish_body.text)
		_finish_ticks([1000, 2000, total - 1])
		check(alias + " one tick faster replaces clean/open and final split", game.best_time == float(total - 1) / hz and game.open_best_time == float(total - 1) / hz and game.best_splits.back() == float(total - 1) / hz and game.hud.finish_body.text.contains("New best"), game.hud.finish_body.text)
		_finish_ticks([999, 2000, total + 20])
		check(alias + " slower complete run improves only an independent segment", game.best_time == float(total - 1) / hz and game.best_splits[0] == 1000.0 / hz and game.best_segments == [999.0 / hz, 1000.0 / hz, float(total - 2001) / hz], game.best_segments)
		_finish_ticks([-1, 2000, total - 5])
		check(alias + " faster open finish preserves the clean run and its segments", game.finish_kind == "open" and game.best_time == float(total - 1) / hz and game.open_best_time == float(total - 5) / hz and game.best_splits[0] == 1000.0 / hz and game.best_segments[0] == 999.0 / hz)
		var config := ConfigFile.new()
		config.load(profile)
		check(alias + " profile remains format 1 with typed ticks", config.get_value("profile", "format") == 1 and typeof(config.get_value(section, "clean_best_ticks")) == TYPE_INT and config.get_value(section, "clean_segment_ticks") == [999, 1000, total - 2001])
		await _drop_game()
	# every preset shares the same file; a later save must preserve earlier sections exactly.
	var config := ConfigFile.new()
	config.load(profile)
	check("three rates retain distinct keys in one profile", sections.size() == 3 and sections[0] != sections[1] and sections[1] != sections[2] and sections[0] != sections[2] and Array(config.get_sections()).filter(func(s: String) -> bool: return s.begins_with("course_")).size() == 3)
	for index: int in 3:
		var alias: String = ["vanilla64", "server128", "r13_original120"][index]
		await make_game({}, alias)
		game.profile_path = profile
		game.persist = true
		game.call("_load_records")
		var hz := int(game.physics_hz)
		var total := 5865 if hz == 128 else (2933 if hz == 64 else 5499)
		check(alias + " reload after all other preset saves stays isolated", game.best_time == float(total - 1) / hz and game.open_best_time == float(total - 5) / hz and game.best_segments[0] == 999.0 / hz)
		var section := sections[index]
		var pristine := FileAccess.get_file_as_string(profile)
		config.load(profile)
		config.set_value(section, "clean_best", 0.5)
		config.set_value(section, "open_best", 0.25)
		config.set_value(section, "clean_splits", [0.1, 0.2, 0.5])
		config.save(profile)
		_clear()
		game.call("_load_records")
		check(alias + " exact payload overrides conflicting float summaries", game.best_time == float(total - 1) / hz and game.open_best_time == float(total - 5) / hz and game.best_splits[0] == 1000.0 / hz)
		_restore_file(profile, pristine)
		for mutation: Array in [["clean_best_ticks", "wrong"], ["open_best_ticks", 5.0], ["clean_segment_ticks", [1, 2]], ["clean_split_ticks", [1000, 999, total - 1]], ["time_ticks_version", "bad"]]:
			config.load(profile)
			config.set_value(section, mutation[0], mutation[1])
			config.save(profile)
			_clear()
			game.call("_load_records")
			check(alias + " rejects malformed " + str(mutation[0]) + " without float fallback", game.best_time < 0.0 and game.open_best_time < 0.0 and game.best_splits.is_empty() and game.best_segments.is_empty())
			_restore_file(profile, pristine)
		config.load(profile)
		config.erase_section_key(section, "time_ticks_version")
		config.save(profile)
		_clear()
		game.call("_load_records")
		check(alias + " legacy summaries recover exact ticks", game.best_time == float(total - 1) / hz and game.best_segments == [999.0 / hz, 1000.0 / hz, float(total - 2001) / hz])
		_restore_file(profile, pristine)
		await _drop_game()
	# deliberately corrupt input: this is a bounded hardening observation, not normal play.
	await make_game({}, "server128")
	game.profile_path = out_dir.path_join("oversized.cfg")
	game.persist = true
	_finish_ticks([1000, 2000, 5865])
	var section := str(game.call("_section"))
	config.load(game.profile_path)
	config.set_value(section, "clean_best_ticks", 9007199254740992)
	config.set_value(section, "open_best_ticks", 9007199254740992)
	config.set_value(section, "clean_split_ticks", [1000, 2000, 9007199254740992])
	config.save(game.profile_path)
	_clear()
	game.call("_load_records")
	var observation := {"loaded_seconds": game.best_time, "rank_ticks": game.call("_record_ticks", game.best_time), "next_valid_run_counts_faster": game.call("_record_faster", 45.8203125, game.best_time)}
	var file := FileAccess.open(out_dir.path_join("oversized-observation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(observation, "  "))
	file.close()
	await _drop_game()
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	file = FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": results.size(), "failed": failed.size(), "results": results}, "  "))
	file.close()
	print("record display review: %d checks, %d failed" % [results.size(), failed.size()])
	quit(1 if not failed.is_empty() else 0)

func _finish_ticks(splits: Array) -> void:
	game.clean_eligible = true
	game.stage_times.clear()
	for tick: int in splits:
		game.stage_times.append(float(tick) / game.physics_hz)
	game.elapsed = float(splits.back()) / game.physics_hz
	game.call("_finish")

func _clear() -> void:
	game.best_time = -1.0
	game.open_best_time = -1.0
	game.best_splits.clear()
	game.best_segments.clear()

func _restore_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

extends SceneTree
const MODEL := preload("res://scripts/recordings/run_review_model.gd")
func _init() -> void:
	var folder := "/tmp/r22-08-run-review/performance-attempts"
	DirAccess.make_dir_recursive_absolute(folder)
	var bytes := FileAccess.get_file_as_bytes("res://tests/fixtures/original-map-parity/breakwater-basic/old/runs/golden.r16run")
	for i: int in 300:
		var file := FileAccess.open(folder.path_join("attempt-%03d.r16run" % i), FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
	var start := Time.get_ticks_usec()
	var entries := MODEL.list_attempts(folder)
	var listed := Time.get_ticks_usec()
	var attempt := MODEL.load_attempt(entries[0].path)
	var best := MODEL.matching_best(entries, attempt)
	var finish := Time.get_ticks_usec()
	var scan := MODEL.begin_scan(folder)
	var worst := 0
	var calls := 0
	while true:
		var at := Time.get_ticks_usec()
		var done := MODEL.step_scan(scan)
		worst = maxi(worst, Time.get_ticks_usec() - at)
		calls += 1
		if done: break
	print("RUN_REVIEW_SCAN: slices=", calls, " worst_ms=", worst / 1000.0)
	print("RUN_REVIEW_PERFORMANCE: count=", entries.size(), " list_ms=", (listed-start)/1000.0, " select_ms=", (finish-listed)/1000.0, " best_ok=", best.ok)
	for filename: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	quit(0 if entries.size() == 300 and best.ok else 1)

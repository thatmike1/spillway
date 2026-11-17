extends SceneTree
const SCREEN := preload("res://scripts/ui/run_review.gd")
const MODEL := preload("res://scripts/recordings/run_review_model.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func inventory(directory: String) -> Dictionary:
	var hashes := {}
	for filename: String in DirAccess.get_files_at(directory):
		hashes[filename] = FileAccess.get_sha256(directory.path_join(filename))
	return hashes
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var empty := SCREEN.new()
	empty.directory = "/tmp/r22-08-run-review/no-recordings-created"
	root.add_child(empty)
	paused = true
	while empty.scanning:
		await process_frame
	check(empty.attempts.item_count == 0 and empty.message.text.begins_with("No recordings yet"), "first-run empty state renders while paused")
	check(not DirAccess.dir_exists_absolute(empty.directory), "first-run screen does not create recordings directory")
	empty.queue_free()
	await process_frame
	var folder := "res://tests/fixtures/original-map-parity/breakwater-basic/old/runs"
	var before := inventory(folder)
	var review_folder := "/tmp/r22-08-run-review/screen-pair"
	DirAccess.make_dir_recursive_absolute(review_folder)
	for route: String in ["basic", "return"]:
		var bytes := FileAccess.get_file_as_bytes("res://tests/fixtures/original-map-parity/breakwater-%s/old/runs/golden.r16run" % route)
		var file := FileAccess.open(review_folder.path_join(route + ".r16run"), FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
	var review_before := inventory(review_folder)
	var screen := SCREEN.new()
	screen.directory = review_folder
	root.add_child(screen)
	paused = true
	while screen.scanning:
		await process_frame
	var selected := -1
	for i: int in screen.entries.size():
		if screen.entries[i].name == "return.r16run":
			selected = i
	check(selected >= 0, "fixture listed")
	if selected >= 0:
		screen.select_attempt(selected)
		check(screen.comparison.get("ok", false), "screen displays real recording pair")
		check(screen.comparison.attempt.path != screen.comparison.best.path, "two distinct real recordings shown")
		check(screen.splits.get_root().get_child_count() > 0, "split rows rendered")
		for fraction: float in [0.0, 0.2, 0.5, 1.0]:
			screen.scrubber.value = screen.scrubber.max_value * fraction
			await process_frame
		var row := screen.splits.get_root().get_first_child()
		row.select(0)
		screen.splits.item_selected.emit()
		check(is_equal_approx(screen.scrubber.value, float(row.get_metadata(0))), "checkpoint selection scrubs")
	check(inventory(folder) == before, "review leaves recording folder byte-identical")
	var close_seen: Array[bool] = [false]
	screen.closed.connect(func() -> void: close_seen[0] = true)
	screen.closed.emit()
	check(close_seen[0], "menu close signal emitted")
	screen.queue_free()
	await process_frame
	check(inventory(folder) == before, "close leaves recording folder byte-identical")
	check(inventory(review_folder) == review_before, "distinct real pair stays byte-identical")
	for filename: String in DirAccess.get_files_at(review_folder):
		DirAccess.remove_absolute(review_folder.path_join(filename))
	DirAccess.remove_absolute(review_folder)
	paused = false
	print("RUN_REVIEW_SCREEN: ", "PASS" if failures == 0 else "FAIL", " files unchanged=", before.size())
	quit(0 if failures == 0 else 1)

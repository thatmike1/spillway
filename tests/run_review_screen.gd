extends SceneTree
const SUPPORT := preload("res://tests/run_review_test_support.gd")
var test_output := ""
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
	test_output = SUPPORT.output()
	var empty := SCREEN.new()
	empty.directory = test_output.path_join("no-recordings-created")
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
	var review_folder := test_output.path_join("screen-pair")
	DirAccess.make_dir_recursive_absolute(review_folder)
	for route: String in ["basic", "return"]:
		var bytes := FileAccess.get_file_as_bytes("res://tests/fixtures/original-map-parity/breakwater-%s/old/runs/golden.r16run" % route)
		var file := FileAccess.open(review_folder.path_join(route + ".r16run"), FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
	var prefix := FileAccess.get_file_as_bytes(review_folder.path_join("return.r16run"))
	var partial := FileAccess.open(review_folder.path_join("zzz-partial.r16run.part"), FileAccess.WRITE)
	partial.store_buffer(prefix.slice(0, prefix.size() / 2))
	partial.close()
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
	check(screen.entries[screen.attempts.get_selected_items()[0]].ok, "default selection skips the newest still-open attempt")
	if selected >= 0:
		screen.select_attempt(selected)
		check(screen.comparison.get("ok", false), "screen displays real recording pair")
		check(screen.comparison.attempt.path != screen.comparison.best.path, "two distinct real recordings shown")
		check(screen.splits.get_root().get_child_count() > 0, "split rows rendered")
		var follow: CheckButton = screen.find_children("*", "CheckButton", true, false)[0]
		follow.button_pressed = true
		check(screen.trace.visible and screen.splits.visible and not screen.stage.visible, "unavailable follow retains usable analysis")
		check(screen.view_note.visible and not screen.view_note.text.is_empty(), "unavailable follow explains why")
		var source := Node3D.new()
		root.add_child(source)
		screen.attach_map(source, screen.comparison.attempt.identity)
		check(screen.stage.visible and not screen.trace.visible, "available follow shows stage")
		screen.camera_target.select(1)
		screen.camera_target.item_selected.emit(1)
		check(screen.stage.follow_target == 1 and screen.view_note.text.contains("personal best"), "follow target explicitly switches to best")
		screen.camera_target.select(0)
		screen.camera_target.item_selected.emit(0)
		var requested: Array[Dictionary] = [{}]
		screen.practice_requested.connect(func(value: Dictionary) -> void: requested[0] = value)
		check(not screen.practice_button.disabled, "matching map enables practice action")
		screen.practice_button.pressed.emit()
		check(requested[0].get("stage") == 1, "practice action requests largest-loss start checkpoint")
		var other := MODEL.load_attempt("res://tests/fixtures/original-map-parity/whiteout-crouch/old/runs/golden.r16run")
		screen.attach_map(source, other.identity)
		check(screen.trace.visible and screen.splits.visible and not screen.stage.visible, "valid to unavailable restores analysis")
		check(screen.practice_button.disabled, "different map cannot start practice")
		check(screen.practice_note.visible and screen.practice_note.text.contains("Whiteout"), "practice mismatch explanation is visible without hovering")
		screen.select_attempt(selected)
		check(screen.trace.visible and screen.splits.visible, "selection preserves unavailable fallback")
		screen.refresh()
		while screen.scanning:
			await process_frame
		check(screen.comparison.ok and screen.trace.visible and screen.splits.visible, "completed refresh restores unavailable fallback")
		screen.select_attempt(selected)
		follow.button_pressed = false
		source.queue_free()
		for fraction: float in [0.0, 0.2, 0.5, 1.0]:
			screen.scrubber.value = screen.scrubber.max_value * fraction
			await process_frame
		var row := screen.splits.get_root().get_first_child()
		row.select(0)
		screen.splits.item_selected.emit()
		check(is_equal_approx(screen.scrubber.value, float(row.get_metadata(0))), "checkpoint selection scrubs")
	var partial_index := -1
	for i: int in screen.entries.size():
		var label := screen.attempts.get_item_text(i)
		check(label.contains("2026-") and label.contains("Z"), "recorded date/time is visible in attempt row")
		var width := screen.attempts.get_theme_font("font").get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		check(width <= screen.attempts.size.x - 20, "timestamp row fits on one line")
		if screen.entries[i].name == "zzz-partial.r16run.part":
			partial_index = i
	check(partial_index >= 0, "partial attempt is listed")
	if partial_index >= 0:
		check(screen.attempts.get_item_text(partial_index).contains("incomplete"), "partial status is visible")
		screen.select_attempt(partial_index)
		check(screen.attempts.get_selected_items()[0] == partial_index, "selected row matches displayed incomplete state")
		check(not screen.trace.visible and not screen.splits.visible and not screen.stage.visible and screen.practice_button.disabled, "incomplete attempt never shows stale analysis or practice")
		check(screen.message.text.contains("Choose a sealed attempt"), "incomplete state explains recovery")
		screen.select_attempt(selected)
		check(screen.trace.visible and screen.splits.visible, "valid selection restores analysis after incomplete file")
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

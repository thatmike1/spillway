extends SceneTree
## native fixture interaction through shot.main's pinned private-display wrapper.
var options: Dictionary
var game: Node
var hud: Node
var before: Array
var fixture_paths: Array[String] = []
var rows: Array = []

func _initialize() -> void:
	options = JSON.parse_string(FileAccess.get_file_as_string("res://capture-options.json"))
	RenderingServer.render_loop_enabled = false
	run.call_deferred()

func settle() -> void:
	for i: int in 5:
		await process_frame

func expect(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func capture(index: int, state: String) -> void:
	await settle()
	RenderingServer.force_draw(true, 0.1)
	var path := str(options.out).path_join("frame-%05d.png" % index)
	var error := root.get_texture().get_image().save_png(path)
	rows.append({"frame": index, "state": state, "error": error, "path": path,
		"paused": game.paused, "practice_stage": game.practice_stage, "attempts": game.attempts,
		"host_input": game.is_processing_input(), "window_size": [root.size.x, root.size.y]})
	assert(error == OK)

func run() -> void:
	fixture_paths = ["res://tests/fixtures/original-map-parity/breakwater-basic/old/runs/golden.r16run", "res://tests/fixtures/original-map-parity/breakwater-return/old/runs/golden.r16run"]
	for path: String in fixture_paths:
		before.append(FileAccess.get_sha256(path))
	var library := str(options.out).path_join("recordings")
	DirAccess.make_dir_recursive_absolute(library)
	var copies_before: Array = []
	for i: int in fixture_paths.size():
		var copy_path := library.path_join("basic.r16run" if i == 0 else "return.r16run")
		var copy := FileAccess.open(copy_path, FileAccess.WRITE)
		copy.store_buffer(FileAccess.get_file_as_bytes(fixture_paths[i]))
		copy.close()
		copies_before.append(FileAccess.get_sha256(copy_path))
	if not expect(copies_before == before, "scanned fixture copies must initially match their sealed sources"):
		return
	game = load("res://scripts/game.gd").new()
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = "user://absent-review-profile.cfg"
	game.ghosts_directory = "user://review-test-ghosts"
	game.ghost_share_storage = "user://review-test-selection.cfg"
	root.add_child(game)
	await settle()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.session.directory = library
	game.set_paused(true)
	hud = game.hud
	hud.show_pause_destination("Runs")
	hud.review_button.pressed.emit()
	await settle()
	var review: Control = hud.review_screen
	while review.scanning:
		await process_frame
	for i: int in review.entries.size():
		if str(review.entries[i].path).ends_with("return.r16run"):
			review.select_attempt(i)
	await settle()
	if review.practice_button.disabled:
		push_error("indexed fixture pair must enable practice: " + review.practice_button.tooltip_text)
		quit(1)
		return
	await capture(0, "review-before-mouse")
	var point: Vector2 = review.practice_button.get_global_transform_with_canvas() * (review.practice_button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	if not expect(root.gui_get_hovered_control() == review.practice_button, "mouse must reach the enabled practice button"):
		return
	var attempts_before := int(game.attempts)
	for down: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		click.pressed = down
		root.push_input(click, true)
		await process_frame
	await settle()
	if not expect(hud.review_screen == null and not game.paused and game.is_processing_input(), "native click must close review and restore host input"):
		return
	if not expect(game.practice_stage == 1 and game.attempts == attempts_before + 1 and not game.clean_eligible, "native click must start one non-best checkpoint attempt"):
		return
	await capture(1, "practice-after-mouse")
	var after: Array = []
	for path: String in fixture_paths:
		after.append(FileAccess.get_sha256(path))
	if not expect(before == after, "native interaction must preserve both sealed fixture hashes"):
		return
	var copies_after := [FileAccess.get_sha256(library.path_join("basic.r16run")), FileAccess.get_sha256(library.path_join("return.r16run"))]
	if not expect(copies_before == copies_after, "native interaction must preserve both scanned fixture copies"):
		return
	var trace := FileAccess.open(str(options.out).path_join("frames.jsonl"), FileAccess.WRITE)
	for row: Dictionary in rows:
		trace.store_line(JSON.stringify(row))
	trace.close()
	var result := FileAccess.open(str(options.out).path_join("interaction.json"), FileAccess.WRITE)
	result.store_string(JSON.stringify({"ok": true, "input": "native viewport mouse motion and left press/release", "fixture_hashes_before": before, "fixture_hashes_after": after, "scanned_copy_hashes_before": copies_before, "scanned_copy_hashes_after": copies_after, "frames": rows}, "\t"))
	result.close()
	print("REVIEW_MENU_NATIVE: PASS")
	game.request_quit(0)
	quit()

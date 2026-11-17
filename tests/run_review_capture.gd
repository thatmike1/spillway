extends SceneTree
## static review-screen evidence, never an at-speed route claim.
const SCREEN := preload("res://scripts/ui/run_review.gd")
const MODEL := preload("res://scripts/recordings/run_review_model.gd")
var output := ""
var follow := false
var matrix := false
var frame_index := 0
var states: Array = []
var directory := "res://tests/fixtures/original-map-parity/breakwater-basic/old/runs"
var attempt_name := "golden.r16run"
func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	if FileAccess.file_exists("res://capture-options.json"):
		var options: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://capture-options.json"))
		output = str(options.out).path_join("frame-00000.png")
		follow = bool(options.settings.get("run_review_follow", false))
		matrix = bool(options.settings.get("run_review_matrix", false))
		directory = str(options.out).path_join("recordings")
		attempt_name = "return.r16run"
		DirAccess.make_dir_recursive_absolute(directory)
		for route: String in ["basic", "return"]:
			var bytes := FileAccess.get_file_as_bytes("res://tests/fixtures/original-map-parity/breakwater-%s/old/runs/golden.r16run" % route)
			var file := FileAccess.open(directory.path_join(route + ".r16run"), FileAccess.WRITE)
			file.store_buffer(bytes)
			file.close()
		if matrix:
			var prefix := FileAccess.get_file_as_bytes(directory.path_join("return.r16run"))
			var partial := FileAccess.open(directory.path_join("zzz-partial.r16run.part"), FileAccess.WRITE)
			partial.store_buffer(prefix.slice(0, prefix.size() / 2))
			partial.close()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--review-frame="): output = arg.trim_prefix("--review-frame=")
		if arg == "--review-follow": follow = true
		if arg.begins_with("--review-directory="): directory = arg.trim_prefix("--review-directory=")
		if arg.begins_with("--review-attempt="): attempt_name = arg.trim_prefix("--review-attempt=")
	run.call_deferred()
func run() -> void:
	var host := preload("res://scripts/game.gd").new()
	root.add_child(host)
	await process_frame
	host.set_physics_process(false)
	host.player.set_physics_process(false)
	host.set_paused(true)
	host.hud.hide()
	var screen := SCREEN.new()
	screen.directory = directory
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	layer.add_child(screen)
	screen.attach_map(host.level, host.motion_identity())
	while screen.scanning:
		await process_frame
	for i: int in screen.entries.size():
		if screen.entries[i].name == attempt_name: screen.select_attempt(i)
	screen.scrubber.value = screen.scrubber.max_value * 0.5
	if follow:
		for node: Node in screen.find_children("*", "CheckButton", true, false):
			node.button_pressed = true
	if matrix:
		var hashes := inventory(directory)
		await save_frame(screen, "analysis")
		screen.follow.button_pressed = true
		await save_frame(screen, "follow-attempt")
		screen.camera_target.select(1)
		screen.camera_target.item_selected.emit(1)
		await save_frame(screen, "follow-best")
		host.select_map("whiteout-relay")
		host.set_paused(true)
		host.set_physics_process(false)
		host.player.set_physics_process(false)
		screen.attach_map(host.level, host.motion_identity())
		if not screen.trace.visible or not screen.splits.visible: push_error("unavailable follow lost analysis")
		await save_frame(screen, "unavailable-whiteout-current-map")
		for i: int in screen.entries.size():
			if screen.entries[i].name == "zzz-partial.r16run.part": screen.select_attempt(i)
		await save_frame(screen, "partial-attempt")
		if inventory(directory) != hashes: push_error("UI capture changed its recording copies")
		var receipt := FileAccess.open(output.get_base_dir().path_join("review-states.json"), FileAccess.WRITE)
		receipt.store_string(JSON.stringify(states, "\t"))
		quit()
		return
	if not output.is_empty():
		await save_frame(screen, "follow-attempt" if follow else "analysis")
	else:
		print("RUN_REVIEW_CAPTURE_SMOKE: pair=", screen.comparison.get("ok", false), " preview_available=", screen.stage.tracks.size() == 2)
	quit(0 if screen.comparison.get("ok", false) and screen.stage.tracks.size() == 2 else 1)

func save_frame(screen: Control, kind: String) -> void:
	await process_frame
	RenderingServer.force_draw(true)
	var path := output.get_base_dir().path_join("frame-%05d.png" % frame_index) if matrix else output
	var error := root.get_texture().get_image().save_png(path)
	if error != OK: push_error("review frame save failed")
	states.append({"kind": kind, "path": path, "comparison_ok": screen.comparison.get("ok", false), "stage": screen.stage.visible, "chart": screen.trace.visible, "splits": screen.splits.visible, "note": screen.view_note.text})
	print("RUN_REVIEW_FRAME ", kind, " ", path)
	frame_index += 1

func inventory(folder: String) -> Dictionary:
	var hashes := {}
	for filename: String in DirAccess.get_files_at(folder):
		hashes[filename] = FileAccess.get_sha256(folder.path_join(filename))
	return hashes

extends SceneTree
## static review-screen evidence, never an at-speed route claim.
const SCREEN := preload("res://scripts/ui/run_review.gd")
const MODEL := preload("res://scripts/recordings/run_review_model.gd")
var output := ""
var follow := false
var directory := "res://tests/fixtures/original-map-parity/breakwater-basic/old/runs"
var attempt_name := "golden.r16run"
func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	if FileAccess.file_exists("res://capture-options.json"):
		var options: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://capture-options.json"))
		output = str(options.out).path_join("frame-00000.png")
		follow = bool(options.settings.get("run_review_follow", false))
		directory = str(options.out).path_join("recordings")
		attempt_name = "return.r16run"
		DirAccess.make_dir_recursive_absolute(directory)
		for route: String in ["basic", "return"]:
			var bytes := FileAccess.get_file_as_bytes("res://tests/fixtures/original-map-parity/breakwater-%s/old/runs/golden.r16run" % route)
			var file := FileAccess.open(directory.path_join(route + ".r16run"), FileAccess.WRITE)
			file.store_buffer(bytes)
			file.close()
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
	if not output.is_empty():
		await process_frame
		RenderingServer.force_draw(true)
		var error := root.get_texture().get_image().save_png(output)
		print("RUN_REVIEW_FRAME: ", output, " error=", error, " pair=", screen.comparison.get("ok", false), " preview_available=", screen.stage.tracks.size() == 2, " preview_note=", screen.view_note.text)
	else:
		print("RUN_REVIEW_CAPTURE_SMOKE: pair=", screen.comparison.get("ok", false), " preview_available=", screen.stage.tracks.size() == 2, " preview_note=", screen.view_note.text)
	quit(0 if screen.comparison.get("ok", false) and screen.stage.tracks.size() == 2 else 1)

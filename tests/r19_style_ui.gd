extends SceneTree
## presentation fixture uses the actual r18 scene controls; points are staged, not earned input.
const MAIN := preload("res://scripts/r17_main.gd")
var output := ""
var checks: Array = []
var resolution := Vector2i(1280, 720)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			resolution = Vector2i(int(parts[0]), int(parts[1]))
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func check(ok: bool, name: String) -> void:
	checks.append({"pass": ok, "name": name})
	print("%s %s" % ["ok" if ok else "FAIL", name])

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	var game := MAIN.new()
	game.persist = false
	game.seed_from_r15 = false
	game.record_runs = false
	root.add_child(game)
	root.mode = Window.MODE_WINDOWED
	root.size = resolution
	game.hud.dismiss_title()
	for i: int in 65:
		await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.session.set_physics_process(false)
	var panel: Control = game.hud.style_panel
	panel.set_process(false)
	var event := {"kind": "backward_bhop", "label": "Backwards 4 hops ×3", "points": 240, "time_s": 1.0, "tick": 1}
	var snap := {"score": 2860, "combo": 3, "mult": 1.5, "combo_left_s": 2.0, "combo_window_s": 2.5,
		"direction": {"kind": "backward_bhop", "hops": 4, "mult": 3.0}, "last": event}
	panel.update_from(snap, 0.0)
	check(panel.direction_label.is_visible_in_tree() and panel.direction_label.text.contains("Backwards"), "direction multiplier visible in actual HUD")
	check(panel.callout.text.contains("Backwards") and panel._shown_rank == 4, "backwards callout has gap rank")
	snap.last = {"kind": "speed", "label": "Speed 420", "points": 30, "time_s": 1.01, "tick": 2}
	panel.update_from(snap, 0.1)
	check(panel.callout.text.contains("Backwards"), "speed burst cannot overwrite backwards hold")
	snap.last = {"kind": "crouch_save", "label": "Crouch save", "points": 900, "time_s": 1.02, "tick": 3}
	panel.update_from(snap, 0.1)
	check(panel.callout.text.contains("Crouch save"), "crouch save retains highest priority")
	check(not panel.callout.get_global_rect().intersects(panel.direction_label.get_global_rect()), "direction and callout do not overlap")
	check(not panel.score_label.get_global_rect().intersects(panel.callout.get_global_rect()), "score and callout do not overlap")
	for label: Label in [panel.callout, panel.direction_label, panel.score_label]:
		check(root.get_visible_rect().encloses(label.get_global_rect()), "text fits viewport: " + label.text)
	if DisplayServer.get_name() != "headless":
		snap.last = event
		panel.update_from(snap, 1.0)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(image.get_size() == resolution, "native frame matches requested resolution")
		image.save_png(output.path_join("backwards.png"))
	snap.direction = {"kind": "sideways_bhop", "hops": 4, "mult": 1.5}
	snap.last = {"kind": "sideways_bhop", "label": "Half-sideways 4 hops ×1.5", "points": 60, "time_s": 2.0, "tick": 4}
	panel.update_from(snap, 1.0)
	check(panel.direction_label.text.contains("Half-sideways") and panel._shown_rank == 3, "sideways rank and label")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("sideways.png"))
	snap.direction = {}
	panel.update_from(snap, 1.0)
	check(not panel.direction_label.is_visible_in_tree(), "broken chain removes live bonus line")
	var failed := checks.filter(func(row: Dictionary) -> bool: return not row.pass)
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed.size(), "renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name()}, "\t"))
	file.close()
	game.request_quit(0)
	quit(0 if failed.is_empty() else 1)

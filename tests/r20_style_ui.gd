extends SceneTree
## bounds and text checks in actual R20 controls; staging proves layout only, not earned score.
const SCENE := preload("res://scenes/r20.tscn")
var output := ""
var resolution := Vector2i(1280, 720)
var checks: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			resolution = Vector2i(int(parts[0]), int(parts[1]))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	print("%s %s" % ["ok" if ok else "FAIL", label])

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	root.mode = Window.MODE_WINDOWED
	root.size = resolution
	var game := SCENE.instantiate()
	game.persist = false
	game.seed_from_r15 = false
	game.record_runs = false
	game.profile_path = output.path_join("absent.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("share.cfg")
	root.add_child(game)
	game.hud.dismiss_title()
	for i: int in 65:
		await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.session.set_physics_process(false)
	var panel: Control = game.hud.style_panel
	panel.set_process(false)
	var snap := {"score": 12340, "combo": 5, "mult": 2.0, "combo_left_s": 2.0, "combo_window_s": 2.5, "context": {"attempt": 1},
		"direction": {"kind": "backward_bhop", "hops": 1, "pending": 0}, "last": {}}
	panel.update_from(snap, 0.0)
	check(panel.direction_label.visible and "1 hops" in panel.direction_label.text and "+0 pending" in panel.direction_label.text, "first hop arms a visible zero pending stack")
	check(panel.caption.text == "banked style" and panel.score_label.text == panel.points_text(12340), "score explicitly labelled banked style")
	for direction: String in ["backward_bhop", "sideways_bhop"]:
		for hops: int in [6, 12, 20, 1000]:
			snap.direction = {"kind": direction, "hops": hops, "pending": preload("res://scripts/r16_style.gd").pending_points(direction, hops)}
			panel.update_from(snap, 1.5)
			check("pending" in panel.direction_label.text and not "×" in panel.direction_label.text, "pending distinct from multiplier: " + direction + str(hops))
			bounds(panel, direction + str(hops))
	snap.direction = {"kind": "", "hops": 0, "pending": 0, "last": {"serial": 1, "kind": "direction_banked", "direction": "backward_bhop", "pending": 30400}}
	panel.update_from(snap, 1.5)
	check("banked" in panel.callout.text and "+" in panel.callout.text and not panel.direction_label.visible, "short banked callout replaces pending")
	bounds(panel, "banked")
	snap.direction.last = {"serial": 2, "kind": "direction_lost", "direction": "backward_bhop", "pending": 30400}
	panel.update_from(snap, 1.5)
	check("lost" in panel.callout.text and not "+" in panel.callout.text and panel.score_label.text == panel.points_text(12340), "loss toast does not look awarded")
	bounds(panel, "lost")
	snap.context.attempt = 2
	panel.update_from(snap, 1.5)
	check(panel._shown_age == 0.0, "same transition serial in another attempt still shows")
	game.set_paused(true)
	panel._process(0.1)
	check(not panel.visible, "pause hides style through inherited panel behavior")
	game.set_paused(false)
	panel._process(0.1)
	check(panel.visible, "resume restores style")
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks, "size": [resolution.x, resolution.y], "window_size": [root.size.x, root.size.y], "logical_viewport": [root.get_visible_rect().size.x, root.get_visible_rect().size.y], "scope": "headless scene bounds and copy; parent owns native GPU inspection"}, "\t"))
	file.close()
	game.request_quit(0)
	quit(0 if ok else 1)

func bounds(panel: Control, label: String) -> void:
	var viewport := root.get_visible_rect()
	var center := Rect2(viewport.size * 0.4, viewport.size * 0.2)
	for node: Label in [panel.direction_label, panel.callout, panel.score_label, panel.caption, panel.mult_label]:
		if node.visible and not node.text.is_empty():
			check(root.get_visible_rect().encloses(node.get_global_rect()), label + " viewport: " + node.name)
			check(not center.intersects(node.get_global_rect()), label + " center clear: " + node.name)
	check(not panel.direction_label.get_global_rect().intersects(panel.callout.get_global_rect()), label + " pending and callout separate")
	check(not panel.score_label.get_global_rect().intersects(panel.callout.get_global_rect()), label + " score and callout separate")

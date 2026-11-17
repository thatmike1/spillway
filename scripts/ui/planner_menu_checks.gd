extends SceneTree
## real planner keys must respect both pause destinations and the run-review input shield.
var output := ""
var native := false
var game: Node
var hud: Node
var checks: Array = []
var frames: Array = []
var started_ms := Time.get_ticks_msec()

func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	if FileAccess.file_exists("res://capture-options.json"):
		var options: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://capture-options.json"))
		output = str(options.out)
		native = true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started_ms > 120000:
		push_error("planner menu watchdog")
		quit(1)
	return false

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	if not ok:
		push_error(label)

func settle() -> void:
	for i: int in 5:
		await process_frame

func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func files() -> Dictionary:
	var result := {}
	var runs := output.path_join("runs")
	var recorded := DirAccess.get_files_at(runs) if DirAccess.dir_exists_absolute(runs) else PackedStringArray()
	for name: String in recorded:
		result["runs/" + name] = FileAccess.get_sha256(output.path_join("runs").path_join(name))
	for name: String in DirAccess.get_files_at(output):
		if name.begins_with("plans.cfg"):
			result[name] = FileAccess.get_sha256(output.path_join(name))
	return result

func state() -> Dictionary:
	return {"attempts": game.attempts, "elapsed": game.elapsed, "identity": game.motion_identity(),
		"position": game.player.global_position, "velocity": game.player.velocity,
		"design": game.level.design().duplicate(true), "planning": game.player.planning,
		"slot": game.player.planner.active_slot, "brush": game.player.planner.brush,
		"notice": game.player.planner.notice, "files": files(), "pending": game.session.pending.duplicate(true)}

func capture(label: String) -> void:
	if not native:
		return
	await settle()
	RenderingServer.force_draw(true, 0.1)
	var path := output.path_join("frame-%05d.png" % frames.size())
	var error := root.get_texture().get_image().save_png(path)
	frames.append({"frame": frames.size(), "state": label, "path": path, "error": error,
		"window_size": [root.size.x, root.size.y], "paused": game.paused,
		"planning": game.player.planning, "planner_visible": game.player.planner.is_visible_in_tree(),
		"review_visible": hud.review_screen != null, "attempts": game.attempts})
	check(error == OK, "native readback " + label)

func challenge_keys(review: bool) -> void:
	var keys: Array[Key] = [KEY_TAB, KEY_F6, KEY_F7, KEY_F8, KEY_BRACKETLEFT, KEY_BRACKETRIGHT,
		KEY_A, KEY_B, KEY_P, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_DELETE, KEY_ENTER]
	for code: Key in keys:
		# enter deliberately focuses a destination/list, avoiding a legitimate resume/practice click.
		if review:
			hud.review_screen.attempts.grab_focus()
		else:
			hud.pause_tabs["Maps"].grab_focus()
		var before := state()
		key(code)
		await settle()
		check(game.paused and state() == before and not game.player.planner.is_visible_in_tree(),
			("review" if review else "pause") + " isolates planner key " + OS.get_keycode_string(code))
		if review:
			check(hud.review_screen != null, "planner key retains review " + OS.get_keycode_string(code))

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://scripts/game.gd").new()
	game.map_id = "plan-yard"
	game.persist = false
	game.record_runs = not native
	game.recordings_dir = output.path_join("runs")
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output.path_join("absent.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.plan_store.path = output.path_join("plans.cfg")
	await settle()
	hud = game.hud
	check(not game.session.recorder.enabled if native else game.session.recorder.enabled and not files().is_empty(), "native wrapper keeps recording disabled" if native else "headless challenge uses actual private recording files")
	key(KEY_ESCAPE)
	await settle()
	check(game.paused and hud.pause_panel.is_visible_in_tree(), "physical Escape opens actual pause menu")
	await capture("paused-maps")
	await challenge_keys(false)
	hud.show_pause_destination("Runs")
	hud.review_button.pressed.emit()
	await settle()
	check(hud.review_screen != null and not game.is_processing_input(), "real Runs entry opens shielded review on Plan Yard")
	await capture("paused-review")
	await challenge_keys(true)
	key(KEY_ESCAPE)
	await settle()
	check(hud.review_screen == null and game.paused and game.is_processing_input(), "physical Escape returns from review to paused Runs")
	key(KEY_ESCAPE)
	key(KEY_TAB)
	await settle()
	check(game.player.planning and game.player.planner.is_visible_in_tree() and not game.session.attempt_live, "unpaused Tab still opens untimed survey")
	game.player.planner.toggle_socket(int(game.level.plan[0]))
	var design: Dictionary = game.level.design().duplicate(true)
	await capture("survey")
	key(KEY_ESCAPE)
	await settle()
	check(game.paused and not game.player.planner.is_visible_in_tree() and hud.pause_panel.is_visible_in_tree(), "Escape hides the survey beneath the visible menu")
	await capture("survey-paused")
	await challenge_keys(false)
	key(KEY_ESCAPE)
	await settle()
	check(not game.paused and game.player.planner.is_visible_in_tree() and game.level.design() == design and not game.session.attempt_live and game.elapsed == 0.0, "resume restores the pending survey outside timing")
	await capture("survey-resumed")
	key(KEY_ESCAPE)
	await settle()
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = size
		hud._layout()
		await settle()
		check(game.paused and not game.player.planner.is_visible_in_tree() and hud.pause_panel.is_visible_in_tree(), "paused survey remains hidden after resize " + str(size))
		check(is_equal_approx(hud.resume_button.get_global_rect().position.y, hud.quit_button.get_global_rect().position.y), "long checkpoint action row fits after resize " + str(size))
		await capture("survey-paused-" + str(size.x))
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	var result := FileAccess.open(output.path_join("planner-menu-checks.json"), FileAccess.WRITE)
	result.store_string(JSON.stringify({"ok": ok, "native": native, "recording_enabled": game.session.recorder.enabled, "checks": checks, "frames": frames}, "\t"))
	result.close()
	if native:
		var trace := FileAccess.open(output.path_join("frames.jsonl"), FileAccess.WRITE)
		for row: Dictionary in frames:
			trace.store_line(JSON.stringify(row))
		trace.close()
	print("PLANNER_MENU: ", ok, " count=", checks.size())
	game.request_quit(0)
	quit(0 if ok else 1)

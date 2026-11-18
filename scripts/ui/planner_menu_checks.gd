extends SceneTree
## real planner keys must respect both pause destinations and the run-review input shield.
const PRACTICE := preload("res://scripts/recordings/run_review_practice.gd")
const MODEL := preload("res://scripts/recordings/run_review_model.gd")
var output := ""
var native := false
var game: Node
var hud: Node
var checks: Array = []
var frames: Array = []
var fixture_paths: Array[String] = []
var fixture_hashes: Array = []
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
		"clean": game.clean_eligible, "practice_reason": game.practice_reason, "preferences": JSON.stringify(game.settings, "", true),
		"spatial_reason": PRACTICE.unavailable_reason(game),
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
		KEY_A, KEY_B, KEY_P, KEY_Q, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_DELETE, KEY_ENTER]
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
	var library := output.path_join("library")
	DirAccess.make_dir_recursive_absolute(library)
	fixture_paths = [fixture_path("original-map-parity/breakwater-basic/old/runs/golden.r16run"), fixture_path("original-map-parity/breakwater-return/old/runs/golden.r16run")]
	for i: int in fixture_paths.size():
		fixture_hashes.append(FileAccess.get_sha256(fixture_paths[i]))
		var file := FileAccess.open(library.path_join("basic.r16run" if i == 0 else "return.r16run"), FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(fixture_paths[i]))
		file.close()
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
	check(PRACTICE.unavailable_reason(game).is_empty(), "committed normal Plan Yard remains eligible under ordinary identity checks")
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
	check(hud.review_screen.spatial_unavailable_reason.is_empty() and hud.review_screen.stage.scenery.get_child_count() > 0, "committed Plan caller permits map presentation")
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
	hud.show_pause_destination("Runs")
	hud.review_button.pressed.emit()
	await settle()
	var review: Control = hud.review_screen
	var reason := PRACTICE.unavailable_reason(game)
	check(not reason.is_empty() and review.spatial_unavailable_reason == reason, "pending survey reason reaches the real viewer")
	check(review.stage.scenery.get_child_count() == 0, "pending geometry is never cloned into the recorded world")
	review.directory = library
	review.refresh()
	while review.scanning:
		await process_frame
	for i: int in review.entries.size():
		if str(review.entries[i].path).ends_with("return.r16run"):
			review.select_attempt(i)
	await settle()
	check(review.comparison.get("ok", false) and review.trace.visible and review.splits.visible and not review.stage.visible and review.stage.tracks.is_empty(), "pending survey preserves real recorded split and speed analysis")
	check(review.practice_button.disabled and review.practice_note.visible and review.practice_note.text == reason, "pending survey explains the disabled segment action")
	await capture("pending-survey-review")
	await challenge_keys(true)
	var before := state()
	var request: Dictionary = MODEL.practice_request(review.comparison)
	check(request.get("ok", false), "real copied pair supplies a completed largest-loss request")
	var refusal := PRACTICE.start(game, request)
	check(not refusal.ok and refusal.error == reason and state() == before, "helper refuses pending phase before any attempt or state mutation")
	var emissions := [0]
	review.practice_requested.connect(func(_request: Dictionary) -> void: emissions[0] += 1)
	review.practice_button.pressed.emit()
	check(emissions[0] == 0 and state() == before, "blocked viewer action suppresses requests")
	review.practice_requested.emit(request)
	await settle()
	check(hud.review_screen == null and game.paused and hud.review_practice_status.visible and hud.review_practice_status.text == reason and state() == before, "stale request returns safely to the same paused pending survey")
	await capture("pending-survey-refusal")
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
	var originals_after: Array = []
	for path: String in fixture_paths:
		originals_after.append(FileAccess.get_sha256(path))
	var copies_after := [FileAccess.get_sha256(library.path_join("basic.r16run")), FileAccess.get_sha256(library.path_join("return.r16run"))]
	check(fixture_hashes == originals_after and fixture_hashes == copies_after, "phase review preserves both sealed originals and scanned copies")
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	var result := FileAccess.open(output.path_join("planner-menu-checks.json"), FileAccess.WRITE)
	result.store_string(JSON.stringify({"ok": ok, "native": native, "recording_enabled": game.session.recorder.enabled, "checks": checks, "frames": frames, "originals_before": fixture_hashes, "originals_after": originals_after, "copies_after": copies_after}, "\t"))
	result.close()
	if native:
		var trace := FileAccess.open(output.path_join("frames.jsonl"), FileAccess.WRITE)
		for row: Dictionary in frames:
			trace.store_line(JSON.stringify(row))
		trace.close()
	print("PLANNER_MENU: ", ok, " count=", checks.size())
	game.request_quit(0)
	quit(0 if ok else 1)

func fixture_path(relative: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--menu-contract="):
			var contract := arg.trim_prefix("--menu-contract=")
			return contract.get_base_dir().get_base_dir().path_join(relative)
	return "res://tests/fixtures/".path_join(relative)

extends SceneTree
## exercise the real viewer button, menu callback and host practice against sealed fixture bytes.
const MODEL := preload("res://scripts/recordings/run_review_model.gd")
var output := ""
var checks: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func settle() -> void:
	for i: int in 5:
		await process_frame

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	if not ok:
		push_error(label)

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	var best_path := fixture_path("original-map-parity/breakwater-basic/old/runs/golden.r16run")
	var attempt_path := fixture_path("original-map-parity/breakwater-return/old/runs/golden.r16run")
	var before := [FileAccess.get_sha256(best_path), FileAccess.get_sha256(attempt_path)]
	var comparison := MODEL.compare(MODEL.load_attempt(attempt_path), MODEL.load_attempt(best_path))
	var game: Node = load("res://scripts/game.gd").new()
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output.path_join("absent.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection.cfg")
	root.add_child(game)
	await settle()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.session.directory = output.path_join("absent-runs")
	game.set_paused(true)
	var hud: Node = game.hud
	hud.show_pause_destination("Runs")
	hud.review_button.pressed.emit()
	await settle()
	var review: Control = hud.review_screen
	check(review != null and not game.is_processing_input() and game.paused, "menu opens the real paused viewer")
	review.scanning = false
	review.comparison = comparison
	review._update_practice_action()
	check(not review.practice_button.disabled, "real comparable fixtures enable segment practice")
	var attempts_before := int(game.attempts)
	var settings_before := JSON.stringify(game.settings, "", true)
	review.practice_button.pressed.emit()
	await settle()
	check(hud.review_screen == null and game.is_processing_input(), "practice button closes viewer and restores host input")
	check(game.attempts == attempts_before + 1 and game.practice_stage == 1 and not game.clean_eligible and not game.paused, "practice button starts exactly one non-best checkpoint attempt")
	var controller: Node = null
	for child: Node in game.get_children():
		if child.get_meta("run_review_practice", false):
			controller = child
	check(controller != null, "practice installs its owned best ghost")
	if controller != null:
		check(is_equal_approx(float(controller.pb_start), 5.7421875) and is_equal_approx(float(controller.ghost.get("_time")), 5.7421875), "best ghost begins at the selected checkpoint clock")
	check(JSON.stringify(game.settings, "", true) == settings_before, "practice preserves user settings")
	check(hud._run_text().begins_with("PB segment guide") and not "no ghost yet" in hud._run_text(), "HUD identifies the active separate PB segment guide")
	game.set_paused(true)
	hud.show_pause_destination("Runs")
	hud.review_button.pressed.emit()
	await settle()
	attempts_before = int(game.attempts)
	hud.review_screen.practice_requested.emit({"ok": false})
	await settle()
	check(hud.review_screen == null and game.paused and game.is_processing_input(), "invalid practice returns to paused Runs with input restored")
	check(game.attempts == attempts_before and hud.review_practice_status.is_visible_in_tree() and not hud.review_practice_status.text.is_empty(), "invalid practice explains failure without starting an attempt")
	check(hud.review_button.has_focus(), "invalid practice restores review action focus")
	game.restart_run("restart")
	await settle()
	check(not "PB segment guide" in hud._run_text() and JSON.stringify(game.settings, "", true) == settings_before, "ordinary restart restores the normal ghost status without changing preferences")
	check([FileAccess.get_sha256(best_path), FileAccess.get_sha256(attempt_path)] == before, "both sealed recording files retain their hashes")
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	var file := FileAccess.open(output.path_join("review-menu-checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks}, "\t"))
	file.close()
	print("review menu checks: ", ok, " count=", checks.size())
	game.request_quit(0)
	quit(0 if ok else 1)

func fixture_path(relative: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--menu-contract="):
			var contract := arg.trim_prefix("--menu-contract=")
			return contract.get_base_dir().get_base_dir().path_join(relative)
	return "res://tests/fixtures/".path_join(relative)

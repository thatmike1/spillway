extends SceneTree
## challenge opted-in map text and the unchanged default in the real HUD chain.
var output := ""
var checks: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	if not ok:
		push_error(label)

func settle() -> void:
	for i: int in 5:
		await process_frame

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var game: Node = load("res://scripts/game.gd").new()
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output.path_join("absent.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	await settle()
	var hud: Node = game.hud
	check(hud.practice_message().is_empty(), "ordinary map does not opt into practice wording")
	game.select_map("tether-yard")
	game.player.set_physics_process(false)
	await settle()
	var fallback := "LMB hold to swing · RMB reel · release LMB to coast\nSpace jump · A/D strafe · Esc rope model and reel preference"
	hud._process(0.0)
	check(hud.title_card.get_node("TitleKeys").text == fallback, "grapple start controls retain exact generic fallback")
	var identity: Dictionary = game.motion_identity().duplicate(true)
	var attempts := int(game.attempts)
	var settings := JSON.stringify(game.settings, "", true)
	var custom := "Aim at the first anchor.\nReel through the low point.\nRise above the pale landing.\nLook ahead while attached."
	game.maps.catalog["tether-yard"]["start_controls"] = custom
	hud._process(0.0)
	check(hud.title_card.get_node("TitleKeys").text == custom, "declared map start controls reach the actual title label")
	check(game.motion_identity() == identity and game.attempts == attempts and JSON.stringify(game.settings, "", true) == settings, "start controls preserve identity attempt and preferences")
	game.maps.catalog["tether-yard"].erase("start_controls")
	var entry: Dictionary = game.map_entry("plan-yard").duplicate(true)
	entry["script"] = "res://scripts/ui/hud_message_fixture.gd"
	game.maps.catalog["hud-message-test"] = entry
	game.maps.order.append("hud-message-test")
	game.select_map("hud-message-test")
	game.player.set_physics_process(false)
	game.practise_stage(0)
	game.player.set_physics_process(false)
	await settle()
	check("R for a clean run" in hud.practice_tag.text, "empty map practice message retains ordinary banner")
	custom = "Envelope practice · no best · Tab, Q turns it off"
	game.level.hud_practice_message = custom
	hud._process(0.0)
	check(hud.practice_tag.text == custom, "opted-in practice message replaces the live banner")
	game.finished = true
	game.finish_kind = "practice"
	hud.show_finish(false, false)
	check(hud._finish_result.text == custom, "opted-in practice message replaces the visible practice finish result")
	game.finished = false
	game.level.hud_practice_message = ""
	hud._process(0.0)
	check("R for a clean run" in hud.practice_tag.text, "clearing custom message restores ordinary live wording")
	hud.show_finish(false, false)
	check("R starts a clean run" in hud._finish_result.text, "empty custom message retains ordinary practice finish result")
	game.select_map("plan-yard")
	game.player.set_physics_process(false)
	game.set_paused(true)
	hud._layout()
	await settle()
	check(hud.practice_button.text == "Practise checkpoint  F" and "Choose your line" in hud.practice_button.tooltip_text, "long checkpoint name moves to the action tooltip")
	check(is_equal_approx(hud.resume_button.get_global_rect().position.y, hud.quit_button.get_global_rect().position.y), "long checkpoint action row keeps Quit alongside Resume at720p")
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	var file := FileAccess.open(output.path_join("hud-hooks-checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks}, "\t"))
	file.close()
	print("HUD_HOOKS: ", ok, " count=", checks.size())
	game.request_quit(0)
	quit(0 if ok else 1)

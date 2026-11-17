extends SceneTree
## exercises the production menu without writing a player profile or any recordings.
var checks: Array = []
var output := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks.append({"ok": ok, "check": message})
	if not ok:
		push_error(message)

func settle() -> void:
	for i: int in 5:
		await process_frame

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node = load("res://scenes/r21.tscn").instantiate()
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
	game.set_paused(true)
	var hud: Node = game.hud
	check(hud.pause_pages.keys() == ["Maps", "Practice", "Settings", "Runs"], "four destinations")
	for key: String in ["source_sensitivity", "source_fov", "r13_sensitivity", "r13_fov", "volume"]:
		hud.show_pause_destination("Settings")
		hud._show_advanced(true)
		var slider: HSlider = hud.pause_panel.find_child("Setting_" + key, true, false)
		var number: Label = hud.pause_panel.find_child("Value_" + key, true, false)
		var reset: Button = hud.pause_panel.find_child("Reset_" + key, true, false)
		slider.value = slider.min_value
		check(is_equal_approx(float(game.settings[key]), slider.value), "slider applies " + key)
		check(number.text == hud.slider_value_text(key, slider.value), "slider number " + key)
		reset.pressed.emit()
		check(is_equal_approx(slider.value, float(game.DEFAULT_SETTINGS[key])), "slider reset " + key)
	for i: int in 5:
		var id := "menu-capacity-%d" % i
		var entry: Dictionary = game.map_entry("breakwater").duplicate(true)
		entry.name = "Additional map %d with a longer title" % i
		game.map_registry.catalog[id] = entry
		game.map_registry.order.append(id)
	hud._build_map_cards()
	check(hud.map_buttons.size() == game.map_ids().size(), "five additional maps represented")
	for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = viewport
		hud._layout()
		await settle()
		for destination: String in hud.pause_pages:
			hud.pause_tabs[destination].pressed.emit()
			if destination == "Runs":
				hud._show_share(true)
			await settle()
			check(hud.pause_destination == destination and hud.pause_pages[destination].visible, "navigate " + destination)
			var focusables: Array[Control] = []
			for node: Node in hud.pause_panel.find_children("*", "Control", true, false):
				if node is Control and node.is_visible_in_tree() and node.focus_mode == Control.FOCUS_ALL and not (node is BaseButton and node.disabled):
					focusables.append(node)
			var seen: Array[Control] = []
			var next: Control = hud.resume_button
			while next != null and next not in seen and seen.size() < 1000:
				seen.append(next)
				next = next.find_next_valid_focus()
			for control: Control in focusables:
				check(control in seen, "Tab reaches " + str(control.name))
				control.grab_focus()
				await settle()
				check(control.has_focus(), "focus " + str(control.name))
				var bounds := control.get_global_rect()
				if hud._pause_scroll.is_ancestor_of(control):
					var scroll_bounds: Rect2 = hud._pause_scroll.get_global_rect()
					check(bounds.position.y >= scroll_bounds.position.y - 1 and bounds.end.y <= scroll_bounds.end.y + 1, "focus scrolls into view " + str(control.name))
				var side: Rect2 = hud._pause_side.get_global_rect()
				check(bounds.position.x >= side.position.x - 1 and bounds.end.x <= side.end.x + 1, "horizontal fit " + str(control.name) + " at " + str(viewport))
			var header: Rect2 = hud.pause_header.get_global_rect()
			check(header.end.y < viewport.y - 80, "header leaves usable scroll space " + str(viewport))
	hud.set_telemetry(true)
	hud._layout()
	await settle()
	check(hud.pause_header.get_global_rect().end.y < root.size.y - 80, "telemetry header fits at 720p")
	hud.set_telemetry(false)
	game.select_map("experiment")
	game.set_paused(true)
	hud.show_pause_destination("Practice")
	await settle()
	check(hud.lab_box.is_visible_in_tree(), "lab controls in Practice")
	check(not "not recorded" in hud.practice_note.text, "practice recording copy agrees")
	var card: Button = hud.map_buttons["experiment"]
	check(card.text.count("not a course") == 1, "lab classification appears once")
	game.map_registry.catalog["tether-yard"]["tether_model"] = "elastic-arc"
	game.select_map("tether-yard")
	game.set_paused(true)
	hud.show_pause_destination("Practice")
	await settle()
	check(hud.tether_section.is_visible_in_tree(), "rope controls in Practice")
	check(hud.tether_models.size() == 6, "all six rope laws reachable")
	check(hud.tether_models.values().all(func(button: Button) -> bool: return button.disabled), "fixed-law map locks model selection")
	check(hud.tether_models["elastic-arc"].button_pressed, "fixed-law map shows effective model")
	check(not hud.anchor_assist_switch.disabled, "assist uses effective map law")
	check(hud.feedback_switches.size() == 7, "all swing feedback toggles represented")
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	var file := FileAccess.open(output.path_join("menu-checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks}, "\t"))
	file.close()
	print("pause menu checks: ", ok, " count=", checks.size())
	game.request_quit(0)
	quit(0 if ok else 1)

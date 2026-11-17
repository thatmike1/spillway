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

func click(control: Control, scroll: ScrollContainer = null) -> void:
	await settle()
	if scroll != null:
		scroll.ensure_control_visible(control)
	await settle()
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	check(root.gui_get_hovered_control() == control, "mouse reaches " + str(control.name))
	for down: bool in [true, false]:
		var button := InputEventMouseButton.new()
		button.position = point
		button.global_position = point
		button.button_index = MOUSE_BUTTON_LEFT
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		button.pressed = down
		root.push_input(button, true)
		await process_frame
	await settle()

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
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
	check("Current map" in hud.pause_kicker.text, "paused heading identifies current map")
	check("Recording is off" in hud.practice_note.text, "practice explains disabled recording")
	check(hud.pause_panel.find_child("RunExportPlayerLabel", true, false) != null, "run export player field has a persistent purpose label")
	check(hud.pause_panel.find_child("GhostPlayerNameLabel", true, false) != null, "ghost export player field has a persistent purpose label")
	check("No compatible racing ghost" in hud.share_selection.text and not "Racing your local best" in hud.share_selection.text, "empty ghost library does not claim an active local best")
	check(hud.tether_history_text("Arc\nLMB attached\nReleased · coast", "Released · coast") == "Arc\nLMB attached\nRecent: Released · coast", "release history is distinct from current attachment")
	for key: String in ["source_sensitivity", "source_fov", "r13_sensitivity", "r13_fov", "volume"]:
		hud.show_pause_destination("Settings")
		hud._show_advanced(true)
		var slider: HSlider = hud.pause_panel.find_child("Setting_" + key, true, false)
		var number: Label = hud.pause_panel.find_child("Value_" + key, true, false)
		var reset: Button = hud.pause_panel.find_child("Reset_" + key, true, false)
		slider.value = slider.min_value
		check(is_equal_approx(float(game.settings[key]), slider.value), "slider applies " + key)
		check(number.text == hud.slider_value_text(key, slider.value), "slider number " + key)
		await click(reset, hud._pause_scroll)
		check(is_equal_approx(slider.value, float(game.DEFAULT_SETTINGS[key])), "slider reset " + key)
	var preview_data: Script = preload("res://scripts/ui/map_previews.gd")
	for id: String in game.map_ids():
		check(preview_data.FRAMES.has(id) and preview_data.FRAMES[id] is Texture2D, "captured preview exists " + id)
	var initial_map_count := int(game.map_ids().size())
	for i: int in 5:
		var id := "menu-capacity-%d" % i
		var entry: Dictionary = game.map_entry("breakwater").duplicate(true)
		entry.name = "Additional map %d with a longer title" % i
		entry.kind = "course" if i == 0 else "experiment"
		game.maps.catalog[id] = entry
		game.maps.order.append(id)
	hud._build_map_cards()
	check(hud.map_buttons.size() == initial_map_count + 5 and game.map_ids().size() == initial_map_count + 5, "five additional maps represented")
	check(hud.map_note.text.begins_with(str(game.map_ids().size()) + " maps."), "Maps count includes experiments")
	for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = viewport
		hud._layout()
		await settle()
		for destination: String in hud.pause_pages:
			if viewport == Vector2i(1280, 720):
				await click(hud.pause_tabs[destination])
			else:
				hud.pause_tabs[destination].pressed.emit()
			if destination == "Runs":
				hud._show_share(true)
			await settle()
			check(hud.pause_destination == destination and hud.pause_pages[destination].visible, "navigate " + destination)
			check(hud.map_preview.visible == (destination == "Maps"), "preview belongs only to Maps " + destination)
			if destination == "Maps":
				check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(hud.map_preview.get_global_rect()), "preview fits viewport " + str(viewport))
			if destination == "Settings":
				var viewport_bounds: Rect2 = hud._pause_scroll.get_global_rect()
				for key: String in ["source_sensitivity", "source_fov", "volume"]:
					var reset: Control = hud.pause_panel.find_child("Reset_" + key, true, false)
					check(viewport_bounds.encloses(reset.get_global_rect()), "common adjustment visible on Settings landing " + key)
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
				if str(control.name).begins_with("Map_"):
					var id := str(control.name).trim_prefix("Map_")
					check(hud.map_preview.selected_id == id, "focus updates map preview " + id)
					if preview_data.FRAMES.has(id):
						check(hud.map_preview.image.texture == preview_data.FRAMES[id], "focus shows its own captured frame " + id)
					hud.map_preview.show_map("", {})
					for point: Vector2 in [Vector2(-10, -10), control.get_global_rect().get_center()]:
						var motion := InputEventMouseMotion.new()
						motion.position = point
						motion.global_position = point
						root.push_input(motion, true)
						await process_frame
					check(hud.map_preview.selected_id == id, "mouse hover updates map preview " + id)
					if preview_data.FRAMES.has(id):
						check(hud.map_preview.image.texture == preview_data.FRAMES[id], "hover shows its own captured frame " + id)
					else:
						check(hud.map_preview.image.texture == null and "unavailable" in hud.map_preview.caption.text, "missing map has honest preview fallback " + id)
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
	check(card.text.to_lower().count("not a course") == 1, "lab classification appears once")
	for id: String in hud.lab_switches:
		var toggle: CheckButton = hud.lab_switches[id]
		toggle.button_pressed = false
		check(not bool(game.lab_moves().get(id, true)), "lab switch disables " + id)
		toggle.button_pressed = true
		check(bool(game.lab_moves().get(id, false)), "lab switch enables " + id)
	game.select_map("tether-yard")
	game.set_paused(true)
	for model: String in hud.tether_models:
		var button: Button = hud.tether_models[model]
		if not button.disabled:
			button.pressed.emit()
		await settle()
		check(game.tether_model() == model and game.paused, "rope choice applies while paused " + model)
	hud.reel_automatic.pressed.emit()
	check(bool(game.settings.tether_auto_reel) and game.paused, "automatic reel applies while paused")
	hud.reel_manual.pressed.emit()
	check(not bool(game.settings.tether_auto_reel) and game.paused, "manual reel applies while paused")
	game.select_map("breakwater")
	game.maps.catalog["tether-yard"]["tether_model"] = "elastic-arc"
	game.select_map("tether-yard")
	game.set_paused(true)
	hud.show_pause_destination("Practice")
	await settle()
	check(hud.tether_section.is_visible_in_tree(), "rope controls in Practice")
	check("LMB" in hud.controls.text and hud.controls.text.split("\n").size() <= 2, "grapple teaching stays compact")
	check(hud.tether_models.size() == 6, "all six rope laws reachable")
	check(hud.tether_models.values().all(func(button: Button) -> bool: return button.disabled), "fixed-law map locks model selection")
	check(hud.tether_models["elastic-arc"].button_pressed, "fixed-law map shows effective model")
	check(not hud.anchor_assist_switch.disabled, "assist uses effective map law")
	check(hud.feedback_switches.size() == 7, "all swing feedback toggles represented")
	if game.settings.has("tether_rope_visual"):
		var identity: Dictionary = game.motion_identity().duplicate(true)
		var attempts := int(game.attempts)
		for key: String in hud.feedback_switches:
			var toggle: CheckButton = hud.feedback_switches[key]
			toggle.button_pressed = true
			check(bool(game.settings.get(key, false)), "feedback toggle applies " + key)
			toggle.button_pressed = false
			check(game.motion_identity() == identity and int(game.attempts) == attempts, "feedback keeps attempt and identity " + key)
	if ResourceLoader.exists("res://scripts/ui/run_review.gd"):
		hud.show_pause_destination("Runs")
		hud.review_button.pressed.emit()
		await settle()
		check(hud.review_screen != null and hud.review_screen.is_visible_in_tree() and game.paused, "review opens while game stays paused")
		var attempt_before_review := int(game.attempts)
		var restart_key := InputEventKey.new()
		restart_key.keycode = KEY_R
		restart_key.physical_keycode = KEY_R
		restart_key.pressed = true
		Input.parse_input_event(restart_key)
		await settle()
		restart_key = InputEventKey.new()
		restart_key.keycode = KEY_R
		restart_key.physical_keycode = KEY_R
		Input.parse_input_event(restart_key)
		check(int(game.attempts) == attempt_before_review and game.paused, "review blocks gameplay restart input")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.physical_keycode = KEY_ESCAPE
		escape.pressed = true
		Input.parse_input_event(escape)
		await settle()
		escape = InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.physical_keycode = KEY_ESCAPE
		Input.parse_input_event(escape)
		check(hud.review_screen == null and game.paused and hud.review_button.has_focus() and game.is_processing_input(), "Escape returns from review to paused menu with focus")
	for id: String in game.map_ids():
		if not bool(game.map_entry(id).get("mail_delivery", false)):
			continue
		game.select_map(id)
		game.set_paused(true)
		hud.show_pause_destination("Practice")
		await settle()
		check(hud.mail_section.is_visible_in_tree(), "mail controls appear on delivery map")
		check(is_zero_approx(hud.controls.modulate.a) and is_zero_approx(hud.keys_line.modulate.a), "mail view suppresses generic teaching")
		for choice: String in hud.mail_groups:
			var group: Dictionary = hud.mail_groups[choice]
			if not game.player.has_method(group.getter):
				continue
			check(game.player.has_method(group.setter) and (group.section as Control).is_visible_in_tree(), "delivery group visible " + choice)
			var choices: Array = group.buttons.keys()
			choices.reverse()
			for value: String in choices:
				var target: Button = group.buttons[value]
				var seen: Array[Control] = []
				var next: Control = hud.resume_button
				while next != null and next not in seen and seen.size() < 1000:
					seen.append(next)
					next = next.find_next_valid_focus()
				check(target in seen, "Tab reaches delivery choice " + choice + "/" + value)
				var before_identity: Dictionary = game.motion_identity().duplicate(true)
				var before_value := str(game.player.call(group.getter))
				var button: Button = group.buttons[value]
				button.grab_focus()
				await settle()
				check(button.has_focus(), "delivery choice accepts focus " + choice + "/" + value)
				if before_value != value:
					await click(button, hud._pause_scroll)
				await settle()
				check(str(game.player.call(group.getter)) == value, "delivery choice applies " + choice + "/" + value)
				check(game.paused, "delivery choice keeps menu paused " + choice)
				if choice == "goal":
					var optional := value == "optional"
					check(("Mail is optional; reach Dispatch to finish." in hud.map_controls.text) == optional and ("Deliver all three before Dispatch." in hud.map_controls.text) != optional, "delivery instructions match goal " + value)
				if before_value != value:
					check(game.motion_identity() != before_identity, "delivery choice separates recording identity " + choice)
		for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 720)]:
			root.size = viewport
			hud._layout()
			hud.show_pause_destination("Practice")
			await settle()
			var scroll: ScrollContainer = hud._pause_scroll
			var point := scroll.get_global_rect().get_center()
			var motion := InputEventMouseMotion.new()
			motion.position = point
			motion.global_position = point
			root.push_input(motion, true)
			await process_frame
			for i: int in 30:
				for down: bool in [true, false]:
					var wheel := InputEventMouseButton.new()
					wheel.position = point
					wheel.global_position = point
					wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
					wheel.pressed = down
					root.push_input(wheel, true)
				await process_frame
			await settle()
			var overflow := scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page
			check(not overflow or scroll.scroll_vertical > 0, "mouse wheel handles Mail overflow at " + str(viewport))
			var goal: Button = hud.mail_groups["goal"].buttons["optional"]
			check(scroll.get_global_rect().encloses(goal.get_global_rect()), "mouse wheel reaches last Mail choice at " + str(viewport))
			for group: Dictionary in hud.mail_groups.values():
				for button: Button in group.buttons.values():
					button.grab_focus()
					await settle()
					check(button.has_focus() and scroll.get_global_rect().encloses(button.get_global_rect()), "Mail choice fits after focus/resize " + str(button.name) + " " + str(viewport))
	game.session.recorder.enabled = true
	hud._refresh_pause()
	check("are recorded" in hud.practice_note.text, "practice explains enabled recording")
	hud.practice_started("copy check")
	check("recorded, no best" in hud.message.text, "practice notification agrees with enabled recording")
	game.session.recorder.enabled = false
	hud._refresh_pause()
	hud.practice_started("copy check")
	check("Recording is off" in hud.practice_note.text and "recording off, no best" in hud.message.text, "practice notification and instructions agree with disabled recording")
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	var file := FileAccess.open(output.path_join("menu-checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks}, "\t"))
	file.close()
	print("pause menu checks: ", ok, " count=", checks.size())
	game.request_quit(0)
	quit(0 if ok else 1)

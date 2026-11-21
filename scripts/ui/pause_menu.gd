extends "res://scripts/r20_hud.gd"
## r21 adds tuning controls and displays the runner's authoritative prospective anchor.
const MAP_PREVIEW := preload("res://scripts/ui/map_preview.gd")
const RUN_REVIEW_PRACTICE := preload("res://scripts/recordings/run_review_practice.gd")
const RUN_REVIEW := preload("res://scripts/ui/run_review.gd")
const MAP_PLACES := preload("res://scripts/ui/menu/map_places.gd")
const MAP_CARDS := preload("res://scripts/ui/menu/map_cards.gd")
const TITLE := preload("res://scripts/ui/menu/title_card.gd")
const R21_TUNING_NOTES := {
	"elastic-soft": "Soft catch · less outward damping; more room to swing.",
	"elastic-firm": "Firm line · a firmer spring when the line stretches.",
	"elastic-arc": "Long arc · slower reel; keeps a longer swinging line."}
var anchor_assist_switch: CheckButton
var anchor_readout: Label
var displayed_anchor: Dictionary = {}
var map_preview: PanelContainer
var pause_header: VBoxContainer
var mail_section: VBoxContainer
var mail_views := {}
var mail_groups := {}
var feedback_switches := {}
var review_practice_status: Label
var review_button: Button
var review_screen: Control
var review_host_input := true
var map_controls: Label
var swing_heading: Label
var swing_note: Label
var swing_grid: GridContainer
var map_bests := {}
var _group_notes := {}

func attach(main: Node) -> void:
	super(main)
	map_controls = _small(pause_pages["Practice"], "")
	map_controls.name = "CurrentMapInstructions"
	pause_pages["Practice"].move_child(map_controls, 0)
	_heading(tether_section, "Elastic tuning")
	for id: String in R21_TUNING_NOTES:
		var button := _button(tether_section, R21_TUNING_NOTES[id], _choose_model.bind(id))
		button.name = "TetherModel_" + id
		button.toggle_mode = true
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tether_models[id] = button
	anchor_assist_switch = CheckButton.new()
	anchor_assist_switch.name = "TetherAnchorAssist"
	anchor_assist_switch.text = "Anchor assist for Elastic ropes"
	anchor_assist_switch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	anchor_assist_switch.toggled.connect(func(on: bool) -> void: game.change_setting("tether_anchor_assist", on))
	tether_section.add_child(anchor_assist_switch)
	_small(tether_section, "Wider in-view acquisition. Switch off to compare the original aim. Classic and Pendulum keep their original aim.")
	tether_note.text = "Changing model, reel or assist restarts the attempt. Release mouse buttons after the menu; a fresh LMB press arms the line. Classic: 3 s. Others: 5 s. LMB release coasts; RMB reels."
	anchor_readout = Label.new()
	anchor_readout.name = "TetherProspectiveAnchor"
	anchor_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.ticket(anchor_readout, "small", 13, SIDE_BOTTOM, 0.9)
	overlay.add_child(anchor_readout)
	anchor_readout.hide()
	_attach_mail_preferences()
	_attach_feedback_preferences()
	review_button = _button(pause_pages["Runs"], "Review local runs", _open_run_review)
	review_button.name = "ReviewLocalRuns"
	pause_pages["Runs"].move_child(review_button, 0)
	review_button.tooltip_text = "Read recorded attempts, compare splits and scrub the speed trace."
	review_practice_status = _small(pause_pages["Runs"], "")
	review_practice_status.name = "ReviewPracticeStatus"
	pause_pages["Runs"].move_child(review_practice_status, 1)
	review_practice_status.hide()
	_pin_pause_header()
	map_preview = MAP_PREVIEW.new()
	map_preview.name = "MapPreview"
	map_preview.details = _place_details
	pause_panel.add_child(map_preview)
	_restyle_header()
	_plain_rope_names()
	_section_runs()
	_attach_motion_settings()
	_restyle_settings()
	_settle_look_line()
	if title_card != null and _title_mark != null:
		TITLE.restyle(title_card, _title_mark)
	_read_map_bests()
	_arrange_map_groups()
	_wire_map_previews()
	map_preview.show_map(str(game.map_id), game.map_entry())
	map_preview.visible = pause_destination == "Maps"
	_layout_pause(get_viewport().get_visible_rect().size)
	_refresh_tether()

func _wire_map_previews() -> void:
	if map_preview == null:
		return
	for id: String in map_buttons:
		var button: Button = map_buttons[id]
		if button.has_meta("preview_connected"):
			continue
		button.set_meta("preview_connected", true)
		var show_view: Callable = map_preview.show_map.bind(id, game.map_entry(id))
		button.mouse_entered.connect(show_view)
		button.focus_entered.connect(show_view)

func _build_map_cards() -> void:
	# a catalog change rebuilds every card; r15 and r19 clear their own grids, this clears the swing one.
	if swing_grid != null and game != null and game.call("map_ids") != _map_ids:
		for child: Node in swing_grid.get_children():
			swing_grid.remove_child(child)
			child.queue_free()
	super()
	_arrange_map_groups()
	_wire_map_previews()

# --- map select: places in three groups --------------------------------------------------------

func _place_details(id: String) -> Dictionary:
	var best := float(map_bests.get(id, -1.0))
	return {"group": MAP_PLACES.group(id, game.map_entry(id), _capabilities(id)), "best": "Best  " + _time(best) if best > 0.0 else "",
		"current": id == str(game.map_id)}

func _capabilities(id: String) -> Dictionary:
	return game.call("_catalog_capabilities").get(id, {}) if game.has_method("_catalog_capabilities") else {}

## clean bests for every map with the current preset, read from the saved profile without
## writing it. the current map always shows the host's own best for its exact identity.
func _read_map_bests() -> void:
	map_bests.clear()
	if game == null:
		return
	var config := ConfigFile.new()
	if bool(game.get("persist")) and config.load(str(game.get("profile_path"))) == OK:
		for section: String in config.get_sections():
			if not section.begins_with("course_") or str(config.get_value(section, "preset", "")) != str(game.preset_id):
				continue
			var best := float(config.get_value(section, "clean_best", -1.0))
			var id := str(config.get_value(section, "map", ""))
			if best > 0.0 and (not map_bests.has(id) or best < float(map_bests[id])):
				map_bests[id] = best
	map_bests.erase(str(game.map_id))
	if float(game.best_time) > 0.0:
		map_bests[str(game.map_id)] = float(game.best_time)

func _arrange_map_groups() -> void:
	var page: VBoxContainer = pause_pages.get("Maps")
	if page == null or map_grid == null or experiments_grid == null or game == null:
		return
	if swing_grid == null:
		swing_heading = _heading(page, MAP_PLACES.GROUP_TITLES.swing)
		swing_heading.name = "SwingHeading"
		swing_note = _small(page, MAP_PLACES.GROUP_NOTES.swing)
		swing_note.name = "SwingNote"
		swing_grid = GridContainer.new()
		swing_grid.name = "SwingGrid"
		swing_grid.add_theme_constant_override("h_separation", CARD_GAP)
		swing_grid.add_theme_constant_override("v_separation", CARD_GAP)
		page.add_child(swing_grid)
		_group_notes["bhop"] = _small(page, MAP_PLACES.GROUP_NOTES.bhop)
		_group_notes["bhop"].name = "BhopNote"
		for heading: Label in [map_heading, swing_heading, experiments_heading]:
			heading.add_theme_font_size_override("font_size", UI.TYPE_H2)
			heading.add_theme_constant_override("line_spacing", 0)
	var order: Array = [map_note, map_heading, _group_notes.get("bhop"), map_grid, swing_heading, swing_note, swing_grid, experiments_heading, experiments_note, experiments_grid]
	var index := 0
	for node: Variant in order:
		if node != null and (node as Node).get_parent() == page:
			page.move_child(node, index)
			index += 1
	map_heading.text = MAP_PLACES.GROUP_TITLES.bhop
	experiments_heading.text = MAP_PLACES.GROUP_TITLES.experiment
	var grids := {"bhop": map_grid, "swing": swing_grid, "experiment": experiments_grid}
	var counts := {"bhop": 0, "swing": 0, "experiment": 0}
	for id: String in game.call("map_ids"):
		if not map_buttons.has(id):
			continue
		var button: Button = map_buttons[id]
		var entry: Dictionary = game.map_entry(id)
		var group := MAP_PLACES.group(id, entry, _capabilities(id))
		var grid: GridContainer = grids[group]
		if button.get_parent() != grid:
			button.reparent(grid)
		grid.move_child(button, counts[group])
		counts[group] += 1
		var best := float(map_bests.get(id, -1.0))
		MAP_CARDS.dress(button, id, str(entry.get("name", id)), MAP_PLACES.line(id, entry), _time(best) if best > 0.0 else "", MAP_PLACES.note(id))
	for group: String in grids:
		var present: bool = counts[group] > 0
		(grids[group] as Control).visible = present
	swing_heading.visible = counts.swing > 0
	swing_note.visible = counts.swing > 0
	experiments_heading.visible = counts.experiment > 0
	experiments_note.visible = counts.experiment > 0
	swing_grid.columns = map_grid.columns
	experiments_grid.columns = map_grid.columns
	# room under the last row so its focus outline is never cut by the scroll edge.
	var tail := page.get_node_or_null("MapsTail")
	if tail == null:
		tail = Control.new()
		tail.name = "MapsTail"
		(tail as Control).custom_minimum_size.y = UI.SPACE_L
		(tail as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(tail)
	page.move_child(tail, page.get_child_count() - 1)

func _refresh_map_note() -> void:
	if map_note != null:
		map_note.text = "%d maps. Hover or focus a place to see it; click it or press Enter to start at its spawn with your preset." % map_buttons.size()

func _paint_map_cards() -> void:
	for id: String in map_buttons:
		MAP_CARDS.paint(map_buttons[id])

# --- header: actions, then the four destinations as tabs ---------------------------------------

func _restyle_header() -> void:
	UI.kicker(pause_kicker)
	var plain := UI.flat(Color(0, 0, 0, 0), UI.RADIUS, Vector4(UI.SPACE_M, UI.SPACE_S, UI.SPACE_M, UI.SPACE_S + 1))
	plain.border_color = Color(UI.INK, 0.0)
	plain.border_width_bottom = UI.EDGE_WIDTH
	var hover := plain.duplicate() as StyleBoxFlat
	hover.bg_color = UI.INK_WASH
	var chosen := plain.duplicate() as StyleBoxFlat
	chosen.border_color = UI.VERMILION
	for tab: Button in pause_tabs.values():
		tab.add_theme_font_override("font", UI.font("title"))
		tab.add_theme_font_size_override("font_size", UI.TYPE_H3)
		tab.add_theme_stylebox_override("normal", plain)
		tab.add_theme_stylebox_override("hover", hover)
		tab.add_theme_stylebox_override("pressed", chosen)
		tab.add_theme_stylebox_override("hover_pressed", chosen)
		for key: String in ["font_color", "font_hover_color", "font_focus_color"]:
			tab.add_theme_color_override(key, UI.INK_SOFT)
		for key: String in ["font_pressed_color", "font_hover_pressed_color"]:
			tab.add_theme_color_override(key, UI.INK)
	var bar := tab_bar()
	if bar != null and bar.get_parent() != null and bar.get_parent().get_node_or_null("PauseTabRule") == null:
		var rule := ColorRect.new()
		rule.name = "PauseTabRule"
		rule.color = UI.PALE_SHADE
		rule.custom_minimum_size = Vector2(0, UI.HAIRLINE)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.get_parent().add_child(rule)
		bar.get_parent().move_child(rule, bar.get_index() + 1)
	if current_map_button != null:
		current_map_button.flat = true
		current_map_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		current_map_button.add_theme_font_size_override("font_size", UI.TYPE_BODY - 1)
		current_map_button.add_theme_color_override("font_color", UI.SLATE)
		current_map_button.add_theme_color_override("font_hover_color", UI.INK)
		current_map_button.add_theme_color_override("font_focus_color", UI.INK)
		current_map_button.text = "Current map controls  →"

func _layout_title(size: Vector2, frame: Rect2) -> void:
	if _title_mark != null and title_card.has_node("ScrimLow"):
		if game != null:
			var id := str(game.map_id)
			(title_card.get_node("TitleMap") as Label).text = "%s  ·  %s" % [str(game.call("map_name")), MAP_PLACES.line(id, game.map_entry(id))]
		TITLE.layout(title_card, _title_mark, size, frame)
	else:
		super(size, frame)

## settings: each slider is one aligned row, its value in ink at a fixed width beside it and a
## quiet reset after; section names are the larger heading size.
func _restyle_settings() -> void:
	var page: Control = pause_pages.get("Settings")
	if page == null:
		return
	for node: Node in page.find_children("Value_*", "Label", true, false):
		var value := node as Label
		UI.text(value, "smallnum", UI.TYPE_LABEL, UI.INK)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size.x = 58
		var row := value.get_parent() as HBoxContainer
		row.add_theme_constant_override("separation", UI.SPACE_M)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		var caption := row.get_parent().get_child(row.get_index() - 1) as Label
		if caption != null:
			UI.text(caption, "label", UI.TYPE_BODY, UI.INK)
			caption.text = PLAIN_SETTING_NAMES.get(str(value.name).trim_prefix("Value_"), caption.text)
	for node: Node in page.find_children("Reset_*", "Button", true, false):
		var reset := node as Button
		reset.flat = true
		reset.add_theme_font_override("font", UI.font("label"))
		reset.add_theme_font_size_override("font_size", UI.TYPE_SMALL + 1)
		reset.add_theme_color_override("font_color", UI.SLATE)
		reset.add_theme_color_override("font_hover_color", UI.INK)
		reset.add_theme_color_override("font_focus_color", UI.INK)
	# comparison presets keep their full description on hover; the sheet shows two lines.
	for node: Node in page.find_children("PresetDetails_*", "Label", true, false):
		var details := node as Label
		if details.get_parent() != null and details.get_parent().name == "AdvancedPresets":
			details.tooltip_text = details.text
			details.mouse_filter = Control.MOUSE_FILTER_PASS
			details.max_lines_visible = 2
			details.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for node: Node in page.find_children("*", "Label", true, false):
		var label := node as Label
		if label.get_theme_font_size("font_size") == 17 and label.text in ["Look and sound", "Movement", "Keys"]:
			label.add_theme_font_size_override("font_size", UI.TYPE_H2)

## the Runs page in three named parts: your recordings, the racing ghost, sharing and export.
func _section_runs() -> void:
	var page: Control = pause_pages.get("Runs")
	if page == null or page.get_node_or_null("RunsHeading_recordings") != null:
		return
	for part: Array in [["recordings", "Your recordings", review_button], ["ghost", "Racing ghost", ghost_switch],
			["share", "Share and export", page.get_node_or_null("GhostSharingToggle")]]:
		var anchor: Control = part[2]
		if anchor == null or anchor.get_parent() != page:
			continue
		var heading := _heading(page, str(part[1]))
		heading.name = "RunsHeading_" + str(part[0])
		heading.add_theme_font_size_override("font_size", UI.TYPE_H2)
		page.move_child(heading, anchor.get_index())

## how each rope law feels, in words for the player; the laws themselves are unchanged.
const ROPE_FEEL := {
	"classic": "Classic · springy, catches at full length",
	"pendulum": "Pendulum · fixed and taut, no spring",
	"elastic": "Elastic · stretchy, stronger pull",
	"elastic-soft": "Soft catch · stretchy and loose",
	"elastic-firm": "Firm line · stretchy, snaps back hard",
	"elastic-arc": "Long arc · slow reel, long swing"}

## the longer story of each law, kept for the hover tip.
const ROPE_ABOUT := {
	"classic": "A springy line that catches you at full length. The original rope.",
	"pendulum": "A fixed rope that goes taut. No spring and no speed cap.",
	"elastic": "Stretchy, with slack and a stronger pull.",
	"elastic-soft": "Stretchy and loose, with more room to swing.",
	"elastic-firm": "Stretchy, but it snaps back harder.",
	"elastic-arc": "A slower reel that keeps a long swinging line."}

func _plain_rope_names() -> void:
	for id: String in tether_models:
		if ROPE_FEEL.has(id):
			var rope := tether_models[id] as Button
			rope.text = ROPE_FEEL[id]
			rope.tooltip_text = ROPE_ABOUT[id]

## plain names for the sliders; the Source arithmetic stays in the line under them.
const PLAIN_SETTING_NAMES := {"source_sensitivity": "Mouse sensitivity (Source scale)", "source_fov": "Field of view (4:3 reference, widened to fit)",
	"r13_sensitivity": "R13 mouse (F3 only)", "r13_fov": "R13 horizontal field of view (F3 only)", "volume": "Volume"}

## the current map's controls as short lines on a quiet panel, without capitals shouting.
func _plain_map_controls() -> void:
	if map_controls == null:
		return
	var lines: Array[String] = []
	for line: String in map_controls.text.split("\n", false):
		line = line.strip_edges()
		if line.begins_with("EXPERIMENTAL "):
			line = line.trim_prefix("EXPERIMENTAL ")
			line = line.left(1).to_upper() + line.substr(1)
		lines.append(line)
	map_controls.text = "\n".join(lines)
	if not map_controls.has_meta("plain"):
		map_controls.set_meta("plain", true)
		UI.text(map_controls, "body", UI.TYPE_BODY - 1, UI.INK)
		map_controls.add_theme_constant_override("line_spacing", 3)
		var panel := UI.flat(UI.PALE_DEEP, UI.RADIUS, Vector4(UI.SPACE_M + 3, UI.SPACE_S + 2, UI.SPACE_M, UI.SPACE_S + 3))
		panel.border_color = UI.SLATE
		panel.border_width_left = UI.EDGE_WIDTH
		map_controls.add_theme_stylebox_override("normal", panel)

## lane 05's presentation-only motion effects, shown once the host knows their settings.
const MOTION_SWITCHES := {"motion_fx_fov": "Speed widens the view (up to about +5°)", "motion_fx_streaks": "Edge speed lines",
	"motion_fx_wind": "Wind flecks", "motion_fx_moments": "Landing, checkpoint and best-time cues"}
var motion_section: VBoxContainer
var motion_rows := {}

func _attach_motion_settings() -> void:
	var page: Control = pause_pages.get("Settings")
	if page == null or not (game.get("settings") is Dictionary) or not (game.settings as Dictionary).has("motion_fx"):
		return
	motion_section = VBoxContainer.new()
	motion_section.name = "MotionEffects"
	motion_section.add_theme_constant_override("separation", 9)
	page.add_child(motion_section)
	var common := page.get_node_or_null("CommonSettings")
	page.move_child(motion_section, common.get_index() + 1 if common != null else 0)
	_heading(motion_section, "Motion effects")
	_small(motion_section, "Presentation only. These keep the current attempt and recording identity.")
	var main_switch := CheckButton.new()
	main_switch.name = "Setting_motion_fx"
	main_switch.text = "Motion effects"
	main_switch.button_pressed = bool(game.settings.get("motion_fx", true))
	main_switch.toggled.connect(func(on: bool) -> void:
		game.change_setting("motion_fx", on)
		_sync_motion_rows())
	motion_section.add_child(main_switch)
	var caption := Label.new()
	caption.text = "Intensity"
	motion_section.add_child(caption)
	var row := HBoxContainer.new()
	motion_section.add_child(row)
	var slider := HSlider.new()
	slider.name = "Setting_motion_fx_intensity"
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.1
	slider.value = float(game.settings.get("motion_fx_intensity", 0.6))
	slider.focus_mode = Control.FOCUS_ALL
	row.add_child(slider)
	var number := _small(row, "%d %%" % roundi(slider.value * 100.0))
	number.name = "Value_motion_fx_intensity"
	number.size_flags_horizontal = Control.SIZE_SHRINK_END
	slider.value_changed.connect(func(value: float) -> void:
		game.change_setting("motion_fx_intensity", value)
		number.text = "%d %%" % roundi(value * 100.0))
	var defaults: Dictionary = load("res://scripts/fx/motion_fx.gd").get("DEFAULTS") if ResourceLoader.exists("res://scripts/fx/motion_fx.gd") else {}
	var default_value := float(defaults.get("motion_fx_intensity", 0.6))
	var reset := _button(row, "Reset", func() -> void: slider.value = default_value)
	reset.name = "Reset_motion_fx_intensity"
	reset.tooltip_text = "Reset to %d %%" % roundi(default_value * 100.0)
	motion_rows["motion_fx_intensity"] = slider
	for key: String in MOTION_SWITCHES:
		var toggle := CheckButton.new()
		toggle.name = "Setting_" + key
		toggle.text = MOTION_SWITCHES[key]
		toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		toggle.button_pressed = bool(game.settings.get(key, true))
		toggle.toggled.connect(func(on: bool) -> void: game.change_setting(key, on))
		motion_section.add_child(toggle)
		motion_rows[key] = toggle
	_sync_motion_rows()

func _sync_motion_rows() -> void:
	if motion_section == null:
		return
	var on := bool(game.settings.get("motion_fx", true))
	(motion_section.get_node("Setting_motion_fx") as CheckButton).set_pressed_no_signal(on)
	for key: String in motion_rows:
		var control: Control = motion_rows[key]
		if control is CheckButton:
			(control as CheckButton).set_pressed_no_signal(bool(game.settings.get(key, true)))
			(control as CheckButton).disabled = not on
		elif control is HSlider:
			(control as HSlider).set_value_no_signal(float(game.settings.get(key, 0.6)))
			(control as HSlider).editable = on

## the sensitivity arithmetic is reference, not the first thing to read: it moves under the sliders.
func _settle_look_line() -> void:
	if not pause_pages.has("Settings") or pause_look == null:
		return
	var common: Node = (pause_pages["Settings"] as Node).get_node_or_null("CommonSettings")
	if common == null or pause_look.get_parent() != common:
		return
	common.move_child(pause_look, common.get_child_count() - 1)
	UI.text(pause_look, "body", UI.TYPE_SMALL, UI.INK_SOFT)

## the world behind map select steps further back so the chosen place reads first.
func _dim_for(destination: String) -> void:
	if pause_panel == null or pause_panel.get_child_count() == 0:
		return
	var dim := pause_panel.get_child(0) as ColorRect
	if dim != null:
		dim.color = Color(UI.SLATE_DEEP, 0.62 if destination == "Maps" else 0.42)

func tab_bar() -> Control:
	return pause_tabs["Maps"].get_parent() if pause_tabs.has("Maps") else null

func show_pause_destination(destination: String, focus_tab: bool = true) -> void:
	super(destination, focus_tab)
	_dim_for(destination)
	if map_preview != null:
		map_preview.visible = destination == "Maps"
		if destination == "Maps":
			map_preview.show_map(str(game.map_id), game.map_entry())

func _show_current_map_controls() -> void:
	show_pause_destination("Practice")
	var target: Control = map_controls
	if mail_section != null and mail_section.visible:
		target = mail_views["body"] if mail_views["envelope"].disabled else mail_views["envelope"]
	elif tether_section.visible:
		target = reel_automatic if reel_manual.disabled else reel_manual
	elif lab_box.visible:
		target = lab_switches["slide"]
	if target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()
	_pause_scroll.ensure_control_visible(target)

func _attach_mail_preferences() -> void:
	mail_section = VBoxContainer.new()
	mail_section.name = "MailPreferences"
	mail_section.add_theme_constant_override("separation", 8)
	pause_pages["Practice"].add_child(mail_section)
	_small(mail_section, "LMB throw · mouse steer · RMB recall. Changing a choice restarts the attempt with its own recording identity.")
	_add_mail_group("view", "Delivery view", "mail_view", "set_mail_view", {"envelope": "Envelope", "body": "Runner's eyes"})
	_add_mail_group("body", "Body while steering", "mail_body", "set_mail_body", {"hold": "Held", "run": "Keep running"})
	_add_mail_group("goal", "Dispatch goal", "mail_goal", "set_mail_goal", {"deliver": "Deliver all mail", "optional": "Optional mail"})
	mail_views = mail_groups["view"].buttons
	_refresh_mail()

func _add_mail_group(id: String, title: String, getter: String, setter: String, choices: Dictionary) -> void:
	var group := VBoxContainer.new()
	group.name = "MailChoice_" + id
	group.add_theme_constant_override("separation", 8)
	mail_section.add_child(group)
	_heading(group, title)
	var buttons := {}
	for value: String in choices:
		var button := _button(group, str(choices[value]), _set_mail_preference.bind(setter, value))
		button.name = "Mail_" + id + "_" + value
		buttons[value] = button
	mail_groups[id] = {"section": group, "getter": getter, "setter": setter, "buttons": buttons}

func _set_mail_preference(setter: String, value: String) -> void:
	if not is_instance_valid(game.player) or not game.player.has_method(setter):
		return
	var was_paused := bool(game.paused)
	game.player.call(setter, value)
	game.set_paused(was_paused)
	_refresh_mail()

func _refresh_mail() -> void:
	if mail_section == null:
		return
	mail_section.visible = is_instance_valid(game.player) and game.player.has_method("mail_view")
	if not mail_section.visible:
		return
	var deliver: Button = mail_groups["goal"].buttons["deliver"]
	deliver.text = "Deliver all mail"
	if game.player.has_method("delivery_progress"):
		var progress: Vector2i = game.player.call("delivery_progress")
		deliver.text = "Deliver mail (%d required)" % progress.y if progress.y > 0 else "Reach Dispatch"
	for id: String in mail_groups:
		var group: Dictionary = mail_groups[id]
		var supported: bool = game.player.has_method(group.getter) and game.player.has_method(group.setter)
		(group.section as Control).visible = supported
		if supported:
			var selected := str(game.player.call(group.getter))
			for value: String in group.buttons:
				(group.buttons[value] as Button).disabled = selected == value
	_mark_current_choices()

func _attach_feedback_preferences() -> void:
	_heading(tether_section, "Swing feedback")
	_small(tether_section, "Presentation only. These switches keep the current attempt and recording identity.")
	var labels := {
		"tether_rope_visual": "Readable rope", "tether_attach_cue": "Attach flash and click",
		"tether_reel_audio": "Reel sound", "tether_tension_audio": "Rope tension sound",
		"tether_wind_audio": "Speed wind", "tether_speed_fov": "Small speed FOV (up to +3°)",
		"tether_anchor_readability": "Anchor ready marker"}
	for key: String in labels:
		var toggle := CheckButton.new()
		toggle.name = "Setting_" + key
		toggle.text = labels[key]
		toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		toggle.toggled.connect(func(on: bool) -> void: game.change_setting(key, on))
		tether_section.add_child(toggle)
		feedback_switches[key] = toggle

func _open_run_review() -> void:
	if review_screen != null:
		return
	review_practice_status.hide()
	review_host_input = game.is_processing_input()
	game.set_process_input(false)
	review_screen = RUN_REVIEW.new()
	review_screen.spatial_unavailable_reason = RUN_REVIEW_PRACTICE.unavailable_reason(game)
	if not str(game.session.directory).is_empty():
		review_screen.set("directory", str(game.session.directory))
	pause_panel.add_child(review_screen)
	review_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# the review is a sheet over the paused world, like the menu, not a page that replaces it.
	var inset := clampf(get_viewport().get_visible_rect().size.x * 0.018, 12.0, 40.0)
	review_screen.offset_left = inset
	review_screen.offset_top = inset
	review_screen.offset_right = -inset
	review_screen.offset_bottom = -inset
	if review_screen.has_method("attach_map"):
		review_screen.call("attach_map", game.level, game.motion_identity())
	review_screen.closed.connect(_close_run_review)
	review_screen.practice_requested.connect(_on_review_practice_requested)
	_pause_side.hide()
	_pause_edge.hide()

func _on_review_practice_requested(request: Dictionary) -> void:
	_close_run_review()
	var result: Dictionary = RUN_REVIEW_PRACTICE.start(game, request)
	if not result.ok:
		review_practice_status.text = str(result.error)
		review_practice_status.show()
		_pause_scroll.scroll_vertical = 0
		notify(str(result.error))

func _close_run_review() -> void:
	if review_screen != null:
		review_screen.queue_free()
		review_screen = null
		game.set_process_input(review_host_input)
	_pause_side.show()
	_pause_edge.show()
	review_button.grab_focus()

func set_paused(value: bool) -> void:
	super(value)
	# the title steps away at once when the menu opens, so its letters never show through the sheet.
	if value and title_card != null:
		_title_alpha = 0.0
		title_card.visible = false
	if value and map_preview != null and pause_destination == "Maps":
		map_preview.show_map(str(game.map_id), game.map_entry())
	if not value and review_screen != null:
		_close_run_review()

func _pin_pause_header() -> void:
	pause_header = VBoxContainer.new()
	pause_header.name = "PauseHeader"
	pause_header.add_theme_constant_override("separation", 9)
	_pause_side.add_child(pause_header)
	for child: Node in _pause_column.get_children():
		if child not in pause_pages.values():
			child.reparent(pause_header)
	_layout_pause(get_viewport().get_visible_rect().size)

func _layout_pause(size: Vector2) -> void:
	super(size)
	if pause_header == null:
		return
	pause_header.position = _pause_scroll.position
	pause_header.custom_minimum_size.x = _pause_scroll.size.x - 16.0
	pause_header.size = Vector2(pause_header.custom_minimum_size.x, 0)
	var header_height := pause_header.get_combined_minimum_size().y + 9.0
	_pause_scroll.position.y += header_height
	_pause_scroll.size.y = maxf(80.0, _pause_scroll.size.y - header_height)
	if map_preview != null:
		map_preview.arrange(size, _pause_side.get_global_rect())

func lab_controls_text() -> String:
	var instructions := super()
	if game != null and is_instance_valid(game.player) and game.player.has_method("mail_goal") and str(game.player.call("mail_goal")) == "optional":
		instructions = instructions.replace("Deliver all three before Dispatch.", "Mail is optional; reach Dispatch to finish.")
	return instructions

func _refresh_pause() -> void:
	_read_map_bests()
	super()
	pause_kicker.text = "Paused  ·  Current map  ·  F%d" % int(game.preset.get("slot", 0)) + ("  ·  Experiment" if bool(game.call("is_lab")) or bool(game.map_entry().get("experimental", false)) else "")
	_arrange_map_groups()
	_paint_map_cards()
	_sync_motion_rows()
	_refresh_mail()
	if map_controls != null:
		map_controls.text = str(game.preset.get("controls", "")) + "\n" + lab_controls_text() if game.is_lab() or game.is_experiment_map() else str(game.preset.get("controls", ""))
	_plain_map_controls()

func _refresh_tether() -> void:
	super()
	_refresh_mail()
	if anchor_assist_switch == null or game == null:
		return
	for key: String in feedback_switches:
		(feedback_switches[key] as CheckButton).set_pressed_no_signal(bool(game.settings.get(key, false)))
	anchor_assist_switch.set_pressed_no_signal(bool(game.settings.get("tether_anchor_assist", true)))
	anchor_assist_switch.disabled = game.tether_model() in ["classic", "pendulum"]
	_mark_current_choices()

## a choice that is disabled because it is already the current one reads as chosen (pale-deep
## with the vermilion lip and ink type), not as greyed out.
func _mark_current_choices() -> void:
	if game == null:
		return
	var current: Array[Button] = []
	if reel_manual != null:
		current.append(reel_automatic if bool(game.settings.get("tether_auto_reel", false)) else reel_manual)
	if tether_models.has(game.tether_model()):
		current.append(tether_models[game.tether_model()])
	for group: Dictionary in mail_groups.values():
		for button: Button in group.buttons.values():
			if button.disabled and button.is_visible_in_tree():
				current.append(button)
	var buttons: Array = [reel_manual, reel_automatic] + tether_models.values()
	for group: Dictionary in mail_groups.values():
		buttons.append_array(group.buttons.values())
	for button: Variant in buttons:
		if button == null:
			continue
		var choice := button as Button
		if choice in current:
			var chosen := UI.flat(UI.PALE_DEEP, UI.RADIUS, Vector4(12, 7, 12, 8))
			chosen.border_color = UI.VERMILION
			chosen.border_width_left = UI.EDGE_WIDTH
			choice.add_theme_stylebox_override("disabled", chosen)
			choice.add_theme_color_override("font_disabled_color", UI.INK)
		else:
			choice.remove_theme_stylebox_override("disabled")
			choice.remove_theme_color_override("font_disabled_color")

func _process(delta: float) -> void:
	super(delta)
	if game != null and game.map_has_capability("mail_delivery"):
		controls.modulate.a = 0.0
		hint.modulate.a = 0.0
		keys_line.modulate.a = 0.0
	elif game != null and game.map_has_capability("grapple"):
		controls.text = "LMB hold to swing · RMB reel · release to coast\nEsc map controls"
		keys_line.modulate.a = 0.0
	_refresh_anchor_readout()

func _lab_text() -> void:
	super()
	if game != null and game.map_has_capability("grapple") and is_instance_valid(game.player):
		var recent: Variant = game.player.get("release_notice")
		if recent is String:
			lab_panel.text = tether_history_text(lab_panel.text, recent)

static func tether_history_text(status: String, recent: String) -> String:
	return status.replace("\n" + recent, "\nRecent: " + recent) if not recent.is_empty() else status

func _run_text() -> String:
	var original := super()
	for child: Node in game.get_children():
		if child.get_meta("run_review_practice", false) and int(child.get("attempt")) == int(game.attempts) and not game.finished:
			var parts: Array = [] if original.is_empty() else Array(original.split("  ·  "))
			if not parts.is_empty() and (str(parts[0]).begins_with("ghost ") or str(parts[0]) == "no ghost yet" or str(parts[0]).begins_with("racing ")):
				parts.pop_front()
			parts.push_front("PB segment guide")
			return "  ·  ".join(parts)
	return original

func _refresh_anchor_readout() -> void:
	if anchor_readout == null:
		return
	displayed_anchor = {}
	anchor_readout.hide()
	if game == null or not game.map_has_capability("grapple") or game.paused or game.finished:
		return
	if not is_instance_valid(game.player) or not game.player.has_method("r21_acquisition_snapshot"):
		return
	var candidate: Dictionary = game.player.call("r21_acquisition_snapshot")
	if str(candidate.get("state", "none")) != "ok":
		return
	var name := str(candidate.get("name", ""))
	if name.is_empty():
		return
	var attached := bool(candidate.get("attached", false))
	if attached and "attempt restarted" in message.text and "release mouse buttons" in message.text:
		_message_time = 0.0
		message.modulate.a = 0.0
	if not attached and not bool(candidate.get("ready", false)):
		return
	anchor_readout.text = "%s: %s · %.1f m" % ["Attached" if attached else "Next", name, float(candidate.get("distance_m", 0.0))]
	anchor_readout.reset_size()
	var view := get_viewport().get_visible_rect().size
	anchor_readout.position = Vector2(32.0, maxf(120.0, view.y - 168.0)) if bool(game.map_entry().get("own_look", false)) else Vector2((view.x - anchor_readout.size.x) * 0.5, view.y * 0.5 + 24.0)
	anchor_readout.show()
	displayed_anchor = candidate.duplicate(true)

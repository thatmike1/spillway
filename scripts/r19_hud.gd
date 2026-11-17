extends "res://scripts/r18_hud.gd"
## the r18 sheet gains a scrolling, data-only ghost exchange section. base cards stay intact.

var share_section: VBoxContainer
var share_list: VBoxContainer
var share_name: LineEdit
var share_status: Label
var share_path: LineEdit
var share_selection: Label
var share_revision: Label
var share_toggle: Button
var experiments_heading: Label
var experiments_note: Label
var experiments_grid: GridContainer
var _list_signature := ""

func attach(main: Node) -> void:
	super(main)
	share_toggle = _button(pause_pages["Runs"], "", func() -> void: _show_share(not share_section.visible))
	share_toggle.name = "GhostSharingToggle"
	share_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT

	share_selection = _small(pause_pages["Runs"], "")

	share_revision = _small(pause_pages["Runs"], "")

	share_section = VBoxContainer.new()
	share_section.name = "GhostSharing"
	share_section.add_theme_constant_override("separation", 8)
	pause_pages["Runs"].add_child(share_section)

	_small(share_section, "Send one best-run file. Your friend drops it in their ghosts folder, then opens Esc or presses Refresh. Nothing is uploaded.")
	share_path = LineEdit.new()
	share_path.name = "GhostFolderPath"
	share_path.editable = false
	share_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share_path.add_theme_font_override("font", UI.font("body"))
	share_path.add_theme_font_size_override("font_size", 12)
	share_path.add_theme_color_override("font_uneditable_color", UI.INK_SOFT)
	share_path.add_theme_stylebox_override("read_only", UI.flat(Color(UI.INK, 0.04), 2, Vector4(8, 6, 8, 6)))
	share_path.text = str(game.ghost_share.folder)
	share_path.tooltip_text = "Ghosts folder: select and copy this path if opening the folder fails."
	share_section.add_child(share_path)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	share_section.add_child(actions)
	_button(actions, "Open ghosts folder", func() -> void:
		game.ghost_share.open_folder()
		_refresh_share()).name = "OpenGhostFolder"
	_button(actions, "Refresh", func() -> void:
		game.ghost_share.scan()
		_list_signature = ""
		_refresh_share()).name = "RefreshGhosts"
	share_name = LineEdit.new()
	share_name.name = "GhostPlayerName"
	share_name.placeholder_text = "Your player name"
	share_name.max_length = 32
	share_name.text = str(game.ghost_share.player_name)
	share_name.add_theme_font_override("font", UI.font("body"))
	share_name.add_theme_font_size_override("font_size", 14)
	share_name.add_theme_color_override("font_color", UI.INK)
	share_name.add_theme_color_override("caret_color", UI.INK)
	share_name.add_theme_color_override("selection_color", Color(UI.EDGE, 0.35))
	share_name.add_theme_color_override("font_selected_color", UI.INK)
	share_name.add_theme_stylebox_override("normal", UI.flat(Color(UI.INK, 0.06), 2, Vector4(12, 8, 12, 8)))
	var name_focus := StyleBoxFlat.new()
	name_focus.draw_center = false
	name_focus.border_color = UI.EDGE
	name_focus.set_border_width_all(2)
	share_name.add_theme_stylebox_override("focus", name_focus)
	share_section.add_child(share_name)
	_button(share_section, "Export my clean best", func() -> void:
		game.ghost_share.export_best(share_name.text)
		game.ghost_share.scan()
		_list_signature = ""
		_refresh_share()).name = "ExportGhost"
	share_status = _small(share_section, "")
	share_status.name = "GhostShareStatus"
	var scroll := ScrollContainer.new()
	scroll.name = "ImportedGhostsScroll"
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	share_section.add_child(scroll)
	share_list = VBoxContainer.new()
	share_list.name = "ImportedGhosts"
	share_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share_list.add_theme_constant_override("separation", 6)
	scroll.add_child(share_list)
	_button(share_section, "Race my local best", func() -> void:
		game.ghost_share.choose("")
		_list_signature = ""
		_refresh_share()).name = "ClearFriendGhost"
	_show_share(false)
	_refresh_share()

func _show_share(on: bool) -> void:
	share_section.visible = on
	share_toggle.text = "%s  Race a friend (ghost files)" % ("▾" if on else "▸")

func _refresh_pause() -> void:
	super()
	_refresh_share()
	_refresh_map_note()

func _build_map_cards() -> void:
	var ids: Array = game.call("map_ids")
	if ids != _map_ids and experiments_grid != null:
		for child: Node in experiments_grid.get_children():
			experiments_grid.remove_child(child)
			child.queue_free()
	super()
	if experiments_grid == null:
		experiments_heading = _heading(pause_pages["Maps"], "Experiments")
		experiments_heading.name = "ExperimentsHeading"
		pause_pages["Maps"].move_child(experiments_heading, map_grid.get_index() + 1)
		experiments_note = _small(pause_pages["Maps"], "Separate maps with experimental rules. The main maps keep their movement.")
		pause_pages["Maps"].move_child(experiments_note, experiments_heading.get_index() + 1)
		experiments_grid = GridContainer.new()
		experiments_grid.name = "ExperimentsGrid"
		experiments_grid.add_theme_constant_override("h_separation", CARD_GAP)
		experiments_grid.add_theme_constant_override("v_separation", CARD_GAP)
		pause_pages["Maps"].add_child(experiments_grid)
		pause_pages["Maps"].move_child(experiments_grid, experiments_note.get_index() + 1)
	for id: String in map_buttons:
		var entry: Dictionary = game.call("map_entry", id)
		if str(entry.get("kind", "")) != "experiment":
			continue
		var button: Button = map_buttons[id]
		if button.get_parent() != experiments_grid:
			button.reparent(experiments_grid)
		button.text = "%s\nEXPERIMENTAL · %s" % [str(entry.name), str(entry.theme)]
	var present := experiments_grid.get_child_count() > 0
	experiments_heading.visible = present
	experiments_note.visible = present
	experiments_grid.visible = present
	experiments_grid.columns = map_grid.columns
	_refresh_map_note()

func _refresh_map_note() -> void:
	if map_note != null:
		map_note.text = "%d maps. Each starts at its spawn and keeps your preset." % map_grid.get_child_count()

func _layout_pause(size: Vector2) -> void:
	super(size)
	if experiments_grid != null:
		experiments_grid.columns = map_grid.columns

func lab_controls_text() -> String:
	return str(game.map_entry().get("instructions", "EXPERIMENTAL")) if game.is_experiment_map() else super()

func _lab_text() -> void:
	super()
	if game.is_experiment_map():
		lab_tag.text = "EXPERIMENTAL · " + str(game.map_name()).to_upper()
		reticle.visible = bool(game.map_entry().get("reticle", false))
		if game.player.has_method("experiment_status"):
			lab_panel.text = str(game.player.call("experiment_status"))
			lab_panel.visible = not lab_panel.text.is_empty()
	else:
		lab_tag.text = "EXPERIMENTAL  ·  MOVEMENT LAB"

func _hint_text() -> String:
	if game.is_experiment_map():
		return "" if game.finished else str(game.level.call("route_hint", game.checkpoint_index, game.player.position))
	return super()

func _process(delta: float) -> void:
	super(delta)
	if game != null and game.is_experiment_map():
		keys_line.text = R16_KEYS_LINE + str(game.map_entry().get("key_hint", ""))

func _refresh_share() -> void:
	if share_section == null or game == null:
		return
	var service: Node = game.ghost_share
	share_status.text = str(service.status)
	share_status.visible = not share_status.text.is_empty()
	share_revision.text = str(game.call("map_revision_description"))
	share_revision.visible = not share_revision.text.is_empty()
	share_selection.text = "Racing your local best" if str(service.selected).is_empty() else ("Chosen friend is paused on this map or preset; racing your local best" if str(service.active).is_empty() else "Racing the selected friend")
	if ghost_switch != null:
		ghost_switch.text = "Show racing ghost  (G)"
	var signature := JSON.stringify([service.rows, service.active, game.course_key])
	if signature == _list_signature:
		return
	_list_signature = signature
	for child: Node in share_list.get_children():
		share_list.remove_child(child)
		child.queue_free()
	if service.rows.is_empty():
		_small(share_list, "No imported ghosts yet. Drop .spillghost files into the folder above.")
	for row: Dictionary in service.rows:
		var time_text := _time(float(row.time)) if float(row.get("time", -1)) > 0 else "time unavailable"
		var note: String = service.note_for(row)
		var identity: Dictionary = row.get("identity", {})
		var context := "%s / %s" % [str(identity.get("map", "unknown map")), str(identity.get("preset", "unknown preset"))]
		var button := _button(share_list, "%s  ·  %s\n%s\n%s" % [str(row.player), time_text, context, note], func() -> void:
			service.choose(str(row.file))
			_list_signature = ""
			_refresh_share())
		button.name = "Friend_" + str(row.file).sha256_text().left(16)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = note != "Ready to race"
		button.toggle_mode = true
		button.set_pressed_no_signal(str(service.active) == str(row.file))
		button.tooltip_text = str(row.file)

func _friend_label() -> String:
	if game == null or game.ghost_share == null:
		return ""
	for row: Dictionary in game.ghost_share.rows:
		if str(row.file) == str(game.ghost_share.active):
			return "%s  %s" % [str(row.player), _time(float(row.time))]
	return ""

func ghost_menu_state() -> String:
	var label := _friend_label()
	return label + " loaded" if not label.is_empty() else super()

func _run_text() -> String:
	var original := super()
	var label := _friend_label()
	if label.is_empty() or not bool(game.settings.ghost):
		return original
	var parts := Array(original.split("  ·  "))
	if not parts.is_empty() and (str(parts[0]).begins_with("ghost ") or parts[0] == "no ghost yet"):
		parts.pop_front()
	parts.push_front("racing " + label)
	return "  ·  ".join(parts)

func ghost_finish_line() -> String:
	var local := super()
	var label := _friend_label()
	return local if label.is_empty() else ((local + "\n") if not local.is_empty() else "") + "Raced " + label

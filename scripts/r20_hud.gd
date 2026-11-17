extends "res://scripts/r19_hud.gd"
## r18 pause-sheet controls for tether, plus a brief cream/ink through-line cue.
const TETHER := preload("res://scripts/r20_tether_player.gd")
var through_cue: ColorRect
var tether_section: VBoxContainer
var reel_manual: Button
var reel_automatic: Button
var tether_models := {}
var tether_note: Label
var tether_model_lock: Label

var export_name: LineEdit
var export_path: LineEdit
var export_status: Label
var export_button: Button
var export_open: Button

func _export_runs() -> void:
	export_button.disabled = true
	export_status.text = "Packing every local attempt…"
	var result: Dictionary = game.export_my_runs(export_name.text)
	export_button.disabled = false
	export_status.text = str(result.get("message", result.get("error", "Export failed.")))
	export_path.text = str(result.get("path", ""))
	export_path.visible = bool(result.get("ok", false))
	export_open.visible = export_path.visible

func _attach_run_export() -> void:
	var section := VBoxContainer.new()
	section.name = "RunExport"
	section.add_theme_constant_override("separation", 6)
	pause_pages["Runs"].add_child(section)
	export_name = LineEdit.new()
	export_name.name = "RunExportPlayer"
	export_name.placeholder_text = "Your player name (for Mike)"
	export_name.max_length = 64
	export_name.text = str(game.ghost_share.player_name)
	if export_name.text.strip_edges().is_empty():
		export_name.text = "Player"
	export_name.add_theme_font_override("font", UI.font("body"))
	export_name.add_theme_color_override("font_color", UI.INK)
	section.add_child(export_name)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	section.add_child(actions)
	export_button = _button(actions, "Export my runs", _export_runs)
	export_button.name = "ExportMyRuns"
	export_open = _button(actions, "Open folder", func() -> void:
		var code: int = game.run_export.open_folder(str(game.last_run_export.get("folder", "")))
		export_status.text = "Folder opened. Send the ZIP manually." if code == OK else "Folder could not open. Select the ZIP path below and copy it.")
	export_open.name = "OpenRunExportFolder"
	export_open.hide()
	export_status = _small(section, "Every attempt + settings. Nothing uploads.")
	export_status.name = "RunExportResult"
	export_path = LineEdit.new()
	export_path.name = "RunExportPath"
	export_path.editable = false
	export_path.add_theme_font_override("font", UI.font("body"))
	export_path.add_theme_font_size_override("font_size", 12)
	export_path.add_theme_color_override("font_uneditable_color", UI.INK_SOFT)
	export_path.tooltip_text = "Select this ZIP path and press Ctrl+C to copy."
	section.add_child(export_path)
	export_path.hide()

func attach(main: Node) -> void:
	super(main)
	_attach_run_export()
	tether_section = VBoxContainer.new()
	tether_section.name = "TetherPreferences"
	tether_section.add_theme_constant_override("separation", 8)
	pause_pages["Practice"].add_child(tether_section)
	_heading(tether_section, "Current map · rope")
	reel_manual = _button(tether_section, "Reel on right mouse", func() -> void: game.change_setting("tether_auto_reel", false))
	reel_manual.name = "ReelOnRightMouse"
	reel_automatic = _button(tether_section, "Reel automatically while attached", func() -> void: game.change_setting("tether_auto_reel", true))
	reel_automatic.name = "ReelAutomatically"
	for id: String in TETHER.MODELS:
		var button := _button(tether_section, TETHER.NOTES[id], _choose_model.bind(id))
		button.name = "TetherModel_" + id
		button.toggle_mode = true
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tether_models[id] = button
	tether_note = _small(tether_section, "Changing either restarts the attempt. Release mouse buttons after the menu; a fresh LMB press arms the line. Classic: 3 s / 1300 u/s². Alternatives: 5 s. All: 30 m aim / 32.03 m break / 2.44 m reel minimum. E belongs to Movement Lab.")
	tether_model_lock = _small(tether_section, "")
	tether_model_lock.name = "TetherFixedLaw"
	_refresh_tether()
	through_cue = ColorRect.new()
	through_cue.name = "ThroughCreamCue"
	through_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	through_cue.color = UI.CREAM
	through_cue.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	through_cue.offset_left = -112
	through_cue.offset_right = 112
	through_cue.offset_top = 64
	through_cue.offset_bottom = 92
	through_cue.visible = false
	add_child(through_cue)
	var launch_text := _small(through_cue, "RISE  ·  SECOND RUN", Color("263d45"))
	launch_text.position = Vector2(12, 4)
	launch_text.size = Vector2(200, 22)
	launch_text.add_theme_color_override("font_color", UI.INK)

func _choose_model(id: String) -> void:
	game.change_setting("tether_model", id)

func _refresh_pause() -> void:
	super()
	_refresh_tether()

func _refresh_tether() -> void:
	if tether_section == null:
		return
	tether_section.visible = game.map_has_capability("grapple")
	reel_manual.disabled = not bool(game.settings.tether_auto_reel)
	reel_automatic.disabled = bool(game.settings.tether_auto_reel)
	for id: String in tether_models:
		tether_models[id].disabled = game.map_entry().has("tether_model") or game.tether_model() == id
		(tether_models[id] as Button).set_pressed_no_signal(game.tether_model() == id)
	if tether_model_lock != null:
		tether_model_lock.visible = game.map_entry().has("tether_model")
		tether_model_lock.text = "This map fixes the rope law to %s. Reel controls are above; feedback controls are below." % game.tether_model()

func _process(delta: float) -> void:
	super(delta)
	if through_cue != null:
		var active: bool = game != null and game.map_id == "through-line" and game.player.has_signal("through_diagnostic") and float(game.player.cue_left_s) > 0.0
		through_cue.visible = active
		if active:
			through_cue.modulate.a = minf(1.0, float(game.player.cue_left_s) / 0.15)
	if game != null and game.map_id == "through-line" and title_card != null:
		(title_card.get_node("TitleKeys") as Label).text = "Bhop into the raised fork · 230+ u/s forward\nMore speed, more lift · air-strafe onto Second Run · keep moving"
	if game != null and game.map_has_capability("grapple") and title_card != null:
		(title_card.get_node("TitleKeys") as Label).text = "LMB hold to swing · RMB reel · release LMB to coast\nSpace jump · A/D strafe · Esc rope model and reel preference"

func map_changed() -> void:
	super()
	_refresh_tether()

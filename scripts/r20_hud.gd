extends "res://scripts/r19_hud.gd"
## r18 pause-sheet controls for tether, plus a brief cream/ink through-line cue.
const TETHER := preload("res://scripts/r20_tether_player.gd")
var through_cue: ColorRect
var tether_section: VBoxContainer
var reel_manual: Button
var reel_automatic: Button
var tether_models := {}
var tether_note: Label

func attach(main: Node) -> void:
	super(main)
	tether_section = VBoxContainer.new()
	tether_section.name = "TetherPreferences"
	tether_section.add_theme_constant_override("separation", 8)
	_pause_column.add_child(tether_section)
	_pause_column.move_child(tether_section, experiments_grid.get_index() + 1)
	_heading(tether_section, "Tether Yard · rope")
	reel_manual = _button(tether_section, "Reel on right mouse", func() -> void: game.change_setting("tether_auto_reel", false))
	reel_manual.name = "ReelOnRightMouse"
	reel_automatic = _button(tether_section, "Reel automatically while attached", func() -> void: game.change_setting("tether_auto_reel", true))
	reel_automatic.name = "ReelAutomatically"
	for id: String in TETHER.MODELS:
		var button := _button(tether_section, TETHER.NOTES[id], _choose_model.bind(id))
		button.name = "TetherModel_" + id
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tether_models[id] = button
	tether_note = _small(tether_section, "Changing either restarts the attempt. Release mouse buttons after the menu; a fresh LMB press arms the line. Classic: 3 s / 1300 u/s². Alternatives: 5 s. All: 30 m aim / 32.03 m break / 2.44 m reel minimum. E belongs to Movement Lab.")
	_refresh_tether()
	through_cue = ColorRect.new()
	through_cue.name = "ThroughCreamCue"
	through_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	through_cue.color = UI.CREAM
	through_cue.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	through_cue.offset_bottom = 30
	through_cue.visible = false
	add_child(through_cue)
	var launch_text := _small(through_cue, "RISE  ·  SECOND RUN", Color("263d45"))
	launch_text.position = Vector2(20, 4)
	launch_text.size = Vector2(380, 22)
	launch_text.add_theme_color_override("font_color", UI.INK)

func _choose_model(id: String) -> void:
	game.change_setting("tether_model", id)

func _refresh_pause() -> void:
	super()
	_refresh_tether()

func _refresh_tether() -> void:
	if tether_section == null:
		return
	tether_section.visible = game.map_id == "tether-yard"
	reel_manual.disabled = not bool(game.settings.tether_auto_reel)
	reel_automatic.disabled = bool(game.settings.tether_auto_reel)
	for id: String in tether_models:
		tether_models[id].disabled = str(game.settings.tether_model) == id

func _process(delta: float) -> void:
	super(delta)
	if through_cue != null:
		var active: bool = game != null and game.map_id == "through-line" and game.player.has_signal("through_diagnostic") and float(game.player.cue_left_s) > 0.0
		through_cue.visible = active
		if active:
			through_cue.modulate.a = minf(1.0, float(game.player.cue_left_s) / 0.15)
			through_cue.offset_bottom = 30
	if game != null and game.map_id == "through-line" and title_card != null:
		(title_card.get_node("TitleKeys") as Label).text = "Bhop into the raised fork · 230+ u/s forward\nMore speed, more lift · air-strafe onto Second Run · keep moving"
	if game != null and game.map_id == "tether-yard" and title_card != null:
		(title_card.get_node("TitleKeys") as Label).text = "LMB hold to swing · RMB reel · release LMB to coast\nSpace jump · A/D strafe · Esc rope model and reel preference"

func map_changed() -> void:
	super()
	_refresh_tether()

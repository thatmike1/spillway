extends "res://scripts/r15_hud.gd"
## p / r16 hud: r15's layout and menu, kept where they are, with r16's additions. the style panel
## (scripts/r16_style_panel.gd) sits low on the right just above the clock; the finish panel and
## the menu add the style best beside the time best, the ghost switch and the recording state.
## every attempt is now recorded, so practice reads "no best" where r15 said "not recorded".

const PANEL := preload("res://scripts/r16_style_panel.gd")
const R16_KEYS_LINE := "F2 bhop server · F5 AA 1000 · Ctrl crouch · R restart · F last checkpoint · G ghost · Esc maps, stages and settings"
const R16_LAB_KEYS_LINE := "F2 / F5 only · Shift slide (in the air: slide on landing) · Space at a wall: kick off · hold E: grapple · 1 / 2 / 3 moves on or off · Ctrl crouch · R · F · G ghost · Esc"

var style_panel: Control
var ghost_switch: CheckButton
var recording_line: Label

func attach(main: Node) -> void:
	super(main)
	style_panel = PANEL.new()
	style_panel.name = "StylePanel"
	overlay.add_child(style_panel)
	# drawn under the finish panel and the menu; the panel hides itself while paused.
	overlay.move_child(style_panel, finish_panel.get_index())
	style_panel.call("attach", main, main.session.style)
	_add_r16_menu()
	_r16_lab_words()
	preset_changed()

func _add_r16_menu() -> void:
	var anchor := pause_records.get_index() + 1
	ghost_switch = CheckButton.new()
	ghost_switch.name = "GhostSwitch"
	ghost_switch.button_pressed = bool(game.settings.ghost)
	ghost_switch.toggled.connect(func(on: bool) -> void:
		if on != bool(game.settings.ghost):
			game.call("toggle_ghost"))
	_pause_column.add_child(ghost_switch)
	_pause_column.move_child(ghost_switch, anchor)
	recording_line = Label.new()
	recording_line.name = "RecordingLine"
	recording_line.add_theme_font_size_override("font_size", 12)
	recording_line.add_theme_color_override("font_color", DIM)
	recording_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recording_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_column.add_child(recording_line)
	_pause_column.move_child(recording_line, anchor + 1)
	for node: Node in _pause_column.get_children():
		if node is Label and str((node as Label).text).begins_with("Checkpoint practice"):
			(node as Label).text = "Checkpoint practice  (recorded, never a best)"

## the lab's move words follow the r16 runner's own laws once it is the lab runner.
func _r16_lab_words() -> void:
	for id: String in lab_switches:
		var words := str(lab_word(id))
		(lab_switches[id] as CheckButton).text = "%s   ·   key %d" % [words, (["slide", "wall_jump", "grapple"] as Array).find(id) + 1]

## r16's words for one lab move: the reworked wall jump and slide (docs/r16/LAB.md's copy), the
## unchanged grapple.
func lab_word(id: String) -> String:
	match id:
		"slide":
			return "Slide  (Shift; Shift in the air before landing: slide on landing)"
		"wall_jump":
			return "Wall jump  (Space at a wall: kick off, %s per landing, each wall once)" % _wall_budget()
	return str(LAB_WORDS.get(id, id))

func _wall_budget() -> String:
	if game == null or game.player == null or game.player.get_script() == null:
		return "2"
	var table: Variant = (game.player.get_script() as Script).get_script_constant_map().get("R16_WALL")
	return str((table as Dictionary).get("budget", 2)) if table is Dictionary else "2"

func lab_controls_text() -> String:
	return "Movement Lab, EXPERIMENTAL moves (labelled game choices, not the approved bhop):\n" \
		+ "Space at a wall: kick off, %s per landing, each wall once (A/D can stay held)\n" % _wall_budget() \
		+ "Shift in the air before landing: slide on landing; release and press Space to hop out  ·  hold E at a ring to grapple, let go to coast"

func preset_changed() -> void:
	super()
	if bool(game.call("is_lab")) and style_panel != null:
		controls.text = str(game.preset.get("controls", "")) + "\n" + lab_controls_text()
		_layout()

func _process(delta: float) -> void:
	super(delta)
	if game == null or game.player == null:
		return
	var lab := bool(game.call("is_lab"))
	keys_line.text = R16_LAB_KEYS_LINE if lab else R16_KEYS_LINE
	if ghost_key_missing():
		keys_line.text = keys_line.text.replace(" · G ghost", "")
	if not bool(game.clean_eligible):
		best_line.text = "practice · no best"
	practice_tag.text = "" if bool(game.clean_eligible) else "PRACTICE (%s) · no best · R for a clean run" % _reason(str(game.practice_reason))
	practice_tag.visible = not practice_tag.text.is_empty()
	_layout()

func ghost_key_missing() -> bool:
	return str(game.call("ghost_key_text")).is_empty()

func practice_started(stage_title: String, note: String = "") -> void:
	finish_panel.hide()
	notify("Practice from %s · recorded, no best%s" % [stage_title, "" if note.is_empty() else "  ·  " + note])

func respawned(stage_title: String) -> void:
	super(stage_title)
	notify("Back to %s · practice, no best" % stage_title)

func show_finish(is_best: bool, is_open_best: bool) -> void:
	super(is_best, is_open_best)
	var kind := str(game.finish_kind)
	var lines := Array(finish_body.text.split("\n"))
	if kind == "practice":
		lines[1] = "No best (%s) · R starts a clean run" % _reason(str(game.practice_reason))
	lines.insert(2, style_finish_line())
	var ghost := ghost_finish_line()
	if not ghost.is_empty():
		lines.insert(3, ghost)
	finish_body.text = "\n".join(lines)
	finish_footer.text = "R  run again     F  practise from %s     F2 / F5  switch preset     G  ghost     Esc  maps" % game.call("stage_title", int(game.checkpoint_index))
	var column := finish_panel.get_child(0) as VBoxContainer
	column.reset_size()
	finish_panel.size = column.get_combined_minimum_size() + Vector2(36, 30)

## the attempt's style score and how it stands against the clean whole-map style best.
func style_finish_line() -> String:
	var style: Dictionary = game.finish_style
	var score := int(style.get("score", 0))
	var points := str(PANEL.points_text(score))
	if not bool(style.get("eligible", false)):
		return "Style %s · %s" % [points, "practice, style not saved" if str(game.finish_kind) == "practice" else "not a clean whole-map run, style not saved"]
	if bool(game.style_new_best):
		var before := int(game.previous_style_best)
		return "Style %s · new style best%s" % [points, "" if before < 0 else "  (was %s)" % PANEL.points_text(before)]
	return "Style %s · style best %s" % [points, PANEL.points_text(int(game.style_best))]

func ghost_finish_line() -> String:
	if bool(game.ghost_new):
		return "This run is the new ghost for this map and preset"
	return ""

func _refresh_pause() -> void:
	super()
	(pause_panel.find_child("PauseHeading", true, false) as Label).text = "SPILLWAY R16  ·  %s" % str(game.call("map_name")).to_upper()
	var records: Array[String] = [pause_records.text]
	records.append("style best %s" % PANEL.points_text(int(game.style_best)) if int(game.style_best) >= 0 else "no style best yet")
	if str(game.style_state).begins_with("rejected"):
		records.append("stored style best ignored (%s)" % str(game.style_state).trim_prefix("rejected: "))
	pause_records.text = "  ·  ".join(records)
	if ghost_switch != null:
		ghost_switch.set_pressed_no_signal(bool(game.settings.ghost))
		ghost_switch.text = "Ghost of the fastest clean recorded run%s  ·  %s" % [("  (G)" if not ghost_key_missing() else ""), ghost_menu_state()]
	if recording_line != null:
		recording_line.text = str(game.session.call("recording_text")) + "\nRecordings are local files; nothing is uploaded. docs/r16/RECORDINGS.md has the format and the analysis tool."

func ghost_menu_state() -> String:
	var state := str(game.session.ghost_state)
	if state == "loaded":
		return "%s run loaded" % _time(float(game.session.ghost_ticks) / float(game.physics_hz))
	if state == "none yet":
		return "no clean recorded run here yet"
	return state

func mechanics_changed() -> void:
	super()
	_r16_lab_words()

func map_changed() -> void:
	super()
	_r16_lab_words()

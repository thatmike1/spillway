extends CanvasLayer
## p / r15 hud. the r14 layout: identity small at the top left, speed low in the centre, the
## strafe panel low on the left, the clock low on the right, the middle clear for landings. the
## map, the active preset, its rate and air acceleration are always on screen, with STAND-IN
## when the game plays a borrowed runner. a CROUCH tag under the speed shows the duck state.
## sync with no eligible samples reads as an em dash, never as 0 %.
##
## the pause menu: records, Resume/Restart/Checkpoint/Quit, a map chooser that lays out cards in
## as many columns as the panel width allows (it scrolls with the menu, so any number of maps
## fits), the stage picker, the two main presets with the advanced comparisons folded under
## them, and the look settings.

const INK := Color("f4f1dd")
const ACCENT := Color("f3cd83")
const AHEAD := Color("9fd8c4")
const BEHIND := Color("eaa17f")
const WARN := Color("f0a070")
const DIM := Color(0.957, 0.945, 0.867, 0.72)
const SHADE := Color(0.055, 0.10, 0.12)
const NO_SAMPLES := "—"
const KEYS_LINE := "F2 bhop server · F5 AA 1000 · Ctrl crouch · R restart · F last checkpoint · Esc maps, stages and settings"
## the movement lab's line: its presets, its three moves and their toggles.
const LAB_KEYS_LINE := "F2 / F5 only · Shift slide · Space at a wall: wall jump · hold E: grapple · 1 / 2 / 3 turn moves on or off · Ctrl crouch · R · F · Esc"
const LAB_CONTROLS := "Movement Lab, EXPERIMENTAL moves (labelled game choices, not the approved bhop):\nShift from a run slides under the pipe rack · Space as you touch a wall jumps off it · hold E at a ring to grapple, let go to coast"
const LAB_WORDS := {"slide": "Slide  (Shift)", "wall_jump": "Wall jump  (Space at a wall)", "grapple": "Grapple  (hold E)"}
## map cards: the narrowest card, the gap between cards and the most columns.
const CARD_MIN_WIDTH := 200.0
const CARD_HEIGHT := 62.0
const CARD_GAP := 8
const MAX_COLUMNS := 4
const PANEL_MAX_WIDTH := 900.0
const PANEL_MIN_WIDTH := 460.0
const KIND_WORDS := {"course": "", "legacy": "R14 map", "lab": "Experiment · not a course", "fixture": "FIXTURE"}

var game: Node
var overlay: Control
var identity: Label
var keys_line: Label
var controls: Label
var speed_label: Label
var speed_unit: Label
var speed_metric: Label
var crouch_tag: Label
var clock: Label
var best_line: Label
var strafe_live: Label
var strafe_last: Label
var strafe_split: Label
var strafe_chain: Label
var split_label: Label
var practice_tag: Label
var message: Label
var hint: Label
var finish_panel: ColorRect
var finish_title: Label
var finish_body: Label
var finish_footer: Label
var pause_panel: Control
var pause_identity: Label
var pause_records: Label
var pause_look: Label
var resume_button: Button
var restart_button: Button
var practice_button: Button
var quit_button: Button
var stage_picker: OptionButton
var stage_practice_button: Button
var map_grid: GridContainer
var map_heading: Label
var advanced_toggle: Button
var advanced_box: VBoxContainer
var preset_buttons: Dictionary = {}
var map_buttons: Dictionary = {}
var lab_tag: Label
var lab_panel: Label
var reticle: Label
var lab_box: VBoxContainer
var lab_switches: Dictionary = {}
var _stage_titles: Array[String] = []
var _map_ids: Array = []
var _pause_side: ColorRect
var _pause_scroll: ScrollContainer
var _pause_column: VBoxContainer
var _ident_shade: ColorRect
var _strafe_shade: ColorRect
var _clock_shade: ColorRect
var _fade: ColorRect
var _blink_alpha: float = 0.0
var _intro_alpha: float = 1.0
var _split_time: float = 0.0
var _message_time: float = 0.0
var _hint_alpha: float = 0.0

func _label(text: String, size: int, color: Color = INK, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.12, 0.14, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else overlay).add_child(label)
	return label

func _shade(alpha: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(SHADE, alpha)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(rect)
	return rect

func _backing(label: Label, alpha: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(SHADE, alpha)
	box.set_content_margin_all(4.0)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.set_corner_radius_all(3)
	label.add_theme_stylebox_override("normal", box)

func attach(main: Node) -> void:
	game = main
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_ident_shade = _shade(0.42)
	identity = _label("", 17, INK)
	keys_line = _label(KEYS_LINE, 12, DIM)
	controls = _label("", 14, INK)
	_backing(controls, 0.40)
	_strafe_shade = _shade(0.36)
	strafe_live = _label("", 15, INK)
	strafe_last = _label("", 15, INK)
	strafe_split = _label("", 13, DIM)
	strafe_chain = _label("", 13, DIM)
	speed_label = _label("0", 40, INK)
	speed_unit = _label("u/s", 15, DIM)
	speed_metric = _label("", 14, DIM)
	crouch_tag = _label("CROUCH", 13, ACCENT)
	_backing(crouch_tag, 0.40)
	_clock_shade = _shade(0.34)
	clock = _label("00:00.00", 22, INK)
	best_line = _label("", 13, DIM)
	split_label = _label("", 22, INK)
	practice_tag = _label("", 15, ACCENT)
	lab_tag = _label("EXPERIMENTAL  ·  MOVEMENT LAB", 18, WARN)
	_backing(lab_tag, 0.55)
	lab_panel = _label("", 14, INK)
	_backing(lab_panel, 0.45)
	reticle = _label("+", 22, INK)
	message = _label("", 17, INK)
	hint = _label("", 15, Color(INK, 0.9))
	for label: Label in [split_label, message, hint, practice_tag]:
		_backing(label, 0.40)
	_make_finish()
	_make_pause()
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.08, 0.09, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_fade)
	get_viewport().size_changed.connect(_layout)
	preset_changed()

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	for label: Label in [identity, practice_tag, message, crouch_tag, lab_tag, lab_panel, reticle]:
		label.reset_size()
	identity.position = Vector2(22, 14)
	keys_line.position = Vector2(22, 40)
	_ident_shade.position = Vector2(14, 10)
	_ident_shade.size = Vector2(maxf(identity.get_minimum_size().x, keys_line.get_minimum_size().x) + 18.0, 50)
	controls.position = Vector2(22, 66)
	var speed_size := speed_label.get_minimum_size()
	speed_label.position = Vector2(size.x * 0.5 - speed_size.x * 0.5 - 14.0, size.y - 86)
	speed_unit.position = Vector2(speed_label.position.x + speed_size.x + 6.0, size.y - 64)
	speed_metric.position = Vector2(size.x * 0.5 - speed_metric.get_minimum_size().x * 0.5, size.y - 36)
	crouch_tag.position = Vector2(size.x * 0.5 - crouch_tag.get_minimum_size().x * 0.5, size.y - 118)
	strafe_live.position = Vector2(22, size.y - 112)
	strafe_last.position = Vector2(22, size.y - 88)
	strafe_split.position = Vector2(22, size.y - 64)
	strafe_chain.position = Vector2(22, size.y - 42)
	_strafe_shade.position = Vector2(14, size.y - 116)
	var strafe_width := 0.0
	for label: Label in [strafe_live, strafe_last, strafe_split, strafe_chain]:
		strafe_width = maxf(strafe_width, label.get_minimum_size().x)
	_strafe_shade.size = Vector2(strafe_width + 18.0, 100)
	var right := size.x - 22.0
	clock.position = Vector2(right - clock.get_minimum_size().x, size.y - 74)
	best_line.position = Vector2(right - best_line.get_minimum_size().x, size.y - 44)
	_clock_shade.position = Vector2(minf(clock.position.x, best_line.position.x) - 10.0, size.y - 78)
	_clock_shade.size = Vector2(right - _clock_shade.position.x + 10.0, 60)
	practice_tag.position = Vector2(size.x - practice_tag.get_minimum_size().x - 22, 14)
	if practice_tag.visible and (practice_tag.get_rect().intersects(identity.get_rect()) or practice_tag.get_rect().intersects(keys_line.get_rect())):
		practice_tag.position.y = controls.position.y + controls.get_minimum_size().y + 8.0
	lab_tag.position = Vector2(size.x - lab_tag.get_minimum_size().x - 22, practice_tag.position.y + (34.0 if practice_tag.visible else 0.0))
	lab_panel.position = Vector2(size.x - lab_panel.get_minimum_size().x - 22, lab_tag.position.y + 36.0)
	reticle.position = size * 0.5 - reticle.get_minimum_size() * 0.5
	message.position = Vector2(size.x * 0.5 - message.get_minimum_size().x * 0.5, size.y - 184)
	hint.position = Vector2(22, size.y - 152)
	split_label.position = Vector2(size.x * 0.5 - split_label.get_minimum_size().x * 0.5, size.y * 0.70)
	finish_panel.position = Vector2(30, maxf(110.0, size.y * 0.5 - finish_panel.size.y * 0.5))
	_layout_pause(size)
	_fade.size = size

## the pause side panel takes most of a narrow window and stops growing on a wide one; the map
## grid gets as many card columns as fit its width.
func _layout_pause(size: Vector2) -> void:
	pause_panel.size = size
	var panel := clampf(size.x * 0.62, minf(size.x, PANEL_MIN_WIDTH), PANEL_MAX_WIDTH)
	_pause_side.size = Vector2(panel, size.y)
	var margin := 36.0 if panel >= 520.0 else 14.0
	_pause_scroll.position = Vector2(margin, 24)
	_pause_scroll.size = Vector2(panel - margin * 1.5, size.y - 48.0)
	var inner := _pause_scroll.size.x - 14.0
	_pause_column.custom_minimum_size = Vector2(inner, 0)
	map_grid.columns = map_columns(inner)

static func map_columns(width: float) -> int:
	return clampi(int(floor((width + CARD_GAP) / (CARD_MIN_WIDTH + CARD_GAP))), 1, MAX_COLUMNS)

func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	_blink_alpha = move_toward(_blink_alpha, 0.0, delta * 8.0)
	_fade.color.a = _blink_alpha
	var started := bool(game.get("_started"))
	_intro_alpha = move_toward(_intro_alpha, 0.0 if started and float(game.elapsed) > 4.0 else 1.0, delta * 1.2)
	controls.modulate.a = _intro_alpha
	identity.text = identity_text()
	var speed_u: float = game.call("display_speed_u")
	speed_label.text = "%d" % roundi(speed_u)
	speed_metric.text = "%.2f m/s" % float(game.display_speed) if bool(game.settings.show_ms) else ""
	crouch_tag.visible = bool(game.call("is_crouched"))
	crouch_tag.text = "CROUCH  ·  no room to stand" if bool(game.call("stand_blocked")) else "CROUCH"
	clock.text = _time(float(game.elapsed))
	if not bool(game.clean_eligible):
		best_line.text = "practice · not recorded"
	elif float(game.best_time) > 0.0:
		best_line.text = "best %s" % _time(float(game.best_time))
	elif float(game.open_best_time) > 0.0:
		best_line.text = "open line %s" % _time(float(game.open_best_time))
	else:
		best_line.text = "no clean time yet, this preset"
	practice_tag.text = "" if bool(game.clean_eligible) else "PRACTICE (%s) · R for a clean run" % _reason(str(game.practice_reason))
	practice_tag.visible = not practice_tag.text.is_empty()
	_lab_text()
	_strafe_text()
	_split_time = maxf(0.0, _split_time - delta)
	split_label.modulate.a = minf(1.0, _split_time * 1.5)
	_message_time = maxf(0.0, _message_time - delta)
	if not str(game.pending_message).is_empty():
		message.text = str(game.pending_message)
		_message_time = maxf(_message_time, 0.5)
	message.modulate.a = minf(1.0, _message_time * 1.5)
	var text := _hint_text()
	if not text.is_empty():
		hint.text = text
	_hint_alpha = move_toward(_hint_alpha, 0.0 if text.is_empty() or started else 0.9, delta * 3.0)
	hint.modulate.a = _hint_alpha
	_layout()

## always visible: map (and what kind it is), active preset with its slot, rate and air
## acceleration, and STAND-IN when the runner is borrowed.
func identity_text() -> String:
	var preset: Dictionary = game.preset
	var rate := "%d Hz" % int(game.physics_hz)
	if not bool(game.rate_ok):
		rate += " (settling)"
	var air := str(preset.air)
	if preset.has("qualifier"):
		air += "  ·  " + str(preset.qualifier)
	var map := str(game.call("map_name")).to_upper()
	var kind := str(KIND_WORDS.get(str(game.call("map_kind")), ""))
	if bool(game.default_map_standin):
		kind = "development stand-in until Breakwater exists"
	if not kind.is_empty():
		map += " (%s)" % kind
	var line := "%s  ·  F%d %s  ·  %s  ·  %s" % [map, int(preset.slot), str(preset.label), rate, air]
	if bool(game.call("runner_is_standin")) and str(preset.family) == "source":
		line += "  ·  STAND-IN runner (R14, no crouch hull)"
	return line

## the lab's tag, its moves' live state and the aim mark. hidden on every other map.
func _lab_text() -> void:
	var lab := bool(game.call("is_lab"))
	lab_tag.visible = lab
	reticle.visible = lab
	var moves: Dictionary = game.call("lab_moves")
	lab_panel.visible = lab and not moves.is_empty()
	keys_line.text = LAB_KEYS_LINE if lab else KEYS_LINE
	if not lab_panel.visible:
		return
	var live: Dictionary = game.player.call("experiment_hud") if game.player.has_method("experiment_hud") else {}
	var lines: Array[String] = []
	for id: String in LAB_WORDS:
		lines.append("%s  %s  ·  %s" % ["ON " if bool(moves.get(id, false)) else "OFF", str(LAB_WORDS[id]), str(live.get(id, ""))])
	lab_panel.text = "\n".join(lines)
	var target := str(live.get("target", "none"))
	reticle.add_theme_color_override("font_color", AHEAD if target == "ok" or bool(live.get("attached", false)) else (BEHIND if target in ["blocked", "far"] else INK))

func mechanics_changed() -> void:
	_sync_lab_switches()
	if pause_panel != null and pause_panel.visible:
		_refresh_pause()

func _sync_lab_switches() -> void:
	if lab_box == null:
		return
	var moves: Dictionary = game.call("lab_moves")
	lab_box.visible = not moves.is_empty()
	for id: String in lab_switches:
		(lab_switches[id] as CheckButton).set_pressed_no_signal(bool(moves.get(id, false)))

func _reason(reason: String) -> String:
	match reason:
		"mechanics":
			return "lab moves changed mid-run"
		"preset":
			return "preset switched mid-run"
		"respawn":
			return "respawned"
		"rate":
			return "rate settling"
	if int(game.practice_stage) >= 0:
		return "checkpoint practice from %s" % game.call("stage_title", int(game.practice_stage))
	return "checkpoint practice"

func _strafe_text() -> void:
	var stats: Node = game.stats
	var flight: Dictionary = stats.flight
	if flight.is_empty():
		var contact := "on the ground" if game.player.call("is_grounded") else "in the air (no takeoff sample)"
		strafe_live.text = "%s  ·  run A/D sync %s" % [contact, sync_text(stats.call("run_sync"), int(stats.total_good), int(stats.total_eligible))]
	else:
		var since := float(stats.call("speed_u")) - float(flight.takeoff)
		strafe_live.text = "in the air  ·  A/D sync %s  ·  %s u/s since takeoff" % [sync_text(stats.call("live_sync"), int(flight.good), int(flight.eligible)), _signed(since)]
	var hop: Dictionary = stats.last_hop
	if hop.is_empty():
		strafe_last.text = "last hop  %s" % NO_SAMPLES
		strafe_split.text = "gain = landing - takeoff"
		strafe_chain.text = "contact = speed walls and lips took"
		return
	strafe_last.text = "last hop  %s u/s  ·  sync %s  ·  %d ticks" % [_signed(float(hop.gain)), sync_text(hop.sync, int(hop.good), int(hop.eligible)), int(hop.air_ticks)]
	var wall := "  ·  wall %d tick%s" % [int(hop.wall_ticks), "" if int(hop.wall_ticks) == 1 else "s"] if int(hop.wall_ticks) > 0 else ""
	strafe_split.text = "air %s  ·  contact %s%s" % [_signed(float(hop.air)), _signed(float(hop.contact)), wall]
	if hop.has("chain"):
		strafe_chain.text = "%d → %d u/s  ·  next takeoff %s  ·  ground %s, %d tick%s" % [roundi(float(hop.takeoff)), roundi(float(hop.landing)), _signed(float(hop.chain)), _signed(float(hop.ground)),
			int(hop.ground_ticks), "" if int(hop.ground_ticks) == 1 else "s"]
	else:
		strafe_chain.text = "%d → %d u/s  ·  takeoff to landing" % [roundi(float(hop.takeoff)), roundi(float(hop.landing))]

## "87 % (34/39)", or the em dash when there were no eligible samples.
static func sync_text(value: Variant, good: int, eligible: int) -> String:
	if value == null or eligible <= 0:
		return NO_SAMPLES
	return "%d %% (%d/%d)" % [roundi(float(value) * 100.0), good, eligible]

func _hint_text() -> String:
	if bool(game.finished) or not game.level.has_method("route_hint"):
		return ""
	return str(game.level.call("route_hint", int(game.checkpoint_index), game.player.global_position))

func preset_changed() -> void:
	controls.text = str(game.preset.get("controls", ""))
	if bool(game.call("is_lab")):
		controls.text += "\n" + LAB_CONTROLS
	_intro_alpha = 1.0
	if bool(game.preset.get("advanced", false)):
		_show_advanced(true)
	if pause_panel != null and pause_panel.visible:
		_refresh_pause()
	_layout()

func map_changed() -> void:
	_sync_stage_picker(true)
	_sync_lab_switches()
	preset_changed()

func run_started() -> void:
	finish_panel.hide()
	notify("")
	split_label.text = ""
	_split_time = 0.0
	_intro_alpha = 1.0

func practice_started(stage_title: String, note: String = "") -> void:
	finish_panel.hide()
	notify("Practice from %s · not recorded%s" % [stage_title, "" if note.is_empty() else "  ·  " + note])

func respawned(stage_title: String) -> void:
	_blink_alpha = 1.0
	notify("Back to %s · practice" % stage_title)

func notify(text: String) -> void:
	message.text = text
	_message_time = 0.0 if text.is_empty() else 3.0

func stage_reached(segment: int, skipped: int) -> void:
	var line := ""
	if skipped > 0:
		var names: Array = []
		for i: int in range(segment - skipped, segment):
			names.append(game.call("segment_title", i))
		line = "%s skipped  ·  " % " and ".join(names)
	line += "%s  %s" % [game.call("segment_title", segment), _time(float(game.stage_times[segment]))]
	var color := INK
	if bool(game.clean_eligible):
		var delta: float = game.call("split_delta_live", segment)
		if is_finite(delta):
			line += "   %s" % _delta(delta)
			color = AHEAD if delta <= 0.0 else BEHIND
	split_label.text = line
	split_label.add_theme_color_override("font_color", color)
	_split_time = 2.6

func show_finish(is_best: bool, is_open_best: bool) -> void:
	_split_time = 0.0
	split_label.text = ""
	var kind := str(game.finish_kind)
	finish_title.text = "%s  %s" % ["FINISH" if kind != "practice" else "PRACTICE FINISH", _time(float(game.elapsed))]
	var lines: Array[String] = ["%s · %s · %d Hz" % [game.call("map_name"), str(game.preset.label), int(game.physics_hz)]]
	match kind:
		"clean":
			var before := float(game.previous_best)
			if is_best:
				lines.append("First clean run with this preset" if before <= 0.0 else "New best  %s" % _delta(float(game.elapsed) - before))
			else:
				lines.append("%s vs best %s" % [_delta(float(game.elapsed) - float(game.best_time)), _time(float(game.best_time))])
		"open":
			lines.append("Open line · a checkpoint was skipped, so not a full-course time")
			lines.append("New open line best" if is_open_best else "Open line best %s" % _time(float(game.open_best_time)))
		_:
			lines.append("Not recorded (%s) · R starts a clean run" % _reason(str(game.practice_reason)))
	lines.append("")
	for i: int in game.stage_times.size():
		var name := str(game.call("segment_title", i))
		var segment: float = game.call("segment_time", i)
		if float(game.stage_times[i]) < 0.0:
			if kind == "practice" and int(game.practice_stage) > i:
				continue
			lines.append("%s   skipped" % name)
			continue
		var line := "%s   %s" % [name, _time(segment) if segment >= 0.0 else "reached at " + _time(float(game.stage_times[i]))]
		if kind == "clean" and i < game.split_deltas.size() and is_finite(game.split_deltas[i]):
			line += "   %s" % _delta(game.split_deltas[i])
		lines.append(line)
	finish_body.text = "\n".join(lines)
	finish_footer.text = "R  run again     F  practise from %s     F2 / F5  switch preset     Esc  maps" % game.call("stage_title", int(game.checkpoint_index))
	finish_panel.show()
	finish_panel.size = Vector2(460, 0)
	var column := finish_panel.get_child(0) as VBoxContainer
	column.reset_size()
	finish_panel.size = column.get_combined_minimum_size() + Vector2(36, 30)

func _make_finish() -> void:
	finish_panel = ColorRect.new()
	finish_panel.color = Color(SHADE, 0.62)
	finish_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(finish_panel)
	var column := VBoxContainer.new()
	column.position = Vector2(18, 14)
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finish_panel.add_child(column)
	finish_title = _label("", 28, INK, column)
	finish_body = _label("", 16, INK, column)
	finish_footer = _label("", 14, ACCENT, column)
	finish_panel.hide()

func _heading(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", ACCENT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _small(parent: Control, text: String, color: Color = DIM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _make_pause() -> void:
	pause_panel = Control.new()
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(pause_panel)
	var dim := ColorRect.new()
	dim.color = Color(SHADE, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	_pause_side = ColorRect.new()
	_pause_side.name = "PauseSide"
	_pause_side.color = Color(SHADE, 0.94)
	_pause_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel.add_child(_pause_side)
	_pause_scroll = ScrollContainer.new()
	_pause_scroll.name = "PauseScroll"
	_pause_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pause_side.add_child(_pause_scroll)
	_pause_column = VBoxContainer.new()
	_pause_column.add_theme_constant_override("separation", 7)
	_pause_scroll.add_child(_pause_column)
	var column := _pause_column
	var heading := Label.new()
	heading.name = "PauseHeading"
	heading.add_theme_font_size_override("font_size", 24)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	pause_identity = _small(column, "")
	pause_records = Label.new()
	pause_records.add_theme_font_size_override("font_size", 14)
	pause_records.add_theme_color_override("font_color", ACCENT)
	pause_records.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(pause_records)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 6)
	column.add_child(buttons)
	resume_button = _button(buttons, "Resume", func() -> void: game.set_paused(false))
	restart_button = _button(buttons, "Restart  R", func() -> void: game.restart_run())
	practice_button = _button(buttons, "Last checkpoint  F", func() -> void: game.practice_restart())
	quit_button = _button(buttons, "Quit", func() -> void: game.request_quit())
	map_heading = _heading(column, "Map  (starts at its spawn, keeps your preset)")
	map_grid = GridContainer.new()
	map_grid.name = "MapGrid"
	map_grid.add_theme_constant_override("h_separation", CARD_GAP)
	map_grid.add_theme_constant_override("v_separation", CARD_GAP)
	column.add_child(map_grid)
	_build_map_cards()
	_heading(column, "Checkpoint practice  (not recorded)")
	var stages := HBoxContainer.new()
	stages.name = "StageRow"
	stages.add_theme_constant_override("separation", 8)
	column.add_child(stages)
	stage_picker = OptionButton.new()
	stage_picker.name = "StagePicker"
	stage_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_picker.fit_to_longest_item = false
	stage_picker.clip_text = true
	stages.add_child(stage_picker)
	# linux release templates mismanage embedded popup focus connections (godot #89657).
	if OS.get_name() == "Linux" and OS.has_feature("template_release") and DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		stage_picker.get_popup().force_native = true
	stage_practice_button = _button(stages, "Practise here", func() -> void: game.practise_stage(stage_picker.get_selected_id()))
	stage_practice_button.name = "StagePractice"
	_sync_stage_picker(true)
	lab_box = VBoxContainer.new()
	lab_box.name = "LabMoves"
	lab_box.add_theme_constant_override("separation", 5)
	column.add_child(lab_box)
	_heading(lab_box, "Movement Lab moves  (EXPERIMENTAL, game choices; a change mid-run makes it practice)")
	for id: String in LAB_WORDS:
		var switch := CheckButton.new()
		switch.name = "LabMove_" + id
		switch.text = "%s   ·   key %d" % [str(LAB_WORDS[id]), (["slide", "wall_jump", "grapple"] as Array).find(id) + 1]
		switch.toggled.connect(func(on: bool) -> void: game.set_mechanic(id, on))
		lab_box.add_child(switch)
		lab_switches[id] = switch
	_small(lab_box, "All three start on in the lab. Off means the key does nothing and the approved F2/F5 movement plays unchanged. Records keep each loadout apart.")
	_sync_lab_switches()
	_heading(column, "Movement  (a switch keeps your position, speed and view)")
	var presets: Script = game.PRESETS
	for id: String in presets.PRIMARY:
		_preset_button(column, presets, id)
	advanced_toggle = Button.new()
	advanced_toggle.name = "AdvancedToggle"
	advanced_toggle.toggle_mode = true
	advanced_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	advanced_toggle.flat = true
	advanced_toggle.toggled.connect(func(on: bool) -> void: _show_advanced(on))
	column.add_child(advanced_toggle)
	advanced_box = VBoxContainer.new()
	advanced_box.name = "AdvancedPresets"
	advanced_box.add_theme_constant_override("separation", 7)
	column.add_child(advanced_box)
	for id: String in presets.ORDER:
		if not id in presets.PRIMARY:
			_preset_button(advanced_box, presets, id)
	_small(advanced_box, "F1 vanilla (64 Hz) is not in R15; the delivered R14 build keeps it.")
	_show_advanced(false)
	_heading(column, "Look")
	pause_look = _small(column, "", INK)
	for item: Array in [["Source sensitivity (Source units, m_yaw 0.022)", "source_sensitivity", 0.2, 10.0, 0.05], ["Source FOV (4:3 reference, widened for the screen)", "source_fov", 70.0, 110.0, 1.0],
			["R13 mouse (× 0.0022 rad per count, advanced F3 only)", "r13_sensitivity", 0.3, 2.5, 0.05], ["R13 horizontal FOV (literal, F3 only)", "r13_fov", 70.0, 110.0, 1.0], ["Volume", "volume", 0.0, 1.0, 0.05]]:
		var label := Label.new()
		label.text = item[0]
		label.add_theme_font_size_override("font_size", 13)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
		var slider := HSlider.new()
		slider.name = "Setting_" + str(item[1])
		slider.min_value = item[2]
		slider.max_value = item[3]
		slider.step = item[4]
		slider.value = game.settings[item[1]]
		slider.value_changed.connect(func(value: float) -> void:
			game.change_setting(str(item[1]), value)
			pause_look.text = str(game.call("look_description")))
		column.add_child(slider)
	var metric := CheckButton.new()
	metric.name = "Setting_show_ms"
	metric.text = "Show m/s under u/s"
	metric.button_pressed = game.settings.show_ms
	metric.toggled.connect(func(value: bool) -> void: game.change_setting("show_ms", value))
	column.add_child(metric)
	_small(column, "Speed is measured horizontal travel over the last 0.1 s (1 u = 0.0254 m); a crouch moving the body's height never counts as speed. Sync counts air ticks with one of A/D held while the view turns: good when it turns toward the key. No such ticks shows %s. Contact is speed that walls, lips and ramps changed in the air, kept apart from sync. Nothing here rates how efficient a strafe was." % NO_SAMPLES)
	pause_panel.hide()
	_layout_pause(get_viewport().get_visible_rect().size)

func _preset_button(parent: Control, presets: Script, id: String) -> void:
	var entry: Dictionary = presets.call("entry", id)
	var button := Button.new()
	button.name = "Preset_" + id
	button.text = "F%d  %s" % [int(entry.slot), str(entry.label)]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.disabled = not bool(presets.call("available", id))
	button.pressed.connect(func() -> void: game.select_preset(id))
	parent.add_child(button)
	preset_buttons[id] = button
	var detail := "%s\nAir: %s · jump: %s" % [str(entry.summary), str(entry.air), str(entry.jump)]
	if not str(entry.controls).is_empty():
		detail += "\n" + str(entry.controls).replace("\n", " · ")
	_small(parent, detail)

func _show_advanced(on: bool) -> void:
	if advanced_box == null:
		return
	advanced_box.visible = on
	advanced_toggle.set_pressed_no_signal(on)
	advanced_toggle.text = "%s  Advanced comparisons (F4 Quake III-inspired, F3 R13)" % ("▾" if on else "▸")

## one card per playable map, rebuilt only when the list of maps changes.
func _build_map_cards() -> void:
	var ids: Array = game.call("map_ids")
	if ids == _map_ids:
		return
	_map_ids = ids.duplicate()
	for child: Node in map_grid.get_children():
		map_grid.remove_child(child)
		child.queue_free()
	map_buttons.clear()
	for id: String in ids:
		var entry: Dictionary = game.call("map_entry", id)
		if id == "experiment":
			entry.theme = "Slide, wall jump and grapple"
		var button := Button.new()
		button.name = "Map_" + id
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(CARD_MIN_WIDTH, CARD_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = map_card_text(entry)
		button.tooltip_text = str(entry.get("theme", ""))
		button.pressed.connect(func() -> void: game.select_map(id))
		map_grid.add_child(button)
		map_buttons[id] = button
	map_heading.text = "Map  ·  %d playable  (starts at its spawn, keeps your preset)" % ids.size()

static func map_card_text(entry: Dictionary) -> String:
	var words := "Not a course" if str(entry.get("kind", "")) == "lab" else str(KIND_WORDS.get(str(entry.get("kind", "")), ""))
	var sub := str(entry.get("theme", ""))
	if not words.is_empty():
		sub = words if sub.is_empty() else "%s · %s" % [sub, words]
	return "%s\n%s" % [str(entry.get("name", entry.get("id", "?"))), sub]

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func set_paused(value: bool) -> void:
	pause_panel.visible = value
	finish_panel.modulate.a = 0.0 if value else 1.0
	if value:
		_refresh_pause()
		# each opening offers the last checkpoint reached, so Practise here without a change is F.
		_sync_stage_picker(true)
		_pause_scroll.scroll_vertical = 0
		resume_button.grab_focus()
	elif stage_picker != null:
		stage_picker.get_popup().hide()

## rebuilds the items when the map's stages changed; `select_current` picks the last stage reached.
func _sync_stage_picker(select_current: bool) -> void:
	if stage_picker == null or game == null or game.level == null:
		return
	var titles: Array[String] = []
	for i: int in int(game.call("stage_count")):
		titles.append(str(game.call("stage_title", i)))
	if titles != _stage_titles:
		_stage_titles = titles
		stage_picker.clear()
		for i: int in titles.size():
			stage_picker.add_item(stage_item_text(i, titles[i]), i)
		select_current = true
	if select_current:
		stage_picker.select(clampi(int(game.checkpoint_index), 0, titles.size() - 1))

static func stage_item_text(index: int, title: String) -> String:
	return "Start  %s" % title if index == 0 else "%d  %s" % [index, title]

func _refresh_pause() -> void:
	(pause_panel.find_child("PauseHeading", true, false) as Label).text = "SPILLWAY R15  ·  %s" % str(game.call("map_name")).to_upper()
	var runner := "runner %s%s" % [str(game.call("runner_path")).get_file(), " (STAND-IN, no crouch hull)" if bool(game.call("runner_is_standin")) and str(game.preset.family) == "source" else ""]
	pause_identity.text = "build %s  ·  record key %s  ·  records %s  ·  %s, %d Hz  ·  %s" % [game.BUILD_ID, str(game.course_key).left(8), game.profile_state, str(game.preset.label), int(game.physics_hz), runner]
	var records: Array[String] = []
	records.append("Best %s" % _time(float(game.best_time)) if float(game.best_time) > 0.0 else "No clean finish with this preset here yet")
	if float(game.open_best_time) > 0.0:
		records.append("open line %s" % _time(float(game.open_best_time)))
	if str(game.record_state).begins_with("rejected"):
		records.append("stored record ignored (%s)" % str(game.record_state).trim_prefix("rejected: "))
	pause_records.text = "  ·  ".join(records)
	practice_button.text = "Practise %s  F" % game.call("stage_title", int(game.checkpoint_index))
	_build_map_cards()
	_sync_stage_picker(false)
	var lab := bool(game.call("is_lab"))
	for id: String in preset_buttons:
		(preset_buttons[id] as Button).set_pressed_no_signal(id == str(game.preset_id))
		(preset_buttons[id] as Button).disabled = not bool(game.PRESETS.call("available", id)) or (lab and not id in game.PRESETS.PRIMARY)
	_sync_lab_switches()
	for id: String in map_buttons:
		(map_buttons[id] as Button).set_pressed_no_signal(id == str(game.map_id))
	pause_look.text = str(game.call("look_description"))
	_layout_pause(get_viewport().get_visible_rect().size)

func _signed(value: float) -> String:
	var rounded := roundi(value)
	if rounded == 0:
		return "±0"
	return "%s%d" % ["+" if rounded > 0 else "-", absi(rounded)]

func _time(value: float) -> String:
	return "%02d:%05.2f" % [int(value) / 60, fmod(value, 60.0)]

func _delta(value: float) -> String:
	if absf(value) < 0.005:
		return "±0.00"
	return "%s%.2f" % ["+" if value > 0.0 else "-", absf(value)]

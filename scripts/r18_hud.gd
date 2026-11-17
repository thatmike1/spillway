extends "res://scripts/r16_hud.gd"
## p / r18 hud: the r15/r16 hud's fields, texts and menu behaviour, presented in one look c
## language (scripts/r18_ui_theme.gd). nothing here writes to the game.
##
## what the player sees: a title card over the live spawn that lifts on any input or once the
## run starts; map and preset small at the top left; teaching text as cream tickets under them
## until the run is under way; speed low centre; time low left; style low right; toasts as a
## ticket at the top centre; the middle stays empty. blocks sit inside a centred 16:9 frame.
## F9 turns on telemetry: the r15 identity line, the key line, the strafe panel, build, record
## key, runner and recording path, the readouts the probes and agents read. off by default.

const UI := preload("res://scripts/r18_ui_theme.gd")
const R18_PANEL := preload("res://scripts/r18_style_panel.gd")
const WORDMARK := preload("res://shaders/r18_wordmark.gdshader")
const TELEMETRY_KEY := "F9"
const PLAYER_KEYS := "Space hop  ·  A / D with the mouse to strafe  ·  Ctrl crouch  ·  R restart  ·  F last checkpoint  ·  G ghost  ·  L look  ·  Esc maps and settings  ·  F9 telemetry"
## the title sheet already carries the preset's own movement text, so it adds only the other keys.
const TITLE_KEYS := "R restart  ·  F last checkpoint  ·  G ghost  ·  L look  ·  Esc maps and settings  ·  F9 telemetry"
## teaching text leaves once the run is under way: four seconds in, or at this speed, whichever is first.
const TEACH_SPEED_U := 280.0

var pause_pages: Dictionary = {}
var pause_tabs: Dictionary = {}
var pause_destination := "Maps"
var current_map_button: Button

var telemetry: bool = false
var map_title: Label
var preset_line: Label
var run_line: Label
var telemetry_extra: Label
var title_card: Control
var pause_keys: Label
var pause_kicker: Label
var map_note: Label
var practice_note: Label
var ghost_state_label: Label
var finish_card: PanelContainer
var _finish_kicker: Label
var _finish_time: Label
var _finish_result: Label
var _finish_meta: Label
var _finish_style: Label
var _finish_ghost: Label
var _finish_splits: GridContainer
var _finish_footer: Label
var _pause_edge: ColorRect
var _title_alpha: float = 1.0
var _title_dismissed: bool = false
var _title_mark: Label
var _teach_alpha: float = 0.0
var _teach_gone: bool = false
var _last_elapsed: float = 0.0

# --- construction --------------------------------------------------------------------------

func _label(text: String, size: int, color: Color = INK, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.world_label(label, "numeral" if size >= 26 else ("title" if size >= 17 else "body"), size, UI.CREAM)
	(parent if parent != null else overlay).add_child(label)
	return label

func _backing(_label_node: Label, _alpha: float) -> void:
	pass

func _shade(_alpha: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(rect)
	return rect

func _heading(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI.font("title"))
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", UI.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_constant_override("line_spacing", 0)
	parent.add_child(label)
	return label

func _small(parent: Control, text: String, color: Color = DIM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI.font("body"))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UI.INK if color == INK else UI.INK_SOFT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func attach(main: Node) -> void:
	super(main)
	# r16's style panel becomes the r18 one, in the same place in the draw order.
	var index := style_panel.get_index()
	overlay.remove_child(style_panel)
	style_panel.free()
	style_panel = R18_PANEL.new()
	style_panel.name = "StylePanel"
	overlay.add_child(style_panel)
	overlay.move_child(style_panel, index)
	style_panel.call("attach", main, main.session.style)
	_style_world()
	_style_menu()
	_make_title()
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--ui-telemetry":
			telemetry = true
	set_telemetry(telemetry)
	preset_changed()

func _style_world() -> void:
	UI.world_label(identity, "smallnum", 12)
	UI.ticket(keys_line, "small", 12, SIDE_LEFT, 0.82)
	UI.ticket(controls, "body", 14)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.ticket(hint, "label", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.ticket(message, "label", 15, SIDE_BOTTOM)
	for label: Label in [strafe_live, strafe_last]:
		UI.telemetry_label(label, 12)
	for label: Label in [strafe_split, strafe_chain]:
		UI.telemetry_label(label, 11, Color(UI.CREAM, 0.74))
	UI.world_label(speed_label, "numeral", 40, UI.CREAM, 5)
	UI.world_label(speed_unit, "label", 14, Color(UI.CREAM, 0.9))
	UI.world_label(speed_metric, "smallnum", 12, Color(UI.CREAM, 0.8), 3)
	crouch_tag.add_theme_font_override("font", UI.font("label"))
	crouch_tag.add_theme_font_size_override("font_size", 11)
	crouch_tag.add_theme_color_override("font_color", UI.CREAM)
	crouch_tag.add_theme_constant_override("outline_size", 0)
	crouch_tag.add_theme_stylebox_override("normal", UI.flat(Color(UI.INK, 0.78), 9, Vector4(9, 2, 9, 3)))
	UI.world_label(clock, "numeral", 30, UI.CREAM, 5)
	UI.world_label(best_line, "small", 12, Color(UI.CREAM, 0.88), 3)
	UI.world_label(split_label, "title", 17)
	UI.ticket(practice_tag, "label", 13)
	UI.ticket(lab_tag, "label", 13, SIDE_RIGHT)
	UI.ticket(lab_panel, "small", 12, SIDE_RIGHT, 0.9)
	UI.world_label(reticle, "title", 22)
	map_title = _label("", 17)
	UI.world_label(map_title, "title", 18)
	preset_line = _label("", 12)
	UI.world_label(preset_line, "small", 12, Color(UI.CREAM, 0.9), 3)
	run_line = _label("", 12)
	UI.world_label(run_line, "small", 11, Color(UI.CREAM, 0.78), 3)
	telemetry_extra = _label("", 11)
	UI.telemetry_label(telemetry_extra, 11, Color(UI.CREAM, 0.74))
	_ident_shade.color = Color(UI.INK, 0.66)
	for node: Control in [map_title, preset_line, run_line, telemetry_extra]:
		overlay.move_child(node, identity.get_index())

func _style_menu() -> void:
	pause_panel.theme = UI.menu_theme()
	for node: Node in _pause_column.get_children():
		if node is Label and str((node as Label).text).begins_with("Checkpoint practice"):
			(node as Label).text = "Checkpoint practice"
	recording_line.add_theme_font_override("font", UI.font("body"))
	recording_line.add_theme_color_override("font_color", UI.INK_SOFT)
	ghost_state_label = _small(_pause_column, "")
	_pause_column.move_child(ghost_state_label, ghost_switch.get_index() + 1)
	# run section: ghost and recording follow the buttons rather than sit above them.
	var order: Array[Control] = [pause_kicker, _pause_column.find_child("PauseHeading", false, false), pause_identity, pause_records,
		resume_button.get_parent(), ghost_switch, ghost_state_label, recording_line]
	for i: int in order.size():
		_pause_column.move_child(order[i], i)
	for node: Control in [ghost_switch, ghost_state_label, recording_line]:
		node.reparent(pause_pages["Runs"])
	map_note = _small(pause_pages["Maps"], "")
	map_note.get_parent().move_child(map_note, map_heading.get_index() + 1)
	for button: Button in [resume_button]:
		var strong := UI.flat(UI.INK, 2, Vector4(16, 8, 16, 9))
		strong.border_color = UI.EDGE
		strong.border_width_bottom = 3
		button.add_theme_stylebox_override("normal", strong)
		button.add_theme_stylebox_override("hover", strong)
		button.add_theme_color_override("font_color", UI.CREAM)
		button.add_theme_color_override("font_hover_color", UI.CREAM)
		button.add_theme_color_override("font_focus_color", UI.CREAM)

## the start screen over the live spawn. it never takes input: it only watches for the first.
func _make_title() -> void:
	title_card = Control.new()
	title_card.name = "TitleCard"
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(title_card)
	overlay.move_child(title_card, pause_panel.get_index())
	var scrim := TextureRect.new()
	scrim.name = "Scrim"
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UI.INK, 0.74))
	gradient.set_color(1, Color(UI.INK, 0.0))
	gradient.add_point(0.5, Color(UI.INK, 0.42))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.2)
	texture.fill_to = Vector2(0.75, 0.75)
	texture.width = 256
	texture.height = 256
	scrim.texture = texture
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_card.add_child(scrim)
	_title_mark = Label.new()
	_title_mark.name = "Wordmark"
	_title_mark.text = "SPILLWAY"
	_title_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_mark.add_theme_font_override("font", UI.font("display"))
	_title_mark.add_theme_font_size_override("font_size", 150)
	_title_mark.add_theme_color_override("font_color", UI.CREAM)
	_title_mark.add_theme_constant_override("line_spacing", -40)
	var material := ShaderMaterial.new()
	material.shader = WORDMARK
	_title_mark.material = material
	title_card.add_child(_title_mark)
	for id: String in ["TitleMap", "TitlePrompt", "TitleKeys"]:
		var label := Label.new()
		label.name = id
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_card.add_child(label)
	UI.world_label(title_card.get_node("TitleMap"), "title", 22, UI.CREAM, 0)
	UI.ticket(title_card.get_node("TitlePrompt"), "label", 16)
	UI.ticket(title_card.get_node("TitleKeys"), "body", 13, SIDE_LEFT, 0.9)
	(title_card.get_node("TitleKeys") as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(title_card.get_node("TitlePrompt") as Label).text = "Move to start  ·  Esc for maps and settings"

func dismiss_title() -> void:
	_title_dismissed = true

func _input(event: InputEvent) -> void:
	if _title_dismissed or title_card == null:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed):
		dismiss_title()

func set_telemetry(on: bool) -> void:
	telemetry = on
	# telemetry is for reading the game now: it lifts the title card at once instead of fading it.
	if on:
		_title_dismissed = true
		_title_alpha = 0.0
		if title_card != null:
			title_card.visible = false
		for node: CanvasItem in [map_title, preset_line, clock, best_line, run_line, speed_label, speed_unit, speed_metric, style_panel, lab_tag, lab_panel, reticle]:
			if node != null:
				node.modulate.a = 1.0
	for node: CanvasItem in [identity, strafe_live, strafe_last, strafe_split, strafe_chain, telemetry_extra, _ident_shade]:
		node.visible = on
	if pause_identity != null:
		pause_identity.visible = on
	if pause_panel != null and pause_panel.visible:
		_refresh_pause()
	_layout()

# --- per frame --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	super(delta)
	if game == null or game.player == null:
		return
	var started := bool(game.get("_started"))
	if started or bool(game.paused):
		_title_dismissed = _title_dismissed or started
	_title_alpha = move_toward(_title_alpha, 0.0 if _title_dismissed else 1.0, delta * 3.0)
	if title_card != null:
		title_card.modulate.a = _title_alpha
		title_card.visible = _title_alpha > 0.0
	map_title.text = str(game.call("map_name"))
	var preset: Dictionary = game.preset
	preset_line.text = "F%d  ·  %s" % [int(preset.slot), str(preset.label)]
	run_line.text = _run_text()
	# teaching text waits until the title has fully cleared, then leaves once the run is under way.
	var elapsed := float(game.elapsed)
	if not started or elapsed < _last_elapsed:
		_teach_gone = false
	elif elapsed > 4.0 or float(game.call("display_speed_u")) > TEACH_SPEED_U:
		_teach_gone = true
	_last_elapsed = elapsed
	_teach_alpha = move_toward(_teach_alpha, 0.0 if _teach_gone or _title_alpha > 0.0 else 1.0, delta * 2.5)
	# the pause sheet stands alone: run HUD and teaching text step out while it is open.
	var shown := 0.0 if bool(game.paused) else 1.0
	keys_line.modulate.a = _teach_alpha * shown
	controls.modulate.a = _teach_alpha * shown
	hint.modulate.a = hint.modulate.a * (1.0 - _title_alpha) * shown
	message.modulate.a = message.modulate.a * shown
	practice_tag.modulate.a = shown
	for node: CanvasItem in [map_title, preset_line, clock, best_line, run_line, speed_label, speed_unit, speed_metric, style_panel, lab_tag, lab_panel, reticle]:
		node.modulate.a = (1.0 - _title_alpha) * shown
	if bool(game.finished):
		controls.modulate.a = 0.0
		keys_line.modulate.a = 0.0
	if telemetry:
		telemetry_extra.text = "%s  ·  record key %s  ·  records %s  ·  runner %s\n%s" % [game.BUILD_ID, str(game.course_key).left(8), game.profile_state,
			str(game.call("runner_path")).get_file(), str(game.session.call("recording_text"))]
	if title_card != null and title_card.visible:
		(title_card.get_node("TitleMap") as Label).text = "%s  —  %s" % [str(game.call("map_name")), str(game.call("map_entry", str(game.map_id)).get("theme", ""))]
		(title_card.get_node("TitleKeys") as Label).text = str(preset.get("controls", "")) + "\n" + TITLE_KEYS
	_layout()

## the ghost and recording line under the clock.
func _run_text() -> String:
	var parts: Array[String] = []
	var state := str(game.session.ghost_state)
	if not bool(game.settings.ghost):
		parts.append("ghost off")
	elif state == "loaded":
		parts.append("ghost %s" % _time(float(game.session.ghost_ticks) / float(game.physics_hz)))
	elif state == "none yet":
		parts.append("no ghost yet")
	if bool(game.record_runs):
		var rec := str(game.session.call("recording_text"))
		parts.append("recording" if rec.begins_with("Recording every") else ("recording off" if rec == "Recording off" else "recording problem"))
	return "  ·  ".join(parts)

# --- layout -----------------------------------------------------------------------------------

func _layout() -> void:
	if overlay == null or map_title == null:
		super()
		return
	var size := get_viewport().get_visible_rect().size
	var frame := UI.safe_frame(size)
	var left := frame.position.x + 32.0
	var right := frame.end.x - 32.0
	for label: Label in [identity, practice_tag, message, crouch_tag, lab_tag, lab_panel, reticle, map_title, preset_line, run_line, keys_line,
			controls, hint, clock, best_line, speed_label, speed_unit, speed_metric, split_label, telemetry_extra,
			strafe_live, strafe_last, strafe_split, strafe_chain]:
		label.reset_size()
	# top left: where you are, then teaching text, then telemetry.
	map_title.position = Vector2(left, 22)
	preset_line.position = Vector2(left, map_title.position.y + map_title.get_minimum_size().y - 1.0)
	var y := preset_line.position.y + preset_line.get_minimum_size().y + 12.0
	var wide := minf(560.0, frame.size.x * 0.46)
	for card: Label in [controls, hint]:
		card.custom_minimum_size.x = minf(wide, UI.text_width(card))
		card.reset_size()
	if controls.modulate.a > 0.01 and not controls.text.is_empty():
		controls.position = Vector2(left, y)
		y += controls.size.y + 6.0
		keys_line.position = Vector2(left, y)
		keys_line.custom_minimum_size.x = 0.0
		y += keys_line.get_minimum_size().y + 10.0
	else:
		controls.position = Vector2(left, y)
		keys_line.position = Vector2(left, y)
	hint.position = Vector2(left, y)
	if hint.modulate.a > 0.01:
		y += hint.size.y + 10.0
	if telemetry:
		var rows: Array[Label] = [identity, strafe_live, strafe_last, strafe_split, strafe_chain, telemetry_extra]
		var top := y + 4.0
		var width := 0.0
		for row: Label in rows:
			row.position = Vector2(left + 10.0, y + 8.0)
			y += row.get_minimum_size().y + 1.0
			width = maxf(width, row.get_minimum_size().x)
		_ident_shade.position = Vector2(left, top)
		_ident_shade.size = Vector2(width + 20.0, y - top + 10.0)
	# top right: the look label is placed by the host above these.
	var top_right := 22.0 + 26.0
	practice_tag.position = Vector2(right - practice_tag.get_minimum_size().x, top_right)
	if practice_tag.visible:
		top_right += practice_tag.get_minimum_size().y + 8.0
	lab_tag.position = Vector2(right - lab_tag.get_minimum_size().x, top_right)
	if lab_tag.visible:
		top_right += lab_tag.get_minimum_size().y + 2.0
	lab_panel.position = Vector2(right - lab_panel.get_minimum_size().x, top_right)
	# top centre: toasts. when the practice tag is up they stack under it on the right instead.
	message.position = Vector2(size.x * 0.5 - message.get_minimum_size().x * 0.5, 22)
	var tag_rect := Rect2(practice_tag.position, practice_tag.get_minimum_size()).grow(8.0)
	if practice_tag.visible and tag_rect.intersects(Rect2(message.position, message.get_minimum_size())):
		message.position = Vector2(right - message.get_minimum_size().x, tag_rect.end.y)
		top_right = message.position.y + message.get_minimum_size().y + 8.0
		lab_tag.position.y = top_right
		lab_panel.position.y = top_right + (lab_tag.get_minimum_size().y + 2.0 if lab_tag.visible else 0.0)
	# low centre: speed, its unit, m/s, the crouch tag and stage splits above it.
	var speed_size := speed_label.get_minimum_size()
	speed_label.position = Vector2(size.x * 0.5 - speed_size.x * 0.5, size.y - 44.0 - speed_size.y)
	speed_unit.position = Vector2(speed_label.position.x + speed_size.x + 4.0, speed_label.position.y + speed_size.y - speed_unit.get_minimum_size().y - 7.0)
	speed_metric.position = Vector2(size.x * 0.5 - speed_metric.get_minimum_size().x * 0.5, size.y - 44.0)
	crouch_tag.position = Vector2(size.x * 0.5 - crouch_tag.get_minimum_size().x * 0.5, speed_label.position.y - crouch_tag.get_minimum_size().y - 2.0)
	split_label.position = Vector2(size.x * 0.5 - split_label.get_minimum_size().x * 0.5, crouch_tag.position.y - split_label.get_minimum_size().y - 6.0)
	# low left: best above the clock, ghost and recording under it.
	run_line.position = Vector2(left, size.y - 24.0 - run_line.get_minimum_size().y)
	clock.position = Vector2(left, run_line.position.y - clock.get_minimum_size().y + 7.0)
	best_line.position = Vector2(left, clock.position.y - best_line.get_minimum_size().y + 5.0)
	reticle.position = size * 0.5 - reticle.get_minimum_size() * 0.5
	if finish_card != null:
		finish_card.reset_size()
		finish_panel.position = Vector2(left, maxf(90.0, size.y * 0.47 - finish_card.size.y * 0.5))
		finish_panel.size = finish_card.size
	if title_card != null and title_card.visible:
		_layout_title(size, frame)
	_layout_pause(size)
	_fade.size = size

func _layout_title(size: Vector2, frame: Rect2) -> void:
	var scrim := title_card.get_node("Scrim") as TextureRect
	scrim.position = Vector2.ZERO
	scrim.size = size
	var left := frame.position.x + 64.0
	var font_size := clampi(int(frame.size.x * 0.115), 72, 190)
	_title_mark.add_theme_font_size_override("font_size", font_size)
	_title_mark.reset_size()
	var mark := _title_mark.get_minimum_size()
	_title_mark.position = Vector2(left - font_size * 0.06, size.y * 0.16)
	(_title_mark.material as ShaderMaterial).set_shader_parameter("box_size", mark)
	var map := title_card.get_node("TitleMap") as Label
	var prompt := title_card.get_node("TitlePrompt") as Label
	var keys := title_card.get_node("TitleKeys") as Label
	for label: Label in [map, prompt, keys]:
		label.reset_size()
	keys.custom_minimum_size.x = minf(560.0, frame.size.x * 0.5)
	keys.reset_size()
	map.position = Vector2(left, _title_mark.position.y + mark.y * 0.86)
	prompt.position = Vector2(left, map.position.y + map.get_minimum_size().y + 18.0)
	keys.position = Vector2(left, prompt.position.y + prompt.get_minimum_size().y + 22.0)

func _layout_pause(size: Vector2) -> void:
	if _pause_side == null:
		return
	var frame := UI.safe_frame(size)
	pause_panel.size = size
	var panel := clampf(frame.size.x * 0.42, minf(size.x, 470.0), 640.0)
	_pause_side.position = Vector2(frame.position.x, 0)
	_pause_side.size = Vector2(panel, size.y)
	if _pause_edge != null:
		_pause_edge.position = Vector2(frame.position.x + panel, 0)
		_pause_edge.size = Vector2(3, size.y)
	var margin := 34.0 if panel >= 520.0 else 18.0
	_pause_scroll.position = Vector2(margin, 26)
	_pause_scroll.size = Vector2(panel - margin - 12.0, size.y - 52.0)
	var inner := _pause_scroll.size.x - 16.0
	_pause_column.custom_minimum_size = Vector2(inner, 0)
	map_grid.columns = map_columns(inner)

# --- menu ------------------------------------------------------------------------------------

func _make_pause() -> void:
	pause_panel = Control.new()
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(pause_panel)
	var dim := ColorRect.new()
	dim.color = Color(UI.INK, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	_pause_side = ColorRect.new()
	_pause_side.name = "PauseSide"
	_pause_side.color = Color(UI.CREAM, 0.98)
	_pause_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel.add_child(_pause_side)
	_pause_edge = ColorRect.new()
	_pause_edge.color = UI.EDGE
	_pause_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel.add_child(_pause_edge)
	_pause_scroll = ScrollContainer.new()
	_pause_scroll.name = "PauseScroll"
	_pause_scroll.follow_focus = true
	_pause_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pause_side.add_child(_pause_scroll)
	_pause_column = VBoxContainer.new()
	_pause_column.add_theme_constant_override("separation", 9)
	_pause_scroll.add_child(_pause_column)
	var column := _pause_column
	pause_kicker = _small(column, "Paused")
	pause_kicker.add_theme_font_override("font", UI.font("label"))
	var heading := Label.new()
	heading.name = "PauseHeading"
	heading.add_theme_font_override("font", UI.font("display"))
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", UI.INK)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	pause_identity = _small(column, "")
	pause_records = Label.new()
	pause_records.add_theme_font_override("font", UI.font("smallnum"))
	pause_records.add_theme_font_size_override("font_size", 14)
	pause_records.add_theme_color_override("font_color", UI.INK)
	pause_records.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(pause_records)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 8)
	column.add_child(buttons)
	resume_button = _button(buttons, "Resume", func() -> void: game.set_paused(false))
	restart_button = _button(buttons, "Restart  R", func() -> void: game.restart_run())
	practice_button = _button(buttons, "Last checkpoint  F", func() -> void: game.practice_restart())
	quit_button = _button(buttons, "Quit", func() -> void: game.request_quit())
	current_map_button = _button(column, "Current map controls", _show_current_map_controls)
	current_map_button.name = "CurrentMapControls"
	var navigation := HFlowContainer.new()
	navigation.name = "PauseDestinations"
	navigation.add_theme_constant_override("h_separation", 8)
	navigation.add_theme_constant_override("v_separation", 8)
	column.add_child(navigation)
	for destination: String in ["Maps", "Practice", "Settings", "Runs"]:
		var tab := _button(navigation, destination, show_pause_destination.bind(destination))
		tab.name = "PauseTab_" + destination
		tab.toggle_mode = true
		pause_tabs[destination] = tab
	for destination: String in pause_tabs:
		var page := VBoxContainer.new()
		page.name = "PausePage_" + destination
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 9)
		column.add_child(page)
		pause_pages[destination] = page
	column = pause_pages["Maps"]
	map_heading = _heading(column, "Maps")
	map_grid = GridContainer.new()
	map_grid.name = "MapGrid"
	map_grid.add_theme_constant_override("h_separation", CARD_GAP)
	map_grid.add_theme_constant_override("v_separation", CARD_GAP)
	column.add_child(map_grid)
	_build_map_cards()
	_spacer(column)
	column = pause_pages["Practice"]
	_heading(column, "Checkpoint practice")
	practice_note = _small(column, "Start from any checkpoint. Practice attempts are recorded, never a best.")
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
	_heading(lab_box, "Movement Lab moves")
	_small(lab_box, "Experimental game choices. Changing one mid-run makes the attempt practice.")
	for id: String in LAB_WORDS:
		var switch := CheckButton.new()
		switch.name = "LabMove_" + id
		switch.text = "%s   ·   key %d" % [str(LAB_WORDS[id]), (["slide", "wall_jump", "grapple"] as Array).find(id) + 1]
		switch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		switch.toggled.connect(func(on: bool) -> void: game.set_mechanic(id, on))
		lab_box.add_child(switch)
		lab_switches[id] = switch
	_small(lab_box, "All three start on in the lab. Off means the key does nothing and the approved F2/F5 movement plays unchanged. Records keep each loadout apart.")
	_sync_lab_switches()
	_spacer(column)
	var settings_page: VBoxContainer = pause_pages["Settings"]
	var movement_options := VBoxContainer.new()
	movement_options.name = "MovementOptions"
	movement_options.add_theme_constant_override("separation", 9)
	settings_page.add_child(movement_options)
	column = movement_options
	_heading(column, "Movement")
	_small(column, "Switching keeps your position, speed and view.")
	var presets: Script = game.PRESETS
	for id: String in presets.PRIMARY:
		_preset_button(column, presets, id)
	advanced_toggle = Button.new()
	advanced_toggle.name = "AdvancedToggle"
	advanced_toggle.toggle_mode = true
	advanced_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	advanced_toggle.flat = true
	advanced_toggle.add_theme_color_override("font_pressed_color", UI.INK)
	advanced_toggle.add_theme_color_override("font_hover_pressed_color", UI.INK)
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
	var common_controls := VBoxContainer.new()
	common_controls.name = "CommonSettings"
	common_controls.add_theme_constant_override("separation", 9)
	settings_page.add_child(common_controls)
	settings_page.move_child(common_controls, 0)
	column = common_controls
	_heading(column, "Look and sound")
	pause_look = _small(column, "", INK)
	for item: Array in [["Source sensitivity (Source units, m_yaw 0.022)", "source_sensitivity", 0.2, 10.0, 0.05], ["Source FOV (4:3 reference, widened for the screen)", "source_fov", 70.0, 110.0, 1.0],
			["R13 mouse (× 0.0022 rad per count, advanced F3 only)", "r13_sensitivity", 0.3, 2.5, 0.05], ["R13 horizontal FOV (literal, F3 only)", "r13_fov", 70.0, 110.0, 1.0], ["Volume", "volume", 0.0, 1.0, 0.05]]:
		var setting_parent: Control = advanced_box if str(item[1]).begins_with("r13_") else column
		var label := Label.new()
		label.text = item[0]
		label.add_theme_font_override("font", UI.font("label"))
		label.add_theme_font_size_override("font_size", 13)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		setting_parent.add_child(label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		setting_parent.add_child(row)
		var slider := HSlider.new()
		var key := str(item[1])
		slider.name = "Setting_" + key
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = item[2]
		slider.max_value = item[3]
		slider.step = item[4]
		slider.value = game.settings[key]
		slider.focus_mode = Control.FOCUS_ALL
		row.add_child(slider)
		var number := _small(row, slider_value_text(key, slider.value))
		number.name = "Value_" + key
		number.size_flags_horizontal = Control.SIZE_SHRINK_END
		number.custom_minimum_size.x = 44
		slider.value_changed.connect(func(value: float) -> void:
			game.change_setting(key, value)
			number.text = slider_value_text(key, value)
			pause_look.text = str(game.call("look_description")))
		var default_value := float(game.DEFAULT_SETTINGS[key])
		var reset := _button(row, "Reset", func() -> void: slider.value = default_value)
		reset.name = "Reset_" + key
		reset.tooltip_text = "Reset to " + slider_value_text(key, default_value)
	var metric := CheckButton.new()
	metric.name = "Setting_show_ms"
	metric.text = "Show m/s under u/s"
	metric.button_pressed = game.settings.show_ms
	metric.toggled.connect(func(value: bool) -> void: game.change_setting("show_ms", value))
	column.add_child(metric)
	column = settings_page
	_small(column, "Speed is measured horizontal travel over the last 0.1 s (1 u = 0.0254 m); a crouch moving the body's height never counts as speed. Sync counts air ticks with one of A/D held while the view turns: good when it turns toward the key. No such ticks shows %s. Contact is speed that walls, lips and ramps changed in the air, kept apart from sync. Nothing here rates how efficient a strafe was." % NO_SAMPLES)
	_spacer(column)
	_heading(column, "Keys")
	pause_keys = _small(column, "", INK)
	show_pause_destination("Maps", false)
	pause_panel.hide()
	_layout_pause(get_viewport().get_visible_rect().size)

func _preset_button(parent: Control, presets: Script, id: String) -> void:
	super(parent, presets, id)
	var entry: Dictionary = presets.call("entry", id)
	var description := parent.get_child(parent.get_child_count() - 1) as Label
	description.name = "PresetDetails_" + id
	description.text = "%s · %d Hz · autohop · no stamina or takeoff clamp" % [str(entry.air), int(entry.rate)] if id in presets.PRIMARY else str(entry.summary)

func _show_current_map_controls() -> void:
	show_pause_destination("Practice")

func show_pause_destination(destination: String, focus_tab: bool = true) -> void:
	if not pause_pages.has(destination):
		return
	pause_destination = destination
	for id: String in pause_pages:
		(pause_pages[id] as Control).visible = id == destination
		(pause_tabs[id] as Button).set_pressed_no_signal(id == destination)
	_pause_scroll.scroll_vertical = 0
	if focus_tab:
		(pause_tabs[destination] as Button).grab_focus()

static func slider_value_text(key: String, value: float) -> String:
	if key == "volume":
		return "%d %%" % roundi(value * 100.0)
	if key.ends_with("fov"):
		return "%d°" % roundi(value)
	return "%.2f" % value

func _show_advanced(on: bool) -> void:
	super(on)
	if advanced_toggle != null:
		advanced_toggle.text = "%s  Advanced (comparison presets and R13 look)" % ("▾" if on else "▸")

func _spacer(parent: Control) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gap)

func _build_map_cards() -> void:
	super()
	for id: String in map_buttons:
		(map_buttons[id] as Button).custom_minimum_size = Vector2(CARD_MIN_WIDTH, CARD_HEIGHT + 4.0)
		var entry: Dictionary = game.call("map_entry", id)
		if str(entry.get("kind", "")) == "legacy":
			(map_buttons[id] as Button).text = "%s\n%s" % [str(entry.name), str(entry.theme)]
	if map_heading != null:
		map_heading.text = "Maps"
	if map_note != null:
		map_note.text = "%d maps. Each starts at its spawn and keeps your preset." % map_buttons.size()

func _refresh_pause() -> void:
	super()
	(pause_panel.find_child("PauseHeading", true, false) as Label).text = str(game.call("map_name"))
	pause_kicker.text = "Paused  ·  %s" % str(game.preset.label) + ("  ·  Experimental" if bool(game.call("is_lab")) else "")
	pause_identity.visible = telemetry
	map_heading.text = "Maps"
	map_note.text = "%d maps. Each starts at its spawn and keeps your preset." % map_buttons.size()
	if ghost_switch != null:
		ghost_switch.text = "Ghost of your fastest clean run%s" % ("  (G)" if not ghost_key_missing() else "")
		ghost_state_label.text = ghost_menu_state()
	if recording_line != null and not telemetry:
		var rec := str(game.session.call("recording_text"))
		recording_line.text = ("Every attempt is recorded on this machine (r16_runs). F9 shows the folder." if rec.begins_with("Recording every") else rec)
	pause_keys.text = keys_line.text + "  ·  L look  ·  F9 telemetry  ·  F11 fullscreen"

func set_paused(value: bool) -> void:
	super(value)
	if value:
		_title_dismissed = true

func preset_changed() -> void:
	super()
	if map_title != null:
		_layout()

# --- finish -------------------------------------------------------------------------------------

func _make_finish() -> void:
	super()
	finish_panel.color = Color(0, 0, 0, 0)
	(finish_panel.get_child(0) as Control).visible = false
	finish_card = PanelContainer.new()
	finish_card.name = "FinishCard"
	finish_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet := UI.flat(Color(UI.CREAM, 0.97), 3, Vector4(26, 20, 28, 22))
	sheet.border_color = UI.EDGE
	sheet.border_width_left = 5
	finish_card.add_theme_stylebox_override("panel", sheet)
	finish_panel.add_child(finish_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finish_card.add_child(column)
	_finish_kicker = _card_label(column, "label", 13, UI.INK_SOFT)
	_finish_time = _card_label(column, "display", 56, UI.INK)
	_finish_time.add_theme_constant_override("line_spacing", -8)
	_finish_result = _card_label(column, "title", 17, UI.SEA_DEEP)
	_finish_meta = _card_label(column, "body", 12, UI.INK_SOFT)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	column.add_child(gap)
	_finish_style = _card_label(column, "label", 15, UI.INK)
	_finish_ghost = _card_label(column, "body", 13, UI.INK_SOFT)
	var rule := ColorRect.new()
	rule.color = Color(UI.INK, 0.16)
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)
	_finish_splits = GridContainer.new()
	_finish_splits.columns = 3
	_finish_splits.add_theme_constant_override("h_separation", 22)
	_finish_splits.add_theme_constant_override("v_separation", 2)
	column.add_child(_finish_splits)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 6)
	column.add_child(gap2)
	_finish_footer = _card_label(column, "body", 12, UI.INK)
	_finish_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_finish_footer.custom_minimum_size.x = 380

func _card_label(parent: Control, role: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI.font(role))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func show_finish(is_best: bool, is_open_best: bool) -> void:
	super(is_best, is_open_best)
	var kind := str(game.finish_kind)
	_finish_kicker.text = {"clean": "Finish  ·  clean run", "open": "Finish  ·  open line"}.get(kind, "Practice finish")
	_finish_time.text = _time(float(game.elapsed))
	var result := ""
	var color := UI.INK
	match kind:
		"clean":
			var before := float(game.previous_best)
			if is_best:
				result = "First clean run with this preset" if before <= 0.0 else "New best  %s" % _delta(float(game.elapsed) - before)
				color = UI.SEA_DEEP
			else:
				var gap := float(game.elapsed) - float(game.best_time)
				result = "%s  vs best %s" % [_delta(gap), _time(float(game.best_time))]
				color = UI.CORAL_DEEP if gap > 0.0 else UI.SEA_DEEP
		"open":
			result = ("New open line best" if is_open_best else "Open line best %s" % _time(float(game.open_best_time))) + "\nA checkpoint was skipped, so not a full-course time"
		_:
			result = "No best (%s)  ·  R starts a clean run" % _reason(str(game.practice_reason))
			color = UI.INK_SOFT
	_finish_result.text = result
	_finish_result.add_theme_color_override("font_color", color)
	_finish_meta.text = "%s  ·  %s  ·  %d Hz" % [game.call("map_name"), str(game.preset.label), int(game.physics_hz)]
	_finish_style.text = style_finish_line()
	_finish_ghost.text = ghost_finish_line()
	_finish_ghost.visible = not _finish_ghost.text.is_empty()
	for child: Node in _finish_splits.get_children():
		_finish_splits.remove_child(child)
		child.queue_free()
	for i: int in game.stage_times.size():
		var name := str(game.call("segment_title", i))
		var segment: float = game.call("segment_time", i)
		var time_text := ""
		var delta_text := ""
		var delta_color := UI.INK_SOFT
		if float(game.stage_times[i]) < 0.0:
			if kind == "practice" and int(game.practice_stage) > i:
				continue
			time_text = "skipped"
		else:
			time_text = _time(segment) if segment >= 0.0 else "at " + _time(float(game.stage_times[i]))
			if kind == "clean" and i < game.split_deltas.size() and is_finite(game.split_deltas[i]):
				delta_text = _delta(game.split_deltas[i])
				delta_color = UI.SEA_DEEP if game.split_deltas[i] <= 0.0 else UI.CORAL_DEEP
		_card_label(_finish_splits, "body", 14, UI.INK).text = name
		var t := _card_label(_finish_splits, "smallnum", 14, UI.INK)
		t.text = time_text
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var d := _card_label(_finish_splits, "smallnum", 14, delta_color)
		d.text = delta_text
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_finish_footer.text = "R  run again    F  practise from %s    F2 / F5  preset    G  ghost    Esc  maps" % game.call("stage_title", int(game.checkpoint_index))
	finish_card.reset_size()
	finish_panel.size = finish_card.size
	_layout()

# --- host hooks ---------------------------------------------------------------------------------

## the r17 host's look label is telemetry, with the same title and pause suppression.
func place_look_label(label: Label) -> void:
	if not label.has_meta("r18_styled"):
		UI.world_label(label, "small", 12, Color(UI.CREAM, 0.86), 3)
		label.set_meta("r18_styled", true)
	var frame := UI.safe_frame(get_viewport().get_visible_rect().size)
	label.reset_size()
	label.position = Vector2(frame.end.x - 32.0 - label.get_minimum_size().x, 24.0)
	label.visible = telemetry and visible and _title_alpha <= 0.0 and game != null and not bool(game.paused)
	label.modulate.a = 1.0

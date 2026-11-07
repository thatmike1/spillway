extends CanvasLayer
## p / r13 overflow hud. the course stays in view: speed and time sit low on the left, a
## split shows briefly where it happens, the finish is a compact card beside the course, and
## the route reminder appears only for a first clear, practice or a recovery. stage names
## come from the level, so a course revision with other stages needs no change here.

const INK := Color("f4f1dd")
const ACCENT := Color("f3cd83")
const AHEAD := Color("9fd8c4")
const BEHIND := Color("eaa17f")
const SHADE := Color(0.055, 0.10, 0.12)
const CONTROLS_SHORT := "WASD run · mouse look · Space jump, hold to keep hopping\nIn the air, keys bend your flight where they point; no keys keeps your line\nS brakes · R restart · F practise stage · Esc pause"
const CONTROLS_FULL := "WASD run. Mouse looks. Space jumps; hold it to keep hopping.\nHeight turns into speed, and clean hops keep it.\nIn the air W bends your flight toward the view, A and D toward that side.\nLet go of the keys to keep your line and look around freely.\nA or D held while the mouse turns the same way carves a little speed.\nS brakes. Ctrl or C ducks. F11 fullscreen.\nR restarts a clean run. F practises from the last stage you reached."

var game: Node
var overlay: Control
var title: Label
var subtitle: Label
var controls: Label
var speed_label: Label
var speed_unit: Label
var clock: Label
var best_line: Label
var hint: Label
var split_label: Label
var practice_tag: Label
var message: Label
var finish_panel: ColorRect
var finish_title: Label
var finish_body: Label
var finish_footer: Label
var pause_panel: Control
var _pause_side: ColorRect
var pause_identity: Label
var pause_records: Label
var resume_button: Button
var restart_button: Button
var practice_button: Button
var quit_button: Button
var _fade: ColorRect
var _intro_shade: ColorRect
var _stats_shade: ColorRect
var _blink_alpha: float = 0.0
var _intro_alpha: float = 1.0
var _intro_hold: bool = true
var _split_time: float = 0.0
var _message_time: float = 0.0
var _hint_alpha: float = 0.0

func _label(text: String, size: int, position: Vector2, color: Color = INK, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.12, 0.14, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else overlay).add_child(label)
	return label

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
	# a soft shade keeps the intro readable over bright concrete and sky.
	_intro_shade = ColorRect.new()
	_intro_shade.color = Color(SHADE, 0.38)
	_intro_shade.position = Vector2(30, 24)
	_intro_shade.size = Vector2(640, 178)
	_intro_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_intro_shade)
	title = _label("SPILLWAY", 46, Vector2(42, 30))
	subtitle = _label("%s  ·  R13" % str(game.COURSE_NAME).to_upper(), 15, Vector2(45, 84), ACCENT)
	controls = _label(CONTROLS_SHORT, 16, Vector2(44, 118))
	_stats_shade = ColorRect.new()
	_stats_shade.color = Color(SHADE, 0.34)
	_stats_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_stats_shade)
	speed_label = _label("0.0", 38, Vector2(40, 0))
	speed_unit = _label("m/s", 15, Vector2(0, 0), Color(INK, 0.75))
	clock = _label("00:00.00", 22, Vector2(0, 0))
	best_line = _label("", 14, Vector2(0, 0), Color(INK, 0.75))
	hint = _label("", 17, Vector2(42, 0), Color(INK, 0.9))
	split_label = _label("", 24, Vector2(0, 0))
	practice_tag = _label("", 15, Vector2(0, 26), ACCENT)
	message = _label("", 18, Vector2(0, 0), INK)
	# bright concrete sits behind most of the course: transient text gets a light backing.
	for label: Label in [hint, split_label, message]:
		_backing(label, 0.34)
	_make_finish()
	_make_pause()
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.08, 0.09, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_fade)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	speed_label.position = Vector2(40, size.y - 70)
	speed_unit.position = Vector2(40 + speed_label.get_minimum_size().x + 6, size.y - 50)
	clock.position = Vector2(170, size.y - 64)
	_stats_shade.position = Vector2(30, size.y - 74)
	_stats_shade.size = Vector2(maxf(250.0, 182.0 + maxf(clock.get_minimum_size().x, best_line.get_minimum_size().x)), 62)
	best_line.position = Vector2(172, size.y - 36)
	hint.position = Vector2(42, size.y - 108)
	message.position = Vector2(42, size.y - 140)
	split_label.position = Vector2(size.x * 0.5 - split_label.get_minimum_size().x * 0.5, size.y * 0.68)
	practice_tag.position = Vector2(size.x - practice_tag.get_minimum_size().x - 32, 26)
	finish_panel.position = Vector2(30, maxf(150.0, size.y * 0.5 - finish_panel.size.y * 0.5))
	pause_panel.size = size
	_pause_side.size = Vector2(minf(560.0, size.x), size.y)
	_fade.size = size

func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	_blink_alpha = move_toward(_blink_alpha, 0.0, delta * 8.0)
	_fade.color.a = _blink_alpha
	# the intro holds until the first move and a few seconds after it, then gives way.
	if bool(game.get("_started")) and float(game.elapsed) > 4.0:
		_intro_hold = false
	_intro_alpha = move_toward(_intro_alpha, 1.0 if _intro_hold else 0.0, delta * (4.0 if _intro_hold else 0.8))
	for item: CanvasItem in [title, subtitle, controls, _intro_shade]:
		item.modulate.a = _intro_alpha
	speed_label.text = "%.1f" % float(game.display_speed)
	clock.text = _time(float(game.elapsed))
	if not bool(game.clean_eligible):
		best_line.text = "practice · not recorded"
	elif float(game.best_time) > 0.0:
		best_line.text = "best %s" % _time(float(game.best_time))
	elif float(game.open_best_time) > 0.0:
		best_line.text = "open line %s" % _time(float(game.open_best_time))
	else:
		best_line.text = "first run"
	practice_tag.text = "" if bool(game.clean_eligible) else "PRACTICE  ·  R for a clean run"
	_split_time = maxf(0.0, _split_time - delta)
	split_label.modulate.a = minf(1.0, _split_time * 1.5)
	_message_time = maxf(0.0, _message_time - delta)
	message.modulate.a = minf(1.0, _message_time * 1.5)
	var text := _hint_text()
	if not text.is_empty():
		hint.text = text
	_hint_alpha = move_toward(_hint_alpha, 0.0 if text.is_empty() or _message_time > 0.0 else 0.9, delta * 3.0)
	hint.modulate.a = _hint_alpha
	_layout()

## the route reminder, or empty: shown for a first clear, in practice and whenever the level's
## hint for where the runner stands differs from its stage's ordinary hint (a recovery).
func _hint_text() -> String:
	if bool(game.finished) or not game.level.has_method("route_hint"):
		return ""
	var stage := int(game.checkpoint_index)
	var feet: Vector3 = game.player.global_position
	var here := str(game.level.call("route_hint", stage, feet))
	var points: Array = game.level.get("checkpoints")
	var usual := here
	if stage < points.size():
		usual = str(game.level.call("route_hint", stage, ((points[stage] as Dictionary)["pose"] as Transform3D).origin))
	if here != usual or float(game.best_time) <= 0.0 or not bool(game.clean_eligible):
		return here
	return ""

func run_started() -> void:
	finish_panel.hide()
	split_label.text = ""
	_split_time = 0.0
	_message_time = 0.0
	# the full intro returns on a new run only until the course has a clean time.
	if float(game.best_time) <= 0.0:
		_intro_hold = true

func practice_started(stage_title: String) -> void:
	finish_panel.hide()
	_intro_hold = false
	notify("Practice from %s" % stage_title)

func respawned(stage_title: String) -> void:
	_blink_alpha = 1.0
	notify("Back to %s · practice" % stage_title)

func notify(text: String) -> void:
	message.text = text
	_message_time = 0.0 if text.is_empty() else 2.5

## a stage boundary was reached: its run time and the comparison that means something here.
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
	else:
		var segment_time: float = game.call("segment_time", segment)
		var best: float = game.best_segments[segment] if segment < game.best_segments.size() else -1.0
		if segment_time > 0.0 and best > 0.0:
			line += "   %s vs best segment" % _delta(segment_time - best)
			color = AHEAD if segment_time <= best else BEHIND
	split_label.text = line
	split_label.add_theme_color_override("font_color", color)
	_split_time = 2.6

func show_finish(is_best: bool, is_open_best: bool) -> void:
	_split_time = 0.0
	_message_time = 0.0
	split_label.text = ""
	var kind := str(game.finish_kind)
	finish_title.text = "%s  %s" % ["WATER RUNNING" if kind != "practice" else "PRACTICE FINISH", _time(float(game.elapsed))]
	var lines: Array[String] = []
	match kind:
		"clean":
			var before := float(game.previous_best)
			if is_best:
				lines.append("First clean run · this is your time to beat" if before <= 0.0 else "New best  %s" % _delta(float(game.elapsed) - before))
			else:
				lines.append("%s vs best %s" % [_delta(float(game.elapsed) - float(game.best_time)), _time(float(game.best_time))])
		"open":
			lines.append("Open line · a stage was skipped, so not a full-course time")
			lines.append("New open line best" if is_open_best else "Open line best %s" % _time(float(game.open_best_time)))
		_:
			lines.append("Not recorded · R starts a clean run")
	lines.append("")
	var previous_best := 0.0
	for i: int in game.stage_times.size():
		var name := str(game.call("segment_title", i))
		var segment: float = game.call("segment_time", i)
		if float(game.stage_times[i]) < 0.0:
			if kind == "practice" and int(game.practice_stage) > i:
				continue
			lines.append("%s   skipped" % name)
			continue
		# after a skip the segment has no start: name the arrival time instead of a segment time.
		var line := "%s   %s" % [name, _time(segment) if segment >= 0.0 else "reached at " + _time(float(game.stage_times[i]))]
		if kind == "clean" and i < game.split_deltas.size() and is_finite(game.split_deltas[i]):
			line += "   %s" % _delta(game.split_deltas[i])
		elif kind == "practice" and segment > 0.0 and i < game.best_segments.size() and float(game.best_segments[i]) > 0.0:
			line += "   %s" % _delta(segment - float(game.best_segments[i]))
		lines.append(line)
	if kind == "clean" and float(game.open_best_time) > 0.0 and float(game.open_best_time) < float(game.best_time) - 0.0005:
		lines.append("")
		lines.append("Open line best %s" % _time(float(game.open_best_time)))
	finish_body.text = "\n".join(lines)
	finish_footer.text = "R  run again     F  practise %s     or keep moving and look round" % game.call("stage_title", int(game.checkpoint_index))
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
	finish_title = _label("", 30, Vector2.ZERO, INK, column)
	finish_body = _label("", 17, Vector2.ZERO, INK, column)
	finish_footer = _label("", 15, Vector2.ZERO, ACCENT, column)
	finish_panel.hide()

func _make_pause() -> void:
	pause_panel = Control.new()
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(pause_panel)
	var side := ColorRect.new()
	side.color = Color(SHADE, 0.93)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel.add_child(side)
	_pause_side = side
	var dim := ColorRect.new()
	dim.color = Color(SHADE, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	pause_panel.move_child(dim, 0)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(56, 40)
	scroll.size = Vector2(470, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(440, 0)
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	var heading := Label.new()
	heading.text = "SPILLWAY R13  ·  %s" % str(game.COURSE_NAME).to_upper()
	heading.add_theme_font_size_override("font_size", 27)
	column.add_child(heading)
	pause_identity = Label.new()
	pause_identity.add_theme_font_size_override("font_size", 12)
	pause_identity.add_theme_color_override("font_color", Color(INK, 0.7))
	column.add_child(pause_identity)
	pause_records = Label.new()
	pause_records.add_theme_font_size_override("font_size", 15)
	pause_records.add_theme_color_override("font_color", ACCENT)
	column.add_child(pause_records)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	resume_button = _button(buttons, "Resume", func() -> void: game.set_paused(false))
	restart_button = _button(buttons, "Restart  R", func() -> void: game.restart_run())
	practice_button = _button(buttons, "Practise  F", func() -> void: game.practice_restart())
	quit_button = _button(buttons, "Quit", func() -> void: game.request_quit())
	for item: Array in [["Mouse sensitivity", "sensitivity", 0.3, 2.5, 0.05], ["Horizontal field of view", "fov", 75.0, 110.0, 1.0], ["Volume", "volume", 0.0, 1.0, 0.05]]:
		var label := Label.new()
		label.text = item[0]
		label.add_theme_font_size_override("font_size", 14)
		column.add_child(label)
		var slider := HSlider.new()
		slider.name = "Setting_" + str(item[1])
		slider.min_value = item[2]
		slider.max_value = item[3]
		slider.step = item[4]
		slider.value = game.settings[item[1]]
		slider.value_changed.connect(func(value: float) -> void: game.change_setting(str(item[1]), value))
		column.add_child(slider)
	for item: Array in [["Comfort camera (less landing dip, no speed FOV)", "comfort"], ["Autohop (hold Space to keep hopping)", "autohop"]]:
		var toggle := CheckButton.new()
		toggle.name = "Setting_" + str(item[1])
		toggle.text = item[0]
		toggle.button_pressed = game.settings[item[1]]
		toggle.toggled.connect(func(value: bool) -> void: game.change_setting(str(item[1]), value))
		column.add_child(toggle)
	var help := Label.new()
	help.text = CONTROLS_FULL
	help.add_theme_font_size_override("font_size", 13)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(440, 0)
	column.add_child(help)
	pause_panel.hide()

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func set_paused(value: bool) -> void:
	pause_panel.visible = value
	# a finish card stays beside the course, never under the settings.
	finish_panel.modulate.a = 0.0 if value else 1.0
	if value:
		pause_identity.text = "build %s  ·  course %s  ·  records %s" % [game.BUILD_ID, str(game.course_key).left(8), game.profile_state]
		var records: Array[String] = []
		records.append("Best %s" % _time(float(game.best_time)) if float(game.best_time) > 0.0 else "No clean finish yet")
		if float(game.open_best_time) > 0.0:
			records.append("open line %s" % _time(float(game.open_best_time)))
		pause_records.text = "  ·  ".join(records)
		practice_button.text = "Practise %s  F" % game.call("stage_title", int(game.checkpoint_index))
		resume_button.grab_focus()

func _time(value: float) -> String:
	return "%02d:%05.2f" % [int(value) / 60, fmod(value, 60.0)]

func _delta(value: float) -> String:
	if absf(value) < 0.005:
		return "±0.00"
	return "%s%.2f" % ["+" if value > 0.0 else "-", absf(value)]

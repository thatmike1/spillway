extends CanvasLayer
## Minimal overlay: timer, a reticle dot, a title card that leaves once you
## move, a pause panel with comfort settings, and the finish card.

signal resume_requested
signal restart_requested
signal quit_requested
signal setting_changed(key: String, value: Variant)

const AMBER: Color = Color("#F3AE52")
const TEXT: Color = Color(0.92, 0.95, 0.98)
const PANEL_BG: Color = Color(0.047, 0.067, 0.094, 0.94)

var _timer: Label
var _best: Label
var _message: Label
var _title: Control
var _pause: Control
var _finish: Control
var _finish_time: Label
var _finish_best: Label
var _fade: ColorRect
var _controls: Dictionary = {}
var _message_time: float = 0.0
var _title_fade: float = -1.0
var _fade_time: float = -1.0
var _finished: bool = false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.04, 0.06, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_timer = _label("00:00.00", 30)
	_timer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_timer.position = Vector2(-200, 22)
	_timer.size = Vector2(170, 40)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_timer)
	_best = _label("", 15)
	_best.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_best.position = Vector2(-200, 60)
	_best.size = Vector2(170, 24)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_best.modulate = Color(1, 1, 1, 0.6)
	root.add_child(_best)
	var dot: ColorRect = ColorRect.new()
	dot.color = Color(1, 1, 1, 0.75)
	dot.size = Vector2(4, 4)
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(2, 2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot)
	_message = _label("", 20)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_message.position = Vector2(-400, -110)
	_message.size = Vector2(800, 32)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_message)
	_title = _make_title(root)
	_pause = _make_pause(root)
	_finish = _make_finish(root)


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		_message.modulate.a = clampf(_message_time / 0.6, 0.0, 1.0)
	if _title_fade >= 0.0:
		_title_fade += delta
		_title.modulate.a = clampf(1.0 - _title_fade / 1.2, 0.0, 1.0)
		if _title_fade > 1.2:
			_title.visible = false
			_title_fade = -1.0
	if _fade_time >= 0.0:
		_fade_time += delta
		# a short dip to dark and back, never a white flash
		var t: float = _fade_time / 0.42
		_fade.color.a = clampf(sin(clampf(t, 0.0, 1.0) * PI) * 1.4, 0.0, 0.92)
		if t >= 1.0:
			_fade_time = -1.0
			_fade.color.a = 0.0


# ---------------------------------------------------------------- called by main

func update_state(elapsed: float, _speed: float) -> void:
	if not _finished:
		_timer.text = format_time(elapsed)


func reset_run(best: float) -> void:
	_finished = false
	_finish.visible = false
	_title.visible = true
	_title.modulate.a = 1.0
	_title_fade = -1.0
	_timer.text = format_time(0.0)
	_best.text = "best " + format_time(best) if best > 0.0 else ""


func hide_title() -> void:
	if _title.visible and _title_fade < 0.0:
		_title_fade = 0.0


func flash_message(text: String) -> void:
	_message.text = text
	_message_time = 2.2


func fade_blink() -> void:
	_fade_time = 0.0


func set_paused(paused: bool) -> void:
	_pause.visible = paused
	if paused:
		(_controls["resume"] as Button).grab_focus()


func show_finish(seconds: float, best: float, is_best: bool) -> void:
	_finished = true
	_timer.text = format_time(seconds)
	_best.text = "best " + format_time(best)
	_finish_time.text = format_time(seconds)
	_finish_best.text = "New best" if is_best else "Best " + format_time(best)
	_finish.visible = true


func load_settings(values: Dictionary) -> void:
	for key: String in values.keys():
		if not _controls.has(key):
			continue
		var control: Control = _controls[key]
		if control is Range:
			(control as Range).set_value_no_signal(float(values[key]))
		elif control is CheckButton:
			(control as CheckButton).set_pressed_no_signal(bool(values[key]))


# ---------------------------------------------------------------- building blocks

func _label(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel(root: Control, width: float, height: float) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(width, height)
	panel.position = Vector2(-width * 0.5, -height * 0.5)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = Color(AMBER, 0.55)
	style.border_width_left = 3
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	return column


func _make_title(root: Control) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	box.position = Vector2(56, -40)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)
	var title: Label = _label("FOLDRUNNER", 44)
	title.add_theme_color_override("font_color", AMBER)
	box.add_child(title)
	box.add_child(_label("Look around. Run when you are ready.", 18))
	var keys: Label = _label("Mouse / arrows look   WASD run   Space jump   Ctrl slide   R restart   Esc pause", 14)
	keys.modulate = Color(1, 1, 1, 0.7)
	box.add_child(keys)
	return box


func _make_pause(root: Control) -> Control:
	var holder: Control = Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(holder)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shade)
	var column: VBoxContainer = _panel(holder, 460, 560)
	var heading: Label = _label("Paused", 28)
	column.add_child(heading)
	var resume: Button = _button("Resume", func() -> void: resume_requested.emit())
	_controls["resume"] = resume
	column.add_child(resume)
	column.add_child(_button("Restart run   (R)", func() -> void: restart_requested.emit()))
	column.add_child(_slider("Mouse sensitivity", "sensitivity", 0.3, 3.0, 0.05))
	column.add_child(_slider("Field of view at 16:9", "fov", 80.0, 105.0, 1.0))
	column.add_child(_slider("Camera bank on wall-runs", "bank", 0.0, 1.0, 0.05))
	column.add_child(_slider("Volume", "volume", 0.0, 1.0, 0.05))
	column.add_child(_toggle("Speed FOV (Foldrunner extension)", "speed_fov"))
	column.add_child(_toggle("Jump grace (Foldrunner extension)", "assists"))
	column.add_child(_toggle("Runner vision", "runner_vision"))
	column.add_child(_toggle("Head bob", "head_bob"))
	column.add_child(_toggle("Invert look", "invert_y"))
	column.add_child(_button("Quit", func() -> void: quit_requested.emit()))
	holder.visible = false
	return holder


func _make_finish(root: Control) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.position = Vector2(-220, -150)
	box.custom_minimum_size = Vector2(440, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	root.add_child(box)
	var head: Label = _label("ROUTE COMPLETE", 18)
	head.add_theme_color_override("font_color", AMBER)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	_finish_time = _label("00:00.00", 64)
	_finish_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_finish_time)
	_finish_best = _label("", 18)
	_finish_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_finish_best)
	var again: Label = _label("R to run it again", 16)
	again.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	again.modulate = Color(1, 1, 1, 0.7)
	box.add_child(again)
	box.visible = false
	return box


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.pressed.connect(action)
	return button


func _slider(text: String, key: String, low: float, high: float, step: float) -> Control:
	var row: VBoxContainer = VBoxContainer.new()
	var caption: Label = _label(text, 14)
	row.add_child(caption)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size.y = 20
	slider.value_changed.connect(func(value: float) -> void: setting_changed.emit(key, value))
	row.add_child(slider)
	_controls[key] = slider
	return row


func _toggle(text: String, key: String) -> Control:
	var toggle: CheckButton = CheckButton.new()
	toggle.text = text
	toggle.toggled.connect(func(value: bool) -> void: setting_changed.emit(key, value))
	_controls[key] = toggle
	return toggle


static func format_time(seconds: float) -> String:
	var centiseconds: int = maxi(0, roundi(seconds * 100.0))
	return "%02d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]

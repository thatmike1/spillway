extends CanvasLayer

signal restart_requested
signal resume_requested
signal comfort_changed(value: float)

var _speed: Label
var _timer: Label
var _objective: Label
var _message: Label
var _pause_panel: PanelContainer
var _pause_title: Label
var _resume_button: Button
var _comfort_slider: HSlider
var _message_remaining: float = 0.0
var _finished: bool = false

func _ready() -> void:
	layer = 10
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	var title: Label = _label("F O L D R U N N E R", 20)
	title.add_theme_color_override("font_color", Color(1, 0.69, 0.4))
	top.add_child(title)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_timer = _label("00:00.00", 22)
	top.add_child(_timer)
	_objective = _label("Follow the light", 17)
	column.add_child(_objective)
	var vertical_spacer: Control = Control.new()
	vertical_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(vertical_spacer)
	_message = _label("Click to begin", 22)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	_speed = _label("0 km/h", 20)
	column.add_child(_speed)
	column.add_child(_label("WASD move   Shift sprint   Space jump / vault   Ctrl crouch   R restart   Esc pause", 13))
	var reticle: Label = _label("·", 25)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-4, -18)
	root.add_child(reticle)
	_create_pause(root)

func update_state(speed: float, progress: String, elapsed: float) -> void:
	if not is_instance_valid(_speed):
		return
	_speed.text = "%d km/h" % roundi(speed * 3.6)
	_objective.text = progress
	if not _finished:
		_timer.text = _format_time(elapsed)

func show_message(text: String) -> void:
	if is_instance_valid(_message):
		_message.text = text
		_message_remaining = 4.0

func set_paused(paused: bool) -> void:
	if not is_instance_valid(_pause_panel):
		return
	_pause_panel.visible = paused
	if paused and not _finished:
		_pause_title.text = "Take a breath"
		_resume_button.text = "Continue"
		_resume_button.grab_focus()
	if not paused:
		_finished = false

func set_finished(seconds: float) -> void:
	_finished = true
	_timer.text = _format_time(seconds)
	_pause_title.text = "Back under open sky"
	_resume_button.text = "Explore the rooftop"
	_pause_panel.visible = true
	_message.text = "Route completed · %s" % _format_time(seconds)
	_message_remaining = 0.0

func reset_run() -> void:
	_finished = false
	_timer.text = "00:00.00"
	_pause_panel.hide()
	show_message("Follow the light")

func set_comfort(value: float) -> void:
	if is_instance_valid(_comfort_slider):
		_comfort_slider.set_value_no_signal(clampf(value, 0.0, 1.0))

func _process(delta: float) -> void:
	if _message_remaining > 0.0:
		_message_remaining -= delta
		if _message_remaining <= 0.0:
			_message.text = ""

func _create_pause(root: Control) -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.name = "PausePanel"
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause_panel.position = Vector2(-210, -220)
	_pause_panel.custom_minimum_size = Vector2(420, 440)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.09, 0.97)
	style.border_color = Color(0.36, 0.42, 0.49)
	style.set_border_width_all(1)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	_pause_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_pause_panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	_pause_panel.add_child(content)
	_pause_title = _label("Take a breath", 26)
	content.add_child(_pause_title)
	var help: Label = _label("Follow the amber marks.\nKeep your momentum when the city turns.\nClick to capture the mouse; Escape releases it.", 15)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(help)
	_resume_button = Button.new()
	_resume_button.text = "Continue"
	_resume_button.custom_minimum_size.y = 44
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	content.add_child(_resume_button)
	var restart: Button = Button.new()
	restart.text = "Start again"
	restart.custom_minimum_size.y = 44
	restart.pressed.connect(func() -> void: restart_requested.emit())
	content.add_child(restart)
	content.add_child(_label("Camera roll", 16))
	var slider: HSlider = HSlider.new()
	_comfort_slider = slider
	slider.name = "ComfortSlider"
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = 0.65
	slider.value_changed.connect(func(value: float) -> void: comfort_changed.emit(value))
	content.add_child(slider)
	content.add_child(_label("Gentle                         Full rotation", 13))
	_pause_panel.hide()

func _label(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.91, 0.94, 0.97))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _format_time(seconds: float) -> String:
	var centiseconds: int = maxi(0, roundi(seconds * 100.0))
	return "%02d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]

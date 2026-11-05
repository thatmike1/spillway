extends CanvasLayer
## p / the course remains visible; timing becomes prominent only at the finish.
var game: Node
var overlay: Control
var title: Label
var subtitle: Label
var status: Label
var speed_label: Label
var timing: Label
var message: Label
var finish_label: Label
var pause_panel: ColorRect
var _resume_button: Button
var _fade: ColorRect
var _blink_alpha: float = 0.0
var _message_time: float = 0.0
var _title_alpha: float = 1.0

func _label(text: String, size: int, position: Vector2, color: Color = Color("f4f1dd")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.12, 0.14, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(label)
	return label

func attach(main: Node) -> void:
	game = main
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	title = _label("SPILLWAY", 46, Vector2(42, 32))
	subtitle = _label("THE LONG WAY DOWN", 14, Vector2(45, 86), Color("f3cd83"))
	status = _label("WASD run    Space jump    Ctrl / C slide\nR new run    F segment practice    Esc settings", 17, Vector2(44, 127))
	speed_label = _label("", 19, Vector2(42, 640))
	timing = _label("", 15, Vector2(42, 673))
	message = _label("", 20, Vector2(42, 572))
	finish_label = _label("", 27, Vector2(42, 215))
	_make_pause()
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.08, 0.09, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_fade)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	speed_label.position.y = size.y - 77.0
	timing.position.y = size.y - 44.0
	message.position.y = size.y - 125.0
	pause_panel.size = size
	_fade.size = size

func _process(delta: float) -> void:
	if game == null:
		return
	_blink_alpha = move_toward(_blink_alpha, 0.0, delta * 8.0)
	_fade.color.a = _blink_alpha
	var speed: float = game.player.get_speed()
	if game.elapsed < 0.15:
		_title_alpha = 1.0
	elif game.elapsed > 3.0:
		_title_alpha = move_toward(_title_alpha, 0.0, delta * 0.65)
	title.modulate.a = _title_alpha
	subtitle.modulate.a = _title_alpha
	status.modulate.a = _title_alpha
	speed_label.text = "%02d  km/h%s" % [roundi(speed * 3.6), "  /  SLIDE" if game.player.mode == "slide" else ""]
	timing.text = "PRACTICE · R starts a clean run" if not game.clean_eligible else ("BEST  %s" % _time(game.best_time) if game.best_time > 0.0 else "")
	if game.finish_kind == "exploration":
		timing.text = "EXPLORATION · R starts a clean run"
	_message_time = maxf(0.0, _message_time - delta)
	message.modulate.a = minf(1.0, _message_time)
	if not game.finished:
		finish_label.text = ""

func notify(text: String) -> void:
	message.text = text
	_message_time = 3.0

func show_finish(is_best: bool) -> void:
	var text := "WATER RUNNING.  %s" % _time(game.elapsed)
	if game.finish_kind == "exploration":
		text += "\nEXPLORATION FINISH · NOT RECORDED"
	else:
		text += "\nNEW CLEAN BEST" if is_best else ("\nPRACTICE FINISH" if not game.clean_eligible else "\nRUN COMPLETE")
	var last: float = 0.0
	for i: int in game.splits.size():
		text += "\n%s   %s" % [["Crest", "Sluice yard", "Outflow"][mini(i, 2)], _time(game.splits[i] - last)]
		if i < game.split_deltas.size() and is_finite(game.split_deltas[i]):
			text += "   %+.2f vs segment best" % game.split_deltas[i]
		last = game.splits[i]
	# p / skipped stages are named plainly instead of receiving invented splits.
	var points: Array = game.level.get("checkpoints")
	for i: int in range(game.checkpoint_index + 1, points.size()):
		text += "\nSkipped %s · %s" % [points[i].get("title", "a stage"), points[i].get("hint", "no split")]
	if game.finish_kind == "exploration":
		text += "\nUnrecorded: no best saved, no split for a skipped stage"
	text += "\n\nR to take another line · keep moving to explore"
	finish_label.text = text

func _time(value: float) -> String:
	return "%02d:%05.2f" % [int(value) / 60, fmod(value, 60.0)]

func _make_pause() -> void:
	pause_panel = ColorRect.new()
	pause_panel.color = Color(0.055, 0.10, 0.12, 0.94)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(pause_panel)
	var column := VBoxContainer.new()
	column.position = Vector2(70, 64)
	column.custom_minimum_size = Vector2(420, 0)
	column.add_theme_constant_override("separation", 18)
	pause_panel.add_child(column)
	var heading := Label.new()
	heading.text = "SPILLWAY / PAUSED"
	heading.add_theme_font_size_override("font_size", 29)
	column.add_child(heading)
	var identity := Label.new()
	identity.text = game.BUILD_ID
	identity.add_theme_font_size_override("font_size", 13)
	column.add_child(identity)
	for item: Array in [["Mouse sensitivity", "sensitivity", 0.3, 2.5, 0.05], ["Horizontal field of view", "fov", 75.0, 110.0, 1.0], ["Volume", "volume", 0.0, 1.0, 0.05]]:
		var label := Label.new()
		label.text = item[0]
		column.add_child(label)
		var slider := HSlider.new()
		slider.min_value = item[2]
		slider.max_value = item[3]
		slider.step = item[4]
		slider.value = game.settings[item[1]]
		slider.value_changed.connect(_slider_changed.bind(str(item[1])))
		column.add_child(slider)
	var comfort_button := CheckButton.new()
	comfort_button.text = "Comfort camera (less impact and no speed FOV)"
	comfort_button.button_pressed = game.settings.comfort
	comfort_button.toggled.connect(func(value: bool) -> void: game.change_setting("comfort", value))
	column.add_child(comfort_button)
	for item: Array in [["Resume", func() -> void: game.set_paused(false)], ["Restart clean run", func() -> void: game.restart_run()], ["Quit", func() -> void: game.request_quit()]]:
		var button := Button.new()
		button.text = item[0]
		if str(item[0]) == "Resume":
			_resume_button = button
		button.pressed.connect(item[1])
		column.add_child(button)
	pause_panel.hide()

func set_paused(value: bool) -> void:
	pause_panel.visible = value
	if value and _resume_button != null:
		_resume_button.grab_focus()

func _slider_changed(value: float, key: String) -> void:
	game.change_setting(key, value)

func blink() -> void:
	_blink_alpha = 1.0

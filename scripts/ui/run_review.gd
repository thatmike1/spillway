extends PanelContainer
## browsing is read-only. the owner closes review before executing the explicit practice request.
signal closed
signal practice_requested(request: Dictionary)
const MODEL := preload("res://scripts/recordings/run_review_model.gd")
const LOOK := preload("res://scripts/r18_ui_theme.gd")
const STAGE := preload("res://scripts/ui/run_review_stage.gd")
const TRACE := preload("res://scripts/ui/run_review_trace.gd")
var directory := "user://r16_runs/"
var spatial_unavailable_reason := ""
var entries: Array = []
var comparison: Dictionary = {}
var attempts: ItemList
var splits: Tree
var trace: Control
var scrubber: HSlider
var message: Label
var clock: Label
var practice_button: Button
var practice_note: Label
var follow: CheckButton
var camera_target: OptionButton
var legend: Label
var _details: VBoxContainer
var stage
var view_note: Label
var _map_source: Node3D
var _map_identity := {}
var scanning := false
var _scan := {}
var _follow_mode := false
var _compact := false
var _readability_ready := false
var _marked_best := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = LOOK.menu_theme()
	add_theme_stylebox_override("panel", LOOK.flat(LOOK.CREAM, 2, Vector4(24, 18, 24, 18)))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := Label.new()
	title.text = "Review my run"
	title.add_theme_font_override("font", LOOK.font("title"))
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Back"
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(message)
	practice_button = Button.new()
	practice_button.text = "Practise this segment"
	practice_button.disabled = true
	practice_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	practice_button.pressed.connect(func() -> void:
		var request := MODEL.practice_request(comparison)
		if request.ok and spatial_unavailable_reason.is_empty() and MODEL.READER.identity_matches(request.identity, _map_identity).is_empty():
			practice_requested.emit(request))
	body.add_child(practice_button)
	practice_note = Label.new()
	practice_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	practice_note.visible = false
	body.add_child(practice_note)
	var columns := HSplitContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var library := VBoxContainer.new()
	columns.add_child(library)
	var heading := Label.new()
	heading.text = "Recent attempts · UTC"
	library.add_child(heading)
	attempts = ItemList.new()
	attempts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attempts.custom_minimum_size.x = 430
	attempts.add_theme_font_size_override("font_size", 14)
	attempts.size_flags_horizontal = Control.SIZE_FILL
	_style_data_control(attempts)
	attempts.item_selected.connect(select_attempt)
	library.add_child(attempts)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_details)
	legend = Label.new()
	legend.text = "Speed (m/s)   •   Attempt: teal   •   Best: rust"
	_details.add_child(legend)
	follow = CheckButton.new()
	follow.text = "Follow camera"
	_details.add_child(follow)
	camera_target = OptionButton.new()
	camera_target.add_item("Follow attempt")
	camera_target.add_item("Follow personal best")
	camera_target.item_selected.connect(func(index: int) -> void:
		stage.follow_target = index
		stage.scrub_to(scrubber.value)
		_update_follow_note())
	_details.add_child(camera_target)
	stage = STAGE.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_child(stage)
	stage.visible = false
	view_note = Label.new()
	view_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_child(view_note)
	view_note.visible = false
	trace = TRACE.new()
	trace.custom_minimum_size = Vector2(260, 150)
	trace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_child(trace)
	clock = Label.new()
	_details.add_child(clock)
	scrubber = HSlider.new()
	scrubber.step = 0.0
	scrubber.editable = false
	scrubber.value_changed.connect(scrub_to)
	_details.add_child(scrubber)
	splits = Tree.new()
	_style_data_control(splits)
	splits.add_theme_color_override("title_button_color", LOOK.INK)
	splits.add_theme_color_override("guide_color", Color(LOOK.INK, 0.12))
	for state: String in ["normal", "hover", "pressed"]:
		splits.add_theme_stylebox_override("title_button_" + state, LOOK.flat(LOOK.CREAM_SHADE))
	splits.columns = 5
	splits.hide_root = true
	splits.column_titles_visible = true
	splits.custom_minimum_size.y = 170
	splits.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i: int in 5:
		splits.set_column_title(i, ["Jump to", "Attempt", "Best", "Total +/−", "Segment +/−"][i])
	splits.item_selected.connect(func() -> void:
		var item := splits.get_selected()
		if item != null: scrubber.value = float(item.get_metadata(0)))
	_details.add_child(splits)
	follow.toggled.connect(func(enabled: bool) -> void:
		_follow_mode = enabled
		_update_view_visibility())
	if is_instance_valid(_map_source) and spatial_unavailable_reason.is_empty():
		stage.attach_map(_map_source, _map_identity)
	get_window().size_changed.connect(_apply_readability)
	_apply_readability()
	refresh()
	close.grab_focus()

func refresh() -> void:
	comparison = {}
	_mark_best()
	practice_button.disabled = true
	practice_note.visible = false
	practice_button.tooltip_text = "Choose a comparable attempt with a completed segment first."
	stage.clear()
	_marked_best = -1
	entries.clear()
	attempts.clear()
	splits.clear()
	trace.series = []
	trace.queue_redraw()
	scrubber.editable = false
	message.text = "Reading local attempts… You can go back while they load."
	_scan = MODEL.begin_scan(directory)
	scanning = true
	view_note.text = "Choose a comparable recording pair first."
	_update_view_visibility()

func _process(_delta: float) -> void:
	if not scanning:
		return
	if not MODEL.step_scan(_scan):
		return
	scanning = false
	entries = _scan.entries
	_finish_list()

func _finish_list() -> void:
	for entry: Dictionary in entries:
		var identity: Dictionary = entry.identity
		attempts.add_item(MODEL.attempt_label(entry))
		attempts.set_item_tooltip(attempts.item_count - 1, "%s\n%s" % [entry.name, identity.get("preset", "")])
	message.text = "Pick an attempt to compare it with its matching personal best." if not entries.is_empty() else "No recordings yet. Play an attempt, then return here."
	if not entries.is_empty():
		var preferred := 0
		for i: int in entries.size():
			if entries[i].ok:
				preferred = i
				break
		attempts.select(preferred)
		select_attempt(preferred)

func select_attempt(index: int) -> void:
	attempts.select(index)
	comparison = {}
	_mark_best()
	practice_note.visible = false
	practice_button.disabled = true
	practice_button.tooltip_text = "Choose a comparable attempt with a completed segment first."
	stage.clear()
	stage.visible = false
	view_note.text = "Choose a comparable recording pair first."
	_update_view_visibility()
	splits.clear()
	trace.series = []
	trace.queue_redraw()
	scrubber.editable = false
	clock.text = ""
	var attempt := MODEL.load_attempt(entries[index].path)
	if not attempt.ok:
		message.text = attempt.error
		return
	var best := MODEL.matching_best(entries, attempt)
	comparison = MODEL.compare(attempt, best)
	if not comparison.ok:
		message.text = comparison.error
		return
	_mark_best()
	message.text = "Personal best: %.3f s · %s. Positive time means slower." % [best.duration, MODEL.recorded_time(best.run.header.get("created_unix", 0.0))]
	message.text += "\n" + MODEL.biggest_loss(comparison)
	_load_preview()
	var root := splits.create_item()
	for split: Dictionary in comparison.splits:
		var row := splits.create_item(root)
		row.set_text(0, split.label)
		row.set_metadata(0, split.time)
		row.set_text(1, "%.3f s" % split.time)
		row.set_text(2, "%.3f s" % split.best_time)
		row.set_text(3, "%+.3f s" % split.delta)
		row.set_text(4, "%+.3f s" % split.loss)
	trace.series = [attempt.speed, best.speed]
	trace.duration = comparison.duration
	scrubber.max_value = comparison.duration
	scrubber.editable = true
	scrubber.value = 0
	scrub_to(0)

func scrub_to(time: float) -> void:
	trace.cursor = time
	trace.queue_redraw()
	stage.scrub_to(time)
	clock.text = "Course clock  %.3f s" % time

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()

func attach_map(source: Node3D, identity: Dictionary) -> void:
	_map_source = source
	_map_identity = identity.duplicate(true)
	if stage != null:
		if spatial_unavailable_reason.is_empty():
			stage.attach_map(source, identity)
		_load_preview()

func _load_preview() -> void:
	var why := spatial_unavailable_reason
	if why.is_empty():
		why = stage.load_pair(comparison)
	else:
		stage.clear()
	view_note.text = why
	if not why.is_empty() and spatial_unavailable_reason.is_empty():
		view_note.text += " Use Back: Maps selects the map; Settings selects the preset."
	if why.is_empty(): _update_follow_note()
	_update_view_visibility()
	_update_practice_action()

func _update_practice_action() -> void:
	var request := MODEL.practice_request(comparison)
	practice_button.text = "Practise largest loss: " + str(request.label) if request.ok else "Practise largest loss"
	practice_button.disabled = not request.ok or not spatial_unavailable_reason.is_empty() or not MODEL.READER.identity_matches(request.get("identity", {}), _map_identity).is_empty()
	practice_note.visible = comparison.get("ok", false) and (not spatial_unavailable_reason.is_empty() or (request.ok and practice_button.disabled))
	if practice_note.visible and not spatial_unavailable_reason.is_empty():
		practice_note.text = spatial_unavailable_reason
	elif practice_note.visible:
		var preset := str(request.identity.get("preset", ""))
		preset = {"server128": "F2", "server128_aa1000": "F5"}.get(preset, preset)
		practice_note.text = "Use Back, then Maps for %s and Settings for %s. Match the recorded layout. Current: %s / %s." % [str(request.identity.get("map", "")).replace("-", " ").capitalize(), preset, str(_map_identity.get("map", "unavailable")).replace("-", " ").capitalize(), {"server128": "F2", "server128_aa1000": "F5"}.get(str(_map_identity.get("preset", "")), str(_map_identity.get("preset", "unavailable")))]
	if not spatial_unavailable_reason.is_empty():
		practice_button.tooltip_text = spatial_unavailable_reason
	elif not request.ok:
		practice_button.tooltip_text = str(request.error)
	elif practice_button.disabled:
		practice_button.tooltip_text = "Load the matching map, movement preset and layout to practise this segment."
	else:
		practice_button.tooltip_text = "Start a normal practice attempt at %s with the best ghost. Existing recordings stay unchanged." % request.label

func _style_data_control(control: Control) -> void:
	control.add_theme_stylebox_override("panel", LOOK.flat(LOOK.CREAM_DEEP))
	control.add_theme_stylebox_override("selected", LOOK.flat(LOOK.INK))
	control.add_theme_stylebox_override("selected_focus", LOOK.flat(LOOK.INK))
	control.add_theme_color_override("font_color", LOOK.INK)
	control.add_theme_color_override("font_selected_color", LOOK.CREAM)
	var focus := LOOK.flat(Color.TRANSPARENT)
	focus.draw_center = false
	focus.border_color = LOOK.EDGE
	focus.set_border_width_all(2)
	control.add_theme_stylebox_override("focus", focus)

func _update_view_visibility() -> void:
	var valid := bool(comparison.get("ok", false))
	var showing_follow: bool = valid and _follow_mode and stage.tracks.size() == 2
	stage.visible = showing_follow
	camera_target.visible = showing_follow
	trace.visible = valid and not showing_follow
	splits.visible = valid and not showing_follow
	legend.visible = valid and not showing_follow
	scrubber.visible = valid
	clock.visible = valid
	follow.visible = valid
	practice_button.visible = valid
	if not valid:
		_follow_mode = false
		follow.set_pressed_no_signal(false)
	follow.text = "Follow camera" if stage.tracks.size() == 2 else "Follow camera (unavailable)"
	follow.disabled = not valid
	view_note.visible = valid and _follow_mode and spatial_unavailable_reason.is_empty()

func _update_follow_note() -> void:
	view_note.text = "Following %s. Teal: attempt; rust: personal best. Switch targets if the other ghost is ahead, behind or hidden by scenery." % ("the attempt" if stage.follow_target == 0 else "the personal best")

func _mark_best() -> void:
	if _marked_best >= 0 and _marked_best < entries.size() and _marked_best < attempts.item_count:
		attempts.set_item_text(_marked_best, MODEL.attempt_label(entries[_marked_best]))
	_marked_best = -1
	if not comparison.get("ok", false): return
	for i: int in entries.size():
		if entries[i].path == comparison.best.path:
			attempts.set_item_text(i, MODEL.attempt_label(entries[i]).replace(str(entries[i].identity.get("map", "Unknown map")) + " / ", "Best / "))
			_marked_best = i
			break

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and attempts != null and trace != null:
		_apply_readability()

func _apply_readability() -> void:
	var compact := get_window().size.x < 1100
	if _readability_ready and compact == _compact: return
	_readability_ready = true
	_compact = compact
	var body_size := 19 if compact else 15
	theme.default_font_size = body_size
	for type: String in ["Button", "OptionButton", "CheckButton", "Tree"]:
		theme.set_font_size("font_size", type, body_size)
	theme.set_font_size("title_button_font_size", "Tree", body_size)
	attempts.add_theme_font_size_override("font_size", 19 if compact else 14)
	attempts.custom_minimum_size.x = 560 if compact else 430
	splits.set_column_custom_minimum_width(0, 150 if compact else 0)
	trace.font_size = 18 if compact else 13
	trace.queue_redraw()

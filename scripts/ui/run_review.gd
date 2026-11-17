extends PanelContainer
## a read-only screen. the owner controls pause and removes it after closed.
signal closed
const MODEL := preload("res://scripts/recordings/run_review_model.gd")
const LOOK := preload("res://scripts/r18_ui_theme.gd")
const STAGE := preload("res://scripts/ui/run_review_stage.gd")
const TRACE := preload("res://scripts/ui/run_review_trace.gd")
var directory := "user://r16_runs/"
var entries: Array = []
var comparison: Dictionary = {}
var attempts: ItemList
var splits: Tree
var trace: Control
var scrubber: HSlider
var message: Label
var clock: Label
var _details: VBoxContainer
var stage
var view_note: Label
var _map_source: Node3D
var _map_identity := {}
var scanning := false
var _scan := {}
var _follow_mode := false

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
	var columns := HSplitContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	attempts = ItemList.new()
	attempts.custom_minimum_size.x = 250
	attempts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attempts.item_selected.connect(select_attempt)
	columns.add_child(attempts)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_details)
	var legend := Label.new()
	legend.text = "Speed over time (m/s)   •   Teal: attempt   •   Rust: personal best"
	_details.add_child(legend)
	var follow := CheckButton.new()
	follow.text = "Follow camera"
	_details.add_child(follow)
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
		stage.visible = enabled and stage.tracks.size() == 2
		view_note.visible = enabled
		trace.visible = not enabled
		splits.visible = not enabled
		legend.visible = not enabled)
	if is_instance_valid(_map_source):
		stage.attach_map(_map_source, _map_identity)
	refresh()
	close.grab_focus()

func refresh() -> void:
	comparison = {}
	stage.clear()
	entries.clear()
	attempts.clear()
	splits.clear()
	trace.series = []
	trace.queue_redraw()
	scrubber.editable = false
	message.text = "Reading local attempts… You can go back while they load."
	_scan = MODEL.begin_scan(directory)
	scanning = true

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
		var text := "%s · %s\n%s · %s" % [identity.get("map", "Unknown map"), identity.get("preset", ""), entry.name, entry.outcome.get("kind", entry.status)]
		attempts.add_item(text)
		attempts.set_item_tooltip(attempts.item_count - 1, entry.name)
	message.text = "Pick an attempt to compare it with its matching personal best." if not entries.is_empty() else "No recordings yet. Play an attempt, then return here."
	if not entries.is_empty():
		attempts.select(0)
		select_attempt(0)

func select_attempt(index: int) -> void:
	comparison = {}
	stage.clear()
	stage.visible = false
	view_note.text = "Choose a comparable recording pair first."
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
	message.text = "Compared with %s. Positive time means slower; unfinished attempts show only reached checkpoints." % best.path.get_file()
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
		stage.attach_map(source, identity)
		_load_preview()

func _load_preview() -> void:
	var why: String = stage.load_pair(comparison)
	view_note.text = why if not why.is_empty() else "Teal is this attempt; rust is its personal best. Scrub below to follow both on the course clock."
	stage.visible = _follow_mode and why.is_empty()

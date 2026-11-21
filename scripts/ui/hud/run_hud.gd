extends "res://scripts/ui/pause_menu.gd"
## design 1121 run hud: hierarchy and calm on top of the inherited r15 to r21 hud. nothing here
## writes to the game; it only restyles and re-places what the chain already shows.
##
## one primary readout (speed) and one secondary (time, with the delta when a split lands) share a
## single low-centre band under the landing zone (scripts/ui/hud/band.gd); style lives on the
## band's right flank. everything that is not needed at 900 u/s steps back once the run starts:
## map and preset, the best line and the ghost/recording line show at spawn and in the pause
## sheet, and the debug-flavoured readouts stay behind F9 as before.

const BAND := preload("res://scripts/ui/hud/band.gd")
## how long a split stays on the band before it fades (the r15 hold is 2.6 s).
const SPLIT_HOLD_S := 2.6

## arrival motion for events on the band: how long they take to settle and how far they rise.
const ARRIVE_S := 0.18
const ARRIVE_PX := 9.0

var _split_name: Label
var _run_quiet: float = 0.0
var _finish_keys: HFlowContainer
var _finish_more: Label

func attach(main: Node) -> void:
	super(main)
	_style_band()
	_style_finish()

func _style_band() -> void:
	UI.world_label(speed_label, "numeral", 46, UI.CREAM, 5)
	UI.world_label(speed_unit, "label", 11, Color(UI.CREAM, 0.78), 2)
	UI.world_label(speed_metric, "smallnum", 11, Color(UI.CREAM, 0.78), 2)
	UI.world_label(clock, "numeral", 24, Color(UI.CREAM, 0.94), 4)
	UI.world_label(best_line, "small", 12, Color(UI.CREAM, 0.82), 3)
	UI.world_label(run_line, "small", 11, Color(UI.CREAM, 0.72), 3)
	UI.world_label(split_label, "numeral", 22, UI.CREAM, 4)
	_split_name = Label.new()
	_split_name.name = "SplitName"
	_split_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.world_label(_split_name, "label", 13, Color(UI.CREAM, 0.9), 3)
	overlay.add_child(_split_name)
	overlay.move_child(_split_name, split_label.get_index())
	_layout()

# --- events -----------------------------------------------------------------------------------

## a split says one thing: the stage it closed and the running delta against the best splits
## (or the stage time when there is no best yet), then it leaves.
func stage_reached(segment: int, skipped: int) -> void:
	super(segment, skipped)
	var title := str(game.call("segment_title", segment))
	var delta: float = game.call("split_delta_live", segment) if bool(game.clean_eligible) else NAN
	var color := UI.CREAM
	if is_finite(delta):
		split_label.text = _delta(delta)
		color = UI.SEA if delta <= 0.0 else UI.CORAL
	else:
		var own: float = game.call("segment_time", segment)
		split_label.text = _time(own if own >= 0.0 else float(game.stage_times[segment]))
	split_label.add_theme_color_override("font_color", color)
	_split_name.text = title if skipped <= 0 else "%s  ·  %d skipped" % [title, skipped]
	_split_time = SPLIT_HOLD_S

func run_started() -> void:
	super()
	if _split_name != null:
		_split_name.text = ""

## 0 at the moment an event arrives, easing out to 1 after ARRIVE_S.
static func _arrival(since: float) -> float:
	var t := clampf(since / ARRIVE_S, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)

# --- per frame --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	super(delta)
	if game == null or game.player == null or _split_name == null:
		return
	var started := bool(game.get("_started"))
	_run_quiet = move_toward(_run_quiet, 1.0 if started else 0.0, delta * 2.0)
	var base := (1.0 - _title_alpha) * (0.0 if bool(game.paused) else 1.0)
	var quiet := 0.0 if telemetry else _run_quiet
	for node: CanvasItem in [map_title, preset_line, best_line]:
		node.modulate.a = base * (1.0 - quiet)
	# the ghost/recording line is telemetry, except when it names who you are racing.
	var racing := run_line.text.begins_with("racing ") or run_line.text.begins_with("PB segment guide")
	run_line.visible = telemetry or racing
	if racing and not telemetry:
		run_line.text = run_line.text.split("  ·  ")[0]
	# one teaching ticket: the preset's own two lines. the long key list is already on the title
	# card and in the pause sheet's Keys page, so it no longer stacks under them during the run.
	if not telemetry:
		keys_line.modulate.a = 0.0
	split_label.modulate.a = minf(1.0, _split_time * 1.5) * _arrival(SPLIT_HOLD_S - _split_time) * base
	_split_name.modulate.a = split_label.modulate.a
	if bool(game.finished):
		split_label.modulate.a = 0.0
		_split_name.modulate.a = 0.0
		# the finish card is the one thing to read now; the band steps back behind it.
		for node: CanvasItem in [speed_label, speed_unit, speed_metric, clock, style_panel]:
			node.modulate.a *= 0.35
	_layout()

# --- layout -----------------------------------------------------------------------------------

func _layout() -> void:
	super()
	if _split_name == null or map_title == null:
		return
	var size := get_viewport().get_visible_rect().size
	if not telemetry and controls.modulate.a > 0.01 and not controls.text.is_empty():
		hint.position.y = controls.position.y + controls.size.y + 8.0
	var y := BAND.baseline(size)
	var cx := BAND.centre(size)
	var left := BAND.left_flank(size)
	BAND.place(speed_label, cx, y, 0)
	BAND.place(speed_unit, cx, y + 15.0, 0)
	BAND.place(speed_metric, cx, y + 29.0, 0)
	var speed_top := y - BAND.ascent(speed_label)
	crouch_tag.reset_size()
	crouch_tag.position = Vector2(roundf(cx - crouch_tag.get_minimum_size().x * 0.5), roundf(speed_top - crouch_tag.get_minimum_size().y - 4.0))
	BAND.place(clock, left, y, -1)
	BAND.place(best_line, left, y + 17.0, -1)
	BAND.place(run_line, left, y + (32.0 if best_line.modulate.a > 0.01 else 17.0), -1)
	# a split arrives by rising a few pixels into place as it fades in, then simply fades out.
	var chip_y := y - BAND.ascent(clock) - 12.0 + (1.0 - _arrival(SPLIT_HOLD_S - _split_time)) * ARRIVE_PX
	BAND.place(split_label, left, chip_y, -1)
	BAND.place(_split_name, split_label.position.x - 8.0, chip_y, -1)
	if finish_card != null and _finish_keys != null:
		finish_card.reset_size()
		finish_panel.size = finish_card.size
		finish_panel.position = Vector2(roundf(cx - finish_card.size.x * 0.5), roundf(maxf(56.0, size.y * 0.42 - finish_card.size.y * 0.5)))

## the grapple anchor readout leaves the aim point (it sat on the landing zone) and joins the band,
## above the speed numeral, where the crouch tag would be.
func _refresh_anchor_readout() -> void:
	super()
	if anchor_readout == null or not anchor_readout.visible or bool(game.map_entry().get("own_look", false)):
		return
	var size := get_viewport().get_visible_rect().size
	var top := BAND.baseline(size) - BAND.ascent(speed_label) - anchor_readout.size.y - 6.0
	if crouch_tag.visible:
		top -= crouch_tag.get_minimum_size().y + 4.0
	anchor_readout.position = Vector2(roundf(BAND.centre(size) - anchor_readout.size.x * 0.5), roundf(top))

# --- finish -------------------------------------------------------------------------------------

## the finish as one composed card: where and how, the time large, the delta to best under it,
## the splits and style as one table, and the keys for what to do next.
func _style_finish() -> void:
	var sheet := UI.flat(Color(UI.CREAM, 0.97), 3, Vector4(30, 22, 30, 22))
	sheet.border_color = UI.EDGE
	sheet.border_width_left = 5
	finish_card.add_theme_stylebox_override("panel", sheet)
	_finish_time.add_theme_font_size_override("font_size", 68)
	_finish_time.add_theme_constant_override("line_spacing", -10)
	_finish_kicker.add_theme_font_size_override("font_size", 13)
	_finish_result.add_theme_font_override("font", UI.font("title"))
	_finish_result.add_theme_font_size_override("font_size", 19)
	_finish_style.add_theme_font_size_override("font_size", 14)
	_finish_splits.add_theme_constant_override("h_separation", 28)
	_finish_splits.add_theme_constant_override("v_separation", 3)
	var column := _finish_time.get_parent() as VBoxContainer
	column.add_theme_constant_override("separation", 4)
	column.custom_minimum_size.x = 400.0
	_finish_footer.hide()
	_finish_keys = HFlowContainer.new()
	_finish_keys.name = "FinishKeys"
	_finish_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finish_keys.add_theme_constant_override("h_separation", 16)
	_finish_keys.add_theme_constant_override("v_separation", 6)
	column.add_child(_finish_keys)
	_finish_more = _card_label(column, "body", 11, UI.INK_SOFT)
	_finish_more.name = "FinishMore"
	# reading order: where, the time, the delta; then the splits table, the style and ghost lines,
	# the keys for what next, and the preset as a footnote.
	var rule: ColorRect = null
	var gaps: Array[Control] = []
	for child: Node in column.get_children():
		if child is ColorRect:
			rule = child
		elif child.get_class() == "Control":
			gaps.append(child)
	var order: Array[Control] = [_finish_kicker, _finish_time, _finish_result, rule, _finish_splits, _finish_style, _finish_ghost]
	order.append_array(gaps)
	order.append_array([_finish_keys, _finish_more, _finish_meta, _finish_footer])
	for i: int in order.size():
		if order[i] != null:
			column.move_child(order[i], i)
	if rule != null:
		rule.custom_minimum_size.y = 1
		rule.color = Color(UI.INK, 0.14)
	for gap: Control in gaps:
		gap.custom_minimum_size.y = 8
	_finish_meta.add_theme_font_size_override("font_size", 11)

func _key_chip(key: String, words: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	_finish_keys.add_child(row)
	var cap := Label.new()
	cap.text = key
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_font_override("font", UI.font("label"))
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", UI.CREAM)
	cap.add_theme_stylebox_override("normal", UI.flat(UI.INK, 3, Vector4(7, 2, 7, 3)))
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var label := _card_label(row, "label", 14, UI.INK)
	label.text = words
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func show_finish(is_best: bool, is_open_best: bool) -> void:
	super(is_best, is_open_best)
	if _finish_keys == null:
		return
	var kind := str(game.finish_kind)
	_finish_kicker.text = "%s  ·  %s" % [str(game.call("map_name")), {"clean": "clean run", "open": "open line"}.get(kind, "practice")]
	_finish_meta.text = "%s  ·  %d Hz" % [str(game.preset.label), int(game.physics_hz)]
	for child: Node in _finish_keys.get_children():
		_finish_keys.remove_child(child)
		child.queue_free()
	_key_chip("R", "Run again")
	_key_chip("F", "Practise %s" % str(game.call("stage_title", int(game.checkpoint_index))))
	_key_chip("Esc", "Maps")
	_finish_more.text = "F2 / F5 preset  ·  G ghost"
	finish_card.reset_size()
	finish_panel.size = finish_card.size
	_layout()

# --- runner-owned status ------------------------------------------------------------------------

## a runner that draws its own status ticket (Mail Run) can hand it here to be placed and sized in
## the hud's language: a compact ticket on the right, under the mode tags, never over the landing.
func place_runner_status(label: Label) -> void:
	if not label.has_meta("d1121_styled"):
		UI.ticket(label, "label", 14, SIDE_RIGHT, 0.92)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size = Vector2.ZERO
		label.set_meta("d1121_styled", true)
	label.reset_size()
	var size := get_viewport().get_visible_rect().size
	var right := UI.safe_frame(size).end.x - 32.0
	var top := 48.0
	for tag: Label in [practice_tag, lab_tag]:
		if tag.visible and not tag.text.is_empty():
			top = maxf(top, tag.position.y + tag.get_minimum_size().y + 8.0)
	label.position = Vector2(roundf(right - label.get_minimum_size().x), roundf(top))

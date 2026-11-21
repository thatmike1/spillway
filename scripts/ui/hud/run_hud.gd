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
var _band_shade: Panel
var _plate_target := Rect2()
var _plate_rect := Rect2()
var _plate_view := Vector2.ZERO
var _run_quiet: float = 0.0
var _finish_keys: HFlowContainer
var _finish_more: Label

func attach(main: Node) -> void:
	super(main)
	_style_band()
	_style_finish()

func _style_band() -> void:
	UI.world_label(speed_label, "numeral", 46, UI.CREAM, 5)
	UI.world_label(speed_unit, "label", 12, Color(UI.CREAM, 0.9), 3)
	UI.world_label(speed_metric, "smallnum", 12, Color(UI.CREAM, 0.9), 3)
	UI.world_label(clock, "numeral", 24, Color(UI.CREAM, 0.94), 4)
	UI.world_label(best_line, "small", 12, Color(UI.CREAM, 0.82), 3)
	UI.world_label(run_line, "small", 11, Color(UI.CREAM, 0.72), 3)
	UI.world_label(split_label, "numeral", 22, UI.CREAM, 4)
	# teaching speaks in one voice: the route hint uses the controls ticket's type.
	UI.ticket(hint, "body", 14)
	# a small translucent ink plate behind the band, sized to what it shows: cream type on the
	# pale decks you land on read as hollow outlines without it; on dark walls it all but vanishes.
	_band_shade = Panel.new()
	_band_shade.name = "BandPlate"
	_band_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band_shade.add_theme_stylebox_override("panel", UI.flat(Color(UI.INK, BAND.PLATE_ALPHA), 4, Vector4.ZERO))
	overlay.add_child(_band_shade)
	overlay.move_child(_band_shade, mini(speed_label.get_index(), clock.get_index()))
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

## toasts are for things the player did. map-revision and recording-identity notes live on the
## pause sheet's Runs page; the Through Line launch already has its own cream cue.
func notify(text: String) -> void:
	if not text.is_empty() and game != null and not telemetry:
		if text == str(game.call("map_revision_description")):
			return
		if text.begins_with("RISE · ") and through_cue != null:
			return
		# a ghost toggle says what it did; the empty-state tail is not news.
		if text.begins_with("Ghost ") and "  ·  no clean recorded run" in text:
			text = text.left(text.find("  ·  "))
		# loading a map names it and its preset over the title card, which already names the map;
		# only a note about what the switch changed (a cancelled preset, the lab's preset) is news.
		var loaded := "%s  ·  %s" % [str(game.call("map_name")), str(game.preset.get("label", ""))]
		if text.begins_with(loaded):
			text = text.trim_prefix(loaded).trim_prefix("  ·  ")
			if text.is_empty():
				return
			text = text.left(1).to_upper() + text.substr(1)
		# a preset switch says which preset; the physics rate is F9 material.
		var rate := text.find("  ·  %d Hz" % int(game.get("physics_hz")))
		if rate > 0 and text.begins_with(str(game.preset.get("label", ""))):
			text = text.left(rate) + text.substr(rate + ("  ·  %d Hz" % int(game.get("physics_hz"))).length())
	super(text)

func run_started() -> void:
	super()
	if _split_name != null:
		_split_name.text = ""

## 0 at the moment an event arrives, easing out to 1 after ARRIVE_S.
static func _arrival(since: float) -> float:
	var t := clampf(since / ARRIVE_S, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)

## the teaching ticket keeps every instruction the preset gives and drops only what every player
## already does (run with WASD, look with the mouse) and the scroll alternative, which the pause
## sheet's Keys page still lists.
static func teaching_text(text: String) -> String:
	var out := text.replace("WASD run · mouse look · ", "").replace(" (or scroll)", "")
	return out.left(1).to_upper() + out.substr(1) if out != text else out

## an experiment map's instructions in the teaching ticket: its first two sentences, without the
## "EXPERIMENTAL" lead the map tag already carries. the pause sheet keeps the whole paragraph.
static func brief_instructions(text: String) -> String:
	var out := text.strip_edges()
	for lead: String in ["EXPERIMENTAL · ", "EXPERIMENTAL "]:
		out = out.trim_prefix(lead)
	var cut := -1
	for i: int in 2:
		cut = out.find(". ", cut + 1)
		if cut < 0:
			return out.left(1).to_upper() + out.substr(1)
	return out.left(1).to_upper() + out.substr(1, cut)

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
	# the practice tag in sentence case, saying where practice started without repeating itself.
	if practice_tag.text.begins_with("PRACTICE ("):
		var reason := _reason(str(game.practice_reason))
		var head := "Practice"
		if reason.begins_with("checkpoint practice from "):
			head = "Practice from " + reason.trim_prefix("checkpoint practice from ")
		elif reason != "checkpoint practice":
			head = "Practice (%s)" % reason
		practice_tag.text = head + " · no best · R for a clean run"
	# an empty state says nothing: no "no clean time yet" line under the clock.
	if not telemetry and best_line.text.begins_with("no clean time"):
		best_line.modulate.a = 0.0
	# experiment maps: one quiet line naming where you are. the runner's status line (rope model,
	# armed, the map's own notes) is teaching: it shows with the teaching ticket and steps back with
	# it, leaving the single map tag. the movement lab keeps its live move panel.
	# (is_lab() is also true on experiment maps; the movement lab is the "lab" kind, never "experiment".)
	if not telemetry and game.is_experiment_map():
		var teaching := _teach_alpha > 0.01 or not bool(game.get("_started"))
		if lab_panel.visible and not lab_panel.text.is_empty() and teaching:
			lab_tag.visible = false
		else:
			lab_panel.visible = false
	# practice says one thing at a time: while its toast is up the tag waits, then takes over.
	if not practice_tag.text.is_empty() and message.modulate.a > 0.05 and message.text.begins_with("Practice from"):
		practice_tag.modulate.a = 0.0
	# the route hint is for finding the way; behind the finish card it is noise.
	if bool(game.finished):
		hint.modulate.a = 0.0
	# the ghost/recording line is telemetry, except when it names who you are racing.
	var racing := run_line.text.begins_with("racing ") or run_line.text.begins_with("PB segment guide")
	run_line.visible = telemetry or racing
	if racing and not telemetry:
		run_line.text = run_line.text.split("  ·  ")[0]
	# one teaching ticket: the preset's own two lines. the long key list is already on the title
	# card and in the pause sheet's Keys page, so it no longer stacks under them during the run.
	if not telemetry:
		keys_line.modulate.a = 0.0
		controls.text = teaching_text(controls.text)
		# on experiment maps the ticket is the map's own instruction, briefly; the preset's bhop
		# lines are on the title card and the pause sheet.
		if game.is_experiment_map() and not game.map_has_capability("grapple"):
			var instructions := str(game.map_entry().get("instructions", ""))
			if not instructions.is_empty() and controls.text.ends_with(instructions):
				controls.text = brief_instructions(instructions)
	split_label.modulate.a = minf(1.0, _split_time * 1.5) * _arrival(SPLIT_HOLD_S - _split_time) * base
	_split_name.modulate.a = split_label.modulate.a
	_band_shade.modulate.a = speed_label.modulate.a
	if bool(game.finished):
		split_label.modulate.a = 0.0
		_split_name.modulate.a = 0.0
		# the finish card is the one thing to read now; the band leaves rather than dimming, since
		# outlined type at partial opacity reads as hollow.
		for node: CanvasItem in [speed_label, speed_unit, speed_metric, clock, style_panel, _band_shade, crouch_tag]:
			node.modulate.a = 0.0
	_layout()
	# measured after every opacity above is final, so hidden lines never widen the plate.
	_plate_target = _plate_bounds()
	# the plate is never smaller than what it holds: it takes an arriving event at once and eases
	# back in when the event leaves. it snaps when the window changes size.
	var view := get_viewport().get_visible_rect().size
	var ease := minf(1.0, delta * 10.0)
	if _plate_rect.size == Vector2.ZERO or view != _plate_view:
		_plate_rect = _plate_target
	else:
		var eased := Rect2(_plate_rect.position.lerp(_plate_target.position, ease), _plate_rect.size.lerp(_plate_target.size, ease))
		_plate_rect = eased.merge(_plate_target)
	_plate_view = view
	_band_shade.position = _plate_rect.position.round()
	_band_shade.size = _plate_rect.size.round()

## the union of what the band is showing right now, grown into a plate.
func _plate_bounds() -> Rect2:
	var shown: Array[Control] = [speed_label, speed_unit, clock]
	if not speed_metric.text.is_empty():
		shown.append(speed_metric)
	for node: Control in [split_label, _split_name, best_line, run_line]:
		if node.visible and node.modulate.a > 0.05 and not (node as Label).text.is_empty():
			shown.append(node)
	if style_panel != null and style_panel.get("score_label") != null:
		for key: String in ["score_label", "mult_label", "callout", "direction_label"]:
			var label: Variant = style_panel.get(key)
			if label is Label and (label as Label).visible and (label as Label).modulate.a > 0.05 and not (label as Label).text.is_empty():
				shown.append(label)
	var box := Rect2(speed_label.position, speed_label.get_minimum_size())
	for node: Control in shown:
		box = box.merge(Rect2(node.position, node.get_minimum_size()))
	# symmetric about the speed numeral, so the plate is one steady instrument and only grows
	# downward when an event arrives.
	var cx := speed_label.position.x + speed_label.get_minimum_size().x * 0.5
	var half := maxf(cx - box.position.x, box.end.x - cx)
	box = Rect2(cx - half, box.position.y, half * 2.0, box.size.y)
	return box.grow_individual(BAND.PLATE_PAD.x, BAND.PLATE_PAD.y, BAND.PLATE_PAD.x, BAND.PLATE_PAD.y)

# --- layout -----------------------------------------------------------------------------------

func _layout() -> void:
	super()
	if _split_name == null or map_title == null:
		return
	var size := get_viewport().get_visible_rect().size
	if not telemetry and not controls.text.is_empty():
		# the preset's two lines stay two lines instead of wrapping into a paragraph.
		controls.custom_minimum_size.x = minf(UI.text_width(controls), UI.safe_frame(size).size.x * 0.6)
		controls.reset_size()
		if controls.modulate.a > 0.01:
			hint.position.y = controls.position.y + controls.size.y + 8.0
	var y := BAND.baseline(size)
	var cx := BAND.centre(size)
	var left := BAND.left_flank(size)
	BAND.place(speed_label, cx, y, 0)
	BAND.place(speed_unit, cx, y + 16.0, 0)
	BAND.place(speed_metric, cx, y + 31.0, 0)
	var speed_top := y - BAND.ascent(speed_label)
	crouch_tag.reset_size()
	crouch_tag.position = Vector2(roundf(cx - crouch_tag.get_minimum_size().x * 0.5), roundf(speed_top - crouch_tag.get_minimum_size().y - 4.0))
	BAND.place(clock, left, y, -1)
	BAND.place(best_line, left, y + 17.0, -1)
	BAND.place(run_line, left, y + (32.0 if best_line.modulate.a > 0.01 else 17.0), -1)
	# a split arrives under the clock, rising a few pixels into place as it fades in, then fades
	# out. events sit below the band so nothing reaches up into the floor ahead.
	var chip_y := y + BAND.EVENT_DROP + (1.0 - _arrival(SPLIT_HOLD_S - _split_time)) * ARRIVE_PX
	BAND.place(split_label, left, chip_y, -1)
	BAND.place(_split_name, split_label.position.x - 8.0, chip_y, -1)
	_plate_target = _plate_bounds()
	if finish_card != null and _finish_keys != null:
		finish_card.reset_size()
		finish_panel.size = finish_card.size
		finish_panel.position = Vector2(roundf(cx - finish_card.size.x * 0.5), roundf(maxf(56.0, size.y * 0.42 - finish_card.size.y * 0.5)))

## the grapple anchor readout leaves the aim point (it sat on the landing zone) and, on maps with
## their own look, the left edge; on every grapple map it joins the band above the speed numeral.
func _refresh_anchor_readout() -> void:
	super()
	if anchor_readout == null or not anchor_readout.visible:
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
	var sheet := UI.flat(UI.CREAM, 3, Vector4(30, 22, 30, 22))
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
	_finish_meta.text = ""
	_finish_meta.hide()
	for child: Node in _finish_keys.get_children():
		_finish_keys.remove_child(child)
		child.queue_free()
	_key_chip("R", "Run again")
	_key_chip("F", "Practise %s" % str(game.call("stage_title", int(game.checkpoint_index))))
	_key_chip("Esc", "Maps")
	_finish_more.text = "F2 / F5 switch preset  ·  G ghost"
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
	# the title card owns the opening view; the ticket arrives as the card leaves.
	label.modulate.a = 1.0 - _title_alpha

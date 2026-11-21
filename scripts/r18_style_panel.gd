extends "res://scripts/r16_style_panel.gd"
## p / r18 style panel: r16's snapshot reading, ranks and texts unchanged; only type, colour and
## place change. low right inside the safe frame: the callout, then multiplier and score, a thin
## orange combo line and the best. cream with an ink outline, no box.

const UI := preload("res://scripts/r18_ui_theme.gd")
const BAND := preload("res://scripts/ui/hud/band.gd")
## design 1121: the combo line's width on the band, how long a changed score stays bright, and its
## resting opacity afterwards.
const BAR_W := 96.0
const LIVE_S := 1.6
const REST_ALPHA := 0.5
var caption: Label
var direction_label: Label
var _last_score: int = 0
var _score_age: float = INF

func attach(main: Node, style_service: RefCounted) -> void:
	super(main, style_service)
	shade.color = Color(0, 0, 0, 0)
	UI.world_label(score_label, "numeral", 24, UI.CREAM, 4)
	UI.world_label(mult_label, "numeral", 17, UI.EDGE)
	UI.world_label(best_label, "small", 12, Color(UI.CREAM, 0.86), 3)
	UI.world_label(callout, "title", 17, UI.CREAM)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UI.INK, 0.0)
	box.border_color = UI.EDGE
	box.border_width_left = 3
	box.content_margin_left = 9.0
	box.content_margin_right = 2.0
	callout.add_theme_stylebox_override("normal", box)
	caption = Label.new()
	caption.text = "banked style"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	UI.world_label(caption, "small", 12, Color(UI.CREAM, 0.86), 3)
	direction_label = Label.new()
	direction_label.name = "DirectionBonus"
	direction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(direction_label)
	UI.world_label(direction_label, "label", 13, UI.EDGE)
	bar_track.color = Color(UI.CREAM, 0.30)
	bar.color = UI.EDGE

func update_from(snap: Dictionary, delta: float) -> void:
	var direction: Dictionary = snap.get("direction", {})
	if direction_label != null:
		var hops := int(direction.get("hops", 0))
		direction_label.visible = hops > 0
		direction_label.text = "%s · %d hops · +%s pending" % ["Backwards" if str(direction.get("kind", "")) == "backward_bhop" else "Half-sideways",
			hops, points_text(int(direction.get("pending", 0)))] if hops > 0 else ""
	super(snap, delta)
	var quiet := _quiet_alpha(snap, delta)
	for node: CanvasItem in [score_label, mult_label, bar, bar_track]:
		node.modulate.a = quiet
	bar.size = Vector2(BAR_W * (bar.size.x / BAR_WIDTH), 2.0)

## quiet until it changes: no score block before anything scores; once there is a score it rests
## dim and comes up to full for a moment when it changes or while a combo is live.
func _quiet_alpha(snap: Dictionary, delta: float) -> float:
	var score := int(snap.get("score", 0))
	if score != _last_score:
		_last_score = score
		_score_age = 0.0
	else:
		_score_age += delta
	if score == 0 and int(snap.get("combo", 0)) <= 0:
		return 0.0
	if int(snap.get("combo", 0)) > 0 or _score_age < LIVE_S:
		return 1.0
	return lerpf(1.0, REST_ALPHA, clampf((_score_age - LIVE_S) / 0.6, 0.0, 1.0))

## the right flank of the run band (scripts/ui/hud/band.gd): score on the speed baseline, the
## multiplier after it, the combo line under it, and the callout above it.
func _layout() -> void:
	var size := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var x := BAND.right_flank(size)
	var y := BAND.baseline(size)
	for label: Label in [score_label, mult_label, best_label, callout, caption]:
		if label != null:
			label.reset_size()
	BAND.place(score_label, x, y, 1)
	BAND.place(mult_label, score_label.position.x + score_label.get_minimum_size().x + 6.0, y, 1)
	var bar_y := y + 6.0
	bar_track.position = Vector2(x, bar_y)
	bar_track.size = Vector2(BAR_W, 2.0)
	bar.position = Vector2(x, bar_y)
	BAND.place(best_label, x, y + 22.0, 1)
	best_label.visible = not best_label.text.is_empty() and game != null and not bool(game.get("_started"))
	if caption != null:
		caption.visible = false
	shade.position = score_label.position
	shade.size = Vector2.ZERO
	var callout_y := y + BAND.EVENT_DROP
	callout.reset_size()
	# a callout arrives like a split: it rises a few pixels into place while it fades in.
	var arrive := clampf(_shown_age / 0.18, 0.0, 1.0) if is_finite(_shown_age) else 1.0
	arrive = 1.0 - (1.0 - arrive) * (1.0 - arrive)
	callout.position = Vector2(roundf(x - 9.0 - 3.0), roundf(callout_y - BAND.ascent(callout) + (1.0 - arrive) * 9.0))
	if _shown_age <= HOLD_S:
		callout.modulate.a = arrive
	if direction_label != null:
		direction_label.reset_size()
		direction_label.position = Vector2(roundf(x), roundf(callout.position.y + callout.get_minimum_size().y + 2.0))

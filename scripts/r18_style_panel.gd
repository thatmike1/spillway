extends "res://scripts/r16_style_panel.gd"
## p / r18 style panel: r16's snapshot reading, ranks and texts unchanged; only type, colour and
## place change. low right inside the safe frame: the callout, then multiplier and score, a thin
## orange combo line and the best. cream with an ink outline, no box.

const UI := preload("res://scripts/r18_ui_theme.gd")
var caption: Label
var direction_label: Label

func attach(main: Node, style_service: RefCounted) -> void:
	super(main, style_service)
	shade.color = Color(0, 0, 0, 0)
	UI.world_label(score_label, "numeral", 26)
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
	caption.text = "style"
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
		var mult := float(direction.get("mult", 1.0))
		direction_label.visible = mult > 1.0
		direction_label.text = "%s · %d hops · ×%s" % ["Backwards" if str(direction.get("kind", "")) == "backward_bhop" else "Half-sideways",
			int(direction.get("hops", 0)), _mult_text(mult)] if mult > 1.0 else ""
	super(snap, delta)

func _layout() -> void:
	var size := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var frame := UI.safe_frame(size)
	var right := frame.end.x - 32.0
	for label: Label in [score_label, mult_label, best_label, callout, caption]:
		if label != null:
			label.reset_size()
	var bottom := size.y - 24.0
	best_label.visible = not best_label.text.is_empty()
	var best_h := best_label.get_minimum_size().y if best_label.visible else 0.0
	best_label.position = Vector2(right - best_label.get_minimum_size().x, bottom - best_h)
	var bar_y := (best_label.position.y if best_label.visible else bottom) - 5.0
	bar_track.position = Vector2(right - BAR_WIDTH, bar_y)
	bar_track.size = Vector2(BAR_WIDTH, 2.0)
	bar.position = Vector2(right - bar.size.x, bar_y)
	var score_size := score_label.get_minimum_size()
	score_label.position = Vector2(right - score_size.x, bar_y - score_size.y + 2.0)
	var mult_size := mult_label.get_minimum_size()
	mult_label.position = Vector2(score_label.position.x - 8.0 - mult_size.x, score_label.position.y + score_size.y - mult_size.y - 3.0)
	if caption != null:
		var left := mult_label.position.x if not mult_label.text.is_empty() else score_label.position.x
		caption.position = Vector2(left - 8.0 - caption.get_minimum_size().x, score_label.position.y + score_size.y - caption.get_minimum_size().y - 5.0)
	shade.position = score_label.position
	shade.size = Vector2.ZERO
	callout.position = Vector2(right - callout.get_minimum_size().x, score_label.position.y - callout.get_minimum_size().y - 6.0)
	if direction_label != null:
		direction_label.reset_size()
		direction_label.position = Vector2(right - direction_label.get_minimum_size().x, callout.position.y - direction_label.get_minimum_size().y - 5.0)

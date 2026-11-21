extends RefCounted
## a map card in the menu language: the place's captured view as a thumbnail, its name, one
## line of what kind of course it is and your best. the button keeps its plain text (read by
## checks, tooltips and screen readers) and draws it transparent under these labels.
const UI := preload("res://scripts/r18_ui_theme.gd")
const DATA := preload("res://scripts/ui/map_previews.gd")
const HEIGHT := 68.0
const PAD := 6.0

static func _box(fill: Color, edge: bool = false) -> StyleBoxFlat:
	var box := UI.flat(fill, UI.RADIUS, Vector4(0, 0, 0, 0))
	if edge:
		box.border_color = UI.VERMILION
		box.border_width_bottom = UI.EDGE_WIDTH
	return box

static func dress(button: Button, id: String, place: String, line: String, best: String) -> void:
	button.text = "%s\n%s" % [place, line]
	button.tooltip_text = line
	if not button.has_meta("place_card"):
		button.set_meta("place_card", true)
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.clip_text = true
		button.custom_minimum_size = Vector2(UI.SPACE_S * 20, HEIGHT)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
			button.add_theme_color_override(key, Color(0, 0, 0, 0))
		button.add_theme_stylebox_override("normal", _box(UI.INK_WASH))
		button.add_theme_stylebox_override("hover", _box(Color(UI.INK, 0.13)))
		button.add_theme_stylebox_override("pressed", _box(UI.INK, true))
		button.add_theme_stylebox_override("hover_pressed", _box(UI.INK, true))
		var row := HBoxContainer.new()
		row.name = "PlaceRow"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", UI.SPACE_M)
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = PAD
		row.offset_top = PAD
		row.offset_right = -UI.SPACE_S
		row.offset_bottom = -PAD
		button.add_child(row)
		var thumb := TextureRect.new()
		thumb.name = "PlaceThumb"
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.clip_contents = true
		thumb.custom_minimum_size = Vector2(roundf((HEIGHT - 2.0 * PAD) * 1.3), 0)
		row.add_child(thumb)
		var words := VBoxContainer.new()
		words.name = "PlaceWords"
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", 0)
		row.add_child(words)
		var top := HBoxContainer.new()
		top.name = "PlaceTop"
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_theme_constant_override("separation", UI.SPACE_S)
		words.add_child(top)
		var title := UI.text(Label.new(), "label", UI.TYPE_LABEL)
		title.name = "PlaceName"
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var record := UI.text(Label.new(), "smallnum", UI.TYPE_SMALL)
		record.name = "PlaceBest"
		var kind := UI.text(Label.new(), "body", UI.TYPE_SMALL)
		kind.name = "PlaceLine"
		kind.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kind.max_lines_visible = 2
		kind.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		kind.add_theme_constant_override("line_spacing", -2)
		for label: Label in [title, record, kind]:
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(title)
		top.add_child(record)
		words.add_child(kind)
	(button.get_node("PlaceRow/PlaceThumb") as TextureRect).texture = DATA.FRAMES.get(id)
	(button.get_node("PlaceRow/PlaceWords/PlaceTop/PlaceName") as Label).text = place
	(button.get_node("PlaceRow/PlaceWords/PlaceLine") as Label).text = line
	var best_label: Label = button.get_node("PlaceRow/PlaceWords/PlaceTop/PlaceBest")
	best_label.text = best
	best_label.visible = not best.is_empty()
	paint(button)

## ink type on the pale card; the current map is an ink plate with pale type.
static func paint(button: Button) -> void:
	if not button.has_meta("place_card"):
		return
	var current := button.button_pressed
	var words := button.get_node("PlaceRow/PlaceWords")
	(words.get_node("PlaceTop/PlaceName") as Label).add_theme_color_override("font_color", UI.PALE if current else UI.INK)
	(words.get_node("PlaceLine") as Label).add_theme_color_override("font_color", Color(UI.PALE, 0.78) if current else UI.INK_SOFT)
	(words.get_node("PlaceTop/PlaceBest") as Label).add_theme_color_override("font_color", UI.SEA_GLASS if current else UI.SEA_GLASS_DEEP)

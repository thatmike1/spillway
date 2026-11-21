extends PanelContainer
## the place you are about to choose: its captured view large, then its group, its name, what
## kind of course it is and your best. follows mouse hover or keyboard focus.
const UI := preload("res://scripts/r18_ui_theme.gd")
const DATA := preload("res://scripts/ui/map_previews.gd")
const PLACES := preload("res://scripts/ui/menu/map_places.gd")
const TEXT_BLOCK := 178.0
var selected_id := ""
var title: Label
var image: TextureRect
var caption: Label
var kicker: Label
var record: Label
var action: Label
## set by the menu: id -> {"group": String, "best": String}. empty when not wired.
var details: Callable

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet := UI.flat(UI.PALE, UI.RADIUS, Vector4(0, 0, 0, 0))
	sheet.border_color = UI.VERMILION
	sheet.border_width_bottom = UI.EDGE_WIDTH
	sheet.shadow_color = Color(UI.INK, 0.28)
	sheet.shadow_size = 18
	sheet.shadow_offset = Vector2(0, 6)
	add_theme_stylebox_override("panel", sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	image = TextureRect.new()
	image.name = "PreviewImage"
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.clip_contents = true
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(image)
	var words := MarginContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		words.add_theme_constant_override("margin_" + side, UI.SPACE_XL)
	words.add_theme_constant_override("margin_top", UI.SPACE_L)
	words.add_theme_constant_override("margin_bottom", UI.SPACE_L)
	column.add_child(words)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", UI.SPACE_XS)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(text)
	kicker = UI.kicker(Label.new(), UI.SLATE)
	kicker.name = "PreviewGroup"
	title = UI.text(Label.new(), "display", UI.TYPE_DISPLAY)
	title.name = "PreviewName"
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption = UI.text(Label.new(), "body", UI.TYPE_BODY + 1, UI.INK)
	caption.name = "PreviewTheme"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", UI.SPACE_L)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	record = UI.text(Label.new(), "smallnum", UI.TYPE_BODY, UI.INK)
	record.name = "PreviewBest"
	action = UI.text(Label.new(), "label", UI.TYPE_SMALL, UI.INK_SOFT)
	action.name = "PreviewAction"
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action.text = "Enter or click to run it from spawn"
	for label: Label in [kicker, title, caption]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(label)
	var gap := Control.new()
	gap.custom_minimum_size.y = UI.SPACE_XS
	text.add_child(gap)
	text.add_child(foot)
	for label: Label in [record, action]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot.add_child(label)

func show_map(id: String, entry: Dictionary) -> void:
	selected_id = id
	title.text = str(entry.get("name", id))
	image.texture = DATA.FRAMES.get(id)
	var info: Dictionary = details.call(id) if details.is_valid() and not id.is_empty() else {}
	var group := str(info.get("group", PLACES.group(id, entry)))
	kicker.text = str(PLACES.GROUP_KICKERS.get(group, ""))
	caption.text = PLACES.about(id, entry) if image.texture != null else "Preview unavailable."
	var best := str(info.get("best", ""))
	record.text = best if not best.is_empty() else "No best yet"
	record.add_theme_color_override("font_color", UI.INK if not best.is_empty() else UI.INK_SOFT)
	action.text = "Current map  ·  Restart R" if bool(info.get("current", false)) else "Enter or click to run it from spawn"

func arrange(viewport_size: Vector2, sidebar: Rect2) -> void:
	var gutter := clampf(viewport_size.x * 0.03, 26.0, 56.0)
	var left := sidebar.end.x + gutter
	var width := maxf(0.0, viewport_size.x - left - gutter)
	var height := minf(viewport_size.y - 2.0 * gutter, width * 9.0 / 16.0 + TEXT_BLOCK)
	width = minf(width, (height - TEXT_BLOCK) * 16.0 / 9.0)
	position = Vector2(left + (viewport_size.x - left - gutter - width) * 0.5, (viewport_size.y - height) * 0.5)
	size = Vector2(width, height)

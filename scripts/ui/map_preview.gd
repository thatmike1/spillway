extends PanelContainer
## a map's captured view follows either mouse hover or keyboard focus.
const UI := preload("res://scripts/r18_ui_theme.gd")
const DATA := preload("res://scripts/ui/map_previews.gd")
var selected_id := ""
var title: Label
var image: TextureRect
var caption: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UI.flat(UI.CREAM, 2, Vector4(16, 16, 16, 16)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	title = Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", UI.font("title"))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UI.INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	image = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(image)
	caption = Label.new()
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_override("font", UI.font("body"))
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", UI.INK_SOFT)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption)

func show_map(id: String, entry: Dictionary) -> void:
	selected_id = id
	title.text = "Preview: " + str(entry.get("name", id))
	image.texture = DATA.FRAMES.get(id)
	caption.text = str(entry.get("theme", "")) if image.texture != null else "Preview unavailable."

func arrange(viewport_size: Vector2, sidebar: Rect2) -> void:
	var left := sidebar.end.x + 26.0
	var width := maxf(0.0, viewport_size.x - left - 26.0)
	var height := minf(viewport_size.y - 52.0, width * 9.0 / 16.0 + 112.0)
	position = Vector2(left, (viewport_size.y - height) * 0.5)
	size = Vector2(width, height)

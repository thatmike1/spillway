extends RefCounted
## the front door: the wordmark large over the live spawn, the place you are standing in under
## it, one primary prompt with the vermilion lip, and the key list quiet at the bottom. it still
## takes no input of its own; the first key or move lifts it as before.
const UI := preload("res://scripts/r18_ui_theme.gd")
const PROMPT := "Move to run  ·  Esc  maps and settings"

static func _gradient(from: Vector2, to: Vector2, stops: Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return s[0]))
	gradient.colors = PackedColorArray(stops.map(func(s: Array) -> Color: return s[1]))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = from
	texture.fill_to = to
	texture.width = 256
	texture.height = 256
	return texture

static func restyle(card: Control, mark: Label) -> void:
	var scrim := card.get_node("Scrim") as TextureRect
	scrim.texture = _gradient(Vector2(0.0, 0.0), Vector2(0.32, 0.86), [[0.0, Color(UI.SLATE_DEEP, 0.80)], [0.42, Color(UI.SLATE_DEEP, 0.46)], [1.0, Color(UI.SLATE_DEEP, 0.0)]])
	var low := TextureRect.new()
	low.name = "ScrimLow"
	low.mouse_filter = Control.MOUSE_FILTER_IGNORE
	low.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	low.stretch_mode = TextureRect.STRETCH_SCALE
	low.texture = _gradient(Vector2(0.5, 1.0), Vector2(0.5, 0.0), [[0.0, Color(UI.INK, 0.62)], [1.0, Color(UI.INK, 0.0)]])
	card.add_child(low)
	card.move_child(low, scrim.get_index() + 1)
	var face := FontVariation.new()
	face.base_font = UI.font("display")
	mark.add_theme_font_override("font", face)
	mark.add_theme_color_override("font_color", UI.PALE)
	mark.add_theme_color_override("font_shadow_color", Color(UI.INK, 0.30))
	mark.add_theme_constant_override("shadow_offset_x", 0)
	mark.add_theme_constant_override("shadow_offset_y", 6)
	var lip := ColorRect.new()
	lip.name = "TitleLip"
	lip.color = UI.VERMILION
	lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lip)
	var map := card.get_node("TitleMap") as Label
	UI.world_label(map, "title", 30, UI.PALE, 0)
	map.add_theme_color_override("font_shadow_color", Color(UI.INK, 0.45))
	map.add_theme_constant_override("shadow_offset_y", 2)
	var prompt := card.get_node("TitlePrompt") as Label
	UI.ticket(prompt, "label", 18, SIDE_BOTTOM, 0.97)
	var box := prompt.get_theme_stylebox("normal") as StyleBoxFlat
	box.content_margin_left = UI.SPACE_L
	box.content_margin_right = UI.SPACE_L
	box.content_margin_top = UI.SPACE_M - 2
	box.content_margin_bottom = UI.SPACE_M
	prompt.text = PROMPT
	var keys := card.get_node("TitleKeys") as Label
	UI.world_label(keys, "body", 14, Color(UI.PALE, 0.92), 0)
	keys.add_theme_color_override("font_shadow_color", Color(UI.INK, 0.55))
	keys.add_theme_constant_override("shadow_offset_y", 1)
	keys.add_theme_constant_override("line_spacing", 3)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func layout(card: Control, mark: Label, size: Vector2, frame: Rect2) -> void:
	(card.get_node("Scrim") as Control).size = size
	var low := card.get_node_or_null("ScrimLow") as Control
	if low != null:
		low.position = Vector2(0, size.y * 0.6)
		low.size = Vector2(size.x, size.y * 0.4)
	var left := frame.position.x + roundf(frame.size.x * 0.05)
	var font_size := clampi(int(frame.size.x * 0.128), 84, UI.TYPE_WORDMARK + 60)
	mark.add_theme_font_size_override("font_size", font_size)
	var face := mark.get_theme_font("font") as FontVariation
	var tracking := -int(font_size * 0.025)
	if face != null and face.spacing_glyph != tracking:
		face.spacing_glyph = tracking
	mark.reset_size()
	var box := mark.get_minimum_size()
	mark.position = Vector2(left - font_size * 0.055, roundf(size.y * 0.075))
	(mark.material as ShaderMaterial).set_shader_parameter("box_size", box)
	var map := card.get_node("TitleMap") as Label
	var prompt := card.get_node("TitlePrompt") as Label
	var keys := card.get_node("TitleKeys") as Label
	var lip := card.get_node_or_null("TitleLip") as ColorRect
	map.reset_size()
	prompt.reset_size()
	# the label box carries the font's descent; the baseline sits about 78% of the way down.
	var baseline := mark.position.y + box.y * 0.80
	if lip != null:
		lip.position = Vector2(left, baseline + UI.SPACE_L)
		lip.size = Vector2(72, 4)
	map.position = Vector2(left, baseline + UI.SPACE_L + 4 + UI.SPACE_M)
	prompt.position = Vector2(left, map.position.y + map.get_minimum_size().y + UI.SPACE_XL)
	keys.custom_minimum_size.x = minf(980.0, frame.size.x - 2.0 * (left - frame.position.x))
	keys.reset_size()
	keys.position = Vector2(left, size.y - keys.get_minimum_size().y - maxf(28.0, size.y * 0.045))

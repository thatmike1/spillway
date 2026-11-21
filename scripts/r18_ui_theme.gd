extends RefCounted
## p / r18 ui language for look c. one typeface (bricolage grotesque, assets/ui/MANIFEST.json) in a
## few axis settings; the world's own colours: cream landing planes, ink structure, teal sides,
## sea-glass water and orange only where something is an edge or needs the eye. hud numbers sit
## straight on the world as cream with an ink outline; teaching text, toasts, the menu and the
## finish are cream sheets with ink type and an orange edge. no glow, no monospace, few capitals.

const FONT_PATH := "res://assets/ui/fonts/BricolageGrotesque-variable.ttf"
const CREAM := Color("f3ead7")
const CREAM_DEEP := Color("e6d8bc")
const CREAM_SHADE := Color("d9c9a8")
const INK := Color("18272e")
const INK_SOFT := Color(0.094, 0.153, 0.18, 0.66)
const TEAL := Color("2d5f6e")
const SEA := Color("9ad7c6")
const SEA_DEEP := Color("23705f")
const EDGE := Color("e15a2b")
const CORAL := Color("f2a483")
const CORAL_DEEP := Color("a9471f")
const OUTLINE := Color(0.07, 0.12, 0.15, 0.78)

# --- tokens -------------------------------------------------------------------------------------
# the names menus and hud should reach for. the colours are the world's own (blend c): the pale
# deck you land on, the weathered slate sides, sea-glass water, the vermilion lip, thin ink.
# the older names above stay as aliases so nothing that already uses them changes colour.
const PALE := CREAM                     ## deck white: sheets, tickets, hud numerals on the world
const PALE_DEEP := CREAM_DEEP           ## a pressed or inset area on a pale sheet
const PALE_SHADE := CREAM_SHADE         ## hairlines and wells on a pale sheet
const SLATE := TEAL                     ## weathered sides: secondary marks, the attempt line
const SLATE_DEEP := Color("1f4350")     ## the underside: scrims behind type on the world
const SEA_GLASS := SEA                  ## water: positive states, ahead of best
const SEA_GLASS_DEEP := SEA_DEEP        ## water in shade: positive text on pale
const VERMILION := EDGE                 ## edges and lips only: focus, selection, the one thing to see
const VERMILION_SOFT := CORAL           ## behind-best tint
const VERMILION_DEEP := CORAL_DEEP      ## behind-best text on pale
const INK_FAINT := Color(0.094, 0.153, 0.18, 0.38)   ## disabled type, quiet separators
const INK_WASH := Color(0.094, 0.153, 0.18, 0.07)    ## resting button and card fill on pale

## type scale in pixels at 1080p-class layouts (menus scale nothing; the hud picks its own).
const TYPE_WORDMARK := 190   ## title only; layouts clamp it to the frame
const TYPE_DISPLAY := 40     ## a screen's one big name (map name in the preview)
const TYPE_H1 := 34          ## sheet heading (paused map name)
const TYPE_H2 := 22          ## section heading on a wide sheet
const TYPE_H3 := 17          ## group heading inside a page
const TYPE_LABEL := 15       ## buttons, card names, row labels
const TYPE_BODY := 14        ## running text
const TYPE_SMALL := 12       ## notes, kinds, secondary lines
const TYPE_MICRO := 11       ## kickers in capitals with tracking

## spacing scale; rows and sections use these and nothing in between.
const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 12
const SPACE_L := 18
const SPACE_XL := 26
const SPACE_XXL := 40

const RADIUS := 2            ## every box: corners are almost square, like poured concrete
const EDGE_WIDTH := 3        ## the vermilion lip on selected and primary things
const HAIRLINE := 1          ## ink rules between rows

## a label in the menu language: ink on pale unless told otherwise, no outline.
static func text(label: Label, role: String, size: int, color: Color = INK) -> Label:
	label.add_theme_font_override("font", font(role))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return label

## a small capitals kicker (map group names, "paused"): tracked, quiet, never orange.
static func kicker(label: Label, color: Color = INK_SOFT) -> Label:
	text(label, "kicker", TYPE_MICRO, color)
	label.uppercase = true
	return label

static var _fonts: Dictionary = {}

## one face per role, cached. opsz follows the size it is drawn at; tnum keeps clocks still.
static func font(role: String) -> FontVariation:
	if _fonts.has(role):
		return _fonts[role]
	var axes := {"display": [96, 800, 100], "numeral": [60, 680, 96], "title": [32, 720, 100], "label": [16, 600, 100],
		"body": [16, 460, 100], "small": [12, 520, 100], "smallnum": [14, 600, 100], "kicker": [12, 640, 100]}
	var v: Array = axes.get(role, axes.body)
	var ts := TextServerManager.get_primary_interface()
	var face := FontVariation.new()
	face.base_font = load(FONT_PATH) as Font
	face.variation_opentype = {ts.name_to_tag("opsz"): v[0], ts.name_to_tag("wght"): v[1], ts.name_to_tag("wdth"): v[2]}
	if role in ["numeral", "smallnum", "display"]:
		face.opentype_features = {ts.name_to_tag("tnum"): 1, ts.name_to_tag("lnum"): 1}
	if role == "kicker":
		face.spacing_glyph = 1
	_fonts[role] = face
	return face

## hud text on the world: cream, ink outline, no box.
static func world_label(label: Label, role: String, size: int, color: Color = CREAM, outline: int = -1) -> void:
	# thin enough that small counters stay open; heavy text gets a little more.
	if outline < 0:
		outline = 2 if size <= 13 else (3 if size <= 22 else 4)
	label.add_theme_font_override("font", font(role))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_shadow_color", Color(OUTLINE, 0.35) if outline > 0 else Color(0, 0, 0, 0))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1 if outline > 0 else 0)
	label.add_theme_constant_override("shadow_outline_size", outline)
	label.remove_theme_stylebox_override("normal")

## the natural one-line width of a label's longest line, for wrapping cards at a sensible width.
static func text_width(label: Label) -> float:
	var face := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var widest := 0.0
	for line: String in label.text.split("\n"):
		widest = maxf(widest, face.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var box := label.get_theme_stylebox("normal")
	return widest + (box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT) if box != null else 0.0) + 2.0

## a cream ticket: ink type on the landing colour with the orange jump edge on one side.
static func ticket(label: Label, role: String, size: int, edge_side: int = SIDE_LEFT, alpha: float = 0.95) -> void:
	label.add_theme_font_override("font", font(role))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(CREAM, alpha)
	box.border_color = EDGE
	box.set_border_width(edge_side, 3)
	box.content_margin_left = 12.0 + (3.0 if edge_side == SIDE_LEFT else 0.0)
	box.content_margin_right = 12.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 7.0 + (2.0 if edge_side == SIDE_BOTTOM else 0.0)
	box.set_corner_radius_all(2)
	label.add_theme_stylebox_override("normal", box)

## the telemetry plate: dark, plain and only there while f9 is on.
static func telemetry_label(label: Label, size: int, color: Color = CREAM) -> void:
	label.add_theme_font_override("font", font("smallnum"))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.remove_theme_stylebox_override("normal")

static func flat(color: Color, radius: int = 2, margins: Vector4 = Vector4(10, 6, 10, 6)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w
	return box

static func _svg(source: String) -> Texture2D:
	return DPITexture.create_from_string(source)

static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)

## the menu theme: ink type on cream, selected items become an ink plate with an orange edge.
static func menu_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font("body")
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", INK)
	var plain := flat(Color(INK, 0.06), 2, Vector4(12, 7, 12, 8))
	var hover := flat(Color(INK, 0.13), 2, Vector4(12, 7, 12, 8))
	var chosen := flat(INK, 2, Vector4(12, 7, 12, 8))
	chosen.border_color = EDGE
	chosen.border_width_bottom = 3
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = EDGE
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	focus.set_expand_margin_all(2)
	var none := StyleBoxEmpty.new()
	for type: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, plain)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, chosen)
		theme.set_stylebox("hover_pressed", type, chosen)
		theme.set_stylebox("focus", type, focus)
		theme.set_stylebox("disabled", type, flat(Color(INK, 0.03), 2, Vector4(12, 7, 12, 8)))
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_focus_color", type, INK)
		theme.set_color("font_pressed_color", type, CREAM)
		theme.set_color("font_hover_pressed_color", type, CREAM)
		theme.set_color("font_disabled_color", type, Color(INK, 0.55))
		theme.set_font("font", type, font("label"))
		theme.set_font_size("font_size", type, 15)
	# text fields: the pale surface with a thin ink edge; focus takes the vermilion lip.
	var field := flat(PALE, RADIUS, Vector4(SPACE_M, SPACE_S - 1, SPACE_M, SPACE_S))
	field.border_color = Color(INK, 0.35)
	field.set_border_width_all(HAIRLINE)
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = EDGE
	field_focus.border_width_bottom = EDGE_WIDTH
	var field_quiet := flat(PALE_DEEP, RADIUS, Vector4(SPACE_M, SPACE_S - 1, SPACE_M, SPACE_S))
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_stylebox("read_only", "LineEdit", field_quiet)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", INK_FAINT)
	theme.set_color("font_uneditable_color", "LineEdit", INK_SOFT)
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_color("selection_color", "LineEdit", Color(SEA, 0.6))
	theme.set_font("font", "LineEdit", font("body"))
	theme.set_font_size("font_size", "LineEdit", 15)
	theme.set_icon("arrow", "OptionButton", _svg('<svg xmlns="http://www.w3.org/2000/svg" width="12" height="8"><path d="M1 1 L6 7 L11 1 Z" fill="%s"/></svg>' % _hex(INK)))
	for type: String in ["CheckButton", "CheckBox"]:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			theme.set_stylebox(state, type, flat(Color(0, 0, 0, 0), 2, Vector4(2, 5, 2, 5)))
		theme.set_stylebox("hover", type, flat(Color(INK, 0.07), 2, Vector4(2, 5, 2, 5)))
		theme.set_stylebox("hover_pressed", type, flat(Color(INK, 0.07), 2, Vector4(2, 5, 2, 5)))
		theme.set_stylebox("focus", type, focus)
		theme.set_font("font", type, font("label"))
		theme.set_font_size("font_size", type, 15)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(key, type, INK)
		theme.set_color("font_disabled_color", type, Color(INK, 0.38))
	var off := '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="22"><rect x="1" y="3" width="38" height="16" rx="8" fill="%s" fill-opacity="0.22"/><circle cx="11" cy="11" r="8" fill="%s"/><circle cx="11" cy="11" r="6" fill="%s"/></svg>' % [_hex(INK), _hex(INK), _hex(CREAM)]
	var on := '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="22"><rect x="1" y="3" width="38" height="16" rx="8" fill="%s"/><circle cx="29" cy="11" r="8" fill="%s"/><circle cx="29" cy="11" r="6" fill="%s"/></svg>' % [_hex(EDGE), _hex(INK), _hex(CREAM)]
	for key: String in ["checked", "checked_mirrored"]:
		theme.set_icon(key, "CheckButton", _svg(on))
	for key: String in ["unchecked", "unchecked_mirrored"]:
		theme.set_icon(key, "CheckButton", _svg(off))
	theme.set_icon("checked_disabled", "CheckButton", _svg(on))
	theme.set_icon("unchecked_disabled", "CheckButton", _svg(off))
	var track := flat(Color(INK, 0.18), 2, Vector4(0, 2, 0, 2))
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", flat(EDGE, 2, Vector4(0, 2, 0, 2)))
	theme.set_stylebox("grabber_area_highlight", "HSlider", flat(EDGE, 2, Vector4(0, 2, 0, 2)))
	var knob := '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"><circle cx="9" cy="9" r="7" fill="%s"/><circle cx="9" cy="9" r="3" fill="%s"/></svg>'
	theme.set_icon("grabber", "HSlider", _svg(knob % [_hex(INK), _hex(CREAM)]))
	theme.set_icon("grabber_highlight", "HSlider", _svg(knob % [_hex(EDGE), _hex(CREAM)]))
	theme.set_icon("grabber_disabled", "HSlider", _svg(knob % [_hex(INK_SOFT), _hex(CREAM)]))
	theme.set_stylebox("scroll", "VScrollBar", flat(Color(INK, 0.05), 3, Vector4(3, 0, 3, 0)))
	theme.set_stylebox("grabber", "VScrollBar", flat(Color(INK, 0.28), 3, Vector4(3, 0, 3, 0)))
	theme.set_stylebox("grabber_highlight", "VScrollBar", flat(Color(INK, 0.45), 3, Vector4(3, 0, 3, 0)))
	theme.set_stylebox("grabber_pressed", "VScrollBar", flat(EDGE, 3, Vector4(3, 0, 3, 0)))
	theme.set_stylebox("panel", "ScrollContainer", none)
	theme.set_stylebox("panel", "PopupMenu", flat(CREAM, 3, Vector4(6, 6, 6, 6)))
	theme.set_stylebox("hover", "PopupMenu", flat(INK, 2))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", CREAM)
	theme.set_font("font", "PopupMenu", font("label"))
	theme.set_font_size("font_size", "PopupMenu", 15)
	theme.set_stylebox("panel", "TooltipPanel", flat(INK, 3, Vector4(10, 6, 10, 6)))
	theme.set_color("font_color", "TooltipLabel", CREAM)
	theme.set_font("font", "TooltipLabel", font("body"))
	return theme

## the safe frame: hud blocks sit inside a centred 16:9 area so an ultrawide keeps them near
## the eye; the extra width is scenery.
static func safe_frame(size: Vector2, aspect: float = 16.0 / 9.0) -> Rect2:
	var width := minf(size.x, size.y * aspect)
	return Rect2(Vector2((size.x - width) * 0.5, 0.0), Vector2(width, size.y))

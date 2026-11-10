extends Control
## p / r16 style panel: one compact score block low on the right, above the r15 clock, and one
## short callout over it when something scores. it reads the style service's snapshot every
## frame and writes nothing to the game. the r15 layout keeps its places: identity top left,
## speed and the crouch tag low centre, strafe panel low left, clock low right, the middle clear
## for landings. same ink, accent and shade as r15_hud.gd, and the same default type.
##
## root wiring: add it under the r16 hud's CanvasLayer and call attach(main, style). optional
## fields read from main when present: `style_best` (int, < 0 none) for the active record key,
## `style_new_best` (bool) after a finish, `clean_eligible` and `finished` (r15 meanings).
## set_best() and set_new_best() override them for hosts without those fields.

const INK := Color("f4f1dd")
const ACCENT := Color("f3cd83")
const DIM := Color(0.957, 0.945, 0.867, 0.72)
const SHADE := Color(0.055, 0.10, 0.12)
## callout ranks: a fresh lower-ranked event never replaces a higher one still in its hold.
const RANK := {"crouch_save": 5, "backward_bhop": 4, "sideways_bhop": 3, "backward_bhop_bank": 4, "sideways_bhop_bank": 3, "gap": 4, "edge": 4, "near_miss": 3, "sync": 2, "speed": 1}
const HOLD_S := 0.9
const FADE_S := 0.5
const BAR_WIDTH := 132.0
## the clock block's top over the bottom edge (r15_hud.gd: shade at size.y - 78).
const CLOCK_TOP := 78.0

var game: Node
var style: RefCounted
var shade: ColorRect
var score_label: Label
var mult_label: Label
var bar: ColorRect
var bar_track: ColorRect
var best_label: Label
var callout: Label
var best_override: int = -2
var new_best_override: int = -1
var _shown_key: String = ""
var _shown_rank: int = 0
var _shown_age: float = INF
var _direction_toast_key: String = ""

func attach(main: Node, style_service: RefCounted) -> void:
	game = main
	style = style_service
	name = "R16StylePanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	shade = ColorRect.new()
	shade.color = Color(SHADE, 0.34)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	score_label = _label("0", 24, INK)
	mult_label = _label("", 16, ACCENT)
	best_label = _label("", 13, DIM)
	bar_track = ColorRect.new()
	bar_track.color = Color(INK, 0.16)
	bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_track)
	bar = ColorRect.new()
	bar.color = ACCENT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	callout = _label("", 19, ACCENT)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(SHADE, 0.40)
	box.set_content_margin_all(4.0)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.set_corner_radius_all(3)
	callout.add_theme_stylebox_override("normal", box)
	callout.modulate.a = 0.0
	if get_viewport() != null:
		get_viewport().size_changed.connect(_layout)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.12, 0.14, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func set_best(value: int) -> void:
	best_override = value

func set_new_best(value: bool) -> void:
	new_best_override = 1 if value else 0

## grouped thousands with a thin space: 12 340.
static func points_text(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = " " + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out

## the callout for one event: its own label and the points it earned.
static func callout_text(event: Dictionary) -> String:
	return "%s  +%s" % [str(event.get("label", event.get("kind", ""))), points_text(int(event.get("points", 0)))]

func _process(delta: float) -> void:
	if style == null:
		return
	var paused := game != null and bool(game.get("paused"))
	visible = not paused
	if paused:
		return
	var snap: Dictionary = style.call("snapshot")
	update_from(snap, delta)

## everything the panel shows comes from one snapshot; tests call this directly.
func update_from(snap: Dictionary, delta: float) -> void:
	var score := int(snap.get("score", 0))
	score_label.text = points_text(score)
	var combo := int(snap.get("combo", 0))
	mult_label.text = "×%s" % _mult_text(float(snap.get("mult", 1.0))) if combo >= 2 else ""
	var window := maxf(0.001, float(snap.get("combo_window_s", 1.0)))
	var left := clampf(float(snap.get("combo_left_s", 0.0)) / window, 0.0, 1.0) if combo > 0 else 0.0
	bar.size = Vector2(BAR_WIDTH * left, 2.0)
	bar.visible = combo > 0
	bar_track.visible = combo > 0
	best_label.text = _best_text(score)
	var last: Dictionary = snap.get("last", {})
	_shown_age += delta
	var key := "%s@%s/%s" % [str(last.get("kind", "")), str(last.get("time_s", "")), str(last.get("tick", ""))]
	if not last.is_empty() and key != _shown_key:
		var rank := int(RANK.get(str(last.get("kind", "")), 1))
		if rank >= _shown_rank or _shown_age > HOLD_S * 0.66:
			callout.text = callout_text(last)
			_shown_rank = rank
			_shown_age = 0.0
		_shown_key = key
	var transition: Dictionary = (snap.get("direction", {}) as Dictionary).get("last", {})
	var serial := int(transition.get("serial", -1))
	var transition_key := "%s/%d" % [str(snap.get("context", {})), serial]
	if not transition.is_empty() and transition_key != _direction_toast_key:
		_direction_toast_key = transition_key
		var pending := int(transition.get("pending", 0))
		var rank := 4 if str(transition.get("direction", "")) == "backward_bhop" else 3
		if pending > 0 and (rank >= _shown_rank or _shown_age > HOLD_S * 0.66):
			var word := "Backwards" if str(transition.get("direction", "")) == "backward_bhop" else "Half-sideways"
			callout.text = "%s %s  %s%s" % [word, "banked" if transition.kind == "direction_banked" else "lost",
				"+" if transition.kind == "direction_banked" else "", points_text(pending)]
			_shown_rank = rank
			_shown_age = 0.0
	if _shown_age <= HOLD_S:
		callout.modulate.a = 1.0
	else:
		callout.modulate.a = clampf(1.0 - (_shown_age - HOLD_S) / FADE_S, 0.0, 1.0)
		if callout.modulate.a <= 0.0:
			_shown_rank = 0
	_layout()

static func _mult_text(mult: float) -> String:
	var text := "%.2f" % mult
	while text.ends_with("0"):
		text = text.left(text.length() - 1)
	return text.trim_suffix(".")

func _best_text(score: int) -> String:
	if game == null:
		return ""
	var clean: Variant = game.get("clean_eligible")
	var finished := bool(game.get("finished")) if game.get("finished") != null else false
	var new_best: bool = new_best_override == 1 or (new_best_override < 0 and game.get("style_new_best") == true)
	if finished and new_best:
		return "new style best"
	if clean == false:
		return "practice, style not saved"
	var best := best_override
	if best == -2:
		var from_game: Variant = game.get("style_best")
		best = int(from_game) if from_game != null else -1
	if best > 0:
		return "style best %s" % points_text(best)
	return "no style best yet" if score > 0 or finished else ""

func _layout() -> void:
	var size := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var right := size.x - 22.0
	for label: Label in [score_label, mult_label, best_label, callout]:
		label.reset_size()
	var base := size.y - CLOCK_TOP - 8.0
	best_label.visible = not best_label.text.is_empty()
	var best_h := best_label.get_minimum_size().y if best_label.visible else 0.0
	best_label.position = Vector2(right - best_label.get_minimum_size().x, base - best_h)
	var bar_y := best_label.position.y - 6.0
	bar_track.position = Vector2(right - BAR_WIDTH, bar_y)
	bar_track.size = Vector2(BAR_WIDTH, 2.0)
	bar.position = Vector2(right - bar.size.x, bar_y)
	var score_size := score_label.get_minimum_size()
	score_label.position = Vector2(right - score_size.x, bar_y - 2.0 - score_size.y)
	var mult_size := mult_label.get_minimum_size()
	mult_label.position = Vector2(score_label.position.x - 10.0 - mult_size.x, score_label.position.y + score_size.y - mult_size.y - 3.0)
	var left := minf(minf(score_label.position.x, mult_label.position.x if not mult_label.text.is_empty() else INF), minf(bar_track.position.x, best_label.position.x))
	shade.position = Vector2(left - 10.0, score_label.position.y - 4.0)
	shade.size = Vector2(right - shade.position.x + 10.0, base - shade.position.y + 2.0)
	callout.position = Vector2(right - callout.get_minimum_size().x + 10.0, shade.position.y - callout.get_minimum_size().y - 8.0)

extends Control
## the survey drawing makes fixed heights explicit instead of pretending to pick depth.
const LAYOUT := preload("res://scripts/plan/layout.gd")
var runner: CharacterBody3D
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
func point(at: Vector3) -> Vector2:
	return Vector2(size.x * 0.5 + at.x * 7, size.y * 0.5 + (at.z+17) * 7)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("203d45"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(30, 42), "PLAN YARD  /  SURVEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("efe8cf"))
	draw_string(font, Vector2(30, 74), "Click or press 1–9. Three anchors maximum. Enter runs. Tab restarts into planning.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("efe8cf"))
	for rect: Rect2 in [Rect2(-18, 5, 36, 15), Rect2(-18, -55, 36, 21), Rect2(-18, -34, 7, 39), Rect2(11, -34, 7, 39), Rect2(-5, -18, 10, 10), Rect2(-5, -30, 10, 9)]:
		draw_rect(Rect2(point(Vector3(rect.position.x, 0, rect.position.y)), rect.size*7), Color("b9b8a5"))
	var level: Node = runner.get_parent().get("level")
	for i: int in LAYOUT.SOCKETS.size():
		var p := point(LAYOUT.SOCKETS[i])
		draw_circle(p, 13, Color("cd854f") if i in level.plan else Color("6c8f95"))
		draw_string(font, p+Vector2(17, 5), "%d / %dm" % [i+1, LAYOUT.SOCKETS[i].y], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("efe8cf"))
	draw_circle(point(runner.get_parent().get("level").spawn.origin), 6, Color("203d45"))
	draw_string(font, point(Vector3(-17, 0, 17)), "SPAWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("203d45"))
	draw_string(font, point(Vector3(-17, 0, -47)), "FINISH", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("203d45"))
	draw_string(font, Vector2(30, size.y-30), "%d / 3 anchors placed. Datum: quays +3m, caisson +7/+9m, sea -4m." % level.plan.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("efe8cf"))
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i: int in LAYOUT.SOCKETS.size():
			if point(LAYOUT.SOCKETS[i]).distance_to(event.position) < 18:
				toggle_socket(i)
				accept_event()
				return

func toggle_socket(index: int) -> void:
	if index < 0 or index >= LAYOUT.SOCKETS.size():
		return
	var level: Node = runner.get_parent().get("level")
	var next: Array = level.plan.duplicate()
	if index in next:
		next.erase(index)
	elif next.size() < 3:
		next.append(index)
	level.apply_plan(next)
	queue_redraw()

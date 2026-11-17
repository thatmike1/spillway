extends "res://scripts/movement/grapple_player.gd"
## isolate planning from the inherited F2 motor and Arc force law.
const OVERLAY := preload("res://scripts/plan/overlay.gd")
var planner: Control
var planning := false
func _ready() -> void:
	super()
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	planner = OVERLAY.new()
	planner.runner = self
	layer.add_child(planner)
	planner.hide()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		if code == KEY_TAB:
			open_plan()
			get_viewport().set_input_as_handled()
		elif planning and code == KEY_ENTER:
			close_plan()
			get_viewport().set_input_as_handled()
func open_plan() -> void:
	var game := get_parent()
	if game.get("level") == null:
		return
	game.restart_run("plan_edit")
	planning = true
	block_tether("plan")
	input_enabled = false
	planner.show()
	planner.queue_redraw()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
func close_plan() -> void:
	planning = false
	planner.hide()
	var game := get_parent()
	game.session.boundary("plan_commit")
	game.course_geometry = game.level.geometry_hash()
	game._refresh_records()
	game.restart_run("plan_commit")
func _physics_process(delta: float) -> void:
	if planning:
		return
	super(delta)

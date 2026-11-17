extends "res://scripts/movement/course_player.gd"
## mail controls exist only on mail-run; the inherited f2 motor is untouched.
const FLIGHT := preload("res://scripts/mail/flight.gd")
var mail_flight := FLIGHT.new()
var view_mode := "envelope"
var _throw_pending := false
var _cancel_pending := false
var _turn := Vector2.ZERO
var _paper: MeshInstance3D
var _status: Label
var _mailboxes: Array = []
var _frozen_step := false

func _ready() -> void:
	super()
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--mail-view=body":
			view_mode = "body"
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(24, 150)
	_status.add_theme_font_size_override("font_size", 20)
	layer.add_child(_status)
	_paper = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.36, 0.025, 0.23)
	_paper.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("fff4d6")
	_paper.material_override = material
	add_child(_paper)
	_paper.top_level = true

func movement_version() -> String:
	return "mail-run-1/frozen-body/" + view_mode

func mail_view() -> String:
	return view_mode

func set_mail_view(value: String) -> void:
	if value not in ["envelope", "body"] or value == view_mode:
		return
	var host := get_parent()
	if host.has_method("restart_run"):
		host.get("session").boundary("mail_view")
	view_mode = value
	if host.has_method("restart_run"):
		host.call("_refresh_records")
		host.call("restart_run", "mail_view")

func reset_to(pose: Transform3D) -> void:
	mail_flight.clear()
	_throw_pending = false
	_cancel_pending = false
	_turn = Vector2.ZERO
	_frozen_step = false
	super(pose)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		set_mail_view("body" if view_mode == "envelope" else "envelope")
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_throw_pending = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_pending = true
	if mail_flight.active and event is InputEventMouseMotion:
		_turn += Vector2(event.screen_relative.x, -event.screen_relative.y) * 0.0025
		return
	super(event)

func _physics_process(delta: float) -> void:
	if not input_enabled:
		super(delta)
		return
	var level: Variant = get_parent().get("level")
	if level != null:
		_mailboxes = level.get("mailboxes")
	if _throw_pending and not mail_flight.active:
		mail_flight.launch(global_position + Vector3.UP * _eye_u * U, -Basis.from_euler(Vector3(pitch, yaw, 0)).z)
	_throw_pending = false
	if _cancel_pending:
		mail_flight.end("cancel")
	_cancel_pending = false
	_frozen_step = mail_flight.active
	if mail_flight.active:
		# hold position and velocity; resume the exact motor state and held hop afterward.
		_previous_position = global_position
		_current_position = global_position
		_prev_eye_u = _eye_u
		_displacement = Vector3.ZERO
		_actual_velocity = Vector3.ZERO
		_duck_shift = Vector3.ZERO
		mail_flight.steer(_turn, 1.0)
		_turn = Vector2.ZERO
		mail_flight.step(delta, _mailboxes, _blocked)
	else:
		super(delta)
	_paper.visible = mail_flight.active
	_paper.global_position = mail_flight.position
	_status.text = "MAIL %d / 3    MISSES %d\nLMB throw · mouse steer · RMB recall\nV view: %s (restarts)\n%s" % [mail_flight.delivered.size(), mail_flight.misses, view_mode, "BODY HELD · %.1fs" % maxf(0, FLIGHT.DURATION - mail_flight.age) if mail_flight.active else mail_flight.result.to_upper()]

func _blocked(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func _update_eye(delta: float) -> void:
	super(delta)
	if mail_flight.active and view_mode == "envelope":
		camera.global_position = mail_flight.position - mail_flight.direction * 0.7 + Vector3.UP * 0.15
		camera.look_at(mail_flight.position + mail_flight.direction * 3.0)

func get_motion_state() -> Dictionary:
	var out := super()
	out["mail"] = {"active": mail_flight.active, "view": view_mode, "delivered": mail_flight.delivered.keys(), "misses": mail_flight.misses}
	if _frozen_step:
		out["events"] = []
		out["mode"] = "mail-hold"
		out["requested_velocity"] = Vector3.ZERO
		out["depenetration"] = Vector3.ZERO
		out["standoff"] = Vector3.ZERO
		out["air_gain_u"] = 0.0
		out["contacts"] = []
		out["contact_count"] = 0
	return out

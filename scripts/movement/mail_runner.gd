extends "res://scripts/movement/course_player.gd"
## mail controls exist only on mail-run; the inherited f2 motor is untouched.
const FEEDBACK := preload("res://scripts/mail/feedback.gd")
const FLIGHT := preload("res://scripts/mail/flight.gd")
var mail_flight := FLIGHT.new()
var view_mode := "envelope"
var body_mode := "hold"
var goal_mode := "deliver"
var _style_suspended := false
var _feedback: Node3D
var _throw_pending := false
var _cancel_pending := false
var _turn := Vector2.ZERO
var _paper: MeshInstance3D
var _status: Label
var _mailboxes: Array = []
var _frozen_step := false

func _ready() -> void:
	process_priority = 100
	super()
	_feedback = FEEDBACK.new()
	add_child(_feedback)
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--mail-view=body":
			view_mode = "body"
		elif arg == "--mail-body=run":
			body_mode = "run"
		elif arg == "--mail-goal=optional":
			goal_mode = "optional"
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(820, 108)
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color("172d32"))
	_status.add_theme_color_override("font_outline_color", Color("fff4d6"))
	_status.add_theme_constant_override("outline_size", 3)
	preload("res://scripts/r18_ui_theme.gd").ticket(_status, "label", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(390, 0)
	_status.size = Vector2(390, 0)
	layer.add_child(_status)
	_paper = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.36, 0.23, 0.025)
	_paper.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("fff4d6")
	_paper.material_override = material
	add_child(_paper)
	_paper.top_level = true
	var seams := MeshInstance3D.new()
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for point: Vector3 in [Vector3(-0.18, 0.115, 0.014), Vector3(0, -0.025, 0.014), Vector3(0, -0.025, 0.014), Vector3(0.18, 0.115, 0.014), Vector3(-0.18, -0.115, 0.014), Vector3(0, 0.015, 0.014), Vector3(0, 0.015, 0.014), Vector3(0.18, -0.115, 0.014)]:
		lines.surface_add_vertex(point)
	lines.surface_end()
	seams.mesh = lines
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color("53666a")
	seams.material_override = ink
	_paper.add_child(seams)

func movement_version() -> String:
	return "mail-run-2/%s/%s/%s" % [body_mode, view_mode, goal_mode]

func mail_view() -> String:
	return view_mode

func mail_body() -> String:
	return body_mode

func mail_goal() -> String:
	return goal_mode

func delivery_progress() -> Vector2i:
	var stage := maxi(0, int(get_parent().get("practice_stage")))
	var count := 0
	for i: int in range(stage, 3):
		if mail_flight.delivered.has("mail-run-post-%d" % (i + 1)):
			count += 1
	return Vector2i(count, maxi(0, 3 - stage))

func delivery_goal_met() -> bool:
	var progress := delivery_progress()
	return goal_mode == "optional" or progress.x == progress.y

func set_mail_view(value: String) -> void:
	if value in ["envelope", "body"]:
		_change_mode("view_mode", value)

func set_mail_body(value: String) -> void:
	if value in ["hold", "run"]:
		_change_mode("body_mode", value)

func set_mail_goal(value: String) -> void:
	if value in ["deliver", "optional"]:
		_change_mode("goal_mode", value)

func _change_mode(key: String, value: String) -> void:
	if str(get(key)) == value:
		return
	var host := get_parent()
	var was_paused := bool(host.get("paused"))
	if host.has_method("restart_run"):
		host.get("session").boundary("mail_setting", {"key": key, "value": value})
	set(key, value)
	if host.has_method("restart_run"):
		host.call("_refresh_records")
		host.call("restart_run", "mail_setting")
		host.call("set_paused", was_paused)

func _hold_style(suspend: bool) -> void:
	if suspend == _style_suspended:
		return
	_style_suspended = suspend
	var session: Variant = get_parent().get("session")
	if session != null:
		session.lifecycle("mail_hold", {"held": suspend}, "pause" if suspend else "resume")

func reset_to(pose: Transform3D) -> void:
	_hold_style(false)
	var completed := is_inside_tree() and bool(get_parent().get("finished"))
	var delivered: Dictionary = mail_flight.delivered.duplicate()
	var misses: int = mail_flight.misses
	mail_flight.clear()
	if completed:
		mail_flight.delivered = delivered
		mail_flight.misses = misses
	if _feedback != null:
		_feedback.reset()
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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		set_mail_body("run" if body_mode == "hold" else "hold")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:
		set_mail_goal("optional" if goal_mode == "deliver" else "deliver")
		return
	if event is InputEventMouseButton and bool(get_parent().get("finished")):
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_throw_pending = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_pending = true
	if mail_flight.active and event is InputEventMouseMotion:
		_turn += Vector2(event.screen_relative.x, -event.screen_relative.y) * tape_radians_per_count * 3.25
		return
	super(event)

func _physics_process(delta: float) -> void:
	if not input_enabled:
		_feedback.observe(mail_flight, true)
		super(delta)
		return
	var level: Variant = get_parent().get("level")
	if level != null:
		_mailboxes = level.get("mailboxes")
	if bool(get_parent().get("finished")):
		_throw_pending = false
		_cancel_pending = false
		_turn = Vector2.ZERO
		if mail_flight.active:
			mail_flight.active = false
			mail_flight.result = "finish"
	if _throw_pending and not mail_flight.active:
		mail_flight.launch(global_position + Vector3.UP * _eye_u * U, -Basis.from_euler(Vector3(pitch, yaw, 0)).z)
	_throw_pending = false
	if _cancel_pending:
		mail_flight.end("cancel")
	_cancel_pending = false
	_frozen_step = mail_flight.active and body_mode == "hold"
	_hold_style(_frozen_step)
	if _frozen_step:
		# hold position and velocity; resume the exact motor state and held hop afterward.
		_previous_position = global_position
		_current_position = global_position
		_prev_eye_u = _eye_u
		_displacement = Vector3.ZERO
		_actual_velocity = Vector3.ZERO
		_duck_shift = Vector3.ZERO
	else:
		super(delta)
	if mail_flight.active:
		mail_flight.steer(_turn, 1.0)
		_turn = Vector2.ZERO
		mail_flight.step(delta, _mailboxes, _blocked)
	_feedback.observe(mail_flight, false)
	_paper.visible = mail_flight.active
	_paper.global_position = mail_flight.position
	if mail_flight.active:
		_paper.look_at(mail_flight.position + mail_flight.direction, Vector3.UP if absf(mail_flight.direction.y) < 0.99 else Vector3.RIGHT)
	var progress := delivery_progress()
	_status.text = "MAIL %d / %d    MISSES %d" % [progress.x, progress.y, mail_flight.misses]
	_status.text += "\n%s · %s · %s" % ["Envelope" if view_mode == "envelope" else "Runner view", "Held" if body_mode == "hold" else "Running", "%d required" % progress.y if goal_mode == "deliver" else "Optional"]
	if mail_flight.active:
		_status.text += "\nSTEER · RMB recall · %.1fs" % maxf(0, FLIGHT.DURATION - mail_flight.age)
		if body_mode == "hold":
			_status.text += "\nKEPT %.0f u/s" % (control_speed() / U)
	elif not bool(get_parent().get("_started")):
		_status.text += "\nLMB throw · mouse steer · RMB recall\nV view · B body · N goal (restart)"
	elif not mail_flight.result.is_empty():
		_status.text += "\n" + mail_flight.result.to_upper()


func _process(delta: float) -> void:
	super(delta)
	if _status != null:
		_status.visible = input_enabled
		# presentation only: a hud that can place the ticket owns its position and size.
		var placer: Variant = get_parent().get("hud")
		if placer != null and placer.has_method("place_runner_status"):
			placer.call("place_runner_status", _status)
			return
		var top := 108.0
		var hud: Variant = get_parent().get("hud")
		if hud != null:
			var badge: Variant = hud.get("lab_tag")
			if badge != null and badge.visible:
				top = maxf(top, badge.position.y + badge.get_minimum_size().y + 16.0)
		_status.position = Vector2(maxf(24, get_viewport().get_visible_rect().size.x - 420), top)

func _blocked(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func _update_eye(delta: float) -> void:
	super(delta)
	if mail_flight.active and view_mode == "envelope":
		var right: Vector3 = mail_flight.direction.cross(Vector3.UP).normalized()
		camera.global_position = mail_flight.position - mail_flight.direction * 0.9 + Vector3.UP * 0.35 + right * 0.25
		camera.look_at(mail_flight.position + mail_flight.direction * 3.0)

func get_motion_state() -> Dictionary:
	var out := super()
	out["mail"] = {"active": mail_flight.active, "view": view_mode, "body": body_mode, "goal": goal_mode, "style_held": _style_suspended, "delivered": mail_flight.delivered.keys(), "misses": mail_flight.misses}
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

extends CharacterBody3D
## First-person runner. Velocity is world space. "Up" is the body's local +Y:
## it stays world up everywhere except on surfaces tagged gravity_surface, where
## it follows the floor normal and the velocity turns with it.
## The camera is a separate top-level rig so mouse look is immediate while
## gravity turns ease visibly and physics steps are interpolated.

signal jumped
signal landed(impact: float)
signal footstep(strength: float)
signal move_started(kind: String)

enum Move { GROUND, AIR, WALLRUN, CLIMB, SLIDE }

const STAND_HEIGHT: float = 1.8
const LOW_HEIGHT: float = 1.0
const RADIUS: float = 0.35
const EYE_STAND: float = 0.72
const EYE_LOW: float = -0.02

@export var base_speed: float = 6.2
@export var top_speed: float = 9.6
@export var momentum_time: float = 1.4
@export var jump_speed: float = 6.6
@export var gravity_strength: float = 18.0
@export var mouse_sensitivity: float = 0.0022
@export var stick_look_speed: float = 3.2
@export var invert_y: bool = false
@export var fov_horizontal: float = 90.0
@export var speed_fov: bool = true
@export_range(0.0, 1.0) var bank_amount: float = 1.0
@export var head_bob_enabled: bool = false

var controls_enabled: bool = true
var move: Move = Move.GROUND
var momentum: float = 0.0
var grounded: bool = false

var _pitch: float = 0.0
var _jump_buffer: float = 0.0
var _coyote: float = 0.0
var _since_jump: float = 1.0
var _air_time: float = 0.0
var _fall_speed: float = 0.0
var _stride: float = 0.0
var _crouched: bool = false
var _slide_speed: float = 0.0
var _slide_time: float = 0.0
var _wall_normal: Vector3 = Vector3.ZERO
var _wall_side: float = 0.0
var _wall_time: float = 0.0
var _last_wall_normal: Vector3 = Vector3.ZERO
var _climb_from: Vector3 = Vector3.ZERO
var _climb_to: Vector3 = Vector3.ZERO
var _climb_time: float = 0.0
var _climb_duration: float = 0.4
var _climb_exit: Vector3 = Vector3.ZERO
var _climb_kind: String = ""
var _climb_hand: Vector3 = Vector3.ZERO
var _eye_height: float = EYE_STAND
var _prev_eye: Vector3 = Vector3.ZERO
var _curr_eye: Vector3 = Vector3.ZERO
var _view_q: Quaternion = Quaternion.IDENTITY
var _dip: float = 0.0
var _dip_velocity: float = 0.0
var _nod: float = 0.0
var _nod_velocity: float = 0.0
var _roll: float = 0.0
var _fov_extra: float = 0.0
var _bob_phase: float = 0.0
var _input_axis: Vector2 = Vector2.ZERO
var _rig: Node3D
var _camera: Camera3D
@onready var _collider: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("player")
	_collider.shape = _collider.shape.duplicate()
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = true
	floor_block_on_wall = true
	max_slides = 6
	_rig = Node3D.new()
	_rig.name = "CameraRig"
	_rig.top_level = true
	add_child(_rig)
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.near = 0.05
	_camera.far = 3000.0
	_camera.current = true
	_rig.add_child(_camera)
	_snap_view()


# ---------------------------------------------------------------- public API

func get_camera() -> Camera3D:
	return _camera


func get_rig() -> Node3D:
	return _rig


func get_speed() -> float:
	return velocity.slide(up_direction).length()


func get_pitch() -> float:
	return _pitch


func get_yaw_forward() -> Vector3:
	return -global_basis.z


func get_input_axis() -> Vector2:
	return _input_axis


func get_stride() -> float:
	return _stride


func get_air_time() -> float:
	return _air_time if not grounded else 0.0


func get_wall_side() -> float:
	return _wall_side if move == Move.WALLRUN else 0.0


func get_climb_progress() -> float:
	return clampf(_climb_time / maxf(_climb_duration, 0.01), 0.0, 1.0) if move == Move.CLIMB else 0.0


func get_climb_kind() -> String:
	return _climb_kind if move == Move.CLIMB else ""


func get_climb_hand_point() -> Vector3:
	return _climb_hand


func is_low() -> bool:
	return move == Move.SLIDE or _crouched


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		_jump_buffer = 0.0


func queue_jump() -> void:
	_jump_buffer = 0.16


func look(yaw_delta: float, pitch_delta: float) -> void:
	if not controls_enabled:
		return
	rotate_object_local(Vector3.UP, yaw_delta)
	_view_q = (_view_q * Quaternion(Vector3.UP, yaw_delta)).normalized()
	_pitch = clampf(_pitch + pitch_delta, deg_to_rad(-88.0), deg_to_rad(88.0))


func reset_to(spawn: Transform3D, up: Vector3 = Vector3.UP) -> void:
	var basis_now: Basis = spawn.basis.orthonormalized()
	if not up.is_equal_approx(basis_now.y):
		basis_now = Basis(Quaternion(basis_now.y, up.normalized())) * basis_now
	global_transform = Transform3D(basis_now.orthonormalized(), spawn.origin)
	up_direction = up.normalized()
	velocity = Vector3.ZERO
	move = Move.GROUND
	momentum = 0.0
	_pitch = 0.0
	_jump_buffer = 0.0
	_coyote = 0.0
	_since_jump = 1.0
	_air_time = 0.0
	_fall_speed = 0.0
	_wall_time = 0.0
	_last_wall_normal = Vector3.ZERO
	_dip = 0.0
	_dip_velocity = 0.0
	_nod = 0.0
	_nod_velocity = 0.0
	_roll = 0.0
	_set_low(false, true)
	_eye_height = EYE_STAND
	reset_physics_interpolation()
	_snap_view()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		# screen_relative ignores the canvas stretch, so sensitivity is the same at any window size
		var delta: Vector2 = motion.screen_relative
		look(-delta.x * mouse_sensitivity, -delta.y * mouse_sensitivity * (-1.0 if invert_y else 1.0))
	elif event.is_action_pressed("jump"):
		_jump_buffer = 0.16


func _read_stick_look(delta: float) -> void:
	var stick: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.15)
	if stick.length_squared() < 0.0001:
		return
	# a gentle response curve keeps small stick motions precise
	var shaped: Vector2 = stick * stick.length()
	look(-shaped.x * stick_look_speed * delta, -shaped.y * stick_look_speed * 0.7 * delta * (-1.0 if invert_y else 1.0))


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	_prev_eye = _curr_eye
	_since_jump += delta
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_input_axis = Vector2.ZERO
	var crouch_held: bool = false
	if controls_enabled:
		_input_axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.2)
		crouch_held = Input.is_action_pressed("crouch")
		_read_stick_look(delta)
	match move:
		Move.CLIMB:
			_step_climb(delta)
		Move.WALLRUN:
			_step_wallrun(delta)
		Move.SLIDE:
			_step_slide(delta, crouch_held)
		_:
			_step_free(delta, crouch_held)
	_follow_surface()
	var target_eye: float = EYE_LOW if is_low() else EYE_STAND
	_eye_height = move_toward(_eye_height, target_eye, delta * (5.5 if target_eye < _eye_height else 3.2))
	_curr_eye = global_position + up_direction * _eye_height


func _wish(axis: Vector2) -> Vector3:
	var forward: Vector3 = (-global_basis.z).slide(up_direction).normalized()
	var right: Vector3 = global_basis.x.slide(up_direction).normalized()
	var wish: Vector3 = right * axis.x - forward * axis.y
	return wish.limit_length(1.0)


func _step_free(delta: float, crouch_held: bool) -> void:
	var up: Vector3 = up_direction
	var was_grounded: bool = grounded
	grounded = is_on_floor() and _since_jump > 0.08
	if grounded:
		_coyote = 0.13
		_air_time = 0.0
	else:
		_coyote = maxf(0.0, _coyote - delta)
		_air_time += delta
	var wish: Vector3 = _wish(_input_axis)
	var forward_input: float = -_input_axis.y
	var vertical: float = velocity.dot(up)
	var lateral: Vector3 = velocity - up * vertical
	var lateral_speed: float = lateral.length()

	if grounded:
		if forward_input > 0.5 and lateral_speed > base_speed * 0.85:
			momentum = minf(1.0, momentum + delta / momentum_time)
		elif _input_axis.length() < 0.1:
			momentum = maxf(0.0, momentum - delta * 2.0)
		# running into something bleeds momentum to match the speed you really have
		momentum = minf(momentum, clampf(inverse_lerp(base_speed, top_speed, lateral_speed + 1.2), 0.0, 1.0))
	var max_speed: float = lerpf(base_speed, top_speed, momentum)
	if forward_input < 0.3:
		max_speed = minf(max_speed, base_speed * 0.85)
	_crouched = grounded and crouch_held and lateral_speed < 5.0
	if _crouched:
		max_speed = 3.0
	_set_low(_crouched, false)

	if grounded:
		var target: Vector3 = wish * max_speed
		var rate: float = 34.0 if target.length() >= lateral_speed - 0.1 else 24.0
		lateral = lateral.move_toward(target, rate * delta)
		# a light press into the floor keeps contact over convex curves and edges
		vertical = minf(vertical, -1.5)
		_stride += lateral.length() * delta
	else:
		if wish.length_squared() > 0.01:
			var cap: float = maxf(lateral_speed, base_speed * 0.8)
			lateral = lateral.move_toward(wish * cap, 9.0 * delta)
		var g: float = gravity_strength * (1.22 if vertical < 0.0 else 1.0)
		vertical = maxf(vertical - g * delta, -42.0)
	velocity = lateral + up * vertical

	# actions in order of priority: slide, vault/climb, wall-run, jump
	if grounded and crouch_held and lateral_speed > 5.2 and _since_jump > 0.15:
		_begin_slide(lateral)
		return
	if forward_input > 0.4 and _since_jump > 0.12:
		if grounded and lateral_speed > 2.0 and _try_ledge(1.25, 0.5 + lateral_speed * 0.05, false):
			return
		if not grounded and vertical < 4.0 and _try_ledge(2.0, 0.65, true):
			return
	if _jump_buffer > 0.0 and grounded and _try_ledge(1.25, 0.9, false):
		return
	if not grounded and _air_time > 0.04 and _try_wallrun(lateral, forward_input):
		return
	if _jump_buffer > 0.0 and (grounded or _coyote > 0.0):
		_do_jump(up * jump_speed + lateral * 1.02)
		return

	var pre_velocity: Vector3 = velocity
	move_and_slide()
	_after_move(was_grounded, pre_velocity)


func _after_move(was_grounded: bool, pre_velocity: Vector3) -> void:
	var now_grounded: bool = is_on_floor()
	var down_speed: float = -pre_velocity.dot(up_direction)
	if now_grounded and not was_grounded and _since_jump > 0.1:
		grounded = true
		_last_wall_normal = Vector3.ZERO
		var impact: float = maxf(down_speed, 0.0)
		if impact > 2.0:
			_on_land(impact)
	if grounded and now_grounded:
		var stride_length: float = 2.2
		if _stride >= stride_length:
			_stride = fmod(_stride, stride_length)
			footstep.emit(clampf(get_speed() / top_speed, 0.2, 1.0))


func _on_land(impact: float) -> void:
	_dip_velocity -= clampf(impact * 0.11, 0.3, 2.6)
	_nod_velocity -= clampf(impact * 0.012, 0.0, 0.16)
	# a very hard landing costs some speed, a normal one keeps it all
	if impact > 15.0:
		momentum *= 0.6
		velocity = velocity * 0.75
	landed.emit(impact)


func _do_jump(new_velocity: Vector3) -> void:
	velocity = new_velocity
	grounded = false
	_since_jump = 0.0
	_coyote = 0.0
	_jump_buffer = 0.0
	_set_low(false, false)
	move = Move.AIR
	_nod_velocity += 0.05
	jumped.emit()
	move_and_slide()


# ---------------------------------------------------------------- slide

func _begin_slide(lateral: Vector3) -> void:
	move = Move.SLIDE
	_slide_speed = lateral.length() + 0.9
	_slide_time = 0.0
	_set_low(true, false)
	_dip_velocity -= 0.4
	move_started.emit("slide")
	velocity = lateral.normalized() * _slide_speed
	move_and_slide()


func _step_slide(delta: float, crouch_held: bool) -> void:
	_slide_time += delta
	var up: Vector3 = up_direction
	var lateral: Vector3 = velocity.slide(up)
	var direction: Vector3 = lateral.normalized() if lateral.length_squared() > 0.01 else (-global_basis.z).slide(up).normalized()
	var wish: Vector3 = _wish(_input_axis)
	if wish.length_squared() > 0.01:
		var steer: float = clampf(direction.signed_angle_to(wish, up), -1.0, 1.0) * 1.4 * delta
		direction = direction.rotated(up, steer)
	_slide_speed = maxf(0.0, _slide_speed - (2.6 + _slide_time * 2.0) * delta)
	var vertical: float = velocity.dot(up)
	grounded = is_on_floor()
	if grounded:
		vertical = minf(vertical, 0.0)
	else:
		vertical -= gravity_strength * delta
	velocity = direction * _slide_speed + up * vertical
	if _jump_buffer > 0.0 and grounded and _can_stand():
		_set_low(false, false)
		_do_jump(up * jump_speed + direction * maxf(_slide_speed, base_speed))
		return
	var done: bool = _slide_speed < 3.6 or (not crouch_held and _slide_time > 0.25)
	if done and (_can_stand() or crouch_held):
		move = Move.GROUND
		momentum = clampf(inverse_lerp(base_speed, top_speed, _slide_speed), 0.0, 1.0)
	var was_grounded: bool = grounded
	var pre: Vector3 = velocity
	move_and_slide()
	if not is_on_floor() and _since_jump > 0.1:
		move = Move.AIR
	_after_move(was_grounded, pre)


# ---------------------------------------------------------------- wall-run

func _try_wallrun(lateral: Vector3, forward_input: float) -> bool:
	if forward_input < 0.3 or lateral.length() < 5.0 or velocity.dot(up_direction) < -5.0:
		return false
	for side: float in [-1.0, 1.0]:
		var origin: Vector3 = global_position + up_direction * 0.2
		var hit: Dictionary = _ray(origin, origin + global_basis.x * side * (RADIUS + 0.55))
		if hit.is_empty():
			continue
		var normal: Vector3 = hit["normal"]
		if absf(normal.dot(up_direction)) > 0.2:
			continue
		if _last_wall_normal != Vector3.ZERO and normal.dot(_last_wall_normal) > 0.9:
			continue
		var along: Vector3 = lateral.slide(normal)
		if along.length() < lateral.length() * 0.55:
			continue
		move = Move.WALLRUN
		_wall_normal = normal
		_wall_side = side
		_wall_time = 0.0
		_last_wall_normal = normal
		var speed: float = maxf(along.length(), 7.2)
		velocity = along.normalized() * speed + up_direction * maxf(velocity.dot(up_direction), 3.2)
		move_started.emit("wallrun")
		return true
	return false


func _step_wallrun(delta: float) -> void:
	_wall_time += delta
	var up: Vector3 = up_direction
	var vertical: float = velocity.dot(up) - 7.5 * delta
	var along: Vector3 = velocity.slide(up).slide(_wall_normal)
	var hit: Dictionary = _ray(global_position, global_position - _wall_normal * (RADIUS + 0.6))
	var keep: bool = not hit.is_empty() and -_input_axis.y > 0.2 and _wall_time < 1.15
	if _jump_buffer > 0.0:
		move = Move.AIR
		_do_jump(along * 0.95 + _wall_normal * 5.0 + up * 6.2)
		return
	if not keep:
		move = Move.AIR
		velocity = along + up * vertical + _wall_normal * 0.8
		return
	velocity = along + up * vertical - _wall_normal * 1.5
	_stride += along.length() * delta
	var pre: Vector3 = velocity
	move_and_slide()
	if is_on_floor():
		move = Move.GROUND
		_after_move(false, pre)
	elif _stride >= 2.0:
		_stride = 0.0
		footstep.emit(0.7)


# ---------------------------------------------------------------- vault and climb

## Looks for a ledge in front. On success starts a short scripted climb that
## keeps forward speed: a vault over thin obstacles, a climb onto deep ones.
func _try_ledge(max_rise: float, reach: float, airborne: bool) -> bool:
	var up: Vector3 = up_direction
	var forward: Vector3 = (-global_basis.z).slide(up).normalized()
	var feet: Vector3 = global_position - up * (STAND_HEIGHT * 0.5)
	var wall: Dictionary = {}
	for height: float in [0.35, 0.8, 1.25, 1.7]:
		if height > max_rise + 0.05:
			break
		var from: Vector3 = feet + up * height
		var hit: Dictionary = _ray(from, from + forward * (RADIUS + reach))
		if not hit.is_empty() and absf(Vector3(hit["normal"]).dot(up)) < 0.35:
			wall = hit
			break
	if wall.is_empty():
		return false
	var into: Vector3 = -Vector3(wall["normal"]).slide(up).normalized()
	if into.dot(forward) < 0.6:
		return false
	var face: Vector3 = wall["position"]
	face = face - up * (face - feet).dot(up)
	var probe_height: float = max_rise + 0.5
	var top_rise: float = -1.0
	var depth: float = 0.0
	for step: int in range(1, 7):
		var along: float = 0.25 * float(step)
		var probe: Vector3 = face + into * along + up * probe_height
		var hit: Dictionary = _ray(probe, probe - up * (probe_height + 0.3))
		if hit.is_empty() or Vector3(hit["normal"]).dot(up) < 0.8:
			break
		var rise: float = (Vector3(hit["position"]) - feet).dot(up)
		if top_rise < 0.0:
			top_rise = rise
		elif absf(rise - top_rise) > 0.25:
			break
		depth = along
	if top_rise < 0.2 or top_rise > max_rise:
		return false
	var thin: bool = depth <= 1.25
	var over: Vector3
	var kind: String
	if thin and not airborne and top_rise < 1.3:
		kind = "vault"
		over = feet + into * (depth + 0.55) + up * (top_rise + STAND_HEIGHT * 0.5 + 0.12)
	else:
		kind = "climb"
		over = feet + into * 0.75 + up * (top_rise + STAND_HEIGHT * 0.5 + 0.06)
	if _blocked_at(over):
		return false
	var speed: float = velocity.slide(up).length()
	_climb_kind = kind
	_climb_from = global_position
	_climb_to = over
	_climb_hand = face + into * 0.15 + up * top_rise
	_climb_time = 0.0
	if kind == "vault":
		_climb_duration = 0.34
		_climb_exit = into * maxf(speed, 6.4) + up * 1.2
	else:
		_climb_duration = clampf(0.26 + top_rise * 0.13, 0.3, 0.52)
		_climb_exit = into * maxf(speed * 0.85, 5.0)
	move = Move.CLIMB
	grounded = false
	_set_low(false, true)
	move_started.emit(kind)
	return true


func _step_climb(delta: float) -> void:
	_climb_time += delta
	var t: float = clampf(_climb_time / _climb_duration, 0.0, 1.0)
	var up: Vector3 = up_direction
	var travel: Vector3 = _climb_to - _climb_from
	var rise: float = travel.dot(up)
	var across: Vector3 = travel - up * rise
	# rise first, then carry over: the body clears the edge before moving across it
	var rise_part: float = 1.0 - pow(1.0 - t, 2.4)
	var across_part: float = t * t * (3.0 - 2.0 * t)
	var target: Vector3 = _climb_from + up * rise * rise_part + across * across_part
	velocity = (target - global_position) / maxf(delta, 0.0001)
	global_position = target
	if t >= 1.0:
		move = Move.AIR
		velocity = _climb_exit
		_since_jump = 0.2
		_air_time = 0.0
		_nod_velocity -= 0.04


# ---------------------------------------------------------------- gravity surfaces

func _follow_surface() -> void:
	if not is_on_floor():
		return
	# read the face straight under the feet: contact normals at slab joints and
	# box edges are unreliable, a ray along -up is not
	var hit: Dictionary = _ray(global_position, global_position - up_direction * 1.5)
	if hit.is_empty():
		return
	var normal: Vector3 = Vector3(hit["normal"]).normalized()
	var body: Object = hit["collider"]
	var target_up: Vector3 = up_direction
	if body is Node and (body as Node).get_meta("gravity_surface", false):
		# curves are built from slabs a few degrees apart; anything steeper is a wall
		if normal.angle_to(up_direction) < deg_to_rad(25.0):
			target_up = normal
	elif normal.dot(Vector3.UP) > 0.9 and up_direction.angle_to(Vector3.UP) < deg_to_rad(30.0):
		target_up = Vector3.UP
	if target_up.is_equal_approx(up_direction):
		return
	var turn: Quaternion = Quaternion(up_direction, target_up)
	velocity = turn * velocity
	global_basis = (Basis(turn) * global_basis).orthonormalized()
	up_direction = global_basis.y.normalized()
	_wall_normal = turn * _wall_normal


# ---------------------------------------------------------------- helpers

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


func _blocked_at(center: Vector3) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = RADIUS - 0.02
	capsule.height = STAND_HEIGHT - 0.06
	query.shape = capsule
	query.transform = Transform3D(global_basis, center)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _can_stand() -> bool:
	return not _blocked_at(global_position)


func _set_low(low: bool, force: bool) -> void:
	var capsule: CapsuleShape3D = _collider.shape as CapsuleShape3D
	var want: float = LOW_HEIGHT if low else STAND_HEIGHT
	if is_equal_approx(capsule.height, want):
		return
	if not low and not force and not _can_stand():
		return
	capsule.height = want
	# keep the feet where they are: the short capsule sits at the bottom
	_collider.position = Vector3(0, -(STAND_HEIGHT - want) * 0.5, 0)


# ---------------------------------------------------------------- camera

func _snap_view() -> void:
	if _rig == null:
		return
	_view_q = global_basis.get_rotation_quaternion()
	_curr_eye = global_position + up_direction * _eye_height
	_prev_eye = _curr_eye
	_update_rig(0.0, true)


func _process(delta: float) -> void:
	_update_rig(delta, false)


func _update_rig(delta: float, snap: bool) -> void:
	var body_q: Quaternion = global_basis.get_rotation_quaternion()
	if snap:
		_view_q = body_q
	else:
		# gravity turns ease in over a fraction of a second, yaw is already applied
		_view_q = _view_q.slerp(body_q, 1.0 - exp(-9.0 * delta)).normalized()
	# landing compression and small nods are springs, never shakes
	_dip_velocity += (-_dip * 170.0 - _dip_velocity * 19.0) * delta
	_dip += _dip_velocity * delta
	_dip = clampf(_dip, -0.45, 0.2)
	_nod_velocity += (-_nod * 150.0 - _nod_velocity * 18.0) * delta
	_nod += _nod_velocity * delta
	var target_roll: float = 0.0
	if move == Move.WALLRUN:
		target_roll = deg_to_rad(9.0) * _wall_side
	elif move == Move.SLIDE:
		target_roll = deg_to_rad(-3.0)
	target_roll += deg_to_rad(1.3) * -_input_axis.x * clampf(get_speed() / top_speed, 0.0, 1.0)
	_roll = lerpf(_roll, target_roll * bank_amount, 1.0 - exp(-8.0 * delta))
	var fraction: float = Engine.get_physics_interpolation_fraction()
	var eye: Vector3 = _curr_eye if snap else _prev_eye.lerp(_curr_eye, fraction)
	var view_basis: Basis = Basis(_view_q)
	var bob: Vector3 = Vector3.ZERO
	if head_bob_enabled and grounded and move == Move.GROUND:
		_bob_phase = _stride / 2.2 * PI
		bob = view_basis.y * absf(sin(_bob_phase)) * 0.035 * clampf(get_speed() / top_speed, 0.0, 1.0)
	_rig.global_transform = Transform3D(
		view_basis * Basis(Vector3.RIGHT, _pitch + _nod) * Basis(Vector3.BACK, _roll),
		eye + view_basis.y * _dip + bob
	)
	var widen: float = 0.0
	if speed_fov:
		widen = 5.0 * clampf(inverse_lerp(base_speed + 0.5, top_speed, get_speed()), 0.0, 1.0)
	_fov_extra = lerpf(_fov_extra, widen, 1.0 - exp(-3.0 * delta)) if not snap else widen
	_camera.fov = vertical_fov(fov_horizontal + _fov_extra)


## Horizontal FOV is defined at 16:9. Camera keeps height, so wider screens see more.
static func vertical_fov(horizontal_degrees: float) -> float:
	var half: float = deg_to_rad(horizontal_degrees) * 0.5
	return rad_to_deg(2.0 * atan(tan(half) / (16.0 / 9.0)))

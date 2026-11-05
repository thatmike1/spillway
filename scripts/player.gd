extends CharacterBody3D
## first-person runner. Velocity is world space. "Up" is the body's local +Y:
## it stays world up everywhere except on surfaces tagged gravity_surface, where
## it follows the floor normal and the velocity turns with it.
## the camera is a separate top-level rig so mouse look is immediate while
## gravity turns ease visibly and physics steps are interpolated.

signal jumped
signal landed(impact: float)
signal footstep(strength: float)
signal move_started(kind: String)

enum Move { GROUND, AIR, WALLRUN, CLIMB, SLIDE, VAULT, GRAB, PULLUP, WALLCLIMB, ROLL, TURN, SPRINGBOARD, STEP, LANDING }

@export var tuning: Resource = preload("res://data/movement.tres")
@export var assists_enabled: bool = false
var base_speed: float:
	get: return tuning.base_speed
var top_speed: float:
	get: return tuning.maximum_speed
var jump_speed: float:
	get: return tuning.jump_speed
var gravity_strength: float:
	get: return tuning.effective_gravity
@export var mouse_sensitivity: float = 0.0022
@export var stick_look_speed: float = 3.2
@export var invert_y: bool = false
@export var fov_horizontal: float = 85.0
@export var speed_fov: bool = true
@export_range(0.0, 1.0) var bank_amount: float = 1.0
@export var head_bob_enabled: bool = true
@export var comfort_enabled: bool = false
var sprint_effect: float = 0
var _step_distance: float = 0

var landing = preload("res://scripts/moves/landing.gd").new()
var vault = preload("res://scripts/moves/vault.gd").new()
var ledge = preload("res://scripts/moves/ledge.gd").new()
var wall = preload("res://scripts/moves/wall.gd").new()
var slide = preload("res://scripts/moves/slide.gd").new()
var turn = preload("res://scripts/moves/turn.gd").new()
var springboard = preload("res://scripts/moves/springboard.gd").new()
var step_up = preload("res://scripts/moves/step.gd").new()
var _body_q: Quaternion = Quaternion.IDENTITY
var _neck: Vector2 = Vector2.ZERO
var _turn_lag: float = 0
var _camera_turn_target: float = 0
var _animation_phase: float = 0
var _landing_elapsed: float = 100
var _step_grace: float = 0
var _clock: float = 0
var _context_lock: float = 0
var _crouch_age: float = 100
var _last_crouch_press: float = -100
var _crouch_held: bool = false
var _air_turned: bool = false
var _vault_landing: bool = false
var _jump_origin: Vector3 = Vector3.ZERO
var controls_enabled: bool = true
var move: Move = Move.GROUND
var momentum: float = 0.0
var grounded: bool = false

var _yaw_input: float = 0.0
var _pre_jump_speed: float = 0.0
var _jump_flight: bool = false
var _fall_origin: float = 0.0
var _air_speed_limit: float = 7.2
var _landing_continuation: bool = false
var _continuation_direction: Vector3 = Vector3.FORWARD
var displacement_velocity: Vector3 = Vector3.ZERO
var travel_distance: float = 0
var _body_recovery: float = 0
var last_landing_speed: float = 0.0
var _pitch: float = 0.0
var _jump_buffer: float = 0.0
var _coyote: float = 0.0
var _since_jump: float = 1.0
var _air_time: float = 0.0
var _stride: float = 0.0
var _crouched: bool = false
var _wall_normal: Vector3 = Vector3.ZERO
var _wall_side: float = 0.0
var _climb_hand: Vector3 = Vector3.ZERO
var _eye_height: float = tuning.standing_eye
var _prev_eye: Vector3 = Vector3.ZERO
var _curr_eye: Vector3 = Vector3.ZERO
var _view_q: Quaternion = Quaternion.IDENTITY
var _dip: float = 0.0
var _dip_velocity: float = 0.0
var _nod: float = 0.0
var _nod_velocity: float = 0.0
var _roll: float = 0.0
var _fov_extra: float = 0.0
var _input_axis: Vector2 = Vector2.ZERO
var _rig: Node3D
var _camera: Camera3D
@onready var _collider: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("player")
	_collider.shape = _collider.shape.duplicate()
	floor_snap_length = 0.45
	floor_max_angle = acos(tuning.walkable_normal)
	(_collider.shape as CapsuleShape3D).radius = tuning.radius
	(_collider.shape as CapsuleShape3D).height = tuning.standing_height
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


func get_presentation_speed() -> float:
	return displacement_velocity.slide(up_direction).length()


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
	return clampf(vault.time / maxf(vault.duration, .01), 0, 1) if move == Move.VAULT else (clampf(ledge.time / tuning.pull_duration, 0, 1) if move == Move.PULLUP else 0.0)


func get_climb_kind() -> String:
	return vault.variant if move == Move.VAULT else ("pullup" if move == Move.PULLUP else "")


func get_climb_hand_point() -> Vector3:
	return _climb_hand


func is_low() -> bool:
	return move in [Move.SLIDE, Move.ROLL] or _crouched


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		_jump_buffer = 0.0


func queue_jump() -> void:
	_jump_buffer = tuning.jump_buffer if assists_enabled else 1.0 / 120.0 + .00001


func look(yaw_delta: float, pitch_delta: float) -> void:
	if not controls_enabled or move in [Move.ROLL, Move.LANDING] or (move == Move.PULLUP and ledge.time < tuning.pull_look_release):
		return
	if move == Move.SLIDE:
		var since: float = slide.start_yaw.signed_angle_to(-global_basis.z, up_direction)
		yaw_delta = clampf(since + yaw_delta, -deg_to_rad(tuning.slide_look), deg_to_rad(tuning.slide_look)) - since
	_yaw_input += yaw_delta
	rotate_object_local(Vector3.UP, yaw_delta)
	_view_q = (_view_q * Quaternion(Vector3.UP, yaw_delta)).normalized()
	var limit: float = 88.0
	if move == Move.WALLRUN:
		limit = 71.41
	elif move == Move.SLIDE:
		limit = tuning.slide_look
	elif _crouched:
		limit = tuning.crouch_pitch
	_pitch = clampf(_pitch + pitch_delta, deg_to_rad(-limit), deg_to_rad(limit))


func reset_to(spawn: Transform3D, up: Vector3 = Vector3.UP) -> void:
	var basis_now: Basis = spawn.basis.orthonormalized()
	if not up.is_equal_approx(basis_now.y):
		basis_now = Basis(Quaternion(basis_now.y, up.normalized())) * basis_now
	global_transform = Transform3D(basis_now.orthonormalized(), spawn.origin)
	up_direction = up.normalized()
	velocity = Vector3.ZERO
	displacement_velocity = Vector3.ZERO
	travel_distance = 0
	sprint_effect = 0
	_step_distance = 0
	_fov_extra = 0
	_stride = 0
	_landing_elapsed = 100
	_body_recovery = 0
	_landing_continuation = false
	_air_speed_limit = tuning.maximum_speed
	move = Move.GROUND
	_jump_flight = false
	_yaw_input = 0.0
	_fall_origin = spawn.origin.dot(up_direction)
	_jump_origin = spawn.origin
	_air_turned = false
	_vault_landing = false
	_context_lock = 0
	_crouch_age = 100
	_crouch_held = false
	wall.consecutive = 0
	wall.from_jump = false
	wall.illegal_time = 0
	momentum = 0.0
	_pitch = 0.0
	_jump_buffer = 0.0
	_coyote = 0.0
	_since_jump = 1.0
	_air_time = 0.0
	_dip = 0.0
	_dip_velocity = 0.0
	_nod = 0.0
	_nod_velocity = 0.0
	_roll = 0.0
	_set_low(false, true)
	_eye_height = tuning.standing_eye
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
	elif event.is_action_pressed("turn"):
		if move in [Move.GROUND, Move.AIR]:
			turn.start(self)
	elif event.is_action_pressed("jump"):
		_jump_buffer = tuning.jump_buffer if assists_enabled else 1.0 / 120.0 + .00001


func _read_stick_look(delta: float) -> void:
	var stick: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.15)
	if stick.length_squared() < 0.0001:
		return
	# a gentle response curve keeps small stick motions precise
	var shaped: Vector2 = stick * stick.length()
	look(-shaped.x * stick_look_speed * delta, -shaped.y * stick_look_speed * 0.7 * delta * (-1.0 if invert_y else 1.0))


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	var motion_origin: Vector3 = global_position
	_prev_eye = _curr_eye
	_body_recovery = maxf(0, _body_recovery - delta)
	_clock += delta
	_landing_elapsed += delta
	_step_grace = maxf(0, _step_grace - delta)
	floor_snap_length = 0 if _step_grace > 0 else .45
	_since_jump += delta
	_context_lock = maxf(0, _context_lock - delta)
	wall.illegal_time = maxf(0, wall.illegal_time - delta)
	_crouch_age += delta
	_input_axis = Vector2.ZERO
	var crouch_held: bool = false
	if controls_enabled:
		_input_axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back", .2)
		crouch_held = Input.is_action_pressed("crouch")
		_read_stick_look(delta)
	if crouch_held and not _crouch_held and _clock - _last_crouch_press > tuning.roll_retrigger:
		_crouch_age = 0
		_last_crouch_press = _clock
	_crouch_held = crouch_held
	match move:
		Move.VAULT: vault.step(self, delta)
		Move.GRAB, Move.PULLUP: ledge.step(self, delta)
		Move.WALLRUN, Move.WALLCLIMB: wall.step(self, delta)
		Move.SLIDE: slide.step(self, delta)
		Move.ROLL, Move.LANDING: landing.step(self, delta)
		Move.TURN: turn.step(self, delta)
		Move.SPRINGBOARD: springboard.step(self, delta)
		Move.STEP: step_up.step(self, delta)
		_: _step_free(delta, crouch_held)
	displacement_velocity = (global_position - motion_origin) / delta
	var distance: float = get_presentation_speed() * delta
	travel_distance += distance
	_stride = fmod(travel_distance, 2.2)
	if grounded and move == Move.GROUND:
		_step_distance += distance
		if _step_distance >= 1.1:
			_step_distance = fmod(_step_distance, 1.1)
			footstep.emit(clampf(get_presentation_speed() / top_speed, .2, 1))
	var streak_target: float = clampf((get_presentation_speed() - 6.1) / .7, 0, 1)
	sprint_effect = lerpf(sprint_effect, streak_target, 1 - exp(-delta * (8 if streak_target > sprint_effect else .8)))
	_jump_buffer = maxf(0, _jump_buffer - delta)
	_camera_turn_target = clampf((_yaw_input / maxf(delta, .00001)) * tuning.turn_lag_multiplier * tuning.turn_lag_projection, -PI / 4, PI / 4) * clampf((get_speed() - 1) / 3, 0, 1)
	_yaw_input = 0
	_follow_surface()
	var target_eye: float = (tuning.standing_eye - tuning.standing_height + tuning.low_height) if is_low() else tuning.standing_eye
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
		_coyote = tuning.coyote_time if assists_enabled else 0.0
		_air_time = 0.0
		move = Move.GROUND
		_fall_origin = global_position.dot(up)
		_air_speed_limit = maxf(tuning.maximum_speed, get_speed())
	else:
		_coyote = maxf(0.0, _coyote - delta)
		_air_time += delta
		move = Move.AIR
	var wish: Vector3 = _wish(_input_axis)
	var forward_input: float = -_input_axis.y
	var vertical: float = velocity.dot(up)
	var lateral: Vector3 = velocity - up * vertical
	var lateral_speed: float = lateral.length()

	_crouched = grounded and crouch_held and lateral_speed < 3.5
	_set_low(_crouched, false)
	if grounded:
		if _jump_buffer <= 0.0:
			lateral = tuning.ground_velocity(lateral, wish, (-global_basis.z).slide(up).normalized(), _yaw_input / delta, delta, _crouched)
		if _landing_continuation:
			# source one-frame continuation; released-input carry is a labelled P extension.
			lateral = velocity.slide(up) + _continuation_direction * tuning.acceleration_limit * delta
			_landing_continuation = false
		vertical = minf(vertical, -1.5)
		momentum = clampf((lateral.length() - base_speed) / (top_speed - base_speed), 0.0, 1.0)
	else:
		# weak acceleration changes the trajectory; it never assigns a new heading.
		if wish.length_squared() > .01:
			var probe: Dictionary = _ray(global_position, global_position + wish * (tuning.radius + .1))
			if probe.is_empty():
				lateral += wish * tuning.air_control * tuning.acceleration_limit * delta
		lateral = lateral.limit_length(_air_speed_limit)
		vertical = maxf(vertical - gravity_strength * delta, -tuning.terminal_speed)
	velocity = lateral + up * vertical

	# current-controller actions precede global context selection.
	if grounded and _jump_buffer > 0 and try_springboard():
		return
	if grounded and crouch_held and lateral.dot((-global_basis.z).slide(up).normalized()) >= tuning.slide_min and _context_lock <= 0:
		slide.start(self, lateral)
		return
	if forward_input > .4 and _context_lock <= 0:
		var edge: Dictionary = detect_edge(maxf(.6, lateral_speed * tuning.vault_reach_time), 3.4 if not grounded else 1.93)
		if not edge.is_empty():
			var h: float = edge.height
			if grounded and h <= tuning.step_height:
				try_ordinary_step(delta)
			elif grounded and h <= 1.48 and lateral_speed <= tuning.step_speed_limit and float(edge.distance) < tuning.step_reach:
				step_up.start(self, edge)
				return
			elif h >= 1.45 and h <= tuning.vault_high_height and vertical >= tuning.vault_high_gate and float(edge.distance) <= 1.2:
				vault.start(self, edge, true, bool(edge.onto))
				vault.step(self, delta)
				return
			elif h >= tuning.vault_low_height and h <= tuning.vault_fast_height and (grounded or vertical >= 0) and forward_input > .7 and float(edge.distance) <= 1.2:
				vault.start(self, edge, false, bool(edge.onto))
				vault.step(self, delta)
				return
			elif not grounded and h > 1.48 and h < tuning.grab_feet_reach and vertical < 4:
				ledge.start(self, edge)
				return
		if not grounded and _air_time > .04 and try_wall(lateral):
			return
	if _jump_buffer > 0 and (grounded or _coyote > 0):
		_pre_jump_speed = lateral.length()
		_jump_flight = true
		var forward: Vector3 = (-global_basis.z).slide(up).normalized()
		if lateral.dot(forward) > tuning.jump_forward_gate:
			lateral += forward * tuning.jump_forward
		_do_jump(up * tuning.jump_speed + lateral)
		return
	if grounded:
		try_ordinary_step(delta)

	var pre_velocity: Vector3 = velocity
	move_and_slide()
	_after_move(was_grounded, pre_velocity)


func _after_move(was_grounded: bool, pre_velocity: Vector3) -> void:
	var now_grounded: bool = is_on_floor()
	var down_speed: float = -pre_velocity.dot(up_direction)
	if now_grounded and not was_grounded and _since_jump > 0.1:
		grounded = true
		wall.consecutive = 0
		wall.from_jump = false
		var impact: float = maxf(down_speed, 0.0)
		if impact > 2.0:
			var soft: bool = false
			if get_slide_collision_count() > 0:
				var body = get_last_slide_collision().get_collider()
				soft = body is Node and body.get_meta("soft_landing", false)
			landing.start(self, impact, soft)
		_fall_origin = global_position.dot(up_direction)


func _do_jump(new_velocity: Vector3) -> void:
	velocity = new_velocity
	_air_speed_limit = maxf(tuning.maximum_speed, velocity.slide(up_direction).length())
	_jump_origin = global_position
	_fall_origin = global_position.dot(up_direction)
	grounded = false
	_since_jump = 0.0
	_coyote = 0.0
	_jump_buffer = 0.0
	_set_low(false, false)
	move = Move.AIR
	_nod_velocity += 0.05
	jumped.emit()
	move_and_slide()


# ---------------------------------------------------------------- context geometry

func get_camera_forward() -> Vector3:
	return -global_basis.z

func sweep_motion(displacement: Vector3) -> KinematicCollision3D:
	if displacement.length_squared() < .00000001:
		return null
	var hit: KinematicCollision3D = move_and_collide(displacement)
	if hit != null and hit.get_normal().dot(up_direction) >= tuning.walkable_normal:
		# keep precise forward travel when the floor resolves a tiny contact penetration.
		var remainder: Vector3 = hit.get_remainder().slide(hit.get_normal())
		if remainder.length_squared() > .00000001:
			var next_hit: KinematicCollision3D = move_and_collide(remainder)
			if next_hit != null:
				return next_hit
	return hit

func detect_edge(reach: float, max_rise: float) -> Dictionary:
	var up: Vector3 = up_direction
	var forward: Vector3 = (-global_basis.z).slide(up).normalized()
	var feet: Vector3 = global_position - up * (tuning.standing_height * .5)
	var face: Dictionary = {}
	for height: float in [.15, .4, .8, 1.25, 1.7, 2.1]:
		if height > max_rise:
			break
		face = _ray(feet + up * height, feet + up * height + forward * (tuning.radius + reach))
		if not face.is_empty() and absf(Vector3(face.normal).dot(up)) < .3:
			break
		face = {}
	if face.is_empty():
		return {}
	var body = face.collider
	if body is Node and body.get_meta("exclude_hands", false):
		return {}
	var into: Vector3 = -Vector3(face.normal).slide(up).normalized()
	if forward.dot(into) < .6:
		return {}
	var front: Vector3 = Vector3(face.position)
	var base: Vector3 = front - up * (front - feet).dot(up)
	var top_hit: Dictionary = _ray(base + into * .08 + up * (max_rise + .15), base + into * .08 - up * .05)
	if top_hit.is_empty() or Vector3(top_hit.normal).dot(up) < .707:
		return {}
	var top: Vector3 = top_hit.position
	var h: float = (top - feet).dot(up)
	if h < .08 or h > max_rise:
		return {}
	var depth: float = .1
	var onto: bool = true
	for i: int in range(1, 17):
		var along: float = float(i) * .15
		var hit = _ray(top + into * along + up * .2, top + into * along - up * .2)
		if hit.is_empty():
			onto = false
			break
		depth = along
	return {"top": top, "into": into, "height": h, "depth": depth, "onto": onto, "distance": (front - global_position).slide(up).length()}

func try_springboard() -> bool:
	var first: Dictionary = detect_edge(maxf(1, get_speed()), 1.49)
	if first.is_empty() or absf(float(first.height) - tuning.spring_intermediate) > tuning.spring_tolerance:
		return false
	var into: Vector3 = first.into
	var probe: Vector3 = Vector3(first.top) + into * tuning.spring_separation
	var feet: Vector3 = global_position - up_direction * (tuning.standing_height * .5)
	var hit = _ray(probe + up_direction * 2, probe - up_direction * .2)
	if hit.is_empty():
		return false
	var height: float = (Vector3(hit.position) - feet).dot(up_direction)
	if height < tuning.spring_min_height or height > tuning.spring_max_height:
		return false
	# require the second support to be a separate higher contact.
	if height - float(first.height) < .2:
		return false
	springboard.start(self, first, {"top": hit.position})
	return true

func try_wall(lateral: Vector3) -> bool:
	if lateral.length() < tuning.wall_min_speed or velocity.dot(up_direction) < -5:
		return false
	var front = _ray(global_position, global_position - global_basis.z * tuning.climb_distance)
	if not front.is_empty() and Vector3(front.normal).dot(global_basis.z) > cos(deg_to_rad(tuning.climb_angle)) and velocity.dot(up_direction) > 0:
		wall.start_vertical(self, front.normal)
		return true
	for side: float in [-1.0, 1.0]:
		var hit = _ray(global_position, global_position + global_basis.x * side * (tuning.radius + tuning.wall_probe))
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.normal
		if absf(normal.dot(up_direction)) > .2:
			continue
		if wall.illegal_time > 0 and normal.dot(wall.illegal_normal) > .9:
			continue
		var body = hit.collider
		if body is Node and body.get_meta("exclude_feet", false):
			continue
		var high_hit = _ray(global_position + up_direction * (tuning.wall_min_height - .9), global_position + up_direction * (tuning.wall_min_height - .9) + global_basis.x * side * (tuning.radius + tuning.wall_probe))
		if high_hit.is_empty():
			continue
		if lateral.normalized().dot(-global_basis.z) < .5 or lateral.slide(normal).length() < lateral.length() * .54:
			continue
		wall.start(self, normal, side)
		return true
	return false

func try_ordinary_step(dt: float) -> bool:
	if not grounded or get_speed() < .1:
		return false
	var motion: Vector3 = velocity.slide(up_direction) * dt
	var toe: Vector3 = global_position - up_direction * (tuning.standing_height * .5 - .05)
	var face = _ray(toe, toe + motion.normalized() * (tuning.radius + .10))
	if face.is_empty() or absf(Vector3(face.normal).dot(up_direction)) > .3:
		return false
	if not test_move(global_transform, motion):
		return false
	var raised: Transform3D = global_transform
	raised.origin += up_direction * tuning.step_height
	if test_move(global_transform, up_direction * tuning.step_height) or test_move(raised, motion):
		return false
	var probe = _ray(raised.origin + motion + motion.normalized() * (tuning.radius + .05), raised.origin + motion + motion.normalized() * (tuning.radius + .05) - up_direction * 1.3)
	if probe.is_empty() or Vector3(probe.normal).dot(up_direction) < tuning.walkable_normal:
		return false
	var height: float = (Vector3(probe.position) - (global_position - up_direction * (tuning.standing_height * .5))).dot(up_direction)
	if height < .01 or height > tuning.step_height:
		return false
	sweep_motion(up_direction * (height + .03))
	velocity = velocity.slide(up_direction)
	_step_grace = .15
	floor_snap_length = 0
	return true


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
	capsule.radius = tuning.radius - 0.02
	capsule.height = tuning.standing_height - 0.06
	query.shape = capsule
	query.transform = Transform3D(global_basis, center)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _can_stand() -> bool:
	return not _blocked_at(global_position)


func _set_low(low: bool, force: bool) -> void:
	var capsule: CapsuleShape3D = _collider.shape as CapsuleShape3D
	var want: float = tuning.low_height if low else tuning.standing_height
	if is_equal_approx(capsule.height, want):
		return
	if not low and not force and not _can_stand():
		return
	capsule.height = want
	# keep the feet where they are: the short capsule sits at the bottom
	_collider.position = Vector3(0, -(tuning.standing_height - want) * 0.5, 0)


# ---------------------------------------------------------------- camera

func _snap_view() -> void:
	if _rig == null:
		return
	_body_q = global_basis.get_rotation_quaternion()
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
	# substep the eye springs, including slow Movie Maker frames and real hitches.
	var spring_steps: int = maxi(1, ceili(delta * 120))
	var h: float = delta / spring_steps
	for i: int in spring_steps:
		_dip_velocity += (-_dip * 170 - _dip_velocity * 19) * h
		_dip = clampf(_dip + _dip_velocity * h, -.45, .2)
		_nod_velocity += (-_nod * 150 - _nod_velocity * 18) * h
		_nod += _nod_velocity * h
	var target_roll: float = 0
	var local_eye: Vector3 = Vector3.ZERO
	var speed: float = get_presentation_speed()
	_animation_phase = travel_distance / 2.2 * TAU
	if move == Move.WALLRUN:
		target_roll = -deg_to_rad(tuning.wall_left_tilt if _wall_side < 0 else tuning.wall_right_tilt) # ue left-handed roll mapped to Godot
		var extent: Vector2 = tuning.wall_left_eye_range if _wall_side < 0 else tuning.wall_right_eye_range
		local_eye = Vector3(sin(_animation_phase * 1.4) * extent.x / 2, sin(_animation_phase * 2.8) * extent.y / 2, 0)
	elif grounded and head_bob_enabled and move == Move.GROUND:
		var extent: Vector2 = tuning.sprint_eye_range if speed >= 6.3 else tuning.run_eye_range
		local_eye = Vector3(sin(_animation_phase) * extent.x / 2, sin(_animation_phase * 2) * extent.y / 2, 0) * (.2 if comfort_enabled else 1.0)
	var anim_pitch: float = 0
	if move == Move.VAULT:
		var f: float = get_climb_progress()
		# port choice (P): crouch the visual body around the planted rail. root capsule clearance
		# is independent of this eye curve; collision resolution follows composition.
		var plant: float = smoothstep(0, .16, f) * (1 - smoothstep(.52, .90, f))
		var over_rail: float = (global_position + up_direction * _eye_height - _climb_hand).dot(up_direction)
		local_eye.y -= maxf(0, over_rail - tuning.vault_eye_above_contact) * plant
		target_roll = .10 * sin(f * PI) # port choice (P): plant-side body lean.
		anim_pitch = -.62 * sin(f * PI) # port choice (P): see the planted hand and rail through push-off
	elif move == Move.PULLUP:
		local_eye.y -= .35 * sin(get_climb_progress() * PI)
	elif move == Move.ROLL:
		var f: float = clampf(landing.time / tuning.roll_active_duration, 0, 1)
		# port choice (P): local track range is retargeted around the crouched shoulder, not
		# subtracted from the world eye. the physical root still travels 3.13517 m.
		local_eye.y -= tuning.roll_eye_range.y * tuning.roll_eye_projection * sin(f * PI)
		anim_pitch = -1.05 * sin(f * PI) # port choice (P): a forward shoulder dip with free horizon recovery.
	elif move == Move.LANDING:
		var f: float = clampf(landing.time / tuning.hard_duration, 0, 1)
		local_eye.y -= tuning.hard_eye_range.y * sin(f * PI)
		# port choice (P): keep the eye in front of the visual torso during impact.
		anim_pitch = -.94 * sin(f * PI)
	elif _landing_elapsed < tuning.normal_landing_recovery:
		# port choice (P): an impact-weighted eye animation, not random or universal shake.
		var amount: float = clampf(pow(landing.impact / 8.0, 2), .15, 1)
		local_eye.y -= tuning.normal_landing_compression * amount * sin(_landing_elapsed / tuning.normal_landing_recovery * PI)
	_turn_lag = lerpf(_turn_lag, _camera_turn_target, minf(1, delta / tuning.turn_lag_time))
	_roll = lerpf(_roll, (target_roll * bank_amount + _turn_lag) * (.2 if comfort_enabled else 1.0), 1 - exp(-8 * delta))
	var fraction: float = Engine.get_physics_interpolation_fraction()
	var eye: Vector3 = _curr_eye if snap else _prev_eye.lerp(_curr_eye, fraction)
	var view_basis: Basis = Basis(_view_q)
	# leg yaw trails view at the recovered maximum angular rate.
	var body_target: Quaternion = global_basis.get_rotation_quaternion()
	var body_angle: float = _body_q.angle_to(body_target)
	_body_q = _body_q.slerp(body_target, minf(1, deg_to_rad(tuning.leg_rotation_speed) * delta / maxf(body_angle, .00001))) if not snap else body_target
	var neck_progress: float = clampf((rad_to_deg(-_pitch) - tuning.neck_start) / tuning.neck_span, 0, 1)
	var neck_target: Vector2 = Vector2(tuning.neck_forward * neck_progress * cos(neck_progress * PI / 4), tuning.neck_down * neck_progress * sin(neck_progress * PI / 4))
	if move == Move.ROLL:
		neck_target = Vector2.ZERO
	_neck = _neck.lerp(neck_target, minf(1, delta / tuning.neck_smoothing))
	local_eye += Vector3(0, -_neck.y, -_neck.x)
	_rig.global_transform = Transform3D(
		view_basis * Basis(Vector3.RIGHT, _pitch + _nod + anim_pitch) * Basis(Vector3.BACK, _roll),
		_resolve_eye(eye + view_basis * (local_eye + Vector3(0, _dip, 0)))
	)
	# foldrunner extension (P): continuous displacement-driven lens; default on.
	var widen: float = 5 * pow(clampf(speed / top_speed, 0, 1), 2) * (.25 if comfort_enabled else 1.0) if speed_fov else 0.0
	_fov_extra = lerpf(_fov_extra, widen, 1 - exp(-3 * delta)) if not snap else widen
	_camera.fov = vertical_fov(fov_horizontal + _fov_extra)

# port choice (P): keep the final composed eye on the body side of nearby solid geometry.
func _resolve_eye(desired: Vector3) -> Vector3:
	var hit: Dictionary = _ray(global_position, desired)
	if not hit.is_empty():
		return Vector3(hit.position) + Vector3(hit.normal) * .14
	return desired

func get_body_basis() -> Basis:
	return Basis(_body_q)

func get_hand_target(side: float) -> Vector3:
	if move in [Move.VAULT, Move.GRAB, Move.PULLUP]:
		return _climb_hand + global_basis.x * side * (.36 if move == Move.VAULT else .18) + up_direction * .025
	if move in [Move.WALLRUN, Move.WALLCLIMB]:
		var origin: Vector3 = global_position + up_direction * (.65 + (.08 * side if move == Move.WALLCLIMB else 0)) - global_basis.z * .45 + global_basis.x * (side * .20 if move == Move.WALLCLIMB else 0)
		var hit = _ray(origin, origin - _wall_normal * (tuning.radius + tuning.wall_probe))
		if not hit.is_empty():
			return Vector3(hit.position) + _wall_normal * .025
	return Vector3.INF

func get_hand_weight(side: float) -> float:
	var contact: Vector3 = get_hand_target(side)
	if not contact.is_finite():
		return 0
	var local: Vector3 = _rig.global_basis.inverse() * (contact - _rig.global_position)
	var reach: float = (1 - smoothstep(1.0, 1.7, local.length())) * (1 - smoothstep(-.05, .05, local.z))
	if move == Move.VAULT:
		if side > 0:
			return 0 # port choice (P): one planted push-off hand, the other balances.
		return reach * minf(1, vault.time / tuning.hand_ik_blend) * minf(1, (vault.duration - vault.time) / tuning.hand_ik_blend)
	if move == Move.WALLRUN and signf(side) != signf(_wall_side):
		return 0
	if move == Move.PULLUP:
		return reach * (1 - smoothstep(.6, 1, get_climb_progress()))
	return reach


## horizontal FOV is defined at 16:9. Camera keeps height, so wider screens see more.
static func vertical_fov(horizontal_degrees: float) -> float:
	var half: float = deg_to_rad(horizontal_degrees) * 0.5
	return rad_to_deg(2.0 * atan(tan(half) / (16.0 / 9.0)))

extends CharacterBody3D
## p / spillway game choices: one velocity motor owns every collision.

signal footstep(strength: float)
signal landed(impact: float)
signal move_started(kind: String)

const RUN_SPEED: float = 8.5
const WATER_SPEED: float = 3.4
const ACCEL: float = 28.0
const BRAKE: float = 34.0
const GRAVITY: float = 20.0
const JUMP_SPEED: float = 7.2
# p / r12 source-style air: acceleration only adds speed along the wish direction until
# the velocity's projection on it reaches the small wish cap, so a strafe synced with the
# mouse curves and gains while W alone or looking alone gains nothing.
const AIR_ACCELERATE: float = 12.0
const AIR_WISH_CAP: float = 0.75
const MAX_SPEED: float = 30.0
# p / above run speed, staying on the ground costs this much each second; hopping skips it.
const GROUND_OVERSPEED_DECAY: float = 8.0
const WATER_DECAY: float = 12.0
# p / shallow water barely touches a slide; it only stops walking.
const SLIDE_WATER_DRAG: float = 0.25
const FLOOR_MAX_DEGREES: float = 46.0
const SURF_MAX_DEGREES: float = 75.0
# p / a held autohop chain never catches a lip; mantles are for carry speed and a fresh press.
const MANTLE_MAX_SPEED: float = 10.0
const STAND_HEIGHT: float = 1.8
const LOW_HEIGHT: float = 1.05
const RADIUS: float = 0.30
const SLIDE_CAP: float = 16.0
const COYOTE: float = 0.10
const BUFFER: float = 0.12

var camera: Camera3D
var collision: CollisionShape3D
var input_enabled: bool = true
var yaw: float = 0.0
var pitch: float = 0.0
var mouse_sensitivity: float = 0.0022
var fov_horizontal: float = 90.0
var comfort: bool = false
var mode: String = "air"
var crouched: bool = false
var in_water: bool = false
var jump_count: int = 0
var mantle_count: int = 0
var hop_count: int = 0
var autohop: bool = true
var surf_ticks: int = 0
var surf_normal: Vector3 = Vector3.ZERO
var land_count: int = 0
var last_impact: float = 0.0
var _coyote: float = 0.0
var _ground_ticks: int = 0
var _hold_ticks: int = 0
var _buffer: float = 0.0
var _eye_height: float = 1.63
var _dip: float = 0.0
var _distance: float = 0.0
var _gait_phase: float = 0.0
var _gait_blend: float = 0.0
var _last_position: Vector3
var _previous_position: Vector3
var _current_position: Vector3
var _mantle_latched: bool = false
var _mantle_phase: int = 0
var _mantle_goal: Vector3
var _mantle_lift: Vector3
var _mantle_wall_normal: Vector3
var _mantle_carry: Vector3
var _mantle_time: float = 0.0
var _eye_probe := SphereShape3D.new()
var _eye_query := PhysicsShapeQueryParameters3D.new()

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(FLOOR_MAX_DEGREES)
	floor_constant_speed = true
	floor_stop_on_slope = true
	safe_margin = 0.002
	# p / the small eye volume protects the near plane during a late duck.
	_eye_probe.radius = 0.12
	_eye_query.shape = _eye_probe
	_eye_query.collision_mask = 1
	_eye_query.exclude = [get_rid()]
	collision = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = STAND_HEIGHT
	collision.shape = capsule
	collision.position.y = STAND_HEIGHT * 0.5
	add_child(collision)
	camera = Camera3D.new()
	camera.name = "Eye"
	camera.near = 0.06
	camera.far = 900.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	camera.top_level = true
	camera.current = true
	reset_to(global_transform)

func reset_to(pose: Transform3D) -> void:
	global_transform = pose
	yaw = pose.basis.get_euler().y
	pitch = -0.23
	velocity = Vector3.ZERO
	mode = "air"
	crouched = false
	in_water = false
	_coyote = 0.0
	_ground_ticks = 0
	_hold_ticks = 0
	_buffer = 0.0
	_dip = 0.0
	surf_normal = Vector3.ZERO
	_eye_height = 1.63
	_gait_phase = 0.0
	_gait_blend = 0.0
	_mantle_latched = false
	_mantle_phase = 0
	_last_position = global_position
	_previous_position = global_position
	_current_position = global_position
	if collision != null:
		_set_height(STAND_HEIGHT)
	if camera != null:
		_update_eye(0.0)

func get_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		yaw -= motion.screen_relative.x * mouse_sensitivity
		pitch = clampf(pitch - motion.screen_relative.y * mouse_sensitivity, -1.40, 1.40)

func _physics_process(delta: float) -> void:
	_previous_position = _current_position
	if not input_enabled:
		_current_position = global_position
		return
	var look := Input.get_vector("look_left", "look_right", "look_down", "look_up")
	yaw -= look.x * 2.4 * delta
	pitch = clampf(pitch + look.y * 1.8 * delta, -1.4, 1.4)
	rotation = Vector3(0.0, yaw, 0.0)
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Basis(Vector3.UP, yaw) * Vector3(stick.x, 0.0, stick.y)
	var jump_held := Input.is_action_pressed("jump")
	if not jump_held:
		_mantle_latched = false
		_hold_ticks = 0
	else:
		_hold_ticks += 1
	if Input.is_action_just_pressed("jump"):
		_buffer = BUFFER
	else:
		_buffer = maxf(0.0, _buffer - delta)
	if mode == "mantle":
		_step_mantle(delta, jump_held)
		_current_position = global_position
		return
	var grounded := is_on_floor()
	if grounded:
		_coyote = COYOTE
	else:
		_coyote = maxf(0.0, _coyote - delta)
	var wants_low := Input.is_action_pressed("crouch")
	if wants_low:
		crouched = true
	elif crouched and _can_stand():
		crouched = false
	_set_height(LOW_HEIGHT if crouched else STAND_HEIGHT)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var previous_mode := mode
	if grounded:
		_ground_ticks += 1
	else:
		_ground_ticks = 0
	# a buffered press, or jump held with autohop, leaves the ground before any ground
	# friction runs, so a hop on the landing tick keeps all of its speed.
	var held_hop := autohop and jump_held and grounded
	var hop := _coyote > 0.0 and (_buffer > 0.0 or held_hop)
	var downslope := Vector3.DOWN.slide(get_floor_normal()) * GRAVITY if grounded else Vector3.ZERO
	var downhill := downslope.dot(horizontal) > 0.2 and get_floor_normal().y < 0.985 if grounded else false
	# p / hysteresis keeps ordinary crouch walking out of slide ownership.
	var slide_threshold := 3.0 if previous_mode == "slide" or downhill else 6.0
	var sliding := grounded and not hop and crouched and horizontal.length() >= slide_threshold
	mode = "slide" if sliding else ("run" if grounded and not hop else "air")
	if mode == "slide" and previous_mode != "slide":
		move_started.emit("slide")
	floor_constant_speed = not sliding
	if grounded and not hop:
		if sliding:
			if wish.length_squared() > 0.01 and stick.y < 0.2:
				var angle := horizontal.signed_angle_to(wish, Vector3.UP)
				horizontal = horizontal.rotated(Vector3.UP, clampf(angle, -PI * 0.5 * delta, PI * 0.5 * delta))
			# downhill feeds a slide up to its cap; speed carried in from a hop is never clipped.
			var carried_in := horizontal.length()
			horizontal += Vector3(downslope.x, 0.0, downslope.z) * delta
			horizontal = horizontal.limit_length(maxf(SLIDE_CAP, carried_in))
			var friction := 0.85 if get_floor_normal().y < 0.985 else 2.0
			friction += maxf(0.0, stick.y) * 12.0
			if in_water:
				friction += SLIDE_WATER_DRAG
			horizontal = horizontal.move_toward(Vector3.ZERO, friction * delta)
		else:
			var speed_limit := 3.2 if crouched else RUN_SPEED
			if in_water:
				speed_limit = minf(speed_limit, WATER_SPEED)
			var carried := maxf(speed_limit, horizontal.length() - (WATER_DECAY if in_water else GROUND_OVERSPEED_DECAY) * delta)
			var target := wish * carried
			# p / changing your mind brakes as firmly as releasing, then accelerates away.
			var braking := wish.length_squared() == 0.0 or horizontal.dot(wish) < 0.0
			horizontal = horizontal.move_toward(target, (BRAKE if braking else ACCEL) * delta)
		velocity.y = -0.4
	else:
		horizontal = _air_accelerate(horizontal, wish, delta)
		velocity.y -= GRAVITY * delta
	horizontal = horizontal.limit_length(MAX_SPEED)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if hop:
		velocity.y = JUMP_SPEED
		if _ground_ticks == 1:
			hop_count += 1
		# p / jump held through a landing is an autohop chain, which never catches a lip
		# until jump is released; a press made on this stretch of ground still can.
		if _hold_ticks > _ground_ticks and _buffer <= 0.0:
			_mantle_latched = true
		_coyote = 0.0
		_buffer = 0.0
		grounded = false
		jump_count += 1
		move_started.emit("jump")
	elif not grounded and jump_held and stick.y < -0.2 and not _mantle_latched and not crouched and get_speed() <= MANTLE_MAX_SPEED:
		if _try_mantle(wish):
			_current_position = global_position
			return
	var impact := -velocity.y
	_limit_collision_speed(delta)
	var before_move := velocity
	# airborne contacts slide along the surface; on the ground steep faces stay walls.
	floor_block_on_wall = grounded
	move_and_slide()
	_clip_air_contacts(before_move)
	# p / contact can turn falling energy into horizontal speed; cap the whole vector
	# after clipping so its direction stays feasible against every touched plane.
	var resolved_speed := get_speed()
	if resolved_speed > MAX_SPEED:
		velocity *= MAX_SPEED / resolved_speed
	if not grounded and is_on_floor() and impact > 2.0:
		last_impact = impact
		land_count += 1
		_dip = minf(0.09, 0.018 + impact * 0.004)
		landed.emit(impact)
		# landings keep the horizontal velocity returned by collision.
	if is_on_floor() and not sliding:
		var travelled := Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length()
		var step_length := 1.35 if crouched else (1.7 if in_water else 2.25)
		_distance += travelled
		_gait_phase = fmod(_gait_phase + travelled * TAU / step_length, TAU)
		if _distance > step_length:
			_distance = 0.0
			footstep.emit(clampf(get_speed() / RUN_SPEED, 0.0, 1.0))
	_last_position = global_position
	_current_position = global_position

func _air_accelerate(horizontal: Vector3, wish: Vector3, delta: float) -> Vector3:
	if wish.length_squared() < 0.0001:
		return horizontal
	var direction := wish.normalized()
	var wish_speed := RUN_SPEED * minf(wish.length(), 1.0)
	# the cap compares against the projection, not the speed: turning the wish away from
	# the velocity reopens room to add, which is what a synced strafe does.
	var room := minf(wish_speed, AIR_WISH_CAP) - horizontal.dot(direction)
	if room <= 0.0:
		return horizontal
	return horizontal + direction * minf(AIR_ACCELERATE * wish_speed * delta, room)

func _clip_air_contacts(before: Vector3) -> void:
	# surf: faces between the floor limit and SURF_MAX are slid on, never stood on. the
	# velocity loses only its component into each touched face, so gravity runs along it.
	surf_normal = Vector3.ZERO
	if is_on_floor():
		return
	var planes: Array[Vector3] = []
	for i: int in get_slide_collision_count():
		_contact_planes(get_slide_collision(i), planes, true)
	if planes.is_empty():
		return
	velocity = _feasible_velocity(before, planes)
	if surf_normal != Vector3.ZERO:
		surf_ticks += 1
		mode = "surf"

func _contact_planes(contact: KinematicCollision3D, planes: Array[Vector3], mark_surf: bool) -> void:
	for j: int in contact.get_collision_count():
		var normal := contact.get_normal(j)
		if normal.y >= cos(floor_max_angle):
			continue
		# classify the actual face, including secondary contacts in a ceiling crease.
		var face := _face_normal(contact.get_position(j), normal)
		var plane := face
		if face.y > cos(deg_to_rad(SURF_MAX_DEGREES)) and face.y < cos(floor_max_angle):
			if mark_surf:
				surf_normal = face
		elif face.y >= cos(floor_max_angle) or face == Vector3.ZERO:
			plane = Vector3(normal.x, 0.0, normal.z).normalized()
		if plane.length_squared() > .5:
			var duplicate := false
			for existing: Vector3 in planes:
				duplicate = duplicate or existing.dot(plane) > .9999
			if not duplicate:
				planes.append(plane)

func _limit_collision_speed(delta: float) -> void:
	# p / a hard fall can exceed the horizontal cap during the engine's swept motion,
	# before the final velocity limit. predict only that high-energy contact and limit
	# its feasible tangent before moving; ordinary movement needs no extra query.
	if velocity.length_squared() <= MAX_SPEED * MAX_SPEED:
		return
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, velocity * delta, hit, safe_margin, false, 8):
		return
	var planes: Array[Vector3] = []
	_contact_planes(hit, planes, false)
	if planes.is_empty():
		return
	var resolved := _feasible_velocity(velocity, planes)
	var speed := Vector2(resolved.x, resolved.z).length()
	if speed > MAX_SPEED:
		velocity = resolved * (MAX_SPEED / speed)

func _feasible_velocity(before: Vector3, planes: Array[Vector3]) -> Vector3:
	# p / project onto the feasible contact cone. its closest point is either the original
	# vector, one face, a two-face crease, or zero. this preserves a clear travel tangent
	# without relying on a fixed number of alternating projections to converge.
	var candidates: Array[Vector3] = [before, Vector3.ZERO]
	for i: int in planes.size():
		candidates.append(before.slide(planes[i]))
		for j: int in range(i + 1, planes.size()):
			var crease := planes[i].cross(planes[j])
			if crease.length_squared() > .000001:
				candidates.append(crease * before.dot(crease) / crease.length_squared())
	var best := Vector3.ZERO
	var cost := before.length_squared()
	for candidate: Vector3 in candidates:
		var valid := true
		for plane: Vector3 in planes:
			if candidate.dot(plane) < -.0001:
				valid = false
		var candidate_cost := candidate.distance_squared_to(before)
		if valid and candidate_cost <= cost:
			best = candidate
			cost = candidate_cost
	return best

func _face_normal(point: Vector3, normal: Vector3) -> Vector3:
	var hit := _ray(point + normal * 0.08, point - normal * 0.08)
	if hit.is_empty():
		return Vector3.ZERO
	# a ray at a seam can find the hidden end cap of the next segment, which faces back
	# along the ramp. a face that disagrees that much with the contact is not the one touched.
	var face: Vector3 = hit.normal
	return face if face.dot(normal) > 0.3 else normal

func _set_height(height: float) -> void:
	(collision.shape as CapsuleShape3D).height = height
	collision.position.y = height * 0.5

func _can_stand() -> bool:
	return _clear_body(global_position, STAND_HEIGHT)

func _clear_body(feet: Vector3, height: float) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS - 0.015
	shape.height = height - 0.02
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (height * 0.5 + 0.02))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func _try_mantle(wish: Vector3) -> bool:
	if wish.length_squared() < 0.1 or velocity.y > 3.0:
		return false
	var forward := wish.normalized()
	var wall := _ray(global_position + Vector3.UP * 0.55, global_position + Vector3.UP * 0.55 + forward * 0.8)
	if wall.is_empty() or absf((wall.normal as Vector3).y) > 0.25:
		return false
	var beyond := global_position + forward * 0.85
	var top := _ray(beyond + Vector3.UP * 1.65, beyond + Vector3.UP * 0.25)
	if top.is_empty() or (top.normal as Vector3).y < 0.9:
		return false
	var goal: Vector3 = top.position + Vector3.UP * 0.025
	if not _clear_body(goal, STAND_HEIGHT):
		return false
	_mantle_latched = true
	_mantle_wall_normal = wall.normal
	_mantle_goal = goal
	_mantle_lift = Vector3(global_position.x, goal.y + 0.03, global_position.z)
	# p / a small hand push restores forward motion lost against the lip.
	_mantle_carry = forward * clampf(get_speed(), 2.5, RUN_SPEED)
	_mantle_phase = 0
	_mantle_time = 0.0
	mode = "mantle"
	mantle_count += 1
	move_started.emit("mantle")
	return true

func _step_mantle(delta: float, jump_held: bool) -> void:
	_mantle_time += delta
	if not jump_held or Input.is_action_pressed("move_back") or _mantle_time > 0.55:
		_end_mantle(false)
		return
	var target := _mantle_lift if _mantle_phase == 0 else _mantle_goal
	var motion := (target - global_position).limit_length(6.5 * delta)
	var collision_result := move_and_collide(motion)
	if collision_result != null:
		_end_mantle(false)
		return
	if global_position.distance_to(target) < 0.015:
		if _mantle_phase == 0:
			_mantle_phase = 1
		else:
			_end_mantle(true)

func _end_mantle(success: bool) -> void:
	# cancelling gives the player back motion without driving them into the caught wall.
	if success:
		velocity = _mantle_carry
		velocity.y = 0.0
	else:
		if velocity.dot(_mantle_wall_normal) < 0.0:
			velocity = velocity.slide(_mantle_wall_normal)
		velocity.y = minf(velocity.y, -1.0)
	mode = "air"
	_buffer = 0.0
	_coyote = 0.0
	# latch survives cancellation until jump is released, preventing a held-input loop.
	_mantle_latched = true

func _process(delta: float) -> void:
	_update_eye(delta)

func _update_eye(delta: float) -> void:
	if camera == null:
		return
	_eye_height = move_toward(_eye_height, 0.90 if crouched else 1.63, 5.5 * delta)
	_dip = move_toward(_dip, 0.0, 0.28 * delta)
	var fraction := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	var feet := _previous_position.lerp(_current_position, fraction)
	var gait_target := 1.0 if is_on_floor() and mode != "slide" and get_speed() > 0.8 and not comfort else 0.0
	_gait_blend = move_toward(_gait_blend, gait_target, delta * 7.0)
	var bob := sin(_gait_phase) * 0.008 * _gait_blend * minf(get_speed() / RUN_SPEED, 1.0)
	var eye_offset := _eye_height + bob - _dip * (0.4 if comfort else 1.0)
	# the body is already low when the eye is still travelling down. resolve that
	# presentation path from inside the clear capsule, never through a ceiling.
	var anchor := feet + Vector3.UP * 0.34
	_eye_query.transform = Transform3D(Basis.IDENTITY, anchor)
	_eye_query.motion = Vector3.UP * maxf(0.0, eye_offset - 0.34)
	var sweep := get_world_3d().direct_space_state.cast_motion(_eye_query)
	camera.global_position = anchor + _eye_query.motion * sweep[0]
	camera.global_rotation = Vector3(pitch, yaw, 0.0)
	var extra := 0.0 if comfort else clampf((get_speed() - 6.0) * 0.5, 0.0, 5.0)
	var horizontal_fov := fov_horizontal + extra
	var view_size := get_viewport().get_visible_rect().size
	var aspect := view_size.x / maxf(view_size.y, 1.0)
	camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(horizontal_fov) * 0.5) / maxf(aspect, 0.1)))

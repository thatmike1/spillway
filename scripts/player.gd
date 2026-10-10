extends CharacterBody3D
## All velocity is world space. move_and_slide owns moving-platform transport.

@export var move_speed: float = 8.0
@export var sprint_speed: float = 13.0
@export var jump_speed: float = 8.0
@export var gravity_strength: float = 22.0
@export_range(0.0, 1.0) var comfort_roll: float = 0.35
@export var head_bob_enabled: bool = false
@export var mouse_sensitivity: float = 0.002
@export var gravity_turn_speed: float = 8.0

var controls_enabled: bool = true
var wall_running: bool = false
var vaulting: bool = false
var _target_up: Vector3 = Vector3.UP
var _region_up: Vector3 = Vector3.UP
var _region_strength: float = 22.0
var _default_strength: float = 22.0
var _pitch: float = 0.0
var _support: WeakRef
var _jump_queued: bool = false
var _separation_time: float = 0.0
var _wall_time: float = 0.0
var _wall_normal: Vector3 = Vector3.ZERO
var _vault_target: Vector3 = Vector3.ZERO
var _vault_lift: Vector3 = Vector3.ZERO
var _vault_remaining: float = 0.0
var _crouched: bool = false
var _bob_time: float = 0.0
var _camera_snap: bool = true
var _zone_grace_ticks: int = 0
@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _collider: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("player")
	_collider.shape = _collider.shape.duplicate()
	floor_snap_length = 0.3
	floor_stop_on_slope = true
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY
	_region_strength = gravity_strength
	_default_strength = gravity_strength

func set_gravity(up: Vector3, strength: float = 22.0) -> void:
	if not up.is_finite() or up.length_squared() < 0.0001:
		return
	_region_up = up.normalized()
	_target_up = _region_up
	_region_strength = maxf(strength, 0.0)
	gravity_strength = _region_strength

func teleport_state(destination: Transform3D, mapped_velocity: Vector3, mapped_up: Vector3) -> void:
	if not destination.origin.is_finite() or not mapped_velocity.is_finite():
		return
	global_transform = destination.orthonormalized()
	velocity = mapped_velocity
	set_gravity(mapped_up, _region_strength)
	up_direction = _target_up
	_align_body(up_direction, 1.0)
	_clear_traversal()
	_zone_grace_ticks = 2
	reset_physics_interpolation()
	_camera_snap = true

func reset_to(spawn: Transform3D, up: Vector3 = Vector3.UP) -> void:
	_pitch = 0.0
	_bob_time = 0.0
	set_gravity(up, _default_strength)
	teleport_state(spawn, Vector3.ZERO, up)
	_set_crouch(false)

func get_camera() -> Camera3D:
	return _camera

func get_speed() -> float:
	return velocity.slide(up_direction).length()

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		_jump_queued = false

func queue_jump() -> void:
	if controls_enabled:
		_jump_queued = true

func _clear_traversal() -> void:
	_support = null
	wall_running = false
	vaulting = false
	_wall_time = 0.0
	_separation_time = 0.15
	_jump_queued = false

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		global_rotate(up_direction, -event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.4, 1.4)

func _physics_process(delta: float) -> void:
	_separation_time = maxf(0.0, _separation_time - delta)
	_resolve_gravity()
	_align_body(_target_up, 1.0 - exp(-gravity_turn_speed * delta))
	up_direction = global_basis.y.normalized()
	var input_axis: Vector2 = Vector2.ZERO
	if controls_enabled:
		input_axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		_set_crouch(Input.is_action_pressed("crouch"))
	var wish: Vector3 = (global_basis.x * input_axis.x + global_basis.z * input_axis.y).slide(up_direction)
	if wish.length_squared() > 0.0001:
		wish = wish.normalized() * input_axis.length()
	var sprinting: bool = controls_enabled and Input.is_action_pressed("sprint") and not _crouched
	var speed: float = sprint_speed if sprinting else move_speed
	if _crouched:
		speed *= 0.5
	var jump: bool = controls_enabled and (_jump_queued or Input.is_action_just_pressed("jump"))
	_jump_queued = false
	if vaulting:
		_vault_remaining -= delta
		var lifting: bool = _vault_remaining > 0.2
		var goal: Vector3 = _vault_lift if lifting else _vault_target
		var remaining: float = _vault_remaining - 0.2 if lifting else _vault_remaining
		velocity = (goal - global_position) / maxf(remaining + delta, delta)
		move_and_slide()
		if _vault_remaining <= 0.0 or is_on_ceiling():
			vaulting = false
			velocity = velocity.slide(up_direction)
		_update_support()
		return
	var grounded: bool = is_on_floor() and _separation_time <= 0.0
	_update_wall_run(delta, wish, sprinting, grounded)
	var vertical: Vector3 = up_direction * velocity.dot(up_direction)
	var lateral: Vector3 = velocity - vertical
	var acceleration: float = 42.0 if grounded else 15.0
	lateral = lateral.move_toward(wish * speed, acceleration * delta)
	if grounded and vertical.dot(up_direction) < 0.0:
		vertical = Vector3.ZERO
	else:
		vertical -= up_direction * gravity_strength * delta * (0.18 if wall_running else 1.0)
	velocity = lateral + vertical
	if wall_running:
		velocity = velocity.slide(_wall_normal) - _wall_normal * 1.0
	if jump:
		if not _crouched and _try_vault():
			pass
		elif grounded or wall_running:
			velocity = velocity.slide(up_direction) + up_direction * jump_speed
			if wall_running:
				velocity += _wall_normal * 5.0
			_separation_time = 0.22
			_support = null
			wall_running = false
			_wall_time = 1.0
	move_and_slide()
	_update_support()

func _resolve_gravity() -> void:
	var selected: Node = null
	var zones: Array[Node] = []
	if _zone_grace_ticks > 0:
		_zone_grace_ticks -= 1
	else:
		zones = get_tree().get_nodes_in_group("gravity_zone")
	for zone: Node in zones:
		if not zone is Area3D or not zone.overlaps_body(self):
			continue
		if selected == null or float(zone.get("priority")) > float(selected.get("priority")):
			selected = zone
		elif is_equal_approx(float(zone.get("priority")), float(selected.get("priority"))) and zone.get_instance_id() < selected.get_instance_id():
			selected = zone
	if selected != null:
		_target_up = selected.call("get_world_up")
		gravity_strength = float(selected.get("strength"))
	else:
		_target_up = _region_up
		gravity_strength = _region_strength
	if _separation_time <= 0.0 and is_on_floor() and _support != null:
		var body: Node3D = _support.get_ref() as Node3D
		if is_instance_valid(body):
			_target_up = body.global_basis.y.normalized()

func _align_body(new_up: Vector3, weight: float) -> void:
	var current: Vector3 = global_basis.y.normalized()
	var desired: Vector3 = new_up.normalized()
	var rotation_delta: Quaternion
	if current.dot(desired) < -0.999:
		rotation_delta = Quaternion(global_basis.x.normalized(), PI)
	else:
		rotation_delta = Quaternion(current, desired)
	global_basis = (Basis(Quaternion.IDENTITY.slerp(rotation_delta, weight)) * global_basis).orthonormalized()

func _update_support() -> void:
	_support = null
	if not is_on_floor() or _separation_time > 0.0:
		return
	_wall_time = 0.0
	for index: int in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(index)
		var body: Object = collision.get_collider()
		if collision.get_normal().dot(up_direction) > 0.65 and body is Node3D and body.get_meta("traversal_up", false):
			_support = weakref(body)
			return

func _ray(start: Vector3, end: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, end, collision_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func _update_wall_run(delta: float, wish: Vector3, sprinting: bool, grounded: bool) -> void:
	wall_running = false
	if grounded or not sprinting or wish.dot(-global_basis.z) < 0.4 or get_speed() < 5.0 or _wall_time >= 0.9:
		return
	for side: float in [-1.0, 1.0]:
		var hit: Dictionary = _ray(global_position, global_position + global_basis.x * side * 0.85)
		if not hit.is_empty():
			var normal: Vector3 = hit["normal"]
			if absf(normal.dot(up_direction)) < 0.2:
				_wall_normal = normal
				wall_running = true
				_wall_time += delta
				return

func _try_vault() -> bool:
	# A short collision-swept climb, never a position teleport. Requires low obstacle,
	# clear head space, a real top surface, and a capsule-sized clear landing.
	var forward: Vector3 = -global_basis.z
	var low: Dictionary = _ray(global_position - up_direction * 0.3, global_position - up_direction * 0.3 + forward * 1.2)
	if low.is_empty() or absf(Vector3(low["normal"]).dot(up_direction)) > 0.3:
		return false
	if not _ray(global_position + up_direction * 0.8, global_position + up_direction * 0.8 + forward * 1.5).is_empty():
		return false
	var probe: Vector3 = Vector3(low["position"]) + forward * 0.65 + up_direction * 1.5
	var top: Dictionary = _ray(probe, probe - up_direction * 2.0)
	if top.is_empty() or Vector3(top["normal"]).dot(up_direction) < 0.8:
		return false
	var target: Vector3 = Vector3(top["position"]) + up_direction * 0.95
	var rise: float = (target - global_position).dot(up_direction)
	if rise < 0.1 or rise > 1.5:
		return false
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = _collider.shape
	shape_query.transform = Transform3D(global_basis, target)
	shape_query.collision_mask = collision_mask
	shape_query.exclude = [get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(shape_query, 1).is_empty():
		return false
	_vault_target = target
	_vault_lift = global_position + up_direction * (rise + 0.08)
	_vault_remaining = 0.36
	vaulting = true
	wall_running = false
	_support = null
	return true

func _set_crouch(value: bool) -> void:
	if value == _crouched or not is_instance_valid(_collider):
		return
	if not value:
		var standing := CapsuleShape3D.new()
		standing.height = 1.8
		standing.radius = 0.35
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = standing
		query.transform = global_transform
		query.collision_mask = collision_mask
		query.exclude = [get_rid()]
		query.margin = 0.0
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return
	_crouched = value
	var capsule: CapsuleShape3D = _collider.shape as CapsuleShape3D
	capsule.height = 1.1 if value else 1.8
	_collider.position.y = -0.35 if value else 0.0

func _process(delta: float) -> void:
	var forward: Vector3 = -global_basis.z
	forward = forward.rotated(global_basis.x, _pitch)
	var horizon_up: Vector3 = Vector3.UP.slide(forward)
	if horizon_up.length_squared() < 0.01:
		horizon_up = up_direction.slide(forward)
	var physical_up: Vector3 = up_direction.slide(forward).normalized()
	# Interpolate rotations, not opposite up vectors (ceiling traversal would
	# otherwise snap or collapse at comfort_roll=0.5).
	var horizon: Basis = Basis.looking_at(forward, horizon_up.normalized())
	var physical: Basis = Basis.looking_at(forward, physical_up)
	var target: Basis = horizon.slerp(physical, comfort_roll)
	if _camera_snap:
		_pivot.global_basis = target
		_camera_snap = false
	else:
		_pivot.global_basis = _pivot.global_basis.orthonormalized().slerp(target, 1.0 - exp(-12.0 * delta))
	_bob_time += delta * get_speed()
	_camera.position.y = sin(_bob_time * 1.6) * 0.025 if head_bob_enabled and is_on_floor() else 0.0
	_pivot.position.y = 0.3 if _crouched else 0.65

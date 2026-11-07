extends "res://scripts/spillway_player.gd"
## p / r13 flow lab motor. velocity is still the one authoritative state, and every contact
## still runs through the r12 collision code; only the control policy is replaced.
## speed and heading are steered separately. input turns the heading at a grip-limited rate,
## so a turn never cuts across the chord and bleeds speed; speed changes only through
## throttle, drag, slope, an explicit brake and a bounded air carve.

# p / ground throttle: below run speed a push gets there fast; above it earned speed fades
# slowly while pushing and faster when coasting. only pushing against the motion brakes hard.
const FLOW_RUN: float = 9.0
const FLOW_ACCEL: float = 30.0
const FLOW_CRUISE_DRAG: float = 1.6
const FLOW_COAST_DRAG: float = 6.0
const FLOW_STOP: float = 30.0
const FLOW_BRAKE: float = 38.0
# p / a wish more than ~120 degrees from the motion is a reversal: brake, then pivot.
const FLOW_REVERSE_ANGLE: float = 2.1
const FLOW_PIVOT_SPEED: float = 1.2
# p / turning is a lateral grip limit: the radius grows with speed and speed is kept.
const FLOW_GRIP: float = 60.0
const FLOW_TURN_MAX: float = 10.0
# p / gravity along the heading feeds or bleeds speed; a slide takes all of it.
const FLOW_SLOPE_RUN: float = 0.55
const FLOW_SLOPE_SLIDE: float = 1.0
const FLOW_SOFT_CAP: float = 20.0
const FLOW_SOFT_DRAG: float = 0.6
const FLOW_SLIDE_ENTER: float = 6.0
const FLOW_SLIDE_KEEP: float = 3.0
const FLOW_SLIDE_GRIP: float = 18.0
const FLOW_SLIDE_DRAG: float = 1.2
# p / air: with any forward or strafe key held the heading follows the view at a limited
# rate without changing speed; no key keeps the line and s brakes gently. a strafe key on
# the inside of a turn the view is making adds a little speed, up to a cap.
const FLOW_AIR_GRIP: float = 18.0
const FLOW_AIR_TURN_MAX: float = 3.2
const FLOW_AIR_BRAKE: float = 5.0
const FLOW_AIR_FLOOR: float = 4.0
const FLOW_AIR_PUSH: float = 6.0
const FLOW_CARVE_GAIN: float = 1.0
const FLOW_CARVE_CAP: float = 17.0
# p / keep a short turn budget between mouse deliveries. a continuous 30 hz sweep must
# earn the same carve as 120 hz; an isolated flick cannot bank a whole flight's reward.
const FLOW_CARVE_WINDOW: float = 0.067
# p / a jump or a real edge keeps most of the surface's climb. supported crests do not
# trigger a hidden launch: the earlier threshold rule also popped on small stair contacts.
const FLOW_RAMP_KEEP: float = 0.8

var carve_gain_total: float = 0.0
# retained for the original lab trace schema; automatic crest launches are retired.
var launch_count: int = 0
var _flow_yaw_last: float = 0.0
var _flow_last_vs: float = 0.0
var _flow_carve_turn: float = 0.0
var _flow_carve_time: float = 0.0

func _ready() -> void:
	super()
	# measured: on a slope the engine then travels along it at the horizontal speed (16 deg
	# runs 0.96 of it horizontally), in a run and a slide alike, so one speed means one pace.
	floor_constant_speed = true

func reset_to(pose: Transform3D) -> void:
	super(pose)
	_flow_yaw_last = yaw
	_flow_last_vs = 0.0
	_clear_carve()

func _physics_process(delta: float) -> void:
	_previous_position = _current_position
	if not input_enabled:
		_current_position = global_position
		return
	var look := Input.get_vector("look_left", "look_right", "look_down", "look_up")
	yaw -= look.x * 2.4 * delta
	pitch = clampf(pitch + look.y * 1.8 * delta, -1.4, 1.4)
	rotation = Vector3(0.0, yaw, 0.0)
	var view_turn := angle_difference(_flow_yaw_last, yaw)
	_flow_yaw_last = yaw
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
		_clear_carve()
		_step_mantle(delta, jump_held)
		_current_position = global_position
		return
	var ground_normal := _ground_normal
	var grounded := ground_normal != Vector3.ZERO
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
	var held_hop := autohop and jump_held and grounded
	var hop := _coyote > 0.0 and (_buffer > 0.0 or held_hop)
	var started_grounded := grounded
	var surface_vy := _surface_climb(ground_normal, horizontal) if grounded else _flow_last_vs
	var downhill := grounded and ground_normal.y < 0.985 and Vector2(ground_normal.x, ground_normal.z).dot(Vector2(horizontal.x, horizontal.z)) > 0.2
	var slide_threshold := FLOW_SLIDE_KEEP if previous_mode == "slide" or downhill else FLOW_SLIDE_ENTER
	var sliding := grounded and not hop and crouched and horizontal.length() >= slide_threshold
	mode = "slide" if sliding else ("run" if grounded and not hop else "air")
	if mode == "slide" and previous_mode != "slide":
		move_started.emit("slide")
	if grounded and not hop:
		_clear_carve()
		horizontal = _flow_ground(horizontal, wish, ground_normal, sliding, delta)
		velocity.y = -0.4
	else:
		horizontal = _flow_air(horizontal, wish, stick, view_turn, delta)
		velocity.y -= GRAVITY * delta
	horizontal = horizontal.limit_length(MAX_SPEED)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if hop:
		velocity.y = JUMP_SPEED + maxf(0.0, surface_vy) * FLOW_RAMP_KEEP
		if _ground_ticks == 1:
			hop_count += 1
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
	floor_block_on_wall = grounded
	motion_mode = MOTION_MODE_FLOATING if not grounded and (surf_normal != Vector3.ZERO or is_on_floor()) else MOTION_MODE_GROUNDED
	move_and_slide()
	_contacts_valid = true
	_ground_normal = _walkable_contact()
	_clip_air_contacts(before_move)
	var landed_on_floor := is_grounded()
	if grounded and not landed_on_floor and not hop:
		# ran off an edge: keep the surface's vertical rate instead of a flat -0.4 start.
		velocity.y = surface_vy * (FLOW_RAMP_KEEP if surface_vy > 0.0 else 1.0)
	if not grounded and landed_on_floor:
		_catch_landing(before_move)
	# keep the support used for this move in the diagnostic history, rather than replacing
	# it with the newly discovered support before a transition can be observed.
	_flow_last_vs = _surface_climb(ground_normal, Vector3(before_move.x, 0.0, before_move.z)) if grounded else 0.0
	var resolved_speed := get_speed()
	if resolved_speed > MAX_SPEED:
		velocity *= MAX_SPEED / resolved_speed
	if not started_grounded and landed_on_floor and impact > 2.0:
		last_impact = impact
		land_count += 1
		_dip = minf(0.09, 0.018 + impact * 0.004)
		landed.emit(impact)
	if landed_on_floor and not sliding:
		var travelled := Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length()
		var step_length := 1.35 if crouched else (1.7 if in_water else 2.25)
		_distance += travelled
		_gait_phase = fmod(_gait_phase + travelled * TAU / step_length, TAU)
		if _distance > step_length:
			_distance = 0.0
			footstep.emit(clampf(get_speed() / FLOW_RUN, 0.0, 1.0))
	_last_position = global_position
	_current_position = global_position

func _flow_ground(horizontal: Vector3, wish: Vector3, normal: Vector3, sliding: bool, delta: float) -> Vector3:
	var speed := horizontal.length()
	var heading := horizontal / speed if speed > 0.05 else Vector3.ZERO
	var wish_length := minf(wish.length(), 1.0)
	var wish_dir := wish / wish.length() if wish_length > 0.05 else Vector3.ZERO
	if heading == Vector3.ZERO:
		if wish_dir == Vector3.ZERO:
			return Vector3.ZERO
		heading = wish_dir
		speed = 0.0
	# horizontal gravity along the slope, positive when the heading points downhill.
	var slope := GRAVITY * normal.y * Vector2(normal.x, normal.z).dot(Vector2(heading.x, heading.z))
	var angle := heading.signed_angle_to(wish_dir, Vector3.UP) if wish_dir != Vector3.ZERO else 0.0
	var reversing := wish_dir != Vector3.ZERO and absf(angle) > FLOW_REVERSE_ANGLE and speed > FLOW_PIVOT_SPEED
	if sliding:
		if reversing:
			speed = move_toward(speed, 0.0, FLOW_BRAKE * 0.5 * delta)
		elif wish_dir != Vector3.ZERO:
			var limit := minf(FLOW_TURN_MAX, FLOW_SLIDE_GRIP / maxf(speed, 0.1)) * delta
			heading = heading.rotated(Vector3.UP, clampf(angle, -limit, limit))
		speed += slope * FLOW_SLOPE_SLIDE * delta
		speed = move_toward(speed, 0.0, (FLOW_SLIDE_DRAG + (SLIDE_WATER_DRAG if in_water else 0.0)) * delta)
	elif wish_dir == Vector3.ZERO:
		if speed > FLOW_PIVOT_SPEED:
			speed += slope * FLOW_SLOPE_RUN * delta
		speed = move_toward(speed, 0.0, (FLOW_COAST_DRAG if speed > FLOW_RUN else FLOW_STOP) * delta)
	elif reversing:
		speed = move_toward(speed, 0.0, FLOW_BRAKE * delta)
	else:
		if speed <= FLOW_PIVOT_SPEED:
			heading = wish_dir
		else:
			var limit := minf(FLOW_TURN_MAX, FLOW_GRIP / speed) * delta
			heading = heading.rotated(Vector3.UP, clampf(angle, -limit, limit))
		var target := (3.2 if crouched else FLOW_RUN) * wish_length
		if in_water:
			target = minf(target, WATER_SPEED)
		speed += slope * FLOW_SLOPE_RUN * delta
		if speed < target:
			speed = minf(target, speed + FLOW_ACCEL * delta)
		else:
			speed = maxf(target, speed - (WATER_DECAY if in_water else FLOW_CRUISE_DRAG) * delta)
	if speed > FLOW_SOFT_CAP:
		speed -= (speed - FLOW_SOFT_CAP) * FLOW_SOFT_DRAG * delta
	return heading * maxf(speed, 0.0)

func _flow_air(horizontal: Vector3, wish: Vector3, stick: Vector2, view_turn: float, delta: float) -> Vector3:
	_flow_carve_time = maxf(0.0, _flow_carve_time - delta)
	if _flow_carve_time <= 0.0:
		_flow_carve_turn = 0.0
	var wish_length := minf(wish.length(), 1.0)
	if wish_length < 0.05:
		_clear_carve()
		return horizontal
	var wish_dir := wish / wish.length()
	var speed := horizontal.length()
	if speed < FLOW_AIR_FLOOR:
		_clear_carve()
		# a standing or slow jump can still drift where it is pointed, a little.
		return (horizontal + wish_dir * FLOW_AIR_PUSH * wish_length * delta).limit_length(maxf(speed, FLOW_AIR_FLOOR))
	var heading := horizontal / speed
	if stick.y > 0.2:
		_clear_carve()
		return heading * move_toward(speed, 0.0, FLOW_AIR_BRAKE * delta)
	# p / in the air the view leads, whatever forward or strafe keys are held: a strafe key
	# never pulls the line sideways, so swapping a for d is not read as a reversal.
	var view := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var angle := heading.signed_angle_to(view, Vector3.UP)
	if absf(angle) > FLOW_REVERSE_ANGLE:
		_clear_carve()
		return horizontal
	var limit := minf(FLOW_AIR_TURN_MAX, FLOW_AIR_GRIP / speed) * delta
	var turn := clampf(angle, -limit, limit)
	heading = heading.rotated(Vector3.UP, turn)
	# a strafe key holds the inside of a turn when it points the way the heading rotates.
	# spend the recent view turn over the physics ticks that actually catch up with it.
	var inside := absf(stick.x) > 0.2 and signf(turn) == -signf(stick.x)
	if not inside or (not is_zero_approx(view_turn) and signf(view_turn) != signf(turn)):
		_clear_carve()
	elif not is_zero_approx(view_turn):
		if signf(_flow_carve_turn) != signf(view_turn):
			_flow_carve_turn = 0.0
		_flow_carve_turn += view_turn
		_flow_carve_time = FLOW_CARVE_WINDOW
	if inside and signf(_flow_carve_turn) == signf(turn):
		var used := minf(absf(turn), absf(_flow_carve_turn))
		_flow_carve_turn -= signf(turn) * used
		var gain := minf(maxf(0.0, FLOW_CARVE_CAP - speed), FLOW_CARVE_GAIN * used)
		speed += gain
		carve_gain_total += gain
	return heading * speed

func _clear_carve() -> void:
	_flow_carve_turn = 0.0
	_flow_carve_time = 0.0

func _catch_landing(before: Vector3) -> void:
	# p / a downslope can catch the fall only along a collision-feasible tangent. include
	# every active plane so projecting onto the floor cannot recreate motion into a wall.
	var planes: Array[Vector3] = [_ground_normal]
	for i: int in get_slide_collision_count():
		_contact_planes(get_slide_collision(i), planes, false, true)
	var caught := _feasible_velocity(before, planes)
	var caught_h := Vector3(caught.x, 0.0, caught.z)
	velocity = _feasible_velocity(velocity, planes)
	var current := Vector3(velocity.x, 0.0, velocity.z)
	if caught_h.length() > current.length() and caught_h.dot(current) >= 0.0:
		velocity = caught

func _surface_climb(normal: Vector3, horizontal: Vector3) -> float:
	# vertical rate of travel along the support at this horizontal velocity.
	if normal.y < 0.1:
		return 0.0
	return -(normal.x * horizontal.x + normal.z * horizontal.z) / normal.y

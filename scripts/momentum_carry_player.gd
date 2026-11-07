extends "res://scripts/spillway_player.gd"
## p / r13 carry motor. height and timing carry speed, side keys can earn more, and w with
## the mouse places a jump without minting speed. velocity is still the one authoritative
## state and every contact still runs through r12's move_and_slide path and helpers.
## one motor with two air laws, chosen before the runner enters the tree; the ground, slope,
## hop, landing, body and camera policy are shared. surf, mantle and slide are not part of it.

# p / projection allowance (m/s) and coefficient (1/s), acting on the side-key wish only.
# narrow keeps r12's side-only law at 120 hz as a diagnostic control, not as cs fidelity.
# matching their best gain at 13 m/s does not match their angular window; both are measured.
const PROFILES := {
	"broad": {"air_cap": 8.5, "air_accel": 0.468},
	"narrow": {"air_cap": 0.75, "air_accel": 12.0},
}
# p / every value here is a tuning hypothesis. tests may change a copy for diagnostics.
const TUNING := {
	# ground: below run speed a push gets there fast; earned overspeed fades gently while
	# pushing, faster when coasting, and only input against the motion brakes hard.
	"run": 8.5,
	"accel": 28.0,
	"push_drag": 2.0,
	"coast_drag": 3.0,
	"stop": 30.0,
	"brake": 34.0,
	# a wish more than ~120 degrees from travel is a reversal: brake, then pivot.
	"reverse_angle": 2.1,
	"pivot_speed": 0.5,
	# turning is lateral grip, responsive at ordinary speed and bounded once overspeed.
	"grip_run": 60.0,
	"grip_over": 20.0,
	"grip_blend": 2.0,
	"turn_max": 10.0,
	# supported slope gravity along the heading, as on a frictionless incline.
	"slope": 1.0,
	# landing grace skips overspeed drag after a real flight, never after a support flicker.
	"grace": 0.08,
	"grace_min_air": 0.05,
	# air: forward input bends the line toward the full wish without changing speed. full
	# authority within 45 degrees of travel, fading to none at 90.
	"assist": 14.0,
	"assist_full": 0.7853982,
	"assist_zero": 1.5707963,
	"air_brake": 5.0,
	# diagnostic only: steer toward camera-forward instead of the full wish. with w+a at a
	# fixed view this reopens the side allowance every tick; the tests prove they detect it.
	"assist_to_view": false,
	# below run speed, w can bring a flight up to it, so held hops from a standstill still get
	# going: each hop leaves on its only ground tick, before any ground acceleration. never
	# above run speed, so it is no overspeed source.
	"air_floor": 8.5,
	"air_push": 6.0,
	# a real ramp edge keeps the surface's vertical rate.
	"edge_keep": 1.0,
	# crouch is a plain duck: slower, never a slide.
	"duck_speed": 3.2,
	"duck_drag": 12.0,
	# inherited r12 emergency envelope. every intervention is booked in the ledger.
	"safety": 30.0,
}

## "broad" or "narrow". read once when the runner enters the tree.
var air_profile: String = "broad":
	set(value):
		if is_inside_tree():
			push_warning("carry: air_profile is fixed after entering the tree")
			return
		assert(PROFILES.has(value), "carry: unknown air profile " + value)
		air_profile = value
var tuning: Dictionary = TUNING.duplicate()
var motion_tick: int = 0
## the tape executor's ordering proof reads this as one increment per motor step.
var tape_step_count: int = 0
var safety_count: int = 0
var grace_count: int = 0
var ledger_totals: Dictionary = {}
var _air_cap: float = 0.0
var _air_accel: float = 0.0
var _grace: float = 0.0
var _air_time: float = 0.0
var _support_climb: float = 0.0
var _tick_ledger: Dictionary = {}
var _tick_start_velocity := Vector3.ZERO
var _requested := Vector3.ZERO
var _engine_velocity := Vector3.ZERO
var _displacement := Vector3.ZERO
var _actual_velocity := Vector3.ZERO
var _residual := Vector3.ZERO

func _ready() -> void:
	var profile: Dictionary = PROFILES[air_profile]
	_air_cap = profile.air_cap
	_air_accel = profile.air_accel
	super()
	# measured in r13 flow: on a walkable slope the engine then travels along it at the
	# requested horizontal speed, so the ground law stores speed along the support.
	floor_constant_speed = true

func reset_to(pose: Transform3D) -> void:
	super(pose)
	_grace = 0.0
	_air_time = 0.0
	_support_climb = 0.0
	_tick_ledger = {}
	_requested = Vector3.ZERO
	_engine_velocity = Vector3.ZERO
	_displacement = Vector3.ZERO
	_actual_velocity = Vector3.ZERO
	_residual = Vector3.ZERO
	ledger_totals = {}
	safety_count = 0
	grace_count = 0

## horizontal speed of actual travel over the last motor step, for hud, audio and camera.
func get_speed() -> float:
	return Vector2(_actual_velocity.x, _actual_velocity.z).length()

## horizontal speed of the velocity the motor will request next, for control decisions.
func control_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func tape_requested_velocity() -> Vector3:
	return _requested

func _physics_process(delta: float) -> void:
	_previous_position = _current_position
	var start := global_position
	if not input_enabled:
		_current_position = global_position
		_displacement = Vector3.ZERO
		_actual_velocity = Vector3.ZERO
		return
	motion_tick += 1
	tape_step_count = motion_tick
	_tick_ledger = {}
	_tick_start_velocity = velocity
	var look := Input.get_vector("look_left", "look_right", "look_down", "look_up")
	yaw -= look.x * 2.4 * delta
	pitch = clampf(pitch + look.y * 1.8 * delta, -1.4, 1.4)
	rotation = Vector3(0.0, yaw, 0.0)
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Basis(Vector3.UP, yaw) * Vector3(stick.x, 0.0, stick.y)
	var jump_held := Input.is_action_pressed("jump")
	_hold_ticks = _hold_ticks + 1 if jump_held else 0
	if Input.is_action_just_pressed("jump"):
		_buffer = BUFFER
	else:
		_buffer = maxf(0.0, _buffer - delta)
	var ground_normal := _ground_normal
	var grounded := ground_normal != Vector3.ZERO
	# the support this tick started on. a hop clears `grounded`; landing logic never uses it,
	# because the engine can still report the floor just after a take-off.
	var started_grounded := grounded
	if grounded:
		_coyote = COYOTE
	else:
		_coyote = maxf(0.0, _coyote - delta)
	if Input.is_action_pressed("crouch"):
		crouched = true
	elif crouched and _can_stand():
		crouched = false
	_set_height(LOW_HEIGHT if crouched else STAND_HEIGHT)
	_ground_ticks = _ground_ticks + 1 if grounded else 0
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	# a buffered press, or jump held with autohop, leaves before any ground drag runs, so a
	# hop on the landing tick keeps all of its speed. coyote time jumps from the last support.
	var hop := _coyote > 0.0 and (_buffer > 0.0 or (autohop and jump_held and grounded))
	mode = "air" if hop or not grounded else ("duck" if crouched else "run")
	# each horizontal law books its own steps; only the vertical writes are booked here.
	horizontal = _carry_ground(horizontal, wish, ground_normal, delta) if grounded and not hop else _carry_air(horizontal, stick, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if grounded and not hop:
		_set_velocity("ground_hold", Vector3(velocity.x, -0.4, velocity.z))
	else:
		_set_velocity("gravity", velocity + Vector3.DOWN * GRAVITY * delta)
	if hop:
		# p / the impulse is added to the travel along the support, as a push off a moving
		# surface would be: an uphill take-off keeps its climb, a downhill one its descent.
		# coyote time jumps from the vertical rate the runner left its last support with.
		var climb := _support_climb
		if grounded:
			var along := _surface_velocity(ground_normal, horizontal)
			_set_velocity("takeoff", Vector3(along.x, velocity.y, along.z))
			climb = along.y
		_set_velocity("jump", Vector3(velocity.x, JUMP_SPEED + climb, velocity.z))
		if _ground_ticks == 1:
			hop_count += 1
		_coyote = 0.0
		_buffer = 0.0
		grounded = false
		jump_count += 1
		move_started.emit("jump")
	var capped := Vector3(velocity.x, 0.0, velocity.z).limit_length(tuning.safety)
	if _set_velocity("safety_cap", Vector3(capped.x, velocity.y, capped.z)):
		safety_count += 1
	var impact := -velocity.y
	var before_limit := velocity
	_limit_collision_speed(delta)
	if _book("safety_cap", before_limit, velocity):
		safety_count += 1
	_requested = velocity
	floor_block_on_wall = grounded
	# a crease can give the engine an aggregate "floor" without a walkable face. floating
	# contact avoids that ground-only recovery path until real floor returns, as in r12.
	motion_mode = MOTION_MODE_FLOATING if not grounded and (surf_normal != Vector3.ZERO or is_on_floor()) else MOTION_MODE_GROUNDED
	move_and_slide()
	_engine_velocity = velocity
	_book("contact_engine", _requested, velocity)
	_contacts_valid = true
	_ground_normal = _walkable_contact()
	# a separating airborne body cannot use this face as support, even when descending
	# in world space. recovery contacts may linger beside a rail after a takeoff; accepting
	# one would rearm autohop and reinterpret air velocity as surface speed on the next tick.
	if _ground_normal != Vector3.ZERO and (hop or not started_grounded) and _requested.dot(_ground_normal) > 0.001:
		_ground_normal = Vector3.ZERO
	var landed_on_floor := is_grounded()
	_clip_steep_contacts(_requested, landed_on_floor)
	if started_grounded and not hop and not landed_on_floor:
		# ran off an edge: leave with the travel along the support instead of the flat -0.4
		# hold. its horizontal part shrinks on a slope; the speed along the surface is kept.
		var along := _surface_velocity(ground_normal, Vector3(velocity.x, 0.0, velocity.z))
		_set_velocity("takeoff", Vector3(along.x, velocity.y, along.z))
		_support_climb = along.y * (tuning.edge_keep if along.y > 0.0 else 1.0)
		_set_velocity("edge_carry", Vector3(velocity.x, _support_climb, velocity.z))
	if not started_grounded and landed_on_floor:
		_catch_landing(_requested)
		# a support flicker after a few milliseconds in the air is not a new landing.
		if _air_time >= tuning.grace_min_air:
			_grace = tuning.grace
			grace_count += 1
	_air_time = 0.0 if landed_on_floor else _air_time + delta
	var resolved := Vector3(velocity.x, 0.0, velocity.z)
	if resolved.length() > tuning.safety:
		if _set_velocity("safety_cap", velocity * (tuning.safety / resolved.length())):
			safety_count += 1
	_displacement = global_position - start
	_actual_velocity = _displacement / delta
	var booked := Vector3.ZERO
	for cause: String in _tick_ledger:
		booked += _tick_ledger[cause]
	_residual = velocity - _tick_start_velocity - booked
	if not started_grounded and landed_on_floor and impact > 2.0:
		last_impact = impact
		land_count += 1
		_dip = minf(0.09, 0.018 + impact * 0.004)
		landed.emit(impact)
	if landed_on_floor:
		var travelled := Vector2(_displacement.x, _displacement.z).length()
		var step_length := 1.35 if crouched else (1.7 if in_water else 2.25)
		_distance += travelled
		_gait_phase = fmod(_gait_phase + travelled * TAU / step_length, TAU)
		if _distance > step_length:
			_distance = 0.0
			footstep.emit(clampf(get_speed() / float(tuning.run), 0.0, 1.0))
	_last_position = global_position
	_current_position = global_position

func _carry_ground(h: Vector3, wish: Vector3, normal: Vector3, delta: float) -> Vector3:
	var run: float = tuning.run
	var speed := h.length()
	var wish_length := minf(wish.length(), 1.0)
	var wish_dir := wish / wish.length() if wish_length > 0.05 else Vector3.ZERO
	var heading := h / speed if speed > 0.05 else wish_dir
	if heading == Vector3.ZERO:
		_book("stop", h, Vector3.ZERO)
		return Vector3.ZERO
	_book("pivot", h, heading * speed)
	var graced := _grace > 0.0
	_grace = maxf(0.0, _grace - delta)
	var before := heading * speed
	if speed > tuning.pivot_speed:
		# gravity along the line the engine travels on the support, positive downhill. the
		# ground speed is the speed along the surface, as floor_constant_speed moves it.
		var climb := _surface_climb(normal, heading)
		var pull := -GRAVITY * climb / sqrt(1.0 + climb * climb)
		speed = maxf(0.0, speed + pull * float(tuning.slope) * delta)
		before = _book_step("slope", before, heading * speed)
	var angle := heading.signed_angle_to(wish_dir, Vector3.UP) if wish_dir != Vector3.ZERO else 0.0
	if wish_dir == Vector3.ZERO:
		if graced:
			return before
		if in_water:
			speed = move_toward(speed, 0.0, WATER_DECAY * delta)
			return _book_step("water", before, heading * speed)
		if speed > run:
			speed = maxf(run, speed - float(tuning.coast_drag) * delta)
			return _book_step("coast", before, heading * speed)
		speed = move_toward(speed, 0.0, float(tuning.stop) * delta)
		return _book_step("stop", before, heading * speed)
	if absf(angle) > tuning.reverse_angle and speed > 0.05:
		# brake all the way to rest before the heading may flip.
		speed = move_toward(speed, 0.0, float(tuning.brake) * delta)
		return _book_step("brake", before, heading * speed)
	if speed <= tuning.pivot_speed:
		heading = wish_dir
		before = _book_step("pivot", before, heading * speed)
	else:
		var over := clampf((speed - run) / float(tuning.grip_blend), 0.0, 1.0)
		var grip := lerpf(tuning.grip_run, tuning.grip_over, over)
		var limit := minf(tuning.turn_max, grip / speed) * delta
		var turn := clampf(angle, -limit, limit)
		heading = heading.rotated(Vector3.UP, turn)
		before = _book_step("grip_turn", before, heading * speed, turn)
	var target := (float(tuning.duck_speed) if crouched else run) * wish_length
	if in_water:
		target = minf(target, WATER_SPEED)
	if speed < target:
		speed = minf(target, speed + float(tuning.accel) * delta)
		return _book_step("ground_accel", before, heading * speed)
	if crouched:
		speed = maxf(target, speed - float(tuning.duck_drag) * delta)
		return _book_step("duck", before, heading * speed)
	if in_water:
		speed = maxf(target, speed - WATER_DECAY * delta)
		return _book_step("water", before, heading * speed)
	if graced:
		return before
	speed = maxf(target, speed - float(tuning.push_drag) * delta)
	return _book_step("push_drag", before, heading * speed)

func _carry_air(h: Vector3, stick: Vector2, delta: float) -> Vector3:
	var basis := Basis(Vector3.UP, yaw)
	var forward := basis * Vector3.FORWARD
	var right := basis * Vector3.RIGHT
	var side := stick.x
	var push := -stick.y
	var current := h
	if absf(side) > 0.05:
		# the classic projection rule, fed only by the side key: the allowance compares
		# against the velocity's projection, so turning the view with the key reopens room.
		var direction := right * signf(side)
		var wish_speed := float(tuning.run) * minf(absf(side), 1.0)
		var room := minf(wish_speed, _air_cap) - current.dot(direction)
		if room > 0.0:
			current = _book_step("air_projection", current, current + direction * minf(_air_accel * wish_speed * delta, room))
	var speed := current.length()
	if push > 0.05:
		# steer toward the full wish, so w+a keeps its sideways meaning instead of always
		# aiming back at camera-forward, which would reopen the side allowance every tick.
		var wish_dir := forward if tuning.assist_to_view else (forward * push + right * side).normalized()
		if speed < tuning.air_floor:
			current = _book_step("air_low_push", current, (current + wish_dir * float(tuning.air_push) * push * delta).limit_length(maxf(speed, tuning.air_floor)))
			speed = current.length()
		if speed < 0.05:
			return current
		var angle := (current / speed).signed_angle_to(wish_dir, Vector3.UP)
		var fade := 1.0 - clampf((absf(angle) - tuning.assist_full) / (tuning.assist_zero - tuning.assist_full), 0.0, 1.0)
		var limit := float(tuning.assist) * push * fade / speed * delta
		var turn := clampf(angle, -limit, limit)
		if turn != 0.0:
			current = _book_step("air_assist", current, current.rotated(Vector3.UP, turn), turn)
	elif push < -0.05 and speed > 0.0:
		# s brakes only the part of travel it opposes and never reverses it.
		var opposed := maxf(0.0, forward.dot(current / speed)) * -push
		if opposed > 0.0:
			current = _book_step("air_brake", current, current * (move_toward(speed, 0.0, float(tuning.air_brake) * opposed * delta) / speed))
	return current

func _clip_steep_contacts(before: Vector3, landed_on_floor: bool) -> void:
	# airborne contacts lose only their component into each touched face, over the complete
	# contact cone. no surf state: a steep face is just a face, and gravity along it is booked.
	surf_normal = Vector3.ZERO
	if landed_on_floor:
		return
	var planes: Array[Vector3] = []
	for i: int in get_slide_collision_count():
		_contact_planes(get_slide_collision(i), planes, true)
	if not planes.is_empty():
		_set_velocity("contact_clip", _feasible_velocity(before, planes))

func _catch_landing(before: Vector3) -> void:
	# p / corrected flow landing: a downslope can catch the fall only along a collision-
	# feasible tangent. every active plane is included so projecting onto the floor cannot
	# recreate motion into a wall.
	var planes: Array[Vector3] = [_ground_normal]
	for i: int in get_slide_collision_count():
		_contact_planes(get_slide_collision(i), planes, false, true)
	if before.dot(_ground_normal) >= 0.0:
		return
	var caught := _feasible_velocity(before, planes)
	var caught_h := Vector3(caught.x, 0.0, caught.z)
	_set_velocity("contact_clip", _feasible_velocity(velocity, planes))
	var current := Vector3(velocity.x, 0.0, velocity.z)
	# the tangent's full length becomes the ground speed along the surface, so a landing on
	# a slope keeps its speed rather than only the horizontal part of it.
	if caught.length() > current.length() and caught_h.length_squared() > 1e-6 and caught_h.dot(current) >= 0.0:
		var surface := caught_h.normalized() * caught.length()
		_set_velocity("landing_catch", Vector3(surface.x, velocity.y, surface.z))

func _surface_climb(normal: Vector3, horizontal: Vector3) -> float:
	# vertical rate of travel along the support at this horizontal velocity.
	if normal.y < 0.1:
		return 0.0
	return -(normal.x * horizontal.x + normal.z * horizontal.z) / normal.y

func _surface_velocity(normal: Vector3, horizontal: Vector3) -> Vector3:
	# the travel the engine makes along the support for this ground velocity: same length,
	# in the vertical plane of the heading.
	var along := horizontal + Vector3.UP * _surface_climb(normal, horizontal)
	return along * (horizontal.length() / along.length()) if along.length_squared() > 1e-12 else Vector3.ZERO

func _set_velocity(cause: String, value: Vector3) -> bool:
	var changed := _book(cause, velocity, value)
	velocity = value
	return changed

func _book_step(cause: String, before: Vector3, after: Vector3, turn: float = 0.0) -> Vector3:
	_book(cause, before, after, turn)
	return after

func _book(cause: String, before: Vector3, after: Vector3, turn: float = 0.0) -> bool:
	# the ledger records what each cause did to the velocity this tick. its sum and residual
	# are bookkeeping diagnostics, not proof that the resulting energy is physical.
	var change := after - before
	if change.length_squared() < 1e-14 and turn == 0.0:
		return false
	_tick_ledger[cause] = _tick_ledger.get(cause, Vector3.ZERO) + change
	var total: Dictionary = ledger_totals.get(cause, {"horizontal": 0.0, "vertical": 0.0, "turn": 0.0, "ticks": 0})
	total.horizontal += Vector2(after.x, after.z).length() - Vector2(before.x, before.z).length()
	total.vertical += change.y
	total.turn += absf(turn)
	total.ticks += 1
	ledger_totals[cause] = total
	return true

## the motor's own report for camera, hud, audio, tests and tape consumers. requested is
## what entered move_and_slide; post_contact is the velocity after collision and landing.
func get_motion_state() -> Dictionary:
	var ledger := {}
	for cause: String in _tick_ledger:
		ledger[cause] = _tick_ledger[cause]
	return {
		"tick": motion_tick,
		"air_profile": air_profile,
		"mode": mode,
		"grounded": is_grounded(),
		"support_normal": _ground_normal,
		"steep_contact": surf_normal,
		"position": global_position,
		"previous_position": _previous_position,
		"start_velocity": _tick_start_velocity,
		"requested_velocity": _requested,
		"engine_velocity": _engine_velocity,
		"post_contact_velocity": velocity,
		"real_velocity": get_real_velocity(),
		"displacement": _displacement,
		"actual_velocity": _actual_velocity,
		"actual_speed": get_speed(),
		"control_speed": control_speed(),
		"specific_energy": 0.5 * _actual_velocity.length_squared() + GRAVITY * global_position.y,
		"contacts": _describe_contacts(),
		"ledger": ledger,
		"ledger_residual": _residual,
		"ledger_totals": ledger_totals.duplicate(true),
		"safety_interventions": safety_count,
		"landing_grace": _grace,
		"grace_count": grace_count,
		"air_time": _air_time,
		"coyote": _coyote,
		"buffer": _buffer,
		"crouched": crouched,
		"yaw": yaw,
		"pitch": pitch,
		"hop_count": hop_count,
		"jump_count": jump_count,
		"land_count": land_count,
	}

func _describe_contacts() -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	if not _contacts_valid:
		return contacts
	for i: int in get_slide_collision_count():
		var contact := get_slide_collision(i)
		for j: int in contact.get_collision_count():
			var body := contact.get_collider(j) as Node
			var normal := contact.get_normal(j)
			var entry := {
				"body": str(body.name) if body != null else "",
				"path": str(body.get_path()) if body != null and body.is_inside_tree() else "",
				"position": contact.get_position(j),
				"normal": normal,
				"walkable": normal.y >= cos(floor_max_angle),
			}
			if body != null:
				for key: String in ["progress_stage", "surface"]:
					if body.has_meta(key):
						entry[key] = body.get_meta(key)
			contacts.append(entry)
	return contacts

extends RefCounted
## root yaw never rotates physical velocity in the air.
var time: float = 0
var duration: float
var airborne: bool
var previous: float = 0
var last_start: float = -100

func start(p) -> void:
	if p._clock - last_start < p.tuning.turn_repeat:
		return
	last_start = p._clock
	time = 0
	previous = 0
	airborne = not p.grounded
	duration = p.tuning.turn_air_duration if airborne else (p.tuning.turn_run_duration if p.get_speed() > 2.6 else p.tuning.turn_stand_duration)
	p.move = p.Move.TURN
	p._air_turned = airborne
	p.move_started.emit("air_turn" if airborne else "turn")

func step(p, dt: float) -> void:
	time += dt
	var fraction: float = smoothstep(0, 1, time / duration)
	p.look((fraction - previous) * PI, 0)
	previous = fraction
	if airborne:
		p.velocity -= p.up_direction * p.tuning.gravity * dt
	else:
		if time < p.tuning.turn_lock:
			p.velocity *= maxf(0, 1 - p.tuning.ground_friction * p.tuning.turn_friction * dt)
		else:
			p.velocity = p.tuning.ground_velocity(p.velocity.slide(p.up_direction), p._wish(p._input_axis), -p.global_basis.z, 0, dt) - p.up_direction
	var pre: Vector3 = p.velocity
	p.move_and_slide()
	if airborne and p.is_on_floor():
		p._after_move(false, pre)
	elif time >= duration:
		p.move = p.Move.AIR if airborne else p.Move.GROUND

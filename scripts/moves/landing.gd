extends RefCounted
## fall height is resolved before the new ground origin is recorded.
var time: float = 0.0
var kind: String = "normal"
var height: float = 0.0
var origin: Vector3
var forward: Vector3

func start(p, impact: float, soft: bool = false) -> void:
	p._landing_elapsed = 0
	var t = p.tuning
	height = maxf(0, p._fall_origin - p.global_position.dot(p.up_direction))
	time = 0.0
	kind = "normal"
	if soft:
		kind = "soft"
	elif height >= t.death_height:
		kind = "death"
	elif p._crouch_age <= t.roll_window and height > t.roll_height and p._input_axis.y < -.1 and not p._air_turned:
		kind = "roll"
	elif height > t.hard_height or p._air_turned:
		kind = "backwards" if p._air_turned else "hard"
	if kind == "roll":
		p.velocity = Vector3.ZERO
		p.move = p.Move.ROLL
		origin = p.global_position
		forward = (-p.global_basis.z).slide(p.up_direction).normalized()
		p.move_started.emit("roll")
	elif kind in ["hard", "backwards", "death"]:
		p.velocity = Vector3.ZERO
		p.move = p.Move.LANDING
		p.move_started.emit(kind + "_landing")
	elif p._jump_flight and not p._vault_landing:
		p.velocity = p.velocity.slide(p.up_direction).limit_length(maxf(0, p._pre_jump_speed - t.landing_reduction))
	p._jump_flight = false
	p._vault_landing = false
	p._air_turned = false
	p.last_landing_speed = p.get_speed()
	p._dip_velocity -= clampf(impact * .11, .3, 2.6)
	p._nod_velocity -= clampf(impact * .012, 0, .16)
	p.landed.emit(impact)

func step(p, dt: float) -> void:
	var previous: float = time
	time += dt
	if kind == "roll":
		# original planted-shoulder/drive/recovery profile; totals match the measurement.
		var a: float = smoothstep(0, 1, previous / p.tuning.roll_duration)
		var b: float = smoothstep(0, 1, time / p.tuning.roll_duration)
		p._set_low(true, false)
		p.sweep_motion(forward * p.tuning.roll_distance * (b - a))
		p.velocity = Vector3.ZERO
		if time >= p.tuning.roll_duration:
			p.move = p.Move.GROUND
			p._set_low(false, false)
	else:
		p.velocity = Vector3.ZERO
		if time >= p.tuning.hard_duration:
			p.move = p.Move.GROUND

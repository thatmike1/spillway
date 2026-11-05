extends RefCounted
## fall height is resolved before the new ground origin is recorded.
var time: float = 0.0
var kind: String = "normal"
var height: float = 0.0
var impact: float = 0.0
var origin: Vector3
var forward: Vector3

func start(p, impact_speed: float, soft: bool = false) -> void:
	impact = impact_speed
	p._landing_elapsed = 0
	var t = p.tuning
	height = maxf(0, p._fall_origin - p.get_support_height())
	time = 0.0
	kind = "normal"
	if soft:
		kind = "soft"
	elif height >= t.death_height:
		kind = "death"
	elif p._crouch_age <= t.roll_window and height > t.roll_height and p._input_axis.y < -.1 and not p._air_turned:
		kind = "roll"
	elif height >= t.hard_height or p._air_turned:
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
	if kind in ["normal", "soft"] and p.get_speed() > .1:
		p._landing_continuation = true
		p._continuation_direction = p.velocity.slide(p.up_direction).normalized()
	p._jump_flight = false
	p._vault_landing = false
	p._air_turned = false
	p.last_landing_speed = p.get_speed()
	# P: normal impact is composed by the eye curve; hard/roll have their own clips.
	p.landed.emit(impact)

func step(p, dt: float) -> void:
	var previous: float = time
	time += dt
	if kind == "roll":
		# port choice (P): constant swept root motion, with matching outgoing velocity.
		var duration: float = p.tuning.roll_active_duration
		var active_dt: float = minf(time, duration) - minf(previous, duration)
		p._set_low(true, false)
		var before: Vector3 = p.global_position
		p.sweep_motion(forward * p.tuning.roll_distance * active_dt / duration)
		p.velocity = (p.global_position - before) / dt
		p._body_recovery = .25
		if time + .000001 >= duration:
			p.move = p.Move.GROUND
			p._context_lock = .12
			p._set_low(false, false)
	else:
		p.velocity = Vector3.ZERO
		p._body_recovery = .25
		if time >= p.tuning.hard_duration:
			p.move = p.Move.GROUND

extends RefCounted
## into-grab clears momentum; pull-up owns an original swept root profile.
var time: float = 0.0
var origin: Vector3
var target: Vector3
var top: Vector3
var into: Vector3
var phase: String = "align"
var duration: float

func start(p, edge: Dictionary) -> void:
	time = 0
	phase = "align"
	origin = p.global_position
	top = edge.top
	into = edge.into
	target = top - into * p.tuning.radius - p.up_direction * p.tuning.grab_drop
	duration = maxf(.05, origin.distance_to(target) / maxf(p.tuning.grab_speed, p.get_speed()))
	p._climb_hand = top
	p.move = p.Move.GRAB
	p.velocity = Vector3.ZERO
	p.move_started.emit("grab")

func pull(p) -> void:
	phase = "pull"
	time = 0
	origin = p.global_position
	target = top + into * p.tuning.pull_forward + p.up_direction * (.9 + p.tuning.contact_margin)
	if p._blocked_at(target):
		phase = "hang"
		return
	p.move = p.Move.PULLUP
	p.move_started.emit("pullup")

func step(p, dt: float) -> void:
	time += dt
	p.velocity = Vector3.ZERO
	if phase == "align":
		var fraction: float = minf(time / duration, 1)
		p.sweep_motion(origin.lerp(target, fraction) - p.global_position)
		if fraction >= 1:
			phase = "hang"
			time = 0
	elif phase == "hang":
		if p._jump_buffer > 0 or (p._input_axis.y < -.7 and time > .18):
			pull(p)
		elif p._crouch_held:
			p.move = p.Move.AIR
			p._context_lock = p.tuning.grab_repeat
	elif phase == "pull":
		var fraction: float = clampf(time / p.tuning.pull_duration, 0, 1)
		# raise the hips while hands stay planted, then move over the lip.
		var rise: Vector3 = p.up_direction * (target - origin).dot(p.up_direction)
		var across: Vector3 = (target - origin).slide(p.up_direction)
		var point: Vector3 = origin + rise * smoothstep(0, .65, fraction) + across * smoothstep(.55, 1, fraction)
		var hit = p.sweep_motion(point - p.global_position)
		if hit != null and hit.get_normal().dot(p.up_direction) < .7:
			p.move = p.Move.AIR
			return
		if fraction >= 1:
			p.move = p.Move.AIR
			p._context_lock = .2
			p._since_jump = .2

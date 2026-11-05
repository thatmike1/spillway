extends RefCounted
## special step-ups are original swept clips; ordinary .35m steps use a sweep solver.
var time: float
var duration: float
var origin: Vector3
var target: Vector3

func start(p, edge: Dictionary) -> void:
	time = 0
	origin = p.global_position
	target = Vector3(edge.top) + Vector3(edge.into) * p.tuning.radius + p.up_direction * (.9 + p.tuning.contact_margin)
	var h: float = edge.height
	duration = p.tuning.step_times.x if h <= .68 else (p.tuning.step_times.y if h <= 1.12 else p.tuning.step_times.z)
	p.move = p.Move.STEP
	p.velocity = Vector3.ZERO
	p.move_started.emit("step")

func step(p, dt: float) -> void:
	time += dt
	var f: float = clampf(time / duration, 0, 1)
	var rise: Vector3 = p.up_direction * (target - origin).dot(p.up_direction)
	var across: Vector3 = (target - origin).slide(p.up_direction)
	var point: Vector3 = origin + rise * smoothstep(0, .6, f) + across * smoothstep(.5, 1, f)
	var hit = p.sweep_motion(point - p.global_position)
	if hit != null and hit.get_normal().dot(p.up_direction) < .7:
		p.move = p.Move.AIR
		return
	if f >= 1:
		p.move = p.Move.AIR
		p.velocity = Vector3.ZERO
		p._context_lock = .2

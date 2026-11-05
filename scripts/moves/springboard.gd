extends RefCounted
## paired footplants are swept precise movements, followed by one ballistic launch.
var time: float = 0
var duration: float
var origin: Vector3
var intermediate: Vector3
var target: Vector3
var direction: Vector3
var saved: float

func start(p, first: Dictionary, second: Dictionary) -> void:
	time = 0
	origin = p.global_position
	direction = first.into
	saved = maxf(p.tuning.spring_min_speed, p.get_speed())
	intermediate = Vector3(first.top) + p.up_direction * (.9 + p.tuning.contact_margin)
	target = Vector3(second.top) + p.up_direction * (.9 + p.tuning.contact_margin)
	duration = maxf(.25, origin.distance_to(target) / saved)
	p.velocity = Vector3.ZERO
	p.move = p.Move.SPRINGBOARD
	p._jump_buffer = 0
	p.move_started.emit("springboard")

func step(p, dt: float) -> void:
	time += dt
	var f: float = clampf(time / duration, 0, 1)
	var target_now: Vector3
	if f < .5:
		var rise: Vector3 = p.up_direction * (intermediate - origin).dot(p.up_direction)
		target_now = origin + rise * smoothstep(0, .25, f) + (intermediate - origin).slide(p.up_direction) * smoothstep(.2, .5, f)
	else:
		var rise: Vector3 = p.up_direction * (target - intermediate).dot(p.up_direction)
		target_now = intermediate + rise * smoothstep(.5, .7, f) + (target - intermediate).slide(p.up_direction) * smoothstep(.65, 1, f)
	var hit = p.sweep_motion(target_now - p.global_position)
	if hit != null and hit.get_normal().dot(p.up_direction) < .7:
		p.move = p.Move.AIR
		return
	if f >= 1:
		p._jump_flight = false
		p._do_jump(direction * maxf(p.tuning.spring_launch_min, saved - p.tuning.spring_launch_cost) + p.up_direction * p.tuning.spring_launch_y)

extends RefCounted
## tangent momentum and two vertical phases; repeat count persists across jumps.
var time: float = 0
var normal: Vector3
var side: float
var consecutive: int = 0
var from_jump: bool = false
var illegal_normal: Vector3 = Vector3.ZERO
var illegal_time: float = 0
var vertical: bool = false

func start(p, n: Vector3, wall_side: float) -> void:
	var t = p.tuning
	consecutive = consecutive + 1 if from_jump else 0
	from_jump = false
	normal = n
	side = wall_side
	time = 0
	vertical = false
	var tangent: Vector3 = p.velocity.slide(p.up_direction).slide(n)
	var speed: float = maxf(tangent.length(), t.wall_begin_speed if p.velocity.dot(p.up_direction) > 0 else 0)
	var gained: float = maxf(0, (p.global_position - p._jump_origin).dot(p.up_direction))
	var budget: float = maxf(0, t.wall_height_budget - gained)
	var ceiling = p._ray(p.global_position, p.global_position + p.up_direction * (budget + .9))
	if not ceiling.is_empty():
		budget = maxf(0, (Vector3(ceiling.position) - p.global_position).dot(p.up_direction) - .9)
	var vz: float = sqrt(2 * budget * t.wall_up_accel)
	p.velocity = tangent.normalized() * speed + p.up_direction * vz
	p._wall_normal = n
	p._wall_side = side
	p.move = p.Move.WALLRUN
	p.move_started.emit("wallrun")

func start_vertical(p, n: Vector3) -> void:
	var t = p.tuning
	normal = n
	vertical = true
	time = 0
	var h: float = t.climb_horizontal_height * clampf(inverse_lerp(t.climb_speed_min, t.climb_speed_max, p.get_speed()), 0, 1)
	h += t.climb_vertical_height * clampf(p.velocity.dot(p.up_direction) / t.climb_vertical_max, 0, 1)
	p.velocity = p.up_direction * sqrt(maxf(4 * h * t.gravity, .0001))
	p.move = p.Move.WALLCLIMB
	p._wall_normal = n
	p.move_started.emit("wallclimb")

func jump(p) -> void:
	var t = p.tuning
	var d: float = normal.dot(p.get_camera_forward().slide(p.up_direction).normalized())
	var tangent: Vector3 = p.velocity.slide(p.up_direction).slide(normal)
	var height: float = maxf(.01, t.wall_jump_height + t.wall_jump_turned * d)
	var vz: float = 2 * t.gravity * sqrt(height / t.gravity) / (1 + consecutive)
	p._do_jump(tangent * (t.wall_tangent_min + (1 - t.wall_tangent_min) * (1 - d)) + normal * (t.wall_push + t.wall_push_turned * d) + p.up_direction * vz)
	from_jump = true
	illegal_normal = normal
	illegal_time = t.wall_illegal_time
	p._context_lock = t.wall_repeat
	p.move_started.emit("walljump")

func step(p, dt: float) -> void:
	time += dt
	var t = p.tuning
	if p._jump_buffer > 0 and not vertical:
		jump(p)
		return
	var contact = p._ray(p.global_position, p.global_position - normal * (t.radius + (t.climb_distance if vertical else t.wall_probe)))
	if contact.is_empty() or p._input_axis.y >= -.1:
		p.move = p.Move.AIR
		return
	var vz: float = p.velocity.dot(p.up_direction)
	var a: float = t.gravity if vertical else (t.wall_up_accel if vz > 0 else t.wall_down_accel) * (1 + consecutive)
	vz -= a * dt
	var tangent: Vector3 = p.velocity.slide(p.up_direction).slide(normal)
	if not vertical:
		tangent *= maxf(0, 1 - t.wall_friction * dt)
	p.velocity = tangent + p.up_direction * vz - normal * (t.climb_attraction if vertical else t.wall_contact_press)
	p._climb_hand = Vector3(contact.position) + p.up_direction * .4
	if vz <= (0 if vertical else t.wall_exit_vertical):
		p.move = p.Move.AIR
		p._context_lock = t.wall_repeat
		return
	var edge: Dictionary = p.detect_edge(t.grab_reach, 3.2)
	if not edge.is_empty() and vertical and float(edge.height) < 2.2:
		p.ledge.start(p, edge)
		return
	var pre: Vector3 = p.velocity
	p.move_and_slide()
	if p.is_on_floor():
		p.move = p.Move.GROUND
		p._after_move(false, pre)

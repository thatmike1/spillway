extends RefCounted
## slide friction is independent of run propulsion, and every exit halves velocity.
var time: float = 0
var start_yaw: Vector3

func start(p, lateral: Vector3) -> void:
	time = 0
	start_yaw = -p.global_basis.z
	p.move = p.Move.SLIDE
	p.velocity = lateral
	p._set_low(true, false)
	p.move_started.emit("slide")

func finish(p) -> void:
	p.velocity *= p.tuning.slide_exit
	p.move = p.Move.AIR if not p.is_on_floor() else p.Move.GROUND
	p._context_lock = .1
	p._set_low(p._crouch_held, false)

func step(p, dt: float) -> void:
	time += dt
	var t = p.tuning
	var lateral: Vector3 = p.velocity.slide(p.up_direction)
	lateral *= maxf(0, 1 - t.ground_friction * t.slide_friction * dt)
	var vz: float = minf(0, p.velocity.dot(p.up_direction)) - t.gravity * dt
	p.velocity = lateral + p.up_direction * vz
	if time >= t.slide_lock and (not p._crouch_held or lateral.length() < t.slide_abort or time >= t.slide_duration):
		finish(p)
		return
	p.move_and_slide()
	if not p.is_on_floor():
		finish(p)

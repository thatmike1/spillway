extends Camera3D
## a separate presentation camera: the runner's physics view and camera stay untouched.
var _base: Camera3D
var offset_degrees := 0.0

func update(base: Camera3D, speed_ups: float, delta: float, on: bool) -> void:
	if not on or base == null:
		reset()
		return
	_base = base
	# a broad speed band, slow response and a rate limit avoid per-hop pumping.
	var target := clampf((speed_ups - 400.0) / 600.0, 0.0, 1.0) * 3.0
	var dt := clampf(delta, 0.0, 0.1)
	var eased := lerpf(offset_degrees, target, 1.0 - exp(-1.2 * dt))
	offset_degrees = move_toward(offset_degrees, eased, dt * 1.5)
	global_transform = base.global_transform
	projection = base.projection
	keep_aspect = base.keep_aspect
	near = base.near
	far = base.far
	size = base.size
	frustum_offset = base.frustum_offset
	h_offset = base.h_offset
	v_offset = base.v_offset
	cull_mask = base.cull_mask
	environment = base.environment
	attributes = base.attributes
	compositor = base.compositor
	doppler_tracking = base.doppler_tracking
	fov = minf(175.0, base.fov + offset_degrees)
	if not current:
		make_current()

func reset() -> void:
	if current:
		if is_instance_valid(_base) and _base.is_inside_tree():
			clear_current(false)
			_base.make_current()
		else:
			clear_current(true)
	_base = null
	offset_degrees = 0.0

func _exit_tree() -> void:
	reset()

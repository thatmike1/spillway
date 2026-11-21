extends Camera3D
## a second presentation camera for the speed view; the runner's own camera is never written.
var _base: Camera3D
var _copied := Transform3D()

## offset_degrees widens the view; a negative dip_m lowers it for a landing settle. both rest at zero.
func update(base: Camera3D, offset_degrees: float, dip_m: float) -> void:
	if base == null or not base.is_inside_tree() or (absf(offset_degrees) < 0.02 and absf(dip_m) < 0.0005):
		reset()
		return
	var taking_over := not current or _base != base
	_base = base
	# follow the runner's eye whenever it moves. a static capture pose moves only the current
	# camera while the frozen eye stays put; keep that pose instead of copying over it.
	if taking_over or base.global_transform != _copied:
		global_transform = base.global_transform
		_copied = base.global_transform
	projection = base.projection
	keep_aspect = base.keep_aspect
	near = base.near
	far = base.far
	size = base.size
	frustum_offset = base.frustum_offset
	h_offset = base.h_offset
	# the settle is a view offset, not a move: anything that reads the rendering camera's position
	# (ghost fade, rain and snow boxes) sees exactly the runner's eye.
	v_offset = base.v_offset + dip_m
	cull_mask = base.cull_mask
	environment = base.environment
	attributes = base.attributes
	compositor = base.compositor
	doppler_tracking = base.doppler_tracking
	fov = clampf(base.fov + offset_degrees, 1.0, 175.0)
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

func _exit_tree() -> void:
	reset()

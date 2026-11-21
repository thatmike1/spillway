extends Camera3D
## a second presentation camera for the speed view; the runner's own camera is never written.
var _base: Camera3D
var _held := false

## offset_degrees widens the view; a negative dip_m lowers it for a landing settle. both rest at zero.
func update(base: Camera3D, offset_degrees: float, dip_m: float, hold_pose: bool) -> void:
	if base == null or not base.is_inside_tree() or (absf(offset_degrees) < 0.02 and absf(dip_m) < 0.0005):
		reset()
		return
	var taking_over := not current or _base != base
	_base = base
	# a static capture pose moves the current camera once; keep it instead of copying over it.
	if not (hold_pose and _held and not taking_over):
		global_transform = base.global_transform.translated(Vector3.UP * dip_m)
	_held = hold_pose
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
	_held = false

func _exit_tree() -> void:
	reset()

extends Camera3D
## a second presentation camera for the speed view; the runner's own camera is never written.
## while it shows the view it rides as a child of the runner camera with an identity transform,
## so anything that reads the rendering camera's position in the same frame (ghost fade, rain
## and snow boxes) sees exactly the runner's eye, never last frame's copy. at rest it is detached.
var _base: Camera3D
var _copied := Transform3D()

## offset_degrees widens the view; a negative dip_m lowers it for a landing settle. both rest at zero.
func update(base: Camera3D, offset_degrees: float, dip_m: float) -> void:
	if base == null or not base.is_inside_tree() or (absf(offset_degrees) < 0.02 and absf(dip_m) < 0.0005):
		reset()
		return
	var taking_over := not current or _base != base or get_parent() != base
	if get_parent() != base:
		if get_parent() != null:
			get_parent().remove_child(self)
		base.add_child(self)
	_base = base
	# a static capture pose moves only the current camera while the frozen eye stays put; keep
	# that pose. whenever the eye moves (every frame of play) the lens is back on it exactly.
	if taking_over or base.global_transform != _copied:
		transform = Transform3D.IDENTITY
		_copied = base.global_transform
	projection = base.projection
	keep_aspect = base.keep_aspect
	near = base.near
	far = base.far
	size = base.size
	frustum_offset = base.frustum_offset
	h_offset = base.h_offset
	# the settle is a view offset, not a move: the lens position stays the runner's eye.
	v_offset = base.v_offset + dip_m
	cull_mask = base.cull_mask
	environment = base.environment
	attributes = base.attributes
	compositor = base.compositor
	doppler_tracking = base.doppler_tracking
	fov = clampf(base.fov + offset_degrees, 1.0, 175.0)
	if not current:
		make_current()

## hand the view back to the runner camera and leave the runner's tree untouched.
func reset() -> void:
	if current:
		if is_instance_valid(_base) and _base.is_inside_tree() and not _base.is_queued_for_deletion():
			clear_current(false)
			_base.make_current()
		else:
			clear_current(true)
	_base = null
	if get_parent() != null:
		get_parent().remove_child(self)

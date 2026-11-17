extends Node3D
## optional presentation observer; never changes runner state or acquisition readiness.
const KEYS := ["tether_rope_visual", "tether_attach_cue", "tether_reel_audio", "tether_tension_audio", "tether_wind_audio", "tether_speed_fov", "tether_anchor_readability"]
const SOUND := preload("res://scripts/audio/tether_sound.gd")
const LENS := preload("res://scripts/fx/tether_lens.gd")
const SEGMENTS := 20
const ROPE_RADIUS := 0.002
var options := {}
var runner: Node3D
var _segments: Array[MeshInstance3D] = []
var _outlines: Array[MeshInstance3D] = []
var _flash: MeshInstance3D
var _ready_marker: MeshInstance3D
var _was_attached := false
var _flash_left := 0.0
var _material: StandardMaterial3D
var _last_count := -1
var _sound: Node
var _lens: Camera3D

func _ready() -> void:
	process_priority = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = _flat(Color("e8dfbd"))
	var ink := _flat(Color("29464a"))
	ink.cull_mode = BaseMaterial3D.CULL_FRONT
	for i: int in SEGMENTS:
		_segments.append(_rope_piece(_material))
		_outlines.append(_rope_piece(ink))
	_flash = _ring(Color("e8dfbd"), 0.22, 0.27)
	_ready_marker = _ring(Color("e8dfbd"), 0.90, 0.96)
	_sound = SOUND.new()
	add_child(_sound)
	_lens = LENS.new()
	add_child(_lens)
	reset()

func attach(body: Node3D) -> bool:
	reset()
	runner = body if body != null and body.has_method("r21_acquisition_snapshot") and body.has_method("get_motion_state") else null
	return runner != null

func configure(settings: Dictionary) -> void:
	for key: String in KEYS:
		options[key] = bool(settings.get(key, false))
	if _sound != null:
		_sound.set_volume(float(settings.get("volume", 0.8)))
		if not enabled("tether_attach_cue"):
			_sound.voices.attach.stop()
	if _lens != null and not enabled("tether_speed_fov"):
		_lens.reset()

func enabled(key: String) -> bool:
	return bool(options.get(key, false))

func reset() -> void:
	if _lens != null:
		_lens.reset()
	if _sound != null:
		_sound.stop_all()
	_was_attached = false
	_flash_left = 0.0
	_last_count = -1
	for piece: MeshInstance3D in _segments + _outlines:
		piece.visible = false
	if _flash != null:
		_flash.visible = false
	if _ready_marker != null:
		_ready_marker.visible = false

func _process(delta: float) -> void:
	observe(delta)

func observe(delta: float) -> void:
	if not is_instance_valid(runner) or not runner.is_inside_tree() or get_tree().paused or not bool(runner.get("input_enabled")):
		reset()
		return
	var snapshot: Dictionary = runner.call("r21_acquisition_snapshot")
	var attached := bool(snapshot.get("attached", false))
	var count := int(runner.get("grapple_count"))
	if _last_count >= 0 and count < _last_count:
		reset()
	_last_count = count
	if attached and not _was_attached:
		_flash_left = 0.18
		if enabled("tether_attach_cue"):
			_sound.attach_cue()
	_was_attached = attached
	_flash_left = maxf(0.0, _flash_left - clampf(delta, 0.0, 0.1))
	var camera: Camera3D = runner.get("camera")
	if camera == null:
		return
	var endpoint: Vector3 = snapshot.get("position", Vector3.ZERO)
	var rest_m := float(runner.get("grapple_length_u")) * float(runner.get("U"))
	var centre: Vector3 = runner.call("_hull_centre")
	var distance := centre.distance_to(endpoint)
	var tension := clampf((distance - rest_m) / 1.2, 0.0, 1.0) if attached else 0.0
	var impulses: Dictionary = runner.get("impulses")
	var pull: Vector3 = impulses.get("grapple_pull", Vector3.ZERO)
	var catch_: Vector3 = impulses.get("grapple_rope", Vector3.ZERO)
	var hz := float(runner.get("physics_hz"))
	tension = maxf(tension, clampf((pull + catch_).length() * hz / 1800.0, 0.0, 1.0))
	var speed := (runner.get("velocity") as Vector3).length() / float(runner.get("U"))
	_sound.update(delta, attached, bool(runner.call("reel_active")), tension, speed, options)
	_lens.update(camera, speed, delta, enabled("tether_speed_fov"))
	var view_fov := _lens.fov if _lens.current else camera.fov
	var start := rope_origin(camera, view_fov)
	var view_camera: Camera3D = _lens if _lens.current else camera
	var pixel_height := maxf(1.0, camera.get_viewport().get_visible_rect().size.y)
	var world_per_pixel_depth := 2.0 / (pixel_height * absf(view_camera.get_camera_projection().y.y))
	var sag := minf(1.8, maxf(0.0, rest_m - distance) * 0.45) if attached else 0.0
	for i: int in SEGMENTS:
		var piece := _segments[i]
		var outline := _outlines[i]
		piece.visible = attached and enabled("tether_rope_visual")
		outline.visible = piece.visible
		if not piece.visible:
			continue
		var a := rope_point(start, endpoint, sag, float(i) / SEGMENTS)
		var b := rope_point(start, endpoint, sag, float(i + 1) / SEGMENTS)
		var clipped := clip_segment(view_camera, a, b)
		if clipped.is_empty():
			piece.visible = false
			outline.visible = false
			continue
		a = clipped[0]
		b = clipped[1]
		var along := b - a
		if along.length_squared() < 0.000001:
			piece.visible = false
			outline.visible = false
			continue
		var y := along.normalized()
		var helper := Vector3.RIGHT if absf(y.dot(Vector3.UP)) > 0.98 else Vector3.UP
		var x := y.cross(helper).normalized()
		var midpoint := (a + b) * 0.5
		var depth_a := -view_camera.global_basis.z.dot(a - view_camera.global_position)
		var depth_b := -view_camera.global_basis.z.dot(b - view_camera.global_position)
		var perspective := view_camera.projection != Camera3D.PROJECTION_ORTHOGONAL
		var radii_a := cable_radii(world_per_pixel_depth * depth_a if perspective else world_per_pixel_depth, tension)
		var radii_b := cable_radii(world_per_pixel_depth * depth_b if perspective else world_per_pixel_depth, tension)
		# matching endpoint radii join adjacent segments without a sudden change in stroke.
		(piece.mesh as CylinderMesh).bottom_radius = radii_a.x
		(piece.mesh as CylinderMesh).top_radius = radii_b.x
		(outline.mesh as CylinderMesh).bottom_radius = radii_a.y
		(outline.mesh as CylinderMesh).top_radius = radii_b.y
		var transform_ := Transform3D(Basis(x, y * along.length(), x.cross(y)), midpoint)
		piece.global_transform = transform_
		outline.global_transform = transform_
	_material.albedo_color = Color("e8dfbd").lerp(Color("b5683c"), tension * 0.65)
	_flash.visible = attached and enabled("tether_attach_cue") and _flash_left > 0.0
	if _flash.visible:
		_face_ring(_flash, endpoint, camera)
		_flash.scale = Vector3.ONE * (1.0 + (1.0 - _flash_left / 0.18) * 2.0) * cue_scale(camera.global_position.distance_to(endpoint))
	_ready_marker.visible = enabled("tether_anchor_readability") and not attached and bool(snapshot.get("ready", false))
	if _ready_marker.visible:
		_face_ring(_ready_marker, endpoint, camera)
		_ready_marker.scale = Vector3.ONE * cue_scale(camera.global_position.distance_to(endpoint))

static func rope_origin(camera: Camera3D, view_fov: float) -> Vector3:
	# terminate below the viewport so the cable never floats loose inside the aiming view.
	return camera.global_position + camera.global_basis * Vector3(0.23, -0.48 * tan(deg_to_rad(view_fov) * 0.5) * 1.12, -0.48)

static func cable_radii(world_per_pixel: float, tension: float) -> Vector2:
	# cap the physical minimum in screen space when a cable passes close to the eye.
	var load_scale := 1.0 + clampf(tension, 0.0, 1.0) * 0.15
	return Vector2(minf(clampf(world_per_pixel, 0.002, 0.05), world_per_pixel * 1.25), minf(clampf(world_per_pixel * 2.0, 0.0032, 0.09), world_per_pixel * 2.5)) * load_scale

static func clip_segment(camera: Camera3D, a: Vector3, b: Vector3) -> PackedVector3Array:
	# clip before sizing the mesh; a midpoint behind the near plane has no useful scale.
	var depth_a := -camera.global_basis.z.dot(a - camera.global_position)
	var depth_b := -camera.global_basis.z.dot(b - camera.global_position)
	if depth_a < camera.near and depth_b < camera.near:
		return PackedVector3Array()
	if depth_a < camera.near:
		a = a.lerp(b, (camera.near - depth_a) / (depth_b - depth_a))
	elif depth_b < camera.near:
		b = b.lerp(a, (camera.near - depth_b) / (depth_a - depth_b))
	return PackedVector3Array([a, b])

static func cue_scale(distance: float) -> float:
	# keep endpoint rings below about six degrees of angular radius near the camera.
	return clampf(distance / 10.0, 0.0, 1.0)

func _rope_piece(material: StandardMaterial3D) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh_ := CylinderMesh.new()
	mesh_.top_radius = ROPE_RADIUS
	mesh_.bottom_radius = ROPE_RADIUS
	mesh_.height = 1.0
	mesh_.radial_segments = 6
	piece.mesh = mesh_
	piece.material_override = material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)
	return piece

static func rope_point(start: Vector3, end: Vector3, sag: float, t: float) -> Vector3:
	return start.lerp(end, t) + Vector3.DOWN * (4.0 * t * (1.0 - t) * sag)

func _face_ring(ring: MeshInstance3D, at: Vector3, camera: Camera3D) -> void:
	ring.global_position = at
	if at.distance_squared_to(camera.global_position) > 0.0001:
		var direction := (camera.global_position - at).normalized()
		var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
		ring.look_at(camera.global_position, up)
		ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)

func _ring(color: Color, inner: float, outer: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh_ := TorusMesh.new()
	mesh_.inner_radius = inner
	mesh_.outer_radius = outer
	node.mesh = mesh_
	var material := _flat(color)
	var ink := _flat(Color("29464a"))
	ink.cull_mode = BaseMaterial3D.CULL_FRONT
	ink.grow = true
	ink.grow_amount = 0.08
	material.next_pass = ink
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

static func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

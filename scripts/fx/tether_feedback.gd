extends Node3D
## optional presentation observer; never changes runner state or acquisition readiness.
const KEYS := ["tether_rope_visual", "tether_attach_cue", "tether_reel_audio", "tether_tension_audio", "tether_wind_audio", "tether_speed_fov", "tether_anchor_readability"]
const SOUND := preload("res://scripts/audio/tether_sound.gd")
const SEGMENTS := 20
var options := {}
var runner: Node3D
var _segments: Array[MeshInstance3D] = []
var _flash: MeshInstance3D
var _ready_marker: MeshInstance3D
var _was_attached := false
var _flash_left := 0.0
var _material: StandardMaterial3D
var _last_count := -1
var _sound: Node

func _ready() -> void:
	process_priority = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = _flat(Color("e8dfbd"))
	for i: int in SEGMENTS:
		var piece := MeshInstance3D.new()
		var mesh_ := CylinderMesh.new()
		mesh_.top_radius = 0.026
		mesh_.bottom_radius = 0.026
		mesh_.height = 1.0
		mesh_.radial_segments = 6
		piece.mesh = mesh_
		piece.material_override = _material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
		_segments.append(piece)
	_flash = _ring(Color("e8dfbd"), 0.22, 0.27)
	_ready_marker = _ring(Color("e8dfbd"), 0.90, 0.96)
	_sound = SOUND.new()
	add_child(_sound)
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

func enabled(key: String) -> bool:
	return bool(options.get(key, false))

func reset() -> void:
	if _sound != null:
		_sound.stop_all()
	_was_attached = false
	_flash_left = 0.0
	_last_count = -1
	for piece: MeshInstance3D in _segments:
		piece.visible = false
	if _flash != null:
		_flash.visible = false
	if _ready_marker != null:
		_ready_marker.visible = false

func _process(delta: float) -> void:
	observe(delta)

func observe(delta: float) -> void:
	if not is_instance_valid(runner) or get_tree().paused or not bool(runner.get("input_enabled")):
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
	var start := camera.global_position + camera.global_basis * Vector3(0.23, -0.26, -0.48)
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
	var sag := minf(1.8, maxf(0.0, rest_m - distance) * 0.45) if attached else 0.0
	for i: int in SEGMENTS:
		var piece := _segments[i]
		piece.visible = attached and enabled("tether_rope_visual")
		if not piece.visible:
			continue
		var a := rope_point(start, endpoint, sag, float(i) / SEGMENTS)
		var b := rope_point(start, endpoint, sag, float(i + 1) / SEGMENTS)
		var along := b - a
		if along.length_squared() < 0.000001:
			piece.visible = false
			continue
		var y := along.normalized()
		var helper := Vector3.RIGHT if absf(y.dot(Vector3.UP)) > 0.98 else Vector3.UP
		var x := y.cross(helper).normalized()
		piece.global_transform = Transform3D(Basis(x * (1.0 + tension * 0.15), y * along.length(), x.cross(y) * (1.0 + tension * 0.15)), (a + b) * 0.5)
	_material.albedo_color = Color("e8dfbd").lerp(Color("b5683c"), tension * 0.65)
	_flash.visible = attached and enabled("tether_attach_cue") and _flash_left > 0.0
	if _flash.visible:
		_face_ring(_flash, endpoint, camera)
		_flash.scale = Vector3.ONE * (1.0 + (1.0 - _flash_left / 0.18) * 2.0)
	_ready_marker.visible = enabled("tether_anchor_readability") and not attached and bool(snapshot.get("ready", false))
	if _ready_marker.visible:
		_face_ring(_ready_marker, endpoint, camera)

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
	node.material_override = _flat(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

static func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

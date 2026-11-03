extends Node
## First-person arms, drawn in their own small world on top of the scene so
## they never clip into walls. Poses are positions in camera space that the
## wrists spring toward: low pumping while running, both hands up and out on a
## jump, a push down on landing, palms planted on a vault, a hand on the wall.

const SKIN: Color = Color("#c39176")
const SLEEVE: Color = Color("#1b222c")
const CUFF: Color = Color("#3c4652")

var _player: CharacterBody3D
var _viewport: SubViewport
var _camera: Camera3D
var _layer: CanvasLayer
var _rect: TextureRect
var _arms: Array[Dictionary] = []
var _land_kick: float = 0.0
var _jump_kick: float = 0.0
var _materials: Dictionary = {}


func attach(player: CharacterBody3D) -> void:
	_player = player
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#7f93ad")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	_viewport.add_child(world)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 150, 0)
	key.light_color = Color("#ffd8b0")
	key.light_energy = 1.1
	_viewport.add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(10, -30, 0)
	rim.light_color = Color("#9fc3e0")
	rim.light_energy = 0.5
	_viewport.add_child(rim)
	_camera = Camera3D.new()
	_camera.near = 0.01
	_camera.far = 10.0
	_camera.current = true
	_viewport.add_child(_camera)
	_materials["skin"] = _material(SKIN, 0.7)
	_materials["sleeve"] = _material(SLEEVE, 0.9)
	_materials["cuff"] = _material(CUFF, 0.8)
	_materials["glove"] = _material(Color("#20262e"), 0.8)
	for side: float in [-1.0, 1.0]:
		_arms.append(_build_arm(side))
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_rect = TextureRect.new()
	_rect.texture = _viewport.get_texture()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_rect)
	player.connect("landed", func(impact: float) -> void: _land_kick = clampf(impact / 12.0, 0.25, 1.0))
	player.connect("jumped", func() -> void: _jump_kick = 1.0)
	get_viewport().size_changed.connect(_resize)
	_resize()


func _resize() -> void:
	if _viewport == null:
		return
	_viewport.size = get_viewport().get_visible_rect().size


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _capsule(parent: Node3D, radius: float, length: float, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length, radius * 2.0)
	mesh.radial_segments = 12
	mesh.rings = 4
	instance.mesh = mesh
	instance.material_override = material
	# capsules are built along Y; the arm code aims them along -Z
	instance.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	parent.add_child(instance)
	return instance


## Hand space: wrist at the origin, fingers along -Z, back of the hand along +Y,
## thumb toward the body's centre line.
func _build_arm(side: float) -> Dictionary:
	var upper: Node3D = Node3D.new()
	_camera.add_child(upper)
	_capsule(upper, 0.05, 1.0, _materials["sleeve"]).name = "Mesh"
	var fore: Node3D = Node3D.new()
	_camera.add_child(fore)
	_capsule(fore, 0.042, 1.0, _materials["sleeve"]).name = "Mesh"
	var hand: Node3D = Node3D.new()
	_camera.add_child(hand)
	var cuff: MeshInstance3D = MeshInstance3D.new()
	var band: CylinderMesh = CylinderMesh.new()
	band.top_radius = 0.043
	band.bottom_radius = 0.043
	band.height = 0.022
	band.radial_segments = 14
	cuff.mesh = band
	cuff.material_override = _materials["cuff"]
	cuff.rotation_degrees = Vector3(90, 0, 0)
	cuff.position = Vector3(0, 0, 0.018)
	hand.add_child(cuff)
	var palm: MeshInstance3D = MeshInstance3D.new()
	var ellipsoid: SphereMesh = SphereMesh.new()
	ellipsoid.radius = 0.5
	ellipsoid.height = 1.0
	ellipsoid.radial_segments = 16
	ellipsoid.rings = 8
	palm.mesh = ellipsoid
	palm.material_override = _materials["skin"]
	palm.scale = Vector3(0.082, 0.034, 0.105)
	palm.position = Vector3(0, 0, -0.048)
	hand.add_child(palm)
	var fingers: Array[Node3D] = []
	var offsets: Array = [-0.027, -0.009, 0.009, 0.026]
	var lengths: Array = [0.074, 0.082, 0.077, 0.061]
	for finger: int in range(4):
		# index finger sits next to the thumb, on the inside
		var x: float = float(offsets[finger]) * side * -1.0
		var length: float = lengths[finger]
		var root_joint: Node3D = Node3D.new()
		root_joint.position = Vector3(x, 0.002, -0.094 + absf(float(offsets[finger])) * 0.25)
		hand.add_child(root_joint)
		var proximal: float = length * 0.56
		_capsule(root_joint, 0.0098, proximal + 0.012, _materials["skin"]).position = Vector3(0, 0, -proximal * 0.5)
		var tip_joint: Node3D = Node3D.new()
		tip_joint.position = Vector3(0, 0, -proximal)
		root_joint.add_child(tip_joint)
		var distal: float = length * 0.44
		_capsule(tip_joint, 0.0088, distal + 0.01, _materials["skin"]).position = Vector3(0, 0, -distal * 0.5)
		fingers.append(root_joint)
		fingers.append(tip_joint)
	var thumb: Node3D = Node3D.new()
	thumb.position = Vector3(-side * 0.036, -0.008, -0.03)
	thumb.rotation_degrees = Vector3(0, side * 42.0, side * 25.0)
	hand.add_child(thumb)
	_capsule(thumb, 0.0115, 0.042, _materials["skin"]).position = Vector3(0, 0, -0.018)
	var thumb_tip: Node3D = Node3D.new()
	thumb_tip.position = Vector3(0, 0, -0.036)
	thumb_tip.rotation_degrees = Vector3(0, side * -18.0, 0)
	thumb.add_child(thumb_tip)
	_capsule(thumb_tip, 0.0102, 0.034, _materials["skin"]).position = Vector3(0, 0, -0.015)
	return {
		"side": side, "upper": upper, "fore": fore, "hand": hand, "fingers": fingers,
		"wrist": Vector3(side * 0.24, -0.5, -0.3), "wrist_velocity": Vector3.ZERO,
		"facing": Basis.IDENTITY, "curl": 0.3,
	}


func _process(delta: float) -> void:
	if _player == null or _camera == null:
		return
	var main_camera: Camera3D = _player.call("get_camera")
	_camera.fov = main_camera.fov
	_land_kick = move_toward(_land_kick, 0.0, delta * 3.2)
	_jump_kick = move_toward(_jump_kick, 0.0, delta * 1.6)
	var move: int = int(_player.get("move"))
	var on_ground: bool = bool(_player.get("grounded"))
	var up: Vector3 = _player.up_direction
	var vertical: float = _player.velocity.dot(up)
	var speed: float = float(_player.call("get_speed"))
	var run: float = clampf(speed / 9.6, 0.0, 1.0)
	var stride_phase: float = float(_player.call("get_stride")) / 2.2 * PI
	var camera_basis: Basis = main_camera.global_basis
	for arm: Dictionary in _arms:
		var side: float = arm["side"]
		var target: Vector3
		var facing: Basis
		var curl: float = 0.35
		var stiffness: float = 140.0
		match move:
			3: # climb or vault: palms planted on the ledge
				var hand_world: Vector3 = _player.call("get_climb_hand_point")
				var local: Vector3 = camera_basis.inverse() * (hand_world - main_camera.global_position)
				var progress: float = float(_player.call("get_climb_progress"))
				target = Vector3(side * 0.2, clampf(local.y, -0.34, -0.1), clampf(local.z, -0.55, -0.3))
				target.y -= progress * 0.25
				target.z += progress * 0.25
				facing = _hand_basis(side, deg_to_rad(-80.0), deg_to_rad(side * -10.0))
				curl = 0.1
				stiffness = 320.0
			2: # wall-run: the wall-side hand reaches out and brushes the wall
				var wall_side: float = float(_player.call("get_wall_side"))
				if signf(wall_side) == signf(side):
					target = Vector3(side * 0.44, -0.04 + sin(stride_phase) * 0.02, -0.3)
					facing = _hand_basis(side, deg_to_rad(-10.0), deg_to_rad(side * -80.0))
					curl = 0.05
				else:
					target = Vector3(side * 0.2, -0.32 + sin(stride_phase * 2.0) * 0.05, -0.36)
					facing = _hand_basis(side, deg_to_rad(30.0), 0.0)
			4: # slide: one hand forward for balance, the other trails low
				if side > 0.0:
					target = Vector3(0.22, -0.2, -0.42)
					facing = _hand_basis(side, deg_to_rad(-20.0), deg_to_rad(-25.0))
				else:
					target = Vector3(-0.34, -0.42, -0.1)
					facing = _hand_basis(side, deg_to_rad(-60.0), 0.0)
			_:
				if on_ground:
					# pumping arms, mostly below the frame; they crest the bottom edge at speed
					var swing: float = sin(stride_phase) * side
					target = Vector3(side * (0.25 - run * 0.03), -0.42 + run * 0.12 * maxf(swing, 0.0) - run * 0.03, -0.3 - swing * 0.1 * run)
					facing = _hand_basis(side, deg_to_rad(40.0 + swing * 20.0), deg_to_rad(side * 10.0))
					curl = 0.75
					target.y -= _land_kick * 0.12
				else:
					# airborne: hands come up into view and spread, then lower for the landing
					var rising: float = clampf(vertical / 6.0, -1.0, 1.0)
					var reach: float = clampf(0.55 + rising * 0.45 + _jump_kick * 0.3, 0.0, 1.0)
					target = Vector3(side * lerpf(0.3, 0.2, reach), lerpf(-0.28, -0.08, reach), lerpf(-0.36, -0.42, reach))
					facing = _hand_basis(side, deg_to_rad(lerpf(-10.0, 72.0, reach)), deg_to_rad(side * lerpf(-30.0, -14.0, reach)))
					curl = lerpf(0.3, 0.08, reach)
					stiffness = 170.0
		_drive_arm(arm, target, facing, curl, stiffness, delta)


## Pitch tips the fingers up (+) or down (-); spread turns them outward.
func _hand_basis(side: float, pitch: float, spread: float) -> Basis:
	# the slight inward roll keeps the backs of the hands angled toward the eye
	return Basis(Vector3.UP, spread) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, side * deg_to_rad(-18.0))


func _drive_arm(arm: Dictionary, target: Vector3, facing: Basis, curl: float, stiffness: float, delta: float) -> void:
	var wrist: Vector3 = arm["wrist"]
	var velocity: Vector3 = arm["wrist_velocity"]
	var damping: float = 2.0 * sqrt(stiffness) * 0.85
	velocity += ((target - wrist) * stiffness - velocity * damping) * delta
	wrist += velocity * delta
	arm["wrist"] = wrist
	arm["wrist_velocity"] = velocity
	var current: Basis = arm["facing"]
	current = Basis(current.get_rotation_quaternion().slerp(facing.get_rotation_quaternion(), 1.0 - exp(-16.0 * delta)))
	arm["facing"] = current
	arm["curl"] = lerpf(float(arm["curl"]), curl, 1.0 - exp(-12.0 * delta))
	var side: float = arm["side"]
	var hand: Node3D = arm["hand"]
	hand.transform = Transform3D(current, wrist)
	var joints: Array[Node3D] = arm["fingers"]
	for index: int in range(joints.size()):
		# fingers fan out slightly when open and close into a loose fist when curled
		var finger: int = index / 2
		var open: float = 1.0 - float(arm["curl"])
		var fan: float = (float(finger) - 1.5) * 0.09 * open * -side if index % 2 == 0 else 0.0
		joints[index].rotation = Vector3(-float(arm["curl"]) * (1.25 if index % 2 == 0 else 1.05), fan, 0)
	var shoulder: Vector3 = Vector3(side * 0.24, -0.42, 0.18)
	var elbow: Vector3 = shoulder.lerp(wrist, 0.5) + Vector3(side * 0.09, -0.13, 0.06)
	var wrist_back: Vector3 = wrist + current * Vector3(0, 0, 0.05)
	_aim(arm["fore"], elbow, wrist_back)
	_aim(arm["upper"], shoulder, elbow)


func _aim(segment: Node3D, from: Vector3, to: Vector3) -> void:
	var direction: Vector3 = to - from
	var length: float = direction.length()
	if length < 0.001:
		return
	var forward: Vector3 = direction / length
	var helper: Vector3 = Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var basis_now: Basis = Basis.looking_at(forward, helper)
	segment.transform = Transform3D(basis_now, (from + to) * 0.5)
	var mesh: MeshInstance3D = segment.get_node("Mesh")
	(mesh.mesh as CapsuleMesh).height = maxf(length + 0.04, 0.1)

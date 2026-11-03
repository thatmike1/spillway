extends Node
## First-person arms, drawn in their own small world on top of the scene so
## they never clip into walls. Poses are positions in camera space that the
## wrists spring toward: low pumping while running, both hands up and out on a
## jump, a push down on landing, palms planted on a vault, a hand on the wall.

const SKIN: Color = Color("#b98a6c")
const SLEEVE: Color = Color("#1b222c")
const CUFF: Color = Color("#5d6873")

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
	_capsule(fore, 0.04, 1.0, _materials["sleeve"]).name = "Mesh"
	var hand: Node3D = Node3D.new()
	_camera.add_child(hand)
	_box(hand, Vector3(0, 0.0, 0.035), Vector3(0.088, 0.088, 0.05), _materials["cuff"])
	_box(hand, Vector3(0, 0, -0.045), Vector3(0.082, 0.03, 0.095), _materials["glove"])
	for finger: int in range(4):
		var x: float = (float(finger) - 1.5) * 0.021
		var length: float = [0.072, 0.085, 0.08, 0.064][finger]
		var knuckle: Node3D = Node3D.new()
		knuckle.position = Vector3(x, 0.0, -0.092)
		knuckle.name = "Finger%d" % finger
		hand.add_child(knuckle)
		var segment: MeshInstance3D = _capsule(knuckle, 0.0095, length, _materials["skin"])
		segment.position = Vector3(0, 0, -length * 0.5 + 0.006)
	var thumb: Node3D = Node3D.new()
	thumb.position = Vector3(-side * 0.04, -0.008, -0.03)
	thumb.rotation_degrees = Vector3(0, side * 38.0, side * 20.0)
	thumb.name = "Thumb"
	hand.add_child(thumb)
	_capsule(thumb, 0.011, 0.06, _materials["skin"]).position = Vector3(0, 0, -0.03)
	return {
		"side": side, "upper": upper, "fore": fore, "hand": hand,
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
					target = Vector3(side * lerpf(0.3, 0.21, reach), lerpf(-0.27, -0.1, reach), lerpf(-0.36, -0.44, reach))
					facing = _hand_basis(side, deg_to_rad(lerpf(-20.0, 55.0, reach)), deg_to_rad(side * lerpf(-25.0, -12.0, reach)))
					curl = lerpf(0.25, 0.05, reach)
					stiffness = 170.0
		_drive_arm(arm, target, facing, curl, stiffness, delta)


## Pitch tips the fingers up (+) or down (-); spread turns them outward.
func _hand_basis(side: float, pitch: float, spread: float) -> Basis:
	return Basis(Vector3.UP, spread) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, side * deg_to_rad(-12.0))


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
	for finger: int in range(4):
		var knuckle: Node3D = hand.get_node("Finger%d" % finger)
		knuckle.rotation = Vector3(-float(arm["curl"]) * 1.4, 0, 0)
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

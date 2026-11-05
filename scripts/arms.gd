extends Node
## original foreground body. shares the scene world, lights and environment.
## port choice (P): fixed arm lengths and authored asynchronous poses, with world contact IK.
const BODY_LAYER: int = 1 << 19
const UPPER_LENGTH: float = .34
const FORE_LENGTH: float = .34

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
var _pelvis: MeshInstance3D
var _lower: Node3D
var _legs: Array[Dictionary] = []
var _materials: Dictionary = {}


func attach(player: CharacterBody3D) -> void:
	_player = player
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.near = 0.01
	_camera.cull_mask = BODY_LAYER
	(player.call("get_camera") as Camera3D).cull_mask &= ~BODY_LAYER
	_camera.far = 10.0
	_camera.current = true
	_viewport.add_child(_camera)
	_materials["skin"] = _material(SKIN, 0.7)
	_materials["sleeve"] = _material(SLEEVE, 0.9)
	_materials["cuff"] = _material(CUFF, 0.8)
	_materials["glove"] = _material(Color("#20262e"), 0.8)
	for side: float in [-1.0, 1.0]:
		_arms.append(_build_arm(side))
	_lower = Node3D.new()
	_camera.add_child(_lower)
	_pelvis = _capsule(_lower, .16, .30, _materials["sleeve"])
	_pelvis.position = Vector3(0, -.12, .04)
	
	for side: float in [-1.0, 1.0]:
		var thigh := Node3D.new()
		_lower.add_child(thigh)
		_capsule(thigh, .085, .45, _materials["sleeve"]).name = "Mesh"
		var shin := Node3D.new()
		_lower.add_child(shin)
		_capsule(shin, .065, .43, _materials["sleeve"]).name = "Mesh"
		var foot := Node3D.new()
		_lower.add_child(foot)
		_box(foot, Vector3(0, -.035, -.025), Vector3(.15, .035, .31), _materials["cuff"])
		_box(foot, Vector3(0, .018, -.035), Vector3(.135, .085, .27), _materials["glove"])
		_capsule(foot, .06, .13, _materials["glove"]).position = Vector3(0, .015, -.13)
		for lace: int in 3:
			_box(foot, Vector3(0, .064, -.04 - lace * .026), Vector3(.075, .008, .009), _materials["cuff"])
		_legs.append({"side": side, "thigh": thigh, "shin": shin, "foot": foot})
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
	instance.layers = BODY_LAYER
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	instance.layers = BODY_LAYER
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	parent.add_child(instance)
	return instance


## hand space: wrist at the origin, fingers along -Z, back of the hand along +Y,
## thumb toward the body's centre line.
func _build_arm(side: float) -> Dictionary:
	var upper: Node3D = Node3D.new()
	_camera.add_child(upper)
	_capsule(upper, 0.044, 1.0, _materials["sleeve"]).name = "Mesh"
	var fore: Node3D = Node3D.new()
	_camera.add_child(fore)
	_capsule(fore, 0.036, 1.0, _materials["sleeve"]).name = "Mesh"
	var hand: Node3D = Node3D.new()
	_camera.add_child(hand)
	var cuff: MeshInstance3D = MeshInstance3D.new()
	var band: CylinderMesh = CylinderMesh.new()
	band.top_radius = 0.036
	band.bottom_radius = 0.036
	band.height = 0.06
	band.radial_segments = 14
	cuff.layers = BODY_LAYER
	cuff.mesh = band
	cuff.material_override = _materials["cuff"]
	cuff.rotation_degrees = Vector3(90, 0, 0)
	cuff.position = Vector3(0, 0, 0.025)
	hand.add_child(cuff)
	var palm: MeshInstance3D = MeshInstance3D.new()
	var ellipsoid: SphereMesh = SphereMesh.new()
	ellipsoid.radius = 0.5
	ellipsoid.height = 1.0
	ellipsoid.radial_segments = 16
	ellipsoid.rings = 8
	palm.layers = BODY_LAYER
	palm.mesh = ellipsoid
	palm.material_override = _materials["glove"]
	palm.scale = Vector3(0.095, 0.044, 0.12)
	palm.position = Vector3(0, 0, -0.048)
	hand.add_child(palm)
	# knuckle ridge and thumb mound give the palm a shaped silhouette.
	_box(hand, Vector3(0, .018, -.073), Vector3(.070, .012, .026), _materials["cuff"])
	_box(hand, Vector3(-side * .027, -.007, -.038), Vector3(.034, .032, .045), _materials["glove"])
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
		_capsule(root_joint, 0.0098, proximal + 0.012, _materials["glove"]).position = Vector3(0, 0, -proximal * 0.5)
		_box(root_joint, Vector3(0, .009, -proximal * .55), Vector3(.014, .006, proximal * .6), _materials["cuff"])
		var tip_joint: Node3D = Node3D.new()
		tip_joint.position = Vector3(0, 0, -proximal)
		root_joint.add_child(tip_joint)
		var distal: float = length * 0.44
		_capsule(tip_joint, 0.0088, distal + 0.01, _materials["glove"]).position = Vector3(0, 0, -distal * 0.5)
		fingers.append(root_joint)
		fingers.append(tip_joint)
	var thumb: Node3D = Node3D.new()
	thumb.position = Vector3(-side * 0.036, -0.008, -0.03)
	thumb.rotation_degrees = Vector3(0, side * 42.0, side * 25.0)
	hand.add_child(thumb)
	_capsule(thumb, 0.0115, 0.042, _materials["glove"]).position = Vector3(0, 0, -0.018)
	var thumb_tip: Node3D = Node3D.new()
	thumb_tip.position = Vector3(0, 0, -0.036)
	thumb_tip.rotation_degrees = Vector3(0, side * -18.0, 0)
	thumb.add_child(thumb_tip)
	_capsule(thumb_tip, 0.0102, 0.034, _materials["glove"]).position = Vector3(0, 0, -0.015)
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
	_camera.global_transform = main_camera.global_transform
	_land_kick = move_toward(_land_kick, 0.0, delta * 3.2)
	_jump_kick = move_toward(_jump_kick, 0.0, delta * 1.6)
	var move: int = int(_player.get("move"))
	var on_ground: bool = bool(_player.get("grounded"))
	var up: Vector3 = _player.up_direction
	var vertical: float = _player.velocity.dot(up)
	var speed: float = float(_player.call("get_presentation_speed"))
	var run: float = clampf(speed / 7.2, 0.0, 1.0)
	var stride_phase: float = float(_player.call("get_stride")) / _player.tuning.gait_stride * TAU
	var camera_basis: Basis = main_camera.global_basis
	var body_basis: Basis = _player.call("get_body_basis")
	_lower.transform = Transform3D(camera_basis.inverse() * body_basis, camera_basis.inverse() * (_player.global_position - main_camera.global_position))
	# port choice (P): impact/roll coils the legs below the eye, including release recovery.
	_lower.visible = move not in [9, 13] and _player._body_recovery <= 0
	_pelvis.visible = move not in [5, 9, 13]
	if move == 5:
		_lower.position += camera_basis.inverse() * up * -1.2
	if move in [4, 9]:
		_lower.position += camera_basis.inverse() * up * -.32
	for leg: Dictionary in _legs:
		var side: float = leg.side
		var phase: float = sin(stride_phase) * side * run if on_ground else .4 * side
		var hip: Vector3 = Vector3(side * .105, -.22, 0)
		var knee: Vector3 = Vector3(side * .12, -.5 + absf(phase) * .10, -.04 - phase * .19)
		var ankle: Vector3 = Vector3(side * .12, -.83 + maxf(phase, 0) * .15, phase * .28)
		if move == 5:
			var progress: float = _player.call("get_climb_progress")
			var lead: float = sin(clampf(progress * 1.35 + (.22 if side > 0 else -.20), 0, 1) * PI)
			knee = Vector3(side * .17, -.40 + lead * .22, -.18 - lead * .32)
			ankle = Vector3(side * .20, -.67 + lead * .26, -.10 - lead * .62)
		if move == 4:
			knee = Vector3(side * .13, -.45, -.42)
			ankle = Vector3(side * .14, -.5, -.78)
		_aim(leg.thigh, hip, knee)
		_aim(leg.shin, knee, ankle)
		(leg.foot as Node3D).position = ankle + Vector3(0, -.02, -.07)
	for arm: Dictionary in _arms:
		var side: float = arm["side"]
		var target: Vector3
		var facing: Basis
		var curl: float = 0.35
		var stiffness: float = 140.0
		match move:
			3, 5, 6, 7, 8: # climb or vault: palms planted on the ledge
				var progress: float = float(_player.call("get_climb_progress"))
				target = Vector3(side * .32, -.20 - progress * .07, -.52)
				facing = _hand_basis(side, deg_to_rad(-10.0), deg_to_rad(side * -10.0))
				curl = 0.1
				stiffness = 320.0
			2: # wall-run: the wall-side hand reaches out and brushes the wall
				var wall_side: float = float(_player.call("get_wall_side"))
				if signf(wall_side) == signf(side):
					target = Vector3(side * 0.44, -0.04 + sin(stride_phase) * 0.02, -0.3)
					facing = _hand_basis(side, deg_to_rad(-10.0), deg_to_rad(side * -80.0))
					curl = 0.05
				else:
					target = Vector3(side * 0.2, -0.12 + sin(stride_phase * 2.0) * 0.04, -0.48)
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
					target = Vector3(side * (.30 - run * .02), -.35 + run * .10 * maxf(swing, 0.0) - run * .02, -.40 - swing * .10 * run)
					facing = _hand_basis(side, deg_to_rad(40.0 + swing * 20.0), deg_to_rad(side * 10.0))
					curl = 0.75
					target.y = lerpf(target.y, -.10, _land_kick)
					target.z = lerpf(target.z, -.48, _land_kick)
				else:
					# port choice (P): reference 15, low outer hands, backs visible, fingers forward.
					# different phase per hand separates takeoff, flight and recovery.
					var rising: float = clampf(vertical / 6.3, -1, 1)
					var reach: float = clampf(.55 + rising * .25 + _jump_kick * (.30 if side < 0 else .1), 0, 1)
					target = Vector3(side * (.36 + .05 * reach), -.23 + .06 * reach + side * .025, -.58 - .03 * reach)
					facing = _hand_basis(side, deg_to_rad(22 + reach * 10 + side * 4), deg_to_rad(side * -16))
					curl = .08 + (1 - reach) * .18
					stiffness = 170.0
		var weight: float = float(_player.call("get_hand_weight", side))
		if weight > 0:
			var contact: Vector3 = _player.call("get_hand_target", side)
			var local: Vector3 = camera_basis.inverse() * (contact - main_camera.global_position)
			target = target.lerp(local, weight)
			# palm -Y rests against the wall normal; fingers point along travel.
			var normal: Vector3 = _player.get("_wall_normal") if move in [2, 8] else _player.up_direction
			var back: Vector3 = camera_basis.inverse() * normal
			var forward: Vector3 = camera_basis.inverse() * (-body_basis.z).slide(normal).normalized()
			if forward.length_squared() < .01:
				forward = camera_basis.inverse() * _player.up_direction
			var z_axis: Vector3 = -forward
			var x_axis: Vector3 = back.cross(z_axis).normalized()
			var contact_basis := Basis(x_axis, z_axis.cross(x_axis).normalized(), z_axis)
			facing = Basis(facing.get_rotation_quaternion().slerp(contact_basis.get_rotation_quaternion(), weight))
			stiffness = 450
		_drive_arm(arm, target, facing, curl, stiffness, delta)


## pitch tips the fingers up (+) or down (-); spread turns them outward.
func _hand_basis(side: float, pitch: float, spread: float) -> Basis:
	# the slight inward roll keeps the backs of the hands angled toward the eye
	return Basis(Vector3.UP, spread) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, side * deg_to_rad(-18.0))


func _drive_arm(arm: Dictionary, target: Vector3, facing: Basis, curl: float, stiffness: float, delta: float) -> void:
	var wrist: Vector3 = arm["wrist"]
	var velocity: Vector3 = arm["wrist_velocity"]
	var damping: float = 2.0 * sqrt(stiffness) * 0.85
	# explicit springs this stiff blow up at long frames (a hitch, a 15 fps recording),
	# so integrate in steps of at most 1/120 s
	var steps: int = maxi(1, ceili(delta * 120.0))
	var h: float = delta / steps
	for _step: int in range(steps):
		velocity += ((target - wrist) * stiffness - velocity * damping) * h
		wrist += velocity * h
	# contact targets are fixed world points, not a spring that slips over the rail.
	if stiffness >= 450:
		wrist = target
		velocity = Vector3.ZERO
	arm["wrist"] = wrist
	arm["wrist_velocity"] = velocity
	var current: Basis = arm["facing"]
	current = Basis(current.get_rotation_quaternion().slerp(facing.get_rotation_quaternion(), 1.0 - exp(-16.0 * delta)))
	if stiffness >= 450:
		current = facing
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
	var shoulder: Vector3 = Vector3(side * .24, -.36, .04)
	var wrist_back: Vector3 = wrist + current * Vector3(0, 0, .035)
	var axis: Vector3 = wrist_back - shoulder
	var distance: float = clampf(axis.length(), .04, UPPER_LENGTH + FORE_LENGTH - .005)
	axis = axis.normalized()
	wrist_back = shoulder + axis * distance
	wrist = wrist_back - current * Vector3(0, 0, .035)
	hand.position = wrist
	arm["wrist"] = wrist
	# analytic two-bone solve, with a stable outward/down pole.
	var pole: Vector3 = Vector3(side * .7, -.8, .3)
	var bend: Vector3 = pole.slide(axis).normalized()
	var along: float = (UPPER_LENGTH * UPPER_LENGTH - FORE_LENGTH * FORE_LENGTH + distance * distance) / (2 * distance)
	var elbow: Vector3 = shoulder + axis * along + bend * sqrt(maxf(0, UPPER_LENGTH * UPPER_LENGTH - along * along))
	_aim(arm["fore"], elbow, wrist_back)
	_aim(arm["upper"], shoulder, elbow)
	arm["elbow"] = elbow
	arm["shoulder"] = shoulder
	arm["end"] = wrist_back



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

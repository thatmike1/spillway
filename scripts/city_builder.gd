extends Node3D
## Fixed, authored route assembled from original modular geometry.

const FOLD_SCRIPT: String = "res://scripts/folding_sector.gd"
const GRAVITY_SCRIPT: String = "res://scripts/gravity_zone.gd"
const PORTAL_SCRIPT: String = "res://scripts/portal_seam.gd"
const ACCENT: Color = Color(1.0, 0.61, 0.28)
var _result: Dictionary = {}
var _materials: Dictionary = {}
var _distant_folds: Array[Node3D] = []

func build() -> Dictionary:
	if not _result.is_empty():
		return _result
	_materials["stone"] = _material(Color(0.13, 0.17, 0.22))
	_materials["roof"] = _material(Color(0.24, 0.29, 0.34))
	_materials["dark"] = _material(Color(0.06, 0.085, 0.12))
	_materials["path"] = _material(ACCENT, true)
	_materials["window"] = _material(Color(0.34, 0.48, 0.61), true)
	_materials["finish"] = _material(Color(0.48, 0.95, 0.78), true)
	_lighting()
	_roof("DepartureRoof", Vector3(0, -0.5, -4), Vector3(12, 1, 20))
	_mark_path(self, Vector3(0, 0.025, -4), 15.0)
	_box(self, Vector3(-4, 0.4, 0), Vector3(2, 0.8, 2), "dark", true, "VaultCrate")
	_box(self, Vector3(4, 1.2, -5), Vector3(1.0, 2.4, 6), "stone", true, "WallRunPractice")

	var fold: AnimatableBody3D = load(FOLD_SCRIPT).new() as AnimatableBody3D
	fold.name = "FoldingBridge"
	fold.position = Vector3(0, 0, -14)
	fold.rotation.x = -PI / 2.0
	fold.set("rotation_axis", Vector3.RIGHT)
	fold.set("fold_angle", PI / 2.0)
	fold.set("duration", 1.8)
	add_child(fold)
	_box(fold, Vector3(0, -0.25, -6), Vector3(8, 0.5, 12), "roof", false, "BridgeDeck")
	_shape(fold, Vector3(0, -0.25, -6), Vector3(8, 0.5, 12))
	_mark_path(fold, Vector3(0, 0.025, -6), 10.5)
	_box(fold, Vector3(-3.8, 0.12, -6), Vector3(0.12, 0.24, 12), "path")
	_box(fold, Vector3(3.8, 0.12, -6), Vector3(0.12, 0.24, 12), "path")

	_roof("ArrivalRoof", Vector3(0, -0.5, -35.5), Vector3(10, 1, 15))
	_mark_path(self, Vector3(0, 0.025, -35.5), 13.0)
	var gravity_zones: Array[Area3D] = []
	# A half-circle route turns the running surface from floor through wall to ceiling.
	var radius: float = 6.0
	var segments: int = 12
	for index: int in range(segments):
		var angle: float = (float(index) + 0.5) * PI / float(segments)
		var normal: Vector3 = Vector3(0, cos(angle), sin(angle))
		var tangent: Vector3 = Vector3(0, sin(angle), -cos(angle))
		var basis: Basis = Basis(Vector3.RIGHT, normal, -tangent)
		var surface_center: Vector3 = Vector3(0, radius * (1.0 - cos(angle)), -43.0 - radius * sin(angle))
		var section: StaticBody3D = StaticBody3D.new()
		section.name = "GravityArc%02d" % index
		section.transform = Transform3D(basis, surface_center)
		section.set_meta("traversal_up", true)
		add_child(section)
		var length: float = 2.0 * radius * tan(PI / (2.0 * float(segments))) + 0.08
		_box(section, Vector3(0, -0.18, 0), Vector3(8, 0.36, length), "roof")
		_shape(section, Vector3(0, -0.18, 0), Vector3(8, 0.36, length))
		_mark_path(section, Vector3(0, 0.025, 0), length * 0.85)
		var zone: Area3D = _gravity_zone(section, Vector3(0, 2, 0), Vector3(9, 4.5, length + 0.35), 10 + index)
		gravity_zones.append(zone)

	var ceiling: StaticBody3D = StaticBody3D.new()
	ceiling.name = "InvertedRoof"
	ceiling.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD), Vector3(0, 12, -36.5))
	ceiling.set_meta("traversal_up", true)
	add_child(ceiling)
	_box(ceiling, Vector3(0, -0.3, 0), Vector3(8, 0.6, 13), "roof")
	_shape(ceiling, Vector3(0, -0.3, 0), Vector3(8, 0.6, 13))
	_mark_path(ceiling, Vector3(0, 0.025, 0), 11.5)
	gravity_zones.append(_gravity_zone(ceiling, Vector3(0, 2, 0), Vector3(9, 5, 14), 30))

	var entry: Node3D = load(PORTAL_SCRIPT).new() as Node3D
	entry.name = "ImpossibleWindowEntry"
	entry.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD), Vector3(0, 10.8, -31))
	entry.set("width", 4.0)
	entry.set("height", 4.0)
	add_child(entry)
	_portal_frame(entry)
	var exit: Node3D = load(PORTAL_SCRIPT).new() as Node3D
	exit.name = "ImpossibleWindowExit"
	exit.position = Vector3(80, 1.2, -10)
	exit.set("width", 4.0)
	exit.set("height", 4.0)
	add_child(exit)
	_portal_frame(exit)
	entry.set("exit_seam", exit)
	exit.set("exit_seam", entry)
	_roof("FinalRoof", Vector3(80, -0.5, 1), Vector3(12, 1, 28))
	_mark_path(self, Vector3(80, 0.025, 2), 21.0)
	_box(self, Vector3(80, 0.035, 10), Vector3(7, 0.07, 2), "finish", false, "FinishMark")
	_sign("RETURN TO THE SKY", Vector3(80, 2.5, 12), PI)
	_sign("FOLLOW THE LIGHT", Vector3(0, 2.1, -12), 0)
	_skyline()
	var fold_trigger: Area3D = _trigger("FoldTrigger", Vector3(0, 1.5, -1), Vector3(12, 5, 5))
	var checkpoint_trigger: Area3D = _trigger("CheckpointTrigger", Vector3(0, 1.5, -32), Vector3(10, 5, 5))
	var finish_trigger: Area3D = _trigger("FinishTrigger", Vector3(80, 1.5, 10), Vector3(10, 5, 3))
	_result = {
		"spawn": Transform3D(Basis.IDENTITY, Vector3(0, 1, 3)),
		"checkpoint": Transform3D(Basis.IDENTITY, Vector3(0, 1, -32)),
		"finish": Transform3D(Basis.IDENTITY, Vector3(80, 1, 10)),
		"fold": fold, "entry_seam": entry, "exit_seam": exit,
		"fold_trigger": fold_trigger, "checkpoint_trigger": checkpoint_trigger,
		"finish_trigger": finish_trigger, "gravity_zones": gravity_zones,
		"jump_gaps": PackedFloat32Array([2.0]),
		"route_bounds": AABB(Vector3(-6, -2, -51), Vector3(92, 17, 66)),
	}
	return _result

func _process(delta: float) -> void:
	for index: int in range(_distant_folds.size()):
		var cluster: Node3D = _distant_folds[index]
		cluster.rotate_z(delta * (0.012 if index % 2 == 0 else -0.008))

func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.2
	return material

func _box(parent: Node3D, center: Vector3, size: Vector3, material_key: String, solid: bool = false, node_name: String = "") -> Node3D:
	var holder: Node3D = parent
	if solid:
		var body: StaticBody3D = StaticBody3D.new()
		body.position = center
		body.set_meta("traversal_up", true)
		parent.add_child(body)
		holder = body
		_shape(body, Vector3.ZERO, size)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _materials[material_key] as StandardMaterial3D
	mesh.position = Vector3.ZERO if solid else center
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if solid else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mesh)
	if not node_name.is_empty():
		if solid:
			holder.name = node_name
		else:
			mesh.name = node_name
	return holder if solid else mesh

func _shape(parent: CollisionObject3D, center: Vector3, size: Vector3) -> void:
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = center
	parent.add_child(collider)

func _roof(node_name: String, center: Vector3, size: Vector3) -> void:
	_box(self, center, size, "roof", true, node_name)
	_box(self, center - Vector3(0, 14, 0), Vector3(size.x, 27, size.z), "stone")
	for side: float in [-1.0, 1.0]:
		_box(self, center + Vector3(side * (size.x / 2.0 - 0.1), 0.85, 0), Vector3(0.15, 0.7, size.z), "dark", true)

func _mark_path(parent: Node3D, center: Vector3, length: float) -> void:
	for side: float in [-1.0, 1.0]:
		_box(parent, center + Vector3(side * 1.3, 0, 0), Vector3(0.045, 0.035, length), "path")

func _gravity_zone(parent: Node3D, center: Vector3, size: Vector3, priority: int) -> Area3D:
	var zone: Area3D = load(GRAVITY_SCRIPT).new() as Area3D
	zone.name = "GravityVolume"
	zone.position = center
	zone.set("local_up", Vector3.UP)
	zone.set("priority", priority)
	zone.collision_layer = 0
	zone.collision_mask = 2
	_shape(zone, Vector3.ZERO, size)
	parent.add_child(zone)
	return zone

func _trigger(node_name: String, center: Vector3, size: Vector3) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = node_name
	area.position = center
	area.collision_layer = 0
	area.collision_mask = 2
	_shape(area, Vector3.ZERO, size)
	add_child(area)
	return area

func _portal_frame(seam: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		_box(seam, Vector3(side * 2.25, 0, 0), Vector3(0.5, 5, 0.6), "dark", true)
		_box(seam, Vector3(side * 2.0, 0, 0.36), Vector3(0.055, 4, 0.055), "path")
		_box(seam, Vector3(0, side * 2.25, 0), Vector3(5, 0.5, 0.6), "dark", true)
		_box(seam, Vector3(0, side * 2.0, 0.36), Vector3(4, 0.055, 0.055), "path")
	# An opaque aperture hides the unmatched view; this is a spatial seam, not a rendered portal.
	_box(seam, Vector3.ZERO, Vector3(4, 4, 0.015), "dark", false, "OpaqueAperture")

func _sign(text: String, center: Vector3, yaw: float) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.008
	label.modulate = ACCENT
	label.position = center
	label.rotation.y = yaw
	label.no_depth_test = false
	add_child(label)

func _lighting() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.075, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.47, 0.6, 0.8)
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -35, 0)
	sun.light_color = Color(0.8, 0.87, 1.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

func _skyline() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 24601
	var window_transforms: Array[Transform3D] = []
	for index: int in range(72):
		var angle: float = float(index) / 72.0 * TAU
		var distance: float = rng.randf_range(70, 150)
		var height: float = rng.randf_range(35, 90)
		var center: Vector3 = Vector3(cos(angle) * distance, height / 2.0 - 35, sin(angle) * distance - 20)
		var size: Vector3 = Vector3(rng.randf_range(9, 18), height, rng.randf_range(9, 18))
		if Vector2(center.x - 80.0, center.z - 1.0).length() < 28.0:
			continue
		_box(self, center, size, "stone")
		for row: int in range(7):
			var window_center: Vector3 = center + Vector3(0, float(row) * height / 8.0 - height * 0.35, size.z / 2.0 + 0.03)
			window_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size.x * 0.75, 0.35, 0.06)), window_center))
	var windows: MultiMeshInstance3D = MultiMeshInstance3D.new()
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	multi.mesh = mesh
	multi.instance_count = window_transforms.size()
	for index: int in range(window_transforms.size()):
		multi.set_instance_transform(index, window_transforms[index])
	windows.multimesh = multi
	windows.material_override = _materials["window"] as StandardMaterial3D
	windows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(windows)
	for cluster_index: int in range(4):
		var cluster: Node3D = Node3D.new()
		cluster.name = "DistantFold%d" % cluster_index
		cluster.position = Vector3(-65.0 + float(cluster_index) * 42.0, 90, -105)
		cluster.rotation.z = float(cluster_index) * 0.35 - 0.6
		add_child(cluster)
		_distant_folds.append(cluster)
		for arm: int in range(5):
			var branch: Node3D = Node3D.new()
			branch.rotation.z = float(arm) * TAU / 5.0
			cluster.add_child(branch)
			_box(branch, Vector3(0, 24, 0), Vector3(9, 38, 12), "dark")
			_box(branch, Vector3(0, 24, 6.1), Vector3(0.2, 32, 0.1), "window")

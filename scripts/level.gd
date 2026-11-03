extends Node3D
## The authored slice. Run direction is -Z. All geometry is original and built
## from primitive meshes at load time.
##
##  S   start roof, y 0, z 8..-48        a normal roof to look around and learn on
##  TA  drawbridge tower, hinge z -51    tips away; its facade becomes the road
##  R2  roof, y -3, z -103..-140         drop, vaults, a choice of lanes
##  R3  roof, y -3, z -144..-165         bends up into TB's facade
##  TB  tower, facade z -171, roof y 25  run up the wall, over the crest, finish

const FOLD_SCRIPT: Script = preload("res://scripts/fold_block.gd")
const FACADE_SHADER: Shader = preload("res://shaders/facade.gdshader")

const AMBER: Color = Color("#F3AE52")
const CYAN: Color = Color("#6CBFCB")
const SILHOUETTE: Color = Color("#0C1118")
const CHARCOAL: Color = Color("#151B24")
const BLUE_ARCH: Color = Color("#24364B")
const CONCRETE: Color = Color("#758391")
const SKY: Color = Color("#A6BBC9")

const STREET_Y: float = -30.0
const TA_HINGE: Vector3 = Vector3(0, 0, -51)
const TA_HEIGHT: float = 48.0
const TA_DEPTH: float = 14.0
const TA_WIDTH: float = 16.0
const CURL_CENTER: Vector3 = Vector3(0, 3, -165)
const CURL_RADIUS: float = 6.0
const CREST_CENTER: Vector3 = Vector3(0, 21, -175)
const CREST_RADIUS: float = 4.0

var fold: AnimatableBody3D
var folds: Array[AnimatableBody3D] = []
var fold_triggers: Array[Dictionary] = []
var cues: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var fold_trigger: Area3D
var finish_trigger: Area3D
var spawn: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 2))
var finish_point: Vector3 = Vector3(0, 25, -190)
var bot_path: Array[Dictionary] = []
var landmarks: Dictionary = {}

var _facades: Array[ShaderMaterial] = []
var _ta_material: ShaderMaterial
var _waves: Array[Dictionary] = []
var _materials: Dictionary = {}
var _spinners: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _built: bool = false


func build() -> void:
	if _built:
		return
	_built = true
	_rng.seed = 731
	_make_materials()
	_environment()
	_street()
	_start_roof()
	_drawbridge_tower()
	_roof_two()
	_roof_three_and_bend()
	_tower_b()
	_city()
	_spectacle()
	_route_for_bot()


func _process(delta: float) -> void:
	for spinner: Dictionary in _spinners:
		var node: Node3D = spinner["node"]
		node.rotate_object_local(spinner["axis"], float(spinner["speed"]) * delta)
	for wave: Dictionary in _waves:
		var block: Node = wave["fold"]
		var material: ShaderMaterial = wave["material"]
		var height: float = wave["height"]
		var warning: float = float(block.call("get_warning"))
		# floors light up bottom to top during the anticipation beat, stay lit while
		# the block turns, then go dark again from the hinge outward once it lands
		var top: float = -height * 0.5 - 2.0 + warning * (height + 4.0) if warning > 0.0 else -10000.0
		wave["settled"] = float(wave["settled"]) + delta if bool(block.call("is_done")) else 0.0
		var settled: float = wave["settled"]
		var bottom: float = -height * 0.5 - 2.0 + clampf(settled / 1.6, 0.0, 1.0) * (height + 4.0)
		material.set_shader_parameter("wave_height", top)
		material.set_shader_parameter("wave_floor", bottom if settled > 0.0 else -10000.0)


## Closest cue index the player has not yet passed is decided by main; this
## only reports where each cue sits right now (cues on the fold move with it).
func cue_position(index: int) -> Vector3:
	var cue: Dictionary = cues[index]
	var anchor: Node3D = cue["anchor"]
	return anchor.global_transform * Vector3(cue["local"])


func set_cue_level(index: int, level: float) -> void:
	var material: StandardMaterial3D = cues[index]["material"]
	material.emission_energy_multiplier = level
	material.albedo_color = AMBER.lerp(Color(0.22, 0.2, 0.18), clampf(1.0 - level / 1.2, 0.0, 0.85))


func reset_state() -> void:
	for block: AnimatableBody3D in folds:
		block.call("reset_fold")


# ---------------------------------------------------------------- materials

func _make_materials() -> void:
	var palettes: Array = [
		[Color("#22344a"), Color("#56636f"), 0.0], [Color("#1b2939"), Color("#47525e"), 3.0],
		[Color("#283a4e"), Color("#5e6c79"), 5.0], [Color("#182230"), Color("#3a4450"), 8.0],
		[Color("#2c3b4b"), Color("#6a7783"), 11.0], [Color("#1e2c3e"), Color("#4f5c69"), 13.0],
	]
	for entry: Array in palettes:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = FACADE_SHADER
		material.set_shader_parameter("wall_color", entry[0])
		material.set_shader_parameter("slab_color", entry[1])
		material.set_shader_parameter("roof_color", Color(entry[0]).lerp(CONCRETE, 0.22))
		material.set_shader_parameter("seed", entry[2])
		material.set_shader_parameter("lit_ratio", 0.14 + _rng.randf() * 0.12)
		material.set_shader_parameter("lit_energy", 2.2)
		material.set_shader_parameter("lit_color", Color("#ffd9a8"))
		_facades.append(material)
	_materials["concrete"] = _standard(CONCRETE, 0.9)
	_materials["concrete_dark"] = _standard(Color("#4a5662"), 0.92)
	_materials["metal"] = _standard(Color("#2a3440"), 0.55, 0.4)
	_materials["dark"] = _standard(CHARCOAL, 0.9)
	_materials["asphalt"] = _standard(Color("#141a22"), 0.95)
	_materials["lane"] = _emissive(Color("#c9d3dc"), 0.25)
	_materials["street_light"] = _emissive(Color("#cfe6ff"), 2.6)
	_materials["warm_light"] = _emissive(Color("#ffd6a0"), 2.2)
	_materials["cyan"] = _emissive(CYAN, 2.4)
	_materials["red_light"] = _emissive(Color("#ff4a3a"), 3.0)
	var beam: StandardMaterial3D = StandardMaterial3D.new()
	beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.albedo_color = Color(0.55, 0.85, 0.95, 0.55)
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["beam"] = beam


func _standard(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _facade(index: int = -1) -> ShaderMaterial:
	if index < 0:
		index = _rng.randi() % _facades.size()
	return _facades[index % _facades.size()]


# ---------------------------------------------------------------- primitives

func _mesh(parent: Node3D, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = material
	instance.position = center
	parent.add_child(instance)
	return instance


func _shape(parent: CollisionObject3D, center: Vector3, size: Vector3) -> CollisionShape3D:
	var collider: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collider.shape = box
	collider.position = center
	parent.add_child(collider)
	return collider


func _solid(parent: Node3D, center: Vector3, size: Vector3, material: Material, node_name: String = "") -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	if not node_name.is_empty():
		body.name = node_name
	body.position = center
	parent.add_child(body)
	_mesh(body, Vector3.ZERO, size, material)
	_shape(body, Vector3.ZERO, size)
	return body


func _cylinder(parent: Node3D, center: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	parent.add_child(instance)
	return instance


## A building from street level to roof_y with a facade material, solid if near the route.
func _building(center_xz: Vector2, footprint: Vector2, roof_y: float, solid: bool, material: Material = null, parapet: bool = true) -> Node3D:
	if material == null:
		material = _facade()
	var height: float = roof_y - STREET_Y
	var center: Vector3 = Vector3(center_xz.x, STREET_Y + height * 0.5, center_xz.y)
	var size: Vector3 = Vector3(footprint.x, height, footprint.y)
	var node: Node3D
	if solid:
		node = _solid(self, center, size, material)
	else:
		node = _mesh(self, center, size, material)
	if parapet:
		_parapet(Vector3(center_xz.x, roof_y, center_xz.y), footprint, solid, [true, true, true, true])
	return node


## Low walls with a lit concrete cap on the chosen sides: [+x, -x, +z, -z].
func _parapet(top_center: Vector3, footprint: Vector2, solid: bool, sides: Array) -> void:
	var height: float = 0.75
	var thick: float = 0.3
	var specs: Array = [
		[Vector3(footprint.x * 0.5 - thick * 0.5, 0, 0), Vector3(thick, height, footprint.y)],
		[Vector3(-footprint.x * 0.5 + thick * 0.5, 0, 0), Vector3(thick, height, footprint.y)],
		[Vector3(0, 0, footprint.y * 0.5 - thick * 0.5), Vector3(footprint.x, height, thick)],
		[Vector3(0, 0, -footprint.y * 0.5 + thick * 0.5), Vector3(footprint.x, height, thick)],
	]
	for index: int in range(4):
		if not bool(sides[index]):
			continue
		var offset: Vector3 = specs[index][0]
		var size: Vector3 = specs[index][1]
		var center: Vector3 = top_center + offset + Vector3(0, height * 0.5, 0)
		if solid:
			_solid(self, center, size, _materials["concrete_dark"])
			_mesh(self, center + Vector3(0, height * 0.5 + 0.05, 0), Vector3(size.x + 0.1, 0.1, size.z + 0.1), _materials["concrete"])
		else:
			_mesh(self, center, size, _materials["concrete"])


## Registers an amber route cue. Meshes added with cue_strip() share its material.
func _cue(anchor: Node3D, local: Vector3, radius: float) -> int:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = AMBER
	material.emission_enabled = true
	material.emission = AMBER
	material.emission_energy_multiplier = 1.0
	material.roughness = 0.5
	cues.append({"anchor": anchor, "local": local, "radius": radius, "material": material})
	return cues.size() - 1


func _cue_strip(index: int, parent: Node3D, center: Vector3, size: Vector3) -> MeshInstance3D:
	return _mesh(parent, center, size, cues[index]["material"])


## A chevron of two bars in the parent's local XY plane, pointing along +Y.
func _chevron(index: int, parent: Node3D, center: Vector3, width: float, normal_offset: float) -> void:
	for side: float in [-1.0, 1.0]:
		var bar: MeshInstance3D = _cue_strip(index, parent, center + Vector3(side * width * 0.25, 0, normal_offset), Vector3(width * 0.62, 0.22, 0.06))
		bar.rotation.z = side * deg_to_rad(-32.0)


func _trigger(node_name: String, center: Vector3, size: Vector3) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = node_name
	area.position = center
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	_shape(area, Vector3.ZERO, size)
	add_child(area)
	return area


## folds_down: how many folds, in route order, are already down at this checkpoint.
func _checkpoint(center: Vector3, size: Vector3, pose: Transform3D, folds_down: int) -> void:
	var area: Area3D = _trigger("Checkpoint%d" % checkpoints.size(), center, size)
	checkpoints.append({"area": area, "pose": pose, "folds_down": folds_down})


# ---------------------------------------------------------------- sky and light

func _environment() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#13233a")
	sky_material.sky_horizon_color = SKY
	sky_material.sky_curve = 0.09
	sky_material.sky_energy_multiplier = 0.9
	sky_material.ground_bottom_color = SILHOUETTE
	sky_material.ground_horizon_color = Color("#56697a")
	sky_material.sun_angle_max = 6.0
	sky_material.sun_curve = 0.25
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.5
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.95
	environment.fog_enabled = true
	environment.fog_light_color = Color("#6f8598")
	environment.fog_density = 0.0019
	environment.fog_sky_affect = 0.1
	environment.fog_sun_scatter = 0.15
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.03
	environment.glow_hdr_threshold = 1.15
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	# low evening sun behind the runner's right shoulder
	sun.rotation_degrees = Vector3(-24, 28, 0)
	sun.light_color = Color("#ffbf8a")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


func _street() -> void:
	_mesh(self, Vector3(0, STREET_Y - 0.5, -150), Vector3(1400, 1, 1400), _materials["asphalt"])


# ---------------------------------------------------------------- route: S

func _start_roof() -> void:
	var roof_y: float = 0.0
	var body: Node3D = _building(Vector2(0, -20), Vector2(20, 56), roof_y, true, _facade(2), false)
	body.name = "StartRoof"
	_parapet(Vector3(0, roof_y, -20), Vector2(20, 56), true, [true, true, true, false])
	# stair housing beside spawn: something solid to look at and turn around
	_solid(self, Vector3(6.4, 1.4, -1.5), Vector3(4.2, 2.8, 3.6), _facade(4))
	_mesh(self, Vector3(6.4, 1.1, 0.33), Vector3(1.1, 2.1, 0.12), _materials["dark"])
	_mesh(self, Vector3(6.4, 2.45, 0.4), Vector3(0.4, 0.12, 0.12), _materials["warm_light"])
	# vent row across the middle, open at both ends: vault it or go round
	var vent: StaticBody3D = _solid(self, Vector3(0, 0.48, -18), Vector3(11, 0.96, 0.9), _materials["metal"], "VentRow")
	var vent_cue: int = _cue(self, Vector3(0, 0.96, -17.55), 6.0)
	_cue_strip(vent_cue, self, Vector3(0, 0.97, -17.56), Vector3(10.6, 0.04, 0.12))
	for x: float in [-4.0, 0.0, 4.0]:
		_mesh(vent, Vector3(x, 0.0, 0.47), Vector3(2.4, 0.6, 0.04), _materials["dark"])
	# rooftop furniture for scale
	_water_tank(Vector3(-7.0, 0, -33), true)
	_ac_unit(Vector3(7.2, 0, -27), true)
	_ac_unit(Vector3(7.2, 0, -30.5), true)
	_skylight(Vector3(-5.5, 0, -8))
	# the takeoff edge: a lit lip on the part you jump from, nowhere else
	var edge: int = _cue(self, Vector3(0, 0, -47.9), 7.0)
	_cue_strip(edge, self, Vector3(0, 0.03, -47.82), Vector3(11.0, 0.06, 0.3))
	_cue_strip(edge, self, Vector3(0, -0.25, -48.02), Vector3(11.0, 0.5, 0.06))
	fold_trigger = _trigger("FoldTrigger", Vector3(0, 2, -6), Vector3(22, 6, 4))
	checkpoints.append({"area": null, "pose": spawn, "folds_down": 0})


func _water_tank(base: Vector3, solid: bool) -> void:
	for corner: Vector2 in [Vector2(-0.9, -0.9), Vector2(0.9, -0.9), Vector2(-0.9, 0.9), Vector2(0.9, 0.9)]:
		_mesh(self, base + Vector3(corner.x, 1.0, corner.y), Vector3(0.18, 2.0, 0.18), _materials["metal"])
	_cylinder(self, base + Vector3(0, 3.4, 0), 1.6, 2.8, _materials["concrete_dark"])
	var cap: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.15
	cone.bottom_radius = 1.7
	cone.height = 0.7
	cap.mesh = cone
	cap.material_override = _materials["metal"]
	cap.position = base + Vector3(0, 5.15, 0)
	add_child(cap)
	if solid:
		var body: StaticBody3D = StaticBody3D.new()
		body.position = base + Vector3(0, 2.6, 0)
		add_child(body)
		_shape(body, Vector3.ZERO, Vector3(3.0, 5.2, 3.0))


func _ac_unit(base: Vector3, solid: bool) -> void:
	var size: Vector3 = Vector3(2.0, 1.15, 2.6)
	if solid:
		_solid(self, base + Vector3(0, size.y * 0.5, 0), size, _materials["metal"])
	else:
		_mesh(self, base + Vector3(0, size.y * 0.5, 0), size, _materials["metal"])
	_cylinder(self, base + Vector3(0, size.y + 0.03, -0.6), 0.6, 0.06, _materials["dark"])
	_cylinder(self, base + Vector3(0, size.y + 0.03, 0.6), 0.6, 0.06, _materials["dark"])


func _skylight(base: Vector3) -> void:
	_solid(self, base + Vector3(0, 0.25, 0), Vector3(3.0, 0.5, 4.0), _materials["concrete_dark"])
	_mesh(self, base + Vector3(0, 0.52, 0), Vector3(2.6, 0.06, 3.6), _materials["street_light"]).material_override = _emissive(Color("#9fc3d8"), 0.5)


# ---------------------------------------------------------------- route: drawbridge tower

func _drawbridge_tower() -> void:
	# the part of the tower below the hinge never moves
	_building(Vector2(0, TA_HINGE.z - TA_DEPTH * 0.5), Vector2(TA_WIDTH, TA_DEPTH), 0.0, true, _facade(0), false)
	_ta_material = (_facade(0).duplicate() as ShaderMaterial)
	_ta_material.set_shader_parameter("lit_ratio", 0.1)
	fold = FOLD_SCRIPT.new() as AnimatableBody3D
	fold.name = "DrawbridgeTower"
	fold.position = TA_HINGE
	fold.set("axis", Vector3.RIGHT)
	fold.set("angle", -PI / 2.0)
	fold.set("anticipation", 1.2)
	fold.set("duration", 3.3)
	add_child(fold)
	folds.append(fold)
	fold_triggers.append({"area": fold_trigger, "fold": fold})
	_waves.append({"fold": fold, "material": _ta_material, "height": TA_HEIGHT, "settled": 0.0})
	var center: Vector3 = Vector3(0, TA_HEIGHT * 0.5, -TA_DEPTH * 0.5)
	_mesh(fold, center, Vector3(TA_WIDTH, TA_HEIGHT, TA_DEPTH), _ta_material)
	_shape(fold, center, Vector3(TA_WIDTH, TA_HEIGHT, TA_DEPTH))
	# corner piers: after the fold they are the low kerbs along the road
	for side: float in [-1.0, 1.0]:
		var pier_center: Vector3 = Vector3(side * (TA_WIDTH * 0.5 - 0.45), TA_HEIGHT * 0.5, 0.2)
		_mesh(fold, pier_center, Vector3(0.9, TA_HEIGHT, 0.4), _materials["concrete"])
		_shape(fold, pier_center, Vector3(0.9, TA_HEIGHT, 0.4))
	# cornice bands every eight floors keep the facade readable as a building while it turns
	for floor_index: int in range(1, 6):
		var y: float = float(floor_index) * 8.0 * 1.0 + 0.2
		_mesh(fold, Vector3(0, y, 0.06), Vector3(TA_WIDTH - 1.8, 0.18, 0.1), _materials["concrete"])
	_mesh(fold, Vector3(0, TA_HEIGHT - 0.3, -TA_DEPTH * 0.5), Vector3(TA_WIDTH + 0.4, 0.6, TA_DEPTH + 0.4), _materials["concrete"])
	# a red aircraft light on the crown: the thing to track as the tower falls
	_mesh(fold, Vector3(0, TA_HEIGHT + 0.25, -TA_DEPTH * 0.5), Vector3(0.5, 0.5, 0.5), _materials["red_light"])
	landmarks["tower_crown"] = fold
	# hinge line, glowing at the foot of the facade before anything moves
	var hinge: int = _cue(fold, Vector3(0, 0, 0), 8.0)
	_cue_strip(hinge, fold, Vector3(0, 0.12, 0.08), Vector3(TA_WIDTH - 2.0, 0.24, 0.12))
	_cue_strip(hinge, self, Vector3(0, -0.1, TA_HINGE.z + 0.2), Vector3(TA_WIDTH - 2.0, 0.2, 0.3))
	# chevrons up the facade point along the future road
	var road: int = _cue(fold, Vector3(0, 24, 0), 24.0)
	var y_pos: float = 6.0
	while y_pos < TA_HEIGHT - 3.0:
		_chevron(road, fold, Vector3(0, y_pos, 0.06), 2.4, 0.0)
		y_pos += 6.8
	# the far lip of the road, where you leave it
	var lip: int = _cue(fold, Vector3(0, TA_HEIGHT, 0), 7.0)
	_cue_strip(lip, fold, Vector3(0, TA_HEIGHT - 0.15, 0.08), Vector3(9.0, 0.3, 0.12))
	_checkpoint(Vector3(0, 2.5, -57), Vector3(16, 5, 6), Transform3D(Basis.IDENTITY, Vector3(0, 0.9, -56)), 1)


# ---------------------------------------------------------------- route: R2

func _roof_two() -> void:
	var roof_y: float = -3.0
	_building(Vector2(0, -121.5), Vector2(22, 37), roof_y, true, _facade(3), false)
	_parapet(Vector3(0, roof_y, -121.5), Vector2(22, 37), true, [true, true, false, false])
	var landing: int = _cue(self, Vector3(0, roof_y, -103.5), 6.0)
	_cue_strip(landing, self, Vector3(0, roof_y + 0.03, -103.4), Vector3(9.0, 0.06, 0.25))
	# a duct you vault, open on the right
	var duct: int = _cue(self, Vector3(-3, roof_y + 1.0, -113.5), 6.0)
	_solid(self, Vector3(-3.5, roof_y + 0.5, -114), Vector3(15, 1.0, 1.0), _materials["metal"], "DuctRow")
	_cue_strip(duct, self, Vector3(-3.5, roof_y + 1.01, -113.52), Vector3(14.6, 0.04, 0.1))
	# a stair housing splits the roof into two lanes
	_solid(self, Vector3(0, roof_y + 1.4, -124.5), Vector3(7.0, 2.8, 5.0), _facade(5))
	_mesh(self, Vector3(-2.0, roof_y + 1.05, -121.95), Vector3(1.1, 2.1, 0.12), _materials["dark"])
	_ac_unit(Vector3(7.0, roof_y, -132.5), true)
	_ac_unit(Vector3(-7.5, roof_y, -119), true)
	_water_tank(Vector3(8.0, roof_y, -108), true)
	var edge: int = _cue(self, Vector3(0, roof_y, -139.9), 7.0)
	_cue_strip(edge, self, Vector3(0, roof_y + 0.03, -139.82), Vector3(12.0, 0.06, 0.3))
	_checkpoint(Vector3(0, roof_y + 2.5, -107), Vector3(22, 5, 6), Transform3D(Basis.IDENTITY, Vector3(0, roof_y + 0.9, -106.5)), 1)


# ---------------------------------------------------------------- route: R3 and the bend

func _roof_three_and_bend() -> void:
	var roof_y: float = -3.0
	# R3 sits across a street from R2; its front skin is the second fold
	_building(Vector2(0, -160.1), Vector2(20, 9.8), roof_y, true, _facade(1), false)
	_parapet(Vector3(0, roof_y, -160.1), Vector2(20, 9.8), true, [true, true, false, false])
	_building(Vector2(0, -168), Vector2(20, 6), roof_y, true, _facade(1), false)
	_skin_bridge(roof_y)
	# the roof bends up into the tower: a quarter pipe of gravity-carrying slabs
	var bend: StaticBody3D = StaticBody3D.new()
	bend.name = "Bend"
	bend.set_meta("gravity_surface", true)
	add_child(bend)
	var steps: int = 14
	var bend_cue: int = _cue(self, Vector3(0, -1.0, -166.5), 7.0)
	for index: int in range(steps):
		var angle: float = (float(index) + 0.5) / float(steps) * PI * 0.5
		var half_step: float = PI * 0.25 / float(steps)
		# angle 0 is the roof, PI/2 is the tower face; slabs are chords, so their
		# ends sit exactly on the arc and nothing pokes past the roof or the wall
		var normal: Vector3 = Vector3(0, cos(angle), sin(angle))
		var point: Vector3 = CURL_CENTER + Vector3(0, -cos(angle), -sin(angle)) * CURL_RADIUS * cos(half_step)
		var tangent: Vector3 = Vector3(0, sin(angle), -cos(angle))
		var slab_basis: Basis = Basis(Vector3.RIGHT, normal, -tangent)
		var length: float = 2.0 * CURL_RADIUS * sin(half_step) + 0.02
		var thickness: float = 3.0
		var holder: Node3D = Node3D.new()
		holder.transform = Transform3D(slab_basis, point)
		bend.add_child(holder)
		var slab_size: Vector3 = Vector3(12.0, thickness, length)
		var mesh: MeshInstance3D = _mesh(holder, Vector3(0, -thickness * 0.5, 0), slab_size, _facade(1))
		mesh.name = "BendSlab%02d" % index
		var collider: CollisionShape3D = _shape(bend, Vector3.ZERO, slab_size)
		collider.transform = Transform3D(slab_basis, point + normal * -thickness * 0.5)
		if index % 3 == 1:
			_cue_strip(bend_cue, holder, Vector3(0, 0.02, 0), Vector3(5.0, 0.05, 0.16))
	_checkpoint(Vector3(0, roof_y + 2.5, -159), Vector3(20, 5, 6), Transform3D(Basis.IDENTITY, Vector3(0, roof_y + 0.9, -158.5)), 2)


## R3's front wall rises a full 15 m above its roof. As you come off the road
## it falls toward you about its foot and lands across the street as a bridge,
## flush with R2's edge; its back face, now on top, carries the route marks.
func _skin_bridge(roof_y: float) -> void:
	var width: float = 14.0
	var rise: float = 15.2
	var skin: float = 1.2
	var back_z: float = -155.2
	# the front wall below the roof line and either side of the falling skin
	_solid(self, Vector3(0, (roof_y - 0.05 + STREET_Y) * 0.5, back_z + skin * 0.5), Vector3(20.0, roof_y - 0.05 - STREET_Y, skin), _facade(1))
	var material: ShaderMaterial = _facade(1).duplicate() as ShaderMaterial
	material.set_shader_parameter("lit_ratio", 0.1)
	var block: AnimatableBody3D = FOLD_SCRIPT.new() as AnimatableBody3D
	block.name = "FallingFront"
	# the hinge is the skin's inner foot, so the slab lands below it, flush with the roofs
	block.position = Vector3(0, roof_y, back_z)
	block.set("axis", Vector3.RIGHT)
	block.set("angle", PI / 2.0)
	block.set("anticipation", 0.9)
	block.set("duration", 2.2)
	block.set("settle_time", 0.5)
	add_child(block)
	folds.append(block)
	_waves.append({"fold": block, "material": material, "height": rise, "settled": 0.0})
	var slab_center: Vector3 = Vector3(0, rise * 0.5, skin * 0.5)
	_mesh(block, slab_center, Vector3(width, rise, skin), material)
	_shape(block, slab_center, Vector3(width, rise, skin))
	_mesh(block, Vector3(0, rise - 0.25, skin * 0.5), Vector3(width + 0.3, 0.5, skin + 0.3), _materials["concrete"])
	for side: float in [-1.0, 1.0]:
		var pier: Vector3 = Vector3(side * (width * 0.5 - 0.35), rise * 0.5, skin + 0.12)
		_mesh(block, pier, Vector3(0.7, rise, 0.24), _materials["concrete"])
	# before: chevrons on the street side point down at the hinge line
	var front: int = _cue(block, Vector3(0, rise * 0.5, skin), 9.0)
	for y_pos: float in [4.5, 8.5, 12.5]:
		var holder: Node3D = Node3D.new()
		holder.position = Vector3(0, y_pos, skin + 0.04)
		holder.rotation.z = PI
		block.add_child(holder)
		_chevron(front, holder, Vector3.ZERO, 2.0, 0.0)
	_cue_strip(front, block, Vector3(0, 0.15, skin + 0.06), Vector3(width - 2.0, 0.3, 0.12))
	# after: the back face is the road, chevrons on it point along the run
	var road: int = _cue(block, Vector3(0, rise * 0.5, 0), 9.0)
	for y_pos: float in [3.5, 7.5, 11.5]:
		var holder: Node3D = Node3D.new()
		holder.position = Vector3(0, y_pos, -0.04)
		holder.rotation = Vector3(0, PI, PI)
		block.add_child(holder)
		_chevron(road, holder, Vector3.ZERO, 2.0, 0.0)
	_cue_strip(road, block, Vector3(0, 0.12, -0.05), Vector3(width - 2.0, 0.24, 0.1))
	var trigger: Area3D = _trigger("FallTrigger", Vector3(0, -1.0, -124), Vector3(22, 6, 6))
	fold_triggers.append({"area": trigger, "fold": block})


# ---------------------------------------------------------------- route: TB

func _tower_b() -> void:
	var face_z: float = -171.0
	var top_y: float = CREST_CENTER.y
	var roof_y: float = CREST_CENTER.y + CREST_RADIUS
	var depth: float = 34.0
	var tower: StaticBody3D = StaticBody3D.new()
	tower.name = "WallTower"
	tower.set_meta("gravity_surface", true)
	add_child(tower)
	var body_center: Vector3 = Vector3(0, (STREET_Y + top_y) * 0.5, face_z - depth * 0.5)
	var body_size: Vector3 = Vector3(20, top_y - STREET_Y, depth)
	_mesh(tower, body_center, body_size, _facade(4))
	_shape(tower, body_center, body_size)
	var cap_center: Vector3 = Vector3(0, (top_y + roof_y) * 0.5, face_z - CREST_RADIUS - (depth - CREST_RADIUS) * 0.5)
	var cap_size: Vector3 = Vector3(20, roof_y - top_y, depth - CREST_RADIUS)
	var roof_body: StaticBody3D = _solid(self, cap_center, cap_size, _facade(4), "WallTowerRoof")
	roof_body.set_meta("gravity_surface", false)
	# chevrons up the face show the wall is the road
	var wall: int = _cue(self, Vector3(0, 12, face_z), 10.0)
	var y_pos: float = 6.5
	while y_pos < top_y - 1.5:
		var holder: Node3D = Node3D.new()
		holder.position = Vector3(0, y_pos, face_z + 0.02)
		add_child(holder)
		_chevron(wall, holder, Vector3.ZERO, 2.4, 0.04)
		y_pos += 4.2
	# the convex crest over the top, also gravity-carrying
	var crest: StaticBody3D = StaticBody3D.new()
	crest.name = "Crest"
	crest.set_meta("gravity_surface", true)
	add_child(crest)
	var steps: int = 10
	var crest_cue: int = _cue(self, CREST_CENTER + Vector3(0, CREST_RADIUS, 0), 6.0)
	for index: int in range(steps):
		var angle: float = (float(index) + 0.5) / float(steps) * PI * 0.5
		var half_step: float = PI * 0.25 / float(steps)
		# angle 0 is the wall face (normal +Z), PI/2 is the roof (normal +Y)
		var normal: Vector3 = Vector3(0, sin(angle), cos(angle))
		var point: Vector3 = CREST_CENTER + normal * CREST_RADIUS * cos(half_step)
		var tangent: Vector3 = Vector3(0, cos(angle), -sin(angle))
		var slab_basis: Basis = Basis(Vector3.RIGHT, normal, -tangent)
		var length: float = 2.0 * CREST_RADIUS * sin(half_step) + 0.02
		var thickness: float = CREST_RADIUS
		var slab_size: Vector3 = Vector3(20.0, thickness, length)
		var holder: Node3D = Node3D.new()
		holder.transform = Transform3D(slab_basis, point)
		crest.add_child(holder)
		_mesh(holder, Vector3(0, -thickness * 0.5, 0), slab_size, _materials["concrete_dark"])
		var collider: CollisionShape3D = _shape(crest, Vector3.ZERO, slab_size)
		collider.transform = Transform3D(slab_basis, point - normal * thickness * 0.5)
		if index == steps - 3:
			_cue_strip(crest_cue, holder, Vector3(0, 0.02, 0), Vector3(6.0, 0.05, 0.2))
	_parapet(Vector3(0, roof_y, face_z - depth * 0.5 - CREST_RADIUS * 0.5), Vector2(20, depth - CREST_RADIUS), true, [true, true, false, true])
	# the finish: a pale beam visible from the very first roof
	var finish_base: Vector3 = Vector3(0, roof_y, -190)
	finish_point = finish_base
	_cylinder(self, finish_base + Vector3(0, 0.06, 0), 2.6, 0.12, _materials["cyan"])
	var beam: MeshInstance3D = _cylinder(self, finish_base + Vector3(0, 200, 0), 1.1, 400.0, _materials["beam"])
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	landmarks["finish_beam"] = beam
	finish_trigger = _trigger("FinishTrigger", finish_base + Vector3(0, 2, 0), Vector3(8, 4, 6))


# ---------------------------------------------------------------- the city around it

func _city() -> void:
	var pitch: float = 38.0
	var block: float = 26.0
	for gx: int in range(-9, 10):
		for gz: int in range(-13, 6):
			var center: Vector2 = Vector2(float(gx) * pitch, float(gz) * pitch - 90.0)
			var distance: float = Vector2(center.x, (center.y + 120.0) * 0.6).length()
			if distance > 360.0:
				continue
			# the route corridor stays clear
			if absf(center.x) < 30.0 and center.y > -230.0 and center.y < 30.0:
				continue
			var downtown: float = clampf(1.0 - Vector2(center.x + 80.0, center.y + 330.0).length() / 220.0, 0.0, 1.0)
			var lots: int = 1 + _rng.randi() % 3
			for lot: int in range(lots):
				var w: float = block / float(lots) - 2.0
				var lot_center: Vector2 = center + Vector2(-block * 0.5 + (float(lot) + 0.5) * block / float(lots), _rng.randf_range(-2.0, 2.0))
				var depth: float = _rng.randf_range(14.0, block)
				var height: float = _rng.randf_range(18.0, 52.0) + downtown * _rng.randf_range(40.0, 130.0)
				if absf(lot_center.x) < 70.0 and lot_center.y > -230.0 and lot_center.y < 30.0:
					height = minf(height, 42.0)
				var roof_y: float = STREET_Y + height
				var near: bool = absf(lot_center.x) < 60.0 and lot_center.y > -240.0 and lot_center.y < 40.0
				_building(lot_center, Vector2(w, depth), roof_y, near, null, height < 60.0)
				if height < 60.0 and _rng.randf() < 0.7:
					var prop_base: Vector3 = Vector3(lot_center.x + _rng.randf_range(-w * 0.25, w * 0.25), roof_y, lot_center.y + _rng.randf_range(-depth * 0.25, depth * 0.25))
					if _rng.randf() < 0.4:
						_water_tank(prop_base, false)
					else:
						_ac_unit(prop_base, false)
				elif height >= 60.0:
					_mesh(self, Vector3(lot_center.x, roof_y + 3.0, lot_center.y), Vector3(w * 0.6, 6.0, depth * 0.6), _facade())
					_mesh(self, Vector3(lot_center.x, roof_y + 10.0, lot_center.y), Vector3(0.3, 10.0, 0.3), _materials["metal"])
	_street_lights(pitch)


func _street_lights(pitch: float) -> void:
	var lights: MultiMeshInstance3D = MultiMeshInstance3D.new()
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var lamp: SphereMesh = SphereMesh.new()
	lamp.radius = 0.35
	lamp.height = 0.7
	lamp.radial_segments = 8
	lamp.rings = 4
	multi.mesh = lamp
	var points: Array[Vector3] = []
	for gx: int in range(-9, 10):
		var x: float = (float(gx) + 0.5) * pitch
		for step: int in range(-60, 20):
			points.append(Vector3(x - 5.0, STREET_Y + 6.0, float(step) * 9.0))
	multi.instance_count = points.size()
	for index: int in range(points.size()):
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, points[index]))
	lights.multimesh = multi
	lights.material_override = _materials["street_light"]
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lights)


## Coherent pieces of city doing impossible things far away: never random rubble.
func _spectacle() -> void:
	# a whole street block hanging on its side to the left, slowly turning
	var hanging: Node3D = _city_chunk(Vector3(-230, 40, -190), 5)
	hanging.rotation_degrees = Vector3(0, 0, -90)
	_spinners.append({"node": hanging, "axis": Vector3(0, 1, 0), "speed": 0.018})
	# an upside-down block overhead and ahead
	var inverted: Node3D = _city_chunk(Vector3(90, 175, -330), 6)
	inverted.rotation_degrees = Vector3(180, 20, 0)
	_spinners.append({"node": inverted, "axis": Vector3(0, 1, 0), "speed": -0.01})
	# a tower bent over at a hinge, the landmark you see from every roof
	var base_center: Vector3 = Vector3(-120, STREET_Y, -320)
	_mesh(self, base_center + Vector3(0, 70, 0), Vector3(26, 140, 26), _facade(5))
	var hinge: Node3D = Node3D.new()
	hinge.position = base_center + Vector3(13, 140, 0)
	hinge.rotation_degrees = Vector3(0, 0, -70)
	add_child(hinge)
	_mesh(hinge, Vector3(-13, 45, 0), Vector3(26, 90, 26), _facade(5))
	_mesh(hinge, Vector3(-13, 91, 0), Vector3(20, 2, 20), _materials["cyan"])
	landmarks["bent_tower"] = hinge


func _city_chunk(origin: Vector3, count: int) -> Node3D:
	var chunk: Node3D = Node3D.new()
	chunk.position = origin
	add_child(chunk)
	_mesh(chunk, Vector3(0, -1, 0), Vector3(90, 2, 34), _materials["concrete_dark"])
	_mesh(chunk, Vector3(0, 0.05, 0), Vector3(90, 0.1, 8), _materials["asphalt"])
	for index: int in range(count):
		var x: float = -36.0 + float(index) * 72.0 / float(maxi(count - 1, 1))
		for side: float in [-1.0, 1.0]:
			var height: float = _rng.randf_range(18.0, 46.0)
			_mesh(chunk, Vector3(x, height * 0.5, side * 11.0), Vector3(12.0, height, 10.0), _facade())
	return chunk


# ---------------------------------------------------------------- bot route

## Waypoints a scripted runner follows with ordinary inputs. "jump" marks a
## takeoff point: the bot presses jump when it gets within reach of it.
func _route_for_bot() -> void:
	bot_path = [
		{"point": Vector3(0, 0.9, -5), "look_around": true},
		{"point": Vector3(0, 0.9, -38), "wait_fold": 0, "watch": Vector3(0, 0, -80)},
		{"point": Vector3(0, 0.9, -48.0), "jump": true},
		{"point": Vector3(0, 0.9, -98.6), "jump": true},
		{"point": Vector3(4.5, -2.1, -112)},
		{"point": Vector3(5.0, -2.1, -128)},
		{"point": Vector3(1.5, -2.1, -137.0), "wait_fold": 1, "watch": Vector3(0, 3, -152), "watch_pitch": 18.0},
		{"point": Vector3(0, -2.1, -160)},
		{"point": Vector3(0, 2.0, -170.3)},
		{"point": Vector3(0, 18.0, -170.1)},
		{"point": Vector3(0, 25.9, -180)},
		{"point": Vector3(0, 25.9, -190)},
	]

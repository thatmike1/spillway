extends Node3D
## p / original crest slice, in metres. poses and route points use the body's feet.
## all stair treads are visual children; only their single smooth ramp collides.

const CONCRETE_SHADER: Shader = preload("res://shaders/spillway_concrete.gdshader")
const WATER_SHADER: Shader = preload("res://shaders/spillway_water.gdshader")

var spawn: Transform3D = Transform3D(Basis.IDENTITY, Vector3(2.5, 12.04, 6.0))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var finish_position: Vector3 = Vector3(11.0, 4.0, -59.0)
var finish_radius: float = 1.6
var water_regions: Array[Dictionary] = []
var routes: Dictionary = {}

var _materials: Dictionary = {}
var _built: bool = false


func build() -> void:
	if _built:
		return
	_built = true
	_make_materials()
	_make_environment()
	_make_crest()
	_make_switchback()
	_make_chute()
	_make_terrace()
	_make_water_and_recovery()
	_make_mantle_housing()
	_make_architecture()
	_make_landscape()
	_define_routes()
	checkpoints = [{"pose": spawn, "title": "Crest"}]
	segment_bounds = [AABB(Vector3(-32.0, -12.0, -66.0), Vector3(66.0, 43.0, 83.0))]


func segment_at(_position: Vector3) -> int:
	# p / only crest is playable until its route and controller have been reviewed.
	return 0


func _make_materials() -> void:
	_materials["concrete"] = _concrete(Color("b4ae98"), Color("aaa48d"), 0.10)
	_materials["old_concrete"] = _concrete(Color("96917c"), Color("a19c86"), 0.17)
	_materials["terracotta"] = _concrete(Color("ae6450"), Color("c57a5f"), 0.08)
	_materials["steel"] = _standard(Color("303e40"), 0.54, 0.55)
	_materials["pipe"] = _standard(Color("526e70"), 0.52, 0.42)
	_materials["ochre"] = _standard(Color("c5973d"), 0.70, 0.08)
	_materials["grate"] = _standard(Color("495250"), 0.77, 0.36)
	_materials["earth"] = _standard(Color("968e69"), 1.0)
	_materials["distant_earth"] = _standard(Color("9ca18e"), 1.0)
	_materials["rock"] = _standard(Color("b4ac91"), 1.0)
	_materials["shadow"] = _standard(Color("435758"), 0.77)
	var water: ShaderMaterial = ShaderMaterial.new()
	water.shader = WATER_SHADER
	water.set_shader_parameter("water_color", Color("286b69"))
	_materials["water"] = water
	var reservoir: ShaderMaterial = ShaderMaterial.new()
	reservoir.shader = WATER_SHADER
	reservoir.set_shader_parameter("water_color", Color("477e7b"))
	reservoir.set_shader_parameter("flow_speed", 0.2)
	reservoir.set_shader_parameter("foam_amount", 0.01)
	_materials["reservoir"] = reservoir


func _concrete(wall: Color, deck: Color, weathering: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = CONCRETE_SHADER
	material.set_shader_parameter("wall_color", wall)
	material.set_shader_parameter("deck_color", deck)
	material.set_shader_parameter("weathering", weathering)
	return material


func _standard(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _make_environment() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "SpillwayDaylight"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var atmosphere: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("79a9bd")
	atmosphere.sky_horizon_color = Color("dbe4db")
	atmosphere.ground_horizon_color = Color("dbe0cf")
	atmosphere.ground_bottom_color = Color("7e8376")
	atmosphere.sky_curve = 0.22
	sky.sky_material = atmosphere
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_sky_contribution = 0.0
	environment.ambient_light_color = Color("c6d9df")
	environment.ambient_light_energy = 0.35
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("c8d6cc")
	environment.fog_light_energy = 0.45
	environment.fog_sky_affect = 0.0
	environment.fog_density = 0.0008
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "LateMorningSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 0.80
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	sun.shadow_bias = 0.035
	add_child(sun)


func _make_crest() -> void:
	_slab("CrestDeck", Vector3(-6.0, 12.0, 5.0), Vector2(28.0, 10.0), 1.2)
	# p / the deck stands on real piers, leaving the lower stair landing open.
	for x: float in [-12.0, -2.0, 6.0]:
		_solid("CrestPier", Vector3(x, 1.0, 5.5), Vector3(1.2, 20.0, 2.0), "old_concrete")
	_rail(Vector3(-20.0, 12.0, 0.0), Vector3(-20.0, 12.0, 10.0))
	_rail(Vector3(-20.0, 12.0, 10.0), Vector3(8.0, 12.0, 10.0))
	_rail(Vector3(8.0, 12.0, 10.0), Vector3(8.0, 12.0, 0.0))
	# the gap in the low crest parapet exposes the stair and chute mouths.
	_solid("CrestParapetWest", Vector3(-15.6, 12.42, 0.1), Vector3(8.8, 0.84, 0.3), "concrete")
	_solid("CrestParapetMiddle", Vector3(-3.2, 12.42, 0.1), Vector3(6.0, 0.84, 0.3), "concrete")
	_solid("CrestParapetEast", Vector3(6.8, 12.42, 0.1), Vector3(2.4, 0.84, 0.3), "concrete")
	# short paint caps belong to the two actual route openings, not a floor trail.
	_box(Vector3(-6.35, 12.86, 0.1), Vector3(0.26, 0.05, 0.36), "ochre")
	_box(Vector3(-0.1, 12.86, 0.1), Vector3(0.26, 0.05, 0.36), "ochre")
	_box(Vector3(5.65, 12.86, 0.1), Vector3(0.26, 0.05, 0.36), "ochre")


func _make_switchback() -> void:
	_stairs("UpperSwitchback", Vector3(-9.0, 12.0, 0.0), Vector3(-9.0, 8.0, -16.0), 4.6, 24)
	_slab("SwitchbackLanding", Vector3(-12.5, 8.0, -18.0), Vector2(13.0, 4.0), 0.65)
	_stairs("LowerSwitchback", Vector3(-16.0, 8.0, -16.0), Vector3(-16.0, 4.0, 0.0), 4.6, 24)
	_slab("LowerStairLanding", Vector3(-19.0, 4.0, 1.0), Vector2(12.0, 4.0), 0.7)
	_slab("WestServiceWalk", Vector3(-22.0, 4.0, -20.0), Vector2(5.0, 42.0), 0.65)
	_slab("WestTerraceJoin", Vector3(-15.5, 4.0, -41.0), Vector2(19.0, 4.0), 0.65)
	_rail(Vector3(-6.7, 8.0, -16.0), Vector3(-6.7, 8.0, -20.0))
	_rail(Vector3(-6.7, 8.0, -20.0), Vector3(-19.0, 8.0, -20.0))
	_rail(Vector3(-19.0, 8.0, -20.0), Vector3(-19.0, 8.0, -16.0))
	_rail(Vector3(-25.0, 4.0, 3.0), Vector3(-25.0, 4.0, -43.0))
	_rail(Vector3(-25.0, 4.0, 3.0), Vector3(-13.0, 4.0, 3.0))
	_rail(Vector3(-19.5, 4.0, -3.5), Vector3(-19.5, 4.0, -38.8))
	_rail(Vector3(-25.0, 4.0, -43.0), Vector3(-12.0, 4.0, -43.0))
	for z: float in [-5.0, -18.0, -32.0]:
		_solid("WestWalkPier", Vector3(-22.0, -2.0, z), Vector3(1.25, 11.4, 1.4), "old_concrete")
	for x: float in [-16.0, -9.0]:
		_solid("StairLandingPier", Vector3(x, -0.2, -18.0), Vector3(1.1, 15.8, 1.3), "old_concrete")


func _make_chute() -> void:
	_ramp("DryChute", Vector3(2.5, 12.0, 0.0), Vector3(2.5, 6.0, -24.0), 5.0, 0.65, "concrete")
	_slab("ChuteLaunch", Vector3(2.5, 6.0, -25.0), Vector2(5.0, 2.0), 0.65)
	# smooth low side walls contain the descent, then end before the launch lip.
	for x: float in [-0.25, 5.25]:
		_ramp("ChuteSide", Vector3(x, 12.65, 0.0), Vector3(x, 6.65, -24.0), 0.4, 0.85, "old_concrete")
		_box(Vector3(x, 6.36, -25.0), Vector3(0.4, 0.72, 2.0), "old_concrete", true, "LaunchCheek")
	# a working drying gate makes crouch clearance legible on the fast line.
	for x: float in [-0.7, 5.7]:
		_solid("GateUpright", Vector3(x, 10.1, -13.0), Vector3(0.4, 5.0, 0.8), "steel")
	_solid("RaisedDryingGate", Vector3(2.5, 11.55, -13.0), Vector3(6.7, 2.8, 0.6), "terracotta")
	_box(Vector3(2.5, 10.17, -12.67), Vector3(6.6, 0.15, 0.08), "ochre")
	_box(Vector3(2.5, 13.05, -13.0), Vector3(7.1, 0.22, 0.95), "steel")
	for x: float in [0.8, 2.5, 4.2]:
		_box(Vector3(x, 11.58, -12.65), Vector3(0.09, 2.4, 0.12), "steel")
	# the dam's deep central web supports the sloping channel, outside the stairs.
	_ramp("DamWeb", Vector3(2.5, 11.3, 0.0), Vector3(2.5, 5.3, -24.0), 9.0, 13.0, "old_concrete")
	for z: float in [-4.0, -12.0, -21.0]:
		_solid("DamEastButtress", Vector3(8.6, -1.5, z), Vector3(2.1, 14.0, 2.2), "concrete")


func _make_terrace() -> void:
	_slab("JumpLandingTerrace", Vector3(1.0, 4.0, -37.0), Vector2(18.0, 12.0), 1.0)
	_slab("RecoveryRampJoin", Vector3(12.0, 4.0, -41.5), Vector2(6.0, 3.0), 0.65)
	# the safe line turns west, south and east around the working settling basin.
	_slab("ForgivingTerraceTurn", Vector3(-9.0, 4.0, -47.5), Vector2(6.0, 17.0), 0.8)
	_slab("SliceExitDeck", Vector3(2.5, 4.0, -59.0), Vector2(29.0, 6.0), 0.85)
	_rail(Vector3(-12.0, 4.0, -43.0), Vector3(-12.0, 4.0, -62.0))
	_rail(Vector3(-12.0, 4.0, -62.0), Vector3(17.0, 4.0, -62.0))
	_rail(Vector3(17.0, 4.0, -62.0), Vector3(17.0, 4.0, -56.0))
	_rail(Vector3(-6.0, 4.0, -45.0), Vector3(-6.0, 4.0, -54.0))
	# the direct line begins right of the chute axis, so carried speed needs steering.
	var bridge_a: Vector3 = Vector3(4.0, 4.0, -42.9)
	var bridge_b: Vector3 = Vector3(10.0, 4.0, -56.1)
	_ramp("CarriedSpeedBridge", bridge_a, bridge_b, 2.3, 0.28, "concrete")
	var right: Vector3 = _right_of(bridge_a, bridge_b)
	for side: float in [-1.0, 1.0]:
		_beam(bridge_a + right * side * 1.15 - Vector3.UP * 0.29,
			bridge_b + right * side * 1.15 - Vector3.UP * 0.29, 0.13, "steel")
		# a low painted edge is visual only, keeping the narrow line honest.
		_beam(bridge_a + right * side * 1.08 + Vector3.UP * 0.012,
			bridge_b + right * side * 1.08 + Vector3.UP * 0.012, 0.055, "ochre")
	for ratio: float in [0.25, 0.75]:
		var support: Vector3 = bridge_a.lerp(bridge_b, ratio)
		_solid("BridgePedestal", Vector3(support.x, 0.65, support.z), Vector3(0.6, 5.1, 0.8), "old_concrete")
		_beam(Vector3(support.x, 1.55, support.z), support + Vector3(-0.8, -0.32, 0.0), 0.15, "steel")
		_beam(Vector3(support.x, 1.55, support.z), support + Vector3(0.8, -0.32, 0.0), 0.15, "steel")
	# the finish is an architectural threshold, with the tower visible beyond.
	for x: float in [8.2, 13.8]:
		_solid("ExitCanopyColumn", Vector3(x, 5.65, -60.3), Vector3(0.3, 3.3, 0.35), "steel")
	_box(Vector3(11.0, 7.4, -60.3), Vector3(6.6, 0.22, 2.8), "terracotta")
	_box(Vector3(11.0, 7.24, -58.85), Vector3(6.6, 0.10, 0.12), "ochre")
	for x: float in [-9.0, 1.0, 12.0]:
		_solid("ExitDeckPier", Vector3(x, -2.0, -59.0), Vector3(1.4, 11.0, 2.0), "old_concrete")
	for z: float in [-35.0, -41.0]:
		_solid("TerracePier", Vector3(-4.0, -2.0, z), Vector3(2.0, 11.0, 2.0), "old_concrete")


func _make_water_and_recovery() -> void:
	_slab("ChannelRecoveryFloor", Vector3(3.5, 1.5, -33.5), Vector2(23.0, 19.0), 1.0, "old_concrete")
	_water("ShallowChannel", Vector3(3.5, 1.78, -33.5), Vector2(23.0, 19.0), "water")
	water_regions.append({"bounds": AABB(Vector3(-8.0, 1.35, -43.0), Vector3(23.0, 0.65, 19.0)), "depth": 0.28})
	_ramp("ChannelRecoveryRamp", Vector3(12.0, 1.5, -29.0), Vector3(12.0, 4.0, -40.0), 4.0, 0.5, "concrete")
	_solid("ChannelEastWall", Vector3(15.3, 1.6, -33.5), Vector3(0.6, 2.2, 20.0), "old_concrete")
	_solid("ChannelWestWall", Vector3(-8.3, 1.6, -28.0), Vector3(0.6, 2.2, 8.0), "old_concrete")
	_solid("ChannelHeadWall", Vector3(10.0, 1.6, -23.7), Vector3(10.0, 2.2, 0.6), "old_concrete")
	# the second catch floor gives a missed narrow bridge a walkable way out too.
	_slab("SettlingBasinFloor", Vector3(5.5, 1.5, -49.5), Vector2(23.0, 13.0), 0.9, "old_concrete")
	_water("SettlingWater", Vector3(5.5, 1.68, -49.5), Vector2(23.0, 13.0), "water")
	water_regions.append({"bounds": AABB(Vector3(-6.0, 1.35, -56.0), Vector3(23.0, 0.5, 13.0)), "depth": 0.18})
	_ramp("BridgeRecoveryRamp", Vector3(15.0, 1.5, -45.0), Vector3(15.0, 4.0, -56.0), 3.2, 0.5, "concrete")
	_solid("SettlingBasinEastWall", Vector3(17.3, 1.6, -49.5), Vector3(0.6, 2.2, 13.0), "old_concrete")
	# surface drains at the ramp feet provide scale without obstructing capsules.
	for z: float in [-28.7, -44.7]:
		var x: float = 12.0 if z > -30.0 else 15.0
		for i: int in 7:
			_box(Vector3(x - 1.1 + float(i) * 0.35, 1.795 if z > -30.0 else 1.695, z), Vector3(0.07, 0.035, 0.7), "grate")


func _make_mantle_housing() -> void:
	# p / optional 1.6 m catch fixture, with a separate walking ramp to its roof.
	_solid("MantleValveHousing", Vector3(-3.0, 4.8, -36.0), Vector3(3.0, 1.6, 4.0), "terracotta")
	_box(Vector3(-3.0, 5.62, -36.0), Vector3(3.12, 0.04, 4.12), "concrete")
	_ramp("ValveRoofAccess", Vector3(-6.0, 4.0, -41.0), Vector3(-6.0, 5.6, -35.0), 1.8, 0.4, "concrete")
	_slab("ValveRoofLanding", Vector3(-5.1, 5.6, -35.0), Vector2(3.6, 2.0), 0.4)
	# roof controls stay behind the catch lip so the motor has clear landing volume.
	_cylinder(Vector3(-3.0, 5.65, -37.0), Vector3(-3.0, 6.2, -37.0), 0.12, "steel")
	_wheel(Vector3(-3.0, 6.22, -37.0), 0.45, "ochre", true)
	for z: float in [-35.0, -36.0, -37.0]:
		_box(Vector3(-1.485, 4.75, z), Vector3(0.04, 0.45, 0.55), "grate")


func _make_architecture() -> void:
	# large pipes and a tower keep the dam legible from the very first view.
	for x: float in [11.5, 14.0]:
		_cylinder(Vector3(x, 10.0, 5.0), Vector3(x, -3.0, -18.0), 0.55, "pipe")
		_cylinder(Vector3(x, -3.0, -18.0), Vector3(x, -3.0, -69.0), 0.55, "pipe")
		for z: float in [-23.0, -39.0, -53.0, -66.0]:
			_solid("PenstockSaddle", Vector3(x, -4.4, z), Vector3(1.65, 1.8, 1.15), "old_concrete")
	_solid("PumpTowerFoundation", Vector3(24.0, -6.0, -78.0), Vector3(17.0, 6.0, 20.0), "old_concrete")
	_solid("PumpTower", Vector3(24.0, 5.0, -79.0), Vector3(8.0, 22.0, 10.0), "terracotta")
	_solid("PumpTowerCrown", Vector3(24.0, 16.25, -79.0), Vector3(9.0, 0.5, 11.0), "concrete")
	_solid("TowerLowerHall", Vector3(19.0, -0.5, -74.0), Vector3(11.0, 11.0, 9.0), "concrete")
	# deep blue inset panels read as industrial glazing, without emissive windows.
	for x: float in [21.7, 24.0, 26.3]:
		_box(Vector3(x, 12.0, -73.97), Vector3(1.4, 4.0, 0.08), "shadow")
		_box(Vector3(x, 12.0, -73.9), Vector3(0.07, 4.0, 0.09), "steel")
		_box(Vector3(x, 12.0, -73.9), Vector3(1.4, 0.08, 0.09), "steel")
	_wheel(Vector3(23.8, 4.1, -72.7), 4.2, "ochre")
	_cylinder(Vector3(23.8, 4.1, -73.7), Vector3(23.8, 4.1, -71.9), 0.42, "steel")
	# retaining wings anchor the crest to the hillside instead of a floating deck.
	_solid("WestRetainingWing", Vector3(-29.0, -0.5, -12.0), Vector3(3.0, 24.0, 52.0), "old_concrete")
	_solid("EastRetainingWing", Vector3(19.0, -1.0, -4.0), Vector3(3.5, 24.0, 30.0), "old_concrete")
	for z: float in [7.0, -5.0, -17.0, -29.0]:
		_solid("WestWingButtress", Vector3(-26.3, -3.0, z), Vector3(2.5, 17.0, 2.0), "concrete")
	# a small utility house at the crest provides nearby scale and layered shadow.
	_solid("CrestGatehouse", Vector3(-15.0, 14.0, 7.5), Vector3(5.0, 4.0, 4.0), "terracotta")
	_box(Vector3(-15.0, 16.15, 7.5), Vector3(5.6, 0.3, 4.6), "concrete")
	_box(Vector3(-15.0, 13.45, 5.47), Vector3(1.0, 2.9, 0.08), "steel")
	_box(Vector3(-13.3, 14.5, 5.45), Vector3(1.25, 1.4, 0.08), "shadow")
	# grating is recessed into the far terrace wall, not placed across a running line.
	for z: float in [-46.0, -49.0, -52.0]:
		_box(Vector3(-5.96, 2.5, z), Vector3(0.08, 1.0, 1.2), "grate")


func _make_landscape() -> void:
	_water("UpperReservoir", Vector3(-14.0, 8.7, 67.0), Vector2(150.0, 108.0), "reservoir")
	_water("DistantOutflow", Vector3(18.0, -7.4, -101.0), Vector2(130.0, 70.0), "reservoir")
	_box(Vector3(-52.0, -1.0, -17.0), Vector3(41.0, 22.0, 93.0), "earth")
	_box(Vector3(45.0, -3.0, -4.0), Vector3(43.0, 20.0, 78.0), "earth")
	for i: int in 4:
		var level_y: float = 7.5 - float(i) * 5.3
		_box(Vector3(-40.0 - float(i) * 5.0, level_y - 3.0, -48.0 - float(i) * 12.0), Vector3(20.0, 6.0, 30.0), "rock")
	# low-poly ridgelines are background landforms only, never traversal platforms.
	_ridge(-145.0, 135.0, -150.0, 25.0, "distant_earth")
	_ridge(-130.0, -65.0, -72.0, 39.0, "earth")
	_ridge(73.0, 150.0, -95.0, 32.0, "rock")


func _define_routes() -> void:
	routes["safe"] = [
		_point(Vector3(2.5, 12.0, 5.0)), _point(Vector3(-9.0, 12.0, 3.0)),
		_point(Vector3(-9.0, 11.75, -1.0)), _point(Vector3(-9.0, 8.0, -17.8)),
		_point(Vector3(-16.0, 8.0, -18.0)), _point(Vector3(-16.0, 7.75, -15.0)),
		_point(Vector3(-16.0, 4.0, 1.0)), _point(Vector3(-22.0, 4.0, 1.0)),
		_point(Vector3(-22.0, 4.0, -40.8)), _point(Vector3(-9.0, 4.0, -41.0)),
		_point(Vector3(-9.0, 4.0, -58.8)), _point(finish_position),
	]
	routes["fast"] = [
		_point(Vector3(2.5, 12.0, 5.0)), _point(Vector3(2.5, 11.25, -3.0), 1.0, true),
		_point(Vector3(2.5, 7.0, -20.0), 1.0, true),
		_point(Vector3(2.5, 6.0, -24.8), 0.55, true, true),
		_point(Vector3(2.9, 4.0, -38.5), 1.8),
		_point(Vector3(4.0, 4.0, -42.1), 0.7),
		_point(Vector3(7.0, 4.0, -49.5), 0.7),
		_point(Vector3(10.0, 4.0, -56.8), 0.9), _point(finish_position),
	]
	routes["recovery"] = [
		_point(Vector3(2.5, 12.0, 5.0)), _point(Vector3(2.5, 11.25, -3.0), 1.0, true),
		_point(Vector3(2.5, 7.0, -20.0), 1.0, true),
		_point(Vector3(2.5, 1.5, -28.4), 1.5),
		_point(Vector3(12.0, 1.5, -28.0)), _point(Vector3(12.0, 4.0, -40.8)),
		_point(Vector3(3.0, 4.0, -41.0)), _point(Vector3(-9.0, 4.0, -41.0)),
		_point(Vector3(-9.0, 4.0, -58.8)), _point(finish_position),
	]


func _point(pos: Vector3, radius: float = 1.0, crouch: bool = false, jump: bool = false) -> Dictionary:
	return {"pos": pos, "radius": radius, "crouch": crouch, "jump": jump}


func _slab(node_name: String, top: Vector3, size: Vector2, thickness: float, material: String = "concrete") -> void:
	_solid(node_name, top - Vector3.UP * thickness * 0.5, Vector3(size.x, thickness, size.y), material)


func _solid(node_name: String, center: Vector3, size: Vector3, material: String) -> StaticBody3D:
	return _box(center, size, material, true, node_name) as StaticBody3D


func _box(center: Vector3, size: Vector3, material: String, collision: bool = false, node_name: String = "Detail") -> Node3D:
	var parent: Node3D = StaticBody3D.new() if collision else Node3D.new()
	parent.name = node_name
	parent.position = center
	add_child(parent)
	if collision:
		var body: StaticBody3D = parent as StaticBody3D
		body.collision_layer = 1
		body.collision_mask = 0
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _materials[material]
	parent.add_child(mesh_instance)
	return parent


func _right_of(a: Vector3, b: Vector3) -> Vector3:
	var forward: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	return forward.cross(Vector3.UP)


func _ramp(node_name: String, a: Vector3, b: Vector3, width: float, thickness: float, material: String, visible: bool = true) -> StaticBody3D:
	var right: Vector3 = _right_of(a, b) * width * 0.5
	var vertices: PackedVector3Array = PackedVector3Array([
		a - right, a + right, b + right, b - right,
		a - right - Vector3.UP * thickness, a + right - Vector3.UP * thickness,
		b + right - Vector3.UP * thickness, b - right - Vector3.UP * thickness,
	])
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = vertices
	collision.shape = shape
	body.add_child(collision)
	if visible:
		var tool: SurfaceTool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_smooth_group(-1)
		for face: Array in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
			for index: int in [0, 1, 2, 0, 2, 3]:
				tool.add_vertex(vertices[int(face[index])])
		tool.generate_normals()
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = tool.commit()
		mesh.material_override = _materials[material]
		body.add_child(mesh)
	return body


func _stairs(node_name: String, a: Vector3, b: Vector3, width: float, count: int) -> void:
	var body: StaticBody3D = _ramp(node_name + "CollisionRamp", a, b, width, 0.7, "concrete", false)
	body.set_meta("smooth_stair_ramp", true)
	var tread_group: Node3D = Node3D.new()
	tread_group.name = node_name + "VisualSteps"
	add_child(tread_group)
	var run_length: float = Vector2(b.x - a.x, b.z - a.z).length()
	var tread_length: float = run_length / float(count)
	var yaw: float = atan2(-(b.x - a.x), -(b.z - a.z))
	for i: int in count:
		var ratio: float = (float(i) + 0.5) / float(count)
		var center: Vector3 = a.lerp(b, ratio) - Vector3.UP * 0.08
		var tread: MeshInstance3D = MeshInstance3D.new()
		tread.name = "VisualTread%02d" % i
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(width, 0.16, tread_length + 0.012)
		tread.mesh = box
		tread.material_override = _materials["concrete"]
		tread.position = center
		tread.rotation.y = yaw
		tread_group.add_child(tread)
	var right: Vector3 = _right_of(a, b) * (width * 0.5 - 0.08)
	_rail(a - right, b - right)
	_rail(a + right, b + right)


func _rail(a: Vector3, b: Vector3) -> void:
	var length: float = a.distance_to(b)
	var sections: int = maxi(1, ceili(length / 2.7))
	# rails collide as continuous beams; posts remain visual to avoid capsule snags.
	_beam(a + Vector3.UP * 1.05, b + Vector3.UP * 1.05, 0.075, "steel", true)
	_beam(a + Vector3.UP * 0.51, b + Vector3.UP * 0.51, 0.045, "steel", true)
	for i: int in sections + 1:
		var point: Vector3 = a.lerp(b, float(i) / float(sections))
		_box(point + Vector3.UP * 0.525, Vector3(0.075, 1.05, 0.075), "steel")
		_box(point + Vector3.UP * 0.035, Vector3(0.22, 0.07, 0.22), "steel")


func _beam(a: Vector3, b: Vector3, thickness: float, material: String, collision: bool = false) -> void:
	var beam: Node3D = _box((a + b) * 0.5, Vector3(thickness, a.distance_to(b), thickness), material, collision, "Beam")
	beam.quaternion = Quaternion(Vector3.UP, (b - a).normalized())


func _cylinder(a: Vector3, b: Vector3, radius: float, material: String) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 16
	instance.mesh = cylinder
	instance.material_override = _materials[material]
	instance.position = (a + b) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	add_child(instance)


func _wheel(center: Vector3, radius: float, material: String, horizontal: bool = false) -> void:
	var count: int = 32 if radius > 1.0 else 16
	for i: int in count:
		var angle_a: float = TAU * float(i) / float(count)
		var angle_b: float = TAU * float(i + 1) / float(count)
		var offset_a: Vector3 = Vector3(cos(angle_a), sin(angle_a), 0.0) * radius
		var offset_b: Vector3 = Vector3(cos(angle_b), sin(angle_b), 0.0) * radius
		if horizontal:
			offset_a = Vector3(offset_a.x, 0.0, offset_a.y)
			offset_b = Vector3(offset_b.x, 0.0, offset_b.y)
		_beam(center + offset_a, center + offset_b, radius * 0.075, material)
		if i % (count / 8) == 0:
			_beam(center, center + offset_a, radius * 0.048, "steel")


func _water(node_name: String, center: Vector3, size: Vector2, material: String) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	instance.mesh = plane
	instance.position = center
	instance.material_override = _materials[material]
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _ridge(left: float, right: float, z: float, height: float, material: String) -> void:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var count: int = 12
	for i: int in count:
		var x_a: float = lerpf(left, right, float(i) / float(count))
		var x_b: float = lerpf(left, right, float(i + 1) / float(count))
		var y_a: float = height * (0.65 + 0.24 * sin(float(i) * 1.7) + 0.14 * sin(float(i) * 3.4))
		var y_b: float = height * (0.65 + 0.24 * sin(float(i + 1) * 1.7) + 0.14 * sin(float(i + 1) * 3.4))
		var points: Array[Vector3] = [Vector3(x_a, -12.0, z + 20.0), Vector3(x_a, y_a, z), Vector3(x_b, y_b, z), Vector3(x_b, -12.0, z + 20.0)]
		for index: int in [0, 1, 2, 0, 2, 3]:
			tool.add_vertex(points[index])
	tool.generate_normals()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = tool.commit()
	mesh.material_override = _materials[material]
	add_child(mesh)

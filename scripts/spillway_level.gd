extends Node3D
## p / original crest slice, in metres. poses and route points use the body's feet.
## all stair treads are visual children; only their single smooth ramp collides.

const CONCRETE_SHADER: Shader = preload("res://shaders/spillway_concrete.gdshader")
const WATER_SHADER: Shader = preload("res://shaders/spillway_water.gdshader")

var spawn: Transform3D = Transform3D(Basis.IDENTITY, Vector3(2.5, 12.04, 3.0))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var finish_position: Vector3 = Vector3(11.0, 4.0, -59.0)
var finish_radius: float = 1.6
var water_regions: Array[Dictionary] = []
var routes: Dictionary = {}
var water_audio_sources: Array[Vector3] = []
var _water_surfaces: Array[Dictionary] = []
var _hero_wheel: Node3D
var _wheel_speed: float = 0.0
var _wheel_running: bool = false

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
	_make_flowing_spill()
	_make_architecture()
	_make_landscape()
	_define_routes()
	checkpoints = [{"pose": spawn, "title": "Crest"}]
	segment_bounds = [AABB(Vector3(-32.0, -12.0, -66.0), Vector3(66.0, 43.0, 83.0))]
	if not OS.get_cmdline_user_args().has("--crest"):
		preload("res://scripts/spillway_course.gd").new().build(self)
		routes["brake"].append_array(routes["safe"].slice(12))
	preload("res://scripts/spillway_art.gd").new().apply(self)
	if not OS.get_cmdline_user_args().has("--no-batch"):
		_batch_static_boxes()


func _batch_static_boxes() -> void:
	# p / same geometry and materials, fewer draw calls; wheel parts remain separate.
	var groups: Dictionary = {}
	for entry: Node in find_children("*", "MeshInstance3D", true, false):
		var source := entry as MeshInstance3D
		if not source.mesh is BoxMesh:
			continue
		var ancestor := source.get_parent()
		var moving: bool = false
		while ancestor != self and ancestor != null:
			if bool(ancestor.get_meta("moving_geometry", false)):
				moving = true
				break
			ancestor = ancestor.get_parent()
		if moving:
			continue
		var material: Material = source.material_override
		if not groups.has(material):
			groups[material] = []
		var pose := global_transform.affine_inverse() * source.global_transform
		var size := (source.mesh as BoxMesh).size
		pose.basis.x *= size.x
		pose.basis.y *= size.y
		pose.basis.z *= size.z
		groups[material].append(pose)
		source.hide()
		source.queue_free()
	for material: Material in groups:
		var transforms: Array = groups[material]
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = transforms.size()
		for i: int in transforms.size():
			instances.set_instance_transform(i, transforms[i])
		var batch := MultiMeshInstance3D.new()
		batch.name = "StaticDetailBatch"
		batch.multimesh = instances
		batch.material_override = material
		add_child(batch)


func segment_at(position: Vector3) -> int:
	if not has_meta("spillway_course_built") or position.z > -62.0:
		return 0
	return 2 if position.z < -98.0 or (position.x > -12.0 and position.z < -80.0) else 1


func _make_materials() -> void:
	_materials["concrete"] = _concrete(Color("9e9f96"), Color("a9aaa2"), 0.10)
	_materials["old_concrete"] = _concrete(Color("858c82"), Color("92988a"), 0.17)
	_materials["wet_concrete"] = _materials["old_concrete"].duplicate()
	(_materials["wet_concrete"] as ShaderMaterial).set_shader_parameter("waterline", 1.78)
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
	environment.fog_light_color = Color("d0dedb")
	environment.fog_light_energy = 0.45
	environment.fog_sky_affect = 0.0
	environment.fog_density = 0.0030
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
	# p / the crest frame is readable at speed; the yard owns the optional low gate.
	_box(Vector3(2.5, 11.35, -13.0), Vector3(6.7, 0.5, 0.6), "ochre", true, "RaisedDryingGate")
	_box(Vector3(2.5, 13.05, -13.0), Vector3(7.1, 0.22, 0.95), "steel")
	for x: float in [0.0, 1.25, 2.5, 3.75, 5.0]:
		_box(Vector3(x, 12.15, -13.0), Vector3(0.10, 1.2, 0.18), "steel")

	# the dam's deep central web supports the sloping channel, outside the stairs.
	_ramp("DamWeb", Vector3(2.5, 11.3, 0.0), Vector3(2.5, 5.3, -24.0), 9.0, 13.0, "old_concrete")
	for z: float in [-4.0, -12.0, -21.0]:
		var top := lerpf(12.7, 7.1, -z / 23.7) - 0.5
		_solid("DamEastButtress", Vector3(8.6, (top - 8.5) * 0.5, z), Vector3(2.1, top + 8.5, 2.2), "concrete")


func _make_terrace() -> void:
	_slab("JumpLandingTerrace", Vector3(1.0, 4.0, -42.0), Vector2(18.0, 14.0), 0.7)
	# p / a sloping apron below the catch lip avoids a deep vertical impact face.
	_ramp("LandingApron", Vector3(1.0, 1.5, -33.2), Vector3(1.0, 3.3, -35.0), 18.0, 0.3, "old_concrete")
	_beam(Vector3(-8.0, 4.025, -35.0), Vector3(10.0, 4.025, -35.0), 0.055, "ochre")
	_slab("RecoveryRampJoin", Vector3(12.0, 4.0, -41.5), Vector2(6.0, 3.0), 0.65)
	# the safe line turns west, south and east around the working settling basin.
	_slab("ForgivingTerraceTurn", Vector3(-9.0, 4.0, -47.5), Vector2(6.0, 17.0), 0.8)
	_slab("SliceExitDeck", Vector3(2.5, 4.0, -59.0), Vector2(29.0, 6.0), 0.85)
	_rail(Vector3(-12.0, 4.0, -43.0), Vector3(-12.0, 4.0, -62.0))
	_rail(Vector3(-12.0, 4.0, -62.0), Vector3(17.0, 4.0, -62.0))
	_rail(Vector3(17.0, 4.0, -62.0), Vector3(17.0, 4.0, -56.0))
	_rail(Vector3(-6.0, 4.0, -45.0), Vector3(-6.0, 4.0, -54.0))
	# the direct line begins right of the chute axis, so carried speed needs steering.
	var bridge_a: Vector3 = Vector3(4.0, 4.0, -48.9)
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
	_solid("ChannelEastWall", Vector3(15.3, 1.6, -33.5), Vector3(0.6, 2.2, 20.0), "wet_concrete")
	_solid("ChannelWestWall", Vector3(-8.3, 1.6, -28.0), Vector3(0.6, 2.2, 8.0), "wet_concrete")
	_solid("ChannelHeadWall", Vector3(10.0, 1.6, -23.7), Vector3(10.0, 2.2, 0.6), "wet_concrete")
	# the second catch floor gives a missed narrow bridge a walkable way out too.
	_slab("SettlingBasinFloor", Vector3(5.5, 1.5, -49.5), Vector2(23.0, 13.0), 0.9, "old_concrete")
	_water("SettlingWater", Vector3(5.5, 1.68, -49.5), Vector2(23.0, 13.0), "water")
	water_regions.append({"bounds": AABB(Vector3(-6.0, 1.35, -56.0), Vector3(23.0, 0.5, 13.0)), "depth": 0.18})
	_ramp("BridgeRecoveryRamp", Vector3(15.0, 1.5, -45.0), Vector3(15.0, 4.0, -56.0), 3.2, 0.5, "concrete")
	_solid("SettlingBasinEastWall", Vector3(17.3, 1.6, -49.5), Vector3(0.6, 2.2, 13.0), "wet_concrete")
	# surface drains at the ramp feet provide scale without obstructing capsules.
	for z: float in [-28.7, -44.7]:
		var x: float = 12.0 if z > -30.0 else 15.0
		for i: int in 7:
			_box(Vector3(x - 1.1 + float(i) * 0.35, 1.795 if z > -30.0 else 1.695, z), Vector3(0.07, 0.035, 0.7), "grate")


func _make_flowing_spill() -> void:
	# p / a wet flume beside the dry route makes the waterworks visibly work.
	var a := Vector3(8.5, 12.7, 0.0)
	var b := Vector3(8.5, 7.1, -23.7)
	_ramp("WetSpillwayBed", a, b, 3.2, 0.5, "wet_concrete")
	for side: float in [-1.0, 1.0]:
		_ramp("WetSpillwayCheek", a + Vector3(side * 1.7, 0.45, 0.0), b + Vector3(side * 1.7, 0.45, 0.0), 0.3, 0.7, "old_concrete")
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.12, a.distance_to(b))
	water.mesh = plane
	water.position = (a + b) * 0.5 + Vector3.UP * 0.07
	water.rotation.x = -atan2(a.y - b.y, a.z - b.z)
	water.material_override = _materials["water"]
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	var cascade := MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(3.12, 5.37)
	cascade.mesh = sheet
	cascade.position = Vector3(8.5, 4.44, -24.05)
	cascade.rotation.x = -1.44
	var foam: ShaderMaterial = _materials["water"].duplicate()
	foam.set_shader_parameter("flow_speed", 2.8)
	foam.set_shader_parameter("foam_amount", 0.8)
	foam.set_shader_parameter("water_color", Color("68a6a0"))
	_materials["foam_water"] = foam
	var curtain: ShaderMaterial = foam.duplicate()
	curtain.set_shader_parameter("vertical_flow", 1.0)
	cascade.material_override = curtain
	cascade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cascade)
	_water("TurbulentPool", Vector3(8.5, 1.81, -25.5), Vector2(3.7, 3.0), "foam_water")
	water_audio_sources.append(Vector3(8.5, 4.4, -24.0))
	water_regions.append({"bounds": AABB(Vector3(6.94, 6.5, -23.7), Vector3(3.12, 6.5, 23.7)), "depth": 0.12})

func splash_at(feet: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var surface_y: float = feet.y
	for surface: Dictionary in _water_surfaces:
		if (surface["bounds"] as Rect2).has_point(Vector2(feet.x, feet.z)) and absf(float(surface["height"]) - feet.y) < 1.0:
			surface_y = float(surface["height"])
			break
	var ripple := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.24
	ring.outer_radius = 0.29
	ring.rings = 24
	ring.ring_segments = 6
	ripple.mesh = ring
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.82, 0.94, 0.90, 0.65)
	material.roughness = 0.8
	ripple.material_override = material
	ripple.position = Vector3(feet.x, surface_y + 0.025, feet.z)
	ripple.scale = Vector3(1.0, 0.18, 1.0)
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ripple)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ripple, "scale", Vector3(4.5, 0.18, 4.5), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.65)
	tween.chain().tween_callback(ripple.queue_free)

func start_wheel() -> void:
	_wheel_running = true

func reset_state() -> void:
	_wheel_running = false
	_wheel_speed = 0.0
	if is_instance_valid(_hero_wheel):
		_hero_wheel.rotation.z = 0.0

func _process(delta: float) -> void:
	_wheel_speed = move_toward(_wheel_speed, 0.75 if _wheel_running else 0.0, delta * 0.35)
	if is_instance_valid(_hero_wheel):
		_hero_wheel.rotation.z -= _wheel_speed * delta


func _make_mantle_housing() -> void:
	# p / optional 1.6 m catch fixture, with a separate walking ramp to its roof.
	_solid("MantleValveHousing", Vector3(-3.0, 4.8, -37.0), Vector3(3.0, 1.6, 4.0), "terracotta")
	_box(Vector3(-3.0, 5.62, -37.0), Vector3(3.12, 0.04, 4.12), "concrete")
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
		# p / the pressure main dives below the basin before the walkable loading apron.
		_cylinder(Vector3(x, -3.0, -18.0), Vector3(x, -3.0, -55.0), 0.55, "pipe")
		_cylinder(Vector3(x, -3.0, -55.0), Vector3(x, -7.0, -60.0), 0.55, "pipe")
		_cylinder(Vector3(x, -7.0, -60.0), Vector3(x, -7.0, -71.0), 0.55, "pipe")
		for z: float in [-23.0, -39.0, -53.0]:
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
	_hero_wheel = _wheel(Vector3(23.8, -0.5, -69.15), 2.45, "ochre")
	_cylinder(Vector3(23.8, -0.5, -73.7), Vector3(23.8, -0.5, -69.0), 0.42, "steel")
	# retaining wings anchor the crest to the hillside instead of a floating deck.
	_solid("WestRetainingWing", Vector3(-29.0, -3.0, -12.0), Vector3(3.0, 17.0, 52.0), "old_concrete")
	_solid("EastRetainingWing", Vector3(19.0, -3.0, -4.0), Vector3(3.5, 17.0, 30.0), "old_concrete")
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
	# p / rounded banks replace the provisional spiked backdrop; no traversal collision.
	_landform(Vector3(-90.0, -8.0, -37.0), Vector2(96.0, 140.0), 26.0, 0.8)
	_landform(Vector3(88.0, -8.0, -36.0), Vector2(88.0, 152.0), 23.0, 2.4)
	_landform(Vector3(-12.0, -10.0, -176.0), Vector2(290.0, 88.0), 31.0, 1.4)
	_landform(Vector3(0.0, -9.5, -83.0), Vector2(170.0, 230.0), 0.5, 0.3)
	_landform(Vector3(-38.0, -9.0, -24.0), Vector2(27.0, 86.0), 14.0, 0.5)
	_landform(Vector3(30.0, -9.0, -8.0), Vector2(23.0, 72.0), 16.0, 1.5)
	_make_trees()


func _landform(center: Vector3, size: Vector2, height: float, seed_phase: float) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = 36
	var nz: int = 18
	for iz: int in nz:
		for ix: int in nx:
			for corner: Vector2i in [Vector2i(0,0), Vector2i(1,1), Vector2i(0,1), Vector2i(0,0), Vector2i(1,0), Vector2i(1,1)]:
				var u := float(ix + corner.x) / nx
				var v := float(iz + corner.y) / nz
				var profile := pow(maxf(0.0, sin(u * PI) * sin(v * PI)), 0.65)
				var variation := 0.76 + 0.13 * sin(u * 13.0 + v * 4.0 + seed_phase) + 0.09 * sin(v * 17.0 - u * 9.0)
				var y := profile * height * variation
				var color := Color("737f6e").lerp(Color("a2a88f"), clampf(y / height, 0.0, 1.0))
				color = color.lerp(Color("859079"), 0.20 + 0.15 * sin(u * 35.0 + v * 18.0))
				tool.set_color(color.srgb_to_linear())
				tool.add_vertex(center + Vector3((u - 0.5) * size.x, y, (v - 0.5) * size.y))
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var mesh := MeshInstance3D.new()
	mesh.name = "WoodedHillside"
	mesh.set_meta("terrain_surface", true)
	mesh.mesh = tool.commit()
	mesh.material_override = material
	add_child(mesh)


func _bank_height(x: float, z: float, side: float) -> float:
	var center := Vector3(-90.0, -8.0, -37.0) if side < 0.0 else Vector3(88.0, -8.0, -36.0)
	var size := Vector2(96.0, 140.0) if side < 0.0 else Vector2(88.0, 152.0)
	var height := 26.0 if side < 0.0 else 23.0
	var phase := 0.8 if side < 0.0 else 2.4
	var u := clampf((x - center.x) / size.x + 0.5, 0.0, 1.0)
	var v := clampf((z - center.z) / size.y + 0.5, 0.0, 1.0)
	var profile := pow(maxf(0.0, sin(u * PI) * sin(v * PI)), 0.65)
	return center.y + profile * height * (0.76 + 0.13 * sin(u * 13.0 + v * 4.0 + phase) + 0.09 * sin(v * 17.0 - u * 9.0))


func _make_trees() -> void:
	# p / shared meshes keep the wooded banks inexpensive and leave course silhouettes open.
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.10
	trunk_mesh.bottom_radius = 0.16
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.material = _standard(Color("5b5040"), 1.0)
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.0
	crown_mesh.bottom_radius = 1.0
	crown_mesh.height = 1.0
	crown_mesh.radial_segments = 7
	crown_mesh.material = _standard(Color("35574e"), 0.95)
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk_mesh
	trunks.instance_count = 40
	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.mesh = crown_mesh
	crowns.instance_count = 120
	for i: int in 40:
		var side := -1.0 if i < 20 else 1.0
		var u := float(i % 20) / 19.0
		var x := side * (68.0 + 10.0 * sin(u * 19.0) * sin(u * 7.0))
		var z := 13.0 - u * 110.0
		var y := _bank_height(x, z, side)
		var h := 4.0 + 2.0 * (0.5 + 0.5 * sin(u * 91.0))
		trunks.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, h, 1.0)), Vector3(x, y + h * 0.5, z)))
		for j: int in 3:
			var width := (1.7 - float(j) * 0.35) * h / 5.0
			var origin := Vector3(x, y + h * (0.55 + float(j) * 0.20), z)
			crowns.set_instance_transform(i * 3 + j, Transform3D(Basis.IDENTITY.scaled(Vector3(width, h * 0.55, width)), origin))
	for entry: MultiMesh in [trunks, crowns]:
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = entry
		add_child(instance)


func _define_routes() -> void:
	routes["safe"] = [
		_point(Vector3(2.5, 12.0, 3.0)), _point(Vector3(-9.0, 12.0, 3.0)),
		_point(Vector3(-9.0, 11.75, -1.0)), _point(Vector3(-9.0, 8.0, -17.8)),
		_point(Vector3(-16.0, 8.0, -18.0)), _point(Vector3(-16.0, 7.75, -15.0)),
		_point(Vector3(-16.0, 4.0, 1.0)), _point(Vector3(-22.0, 4.0, 1.0)),
		_point(Vector3(-22.0, 4.0, -40.8)), _point(Vector3(-9.0, 4.0, -41.0)),
		_point(Vector3(-9.0, 4.0, -58.8)), _point(finish_position),
	]
	# p / run normally first, then crouch at the chute mouth; do not understate launch speed.
	var launch: Array = [
		_point(Vector3(2.5, 12.0, 0.8), 0.45),
		_point(Vector3(2.5, 7.0, -20.0), 1.0, true),
		_point(Vector3(2.5, 6.0, -24.8), 0.55, true, true),
		_point(Vector3(2.9, 4.0, -41.0), 1.8),
	]
	routes["fast"] = launch.duplicate(true)
	routes["fast"].append_array([
		_point(Vector3(4.0, 4.0, -48.1), 0.7),
		_point(Vector3(7.0, 4.0, -52.5), 0.7),
		_point(Vector3(10.0, 4.0, -56.8), 0.9), _point(finish_position),
	])
	routes["brake"] = launch.duplicate(true)
	routes["brake"].append_array([
		_point(Vector3(-9.0, 4.0, -43.0)), _point(Vector3(-9.0, 4.0, -58.8)), _point(finish_position),
	])
	# no jump, no slide: a short running takeoff drops into the channel, with no reset.
	routes["recovery"] = [
		_point(Vector3(2.5, 12.0, 1.0)), _point(Vector3(2.5, 7.0, -20.0)),
		_point(Vector3(2.5, 1.5, -30.7), 1.0),
		_point(Vector3(12.0, 1.5, -28.0)), _point(Vector3(12.0, 4.0, -40.8)),
		_point(Vector3(3.0, 4.0, -41.0)), _point(Vector3(-9.0, 4.0, -41.0)),
		_point(Vector3(-9.0, 4.0, -58.8)), _point(finish_position),
	]


func _point(pos: Vector3, radius: float = 1.0, crouch: bool = false, jump: bool = false) -> Dictionary:
	return {"pos": pos, "radius": radius, "crouch": crouch, "jump": jump}


func _slab(node_name: String, top: Vector3, size: Vector2, thickness: float, material: String = "concrete") -> void:
	_solid(node_name, top - Vector3.UP * thickness * 0.5, Vector3(size.x, thickness, size.y), material)
	# p / profiled edges and a recessed shadow line give concrete a made surface.
	if material in ["concrete", "old_concrete"]:
		for side: float in [-1.0, 1.0]:
			_box(top + Vector3(0.0, -0.055, side * size.y * 0.5), Vector3(size.x, 0.11, 0.13), material)
			_box(top + Vector3(side * size.x * 0.5, -0.055, 0.0), Vector3(0.13, 0.11, size.y), material)
			_box(top + Vector3(0.0, -0.16, side * (size.y * 0.5 + 0.002)), Vector3(size.x, 0.035, 0.025), "shadow")
			_box(top + Vector3(side * (size.x * 0.5 + 0.002), -0.16, 0.0), Vector3(0.025, 0.035, size.y), "shadow")


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
		body.set_meta("surface", "metal" if material in ["steel", "grate", "pipe"] else "concrete")
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
	body.set_meta("surface", "metal" if material in ["steel", "grate", "pipe"] else "concrete")
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


func _wheel(center: Vector3, radius: float, material: String, horizontal: bool = false) -> Node3D:
	var first_child := get_child_count()
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

	var members := get_children().slice(first_child)
	var pivot := Node3D.new()
	pivot.name = "ValveWheel"
	pivot.set_meta("moving_geometry", true)
	pivot.position = center
	add_child(pivot)
	for member: Node in members:
		member.reparent(pivot, true)
	return pivot


func _water(node_name: String, center: Vector3, size: Vector2, material: String) -> void:
	_water_surfaces.append({"bounds": Rect2(Vector2(center.x, center.z) - size * 0.5, size), "height": center.y})
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	instance.mesh = plane
	instance.position = center
	instance.material_override = _materials[material]
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

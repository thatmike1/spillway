extends RefCounted
## p / art pass over the built course: light, materials, landform, forest and the tower landmark.
## everything added here is visual only and sits on structures or terrain outside the running lines.

const BRICK_SHADER: Shader = preload("res://shaders/spillway_art_brick.gdshader")
const TERRAIN_SHADER: Shader = preload("res://shaders/spillway_art_terrain.gdshader")
const FINISH_PRESENTATION: Script = preload("res://scripts/spillway_finish_presentation.gd")
# p / the running area; no tree or ridge geometry is placed inside it.
const COURSE := Rect2(-48.0, -120.0, 92.0, 138.0)

var _level: Node3D
var _materials: Dictionary


func apply(level: Node3D) -> void:
	if level.has_meta("spillway_art_applied"):
		return
	level.set_meta("spillway_art_applied", true)
	_level = level
	_materials = level.get("_materials")
	_light()
	_retune_materials()
	_wet_bands()
	_fix_roof_overlap()
	_terrain()
	_horizon()
	_forest()
	_tower()
	_penstocks()
	_finish_bay()


func _light() -> void:
	var world := _level.find_child("SpillwayDaylight", false, false) as WorldEnvironment
	if world != null:
		var environment := world.environment
		var sky := environment.sky.sky_material as ProceduralSkyMaterial
		# deeper zenith against a pale haze horizon; the ground half matches the fog.
		sky.sky_top_color = Color("4f86b0")
		sky.sky_horizon_color = Color("cddbdc")
		sky.sky_curve = 0.16
		sky.ground_horizon_color = Color("b9cccf")
		sky.ground_bottom_color = Color("7c8f86")
		# cool sky fill keeps shade readable without flattening the sunlit faces.
		environment.ambient_light_color = Color("9db7cf")
		environment.ambient_light_energy = 0.46
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.tonemap_exposure = 1.0
		environment.tonemap_white = 5.0
		# distance haze separates the course, the banks and the far ridge into layers.
		environment.fog_light_color = Color("bfd0d4")
		environment.fog_light_energy = 1.0
		environment.fog_density = 0.0021
		environment.fog_aerial_perspective = 0.5
		environment.fog_sky_affect = 0.0
		environment.adjustment_enabled = true
		environment.adjustment_contrast = 1.06
		environment.adjustment_saturation = 1.08
	var sun := _level.find_child("LateMorningSun", false, false) as DirectionalLight3D
	if sun != null:
		# lower and warmer: longer shadows model piers, rails and housings.
		sun.rotation_degrees = Vector3(-39.0, -34.0, 0.0)
		sun.light_color = Color("ffe6c2")
		sun.light_energy = 1.32
		sun.shadow_blur = 0.6


func _retune_materials() -> void:
	# decks stay the lightest plane in view without clipping; walls sit a value step below.
	_concrete("concrete", Color("837f75"), Color("958f81"), 0.12)
	_concrete("old_concrete", Color("6f7369"), Color("838477"), 0.22)
	_concrete("wet_concrete", Color("6f7369"), Color("838477"), 0.22)
	_tint("steel", Color("26363a"), 0.48, 0.6)
	_tint("pipe", Color("3f5f63"), 0.45, 0.45)
	_tint("ochre", Color("d79a2b"), 0.62, 0.05)
	_tint("grate", Color("3b4644"), 0.7, 0.4)
	_tint("shadow", Color("22343a"), 0.35, 0.1)
	var water := _materials.get("water") as ShaderMaterial
	if water != null:
		water.set_shader_parameter("water_color", Color("21615e"))
	var reservoir := _materials.get("reservoir") as ShaderMaterial
	if reservoir != null:
		reservoir.set_shader_parameter("water_color", Color("3e7476"))
	var foam := _materials.get("foam_water") as ShaderMaterial
	if foam != null:
		foam.set_shader_parameter("water_color", Color("5f9c95"))
	# terracotta becomes coursed brick, shared by every housing, the filter house and the tower.
	var brick := ShaderMaterial.new()
	brick.shader = BRICK_SHADER
	brick.set_shader_parameter("brick_color", Color("9a5540"))
	brick.set_shader_parameter("mortar_color", Color("c4b49c"))
	brick.set_shader_parameter("cap_color", Color("9c978a"))
	var old_brick: Material = _materials.get("terracotta")
	_materials["terracotta"] = brick
	_swap_material(old_brick, brick)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("1d3640")
	glass.roughness = 0.12
	glass.metallic = 0.35
	_materials["art_glass"] = glass


func _concrete(key: String, wall: Color, deck: Color, weathering: float) -> void:
	var material := _materials.get(key) as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("wall_color", wall)
	material.set_shader_parameter("deck_color", deck)
	material.set_shader_parameter("weathering", weathering)


func _tint(key: String, color: Color, roughness: float, metallic: float) -> void:
	var material := _materials.get(key) as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic


func _swap_material(from: Material, to: Material) -> void:
	if from == null:
		return
	for node: Node in _level.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if geometry.material_override == from:
			geometry.material_override = to


func _wet_bands() -> void:
	# p / the outflow basin and the river each leave a moss line on the concrete standing in them.
	var source := _materials.get("old_concrete") as ShaderMaterial
	if source == null:
		return
	var basin: ShaderMaterial = source.duplicate()
	basin.set_shader_parameter("waterline", -5.73)
	var river: ShaderMaterial = source.duplicate()
	river.set_shader_parameter("waterline", -7.4)
	_materials["art_basin_wet"] = basin
	_materials["art_river_wet"] = river
	var basin_area := Rect2(-18.5, -104.5, 35.0, 43.0)
	for node: Node in _level.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.material_override != source or mesh.mesh == null:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		var footprint := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		if box.position.y < -5.73 and box.end.y > -5.6 and basin_area.intersects(footprint):
			mesh.material_override = basin
		elif box.position.y < -7.4 and box.end.y > -7.2:
			mesh.material_override = river


func _fix_roof_overlap() -> void:
	# the filter house top is coplanar with its roof slab; drop only the visual box 3 cm.
	var house := _level.find_child("FilterHouse", false, false)
	if house == null:
		return
	for child: Node in house.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null and mesh.mesh is BoxMesh:
			var box := (mesh.mesh as BoxMesh).duplicate() as BoxMesh
			box.size.y -= 0.06
			mesh.mesh = box
			mesh.position.y -= 0.03


func _terrain() -> void:
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	for node: Node in _level.find_children("*", "MeshInstance3D", true, false):
		if bool(node.get_meta("terrain_surface", false)):
			(node as MeshInstance3D).material_override = material


func _horizon() -> void:
	# p / a far ridge ring closes the valley; fog turns it into the bluest depth layer.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = [[175.0, -10.0, Color("566a52")], [300.0, 2.0, Color("5d7059")],
		[390.0, 34.0, Color("5f7468")], [470.0, 6.0, Color("6c7f78")]]
	var segments: int = 96
	var centre := Vector3(-5.0, 0.0, -50.0)
	for s: int in segments:
		for r: int in rings.size() - 1:
			var quad: Array[Vector3] = []
			var colors: Array[Color] = []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var angle := TAU * float(s + corner.x) / float(segments)
				var ring: Array = rings[r + corner.y]
				var swell := 1.0 + 0.45 * sin(angle * 3.0 + 0.7) + 0.25 * sin(angle * 7.0 + 2.1)
				var y: float = ring[1]
				if r + corner.y == 2:
					y *= swell
				var radius: float = ring[0] * (1.0 + 0.06 * sin(angle * 5.0))
				quad.append(centre + Vector3(cos(angle) * radius, y, sin(angle) * radius))
				colors.append(ring[2])
			for index: int in [0, 2, 1, 0, 3, 2]:
				tool.set_color(colors[index].srgb_to_linear())
				tool.add_vertex(quad[index])
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ridge := MeshInstance3D.new()
	ridge.name = "ArtFarRidge"
	ridge.mesh = tool.commit()
	ridge.material_override = material
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_level.add_child(ridge)


func _forest() -> void:
	# p / grouped conifers and broadleaf clumps on the actual terrain, two draw calls in all.
	var heights := _terrain_grid()
	if heights.is_empty():
		return
	var conifers: Array[Transform3D] = []
	var conifer_colors: Array[Color] = []
	var broadleaf: Array[Transform3D] = []
	var broadleaf_colors: Array[Color] = []
	var trunks: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1950
	var dark: Array[Color] = [Color("26402f"), Color("2f4a36"), Color("34503a"), Color("2b4536")]
	var light: Array[Color] = [Color("4f6a38"), Color("5c7440"), Color("6a7a42"), Color("47613a")]
	var groves: int = 0
	var attempts: int = 0
	while groves < 46 and attempts < 600:
		attempts += 1
		var centre := Vector2(rng.randf_range(-150.0, 150.0), rng.randf_range(-215.0, 70.0))
		if COURSE.grow(10.0).has_point(centre) or _wet(centre):
			continue
		groves += 1
		var count: int = rng.randi_range(5, 12)
		var spread: float = rng.randf_range(5.0, 11.0)
		for i: int in count:
			var p := centre + Vector2(rng.randfn(0.0, spread), rng.randfn(0.0, spread))
			if COURSE.grow(4.0).has_point(p) or _wet(p):
				continue
			var ground: float = _height_at(heights, p)
			if is_nan(ground):
				continue
			var tall: float = rng.randf_range(6.0, 11.0)
			# p / crowns have visible trunks rooted at the sampled terrain height.
			trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(tall * 0.025, tall * 0.65, tall * 0.025)), Vector3(p.x, ground + tall * 0.325, p.y)))
			trunk_colors.append(Color("51483a").srgb_to_linear())
			if rng.randf() < 0.68:
				for tier: int in 2:
					var width: float = tall * (0.30 - float(tier) * 0.08)
					var height: float = tall * (0.62 - float(tier) * 0.12)
					var y: float = ground + tall * (0.18 + float(tier) * 0.34) + height * 0.5
					conifers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(width, height, width)), Vector3(p.x, y, p.y)))
					conifer_colors.append(dark[rng.randi() % dark.size()].srgb_to_linear())
			else:
				var crown: float = tall * rng.randf_range(0.34, 0.45)
				var basis := Basis.IDENTITY.scaled(Vector3(crown, crown * 0.85, crown))
				broadleaf.append(Transform3D(basis, Vector3(p.x, ground + tall * 0.55, p.y)))
				broadleaf_colors.append(light[rng.randi() % light.size()].srgb_to_linear())
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 5
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.75
	trunk.bottom_radius = 1.0
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	_scatter("ArtTreeTrunks", trunk, trunks, trunk_colors)
	_scatter("ArtConiferBelt", cone, conifers, conifer_colors)
	_scatter("ArtBroadleafBelt", ball, broadleaf, broadleaf_colors)


func _scatter(label: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color]) -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for i: int in transforms.size():
		instances.set_instance_transform(i, transforms[i])
		instances.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = instances
	node.material_override = material
	_level.add_child(node)


func _wet(p: Vector2) -> bool:
	for surface: Dictionary in _level.get("_water_surfaces"):
		if (surface["bounds"] as Rect2).grow(3.0).has_point(p):
			return true
	return false


func _terrain_grid() -> Dictionary:
	# bucket terrain triangles into 8 m cells so each tree finds its ground in a few tests.
	var grid: Dictionary = {}
	for node: Node in _level.find_children("*", "MeshInstance3D", true, false):
		if not bool(node.get_meta("terrain_surface", false)):
			continue
		var mesh := node as MeshInstance3D
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		var pose := mesh.global_transform
		for i: int in range(0, faces.size(), 3):
			var tri: Array[Vector3] = [pose * faces[i], pose * faces[i + 1], pose * faces[i + 2]]
			var low := Vector2(minf(tri[0].x, minf(tri[1].x, tri[2].x)), minf(tri[0].z, minf(tri[1].z, tri[2].z)))
			var high := Vector2(maxf(tri[0].x, maxf(tri[1].x, tri[2].x)), maxf(tri[0].z, maxf(tri[1].z, tri[2].z)))
			for cx: int in range(floori(low.x / 8.0), floori(high.x / 8.0) + 1):
				for cz: int in range(floori(low.y / 8.0), floori(high.y / 8.0) + 1):
					var key := Vector2i(cx, cz)
					if not grid.has(key):
						grid[key] = []
					grid[key].append(tri)
	return grid


func _height_at(grid: Dictionary, p: Vector2) -> float:
	var best: float = NAN
	for tri: Array in grid.get(Vector2i(floori(p.x / 8.0), floori(p.y / 8.0)), []):
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(d) < 0.0001:
			continue
		var u := ((b.z - c.z) * (p.x - c.x) + (c.x - b.x) * (p.y - c.z)) / d
		var v := ((c.z - a.z) * (p.x - c.x) + (a.x - c.x) * (p.y - c.z)) / d
		var w := 1.0 - u - v
		if u < -0.001 or v < -0.001 or w < -0.001:
			continue
		var y := a.y * u + b.y * v + c.y * w
		if is_nan(best) or y > best:
			best = y
	return best


func _tower() -> void:
	# p / the destination reads as a made building: plinth, pilasters, glazing, cornice and crane.
	var x0 := 20.0
	var x1 := 28.0
	var z0 := -84.0
	var z1 := -74.0
	# a flush rusticated plinth stands on the walkable foundation; nothing projects below head height.
	_box(Vector3(24.0, -1.75, z0 - 0.03), Vector3(8.06, 2.5, 0.06), "concrete")
	_box(Vector3(x1 + 0.03, -1.75, -79.0), Vector3(0.06, 2.5, 10.06), "concrete")
	_box(Vector3(x0 - 0.03, -1.75, -81.25), Vector3(0.06, 2.5, 5.5), "concrete")
	for corner: Vector2 in [Vector2(x1, z0), Vector2(x0, z0), Vector2(x1, z1), Vector2(x0, z1)]:
		var base: float = 5.0 if corner == Vector2(x0, z1) else -0.5
		_box(Vector3(corner.x, (base + 15.9) * 0.5, corner.y), Vector3(0.75, 15.9 - base, 0.75), "concrete")
	# tall glazed bays on the three faces seen from the roof, the gantry and the finish.
	for along: float in [-2.4, 0.0, 2.4]:
		_bay(Vector3(x0 - 0.04, 0.0, -79.0 + along), Vector3(-1, 0, 0))
		_bay(Vector3(24.0 + along, 0.0, z0 - 0.04), Vector3(0, 0, -1))
		_bay(Vector3(x1 + 0.04, 0.0, -79.0 + along), Vector3(1, 0, 0))
	# stepped cornice under the existing crown.
	_box(Vector3(24.0, 15.55, -79.0), Vector3(8.5, 0.3, 10.5), "concrete")
	_box(Vector3(24.0, 15.25, -79.0), Vector3(8.2, 0.12, 10.2), "shadow")
	_box(Vector3(24.0, 16.85, -79.0), Vector3(9.0, 0.7, 0.2), "concrete")
	# the roof head-house and a cantilever crane mark the finish from the crest.
	_box(Vector3(24.0, 17.85, -81.0), Vector3(5.0, 2.7, 4.6), "terracotta")
	_box(Vector3(24.0, 19.3, -81.0), Vector3(5.6, 0.25, 5.2), "concrete")
	_box(Vector3(22.2, 17.4, -78.67), Vector3(1.0, 1.9, 0.06), "steel")
	_box(Vector3(25.4, 18.0, -78.67), Vector3(1.6, 0.9, 0.06), "art_glass")
	_box(Vector3(26.0, 18.4, -76.0), Vector3(0.45, 3.8, 0.45), "steel")
	_beam(Vector3(26.0, 20.4, -79.5), Vector3(26.0, 20.4, -68.0), 0.42, "ochre")
	_beam(Vector3(26.0, 20.4, -79.5), Vector3(26.0, 22.6, -76.0), 0.12, "steel")
	_beam(Vector3(26.0, 22.6, -76.0), Vector3(26.0, 20.6, -68.2), 0.09, "steel")
	_beam(Vector3(26.0, 20.2, -69.0), Vector3(26.0, 16.6, -69.0), 0.035, "steel")
	_box(Vector3(26.0, 16.4, -69.0), Vector3(0.35, 0.45, 0.35), "ochre")
	# the lower pump hall gets a cornice and west windows, all above reach.
	_box(Vector3(19.0, 4.8, -69.42), Vector3(11.2, 0.35, 0.18), "concrete")
	_box(Vector3(13.42, 4.8, -74.0), Vector3(0.18, 0.35, 9.2), "concrete")
	for z: float in [-71.6, -74.0, -76.4]:
		_box(Vector3(13.46, 2.2, z), Vector3(0.06, 3.4, 1.3), "art_glass")
		_box(Vector3(13.42, 2.2, z), Vector3(0.08, 3.4, 0.08), "steel")
		_box(Vector3(13.42, 2.2, z), Vector3(0.08, 0.08, 1.3), "steel")
		_box(Vector3(13.38, 0.42, z), Vector3(0.18, 0.12, 1.6), "concrete")


func _bay(at: Vector3, out: Vector3) -> void:
	var across := Vector3(abs(out.z), 0, abs(out.x))
	var depth := Vector3(abs(out.x), 0, abs(out.z))
	var centre := Vector3(at.x, 10.0, at.z)
	_box(centre, across * 1.3 + depth * 0.06 + Vector3.UP * 8.0, "art_glass")
	_box(centre + out * 0.02, across * 0.07 + depth * 0.08 + Vector3.UP * 8.0, "steel")
	for row: int in 5:
		_box(centre + out * 0.02 + Vector3.UP * (-3.2 + float(row) * 1.6), across * 1.3 + depth * 0.08 + Vector3.UP * 0.07, "steel")
	_box(centre + out * 0.06 - Vector3.UP * 4.1, across * 1.6 + depth * 0.2 + Vector3.UP * 0.14, "concrete")


func _penstocks() -> void:
	# p / flange rings and a thrust block turn the two crest penstocks into fabricated pipe.
	var rings: Array[Transform3D] = []
	for x: float in [11.5, 14.0]:
		for leg: Array in [[Vector3(x, 10.0, 5.0), Vector3(x, -3.0, -18.0)], [Vector3(x, -3.0, -18.0), Vector3(x, -3.0, -57.0)]]:
			var a: Vector3 = leg[0]
			var b: Vector3 = leg[1]
			var axis := (b - a).normalized()
			var count: int = floori(a.distance_to(b) / 4.5)
			for i: int in range(1, count + 1):
				var basis := Basis(Quaternion(Vector3.UP, axis)).scaled(Vector3(0.66, 0.2, 0.66))
				rings.append(Transform3D(basis, a.lerp(b, float(i) / float(count + 1))))
	var ring := CylinderMesh.new()
	ring.top_radius = 1.0
	ring.bottom_radius = 1.0
	ring.height = 1.0
	ring.radial_segments = 16
	ring.rings = 1
	var colors: Array[Color] = []
	for i: int in rings.size():
		colors.append((_materials["steel"] as StandardMaterial3D).albedo_color.srgb_to_linear())
	_scatter("ArtPenstockFlanges", ring, rings, colors)
	_level.call("_box", Vector3(12.75, -3.4, -18.0), Vector3(4.6, 2.6, 3.4), "old_concrete", true, "PenstockThrustBlock")
	_level.call("_box", Vector3(12.75, -2.0, -18.0), Vector3(4.9, 0.25, 3.7), "concrete", true, "PenstockThrustCap")


func _finish_bay() -> void:
	# p / only the full course has the guarded wheel bay this dresses.
	if not _level.has_meta("spillway_course_built"):
		return
	var bay: Node3D = FINISH_PRESENTATION.new()
	_level.add_child(bay)
	bay.call("build", _level, _materials)


func _box(center: Vector3, size: Vector3, material: String) -> void:
	_level.call("_box", center, size, material)


func _beam(a: Vector3, b: Vector3, thickness: float, material: String) -> void:
	_level.call("_beam", a, b, thickness, material)

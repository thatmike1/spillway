extends RefCounted
## the outer pump reach shares the estuary, with broad open sky and a transverse pump landmark.
const BASE := preload("res://scripts/art/sluice_six_art.gd")
const MATERIALS := preload("res://scripts/art/sluice_six_materials.gd")
const ESTUARY := preload("res://scripts/art/sluice_six_estuary.gd")
const CONTOURS := preload("res://scripts/r17_contours.gd")
const COAST := preload("res://scripts/art/outer_reach_coast.gd")
const INK := preload("res://scripts/art/outer_reach_ink.gd")
const SKY_LIGHT := preload("res://scripts/look/sky_light.gd")
static func dress(level: Node3D) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var painted := ShaderMaterial.new()
	painted.shader = load("res://shaders/look/sky.gdshader")
	painted.set_shader_parameter("panorama",load("res://assets/look/cloud-sky.png"))
	sky.sky_material = painted
	env.sky = sky
	env.sky_rotation = Vector3(0,PI+0.6,0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cdd4d3")
	env.ambient_light_energy = 0.4
	world.environment = env
	level.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14,-145,0)
	sun.light_color = Color("ffdbad")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0
	level.add_child(sun)
	# lane 02's sky and light table owns the hour, sun and fill; it repaints this map's own sky.
	if SKY_LIGHT.has_map("outer-reach"):
		SKY_LIGHT.apply(env, sun, "outer-reach")
	for child: Node in level.get_children():
		if child is MeshInstance3D:
			var service: bool = str(child.name).contains("shore_") or str(child.name).contains("control_house") or str(child.name).contains("service_gallery")
			# decks are shell-white rather than peach under the low warm sun.
			# route decks carry cast-slab joints at a working spacing and lane 07's tide staining.
			if service:
				child.material_override = MATERIALS.concrete(Color("b6bcae"),Color("798f96"),false,child.get_aabb())
			else:
				child.material_override = MATERIALS.concrete(Color("b0ada5"),Color("7d959c"),true,child.get_aabb(),Vector2(0.34,0.66),Vector2(6.0,9.0),0.9)
	BASE._box(level,"outer_water",Vector3(-120,-3,-140),Vector3(900,0.1,800),Color("598a90"))
	var footprints := PackedVector4Array()
	for support: Vector4 in level.supports:
		footprints.append(support)
	level.get_node("outer_water").material_override = MATERIALS.water(footprints)
	ESTUARY.dress(level)
	COAST.dress(level)
	for child: Node in level.get_children():
		if child is MeshInstance3D and str(child.name).contains("quay_curb_"):
			# the quay curbs are a side edge, not a takeoff: pale stone, leaving orange to the lips.
			child.material_override = BASE._material(Color("cfc8b8"))
	BASE._pile_bearings(level)
	var x: float = level.spawn.origin.x
	var z: float = level.finish_position.z-8.0
	var housing := MeshInstance3D.new()
	housing.name = "TidalPumpHousing"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 3.3
	cylinder.bottom_radius = 3.3
	cylinder.height = 3.0
	cylinder.radial_segments = 32
	housing.mesh = cylinder
	housing.rotation.x = PI*0.5
	housing.position = Vector3(x,11,z+1)
	housing.material_override = BASE._material(Color("496b77"))
	level.add_child(housing)
	var rim := MeshInstance3D.new()
	rim.name = "PumpFrontFlange"
	var torus := TorusMesh.new()
	torus.inner_radius = 2.85
	torus.outer_radius = 3.4
	torus.rings = 40
	torus.ring_segments = 8
	rim.mesh = torus
	rim.rotation.x = PI*0.5
	rim.position = Vector3(x,11,z+2.6)
	rim.material_override = BASE._material(Color("a9b7b4"))
	level.add_child(rim)
	# a dark throat behind the blades gives the wheel depth instead of a flat emblem.
	var throat := MeshInstance3D.new()
	throat.name = "PumpThroat"
	var plate := CylinderMesh.new()
	plate.top_radius = 2.86
	plate.bottom_radius = 2.86
	plate.height = 0.06
	plate.radial_segments = 32
	throat.mesh = plate
	throat.rotation.x = PI*0.5
	throat.position = Vector3(x,11,z+2.54)
	throat.material_override = BASE._material(Color("22343a"))
	level.add_child(throat)
	BASE._box(level,"pump_spindle",Vector3(x,11,z+2.9),Vector3(1.1,1.1,0.5),Color("809a9e"))
	for i: int in 6:
		var angle := TAU*i/6.0
		var blade := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.0,0.25,0.16)
		blade.mesh = box
		blade.rotation.z = angle+0.18
		blade.position = Vector3(x+cos(angle)*1.6,11+sin(angle)*1.6,z+2.65)
		blade.material_override = BASE._material(Color("a9b7b4"))
		level.add_child(blade)
	BASE._box(level,"pump_outlet",Vector3(x+4.8,11,z+1),Vector3(3.2,1.3,1.3),Color("59747d"),true)
	BASE._box(level,"pump_bed_back_trim",Vector3(x,7.12,z-3.01),Vector3(14,0.16,0.12),Color("3c555e"))
	for side: int in [-1,1]:
		BASE._box(level,"pump_riser_%s" % side,Vector3(x+side*6.5,4,z),Vector3(1.3,7,3.5),Color("59747d"),true)
	BASE._box(level,"pump_discharge",Vector3(x+6.5,5.5,z+2),Vector3(2.2,11,2.2),Color("59747d"),true)
	# the pump portal carries no map title; the finish board below is the only lettering.
	var font: Font = load("res://assets/ui/fonts/BricolageGrotesque-variable.ttf")
	BASE._box(level,"finish_board",Vector3(x,4.5,z+5.05),Vector3(5.2,1.2,0.1),Color("3c555e"))
	for side: int in [-1,1]:
		BASE._box(level,"finish_hanger_%s" % side,Vector3(x+side*2,6.1,z+5.05),Vector3(0.05,2,0.05),Color("3c555e"))
	var finish := Label3D.new()
	finish.text = "FINISH"
	finish.font = font
	finish.font_size = 56
	finish.pixel_size = 0.012
	finish.outline_size = 0
	finish.position = Vector3(x,4.5,z+5.12)
	level.add_child(finish)
	BASE._box(level,"finish_line",Vector3(x,0.015,level.finish_bounds.end.z),Vector3(18,0.02,0.16),Color("3c5156"))
	# one control building, its gallery and shore causeway explain the pump's service access.
	BASE._box(level,"house_coping",Vector3(-200,13.2,-207),Vector3(14.6,0.4,20.6),Color("bfc4b4"),true)
	BASE._box(level,"house_south_windows",Vector3(-200,7.2,-196.96),Vector3(11,1.6,0.08),Color("3c626c"))
	BASE._box(level,"house_west_windows",Vector3(-207.04,7.2,-207),Vector3(0.08,1.6,16),Color("3c626c"))
	for post_x: float in [-204,-200,-196]:
		BASE._box(level,"house_mullion_%s" % post_x,Vector3(post_x,7.2,-196.89),Vector3(0.10,1.6,0.12),Color("92a5a5"))
	BASE._box(level,"pump_bank_connection",Vector3(-210.25,11,z+1),Vector3(6.5,1.3,1.3),Color("59747d"),true)
	for rail_z: float in [z-1.45,z+1.45]:
		for post_x: float in [-213.5,-210.5,-207.5]:
			BASE._box(level,"gallery_post_%s_%s" % [post_x,rail_z],Vector3(post_x,7.5,rail_z),Vector3(0.08,1,0.08),Color("465e66"))
		BASE._box(level,"gallery_rail_%s" % rail_z,Vector3(-210.5,8,rail_z),Vector3(7,0.08,0.08),Color("465e66"))
	for rail_z: float in [-213.7,-200.3]:
		for i: int in 9:
			BASE._box(level,"causeway_post_%s_%s" % [rail_z,i],Vector3(-193+i*5.5,1.6,rail_z),Vector3(0.10,1.2,0.10),Color("465e66"))
		BASE._box(level,"causeway_rail_%s" % rail_z,Vector3(-171.5,2.2,rail_z),Vector3(47,0.10,0.10),Color("465e66"))
	var contours := CONTOURS.new()
	var drawn := contours.build(level,false)
	_single_band_lips(drawn, level)
	level.add_child(drawn)
	INK.dress(level)

static func _single_band_lips(root: Node3D, level: Node3D) -> void:
	# only the takeoff edge carries orange here: one band on the deck top. the shared lip's
	# vertical face read as a second band under the deck's ink edge, and the receiving lip of the
	# next deck read as another band beyond it.
	var lips := root.get_node_or_null("JumpLips") as MeshInstance3D
	if lips == null or not lips.mesh is ArrayMesh:
		return
	var lands: Array[Vector3] = []
	for gap: Dictionary in level.get("jump_gaps"):
		if gap.get("land") is Vector3:
			lands.append(gap.land)
	var arrays: Array = (lips.mesh as ArrayMesh).surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var top := PackedVector3Array()
	var up := PackedVector3Array()
	# each lip is two triangles of top band followed by two of vertical face.
	for i: int in range(0, points.size() - 5, 6):
		if normals[i].y < 0.5:
			continue
		var a := points[i]
		var b := points[i+1]
		var receiving := false
		for land: Vector3 in lands:
			var nearest := Geometry3D.get_closest_point_to_segment(land, a, b)
			if Vector2(nearest.x - land.x, nearest.z - land.z).length() < 0.6 and absf(nearest.y - land.y) < 0.6:
				receiving = true
		if receiving:
			continue
		for k: int in 6:
			top.append(points[i+k])
			up.append(Vector3.UP)
	var kept := []
	kept.resize(Mesh.ARRAY_MAX)
	kept[Mesh.ARRAY_VERTEX] = top
	kept[Mesh.ARRAY_NORMAL] = up
	var mesh := ArrayMesh.new()
	if not top.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, kept)
	lips.mesh = mesh

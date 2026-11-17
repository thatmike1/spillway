extends RefCounted
## the outer pump reach shares the estuary, with broad open sky and a transverse pump landmark.
const BASE := preload("res://scripts/art/sluice_six_art.gd")
const MATERIALS := preload("res://scripts/art/sluice_six_materials.gd")
const ESTUARY := preload("res://scripts/art/sluice_six_estuary.gd")
const CONTOURS := preload("res://scripts/r17_contours.gd")
const COAST := preload("res://scripts/art/outer_reach_coast.gd")
const INK := preload("res://scripts/art/outer_reach_ink.gd")
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
	for child: Node in level.get_children():
		if child is MeshInstance3D:
			var service: bool = str(child.name).contains("shore_") or str(child.name).contains("control_house") or str(child.name).contains("service_gallery")
			child.material_override = MATERIALS.concrete(Color("b6bcae") if service else Color("c8c4b8"),Color("798f96") if service else Color("6e8590"),not service,child.get_aabb())
	BASE._box(level,"outer_water",Vector3(-120,-3,-140),Vector3(900,0.1,800),Color("598a90"))
	var footprints := PackedVector4Array()
	for support: Vector4 in level.supports:
		footprints.append(support)
	level.get_node("outer_water").material_override = MATERIALS.water(footprints)
	ESTUARY.dress(level)
	COAST.dress(level)
	for child: Node in level.get_children():
		if child is MeshInstance3D and str(child.name).contains("quay_curb_"):
			child.material_override = BASE._material(Color("bd653e"))
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
	var nameplate := Label3D.new()
	nameplate.text = "OUTER REACH"
	nameplate.font = load("res://assets/ui/fonts/BricolageGrotesque-variable.ttf")
	nameplate.font_size = 64
	nameplate.pixel_size = 0.022
	nameplate.outline_size = 0
	nameplate.modulate = Color("f2e8cc")
	nameplate.position = Vector3(x,19,z+5.02)
	level.add_child(nameplate)
	BASE._box(level,"finish_board",Vector3(x,4.5,z+5.05),Vector3(5.2,1.2,0.1),Color("3c555e"))
	for side: int in [-1,1]:
		BASE._box(level,"finish_hanger_%s" % side,Vector3(x+side*2,6.1,z+5.05),Vector3(0.05,2,0.05),Color("3c555e"))
	var finish := Label3D.new()
	finish.text = "FINISH"
	finish.font = nameplate.font
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
	level.add_child(contours.build(level,false))
	INK.dress(level)

extends RefCounted
const CONTOURS := preload("res://scripts/r17_contours.gd")
## original procedural architecture; no imported reference or concept assets.
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
	env.sky_rotation = Vector3(0,PI,0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8e4de")
	env.ambient_light_energy = 0.65
	world.environment = env
	level.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32,-35,0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	level.add_child(sun)
	for child: Node in level.get_children():
		if child is MeshInstance3D:
			child.material_override = _concrete()
	_box(level,"tidal_water",Vector3(0,-3,-70),Vector3(350,0.1,450),Color("598a90"))
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/look/water.gdshader")
	level.get_node("tidal_water").material_override = water
	# one connected waterworks: banks, section abutments, a service bridge and the spill tower.
	for side: int in [-1,1]:
		_box(level,"bank_%d" % side,Vector3(side*19,-1,-74),Vector3(8,12,184),Color("687b7a"),true)
		_box(level,"bank_cap_%d" % side,Vector3(side*19,5.1,-74),Vector3(8.2,0.25,184),Color("bcbdaa"))
		for z: float in [-14,-52,-97,-132]:
			_box(level,"abutment_%d_%d" % [side,int(z)],Vector3(side*14.8,0,z),Vector3(2.4,12,4.2),Color("728681"),true)
	_box(level,"service_bridge",Vector3(0,6.5,-52),Vector3(32,1,4.2),Color("7d8d87"),true)
	var tower_z: float = level.finish_position.z - 15.0
	_box(level,"tower_body",Vector3(0,7.5,tower_z),Vector3(12,29,10),Color("7d8d87"),true)
	for side: int in [-1,1]:
		_box(level,"tower_leg_%d" % side,Vector3(side*7,10,tower_z),Vector3(2,34,10),Color("7d8d87"),true)
	_box(level,"tower_crown",Vector3(0,27,tower_z),Vector3(16,2,10),Color("c7c8b4"),true)
	var number := Label3D.new()
	number.name = "TowerNumber"
	number.text = "06"
	number.font = load("res://assets/ui/fonts/BricolageGrotesque-variable.ttf")
	number.font_size = 72
	number.pixel_size = 0.08
	number.modulate = Color("d2cfb7")
	number.outline_size = 0
	number.position = Vector3(0,14,tower_z+5.015)
	level.add_child(number)
	# the established contour builder inks actual visible boundaries and paints only jump lips.
	level.add_child(CONTOURS.new().build(level,true))
static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.94
	return m
static func _box(level: Node3D, id: String, at: Vector3, size: Vector3, color: Color, structural: bool = false) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = _concrete(color.lightened(0.15),color) if structural else _material(color)
	level.add_child(mesh)

static func _concrete(top: Color = Color("d7d4bc"), side: Color = Color("627d7b")) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/look/surface.gdshader")
	material.set_shader_parameter("top_color",top)
	material.set_shader_parameter("side_color",side)
	material.set_shader_parameter("wear",load("res://assets/look/painted-wear.png"))
	material.set_shader_parameter("wear_amount",0.32)
	material.set_shader_parameter("deck",1.0)
	return material

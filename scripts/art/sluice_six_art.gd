extends RefCounted
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
	# the retaining banks and tower form one supported civil structure around the race.
	for side: int in [-1,1]:
		_box(level,"bank_%d" % side,Vector3(side*19,-1,-74),Vector3(8,12,184),Color("687b7a"))
		_box(level,"bank_cap_%d" % side,Vector3(side*19,5.1,-74),Vector3(8.2,0.25,184),Color("bcbdaa"))
		_box(level,"tower_leg_%d" % side,Vector3(side*8,10,level.finish_position.z-4),Vector3(4,34,12),Color("7d8d87"))
	_box(level,"tower_crown",Vector3(0,26,level.finish_position.z-4),Vector3(20,3,12),Color("c7c8b4"))
	for d: Dictionary in level.decks:
		for z: float in [d.near,d.far]:
			_box(level,"lip_%s_%s" % [d.id,z],Vector3(d.x,0.012,z),Vector3(d.width,0.025,0.12),Color("bd743f"))
static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.94
	return m
static func _box(level: Node3D, id: String, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = _material(color)
	level.add_child(mesh)

static func _concrete() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/look/surface.gdshader")
	material.set_shader_parameter("top_color",Color("d7d4bc"))
	material.set_shader_parameter("side_color",Color("627d7b"))
	material.set_shader_parameter("wear",load("res://assets/look/painted-wear.png"))
	material.set_shader_parameter("wear_amount",0.32)
	material.set_shader_parameter("deck",1.0)
	return material

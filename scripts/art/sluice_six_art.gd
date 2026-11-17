extends RefCounted
const MATERIALS := preload("res://scripts/art/sluice_six_materials.gd")
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
	env.ambient_light_energy = 0.38
	world.environment = env
	level.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32,-35,0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 0.70
	sun.shadow_enabled = true
	level.add_child(sun)
	for child: Node in level.get_children():
		if child is MeshInstance3D:
			child.material_override = MATERIALS.concrete(Color("c8c3ad"),Color("4d6873"),true)
	_box(level,"tidal_water",Vector3(0,-3,-70),Vector3(350,0.1,450),Color("598a90"))
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/look/water.gdshader")
	level.get_node("tidal_water").material_override = water
	# one connected waterworks: banks, section abutments, a service bridge and the spill tower.
	# submerged bank foundations connect the works; the estuary side stays open to the horizon.
	for side: int in [-1,1]:
		_box(level,"bank_footing_%d" % side,Vector3(side*19,-5.6,-74),Vector3(8,4.8,184),Color("687b7a"),true)
		for z: float in [-14,-52,-97,-132]:
			_box(level,"abutment_%d_%d" % [side,int(z)],Vector3(side*14.8,0,z),Vector3(2.4,12,4.2),Color("858b82"),true)
	for span: Vector2 in [Vector2(8,-22),Vector2(-42,-76),Vector2(-96,-130),Vector2(-144,-166)]:
		var middle := (span.x+span.y)*0.5
		var length := span.x-span.y
		_box(level,"east_bank_%d" % int(middle),Vector3(19,-1,middle),Vector3(8,12,length),Color("858b82"),true)
		_box(level,"east_cap_%d" % int(middle),Vector3(19,5.1,middle),Vector3(8.2,0.25,length),Color("b5b4a1"))
	_box(level,"service_bridge",Vector3(0,6.5,-52),Vector3(32,1,4.2),Color("7d8d87"),true)
	var tower_z: float = level.finish_position.z - 15.0
	_box(level,"tower_body",Vector3(0,16,tower_z),Vector3(12,12,10),Color("969887"),true)
	for side: int in [-1,1]:
		_box(level,"tower_leg_%d" % side,Vector3(side*7,10,tower_z),Vector3(2,34,10),Color("969887"),true)
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
	var contours := CONTOURS.new()
	level.add_child(contours.build(level,true))
	# thicker near contours keep the small landing silhouettes visible at running height.
	var edge_lines := CONTOURS.new()
	edge_lines.lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	for d: Dictionary in level.decks:
		var x0: float = d.x-d.width*0.5
		var x1: float = d.x+d.width*0.5
		var corners: Array[Vector3] = [Vector3(x0,0.02,d.near),Vector3(x1,0.02,d.near),Vector3(x1,0.02,d.far),Vector3(x0,0.02,d.far)]
		for i: int in 4:
			edge_lines.line(corners[i],corners[(i+1)%4],0.018)
	var ink := MeshInstance3D.new()
	ink.name = "LandingInk"
	ink.mesh = edge_lines.lines.commit()
	var ink_material := ShaderMaterial.new()
	ink_material.shader = load("res://shaders/look/ink.gdshader")
	ink.material_override = ink_material
	ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(ink)
	var finish_z: float = level.finish_bounds.end.z
	_box(level,"finish_line",Vector3(0,0.015,finish_z),Vector3(14,0.02,0.16),Color("3c5156"))
	var finish := Label3D.new()
	finish.name = "FinishStencil"
	finish.text = "FINISH"
	finish.font = number.font
	finish.font_size = 48
	finish.pixel_size = 0.025
	finish.outline_size = 0
	finish.modulate = Color("3c5156")
	finish.rotation.x = -PI*0.5
	finish.position = Vector3(0,0.028,finish_z-1.6)
	level.add_child(finish)
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
	mesh.material_override = MATERIALS.concrete(color.lightened(0.15),color) if structural else _material(color)
	level.add_child(mesh)

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
	env.ambient_light_color = Color("cdd4d3")
	env.ambient_light_energy = 0.52
	world.environment = env
	level.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32,-35,0)
	sun.light_color = Color("fff5e7")
	sun.light_energy = 0.48
	sun.shadow_enabled = true
	level.add_child(sun)
	for child: Node in level.get_children():
		if child is MeshInstance3D:
			child.material_override = MATERIALS.concrete(Color("c8c4b8"),Color("73818c"),true)
	_box(level,"tidal_water",Vector3(0,-3,-70),Vector3(350,0.1,450),Color("598a90"))
	level.get_node("tidal_water").material_override = MATERIALS.water()
	# one connected waterworks: banks, section abutments, a service bridge and the spill tower.
	# submerged bank foundations connect the works; the estuary side stays open to the horizon.
	for side: int in [-1,1]:
		_box(level,"bank_footing_%d" % side,Vector3(side*19,-5.6,-74),Vector3(8,4.8,184),Color("687b7a"),true)
		_box(level,"bridge_abutment_%d" % side,Vector3(side*14.8,0,-52),Vector3(2.4,12,4.2),Color("858b82"),true)
	for span: Vector2 in [Vector2(8,-22),Vector2(-42,-76),Vector2(-96,-130),Vector2(-144,-166)]:
		var middle := (span.x+span.y)*0.5
		var length := span.x-span.y
		_box(level,"east_bank_%d" % int(middle),Vector3(19,-1,middle),Vector3(8,12,length),Color("858b82"),true)
		_box(level,"east_cap_%d" % int(middle),Vector3(19,5.1,middle),Vector3(8.2,0.25,length),Color("b5b4a1"))
	_box(level,"service_bridge",Vector3(0,6.5,-52),Vector3(32,1,4.2),Color("7d8d87"),true)
	# a service bridge reads as an accessible walkway, with rails and steps onto the east bank.
	for z: float in [-54,-50]:
		for x: float in [-14,-7,0,7,14]:
			_box(level,"rail_post_%d_%d" % [int(x),int(z)],Vector3(x,7.45,z),Vector3(0.08,0.9,0.08),Color("384b4f"))
		_box(level,"bridge_rail_%d" % int(z),Vector3(0,7.9,z),Vector3(30,0.08,0.08),Color("384b4f"))
	for i: int in 8:
		var top := 6.8-0.2*i
		_box(level,"access_step_%d" % i,Vector3(16.15+0.3*i,(top+5.1)*0.5,-52),Vector3(0.3,top-5.1,3),Color("a5a797"),true)
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
	# the finish board hangs from the gate, leaving the opening and horizon visible below it.
	_box(level,"finish_board",Vector3(0,4,tower_z+5.08),Vector3(5.2,1.2,0.08),Color("384b4f"))
	for x: float in [-2.2,2.2]:
		_box(level,"board_hanger_%s" % x,Vector3(x,7.3,tower_z+5.08),Vector3(0.045,5.4,0.045),Color("384b4f"))
	var sign := Label3D.new()
	sign.name = "GateFinish"
	sign.text = "FINISH"
	sign.font = number.font
	sign.font_size = 56
	sign.pixel_size = 0.012
	sign.outline_size = 0
	sign.modulate = Color("e0dccb")
	sign.position = Vector3(0,4,tower_z+5.13)
	level.add_child(sign)
	# the established contour builder inks actual visible boundaries and paints only jump lips.
	var contours := CONTOURS.new()
	level.add_child(contours.build(level,false))
	# thicker near contours keep the small landing silhouettes visible at running height.
	var edge_lines := CONTOURS.new()
	edge_lines.lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	for d: Dictionary in level.decks:
		var x0: float = d.x-d.width*0.5
		var x1: float = d.x+d.width*0.5
		var corners: Array[Vector3] = [Vector3(x0,0.02,d.near),Vector3(x1,0.02,d.near),Vector3(x1,0.02,d.far),Vector3(x0,0.02,d.far)]
		for i: int in 4:
			edge_lines.line(corners[i],corners[(i+1)%4],0.018)
			edge_lines.line(corners[i],Vector3(corners[i].x,-3.1,corners[i].z),0.022)
	for child: Node in level.get_children():
		if not child is MeshInstance3D or not child.get_meta("sluice_structural",false):
			continue
		var size: Vector3 = child.mesh.size
		var points: Array[Vector3] = []
		for i: int in 8:
			points.append(child.position+Vector3(1 if (i & 1) != 0 else -1,1 if (i & 2) != 0 else -1,1 if (i & 4) != 0 else -1)*size*0.5)
		for i: int in 8:
			for axis: int in 3:
				var other := i ^ (1 << axis)
				if other > i:
					edge_lines.line(points[i],points[other],0.03)
	var ink := MeshInstance3D.new()
	ink.name = "LandingInk"
	ink.mesh = edge_lines.lines.commit()
	ink.material_override = MATERIALS.ink()
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
	mesh.set_meta("sluice_structural",structural)
	mesh.material_override = MATERIALS.concrete(color.lightened(0.15),color) if structural else _material(color)
	level.add_child(mesh)

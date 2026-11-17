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
			var support := str(child.name).begins_with("Mesh_support_") or str(child.name).begins_with("Mesh_service_")
			var top_color := Color("b7b7a5") if support else Color("c8c4b8")
			var side_color := Color("8a9186") if support else Color("73818c")
			if str(child.name).begins_with("Mesh_deck_pier_"):
				var index := int(str(child.name).trim_prefix("Mesh_deck_pier_"))
				if index >= 9:
					top_color = Color("d4cdbb") if index % 2 == 0 else Color("b4bdbc")
					side_color = Color("7a8c96") if index % 2 == 0 else Color("596d7a")
			child.material_override = MATERIALS.concrete(top_color,side_color,not support,child.get_aabb())
	_box(level,"tidal_water",Vector3(0,-3,-70),Vector3(350,0.1,450),Color("598a90"))
	var footprints := PackedVector4Array()
	for support: Vector4 in level.supports:
		footprints.append(support)
	for side: int in [-1,1]:
		footprints.append(Vector4(side*14.8,-52,1.2,2.1))
		footprints.append(Vector4(side*7,level.finish_position.z-15,1,5))
	level.get_node("tidal_water").material_override = MATERIALS.water(footprints)
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
	# bank service walks connect the retaining bays rather than leaving isolated wall slabs.
	for gap: Vector2 in [Vector2(-22,-42),Vector2(-76,-96),Vector2(-130,-144)]:
		var middle := (gap.x+gap.y)*0.5
		var length := gap.x-gap.y
		_box(level,"bank_link_%d" % int(middle),Vector3(16.2,4.7,middle),Vector3(2.4,0.6,length),Color("858b82"),true)
		for x: float in [15.1,17.3]:
			for z: float in [gap.x,middle,gap.y]:
				_box(level,"bank_rail_post_%s_%s" % [x,z],Vector3(x,5.5,z),Vector3(0.08,1,0.08),Color("384b4f"))
			_box(level,"bank_rail_%s_%s" % [x,middle],Vector3(x,6,middle),Vector3(0.08,0.08,length),Color("384b4f"))
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
	# metal guides show where the raised gate travels, fixed into its concrete piers and crosshead.
	for side: int in [-1,1]:
		_box(level,"gate_guide_%d" % side,Vector3(side*5.85,3.5,tower_z+5.12),Vector3(0.16,13,0.22),Color("384b4f"))
	_box(level,"gate_crosshead",Vector3(0,10,tower_z+5.12),Vector3(12,0.24,0.22),Color("384b4f"))
	_gate_control(level,tower_z)
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
	# lip paint and a small equipment stencil distinguish the optional inspection opening.
	for side: int in [-1,1]:
		_box(level,"inspection_lip_%d" % side,Vector3(4.675+side*0.555,1.8,-37.24),Vector3(0.06,3.6,0.014),Color("d95b30"))
	_box(level,"inspection_lip_top",Vector3(4.675,3.63,-37.24),Vector3(1.05,0.06,0.014),Color("d95b30"))
	var inspection := Label3D.new()
	inspection.name = "InspectionStencil"
	inspection.text = "INSPECTION"
	inspection.font = number.font
	inspection.font_size = 24
	inspection.pixel_size = 0.007
	inspection.outline_size = 0
	inspection.modulate = Color("364e54")
	inspection.position = Vector3(4.675,3.82,-37.23)
	level.add_child(inspection)
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
	for piece: Dictionary in level.manifest:
		if piece.role not in ["support","obstacle"]:
			continue
		var points: Array = piece.points
		for i: int in 4:
			edge_lines.line(points[i],points[(i+1)%4],0.018)
			edge_lines.line(points[i],points[i+4],0.018)
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
	mesh.material_override = MATERIALS.concrete(color.lightened(0.15),color,false,AABB(at-size*0.5,size)) if structural else _material(color)
	level.add_child(mesh)

static func _gate_control(level: Node3D, tower_z: float) -> void:
	# one connected drive: bearing plate, handwheel, shaft and the gate's left guide.
	var at := Vector3(-4.6,12,tower_z+5.34)
	var metal := _material(Color("384b53"))
	metal.metallic = 0.55
	metal.roughness = 0.6
	_box(level,"wheel_bearing",Vector3(at.x,at.y,tower_z+5.04),Vector3(0.72,0.72,0.1),Color("6c7977"))
	_box(level,"wheel_hub",Vector3(at.x,at.y,tower_z+5.2),Vector3(0.32,0.32,0.32),Color("384b53"))
	for x: float in [-0.26,0.26]:
		for y: float in [-0.26,0.26]:
			_box(level,"bearing_bolt_%s_%s" % [x,y],Vector3(at.x+x,at.y+y,tower_z+5.12),Vector3(0.09,0.09,0.1),Color("b9b6a2"))
	var ring := MeshInstance3D.new()
	ring.name = "GateHandwheel"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.70
	torus.outer_radius = 0.86
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = metal
	ring.rotation.x = PI*0.5
	ring.position = at
	level.add_child(ring)
	for i: int in 6:
		var angle := TAU*i/6.0
		var spoke := MeshInstance3D.new()
		spoke.name = "WheelSpoke_%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(0.70,0.08,0.1)
		spoke.mesh = box
		spoke.material_override = metal
		spoke.position = at+Vector3(cos(angle),sin(angle),0)*0.38
		spoke.rotation.z = angle
		level.add_child(spoke)
	_box(level,"wheel_drive",Vector3(-5.225,12,tower_z+5.17),Vector3(1.25,0.11,0.11),Color("384b53"))
	_box(level,"wheel_shaft",Vector3(-5.85,11,tower_z+5.17),Vector3(0.11,2,0.11),Color("384b53"))

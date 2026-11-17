extends Node3D
## scenery only: no physics bodies, anchors, checkpoints or movement callbacks.
var age := 0.0
var trolley: Node3D

func build(concrete: Material) -> void:
	position.z = -87.0
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://assets/maps/foundry/outline.gdshader")
	ink.set_shader_parameter("width",0.12)
	var steel := painted(Color("315c61"),ink)
	var trim := painted(Color("91a195"),ink)
	var dark := painted(Color("223d43"),ink)
	var panel := painted(Color("53777c"),ink)
	for x: float in [-27.0,27.0]:
		block(self,"foundation",Vector3(x,-7,0),Vector3(7,12,9),concrete)
		block(self,"tower",Vector3(x,19.25,0),Vector3(3.5,40.5,4),steel)
		block(self,"foot",Vector3(x,-0.6,0),Vector3(5,0.8,6),dark)
		var inner := x-signf(x)*9.0
		brace(self,Vector3(x,29.0,0),Vector3(inner,39.5,0),1.1,trim)
	block(self,"lintel",Vector3(0,40,0),Vector3(60,2.2,4),steel)
	for y: float in [38.9,41.1]:
		block(self,"flange",Vector3(0,y,0),Vector3(60,0.25,4.4),trim)
	for z: float in [-1.25,1.25]:
		block(self,"rail",Vector3(0,41.16,z),Vector3(56,0.16,0.2),dark)
	block(self,"raised_gate",Vector3(0,30,0.4),Vector3(47,8,0.9),panel)
	for y: float in [26.0,34.0]:
		block(self,"gate_flange",Vector3(0,y,1.05),Vector3(48,0.35,0.6),trim)
	for x: float in [-23.0,-16.0,-8.0,0.0,8.0,16.0,23.0]:
		block(self,"gate_rib",Vector3(x,30,1.05),Vector3(0.3,8,0.7),steel)
	for x: float in [-16.0,16.0]:
		block(self,"winch",Vector3(x,42.5,0),Vector3(3.2,2.8,3.0),dark)
		block(self,"hoist_line",Vector3(x,37.0,1.05),Vector3(0.16,6.0,0.16),trim)
	trolley = Node3D.new()
	trolley.name = "ServiceTrolley"
	add_child(trolley)
	block(trolley,"cab",Vector3(0,43.3,0),Vector3(4.4,2.2,3.4),steel)
	block(trolley,"window",Vector3(0,43.5,1.72),Vector3(2.8,0.9,0.03),dark)
	for x: float in [-1.5,1.5]:
		for z: float in [-1.25,1.25]:
			var wheel := MeshInstance3D.new()
			var shape := CylinderMesh.new()
			shape.top_radius = 0.55
			shape.bottom_radius = 0.55
			shape.height = 0.25
			wheel.mesh = shape
			wheel.material_override = dark
			wheel.position = Vector3(x,41.79,z)
			wheel.rotation.x = PI/2
			trolley.add_child(wheel)

	# joint plates and guides describe a raised gate leaf, not a signboard.
	for x: float in [-27.0,27.0]:
		for y: float in [1.0,28.0,39.0]:
			block(self,"splice_plate",Vector3(x,y,2.08),Vector3(4.1,2.4,0.18),dark)
			for dx: float in [-1.35,1.35]:
				for dy: float in [-0.7,0.7]:
					block(self,"plate_fastener",Vector3(x+dx,y+dy,2.2),Vector3(0.22,0.22,0.1),trim)
		block(self,"gate_guide",Vector3(signf(x)*24.5,17.5,0.7),Vector3(0.4,37,0.6),steel)
		for y: float in [4.0,20.0,36.0]:
			block(self,"guide_bracket",Vector3(signf(x)*25.0,y,0.7),Vector3(1.4,0.3,0.7),dark)
	# the existing finish edge gets paint only, with no new parapet or blocker.
	block(self,"quay_lip",Vector3(0,2.025,9.04),Vector3(20,0.05,0.16),painted(Color("b5683c"),ink))
	_breakwater_light(concrete,steel,dark,ink)

func _breakwater_light(concrete: Material, steel: Material, dark: Material, ink: Material) -> void:
	# a distant breakwater has a submerged base and a single navigation light.
	var shore := concrete.duplicate() as ShaderMaterial
	shore.set_shader_parameter("waterline_y",-10.0)
	block(self,"breakwater",Vector3(12,-10.5,-98),Vector3(50,11,15),shore)
	var plaster := concrete.duplicate() as ShaderMaterial
	plaster.set_shader_parameter("dry_concrete",Vector3(0.76,0.71,0.60))
	cylinder(self,"light_tower",Vector3(-7,10,-98),30.0,2.6,1.9,plaster)
	cylinder(self,"light_band",Vector3(-7,7,-98),2.2,2.37,2.32,steel)
	cylinder(self,"upper_light_band",Vector3(-7,20,-98),1.4,2.06,2.03,steel)
	cylinder(self,"lantern_base",Vector3(-7,25.1,-98),0.5,2.6,2.6,dark)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("f1dba3")
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.emission_enabled = true
	glass.emission = Color("f1dba3")
	glass.emission_energy_multiplier = 0.6
	glass.next_pass = ink
	cylinder(self,"lantern",Vector3(-7,26.2,-98),1.8,1.55,1.55,glass)
	for dx: float in [-1.6,1.6]:
		for dz: float in [-1.6,1.6]:
			block(self,"lantern_post",Vector3(-7+dx,26.2,-98+dz),Vector3(0.18,2.1,0.18),dark)
	cylinder(self,"lantern_roof",Vector3(-7,28,-98),1.8,2.8,0.1,steel)

static func painted(color: Color, ink: Material) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/maps/foundry/steel.gdshader")
	material.set_shader_parameter("paint",color)
	material.next_pass = ink
	return material

static func cylinder(parent: Node3D, id: String, at: Vector3, height: float, bottom: float, top: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = id
	var shape := CylinderMesh.new()
	shape.height = height
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.radial_segments = 16
	node.mesh = shape
	node.position = at
	node.material_override = material
	parent.add_child(node)

func _process(delta: float) -> void:
	age = fmod(age+delta,120.0)
	trolley.position.x = sin(age*TAU/40.0)*20.0

static func block(parent: Node3D, id: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh

static func brace(parent: Node3D, start: Vector3, finish: Vector3, width: float, material: Material) -> void:
	var mesh := block(parent,"brace",(start+finish)*0.5,Vector3(width,width,start.distance_to(finish)),material)
	mesh.basis = Basis.looking_at(finish-start,Vector3.UP)

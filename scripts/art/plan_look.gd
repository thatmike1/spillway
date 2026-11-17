extends RefCounted
## presentation follows the existing concrete and steel; no collider or record identity changes.
const SURFACE := preload("res://shaders/look/surface.gdshader")
const SKY := preload("res://shaders/look/sky.gdshader")
const WATER := preload("res://shaders/look/water.gdshader")
const CONTOURS := preload("res://scripts/r17_contours.gd")
func concrete(metal := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("wear",preload("res://assets/look/painted-wear.png"))
	material.set_shader_parameter("top_color",Color("59777b") if metal else Color("eee3cc"))
	material.set_shader_parameter("side_color",Color("4b6970") if metal else Color("668589"))
	material.set_shader_parameter("wear_amount",0.2 if metal else 0.65)
	material.set_shader_parameter("deck",0.0 if metal else 1.0)
	material.set_shader_parameter("metal",0.0)
	return material
func style(root: Node3D) -> void:
	var stone := concrete()
	var steel := concrete(true)
	for mesh: Node in root.find_children("*","MeshInstance3D",true,false):
		var id := str(mesh.name)
		if id.begins_with("Mesh_") or id.ends_with("_top") or id in ["PlanLift_mesh","PlanPad_mesh"]:
			mesh.material_override = stone
		elif id.begins_with("gantry_") or id.begins_with("travelling_") or id.begins_with("hanger"):
			mesh.material_override = steel
func attach(level: Node3D) -> void:
	style(level)
	for node: Node in level.get_children():
		if node is WorldEnvironment:
			var sky := Sky.new()
			var panorama := ShaderMaterial.new()
			panorama.shader = SKY
			panorama.set_shader_parameter("panorama",preload("res://assets/look/cloud-sky.png"))
			sky.sky_material = panorama
			var env: Environment = node.environment
			env.background_mode = Environment.BG_SKY
			env.sky = sky
			env.sky_rotation.y = PI
			env.ambient_light_color = Color("a6bfc3")
			env.ambient_light_energy = 0.45
			env.ambient_light_sky_contribution = 0.0
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env.tonemap_exposure = 1.0
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-36,-30,0)
			node.light_color = Color("fff0d3")
			node.light_energy = 0.7
			node.shadow_enabled = true
			node.directional_shadow_max_distance = 100
		if node is MeshInstance3D and str(node.name) == "sea":
			var material := ShaderMaterial.new()
			material.shader = WATER
			node.material_override = material
	level.add_child(CONTOURS.new().build(level))
	edges(level)
	for x: float in [-4,4]:
		level.box("sign_hanger",Vector3(x,14.5,-48.6),Vector3(0.1,1.3,0.1),Color("4b6970"))
	for x: float in [-12,0,12]:
		for z: float in [1,-11,-25,-49]:
			level.box("rail_joint",Vector3(x,15,z),Vector3(0.9,1.4,1.2),Color("57787b"))
	level.box("gantry_finish_board",Vector3(0,13.1,-48.6),Vector3(12,1.8,0.2),Color("29434b"))
	var sign := Label3D.new()
	sign.position = Vector3(0,13.1,-48.47)
	sign.text = "FAR QUAY  /  FINISH"
	sign.font_size = 64
	sign.pixel_size = 0.015
	sign.modulate = Color("efe4cc")
	sign.outline_size = 0
	level.add_child(sign)
	level.box("finish_threshold",Vector3(0,3.025,-46),Vector3(36,0.025,0.8),Color("29434b"))

	var floor_sign := Label3D.new()
	floor_sign.position = Vector3(0,3.06,-45.2)
	floor_sign.rotation_degrees.x = -90
	floor_sign.text = "FINISH"
	floor_sign.font_size = 96
	floor_sign.pixel_size = 0.025
	floor_sign.modulate = Color("29434b")
	floor_sign.outline_size = 0
	level.add_child(floor_sign)
func edges(level: Node3D) -> void:
	# orange follows exposed water edges, never a flat quay-to-quay joint.
	var strips := [
		[Vector3(0,3.035,5),Vector3(22,0.035,0.18)],
		[Vector3(0,3.035,-34),Vector3(22,0.035,0.18)],
		[Vector3(0,3.035,19.9),Vector3(36,0.035,0.18)],
		[Vector3(0,3.035,-54.9),Vector3(36,0.035,0.18)]]
	for x: float in [-17.9,-11.1,11.1,17.9]:
		strips.append([Vector3(x,3.035,-14.5),Vector3(0.18,0.035,39)])
	for span: Array in [[7.0,-18.0,-8.0],[9.0,-30.0,-21.0]]:
		var y: float = span[0]+0.035
		for z: float in [span[1]+0.1,span[2]-0.1]:
			strips.append([Vector3(0,y,z),Vector3(10,0.035,0.18)])
		for x: float in [-4.9,4.9]:
			strips.append([Vector3(x,y,(span[1]+span[2])/2),Vector3(0.18,0.035,span[2]-span[1])])
	for strip: Array in strips:
		level.box("water_lip",strip[0],strip[1],Color("d2824c"))

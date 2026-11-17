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
	material.set_shader_parameter("top_color",Color("43595b") if metal else Color("e2d6c1"))
	material.set_shader_parameter("side_color",Color("344d53") if metal else Color("57787b"))
	material.set_shader_parameter("wear_amount",0.28)
	material.set_shader_parameter("deck",0.0 if metal else 0.4)
	material.set_shader_parameter("metal",0.6 if metal else 0.0)
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
			env.ambient_light_energy = 0.38
			env.ambient_light_sky_contribution = 0.0
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 0.92
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-24,-135,0)
			node.light_color = Color("fff0d3")
			node.light_energy = 0.55
		if node is MeshInstance3D and str(node.name) == "sea":
			var material := ShaderMaterial.new()
			material.shader = WATER
			node.material_override = material
	level.add_child(CONTOURS.new().build(level))
	level.box("gantry_finish_board",Vector3(0,13.1,-48.6),Vector3(12,1.8,0.2),Color("29434b"))
	var sign := Label3D.new()
	sign.position = Vector3(0,13.1,-48.47)
	sign.text = "FAR QUAY  /  FINISH"
	sign.font_size = 64
	sign.pixel_size = 0.015
	sign.modulate = Color("efe4cc")
	sign.outline_size = 0
	level.add_child(sign)
	level.box("finish_threshold",Vector3(0,3.025,-46),Vector3(36,0.025,0.22),Color("29434b"))

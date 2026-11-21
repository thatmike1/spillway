extends RefCounted
## presentation follows the existing concrete and steel; no collider or record identity changes.
const STEEL := preload("res://scripts/art/plan_steel.gdshader")
const CONCRETE := preload("res://scripts/art/plan_concrete.gdshader")
const SKY := preload("res://shaders/look/sky.gdshader")
const WATER := preload("res://scripts/art/plan_water.gdshader")
const CONTOURS := preload("res://scripts/r17_contours.gd")
func metal_material(detail := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = STEEL
	material.set_shader_parameter("wear_strength",0.36 if detail else 0.10)
	material.set_shader_parameter("wear",preload("res://assets/look/painted-wear.png"))
	return material
func style(root: Node3D) -> void:
	var steel := metal_material()
	var joint := metal_material(true)
	for mesh: Node in root.find_children("*","MeshInstance3D",true,false):
		var id := str(mesh.get_meta("plan_art_id",mesh.name))
		if id.begins_with("Mesh_") or id.ends_with("_top") or id in ["PlanLift_mesh","PlanPad_mesh"]:
			var stone := ShaderMaterial.new()
			stone.shader = CONCRETE
			stone.set_shader_parameter("plaster",preload("res://assets/r15/breakwater/textures/white_plaster_rough_02/white_plaster_rough_02_diff_1k.jpg"))
			stone.set_shader_parameter("wear",preload("res://assets/look/painted-wear.png"))
			var bounds: AABB = mesh.get_aabb()
			stone.set_shader_parameter("top_y",mesh.to_global(bounds.end).y)
			mesh.material_override = stone
		elif (id.begins_with("gantry_") and id != "gantry_finish_board") or id.begins_with("travelling_") or id.begins_with("hanger") or id.begins_with("rail_joint") or id.begins_with("sign_hanger"):
			mesh.material_override = joint if id.begins_with("hanger") or id.begins_with("rail_joint") else steel
func attach(level: Node3D) -> void:
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
			env.ambient_light_color = Color("c6c6ca")
			env.ambient_light_energy = 0.5
			env.ambient_light_sky_contribution = 0.0
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env.tonemap_exposure = 1.0
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-36,-30,0)
			node.light_color = Color("fff0dd")
			node.light_energy = 0.42
			node.shadow_enabled = true
			node.directional_shadow_max_distance = 100
		if node is MeshInstance3D and str(node.name) == "sea":
			var material := ShaderMaterial.new()
			material.shader = WATER
			material.set_shader_parameter("wear",preload("res://assets/look/painted-wear.png"))
			node.material_override = material
	level.add_child(CONTOURS.new().build(level))
	edges(level)
	for x: float in [-4,4]:
		level.box("sign_hanger",Vector3(x,14.5,-48.6),Vector3(0.1,1.3,0.1),Color("4b6970"))
	for x: float in [-12,0,12]:
		for z: float in [1,-11,-25,-49]:
			level.box("rail_joint",Vector3(x,14.42,z),Vector3(0.6,0.14,1.15),Color("718586"))
	level.box("gantry_finish_board",Vector3(0,13.1,-48.6),Vector3(12,1.8,0.2),Color("29434b"))
	var sign := Label3D.new()
	sign.position = Vector3(0,13.1,-48.47)
	sign.text = "FAR QUAY  /  FINISH"
	sign.font_size = 64
	sign.pixel_size = 0.015
	sign.modulate = Color("efe4cc")
	sign.outline_size = 0
	level.add_child(sign)
	# the hanging board names the finish; the floor carries only the threshold line, no lettering.
	level.box("finish_threshold",Vector3(0,3.025,-46),Vector3(36,0.025,0.8),Color("29434b"))

	style(level)
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

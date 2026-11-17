extends RefCounted
## original procedural concrete with the project's licensed painted sky; visual only, no physics or acquisition writes.
static func apply(level: Node3D) -> void:
	var concrete := _surface(Color("cfc9b9"),Color("657a7c"),0.85)
	var incline := _surface(Color("b8c7c0"),Color("617777"),0.85)
	var basin := _surface(Color("728781"),Color("4d6667"),0.35)
	for node: Node in level.get_children():
		if node is MeshInstance3D and (node.name.begins_with("Mesh_") or node.name.begins_with("viaduct_pier") or node.name.begins_with("viaduct_crossbeam") or node.name.begins_with("viaduct_foot")):
			if str(node.name).contains("maintenance_court"):
				node.material_override = basin
			elif str(node.name).begins_with("Mesh_recovery"):
				node.material_override = incline
			else:
				node.material_override = concrete
	for node: Node in level.get_children():
		if node is MeshInstance3D and node.name == "viaduct_house_panel":
			var cladding := _surface(Color("718b90"),Color("587a82"),0.0)
			cladding.set_shader_parameter("metal",0.65)
			node.material_override = cladding
	# broad distant banks ground the basin without crowding the playable silhouette.
	for side: float in [-1.0,1.0]:
		box(level,Vector3(side*67,-7.5,-35),Vector3(48,12,180),Color("6f8175"))
		box(level,Vector3(side*42,-6,-35),Vector3(1,12,180),Color("566563"))
	# reuse the project's original redistributable painted sky, not the private moodboard.
	for node: Node in level.get_children():
		if node is MeshInstance3D and node.name == "Water":
			var water := ShaderMaterial.new()
			water.shader = preload("res://shaders/look/water.gdshader")
			node.material_override = water
		if node is WorldEnvironment:
			var sky := Sky.new()
			var painted := ShaderMaterial.new()
			painted.shader = preload("res://shaders/look/sky.gdshader")
			painted.set_shader_parameter("panorama",preload("res://assets/look/r17/practice-sky.png"))
			sky.sky_material = painted
			node.environment.sky = sky
			node.environment.background_mode = Environment.BG_SKY
			node.environment.ambient_light_energy = 0.30
			node.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			node.environment.tonemap_exposure = 0.92
		if node is DirectionalLight3D:
			node.light_energy = 0.35
			node.shadow_enabled = true
			node.directional_shadow_max_distance = 160.0
	level.add_child(preload("res://scripts/r17_contours.gd").new().build(level,true))
	level.add_child(preload("res://scripts/art/viaduct_cable.gd").new())

static func box(level: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = preload("res://scripts/movement/grapple_player.gd")._flat(color)
	level.add_child(node)

static func _surface(top: Color, side: Color, joints: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/look/surface.gdshader")
	material.set_shader_parameter("wear",preload("res://assets/look/painted-wear.png"))
	material.set_shader_parameter("top_color",top)
	material.set_shader_parameter("side_color",side)
	material.set_shader_parameter("wear_amount",0.28)
	material.set_shader_parameter("deck",joints)
	return material

extends RefCounted
## original crane structure; existing project textures retain their recorded provenance.
const GEO := preload("res://scripts/r19_course_geometry.gd")
const SURFACE := preload("res://shaders/look/surface.gdshader")
const SKY := preload("res://shaders/look/sky.gdshader")

static func dress(level: Node3D) -> void:
	var concrete := ShaderMaterial.new()
	concrete.shader = SURFACE
	concrete.set_shader_parameter("top_color", Color("e4ddc9"))
	concrete.set_shader_parameter("side_color", Color("405b5d"))
	concrete.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
	concrete.set_shader_parameter("wear_amount", 0.22)
	concrete.set_shader_parameter("deck", 1.0)
	for node in level.get_children():
		if node is MeshInstance3D and (str(node.name).begins_with("Mesh_deck") or str(node.name).begins_with("Art_pier")):
			node.material_override = concrete
		if node is WorldEnvironment:
			var sky := Sky.new()
			var paint := ShaderMaterial.new()
			paint.shader = SKY
			paint.set_shader_parameter("panorama", load("res://assets/look/cloud-sky.png"))
			sky.sky_material = paint
			node.environment.background_mode = Environment.BG_SKY
			node.environment.sky = sky
			node.environment.ambient_light_energy = 0.55
		if node is DirectionalLight3D:
			node.shadow_enabled = true
			node.light_energy = 0.85
	for x: float in [-13, 13]:
		# the rails bind both portals into one working crane on continuous tidal quays.
		GEO.prism(level, "crane_quay_%s" % x, GEO.rectangle(x - 2.5, x + 2.5, -111, 27, 3.9), -5, -1, "structure")
		level._box("Art_quay_cap_%s" % x, Vector3(x, 3.94, -42), Vector3(5, 0.16, 138), Color("b5b5a3"))
		level._box("Art_rail_%s" % x, Vector3(x, 4.1, -42), Vector3(0.18, 0.17, 138), Color("263d45"))
		level._box("Art_crane_run_%s" % x, Vector3(x, 15.1, -45), Vector3(0.7, 0.7, 48.7), Color("29464a"))
	for i: int in level.DECKS.size():
		var deck: Array = level.DECKS[i]
		for x: float in [-7.98, 7.98]:
			level._box("Art_ink_edge_%d_%s" % [i, x], Vector3(x, 4.016, (deck[2] + deck[3]) / 2), Vector3(0.035, 0.018, deck[3] - deck[2]), Color("405358"))
		# receiving edges stay pale; a dark vertical fascia separates them from water.
		level._box("Art_fascia_%d" % i, Vector3(0, 3.63, deck[3] + 0.012), Vector3(16, 0.7, 0.025), Color("29464a"))
	for node in level.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("Mesh_deck"):
			node.material_override = concrete

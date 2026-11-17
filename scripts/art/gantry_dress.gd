extends RefCounted
## original crane structure; existing project textures retain their recorded provenance.
const GEO := preload("res://scripts/r19_course_geometry.gd")
const SURFACE := preload("res://assets/maps/gantry/concrete.gdshader")
const WATER := preload("res://shaders/look/water.gdshader")
const SKY := preload("res://shaders/look/sky.gdshader")

static func dress(level: Node3D) -> void:
	var concrete := ShaderMaterial.new()
	concrete.shader = SURFACE
	concrete.set_shader_parameter("top_color", Color("d2c9b4"))
	concrete.set_shader_parameter("side_color", Color("526f73"))
	concrete.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
	concrete.set_shader_parameter("wear_amount", 0.38)
	concrete.set_shader_parameter("deck", 1.0)
	for node in level.get_children():
		if node is MeshInstance3D and (str(node.name).begins_with("Mesh_deck") or str(node.name).begins_with("Art_pier")):
			node.material_override = concrete
		if node is MeshInstance3D and str(node.name) == "Water":
			var water := ShaderMaterial.new()
			water.shader = WATER
			node.material_override = water
		if node is WorldEnvironment:
			var sky := Sky.new()
			var paint := ShaderMaterial.new()
			paint.shader = SKY
			paint.set_shader_parameter("panorama", load("res://assets/look/cloud-sky.png"))
			sky.sky_material = paint
			node.environment.background_mode = Environment.BG_SKY
			node.environment.sky = sky
			node.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			node.environment.tonemap_exposure = 0.95
			node.environment.ambient_light_energy = 0.4
		if node is DirectionalLight3D:
			node.shadow_enabled = true
			node.light_energy = 0.75
	for x: float in [-13, 13]:
		# the rails bind both portals into one working crane on continuous tidal quays.
		GEO.prism(level, "crane_quay_%s" % x, GEO.rectangle(x - 2.5, x + 2.5, -111, 27, 3.9), -5, -1, "structure")
		level._box("Art_quay_cap_%s" % x, Vector3(x, 3.94, -42), Vector3(5, 0.16, 138), Color("8f9e95"))
		level._box("Art_rail_%s" % x, Vector3(x, 4.1, -42), Vector3(0.18, 0.17, 138), Color("263d45"))
		level._box("Art_crane_run_%s" % x, Vector3(x, 15.1, -45), Vector3(0.7, 0.7, 48.7), Color("29464a"))
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("3a5357")
	metal.roughness = 0.92
	for i: int in level.ANCHORS.size():
		var at: Vector3 = level.ANCHORS[i]
		for x: float in [-13.0, 13.0]:
			GEO.prism(level, "gantry_foot_%d_%s" % [i, x], GEO.rectangle(x - 0.85, x + 0.85, at.z - 0.85, at.z + 0.85, 4.04), 3.8, -1, "structure", "gantry_bearing")
	for pad: Dictionary in level.hop_pads:
		# cross-bearings connect each casting to the crane quays, below the route top.
		GEO.prism(level, "bearing_%d_%d" % [pad.stage, pad.index], GEO.rectangle(-13.4, 13.4, pad.far + 0.15, pad.near - 0.15, 3.15), 2.55, -1, "structure", "gantry_bearing")
		if pad.index == -1 and pad.stage > 0:
			level._box("Art_paint_orange_receiver_%d" % pad.stage, Vector3(0, 4.025, pad.near - 0.08), Vector3(level.HALF_WIDTH * 2, 0.035, 0.16), Color("b5683c"))
		for x: float in [pad.x0, pad.x1]:
			level._box("Art_ink_edge_%d_%d_%s" % [pad.stage, pad.index, x], Vector3(x, 4.016, (pad.far + pad.near) / 2), Vector3(0.035, 0.018, pad.near - pad.far), Color("405358"))
		level._box("Art_bearing_joint_%d_%d" % [pad.stage, pad.index], Vector3(0, 3.2, pad.near + 0.014), Vector3(level.HALF_WIDTH * 2 - 0.06, 0.035, 0.025), Color("354e52"))
	for node in level.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("Mesh_deck"):
			node.material_override = concrete
		if node is MeshInstance3D and str(node.name).begins_with("Mesh_gantry_bearing"):
			node.material_override = metal

	var stroke := RopeStroke.new()
	stroke.name = "GantryRopeStroke"
	stroke.process_priority = 100
	level.add_child(stroke)

class RopeStroke extends Node:
	var styled_instance := 0

	func _process(_delta: float) -> void:
		var host := get_parent().get_parent()
		if not host.has_method("map_entry") or str(host.get("map_id")) != "gantry":
			return
		var runner: Node = host.get("player")
		if runner == null or runner.get_instance_id() == styled_instance:
			return
		var rope := runner.get_node_or_null("GrappleTether") as MeshInstance3D
		if rope == null or not rope.mesh is CylinderMesh:
			return
		# a map-local copy changes only the visual stroke, never the motor or rope law.
		var mesh := rope.mesh.duplicate() as CylinderMesh
		mesh.top_radius = 0.006
		mesh.bottom_radius = 0.006
		rope.mesh = mesh
		styled_instance = runner.get_instance_id()

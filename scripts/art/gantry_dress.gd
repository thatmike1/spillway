extends RefCounted
## original crane structure; existing project textures retain their recorded provenance.
const GEO := preload("res://scripts/r19_course_geometry.gd")
const SURFACE := preload("res://assets/maps/gantry/concrete.gdshader")
const WATER := preload("res://assets/maps/gantry/water.gdshader")
const SKY := preload("res://shaders/look/sky.gdshader")
const LOOK := preload("res://scripts/look/maps/gantry.gd")

static func dress(level: Node3D) -> void:
	var concrete := ShaderMaterial.new()
	concrete.shader = SURFACE
	concrete.set_shader_parameter("top_color", Color("d9d8ce"))
	concrete.set_shader_parameter("side_color", Color("526467"))
	concrete.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
	concrete.set_shader_parameter("wear_amount", 0.38)
	concrete.set_shader_parameter("deck", 0.0)
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
			node.environment.tonemap_exposure = 0.90
			node.environment.ambient_light_color = Color("c0c4c5")
			node.environment.ambient_light_energy = 0.40
		if node is DirectionalLight3D:
			node.shadow_enabled = true
			node.light_energy = 0.50
			node.light_color = Color("fff6e8")
			node.directional_shadow_max_distance = 180.0
	for x: float in [-13, 13]:
		# the rails bind both portals into one working crane on continuous tidal quays.
		GEO.prism(level, "crane_quay_%s" % x, GEO.rectangle(x - 2.5, x + 2.5, -111, 27, 3.9), -5, -1, "structure")
		level._box("Art_quay_cap_%s" % x, Vector3(x, 3.94, -42), Vector3(5, 0.16, 138), Color("b7b09b"))
		level._box("Art_rail_%s" % x, Vector3(x, 4.1, -42), Vector3(0.18, 0.17, 138), Color("263d45"))
		level._box("Art_crane_run_%s" % x, Vector3(x, 15.1, -45), Vector3(0.7, 0.7, 48.7), Color("29464a"))
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("cf7746")
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("837f70")
	metal.roughness = 0.92
	for i: int in level.ANCHORS.size():
		var at: Vector3 = level.ANCHORS[i]
		for x: float in [-13.0, 13.0]:
			GEO.prism(level, "gantry_foot_%d_%s" % [i, x], GEO.rectangle(x - 0.85, x + 0.85, at.z - 0.85, at.z + 0.85, 4.04), 3.8, -1, "structure", "gantry_bearing")
	for pad: Dictionary in level.hop_pads:
		# cross-bearings connect each casting to the crane quays, below the route top.
		GEO.prism(level, "bearing_%d_%d" % [pad.stage, pad.index], GEO.rectangle(-13.4, 13.4, pad.far + 0.15, pad.near - 0.15, 3.15), 2.55, -1, "structure", "gantry_bearing")
		if pad.index == -1 and pad.stage > 0:
			level._box("Art_paint_orange_receiver_%d" % pad.stage, Vector3(0, 4.009, pad.near - 0.2), Vector3(level.HALF_WIDTH * 2, 0.012, 0.45), Color("b5683c"))
			level._box("Art_paint_orange_receiver_face_%d" % pad.stage, Vector3(0, 3.85, pad.near + 0.015), Vector3(level.HALF_WIDTH * 2, 0.28, 0.025), Color("b5683c"))
		for x: float in [pad.x0, pad.x1]:
			level._box("Art_ink_edge_%d_%d_%s" % [pad.stage, pad.index, x], Vector3(x, 4.016, (pad.far + pad.near) / 2), Vector3(0.035, 0.018, pad.near - pad.far), Color("405358"))
		level._box("Art_bearing_joint_%d_%d" % [pad.stage, pad.index], Vector3(0, 3.2, pad.near + 0.014), Vector3(level.HALF_WIDTH * 2 - 0.06, 0.035, 0.025), Color("354e52"))
	for node in level.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("Mesh_deck"):
			node.material_override = concrete
		if node is MeshInstance3D and str(node.name).begins_with("Mesh_gantry_bearing"):
			node.material_override = metal
		if node is MeshInstance3D and str(node.name).begins_with("Art_paint_orange_receiver"):
			node.material_override = paint

	_sky_light(level, str(level.variant))
	var stroke := RopeStroke.new()
	stroke.name = "GantryRopeStroke"
	stroke.process_priority = 100
	level.add_child(stroke)

static func _sky_light(level: Node3D, id: String) -> void:
	# lane 02 owns these sky and light values; this file only hands over its environment and sun.
	var sky_light := load("res://scripts/look/sky_light.gd")
	if sky_light == null or not sky_light.has_map(id):
		return
	var env: Environment
	var sun: DirectionalLight3D
	for node: Node in level.get_children():
		if node is WorldEnvironment and env == null:
			env = (node as WorldEnvironment).environment
		if node is DirectionalLight3D and sun == null:
			sun = node
	if env != null:
		sky_light.apply(env, sun, id)

static func ink(level: Node3D) -> void:
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://assets/maps/gantry/outline.gdshader")
	for node: Node in level.get_children():
		if not node is MeshInstance3D or str(node.name) == "Water" or str(node.name).contains("headland") or str(node.name).contains("dispatch_glass"):
			continue
		if str(node.name).contains("paint_orange") or str(node.name).begins_with("Art_chain_receiver"):
			continue
		if node.material_override != null:
			node.material_override.next_pass = outline
	# retain the established structural outlines without repainting every hop edge orange.
	var contours: Node3D = preload("res://scripts/r17_contours.gd").new().build(level, true)
	var lips := contours.get_node_or_null("JumpLips")
	if lips != null:
		contours.remove_child(lips)
		lips.free()
	level.add_child(contours)
	level.art_manifest.append(["gantry_materials", "neutral cream tops, separate architectural stone, blue-green sides, structural ink v4"])
	# presentation-only pass after the identity inputs above are complete.
	LOOK.dress(level)

static func portal_details(level: Node3D, index: int, at: Vector3) -> void:
	# wheel trucks ride the continuous quay rails; the crossbeam carries a lifting carriage.
	for side: float in [-1, 1]:
		level._box("Art_gantry_truck_%d_%s" % [index, side], Vector3(side * 13, 4.65, at.z), Vector3(1.05, 0.3, 3.4), Color("506972"))
		for z: float in [at.z - 1.1, at.z + 1.1]:
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.25
			cylinder.bottom_radius = 0.25
			cylinder.height = 0.16
			cylinder.radial_segments = 12
			wheel.mesh = cylinder
			wheel.name = "Art_gantry_wheel"
			wheel.position = Vector3(side * 13, 4.435, z)
			wheel.rotation.z = PI * 0.5
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("293d45")
			wheel.material_override = material
			level.add_child(wheel)
			level.art_manifest.append(["gantry_wheel", index, side, z, 0.25])
		level._box("Art_gantry_knee_%d_%s" % [index, side], Vector3(side * 11.5, at.y - 0.4, at.z), Vector3(0.28, 4.24264, 0.28), Color("506972"))
		var knee := level.get_child(level.get_child_count() - 1) as MeshInstance3D
		knee.rotation.z = side * PI * 0.25
		level.art_manifest.append(["gantry_knee_roll", index, side, knee.rotation.z])
	level._box("Art_gantry_carriage_%d" % index, at + Vector3(0, 1.5, 0), Vector3(2.2, 0.55, 1.3), Color("71868a"))
	level._box("Art_gantry_carriage_strap_%d" % index, at + Vector3(0, 1.1, 0), Vector3(0.35, 1.1, 0.28), Color("3c535b"))

class RopeStroke extends Node:
	var styled_instance := 0

	func _process(_delta: float) -> void:
		var host := get_parent().get_parent()
		if not host.has_method("map_entry") or str(host.get("map_id")) not in ["gantry", "gantry-chain"]:
			return
		var runner: Node = host.get("player")
		if runner == null:
			return
		var rope := runner.get_node_or_null("GrappleTether") as MeshInstance3D
		if rope == null or not rope.mesh is CylinderMesh:
			return
		if runner.get_instance_id() != styled_instance:
			# a map-local copy changes only the visual stroke, never the motor or rope law.
			rope.mesh = rope.mesh.duplicate()
			styled_instance = runner.get_instance_id()
		if not rope.visible:
			return
		var camera: Camera3D = runner.get("camera")
		var hand := rope.global_transform * Vector3(0, -0.5, 0)
		var end := rope.global_transform * Vector3(0, 0.5, 0)
		var view := camera.global_transform.affine_inverse()
		var hand_depth: float = -(view * hand).z
		var end_depth: float = -(view * end).z
		var near_depth := camera.near * 1.05
		if end_depth < near_depth:
			# clip the visual endpoint before projecting; the attached physics anchor is untouched.
			end = hand.lerp(end, clampf((hand_depth - near_depth) / (hand_depth - end_depth), 0.0, 1.0))
			var span := end - hand
			var up := span.normalized()
			var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
			rope.global_transform = Transform3D(Basis(side, span, side.cross(up)), (hand + end) * 0.5)
		var mesh := rope.mesh as CylinderMesh
		mesh.top_radius = stroke_radius(camera, end, rope.global_basis)
		mesh.bottom_radius = stroke_radius(camera, hand, rope.global_basis)

	static func stroke_radius(camera: Camera3D, at: Vector3, basis: Basis) -> float:
		# cap the projected diameter at two pixels and the world radius at the previous six mm.
		# use the actual cap axes: offscreen near-plane caps also change depth across their width.
		var probe := 0.00001
		var pixel_diameter := 0.0
		for axis: Vector3 in [basis.x, basis.z]:
			var a := camera.unproject_position(at + axis * probe)
			var b := camera.unproject_position(at - axis * probe)
			pixel_diameter = maxf(pixel_diameter, a.distance_to(b))
		return minf(0.006, 2.0 * probe / maxf(pixel_diameter, 0.000001))

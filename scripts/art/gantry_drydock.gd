extends RefCounted
## original scenery and outside-route service access; no acquisition nodes or motor configuration.
const PALE := Color("c7b89c")
const SIDE := Color("606c6c")
const STEEL := Color("4e727e")
const RIB := Color("8c9690")
const GEO := preload("res://scripts/r19_course_geometry.gd")

static func dress(level: Node3D) -> void:
	for pad: Dictionary in level.hop_pads:
		if pad.index == -1 and pad.stage > 0:
			receiving_frame(level, pad.near, pad.stage)
	# the raised caisson spans an open water channel between long working quays.
	for x: float in [26.25, 73.75]:
		box(level, "gate_quay_%s" % x, Vector3(x, -1, -90), Vector3(10.5, 7, 50), SIDE)
		box(level, "gate_quay_cap_%s" % x, Vector3(x, 2.6, -90), Vector3(10.5, 0.35, 50), PALE)
	for x: float in [25, 75]:
		box(level, "gate_foundation_%s" % x, Vector3(x, -1, -96), Vector3(11, 8, 15), STEEL)
		box(level, "gate_foot_%s" % x, Vector3(x, 4, -96), Vector3(8.5, 2.5, 11), PALE)
		box(level, "gate_pylon_%s" % x, Vector3(x, 24, -96), Vector3(4, 39, 6), PALE)
		box(level, "gate_pylon_seam_%s" % x, Vector3(x - 1.2, 24, -92.97), Vector3(0.08, 39, 0.04), SIDE)
		box(level, "gate_bearing_%s" % x, Vector3(x, 43, -96), Vector3(7, 2, 9), SIDE)
	box(level, "gate_crane_beam", Vector3(50, 45, -96), Vector3(59, 3.5, 7), PALE)
	box(level, "gate_crane_shadow", Vector3(50, 43.15, -96), Vector3(59, 0.3, 7.1), STEEL)
	box(level, "gate_crane_rail", Vector3(50, 47, -94), Vector3(59, 0.25, 0.25), STEEL)
	for x: float in [30.6, 69.4]:
		box(level, "gate_guide_%s" % x, Vector3(x, 14.5, -96), Vector3(1.8, 37, 7), PALE)
		box(level, "gate_guide_slot_%s" % x, Vector3(x + (0.9 if x < 50 else -0.9), 14.5, -92.4), Vector3(0.14, 37, 0.18), STEEL)
	# one coherent load: a hollow caisson with frame, skin and load-bearing ribs.
	box(level, "gate_skin", Vector3(50, 20, -96), Vector3(36, 25, 3.5), STEEL)
	for y: float in [7.5, 32.5]:
		box(level, "gate_frame_%s" % y, Vector3(50, y, -93.7), Vector3(38, 1.3, 1.5), RIB)
	for x: float in [31.5, 68.5]:
		box(level, "gate_end_%s" % x, Vector3(x, 20, -93.7), Vector3(1.3, 25, 1.5), RIB)
	for i: int in 5:
		var x := 37.5 + i * 6.25
		box(level, "gate_rib_%d" % i, Vector3(x, 20, -93.5), Vector3(0.55, 24, 1.9), RIB)
	for y: float in [13.5, 20, 26.5]:
		box(level, "gate_stiffener_%s" % y, Vector3(50, y, -93.2), Vector3(36, 0.45, 2.2), RIB)
	for i: int in 4:
		var x := 35.0 + i * 10.0
		box(level, "gate_trolley_%d" % i, Vector3(x, 42.1, -96), Vector3(2.2, 1.8, 5), STEEL)
		box(level, "gate_hoist_%d" % i, Vector3(x, 37.5, -95.7), Vector3(0.12, 8, 0.12), STEEL)
		box(level, "gate_hoist_pair_%d" % i, Vector3(x + 0.35, 37.5, -96.3), Vector3(0.12, 8, 0.12), STEEL)
		box(level, "gate_lift_%d" % i, Vector3(x, 33.1, -96), Vector3(1.3, 1, 3.7), Color("a4734e"))
	# flange seams and hinge bearings explain the caisson's fabrication at running scale.
	for x: float in [31.5, 68.5]:
		for y: float in [11, 20, 29]:
			box(level, "gate_hinge_%s_%s" % [x, y], Vector3(x, y, -92.5), Vector3(2, 1.2, 1.4), STEEL)
	for y: float in [13.5, 20, 26.5]:
		box(level, "gate_flange_%s" % y, Vector3(50, y - 0.32, -92.05), Vector3(36, 0.08, 0.08), Color("263f44"))
	# the harbour wall connects to the work quay and curves into the open sea.
	for i: int in 12:
		var angle := deg_to_rad(float(i) * 4.0)
		var at := Vector3(75 + sin(angle) * 95, -1.5, -111 - (1 - cos(angle)) * 95)
		box(level, "breakwater_%d" % i, at, Vector3(8.0, 5.8, 8), SIDE, angle)
		box(level, "breakwater_crest_%d" % i, at + Vector3(0, 3.05, 0), Vector3(8.1, 0.35, 8.1), PALE, angle)
	terminal(level)
	signal_house(level)
	headland(level)
	# use the same concrete for the large crane/hall masses, with crisp fabricated joints.
	var surface := level.get_node("Mesh_deck_apron_0_pad_-1").material_override as ShaderMaterial
	var stone := surface.duplicate() as ShaderMaterial
	stone.set_shader_parameter("side_color", Color("b9b8a9"))
	stone.set_shader_parameter("wear_amount", 0.45)
	var coated := surface.duplicate() as ShaderMaterial
	coated.set_shader_parameter("top_color", Color("81989a"))
	coated.set_shader_parameter("side_color", Color("507687"))
	coated.set_shader_parameter("wear_color", Color("9e8a65"))
	coated.set_shader_parameter("wear_amount", 0.65)
	coated.set_shader_parameter("joint_pitch", 6.25)
	coated.set_shader_parameter("waterline", 9.5)
	for node: Node in level.get_children():
		if not node is MeshInstance3D:
			continue
		var id := str(node.name)
		if (id.contains("gate_pylon") and not id.contains("seam")) or id.contains("gate_crane_beam") or (id.contains("gate_guide") and not id.contains("guide_slot")) or id.contains("hall_wall") or id.contains("hall_roof") or id.contains("hall_skylight") or id.contains("signal_tower"):
			node.material_override = stone
		if id == "Art_drydock_gate_skin":
			node.material_override = coated
	service_access(level, surface)

static func service_access(level: Node3D, surface: Material) -> void:
	# a service ramp joins both quays outside the timed line; the working floor is walkable.
	var top: Array[Vector3] = [Vector3(15.5, 3.9, -89), Vector3(21, 2.775, -89), Vector3(21, 2.775, -84), Vector3(15.5, 3.9, -84)]
	GEO.prism(level, "gate_service_ramp", top, 2.1, -1, "structure")
	level.get_node("Mesh_deck_gate_service_ramp").material_override = surface
	proxy(level, "gate_working_quay_left", GEO.rectangle(21, 31.5, -115, -65, 2.775), -5)
	proxy(level, "gate_working_quay_right", GEO.rectangle(68.5, 79, -115, -65, 2.775), -5)
	for x: float in [30.6, 69.4]:
		proxy(level, "gate_guide_%s" % x, GEO.rectangle(x - 0.9, x + 0.9, -99.5, -92.5, 33), -4)
	for x: float in [25, 75]:
		proxy(level, "gate_foundation_%s" % x, GEO.rectangle(x - 5.5, x + 5.5, -103.5, -88.5, 3), -5)
		proxy(level, "gate_foot_%s" % x, GEO.rectangle(x - 4.25, x + 4.25, -101.5, -90.5, 5.25), 2.75)
		proxy(level, "gate_pylon_%s" % x, GEO.rectangle(x - 2, x + 2, -99, -93, 43.5), 4.5)
	for z: float in [-89, -84]:
		for x: float in [15.6, 18.25, 20.9]:
			var y := lerpf(3.9, 2.775, (x - 15.5) / 5.5)
			box(level, "service_rail_post_%s_%s" % [x, z], Vector3(x, y + 0.575, z), Vector3(0.065, 1.15, 0.065), STEEL)
		box(level, "service_handrail_%s" % z, Vector3(18.25, 4.4375, z), Vector3(5.615, 0.065, 0.065), STEEL)
		var rail := level.get_child(level.get_child_count() - 1) as MeshInstance3D
		rail.rotation.z = atan2(-1.125, 5.5)
		level.art_manifest.append(["service_rail_pitch", z, rail.rotation.z])

static func proxy(level: Node3D, id: String, top: Array[Vector3], bottom: float) -> void:
	GEO.prism(level, id, top, bottom, -1, "structure", "prop_proxy")
	level.get_child(level.get_child_count() - 1).visible = false
	# the original scenery mesh supplies these visible faces; do not ink the hidden proxy.
	level.prisms.pop_back()

static func receiving_frame(level: Node3D, near: float, stage: int) -> void:
	# a visible crosshead fronts the existing structural bearing; its knees root into the tide.
	box(level, "receiving_crosshead_%d" % stage, Vector3(0, 2.82, near + 0.08), Vector3(26.8, 0.65, 0.6), Color("849a98"))
	box(level, "receiving_flange_%d" % stage, Vector3(0, 2.47, near + 0.08), Vector3(27.1, 0.10, 0.75), STEEL)
	for x: float in [-8, 8]:
		box(level, "receiving_pile_%d_%s" % [stage, x], Vector3(x, -1.2, near + 0.08), Vector3(1.0, 7.4, 1.4), SIDE)
		box(level, "receiving_cap_%d_%s" % [stage, x], Vector3(x, 2.3, near + 0.08), Vector3(1.7, 0.5, 1.9), RIB)

static func terminal(level: Node3D) -> void:
	# the dispatch axis ends in a servicing hall, beyond the timed apron, rather than empty sea.
	for x: float in [-19, 19]:
		box(level, "hall_foundation_%s" % x, Vector3(x, -1, -194), Vector3(9, 8, 32), SIDE)
		box(level, "hall_wall_%s" % x, Vector3(x, 7, -194), Vector3(6, 20, 28), PALE)
		box(level, "hall_front_seam_%s" % x, Vector3(x - 1.8, 7, -179.95), Vector3(0.10, 20, 0.08), SIDE)
	box(level, "hall_rear_lintel", Vector3(0, 16, -207), Vector3(32, 2, 2), PALE)
	for x: float in [-20, 20]:
		box(level, "hall_roof_%s" % x, Vector3(x, 18, -194), Vector3(4, 3, 29), PALE)
	box(level, "hall_roof_front", Vector3(0, 18, -180), Vector3(44, 3, 1), PALE)
	for z: float in [-185, -203]:
		box(level, "hall_skylight_%s" % z, Vector3(0, 18, z), Vector3(44, 1.2, 0.8), PALE)
	box(level, "hall_apron", Vector3(0, 3.7, -185), Vector3(44, 0.6, 18), SIDE)
	for x: float in [-13, 13]:
		box(level, "hall_quay_%s" % x, Vector3(x, -1, -154.5), Vector3(5, 9.8, 87), SIDE)
		box(level, "hall_quay_cap_%s" % x, Vector3(x, 3.94, -154.5), Vector3(5, 0.16, 87), PALE)

static func signal_house(level: Node3D) -> void:
	# one harbour signal house continues the hall's quay and anchors the arrival sightline.
	var yaw := atan2(-41.0, 58.0)
	box(level, "signal_causeway", Vector3(39.5, -1.8, -236), Vector3(8, 6.6, 71.02816), SIDE, yaw)
	box(level, "signal_causeway_cap", Vector3(39.5, 1.6, -236), Vector3(8.2, 0.2, 71.02816), PALE, yaw)
	box(level, "signal_foundation", Vector3(60, -2.5, -265), Vector3(13, 10, 14), SIDE)
	box(level, "signal_plinth", Vector3(60, 2.6, -265), Vector3(13.3, 0.2, 14.3), PALE)
	box(level, "signal_tower", Vector3(60, 14.5, -265), Vector3(5, 24, 5), PALE)
	for y: float in [8, 14, 20]:
		box(level, "signal_band_%s" % y, Vector3(60, y, -265), Vector3(5.06, 0.08, 5.06), STEEL)
	box(level, "signal_lantern_base", Vector3(60, 26.5, -265), Vector3(6.8, 0.4, 6.8), STEEL)
	box(level, "signal_lantern_glass", Vector3(60, 28.1, -265), Vector3(5.7, 2.8, 5.7), Color("fff0cc"))
	var glass := level.get_child(level.get_child_count() - 1) as MeshInstance3D
	(glass.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for x: float in [-2.85, 2.85]:
		for z: float in [-2.85, 2.85]:
			box(level, "signal_lantern_post_%s_%s" % [x, z], Vector3(60 + x, 28.1, -265 + z), Vector3(0.22, 2.8, 0.22), STEEL)
	box(level, "signal_lantern_roof", Vector3(60, 29.9, -265), Vector3(8, 0.8, 8), PALE)
	box(level, "signal_lantern_edge", Vector3(60, 30.33, -265), Vector3(8.08, 0.12, 8.08), Color("a4734e"))
	box(level, "signal_mast", Vector3(60, 31.2, -265), Vector3(0.15, 1.6, 0.15), STEEL)

static func box(level: Node3D, id: String, at: Vector3, size: Vector3, color: Color, yaw := 0.0) -> void:
	level._box("Art_drydock_" + id, at, size, color)
	var node := level.get_child(level.get_child_count() - 1) as MeshInstance3D
	node.rotation.y = yaw
	if not is_zero_approx(yaw):
		level.art_manifest.append(["drydock_rotation", id, yaw])

static func headland(level: Node3D) -> void:
	# the coast stays behind the signal foundation and causeway so it cannot hide their water contact.
	var heights := [12.0, 15.0, 15.0, 23.0, 26.0, 24.0, 17.0, 18.0, 29.0, 32.0, 26.0, 22.0, 14.0, 12.0, 17.0, 15.0, 9.0]
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for i: int in (heights.size() - 1) * 4:
		var a := ridge(heights, float(i) / 4)
		var b := ridge(heights, float(i + 1) / 4)
		var c := Vector3(a.x, a.y * 0.25, a.z + 15)
		var d := Vector3(b.x, b.y * 0.25, b.z + 15)
		vertices.append_array(PackedVector3Array([a, c, b, b, c, d]))
		var shade_a := Color("81968e").lerp(Color("9ca99b"), 0.5 + 0.5 * sin(a.x * 0.008))
		var shade_b := Color("81968e").lerp(Color("9ca99b"), 0.5 + 0.5 * sin(b.x * 0.008))
		colors.append_array(PackedColorArray([shade_a, Color("7f938c"), shade_b, shade_b, Color("7f938c"), Color("7f938c")]))
		var e := Vector3(c.x, -5, c.z + 6)
		var f := Vector3(d.x, -5, d.z + 6)
		vertices.append_array(PackedVector3Array([c, e, d, d, e, f]))
		colors.append_array(PackedColorArray([Color("7f938c"), Color("718a87"), Color("7f938c"), Color("7f938c"), Color("718a87"), Color("718a87")]))
	var mesh := ArrayMesh.new()
	for i: int in colors.size():
		colors[i] = colors[i].lerp(colors[i].srgb_to_linear(), 0.45)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = "Art_drydock_headland"
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	level.add_child(node)
	level.art_manifest.append(["drydock_headland", heights, "original continuous coast mesh v3, smooth ridge and atmospheric scarp gradients"])

static func ridge(heights: Array, u: float) -> Vector3:
	var index := mini(floori(u), heights.size() - 2)
	var t := clampf(u - index, 0, 1)
	var height := lerpf(heights[index], heights[index + 1], t * t * (3 - 2 * t))
	return Vector3(-350 + u * 42, height, -345 - 6 * sin(u * 0.55) - 3 * sin(u * 1.7))

extends RefCounted
## mail run in look c: a postal quay. pale running deck, weathered blue posting houses whose
## slots read as one pale panel with an ink mouth and an orange lip, a lettered dispatch arch and
## the mail packet moored past it. presentation only: map nodes keep their meshes and collision,
## and everything added here sits under the look layer with no collision.
const SURFACE := preload("res://shaders/look/surface.gdshader")
const WEAR := preload("res://assets/look/painted-wear.png")
const UI := preload("res://scripts/r18_ui_theme.gd")

const DECK := Color("d9cfc2")
const PALE := Color("f1ead8")
const STONE := Color("d9d0bb")
const SIDE := Color("66868e")
const HOUSE := Color("7799a4")
const INK := Color("18272e")
const EDGE := Color("e15a2b")
const POSTS := [Vector3(12, 4, -14), Vector3(-12, 4, -52), Vector3(12, 4, -90)]

var _materials := {}
var _labels: Array[Dictionary] = []
var _hidden: Array[Node] = []

func material(key: String, node: GeometryInstance3D, proposed: Material) -> Material:
	if not key.begins_with("Mail_"):
		return proposed
	var id := key.trim_prefix("Mail_")
	if id.begins_with("quay_"):
		return _surface("deck", DECK, SIDE, 0.2, 1.0)
	if id.begins_with("seawall"):
		return _surface("seawall", DECK, SIDE, 0.42, 0.0)
	if id.begins_with("post_cap") or id.begins_with("post_plinth"):
		return _surface("cornice", PALE, STONE, 0.12, 0.0)
	if id.begins_with("post_"):
		return _surface("house", PALE, HOUSE, 0.38, 0.0)
	if id.begins_with("arch_pier") or id == "sorting_arch":
		return _surface("house", PALE, HOUSE, 0.38, 0.0)
	if id.begins_with("slot_") or id.begins_with("collection_plate"):
		# the slot surround is painted, so it stays readable when the face is in shade.
		return _flat("panel", Color("e2dac6"), true)
	if id.begins_with("mouth"):
		return _flat("mouth", INK, true)
	if id.begins_with("lip_"):
		return _flat("lip", EDGE, true)
	if id.begins_with("apron_lip") or id.begins_with("station_joint"):
		# the court edge is not a takeoff, so it is drawn as an ink joint, not orange.
		return _flat("joint", Color("38525b"), true)
	if id.begins_with("apron_drain"):
		return _flat("drain", Color("7d9396"), false)
	if id.begins_with("apron"):
		return _flat("apron", Color("e2dccb"), false)
	return proposed

func dress(level: Node3D) -> Node3D:
	var root := Node3D.new()
	for i: int in POSTS.size():
		var at: Vector3 = POSTS[i]
		var face := -1.0 if i == 1 else 1.0
		# one pale panel around the slot, so the ink mouth and orange lip read from the quay.
		_box(root, "slot_panel_%d" % i, at + Vector3(0, 0.12, 0.13 * face), Vector3(3.2, 3.0, 0.06), _flat("panel", Color("e2dac6"), true))
		# the post number is painted on the house face instead of floating over the roof.
		_stencil(root, "%02d" % (i + 1), at + Vector3(-2.4 * face, -0.35, 0.115 * face), PI if face < 0 else 0.0, 0.014, PALE)
	# post 02 faces away from spawn, so its back says where the slot is.
	_stencil(root, "02", Vector3(-12, 4.75, -50.085), 0.0, 0.012, PALE)
	_stencil(root, "SLOT ON THE FAR SIDE", Vector3(-12, 3.35, -50.085), 0.0, 0.0028, PALE)
	_stencil(root, "DISPATCH", Vector3(0, 17.0, -122.47), 0.0, 0.013, PALE)
	_box(root, "arch_cornice", Vector3(0, 18.62, -125), Vector3(19.4, 0.24, 5.4), _surface("cornice", PALE, STONE, 0.12, 0.0))
	_packet(root)
	for node: Node in level.get_children():
		var name := str(node.name)
		if node is Label3D:
			if name.begins_with("Mail_post_number_") or name == "Mail_finish" or name == "Mail_rear_notice":
				_hidden.append(node)
			else:
				_labels.append({"node": node, "font": (node as Label3D).font, "modulate": (node as Label3D).modulate})
	return root

func set_enabled(value: bool) -> void:
	for node: Node in _hidden:
		if is_instance_valid(node):
			(node as Label3D).visible = not value
	for state: Dictionary in _labels:
		if is_instance_valid(state.node):
			state.node.font = UI.font("label") if value else state.font
			state.node.modulate = INK if value else state.modulate

func _packet(root: Node3D) -> void:
	# the mail packet lies across the quay head beyond dispatch: where the post is going.
	var hull := MeshInstance3D.new()
	hull.name = "packet_hull"
	hull.mesh = _extrude(PackedVector2Array([Vector2(-14, -6.8), Vector2(10.5, -6.8), Vector2(14.6, 1.7), Vector2(13.4, 1.7), Vector2(-13.2, 1.15), Vector2(-14.4, 1.35)]), 5.2)
	hull.position = Vector3(0, 2.6, -141.6)
	hull.material_override = _surface("hull", Color("d8d1bf"), Color("2c4752"), 0.3, 0.0)
	root.add_child(hull)
	_box(root, "packet_boot", Vector3(-1.7, -3.7, -141.6), Vector3(24.8, 0.5, 5.26), _flat("boot", Color("c9c1ad"), false))
	_box(root, "packet_deck", Vector3(-0.2, 3.8, -141.6), Vector3(26.4, 0.12, 4.8), _surface("deck", DECK, SIDE, 0.2, 1.0))
	_box(root, "packet_saloon", Vector3(-3.5, 5.15, -141.6), Vector3(10.0, 2.6, 3.8), _surface("cabin", PALE, Color("e3dccb"), 0.15, 0.0))
	_box(root, "packet_windows", Vector3(-3.5, 5.35, -139.68), Vector3(8.8, 0.62, 0.04), _flat("mouth", INK, true))
	_box(root, "packet_bridge", Vector3(-5.0, 7.35, -141.6), Vector3(4.6, 1.8, 3.4), _surface("cabin", PALE, Color("e3dccb"), 0.15, 0.0))
	_box(root, "packet_bridge_glass", Vector3(-5.0, 7.55, -139.88), Vector3(4.0, 0.55, 0.04), _flat("mouth", INK, true))
	_box(root, "packet_roof", Vector3(-3.5, 6.52, -141.6), Vector3(10.6, 0.14, 4.3), _flat("pale", PALE, false))
	var funnel := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.82
	tube.bottom_radius = 0.9
	tube.height = 4.4
	tube.radial_segments = 20
	funnel.mesh = tube
	funnel.position = Vector3(3.6, 6.6, -141.6)
	funnel.material_override = _surface("funnel", Color("2c4752"), Color("2c4752"), 0.2, 0.0)
	root.add_child(funnel)
	var band := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.87
	ring.bottom_radius = 0.88
	ring.height = 0.55
	ring.radial_segments = 20
	band.mesh = ring
	band.position = Vector3(3.6, 7.9, -141.6)
	band.material_override = _flat("pale", PALE, false)
	root.add_child(band)
	_box(root, "packet_mast", Vector3(9.0, 7.8, -141.6), Vector3(0.18, 8.0, 0.18), _flat("mast", Color("2c4752"), false))
	_box(root, "packet_yard", Vector3(9.0, 10.2, -141.6), Vector3(0.12, 0.12, 3.4), _flat("mast", Color("2c4752"), false))

func _extrude(outline: PackedVector2Array, depth: float) -> ArrayMesh:
	# a side profile pushed across the beam: flat sheer, raked bow, square stern.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := depth * 0.5
	var centre := Vector2.ZERO
	for p: Vector2 in outline:
		centre += p / outline.size()
	var caps := Geometry2D.triangulate_polygon(outline)
	for z: float in [half, -half]:
		for t: int in range(0, caps.size(), 3):
			var a: Vector2 = outline[caps[t]]
			var b: Vector2 = outline[caps[t + 1]]
			var c: Vector2 = outline[caps[t + 2]]
			_triangle(tool, Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(c.x, c.y, z), Vector3(0, 0, signf(z)))
	for i: int in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var edge := b - a
		var out := Vector3(edge.y, -edge.x, 0)
		if out.dot(Vector3((a + b).x * 0.5 - centre.x, (a + b).y * 0.5 - centre.y, 0)) < 0.0:
			out = -out
		_triangle(tool, Vector3(a.x, a.y, half), Vector3(a.x, a.y, -half), Vector3(b.x, b.y, -half), out)
		_triangle(tool, Vector3(a.x, a.y, half), Vector3(b.x, b.y, -half), Vector3(b.x, b.y, half), out)
	tool.generate_normals()
	return tool.commit()

func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	# godot treats clockwise triangles as front faces.
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var swap := b
		b = c
		c = swap
	for v: Vector3 in [a, b, c]:
		tool.add_vertex(v)

func _stencil(root: Node3D, text: String, at: Vector3, turn: float, pixels: float, color: Color) -> void:
	var label := Label3D.new()
	label.name = "stencil_" + text
	label.text = text
	label.font = UI.font("display")
	label.font_size = 128
	label.pixel_size = pixels
	label.modulate = color
	label.outline_size = 0
	label.double_sided = false
	label.position = at
	label.rotation.y = turn
	root.add_child(label)

func _box(root: Node3D, id: String, at: Vector3, size: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	root.add_child(node)

func _surface(key: String, top: Color, side: Color, wear: float, deck: float) -> ShaderMaterial:
	if not _materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SURFACE
		mat.set_shader_parameter("wear", WEAR)
		mat.set_shader_parameter("top_color", top)
		mat.set_shader_parameter("side_color", side)
		mat.set_shader_parameter("wear_amount", wear)
		mat.set_shader_parameter("deck", deck)
		_materials[key] = mat
	return _materials[key]

func _flat(key: String, color: Color, unshaded: bool) -> StandardMaterial3D:
	var id := "flat_" + key
	if not _materials.has(id):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.95
		if unshaded:
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[id] = mat
	return _materials[id]

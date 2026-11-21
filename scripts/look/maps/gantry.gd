extends RefCounted
## design 1121 look pass for Gantry and Gantry Chain: presentation only.
## nothing here calls level._box() or touches manifest/art_manifest, so geometry_hash() and the
## recording identity stay exact. new pieces are plain meshes with no collision, outside the
## swing corridor (|x| <= 6.5) and above every deck.

const SHELL := Color("cdc8bf")
const SIDE := Color("62787c")
const WEAR := Color("9a9c8c")
const CARRIAGE := Color("e0d6bf")
const CAB := Color("c4bca8")
const GLASS := Color("22363c")
const RING := Color("d2683a")

static func dress(level: Node3D) -> void:
	_surfaces(level)
	_caisson(level)
	_lips(level)
	for anchor: Node in level.get_children():
		if anchor is Node3D and str(anchor.name).begins_with("Anchor_"):
			var index := int(str(anchor.name).trim_prefix("Anchor_")) - 1
			_anchor(level, index, anchor as Node3D)

static func _lips(level: Node3D) -> void:
	# each slot takeoff gets a band as deep as its receiver, so the choice edge reads from mid-apron.
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("cf7746")
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for node: Node in level.get_children():
		var id := str(node.name)
		if not (id.begins_with("Art_paint_orange_lip_") or id == "Art_chain_takeoff"):
			continue
		var lip := node as MeshInstance3D
		lip.material_override = paint
		var band := MeshInstance3D.new()
		band.name = "Look_takeoff_band_" + id.trim_prefix("Art_")
		var mesh := BoxMesh.new()
		mesh.size = Vector3((lip.mesh as BoxMesh).size.x, 0.014, 0.55)
		band.mesh = mesh
		band.position = Vector3(lip.position.x, 4.008, lip.position.z - 0.12 + 0.275)
		band.material_override = paint
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(band)

static func _surfaces(level: Node3D) -> void:
	# warm shell tops that no longer clip to white, weathered blue-grey sides instead of near black.
	var concrete := level.get_node("Mesh_deck_apron_0_pad_-1").material_override as ShaderMaterial
	var materials: Array[ShaderMaterial] = [concrete]
	var runout := level.get_node_or_null("Mesh_deck_dispatch_runout") as MeshInstance3D
	if runout != null and runout.material_override is ShaderMaterial and runout.material_override != concrete:
		materials.append(runout.material_override)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("top_color", SHELL)
		material.set_shader_parameter("side_color", SIDE)
		material.set_shader_parameter("wear_color", WEAR)
		material.set_shader_parameter("wear_amount", 0.45)
		material.set_shader_parameter("weather", 1.0)
		# deck tops sit with Tether and Viaduct's value under lane 02's light (a stronger lift turned them yellow).
		material.set_shader_parameter("top_gain", 0.94)
	# the cross-bearings seen between hop planks read as lit steel, not black stripes.
	var bearing := level.get_node_or_null("Mesh_gantry_bearing_bearing_0_-1") as MeshInstance3D
	if bearing != null and bearing.material_override is StandardMaterial3D:
		(bearing.material_override as StandardMaterial3D).albedo_color = Color("a19d8b")

static func _caisson(level: Node3D) -> void:
	# the gate's navy skin behind pale ribs read as a glazed facade; plate and ribs now share one
	# weathered steel so the caisson reads as a single fabricated load with runoff down its face.
	var skin := level.get_node_or_null("Art_drydock_gate_skin") as MeshInstance3D
	if skin == null or not skin.material_override is ShaderMaterial:
		return
	var plate := skin.material_override as ShaderMaterial
	plate.set_shader_parameter("side_color", Color("a9b6b5"))
	plate.set_shader_parameter("weather", 1.0)
	# a lighter plate (this shader renders mid tones far darker than their albedo) with darker runoff and
	# joint wear, so the gate carries the same weathering as the aprons instead of one flat dark tone.
	plate.set_shader_parameter("wear_color", Color("5f6c6b"))
	plate.set_shader_parameter("wear_amount", 0.85)
	# frame, ends, ribs and stiffeners take the plate's own material, so the grid reads only by its edges.
	for node: Node in level.get_children():
		var id := str(node.name)
		for part: String in ["gate_frame_", "gate_end_", "gate_rib_", "gate_stiffener_"]:
			if id.begins_with("Art_drydock_" + part) and node is MeshInstance3D:
				(node as MeshInstance3D).material_override = plate

static func _anchor(level: Node3D, index: int, anchor: Node3D) -> void:
	# the ring is signal paint: unshaded so it keeps its colour under the beam's shadow.
	var ring := anchor.get_node_or_null("Art_paint_orange_anchor") as MeshInstance3D
	if ring != null:
		var paint := StandardMaterial3D.new()
		paint.albedo_color = RING
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = paint
	# a pale lifting carriage separates the ring from the dark crossbeam at distance.
	var carriage := level.get_node_or_null("Art_gantry_carriage_%d" % index) as MeshInstance3D
	if carriage != null:
		var pale := StandardMaterial3D.new()
		pale.albedo_color = CARRIAGE
		pale.roughness = 1.0
		pale.next_pass = carriage.material_override.next_pass if carriage.material_override != null else null
		carriage.material_override = pale
	_cab(level, index, anchor.position)

static func _cab(level: Node3D, index: int, at: Vector3) -> void:
	# an operator cab hung off the left leg says "working crane": a cab-sized body with a wrapped window
	# band, a floor platform with a rail, and a ladder down the leg, so it reads as a room and not a lamp.
	# everything sits outside the leg (x <= -12.65), far from the swing corridor.
	var y := at.y - 3.0
	var root := Node3D.new()
	root.name = "Look_gantry_cab_%d" % index
	root.position = Vector3(-14.75, y, at.z)
	level.add_child(root)
	_piece(root, "body", Vector3.ZERO, Vector3(2.8, 2.6, 3.2), CAB, true)
	_piece(root, "roof", Vector3(0, 1.38, 0), Vector3(3.05, 0.16, 3.45), GLASS, true)
	_piece(root, "glazing_front", Vector3(0, 0.4, 1.61), Vector3(2.5, 1.0, 0.03), GLASS, false)
	_piece(root, "glazing_back", Vector3(0, 0.4, -1.61), Vector3(2.5, 1.0, 0.03), GLASS, false)
	_piece(root, "glazing_side", Vector3(-1.41, 0.4, 0), Vector3(0.03, 1.0, 2.9), GLASS, false)
	_piece(root, "platform", Vector3(0.2, -1.38, 0), Vector3(3.6, 0.16, 4.2), GLASS, true)
	for z: float in [-2.05, 2.05]:
		_piece(root, "rail_%s" % z, Vector3(0.2, -0.85, z), Vector3(3.6, 0.07, 0.07), GLASS, false)
		for x: float in [-1.55, 1.95]:
			_piece(root, "rail_post_%s_%s" % [z, x], Vector3(x, -1.1, z), Vector3(0.07, 0.55, 0.07), GLASS, false)
	# a ladder on the leg's near face, from the quay rail up to the cab platform.
	var foot := 4.65
	var head := y - 1.46
	if head > foot + 1.0:
		var ladder := Node3D.new()
		ladder.name = "Look_gantry_ladder_%d" % index
		ladder.position = Vector3(-13.0, 0, at.z + 0.5)
		level.add_child(ladder)
		for x: float in [-0.22, 0.22]:
			_piece(ladder, "stile_%s" % x, Vector3(x, (foot + head) * 0.5, 0), Vector3(0.06, head - foot, 0.06), GLASS, false)
		var rung := foot + 0.3
		while rung < head:
			_piece(ladder, "rung_%s" % rung, Vector3(0, rung, 0), Vector3(0.44, 0.04, 0.04), GLASS, false)
			rung += 0.45

static func _piece(root: Node3D, id: String, at: Vector3, size: Vector3, color: Color, inked: bool) -> void:
	var node := MeshInstance3D.new()
	node.name = id
	node.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if inked:
		var outline := ShaderMaterial.new()
		outline.shader = preload("res://assets/maps/gantry/outline.gdshader")
		material.next_pass = outline
	node.material_override = material
	root.add_child(node)

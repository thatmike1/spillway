extends RefCounted
## saltglass in look c: the map-local surface and sea shaders switch to shell-white decks,
## salt-white pans, a slope that fades to sea-glass at its toe and a lighter sea, only with L on.
## pumps and the brine header become one mid-tone line of plant instead of dark lumps, and the
## work lamp and the instruction lettering on the store wall step aside. L off keeps the r22
## materials and nodes by reference; no solid, identity or route changes.
const SURFACE := preload("res://shaders/look/surface.gdshader")
const WEAR := preload("res://assets/look/painted-wear.png")
## the lamp whose pole and head cross the "SALT 04 / OUTER QUAY" lettering seen from the quay.
const SIGN_LAMP := "quay_210"

var _plant: ShaderMaterial
var _pipe: StandardMaterial3D
var _hidden: Array[Node3D] = []
var _level: Node3D
var _stencil: Label3D
var _stencil_text := ""
var _lip_old := {}
var _ink: StandardMaterial3D

func material(key: String, node: GeometryInstance3D, proposed: Material) -> Material:
	if key.begins_with("SaltglassSurface_") or key == "SaltglassWater":
		var original := node.material_override as ShaderMaterial
		if original == null:
			return proposed
		var copy := original.duplicate() as ShaderMaterial
		copy.set_shader_parameter("look_c", true)
		return copy
	if key.begins_with("Art_pan_pump_") or key.begins_with("Art_pump_foot_"):
		return _plant_material()
	if key.begins_with("Art_paint_dark_brine_header_"):
		return _pipe_material()
	if key.ends_with(SIGN_LAMP) and key.begins_with("Art_lamp_"):
		_hidden.append(node)
	return proposed

func dress(level: Node3D) -> Node3D:
	_level = level
	# the outer-quay instruction lettering leaves the store wall with L on; the orange lips mark it.
	var sign := level.get_node_or_null("Sign_outer_quay") as Node3D
	if sign != null:
		_hidden.append(sign)
	_stencil = level.get_node_or_null("Sign_store_stencil") as Label3D
	# the store reads as a building: a loading door on its quay face and a pale cornice on its roof
	# edge. the store solid occupies x 215..220, z 40..54, y 5.3..11.3; nothing here collides.
	var root := Node3D.new()
	_box(root, Vector3(214.96, 7.05, 44.0), Vector3(0.04, 3.5, 3.4), Color("e3dccb"))
	_box(root, Vector3(214.94, 6.95, 44.0), Vector3(0.04, 3.3, 3.0), Color("1c2c33"))
	_box(root, Vector3(217.5, 11.42, 47.0), Vector3(5.3, 0.24, 14.3), Color("e3dccb"))
	return root

func _box(root: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var flat := StandardMaterial3D.new()
	flat.albedo_color = color
	flat.roughness = 0.95
	node.material_override = flat
	root.add_child(node)

func _lips(value: bool) -> void:
	# with L on, pan and deck lips are a crisp ink edge instead of a pale band; saltglass's own
	# deferred fixture paints them pale first, so this runs deferred after it.
	if _level == null or not is_instance_valid(_level):
		return
	if _ink == null:
		_ink = StandardMaterial3D.new()
		_ink.albedo_color = Color("24383f")
		_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	for node: Node in _level.find_children("JumpLips", "MeshInstance3D", true, false):
		var lip := node as MeshInstance3D
		if value:
			# remember whatever the map last painted, so L off returns exactly that.
			if lip.material_override != _ink:
				_lip_old[lip] = lip.material_override
			lip.material_override = _ink
		elif _lip_old.has(lip):
			lip.material_override = _lip_old[lip]

func set_enabled(value: bool) -> void:
	_lips.call_deferred(value)
	if _stencil != null and is_instance_valid(_stencil):
		if _stencil_text.is_empty():
			_stencil_text = _stencil.text
		_stencil.text = "SALT" if value else _stencil_text
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = not value

func _plant_material() -> ShaderMaterial:
	if _plant == null:
		_plant = ShaderMaterial.new()
		_plant.shader = SURFACE
		_plant.set_shader_parameter("wear", WEAR)
		_plant.set_shader_parameter("top_color", Color("e6dfcf"))
		_plant.set_shader_parameter("side_color", Color("7b9aa3"))
		_plant.set_shader_parameter("wear_amount", 0.25)
		_plant.set_shader_parameter("deck", 0.0)
	return _plant

func _pipe_material() -> StandardMaterial3D:
	if _pipe == null:
		_pipe = StandardMaterial3D.new()
		_pipe.albedo_color = Color("6f8f99")
		_pipe.roughness = 0.9
	return _pipe

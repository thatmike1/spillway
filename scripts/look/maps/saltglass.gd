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
	# the outer-quay instruction lettering leaves the store wall with L on; the orange lips mark it.
	var sign := level.get_node_or_null("Sign_outer_quay") as Node3D
	if sign != null:
		_hidden.append(sign)
	return null

func set_enabled(value: bool) -> void:
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

extends RefCounted
## sunken court, look C only: a drowned water temple in warm limestone. pale flagged tops you land
## on, weathered sandstone faces, and fewer, larger things round it: the toy pines, wall-top
## obelisks, broken columns and hanging moss strips that were scattered to fill space hide while
## L is on, and the far pine groves stay as one quiet painted backdrop. nothing here collides.

## tops a touch cooler so full sun no longer clips them; faces a warm weathered sandstone instead
## of the khaki that read olive in shade.
const PALETTE := {"top": "e4dccd", "side": "a68b6f"}
const SURFACES := {
	"ashlar": {"side_color": "a08467", "top_color": "c9b79c", "wear_amount": 0.22},
	"vault": {"side_color": "8a6f56", "top_color": "b9a284", "wear_amount": 0.25},
	"column": {"side_color": "c4b096", "top_color": "ddd1bd", "wear_amount": 0.12},
	"cliff": {"side_color": "7d6a58", "top_color": "8f8a6a", "wear_amount": 0.3},
}
## far groves: one cool painted green, so distance reads and nothing looks like a toy.
const FAR_PINE := "5d7466"
## assets hidden under L on: filler that explains nothing about the place.
const FILLER := ["statue_columnDamaged", "hanging_moss", "grass_leafs", "plant_bushSmall", "log"]

var _hidden: Array[Node3D] = []
var _pine_material: ShaderMaterial

func material(key: String, node: GeometryInstance3D, proposed: Material) -> Material:
	var asset := _asset_of(node)
	if asset.contains("tree_pine") and _is_far(node):
		if _pine_material == null:
			_pine_material = ShaderMaterial.new()
			_pine_material.shader = load("res://shaders/look/surface.gdshader")
			_pine_material.set_shader_parameter("top_color", Color(FAR_PINE).lightened(0.12))
			_pine_material.set_shader_parameter("side_color", Color(FAR_PINE))
			_pine_material.set_shader_parameter("wear_amount", 0.0)
			_pine_material.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
		return _pine_material
	return proposed

func dress(level: Node3D) -> Node3D:
	var scenery := level.get_node_or_null("Scenery")
	if scenery == null:
		return null
	var s: Array = (level.get_script() as Script).get_script_constant_map().SANCTUARY
	for child: Node in scenery.get_children():
		if not child is Node3D:
			continue
		var wrapper := child as Node3D
		var asset := str(wrapper.get_meta("r15_asset", "")).get_file().get_basename()
		var hide := asset in FILLER
		if asset.begins_with("tree_pine") or asset == "plant_bush":
			hide = not _far(wrapper.position)
		elif asset == "statue_obelisk":
			# the three on the sanctuary parapet mark the finish; the others are scattered markers.
			var p := wrapper.position
			hide = not (p.x > float(s[0]) - 1.0 and p.x < float(s[1]) + 1.0 and p.z > float(s[2]) - 1.0 and p.z < float(s[3]) + 1.0)
		if hide:
			_hidden.append(wrapper)
	return null

func set_enabled(value: bool) -> void:
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = not value

func _far(p: Vector3) -> bool:
	# the court and cloister fill x -24..57; groves beyond those flanks read as one backdrop.
	return p.x < -30.0 or p.x > 60.0

func _is_far(node: Node) -> bool:
	var at := node
	while at != null:
		if at is Node3D and (at as Node3D).has_meta("r15_asset"):
			return _far((at as Node3D).position)
		at = at.get_parent()
	return false

func _asset_of(node: Node) -> String:
	var at := node
	while at != null:
		if at.has_meta("r15_asset"):
			return str(at.get_meta("r15_asset"))
		at = at.get_parent()
	return ""

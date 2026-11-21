extends RefCounted
## rainline, look C only: rooftops of a rainy city at night. the decks join the pale family the
## other maps use (warm limestone, not blue-grey), the neon shop signs become painted enamel
## signs in warm off-white and amber, and painted floor and wall figures hide while L is on.
## nothing here collides.

## decks a damp neutral a step darker than the dry-day family (e4dbca read dry and pale under
## the rain, critic 19:28), still the palest surface; sides of kinds not listed below
## (parapets, cappings) join the concrete family, not the navy.
const PALETTE := {"top": "cdc8bf", "side": "78736c"}
## the facades were one navy with the sky: wet brick, concrete and render give the street its
## materials back and separate the buildings from each other and from the night. the art file
## splits each kind into grid cells (Mesh_brick_3_-2), so these match on the kind before the cell.
## roof decks carry joints and broad tonal variation (deck, deck_mottle), so the near roof is not a
## blank plane (critic 19:28).
const FACADES := {
	"roof_tar": {"side_color": "8a6257", "wear_amount": 0.06, "streak_amount": 0.18, "deck": 0.7, "deck_mottle": 0.12},
	"roof_felt": {"side_color": "806057", "wear_amount": 0.06, "streak_amount": 0.18, "deck": 0.7, "deck_mottle": 0.12},
	"brick": {"side_color": "8a6257", "wear_amount": 0.06, "streak_amount": 0.18},
	"brick_cap": {"side_color": "8a6257", "wear_amount": 0.06, "streak_amount": 0.18},
	"facade_brick": {"side_color": "7f5c50", "top_color": "8d6a5e", "wear_amount": 0.06, "streak_amount": 0.18},
	"tower": {"side_color": "6f6663", "wear_amount": 0.06, "streak_amount": 0.15},
	"roof_gravel": {"side_color": "78736c", "wear_amount": 0.06, "streak_amount": 0.15, "deck": 0.7, "deck_mottle": 0.12},
	"concrete": {"side_color": "78736c", "wear_amount": 0.06, "streak_amount": 0.15, "deck": 0.7, "deck_mottle": 0.12},
	"facade_dark": {"side_color": "5e5c59", "top_color": "6b6966", "wear_amount": 0.06, "streak_amount": 0.15},
	"render": {"side_color": "a39a88", "wear_amount": 0.05, "streak_amount": 0.12},
	"facade_render": {"side_color": "948b7a", "top_color": "a39a88", "wear_amount": 0.05, "streak_amount": 0.12},
}
## rooftop plant from the factory kit came in periwinkle: galvanised grey instead, set per
## surface on the reachable props (their collision is the level's; only colour changes).
const PLANT := {"side": "868279", "top": "a7a298"}
const ENAMEL := [Color("efe3c8"), Color("e6b45c")]

var _hidden: Array[Node3D] = []
var _signs: Array[Dictionary] = []

var _plant: Array[MeshInstance3D] = []
var _plant_prior: Array[Material] = []
var _galvanised: ShaderMaterial

func dress(level: Node3D) -> Node3D:
	for child: Node in level.get_children():
		if child is Node3D and str(child.name).begins_with("Prop_") and "kenney-factory" in str(child.get_meta("r15_asset", "")):
			for mesh: Node in child.find_children("*", "MeshInstance3D", true, false):
				var unit := mesh as MeshInstance3D
				if unit.mesh == null:
					continue
				_plant.append(unit)
				for k: int in unit.mesh.get_surface_count():
					_plant_prior.append(unit.get_surface_override_material(k))
	_galvanised = ShaderMaterial.new()
	_galvanised.shader = load("res://shaders/look/surface.gdshader")
	_galvanised.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
	_galvanised.set_shader_parameter("side_color", Color(PLANT.side))
	_galvanised.set_shader_parameter("top_color", Color(PLANT.top))
	_galvanised.set_shader_parameter("wear_amount", 0.06)
	_galvanised.set_shader_parameter("metal", 0.0)
	var i := 0
	for child: Node in level.get_children():
		if not child is Label3D:
			continue
		var label := child as Label3D
		if str(label.name).begins_with("Label_"):
			_hidden.append(label)
		elif label.font_size == 128:
			_signs.append({"node": label, "old": label.modulate, "new": ENAMEL[i % ENAMEL.size()]})
			i += 1
	return null

## the shared look builds one material per mesh; this recolours it in place by the mesh's kind.
func material(key: String, _node: Node, proposed: Material) -> Material:
	if not proposed is ShaderMaterial or not key.begins_with("Mesh_"):
		return proposed
	var kind := key.trim_prefix("Mesh_")
	var cell := RegEx.create_from_string("_-?\\d+_-?\\d+$")
	kind = cell.sub(kind, "")
	if not FACADES.has(kind):
		return proposed
	for parameter: String in FACADES[kind]:
		var value: Variant = FACADES[kind][parameter]
		(proposed as ShaderMaterial).set_shader_parameter(parameter, Color(value) if value is String else value)
	return proposed

func set_enabled(value: bool) -> void:
	var n := 0
	for unit: MeshInstance3D in _plant:
		for k: int in unit.mesh.get_surface_count():
			if is_instance_valid(unit):
				unit.set_surface_override_material(k, _galvanised if value else _plant_prior[n])
			n += 1
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = not value
	for sign: Dictionary in _signs:
		if is_instance_valid(sign.node):
			(sign.node as Label3D).modulate = sign.new if value else sign.old

extends RefCounted
## rainline, look C only: rooftops of a rainy city at night. the decks join the pale family the
## other maps use (warm limestone, not blue-grey), the neon shop signs become painted enamel
## signs in warm off-white and amber, and painted floor and wall figures hide while L is on.
## nothing here collides.

const PALETTE := {"top": "e4dbca"}
## the facades were one navy with the sky: wet brick, concrete and render give the street its
## materials back and separate the buildings from each other and from the night.
const SURFACES := {
	"roof_tar": {"side_color": "74504a", "wear_amount": 0.2},
	"roof_felt": {"side_color": "6c4b46", "wear_amount": 0.2},
	"brick": {"side_color": "74504a", "wear_amount": 0.2},
	"tower": {"side_color": "655a5a", "wear_amount": 0.15},
	"brick_cap": {"side_color": "74504a", "wear_amount": 0.2},
	"roof_gravel": {"side_color": "5f6b73", "wear_amount": 0.18},
	"concrete": {"side_color": "5f6b73", "wear_amount": 0.18},
	"render": {"side_color": "a39a88", "wear_amount": 0.12},
}
const ENAMEL := [Color("efe3c8"), Color("e6b45c")]

var _hidden: Array[Node3D] = []
var _signs: Array[Dictionary] = []

func dress(level: Node3D) -> Node3D:
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

func set_enabled(value: bool) -> void:
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = not value
	for sign: Dictionary in _signs:
		if is_instance_valid(sign.node):
			(sign.node as Label3D).modulate = sign.new if value else sign.old

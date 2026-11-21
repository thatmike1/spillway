extends RefCounted
## sunken court, look C only: a drowned water temple in warm limestone. pale flagged tops you land
## on, weathered sandstone faces, and fewer, larger things round it: the toy pines, wall-top
## obelisks, broken columns and hanging moss strips that were scattered to fill space hide while
## L is on, and the low-poly pine groves. nothing here collides.

## tops a touch cooler so full sun no longer clips them; faces a warm weathered sandstone instead
## of the khaki that read olive in shade.
const PALETTE := {"top": "e6dccb", "side": "c99c6c"}
const SURFACES := {
	"ashlar": {"side_color": "c4966a", "top_color": "d8c6a6", "wear_amount": 0.22},
	"vault": {"side_color": "a8805a", "top_color": "cbb391", "wear_amount": 0.25},
	"column": {"side_color": "c4b096", "top_color": "ddd1bd", "wear_amount": 0.12},
	"cliff": {"side_color": "7d6a58", "top_color": "8f8a6a", "wear_amount": 0.3},
}
## assets hidden under L on: filler that explains nothing about the place.
const FILLER := ["statue_columnDamaged", "hanging_moss", "grass_leafs", "plant_bushSmall", "log"]

var _hidden: Array[Node3D] = []

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
			hide = true
		elif asset == "statue_obelisk":
			# the three on the sanctuary parapet mark the finish; the others are scattered markers.
			var p := wrapper.position
			hide = not (p.x > float(s[0]) - 1.0 and p.x < float(s[1]) + 1.0 and p.z > float(s[2]) - 1.0 and p.z < float(s[3]) + 1.0)
		if hide:
			_hidden.append(wrapper)
	# floor lettering (gap widths, instructions) is teaching text, not the place; the gate sign stays.
	var marks := level.get_node_or_null("Markings")
	if marks != null:
		for label: Node in marks.get_children():
			if label is Label3D and str(label.name) != "GateSign":
				_hidden.append(label as Node3D)
	return null

func set_enabled(value: bool) -> void:
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = not value

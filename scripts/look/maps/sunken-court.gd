extends RefCounted
## sunken court, look C only: a drowned water temple in warm limestone. pale flagged tops you land
## on, weathered sandstone faces, and fewer, larger things round it: the toy pines, wall-top
## obelisks, broken columns and hanging moss strips that were scattered to fill space hide while
## L is on, and the low-poly pine groves. nothing here collides.

## decks near lane 01's shell-white (d9d5cb), nudged off green: the cyan fill and fog of this
## map's light turned d9d5cb into (227,239,218) and the sandstone into olive. full sun no longer clips;
## faces a warm weathered sandstone instead of the khaki that read olive in shade. wear is low
## and streaks carry the weathering: high wear read as camouflage spots on the big walls.
const PALETTE := {"top": "ddd3cc", "side": "b4957e"}
const SURFACES := {
	"ashlar": {"side_color": "b0917a", "top_color": "d6cbc2", "wear_amount": 0.06, "streak_amount": 0.18},
	"vault": {"side_color": "9a7c68", "top_color": "c9b9a9", "wear_amount": 0.06, "streak_amount": 0.18},
	"column": {"side_color": "c2ab97", "top_color": "d8ccc3", "wear_amount": 0.04, "streak_amount": 0.12},
	# deck kinds keep the palette top; their faces (under landings) streak instead of chipping.
	"flag": {"wear_amount": 0.03, "streak_amount": 0.18},
	"stair": {"wear_amount": 0.03, "streak_amount": 0.18},
	"architrave": {"wear_amount": 0.03, "streak_amount": 0.18},
	# the pool floor read as a flat saturated green under the water: a darker sea-glass stone.
	"pool_floor": {"top_color": "7d9089", "side_color": "6c7d77", "wear_amount": 0.03},
	"cliff": {"side_color": "7d6f60", "top_color": "8f8a6a", "wear_amount": 0.08, "streak_amount": 0.2},
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

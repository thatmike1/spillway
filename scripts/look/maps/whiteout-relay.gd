extends RefCounted
## whiteout relay, look C only: a radar station on a snow ridge. pale decks, weathered teal
## barriers and buildings instead of navy, and one landmark: the big dish on the far peak, with
## the receiver dish rising out of its pit near the end. the scattered plateau dishes, small
## sheds, loose machines and the pines crowding the road hide while L is on. reachable props
## (named Prop_*) are never touched: their collision is the level's. nothing here collides.

const PALETTE := {"side": "4f7880"}
## plateau dishes and small buildings that repeat the landmark at toy scale.
const FILLER := ["satelliteDish", "satelliteDish_detailed", "hangar_smallA", "machine_generator", "machine_generatorLarge", "machine_wireless", "supports_high"]

var _hidden: Array[Node3D] = []

func dress(level: Node3D) -> Node3D:
	var k: Dictionary = (level.get_script() as Script).get_script_constant_map()
	var receiver: Vector3 = k.RECEIVER
	for child: Node in level.get_children():
		if not child is Node3D or str(child.name).begins_with("Prop_") or not child.has_meta("r15_asset"):
			continue
		var wrapper := child as Node3D
		var asset := str(wrapper.get_meta("r15_asset")).get_file().get_basename()
		var p := wrapper.position
		var hide := asset in FILLER
		if asset == "satelliteDish_large":
			# keep the far landmark and the receiver; the plateau copies go.
			var landmark := p.y > 30.0
			var at_receiver := Vector2(p.x - receiver.x, p.z - receiver.z).length() < 4.0
			hide = not (landmark or at_receiver)
		elif asset.begins_with("tree_pine"):
			# pines stay only as far stands well off the road and the works.
			hide = absf(p.x) < 45.0
		if hide:
			_hidden.append(wrapper)
	# figures on decks and walls are teaching text; the station-name banner in the hangar too.
	var marks := level.get_node_or_null("Markings")
	if marks != null:
		for label: Node in marks.get_children():
			if not label is Label3D:
				continue
			var label_name := str(label.name)
			if not label_name.begins_with("Sign_") or label_name.begins_with("Sign_WHITEOUT"):
				_hidden.append(label as Node3D)
	return null

func set_enabled(value: bool) -> void:
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = not value

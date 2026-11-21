extends RefCounted
## night shift, look C only: a transit depot at night. the walls, the trains and the sky were one
## navy, so silhouettes vanished: walls become weathered moonlit concrete, the rolling stock an
## oxide red with pale roofs, so the train, both walls and the passage edges separate without
## brightening the floor. the cropped station banner and painted figures hide while L is on.
## nothing here collides.

const PALETTE := {"side": "56646f"}
## authored place signs that stay; any other label under Markings is a painted figure.
const SIGNS := ["Platform1", "Roundel_w", "Roundel_e", "ThroatSign", "BaysSign", "Door1", "Door2", "ShutterSign", "SignalBox", "TerminusSign", "LoopSign"]

var _hidden: Array[Node3D] = []
var _stock: ShaderMaterial

## the parked cars are kit models under the RollingStock group: one oxide-red body, pale roofs.
func material(_key: String, node: GeometryInstance3D, proposed: Material) -> Material:
	var at: Node = node.get_parent()
	while at != null:
		if str(at.name) == "RollingStock":
			if _stock == null:
				_stock = ShaderMaterial.new()
				_stock.shader = load("res://shaders/look/surface.gdshader")
				_stock.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
				_stock.set_shader_parameter("side_color", Color("7e4134"))
				_stock.set_shader_parameter("top_color", Color("d6cdb9"))
				_stock.set_shader_parameter("wear_amount", 0.18)
				_stock.set_shader_parameter("metal", 1.0)
			return _stock
		at = at.get_parent()
	return proposed

func dress(level: Node3D) -> Node3D:
	var marks := level.get_node_or_null("Markings")
	if marks != null:
		for label: Node in marks.get_children():
			if label is Label3D and not str(label.name) in SIGNS:
				# includes DepotSign, the banner that crops across the spawn view.
				_hidden.append(label as Node3D)
	return null

func set_enabled(value: bool) -> void:
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = not value

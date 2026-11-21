extends RefCounted
## night shift, look C only: a transit depot at night. the walls, the trains and the sky were one
## navy, so silhouettes vanished: walls become weathered moonlit concrete, cladding and brick, the
## rolling stock a muted green-grey with pale roofs (cool, so the orange lips stay the only warm
## line), and the train, both walls and the passage edges separate without brightening the floor. the cropped station banner and painted figures hide while L is on.
## nothing here collides.

## deck a moonlit concrete a step below lane 01's night value: dedad0 glowed blue-white as the
## brightest surface in the night (critic 19:28); the warmer e1d9c5 went mauve under the roof.
const PALETTE := {"top": "c9c6bd", "side": "7d7468"}
## authored place signs that stay; any other label under Markings is a painted figure.
## wall and roof-steel kinds get material and wear; the art file splits each kind into grid cells
## (Mesh_cladding_3_m2), so these match on the kind before the cell.
const WALLS := {
	"concrete": {"side_color": "86807a", "wear_amount": 0.08, "streak_amount": 0.3},
	"cladding": {"side_color": "6f7a7e", "wear_amount": 0.08, "streak_amount": 0.3},
	"brick": {"side_color": "75625a", "wear_amount": 0.08, "streak_amount": 0.3},
	# the trackbed slots between and beside the platforms: dark ballast, as the baseline read them,
	# so the corridor shows its track instead of pale hairlines.
	"bed": {"top_color": "3b4046", "side_color": "30353a", "wear_amount": 0.04, "deck": 0.0},
	"formwork": {"side_color": "7f7a70", "wear_amount": 0.08, "streak_amount": 0.3},
	# the canopy, its beams and columns: cool slate steel, a lit top and a darker side, so the
	# roof keeps the night mood against the sky instead of a flat mid grey.
	"girder": {"side_color": "46505d", "top_color": "8794a2", "wear_amount": 0.1},
	"steel": {"side_color": "505b68", "top_color": "8794a2", "wear_amount": 0.1},
	"roof": {"side_color": "56606c", "top_color": "7f8b98", "wear_amount": 0.12},
	"plate": {"side_color": "505b68", "top_color": "8794a2", "wear_amount": 0.1},
}
const SIGNS := ["Platform1", "Roundel_w", "Roundel_e", "ThroatSign", "BaysSign", "Door1", "Door2", "ShutterSign", "SignalBox", "TerminusSign", "LoopSign"]

var _hidden: Array[Node3D] = []
var _stock: ShaderMaterial
var _rail: ShaderMaterial

var _cars: Array[MeshInstance3D] = []
## each car surface's original override, captured before the layer applies anything.
var _prior: Array[Material] = []

func dress(level: Node3D) -> Node3D:
	# the parked cars are kit models under the RollingStock group: one green-grey body, pale roofs.
	# set per surface in set_enabled, after the layer's own swaps (not through material(): a
	# material_override on kit meshes logged render errors in captures).
	var stock := level.get_node_or_null("RollingStock")
	if stock != null:
		for mesh: Node in stock.find_children("*", "MeshInstance3D", true, false):
			var car := mesh as MeshInstance3D
			if car.mesh == null:
				continue
			_cars.append(car)
			for i: int in car.mesh.get_surface_count():
				_prior.append(car.get_surface_override_material(i))
		_stock = ShaderMaterial.new()
		_stock.shader = load("res://shaders/look/surface.gdshader")
		_stock.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
		_stock.set_shader_parameter("side_color", Color("586b62"))
		_stock.set_shader_parameter("top_color", Color("c9cfc8"))
		_stock.set_shader_parameter("wear_amount", 0.18)
		_stock.set_shader_parameter("metal", 0.0)
	var marks := level.get_node_or_null("Markings")
	if marks != null:
		for label: Node in marks.get_children():
			if label is Label3D and not str(label.name) in SIGNS:
				# includes DepotSign, the banner that crops across the spawn view.
				_hidden.append(label as Node3D)
	return null

## the shared look builds one material per wall mesh; this sets its kind's colour and wear in place.
func material(key: String, node: Node, proposed: Material) -> Material:
	# the kit rails sunk in the floors came through the shared prop shader in the pale deck top and
	# read as hairlines; dark rail steel puts the track slots back (per surface; node calls are null).
	if proposed is ShaderMaterial and node != null and "/Rails/" in str(node.get_path()):
		if _rail == null:
			_rail = ShaderMaterial.new()
			_rail.shader = load("res://shaders/look/surface.gdshader")
			_rail.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
			_rail.set_shader_parameter("top_color", Color("4a4f55"))
			_rail.set_shader_parameter("side_color", Color("2b2f34"))
			_rail.set_shader_parameter("wear_amount", 0.04)
			_rail.set_shader_parameter("deck", 0.0)
		return _rail
	if not proposed is ShaderMaterial or not key.begins_with("Mesh_"):
		return proposed
	var kind := RegEx.create_from_string("_m?\\d+_m?\\d+$").sub(key.trim_prefix("Mesh_"), "")
	if not WALLS.has(kind):
		return proposed
	for parameter: String in WALLS[kind]:
		var value: Variant = WALLS[kind][parameter]
		(proposed as ShaderMaterial).set_shader_parameter(parameter, Color(value) if value is String else value)
	return proposed

func set_enabled(value: bool) -> void:
	var k := 0
	for car: MeshInstance3D in _cars:
		for i: int in car.mesh.get_surface_count():
			if is_instance_valid(car):
				car.set_surface_override_material(i, _stock if value else _prior[k])
			k += 1
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = not value

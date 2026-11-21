extends RefCounted
## overflow, look c only. the one downhill landscape keeps its valley, terrain and trees, and
## comes into blend c where you run: shell-white decks, landings a clear step paler than the
## run decks that feed them, dark damp catch floors, weathered dam walls with pale copings,
## sage ground instead of flat green, so a takeoff, its gap and its landing read as three
## different things. the sluice house and the other buildings go warm weathered brick so the
## landmark reads against the woods, and the pool and race take the calm sea-glass water sluice
## six uses instead of the shared zigzag pattern. no node is added; only materials change.

const PALETTE := {"top": "e6e4da", "side": "5b7173"}
const SURFACES := {
	"run": {"top_color": "cfcec2", "side_color": "5e7473", "wear_amount": 0.08},
	"land": {"top_color": "dedcd0", "side_color": "5e7473", "wear_amount": 0.08},
	"catch": {"top_color": "56685f", "side_color": "43575a", "wear_amount": 0.3},
	"recovery": {"top_color": "a2ab9e", "side_color": "55696a"},
	"wall": {"top_color": "d9d3c3", "side_color": "62787a", "wear_amount": 0.1},
	"structure": {"top_color": "c7c3b4", "side_color": "71878a", "wear_amount": 0.1},
	"old": {"top_color": "7b897f", "side_color": "4e6264", "wear_amount": 0.12},
	"brick": {"top_color": "8f6a5a", "side_color": "8a5f4e", "wear_amount": 0.12},
	"terrain": {"top_color": "7f977b", "side_color": "6a7f6b", "wear_amount": 0.0},
	# the pines keep a dark forest green: their upward canopy faces would otherwise take a deck top.
	"trees": {"top_color": "4f6b55", "side_color": "425d4b", "wear_amount": 0.0, "top_from": 0.95, "top_full": 1.0},
}

const SEA := preload("res://scripts/art/sluice_six_materials.gd")
var _water: ShaderMaterial

func material(_key: String, node: GeometryInstance3D, proposed: Material) -> Material:
	var old := node.material_override as ShaderMaterial
	if old == null or old.shader == null or not old.shader.resource_path.ends_with("momentum_overflow_water.gdshader"):
		return proposed
	if _water == null:
		_water = SEA.water(PackedVector4Array(), Vector3(0.24, 0.40, 0.40), Vector3(0.40, 0.53, 0.51), 0.0, 0.07)
	return _water

extends "res://scripts/r16_experiment_player.gd"
## p / tether yard locks the inherited bounded rope to one map and removes the other lab moves.

const TETHER_VERSION := "r19-tether-yard-grapple-only-1"
const TETHER_LAW := {"law": "r19-tether-yard-rope-1", "rope": GRAPPLE,
	"base": "r15-lab-grapple-1 unchanged", "loadout": "grapple only, locked", "wall_jump": false, "slide": false}

func _init() -> void:
	enabled = {"slide": false, "wall_jump": false, "grapple": true}

func movement_version() -> String:
	return TETHER_VERSION

func mechanic_enabled(id: String) -> bool:
	return id == "grapple"

func set_mechanic(_id: String, _on: bool) -> void:
	# the course has one fixed law; old lab keys and menu calls cannot enable other moves.
	pass

func _wall_step(_v: Vector3, _grounded: bool) -> Vector3:
	return Vector3.ZERO

func _slide_step(_v: Vector3, _grounded: bool) -> void:
	_slide_duck = false
	slide_active = false
	slide_armed = false

func _ready() -> void:
	super()
	_tether_material = _flat(Color("29464a"))
	_ring_material = _flat(Color("b5683c"))
	_tether.material_override = _tether_material
	_target_ring.material_override = _ring_material

static func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.emission_enabled = false
	return material

func _process(delta: float) -> void:
	super(delta)
	# the inherited visual routine changes cyan/orange each frame; replace its colors here.
	if _ring_material != null:
		_ring_material.albedo_color = Color("b5683c") if not grapple.is_empty() else Color("356b68")
		_ring_material.emission_enabled = false
		_tether_material.emission_enabled = false

func get_motion_state() -> Dictionary:
	var out := super()
	out.experiment.version = TETHER_VERSION
	out.experiment["tether_law"] = TETHER_LAW
	out.experiment["locked"] = true
	return out

extends "res://scripts/r20_main.gd"
## component adapter only; final acceptance must run parent-owned r21_main and r21_hud.
const R21_RUNNER := preload("res://scripts/r21_tether_player.gd")

func _ready() -> void:
	map_registry = R20_MAPS.make().duplicate(true)
	map_registry.catalog["tether-yard"].runner = "res://scripts/r21_tether_player.gd"
	if not has_meta("original_geometry"):
		map_registry.catalog["tether-yard"].script = "res://scripts/r21_tether_level.gd"
	super()

func _setting_value(key: String, value: Variant) -> Variant:
	if key == "tether_model":
		return str(value) if str(value) in R21_RUNNER.R21_MODELS else "classic"
	return super(key, value)

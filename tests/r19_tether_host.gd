extends "res://scripts/r19_main.gd"
## component adapter: real r19 host/session, with only tether registration and integration hooks.
const TETHER := preload("res://scripts/r19_tether_level.gd")

func _ready() -> void:
	if map_registry.is_empty():
		map_registry = MAPS.make().duplicate(true)
	map_registry.catalog[TETHER.MAP_ID] = TETHER.MAP_ENTRY.duplicate(true)
	if not TETHER.MAP_ID in map_registry.order:
		map_registry.order.append(TETHER.MAP_ID)
	map_id = TETHER.MAP_ID
	super._ready()

func _source_script_path() -> String:
	return str(TETHER.MAP_ENTRY.runner) if map_id == TETHER.MAP_ID else super._source_script_path()

func is_lab() -> bool:
	return map_id == TETHER.MAP_ID or super.is_lab()

func lab_moves() -> Dictionary:
	return {} if map_id == TETHER.MAP_ID else super.lab_moves()

func _build_level() -> void:
	super._build_level()
	if map_id == TETHER.MAP_ID and level != null and look_layer == null:
		look_layer = PRESENTATION.new()
		level.add_child(look_layer)
		look_layer.attach(level, "practice")
		look_layer.set_enabled(look_enabled)

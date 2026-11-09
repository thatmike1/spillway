extends "res://scripts/r19_main.gd"
## component integration only; parent owns production registry and experiment UI.
const FALL := preload("res://scripts/r19_fall_line_level.gd")
func _ready() -> void:
	map_registry = MAPS.make().duplicate(true)
	map_registry.catalog[FALL.MAP_ID] = FALL.MAP_ENTRY.duplicate(true)
	map_registry.order.append(FALL.MAP_ID)
	map_id = FALL.MAP_ID
	super._ready()
func _source_script_path() -> String:
	return "res://scripts/r15_source_player.gd" if map_id == FALL.MAP_ID else super._source_script_path()
func is_lab() -> bool:
	return map_id == FALL.MAP_ID or super.is_lab()
func lab_moves() -> Dictionary:
	return {} if map_id == FALL.MAP_ID else super.lab_moves()
func _build_level() -> void:
	super._build_level()
	if map_id == FALL.MAP_ID and level != null and look_layer == null:
		look_layer = PRESENTATION.new()
		level.add_child(look_layer)
		look_layer.attach(level,"practice")
		look_layer.set_enabled(look_enabled)

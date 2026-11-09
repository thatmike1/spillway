extends "res://scripts/r19_main.gd"
## component-only registration until the parent adds this completed experiment to production.
const LINE_LEVEL := preload("res://scripts/r19_line_drive_level.gd")

func _ready() -> void:
	map_registry = MAPS.make().duplicate(true)
	map_registry.catalog[LINE_LEVEL.MAP_ID] = LINE_LEVEL.MAP_ENTRY.duplicate(true)
	map_registry.order.append(LINE_LEVEL.MAP_ID)
	map_id = LINE_LEVEL.MAP_ID
	super._ready()

func _source_script_path() -> String:
	return "res://scripts/r19_line_drive_player.gd" if map_id == LINE_LEVEL.MAP_ID else super()

func is_lab() -> bool:
	return map_id == LINE_LEVEL.MAP_ID or super()

func lab_moves() -> Dictionary:
	return {} if map_id == LINE_LEVEL.MAP_ID else super()

func _build_level() -> void:
	super._build_level()
	if map_id == LINE_LEVEL.MAP_ID and look_layer == null:
		look_layer = PRESENTATION.new()
		level.add_child(look_layer)
		look_layer.attach(level, "practice")
		look_layer.set_enabled(look_enabled)

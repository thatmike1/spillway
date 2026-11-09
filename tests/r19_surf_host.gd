extends "res://scripts/r19_main.gd"
## test registration and look hook only. gameplay/session/runner stay the actual r19 host.

const SURF_LEVEL := preload("res://scripts/r19_surf_level.gd")

func _ready() -> void:
	map_registry = MAPS.make().duplicate(true)
	map_registry.catalog[SURF_LEVEL.MAP_ID] = SURF_LEVEL.MAP_ENTRY.duplicate(true)
	map_registry.order.append(SURF_LEVEL.MAP_ID)
	map_id = SURF_LEVEL.MAP_ID
	super._ready()

func _build_level() -> void:
	super._build_level()
	if map_id == SURF_LEVEL.MAP_ID:
		look_layer = PRESENTATION.new()
		level.add_child(look_layer)
		look_layer.attach(level, "practice")
		look_layer.set_enabled(look_enabled)

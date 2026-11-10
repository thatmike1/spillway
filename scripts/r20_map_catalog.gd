extends RefCounted
## keep every delivered catalog entry; only saltglass receives new geometry here.
const BASE := preload("res://scripts/r19_map_catalog.gd")
const SURF := preload("res://scripts/r20_surf_level.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog[SURF.MAP_ID] = SURF.MAP_ENTRY.duplicate(true)
	return maps

extends RefCounted
## preserve the delivered catalog and replace only the revised saltglass course.
const BASE := preload("res://scripts/r20_map_catalog.gd")
const SURF := preload("res://scripts/r21_surf_level.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog[SURF.MAP_ID] = SURF.MAP_ENTRY.duplicate(true)
	return maps

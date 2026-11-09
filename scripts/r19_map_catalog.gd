extends RefCounted
## retain the delivered catalog verbatim and append only completed R19 components.
const BASE := preload("res://scripts/r15_maps.gd")
const SURF := preload("res://scripts/r19_surf_level.gd")
const TETHER := preload("res://scripts/r19_tether_level.gd")
const FALL := preload("res://scripts/r19_fall_line_level.gd")
const LINE := preload("res://scripts/r19_line_drive_level.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog[SURF.MAP_ID] = SURF.MAP_ENTRY.duplicate(true)
	maps.order.append(SURF.MAP_ID)
	maps.catalog[TETHER.MAP_ID] = TETHER.MAP_ENTRY.duplicate(true)
	maps.order.append(TETHER.MAP_ID)
	maps.catalog[FALL.MAP_ID] = FALL.MAP_ENTRY.duplicate(true)
	maps.order.append(FALL.MAP_ID)
	maps.catalog[LINE.MAP_ID] = LINE.MAP_ENTRY.duplicate(true)
	maps.order.append(LINE.MAP_ID)
	return maps

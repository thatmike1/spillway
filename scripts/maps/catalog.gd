extends RefCounted
## preserve the delivered catalog and replace the two revised experimental courses.
const BASE := preload("res://scripts/r20_map_catalog.gd")
const TETHER := preload("res://scripts/r21_tether_level.gd")
const MAIL := preload("res://scripts/maps/mail_run.gd")
const SURF := preload("res://scripts/r21_surf_level.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog[SURF.MAP_ID] = SURF.MAP_ENTRY.duplicate(true)
	maps.catalog[TETHER.MAP_ID] = TETHER.MAP_ENTRY.duplicate(true)
	maps.catalog[MAIL.MAP_ID] = MAIL.MAP_ENTRY.duplicate(true)
	maps.order.append(MAIL.MAP_ID)
	return maps

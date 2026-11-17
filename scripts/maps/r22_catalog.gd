extends RefCounted
## live additions are separate from the retained r21 catalog contract.
const BASE := preload("res://scripts/maps/catalog.gd")
const SEAWARD := preload("res://scripts/maps/saltglass_seaward.gd")
const VIADUCT := preload("res://scripts/maps/viaduct.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog[VIADUCT.MAP_ID] = VIADUCT.MAP_ENTRY.duplicate(true)
	maps.order.append(VIADUCT.MAP_ID)
	maps.catalog[SEAWARD.MAP_ID] = SEAWARD.MAP_ENTRY.duplicate(true)
	maps.order.append(SEAWARD.MAP_ID)
	return maps

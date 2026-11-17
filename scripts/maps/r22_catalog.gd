extends RefCounted
## live additions are separate from the retained r21 catalog contract.
const GANTRY := preload("res://scripts/maps/gantry.gd")
const BASE := preload("res://scripts/maps/catalog.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog[GANTRY.MAP_ID] = GANTRY.MAP_ENTRY.duplicate(true)
	maps.order.append(GANTRY.MAP_ID)
	return maps

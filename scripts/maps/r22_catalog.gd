extends RefCounted
## live additions are separate from the retained r21 catalog contract.
const SLUICE := preload("res://scripts/maps/sluice_six.gd")
const BASE := preload("res://scripts/maps/catalog.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog[SLUICE.MAP_ID] = SLUICE.MAP_ENTRY.duplicate(true)
	maps.order.append(SLUICE.MAP_ID)
	return maps

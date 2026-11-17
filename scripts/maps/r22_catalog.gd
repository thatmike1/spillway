extends RefCounted
## live additions are separate from the retained r21 catalog contract.
const BASE := preload("res://scripts/maps/catalog.gd")
const VIADUCT := preload("res://scripts/maps/viaduct.gd")
const FOUNDRY := preload("res://scripts/maps/foundry.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog[VIADUCT.MAP_ID] = VIADUCT.MAP_ENTRY.duplicate(true)
	maps.order.append(VIADUCT.MAP_ID)
	maps.catalog[FOUNDRY.FOUNDRY_ID] = FOUNDRY.FOUNDRY_ENTRY.duplicate(true)
	maps.order.append(FOUNDRY.FOUNDRY_ID)
	return maps

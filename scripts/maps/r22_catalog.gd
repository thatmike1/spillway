extends RefCounted
## live additions are separate from the retained r21 catalog contract.
const FOUNDRY := preload("res://scripts/maps/foundry.gd")
const BASE := preload("res://scripts/maps/catalog.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog[FOUNDRY.FOUNDRY_ID] = FOUNDRY.FOUNDRY_ENTRY.duplicate(true)
	maps.order.append(FOUNDRY.FOUNDRY_ID)
	return maps

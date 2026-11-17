extends RefCounted
## live additions are separate from the retained r21 catalog contract.
const MAIL := preload("res://scripts/maps/mail_run.gd")
const SLUICE := preload("res://scripts/maps/sluice_six.gd")
const BASE := preload("res://scripts/maps/catalog.gd")
const VIADUCT := preload("res://scripts/maps/viaduct.gd")
const GANTRY := preload("res://scripts/maps/gantry.gd")
const GANTRY_CHAIN := preload("res://scripts/maps/gantry_chain.gd")
const FOUNDRY := preload("res://scripts/maps/foundry.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog[VIADUCT.MAP_ID] = VIADUCT.MAP_ENTRY.duplicate(true)
	maps.order.append(VIADUCT.MAP_ID)
	maps.catalog[GANTRY.MAP_ID] = GANTRY.MAP_ENTRY.duplicate(true)
	maps.order.append(GANTRY.MAP_ID)
	maps.catalog[GANTRY_CHAIN.CHAIN_ID] = GANTRY_CHAIN.CHAIN_ENTRY.duplicate(true)
	maps.order.append(GANTRY_CHAIN.CHAIN_ID)
	maps.catalog[MAIL.MAP_ID] = MAIL.MAP_ENTRY.duplicate(true)
	maps.order.append(MAIL.MAP_ID)
	maps.catalog[SLUICE.MAP_ID] = SLUICE.MAP_ENTRY.duplicate(true)
	maps.order.append(SLUICE.MAP_ID)
	maps.catalog[FOUNDRY.FOUNDRY_ID] = FOUNDRY.FOUNDRY_ENTRY.duplicate(true)
	maps.order.append(FOUNDRY.FOUNDRY_ID)
	return maps

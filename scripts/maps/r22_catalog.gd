extends RefCounted
## live additions are separate from the retained r21 catalog contract.
const MAIL := preload("res://scripts/maps/mail_run.gd")
const BASE := preload("res://scripts/maps/catalog.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog[MAIL.MAP_ID] = MAIL.MAP_ENTRY.duplicate(true)
	maps.order.append(MAIL.MAP_ID)
	return maps

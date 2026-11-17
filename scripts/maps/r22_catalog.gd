extends RefCounted
## live additions are separate from the retained r21 catalog contract.
const BASE := preload("res://scripts/maps/catalog.gd")

static func make() -> Dictionary:
	var maps := BASE.make().duplicate(true)
	maps.catalog["plan-yard"] = preload("res://scripts/maps/plan_yard.gd").MAP_ENTRY.duplicate(true)
	maps.order.append("plan-yard")
	return maps

extends RefCounted
## live additions are separate from the retained r21 catalog contract.
const BASE := preload("res://scripts/maps/catalog.gd")

static func make() -> Dictionary:
	return BASE.make().duplicate(true)

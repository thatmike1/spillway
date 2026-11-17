extends SceneTree
## catalog capabilities must enable a second grapple map without changing tether identity.
const HOST := preload("res://scripts/game.gd")
const MAPS := preload("res://scripts/r21_map_catalog.gd")

func _initialize() -> void:
	var host := HOST.new()
	host.maps = MAPS.make()
	host.map_id = "tether-yard"
	assert(host.map_has_capability("grapple"))
	var original: Dictionary = host.map_entry().duplicate(true)
	host.maps.catalog["capability-fixture"] = original.duplicate(true)
	host.maps.catalog["capability-fixture"].erase("revision_notice")
	host.map_id = "capability-fixture"
	assert(host.map_has_capability("grapple"))
	assert(not host.map_has_capability("unknown"))
	assert(not "Earlier Tether Yard" in host.map_revision_description())
	host.map_id = "breakwater"
	assert(not host.map_has_capability("grapple"))
	host.free()
	print("PASS: grapple capability follows catalog entries")
	quit()

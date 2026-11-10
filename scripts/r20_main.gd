extends "res://scripts/r19_main.gd"
## r20 composes new components around the unchanged source motor and prior maps.
const R20_MAPS := preload("res://scripts/r20_map_catalog.gd")

func _ready() -> void:
	if map_registry.is_empty():
		map_registry = R20_MAPS.make()
	super._ready()
	if startup_error.is_empty() and map_id == "saltglass":
		hud.call("notify", map_revision_description())

func interface_startup_message() -> String:
	return "r20: %s; Saltglass high fins and rising crescent; inherited F2 motor; R18 interface; L compares presentation; F9 telemetry" % SHARE.BUILD

func window_title() -> String:
	return super.window_title().replace("Spillway R19", "Spillway R20")

func recording_metadata(reason: String) -> Dictionary:
	var metadata := super(reason)
	metadata.build_label = "Spillway R20"
	return metadata

func map_revision_description() -> String:
	if map_id == "saltglass":
		return "Older Saltglass ghosts use the low fins and return ramps and cannot race this map revision."
	return super()

func select_map(id: String) -> void:
	var prior := map_id
	super.select_map(id)
	if map_id != prior and map_id == "saltglass":
		hud.call("notify", map_revision_description())

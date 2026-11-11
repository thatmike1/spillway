extends "res://scripts/r20_main.gd"
## r21 composes revised experimental courses around the frozen r20 host.
const R21_MAPS := preload("res://scripts/r21_map_catalog.gd")

func _ready() -> void:
	if map_registry.is_empty():
		map_registry = R21_MAPS.make()
	super._ready()

func interface_startup_message() -> String:
	return "r21: %s; Saltglass surf exits and outside lines; inherited F2 motor; R18 interface; L compares presentation; F9 telemetry" % SHARE.BUILD

func window_title() -> String:
	return super.window_title().replace("Spillway R20", "Spillway R21")

func recording_metadata(reason: String) -> Dictionary:
	var metadata := super(reason)
	metadata.build_label = "Spillway R21"
	return metadata

func map_revision_description() -> String:
	if map_id == "saltglass":
		return "Earlier Saltglass ghosts use different exits and cannot race this map revision."
	return super()

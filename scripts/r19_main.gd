extends "res://scripts/r17_main.gd"
## r19 composes map revisions and new features beside the inherited source motor.

const COURSE_REVISIONS := preload("res://scripts/r19_course_revisions.gd")
var map_revision: Dictionary = {}

func _ready() -> void:
	super._ready()
	if startup_error.is_empty():
		print("r19: explicit course revisions; R19 style; inherited F2 motor")
		if not map_revision.is_empty():
			hud.call("notify", map_revision_description())

## this inherited hook runs after optional solids exist and before look contours are built.
func _geometry_id() -> String:
	var base := super._geometry_id()
	map_revision = COURSE_REVISIONS.apply(level)
	if map_revision.is_empty():
		return base
	opportunities = map_revision.duplicate(true)
	overlay_id = "%s:%s" % [opportunities.version, opportunities.hash]
	return JSON.stringify([base, map_revision.version, map_revision.hash]).sha256_text()

func window_title() -> String:
	return super.window_title().replace("Spillway R18", "Spillway R19")

func select_map(id: String) -> void:
	var prior := map_id
	super.select_map(id)
	if map_id != prior and not map_revision.is_empty():
		hud.call("notify", map_revision_description())

func map_revision_description() -> String:
	return "Older Breakwater ghosts use the narrower gate and cannot race this revision." if not map_revision.is_empty() else ""

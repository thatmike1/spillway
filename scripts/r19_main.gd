extends "res://scripts/r17_main.gd"
## r19 composes map revisions and new features beside the inherited source motor.

const COURSE_REVISIONS := preload("res://scripts/r19_course_revisions.gd")
const SHARE := preload("res://scripts/r19_ghost_share.gd")
const R19_HUD := preload("res://scripts/r19_hud.gd")
var map_revision: Dictionary = {}
var ghost_share: Node
## isolated test seams; never supplied by a shared ghost file.
var ghosts_directory := ""
var ghost_share_storage := ""
var ghost_folder_opener: Callable

func _ready() -> void:
	ghost_share = SHARE.new()
	ghost_share.name = "GhostShare"
	ghost_share.folder_opener = ghost_folder_opener
	ghost_share.setup(self, ghosts_directory, ghost_share_storage)
	add_child(ghost_share)
	super._ready()
	if startup_error.is_empty():
		ghost_share.scan()
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

func _new_hud() -> CanvasLayer:
	return R19_HUD.new()

func recording_metadata(reason: String) -> Dictionary:
	var metadata := super(reason)
	metadata.build = SHARE.BUILD
	metadata.build_label = "Spillway R19"
	return metadata

func _refresh_records() -> void:
	super()
	if ghost_share != null and session != null:
		ghost_share.identity_changed()

func set_paused(value: bool) -> void:
	if value and not paused and ghost_share != null:
		ghost_share.scan()
	super(value)

func ghost_shown() -> bool:
	return super() and (ghost_share == null or str(ghost_share.active).is_empty())

func toggle_ghost() -> void:
	super()
	if ghost_share != null and not str(ghost_share.active).is_empty():
		hud.call("notify", "Ghost %s  ·  %s" % ["on" if bool(settings.ghost) else "off", hud.call("ghost_menu_state")])

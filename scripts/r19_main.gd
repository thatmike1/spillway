extends "res://scripts/r17_main.gd"
## r19 composes map revisions and new features beside the inherited source motor.

const COURSE_REVISIONS := preload("res://scripts/r19_course_revisions.gd")
const SHARE := preload("res://scripts/r19_ghost_share.gd")
const R19_HUD := preload("res://scripts/r19_hud.gd")
const SURF_LEVEL := preload("res://scripts/r19_surf_level.gd")
const R19_MAPS := preload("res://scripts/r19_map_catalog.gd")
var map_revision: Dictionary = {}
var ghost_share: Node
## isolated test seams; never supplied by a shared ghost file.
var ghosts_directory := ""
var ghost_share_storage := ""
var ghost_folder_opener: Callable

func _ready() -> void:
	if map_registry.is_empty():
		map_registry = R19_MAPS.make()
	ghost_share = SHARE.new()
	ghost_share.name = "GhostShare"
	ghost_share.folder_opener = ghost_folder_opener
	ghost_share.setup(self, ghosts_directory, ghost_share_storage)
	add_child(ghost_share)
	super._ready()
	if startup_error.is_empty():
		ghost_share.scan()
		if not map_revision.is_empty():
			hud.call("notify", map_revision_description())

func _build_level() -> void:
	super._build_level()
	if (map_id == SURF_LEVEL.MAP_ID or is_experiment_map()) and level != null:
		look_layer = PRESENTATION.new()
		level.add_child(look_layer)
		look_layer.attach(level, "practice")
		look_layer.set_enabled(look_enabled)

func is_experiment_map() -> bool:
	return map_kind() == "experiment"

func is_lab() -> bool:
	return super() or is_experiment_map()

func lab_moves() -> Dictionary:
	return {} if is_experiment_map() else super()

func _source_script_path() -> String:
	if is_experiment_map() and source_runner is String and str(source_runner).is_empty():
		return str(map_entry().get("runner", PRESETS.SOURCE_PLAYER))
	return super()

func _lab_restrict() -> String:
	var note := super()
	return note.replace("The Movement Lab", "Experiments") if is_experiment_map() else note

func law_labels() -> Dictionary:
	var labels := super()
	if is_experiment_map():
		labels["course_law"] = "experimental"
		labels["experimental"] = ["%s: %s" % [map_name(), family_version()], str(map_entry().get("instructions", ""))]
	return labels

func interface_startup_message() -> String:
	return "r19: %s; R19 style, ghost sharing and course revisions; inherited F2 motor; R18 interface; L compares presentation; F9 telemetry" % SHARE.BUILD

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

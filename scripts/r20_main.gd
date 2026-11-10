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
	if id != map_id and id in map_ids():
		_discard_direction("map")
	super.select_map(id)
	if map_id != prior and map_id == "saltglass":
		hud.call("notify", map_revision_description())

## record unbanked stack losses while the old attempt is still open; no score is awarded.
func _discard_direction(reason: String) -> void:
	if session == null or session.style == null or not session.style.has_method("discard_pending"):
		return
	var diagnostics: Variant = session.style.call("discard_pending", reason)
	if diagnostics is Array and session.recorder != null and session.recorder.is_open():
		for diagnostic: Dictionary in diagnostics:
			session.recorder.event("direction", diagnostic)

func restart_run(reason: String = "restart") -> void:
	_discard_direction(reason)
	super.restart_run(reason)

func practise_stage(stage: int) -> void:
	_discard_direction("practice")
	super.practise_stage(stage)

## a deferred or rejected preset request is not a boundary; only an applied switch is.
func _switch_to(next: Dictionary, same_body: bool) -> void:
	_discard_direction("preset")
	super._switch_to(next, same_body)

func set_mechanic(id: String, on: bool) -> void:
	if is_lab() and lab_moves().has(id) and bool(lab_moves()[id]) != on:
		_discard_direction("loadout")
	super.set_mechanic(id, on)

func set_paused(value: bool) -> void:
	if value != paused and session != null and session.style != null:
		session.style.discontinuity("pause" if value else "resume")
	super.set_paused(value)

func request_quit(exit_code: int = 0) -> void:
	if not _quitting:
		_discard_direction("quit")
	super.request_quit(exit_code)

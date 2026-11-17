extends "res://scripts/r19_main.gd"
## r20 composes new components around the unchanged source motor and prior maps.
const R20_HUD := preload("res://scripts/r20_hud.gd")
const R20_TETHER := preload("res://scripts/r20_tether_player.gd")
const R20_MAPS := preload("res://scripts/r20_map_catalog.gd")

const RUN_EXPORT := preload("res://scripts/r20_run_export.gd")
var run_export := RUN_EXPORT.new()
var run_export_directory := "user://run_exports"
var run_export_folder_opener: Callable
var last_run_export: Dictionary = {}

func _input(event: InputEvent) -> void:
	if paused and event is InputEventKey and is_instance_valid(hud):
		var field := get_viewport().gui_get_focus_owner()
		if field != null and field in [hud.get("export_name"), hud.get("export_path")]:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if code != KEY_ESCAPE and (code < KEY_F1 or code > KEY_F12):
				return
	super._input(event)

func export_my_runs(label: String) -> Dictionary:
	if not paused:
		return {"ok": false, "error": "Pause before exporting runs."}
	var flushed := run_export.flush_open_attempt(session.recorder)
	if not flushed.ok:
		last_run_export = flushed
	else:
		run_export.folder_opener = run_export_folder_opener
		last_run_export = run_export.collect(session.directory if not str(session.directory).is_empty() else recordings_dir, OS.get_user_data_dir(), profile_path, settings,
			run_export_directory, label, str(ProjectSettings.get_setting("application/config/version")))
	return last_run_export

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
	if map_has_capability("grapple"):
		return {"tether-yard": "R19 E ghosts and different rope models/reel preferences cannot race this Tether identity."}.get(map_id, "Rope models and reel preferences have separate recording identities.")
	return super()

func select_map(id: String) -> void:
	var prior := map_id
	if id != map_id and id in map_ids():
		_block_tether("map")
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
	_block_tether(reason)
	_discard_direction(reason)
	super.restart_run(reason)

func practise_stage(stage: int) -> void:
	_block_tether("practice")
	_discard_direction("practice")
	super.practise_stage(stage)

## a deferred or rejected preset request is not a boundary; only an applied switch is.
func _switch_to(next: Dictionary, same_body: bool) -> void:
	_block_tether("preset")
	_discard_direction("preset")
	super._switch_to(next, same_body)

func set_mechanic(id: String, on: bool) -> void:
	if is_lab() and lab_moves().has(id) and bool(lab_moves()[id]) != on:
		_discard_direction("loadout")
	super.set_mechanic(id, on)

func set_paused(value: bool) -> void:
	if value != paused:
		_block_tether("pause" if value else "resume")
	if value != paused and session != null and session.style != null:
		session.style.discontinuity("pause" if value else "resume")
	super.set_paused(value)

func request_quit(exit_code: int = 0) -> void:
	if not _quitting:
		_block_tether("quit")
		_discard_direction("quit")
	super.request_quit(exit_code)


func _new_hud() -> CanvasLayer:
	return R20_HUD.new()

func _load_settings() -> void:
	settings["tether_model"] = "classic"
	settings["tether_auto_reel"] = false
	super()

func _setting_value(key: String, value: Variant) -> Variant:
	if key == "tether_model":
		return str(value) if str(value) in R20_TETHER.MODELS else "classic"
	if key == "tether_auto_reel":
		return bool(value)
	return super(key, value)

func _make_runner(entry: Dictionary) -> CharacterBody3D:
	var runner := super(entry)
	if runner.has_method("configure_tether"):
		runner.call("configure_tether", str(settings.get("tether_model", "classic")), bool(settings.get("tether_auto_reel", false)))
		runner.connect("tether_diagnostic", _tether_diagnostic)
	if runner.has_signal("through_diagnostic"):
		runner.connect("through_diagnostic", _through_diagnostic)
	return runner

func _tether_diagnostic(data: Dictionary) -> void:
	# the frozen recorder accepts arbitrary event payloads; this stream has no score meaning.
	if session != null and session.recorder != null and session.recorder.is_open():
		session.recorder.event("tether", data)

func _through_diagnostic(data: Dictionary) -> void:
	if str(data.get("kind", "")) == "launch" and is_instance_valid(hud):
		hud.call("notify", "RISE · horizontal speed carried · land on Second Run")
	if session != null and session.recorder != null and session.recorder.is_open():
		session.recorder.event("through", data)

func _block_tether(reason: String) -> void:
	if is_instance_valid(player) and player.has_method("clear_through"):
		player.call("clear_through", reason)
	if is_instance_valid(player) and player.has_method("block_tether"):
		player.call("block_tether", reason)

func respawn() -> void:
	_block_tether("respawn")
	super()

func mechanics() -> Array:
	var out := super()
	if map_has_capability("grapple") and is_instance_valid(player) and player.has_method("tether_identity"):
		out.append(player.call("tether_identity"))
	return out

func _apply_settings() -> void:
	super()
	if is_instance_valid(player) and player.has_method("configure_tether"):
		var cue: AudioStreamPlayer = player.get("cue_player")
		if cue != null:
			cue.volume_db = linear_to_db(float(settings.volume)) if float(settings.volume) > 0.0 else -80.0

	if is_instance_valid(player) and player.has_signal("through_diagnostic"):
		var cue: AudioStreamPlayer = player.get("cue_player")
		if cue != null:
			cue.volume_db = linear_to_db(float(settings.volume)) if float(settings.volume) > 0.0 else -80.0

func change_setting(key: String, value: Variant) -> void:
	if key not in ["tether_model", "tether_auto_reel"]:
		super(key, value)
		return
	if not map_has_capability("grapple"):
		return
	var next: Variant = _setting_value(key, value)
	if settings.get(key) == next:
		return
	var was_paused := paused
	_block_tether("model" if key == "tether_model" else "automatic_reel")
	_discard_direction("tether_settings")
	session.boundary("loadout", {"key": key, "from": settings.get(key), "to": next})
	settings[key] = next
	player.call("configure_tether", str(settings.tether_model), bool(settings.tether_auto_reel))
	_refresh_records()
	restart_run("tether_settings")
	set_paused(was_paused)
	_save()
	hud.call("_refresh_tether")
	hud.call("notify", "Tether rope changed · attempt restarted · release mouse buttons, then press LMB")

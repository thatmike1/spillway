extends "res://scripts/r20_main.gd"
## r21 composes revised experimental courses around the frozen r20 host.
const R21_MAPS := preload("res://scripts/r21_map_catalog.gd")

func _ready() -> void:
	if map_registry.is_empty():
		map_registry = R21_MAPS.make()
	super._ready()
	if startup_error.is_empty() and map_has_capability("grapple"):
		hud.call("notify", map_revision_description())

func interface_startup_message() -> String:
	return "r21: %s; Saltglass surf exits and outside lines; inherited F2 motor; R18 interface; Elastic tuning and anchor preview; L compares presentation; F9 telemetry" % SHARE.BUILD

func window_title() -> String:
	return super.window_title().replace("Spillway R20", "Spillway R21")

func recording_metadata(reason: String) -> Dictionary:
	var metadata := super(reason)
	metadata.build_label = "Spillway R21"
	return metadata

func map_revision_description() -> String:
	if map_id == "saltglass":
		return "Earlier Saltglass ghosts use different exits and cannot race this map revision."
	if map_has_capability("grapple"):
		return {"tether-yard": "Earlier Tether Yard ghosts use taller transfer decks or different rope settings and cannot race this revision."}.get(map_id, "Rope models, reel and assist settings have separate recording identities.")
	return super()

const R21_HUD := preload("res://scripts/r21_hud.gd")
const R21_MODELS := ["classic", "pendulum", "elastic", "elastic-soft", "elastic-firm", "elastic-arc"]

func _new_hud() -> CanvasLayer:
	return R21_HUD.new()

func _load_settings() -> void:
	settings["tether_anchor_assist"] = true
	super()

func _setting_value(key: String, value: Variant) -> Variant:
	if key == "tether_anchor_assist":
		return bool(value)
	if key == "tether_model":
		return str(value) if str(value) in R21_MODELS else "classic"
	return super(key, value)

func _make_runner(entry: Dictionary) -> CharacterBody3D:
	var runner := super(entry)
	if runner.has_method("configure_anchor_assist"):
		runner.call("configure_anchor_assist", bool(settings.get("tether_anchor_assist", true)))
	return runner

func change_setting(key: String, value: Variant) -> void:
	if key != "tether_anchor_assist":
		super(key, value)
		return
	if not map_has_capability("grapple") or str(settings.get("tether_model", "classic")) in ["classic", "pendulum"]:
		return
	var next := bool(_setting_value(key, value))
	if bool(settings.get(key, true)) == next:
		return
	var was_paused := paused
	_block_tether("anchor_assist")
	_discard_direction("tether_settings")
	session.boundary("loadout", {"key": key, "from": settings.get(key, true), "to": next})
	settings[key] = next
	player.call("configure_anchor_assist", next)
	_refresh_records()
	restart_run("tether_settings")
	set_paused(was_paused)
	_save()
	hud.call("_refresh_tether")
	hud.call("notify", "Anchor assist changed · attempt restarted · release mouse buttons, then press LMB")

func select_map(id: String) -> void:
	var prior := map_id
	super(id)
	if map_id != prior and map_has_capability("grapple"):
		hud.call("notify", map_revision_description())

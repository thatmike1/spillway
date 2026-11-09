extends "res://scripts/r16_main.gd"
## r17 adds presentation after the delivered r16 world is complete. all game hooks stay inherited.
const PRESENTATION := preload("res://scripts/r17_look.gd")
const PALETTES := preload("res://scripts/r17_palettes.gd")
## r18: the player-facing interface. it replaces the inherited hud object after the r16 host has
## built its world; the hud is presentation only, so every game call reaches the same methods.
const UI_HUD := preload("res://scripts/r18_hud.gd")
var look_enabled := true
var look_layer: Node3D
var look_label: Label

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--look=old":
			look_enabled = false
	# required presentation assets must fail before the inherited host starts, including release builds.
	for id: String in PALETTES.MAPS:
		var path := str(PALETTES.MAPS[id].sky)
		if not ResourceLoader.exists(path) or not load(path) is Texture2D:
			startup_error = "r17: painted sky is missing or invalid: " + path
			push_error(startup_error)
			get_tree().quit(3)
			return
	super._ready()
	if not startup_error.is_empty():
		return
	_install_hud()
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	look_label = Label.new()
	look_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(look_label)
	_refresh_look_label()
	print(interface_startup_message())

func interface_startup_message() -> String:
	return "r18: spillway-2026.11.09-r18; delivered R16 behavior; R17 look, R18 interface; L compares presentation; F9 telemetry"

func _build_level() -> void:
	super._build_level()
	look_layer = null
	if map_id in MAPS.ORDER:
		look_layer = PRESENTATION.new()
		level.add_child(look_layer)
		look_layer.attach(level, map_id)
		look_layer.set_enabled(look_enabled)
	_refresh_look_label()

## player-facing descriptions live here so the frozen map registry and physical ids stay exact.
func map_entry(id: String = "") -> Dictionary:
	var entry := super(id).duplicate(true)
	var key := map_id if id.is_empty() else id
	if key == "practice":
		entry["theme"] = "Open yard for speed, strafes and gap practice"
	elif key == "overflow":
		entry["theme"] = "Dam-top run through spillways and service decks"
	return entry

func set_look(value: bool) -> void:
	look_enabled = value
	if is_instance_valid(look_layer):
		look_layer.set_enabled(value)
	_refresh_look_label()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_L:
		if event.pressed and not event.echo:
			set_look(not look_enabled)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.physical_keycode == KEY_F9:
		if event.pressed and not event.echo and is_instance_valid(hud) and hud.has_method("set_telemetry"):
			hud.call("set_telemetry", not bool(hud.get("telemetry")))
			_place_look_label()
		get_viewport().set_input_as_handled()
		return
	super._input(event)

## swap the inherited hud for the r18 one, carrying over what it was already showing.
func _install_hud() -> void:
	var old := hud
	var fresh: CanvasLayer = _new_hud()
	hud = fresh
	add_child(fresh)
	fresh.call("attach", self)
	fresh.call("map_changed")
	var note := ""
	if is_instance_valid(old):
		var message := old.get("message") as Label
		if message != null and message.modulate.a > 0.0:
			note = message.text
		fresh.visible = old.visible
		remove_child(old)
		old.free()
	if not note.is_empty():
		fresh.call("notify", note)

func _new_hud() -> CanvasLayer:
	return UI_HUD.new()

func _refresh_look_label() -> void:
	if is_instance_valid(look_label):
		look_label.text = "%s  ·  L" % ("Look C" if look_enabled else "original R16 look")
		_place_look_label()

func _place_look_label() -> void:
	if not is_instance_valid(look_label):
		return
	if is_instance_valid(hud) and hud.has_method("place_look_label"):
		hud.call("place_look_label", look_label)
		return
	var top := 18.0
	if is_instance_valid(hud) and hud.visible:
		var occupied := false
		for field: String in ["lab_tag", "lab_panel", "practice_tag"]:
			var control := hud.get(field) as Control
			if control != null and control.is_visible_in_tree():
				top = maxf(top, control.get_global_rect().end.y + 10.0)
				occupied = true
		# the inherited instructions can extend below the lab panel or practice banner.
		if occupied and hud.controls.is_visible_in_tree():
			top = maxf(top, hud.controls.get_global_rect().end.y + 10.0)
	look_label.position.y = top

func _process(_delta: float) -> void:
	# place after the inherited hud has laid out its current lab and practice messages.
	if is_instance_valid(look_label):
		_place_look_label.call_deferred()

func window_title() -> String:
	return super.window_title().replace("Spillway R16", "Spillway R18")

extends "res://scripts/r16_main.gd"
## r17 adds presentation after the delivered r16 world is complete. all game hooks stay inherited.
const PRESENTATION := preload("res://scripts/r17_look.gd")
const PALETTES := preload("res://scripts/r17_palettes.gd")
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
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	look_label = Label.new()
	look_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	look_label.offset_left = -410
	look_label.offset_right = -18
	look_label.offset_top = 18
	look_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	look_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	look_label.add_theme_font_size_override("font_size", 16)
	look_label.add_theme_color_override("font_color", Color("fff1d6"))
	look_label.add_theme_color_override("font_shadow_color", Color("162b32"))
	look_label.add_theme_constant_override("shadow_offset_x", 1)
	look_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(look_label)
	_refresh_look_label()
	print("r17: spillway-2026.11.09-r17; delivered R16 behavior; L compares presentation")

func _build_level() -> void:
	super._build_level()
	look_layer = null
	if map_id in MAPS.ORDER:
		look_layer = PRESENTATION.new()
		level.add_child(look_layer)
		look_layer.attach(level, map_id)
		look_layer.set_enabled(look_enabled)
	_refresh_look_label()

func set_look(value: bool) -> void:
	look_enabled = value
	if is_instance_valid(look_layer):
		look_layer.set_enabled(value)
	_refresh_look_label()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_L:
		if event.pressed and not event.echo:
			set_look(not look_enabled)
		return
	super._input(event)

func _refresh_look_label() -> void:
	if is_instance_valid(look_label):
		look_label.text = "R17 · %s · L compare" % ("paint + ink" if look_enabled else "original R16 look")
		_place_look_label()

func _place_look_label() -> void:
	if not is_instance_valid(look_label):
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
	if is_instance_valid(look_label) and look_label.is_visible_in_tree():
		_place_look_label.call_deferred()

func window_title() -> String:
	return super.window_title().replace("Spillway R16", "Spillway R17")

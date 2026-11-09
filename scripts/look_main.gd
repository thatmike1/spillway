extends "res://scripts/r15_main.gd"
## p / isolated look-c host. all motor, collision, progress and input behavior is inherited.
const LOOK := preload("res://scripts/look_breakwater.gd")
var look_enabled := true
var look_layer: Node3D
var look_label: Label

func _ready() -> void:
	persist = false
	seed_from_r14 = false
	map_id = "breakwater"
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--look=old":
			look_enabled = false
	super._ready()
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	look_label = Label.new()
	look_label.position = Vector2(18, 72)
	look_label.add_theme_font_size_override("font_size", 16)
	look_label.add_theme_color_override("font_color", Color("fff1d6"))
	look_label.add_theme_color_override("font_shadow_color", Color("162b32"))
	look_label.add_theme_constant_override("shadow_offset_x", 1)
	look_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(look_label)
	_refresh_look_label()
	print("look-c: spillway-look-c-1; base=1fe1d7a8c; R15 course runner; records off")

func _build_level() -> void:
	super._build_level()
	look_layer = null
	if map_id == "breakwater":
		look_layer = LOOK.new()
		level.add_child(look_layer)
		look_layer.call("attach", level)
		look_layer.call("set_enabled", look_enabled)
	_refresh_look_label()

func set_look(value: bool) -> void:
	look_enabled = value
	if is_instance_valid(look_layer):
		look_layer.call("set_enabled", value)
	_refresh_look_label()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L:
		set_look(not look_enabled)
		return
	super._input(event)

func _refresh_look_label() -> void:
	if look_label != null:
		look_label.text = "LOOK C EXPERIMENT  ·  %s  ·  L compare  ·  records off" % ("paint + ink" if look_enabled else "original") if map_id == "breakwater" else "LOOK C EXPERIMENT  ·  original map  ·  Breakwater only  ·  records off"

func window_title() -> String:
	return "Spillway · Look C experiment · %s · L compare" % map_name()

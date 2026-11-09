extends "res://scripts/r15_main.gd"
## labelled r15-host wrapper, not actual r16 acceptance. no timing or movement override.

const OPPORTUNITIES := preload("res://scripts/r16_style_opportunities.gd")

func _ready() -> void:
	seed_from_r14 = false
	super._ready()
	if "--overlay=off" not in OS.get_cmdline_user_args():
		OPPORTUNITIES.apply(level)

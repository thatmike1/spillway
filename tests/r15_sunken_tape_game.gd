extends "res://scripts/r15_main.gd"
## p / setup only, for the standard tape executor (tools/momentum-tape.py --game-script): the
## actual r15 main on the named map sunken-court. nothing in the main, hud, presets or runner
## changes; records stay off through the tape wrapper's isolated profile.

func _init():
	map_id = "sunken-court"

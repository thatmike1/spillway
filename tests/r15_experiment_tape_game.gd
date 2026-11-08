extends "res://scripts/r15_main.gd"
## p / setup only, for replaying movement lab tapes through tools/momentum-tape.py: the actual r15
## main started on the lab map, so it picks the lab runner itself. nothing else changes; records
## stay off through the tape wrapper's isolated profile.

func _init():
	map_id = "experiment"

extends "res://tests/saltglass_seaward.gd"
## adapt the owner collision audit to the shared component output directory.

func _initialize() -> void:
	super._initialize()
	output = output.path_join("seaward.json")

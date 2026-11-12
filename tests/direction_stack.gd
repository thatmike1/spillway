extends "res://verification/frozen/r20_style_stack.gd"
## compare the current stack against the preserved independent r19 style implementation.
func _initialize() -> void:
	baseline_path = "res://verification/frozen/r20_candidate_r19_style.gd"
	super._initialize()

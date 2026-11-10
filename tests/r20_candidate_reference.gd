extends "res://tests/r20_candidate_r19_style.gd"
## observational reference only; the committed verification-only parent is byte-exact R19 style from the baseline commit.
## production session.style is never replaced. retain unrounded base arithmetic and ordinary combo.
func _award(kind: String, sample: Dictionary, base: float, label: String, measures: Dictionary, geo: Dictionary, out: Array[Dictionary]) -> void:
	if kind in ["backward_bhop", "sideways_bhop"]:
		return
	var prior := _direction_mult
	_direction_mult = 1.0
	super._award(kind, sample, base, label, measures, geo, out)
	_direction_mult = prior

extends "res://tests/r16_style_fixture_level.gd"
## labelled review geometry, configured before the real host computes its identity.

static var review_spec: Dictionary = {}

func build() -> void:
	configure(review_spec if not review_spec.is_empty() else flat_spec())

func geometry_hash() -> String:
	return var_to_str([super.geometry_hash(), review_spec.get("finish")]).sha256_text()

extends SceneTree
## p / attach the owned visibility component test without the pack probe's startup autoload.
func _initialize() -> void:
	root.add_child.call_deferred(load("res://tests/r16_delivery_visibility.gd").new())

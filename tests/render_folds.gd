extends SceneTree
## fixed-observer fold readability fixture; route proof is test_traversal.gd.
var main: Node3D
var phase: int = -1
var time: float = 0
var label: Label

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.city_mode = true
	root.add_child(main)
	await physics_frame
	var layer := CanvasLayer.new()
	layer.layer = 30
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 22)
	layer.add_child(label)

func _physics_process(dt: float) -> bool:
	if label == null:
		return false
	time += dt
	var next: int = 0 if time < 7.5 else 1
	if time > 18:
		quit()
		return false
	if next != phase:
		phase = next
		var player = main.player
		if phase == 0:
			player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, .9, -18)))
			player.look(0, .25)
			main.level.folds[0].start_fold()
			label.text = "fold fixture: connected wings, windows and facade share one hinge"
		else:
			player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 25.9, -207)))
			player.look(.9, .05)
			main.level.folds[2].start_fold()
			label.text = "fold fixture: road, sidewalks, vans and buildings turn as one district"
	return false

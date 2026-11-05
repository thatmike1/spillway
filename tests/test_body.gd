extends "res://tests/test_spec_ground.gd"

func _run() -> void:
	MAIN.bind_inputs()
	await fresh()
	var arms = load("res://scripts/arms.gd").new()
	fixture.add_child(arms)
	arms.attach(player)
	check(not arms._viewport.own_world_3d, "body shares scene light and shadow world")
	player.move = player.Move.GRAB
	player._climb_hand = player.position + Vector3(0, .9, -.35)
	player.look(0, .30)
	player._update_rig(.016, true)
	for i: int in 180:
		arms._process(1.0 / 120)
	for arm: Dictionary in arms._arms:
		check(absf(arm.shoulder.distance_to(arm.elbow) - arms.UPPER_LENGTH) < .0001, "upper arm length is fixed")
		check(absf(arm.elbow.distance_to(arm.end) - arms.FORE_LENGTH) < .0001, "forearm length is fixed")
		var target: Vector3 = player.get_hand_target(arm.side)
		check(arm.hand.global_position.distance_to(target) < .005, "reachable hand is planted on its world target")
		check(arm.hand.global_basis.y.dot(player.up_direction) > .99, "palm rests flat on ledge")
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5, 5, .2)
	collider.shape = shape
	wall.position = Vector3(0, 2, -.65)
	wall.add_child(collider)
	fixture.add_child(wall)
	player.set_physics_process(false)
	await ticks(2)
	player.move = player.Move.WALLCLIMB
	player._wall_normal = Vector3.BACK
	var left: Vector3 = player.get_hand_target(-1)
	var right: Vector3 = player.get_hand_target(1)
	check(left.is_finite() and right.is_finite() and left.distance_to(right) > .35, "vertical climb has two separate real wall targets")
	for i: int in 180:
		arms._process(1.0 / 120)
	for arm: Dictionary in arms._arms:
		check(arm.hand.global_basis.y.dot(Vector3.BACK) > .99, "palm is flat against real wall normal")
	print("body: %d/%d checks passed" % [checks - failures, checks])
	fixture.queue_free()
	quit(1 if failures else 0)

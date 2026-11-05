extends SceneTree
## the assembled game: starts unpaused with look live on the first frame, the
## timer waits for the first step, the fold lands where the road should be,
## falls respawn at the last checkpoint with the city as it was, restart and
## pause behave, and the route cues advance.

var failures: int = 0
var checks: int = 0
var main: Node3D
var player: CharacterBody3D
var level: Node3D


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func ticks(count: int) -> void:
	for index: int in count:
		await physics_frame


func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	main.city_mode = true
	root.add_child(main)
	await physics_frame
	player = main.get("player")
	level = main.get("level")
	for index: int in 2:
		var entry: Dictionary = level.fold_triggers[index]
		var shape: BoxShape3D = (entry.area.get_child(0) as CollisionShape3D).shape
		var entry_z: float = entry.area.position.z + shape.size.z / 2
		var edge_z: float = -48 if index == 0 else -140
		var arrival: float = (entry_z - edge_z) / player.tuning.maximum_speed
		var block: Node = entry.fold
		check(arrival > block.anticipation + block.duration + block.settle_time, "fold %d is settled before even a constant full-speed arrival" % index)
	await _test_start()
	await _test_fold()
	await _test_fall_and_checkpoint()
	await _test_restart_and_pause()
	await _test_finish()
	print("integration: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _test_start() -> void:
	check(not paused, "the game is not paused at start")
	check(bool(player.get("controls_enabled")), "controls are live at start")
	var before: Vector3 = -player.global_basis.z
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.screen_relative = Vector2(-150, 0)
	motion.relative = Vector2(-150, 0)
	Input.parse_input_event(motion)
	await ticks(2)
	check(not before.is_equal_approx(-player.global_basis.z), "mouse look works on the first frames, no click needed")
	await ticks(60)
	check(float(main.get("elapsed")) == 0.0, "the timer waits until the runner moves")
	Input.action_press("move_forward")
	await ticks(60)
	Input.action_release("move_forward")
	check(bool(main.get("timer_running")) and float(main.get("elapsed")) > 0.0, "the timer starts with the first steps")


func _test_fold() -> void:
	var fold: Node = level.get("fold")
	check(not bool(fold.call("is_done")), "the tower stands before the trigger")
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(0, 0.9, -6)), Vector3.UP)
	await ticks(3)
	check(int(fold.get("phase")) != 0, "walking onto the trigger starts the fold")
	check(float(fold.call("get_progress")) == 0.0, "it announces itself before it moves")
	await ticks(120 * 6)
	check(bool(fold.call("is_done")), "the fold settles within six seconds")
	var tower: Node3D = fold as Node3D
	var facade_normal: Vector3 = tower.global_basis * Vector3.BACK
	check(facade_normal.dot(Vector3.UP) > 0.999, "the facade now faces the sky")
	var hit: Dictionary = _ray(Vector3(0, 5, -72), Vector3(0, -5, -72))
	check(not hit.is_empty() and absf(Vector3(hit["position"]).y) < 0.05, "the road surface sits level with the start roof")
	check(not _ray(Vector3(0, 5, -98.5), Vector3(0, -5, -98.5)).is_empty(), "the road reaches 48 m out")


func _test_fall_and_checkpoint() -> void:
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(0, 0.9, -57)), Vector3.UP)
	await ticks(3)
	check(int(main.get("checkpoint_index")) == 1, "standing on the road takes the checkpoint")
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(30, -25, -70)), Vector3.UP)
	await ticks(60)
	check(int(main.get("respawn_count")) == 1, "falling below the roofs respawns")
	check(player.global_position.distance_to(Vector3(0, 0.9, -56)) < 0.5, "respawn is at the last checkpoint")
	check(bool(level.get("fold").call("is_done")), "the fold stays folded after a fall")


func _test_restart_and_pause() -> void:
	main.call("restart_run")
	await ticks(2)
	var fold: Node = level.get("fold")
	check(not bool(fold.call("is_done")) and int(fold.get("phase")) == 0, "restart stands the tower back up")
	check(int(main.get("checkpoint_index")) == 0 and float(main.get("elapsed")) == 0.0, "restart clears checkpoint and timer")
	check(player.global_position.distance_to(Vector3(0, 0.9, 2)) < 0.3, "restart returns to the first roof")
	check((fold as Node3D).global_basis.y.dot(Vector3.UP) > 0.999, "the standing tower really stands, not just its state")
	# respawning past a fold that never ran cuts it straight to its landed pose
	main.set("checkpoint_index", 1)
	main.call("respawn")
	await ticks(30)
	check((fold as Node3D).global_basis.z.dot(Vector3.UP) > 0.999, "a cut to the folded state moves the tower itself")
	check(player.global_position.distance_to(Vector3(0, 0.9, -56)) < 0.3, "the runner stands on the cut road, not inside it")
	main.call("restart_run")
	await ticks(2)
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(0, 0.9, -6)), Vector3.UP)
	await ticks(3)
	main.call("set_paused", true)
	var phase: int = int(fold.get("phase"))
	var progress_marker: Transform3D = (fold as Node3D).transform
	var elapsed: float = float(main.get("elapsed"))
	await process_frame
	await process_frame
	await process_frame
	check(paused, "pause stops the tree")
	check((fold as Node3D).transform.is_equal_approx(progress_marker) and int(fold.get("phase")) == phase, "the fold holds still while paused")
	check(float(main.get("elapsed")) == elapsed, "the timer holds while paused")
	main.call("set_paused", false)
	await ticks(2)
	check(not paused and bool(player.get("controls_enabled")), "resume gives control back")


func _test_finish() -> void:
	var cues_before: int = int(main.get("cue_progress"))
	var finish: Vector3 = level.get("finish_point")
	player.call("reset_to", Transform3D(Basis.IDENTITY, finish + Vector3(0, 0.9, 4)), Vector3.UP)
	Input.action_press("move_forward")
	await ticks(120)
	Input.action_release("move_forward")
	check(bool(main.get("finished")), "reaching the beam finishes the run")
	check(float(main.get("best_time")) > 0.0, "a best time is kept")
	check(int(main.get("cue_progress")) >= cues_before, "cue progress never goes backwards")


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	return player.get_world_3d().direct_space_state.intersect_ray(query)

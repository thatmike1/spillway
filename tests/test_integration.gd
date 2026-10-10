extends SceneTree
## Real combined scene checks. This verifies state flow, not human route traversal.

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "Main scene loads")
	if packed == null:
		quit(1)
		return
	var main: Node3D = packed.instantiate() as Node3D
	root.add_child(main)
	await physics_frame
	await process_frame
	var player: CharacterBody3D = main.get("player") as CharacterBody3D
	var city: Node3D = main.get("city") as Node3D
	var route: Dictionary = main.get("route") as Dictionary
	_expect(player != null and city != null, "Player and city present")
	_expect(player.global_position.is_finite(), "Initial position finite")
	_expect(route.has("spawn") and route.has("fold") and route.has("entry_seam"), "Core route fixtures present")
	_expect(not bool(main.get("finished")), "Starts unfinished")
	for index: int in range(4):
		await physics_frame
	_expect(int(main.get("stage")) == 0, "Idle spawn does not trip roof trigger")
	var initial: Transform3D = route.get("spawn", Transform3D.IDENTITY)
	_expect(player.global_position.distance_to(initial.origin) < 0.5, "Player begins at authored spawn")
	main.call("_on_fold_trigger", player)
	_expect(int(main.get("stage")) == 1, "Fold trigger advances progression")
	var fold: Node = route["fold"] as Node
	_expect(bool(fold.call("is_folding")), "Fold actually begins")
	for index: int in range(8):
		await physics_frame
	_expect(float(fold.call("get_progress")) > 0.0, "Folding advances in combined scene")
	main.call("_set_pause", true)
	var paused_progress: float = float(fold.call("get_progress"))
	var paused_time: float = float(main.get("elapsed"))
	for index: int in range(5):
		await physics_frame
	_expect(is_equal_approx(float(fold.call("get_progress")), paused_progress), "Pause stops architecture")
	_expect(is_equal_approx(float(main.get("elapsed")), paused_time), "Pause stops run clock")
	main.call("_set_pause", false)
	main.call("_on_checkpoint_trigger", player)
	_expect(bool(main.get("has_checkpoint")), "Checkpoint registered")
	main.call("recover_checkpoint")
	var checkpoint: Transform3D = route.get("checkpoint", Transform3D.IDENTITY)
	_expect(player.global_position.distance_to(checkpoint.origin) < 0.05, "Recovery uses checkpoint pose")
	_expect(player.velocity.length() < 0.001, "Recovery clears momentum")
	main.call("_on_portal_crossed", player)
	_expect(int(main.get("stage")) == 4, "Portal progression advances")
	main.call("_on_finish_trigger", player)
	_expect(bool(main.get("finished")) and paused, "Finish stops simulation")
	main.call("restart_run")
	_expect(not bool(main.get("finished")) and not paused, "Restart restores running state")
	_expect(not bool(main.get("has_checkpoint")) and int(main.get("stage")) == 0, "Restart clears progression")
	_expect(is_zero_approx(float(fold.call("get_progress"))), "Restart restores architecture")
	_expect(player.global_position.distance_to(initial.origin) < 0.05, "Restart restores spawn")
	_expect(player.velocity.is_finite() and player.velocity.length() < 0.001, "Restart clears finite velocity")
	for index: int in range(4):
		await physics_frame
	_expect(not bool(main.get("finished")) and int(main.get("stage")) == 0, "Restart stays reset after real physics ticks")
	main.queue_free()
	await process_frame
	print("integration: %d checks, %d failures (state flow; visual/route feel unverified)" % [checks, failures])
	quit(1 if failures else 0)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

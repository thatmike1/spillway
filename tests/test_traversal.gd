extends SceneTree
## Scripted-input route traversal with actual collisions, triggers and portal.
## No waypoint teleports. Does not validate camera comfort or visual readability.

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var main: Node3D = packed.instantiate() as Node3D
	root.add_child(main)
	await physics_frame
	await process_frame
	var player: CharacterBody3D = main.get("player") as CharacterBody3D
	player.call("set_controls_enabled", true)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var jumped: bool = false
	var crossed: bool = false
	var checkpoint_seen: bool = false
	for frame: int in range(720):
		# Deliberate jump across the 2m break between bridge and arrival roof.
		if not jumped and player.global_position.z < -24.3 and player.global_position.x < 20.0:
			player.call("queue_jump")
			jumped = true
		await physics_frame
		await process_frame
		checkpoint_seen = checkpoint_seen or bool(main.get("has_checkpoint"))
		crossed = crossed or player.global_position.x > 60.0
		if frame % 90 == 0:
			print("route tick=%d position=%s up=%s stage=%d" % [frame, player.global_position, player.up_direction, int(main.get("stage"))])
		if not player.global_position.is_finite() or not player.velocity.is_finite():
			push_error("Non-finite traversal state")
			failures += 1
			break
		if bool(main.get("finished")):
			break
	Input.action_release("move_forward")
	Input.action_release("sprint")
	if not checkpoint_seen:
		push_error("Scripted traversal failed to reach checkpoint")
		failures += 1
	if not crossed:
		push_error("Scripted traversal failed to cross impossible window")
		failures += 1
	if not bool(main.get("finished")):
		push_error("Scripted traversal failed to finish")
		failures += 1
	print("traversal: %d failures, elapsed %.2fs; rendering and feel unverified" % [failures, float(main.get("elapsed"))])
	paused = false
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)

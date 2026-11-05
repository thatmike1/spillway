extends SceneTree
## the scripted runner completes the whole route with ordinary inputs only:
## held W, mouse-motion steering and Space. No waypoint teleports, no respawns.
## run once with default comfort settings and once with camera bank off.

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	for no_bank: bool in [false, true]:
		await _route(no_bank)
	print("traversal: %d failures; physics only, feel and visuals need a human" % failures)
	quit(1 if failures else 0)


func _route(no_bank: bool) -> void:
	var main: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	main.city_mode = true
	root.add_child(main)
	await physics_frame
	var player: CharacterBody3D = main.get("player")
	var bot: Node = main.call("attach_bot", false, no_bank)
	var fold: Node = main.get("level").get("fold")
	var previous: Vector3 = player.global_position
	var max_step: float = 0.0
	var max_up_turn: float = 0.0
	var saw_wall: bool = false
	var saw_fold_done: bool = false
	var actions: Dictionary = {}
	player.connect("move_started", func(kind: String) -> void: actions[kind] = true)
	var ticks: int = 0
	while ticks < 120 * 120:
		await physics_frame
		ticks += 1
		var step: float = player.global_position.distance_to(previous)
		max_step = maxf(max_step, step)
		previous = player.global_position
		saw_fold_done = saw_fold_done or bool(fold.call("is_done"))
		if player.up_direction.dot(Vector3.BACK) > 0.95:
			saw_wall = true
		max_up_turn = maxf(max_up_turn, player.up_direction.angle_to(Vector3.UP))
		if not player.global_position.is_finite():
			check(false, "non-finite position")
			break
		if bool(main.get("finished")):
			break
	var elapsed: float = float(main.get("elapsed"))
	for line: String in bot.get("log_lines"):
		print("  ", line)
	print("route (bank %s): finished=%s elapsed=%.2fs respawns=%d max_step=%.3fm actions=%s" % [
		"off" if no_bank else "on", main.get("finished"), elapsed, int(main.get("respawn_count")), max_step, actions.keys()])
	check(bool(main.get("finished")), "bot did not finish the route")
	check(int(main.get("respawn_count")) == 0, "bot fell and respawned")
	check(saw_fold_done, "fold never completed")
	for block: Node in main.get("level").get("folds"):
		check(bool(block.call("is_done")), "%s never landed" % block.name)
	check(saw_wall, "never ran on the tower face")
	check(max_up_turn > deg_to_rad(85.0), "gravity never turned to the wall")
	# 120 Hz physics at ~10 m/s is under 0.1 m a tick; anything big is a teleport
	check(max_step < 0.35, "position jumped %.2fm in one tick" % max_step)
	check(elapsed >= 60.0 and elapsed <= 90.0, "run length %.1fs outside the 60-90s slice" % elapsed)
	for kind: String in ["vault", "high_vault", "wallclimb", "grab", "pullup", "roll", "slide", "wallrun", "walljump", "springboard", "step", "turn"]:
		check(actions.has(kind), "route missed " + kind)
	Input.action_release("move_forward")
	main.queue_free()
	await process_frame
	await physics_frame

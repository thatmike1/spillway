extends SceneTree
## input-only chained yard lap: no position/velocity assignments after startup.
var failures: int = 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var actions: Dictionary = {}
	var jumps: Array = [0]
	var normal: Array = [false]
	main.player.move_started.connect(func(kind): actions[kind] = true)
	main.player.jumped.connect(func(): jumps[0] += 1)
	main.player.landed.connect(func(_impact): normal[0] = normal[0] or main.player.landing.kind == "normal")
	var bot = main.attach_bot()
	for i: int in 120 * 45:
		await physics_frame
		if main.finished:
			break
	print("yard chain: finished=%s elapsed=%.3f respawns=%d actions=%s jumps=%d normal=%s at=%s waypoint=%d" % [main.finished, main.elapsed, main.respawn_count, actions.keys(), jumps[0], normal[0], main.player.position, bot.index])
	for line: String in bot.log_lines:
		print(line)
	check(main.finished and main.respawn_count == 0, "yard chain completes without respawn")
	check(jumps[0] >= 2 and normal[0], "yard chain includes jump and ordinary landing")
	for action: String in ["vault", "springboard", "roll", "wallrun", "walljump"]:
		check(actions.has(action), "yard chain includes %s" % action)
	print("yard chain: %d/7 checks passed" % (7 - failures))
	main.audio.stop_all()
	quit(1 if failures else 0)

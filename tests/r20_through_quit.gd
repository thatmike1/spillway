extends "res://tests/r20_through_component.gd"
## exercise the real asynchronous quit after a physical launch; save before its eight-frame drain exits.
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.render_loop_enabled = false
	Engine.physics_ticks_per_second = 128
	hook = Post.new()
	hook.driver = self
	hook.process_physics_priority = 1001
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	new_case("quit", Vector3(0, 6, -39.96), Vector3(0, 0, -500))
	await ticks(1)
	check(game.player.used and game.player.cue_player.playing, "physical launch before quit")
	game.request_quit(0)
	check(game._quitting and game.player.cue_left_s == 0.0 and not game.player.cue_player.playing and not game.player.monitoring, "actual quit synchronously clears all experimental feedback and pending observations")
	check(not game.session.recorder.is_open(), "quit seals active recorder before drain")
	var ok := checks.all(func(row: Dictionary) -> bool: return bool(row.ok))
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks, "recordings": game.session.sealed}, "\t"))
	file.close()
	if not ok:
		quit(1)

extends "res://tests/viaduct_replay.gd"
## raw event replay through the live menu host, checkpoint lifecycle and recording identity.
const HOST := preload("res://scripts/game.gd")

func replay(tape_path: String) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(tape_path))
	if not parsed is Array or parsed.is_empty():
		return false
	var events: Array = parsed
	for action: StringName in InputMap.get_actions():
		Input.action_release(action)
	for index: int in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		var release := InputEventMouseButton.new()
		release.button_index = index
		release.pressed = false
		Input.parse_input_event(release)
	Input.flush_buffered_events()
	var game := HOST.new()
	game.map_id = "viaduct"
	game.motor = "server128"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = "/tmp/r22-01-swing-flow/host-absent.cfg"
	game.ghosts_directory = "/tmp/r22-01-swing-flow/host-ghosts"
	game.ghost_share_storage = "/tmp/r22-01-swing-flow/host-selection.cfg"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_input(false)
	var player: CharacterBody3D = game.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	game.restart_run("restart")
	var identity: Dictionary = game.motion_identity()
	var cursor := 0
	var ticks := 0
	await physics_frame
	for tick: int in 4000:
		ticks = tick+1
		while cursor < events.size() and roundi(float(events[cursor].time)*128) <= tick:
			inject_event(player,events[cursor])
			cursor += 1
		player._physics_process(1.0/128)
		game._physics_process(1.0/128)
		if game.finished or cursor == events.size():
			break
		await physics_frame
	var ok: bool = game.startup_error.is_empty() and game.finished and game.finish_kind == "clean" and game.checkpoint_index == 3 and game.respawn_count == 0 and identity.map == "viaduct" and player.model == "elastic-arc"
	print("VIADUCT LIVE HOST ",ok," ticks=",ticks," finish=",game.finish_kind," checkpoint=",game.checkpoint_index," respawns=",game.respawn_count," map=",identity.map," model=",player.model," course=",identity.course_key," geometry-version=",game.level.level_version)
	game.request_quit(0)
	game.free()
	await physics_frame
	return ok

extends SceneTree
## real-host checkpoint regression: replay to an early landing, inject a fall, then restart cleanly.
const HOST := preload("res://scripts/game.gd")
var output := ""
var tape_path := ""
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg.begins_with("--tape="):
			tape_path = arg.trim_prefix("--tape=")
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"ok":ok,"check":label})
	if not ok:
		push_error(label)
func release_inputs() -> void:
	for action: String in ["move_forward","move_back","move_left","move_right","jump","crouch"]:
		Input.action_release(action)
func run() -> void:
	if not output.is_absolute_path() or not FileAccess.file_exists(tape_path):
		push_error("pass --tape=<real-course tapes.json> and external --out")
		quit(1)
		return
	RenderingServer.render_loop_enabled = false
	Engine.physics_ticks_per_second = 128
	var tape: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(tape_path))
	check(not tape.get("calibration",true) and tape.map_id == "outer-reach", "input fixture is real-course data")
	var game := HOST.new()
	game.map_id = "outer-reach"
	game.motor = "server128"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output.path_join("absent.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.apply_preset("csgo_server",{"sensitivity":2.5,"fov":90.0})
	await physics_frame
	var first := await replay(game,tape.results[0],true)
	check(first.early_landing, "normal inputs reach an early receiver")
	check(game.checkpoint_index == 0, "early receiver keeps quay checkpoint")
	# fault injection is explicitly separate from the clean replay below; no velocity is seeded.
	release_inputs()
	game.player.reset_to(Transform3D(Basis.IDENTITY,game.player.global_position+Vector3.DOWN*10))
	for tick: int in 32:
		game.player._physics_process(1.0/128)
		game._physics_process(1.0/128)
		await physics_frame
	check(game.respawn_count == 1 and game.checkpoint_index == 0, "water fall retains quay checkpoint")
	check(game.player.global_position.distance_to(game.level.spawn.origin) < 0.1, "fall returns to acceleration quay")
	game.practice_restart()
	check(game.practice_stage == 0 and not game.clean_eligible and game.player.global_position.distance_to(game.level.spawn.origin) < 0.1, "practice after early landing also starts at quay")
	release_inputs()
	game.restart_run()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	await physics_frame
	var clean := await replay(game,tape.results[0],false)
	check(clean.early_checkpoint_ok, "all seven receivers preserve quay checkpoint")
	check(game.finished and game.finish_kind == "clean" and game.respawn_count == 0, "unmodified normal-spawn input lap finishes cleanly")
	check(game.checkpoint_index == 1, "pump checkpoint is reached only at terminal court")
	var identity: Dictionary = game.motion_identity()
	var result := {"ok":checks.all(func(row: Dictionary) -> bool:return row.ok),"checks":checks,"samples":samples,"geometry_hash":game.level.geometry_hash(),"identity":identity,"finished":game.finished,"finish_kind":game.finish_kind,"respawns":game.respawn_count,"elapsed":game.elapsed,"feet":str(game.player.global_position),"fault_injection":"only the separate early-fall regression resets below water; clean replay starts again from spawn with zero velocity"}
	release_inputs()
	game.request_quit(0)
	game.free()
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("host.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("OUTER HOST ",result.ok," elapsed=",result.elapsed)
	quit(0 if result.ok else 1)
func replay(game: Node3D, tape: Dictionary, stop_early: bool) -> Dictionary:
	var event_index := 0
	var early_checkpoint_ok := true
	var was_grounded := false
	for tick: int in int(tape.ticks):
		while event_index < tape.events.size() and float(tape.events[event_index].time) <= float(tick)/128:
			var event: Dictionary = tape.events[event_index]
			if event.has("action"):
				if event.pressed:
					Input.action_press(str(event.action))
				else:
					Input.action_release(str(event.action))
			else:
				var motion := InputEventMouseMotion.new()
				motion.screen_relative = Vector2(event.mouse[0],event.mouse[1])
				game.player._unhandled_input(motion)
			event_index += 1
		game.player._physics_process(1.0/128)
		game._physics_process(1.0/128)
		var grounded: bool = game.player.is_grounded()
		var feet: Vector3 = game.player.global_position
		if feet.z > -188.3:
			early_checkpoint_ok = early_checkpoint_ok and game.checkpoint_index == 0
		if grounded and not was_grounded:
			samples.append({"phase":"fall-probe" if stop_early else "clean","tick":tick,"feet":str(feet),"checkpoint":game.checkpoint_index})
			if stop_early and feet.z < -64.5:
				return {"early_landing":true,"early_checkpoint_ok":early_checkpoint_ok}
		was_grounded = grounded
		await physics_frame
	return {"early_landing":false,"early_checkpoint_ok":early_checkpoint_ok}

extends SceneTree
## replay retained commands without the geometry-aware controller that generated them.
const LEVEL := preload("res://scripts/maps/sluice_six.gd")
const PLAYER := preload("res://scripts/movement/course_player.gd")
var tape_path := ""
var output := ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tape="):
			tape_path = arg.trim_prefix("--tape=")
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	call_deferred("run")
func run() -> void:
	if not FileAccess.file_exists(tape_path) or not output.is_absolute_path():
		push_error("pass --tape=<retained tapes.json> and --out=<external folder>")
		quit(1)
		return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(tape_path))
	var level := LEVEL.new()
	root.add_child(level)
	level.build()
	if source.preset != "server128" or source.geometry_hash != level.geometry_hash():
		push_error("tape identity does not match this geometry and f2")
		quit(1)
		return
	Engine.physics_ticks_per_second = 128
	for action: String in ["move_forward","move_back","move_left","move_right","look_left","look_right","look_up","look_down","jump","crouch"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var player := PLAYER.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.apply_preset("csgo_server")
	await physics_frame
	var rows: Array = []
	for tape: Dictionary in source.results:
		for action: String in ["move_forward","move_left","move_right","jump"]:
			Input.action_release(action)
		player.reset_to(level.spawn)
		var safe := true
		for command: Dictionary in tape.commands:
			for action: String in ["move_forward","move_left","move_right","jump"]:
				Input.action_release(action)
			if command.forward > 0:
				Input.action_press("move_forward",command.forward)
			if command.side != 0:
				Input.action_press("move_right" if command.side > 0 else "move_left",absf(command.side))
			if command.jump:
				Input.action_press("jump")
			var motion := InputEventMouseMotion.new()
			motion.screen_relative = Vector2(-wrapf(command.yaw-player.yaw,-PI,PI)/deg_to_rad(float(player.settings.sensitivity)*float(player.settings.m_yaw)),0)
			player._unhandled_input(motion)
			player._physics_process(1.0/128)
			safe = safe and level.kill_bounds.has_point(player.global_position)
			await physics_frame
		var ok: bool = safe and level.is_finish_at(player.global_position) and str(player.global_position) == tape.feet and tape.commands.size() == tape.ticks
		rows.append({"line":tape.line,"ok":ok,"ticks":tape.ticks,"feet":str(player.global_position),"expected_feet":tape.feet})
		print("REPLAY ",JSON.stringify(rows.back()))
	for action: String in ["move_forward","move_left","move_right","jump"]:
		Input.action_release(action)
	DirAccess.make_dir_recursive_absolute(output)
	var report := FileAccess.open(output.path_join("replay.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"geometry_hash":level.geometry_hash(),"results":rows}))
	quit(0 if rows.size() == 2 and rows.all(func(r: Dictionary) -> bool:return r.ok) else 1)

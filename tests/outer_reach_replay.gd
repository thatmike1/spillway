extends SceneTree
## replay retained action and mouse-count events without geometry-aware steering or yaw correction.
const LEVEL := preload("res://scripts/maps/outer_reach.gd")
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
	if source.get("calibration",true) or source.get("map_id","") != "outer-reach" or source.preset != "server128" or source.geometry_hash != level.geometry_hash() or source.get("look", {}) != {"sensitivity":2.5,"fov":90.0}:
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
	player.apply_preset("csgo_server", {"sensitivity":2.5,"fov":90.0})
	await physics_frame
	var rows: Array = []
	for tape: Dictionary in source.results:
		for action: String in ["move_forward","move_left","move_right","jump"]:
			Input.action_release(action)
		player.reset_to(level.spawn)
		var safe := true
		var event_index := 0
		for tick: int in int(tape.ticks):
			while event_index < tape.events.size() and float(tape.events[event_index].time) <= float(tick)/128.0:
				var event: Dictionary = tape.events[event_index]
				if event.has("action"):
					if event.pressed:
						Input.action_press(str(event.action))
					else:
						Input.action_release(str(event.action))
				else:
					var mouse := InputEventMouseMotion.new()
					mouse.screen_relative = Vector2(float(event.mouse[0]),float(event.mouse[1]))
					player._unhandled_input(mouse)
				event_index += 1
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
	quit(0 if rows.size() == 1 and rows.all(func(r: Dictionary) -> bool:return r.ok) else 1)

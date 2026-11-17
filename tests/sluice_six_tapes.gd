extends SceneTree
## normal spawn, real f2 runner, input commands only after the initial reset.
const LEVEL := preload("res://scripts/maps/sluice_six.gd")
const PLAYER := preload("res://scripts/movement/course_player.gd")
var expert := false
var level: Node3D
var player: CharacterBody3D
var output := "/tmp/r22-06-bhop-course/tapes"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--expert":
			expert = true
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	call_deferred("run")
func run() -> void:
	Engine.physics_ticks_per_second = 128
	for action: String in ["move_forward","move_back","move_left","move_right","look_left","look_right","look_up","look_down","jump","crouch"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	level = LEVEL.new()
	root.add_child(level)
	level.build()
	player = PLAYER.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.apply_preset("csgo_server")
	await physics_frame
	var results: Array = []
	for fast: bool in [false,true]:
		if fast and not expert:
			continue
		player.reset_to(level.spawn)
		var tape: Array = []
		var events: Array = []
		var stages: Array[int] = []
		var previous := {"move_forward":false,"move_left":false,"move_right":false,"jump":false}
		var finished := false
		var air_tick := 0
		var pair_side := 1.0
		for tick: int in 6000:
			var feet := player.global_position
			var edge := -10000.0
			for d: Dictionary in level.decks:
				if feet.z <= d.near + 0.4 and feet.z >= d.far - 0.4:
					edge = d.far
					break
			var jump: bool = player.is_grounded() and feet.z - edge < (1.8 if fast else 1.0)
			var command := {"forward":1.0,"side":0.0,"yaw":0.0,"jump":jump}
			if player.is_grounded():
				air_tick = 0
			if fast and not player.is_grounded():
				command.forward = 0.0
				if Vector2(player.velocity.x,player.velocity.z).length() < 8.0 or air_tick % 2 == 1:
					if air_tick % 2 == 0:
						pair_side = -1.0 if feet.x > 0 else 1.0
					command.side = pair_side if air_tick % 2 == 0 else -pair_side
					command.yaw = atan2(-player.velocity.x,-player.velocity.z)
					air_tick += 1
			Input.action_release("move_forward")
			Input.action_release("move_left")
			Input.action_release("move_right")
			if command.forward > 0:
				Input.action_press("move_forward",command.forward)
			if command.side != 0:
				Input.action_press("move_right" if command.side > 0 else "move_left")
			if jump:
				Input.action_press("jump")
			else:
				Input.action_release("jump")
			var motion := InputEventMouseMotion.new()
			motion.screen_relative = Vector2(-wrapf(command.yaw-player.yaw,-PI,PI)/deg_to_rad(float(player.settings.sensitivity)*float(player.settings.m_yaw)),0)
			player._unhandled_input(motion)
			var actions := {"move_forward":command.forward > 0,"move_left":command.side < 0,"move_right":command.side > 0,"jump":jump}
			for action: String in actions:
				if actions[action] != previous[action]:
					events.append({"time":float(tick)/128.0,"action":action,"pressed":actions[action]})
			previous = actions
			if motion.screen_relative != Vector2.ZERO:
				events.append({"time":float(tick)/128.0,"mouse":[motion.screen_relative.x,0.0]})
			player._physics_process(1.0/128)
			tape.append(command)
			if player.is_grounded():
				var stage: int = level.segment_at(player.global_position)
				if not stages.has(stage):
					stages.append(stage)
			if not level.kill_bounds.has_point(player.global_position):
				print("FALL tick=",tick," feet=",player.global_position)
				break
			if level.is_finish_at(player.global_position):
				finished = true
				break
			await physics_frame
		var result := {"line":"fast" if fast else "basic","finished":finished,"ticks":tape.size(),"feet":str(player.global_position),"commands":tape,"stages":stages}
		DirAccess.make_dir_recursive_absolute(output)
		var event_file := FileAccess.open(output.path_join(result.line+"-events.json"),FileAccess.WRITE)
		event_file.store_string(JSON.stringify(events))
		results.append(result)
		Input.action_release("move_left")
		Input.action_release("move_right")
		print("TAPE ",result.line," finished=",finished," ticks=",tape.size()," feet=",player.global_position)
	Input.action_release("move_forward")
	Input.action_release("jump")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("tapes.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"geometry_hash":level.geometry_hash(),"preset":"server128","results":results}))
	var ok := results.all(func(r: Dictionary) -> bool:return r.finished and r.stages == [0,1,2,3])
	if expert:
		ok = ok and results.size() == 2 and results[1].ticks < results[0].ticks
	quit(0 if ok else 1)

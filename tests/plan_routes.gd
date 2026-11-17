extends SceneTree
## drive the production host using ordinary input, then replay the recorded commands.
const HOST := preload("res://scripts/game.gd")
const LAYOUT := preload("res://scripts/plan/layout.gd")
var game: Node
var tick := 0
var trial := 0
var stage := 0
var tape: Array = []
var replay := false
var complete := false
var ready := false
var rows: Array = []
var output := "/tmp/r22-14-anchor-plan/routes"
var mode := "west"
var last_trial := 2
var arc_mode := false
var release_rise_mps := 6.0
var release_delay := 0.0
var aim_ceiling := 90.0
var pending_release := -1
var settling := 40
var rope_stage := 0
var aim_age := 0
var buttons := {}
var held := {}
var initial_attempt := 0
var attached_ticks := 0
var max_height := 0.0
var max_speed := 0.0
var landings: Array = []
var prior_grounded := true
var points: Array[Vector3] = []
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--aim-ceiling="):
			aim_ceiling = float(arg.trim_prefix("--aim-ceiling="))
		if arg.begins_with("--delay="):
			release_delay = float(arg.trim_prefix("--delay="))
		if arg.begins_with("--rise="):
			release_rise_mps = float(arg.trim_prefix("--rise="))
		if arg == "--arc":
			arc_mode = true
		if arg.begins_with("--trial="):
			trial = int(arg.trim_prefix("--trial="))
			last_trial = trial
		if arg == "--only-west":
			last_trial = 0
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	RenderingServer.render_loop_enabled = false
	start.call_deferred()
func start() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game = HOST.new()
	game.map_id = "plan-yard"
	game.motor = "server128"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output.path_join("profile.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	root.add_child(game)
	await process_frame
	begin()
func begin() -> void:
	mode = ["west", "diagonal", "centre"][trial]
	var plans := [[0,3,6], [1,4,8], [1,4,7]]
	tick = 0
	if not replay:
		event({"time":0,"button":1,"pressed":false})
		event({"time":0,"button":2,"pressed":false})
		key("Tab")
		for i: int in LAYOUT.DEFAULT:
			key(str(i+1))
		for i: int in plans[trial]:
			key(str(i+1))
		key("Enter")
	else:
		for row: Dictionary in tape:
			if float(row.time) == 0:
				event(row)
	assert(game.level.plan == plans[trial])
	if trial < 2:
		var x := -14.0 if trial == 0 else 14.0
		points = [Vector3(x,3,13), Vector3(x,3,-49), Vector3(0,3,-49)]
	else:
		points = [Vector3(-8,3,5), Vector3(-8,3,-36), Vector3(0,3,-49)]
	settling = 40
	pending_release = -1
	rope_stage = 0
	aim_age = 0
	if arc_mode:
		points[0] = Vector3(LAYOUT.SOCKETS[plans[trial][0]].x,3,13)
	stage = 0
	tick = 0
	attached_ticks = 0
	max_height = 0
	max_speed = 0
	landings = []
	prior_grounded = true
	initial_attempt = game.attempts
	ready = true
func event(row: Dictionary) -> void:
	if not replay:
		tape.append(row)
	var input: InputEvent
	if row.has("key"):
		var keyboard := InputEventKey.new()
		keyboard.keycode = OS.find_keycode_from_string(row.key)
		keyboard.physical_keycode = keyboard.keycode
		keyboard.pressed = row.pressed
		input = keyboard
	elif row.has("mouse"):
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(row.mouse[0], row.mouse[1])
		motion.screen_relative = motion.relative
		input = motion
	elif row.has("action"):
		var action := InputEventAction.new()
		action.action = row.action
		action.pressed = row.pressed
		action.strength = row.get("strength", 1.0)
		input = action
	else:
		var button := InputEventMouseButton.new()
		buttons[int(row.button)] = bool(row.pressed)
		button.button_index = row.button
		button.pressed = row.pressed
		input = button
	Input.parse_input_event(input)
	Input.flush_buffered_events()
func key(code: String) -> void:
	event({"time":0,"key":code,"pressed":true})
	event({"time":0,"key":code,"pressed":false})
func button(index: int, on: bool) -> void:
	if bool(buttons.get(index,false)) != on:
		buttons[index] = on
		event({"time":tick/128.0,"button":index,"pressed":on})
func action(id: String, strength: float) -> void:
	if absf(float(held.get(id,-1))-strength) > 0.005:
		held[id] = strength
		event({"time": tick/128.0, "action": id, "pressed": strength > 0, "strength": strength})
func _physics_process(_delta: float) -> bool:
	if not ready or complete or game == null or game.player == null:
		return false
	if settling > 0:
		settling -= 1
		tick += 1
		return false
	var player: CharacterBody3D = game.player
	if bool(game.finished) or tick > 128*22 or game.attempts != initial_attempt or game.respawn_count > 0:
		end_trial()
		return false
	if replay:
		for row: Dictionary in tape:
			if not row.has("key") and roundi(float(row.time)*128) == tick:
				event(row)
	else:
		var at := player.global_position
		if tick % 64 == 0:
			print("sample ",tick," stage ",stage," at ",at," velocity ",player.velocity," yaw ",player.yaw," rope_stage ",rope_stage," rope ",player.grapple," inputs ",[Input.get_action_strength("move_forward"),Input.get_action_strength("move_back"),Input.get_action_strength("move_left"),Input.get_action_strength("move_right")])
		var target: Vector3 = points[stage]
		if Vector2(at.x-target.x,at.z-target.z).length() < (1.0 if stage == 0 else 4.5) and stage < points.size()-1:
			stage += 1
			target = points[stage]
		var desired := target - at
		desired.y = 0
		var aim := target - (at+Vector3.UP*1.6256) - Vector3(player.velocity.x,0,player.velocity.z)*0.25
		if arc_mode:
			var socket: int = game.level.plan[mini(rope_stage,2)]
			var ring: Vector3 = LAYOUT.SOCKETS[socket]
			desired = Vector3(ring.x-at.x-player.velocity.x*0.8,0,-15)
			if stage == 0:
				desired = target-at
				desired.y = 0
			if rope_stage >= 3:
				desired = Vector3(0-at.x,0,-49-at.z)
				aim = desired + Vector3.DOWN*1.6256
			else:
				aim = ring-(at+Vector3.UP*1.6256)
			aim_age += 1
			var holding: bool = rope_stage < 3 and aim_age > 5 and at.z < 8
			var release_ready: bool = at.z < ring.z - 1.0 and player.velocity.y > (3.0 if socket == 4 else release_rise_mps)
			if socket == 4:
				release_ready = release_ready and at.y > 11
			if rope_stage == 2:
				release_ready = at.z < ring.z - 3 and at.y > 5.0 and player.velocity.z < -5
			if holding and pending_release < 0 and release_ready:
				pending_release = tick + roundi(release_delay*128)
			if pending_release >= 0 and tick >= pending_release:
				holding = false
				pending_release = -1
				rope_stage += 1
				aim_age = 0
			button(1,holding)
			button(2,holding)
		var yaw := atan2(-aim.x,-aim.z)
		var pitch := atan2(aim.y,Vector2(aim.x,aim.z).length())
		pitch = minf(pitch,deg_to_rad(aim_ceiling))
		var meta: Dictionary = game.look_metadata()
		var dx := -wrapf(yaw-player.yaw,-PI,PI)/float(meta.yaw_rad_per_count)
		var dy: float = (player.pitch-pitch)/float(meta.pitch_rad_per_count)
		event({"time": tick/128.0,"mouse":[dx,dy]})
		if arc_mode:
			var forward := Vector3(-sin(yaw),0,-cos(yaw))
			var right := Vector3(cos(yaw),0,-sin(yaw))
			desired = desired.normalized()
			var horizontal := Vector2(player.velocity.x,player.velocity.z)
			if player.grapple.is_empty() and not player.is_grounded() and horizontal.length() > 0.1 and horizontal.length() < 5:
				var a := horizontal.normalized().rotated(PI/2)
				var b := horizontal.normalized().rotated(-PI/2)
				var goal := Vector2(desired.x,desired.z)
				var wish := a if a.dot(goal) > b.dot(goal) else b
				desired = Vector3(wish.x,0,wish.y)
			var f := desired.dot(forward)
			var side := desired.dot(right)
			action("move_forward",maxf(f,0))
			action("move_back",maxf(-f,0))
			action("move_right",maxf(side,0))
			action("move_left",maxf(-side,0))
			action("jump",1 if stage > 0 and at.z < 8 else 0)
		else:
			action("move_forward",1)
			action("jump",1 if stage == 1 and at.z < -2 and absf(player.velocity.x) < 0.5 else 0)
	if not player.grapple.is_empty():
		attached_ticks += 1
	max_height = maxf(max_height, player.global_position.y)
	max_speed = maxf(max_speed, player.get_speed())
	if player.is_grounded() and not prior_grounded:
		landings.append({"tick": tick, "position": str(player.global_position), "speed_mps":player.get_speed()})
	prior_grounded = player.is_grounded()
	tick += 1
	return false
func end_trial() -> void:
	var row := {"plan": game.level.plan, "route": mode, "replay": replay, "finished": game.finished, "clean": game.finish_kind, "ticks": tick, "time": game.elapsed, "attached_ticks": attached_ticks, "max_height": max_height, "max_speed_mps":max_speed, "landings":landings, "arc_mode": arc_mode, "release_rise_mps": release_rise_mps, "release_delay_s":release_delay, "aim_ceiling_deg":aim_ceiling, "position": str(game.player.global_position), "identity": game.motion_identity()}
	rows.append(row)
	print(JSON.stringify(row))
	for id: String in ["move_forward","move_back","move_left","move_right","jump"]:
		Input.action_release(id)
	held.clear()
	button(1,false)
	button(2,false)
	buttons.clear()
	if not replay:
		FileAccess.open(output.path_join(mode+"-tape.json"),FileAccess.WRITE).store_string(JSON.stringify(tape))
		replay = true
		schedule_trial()
	else:
		replay = false
		tape = []
		trial += 1
		if trial <= last_trial:
			schedule_trial()
		else:
			FileAccess.open(output.path_join("routes.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
			complete = true
			var ok := rows.all(func(r: Dictionary) -> bool: return r.finished and r.clean == "clean")
			for i: int in range(0,rows.size(),2):
				for field: String in ["ticks","time","position","identity","attached_ticks"]:
					ok = ok and rows[i][field] == rows[i+1][field]
			game.request_quit(0 if ok else 1)

func schedule_trial() -> void:
	ready = false
	game.free()
	game = null
	start.call_deferred()

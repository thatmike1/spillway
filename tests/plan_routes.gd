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
var rows: Array = []
var output := "/tmp/r22-14-anchor-plan/routes"
var mode := "west"
var last_trial := 2
var held := {}
var initial_attempt := 0
var attached_ticks := 0
var max_height := 0.0
var points: Array[Vector3] = []
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
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
	mode = ["west", "east", "centre"][trial]
	var plans := [[0,3,6], [2,5,8], [1,4,7]]
	game.player.open_plan()
	game.level.apply_plan(plans[trial])
	game.player.close_plan()
	if trial < 2:
		var x := -14.0 if trial == 0 else 14.0
		points = [Vector3(x,3,13), Vector3(x,3,-49), Vector3(0,3,-49)]
	else:
		points = [Vector3(-8,3,5), Vector3(-8,3,-36), Vector3(0,3,-49)]
	stage = 0
	tick = 0
	attached_ticks = 0
	max_height = 0
	initial_attempt = game.attempts
func event(row: Dictionary) -> void:
	if not replay:
		tape.append(row)
	var input: InputEvent
	if row.has("mouse"):
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
		button.button_index = row.button
		button.pressed = row.pressed
		input = button
	Input.parse_input_event(input)
	Input.flush_buffered_events()
func action(id: String, strength: float) -> void:
	if absf(float(held.get(id,-1))-strength) > 0.005:
		held[id] = strength
		event({"time": tick/128.0, "action": id, "pressed": strength > 0, "strength": strength})
func _physics_process(_delta: float) -> bool:
	if complete or game == null or game.player == null:
		return false
	var player: CharacterBody3D = game.player
	if bool(game.finished) or tick > 128*22 or game.attempts != initial_attempt or game.respawn_count > 0:
		end_trial()
		return false
	if replay:
		for row: Dictionary in tape:
			if roundi(float(row.time)*128) == tick:
				event(row)
	else:
		var at := player.global_position
		if tick % 128 == 0:
			print("sample ",tick," stage ",stage," at ",at," velocity ",player.velocity," yaw ",player.yaw)
		var target: Vector3 = points[stage]
		if Vector2(at.x-target.x,at.z-target.z).length() < (1.0 if stage == 0 else 4.5) and stage < points.size()-1:
			stage += 1
			target = points[stage]
		var aim := target - (at+Vector3.UP*1.6256) - Vector3(player.velocity.x,0,player.velocity.z)*0.25
		var yaw := atan2(-aim.x,-aim.z)
		var pitch := atan2(aim.y,Vector2(aim.x,aim.z).length())
		var meta: Dictionary = game.look_metadata()
		var dx := -wrapf(yaw-player.yaw,-PI,PI)/float(meta.yaw_rad_per_count)
		var dy: float = (player.pitch-pitch)/float(meta.pitch_rad_per_count)
		event({"time": tick/128.0,"mouse":[dx,dy]})
		action("move_forward",1)
		action("jump",1 if stage == 1 and at.z < -2 and absf(player.velocity.x) < 0.5 else 0)
	if not player.grapple.is_empty():
		attached_ticks += 1
	max_height = maxf(max_height, player.global_position.y)
	tick += 1
	return false
func end_trial() -> void:
	var row := {"plan": game.level.plan, "route": mode, "replay": replay, "finished": game.finished, "clean": game.finish_kind, "ticks": tick, "time": game.elapsed, "attached_ticks": attached_ticks, "max_height": max_height, "position": str(game.player.global_position), "identity": game.motion_identity()}
	rows.append(row)
	print(JSON.stringify(row))
	for id: String in ["move_forward","move_back","move_left","move_right","jump"]:
		Input.action_release(id)
	held.clear()
	if not replay:
		FileAccess.open(output.path_join(mode+"-tape.json"),FileAccess.WRITE).store_string(JSON.stringify(tape))
		replay = true
		begin()
	else:
		replay = false
		tape = []
		trial += 1
		if trial <= last_trial:
			begin()
		else:
			FileAccess.open(output.path_join("routes.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
			complete = true
			var ok := rows.all(func(r: Dictionary) -> bool: return r.finished and r.clean == "clean")
			game.request_quit(0 if ok else 1)

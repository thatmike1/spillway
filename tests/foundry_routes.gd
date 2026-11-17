extends SceneTree
## command-only route construction followed by a fixed-input replay from normal spawn.
const LEVEL := preload("res://scripts/maps/foundry.gd")
const PLAYER := preload("res://scripts/movement/grapple_player.gd")
const PRESETS := preload("res://scripts/r14_presets.gd")
var level: Node3D
var player: CharacterBody3D
var output := "/tmp/r22-02-swing-height/routes"
var held := false
var tape: Array = []
var reached: Array = []
var last_catch := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func mouse(on: bool) -> void:
	if held == on:
		return
	held = on
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = on
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	player._unhandled_input(event)
	var reel := InputEventMouseButton.new()
	reel.button_index = MOUSE_BUTTON_RIGHT
	reel.pressed = on
	Input.parse_input_event(reel)
	Input.flush_buffered_events()

func reset() -> void:
	reached = [0]
	mouse(false)
	Input.action_release("move_forward")
	Input.action_release("jump")
	player.reset_to(level.spawn)
	player.configure_tether("elastic-arc", false)
	player.input_enabled = true
	player._input_blocked = false

func aim(at: Vector3) -> void:
	var d: Vector3 = at - player._eye()
	player.yaw = atan2(-d.x,-d.z)
	player.pitch = clampf(atan2(d.y,Vector2(d.x,d.z).length()),-player.PITCH_LIMIT,player.PITCH_LIMIT)

func step(at: Vector3, rope: bool, jump: bool, forward: bool = true) -> void:
	aim(at)
	mouse(rope)
	if forward:
		Input.action_press("move_forward")
	else:
		Input.action_release("move_forward")
	if jump:
		Input.action_press("jump")
	else:
		Input.action_release("jump")
	tape.append({"yaw":player.yaw,"pitch":player.pitch,"rope":rope,"jump":jump,"forward":forward})
	player._physics_process(1.0/128)
	observe_checkpoints()

func observe_checkpoints() -> void:
	for i: int in level.checkpoints.size():
		if level.checkpoints[i].bounds.has_point(player.position) and i not in reached:
			reached.append(i)

func walk(at: Vector3, limit: int = 1400) -> bool:
	for tick: int in limit:
		var flat := Vector2(player.position.x-at.x,player.position.z-at.z).length()
		if flat < 1.1:
			return true
		await step(Vector3(at.x,player._eye().y,at.z),false,false)
	return false

func crossing(anchor: Vector3, target: Vector3, hold_ticks: int) -> void:
	for tick: int in hold_ticks:
		await step(anchor,true,tick < 10)
	for tick: int in 700:
		if player.position.z < target.z+1 and player.position.y < target.y+1 and player.position.y > target.y-1:
			break
		await step(Vector3(target.x,player._eye().y,target.z-4),false,false)
		if player.position.y < -6:
			break

func route(shortcut: bool, hold_ticks: int) -> Dictionary:
	await reset()
	tape = []
	if shortcut:
		await walk(Vector3(0,18,3))
		await crossing(LEVEL.FOUNDRY_ANCHORS[0],Vector3(0,12,-28),hold_ticks)
	else:
		await walk(Vector3(-16,18,7))
		await walk(Vector3(-16,12,-28))
		await walk(Vector3(0,12,-30))
	var crossed := player.position.y > 11 and player.position.z < -19 and player.position.z > -37
	var crossing_ticks := tape.size()
	if crossed:
		await walk(Vector3(0,12,-33))
		await crossing(LEVEL.FOUNDRY_ANCHORS[2],Vector3(0,2,-56),110)
		var caught := player.position.y > 0
		last_catch = caught
		if not caught:
			await walk(Vector3(19,-8,-26))
			await walk(Vector3(19,2,-73))
			await walk(Vector3(0,2,-73))
		else:
			await walk(level.finish_position)
	var result := {"shortcut":shortcut,"hold":hold_ticks,"crossed":crossed,"finish":level.is_finish_at(player.position),"checkpoints":reached.duplicate(),"descending_catch":last_catch,"ticks":tape.size(),"crossing_ticks":crossing_ticks,"position":str(player.position),"grapples":player.grapple_count}
	if result.finish:
		var file := FileAccess.open(output.path_join("shortcut.json" if shortcut else "gallery.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(tape))
		FileAccess.open(output.path_join("shortcut-events.json" if shortcut else "gallery-events.json"),FileAccess.WRITE).store_string(JSON.stringify(event_tape(tape)))
		result["replay"] = await replay(tape)
	print(JSON.stringify(result))
	return result

func replay(commands: Array) -> Dictionary:
	await reset()
	for cmd: Dictionary in commands:
		var event := InputEventMouseMotion.new()
		event.screen_relative = Vector2(-wrapf(float(cmd.yaw)-player.yaw,-PI,PI),-(float(cmd.pitch)-player.pitch))/deg_to_rad(2.5*0.022)
		player._unhandled_input(event)
		mouse(bool(cmd.rope))
		for action: String in ["move_forward", "jump"]:
			var on: bool = bool(cmd.forward) if action == "move_forward" else bool(cmd.jump)
			if on:
				Input.action_press(action)
			else:
				Input.action_release(action)
		player._physics_process(1.0/128)
		observe_checkpoints()
	return {"checkpoints":reached.duplicate(),"finish":level.is_finish_at(player.position),"position":str(player.position),"ticks":commands.size()}

func event_tape(commands: Array) -> Array:
	var events: Array = []
	var previous := {"yaw":0.0,"pitch":0.0,"rope":false,"jump":false,"forward":false}
	var count_scale := deg_to_rad(2.5 * 0.022)
	for tick: int in commands.size():
		var cmd: Dictionary = commands[tick]
		var time := float(tick+1)/128
		var dx := -wrapf(float(cmd.yaw)-float(previous.yaw),-PI,PI)/count_scale
		var dy := -(float(cmd.pitch)-float(previous.pitch))/count_scale
		if absf(dx)+absf(dy) > 0:
			events.append({"time":time,"mouse":[dx,dy]})
		for key: String in ["rope","jump","forward"]:
			if bool(cmd[key]) != bool(previous[key]):
				if key == "rope":
					events.append({"time":time,"button":1,"pressed":cmd[key]})
					events.append({"time":time,"button":2,"pressed":cmd[key]})
				else:
					events.append({"time":time,"action":"move_forward" if key == "forward" else "jump","pressed":cmd[key]})
		previous = cmd
	return events

func run() -> void:
	for action: String in ["jump","move_forward","move_back","move_left","move_right","crouch","look_left","look_right","look_up","look_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	Engine.physics_ticks_per_second = 128
	DirAccess.make_dir_recursive_absolute(output)
	level = LEVEL.new()
	root.add_child(level)
	level.build()
	player = PLAYER.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.apply_settings(PRESETS.source_settings("server128", {}))
	await physics_frame
	var results: Array = []
	results.append(await route(false,0))
	for ticks: int in [140]:
		results.append(await route(true,ticks))
	await reset()
	tape = []
	await walk(Vector3(8,18,3))
	for tick: int in 800:
		await step(Vector3(8,player._eye().y,-10),false,false)
		if player.position.y < -7.8:
			break
	var fell := player.position.y < -7.8
	await walk(Vector3(0,-8,-80))
	await walk(Vector3(-28,-8,-80))
	await walk(Vector3(-28,18,21),2600)
	await walk(Vector3(-16,18,21))
	await walk(level.spawn.origin)
	var recovery := {"fell_to_court":fell,"returned_without_reset":player.position.distance_to(level.spawn.origin)<1.2,"ticks":tape.size(),"position":str(player.position)}
	var ok: bool = results.all(func(r: Dictionary) -> bool: return r.finish and r.replay.finish and r.descending_catch and r.position == r.replay.position and r.checkpoints.size()==3 and r.replay.checkpoints.size()==3) and results[1].ticks < results[0].ticks and recovery.fell_to_court and recovery.returned_without_reset
	var file := FileAccess.open(output.path_join("summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":ok,"routes":results,"recovery":recovery,"geometry_hash":level.geometry_hash()},"\t"))
	file.close()
	mouse(false)
	player.free()
	level.free()
	quit(0 if ok else 1)

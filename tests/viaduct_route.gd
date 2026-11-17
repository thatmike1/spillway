extends SceneTree
## real motor route probe: only view angles and input commands change after normal spawn.
const LEVEL := preload("res://scripts/maps/viaduct.gd")
const PLAYER := preload("res://scripts/movement/grapple_player.gd")
var level: Node3D
var player: CharacterBody3D
var tick := 0
var bay := 0
var attached := [false,false,false]
var output := "/tmp/r22-01-swing-flow/route"
var tape: Array = []
var samples: Array = []
var events: Array = []
var previous_hold := false
var fast_line := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--fast":
			fast_line = true
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func run() -> void:
	for action: String in ["move_forward","move_back","move_right","move_left","jump","crouch","look_left","look_right","look_down","look_up"]:
		InputMap.add_action(action)
	level = LEVEL.new()
	root.add_child(level)
	level.build()
	player = PLAYER.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.apply_settings(preload("res://scripts/r14_presets.gd").source_settings("server128",{}))
	player.apply_engine_rate()
	player.configure_tether("elastic-arc",false)
	player.reset_to(level.spawn)
	player.input_enabled = true
	await physics_frame
	for n: int in 4000:
		tick = n
		var feet := player.global_position
		if bay < 3 and not player.grapple.is_empty():
			attached[bay] = true
		if bay < 3 and feet.z < LEVEL.V_ANCHORS[bay].z-2.0 and (bay == 0 or (feet.y > (3.5 if fast_line and bay == 2 else 5.0) and (bay < 2 or feet.x < -1.0))):
			bay += 1
		var aim: Vector3 = LEVEL.V_ANCHORS[mini(bay,2)]
		# attachment persists independently of view: preview the next transfer before releasing.
		if bay < 3 and not player.grapple.is_empty() and feet.z < LEVEL.V_ANCHORS[bay].z+6.0:
			aim = LEVEL.V_ANCHORS[bay+1] if bay < 2 else level.finish_position+Vector3(0,2,0)
		var destination: Vector3 = [Vector3(8,3,-23),Vector3(0,3,-53),Vector3(-8,2,-89),Vector3(-8,2,-94)][bay]
		var delta: Vector3 = aim-player._eye() if bay < 3 else destination-player._eye()
		var desired_yaw := atan2(-delta.x,-delta.z)
		var desired_pitch := asin(delta.normalized().y)
		var gain := deg_to_rad(float(player.settings.sensitivity)*float(player.settings.m_yaw))
		var motion := InputEventMouseMotion.new()
		motion.screen_relative = Vector2(wrapf(player.yaw-desired_yaw,-PI,PI),player.pitch-desired_pitch)/gain
		player._unhandled_input(motion)
		events.append({"time":float(n)/128,"mouse":[motion.screen_relative.x,motion.screen_relative.y]})
		var wish := (destination-feet)*Vector3(1,0,1)
		wish = wish.normalized()
		var forward := Vector3(-sin(player.yaw),0,-cos(player.yaw))
		var right := Vector3(cos(player.yaw),0,-sin(player.yaw))
		var f := clampf(wish.dot(forward),-1.0,1.0)
		var s := clampf(wish.dot(right),-1.0,1.0)
		var hold: bool = bay < 3
		# one released tick between bays lets the production fresh-press guard rearm.
		if bay > 0 and not player.grapple.is_empty() and player.grapple.position != LEVEL.V_ANCHORS[mini(bay,2)]:
			hold = false
		for pair: Array in [["move_forward",maxf(f,0)],["move_back",maxf(-f,0)],["move_right",maxf(s,0)],["move_left",maxf(-s,0)]]:
			events.append({"time":float(n)/128,"action":pair[0],"pressed":pair[1]>0.001,"strength":pair[1]})
			if pair[1] > 0.001:
				Input.action_press(pair[0],pair[1])
			else:
				Input.action_release(pair[0])
		Input.action_press("jump")
		events.append({"time":float(n)/128,"action":"jump","pressed":true})
		if n == 0:
			var reel := InputEventMouseButton.new()
			reel.button_index = MOUSE_BUTTON_RIGHT
			reel.pressed = true
			Input.parse_input_event(reel)
			events.append({"time":0,"button":2,"pressed":true})
		if hold != previous_hold:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.pressed = hold
			Input.parse_input_event(mouse)
			player._unhandled_input(mouse)
			events.append({"time":float(n)/128,"button":1,"pressed":hold})
		previous_hold = hold
		tape.append([player.yaw,player.pitch,f,s,hold])
		player._physics_process(1.0/128)
		if n % 32 == 0:
			samples.append({"tick":n,"feet":player.global_position,"bay":bay,"attached":not player.grapple.is_empty(),"speed":player.velocity.length(),"eye":player._eye(),"yaw":player.yaw,"pitch":player.pitch})
		if level.is_finish_at(player.global_position) or player.global_position.y < -10:
			break
		await physics_frame
	var ok: bool = level.is_finish_at(player.global_position) and attached.all(func(v: bool) -> bool: return v)
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("route.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":ok,"line":"fast" if fast_line else "basic","ticks":tick+1,"attached":attached,"feet":player.global_position,"samples":samples,"tape":tape},"\t"))
	file.close()
	file = FileAccess.open(output.path_join("input.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(events))
	file.close()
	print("VIADUCT ",ok," tick=",tick," feet=",player.global_position," attached=",attached)
	player.free()
	level.free()
	quit(0 if ok else 1)

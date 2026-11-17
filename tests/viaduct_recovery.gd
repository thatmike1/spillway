extends SceneTree
## walk off normal spawn and return by the connected court and ramp, without resetting.
const LEVEL := preload("res://scripts/maps/viaduct.gd")
const PLAYER := preload("res://scripts/movement/grapple_player.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	for action: String in ["move_forward","move_back","move_right","move_left","jump","crouch","look_left","look_right","look_down","look_up"]:
		InputMap.add_action(action)
	var level := LEVEL.new()
	root.add_child(level)
	level.build()
	var player := PLAYER.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.apply_settings(preload("res://scripts/r14_presets.gd").source_settings("server128",{}))
	player.apply_engine_rate()
	player.configure_tether("elastic-arc",false)
	player.reset_to(level.spawn)
	player.input_enabled = true
	var phase := 0
	var targets := [Vector3(-12,-5,12),Vector3(-12,-5,39),Vector3(10,-5,42),Vector3(10,4,14),Vector3(0,4,12)]
	var touched_court := false
	await physics_frame
	for tick: int in 4000:
		var feet := player.global_position
		touched_court = touched_court or (feet.y < -4.9 and player.state.grounded)
		var destination: Vector3 = targets[phase]
		if Vector2(feet.x-destination.x,feet.z-destination.z).length() < 0.6 and absf(feet.y-destination.y) < 0.3:
			phase += 1
			if phase == targets.size():
				break
			destination = targets[phase]
		var direction := destination-feet
		player.yaw = atan2(-direction.x,-direction.z)
		Input.action_press("move_forward")
		player._physics_process(1.0/128)
		await physics_frame
	var ok := phase == targets.size() and touched_court and player.global_position.y > 3.9
	print("VIADUCT RECOVERY ",ok," phase=",phase," feet=",player.global_position," court=",touched_court)
	quit(0 if ok else 1)

extends SceneTree
## labelled low-court fixtures: walk every ramp through its actual supported clearance.
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
	player.input_enabled = true
	var all_ok := true
	for bay: int in 4:
		var d: Array = LEVEL.V_DECKS[bay]
		var h: float = LEVEL.V_HEIGHTS[bay]
		var x: float = d[1]+3
		var high_z: float = d[3]-4
		var low_z := high_z+28
		Input.action_release("move_forward")
		# fixture placement only; each walk has no reset or position correction after this start.
		player.reset_to(Transform3D(Basis.IDENTITY,Vector3(x,-4.96,low_z+1)))
		await physics_frame
		var phase := 0
		var targets := [Vector3(x,h,high_z-1),Vector3(d[1]-2,h,high_z-2)]
		for tick: int in 1600:
			var feet := player.global_position
			var target: Vector3 = targets[phase]
			if Vector2(feet.x-target.x,feet.z-target.z).length() < 0.6 and absf(feet.y-target.y) < 0.3:
				phase += 1
				if phase == targets.size():
					break
				target = targets[phase]
			var direction := target-feet
			player.yaw = atan2(-direction.x,-direction.z)
			Input.action_press("move_forward")
			player._physics_process(1.0/128)
			await physics_frame
		var ok := phase == targets.size()
		all_ok = all_ok and ok
		print("VIADUCT RETURN ",bay," ",ok," feet=",player.global_position)
	player.free()
	level.free()
	quit(0 if all_ok else 1)

extends SceneTree
## compare earned flat-ground trajectories with rope idle, using identical F2 commands.
const COURSE := preload("res://scripts/movement/course_player.gd")
const GRAPPLE := preload("res://scripts/movement/grapple_player.gd")
const PRESETS := preload("res://scripts/r14_presets.gd")
var samples: Array = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	Engine.physics_ticks_per_second = 128
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "look_left", "look_right", "look_up", "look_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	body.position.y = -0.5
	body.add_child(shape)
	root.add_child(body)
	await physics_frame
	for script in [COURSE, GRAPPLE]:
		var player = script.new()
		player.apply_settings(PRESETS.source_settings("server128", {}))
		root.add_child(player)
		player.set_physics_process(false)
		player.set_process(false)
		player.input_enabled = true
		player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 30)))
		var tape: Array = []
		Input.action_press("jump")
		for tick in 1024:
			Input.action_release("move_forward")
			Input.action_release("move_left")
			Input.action_release("move_right")
			if tick < 32:
				Input.action_press("move_forward")
			else:
				var side := 1.0 if (tick / 64) % 2 == 0 else -1.0
				Input.action_press("move_right" if side > 0 else "move_left")
				player.yaw += -side * 0.012
			player._physics_process(1.0 / 128)
			tape.append([player.position, player.velocity, player.state.jump_count, player.state.land_count])
		samples.append(tape)
		print(script.resource_path, " jumps=", player.state.jump_count, " speed_ups=", Vector2(player.velocity.x, player.velocity.z).length() / player.U)
		player.free()
	var exact: bool = samples[0] == samples[1] and samples[0][-1][2] > 8
	print("GANTRY_F2_PARITY exact=", exact, " compared_ticks=1024")
	quit(0 if exact else 1)

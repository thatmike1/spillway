extends "res://tests/test_spec_ground.gd"

func _run() -> void:
	MAIN.bind_inputs()
	await fresh()
	player._update_rig(.016, true)
	check(absf(player.get_camera().fov - 54.53644224813771) < .1, "85 horizontal converts to about 54.54 vertical")
	check(player.get_camera().keep_aspect == Camera3D.KEEP_HEIGHT, "ultrawide preserves vertical FOV")
	check(not player.speed_fov and not player.assists_enabled, "spec baseline disables added FOV and general assists")
	player.look(.5, 0)
	player._update_rig(.016, false)
	check(player.get_camera().global_basis.z.dot(player.global_basis.z) > .999, "view yaw responds immediately")
	check(player.get_body_basis().z.dot(player.global_basis.z) < .99, "lower body yaw trails immediate view")
	var collision: Vector3 = player.position
	player.look(0, deg_to_rad(-70))
	for i: int in 20:
		player._update_rig(.016, false)
	check(player._neck.x > .15 and player._neck.y > .05, "look down uses recovered swan-neck translation")
	check(player.position == collision, "swan neck leaves collision body still")
	await fresh()
	player.move = player.Move.WALLRUN
	player._wall_side = -1
	for i: int in 200:
		player._update_rig(.016, false)
	check(absf(rad_to_deg(player._roll) - 17.814) < .01, "left wall bank +17.814")
	player._wall_side = 1
	for i: int in 200:
		player._update_rig(.016, false)
	check(absf(rad_to_deg(player._roll) + 23) < .01, "right wall bank -23")
	player.bank_amount = 0
	for i: int in 200:
		player._update_rig(.016, false)
	check(absf(player._roll) < .001, "comfort bank zero removes extra tilt")
	player.move = player.Move.VAULT
	player.vault.time = .30
	player.vault.duration = .65
	player._climb_hand = player.get_camera().global_position + player.global_basis * Vector3(0, -.3, -.5)
	var left: Vector3 = player.get_hand_target(-1)
	check(absf(left.distance_to(player._climb_hand) - .18) < .001, "hand target belongs to actual world contact")
	player._climb_hand += Vector3.RIGHT
	check(absf(player.get_hand_target(-1).distance_to(left) - 1) < .001, "moving contact moves hand target exactly")
	print("spec camera: %d/%d checks passed" % [checks - failures, checks])
	player.move = player.Move.GROUND
	fixture.queue_free()
	quit(1 if failures else 0)

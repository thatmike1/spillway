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
	check(absf(rad_to_deg(player._roll) + 17.814) < .01, "left source +17.814 maps to Godot negative roll")
	check(player.get_camera().global_basis.x.dot(player.up_direction) < -.25, "left ear rises away from the left wall")
	player._wall_side = 1
	for i: int in 200:
		player._update_rig(.016, false)
	check(absf(rad_to_deg(player._roll) - 23) < .01, "right source -23 maps to Godot positive roll")
	check(player.get_camera().global_basis.x.dot(player.up_direction) > .35, "right ear rises away from the right wall")
	player.bank_amount = 0
	for i: int in 200:
		player._update_rig(.016, false)
	check(absf(player._roll) < .001, "comfort bank zero removes extra tilt")
	player.move = player.Move.VAULT
	player.vault.time = .30
	player.vault.duration = .65
	player._climb_hand = player.get_camera().global_position + player.global_basis * Vector3(0, -.3, -.5)
	var left: Vector3 = player.get_hand_target(-1)
	check(absf((left - player._climb_hand).slide(player.up_direction).length() - .36) < .001, "hand target belongs to actual world contact")
	player._climb_hand += Vector3.RIGHT
	check(absf(player.get_hand_target(-1).distance_to(left) - 1) < .001, "moving contact moves hand target exactly")
	player.move = player.Move.GROUND
	player._dip = -.3
	player._dip_velocity = 2
	for i: int in 40:
		player._update_rig(.1, false)
	check(absf(player._dip) < .001 and absf(player._dip_velocity) < .001, "eye springs settle through 100ms frames")
	await fresh()
	player.move = player.Move.ROLL
	player._eye_height = .18
	player._curr_eye = player.position + Vector3.UP * .18
	player._prev_eye = player._curr_eye
	var clearance: float = 100
	for i: int in 128:
		player.landing.time = i / 127.0 * player.tuning.roll_duration
		player._update_rig(.01, true)
		clearance = minf(clearance, player.get_camera().global_position.y)
	check(clearance > .35, "dense roll eye stays above the floor: %.3fm" % clearance)
	player.move = player.Move.GROUND
	player._camera_turn_target = 6 * player.tuning.turn_lag_multiplier * player.tuning.turn_lag_projection
	for i: int in 20:
		player._update_rig(.016, false)
	check(absf(rad_to_deg(player._roll)) > 2 and absf(rad_to_deg(player._roll)) < 7, "fast angular-rate flick has small visible roll")
	await fresh()
	player.landing.impact = 6.3
	player._landing_elapsed = .16
	player._update_rig(.016, true)
	var compression: float = player.position.y + player.tuning.standing_eye - player.get_camera().global_position.y
	check(compression > .055 and compression < .07, "ordinary landing has a visible impact-scaled eye dip")
	player._landing_elapsed = .33
	player._update_rig(.016, true)
	check(absf(player.get_camera().global_position.y - player.position.y - player.tuning.standing_eye) < .001, "ordinary eye recovers in .32 seconds")
	check(player._resolve_eye(player.position - Vector3.UP * 2).y > .1, "final eye resolves against solid floor")
	print("spec camera: %d/%d checks passed" % [checks - failures, checks])
	player.move = player.Move.GROUND
	fixture.queue_free()
	quit(1 if failures else 0)

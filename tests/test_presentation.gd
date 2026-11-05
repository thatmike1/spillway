extends "res://tests/test_spec_moves.gd"
## continuity uses swept travel while precise controllers own displacement.
var audio: Node
var arms: Node

func _run() -> void:
	MAIN.bind_inputs()
	for episode: String in ["vault", "roll", "hard"]:
		await fresh()
		audio = load("res://scripts/audio.gd").new()
		fixture.add_child(audio)
		audio.attach(player, fixture)
		arms = load("res://scripts/arms.gd").new()
		fixture.add_child(arms)
		arms.attach(player)
		Input.action_press("move_forward")
		player.velocity = Vector3(0, 0, -7.2)
		await ticks(240)
		check(player.speed_fov and player.head_bob_enabled, "presentation on by default")
		var start_distance: float = player.travel_distance
		if episode == "vault":
			var top: Vector3 = player.position + Vector3(0, .1, -1.15)
			box_at(Vector3(top.x, .5, top.z - .3), Vector3(5, 1, .6))
			await ticks(1)
			player.vault.start(player, {"top": top, "into": Vector3.FORWARD, "height": 1, "depth": .6, "onto": false}, false)
		elif episode == "roll":
			player._fall_origin = player.position.y + 3
			player._input_axis = Vector2(0, -1)
			player._crouch_age = .1
			player.landing.start(player, 11)
		else:
			player._fall_origin = player.position.y + 6
			player.landing.start(player, 14)
		var state: int = player.move
		var continuous: bool = true
		var view_forward: bool = true
		var coiled: bool = true
		var last_distance: float = player.travel_distance
		for i: int in 260:
			await ticks(1)
			player._update_rig(1.0 / 120, false)
			arms._process(1.0 / 120)
			view_forward = view_forward and (-player.get_camera().global_basis.z).dot(-player.global_basis.z) > .35
			if episode != "hard":
				continuous = continuous and player._fov_extra > 1 and player.sprint_effect > .2 and audio._wind_level > .5 and player.travel_distance > last_distance
			else:
				coiled = coiled and not arms._lower.visible
			last_distance = player.travel_distance
			if player.move != state:
				break
		if episode == "hard":
			check(coiled, "hard landing keeps coiled lower body below view")
		check(view_forward, "%s camera never rotates outside/behind runner" % episode)
		if episode != "hard":
			check(continuous, "%s FOV/streak/wind/gait advance continuously during swept travel" % episode)
			check(player.travel_distance > start_distance + 2, "%s arm cadence advances with actual distance" % episode)
		for i: int in range(1, 11):
			await ticks(1)
			player._update_rig(1.0 / 120, false)
			arms._process(1.0 / 120)
			if i in [1, 2, 10]:
				check((-player.get_camera().global_basis.z).dot(-player.global_basis.z) > .35, "%s view remains forward +%d" % [episode, i])
				if episode != "vault":
					check(not arms._lower.visible, "%s recovery keeps lower body below view +%d" % [episode, i])
		# the full cycle must contain both signs, avoiding the old repeating half-wave.
		player.move = player.Move.GROUND
		player.grounded = true
		player._stride = player.tuning.gait_stride * .25
		for i: int in 100:
			arms._process(1.0 / 120)
		var first: float = arms._arms[0].wrist.z - arms._arms[1].wrist.z
		player._stride = player.tuning.gait_stride * .75
		for i: int in 100:
			arms._process(1.0 / 120)
		var second: float = arms._arms[0].wrist.z - arms._arms[1].wrist.z
		check(first * second < 0, "actual arm poses alternate across full displacement gait")
		audio.stop_all()
	# comfort reduces the composed motion and effect intensity through one setting.
	player.comfort_enabled = true
	player.displacement_velocity = Vector3(0, 0, -7.2)
	player._update_rig(.1, true)
	check(player._fov_extra <= 1.251, "single comfort option reduces speed FOV")
	var streaks = load("res://scripts/streaks.gd").new()
	streaks.player = player
	fixture.add_child(streaks)
	player.sprint_effect = 1
	streaks._process(0)
	var comfortable: float = streaks.strength
	player.comfort_enabled = false
	streaks._process(0)
	check(comfortable < streaks.strength / 3, "same comfort option reduces actual streak drawing")
	print("presentation: %d/%d checks passed" % [checks - failures, checks])
	fixture.queue_free()
	quit(1 if failures else 0)

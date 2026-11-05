extends "res://tests/test_spec_moves.gd"
## footage-first acceptance: real collision, inside ownership and release +1/+2/+10.
var rows: FileAccess

func row(label: String, frame: int, previous: Vector3) -> void:
	var motion: Vector3 = (player.position - previous) * 120
	rows.store_line("%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f" % [label, frame, player.move, player.position.y, player.position.z, player.get_speed(), motion.slide(player.up_direction).length(), player.landing.height, player.displacement_velocity.slide(player.up_direction).length()])

func _run() -> void:
	MAIN.bind_inputs()
	DirAccess.make_dir_recursive_absolute(out)
	rows = FileAccess.open(out.path_join("feel-handoffs.csv"), FileAccess.WRITE)
	rows.store_line("case,frame,state,y,z,velocity_speed,displacement_speed,fall_height,presentation_speed")
	for drop: float in [0.0, 1.0, 3.0]:
		for held: bool in [false, true]:
			await ordinary(drop, held)
	await hard_drop()
	await low_vault(false)
	await low_vault(true)
	await roll_exit(false)
	await roll_exit(true)
	await sprint_turn()
	await grab_required()
	rows.close()
	print("feel: %d/%d checks passed; CSV %s/feel-handoffs.csv" % [checks - failures, checks, out])
	fixture.queue_free()
	quit(1 if failures else 0)

func ordinary(drop: float, held: bool) -> void:
	await fresh()
	if drop > 0:
		box_at(Vector3(0, drop / 2, 5), Vector3(30, drop, 10))
	player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, drop + .9, 3)))
	await ticks(5)
	player.velocity = Vector3(0, 0, -7.2)
	Input.action_press("move_forward")
	player.queue_jump()
	await ticks(1)
	if not held:
		Input.action_release("move_forward")
	var origin: Vector3 = player.position
	var max_y: float = origin.y
	var airtime: float = 0
	var previous: Vector3 = player.position
	var air_bound_ok: bool = true
	for i: int in 240:
		await ticks(1)
		airtime += 1.0 / 120
		max_y = maxf(max_y, player.position.y)
		air_bound_ok = air_bound_ok and player.get_speed() <= 8.2 + 1.536 * airtime + .02
		row("jump%d_%s" % [int(drop), held], i, previous)
		previous = player.position
		if not player._jump_flight and airtime > .1:
			break
	if drop == 0:
		check(airtime >= .70 and airtime <= .90 and max_y - drop - .9 >= .9 and max_y - drop - .9 <= 1.4, "flat jump %s: %.4fs / %.4fm" % [held, airtime, max_y - .9])
	check(player.landing.kind == "normal", "jump down %.0fm W=%s is ordinary (height %.3f)" % [drop, held, player.landing.height])
	check(absf(player.landing.height - drop) < .03, "classification uses support drop, not apex")
	check(air_bound_ok, "air speed stays inside launch plus control allowance")
	var exit: float = player.last_landing_speed
	check(exit >= 7.2 - .65 - .02, "ordinary exit %.4f >= 6.55 W=%s" % [exit, held])
	var rises: bool = false
	for frame: int in range(1, 11):
		await ticks(1)
		row("ordinary_exit%d_%s" % [int(drop), held], frame, previous)
		previous = player.position
		if frame <= 2 and player.get_speed() > exit + .01:
			rises = true
		if frame in [1, 2, 10]:
			check(player.get_speed() > .1, "ordinary +%d retains motion" % frame)
	check(rises, "ordinary W=%s speed rises within two frames" % held)

func hard_drop() -> void:
	await fresh()
	player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 6.9, 0)))
	for i: int in 180:
		await ticks(1)
		if player.move == player.Move.LANDING:
			break
	check(player.landing.kind == "hard" and player.landing.height >= 5.3, "6m real fall is hard")
	for i: int in 240:
		var previous: Vector3 = player.position
		await ticks(1)
		row("hard_inside", i, previous)
		if player.move != player.Move.LANDING:
			break
	for i: int in range(1, 11):
		var previous: Vector3 = player.position
		await ticks(1)
		row("hard_after", i, previous)
		if i in [1, 2, 10]:
			check(player.move != player.Move.LANDING, "hard released +%d" % i)

func low_vault(held: bool) -> void:
	await fresh()
	box_at(Vector3(0, .5, -7), Vector3(5, 1, .6))
	player.velocity = Vector3(0, 0, -7.2)
	Input.action_press("move_forward")
	var previous: Vector3 = player.position
	for i: int in 140:
		previous = player.position
		await ticks(1)
		if player.move == player.Move.VAULT:
			break
	check(player.move == player.Move.VAULT, "sprint selects low vault")
	var approach: float = player.vault.approach
	var minimum: float = INF
	var uninterrupted: bool = true
	if not held:
		Input.action_release("move_forward")
	for i: int in 100:
		var distance: float = (player.position - previous).dot(Vector3.FORWARD)
		minimum = minf(minimum, distance * 120)
		uninterrupted = uninterrupted and distance > .00001
		row("vault_%s" % held, i, previous)
		previous = player.position
		if player.move != player.Move.VAULT:
			break
		await ticks(1)
	check(uninterrupted, "low vault has forward displacement every tick W=%s" % held)
	check(minimum >= .7 * approach, "low vault min %.3f / approach %.3f >=70%%" % [minimum, approach])
	check(player.get_speed() >= .95 * approach, "low vault already recovered >=95%% at release")
	for i: int in range(1, 11):
		await ticks(1)
		row("vault_after_%s" % held, i, previous)
		previous = player.position
		if i in [1, 2, 10]:
			check(player.get_speed() > .1, "vault W=%s +%d retains motion" % [held, i])

func roll_exit(held: bool) -> void:
	await fresh()
	player.velocity = Vector3(0, 0, -7.2)
	player._fall_origin = player.position.y + 3
	player._input_axis = Vector2(0, -1)
	player._crouch_age = .1
	player.landing.start(player, 11)
	if held:
		Input.action_press("move_forward")
	var start: Vector3 = player.position
	var previous: Vector3 = start
	var last_motion: float = 0
	for i: int in 100:
		await ticks(1)
		last_motion = player.position.distance_to(previous) * 120
		row("roll_%s" % held, i, previous)
		previous = player.position
		if player.move != player.Move.ROLL:
			break
	check(absf(player.position.distance_to(start) - 3.13517) < .005, "active roll keeps measured root distance")
	check(last_motion > .1 and absf(player.get_speed() - last_motion) < .01, "roll release %.4f matches last motion %.4f" % [player.get_speed(), last_motion])
	for i: int in range(1, 11):
		await ticks(1)
		row("roll_after_%s" % held, i, previous)
		previous = player.position
		if i in [1, 2, 10]:
			check(player.get_speed() > .1, "roll W=%s +%d never dips to zero" % [held, i])

func sprint_turn() -> void:
	await fresh()
	Input.action_press("move_forward")
	var cue_time: float = -1
	for i: int in 1200:
		await ticks(1)
		if cue_time < 0 and player.sprint_effect >= .35:
			cue_time = float(i + 1) / 120
	var straight: float = player.get_speed()
	check(cue_time >= 1.8 and cue_time <= 2.6, "visible streak envelope reached at %.4fs" % cue_time)
	await fresh()
	Input.action_press("move_forward")
	for i: int in 1200:
		player.look(deg_to_rad(30) / 120, 0)
		await ticks(1)
	check(player.get_speed() >= straight * .9, "30deg/s turn %.4f >=90%% of straight %.4f" % [player.get_speed(), straight])

func grab_required() -> void:
	await fresh()
	box_at(Vector3(0, 1.4, -7), Vector3(10, 2.8, 8))
	player.velocity = Vector3(0, 0, -7.2)
	Input.action_press("move_forward")
	player.queue_jump()
	var grabbed: bool = false
	var stood_without_grab: bool = false
	for i: int in 400:
		await ticks(1)
		grabbed = grabbed or player.move == player.Move.GRAB
		stood_without_grab = stood_without_grab or (player.position.y >= 3.69 and player.grounded and not grabbed)
	check(grabbed and not stood_without_grab, "2.8m ledge requires grab, cannot ballistic standing-jump onto it")

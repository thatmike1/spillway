extends "res://tests/test_spec_ground.gd"
## contract traces include actual collision geometry plus isolated transitions.

func box_at(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = center
	body.add_child(shape)
	fixture.add_child(body)
	return body

func record_ticks(name: String, count: int) -> void:
	trace(name)
	for i: int in count:
		await physics_frame
		sample(float(i + 1) / 120)
	csv.close()

func _run() -> void:
	MAIN.bind_inputs()
	DirAccess.make_dir_recursive_absolute(out)
	await _vaults()
	await _landings()
	await _ledges()
	await _walls()
	await _slide_turn()
	await _steps_spring()
	await _platform()
	print("spec moves: %d/%d checks passed" % [checks - failures, checks])
	fixture.queue_free()
	quit(1 if failures else 0)

func _vaults() -> void:
	await fresh()
	box_at(Vector3(0, .5, -7), Vector3(5, 1, .6))
	await ticks(2)
	Input.action_press("move_forward")
	var entered: bool = false
	for i: int in 240:
		await physics_frame
		if player.move == player.Move.VAULT:
			entered = true
			break
	check(entered, "geometry selects fast vault")
	check(player.vault.variant == "fast_over", "thin obstacle selects over variant")
	var saved: float = player.vault.saved_speed
	check(saved >= 4 and saved <= 7.2, "low vault saved speed %.4f in [4,7.2]" % saved)
	check(absf(player.vault.duration - .65) < .001, "fast vault duration .35 + .30")
	Input.action_release("move_forward")
	await record_ticks("vault_fast", 80)
	check(player.position.z < -7.6, "swept fast vault clears the obstacle")
	check(absf(player.vault.exit_velocity.length() - saved) < .001, "exit speed comes from final stage displacement/time")
	await fresh()
	box_at(Vector3(0, .85, -3), Vector3(5, 1.7, .5))
	await ticks(2)
	player.velocity = Vector3(0, 2, -7)
	var edge: Dictionary = {"top": Vector3(0, 1.7, -2.75), "into": Vector3.FORWARD, "height": 1.7, "depth": .5, "onto": false}
	player.vault.start(player, edge, true)
	check(player.vault.saved_speed == 4, "high vault caps saved speed at 4")
	check(absf(player.vault.duration - 1.03) < .001, "high vault has separate .28/.30/.45 stages")
	await record_ticks("vault_high", 126)
	check(player.position.z < -3.5, "high vault sweeps over real geometry")
	# blocked path aborts instead of teleporting through the ceiling.
	await fresh()
	box_at(Vector3(0, 2.6, -1), Vector3(6, .3, 6))
	await ticks(2)
	player.velocity = Vector3(0, 0, -5)
	player.vault.start(player, edge, true)
	await ticks(80)
	check(player.position.y < 1.7, "blocked vault aborts at collision")

func _landings() -> void:
	await fresh()
	player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 6.9, 0)))
	player._fall_origin = 6.9
	await record_ticks("hard_landing", 175)
	check(player.landing.kind == "hard", "6m drop selects hard by fall origin")
	check(player.velocity.length() < .001, "hard landing clears velocity")
	await fresh()
	player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 4.9, 0)))
	player._fall_origin = 4.9
	Input.action_press("move_forward")
	var pressed: bool = false
	for i: int in 160:
		await physics_frame
		if player.position.y < 1.7 and not pressed:
			Input.action_press("crouch")
			pressed = true
		if player.move == player.Move.ROLL:
			break
	check(player.landing.kind == "roll", "fresh crouch inside .2s selects roll on >2m drop")
	var start: Vector3 = player.position
	Input.action_release("move_forward")
	await record_ticks("roll", 152)
	check(absf(player.position.distance_to(start) - 3.13517) < .08, "roll travels %.4fm vs 3.13517 ± .08m" % player.position.distance_to(start))
	await fresh()
	player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 4.9, 0)))
	Input.action_press("move_forward")
	Input.action_press("crouch")
	await ticks(180)
	check(player.landing.kind == "normal", "held crouch does not refresh roll eligibility")
	await fresh()
	player._fall_origin = player.position.y + 2
	player._crouch_age = .1
	player._input_axis = Vector2(0, -1)
	player.landing.start(player, 6)
	check(player.landing.kind == "normal", "exactly 2m does not pass strict roll-height gate")
	player._fall_origin = player.position.y + 6
	player.landing.start(player, 10, true)
	check(player.landing.kind == "soft", "soft object bypasses hard response")

func _ledges() -> void:
	await fresh()
	box_at(Vector3(0, 1.4, -3), Vector3(6, 2.8, 6))
	player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 1)))
	await ticks(2)
	var edge: Dictionary = player.detect_edge(2, 3.4)
	check(not edge.is_empty(), "ledge detector finds actual top")
	if edge.is_empty():
		return
	player.velocity = Vector3(0, -1, -6)
	player.ledge.start(player, edge)
	await record_ticks("grab", 45)
	check(player.velocity.length() == 0 and player.ledge.phase == "hang", "grab alignment ends with zero momentum")
	player.ledge.pull(player)
	await record_ticks("pullup", 190)
	check(player.position.y > 3.65 and player.position.z < 0, "pull-up clears ledge and stands on roof %s" % player.position)

func _walls() -> void:
	await fresh()
	box_at(Vector3(-.7, 5, -15), Vector3(.4, 10, 60))
	player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 3, 0)))
	player.velocity = Vector3(0, 1, -6)
	player._jump_origin = player.position
	Input.action_press("move_forward")
	player.wall.start(player, Vector3.RIGHT, -1)
	check(absf(player.velocity.y - 5.28015) < .001, "fresh wall entry vertical 5.28015")
	await record_ticks("wallrun", 198)
	check(player.wall.time > 1.60 and player.wall.time < 1.68, "wall run ends through -5m/s at %.4fs" % player.wall.time)
	check(player.move != player.Move.WALLRUN, "wall run exits by vertical threshold")
	await fresh()
	player.velocity = Vector3(0, 3, -6)
	player.wall.normal = Vector3.RIGHT
	player.wall.consecutive = 0
	player.wall.jump(player)
	var fresh_v: float = player.velocity.y
	check(absf(fresh_v - 5.65685) < .001, "wall jump d=0 uses doubled-height equation")
	check(absf(player.velocity.x - 1.2) < .001 and absf(player.velocity.z + 6) < .001, "wall jump retains tangent and adds outward push")
	player.wall.consecutive = 1
	player.wall.jump(player)
	check(absf(player.velocity.y * 2 - fresh_v) < .001, "consecutive wall jump halves boost")
	player.wall.consecutive = 0
	player.look(-PI / 2, 0)
	player.wall.jump(player)
	check(absf(player.velocity.x - 5.2) < .01 and absf(player.velocity.y - 7.15542) < .01, "turned wall jump d=1 gets 5.2 outward and 7.15542 vertical")
	await fresh()
	box_at(Vector3(0, 5, -1), Vector3(10, 10, .4))
	player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 2, 0)))
	player.velocity = Vector3(0, 3.2, -6.5)
	player.wall.start_vertical(player, Vector3.BACK)
	check(absf(player.velocity.y - sqrt(4 * 1.9 * 8)) < .001, "vertical climb converts horizontal/upward budgets")
	Input.action_press("move_forward")
	await record_ticks("wallclimb", 20)
	check(player.position.y > 3, "vertical controller rises along real wall")

func _slide_turn() -> void:
	await fresh()
	player.velocity = Vector3(0, 0, -6)
	player.slide.start(player, player.velocity)
	Input.action_press("crouch")
	await ticks(40)
	Input.action_release("crouch")
	await ticks(10)
	check(player.move == player.Move.SLIDE, "slide holds .5s entry lock")
	var before: float = player.get_speed()
	player.slide.finish(player)
	check(absf(player.get_speed() - before * .5) < .001, "slide exit halves velocity")
	await fresh()
	box_at(Vector3(0, 1.5, 0), Vector3(5, .3, 8))
	player._set_low(true, false)
	check(not player._can_stand(), "crouch clearance rejects overhead slab")
	player._set_low(false, false)
	check(is_equal_approx(player.get_node("CollisionShape3D").shape.height, 1.22), "failed stand keeps 1.22m collision")
	await fresh()
	player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
	player.velocity = Vector3(0, 1, -5)
	player.grounded = false
	player.turn.start(player)
	await record_ticks("air_turn", 72)
	check((-player.global_basis.z).dot(Vector3.BACK) > .999, "air turn rotates authored 180 degrees in .6s")
	check(absf(player.velocity.z + 5) < .001, "air turn retains translation")

func _steps_spring() -> void:
	await fresh()
	box_at(Vector3(0, .125, -3), Vector3(5, .25, 1))
	Input.action_press("move_forward")
	var max_y: float = .9
	for i: int in 130:
		await physics_frame
		max_y = maxf(max_y, player.position.y)
	check(max_y > 1.1 and player.position.z < -3.7, "ordinary .25m step sweeps up and forward (max_y %.3f, end %s)" % [max_y, player.position])
	await fresh()
	box_at(Vector3(0, .44, -2), Vector3(5, .88, 2))
	await ticks(2)
	var edge: Dictionary = {"top": Vector3(0, .88, -1), "into": Vector3.FORWARD, "height": .88}
	player.step_up.start(player, edge)
	await record_ticks("step_up", 85)
	check(player.position.y > 1.7 and player.position.z < -1, "special .88m step uses swept body profile")
	await fresh()
	box_at(Vector3(0, .32, -2), Vector3(5, .64, .5))
	box_at(Vector3(0, .6, -3.12), Vector3(5, 1.2, .5))
	player.velocity = Vector3(0, 0, -6.3)
	check(player.try_springboard(), "springboard detects paired .64/1.2m footplants")
	var started: bool = player.move == player.Move.SPRINGBOARD
	for i: int in 160:
		await physics_frame
		if player.move == player.Move.AIR:
			break
	check(started and absf(player.velocity.y - 9.5) < .001 and absf(player.get_speed() - 5.3) < .001, "springboard launches 9.5 vertical, saved 6.3 minus 1 horizontal")
	await record_ticks("springboard_flight", 145)

func _platform() -> void:
	await fresh()
	var platform := AnimatableBody3D.new()
	platform.sync_to_physics = false
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 1, 10)
	collider.shape = shape
	platform.add_child(collider)
	platform.position = Vector3(0, 1, 0)
	fixture.add_child(platform)
	player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 2.4, 0)))
	for i: int in 30:
		platform.position.x += 2.0 / 120
		await physics_frame
	player.queue_jump()
	platform.position.x += 2.0 / 120
	await ticks(1)
	check(player.velocity.x > 1.8 and player.velocity.x < 2.2, "platform departure adds 2m/s exactly once (%.3f)" % player.velocity.x)

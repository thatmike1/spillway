extends SceneTree
## actual-level input fixtures for admission, edge guarding and optional roof access.
## reset_to supplies each documented starting pose; no episode writes velocity or yaw.
var game: Node3D
var player: CharacterBody3D
var checks := 0
var failures := 0
var label := "setup"

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, text: String) -> void:
	checks += 1
	print("%s [%s] %s" % ["PASS" if value else "FAIL", label, text])
	if not value:
		failures += 1

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func ticks(count: int) -> void:
	for i: int in count:
		await physics_frame

func aim(at: Vector3) -> void:
	var offset := at - player.global_position
	var target := atan2(-offset.x, -offset.z)
	var delta := angle_difference(float(player.get("yaw")), target)
	var event := InputEventMouseMotion.new()
	event.screen_relative = Vector2(-delta / float(player.get("mouse_sensitivity")), 0)
	event.relative = event.screen_relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func fixture(name: String, at: Vector3, yard: bool = true) -> void:
	label = name
	for key: String in ["move_forward", "move_back", "jump", "crouch"]:
		action(key, false)
	game.call("restart_run")
	if yard:
		var pose: Transform3D = game.get("level").get("checkpoints")[1].pose
		player.call("reset_to", pose)
		await ticks(3)
		check(int(game.get("checkpoint_index")) == 1, "fixture grants yard through its real admission volume")
	player.call("reset_to", Transform3D(Basis.IDENTITY, at))
	await ticks(8)

func walk(at: Vector3, limit: int = 600) -> bool:
	action("move_forward", true)
	for i: int in limit:
		aim(at)
		await ticks(1)
		if Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() < .65:
			action("move_forward", false)
			return true
	action("move_forward", false)
	return false

func approach_roof(x: float, takeoff_z: float) -> bool:
	action("move_forward", true)
	for i: int in 300:
		await ticks(1)
		if player.global_position.z <= takeoff_z:
			break
	action("jump", true)
	for i: int in 180:
		await ticks(1)
		if str(player.get("mode")) == "mantle":
			return true
		if player.global_position.y >= 2.98 and player.global_position.z < -99.5:
			return false
	return false

func roof_fixture(name: String, at: Vector3) -> void:
	await fixture(name, at)
	player.call("reset_to", game.get("level").get("checkpoints")[2].pose)
	await ticks(3)
	check(int(game.get("checkpoint_index")) == 2, "fixture grants Outflow through its real roof region")
	player.call("reset_to", Transform3D(Basis.IDENTITY, at))
	await ticks(8)

func housing_toward_tower() -> void:
	await fixture("housing turns toward tower", Vector3(-21, 1.54, -90))
	var jumps: int = player.get("jump_count")
	action("move_forward", true)
	for i: int in 300:
		await ticks(1)
		if player.global_position.z <= -93.2:
			break
	action("jump", true)
	for i: int in 90:
		await ticks(1)
		if player.global_position.y > 2.6 and player.is_on_floor():
			break
	action("jump", false)
	await walk(Vector3(-16, 2.5, -98.6), 240)
	await walk(Vector3(-6, .1, -95.3), 240)
	check(int(game.get("checkpoint_index")) == 2 and int(game.get("respawn_count")) == 0,
		"turning toward the tower from the housing admits Outflow")
	check(int(player.get("jump_count")) == jumps + 1, "housing-to-run-up line uses only its original jump")
	await fixture("roof bridge turns toward tower", Vector3(-21, 3.05, -98.9))
	jumps = player.get("jump_count")
	await walk(Vector3(-15, 2.4, -98.5), 240)
	check(int(game.get("checkpoint_index")) == 2 and int(game.get("respawn_count")) == 0,
		"walking east from the roof bridge admits Outflow")
	check(int(player.get("jump_count")) == jumps, "bridge approach needs no jump")

func finished_exploration() -> void:
	await roof_fixture("exploration preserves finished result", Vector3(24, -2.96, -63))
	await walk(Vector3(24, -3, -66.5), 200)
	check(bool(game.get("finished")), "fixture reaches the wheel through input")
	var time: float = game.get("elapsed")
	var splits: Array = game.get("splits").duplicate()
	var clean: bool = game.get("clean_eligible")
	var fell := false
	var returned := false
	action("move_forward", true)
	for i: int in 600:
		aim(Vector3(33.5, -3, -75))
		await ticks(1)
		fell = fell or player.global_position.y < -7.7
		if fell and player.global_position.y > -3.1:
			returned = true
			break
	action("move_forward", false)
	await ticks(10)
	check(fell and returned, "episode falls out of bounds and returns near the wheel")
	check(bool(game.get("finished")) and is_equal_approx(float(game.get("elapsed")), time),
		"a genuine post-finish fall retains the result and frozen clock")
	check(game.get("splits") == splits and bool(game.get("clean_eligible")) == clean and int(game.get("respawn_count")) == 0,
		"post-finish recovery does not turn the completed run into practice")
	check(not str(game.get("hud").get("finish_label").text).is_empty(), "result remains visible after exploration")

func run() -> void:
	game = load("res://scripts/spillway_main.gd").new()
	root.add_child(game)
	game.set("_persist", false)
	player = game.get("player")
	await fixture("west yard corner", Vector3(-9, 4.05, -56.5), false)
	check(await walk(Vector3(7.7, 4, -62.8)), "corner can be reached with ordinary input")
	check(await walk(Vector3(9.9, 4, -69.5)), "entry ramp continues without a reset")
	check(int(game.get("checkpoint_index")) == 1 and int(game.get("respawn_count")) == 0, "cutting the west corner still admits the yard")
	for x: float in [-14, -12.2]:
		await fixture("guarded low apron %.1f" % x, Vector3(x, 1.55, -94))
		aim(Vector3(x, 1.5, -102))
		action("move_forward", true)
		await ticks(300)
		check(player.global_position.z > -97.0 and int(game.get("checkpoint_index")) == 1, "ordinary running cannot step from the low apron onto the finale run-up")
	await fixture("guarded diagonal junction", Vector3(-14, 1.55, -90))
	await walk(Vector3(-12, 1.5, -96.2), 240)
	await walk(Vector3(-5, 0, -95), 300)
	check(player.global_position.x < -11.2 and player.global_position.y >= 1.35 and int(game.get("checkpoint_index")) == 1,
		"the east opening is guarded too; ordinary diagonal running stays on the apron: %s" % player.global_position)
	await fixture("continuous housing line", Vector3(-21, 1.54, -90))
	var jumps: int = player.get("jump_count")
	await approach_roof(-21, -93.2)
	await ticks(80)
	check(player.global_position.y >= 2.98 and player.global_position.z < -99.5 and int(game.get("checkpoint_index")) == 2, "one jump onto the housing runs smoothly onto the roof: %s mode=%s" % [player.global_position, player.get("mode")])
	check(int(player.get("jump_count")) == jumps + 1, "the former slot and curb need no second jump")
	await fixture("actual roof mantle", Vector3(-23.3, 1.54, -90))
	var caught := await approach_roof(-23.3, -96.4)
	check(caught, "held forward and jump catch the actual roof beside the housing")
	await ticks(100)
	check(player.global_position.y >= 2.98 and int(game.get("checkpoint_index")) == 2, "authored mantle lands in the Outflow admission region")
	await fixture("actual roof mantle cancellation", Vector3(-23.3, 1.54, -90))
	caught = await approach_roof(-23.3, -96.4)
	check(caught, "cancellation episode reaches a real catch")
	if caught:
		var count: int = player.get("mantle_count")
		action("move_back", true)
		await ticks(2)
		check(str(player.get("mode")) != "mantle", "backward input cancels the actual roof catch promptly")
		action("move_back", false)
		await ticks(20)
		check(int(player.get("mantle_count")) == count, "the same held jump cannot immediately recatch")
	for start: Vector3 in [Vector3(16, -2.96, -65), Vector3(32, -2.96, -64)]:
		await fixture("direct wheel approach %.0f" % start.x, start)
		var roof: Transform3D = game.get("level").get("checkpoints")[2].pose
		player.call("reset_to", roof)
		await ticks(3)
		check(int(game.get("checkpoint_index")) == 2, "fixture grants Outflow through its real roof region")
		player.call("reset_to", Transform3D(Basis.IDENTITY, start))
		await ticks(8)
		await walk(Vector3(23.8, -3, -68.8))
		check(bool(game.get("finished")), "walking directly to the wheel finishes from either side")
	await housing_toward_tower()
	await finished_exploration()
	for key: String in ["move_forward", "move_back", "jump", "crouch"]:
		action(key, false)
	print("spillway access: %d/%d checks passed; explicit authored-level fixtures, not whole-route proof" % [checks - failures, checks])
	game.call("request_quit", 1 if failures else 0)

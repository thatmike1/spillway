extends "test_spillway_access.gd"
## r12 yard bank tail, machinery house and apron edges: input-only episodes from documented
## fixture poses (reset_to); no velocity or yaw writes. they prove a way on, not a pleasant one.

const ROOF := Vector3(-26, 3, -101.5)

## hold the given keys while aiming at a point; report reach time, worst stall and speeds.
func episode(keys: Array, toward: Vector3, seconds: float, done: Callable, runup: int = 0) -> Dictionary:
	# an optional run-up on W alone reaches running speed before a hop chain starts.
	action("move_forward", true)
	for i: int in runup:
		aim(toward)
		await ticks(1)
	for key: String in keys:
		action(key, true)
	var stall := 0
	var worst := 0
	var reached := -1.0
	var speeds: Array[float] = []
	for i: int in int(seconds * 120):
		aim(toward)
		await ticks(1)
		var speed := float(player.call("get_speed"))
		speeds.append(speed)
		stall = stall + 1 if speed < .5 else 0
		worst = maxi(worst, stall)
		if done.call():
			reached = i / 120.0
			break
	for key: String in keys:
		action(key, false)
	return {"reached": reached, "stall": worst / 120.0, "speeds": speeds}

func on_roof() -> bool:
	return player.global_position.y > 2.95 and player.global_position.z < -99.2

func run() -> void:
	game = load("res://scripts/spillway_main.gd").new()
	root.add_child(game)
	game.set("_persist", false)
	player = game.get("player")
	# 1. the recorded baseline-fast-4 pin pose between the bank's tail and the inner ramp.
	await fixture("bank tail pin pose", Vector3(-23.95, 2.2, -93.8))
	var result := await episode(["move_forward"], ROOF, 3.0, on_roof)
	check(result.reached >= 0.0 and result.stall < .25, "W from the old pin pose walks onto the roof: %s stall %.2f s" % [player.global_position, result.stall])
	# 2. a walker low along the bank's foot meets the ramp head on, never a crease or corner.
	for start: Vector3 in [Vector3(-15, 1.55, -84.2), Vector3(-19, 1.55, -86.7), Vector3(-21, 1.55, -88.3)]:
		await fixture("bank foot walk %.0f" % start.x, start)
		# along the foot to its tail first, as a rider who slipped off low would run, then up.
		var tail := Vector3(-24.4, 1.5, -94.4)
		var along := await episode(["move_forward"], tail, 3.0, func() -> bool: return Vector2(player.global_position.x - tail.x, player.global_position.z - tail.z).length() < .9)
		result = await episode(["move_forward"], ROOF, 3.0, on_roof)
		check(along.reached >= 0.0 and result.reached >= 0.0 and maxf(along.stall, result.stall) < .25, "walking along the bank's foot reaches its tail and the roof without a stall: %s stall %.2f s" % [player.global_position, maxf(along.stall, result.stall)])
	# 3. held strafe into the foot while walking (W+D) still runs out onto the ramp.
	await fixture("bank foot strafe", Vector3(-19, 1.55, -86.7))
	result = await episode(["move_forward", "move_right"], ROOF, 5.0, on_roof)
	check(result.reached >= 0.0 and result.stall < .3, "W+D along the foot leaves the bank's tail for the roof: %s stall %.2f s" % [player.global_position, result.stall])
	# 4. a hop chain that misses the bank wide meets the machinery house's long side at a glance.
	await fixture("wide miss into machinery house", Vector3(-8.5, 1.55, -80.6))
	# r12 / held jump is an autohop chain here, as in play (fixture() selects buffered mode).
	player.set("autohop", true)
	var target := Vector3(-30, 1.5, -86.2)
	result = await episode(["move_forward", "jump"], target, 2.5, func() -> bool: return player.global_position.x < -24.0, 50)
	var before := 0.0
	var worst_ratio := 1.0
	var speeds: Array[float] = result.speeds
	for i: int in range(1, speeds.size()):
		before = maxf(before, speeds[i - 1])
		if speeds[i - 1] > 4.0:
			worst_ratio = minf(worst_ratio, speeds[i] / speeds[i - 1])
	check(worst_ratio > .75 and result.reached >= 0.0, "the house turns a wide hop along its side; worst single-tick retention %.2f, past it: %s" % [worst_ratio, player.global_position])
	check(int(game.get("respawn_count")) == 0, "the deflected hop stays in the yard")
	# 5. a hop drifting off the inner ramp lands on the intake grating, not out of bounds.
	await fixture("hop off the inner ramp", Vector3(-21.8, 1.55, -89.4))
	# r12 / held jump is an autohop chain here, as in play (fixture() selects buffered mode).
	player.set("autohop", true)
	result = await episode(["move_forward", "jump"], Vector3(-31, 1.5, -98), 2.5, func() -> bool: return false, 30)
	check(int(game.get("respawn_count")) == 0 and player.global_position.y > 1.3, "the slot between the roof ramps is covered: %s" % player.global_position)
	# 6. the apron's north edge is railed beside the safe route.
	await fixture("apron north edge", Vector3(-28, 1.55, -74.5))
	result = await episode(["move_forward"], Vector3(-28, 1.5, -66), 2.5, func() -> bool: return false)
	check(int(game.get("respawn_count")) == 0 and player.global_position.z < -71.9, "walking north stops at the apron's rail: %s" % player.global_position)
	for key: String in ["move_forward", "move_back", "move_right", "jump", "crouch"]:
		action(key, false)
	print("yard join: %d/%d checks passed; input-only fixtures from documented poses, not a fun claim" % [checks - failures, checks])
	game.call("request_quit", 1 if failures else 0)

extends "test_yard_join.gd"
## r12 settling basin exit: input-only episodes from the discovery review's basin positions and
## from a walked bridge miss, on to the yard's admission (stage 1). fixture poses via reset_to;
## no velocity or yaw writes. they prove a way on, not that a player finds it.

const RAMP_FRONT := Vector3(13.5, 1.5, -50.2)
const RAMP_TOP := Vector3(14, 4, -56.8)
const YARD := Vector3(10.5, 4, -66)
## the discovery review's low positions that are still open water, plus the basin's far end.
const REVIEW_WATER: Array[Vector3] = [Vector3(9.94, 1.54, -53.41), Vector3(8.88, 1.54, -51.05),
	Vector3(10.4, 1.54, -55.6), Vector3(6.65, 1.54, -49.6), Vector3(2, 1.54, -52), Vector3(-4.5, 1.54, -54.8)]

## the ramp's west side is a wall a capsule cannot step onto, so the way on is round its corner:
## north into the open water in front of its toe, east along the toe, up the ramp, into the yard.
func round_toe(from: Vector3) -> Array:
	return [Vector3(minf(from.x, 10.4), 1.5, -50.2), RAMP_FRONT, RAMP_TOP, YARD]

func in_yard() -> bool:
	return int(game.get("checkpoint_index")) == 1

## held W toward each point in turn, the last until the yard admits the runner.
func escape(name: String, points: Array) -> void:
	var total := 0.0
	var stall := 0.0
	var ok := true
	for i: int in points.size():
		var point: Vector3 = points[i]
		var done := in_yard if i == points.size() - 1 else func() -> bool:
			return Vector2(player.global_position.x - point.x, player.global_position.z - point.z).length() < .45
		var result := await episode(["move_forward"], point, 8.0, done)
		print("  leg %d to %s: reached %.2f stall %.2f at %s" % [i, point, result.reached, result.stall, player.global_position])
		ok = ok and result.reached >= 0.0
		total += result.reached if result.reached >= 0.0 else 8.0
		stall = maxf(stall, result.stall)
	check(ok and stall < .3 and int(game.get("respawn_count")) == 0,
		"%s: held W reaches the yard in %.2f s, worst stall %.2f s, at %s" % [name, total, stall, player.global_position])

func run() -> void:
	game = load("res://scripts/spillway_main.gd").new()
	root.add_child(game)
	game.set("_persist", false)
	player = game.get("player")
	# 1. the review's decision 35: on the terrace's south edge with the basin below.
	await fixture("terrace south edge drop", Vector3(15.94, 4.04, -48.0), false)
	await escape("stepping off the terrace into the basin", [RAMP_FRONT, RAMP_TOP, YARD])
	# 2. the review's open-water positions after its bridge overshoot (x 11..17 is now ramp).
	# a runner who pushes straight at the ramp's side instead is reported below, not checked.
	for start: Vector3 in REVIEW_WATER:
		await fixture("basin water %.1f %.1f" % [start.x, start.z], start, false)
		await escape("from open water at %s" % start, round_toe(start))
	# the same positions held straight at the toe: the side wall costs time, never a jump.
	for start: Vector3 in REVIEW_WATER:
		await fixture("basin water straight %.1f %.1f" % [start.x, start.z], start, false)
		var naive := await episode(["move_forward"], RAMP_FRONT, 10.0, func() -> bool: return Vector2(player.global_position.x - RAMP_FRONT.x, player.global_position.z - RAMP_FRONT.z).length() < .45)
		print("  straight at the toe's front from %s: arrived after %.2f s (-1 = not in 10 s), worst stall %.2f s, at %s" % [start, naive.reached, naive.stall, player.global_position])
	# 3. a walked bridge: no hop at the expansion joint drops the runner into the basin.
	await fixture("bridge joint miss", Vector3(4.3, 4.04, -49.4), false)
	var fell := await episode(["move_forward"], Vector3(10, 4, -56.1), 4.0, func() -> bool: return player.global_position.y < 2.0)
	check(fell.reached >= 0.0, "walking the bridge without a hop falls at the joint: %s" % player.global_position)
	await escape("after the joint miss", round_toe(player.global_position))
	# 4. a hop chain strafing right on the bridge stays on it or drops into the basin, then out.
	await fixture("bridge right drift", Vector3(4.3, 4.04, -49.4), false)
	player.set("autohop", true)
	await episode(["move_forward", "move_right", "jump"], Vector3(10, 4, -56.1), 1.6, func() -> bool: return false, 30)
	player.set("autohop", false)
	await ticks(120)
	check(int(game.get("respawn_count")) == 0, "the drifting hop stays on the bridge, ramp or basin: %s" % player.global_position)
	var on_ramp := player.global_position.x > 11.0 and player.global_position.y > 1.75
	await escape("after the right drift", [RAMP_TOP, YARD] if on_ramp else round_toe(player.global_position))
	# 5. a hop chain east along the toe's open water meets a guard on the basin's east wall, not
	# the drop outside it (the matrix's early-fast-1 hopped it before that guard reached z -49).
	for z: float in [-49.4, -50.3, -51.4]:
		await fixture("east wall hop %.1f" % z, Vector3(9, 1.54, z), false)
		player.set("autohop", true)
		await episode(["move_forward", "jump"], Vector3(22, 1.5, z - .6), 2.5, func() -> bool: return false, 20)
		player.set("autohop", false)
		await ticks(60)
		check(int(game.get("respawn_count")) == 0 and player.global_position.x < 16.75 and player.global_position.y > 1.3,
			"hopping east along the toe stays inside the basin: %s" % player.global_position)
	for key: String in ["move_forward", "move_back", "move_right", "jump", "crouch"]:
		action(key, false)
	print("basin exit: %d/%d checks passed; input-only fixtures from documented poses, not a fun claim" % [checks - failures, checks])
	game.call("request_quit", 1 if failures else 0)

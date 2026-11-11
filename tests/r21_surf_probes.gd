extends "res://tests/r21_surf_route.gd"
## controlled input departures share the production scene and the intended route's exact prefix.
var departure_tick := -1
var departure_checkpoint := -1
var departure_position := Vector3.ZERO
var lowest_y := INF
var reached_stage3 := false

func _control_source(tick: int) -> void:
	var probe := str(opts.get("probe", ""))
	assert(probe in ["turnaround", "turnaround_diagonal", "west_bail", "east_bail"])
	var west := probe == "west_bail"
	var bail := (west and node_index == 1 and player.position.z < -42) or (probe == "east_bail" and node_index == 15 and player.position.z > -126)
	if departure_tick < 0 and (bail or probe.begins_with("turnaround")):
		departure_tick = tick
		departure_checkpoint = game.checkpoint_index
		departure_position = player.position
	if departure_tick >= 0:
		if probe.begins_with("turnaround"):
			_turn_to(0)
			_want({"s": true, "space": true, "d": true} if probe.ends_with("diagonal") else {"s": true, "space": true}, tick)
		else:
			_turn_to(0 if west else PI)
			_want({"a": true}, tick)
		return
	super._control_source(tick)

func _observe(tick: int) -> void:
	lowest_y = minf(lowest_y, player.position.y)
	reached_stage3 = reached_stage3 or game.checkpoint_index >= 3
	super._observe(tick)

func _accept(summary: Dictionary) -> bool:
	var probe := str(opts.probe)
	var checkpoint: Dictionary = level.checkpoints[departure_checkpoint]
	var expected := 2 if probe == "east_bail" else 0
	var ok: bool = not summary.finished and summary.respawns == 1 and departure_tick >= 0 and departure_checkpoint == expected and game.checkpoint_index == expected
	ok = ok and lowest_y < -10 and player.position.distance_to(checkpoint.pose.origin) < 0.2 and not reached_stage3
	_write("probe.json", {"ok": ok, "probe": probe, "departure_tick": departure_tick, "departure_checkpoint": departure_checkpoint, "departure_position": plain(departure_position), "lowest_y": lowest_y,
		"respawn_checkpoint": game.checkpoint_index, "respawn_position": plain(player.position), "expected_pose": plain(checkpoint.pose.origin), "reached_stage3": reached_stage3,
		"seconds_to_respawn": float(summary.ticks - departure_tick) / hz, "limit": "controlled representative departure, not universal skip impossibility"})
	return ok

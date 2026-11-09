extends "res://tests/r19_tether_route.gd"
## release deliberately early, land on the catch court and walk the physical return ramp.
var recovery_phase := "approach"
var catch_tick := -1
var recovery_supports: Array = []
var recovered := false

func _control_source(tick: int) -> void:
	if recovery_phase == "approach":
		if node_index == 1 and not player.grapple.is_empty() and player.grapple_ticks >= 45:
			_want({}, tick)
			recovery_phase = "fall"
			return
		super._control_source(tick)
		return
	if recovery_phase == "fall":
		_want({}, tick)
		if player.is_grounded() and player.position.y < -4.5:
			catch_tick = tick
			recovery_phase = "walk"
			nodes = [{"p": Vector2(9, 38)}, {"p": Vector2(9, 34)}, {"p": Vector2(9, 10)}, {"p": Vector2(0, 10)}]
			node_index = 0
			node_from = Vector2(player.position.x, player.position.z)
		return
	if player.is_grounded():
		var support := _support(player.position)
		if not recovery_supports.has(support):
			recovery_supports.append(support)
		if support.begins_with("transfer_0") and player.position.y > 3.9 and player.position.x < 5.5:
			recovered = true
			return
	_pitch_to(0.0)
	# ordinary walking input, no grapple or jump, after the deliberate drop.
	var target: Vector2 = nodes[node_index].p if node_index < nodes.size() else Vector2(0, 10)
	var here := Vector2(player.position.x, player.position.z)
	if here.distance_to(target) < 0.7 and node_index < nodes.size():
		_next(here, tick)
		return
	_look(here, target)
	_want({"w": true}, tick)

func _route_finished(_tick: int) -> bool:
	return recovered

func _end(reason: String, tick: int) -> void:
	if not closing:
		game.session.boundary("quit", {"reason": "recovery complete"})
	super._end(reason, tick)

func _accept(summary: Dictionary) -> bool:
	summary["recovery"] = {"caught_at_tick": catch_tick, "supports": recovery_supports, "recovered": recovered}
	return recovered and catch_tick >= 0 and int(summary.respawns) == 0 and attached_ticks > 0 and pull_ticks > 0 \
		and int(summary.actual_v_mismatches) == 0 and recovery_supports.has("return_ramp_0") \
		and summary.recordings.any(func(r: Dictionary) -> bool: return bool(r.ok))

extends "res://tests/r19_surf_driver.gd"
## deliberately release the west fin, land on its catch, then walk the authored return ramp.
var recovery_phase := "surf"
var catch_at := -1
var recovered := false
var recovery_supports: Array = []

func _control_source(tick: int) -> void:
	if recovery_phase == "surf":
		if node_index == 1 and player.position.z < -25.0:
			recovery_phase = "released"
			_want({}, tick)
			return
		super._control_source(tick)
		return
	if recovery_phase == "released":
		_want({}, tick)
		if player.is_grounded() and player.position.y < -3.5:
			catch_at = tick
			recovery_phase = "return"
			nodes = [{"p": Vector2(-7, -52)}, {"p": Vector2(-7, -85)}, {"p": Vector2(-7, -96)}]
			node_index = 0
			node_from = Vector2(player.position.x, player.position.z)
		return
	if player.is_grounded():
		var piece := _support(player.position)
		if not recovery_supports.has(piece):
			recovery_supports.append(piece)
	if game.checkpoint_index == 1 and player.is_grounded() and player.position.y > 9.9 and _support(player.position).begins_with("west_landing"):
		recovered = true
		return
	# the ordinary input controller walks the catch, incline and terrace in that order.
	super._control_source(tick)

func _route_finished(_tick: int) -> bool:
	return recovered

func _end(reason: String, tick: int) -> void:
	super._end("recovered" if recovered else reason, tick)

func _accept(summary: Dictionary) -> bool:
	summary["recovery"] = {"caught_at_tick": catch_at, "supports": recovery_supports, "recovered": recovered}
	return recovered and catch_at >= 0 and int(summary.respawns) == 0 and bad_ground_ticks == 0 \
		and int(summary.actual_v_mismatches) == 0 and summary.elapsed < 40.0 \
		and recovery_supports.any(func(id: String) -> bool: return id == "return_west") \
		and (summary.recordings as Array).any(func(r: Dictionary) -> bool: return bool(r.ok))

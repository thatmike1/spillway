extends "res://tests/r19_line_drive_route.gd"
## intentional ordinary walking miss, then physical lower court and ramp recovery.
var observations: Array[Dictionary] = []
var caught := false
var lowest := INF

func _start() -> void:
	super()
	max_ticks = 6500
	nodes = [{"p": Vector2(0, -46), "fall": 1.0}, {"p": Vector2(10, -46)},
		{"p": Vector2(10, 32)}, {"p": Vector2(0, 32)}, {"p": Vector2(0, 12)}]

func _observe(tick: int) -> void:
	lowest = minf(lowest, player.position.y)
	caught = caught or (player.is_grounded() and player.position.y < 0.1)
	observations.append({"tick": tick, "p": plain(player.position), "v": plain(player.velocity),
		"grounded": player.is_grounded(), "launches": player.launch_events.size(), "node": node_index, "respawns": game.respawn_count})
	if caught and node_index >= 4 and player.is_grounded() and player.position.y >= 5.99 and player.position.z <= 16:
		_end("returned", tick+1)
	elif game.respawn_count > 0:
		_end("unexpected respawn", tick+1)

func _route_finished(_tick: int) -> bool:
	return false

func _end(reason: String, tick: int) -> void:
	if closing:
		return
	closing = true
	done = true
	_want({},tick)
	var ok: bool = reason == "returned" and caught and game.respawn_count == 0 and player.launch_events.is_empty() and lowest >= -0.02
	_write("recovery.json", {"ok": ok, "reason": reason, "seconds": float(tick)/hz, "caught": caught,
		"position": plain(player.position), "respawns": game.respawn_count, "minimum_y": lowest, "observations": observations})
	print("line drive recovery ok=", ok, " reason=", reason, " seconds=", float(tick)/hz)
	await game.request_quit(0 if ok else 1)

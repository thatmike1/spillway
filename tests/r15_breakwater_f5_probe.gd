extends "res://tests/r15_breakwater_driver.gd"
## bounded input-only controller experiment on the unchanged actual r15 main.
## position feedback chooses inputs; no claim of human or imperfect-input play.

var probe_flights: Array = []
var last_ground: Dictionary = {}
var active_flight: Dictionary = {}
var probe_variant := "chain"

func _start() -> void:
	super._start()
	probe_variant = str(opts.get("variant", "chain"))
	if replay.is_empty():
		nodes = []
		for item: Dictionary in GATE + ROWS + QUAY + [
			{"p": Vector2(-76.0, -125.0), "hop": true, "vt": 3000.0},
			{"p": Vector2(-78.5, -248.0), "hop": true, "vt": 3000.0},
			{"p": Vector2(-84.5, -256.0)},
			{"p": Vector2(-80.5, -267.0)},
		]:
			nodes.append(item.duplicate())
	max_ticks = int(replay.duration_ticks) if not replay.is_empty() else 6500

func _observe(tick: int) -> void:
	super._observe(tick)
	var p := player.global_position
	var state: Dictionary = player.call("get_motion_state")
	var sample := {"tick": tick, "p": [p.x, p.y, p.z], "v": [player.velocity.x / U, player.velocity.y / U, player.velocity.z / U],
		"speed_ups": Vector2(player.velocity.x, player.velocity.z).length() / U, "events": state.get("events", [])}
	if player.call("is_grounded"):
		sample["piece"] = _support(p)
		if not active_flight.is_empty():
			active_flight["landing"] = sample
			probe_flights.append(active_flight)
			active_flight = {}
		last_ground = sample
	elif active_flight.is_empty():
		active_flight = {"last_ground": last_ground, "first_air": sample}
	if int(game.get("respawn_count")) > 0 and replay.is_empty():
		_end("first_respawn", tick + 1)

func _route_finished(_tick: int) -> bool:
	return replay.is_empty() and finish_tick >= 0

func _end(reason: String, tick: int) -> void:
	var additional := {"variant": probe_variant, "actual_physics": game.call("physics_fingerprint"), "actual_stage_times": game.get("stage_times"),
		"rate_ok": game.get("rate_ok"), "clean_eligible": game.get("clean_eligible"), "probe_flights": probe_flights,
		"pending_flight": active_flight, "probe_sha256": FileAccess.get_sha256("res://tests/r15_breakwater_f5_probe.gd")}
	super._end(reason, tick)
	_write("probe.json", additional)

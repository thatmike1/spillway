extends SceneTree
## swept hit, obstruction, duplicate delivery, timeout, cancel and steering contracts.
const FLIGHT := preload("res://scripts/mail/flight.gd")
func _initialize() -> void:
	var boxes := [{"id": "one", "bounds": AABB(Vector3(-1, -1, -4), Vector3(2, 2, 1))}]
	var empty := func(_a: Vector3, _b: Vector3) -> Dictionary: return {}
	var blocked := func(_a: Vector3, _b: Vector3) -> Dictionary: return {"position": Vector3(0, 0, -1)}
	var flight := FLIGHT.new()
	assert(flight.launch(Vector3.ZERO, Vector3.FORWARD))
	assert(not flight.launch(Vector3.ZERO, Vector3.FORWARD))
	flight.step(0.25, boxes, empty)
	assert(flight.result == "hit" and flight.delivered.size() == 1)
	flight.launch(Vector3.ZERO, Vector3.FORWARD)
	flight.step(0.25, boxes, empty)
	assert(flight.active and flight.delivered.size() == 1)
	flight.end("cancel")
	assert(flight.misses == 1)
	flight.clear()
	flight.launch(Vector3.ZERO, Vector3.FORWARD)
	flight.step(0.25, boxes, blocked)
	assert(flight.result == "wall" and flight.delivered.is_empty())
	flight.launch(Vector3.ZERO, Vector3.FORWARD)
	flight.steer(Vector2(1, 0), 0.1)
	assert(flight.direction.x > 0 and is_equal_approx(flight.direction.length(), 1))
	flight.step(FLIGHT.DURATION, [], empty)
	assert(flight.result == "timeout")
	flight.clear()
	assert(flight.misses == 0 and flight.delivered.is_empty() and not flight.active)
	print("MAIL FLIGHT PASS: swept hit, occlusion, duplicate, cancel, timeout, steering, reset")
	quit()

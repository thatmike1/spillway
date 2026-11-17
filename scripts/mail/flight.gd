extends RefCounted
## isolated envelope simulation; body time and global engine time are never changed.
const VERSION := "mail-flight-2"
const SPEED := 24.0
const DURATION := 1.6
const TURN_RATE := 2.8
var active := false
var position := Vector3.ZERO
var direction := Vector3.FORWARD
var age := 0.0
var delivered: Dictionary = {}
var misses := 0
var result := ""
var target_id := ""

func launch(at: Vector3, aim: Vector3) -> bool:
	if active or aim.length_squared() < 0.01:
		return false
	position = at
	direction = aim.normalized()
	age = 0.0
	active = true
	result = ""
	target_id = ""
	return true

func steer(turn: Vector2, dt: float) -> void:
	var right := direction.cross(Vector3.UP).normalized()
	direction = (direction + (right * turn.x + Vector3.UP * turn.y) * TURN_RATE * dt).normalized()

func step(dt: float, boxes: Array, blocked: Callable) -> void:
	if not active:
		return
	var previous := position
	position += direction * SPEED * dt
	age += dt
	# compare swept segment distances so a mailbox behind a wall cannot be delivered.
	var wall: Dictionary = blocked.call(previous, position)
	var wall_distance := previous.distance_to(wall.position) if not wall.is_empty() else INF
	for box: Dictionary in boxes:
		if delivered.has(str(box.id)):
			continue
		var hit: Variant = (box.bounds as AABB).intersects_segment(previous, position)
		if box.has("front"):
			var face := float(box.front)
			var travel_z := position.z - previous.z
			if travel_z * face >= 0.0:
				continue
			var fraction: float = (box.position.z + face * 0.5 - previous.z) / travel_z
			if fraction < 0 or fraction > 1:
				continue
			var crossing := previous.lerp(position, fraction)
			if not (box.bounds as AABB).has_point(crossing - Vector3(0, 0, face * 0.0001)):
				continue
			hit = crossing
		if hit != null and previous.distance_to(hit as Vector3) <= wall_distance:
			delivered[str(box.id)] = true
			target_id = str(box.id)
			end("hit")
			return
	if not wall.is_empty():
		position = wall.position
		end("wall")
	elif age >= DURATION:
		end("timeout")

func end(reason: String) -> void:
	if not active:
		return
	active = false
	result = reason
	if reason != "hit":
		misses += 1

func clear() -> void:
	active = false
	delivered.clear()
	misses = 0
	result = ""

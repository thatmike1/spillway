extends RefCounted
## input-only controller for the authored Penstock straight, shared by source and pack probes.
var origin := Vector3.ZERO
var lane_yaw := 0.0
var rpc := 0.0
var kind := "back"
var ending := "bank"
var held: Dictionary = {}
var memory: Dictionary = {}
var phase := "accelerate"
var terminal_serial := 0
var done := false

func configure(feet: Vector3, yaw: float, radians_per_count: float, direction: String, terminal: String) -> void:
	origin = feet
	lane_yaw = yaw
	rpc = radians_per_count
	kind = direction
	ending = terminal

func commands(tick: int, row: Dictionary) -> Array:
	var out: Array = []
	if tick == 1:
		_key(out, "w", true)
	if row.is_empty():
		return out
	if phase == "accelerate":
		if tick == 110:
			_key(out, "space", true)
		if tick < 110:
			return out
		if not memory.has("air") and not bool(row.g):
			memory.air = tick
			_key(out, "w", false)
		if not memory.has("air"):
			return out
		if float(row.speed) >= 360.0 and not bool(row.g):
			phase = "align"
		else:
			var right := Vector3(cos(lane_yaw), 0.0, -sin(lane_yaw))
			var offset := ((row.p as Vector3) - origin).dot(right)
			var target := lane_yaw + deg_to_rad(28.0) * sin(float(tick - int(memory.air)) / 96.0 * TAU) - clampf(offset * 0.04, -0.12, 0.12)
			var turn := clampf(angle_difference(float(row.yaw), target), -0.04, 0.04)
			out.append(["mouse", -turn / rpc])
			_key(out, "a", turn > 0.0)
			_key(out, "d", turn <= 0.0)
			return out
	if phase == "align":
		var velocity: Vector3 = row.v
		var travel_yaw := atan2(-velocity.x, -velocity.z)
		var error := angle_difference(travel_yaw, lane_yaw)
		_turn(out, float(row.yaw), travel_yaw + PI)
		_key(out, "a", error < -0.01)
		_key(out, "d", error > 0.01)
		if absf(error) <= 0.01:
			phase = "stack"
			_key(out, "a", false)
			_key(out, "d", false)
			if kind == "side":
				_turn(out, travel_yaw + PI, travel_yaw + PI * 0.5)
		return out
	if phase == "stack" and int(row.direction.hops) >= 6:
		terminal_serial = int((row.direction.get("last", {}) as Dictionary).get("serial", 0))
		phase = "terminal"
		if ending == "bank":
			_turn(out, float(row.yaw), atan2(-(row.v as Vector3).x, -(row.v as Vector3).z))
		else:
			_key(out, "space", false)
	return out

func observe(row: Dictionary) -> void:
	var last: Dictionary = row.direction.get("last", {})
	if phase == "terminal" and int(last.get("serial", 0)) > terminal_serial:
		done = true

func release() -> Array:
	var out: Array = []
	for key: String in held.keys():
		_key(out, key, false)
	return out

func _turn(out: Array, before: float, after: float) -> void:
	out.append(["mouse", -angle_difference(before, after) / rpc])

func _key(out: Array, key: String, down: bool) -> void:
	if bool(held.get(key, false)) != down:
		held[key] = down
		out.append([key, down])

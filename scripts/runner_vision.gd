extends RefCounted
## authored object eligibility, independent proximity/look timers and material fades.
const RED: Color = Color("#d9342e") # runner vision RGB is U; this treatment is P.
const NEUTRAL: Color = Color("#a5aeb6")
var objects: Array[Dictionary] = []
var mode: int = 1
var difficulty: int = 0
var tutorial: bool = false
var allowed: bool = true

func register(anchor: Node3D, offset: Vector3, material: StandardMaterial3D, options: Dictionary = {}) -> int:
	objects.append({
		"anchor": anchor, "offset": offset, "material": material,
		"eligible": options.get("eligible", true), "distance": options.get("distance", 15.0),
		"horizontal": options.get("horizontal", false), "direction": options.get("direction", Vector3.BACK),
		"angle": options.get("angle", 0.0), "proximity_delay": options.get("proximity_delay", 0.0),
		"look_delay": options.get("look_delay", -1.0), "group": options.get("group", ""),
		# static actor duration casts 1.5s to integer before max with .5 -> 1s (H/M).
		"minimum": options.get("minimum", 1.0), "near_time": 0.0, "look_time": 0.0,
		"hold": 0.0, "level": 0.0, "look_requested": false, "forced": -1,
	})
	material.emission_enabled = false
	material.albedo_color = NEUTRAL
	return objects.size() - 1

func position(index: int) -> Vector3:
	var obj: Dictionary = objects[index]
	return (obj.anchor as Node3D).global_transform * Vector3(obj.offset)

func look_at_attempt(index: int) -> void:
	objects[index].look_requested = true

func force_group(group: String, active: bool) -> void:
	for obj: Dictionary in objects:
		if obj.group == group:
			obj.forced = 1 if active else 0

func reset() -> void:
	for obj: Dictionary in objects:
		obj.near_time = 0.0
		obj.look_time = 0.0
		obj.hold = 0.0
		obj.level = 0.0
		obj.forced = -1
		obj.look_requested = false
		(obj.material as StandardMaterial3D).albedo_color = NEUTRAL

func step(player_position: Vector3, dt: float) -> void:
	var enabled: bool = allowed and (mode != 0 or tutorial) and (difficulty != 2 or tutorial)
	var groups: Dictionary = {}
	var activation: Array[bool] = []
	for i: int in objects.size():
		var obj: Dictionary = objects[i]
		var offset: Vector3 = player_position - position(i)
		if obj.horizontal:
			offset.y = 0
		var near: bool = offset.length() <= float(obj.distance)
		var cone: bool = true
		if float(obj.angle) > 1 and offset.length_squared() > .001:
			var direction: Vector3 = (obj.anchor as Node3D).global_basis * Vector3(obj.direction)
			cone = direction.normalized().dot(offset.normalized()) >= cos(deg_to_rad(float(obj.angle)) / 2)
		obj.near_time = float(obj.near_time) + dt if near and cone else 0.0
		obj.look_time = float(obj.look_time) + dt if obj.look_requested else 0.0
		var prox: bool = near and cone and float(obj.near_time) >= float(obj.proximity_delay)
		var looked: bool = obj.look_requested and float(obj.look_delay) >= 0 and float(obj.look_time) >= float(obj.look_delay)
		var active: bool = (prox or looked) and bool(obj.eligible) and enabled
		if int(obj.forced) >= 0:
			active = int(obj.forced) == 1 and enabled and bool(obj.eligible)
		activation.append(active)
		if active and not String(obj.group).is_empty():
			groups[obj.group] = true
	for i: int in objects.size():
		var obj: Dictionary = objects[i]
		var active: bool = enabled and bool(obj.eligible) and (activation[i] or groups.has(obj.group))
		if int(obj.forced) == 0:
			active = false
		if active:
			obj.hold = float(obj.minimum)
		else:
			obj.hold = maxf(0, float(obj.hold) - dt)
		var target: float = 1 if (active or float(obj.hold) > 0) and enabled else 0
		# recovered fade rates 1 in / 4 out (H/M), independent of camera visibility.
		obj.level = move_toward(float(obj.level), target, dt * (1 if target > float(obj.level) else 4))
		(obj.material as StandardMaterial3D).albedo_color = NEUTRAL.lerp(RED, float(obj.level))

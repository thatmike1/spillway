extends RefCounted
## surveyed attachment positions, carried in identity rather than render-only state.
const SOCKETS := [Vector3(-9, 11, 1), Vector3(0, 14, 0), Vector3(9, 11, 1), Vector3(-12, 11, -11), Vector3(0, 14, -13), Vector3(12, 11, -11), Vector3(-9, 11, -25), Vector3(0, 14, -27), Vector3(9, 11, -25)]
const DEFAULT := [0, 3, 6]
static func valid(value: Variant, budget: int = 3) -> bool:
	if not value is Array or value.size() > budget:
		return false
	var seen := {}
	for item: Variant in value:
		if not (item is int or item is float) or not is_finite(float(item)) or float(item) != int(item) or int(item) < 0 or int(item) >= SOCKETS.size() or seen.has(int(item)):
			return false
		seen[int(item)] = true
	return true
static func canonical(value: Array) -> Array:
	var result: Array = value.map(func(v: Variant) -> int: return int(v))
	result.sort()
	return result

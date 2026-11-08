extends "res://tests/test_r14_practice_level.gd"
## independent anchor controls and a convex-volume containment proof for the tail edit.

func _walking(level: Node3D) -> Dictionary:
	var result := super._walking(level)
	var adjustments: Array = report.get("grid_anchor_adjustments", []).duplicate(true)
	var controls := []
	for gap: Dictionary in level.get("jump_gaps"):
		var along := ((gap.land as Vector3) - (gap.edge as Vector3)).normalized()
		var p: Vector3 = gap.edge - along * 0.6
		var hit := _ray(level, Vector3(p.x, 14, p.z), Vector3(p.x, -7, p.z))
		if hit.is_empty():
			continue
		var key := _key(p)
		var body: Node = hit.collider
		var fake := {key: {"piece": "different_body"}}
		var wrong := _anchor_key(level, fake, p)
		_check(str(gap.label) + " anchor rejects different body", wrong == Vector2i(-1, -1))
		var far := key + Vector2i(2, 0)
		var distant := _anchor_key(level, {far: {"piece": str(body.name)}}, p)
		_check(str(gap.label) + " anchor rejects distant same body", distant == Vector2i(-1, -1))
		controls.append({"gap": gap.label, "exact_body": str(body.name), "different_rejected": wrong == Vector2i(-1, -1), "distant_rejected": distant == Vector2i(-1, -1)})
	var empty_p := Vector3(-230, 0, -136)
	_check("anchor over the pit cannot choose a neighbouring deck", _anchor_key(level, {_key(empty_p): {"piece": "s6_runin"}}, empty_p) == Vector2i(-1, -1))
	for adjustment: Dictionary in adjustments:
		var p: Vector3 = adjustment.point
		var k: Vector2i = adjustment.cell
		var centre := Vector3(GRID.position.x + (k.x + 0.5) * CELL, p.y, GRID.position.z + (k.y + 0.5) * CELL)
		var body_name := str(adjustment.piece)
		var all_same := true
		for i: int in 21:
			var q := p.lerp(centre, i / 20.0)
			var hit := _ray(level, Vector3(q.x, 14, q.z), Vector3(q.x, -7, q.z))
			all_same = all_same and not hit.is_empty() and str(hit.collider.name) == body_name and (hit.normal as Vector3).y >= WALKABLE
		_check("adjusted anchor has a continuous same-body face", all_same, [body_name, p, centre])
		_check("adjusted anchor stays within 0.375 m", float(adjustment.distance_m) <= 0.375)
	var old_runin := [Vector2(-244, -110), Vector2(-228, -110), Vector2(-228, -134.5), Vector2(-244, -124)]
	var runin: Dictionary = (level.get("manifest") as Array).filter(func(e: Dictionary) -> bool: return str(e.name) == "s6_runin")[0]
	for p: Vector3 in (runin.points as Array).slice(0, 4):
		_check("new runin vertex lies inside old runin", _in_convex(Vector2(p.x, p.z), old_runin), p)
	# split the new landing at the old landing's west edge. its east half is unchanged;
	# its added west rectangle must be inside the old runin, including its full depth.
	for p: Vector2 in [Vector2(-228.8, -118.5), Vector2(-228, -118.5), Vector2(-228, -114), Vector2(-228.8, -114)]:
		_check("added landing corner already occupied by old runin", _in_convex(p, old_runin), p)
	var top: Dictionary = (level.get("manifest") as Array).filter(func(e: Dictionary) -> bool: return str(e.name) == "s6_lane_top")[0]
	_check("changed tail pieces share the old floor and base", (runin.points as Array).slice(0, 4).all(func(p: Vector3) -> bool: return p.y == 0.0) and (top.points as Array).slice(0, 4).all(func(p: Vector3) -> bool: return p.y == 0.0) and (runin.points as Array).slice(4).all(func(p: Vector3) -> bool: return p.y == -6.0) and (top.points as Array).slice(4).all(func(p: Vector3) -> bool: return p.y == -6.0))
	report["grid_anchor_adjustments"] = adjustments
	report["independent_anchor_controls"] = controls
	return result

func _in_convex(p: Vector2, polygon: Array) -> bool:
	var side := 0.0
	for i: int in polygon.size():
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		var cross := (b - a).cross(p - a)
		if absf(cross) <= 0.0001 * (b - a).length():
			continue
		if side * cross < 0:
			return false
		side = cross
	return true

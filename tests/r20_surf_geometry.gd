extends RefCounted
## compare the actual collision shapes to the full manifest, not just a route subset.

static func audit(level: Node3D) -> Dictionary:
	var failures: Array = []
	var pieces: Array = []
	var max_extent := 0.0
	var steep := 0
	var climbing: Array = []
	var flat_exits := {}
	for row: Dictionary in level.manifest:
		var body := level.get_node(NodePath(row.name)) as StaticBody3D
		var collision := body.get_child(0) as CollisionShape3D
		var shape := collision.shape as ConvexPolygonShape3D
		var actual: Array[Vector3] = []
		for p: Vector3 in shape.points:
			actual.append(body.transform * collision.transform * p)
		if actual.size() != row.points.size():
			failures.append("vertex count: " + row.name)
		for p: Vector3 in row.points:
			if not actual.any(func(q: Vector3) -> bool: return p.distance_to(q) < 0.00003):
				failures.append("collision/manifest vertex: " + row.name)
		var bounds := AABB(actual[0], Vector3.ZERO)
		for p: Vector3 in actual:
			bounds = bounds.expand(p)
		var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		max_extent = maxf(max_extent, extent)
		if extent > 32.0001:
			failures.append("piece exceeds 32m: " + row.name)
		var normal := ((actual[1] - actual[0]).cross(actual[2] - actual[0])).normalized()
		if normal.y < 0:
			normal = -normal
		if row.role == "surf":
			steep += 1
			if absf(normal.y - 1.0 / sqrt(3.25)) > 0.00001 or normal.y >= 0.7:
				failures.append("surf plane is not the declared steep face: " + row.name)
		if row.role == "recovery" or str(row.name).begins_with("catch_") or str(row.name).begins_with("return_"):
			failures.append("recovery geometry exists: " + row.name)
		if str(row.name).begins_with("crescent_"):
			climbing.append({"name": row.name, "height": actual[0].y})
		if "landing" in str(row.name):
			flat_exits[row.name] = normal.y
			if absf(normal.y - 1.0) > 0.00001:
				failures.append("exit support must be flat: " + row.name)
		# no walkable support may overlap either fin interior in plan view.
		if normal.y >= 0.7:
			for fin: AABB in [AABB(Vector3(-12, -10, -167.99), Vector3(36, 40, 167.98)), AABB(Vector3(60, -10, -167.99), Vector3(36, 40, 167.98))]:
				if bounds.intersects(fin):
					failures.append("walkable support beneath/within fin: " + row.name)
		pieces.append({"name": row.name, "vertices": actual.map(func(p: Vector3) -> Array: return [p.x, p.y, p.z]), "normal": [normal.x, normal.y, normal.z], "role": row.role, "stage": row.stage, "extent_m": extent})
	if steep != 16:
		failures.append("need sixteen physical steep pieces")
	if level.find_children("*", "Area3D", true, false).size() != 0:
		failures.append("unexpected trigger geometry")
	for i: int in range(1, climbing.size()):
		if float(climbing[i].height) <= float(climbing[i - 1].height):
			failures.append("crescent does not climb")
	if climbing.size() != 3 or flat_exits.size() != 4:
		failures.append("missing crescent or exit pieces")
	# the old spawn-side stage-3 shortcut has no solid within a 45 m radius.
	var spawn_stage3_gap := INF
	for piece: Dictionary in level.manifest:
		if int(piece.stage) == 3:
			var bounds := AABB(piece.points[0], Vector3.ZERO)
			for point: Vector3 in piece.points:
				bounds = bounds.expand(point)
			var nearest := Vector2(clampf(level.spawn.origin.x, bounds.position.x, bounds.end.x), clampf(level.spawn.origin.z, bounds.position.z, bounds.end.z))
			spawn_stage3_gap = minf(spawn_stage3_gap, nearest.distance_to(Vector2(level.spawn.origin.x, level.spawn.origin.z)))
	if spawn_stage3_gap < 45:
		failures.append("stage 3 still close to spawn")
	return {"climbing": climbing, "flat_exits": flat_exits, "spawn_stage3_min_plan_gap_m": spawn_stage3_gap, "ok": failures.is_empty(), "errors": failures, "hash": level.geometry_hash(), "max_extent_m": max_extent, "steep_pieces": steep, "pieces": pieces}

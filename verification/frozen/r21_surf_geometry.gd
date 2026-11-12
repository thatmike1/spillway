extends RefCounted
## compare the actual collision shapes to the full manifest, not just a route subset.

static func audit(level: Node3D) -> Dictionary:
	var failures: Array = []
	var pieces: Array = []
	var names := {}
	for row: Dictionary in level.manifest:
		if names.has(row.name):
			failures.append("duplicate manifest name: " + str(row.name))
		names[row.name] = true
	for body: Node in level.find_children("*", "StaticBody3D", true, false):
		if not names.has(str(body.name)):
			failures.append("unmanifested solid: " + str(body.name))
	var fin_corridors: Array[AABB] = []
	for fin: String in ["west", "east"]:
		var bounds := AABB()
		var found := false
		for row: Dictionary in level.manifest:
			if row.role != "surf" or not str(row.name).begins_with("Surf_" + fin + "_"):
				continue
			for point: Vector3 in row.points:
				if not found:
					bounds = AABB(point, Vector3.ZERO)
					found = true
				bounds = bounds.expand(point)
		if not found:
			failures.append("missing physical fin: " + fin)
		else:
			# include both sides of the fin, from kill height upward, excluding its two end planes.
			fin_corridors.append(AABB(Vector3(bounds.position.x - 12, level.kill_bounds.position.y, bounds.position.z + 0.01), Vector3(bounds.size.x + 24, level.kill_bounds.size.y, bounds.size.z - 0.02)))
	var max_extent := 0.0
	var steep := 0
	var climbing: Array = []
	var flat_exits := {}
	for row: Dictionary in level.manifest:
		var body := level.get_node(NodePath(row.name)) as StaticBody3D
		if int(body.get_meta("progress_stage", -999)) != int(row.stage) or str(body.get_meta("surface", "")) != str(row.role):
			failures.append("collision/manifest metadata: " + str(row.name))
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
			for fin: AABB in fin_corridors:
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
	if climbing.size() != 9 or flat_exits.size() != 4:
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
	return {"fin_corridors": fin_corridors.map(func(b: AABB) -> Dictionary: return {"position": [b.position.x, b.position.y, b.position.z], "size": [b.size.x, b.size.y, b.size.z]}), "climbing": climbing, "flat_exits": flat_exits, "spawn_stage3_min_plan_gap_m": spawn_stage3_gap, "ok": failures.is_empty(), "errors": failures, "hash": level.geometry_hash(), "max_extent_m": max_extent, "steep_pieces": steep, "pieces": pieces}

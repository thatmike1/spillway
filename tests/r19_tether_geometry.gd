extends RefCounted
## compare every actual convex and anchor with the complete authored identity data.

static func audit(level: Node3D) -> Dictionary:
	var errors: Array = []
	var pieces: Array = []
	var max_extent := 0.0
	for row: Dictionary in level.manifest:
		var body := level.get_node(NodePath(row.name)) as StaticBody3D
		var collision := body.get_child(0) as CollisionShape3D
		var shape := collision.shape as ConvexPolygonShape3D
		var actual: Array[Vector3] = []
		for p: Vector3 in shape.points:
			actual.append(body.transform * collision.transform * p)
		if actual.size() != row.points.size():
			errors.append("vertex count: " + row.name)
		for p: Vector3 in row.points:
			if not actual.any(func(q: Vector3) -> bool: return p.distance_to(q) < 0.00003):
				errors.append("collision/manifest mismatch: " + row.name)
		var bounds := AABB(actual[0], Vector3.ZERO)
		for p: Vector3 in actual:
			bounds = bounds.expand(p)
		var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		max_extent = maxf(max_extent, extent)
		if extent > 32.0001:
			errors.append("piece exceeds 32m: " + row.name)
		pieces.append({"name": row.name, "vertices": actual.map(func(p: Vector3) -> Array: return [p.x, p.y, p.z]), "role": row.role, "stage": row.stage})
	var anchors: Array = []
	for i: int in level.ANCHORS.size():
		var node := level.get_node("Anchor_%d" % (i + 1)) as Node3D
		if node.position != level.ANCHORS[i] or not node.is_in_group("r15_grapple_anchor"):
			errors.append("anchor position/group mismatch")
		anchors.append([node.position.x, node.position.y, node.position.z])
	if level.find_children("*", "Area3D", true, false).size() != 0:
		errors.append("unexpected trigger geometry")
	return {"ok": errors.is_empty(), "errors": errors, "hash": level.geometry_hash(), "max_extent_m": max_extent, "pieces": pieces, "anchors": anchors}

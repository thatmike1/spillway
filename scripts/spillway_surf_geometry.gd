extends RefCounted
## p / original dam faces: shared-edge convex wedges, with visible and physical vertices identical.
## yaw rotates the initial tangent (-z); positive bend turns right. side +1 puts the riding
## face's high edge on the runner's right (hold D), -1 on the left (hold A). when the face
## sits inside the turn it needs strafe to hold; outside the turn it is a banked berm.

static func point(section: Dictionary, theta: float, radius: float, height: float = 0.0) -> Vector3:
	var bend: float = section.bend
	var center := Vector3(bend * section.radius, 0, 0)
	var local := center + Vector3(-bend * cos(theta), 0, -sin(theta)) * radius
	local.y = height + lerpf(section.drop_start, section.drop_end, theta / section.arc)
	return section.origin + Basis(Vector3.UP, section.yaw) * local

static func angle_at(section: Dictionary, position: Vector3) -> float:
	var local: Vector3 = Basis(Vector3.UP, -section.yaw) * (position - section.origin)
	return atan2(-local.z, -section.bend * (local.x - section.bend * section.radius))

static func tangent_yaw(section: Dictionary, theta: float) -> float:
	return section.yaw - section.bend * theta

static func build(level: Node3D, label: String, origin: Vector3, yaw: float, bend: int, radius: float, arc_degrees: float, height: float, drop_end: float = 0.0, stage: int = 0, end_height: float = -1.0, side: int = 1) -> Dictionary:
	var section := {"name": label, "origin": origin, "yaw": yaw, "bend": float(bend), "radius": radius,
		"arc": deg_to_rad(arc_degrees), "height": height, "run": height / tan(deg_to_rad(60.0)),
		"drop_start": 0.0, "drop_end": drop_end, "stage": stage, "height_end": height if end_height < 0 else end_height, "side": float(side)}
	var segments := ceili(arc_degrees / 3.0)
	section["segments"] = segments
	for i: int in segments:
		var vertices := PackedVector3Array()
		for theta: float in [section.arc * i / segments, section.arc * (i + 1) / segments]:
			var local_height := lerpf(height, section.height_end, theta / section.arc)
			var foot_radius := radius + local_height / tan(deg_to_rad(60.0)) * side / bend
			vertices.append(point(section, theta, foot_radius))
			vertices.append(point(section, theta, radius, local_height))
			vertices.append(point(section, theta, radius, -14.0))
		var faces: Array = [[0, 1, 2], [3, 5, 4], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]]
		if stage == 1:
			# p / the yard chute bridges the lower outflow; a real slab leaves that underpass open.
			vertices = PackedVector3Array([vertices[0], vertices[1], vertices[4], vertices[3]])
			for index: int in 4:
				vertices.append(vertices[index] - Vector3.UP * .8)
			faces = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
		var body := StaticBody3D.new()
		body.name = "%sFace%02d" % [label, i]
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("surface", "concrete")
		body.set_meta("surf_section", label)
		level.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = vertices
		collision.shape = shape
		body.add_child(collision)
		var center := Vector3.ZERO
		for vertex: Vector3 in vertices:
			center += vertex / vertices.size()
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_smooth_group(-1)
		for face: Array in faces:
			var indices: Array = [0, 1, 2] if face.size() == 3 else [0, 1, 2, 0, 2, 3]
			for tri: int in indices.size() / 3:
				var a: Vector3 = vertices[face[indices[tri * 3]]]
				var b: Vector3 = vertices[face[indices[tri * 3 + 1]]]
				var c: Vector3 = vertices[face[indices[tri * 3 + 2]]]
				# godot's front winding is clockwise; derive an outward normal from the solid.
				var normal := (c - a).cross(b - a).normalized()
				if normal.dot((a + b + c) / 3.0 - center) < 0:
					var swap := b
					b = c
					c = swap
					normal = -normal
				for vertex: Vector3 in [a, b, c]:
					tool.set_normal(normal)
					tool.add_vertex(vertex)
		var mesh := MeshInstance3D.new()
		mesh.mesh = tool.commit()
		mesh.material_override = level.get("_materials")["concrete"]
		body.add_child(mesh)
		# the high coping is hardware, not a continuous route stripe along the riding face.
		if i % 3 == 0:
			var theta: float = section.arc * (i + .5) / segments
			var at := point(section, theta, radius, lerpf(height, section.height_end, theta / section.arc))
			level.call("_box", at + Vector3.UP * .035, Vector3(.18, .07, .32), "ochre")
	if stage == 1:
		for fraction: float in [0.0, .66, 1.0]:
			var at := point(section, section.arc * fraction, radius, height - .8)
			if fraction == 0.0:
				var supported := at + Vector3.RIGHT * 3.0
				level.call("_beam", at, supported, .35, "steel", true)
				at = supported
			level.call("_solid", "YardBankPier", Vector3(at.x, (at.y - 9) * .5, at.z), Vector3(.7, at.y + 9, .9), "old_concrete")
	return section

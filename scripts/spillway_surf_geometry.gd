extends RefCounted
## p / original dam faces: shared-edge convex wedges, with visible and physical vertices identical.
## yaw rotates the initial tangent (-z); positive bend turns right. side +1 puts the riding
## face's high edge on the runner's right (hold D), -1 on the left (hold A). when the face
## sits inside the turn it needs strafe to hold; outside the turn it is a banked berm.

static func point(section: Dictionary, theta: float, radius: float, height: float = 0.0) -> Vector3:
	var bend: float = section.bend
	var center := Vector3(bend * section.radius, 0, 0)
	var local := center + Vector3(-bend * cos(theta), 0, -sin(theta)) * radius
	local.y = height + drop_at(section, theta)
	return section.origin + Basis(Vector3.UP, section.yaw) * local

## the section's vertical offset along its arc. without end grades it is linear; with them
## (metres per metre of coping arc) it is a cubic, so chained sections can share one smooth
## descent with no grade step at their joints.
static func drop_at(section: Dictionary, theta: float) -> float:
	var t: float = theta / section.arc
	if not section.has("drop_grade_start"):
		return lerpf(section.drop_start, section.drop_end, t)
	var length: float = section.radius * section.arc
	var start: float = section.drop_start
	var end: float = section.drop_end
	var start_grade: float = section.drop_grade_start * length
	var end_grade: float = section.drop_grade_end * length
	if t < 0.0:
		return start + start_grade * t
	if t > 1.0:
		return end + end_grade * (t - 1.0)
	var t2 := t * t
	var t3 := t2 * t
	return (2 * t3 - 3 * t2 + 1) * start + (t3 - 2 * t2 + t) * start_grade + (3 * t2 - 2 * t3) * end + (t3 - t2) * end_grade

static func angle_at(section: Dictionary, position: Vector3) -> float:
	var local: Vector3 = Basis(Vector3.UP, -section.yaw) * (position - section.origin)
	return atan2(-local.z, -section.bend * (local.x - section.bend * section.radius))

static func tangent_yaw(section: Dictionary, theta: float) -> float:
	return section.yaw - section.bend * theta

## foot_height raises the riding face's low edge above the origin (the 60 degree plane is
## unchanged); a stage-1 slab also tapers to a knife edge over its first taper_degrees.
## face_height >= 0 fixes the riding plane at that coping height: a lower coping then only
## trims the top of the same plane instead of twisting it (the coping sits inside radius).
## drop_grades [start, end] makes the drop a cubic with those end grades (see drop_at).
static func build(level: Node3D, label: String, origin: Vector3, yaw: float, bend: int, radius: float, arc_degrees: float, height: float, drop_end: float = 0.0, stage: int = 0, end_height: float = -1.0, side: int = 1, foot_height: float = 0.0, taper_degrees: float = 0.0, solid_from_degrees: float = 360.0, face_height: float = -1.0, drop_grades: Array = []) -> Dictionary:
	var section := {"name": label, "origin": origin, "yaw": yaw, "bend": float(bend), "radius": radius,
		"arc": deg_to_rad(arc_degrees), "height": height, "run": height / tan(deg_to_rad(60.0)),
		"drop_start": 0.0, "drop_end": drop_end, "stage": stage, "height_end": height if end_height < 0 else end_height, "side": float(side),
		"foot_height": foot_height, "face_height": face_height}
	if drop_grades.size() == 2:
		section["drop_grade_start"] = float(drop_grades[0])
		section["drop_grade_end"] = float(drop_grades[1])
	var segments := ceili(arc_degrees / 3.0)
	section["segments"] = segments
	for i: int in segments:
		var solid: bool = stage == 1 and arc_degrees * i / segments >= solid_from_degrees - .001
		var vertices := PackedVector3Array()
		for theta: float in [section.arc * i / segments, section.arc * (i + 1) / segments]:
			var local_height := coping_height(section, theta)
			var plane_height := local_height if face_height < 0 else face_height
			var foot_radius := radius + (plane_height - foot_height) / tan(deg_to_rad(60.0)) * side / bend
			var top_radius := coping_radius(section, theta)
			vertices.append(point(section, theta, foot_radius, foot_height))
			vertices.append(point(section, theta, top_radius, local_height))
			# p / a stage-1 face wholly over the apron is a solid bank on it, with no crawlspace.
			vertices.append(point(section, theta, top_radius, foot_height if solid else -14.0))
		var faces: Array = [[0, 1, 2], [3, 5, 4], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]]
		if stage == 1 and not solid:
			# p / the yard chute bridges the lower outflow; a real slab leaves that underpass open.
			vertices = PackedVector3Array([vertices[0], vertices[1], vertices[4], vertices[3]])
			for index: int in 4:
				# indices 0,1 sit at this face's start angle, 2,3 at its end angle.
				var theta: float = section.arc * (i + (0 if index < 2 else 1)) / segments
				vertices.append(vertices[index] - Vector3.UP * _thickness(theta, taper_degrees))
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
			var at := point(section, theta, coping_radius(section, theta), coping_height(section, theta))
			level.call("_box", at + Vector3.UP * .035, Vector3(.18, .07, .32), "ochre")
	if stage == 1:
		for fraction: float in [0.0, .66, 1.0]:
			var at := point(section, section.arc * fraction, radius, height - _thickness(section.arc * fraction, taper_degrees) - (.175 if fraction == 0.0 else 0.0))
			if fraction == 0.0:
				var supported := at + Vector3.RIGHT * 3.0
				level.call("_beam", at, supported, .35, "steel", true)
				at = supported
			level.call("_solid", "YardBankPier", Vector3(at.x, (at.y - 9) * .5, at.z), Vector3(.7, at.y + 9, .9), "old_concrete")
	return section

## local coping height, above the section origin.
static func coping_height(section: Dictionary, theta: float) -> float:
	return lerpf(section.height, section.height_end, clampf(theta / section.arc, 0, 1))

## plan radius of the coping line: the section radius, or inside it on a fixed plane.
static func coping_radius(section: Dictionary, theta: float) -> float:
	if float(section.get("face_height", -1.0)) < 0.0:
		return section.radius
	return section.radius + (section.face_height - coping_height(section, theta)) / tan(deg_to_rad(60.0)) * section.side / section.bend

static func _thickness(theta: float, taper_degrees: float) -> float:
	# p / a 0.8 m slab, thinned to 5 cm at a tapered leading end so an early arrival glances off.
	if taper_degrees <= 0.0:
		return .8
	return lerpf(.05, .8, clampf(theta / deg_to_rad(taper_degrees), 0, 1))

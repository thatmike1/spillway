extends RefCounted
## convex collision and outward-facing meshes share exactly the same vertices.

static func prism(level: Node3D, id: String, top: Array[Vector3], bottom: float, stage: int, role: String, kind: String = "deck") -> void:
	var points: Array[Vector3] = top.duplicate()
	for p: Vector3 in top:
		points.append(Vector3(p.x, bottom, p.z))
	var body := StaticBody3D.new()
	body.name = id
	body.set_meta("progress_stage", stage)
	body.set_meta("surface", role)
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var origin := Vector3.ZERO
	for p: Vector3 in points:
		origin += p / points.size()
	body.position = origin
	var local_points := PackedVector3Array()
	for p: Vector3 in points:
		local_points.append(p - origin)
	shape.points = local_points
	collision.shape = shape
	body.add_child(collision)
	level.add_child(body)
	level.manifest.append({"name": id, "points": points, "shape": "prism", "stage": stage, "role": role, "kind": kind})
	level.prisms.append({"kind": kind, "top": top})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector3.ZERO
	for p: Vector3 in points:
		centre += p / points.size()
	var n := top.size()
	for i: int in range(1, n - 1):
		triangle(st, top[0], top[i], top[i + 1], centre)
		triangle(st, points[n], points[n + i], points[n + i + 1], centre)
	for i: int in n:
		var j := (i + 1) % n
		triangle(st, points[i], points[j], points[n + j], centre)
		triangle(st, points[i], points[n + j], points[n + i], centre)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh_%s_%s" % [kind, id]
	mesh.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b9b3a1") if role != "surf" else Color("657f81")
	material.roughness = 0.95
	mesh.material_override = material
	level.add_child(mesh)

static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot((a + b + c) / 3.0 - centre) < 0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	st.set_normal(normal)
	# godot's front faces use clockwise winding.
	for p: Vector3 in [a, c, b]:
		st.add_vertex(p)

static func rectangle(x0: float, x1: float, z0: float, z1: float, y: float) -> Array[Vector3]:
	return [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]

static func deck(level: Node3D, id: String, x0: float, x1: float, z0: float, z1: float, y: float, stage: int, role: String = "route") -> void:
	# every axis is at most 32 m; exact shared edges avoid artificial seam lips.
	var nx := ceili((x1 - x0) / 24.0)
	var nz := ceili((z1 - z0) / 24.0)
	for ix: int in nx:
		for iz: int in nz:
			var a := lerpf(x0, x1, float(ix) / nx)
			var b := lerpf(x0, x1, float(ix + 1) / nx)
			var c := lerpf(z0, z1, float(iz) / nz)
			var d := lerpf(z0, z1, float(iz + 1) / nz)
			prism(level, "%s_%d_%d" % [id, ix, iz], rectangle(a, b, c, d, y), y - 0.8, stage, role)

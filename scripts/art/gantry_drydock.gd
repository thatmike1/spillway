extends RefCounted
## original scenery meshes; no collision, acquisition nodes or motor configuration.
const PALE := Color("c6c2aa")
const SIDE := Color("687f7b")
const STEEL := Color("35585b")
const RIB := Color("77938b")

static func dress(level: Node3D) -> void:
	# the gate crane stands on a connected working quay, with its feet below the tide.
	box(level, "gate_quay", Vector3(50, -1, -96), Vector3(58, 7, 27), SIDE)
	box(level, "gate_quay_cap", Vector3(50, 2.6, -96), Vector3(58, 0.35, 27), PALE)
	for x: float in [25, 75]:
		box(level, "gate_foundation_%s" % x, Vector3(x, -1, -96), Vector3(11, 8, 15), STEEL)
		box(level, "gate_foot_%s" % x, Vector3(x, 4, -96), Vector3(8.5, 2.5, 11), PALE)
		box(level, "gate_pylon_%s" % x, Vector3(x, 24, -96), Vector3(4, 39, 6), PALE)
		box(level, "gate_pylon_seam_%s" % x, Vector3(x - 1.2, 24, -92.97), Vector3(0.08, 39, 0.04), SIDE)
		box(level, "gate_bearing_%s" % x, Vector3(x, 43, -96), Vector3(7, 2, 9), SIDE)
	box(level, "gate_crane_beam", Vector3(50, 45, -96), Vector3(59, 3.5, 7), PALE)
	box(level, "gate_crane_shadow", Vector3(50, 43.15, -96), Vector3(59, 0.3, 7.1), STEEL)
	box(level, "gate_crane_rail", Vector3(50, 47, -94), Vector3(59, 0.25, 0.25), STEEL)
	# one coherent load: a hollow caisson with frame, skin and load-bearing ribs.
	box(level, "gate_skin", Vector3(50, 20, -96), Vector3(36, 25, 3.5), STEEL)
	for y: float in [7.5, 32.5]:
		box(level, "gate_frame_%s" % y, Vector3(50, y, -93.7), Vector3(38, 1.3, 1.5), RIB)
	for x: float in [31.5, 68.5]:
		box(level, "gate_end_%s" % x, Vector3(x, 20, -93.7), Vector3(1.3, 25, 1.5), RIB)
	for i: int in 5:
		var x := 37.5 + i * 6.25
		box(level, "gate_rib_%d" % i, Vector3(x, 20, -93.5), Vector3(0.55, 24, 1.9), RIB)
	for y: float in [13.5, 20, 26.5]:
		box(level, "gate_stiffener_%s" % y, Vector3(50, y, -93.2), Vector3(36, 0.45, 2.2), RIB)
	for i: int in 4:
		var x := 35.0 + i * 10.0
		box(level, "gate_trolley_%d" % i, Vector3(x, 42.1, -96), Vector3(2.2, 1.8, 5), STEEL)
		box(level, "gate_hoist_%d" % i, Vector3(x, 37.5, -95.7), Vector3(0.12, 8, 0.12), STEEL)
		box(level, "gate_hoist_pair_%d" % i, Vector3(x + 0.35, 37.5, -96.3), Vector3(0.12, 8, 0.12), STEEL)
		box(level, "gate_lift_%d" % i, Vector3(x, 33.1, -96), Vector3(1.3, 1, 3.7), Color("a4734e"))
	# the harbour wall connects to the work quay and curves into the open sea.
	for i: int in 12:
		var angle := deg_to_rad(float(i) * 4.0)
		var at := Vector3(75 + sin(angle) * 95, -1.5, -111 - (1 - cos(angle)) * 95)
		box(level, "breakwater_%d" % i, at, Vector3(8.0, 5.8, 8), SIDE, angle)
		box(level, "breakwater_crest_%d" % i, at + Vector3(0, 3.05, 0), Vector3(8.1, 0.35, 8.1), PALE, angle)
	headland(level)

static func box(level: Node3D, id: String, at: Vector3, size: Vector3, color: Color, yaw := 0.0) -> void:
	level._box("Art_drydock_" + id, at, size, color)
	var node := level.get_child(level.get_child_count() - 1) as MeshInstance3D
	node.rotation.y = yaw
	if not is_zero_approx(yaw):
		level.art_manifest.append(["drydock_rotation", id, yaw])

static func headland(level: Node3D) -> void:
	# a single continuous coast mass, with a lower warm scarp below the distant ridge.
	var heights := [12.0, 15.0, 15.0, 23.0, 26.0, 24.0, 17.0, 18.0, 29.0, 32.0, 26.0, 22.0, 14.0, 12.0, 17.0, 15.0, 9.0]
	var vertices := PackedVector3Array()
	for i: int in heights.size() - 1:
		var a := Vector3(-350 + i * 42, heights[i], -285 - float(i % 3) * 7)
		var b := Vector3(-350 + (i + 1) * 42, heights[i + 1], -285 - float((i + 1) % 3) * 7)
		var c := Vector3(a.x, -5, a.z + 15)
		var d := Vector3(b.x, -5, b.z + 15)
		vertices.append_array(PackedVector3Array([a, c, b, b, c, d]))
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = "Art_drydock_headland"
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("809b96")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	level.add_child(node)
	level.art_manifest.append(["drydock_headland", heights, "original continuous coast mesh v1"])

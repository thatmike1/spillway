extends RefCounted
## structural top boundaries from the immutable solid manifest, never triangle or texture edges.
const INK := preload("res://shaders/look/ink.gdshader")
var lines := SurfaceTool.new()
var paint := SurfaceTool.new()
var seen := {}
var line_count := 0
var lip_count := 0

func build(level: Node3D, with_ink: bool = true) -> Node3D:
	lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pieces: Array = []
	var joined := {}
	for solid: Dictionary in level.get("manifest"):
		var points: Array = solid.get("points", [])
		if solid.get("shape", "") != "prism" or points.size() < 6 or points.size() % 2 != 0:
			continue
		var top: Array = points.slice(0, points.size()/2)
		var role := str(solid.get("role", ""))
		if role in ["prop","rail","hazard","ceiling"] or str(solid.get("kind", "")) in ["prop_proxy","train"]:
			continue
		pieces.append({"top":top,"route":role in ["route","recovery","baffle"],"points":points})
		for i: int in top.size():
			var key := edge_key(top[i],top[(i+1)%top.size()])
			joined[key] = int(joined.get(key,0))+1
	if with_ink:
		for piece: Dictionary in pieces:
			var top: Array = piece.top
			var low := INF
			var high := -INF
			for point: Vector3 in top:
				low = minf(low,point.y)
				high = maxf(high,point.y)
			# arch collision wedges are not visible silhouette edges. keep their route caps only.
			if not piece.route and high-low > 0.05:
				continue
			for i: int in top.size():
				var a: Vector3 = top[i]
				var b: Vector3 = top[(i+1)%top.size()]
				if int(joined.get(edge_key(a,b),0)) == 1:
					line(a+Vector3.UP*0.009,b+Vector3.UP*0.009,0.005 if piece.route else 0.009)
	var gaps: Variant = level.get("jump_gaps")
	if gaps is Array:
		for gap: Dictionary in gaps:
			for key: String in ["edge","land"]:
				if gap.get(key) is Vector3:
					gap_lip(gap[key],pieces)
	if (level.get_script() as Script).resource_path == "res://scripts/r15_experiment_level.gd":
		var k: Dictionary = (level.get_script() as Script).get_script_constant_map()
		for z: float in [k.LANE_Z1,k.TRENCH_Z1]:
			gap_lip(Vector3(0,0,z),pieces)
		for z: float in [k.GAP_Z0,k.GAP_Z1]:
			for x: float in [-6,6]:
				gap_lip(Vector3(x,k.MEZZ_Y,z),pieces)
	var root := Node3D.new()
	root.name = "StructuralContours"
	if line_count > 0:
		var mesh := MeshInstance3D.new()
		mesh.name = "Ink"
		mesh.mesh = lines.commit()
		var material := ShaderMaterial.new()
		material.shader = INK
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh)
	if lip_count > 0:
		var mesh := MeshInstance3D.new()
		mesh.name = "JumpLips"
		mesh.mesh = paint.commit()
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("d95b30")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh)
	root.set_meta("ink_segments",line_count)
	root.set_meta("jump_lips",lip_count)
	return root

func gap_lip(at: Vector3, pieces: Array) -> void:
	var best := 1.1
	var chosen := {}
	for piece: Dictionary in pieces:
		if not piece.route:
			continue
		var top: Array = piece.top
		var centre := Vector3.ZERO
		for v: Vector3 in top:
			centre += v/top.size()
		for i: int in top.size():
			var a: Vector3 = top[i]
			var b: Vector3 = top[(i+1)%top.size()]
			var ab := b-a
			if ab.length_squared() < 0.25:
				continue
			var nearest := a+ab*clampf((at-a).dot(ab)/ab.length_squared(),0.0,1.0)
			var distance := nearest.distance_to(at)
			if distance < best:
				best = distance
				chosen = {"a":a,"b":b,"centre":centre}
	if chosen.is_empty():
		return
	var a: Vector3 = chosen.a
	var b: Vector3 = chosen.b
	var key := "paint/"+edge_key(a,b)
	if seen.has(key):
		return
	seen[key] = true
	var inward := Vector3.UP.cross(b-a).normalized()
	if inward.dot(chosen.centre-(a+b)*0.5) < 0:
		inward = -inward
	a += Vector3.UP*0.012
	b += Vector3.UP*0.012
	for point: Vector3 in [a,b,b+inward*0.10,a,b+inward*0.10,a+inward*0.10]:
		paint.set_normal(Vector3.UP)
		paint.add_vertex(point)
	lip_count += 1

func line(a: Vector3, b: Vector3, radius: float) -> void:
	if a.distance_to(b) < 0.7:
		return
	var key := edge_key(a,b)
	if seen.has(key):
		return
	seen[key] = true
	line_count += 1
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()*radius
	var up := side.cross(axis).normalized()*radius
	var corners := [side+up,-side+up,-side-up,side-up]
	for i: int in 4:
		for point: Vector3 in [a+corners[i],b+corners[i],b+corners[(i+1)%4],a+corners[i],b+corners[(i+1)%4],a+corners[(i+1)%4]]:
			lines.add_vertex(point)

static func edge_key(a: Vector3, b: Vector3) -> String:
	var aa := str(a.snapped(Vector3.ONE*0.001))
	var bb := str(b.snapped(Vector3.ONE*0.001))
	return aa+"/"+bb if aa < bb else bb+"/"+aa

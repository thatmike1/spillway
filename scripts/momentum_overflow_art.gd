extends RefCounted
## p / overflow art pass: one call after the level's build() relights the course and
## re-skins its merged meshes by what each surface is for. it reads the level's geometry
## manifest, adds no collision, moves no solid, changes no progress data and never edits the
## kit's cached materials (every material here is a new resource on this level only).
## choices, costs and evidence: docs/momentum/ART-PASS.md.
##
##   var level := LevelScript.new(); add_child(level); level.build()
##   OverflowArt.apply(level)   # once; a second call returns the first report

const Materials := preload("res://scripts/momentum_materials.gd")
const SURFACE: Shader = preload("res://shaders/momentum_overflow_surface.gdshader")
const WATER: Shader = preload("res://shaders/momentum_overflow_water.gdshader")
const TERRAIN: Shader = preload("res://shaders/momentum_overflow_terrain.gdshader")
const SKY: Shader = preload("res://shaders/momentum_overflow_sky.gdshader")
const TREE: Shader = preload("res://shaders/momentum_overflow_tree.gdshader")

const VERSION := "overflow-art-1"
const WALKABLE := ["route", "catch", "recovery", "baffle"]
## edge codes written into the vertex data; the surface shader decodes them.
const FREE := 1000.0
const JOINED := 5000.0
const CONTACT := 0.0
## p / how close (m, in plan) two top edges must lie to count as the same line.
const LINE_TOLERANCE := 0.06
## p / terrain and trees keep this far (m, in plan) from every walkable or wall piece.
const CLEARANCE := 45.0
const WATER_Y := -7.6

## p / looks: the kit's texture sets with this level's values. sunlit run decks are the
## lightest broad plane, landings a clear step above them, catch floors dark and damp,
## recovery ramps a mid value with grooves across the fall line, walls a step below the
## decks with lighter copings. steel is dark, ochre and brick are the only warm accents.
const LOOKS := {
	&"run": {"top": &"deck", "side": &"formwork", "params": {
		"desaturate": 0.9, "top_tint": Vector3(0.9, 0.89, 0.86), "side_tint": Vector3(0.78, 0.77, 0.75),
		"top_detail": 0.7, "bay_size": Vector2(4.0, 4.0), "bay_tone": 0.045, "joint_dark": 0.55,
		"side_joint_spacing": 12.0, "macro_strength": 0.05, "margin_width": 0.32, "margin_lift": 0.1,
		"arris_lift": 0.28, "contact_ao": 0.55, "lip_stain": 0.5}},
	&"land": {"top": &"deck", "side": &"formwork", "params": {
		"desaturate": 0.92, "top_tint": Vector3(1.0, 0.99, 0.95), "side_tint": Vector3(0.78, 0.77, 0.75),
		"top_detail": 0.6, "bay_size": Vector2(2.0, 2.0), "bay_tone": 0.05, "joint_dark": 0.45,
		"side_joint_spacing": 12.0, "macro_strength": 0.1, "macro_scale": 16.0, "margin_width": 0.32, "margin_lift": 0.08,
		"arris_lift": 0.22, "contact_ao": 0.55, "lip_stain": 0.5, "specular_level": 0.35, "puddles": 0.22, "stain": 0.25}},
	&"catch": {"top": &"deck", "side": &"formwork", "params": {
		"desaturate": 0.6, "top_tint": Vector3(0.52, 0.53, 0.47), "side_tint": Vector3(0.5, 0.52, 0.48),
		"top_detail": 1.0, "bay_size": Vector2(3.0, 3.0), "bay_tone": 0.08, "joint_dark": 0.6,
		"side_joint_spacing": 12.0, "macro_strength": 0.12, "stain": 0.6, "moss": 0.55, "puddles": 0.5,
		"contact_ao": 0.6, "lip_stain": 0.4, "roughness_scale": 0.9, "margin_width": 0.0, "film": 0.85}},
	&"recovery": {"top": &"deck", "side": &"formwork", "params": {
		"desaturate": 0.65, "top_tint": Vector3(0.7, 0.68, 0.6), "side_tint": Vector3(0.55, 0.56, 0.52),
		"top_detail": 0.8, "bay_size": Vector2(0.0, 0.0), "macro_strength": 0.08, "stain": 0.35,
		"moss": 0.3, "rib_spacing": 0.32, "rib_strength": 0.85, "contact_ao": 0.5, "lip_stain": 0.4,
		"margin_width": 0.32, "margin_lift": 0.12, "arris_lift": 0.25}},
	&"wall": {"top": &"deck", "side": &"formwork", "params": {
		"desaturate": 0.9, "top_tint": Vector3(0.98, 0.96, 0.92), "side_tint": Vector3(0.72, 0.71, 0.69),
		"top_detail": 0.6, "bay_size": Vector2(2.0, 2.0), "bay_tone": 0.04, "joint_dark": 0.6,
		"side_joint_spacing": 6.0, "side_bay_tone": 0.06, "macro_strength": 0.08, "stain": 0.22,
		"foot_ao": 0.6}},
	&"structure": {"top": &"deck", "side": &"formwork", "params": {
		"desaturate": 0.9, "top_tint": Vector3(0.84, 0.83, 0.8), "side_tint": Vector3(0.68, 0.67, 0.65),
		"top_detail": 0.7, "bay_size": Vector2(4.0, 4.0), "bay_tone": 0.05, "joint_dark": 0.5,
		"side_joint_spacing": 12.0, "macro_strength": 0.1, "stain": 0.3}},
	&"old": {"top": &"deck", "side": &"formwork", "params": {
		"desaturate": 0.6, "top_tint": Vector3(0.6, 0.6, 0.54), "side_tint": Vector3(0.54, 0.55, 0.5),
		"bay_size": Vector2(4.0, 4.0), "bay_tone": 0.08, "joint_dark": 0.55, "side_joint_spacing": 12.0,
		"macro_strength": 0.14, "stain": 0.7, "waterline": -6.0}},
	&"brick": {"top": &"deck", "side": &"brick", "params": {
		"desaturate": 0.25, "top_tint": Vector3(0.84, 0.83, 0.8), "side_tint": Vector3(0.6, 0.42, 0.35),
		"macro_strength": 0.08}},
	&"steel": {"top": &"plate", "side": &"plate", "params": {
		"desaturate": 0.85, "top_tint": Vector3(0.34, 0.37, 0.4), "side_tint": Vector3(0.34, 0.37, 0.4),
		"metallic_scale": 0.55, "roughness_scale": 0.85, "macro_strength": 0.05}},
	&"ochre": {"top": &"plate", "side": &"plate", "params": {
		"desaturate": 0.85, "top_tint": Vector3(0.7, 0.7, 0.7), "side_tint": Vector3(0.7, 0.7, 0.7),
		"metallic_scale": 0.65, "paint_amount": 1.0, "paint_color": Color("94692a"),
		"paint_roughness": 0.55, "macro_strength": 0.03}},
	&"glass": {"top": &"plate", "side": &"plate", "params": {
		"desaturate": 1.0, "top_tint": Vector3(0.07, 0.08, 0.09), "side_tint": Vector3(0.07, 0.08, 0.09),
		"metallic_scale": 0.0, "roughness_scale": 0.25, "specular_level": 0.6, "macro_strength": 0.15,
		"normal_strength": 0.2}},
}
## the level's material kind for pieces that are not walkable or walls, and for visual-only
## prisms (roofs, dam faces, gantries, nosings).
const KIND_LOOK := {
	&"deck": &"structure", &"landing": &"structure", &"concrete": &"structure",
	&"apron": &"old", &"pool": &"old", &"old_concrete": &"old",
	&"brick": &"brick", &"steel": &"steel", &"ochre": &"ochre",
}


## dresses a built course once and returns what it did; any other variant or the neutral
## material mode is left untouched.
static func apply(level: Node3D) -> Dictionary:
	if level.has_meta("overflow_art"):
		return level.get_meta("overflow_art")
	var report := {"version": VERSION, "applied": false}
	if str(level.get("variant")) != "course" or str(level.get("material_mode")) != "kit":
		report["reason"] = "only the kit-textured course is dressed"
		level.set_meta("overflow_art", report)
		return report
	var started := Time.get_ticks_usec()
	var pieces := _pieces(level)
	_classify_edges(pieces)
	var builder := Builder.new()
	_light(level, report)
	_reskin(level, pieces, builder, report)
	_landmarks(level, pieces, builder, report)
	_water(level, pieces, report)
	_pool_water(level, pieces, builder, report)
	builder.commit(level, report)
	_terrain(level, pieces, report)
	_runtime(level, pieces, report)
	report["applied"] = true
	report["apply_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	level.set_meta("overflow_art", report)
	return report


# --- geometry from the manifest ------------------------------------------------------------

static func _pieces(level: Node3D) -> Array:
	var pieces: Array = []
	for entry: Dictionary in level.get("manifest"):
		var points: Array = entry.get("points", [])
		if entry.get("shape", "") != "prism" or points.size() != 8:
			continue
		var top: Array[Vector3] = [points[0], points[1], points[2], points[3]]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p: Vector3 in points:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		pieces.append({"name": str(entry.name), "role": str(entry.role), "kind": StringName(entry.get("kind", &"")),
			"points": points, "top": top, "lo": lo, "hi": hi, "edges": [JOINED, JOINED, JOINED, JOINED], "feet": {}})
	return pieces


static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


static func _line_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := _flat(b) - _flat(a)
	var length := ab.length()
	if length < 1e-6:
		return (_flat(p) - _flat(a)).length()
	return absf(ab.cross(_flat(p) - _flat(a))) / length


static func _param(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := _flat(b) - _flat(a)
	return (_flat(p) - _flat(a)).dot(ab) / maxf(ab.length_squared(), 1e-12)


static func _near(a: Dictionary, b: Dictionary, margin: float) -> bool:
	return a.lo.x - margin <= b.hi.x and b.lo.x - margin <= a.hi.x and a.lo.y - margin <= b.hi.y and b.lo.y - margin <= a.hi.y


## every top edge of a walkable piece becomes free (a drop: nothing level or higher meets
## it), contact (a wall or higher deck stands on it) or joined (level deck continues).
## each wall face that stands on a walkable edge remembers that edge for its foot.
static func _classify_edges(pieces: Array) -> void:
	for piece: Dictionary in pieces:
		var walkable: bool = piece.role in WALKABLE
		for k: int in 4:
			var a: Vector3 = piece.top[k]
			var b: Vector3 = piece.top[(k + 1) % 4]
			var length := (_flat(b) - _flat(a)).length()
			if length < 1e-3:
				continue
			var cover := {"joined": 0.0, "contact": 0.0}
			var best_foot := 0.0
			for other: Dictionary in pieces:
				if other == piece or not _near(piece, other, 0.2):
					continue
				var other_walkable: bool = other.role in WALKABLE
				if not walkable and not (piece.role == "wall" and other_walkable):
					continue
				for m: int in 4:
					var c: Vector3 = other.top[m]
					var d: Vector3 = other.top[(m + 1) % 4]
					if _line_distance(c, a, b) > LINE_TOLERANCE or _line_distance(d, a, b) > LINE_TOLERANCE:
						continue
					var tc := _param(c, a, b)
					var td := _param(d, a, b)
					var lo := maxf(0.0, minf(tc, td))
					var hi := minf(1.0, maxf(tc, td))
					if (hi - lo) * length < 0.05 or absf(td - tc) < 1e-9:
						continue
					var mid := (lo + hi) * 0.5
					var own_y := lerpf(a.y, b.y, mid)
					var other_y := lerpf(c.y, d.y, (mid - tc) / (td - tc))
					if walkable:
						var dy := other_y - own_y
						if absf(dy) < 0.08:
							cover.joined += hi - lo
						elif dy > 0.0:
							cover.contact += hi - lo
					elif other_y < own_y and hi - lo > best_foot:
						# a wall face standing on this walkable edge: its foot follows that edge.
						best_foot = hi - lo
						piece.feet[k] = [c, d]
			if walkable:
				if cover.joined >= 0.5:
					piece.edges[k] = JOINED
				elif cover.contact >= 0.35:
					piece.edges[k] = CONTACT
				else:
					piece.edges[k] = FREE


# --- light, sky and air ----------------------------------------------------------------------

static func _light(level: Node3D, report: Dictionary) -> void:
	# p / a late-afternoon sun low on the left rear of the first leg: shadows rake across the
	# decks toward the right, the right-hand wall faces and the sluice house front are lit,
	# and the tail race turns into the light. warm sun against a cool sky fill keeps lit and
	# shaded planes apart in temperature as well as value.
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.62
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("c8c6b8")
	environment.fog_light_energy = 1.0
	environment.fog_sun_scatter = 0.1
	environment.fog_density = 0.0016
	environment.fog_aerial_perspective = 0.55
	environment.fog_sky_affect = 0.15
	environment.fog_height = -3.0
	environment.fog_height_density = 0.025
	var replaced := false
	for child: Node in level.get_children():
		if child is WorldEnvironment:
			(child as WorldEnvironment).environment = environment
			replaced = true
		elif child is DirectionalLight3D:
			var sun := child as DirectionalLight3D
			sun.rotation = Vector3(deg_to_rad(-31.0), deg_to_rad(-50.0), 0.0)
			sun.light_energy = 2.1
			sun.light_color = Color("ffdcb0")
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 200.0
	if not replaced:
		var world := WorldEnvironment.new()
		world.name = "ArtEnvironment"
		world.environment = environment
		level.add_child(world)
	report["environment"] = "replaced" if replaced else "added"


# --- surfaces ------------------------------------------------------------------------------

## gathers triangles per look with the per-vertex edge data, and commits one mesh per look.
class Builder:
	var tools: Dictionary = {}
	var triangles: Dictionary = {}

	func tool(look: StringName) -> SurfaceTool:
		if not tools.has(look):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[look] = st
			triangles[look] = 0
		return tools[look]

	func vertex(look: StringName, p: Vector3, n: Vector3, uv: Vector2, uv2: Vector2, flag: float) -> void:
		var st := tool(look)
		st.set_normal(n)
		st.set_uv(uv)
		st.set_uv2(uv2)
		st.set_color(Color(flag, 0.0, 0.0, 1.0))
		st.add_vertex(p)

	## an axis box in `basis` around `centre`, outward normals, no edge data.
	func box(look: StringName, centre: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
		var h := size * 0.5
		var faces := [
			[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
			[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
			[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
		]
		for face: Array in faces:
			var n: Vector3 = face[0]
			var u: Vector3 = face[1]
			var v: Vector3 = face[2]
			var c := n * h
			var du := u * h
			var dv := v * h
			var quad := [c - du - dv, c - du + dv, c + du + dv, c + du - dv]
			var wn := (basis * n).normalized()
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				var pts: Array[Vector3] = []
				for i: int in tri:
					pts.append(centre + basis * (quad[i] as Vector3))
				# godot treats clockwise as front: keep the right-hand normal pointing inward.
				if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(wn) > 0.0:
					var swap := pts[1]
					pts[1] = pts[2]
					pts[2] = swap
				for p: Vector3 in pts:
					vertex(look, p, wn, Vector2.ZERO, Vector2.ZERO, 0.0)
				triangles[look] += 1

	func commit(level: Node3D, report: Dictionary) -> void:
		var meshes := {}
		for look: StringName in tools:
			var instance := MeshInstance3D.new()
			instance.name = "Art_" + String(look)
			instance.mesh = (tools[look] as SurfaceTool).commit()
			instance.material_override = OverflowArtLooks.material(look)
			if look == &"glass":
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			level.add_child(instance)
			meshes[String(look)] = triangles[look]
		report["meshes"] = meshes
		tools.clear()


## the look materials: new ShaderMaterials over the kit's texture sets, cached per apply.
class OverflowArtLooks:
	static func material(look: StringName) -> ShaderMaterial:
		var spec: Dictionary = LOOKS[look]
		var m := ShaderMaterial.new()
		m.shader = SURFACE
		m.resource_name = "overflow_art_" + String(look)
		_bind(m, "top", spec.top)
		_bind(m, "side", spec.side)
		for key: String in spec.params:
			m.set_shader_parameter(key, spec.params[key])
		return m

	static func _bind(m: ShaderMaterial, slot: String, set_name: StringName) -> void:
		var texture_set: Dictionary = Materials.SETS[set_name]
		var base := Materials.ROOT + "textures/%s/%s_" % [texture_set.id, texture_set.id]
		m.set_shader_parameter(slot + "_albedo", load(base + "diff_1k.png"))
		m.set_shader_parameter(slot + "_normal", load(base + "nor_gl_1k.png"))
		m.set_shader_parameter(slot + "_arm", load(base + "arm_1k.png"))
		m.set_shader_parameter(slot + "_tile", Vector2.ONE * float(texture_set.metres))


static func _look_for(kind: StringName, role: String) -> StringName:
	match role:
		"route", "baffle":
			return &"land" if kind == &"landing" else &"run"
		"catch":
			return &"catch"
		"recovery":
			return &"recovery"
		"wall":
			return &"wall"
	return KIND_LOOK.get(kind, &"")


static func _key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 500.0), roundi(p.y * 500.0), roundi(p.z * 500.0))


## replaces each merged Mesh_<kind> with the same triangles regrouped by look. a triangle
## whose three corners are corners of one manifest prism of that kind takes the prism's role
## and edge data; any other triangle is visual-only and takes the kind's look. hills are
## dropped for the terrain. an unknown kind is left as the level built it.
static func _reskin(level: Node3D, pieces: Array, builder: Builder, report: Dictionary) -> void:
	var corners := {}
	for i: int in pieces.size():
		var points: Array = pieces[i].points
		for j: int in 8:
			var key := _key(points[j])
			if not corners.has(key):
				corners[key] = []
			corners[key].append(Vector2i(i, j))
	var counts := {"manifest": 0, "visual": 0, "skipped": 0}
	var kept: Array[String] = []
	for child: Node in level.get_children():
		var mi := child as MeshInstance3D
		if mi == null or not String(mi.name).begins_with("Mesh_") or mi.mesh == null:
			continue
		var kind := StringName(String(mi.name).trim_prefix("Mesh_"))
		if kind == &"hill":
			mi.visible = false
			mi.queue_free()
			continue
		if not KIND_LOOK.has(kind):
			kept.append(String(mi.name))
			continue
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := index.size() if index.size() > 0 else verts.size()
			for t: int in range(0, count, 3):
				var ids := [t, t + 1, t + 2] if index.is_empty() else [index[t], index[t + 1], index[t + 2]]
				var tri: Array[Vector3] = [verts[ids[0]], verts[ids[1]], verts[ids[2]]]
				var tri_n: Array[Vector3] = [normals[ids[0]], normals[ids[1]], normals[ids[2]]]
				var owner := _owner(tri, kind, pieces, corners)
				if owner.x < 0:
					var look: StringName = KIND_LOOK[kind]
					for v: int in 3:
						builder.vertex(look, tri[v], tri_n[v], Vector2.ZERO, Vector2.ZERO, 0.0)
					builder.triangles[look] += 1
					counts.visual += 1
					continue
				var piece: Dictionary = pieces[owner.x]
				var look := _look_for(kind, piece.role)
				_emit(builder, look, piece, tri, tri_n, owner.y)
				builder.triangles[look] += 1
				counts.manifest += 1
		mi.visible = false
		level.remove_child(mi)
		mi.queue_free()
	counts["kept_meshes"] = kept
	report["triangles"] = counts


## (piece index, face code) of the prism owning all three corners; face code 4 is the top,
## 5 the bottom, 0..3 the side under top edge k. (-1, -1) for a visual-only triangle.
static func _owner(tri: Array[Vector3], kind: StringName, pieces: Array, corners: Dictionary) -> Vector2i:
	var first: Array = corners.get(_key(tri[0]), [])
	for candidate: Vector2i in first:
		var piece: Dictionary = pieces[candidate.x]
		if piece.kind != kind:
			continue
		var slots: Array[int] = [candidate.y]
		for v: int in [1, 2]:
			var found := -1
			for other: Vector2i in corners.get(_key(tri[v]), []):
				if other.x == candidate.x:
					found = other.y
					break
			if found < 0:
				break
			slots.append(found)
		if slots.size() < 3:
			continue
		var tops := 0
		var columns := {}
		for slot: int in slots:
			tops += 1 if slot < 4 else 0
			columns[slot % 4] = true
		if tops == 3:
			return Vector2i(candidate.x, 4)
		if tops == 0:
			return Vector2i(candidate.x, 5)
		var cols: Array = columns.keys()
		if cols.size() != 2:
			return Vector2i(candidate.x, 5)
		var i: int = cols[0]
		var j: int = cols[1]
		return Vector2i(candidate.x, i if (i + 1) % 4 == j else j)
	return Vector2i(-1, -1)


static func _emit(builder: Builder, look: StringName, piece: Dictionary, tri: Array[Vector3], tri_n: Array[Vector3], face: int) -> void:
	var walkable: bool = piece.role in WALKABLE
	var top: Array[Vector3] = piece.top
	for v: int in 3:
		var p := tri[v]
		var uv := Vector2.ZERO
		var uv2 := Vector2.ZERO
		var flag := 0.0
		if face == 4 and walkable:
			flag = 1.0
			var data := PackedFloat32Array([JOINED, JOINED, JOINED, JOINED])
			var centre := (_flat(top[0]) + _flat(top[1]) + _flat(top[2]) + _flat(top[3])) * 0.25
			for k: int in 4:
				var code: float = piece.edges[k]
				if code == JOINED:
					continue
				var a := _flat(top[k])
				var b := _flat(top[(k + 1) % 4])
				var inward := (b - a).orthogonal().normalized()
				if inward.dot(centre - a) < 0.0:
					inward = -inward
				data[k] = code + (_flat(p) - a).dot(inward)
			uv = Vector2(data[0], data[1])
			uv2 = Vector2(data[2], data[3])
		elif face < 4 and walkable and piece.edges[face] == FREE:
			var a := top[face]
			var b := top[(face + 1) % 4]
			uv = Vector2(lerpf(a.y, b.y, _param(p, a, b)) - p.y, 1.0)
		elif face < 4 and piece.role == "wall" and piece.feet.has(face):
			var foot: Array = piece.feet[face]
			var c: Vector3 = foot[0]
			var d: Vector3 = foot[1]
			uv = Vector2(p.y - lerpf(c.y, d.y, _param(p, c, d)), 2.0)
		builder.vertex(look, p, tri_n[v], uv, uv2, flag)


# --- landmarks and building detail -----------------------------------------------------------

static func _piece(pieces: Array, name: String) -> Dictionary:
	for piece: Dictionary in pieces:
		if piece.name == name:
			return piece
	return {}


## flush detail on a building face: windows, a door and a string course, all within 6 cm
## of the wall (no reachable ledge), plus whatever stands on its roof.
static func _landmarks(level: Node3D, pieces: Array, builder: Builder, report: Dictionary) -> void:
	var placed: Array[String] = []
	var house := _piece(pieces, "sluice_house")
	if not house.is_empty():
		var deck := _piece(pieces, "sluice_deck")
		var floor_y: float = deck.top[0].y if not deck.is_empty() else house.lo.y
		var top_y: float = house.top[0].y
		var x0: float = house.lo.x
		var x1: float = house.hi.x
		var front: float = house.hi.y
		# a row of tall windows above the wheel panel, a door at deck level, a string course.
		var count := maxi(2, int((x1 - x0) / 5.5))
		for i: int in count:
			var x := lerpf(x0, x1, (i + 0.5) / count)
			_window(builder, Vector3(x, floor_y + 10.2, front), Vector2(1.6, 3.2), Vector3.BACK)
		_door(builder, Vector3(x0 + 3.2, floor_y, front), Vector3.BACK)
		builder.box(&"structure", Vector3((x0 + x1) * 0.5, floor_y + 8.05, front + 0.03), Vector3(x1 - x0, 0.32, 0.06))
		# p / the landmark: a brick stack rising 19 m above the roof at the house's west end,
		# capped in concrete, visible from the crest down the whole route.
		var stack := Vector3(x0 + 5.0, top_y + 0.8, house.lo.y + 3.5)
		builder.box(&"brick", stack + Vector3.UP * 9.5, Vector3(2.8, 19.0, 2.8))
		builder.box(&"structure", stack + Vector3.UP * 18.7, Vector3(3.3, 1.2, 3.3))
		builder.box(&"structure", stack + Vector3.UP * 12.0, Vector3(3.0, 0.4, 3.0))
		# a roof lantern over the wheel room.
		builder.box(&"steel", Vector3((x0 + x1) * 0.5 + 4.0, top_y + 1.6, (house.lo.y + house.hi.y) * 0.5), Vector3(9.0, 1.6, 3.4))
		placed.append("sluice_house")
	var pier_w := _piece(pieces, "outlet_pier_w")
	var pier_e := _piece(pieces, "outlet_pier_e")
	if not pier_w.is_empty() and not pier_e.is_empty():
		# p / the gate hoist: a steel portal on the outlet piers with an ochre beam and a hoist
		# housing, 9 m above the deck. the runtime hangs two cables from it to the moving gate.
		var y0: float = pier_w.top[0].y + 0.8
		var zc: float = minf(pier_w.hi.y, pier_e.hi.y) - 1.0
		var xw: float = (pier_w.lo.x + pier_w.hi.x) * 0.5
		var xe: float = (pier_e.lo.x + pier_e.hi.x) * 0.5
		for x: float in [xw, xe]:
			builder.box(&"steel", Vector3(x, y0 + 4.0, zc), Vector3(0.7, 8.0, 0.7))
			builder.box(&"steel", Vector3(x, y0 + 4.0, zc - 1.6), Vector3(0.5, 8.0, 0.5))
		builder.box(&"ochre", Vector3((xw + xe) * 0.5, y0 + 8.4, zc - 0.7), Vector3(absf(xe - xw) + 1.4, 0.8, 3.0))
		builder.box(&"steel", Vector3((xw + xe) * 0.5, y0 + 9.6, zc - 0.8), Vector3(3.0, 1.6, 2.2))
		report["hoist_beam_y"] = y0 + 8.0
		placed.append("hoist")
	var pump := _piece(pieces, "pump_house")
	if not pump.is_empty():
		# windows on the face toward the pier (its low-x face), two vents on the roof.
		var face_x: float = pump.lo.x
		var z0: float = pump.lo.y
		var z1: float = pump.hi.y
		var count := maxi(2, int((z1 - z0) / 4.0))
		for i: int in count:
			var z := lerpf(z0, z1, (i + 0.5) / count)
			_window(builder, Vector3(face_x, 11.8, z), Vector2(1.4, 2.8), Vector3.LEFT)
		builder.box(&"structure", Vector3(face_x - 0.03, 9.6, (z0 + z1) * 0.5), Vector3(0.06, 0.3, z1 - z0))
		for f: float in [0.3, 0.7]:
			builder.box(&"steel", Vector3((pump.lo.x + pump.hi.x) * 0.5, pump.top[0].y + 1.4, lerpf(z0, z1, f)), Vector3(2.2, 1.6, 2.2))
		placed.append("pump_house")
	var gate := _piece(pieces, "gatehouse")
	if not gate.is_empty():
		var face_z: float = gate.lo.y
		var base_y: float = gate.points[4].y
		var xc: float = (gate.lo.x + gate.hi.x) * 0.5
		_door(builder, Vector3(xc - 2.5, base_y, face_z), Vector3.FORWARD)
		for dx: float in [2.0, 5.0]:
			_window(builder, Vector3(xc + dx, base_y + 3.6, face_z), Vector2(1.2, 2.2), Vector3.FORWARD)
		_window(builder, Vector3(xc - 5.0, base_y + 3.6, face_z), Vector2(1.2, 2.2), Vector3.FORWARD)
		placed.append("gatehouse")
	report["landmarks"] = placed


static func _window(builder: Builder, centre: Vector3, size: Vector2, out: Vector3) -> void:
	var basis := _face_basis(out)
	builder.box(&"steel", centre + out * 0.025, Vector3(size.x + 0.24, size.y + 0.24, 0.05), basis)
	builder.box(&"glass", centre + out * 0.035, Vector3(size.x, size.y, 0.05), basis)
	# mullion and transom.
	builder.box(&"steel", centre + out * 0.05, Vector3(0.08, size.y, 0.04), basis)
	builder.box(&"steel", centre + out * 0.05 + Vector3.UP * size.y * 0.18, Vector3(size.x, 0.08, 0.04), basis)
	builder.box(&"structure", centre + out * 0.04 - Vector3.UP * (size.y * 0.5 + 0.1), Vector3(size.x + 0.4, 0.16, 0.08), basis)


static func _door(builder: Builder, foot: Vector3, out: Vector3) -> void:
	var basis := _face_basis(out)
	builder.box(&"steel", foot + out * 0.025 + Vector3.UP * 1.35, Vector3(1.5, 2.7, 0.05), basis)
	builder.box(&"ochre", foot + out * 0.04 + Vector3.UP * 1.3, Vector3(1.2, 2.5, 0.04), basis)


## basis whose +z points along `out` (a face normal), x along the face, y up.
static func _face_basis(out: Vector3) -> Basis:
	var z := out.normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Basis(x, Vector3.UP, z)


# --- water ---------------------------------------------------------------------------------

static func _water_material(params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WATER
	for key: String in params:
		m.set_shader_parameter(key, params[key])
	return m


## still bodies become dark reflective water; the dam spill and the sluice release become
## foam sheets. the spill is laid back onto the dam face it belongs to.
static func _water(level: Node3D, pieces: Array, report: Dictionary) -> void:
	var release: Variant = level.get("_release")
	var found := {"still": 0, "spill": 0, "release": 0}
	for child: Node in level.get_children():
		var mi := child as MeshInstance3D
		if mi == null or not (mi.mesh is PlaneMesh) or not (mi.material_override is ShaderMaterial):
			continue
		var old := mi.material_override as ShaderMaterial
		if old.get_shader_parameter("flow") == null:
			continue
		var plane := mi.mesh as PlaneMesh
		var flow := float(old.get_shader_parameter("flow"))
		if mi == release:
			mi.material_override = _water_material({"flow_speed": 5.5, "sheet_size": plane.size, "foam_amount": 0.7, "churn": 0.9, "aeration": 0.45})
			found.release += 1
		elif absf(flow) > 0.0:
			_lay_spill(mi, pieces, report)
			mi.material_override = _water_material({"flow_speed": 7.0, "sheet_size": (mi.mesh as PlaneMesh).size, "foam_amount": 0.8, "churn": 0.6, "aeration": 0.55})
			found.spill += 1
		else:
			var reservoir := mi.position.y > 0.0
			mi.material_override = _water_material({"ripple_scale": 9.0 if reservoir else 6.0, "ripple_strength": 0.2 if reservoir else 0.3,
				"deep": Color(0.05, 0.1, 0.11) if reservoir else Color(0.045, 0.095, 0.085)})
			found.still += 1
	report["water"] = found


static func _lay_spill(spill: MeshInstance3D, pieces: Array, report: Dictionary) -> void:
	# p / the level tilts its spill sheet the wrong way (high end downstream), so it cuts
	# through the dam face as a bright wedge. lay it on the face instead: from the crest's
	# downstream edge to the tailwater, 0.25 m proud, flowing down. visual only.
	var crest := _piece(pieces, "dam_crest_r" if spill.position.x >= 0.0 else "dam_crest_l")
	if crest.is_empty():
		report["spill"] = "left as built: no dam crest piece"
		return
	var top := Vector3(spill.position.x, crest.top[0].y, crest.lo.y)
	# the level's downstream dam face falls 29 m over 58 m from the crest's downstream edge.
	var fall := Vector3(0.0, -29.0, -58.0).normalized()
	var length := (WATER_Y + 0.4 - top.y) / fall.y
	var size := Vector2((spill.mesh as PlaneMesh).size.x, length)
	var mesh := PlaneMesh.new()
	mesh.size = size
	spill.mesh = mesh
	var normal := Vector3(0.0, -fall.z, fall.y).normalized()
	if normal.y < 0.0:
		normal = -normal
	# plane +z (uv v) runs down the face, so the foam slides with the water.
	spill.transform = Transform3D(Basis(fall.cross(normal).normalized(), normal, fall), top + fall * length * 0.5 + normal * 0.25)
	spill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	report["spill"] = "laid on the dam face, %.1f m" % length


## p / the plunge pool and the bay as working water: shallow standing water where each
## sloped catch floor is lowest (0.35 m deep at its low edge, so it covers about a metre
## and a half of floor, short of where a short jump lands), and an outfall pouring from
## each wall of the pool. the floors themselves carry the moving film in their look.
## visual only: the floors stay the walking surface and nothing here has collision.
static func _pool_water(level: Node3D, pieces: Array, builder: Builder, report: Dictionary) -> void:
	var placed: Array[String] = []
	for piece: Dictionary in pieces:
		if piece.role != "catch":
			continue
		var top: Array[Vector3] = piece.top
		var lo_y := INF
		var hi_y := -INF
		for p: Vector3 in top:
			lo_y = minf(lo_y, p.y)
			hi_y = maxf(hi_y, p.y)
		if hi_y - lo_y < 1.0:
			continue
		var y := lo_y + 0.35
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(top[i].x, top[i].z) / 10.0)
			st.add_vertex(Vector3(top[i].x, y, top[i].z))
		var standing := MeshInstance3D.new()
		standing.name = "ArtStanding_" + String(piece.name)
		standing.mesh = st.commit()
		standing.material_override = _water_material({"ripple_scale": 3.0, "ripple_strength": 0.35, "drift": 0.3,
			"deep": Color(0.07, 0.1, 0.085), "shallow": Color(0.14, 0.17, 0.13)})
		standing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(standing)
		placed.append(String(piece.name))
	var apron := _piece(pieces, "pool_apron")
	if not apron.is_empty():
		for wall_name: String in ["pool_w", "pool_e"]:
			var wall := _piece(pieces, wall_name)
			if wall.is_empty():
				continue
			# the inner face is the one nearer the apron's middle.
			var centre_x: float = (apron.lo.x + apron.hi.x) * 0.5
			var face_x: float = wall.hi.x if absf(wall.hi.x - centre_x) < absf(wall.lo.x - centre_x) else wall.lo.x
			var into := Vector3(signf(centre_x - face_x), 0.0, 0.0)
			var z: float = lerpf(wall.lo.y, wall.hi.y, 0.55)
			var floor_y := _plane_height(apron.top, face_x + into.x * 0.5, z)
			var mouth_y: float = wall.top[0].y - 1.1
			# a dark culvert mouth flush on the face, then the falling sheet 0.12 m off it.
			builder.box(&"steel", Vector3(face_x + into.x * 0.03, mouth_y + 0.15, z), Vector3(0.06, 1.3, 3.0))
			builder.box(&"glass", Vector3(face_x + into.x * 0.04, mouth_y + 0.15, z), Vector3(0.06, 1.0, 2.6))
			var drop := mouth_y - floor_y
			var sheet := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(2.4, drop)
			sheet.mesh = plane
			# plane +z (uv v) points down the face; its normal faces into the pool.
			sheet.transform = Transform3D(Basis(Vector3.DOWN.cross(into).normalized(), into, Vector3.DOWN), Vector3(face_x + into.x * 0.12, (mouth_y + floor_y) * 0.5, z))
			sheet.material_override = _water_material({"flow_speed": 6.0, "sheet_size": plane.size, "foam_amount": 0.8, "churn": 0.3, "aeration": 0.55})
			sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sheet.name = "ArtOutfall_" + wall_name
			level.add_child(sheet)
			# foam spreading where it lands, flush on the floor.
			var foam := MeshInstance3D.new()
			var foam_plane := PlaneMesh.new()
			foam_plane.size = Vector2(3.2, 3.0)
			foam.mesh = foam_plane
			var normal := _plane_normal(apron.top)
			var out := (into - normal * into.dot(normal)).normalized()
			foam.transform = Transform3D(Basis(normal.cross(out).normalized(), normal, out), Vector3(face_x + into.x * 1.6, floor_y + 0.03, z))
			foam.material_override = _water_material({"flow_speed": 1.5, "sheet_size": foam_plane.size, "foam_amount": 0.6, "churn": 0.8, "aeration": 0.2})
			foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			level.add_child(foam)
			placed.append(wall_name)
	report["pool_water"] = placed


static func _plane_normal(top: Array[Vector3]) -> Vector3:
	var n := (top[1] - top[0]).cross(top[3] - top[0]).normalized()
	return n if n.y > 0.0 else -n


## height of the plane through a top quad at (x, z).
static func _plane_height(top: Array[Vector3], x: float, z: float) -> float:
	var n := _plane_normal(top)
	return top[0].y - (n.x * (x - top[0].x) + n.z * (z - top[0].z)) / n.y


# --- terrain -------------------------------------------------------------------------------

## p / the valley: sides rise from below the tailwater well away from the course, buried
## under the dam's ends and closing beyond the sluice house. every vertex within CLEARANCE
## of a walkable or wall piece is pulled under the water, so no slope can sit within
## reach of a run whatever the course layout. no collision.
static func _terrain(level: Node3D, pieces: Array, report: Dictionary) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 1307
	noise.frequency = 1.0 / 140.0
	noise.fractal_octaves = 4
	var step := 10.0
	var x0 := -440.0
	var z0 := -600.0
	var nx := 81
	var nz := 96
	# clearance field on the grid: distance (plan) to the nearest course piece.
	var clear := PackedFloat32Array()
	clear.resize(nx * nz)
	clear.fill(1e6)
	for piece: Dictionary in pieces:
		if not (piece.role in WALKABLE or piece.role == "wall"):
			continue
		var reach := CLEARANCE + 40.0
		var i0 := clampi(int(floor((piece.lo.x - reach - x0) / step)), 0, nx - 1)
		var i1 := clampi(int(ceil((piece.hi.x + reach - x0) / step)), 0, nx - 1)
		var j0 := clampi(int(floor((piece.lo.y - reach - z0) / step)), 0, nz - 1)
		var j1 := clampi(int(ceil((piece.hi.y + reach - z0) / step)), 0, nz - 1)
		for j: int in range(j0, j1 + 1):
			for i: int in range(i0, i1 + 1):
				var p := Vector2(x0 + i * step, z0 + j * step)
				var d := Vector2(maxf(0.0, maxf(piece.lo.x - p.x, p.x - piece.hi.x)), maxf(0.0, maxf(piece.lo.y - p.y, p.y - piece.hi.y))).length()
				var k := j * nx + i
				clear[k] = minf(clear[k], d)
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	var lowest_near := -INF
	for j: int in nz:
		for i: int in nx:
			var x := x0 + i * step
			var z := z0 + j * step
			var axis := lerpf(-6.0, -38.0, smoothstep(-30.0, -230.0, z))
			var half := lerpf(66.0, 96.0, smoothstep(30.0, -200.0, z))
			var s := absf(x - axis) - half
			var h := -11.0 + 78.0 * (1.0 - exp(-maxf(s, 0.0) / 60.0))
			h += noise.get_noise_2d(x, z) * 16.0 * smoothstep(0.0, 40.0, s)
			# the valley closes in a ridge behind the sluice house.
			h = maxf(h, -11.0 + 62.0 * smoothstep(-265.0, -430.0, z) + noise.get_noise_2d(x * 1.7, z) * 8.0)
			var c := clear[j * nx + i]
			h = lerpf(minf(h, -9.5), h, smoothstep(CLEARANCE, CLEARANCE + 25.0, c))
			if c < CLEARANCE:
				lowest_near = maxf(lowest_near, h)
			heights[j * nx + i] = h
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in nz:
		for i: int in nx:
			st.add_vertex(Vector3(x0 + i * step, heights[j * nx + i], z0 + j * step))
	for j: int in nz - 1:
		for i: int in nx - 1:
			var a := j * nx + i
			# skip quads entirely under the tailwater; nothing sees them.
			if maxf(maxf(heights[a], heights[a + 1]), maxf(heights[a + nx], heights[a + nx + 1])) < WATER_Y - 1.0:
				continue
			for k: int in [a, a + 1, a + nx, a + 1, a + nx + 1, a + nx]:
				st.add_index(k)
	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "Art_terrain"
	terrain.mesh = st.commit()
	var material := ShaderMaterial.new()
	material.shader = TERRAIN
	material.set_shader_parameter("water_y", WATER_Y)
	terrain.material_override = material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(terrain)
	report["terrain"] = {"vertices": nx * nz, "max_height_within_clearance": lowest_near, "clearance_m": CLEARANCE}
	_trees(level, heights, clear, x0, z0, step, nx, nz, report)


static func _tree_mesh() -> ArrayMesh:
	# a three-tier conifer, 1 m tall at unit scale, origin at its foot; tiers overlap so the
	# silhouette is ragged rather than a single cone.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier: Array in [[0.08, 0.5, 0.36], [0.32, 0.78, 0.28], [0.56, 1.0, 0.18]]:
		var y0: float = tier[0]
		var y1: float = tier[1]
		var r: float = tier[2]
		for k: int in 7:
			var a0 := TAU * (k + y0) / 7.0
			var a1 := TAU * (k + 1 + y0) / 7.0
			var p0 := Vector3(cos(a0) * r, y0, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, y0, sin(a1) * r)
			var tip := Vector3(0, y1, 0)
			var n := (p1 - p0).cross(tip - p0).normalized()
			if n.dot(p0 + p1) < 0.0:
				n = -n
			# godot treats clockwise as front: the right-hand normal must point inward.
			var tri: Array[Vector3] = [p0, tip, p1]
			if (tip - p0).cross(p1 - p0).dot(n) > 0.0:
				tri = [p0, p1, tip]
			for p: Vector3 in tri:
				st.set_normal((n + Vector3.UP * 0.2).normalized())
				st.add_vertex(p)
	return st.commit()


static func _trees(level: Node3D, heights: PackedFloat32Array, clear: PackedFloat32Array, x0: float, z0: float, step: float, nx: int, nz: int, report: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7713
	var clump := FastNoiseLite.new()
	clump.seed = 41
	clump.frequency = 1.0 / 90.0
	var transforms: Array[Transform3D] = []
	for j: int in range(1, nz - 1):
		for i: int in range(1, nx - 1):
			var k := j * nx + i
			var h := heights[k]
			var x := x0 + i * step
			var z := z0 + j * step
			if clear[k] < CLEARANCE + 30.0 or h < -4.0 or h > 52.0 or (z > 40.0 and h < 22.0):
				continue
			var slope := maxf(absf(heights[k + 1] - heights[k - 1]), absf(heights[k + nx] - heights[k - nx])) / (2.0 * step)
			if slope > 0.75:
				continue
			var density := clump.get_noise_2d(x, z) * 0.5 + 0.5
			var tries := int(density * density * 5.0)
			for t: int in tries:
				var px := x + rng.randf_range(-step * 0.5, step * 0.5)
				var pz := z + rng.randf_range(-step * 0.5, step * 0.5)
				var fx := (px - x0) / step
				var fz := (pz - z0) / step
				var ia := clampi(int(fx), 0, nx - 2)
				var ja := clampi(int(fz), 0, nz - 2)
				var u := fx - ia
				var w := fz - ja
				var hy := lerpf(lerpf(heights[ja * nx + ia], heights[ja * nx + ia + 1], u), lerpf(heights[(ja + 1) * nx + ia], heights[(ja + 1) * nx + ia + 1], u), w)
				var size := rng.randf_range(9.0, 16.0)
				var lean := Basis(Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized(), rng.randf_range(0.0, 0.06))
				var basis := (lean * Basis(Vector3.UP, rng.randf() * TAU)).scaled(Vector3(size, size * rng.randf_range(0.9, 1.4), size))
				transforms.append(Transform3D(basis, Vector3(px, hy - 0.5, pz)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _tree_mesh()
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var trees := MultiMeshInstance3D.new()
	trees.name = "Art_trees"
	trees.multimesh = multimesh
	var material := ShaderMaterial.new()
	material.shader = TREE
	trees.material_override = material
	trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(trees)
	report["trees"] = transforms.size()


# --- the working sluice ----------------------------------------------------------------------

## follows the level's own finish state: spray at the gate while the release runs, and the
## hoist cables tracking the gate as the level lifts it. reads the level, never drives it.
class Runtime:
	extends Node3D
	var level: Node3D
	var mist: CPUParticles3D
	var cables: Array[MeshInstance3D] = []
	var beam_y := 0.0
	var overflow: MeshInstance3D
	var channel_y := 0.0

	func _process(_delta: float) -> void:
		var release: Variant = level.get("_release")
		var running := false
		if release is MeshInstance3D:
			running = (release as MeshInstance3D).visible and (release as MeshInstance3D).scale.z > 0.15
		if is_instance_valid(mist) and mist.emitting != running:
			mist.emitting = running
		var gate: Variant = level.get("_gate")
		if gate is Node3D and is_instance_valid(gate):
			# the gate plate's top edge is 3 m above the gate node (plate 8 m tall, centred 1 m below).
			var bottom := (gate as Node3D).position.y + 3.0
			for cable: MeshInstance3D in cables:
				cable.scale = Vector3(1.0, maxf(0.05, beam_y - bottom), 1.0)
				cable.position.y = (beam_y + bottom) * 0.5
			if is_instance_valid(overflow):
				# the sheet hangs from the plate's top edge down to the channel.
				overflow.visible = running
				overflow.position.y = bottom
				overflow.scale.y = maxf(0.1, bottom - channel_y)


static func _runtime(level: Node3D, pieces: Array, report: Dictionary) -> void:
	var runtime := Runtime.new()
	runtime.name = "ArtRuntime"
	runtime.level = level
	level.add_child(runtime)
	var gate: Variant = level.get("_gate")
	var release: Variant = level.get("_release")
	var parts: Array[String] = []
	if gate is Node3D and report.has("hoist_beam_y"):
		runtime.beam_y = float(report.hoist_beam_y)
		var cable_mesh := BoxMesh.new()
		cable_mesh.size = Vector3(0.07, 1.0, 0.07)
		var steel := OverflowArtLooks.material(&"steel")
		for dx: float in [-3.0, 3.0]:
			var cable := MeshInstance3D.new()
			cable.mesh = cable_mesh
			cable.material_override = steel
			cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			runtime.add_child(cable)
			cable.position = (gate as Node3D).position + Vector3(dx, 0.0, 0.0)
			runtime.cables.append(cable)
		parts.append("cables")
	if release is MeshInstance3D:
		var at: Variant = (release as MeshInstance3D).get_meta("gate_at", null)
		if at is Vector3:
			var mist := CPUParticles3D.new()
			mist.name = "GateSpray"
			mist.emitting = false
			# p / the outflow channel runs 5.5 m below the sluice deck's parapet, so the release
			# itself is out of sight from the finish; its spray rises above the parapet line.
			mist.amount = 80
			mist.lifetime = 3.0
			mist.position = (at as Vector3) + Vector3(0.0, 0.6, 1.2)
			mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			mist.emission_box_extents = Vector3(4.4, 0.3, 0.8)
			mist.direction = Vector3(0.0, 1.0, 0.45)
			mist.spread = 18.0
			mist.initial_velocity_min = 5.5
			mist.initial_velocity_max = 8.5
			mist.gravity = Vector3(0.0, -3.2, 0.0)
			mist.damping_min = 0.6
			mist.damping_max = 1.2
			mist.scale_amount_min = 1.8
			mist.scale_amount_max = 3.6
			var curve := Curve.new()
			curve.add_point(Vector2(0.0, 0.4))
			curve.add_point(Vector2(1.0, 1.0))
			mist.scale_amount_curve = curve
			var quad := QuadMesh.new()
			quad.size = Vector2(1.0, 1.0)
			var spray := StandardMaterial3D.new()
			spray.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			spray.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			spray.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			spray.albedo_color = Color(0.94, 0.95, 0.93, 0.28)
			spray.albedo_texture = _soft_dot()
			quad.material = spray
			mist.mesh = quad
			mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			runtime.add_child(mist)
			runtime.mist = mist
			parts.append("spray")
			if gate is Node3D:
				# p / the release runs 5.5 m below the finish deck's parapet, out of sight. while
				# it runs, white water also pours over the lifted plate's top edge in a curved
				# sheet, from above the parapet line down into the channel: a stylised overflow,
				# not a hydraulic model. see ART-PASS.md for the geometry alternative.
				runtime.channel_y = (at as Vector3).y
				runtime.overflow = _nappe((gate as Node3D).position, 9.4)
				runtime.add_child(runtime.overflow)
				parts.append("overflow")
	report["runtime"] = parts


## a unit-height curved sheet, 0 at its lip falling to -1, throwing 1.6 m forward (+z) as it
## falls; the runtime scales it to the actual drop. uv v runs down the sheet.
static func _nappe(at: Vector3, width: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 10
	var points: Array[Vector3] = []
	for r: int in rows + 1:
		var t := float(r) / rows
		points.append(Vector3(0.0, -t, 0.25 + 1.6 * sqrt(t)))
	for r: int in rows:
		var a := points[r]
		var b := points[r + 1]
		var quad := [Vector3(-width * 0.5, a.y, a.z), Vector3(width * 0.5, a.y, a.z), Vector3(width * 0.5, b.y, b.z), Vector3(-width * 0.5, b.y, b.z)]
		var uvs := [Vector2(0, float(r) / rows), Vector2(1, float(r) / rows), Vector2(1, float(r + 1) / rows), Vector2(0, float(r + 1) / rows)]
		var n := (b - a).cross(Vector3.RIGHT).normalized()
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uvs[i])
			st.add_vertex(quad[i])
	var sheet := MeshInstance3D.new()
	sheet.name = "GateOverflow"
	sheet.mesh = st.commit()
	sheet.material_override = _water_material({"flow_speed": 6.5, "sheet_size": Vector2(width, 8.0), "foam_amount": 0.85, "churn": 0.25, "aeration": 0.45, "foam_color": Color(0.78, 0.8, 0.78)})
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.position = at
	sheet.visible = false
	return sheet


static func _soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture

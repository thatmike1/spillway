extends RefCounted
## p / r14 practice readability: one call after Penstock Yard's build() (and after the overflow
## art pass, which leaves this map alone) separates what a runner lands on from what stops them
## and what drops them. it reads the level's manifest and changes only what is drawn:
##   - deck faces (landing and track kinds) turn a dark formwork, tops keep their light finish;
##   - pit floors and the foot of every wall go dark and damp, so the void reads as a drop;
##   - every landing lip that faces a declared gap gets a pale steel nosing;
##   - every take-off deck gets a red-oxide take-off pad: the part of the deck from which a flat
##     vanilla jump at the 250 u/s knife run carries the feet onto the next deck, behind a pale
##     start bar. a short jump from behind the bar was early; from on the pad it was slow.
## no collision body, transform, progress field, marking or geometry hash changes, and the
## pass adds no physics node. what it draws and why: docs/r14/READABILITY.md.

const Materials := preload("res://scripts/momentum_materials.gd")
const Practice := preload("res://scripts/r14_practice_level.gd")

const VERSION := 1
## p / the take-off pad's reference: the knife run every source preset reaches on the ground,
## jumping flat (vanilla jump and gravity, the level's own flight_time). feet centre to the
## landing edge with no hull credit, so the pad is the conservative side of the real window.
const REFERENCE_UPS := 250.0
## take-off group -> landing group, by piece name; a trailing "_" matches a prefix. the pump
## bend's notch is left out: run speed reaches no part of it, so its pad would be empty.
const PAIRS := [
	["s0_runin", "s1_block_1"], ["s1_block_1", "s1_block_2"], ["s1_block_2", "s1_block_3"],
	["s1_block_3", "s1_block_4"], ["s1_block_4", "s1_block_5"], ["s1_block_5", "s1_block_6"],
	["s1_block_6", "s1_block_7"], ["s1_block_7", "s1_block_8"], ["s1_block_8", "s2_island_1_"],
	["s2_island_1_", "s2_island_2_"], ["s2_island_2_", "s2_island_3_"],
	["s4_runin", "s4_middle"], ["s4_middle", "s4_runout"], ["s6_runin", "s6_platform"],
]
## p / sizes in metres: the start bar behind a pad, the nosing over a lip (top, face, standoff)
## and how far each layer floats over its deck (strips sit at 0.004, labels at 0.01).
const BAR := 0.1
const NOSE_TOP := 0.07
const NOSE_FACE := 0.14
const NOSE_OUT := 0.006
const PAD_LIFT := 0.002
const NOSE_LIFT := 0.005
## p / a lip faces its gap when its outward normal points within 60 degrees of the nearest
## take-off point; probes this far past an edge decide whether there is deck or drop beyond.
const FACING := 0.5
const PROBE := 0.3
const SEGMENTS := 48

## p / the look. faces keep the formwork scan at under half the top's value, pits and wall feet
## go damp below the waterline (pit floors at -2.5 and -4.0, the finish platform at -1.5 stays
## dry). pad, bar and nosing are pigmented finishes of the deck scan itself, not chipped paint:
## the pad a red oxide well under the top's value, bar and nosing a pale precast tone.
const FACE_TINT := Vector3(0.44, 0.45, 0.47)
const PIT_TINT := Vector3(0.36, 0.4, 0.38)
const WATERLINE := -2.1
const PAD_TINT := Vector3(0.9, 0.42, 0.33)
const PALE_TINT := Vector3(1.5, 1.49, 1.44)

static func apply(level: Node3D) -> Dictionary:
	if level.has_meta("practice_readability"):
		return level.get_meta("practice_readability")
	var report := {"version": VERSION, "applied": false}
	if level.get_script() != Practice or str(level.get("material_mode")) != "kit":
		report["reason"] = "only the kit-textured practice map is dressed"
		level.set_meta("practice_readability", report)
		return report
	var started := Time.get_ticks_usec()
	var pieces := _pieces(level)
	_retint(level, report)
	var pad := SurfaceTool.new()
	var bar := SurfaceTool.new()
	var nose := SurfaceTool.new()
	for st: SurfaceTool in [pad, bar, nose]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pads: Array = []
	var lips: Array = []
	for pair: Array in PAIRS:
		var from := _group(pieces, pair[0])
		var to := _group(pieces, pair[1])
		assert(not from.is_empty() and not to.is_empty(), "readability: missing pieces for " + str(pair))
		var drop: float = from[0].y - to[0].y
		var reach := REFERENCE_UPS * Practice.U * Practice.flight_time(drop)
		var area := 0.0
		for region: PackedVector2Array in _pad_regions(from, to, reach):
			area += _area(region)
			_flat(pad, region, from[0].y + PAD_LIFT)
			for strip: PackedVector2Array in _bars(from, region):
				_flat(bar, strip, from[0].y + PAD_LIFT)
		for piece: Dictionary in to:
			for edge: Array in _lips(piece, from, pieces, reach):
				_nosing(nose, edge[0], edge[1], edge[2], piece.y)
				lips.append(piece.name)
		pads.append({"from": pair[0], "to": pair[1], "drop_m": snappedf(drop, 0.001), "reach_m": snappedf(reach, 0.001), "pad_m2": snappedf(area, 0.01)})
	# the pad keeps the deck's 4 m bays, so its joints run on from the slab around it.
	_commit(level, "ReadabilityPads", pad, Materials.variant(&"deck", {"desaturate": 1.0, "top_tint": PAD_TINT, "bay_tone": 0.03}))
	var pale := {"desaturate": 1.0, "top_tint": PALE_TINT, "side_tint": PALE_TINT, "side": &"deck", "bay_size": Vector2.ZERO, "side_joint_spacing": 0.0, "macro_strength": 0.03}
	_commit(level, "ReadabilityBars", bar, Materials.variant(&"deck", pale))
	_commit(level, "ReadabilityNosing", nose, Materials.variant(&"deck", pale))
	report["pads"] = pads
	report["lips"] = lips
	report["applied"] = true
	report["apply_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	level.set_meta("practice_readability", report)
	return report

# --- materials on the level's own merged meshes ----------------------------------------------

static func _retint(level: Node3D, report: Dictionary) -> void:
	# the level merges every piece of a kind into Mesh_<kind>; only its material is replaced,
	# with an edit-safe variant of the same shader, so nothing new compiles on first sight.
	var changed: Array = []
	for kind: StringName in [&"landing", &"track"]:
		var look: Array = Practice.LOOK[kind]
		var params: Dictionary = (look[1] as Dictionary).duplicate()
		params["side_tint"] = FACE_TINT
		if _override(level, kind, Materials.variant(look[0], params)):
			changed.append(kind)
	var catch: Dictionary = (Practice.LOOK[&"catch"][1] as Dictionary).duplicate()
	catch["top_tint"] = PIT_TINT
	catch["waterline"] = WATERLINE
	if _override(level, &"catch", Materials.variant(Practice.LOOK[&"catch"][0], catch)):
		changed.append(&"catch")
	if _override(level, &"concrete", Materials.variant(&"concrete", {"waterline": WATERLINE})):
		changed.append(&"concrete")
	report["retinted"] = changed

static func _override(level: Node3D, kind: StringName, material: Material) -> bool:
	var mesh := level.get_node_or_null(NodePath("Mesh_" + String(kind))) as MeshInstance3D
	if mesh == null:
		return false
	mesh.material_override = material
	return true

static func _commit(level: Node3D, label: String, st: SurfaceTool, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = st.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(instance)

# --- geometry from the manifest ---------------------------------------------------------------

static func _pieces(level: Node3D) -> Array:
	# every collision piece's top as an xz polygon (counter-clockwise) with its height.
	var pieces: Array = []
	for entry: Dictionary in level.get("manifest"):
		var top := PackedVector2Array()
		var y := -INF
		var flat := true
		for i: int in 4:
			var p: Vector3 = entry.points[i]
			top.append(Vector2(p.x, p.z))
			y = maxf(y, p.y)
			flat = flat and absf(p.y - (entry.points[0] as Vector3).y) < 1e-4
		if Geometry2D.is_polygon_clockwise(top):
			top.reverse()
		pieces.append({"name": str(entry.name), "role": str(entry.role), "top": top, "y": y, "flat": flat})
	return pieces

static func _group(pieces: Array, key: String) -> Array:
	var out: Array = []
	for piece: Dictionary in pieces:
		if piece.name == key or (key.ends_with("_") and str(piece.name).begins_with(key)):
			assert(piece.flat, "readability: sloped deck " + str(piece.name))
			out.append(piece)
	return out

static func _pad_regions(from: Array, to: Array, reach: float) -> Array:
	# the take-off decks' points within `reach` of a landing deck: each landing piece grown by
	# the reach (a convex hull of circles at its corners), cut to each take-off piece, merged.
	var cuts: Array = []
	for land: Dictionary in to:
		var grown := _grown(land.top, reach)
		for start: Dictionary in from:
			for poly: PackedVector2Array in Geometry2D.intersect_polygons(start.top, grown):
				if not Geometry2D.is_polygon_clockwise(poly) and _area(poly) > 1e-4:
					cuts.append(poly)
	return _union(cuts)

static func _grown(poly: PackedVector2Array, r: float) -> PackedVector2Array:
	var cloud := PackedVector2Array()
	for p: Vector2 in poly:
		for k: int in SEGMENTS:
			cloud.append(p + Vector2.from_angle(TAU * k / SEGMENTS) * r)
	var hull := Geometry2D.convex_hull(cloud)
	hull.remove_at(hull.size() - 1)
	return hull

static func _union(polys: Array) -> Array:
	# merges touching pieces (ring islands share exact chords) so one pad has one outline.
	var out: Array = []
	for poly: PackedVector2Array in polys:
		var current := poly
		var i := 0
		while i < out.size():
			var merged := Geometry2D.merge_polygons(current, out[i])
			if merged.size() == 1:
				current = merged[0]
				out.remove_at(i)
				i = 0
			else:
				i += 1
		out.append(current)
	return out

static func _bars(from: Array, region: PackedVector2Array) -> Array:
	# the start bar: a band just behind the pad's open side, on the take-off deck only. where the
	# pad meets the deck's own edges there is nothing behind it, so no bar is drawn there.
	var strips: Array = []
	var grown := Geometry2D.offset_polygon(region, BAR, Geometry2D.JOIN_ROUND)
	for halo: PackedVector2Array in grown:
		if Geometry2D.is_polygon_clockwise(halo):
			continue
		for start: Dictionary in from:
			for ring: PackedVector2Array in Geometry2D.intersect_polygons(halo, start.top):
				for strip: PackedVector2Array in Geometry2D.clip_polygons(ring, region):
					if not Geometry2D.is_polygon_clockwise(strip) and _area(strip) > 1e-4:
						strips.append(strip)
	return strips

static func _lips(piece: Dictionary, from: Array, pieces: Array, reach: float) -> Array:
	# a landing piece's edges with a drop beyond them that face the take-off decks.
	var edges: Array = []
	var top: PackedVector2Array = piece.top
	for i: int in top.size():
		var a := top[i]
		var b := top[(i + 1) % top.size()]
		var mid := (a + b) * 0.5
		var out := (b - a).orthogonal().normalized()
		if not Geometry2D.is_point_in_polygon(mid - out * 0.01, top):
			out = -out
		if _covered(mid + out * PROBE, piece.y, pieces):
			continue
		# judged where the edge comes closest to a take-off deck: slanted gauges are wide at one end.
		var gap := INF
		var toward := Vector2.ZERO
		for k: int in 9:
			var p := a.lerp(b, k / 8.0)
			for start: Dictionary in from:
				var q := _closest(start.top, p)
				if q.distance_to(p) < gap:
					gap = q.distance_to(p)
					toward = (q - p).normalized()
		if gap > reach + 1.0 or out.dot(toward) < FACING:
			continue
		edges.append([a, b, out])
	return edges

static func _covered(p: Vector2, y: float, pieces: Array) -> bool:
	for piece: Dictionary in pieces:
		if piece.y >= y - 0.1 and Geometry2D.is_point_in_polygon(p, piece.top):
			return true
	return false

static func _closest(poly: PackedVector2Array, p: Vector2) -> Vector2:
	var best := Vector2.INF
	for i: int in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		if q.distance_to(p) < best.distance_to(p):
			best = q
	return best

static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i: int in poly.size():
		sum += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(sum) * 0.5

# --- meshes ------------------------------------------------------------------------------------

static func _flat(st: SurfaceTool, poly: PackedVector2Array, y: float) -> void:
	# a flush polygon facing up (godot fronts are clockwise seen from the front).
	var indices := Geometry2D.triangulate_polygon(poly)
	for t: int in range(0, indices.size(), 3):
		var tri: Array[Vector3] = []
		for k: int in 3:
			var p := poly[indices[t + k]]
			tri.append(Vector3(p.x, y, p.y))
		if (tri[1] - tri[0]).cross(tri[2] - tri[0]).y > 0.0:
			tri.reverse()
		for v: Vector3 in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)

static func _nosing(st: SurfaceTool, a: Vector2, b: Vector2, out: Vector2, y: float) -> void:
	# an angle over the lip: NOSE_TOP onto the deck, NOSE_FACE down the face, standing NOSE_OUT
	# proud of both so it never fights the deck. a box whose hidden faces are skipped.
	var o := Vector3(out.x, 0.0, out.y)
	var a3 := Vector3(a.x, y, a.y)
	var b3 := Vector3(b.x, y, b.y)
	var inner := -o * NOSE_TOP
	var proud := o * NOSE_OUT
	var top := Vector3.UP * NOSE_LIFT
	var low := Vector3.DOWN * NOSE_FACE
	_quad(st, [a3 + inner + top, b3 + inner + top, b3 + proud + top, a3 + proud + top], Vector3.UP)
	_quad(st, [a3 + proud + top, b3 + proud + top, b3 + proud + low, a3 + proud + low], o)
	_quad(st, [a3 + inner + low, b3 + inner + low, b3 + proud + low, a3 + proud + low], Vector3.DOWN)

static func _quad(st: SurfaceTool, quad: Array, normal: Vector3) -> void:
	for tri: Array in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector3 = quad[tri[0]]
		var b: Vector3 = quad[tri[1]]
		var c: Vector3 = quad[tri[2]]
		if (b - a).cross(c - a).dot(normal) > 0.0:
			var swap := b
			b = c
			c = swap
		for v: Vector3 in [a, b, c]:
			st.set_normal(normal)
			st.add_vertex(v)

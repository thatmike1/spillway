extends RefCounted
## through line, look c only: the two runs stand as two monumental plinths in open water, with
## the launch channel cut between them, so nothing reads as a slab hanging in a void. the fork
## and its 250 u/s arc stay orange (the shared layer would paint them cream), the example arcs
## become thin dashed lines instead of cubes in the sky, instruction text leaves the world (the
## hud already carries it) and the two remaining signs, 02 and OUTFLOW, hang from structure.
## no node here collides; plinths stay inset under the real decks and below their undersides,
## so no visual ledge appears beside a landing. l off restores every label exactly.

const SURFACE := preload("res://shaders/look/surface.gdshader")
const WATER := preload("res://shaders/look/water.gdshader")
## shell-white decks instead of the practice palette's khaki.
const PALETTE := {"top": "f8f3e6", "side": "4f6a70"}
## sea level, 7 m below first run and 10 m below second run.
const SEA_Y := -3.0
const FOOT_Y := -8.0
## how far plinths sit inside each deck's edge, so the deck slab keeps its own lip and shadow line.
const INSET := 0.5
const ORANGE := Color("d95b30")
const CREAM := Color("f4eddc")
const INK := Color("263d45")
const STONE_SIDE := Color("4f6a70")
const STONE_TOP := Color("8fa09c")
## the level's own paint colours, used to recognise its pieces (duplicate node names get renamed).
const LEVEL_ORANGE := Color("b5683c")
const LEVEL_DARK := Color("29464a")

var _stone: ShaderMaterial
var _ink: StandardMaterial3D
var _dots: Array[Node3D] = []
## label path -> [text, pixel_size] with l on; the originals are read back from the level.
const SIGNS := {"Sign_start": ["", 0.0], "Sign_gate": ["", 0.0], "Sign_second": ["02", 0.03], "Sign_finish": ["OUTFLOW", 0.02]}
var _labels: Array[Dictionary] = []

func material(_key: String, node: GeometryInstance3D, proposed: Material) -> Material:
	var old := node.material_override as StandardMaterial3D
	if old == null:
		return proposed
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh and ((node as MeshInstance3D).mesh as BoxMesh).size.is_equal_approx(Vector3.ONE * 0.2):
		# example-arc cubes: hidden with l on, replaced by the dashed lines in dress().
		_dots.append(node)
		return proposed
	if old.albedo_color.is_equal_approx(LEVEL_ORANGE):
		return _flat(ORANGE)
	if old.albedo_color.is_equal_approx(LEVEL_DARK):
		return _flat(INK)
	return proposed

func dress(level: Node3D) -> Node3D:
	var root := Node3D.new()
	_stone = ShaderMaterial.new()
	_stone.shader = SURFACE
	_stone.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
	_stone.set_shader_parameter("top_color", STONE_TOP)
	_stone.set_shader_parameter("side_color", STONE_SIDE)
	_stone.set_shader_parameter("wear_amount", 0.22)
	_ink = _flat(INK)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	sea.mesh = plane
	sea.position = Vector3(0, SEA_Y, -60)
	var water := ShaderMaterial.new()
	water.shader = WATER
	sea.material_override = water
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sea)
	# the plinths follow the real deck pieces' footprints and undersides from the manifest.
	for run: String in ["first_run", "second_start", "second_run"]:
		var box := _footprint(level, run)
		if box.size == Vector3.ZERO:
			continue
		var top := box.position.y - 0.02
		var x0 := box.position.x + INSET
		var x1 := box.end.x - INSET
		var z0 := box.position.z + INSET
		var z1 := box.end.z - INSET
		_block(root, "Plinth_" + run, Vector3((x0 + x1) * 0.5, (top + FOOT_Y) * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, top - FOOT_Y, z1 - z0), _stone)
	# the paired towers stand just beyond second start's sides; each gets its own pier to the sea.
	for side: float in [-1.0, 1.0]:
		_block(root, "TowerPier_%d" % int(side), Vector3(side * 24.8, (7.0 + FOOT_Y) * 0.5, -59), Vector3(1.0, 7.0 - FOOT_Y, 2.0), _stone)
	# the 02 hangs from the dark header between the towers.
	for x: float in [-1.6, 1.6]:
		_block(root, "HeaderHanger_%s" % x, Vector3(x, 15.3, -59), Vector3(0.05, 1.3, 0.05), _ink)
	# OUTFLOW hangs from a gantry whose legs stand at second run's far corners, beyond the finish.
	for side: float in [-1.0, 1.0]:
		_block(root, "OutflowLeg_%d" % int(side), Vector3(side * 19.4, 10.0, -141.6), Vector3(0.5, 6.0, 0.5), _ink)
	_block(root, "OutflowBeam", Vector3(0, 13.1, -141.6), Vector3(39.3, 0.4, 0.5), _ink)
	for x: float in [-2.6, 2.6]:
		_block(root, "OutflowHanger_%s" % x, Vector3(x, 12.25, -140.05), Vector3(0.05, 1.3, 0.05), _ink)
	# the finish band's near edge, painted flush on second run.
	var finish: AABB = level.get("finish_bounds")
	_block(root, "FinishLine", Vector3(0, 7.006, finish.end.z), Vector3(39.6, 0.012, 0.18), _ink)
	_arcs(root)
	for path: String in SIGNS:
		var label := level.get_node_or_null(path) as Label3D
		if label != null:
			_labels.append({"node": label, "text": label.text, "pixel": label.pixel_size, "on": SIGNS[path]})
	return root

func set_enabled(value: bool) -> void:
	for dot: Node3D in _dots:
		if is_instance_valid(dot):
			dot.visible = not value
	for entry: Dictionary in _labels:
		var label := entry.node as Label3D
		if not is_instance_valid(label):
			continue
		var on: Array = entry.on
		label.visible = not value or not str(on[0]).is_empty()
		label.text = str(on[0]) if value and not str(on[0]).is_empty() else str(entry.text)
		label.pixel_size = float(on[1]) if value and not str(on[0]).is_empty() else float(entry.pixel)

func _arcs(root: Node3D) -> void:
	# the level's two example flights (same formula as r20_through_level.gd), drawn as dashes.
	for speed: float in [250.0, 500.0]:
		var up := (420.0 + 0.7 * speed) * 0.0254
		var g := 800.0 * 0.0254
		var t_land := (up + sqrt(up * up - 2.0 * g * 3.0)) / g
		var x := -0.7 if speed == 250.0 else 0.7
		var material := _flat(ORANGE if speed == 250.0 else CREAM)
		var points: Array[Vector3] = []
		for i: int in range(1, 19):
			var t := t_land * float(i) / 18.0
			points.append(Vector3(x, 4.0 + up * t - 0.5 * g * t * t, -40.0 - speed * 0.0254 * t))
		for i: int in points.size() - 1:
			var a := points[i].lerp(points[i + 1], 0.2)
			var b := points[i].lerp(points[i + 1], 0.8)
			# past the channel the arc stops above head height, so no dash crosses a runner's view of the court.
			if b.z < -47.0 and minf(a.y, b.y) < 7.0 + 2.4:
				continue
			var dash := MeshInstance3D.new()
			dash.name = "ArcDash_%d_%d" % [int(speed), i]
			var tube := CylinderMesh.new()
			tube.top_radius = 0.045
			tube.bottom_radius = 0.045
			tube.height = a.distance_to(b)
			tube.radial_segments = 6
			tube.rings = 1
			dash.mesh = tube
			dash.material_override = material
			dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dash.transform = Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())), (a + b) * 0.5)
			root.add_child(dash)

func _footprint(level: Node3D, run: String) -> AABB:
	# the union of a run's deck pieces (named <run>_<ix>_<iz>), top face down to its underside.
	var box := AABB()
	var first := true
	for piece: Dictionary in level.get("manifest"):
		if not str(piece.name).begins_with(run + "_"):
			continue
		for p: Vector3 in piece.points:
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box

func _block(root: Node3D, id: String, at: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	root.add_child(node)

func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m

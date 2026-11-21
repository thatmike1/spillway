extends RefCounted
## whiteout relay, look C only: a radar station on a snow ridge. pale decks, weathered teal
## barriers and buildings instead of navy, and one landmark: the big dish on the far peak, with
## the receiver dish rising out of its pit near the end. the scattered plateau dishes, small
## sheds, loose machines and the pines crowding the road hide while L is on. reachable props
## (named Prop_*) are never touched: their collision is the level's. the hangar at spawn gets a
## steel portal frame (columns and roof beams every 6 m), a dark dado band round its walls and a
## frame round the door, so the first room reads as a built hall. nothing here collides; the
## columns stand 0.12 m proud of the walls, inside the runner's 0.30 m radius.

## decks in the pale shell family, a step below the shared value: the snow-country sun clipped
## e6e2d8 to white on the road. the sand top of the old palette read warmer than any other map.
## nudged warm so the road and the hangar floor read as one deck family out of the door.
const PALETTE := {"top": "d6cdc3", "side": "4f7880"}
## the hangar floor sits under warm lamps, out of the sun: a light warm stone so it reads as the
## pale deck family indoors instead of mauve-grey. art meshes are named Mesh_<kind>_<region>.
const FLOORS := {"tread_warm_hangar": {"top_color": "ddd5ca"}}
## every art face: weathering as tall streaks, not chips (high wear read as camouflage spots).
const WEATHER := {"wear_amount": 0.04, "streak_amount": 0.18}
## plateau dishes and small buildings that repeat the landmark at toy scale.
const FILLER := ["satelliteDish", "satelliteDish_detailed", "hangar_smallA", "machine_generator", "machine_generatorLarge", "machine_wireless", "supports_high"]

var _hidden: Array[Node3D] = []

func dress(level: Node3D) -> Node3D:
	var k: Dictionary = (level.get_script() as Script).get_script_constant_map()
	var receiver: Vector3 = k.RECEIVER
	for child: Node in level.get_children():
		if not child is Node3D or str(child.name).begins_with("Prop_") or not child.has_meta("r15_asset"):
			continue
		var wrapper := child as Node3D
		var asset := str(wrapper.get_meta("r15_asset")).get_file().get_basename()
		var p := wrapper.position
		var hide := asset in FILLER
		if asset == "satelliteDish_large":
			# keep the far landmark and the receiver; the plateau copies go.
			var landmark := p.y > 30.0
			var at_receiver := Vector2(p.x - receiver.x, p.z - receiver.z).length() < 4.0
			hide = not (landmark or at_receiver)
		elif asset.begins_with("tree_pine"):
			# pines stay only as far stands well off the road and the works.
			hide = absf(p.x) < 45.0
		if hide:
			_hidden.append(wrapper)
	# figures on decks and walls are teaching text; the station-name banner in the hangar too.
	var marks := level.get_node_or_null("Markings")
	if marks != null:
		for label: Node in marks.get_children():
			if not label is Label3D:
				continue
			var label_name := str(label.name)
			if not label_name.begins_with("Sign_") or label_name.begins_with("Sign_WHITEOUT"):
				_hidden.append(label as Node3D)
	return _hangar(k)

## columns and beams at these z, from the back wall toward the door.
const FRAMES := [13.4, 7.5, 1.5, -4.5, -10.5]
const PROUD := 0.12

func _hangar(k: Dictionary) -> Node3D:
	var h: float = k.HANGAR_HALF
	var back: float = k.HANGAR_BACK
	var front: float = k.HANGAR_FRONT
	var roof: float = k.HANGAR_ROOF
	var door: float = k.DOOR_HALF
	var y0: float = k.TRACK_Y
	var steel := SurfaceTool.new()
	steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dado := SurfaceTool.new()
	dado.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: float in FRAMES:
		for side: float in [-1.0, 1.0]:
			var x := h * side
			_box(steel, Vector3(minf(x, x - PROUD * side), y0, z - 0.22), Vector3(maxf(x, x - PROUD * side), roof, z + 0.22))
		_box(steel, Vector3(-h, roof - 0.65, z - 0.18), Vector3(h, roof, z + 0.18))
	# the door frame sits on the front wall's inner face and the lintel, never in the opening.
	for side: float in [-1.0, 1.0]:
		_box(steel, Vector3(minf(door * side, (door + 0.45) * side), y0, front), Vector3(maxf(door * side, (door + 0.45) * side), 6.45, front + PROUD))
	_box(steel, Vector3(-door - 0.45, 6.0, front), Vector3(door + 0.45, 6.45, front + PROUD))
	# a dark dado band, 1.1 m high, round the back, both sides and the front beside the door.
	var band := 1.1
	_box(dado, Vector3(-h, y0, back - 0.04), Vector3(h, y0 + band, back))
	for side: float in [-1.0, 1.0]:
		var x := h * side
		_box(dado, Vector3(minf(x, x - 0.04 * side), y0, front), Vector3(maxf(x, x - 0.04 * side), y0 + band, back))
		_box(dado, Vector3(minf(door * side, x), y0, front), Vector3(maxf(door * side, x), y0 + band, front + 0.04))
	var root := Node3D.new()
	root.name = "HangarFrame"
	for pair: Array in [[steel, "393f45", "Steel"], [dado, "4f5d61", "Dado"]]:
		var mesh := MeshInstance3D.new()
		mesh.name = pair[2]
		mesh.mesh = (pair[0] as SurfaceTool).commit()
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(pair[1])
		paint.roughness = 0.8
		mesh.material_override = paint
		root.add_child(mesh)
	return root

func _box(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	# a closed box with outward flat normals.
	var faces := [
		[Vector3.UP, [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]],
		[Vector3.DOWN, [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z)]],
		[Vector3.LEFT, [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, lo.y, hi.z)]],
		[Vector3.RIGHT, [Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z)]],
		[Vector3.FORWARD, [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z)]],
		[Vector3.BACK, [Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z)]],
	]
	for face: Array in faces:
		var n: Vector3 = face[0]
		var q: Array = face[1]
		for tri: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			# godot fronts are clockwise seen from outside.
			var a: Vector3 = tri[0]
			var b: Vector3 = tri[1]
			var c: Vector3 = tri[2]
			if (b - a).cross(c - a).dot(n) > 0.0:
				var t := b
				b = c
				c = t
			for v: Vector3 in [a, b, c]:
				st.set_normal(n)
				st.add_vertex(v)

## the shared look builds one material per art mesh; this sets weathering and the hangar floor in place.
func material(key: String, _node: Node, proposed: Material) -> Material:
	var kind := key.trim_prefix("Mesh_")
	if proposed is ShaderMaterial and key.begins_with("Mesh_") and (proposed as ShaderMaterial).get_shader_parameter("wear_amount") != null:
		for parameter: String in WEATHER:
			(proposed as ShaderMaterial).set_shader_parameter(parameter, WEATHER[parameter])
	if proposed is ShaderMaterial and FLOORS.has(kind):
		for parameter: String in FLOORS[kind]:
			var value: Variant = FLOORS[kind][parameter]
			(proposed as ShaderMaterial).set_shader_parameter(parameter, Color(value) if value is String else value)
	return proposed

func set_enabled(value: bool) -> void:
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = not value

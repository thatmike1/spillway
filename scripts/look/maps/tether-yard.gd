extends RefCounted
## design 1121 look override for Tether Yard, loaded by the shared r17 look layer (L on only).
## presentation only: no collision, nothing enters manifest/art_manifest, anchors stay where they are.

const RING := Color("d2683a")
const STEEL := Color("29464a")
const CARRIAGE := Color("e0d6bf")
const PIER := Color("5b7378")
const GLASS := Color("22363c")
const COURT_TOP := -5.0
## shell tops and weathered blue-grey sides instead of the shared practice palette's khaki.
const PALETTE := {"top": "f6ead0", "side": "6d8388"}

var _labels: Array[Label3D] = []
var _concrete: ShaderMaterial

func material(key: String, node: GeometryInstance3D, proposed: Material) -> Material:
	# the shared layer paints every Art_paint mesh cream; the swing rings must stay signal vermilion.
	if key == "Art_paint_orange_anchor":
		var paint := StandardMaterial3D.new()
		paint.albedo_color = RING
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return paint
	# the shared water tiles visibly at this basin's scale; the crane dock's quiet sea does not.
	if key == "Water":
		var sea := ShaderMaterial.new()
		sea.shader = preload("res://assets/maps/gantry/water.gdshader")
		# seen from a few metres up, the dock's fine ripple bands read as wood grain; broaden and soften them.
		sea.set_shader_parameter("swell_scale", 0.4)
		sea.set_shader_parameter("ripple_mix", 0.3)
		return sea
	# transfer decks share the rope courses' cast concrete: runoff wear, no joint grid, so the only lines
	# on a landing are its real edges. tops render well below their albedo under this basin's light, so the top is set near white.
	if key.begins_with("Mesh_deck_transfer"):
		if _concrete == null:
			_concrete = ShaderMaterial.new()
			_concrete.shader = preload("res://assets/maps/gantry/concrete.gdshader")
			_concrete.set_shader_parameter("top_color", Color("faf3e2"))
			_concrete.set_shader_parameter("side_color", Color("6d8388"))
			_concrete.set_shader_parameter("wear_color", Color("9a9c8c"))
			_concrete.set_shader_parameter("wear", preload("res://assets/look/painted-wear.png"))
			_concrete.set_shader_parameter("wear_amount", 0.45)
			_concrete.set_shader_parameter("deck", 0.0)
			_concrete.set_shader_parameter("waterline", -8.0)
			_concrete.set_shader_parameter("weather", 1.0)
		return _concrete
	return proposed

func dress(level: Node3D) -> Node3D:
	var root := Node3D.new()
	var steel := _material(STEEL)
	var pale := _material(CARRIAGE)
	var pier := _material(PIER)
	# each lifting frame reads as a fabricated portal strong enough to carry a person.
	for i: int in level.ANCHORS.size():
		var at: Vector3 = level.ANCHORS[i]
		var frame := Node3D.new()
		frame.name = "Frame%d" % i
		root.add_child(frame)
		_box(frame, "beam", at + Vector3(0, 1.15, 0), Vector3(23.0, 0.75, 0.7), steel)
		for side: float in [-11.0, 11.0]:
			var x := at.x + side
			_box(frame, "post_%s" % side, Vector3(x, (COURT_TOP + at.y + 1.5) * 0.5, at.z), Vector3(0.7, at.y + 1.5 - COURT_TOP, 0.7), steel)
			_box(frame, "foot_%s" % side, Vector3(x, COURT_TOP + 0.3, at.z), Vector3(1.6, 0.6, 1.6), pier)
			var knee := _box(frame, "knee_%s" % side, Vector3(at.x + side * 0.86, at.y - 0.35, at.z), Vector3(0.26, 3.6, 0.26), steel)
			knee.rotation.z = signf(side) * PI * 0.25
		# a pale lifting carriage wraps the dark beam above the ring, so it reads as a trolley at distance
		# rather than a lamp sitting on top.
		_box(frame, "carriage", at + Vector3(0, 1.15, 0), Vector3(2.2, 1.1, 1.0), pale)
		_box(frame, "strap", at + Vector3(0, 0.42, 0), Vector3(0.3, 0.45, 0.26), steel)
	# every transfer deck stands on paired piers that reach the court floor, inset under the slab.
	# the live entry is the r19/r20 level (every deck at 4 m); the newer module adds DECK_HEIGHTS.
	var heights: Variant = []
	var script := level.get_script() as Script
	while script != null and heights is Array and (heights as Array).is_empty():
		heights = script.get_script_constant_map().get("DECK_HEIGHTS", [])
		script = script.get_base_script()
	for i: int in level.DECKS.size():
		var d: Array = level.DECKS[i]
		var top: float = (float(heights[i]) if heights is Array and i < heights.size() else 4.0) - 0.8
		var height := top - COURT_TOP
		for x: float in [float(d[0]) + 1.2, float(d[1]) - 1.2]:
			for z: float in [float(d[2]) + 1.4, float(d[3]) - 1.4]:
				_box(root, "pier_%d_%s_%s" % [i, x, z], Vector3(x, COURT_TOP + height * 0.5, z), Vector3(1.0, height, 1.2), pier)
		_box(root, "bearer_%d_far" % i, Vector3((float(d[0]) + float(d[1])) * 0.5, top - 0.3, float(d[2]) + 1.4), Vector3(float(d[1]) - float(d[0]) - 1.6, 0.6, 0.9), pier)
		_box(root, "bearer_%d_near" % i, Vector3((float(d[0]) + float(d[1])) * 0.5, top - 0.3, float(d[3]) - 1.4), Vector3(float(d[1]) - float(d[0]) - 1.6, 0.6, 0.9), pier)
	# every receiving deck shows its landing edge in vermilion, on the top and down its near face.
	var paint := StandardMaterial3D.new()
	paint.albedo_color = RING
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i: int in range(1, level.DECKS.size()):
		var d: Array = level.DECKS[i]
		var h: float = (float(heights[i]) if heights is Array and i < heights.size() else 4.0)
		var width := float(d[1]) - float(d[0])
		var cx := (float(d[0]) + float(d[1])) * 0.5
		var near := float(d[3])
		var top_band := _box(root, "receiver_%d" % i, Vector3(cx, h + 0.008, near - 0.25), Vector3(width, 0.014, 0.45), paint)
		top_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var face := _box(root, "receiver_face_%d" % i, Vector3(cx, h - 0.15, near + 0.015), Vector3(width, 0.28, 0.025), paint)
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# control text leaves the world with L on; the HUD already carries the same hints.
	_labels.clear()
	for label: Node in level.find_children("Sign_*", "Label3D", true, false):
		_labels.append(label as Label3D)
	set_enabled(true)
	return root

func set_enabled(value: bool) -> void:
	for label: Label3D in _labels:
		if is_instance_valid(label):
			label.visible = not value

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://assets/maps/gantry/outline.gdshader")
	material.next_pass = ink
	return material

static func _box(parent: Node3D, id: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = id
	node.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	return node

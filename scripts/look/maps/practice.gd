extends RefCounted
## penstock yard, look c only. the yard is named for the water it trains along: the dam's
## penstock now runs as one continuous pipe from the dam face, over the end of the stop-log
## blocks, through the valve tower and along the north side of the penstock straight to a
## powerhouse beside the weirs, on piers that stand in the tailwater. decks go shell-white with
## landings a step paler than run decks, pits go dark, take-off pads go quiet, and painted
## figures leave the world while l is on (l off brings every label back).
## nothing here collides. the pipe crosses the course only above 6.9 m, over the end of the
## blocks, where a hop peaks under 1.5 m; every pier stands outside the training walls.

const SURFACE := preload("res://shaders/look/surface.gdshader")
const PALETTE := {"top": "d8cfc1", "side": "4c6468"}
## run decks a step below the landings, pits and walls weathered and darker than any deck.
## the dam's 1:1.2 face is steep enough to count as a walkable slope for the shared shader; it
## stays a weathered side here instead of a second pale deck the size of the sky.
const SURFACES := {
	"track": {"top_color": "d4cbbd"},
	"landing": {"top_color": "ddd4c6"},
	"catch": {"top_color": "52665f", "side_color": "3d5254"},
	"return": {"top_color": "8d9a90"},
	"concrete": {"side_color": "5d7375", "wear_amount": 0.05, "top_from": 0.65, "top_full": 0.8},
	"old_concrete": {"side_color": "4a5f60", "wear_amount": 0.07},
	"brick": {"top_color": "a9b2a8", "side_color": "6f7f7a", "wear_amount": 0.1},
}
## the pipe: one line at z, from the dam face east to the powerhouse west, centre height and radius.
const PIPE_Z := -77.0
const PIPE_EAST := 48.0
const PIPE_WEST := -197.0
const PIPE_Y := 8.5
const PIPE_R := 1.6
const WATER_Y := -8.0
## piers outside the training walls; none between x -14 and 10, where the pipe spans the course.
const PIERS := [40.0, 26.0, 12.0, -40.0, -56.0, -72.0, -88.0, -104.0, -120.0, -136.0, -152.0, -168.0, -184.0]
const VALVE_TOWER_X := -21.0

var _labels: Array[Label3D] = []

func material(key: String, _node: GeometryInstance3D, proposed: Material) -> Material:
	if key == "ReadabilityPads":
		# the take-off window stays visible as a faint warm-grey field, not a mauve slab.
		return _flat(Color("d6cbb6"), true)
	return proposed

func dress(level: Node3D) -> Node3D:
	var root := Node3D.new()
	var steel := _surface(Color("7f918d"), Color("a9b5b0"), 0.06)
	var stone := _surface(Color("5b7072"), Color("98a39c"), 0.08)
	# the pipe, in sections with stiffening rings, so it reads as a riveted penstock.
	var length := PIPE_EAST - PIPE_WEST
	_cylinder_x(root, "Penstock", Vector3((PIPE_EAST + PIPE_WEST) * 0.5, PIPE_Y, PIPE_Z), PIPE_R, length, steel)
	var x := PIPE_EAST - 6.0
	while x > PIPE_WEST + 2.0:
		if absf(x - VALVE_TOWER_X) > 4.0:
			_cylinder_x(root, "PenstockRing_%d" % int(x), Vector3(x, PIPE_Y, PIPE_Z), PIPE_R + 0.12, 0.35, steel)
		x -= 8.0
	# piers from the tailwater, each with a saddle under the pipe.
	for px: float in PIERS:
		var top := PIPE_Y - PIPE_R + 0.15
		_box(root, "PenstockPier_%d" % int(px), Vector3(px, (top - 0.6 + WATER_Y) * 0.5, PIPE_Z), Vector3(1.6, top - 0.6 - WATER_Y, 3.6), stone)
		_box(root, "PenstockSaddle_%d" % int(px), Vector3(px, top - 0.3, PIPE_Z), Vector3(2.0, 0.6, 3.9), stone)
	# where the pipe meets the dam face, an anchor block; at its west end, the powerhouse.
	_box(root, "DamAnchor", Vector3(PIPE_EAST + 1.0, (PIPE_Y + 2.6 + WATER_Y) * 0.5, PIPE_Z), Vector3(6.0, PIPE_Y + 2.6 - WATER_Y, 6.5), stone)
	var house_x := PIPE_WEST - 10.0
	_box(root, "Powerhouse", Vector3(house_x, (13.0 + WATER_Y) * 0.5, -77.0), Vector3(20.0, 13.0 - WATER_Y, 20.0), stone)
	_box(root, "PowerhouseRoof", Vector3(house_x, 13.25, -77.0), Vector3(21.0, 0.5, 21.0), _surface(Color("3e5356"), Color("c9c6b6"), 0.15))
	for i: int in 3:
		_box(root, "PowerhouseWindow_%d" % i, Vector3(PIPE_WEST - 0.04, 9.5, -83.0 + i * 6.0), Vector3(0.1, 4.5, 2.4), _flat(Color("2f4447")))
	for label: Node in level.find_children("*", "Label3D", true, false):
		if str(level.get_path_to(label)).begins_with("Markings"):
			_labels.append(label)
	return root

func set_enabled(value: bool) -> void:
	for label: Label3D in _labels:
		if is_instance_valid(label):
			label.visible = not value

func _surface(side: Color, top: Color, wear: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
	m.set_shader_parameter("top_color", top)
	m.set_shader_parameter("side_color", side)
	m.set_shader_parameter("wear_amount", wear)
	return m

func _box(root: Node3D, id: String, at: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	root.add_child(node)

func _cylinder_x(root: Node3D, id: String, at: Vector3, radius: float, length: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = id
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 20
	mesh.rings = 1
	node.mesh = mesh
	node.position = at
	node.rotation = Vector3(0, 0, PI * 0.5)
	node.material_override = material
	root.add_child(node)

func _flat(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

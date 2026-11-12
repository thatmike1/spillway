extends Node3D
## saltglass: high entries, rising crescent, flat exits and open water below the fins.

const GEO := preload("res://scripts/r19_course_geometry.gd")
const LEVEL_ID := "r21-saltglass"
const LEVEL_NAME := "Saltglass"
const LEVEL_VERSION := 3
const MAP_ID := "saltglass"
const MAP_ENTRY := {"name": LEVEL_NAME, "theme": "Low exits, climbing salt pans and outside lines", "kind": "course", "script": "res://scripts/r21_surf_level.gd"}
var level_id := LEVEL_ID
var level_name := LEVEL_NAME
var level_version := LEVEL_VERSION
var variant := "saltglass"
var spawn := Transform3D(Basis.IDENTITY, Vector3(9.7, 15.54, 16))
var finish_title := "Salt house"
var finish_position := Vector3(310, 4, 38)
var finish_radius := 4.0
var finish_bounds := AABB(Vector3(300, 3.7, 27), Vector3(22, 4, 22))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var progress_roles: Array = ["route"]
var kill_bounds := AABB(Vector3(-40, -11, -240), Vector3(430, 80, 420))
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var mechanics: Array = []
var manifest: Array[Dictionary] = []
var prisms: Array[Dictionary] = []
var jump_gaps: Array[Dictionary] = []
var routes: Dictionary = {}
var _built := false

func build() -> void:
	if _built:
		return
	_built = true
	# p / entry decks at 86.1% of the 18 m crest; both first contacts must exceed 80%.
	GEO.deck(self, "headrace", 6, 16, 0, 24, 15.5, 0)
	_fin("west", Transform3D.IDENTITY, 0)
	# p / lower flat supports are beyond the fin end, never beneath its face.
	GEO.deck(self, "west_landing", -16, 20, -197, -173, 7, 1)
	# p / nine ascending pans preserve the high second entry after the low fling.
	for i: int in 9:
		var x := 4.0 + 13.0 * i
		GEO.deck(self, "crescent_%d" % i, x, x + 11.5, -224, -200, 7.9 + 0.9 * i, 1)
	GEO.deck(self, "east_headrace", 108, 142, -206, -168, 15.5, 2)
	_fin("east", Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(132, 0, -168)), 2)
	GEO.deck(self, "east_landing", 112, 148, 5, 29, 7, 3)
	# p / a working salt quay has broken pans and a tall store, with water outside.
	for i: int in 9:
		var x := 128.0 + 19.0 * i
		GEO.deck(self, "salt_step_%d" % i, x, x + 16, 32, 54, 6.5 - 0.3 * i, 3)
	# the inland quay links the pans; its narrow necks stop short of the outside edge.
	for i: int in range(1, 9):
		var x := 128.0 + 19.0 * i
		GEO.deck(self, "quay_neck_%d" % i, x - 3, x, 32, 44, 6.8 - 0.3 * i, 3)
	GEO.deck(self, "outside_lip", 220, 223, 49, 54, 5.0, 3)
	GEO.deck(self, "house_neck", 296, 300, 32, 44, 4.1, 3)
	GEO.deck(self, "salt_house", 300, 322, 27, 64, 4, 3)
	# the store's south face ends at the quay edge. outside it there is only sea.
	GEO.prism(self, "salt_store", GEO.rectangle(215, 220, 40, 54, 11.3), 5.3, 3, "obstacle", "warehouse")
	_gap("crescent_first", Vector3(12, 7, -197), Vector3(12, 7.9, -200))
	for i: int in range(1, 9):
		var x := 4.0 + 13.0 * i
		_gap("crescent_%d" % i, Vector3(x - 1.5, 7.0 + 0.9 * i, -212), Vector3(x, 7.9 + 0.9 * i, -212))
	_gap("salt_first", Vector3(138, 7, 29), Vector3(138, 6.5, 32))
	for i: int in range(1, 9):
		var x := 128.0 + 19.0 * i
		_gap("salt_%d" % i, Vector3(x - 3, 6.8 - 0.3 * i, 53), Vector3(x, 6.5 - 0.3 * i, 53))
	_gap("salt_house", Vector3(296, 4.1, 53), Vector3(310, 4, 53))
	_define_progress()
	_environment()
	_sign("title", Vector3(10, 19, 24), PI, "SALTGLASS\nHIGH FINS / RISING CRESCENT / SALT STEPS", 0.006)
	_sign("surf_entry", Vector3(15, 20, 2), 0.0, "SURF\nA / D INTO THE FACE\nLET THE FIN CARRY YOU TO THE LOW DECK", 0.005)
	_sign("crescent", Vector3(120, 20, -236), 0, "CRESCENT\nCLIMB THROUGH THE HOPS", 0.007)
	_dressing()
	_sign("salt_house", Vector3(322, 8, 38), -PI * 0.5, "SALT HOUSE\nFINISH", 0.009)

func _fin(id: String, pose: Transform3D, stage: int) -> void:
	# p / 168 m fin; each 21 m prism stays below 32 m in every dimension.
	# p / 2 cm downhill seam relief is geometry, never a collision-law override.
	for i: int in 8:
		var a := -21.0 * i
		var b := -21.0 * (i + 1)
		var drop := 0.02 * i
		var top: Array[Vector3] = [pose * Vector3(0, -drop, a), pose * Vector3(12, 18 - drop, a), pose * Vector3(12, 18 - drop, b), pose * Vector3(0, -drop, b)]
		GEO.prism(self, "Surf_%s_%d" % [id, i], top, -5, stage, "surf", "steel_ramp")

func _define_progress() -> void:
	checkpoints = [
		{"pose": spawn, "title": "West fin", "bounds": AABB(Vector3(6, 15.2, 12), Vector3(10, 4, 12))},
		{"pose": Transform3D(Basis.IDENTITY, Vector3(6, 7.04, -194)), "title": "Climbing salt pans", "bounds": AABB(Vector3(-16, 6.7, -197), Vector3(36, 10, 24))},
		{"pose": Transform3D(Basis(Vector3.UP, PI), Vector3(122.3, 15.54, -178)), "title": "East fin", "bounds": AABB(Vector3(108, 15.2, -206), Vector3(34, 5, 38))},
		{"pose": Transform3D(Basis(Vector3.UP, PI), Vector3(126, 7.04, 26)), "title": "Salt quay", "bounds": AABB(Vector3(112, 6.7, 5), Vector3(36, 10, 24))},
	]
	routes = {"basic": [spawn.origin, Vector3(9.7, 15.5, 0), Vector3(5.3, 7.8, -168), Vector3(6, 7, -194), Vector3(12, 7.9, -222), Vector3(108, 15.1, -222), Vector3(122.3, 15.5, -178), Vector3(126.7, 7.8, 0), Vector3(126, 7, 26), Vector3(138, 6.5, 53), Vector3(205, 5.6, 47), Vector3(234, 5.3, 47), finish_position]}
	routes["outside"] = [Vector3(205, 5.6, 61), Vector3(212, 5.6, 63), Vector3(219, 7, 67), Vector3(231, 5.3, 63)]

func route_hint(stage: int, _feet: Vector3) -> String:
	match stage:
		0:
			return "Enter high, then let the fin carry you low and long to the flat deck. Water below."
		1:
			return "Link the climbing salt pans to the high east headrace. Every rise needs a clean hop."
		2:
			return "D presses into the east fin too. Spend speed on distance to the lower flat deck."
	return "The store splits the quay: broad inland landings, or a precise outside curve over water."

func is_finish_at(feet: Vector3) -> bool:
	return finish_bounds.has_point(feet)

func geometry_hash() -> String:
	var data: Array = ["centred-convex-v1"]
	for piece: Dictionary in manifest:
		var points: Array = []
		for p: Vector3 in piece.points:
			points.append([p.x, p.y, p.z])
		data.append([piece.name, piece.stage, piece.role, piece.kind, points])
	# progress and finish volumes belong to the same identity as every solid.
	for point: Dictionary in checkpoints:
		var bounds: AABB = point.bounds
		data.append([point.title, _v(point.pose.origin), _v(bounds.position), _v(bounds.size)])
	data.append([LEVEL_ID, LEVEL_VERSION, _v(spawn.origin), _v(finish_position), _v(finish_bounds.position), _v(finish_bounds.size), _v(kill_bounds.position), _v(kill_bounds.size)])
	return JSON.stringify(data, "", false, true).sha256_text()

func _gap(id: String, edge: Vector3, land: Vector3) -> void:
	jump_gaps.append({"label": id, "edge": edge, "land": land, "recovery": "fall and respawn at last checkpoint"})

func _environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b7cacc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bdd0ce")
	env.ambient_light_energy = 0.5
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -110, 0)
	sun.light_color = Color("fff0d2")
	sun.light_energy = 0.7
	add_child(sun)
	var sea := MeshInstance3D.new()
	sea.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	sea.mesh = plane
	sea.position = Vector3(0, -7, -40)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("789f9c")
	material.roughness = 0.9
	sea.material_override = material
	add_child(sea)

func _sign(id: String, at: Vector3, yaw: float, text: String, pixels: float) -> void:
	var label := Label3D.new()
	label.name = "Sign_" + id
	label.position = at
	label.rotation.y = yaw
	label.text = text
	label.font_size = 48
	label.pixel_size = pixels
	label.modulate = Color("263d45")
	label.outline_size = 0
	add_child(label)

func _line(id: String, a: Vector3, b: Vector3, color: Color, radius: float) -> void:
	var node := MeshInstance3D.new()
	node.name = "Art_paint_dark_" + id
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	node.mesh = mesh
	node.position = (a + b) * 0.5
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP).normalized()
	var forward := side.cross(axis).normalized()
	node.basis = Basis(side, axis, forward)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	add_child(node)

static func _v(p: Vector3) -> Array:
	return [p.x, p.y, p.z]

func _dressing() -> void:
	# original primitive pump housings, evaporation racks and mooring poles; no collision.
	for i: int in 9:
		var x := 14.0 + 13.0 * i
		_art_box("pan_pump_%d" % i, Vector3(x, 9.2 + 0.9 * i, -232), Vector3(2.4, 2.2, 2), Color("657f81"))
	for i: int in 12:
		_art_box("water_post_%d" % i, Vector3(150 + 14 * i, -3, 76), Vector3(0.7, 10, 0.7), Color("586b6b"))
	for i: int in 5:
		_art_box("store_louvre_%d" % i, Vector3(218.5, 7.5 + i * 0.55, 54.03), Vector3(5, 0.12, 0.1), Color("263d45"))
	_art_box("salt_house_roof", Vector3(314, 9, 58), Vector3(12, 0.4, 9), Color("657f81"))
	for x: float in [308.5, 319.5]:
		_art_box("house_column_%s" % x, Vector3(x, 6.5, 60), Vector3(0.3, 5, 0.3), Color("657f81"))

func _art_box(id: String, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = "Art_" + id
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	node.material_override = material
	add_child(node)

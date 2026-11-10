extends Node3D
## saltglass: high entries, rising crescent, flat exits and open water below the fins.

const GEO := preload("res://scripts/r19_course_geometry.gd")
const LEVEL_ID := "r20-saltglass"
const LEVEL_NAME := "Saltglass"
const LEVEL_VERSION := 2
const MAP_ID := "saltglass"
const MAP_ENTRY := {"name": LEVEL_NAME, "theme": "High fins, rising crescent and salt steps", "kind": "course", "script": "res://scripts/r20_surf_level.gd"}
var level_id := LEVEL_ID
var level_name := LEVEL_NAME
var level_version := LEVEL_VERSION
var variant := "saltglass"
var spawn := Transform3D(Basis.IDENTITY, Vector3(9.7, 15.54, 16))
var finish_title := "Salt house"
var finish_position := Vector3(220, 11, 39)
var finish_radius := 4.0
var finish_bounds := AABB(Vector3(210, 10.7, 29), Vector3(20, 4, 20))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var progress_roles: Array = ["route"]
var kill_bounds := AABB(Vector3(-40, -11, -240), Vector3(384, 80, 320))
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
	GEO.deck(self, "west_landing", -10, 20, -186, -168, 14, 1)
	# p / three 0.5 m rises, then the 15.5 m east headrace. no recovery court.
	for i: int in 3:
		var x := 2.0 + 24.0 * i
		GEO.deck(self, "crescent_%d" % i, x, x + 22, -210, -188, 14.5 + 0.5 * i, 1)
	GEO.deck(self, "east_headrace", 60, 94, -186, -168, 15.5, 2)
	_fin("east", Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(84, 0, -168)), 2)
	GEO.deck(self, "east_landing", 64, 94, 0, 22, 14, 3)
	# p / the tail heads away from spawn. the old stage-3 bridge behind spawn is absent.
	for i: int in 6:
		var x := 72.0 + 24.0 * i
		var z := 24.0 if i % 2 == 0 else 30.0
		GEO.deck(self, "salt_step_%d" % i, x, x + 23.5, z, z + 22, 13.5 - 0.5 * i, 3)
	_gap("crescent_first", Vector3(10, 14, -186), Vector3(10, 14.5, -188))
	for i: int in range(1, 3):
		var x := 2.0 + 24.0 * i
		_gap("crescent_%d" % i, Vector3(x - 2, 14.0 + 0.5 * i, -199), Vector3(x, 14.5 + 0.5 * i, -199))
	_gap("east_headrace", Vector3(66, 15.5, -188), Vector3(66, 15.5, -186))
	_gap("salt_first", Vector3(84, 14, 22), Vector3(84, 13.5, 24))
	for i: int in range(1, 6):
		var x := 72.0 + 24.0 * i
		_gap("salt_%d" % i, Vector3(x - 0.5, 14.0 - 0.5 * i, 38), Vector3(x, 13.5 - 0.5 * i, 38))
	_define_progress()
	_environment()
	_sign("title", Vector3(10, 19, 24), PI, "SALTGLASS\nHIGH FINS / RISING CRESCENT / SALT STEPS", 0.006)
	_sign("surf_entry", Vector3(15, 20, 2), 0.0, "SURF\nA / D INTO THE FACE\nKEEP HEIGHT FOR THE FLAT EXIT", 0.005)
	_sign("crescent", Vector3(80, 18, -212), 0, "CRESCENT\nCLIMB THROUGH THE HOPS", 0.007)
	_sign("salt_house", Vector3(230, 15, 39), -PI * 0.5, "SALT HOUSE\nFINISH", 0.009)

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
		{"pose": Transform3D(Basis.IDENTITY, Vector3(6, 14.04, -176)), "title": "Rising crescent", "bounds": AABB(Vector3(-10, 13.7, -186), Vector3(30, 8, 18))},
		{"pose": Transform3D(Basis(Vector3.UP, PI), Vector3(74.3, 15.54, -178)), "title": "East fin", "bounds": AABB(Vector3(60, 15.2, -186), Vector3(34, 5, 18))},
		{"pose": Transform3D(Basis(Vector3.UP, PI), Vector3(78, 14.04, 10)), "title": "Salt steps", "bounds": AABB(Vector3(64, 13.7, 0), Vector3(30, 9, 22))},
	]
	routes = {"basic": [spawn.origin, Vector3(9.7, 15.5, 0), Vector3(10, 15.5, -168), Vector3(6, 14, -176), Vector3(10, 14.5, -199), Vector3(60, 15.5, -199), Vector3(74.3, 15.5, -178), Vector3(74.3, 15.5, -168), Vector3(74, 15.5, 0), Vector3(78, 14, 10), Vector3(84, 13.5, 35), finish_position]}
	routes["advanced"] = routes.basic

func route_hint(stage: int, _feet: Vector3) -> String:
	match stage:
		0:
			return "Enter high. Release W and press D into the west fin. Keep height for the flat exit. A miss falls to your last checkpoint."
		1:
			return "The crescent climbs. Link the raised hop islands to the high east headrace."
		2:
			return "D presses into the east fin too. Carry the face to its flat landing; there is no lower return."
	return "Link the salt steps away from the start to the salt house."

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
	plane.size = Vector2(600, 600)
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

extends Node3D
## saltglass: open, paired steep fins with a descending bhop crescent between them.

const GEO := preload("res://scripts/r19_course_geometry.gd")
const LEVEL_ID := "r19-saltglass"
const LEVEL_NAME := "Saltglass"
const LEVEL_VERSION := 1
const MAP_ID := "saltglass"
const MAP_ENTRY := {"name": LEVEL_NAME, "theme": "Steep spillway fins and descending hop islands", "kind": "course", "script": "res://scripts/r19_surf_level.gd"}
var level_id := LEVEL_ID
var level_name := LEVEL_NAME
var level_version := LEVEL_VERSION
var variant := "saltglass"
var spawn := Transform3D(Basis.IDENTITY, Vector3(2, 6.04, 16))
var finish_title := "Salt house"
var finish_position := Vector3(-67, 4.5, 39)
var finish_radius := 4.0
var finish_bounds := AABB(Vector3(-76, 4.2, 29), Vector3(17, 4, 20))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var progress_roles: Array = ["route"]
var kill_bounds := AABB(Vector3(-100, -11, -150), Vector3(190, 70, 225))
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
	GEO.deck(self, "headrace", -2, 10, 0, 18, 6, 0)
	_fin("west", Transform3D.IDENTITY, 0)
	# wide terraces make the reversal legible before the surf exit, with four real gaps.
	GEO.deck(self, "west_landing", -12, 16, -104, -92, 10, 1)
	_exit_ramp("west_exit", -12, 16, -84, -92, 1)
	GEO.deck(self, "crescent_west", -2, 16, -126, -106, 8.5, 1)
	GEO.deck(self, "crescent_centre", 18, 38, -126, -106, 7.5, 1)
	GEO.deck(self, "crescent_east", 40, 64, -126, -106, 6.5, 1)
	GEO.deck(self, "east_headrace", 48, 66, -104, -84, 6, 2)
	_fin("east", Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(60, 0, -84)), 2)
	GEO.deck(self, "east_landing", 44, 72, 8, 20, 10, 3)
	_exit_ramp("east_exit", 44, 72, 0, 8, 3)
	var xs := [42.0, 18.0, -6.0, -30.0, -54.0, -78.0]
	for i: int in xs.size():
		var x: float = xs[i]
		var z := 20.0 if i % 2 == 0 else 28.0
		var y := 9.5 - i
		GEO.deck(self, "salt_step_%d" % i, x, x + 22.0, z, z + 22.0, y, 3)
		if i > 0:
			_gap("salt_gap_%d" % i, Vector3(x + 24, y + 1, 35), Vector3(x + 22, y, 35))
	# catch courts are physical lower routes, with walkable ramps back to the terraces.
	_recovery_court("crescent", -4, 66, -140, -82, 1.5, Vector3(62, 6.5, -126), Vector3(62, 1.5, -138))
	_recovery_court("salt", -80, 66, 18, 64, 0.0, Vector3(-74, 4.5, 50), Vector3(-74, 0, 62))
	_define_progress()
	_environment()
	_sign("title", Vector3(2, 9, 18), PI, "SALTGLASS\nWEST FIN / CRESCENT / EAST FIN / SALT STEPS", 0.006)
	_sign("surf_entry", Vector3(7, 10, 2), 0.0, "SURF\nA / D INTO THE FACE\nTURN TO TRADE HEIGHT FOR SPEED", 0.005)
	_sign("crescent", Vector3(28, 11, -128), 0, "CRESCENT\nKEEP THE HOPS CONNECTED", 0.007)
	_sign("salt_house", Vector3(-76, 8, 39), PI * 0.5, "SALT HOUSE\nFINISH", 0.009)
	_gap("crescent_drop", Vector3(6, 10, -104), Vector3(6, 8.5, -106))
	_gap("crescent_middle", Vector3(16, 8.5, -116), Vector3(18, 7.5, -116))
	_gap("crescent_east", Vector3(38, 7.5, -116), Vector3(40, 6.5, -116))
	_gap("east_entry", Vector3(58, 6.5, -106), Vector3(58, 6, -104))

func _fin(id: String, pose: Transform3D, stage: int) -> void:
	# four 21 m convex prisms, a 56.3099 degree face, no assist or trigger.
	# a 2 cm downhill step hides each incoming end face below the outgoing face.
	for i: int in 4:
		var a := -21.0 * i
		var b := -21.0 * (i + 1)
		var drop := 0.02 * i
		var top: Array[Vector3] = [pose * Vector3(0, -drop, a), pose * Vector3(12, 18 - drop, a), pose * Vector3(12, 18 - drop, b), pose * Vector3(0, -drop, b)]
		GEO.prism(self, "Surf_%s_%d" % [id, i], top, -5, stage, "surf", "steel_ramp")
		# the low-side catch stays below the surf face. it offers a walkable way forward.
		var z0 := minf((pose * Vector3(0, 0, a)).z, (pose * Vector3(0, 0, b)).z)
		var z1 := maxf((pose * Vector3(0, 0, a)).z, (pose * Vector3(0, 0, b)).z)
		var x0 := -12.0 if id == "west" else 60.0
		GEO.deck(self, "catch_%s_%d" % [id, i], x0, x0 + 12, z0, z1, -4, stage, "recovery")
	# a 28 m walkable incline connects the low-side catch to the exit ramp.
	var ramp: Array[Vector3] = [pose * Vector3(-12, -4, -56), pose * Vector3(-2, -4, -56), pose * Vector3(-2, 6, -84), pose * Vector3(-12, 6, -84)]
	GEO.prism(self, "return_%s" % id, ramp, -5, stage, "recovery", "recovery")
	for i: int in 3:
		# thin structural ink follows the crest, without collision.
		var start := pose * Vector3(12.01, 18.02, -28.0 * i)
		var end := pose * Vector3(12.01, 18.02, -28.0 * (i + 1))
		_line("crest_%s_%d" % [id, i], start, end, Color("263d45"), 0.025)

func _exit_ramp(id: String, x0: float, x1: float, entry_z: float, exit_z: float, stage: int) -> void:
	# a low mouth catches the faster, lower surf line; the walkable rise joins the hop deck.
	var top: Array[Vector3] = [Vector3(x0, 6, entry_z), Vector3(x1, 6, entry_z), Vector3(x1, 10, exit_z), Vector3(x0, 10, exit_z)]
	GEO.prism(self, id, top, 5.2, stage, "route", "steel_ramp")

func _recovery_court(id: String, x0: float, x1: float, z0: float, z1: float, y: float, high: Vector3, low: Vector3) -> void:
	GEO.deck(self, "catch_" + id, x0, x1, z0, z1, y, -1, "recovery")
	var top: Array[Vector3] = [low + Vector3(-3, 0, 0), low + Vector3(3, 0, 0), high + Vector3(3, 0, 0), high + Vector3(-3, 0, 0)]
	GEO.prism(self, "return_" + id, top, y - 0.8, -1, "recovery", "recovery")

func _define_progress() -> void:
	checkpoints = [
		{"pose": spawn, "title": "West fin", "bounds": AABB(Vector3(-2, 5.8, 12), Vector3(12, 4, 12))},
		{"pose": Transform3D(Basis.IDENTITY, Vector3(6, 10.04, -92)), "title": "Crescent", "bounds": AABB(Vector3(-12, 9.7, -104), Vector3(28, 8, 12))},
		{"pose": Transform3D(Basis(Vector3.UP, PI), Vector3(58, 6.04, -98)), "title": "East fin", "bounds": AABB(Vector3(48, 5.7, -104), Vector3(18, 5, 20))},
		{"pose": Transform3D(Basis(Vector3.UP, PI), Vector3(54, 10.04, 8)), "title": "Salt steps", "bounds": AABB(Vector3(44, 9.7, 8), Vector3(28, 9, 12))},
	]
	finish_position.y = 4.5
	routes = {"basic": [Vector3(2, 6, 0), Vector3(7, 11, -84), Vector3(6, 10, -96), Vector3(7, 8.5, -116), Vector3(28, 7.5, -116), Vector3(56, 6.5, -116), Vector3(58, 6, -94), Vector3(53, 11, 0), Vector3(54, 10, 12), Vector3(54, 9.5, 32), Vector3(30, 8.5, 39), Vector3(6, 7.5, 32), Vector3(-18, 6.5, 39), Vector3(-42, 5.5, 32), finish_position]}
	routes["advanced"] = routes.basic

func route_hint(stage: int, _feet: Vector3) -> String:
	match stage:
		0:
			return "Run off the headrace, release W and press D into the west fin. Turn away slightly to trade height for speed."
		1:
			return "Carry the exit into the descending crescent hops, then turn back toward the east fin. Lower catch courts have return ramps."
		2:
			return "D presses into the east fin too. Keep enough height for its low exit mouth, then carry speed onto the salt steps."
	return "Link the descending hop islands to the salt house. Orange lips mark the gaps; the low court has a walkable return."

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
	jump_gaps.append({"label": id, "edge": edge, "land": land, "recovery": "catch court and marked return ramp"})

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

extends Node3D
## p / two compact authored segments coexist; the gate ends the first and the raised court starts the second.
const GEO := preload("res://scripts/r19_course_geometry.gd")
const RUNNER := preload("res://scripts/r20_through_player.gd")
const MAP_ID := "through-line"
const MAP_ENTRY := {"name": "Through Line", "theme": "Build speed, rise through the fork, land running", "kind": "experiment", "experimental": true,
	"script": "res://scripts/r20_through_level.gd", "runner": "res://scripts/r20_through_player.gd", "key_hint": " · Forward through the raised fork at 230+ u/s",
	"instructions": "EXPERIMENTAL · bhop down First Run. Cross the tall orange fork forward at 230+ u/s: horizontal speed carries unchanged; more speed gives more lift. Air-strafe onto Second Run's raised cream court, then keep moving to its far finish. One launch per attempt; R resets. Dotted arcs are 250 / 500 u/s examples, not steering assistance."}
var level_id := "r20-through-line"
var level_name := "Through Line"
var level_version := 1
var variant := MAP_ID
var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 4.04, 12))
var finish_title := "Second Run outflow"
var finish_position := Vector3(0, 7, -133)
var finish_radius := 4.0
var finish_bounds := AABB(Vector3(-20, 6.8, -140), Vector3(40, 4, 9))
var kill_bounds := AABB(Vector3(-70, -18, -180), Vector3(140, 110, 210))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var progress_roles: Array = ["route"]
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var mechanics: Array = [RUNNER.LAW]
var manifest: Array[Dictionary] = []
var prisms: Array[Dictionary] = []
var art_manifest: Array = []
var jump_gaps: Array[Dictionary] = []
var routes: Dictionary = {}
var _built := false

func build() -> void:
	if _built:
		return
	_built = true
	GEO.deck(self, "first_run", -8, 8, -42, 18, 4, 0)
	# a broad elevated start receives both slow and fast flights; it is real collision from scene creation.
	GEO.deck(self, "second_start", -24, 24, -110, -47, 7, 1)
	GEO.deck(self, "second_run", -20, 20, -142, -110, 7, 1)
	checkpoints = [{"pose": spawn, "title": "First Run", "bounds": AABB(Vector3(-8, 3.8, -42), Vector3(16, 4.2, 60))},
		{"pose": Transform3D(Basis.IDENTITY, Vector3(0, 7.04, -51)), "title": "Second Run", "bounds": AABB(Vector3(-24, 6.8, -110), Vector3(48, 0.5, 63))}]
	segment_bounds = [checkpoints[0].bounds, AABB(Vector3(-24, 6.8, -142), Vector3(48, 5, 95))]
	# heavy open fork: posts and upward-pointing fins, no collision in the movement aperture.
	for side: float in [-1.0, 1.0]:
		_box("paint_orange_fork_post", Vector3(side * 5.4, 7, -40), Vector3(0.7, 6, 1.1), Color("b5683c"))
		var fin := _box("paint_orange_fork_fin", Vector3(side * 6.1, 10.0, -40), Vector3(0.6, 3.0, 1.1), Color("b5683c"))
		fin.rotation.z = side * -0.45
		art_manifest.append(["fork_fin_rotation", fin.rotation])
		_box("paint_dark_fork_foot", Vector3(side * 5.4, 4.25, -40), Vector3(2.2, 0.5, 3), Color("29464a"))
		# tall paired towers and a roof establish the destination above the empty gap.
		_box("paint_dark_second_tower", Vector3(side * 24.8, 11, -59), Vector3(1, 8, 2), Color("29464a"))
		_box("paint_orange_second_beacon", Vector3(side * 24.8, 15.5, -59), Vector3(1.3, 1, 2.3), Color("b5683c"))
	_box("paint_dark_second_header", Vector3(0, 16.2, -59), Vector3(50.6, 0.55, 1), Color("29464a"))
	_sign("second", Vector3(0, 14, -59), "02 / SECOND RUN\nLAND ON THE CREAM COURT", 0.009)
	_sign("gate", Vector3(0, 11.7, -40), "RISE\nSPEED BECOMES HEIGHT", 0.006)
	_sign("start", Vector3(-6, 7, 3), "01 / FIRST RUN\nBHOP INTO THE FORK\n230+ u/s / FORWARD", 0.006)
	_sign("finish", Vector3(0, 11, -140), "OUTFLOW\nKEEP RUNNING", 0.008)
	for speed: float in [250.0, 500.0]:
		var up := (420.0 + 0.7 * speed) * 0.0254
		var t_land := (up + sqrt(up * up - 2.0 * 800.0 * 0.0254 * 3.0)) / (800.0 * 0.0254)
		for i: int in range(1, 19):
			var t := t_land * float(i) / 18.0
			var at := Vector3(-0.7 if speed == 250.0 else 0.7, 4.0 + up * t - 0.5 * 800.0 * 0.0254 * t * t, -40.0 - speed * 0.0254 * t)
			_box("paint_orange_trajectory" if speed == 250.0 else "paint_cream_trajectory", at, Vector3.ONE * 0.20, Color("b5683c") if speed == 250.0 else Color("f1ead8"))
		_box("paint_orange_landing_example", Vector3(0, 7.04, -40.0 - speed * 0.0254 * t_land), Vector3(6, 0.06, 0.3), Color("b5683c"))
	_environment()
	routes = {"basic": [spawn.origin, Vector3(0, 4, -40), Vector3(0, 7, -60), finish_position]}
	routes["advanced"] = routes.basic

func route_hint(stage: int, _feet: Vector3) -> String:
	return "Bhop forward through the raised fork. 230+ u/s earns lift; dotted arcs show two example speeds." if stage == 0 else "Second Run is already here. Land on its broad cream court, carry your speed, and run under the far OUTFLOW sign."

func is_finish_at(feet: Vector3) -> bool:
	return finish_bounds.has_point(feet)

func geometry_hash() -> String:
	return var_to_str([level_id, level_version, RUNNER.LAW, manifest, art_manifest, checkpoints, spawn, finish_bounds, kill_bounds]).sha256_text()

func _box(id: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Art_" + id
	node.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	node.material_override = material
	add_child(node)
	art_manifest.append([id, at, size, color])
	return node

func _sign(id: String, at: Vector3, text: String, pixels: float) -> void:
	var label := Label3D.new()
	label.name = "Sign_" + id
	label.position = at
	label.text = text
	label.font_size = 48
	label.pixel_size = pixels
	label.modulate = Color("263d45")
	label.outline_size = 0
	add_child(label)
	art_manifest.append([id, at, text, pixels])

func _environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b7cacc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bdd0ce")
	env.ambient_light_energy = 0.6
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_energy = 1.3
	add_child(sun)

extends Node3D
## the postal quay: one supported seawall, three delivery courts and a sorting arch.
const MATERIAL := preload("res://scripts/art/mail_material.gd")
const GEO := preload("res://scripts/r19_course_geometry.gd")
const MAP_ID := "mail-run"
const MAP_ENTRY := {"name": "Mail Run", "theme": "Hold the hop. Steer the post.", "kind": "experiment", "experimental": true, "mail_delivery": true,
	"runner": "res://scripts/movement/mail_runner.gd", "script": "res://scripts/maps/mail_run.gd", "reticle": true,
	"instructions": "F2 bhop. LMB throws; mouse steers the envelope while your body is held. RMB recalls. Deliveries are optional score. V switches envelope/body view and restarts."}
var level_id := "r22-mail-run"
var level_name := "Mail Run"
var level_version := 2
var variant := MAP_ID
var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 2.04, 12))
var finish_title := "Dispatch"
var finish_position := Vector3(0, 2, -130)
var finish_radius := 3.0
var finish_bounds := AABB(Vector3(-6, 1.8, -134), Vector3(12, 4, 8))
var kill_bounds := AABB(Vector3(-50, -8, -150), Vector3(100, 60, 180))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var progress_roles: Array = ["route"]
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var mechanics: Array = ["mail-flight-1", "body-hold", "optional-delivery"]
var manifest: Array[Dictionary] = []
var prisms: Array[Dictionary] = []
var art_manifest: Array = []
var jump_gaps: Array[Dictionary] = []
var routes: Dictionary = {}
var mailboxes: Array = []
var _built := false

func build() -> void:
	if _built:
		return
	_built = true
	for stage: int in 4:
		var end := 16.0 - stage * 38.0
		GEO.deck(self, "quay_%d" % stage, -6, 6, end - 38, end, 2, stage)
		var bounds := AABB(Vector3(-6, 1.8, end - 38), Vector3(12, 3, 38))
		checkpoints.append({"pose": Transform3D(Basis.IDENTITY, Vector3(0, 2.04, end - 3)), "title": ["Outbox", "East post", "West post", "Dispatch"][stage], "bounds": bounds})
		segment_bounds.append(bounds)
		box("seawall_%d" % stage, Vector3(0, -1.0, end - 19), Vector3(12, 5, 38), Color("53666a"))
	for i: int in 3:
		var side := 1.0 if i != 1 else -1.0
		var at := Vector3(side * 12, 4.0, -14.0 - i * 38)
		mailboxes.append({"id": "mail-run-post-%d" % (i + 1), "bounds": AABB(at - Vector3(1.1, 0.8, 0.5), Vector3(2.2, 1.6, 1.0)), "position": at})
		box("post_%d" % i, at + Vector3(0, -3, -0.9), Vector3(6, 10, 2), Color("53666a"))
		box("mouth_%d" % i, at + Vector3(0, 0, 0.15), Vector3(2.5, 1.8, 0.12), Color("172d32"))
		box("lip_%d" % i, at + Vector3(0, 0.95, 0.25), Vector3(2.8, 0.12, 0.4), Color("bc713e"))
		GEO.deck(self, "post_court_%d" % i, minf(side * 12 - 3, -6), maxf(side * 12 + 3, 6), at.z - 4, at.z + 8, 2, i)
		label("post_number_%d" % i, at + Vector3(0, 2.4, 0.5), "%02d" % (i + 1), 0.03)
		box("post_cap_%d" % i, at + Vector3(0, 2.1, -0.9), Vector3(6.3, 0.25, 2.3), Color("ded8c2"))
	label("entry", Vector3(0, 6, -2), "MAIL RUN\nTHROW WITHOUT LOSING THE HOP\nLMB throw · mouse steer · RMB recall\nV compares views (restarts)", 0.008)
	label("finish", Vector3(0, 7, -135), "DISPATCH", 0.022)
	for x: float in [-8, 8]:
		box("arch_pier_%s" % x, Vector3(x, 7, -125), Vector3(3, 22, 5), Color("53666a"))
	box("sorting_arch", Vector3(0, 17, -125), Vector3(19, 3, 5), Color("ded8c2"))
	_environment()
	routes = {"basic": [spawn.origin, finish_position], "advanced": [spawn.origin, Vector3(10, 2, -8), Vector3(-10, 2, -46), Vector3(10, 2, -84), finish_position]}

func box(id: String, at: Vector3, size: Vector3, color: Color) -> void:
	art_manifest.append([id, at, size, color])
	var node := MeshInstance3D.new()
	node.name = "Water" if id == "water" else "Mail_" + id
	node.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	node.material_override = mat
	if id.begins_with("post_") or id.begins_with("seawall") or id.begins_with("arch_") or id == "sorting_arch":
		node.material_override = MATERIAL.concrete(Color("53666a"))
	add_child(node)
	if id.begins_with("post_") or id.begins_with("arch_pier") or id == "sorting_arch" or id.begins_with("seawall_"):
		var body := StaticBody3D.new()
		body.name = "Mail_wall_" + id
		body.position = at
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)

func label(id: String, at: Vector3, text: String, pixels: float) -> void:
	var node := Label3D.new()
	node.name = "Mail_" + id
	node.position = at
	node.text = text
	node.pixel_size = pixels
	node.font_size = 48
	node.modulate = Color("172d32")
	node.outline_size = 0
	add_child(node)

func _environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bbd2d3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8d6d0")
	env.ambient_light_energy = 0.65
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -25, 0)
	sun.light_color = Color("ffebca")
	sun.light_energy = 0.9
	add_child(sun)
	box("water", Vector3(0, -4, -60), Vector3(600, 0.1, 600), Color("749b9a"))

func is_finish_at(feet: Vector3) -> bool:
	return finish_bounds.has_point(feet)

func geometry_hash() -> String:
	return JSON.stringify([level_id, level_version, manifest, mailboxes, checkpoints, art_manifest, finish_bounds]).sha256_text()

func route_hint(_stage: int, _feet: Vector3) -> String:
	return "Centre line is fastest. Side courts shorten the throw. Mail is optional; every miss costs only the time spent steering."

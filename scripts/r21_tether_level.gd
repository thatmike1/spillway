extends Node3D
## p / measured front-contact clearance revision; source motor and old course remain frozen.

const GEO := preload("res://scripts/r19_course_geometry.gd")
const RUNNER := preload("res://scripts/r21_tether_player.gd")
const LEVEL_ID := "r21-tether-yard"
const LEVEL_NAME := "Tether Yard"
const LEVEL_VERSION := 2
const DECK_HEIGHTS := [4.0, 3.0, 4.0, 2.25]
const MAP_ID := "tether-yard"
const MAP_ENTRY := {"name": LEVEL_NAME, "theme": "Hold, swing and release across the transfer yard", "kind": "experiment",
	"experimental": true, "runner": "res://scripts/r21_tether_player.gd", "script": "res://scripts/r21_tether_level.gd",
	"reticle": true, "key_hint": " · Hold LMB at a ring; release to coast",
	"instructions": "EXPERIMENTAL grapple course. Aim at a marked ring, hold LMB to attach, RMB reels, release LMB to coast. Jump into a transfer, then aim at the next ring. Slide and wall jump are off."}
const ANCHORS := [Vector3(0, 12, -8), Vector3(10, 12, -38), Vector3(-2, 12, -68)]
const DECKS := [[-6.0, 6.0, 0.0, 16.0], [-8.0, 12.0, -30.0, -16.0], [4.0, 22.0, -60.0, -46.0], [-14.0, 8.0, -92.0, -76.0]]
var level_id := LEVEL_ID
var level_name := LEVEL_NAME
var level_version := LEVEL_VERSION
var variant := MAP_ID
var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 4.04, 12))
var finish_title := "Dispatch deck"
var finish_position := Vector3(-4, 2.25, -87)
var finish_radius := 3.0
var finish_bounds := AABB(Vector3(-14, 2.05, -92), Vector3(22, 4, 10))
var kill_bounds := AABB(Vector3(-30, -12, -110), Vector3(70, 60, 164))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var progress_roles: Array = ["route"]
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var mechanics: Array = [RUNNER.TETHER_LAW]
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
	for i: int in DECKS.size():
		var d: Array = DECKS[i]
		var height: float = DECK_HEIGHTS[i]
		GEO.deck(self, "transfer_%d" % i, d[0], d[1], d[2], d[3], height, i)
		var pose := spawn if i == 0 else Transform3D(Basis.IDENTITY, Vector3((d[0] + d[1]) * 0.5, height + 0.04, d[3] - 2))
		checkpoints.append({"pose": pose, "title": ["First line", "East transfer", "West transfer", "Dispatch"][i],
			"bounds": AABB(Vector3(d[0], height - 0.2, d[2]), Vector3(d[1] - d[0], 2.0, d[3] - d[2]))})
		# a small orange painted lip is visual only and never bridges a gap.
		_box("Art_paint_orange_lip_%d" % i, Vector3((d[0] + d[1]) * 0.5, height + 0.025, d[2] + 0.12), Vector3(d[1] - d[0], 0.035, 0.20), Color("b5683c"))
	GEO.deck(self, "catch_court", -22, 30, -100, 42, -5, -1, "recovery")
	for i: int in 4:
		var d: Array = DECKS[i]
		var height: float = DECK_HEIGHTS[i]
		var x := float(d[1]) + 3.0
		var high_z := float(d[3]) - 4.0
		var low_z := high_z + 24.0
		var top: Array[Vector3] = [Vector3(x - 3, height, high_z), Vector3(x + 3, height, high_z), Vector3(x + 3, -5, low_z), Vector3(x - 3, -5, low_z)]
		GEO.prism(self, "return_ramp_%d" % i, top, -5.8, -1, "recovery", "recovery")
		GEO.deck(self, "return_landing_%d" % i, d[1] - 1.0, x + 3, high_z - 4, high_z, height, -1, "recovery")
		_sign("return_%d" % i, Vector3(x, -2, low_z), "RETURN RAMP\nWALK BACK UP", 0.006)
	for i: int in ANCHORS.size():
		_anchor(i, ANCHORS[i])
	_environment()
	_sign("entry", Vector3(0, 7.5, 15), "TETHER YARD\nEXPERIMENTAL / GRAPPLE ONLY\nAIM AT AN ORANGE RING. HOLD LMB.", 0.006)
	_sign("hold", Vector3(0, 8, 0), "LMB HOLD / RMB REEL\nRELEASE WHILE MOVING TOWARD THE NEXT DECK", 0.005)
	_sign("east", Vector3(12, 7, -29), "LOOK FOR THE NEXT ORANGE RING\nRELEASE LMB, AIM, HOLD AGAIN", 0.005)
	_sign("dispatch", Vector3(8, 7, -92), "DISPATCH\nFINISH", 0.009)
	for i: int in 3:
		jump_gaps.append({"label": "transfer_%d" % i, "edge": Vector3(0, DECK_HEIGHTS[i], -30.0 * i), "land": Vector3(0, DECK_HEIGHTS[i + 1], -16.0 - 30.0 * i), "recovery": "lower court and return ramp"})
	routes = {"basic": [spawn.origin, Vector3(0, 4, 1), Vector3(0, DECK_HEIGHTS[1], -22), Vector3(12, 4, -52), finish_position]}
	routes["advanced"] = routes.basic

func _anchor(index: int, at: Vector3) -> void:
	var anchor := Node3D.new()
	anchor.name = "Anchor_%d" % (index + 1)
	anchor.position = at
	anchor.set_meta("r21_anchor_id", "transfer-%d" % (index + 1))
	anchor.set_meta("anchor_name", "Transfer %d" % (index + 1))
	anchor.add_to_group(RUNNER.ANCHOR_GROUP)
	add_child(anchor)
	var ring := MeshInstance3D.new()
	ring.name = "Art_paint_orange_anchor"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.60
	torus.outer_radius = 0.85
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	ring.material_override = RUNNER._flat(Color("b5683c"))
	anchor.add_child(ring)
	_box("Art_paint_dark_beam_%d" % index, at + Vector3(0, 1.1, 0), Vector3(22, 0.30, 0.35), Color("29464a"))
	for side: float in [-11.0, 11.0]:
		_box("Art_paint_dark_post_%d_%s" % [index, side], Vector3(at.x + side, 4.0, at.z), Vector3(0.30, 18.2, 0.35), Color("29464a"))
	_sign("anchor_%d" % index, at + Vector3(0, 1.8, 0), "TRANSFER %d\nHOLD LMB" % (index + 1), 0.006)

func route_hint(stage: int, _feet: Vector3) -> String:
	if stage == 0:
		return "Aim up at the orange ring and hold LMB. RMB reels you across; release LMB while travelling toward the cream deck."
	if stage < 3:
		return "Release LMB, aim at the next orange ring, then hold LMB again. Air-strafe toward the next deck. Missed it? The lower court has return ramps."
	return "Land on the dispatch deck and cross its far end. Broad catch courts and ramps stay open for another line."

func is_finish_at(feet: Vector3) -> bool:
	return finish_bounds.has_point(feet)

func geometry_hash() -> String:
	var data: Array = [LEVEL_ID, LEVEL_VERSION, RUNNER.R21_VERSION, DECK_HEIGHTS, art_manifest]
	for piece: Dictionary in manifest:
		var points: Array = []
		for p: Vector3 in piece.points:
			points.append(_v(p))
		data.append([piece.name, piece.stage, piece.role, piece.kind, points])
	for at: Vector3 in ANCHORS:
		data.append(["anchor", _v(at)])
	for point: Dictionary in checkpoints:
		data.append([point.title, _v(point.pose.origin), _v(point.bounds.position), _v(point.bounds.size)])
	data.append([_v(spawn.origin), _v(finish_position), _v(finish_bounds.position), _v(finish_bounds.size), _v(kill_bounds.position), _v(kill_bounds.size)])
	return JSON.stringify(data, "", false, true).sha256_text()

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
	_box("Water", Vector3(0, -8, -40), Vector3(600, 0.05, 600), Color("789f9c"))

func _box(id: String, at: Vector3, size: Vector3, color: Color) -> void:
	art_manifest.append([id, _v(at), _v(size), color.to_html()])
	var node := MeshInstance3D.new()
	node.name = id
	node.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = RUNNER._flat(color)
	add_child(node)

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

static func _v(p: Vector3) -> Array:
	return [p.x, p.y, p.z]

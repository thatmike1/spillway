extends Node3D
## p / measured front-contact clearance revision; source motor and old course remain frozen.

const ART := preload("res://scripts/art/gantry_dress.gd")
const GEO := preload("res://scripts/r19_course_geometry.gd")
const RUNNER := preload("res://scripts/r21_tether_player.gd")
const LEVEL_ID := "r22-gantry"
const LEVEL_NAME := "Gantry"
const LEVEL_VERSION := 2
const DECK_HEIGHTS := [4.0, 4.0, 4.0]
const MAP_ID := "gantry"
const MAP_ENTRY := {"name": LEVEL_NAME, "theme": "Build a hop line; carry it through the crane slots", "kind": "experiment",
	"experimental": true, "runner": "res://scripts/movement/grapple_player.gd", "script": "res://scripts/maps/gantry.gd",
	"reticle": true, "grapple": true, "own_look": true, "tether_model": "elastic-arc", "key_hint": " · Space hops · LMB swing · RMB reel",
	"instructions": "Build speed on the pale aprons with Space and air strafing. Hold LMB at a ring across each water slot. RMB reels; release to land and hop again. Arc rope law."}
const ANCHORS := [Vector3(0, 14, -21), Vector3(0, 14, -69)]
const HALF_WIDTH := 6.5024
const HOP_PAD := 1.6256
const HOP_GAP := 1.6256
const PAD_COUNTS := [9, 7, 7]
const DECKS := [[-HALF_WIDTH, HALF_WIDTH, -12.0, 24.0], [-HALF_WIDTH, HALF_WIDTH, -60.0, -30.0], [-HALF_WIDTH, HALF_WIDTH, -108.0, -78.0]]
var level_id := LEVEL_ID
var level_name := LEVEL_NAME
var level_version := LEVEL_VERSION
var variant := MAP_ID
var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 4.04, 20))
var finish_title := "Dispatch apron"
var finish_position := Vector3(0, 4, -103)
var finish_radius := 3.0
var finish_bounds := AABB(Vector3(-8, 3.8, -108), Vector3(16, 3, 8))
var kill_bounds := AABB(Vector3(-40, -5, -125), Vector3(80, 65, 165))
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
var hop_pads: Array[Dictionary] = []
var _built := false

func build() -> void:
	if _built:
		return
	_built = true
	for i: int in DECKS.size():
		var d: Array = DECKS[i]
		var count: int = PAD_COUNTS[i]
		var apron_far: float = d[2] + count * (HOP_PAD + HOP_GAP)
		_pad(i, -1, d[0], d[1], apron_far, d[3])
		var near: float = apron_far - HOP_GAP
		for j: int in count:
			_pad(i, j, d[0], d[1], near - HOP_PAD, near)
			jump_gaps.append({"label": "gantry-hop-%d-%d" % [i, j], "edge": Vector3(0, 4, near + HOP_GAP), "land": Vector3(0, 4, near), "recovery": "restart or checkpoint"})
			near -= HOP_PAD + HOP_GAP
		var pose := spawn if i == 0 else Transform3D(Basis.IDENTITY, Vector3(0, 4.04, d[3] - 3))
		checkpoints.append({"pose": pose, "title": ["Runway", "Transfer apron", "Dispatch"][i],
			"bounds": AABB(Vector3(d[0], 3.8, d[2]), Vector3(d[1] - d[0], 2, d[3] - d[2]))})
		_box("Art_paint_orange_lip_%d" % i, Vector3(0, 4.025, d[2] + 0.12), Vector3(HALF_WIDTH * 2, 0.035, 0.20), Color("b5683c"))
	for i: int in ANCHORS.size():
		_anchor(i, ANCHORS[i])
	_environment()
	ART.dress(self)
	_sign("entry", Vector3(-6, 7, 16), "GANTRY\nHOP / SWING / HOP", 0.008)
	_sign("dispatch", Vector3(0, 7, -108), "DISPATCH", 0.010)
	routes = {"basic": [spawn.origin, Vector3(0, 4, -10), Vector3(0, 4, -40), Vector3(0, 4, -58), finish_position]}
	routes["advanced"] = routes.basic
	for i: int in 2:
		jump_gaps.append({"label": "gantry-slot-%d" % i, "edge": Vector3(0, 4, DECKS[i][2]), "land": Vector3(0, 4, DECKS[i + 1][3]), "recovery": "restart or checkpoint"})

func _pad(stage: int, index: int, x0: float, x1: float, far: float, near: float) -> void:
	GEO.prism(self, "apron_%d_pad_%d" % [stage, index], GEO.rectangle(x0, x1, far, near, 4), -5, stage, "route")
	hop_pads.append({"stage": stage, "index": index, "x0": x0, "x1": x1, "far": far, "near": near})

func _anchor(index: int, at: Vector3) -> void:
	var anchor := Node3D.new()
	anchor.name = "Anchor_%d" % (index + 1)
	anchor.position = at
	anchor.set_meta("r21_anchor_id", "gantry-slot-%d" % (index + 1))
	anchor.set_meta("anchor_name", "Gantry slot %d" % (index + 1))
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
	_box("Art_paint_dark_beam_%d" % index, at + Vector3(0, 1.1, 0), Vector3(26, 0.65, 0.7), Color("29464a"))
	for side: float in [-13.0, 13.0]:
		_box("Art_paint_dark_post_%d_%s" % [index, side], Vector3(at.x + side, 4.0, at.z), Vector3(0.7, 22.2, 0.7), Color("29464a"))
	var rim := MeshInstance3D.new()
	rim.name = "Art_anchor_dark_rim"
	var outline := TorusMesh.new()
	outline.inner_radius = 0.82
	outline.outer_radius = 1.0
	rim.mesh = outline
	rim.rotation.x = PI * 0.5
	rim.material_override = RUNNER._flat(Color("263d45"))
	anchor.add_child(rim)
	_box("Art_anchor_bracket_%d" % index, at + Vector3(0, 1.0, 0), Vector3(1.6, 0.40, 0.20), Color("29464a"))

func route_hint(stage: int, _feet: Vector3) -> String:
	return "Space and air-strafe on the apron. Hold LMB at the next ring; release over the receiving apron." if stage < 2 else "Carry the landing into hops down the dispatch apron."

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
	_box("Water", Vector3(0, -4.5, -40), Vector3(600, 0.05, 600), Color("789f9c"))

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

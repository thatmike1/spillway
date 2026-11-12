extends Node3D
## fixture, not a course: a labelled level with the r14 level interface for tests/test_r16_style.gd.
## its geometry is a list of convex prisms (ConvexPolygonShape3D, as the r15 maps build), set
## whole by configure(spec) between episodes so a test can place a beam, a window, a ledge, a
## gap, a pillar or a wall from a calibration run of the same deterministic input. every piece
## is named, so style events carry a stable path. the default spec is a flat 48 x 224 m floor of 24 x 32 m pieces.
##
## spec: {"pieces": [{"name", "top": [Vector3...] (convex, planar, clockwise or not), "base": y,
## "surface": role}], "spawn": Transform3D, "finish": AABB (optional), "kill_y": float}

var level_id := "r16-style-fixture"
var level_name := "Style fixture"
var level_version := 1
var variant := "fixture"
var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 4))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var finish_position := Vector3(0, 0, -400)
var finish_radius := 2.0
var finish_title := "Fixture finish"
var kill_bounds: Variant = AABB(Vector3(-200, -3, -500), Vector3(400, 300, 600))
var manifest: Array[Dictionary] = []
var pieces: Array[Node] = []
var _finish_box := AABB(Vector3(-1000, -1000, -1000), Vector3.ZERO)
var _spec_hash := ""

static func deck(name: String, x0: float, x1: float, z0: float, z1: float, top: float, base: float = -1.0, surface := "route") -> Dictionary:
	return {"name": name, "top": [Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z1)], "base": base, "surface": surface}

## an axis-aligned block from low to high.
static func block(name: String, low: Vector3, high: Vector3, surface := "wall") -> Dictionary:
	return deck(name, low.x, high.x, low.z, high.z, high.y, low.y, surface)

## a vertical slab whose inner face runs along `a -> b` (horizontal points) and reaches
## `thickness` m to the side `outward` (unit, horizontal), from `bottom` to `top`.
static func slab(name: String, a: Vector3, b: Vector3, outward: Vector3, thickness: float, bottom: float, top: float, surface := "wall") -> Dictionary:
	var o := outward * thickness
	return {"name": name, "top": [Vector3(a.x, top, a.z), Vector3(b.x, top, b.z), Vector3(b.x + o.x, top, b.z + o.z), Vector3(a.x + o.x, top, a.z + o.z)], "base": bottom, "surface": surface}

static func flat_spec() -> Dictionary:
	var out: Array = []
	for k: int in 7:
		for side: int in 2:
			out.append(deck("deck_%d_%d" % [k, side], -24.0 + 24.0 * side, 24.0 * side, 8.0 - 32.0 * k, 8.0 - 32.0 * (k + 1), 0.0))
	return {"pieces": out, "spawn": Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 4))}

func build() -> void:
	configure(flat_spec())
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.4, 0)
	add_child(light)

func configure(spec: Dictionary) -> void:
	for node: Node in pieces:
		remove_child(node)
		node.free()
	pieces.clear()
	manifest.clear()
	for piece: Dictionary in spec.get("pieces", []):
		_prism(piece)
	spawn = spec.get("spawn", Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 4)))
	checkpoints = [{"pose": spawn, "title": "Fixture start"}]
	_finish_box = spec.get("finish", AABB(Vector3(-1000, -1000, -1000), Vector3.ZERO))
	finish_position = _finish_box.get_center()
	var kill_y := float(spec.get("kill_y", -3.0))
	kill_bounds = AABB(Vector3(-200, kill_y, -500), Vector3(400, 300 - kill_y, 600))
	segment_bounds = [AABB(Vector3(-200, kill_y, -500), Vector3(400, 300, 600))]
	_spec_hash = var_to_str(manifest).sha256_text()

func _prism(piece: Dictionary) -> void:
	var points := PackedVector3Array()
	for p: Vector3 in piece.top:
		points.append(p)
	for p: Vector3 in piece.top:
		points.append(Vector3(p.x, float(piece.base), p.z))
	var body := StaticBody3D.new()
	body.name = str(piece.name)
	body.set_meta("surface", str(piece.get("surface", "route")))
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	shape.shape = hull
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = hull.get_debug_mesh()
	body.add_child(mesh)
	add_child(body)
	pieces.append(body)
	manifest.append({"name": str(piece.name), "points": points, "surface": str(piece.get("surface", "route"))})

func is_finish_at(feet: Vector3) -> bool:
	return _finish_box.has_point(feet)

func segment_at(_position: Vector3) -> int:
	return 0

func route_hint(_stage: int, _feet: Vector3) -> String:
	return "Style fixture"

func start_wheel() -> void:
	pass

func reset_state() -> void:
	pass

func geometry_hash() -> String:
	return _spec_hash

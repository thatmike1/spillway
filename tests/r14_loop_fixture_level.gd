extends Node3D
## fixture, not a course: a small labelled level with the overflow level interface for
## tests/test_r14_loop*.gd. flat decks run along -z with stage decks tagged progress_stage 1-3
## and a finish box, then a void. walls line both sides. a bay to the right of the start holds a
## slot 0.7 m wide: the r13 capsule (0.6 m) fits in it, the source box (0.81 m) does not.
## walking right (+x) from the start drops through a hole in the bay floor.
## params: "spawn" = "start" or "slot"; "tag" changes the geometry identity without moving anything.

static var params: Dictionary = {}

var level_id := "r14-loop-fixture"
var level_name := "Loop fixture"
var level_version := 1
var variant := "fixture"
var spawn := Transform3D.IDENTITY
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var finish_position := Vector3(0, 0, -35)
var finish_radius := 2.0
var finish_title := "Fixture gate"
var kill_bounds := AABB(Vector3(-30, -3, -80), Vector3(60, 40, 100))
var manifest: Array[Dictionary] = []
var wheel_starts := 0
var resets := 0
var _finish_box := AABB(Vector3(-4, -0.5, -36), Vector3(8, 3.5, 2))
var _tag := "v1"

func build() -> void:
	_tag = str(params.get("tag", "v1"))
	_box("fx_start", Vector3(-4, -1, -10), Vector3(12, 0, 6), -1)
	# the bay floor stops short of the back wall: a 2 x 4 m hole to fall through.
	_box("fx_bay", Vector3(12, -1, -10), Vector3(14, 0, 2), -1)
	_box("fx_stage1", Vector3(-4, -1, -20), Vector3(4, 0, -10), 1)
	_box("fx_stage2", Vector3(-4, -1, -30), Vector3(4, 0, -20), 2)
	_box("fx_finish", Vector3(-4, -1, -44), Vector3(4, 0, -30), 3)
	_box("fx_wall_left", Vector3(-4.4, 0, -44), Vector3(-4, 3, 6.4), -1, "wall")
	_box("fx_wall_right", Vector3(4, 0, -44), Vector3(4.4, 3, -10), -1, "wall")
	_box("fx_wall_bay", Vector3(14, 0, -10.4), Vector3(14.4, 3, 6.4), -1, "wall")
	_box("fx_wall_back", Vector3(-4.4, 0, 6), Vector3(14.4, 3, 6.4), -1, "wall")
	_box("fx_wall_front", Vector3(4, 0, -10.4), Vector3(14.4, 3, -10), -1, "wall")
	_box("fx_slot_a", Vector3(7, 0, -4), Vector3(8.65, 3, 0), -1, "wall")
	_box("fx_slot_b", Vector3(9.35, 0, -4), Vector3(11, 3, 0), -1, "wall")
	var start := Vector3(0, 0.04, 4)
	if str(params.get("spawn", "start")) == "slot":
		start = Vector3(9, 0.04, -1)
	spawn = Transform3D(Basis.IDENTITY, start)
	checkpoints = [
		{"pose": spawn, "title": "Fixture start"},
		{"pose": Transform3D(Basis.IDENTITY, Vector3(0, 0.04, -12)), "title": "Alpha deck", "radius": 0.0},
		{"pose": Transform3D(Basis.IDENTITY, Vector3(0, 0.04, -22)), "title": "Beta deck", "radius": 0.0},
	]
	segment_bounds = [AABB(Vector3(-4, -1, -44), Vector3(18, 6, 50))]
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.4, 0)
	add_child(light)

func _box(label: String, low: Vector3, high: Vector3, stage: int, role: String = "route") -> void:
	var body := StaticBody3D.new()
	body.name = label
	if stage >= 0:
		body.set_meta("progress_stage", stage)
	body.set_meta("surface", role)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = high - low
	shape.shape = box
	shape.position = (low + high) * 0.5
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var visual := BoxMesh.new()
	visual.size = box.size
	mesh.mesh = visual
	mesh.position = shape.position
	body.add_child(mesh)
	add_child(body)
	manifest.append({"name": label, "kind": "concrete", "role": role, "low": low, "high": high})

func is_finish_at(feet: Vector3) -> bool:
	return _finish_box.has_point(feet)

func segment_at(_position: Vector3) -> int:
	return 0

func route_hint(stage: int, _feet: Vector3) -> String:
	return "Fixture: run on to %s." % (finish_title if stage >= 2 else str(checkpoints[stage + 1].title))

func start_wheel() -> void:
	wheel_starts += 1

func reset_state() -> void:
	resets += 1

func geometry_hash() -> String:
	return JSON.stringify(["r14-loop-fixture", var_to_str(manifest), _tag]).sha256_text()

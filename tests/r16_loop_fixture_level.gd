extends Node3D
## fixture, not a course: a labelled level with the r14 level interface for tests/test_r16_loop.gd.
## a start deck along -z, a void across the whole width, a landing deck (stage 1) and a finish
## deck (stage 2), with walls on both sides and kill bounds 3 m under the decks. running into the
## void with W alone falls and respawns; W with Space held hops across it (a style gap).
## params (static, read in build): "gap_z" = the near lip's z (default -10), "gap_m" = the void's
## length (default 1.6), "tag" changes the geometry identity without moving anything.

static var params: Dictionary = {}

var level_id := "r16-loop-fixture"
var level_name := "R16 loop fixture"
var level_version := 1
var variant := "fixture"
var spawn := Transform3D.IDENTITY
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var finish_position := Vector3.ZERO
var finish_radius := 2.0
var finish_title := "Fixture gate"
var kill_bounds: Variant = null
var manifest: Array[Dictionary] = []
var _finish_box := AABB()
var _tag := "v1"

func build() -> void:
	_tag = str(params.get("tag", "v1"))
	var lip := float(params.get("gap_z", -10.0))
	var far := lip - float(params.get("gap_m", 1.6))
	_box("fx_start", Vector3(-4, -1, lip), Vector3(4, 0, 6), -1, "route")
	_box("fx_landing", Vector3(-4, -1, far - 26), Vector3(4, 0, far), 1, "route")
	_box("fx_finish", Vector3(-4, -1, far - 40), Vector3(4, 0, far - 26), 2, "route")
	_box("fx_wall_left", Vector3(-4.4, 0, far - 40), Vector3(-4, 3, 6.4), -1, "wall")
	_box("fx_wall_right", Vector3(4, 0, far - 40), Vector3(4.4, 3, 6.4), -1, "wall")
	_box("fx_wall_back", Vector3(-4.4, 0, 6), Vector3(4.4, 3, 6.4), -1, "wall")
	spawn = Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 4))
	checkpoints = [{"pose": spawn, "title": "Fixture start"},
		{"pose": Transform3D(Basis.IDENTITY, Vector3(0, 0.04, far - 2)), "title": "Landing deck", "radius": 0.0}]
	finish_position = Vector3(0, 0, far - 36)
	_finish_box = AABB(Vector3(-4, -0.5, far - 37), Vector3(8, 3.5, 2))
	segment_bounds = [AABB(Vector3(-4, -1, far - 40), Vector3(8, 6, 46 - far))]
	kill_bounds = AABB(Vector3(-30, -3, far - 60), Vector3(60, 40, 80 - far))
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.4, 0)
	add_child(light)

func _box(label: String, low: Vector3, high: Vector3, stage: int, role: String) -> void:
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
	manifest.append({"name": label, "role": role, "low": low, "high": high})

func is_finish_at(feet: Vector3) -> bool:
	return _finish_box.has_point(feet)

func segment_at(_position: Vector3) -> int:
	return 0

func route_hint(stage: int, _feet: Vector3) -> String:
	return "Fixture: hop the void, run to the gate." if stage == 0 else "Fixture: run to the gate."

func reset_state() -> void:
	pass

func geometry_hash() -> String:
	return JSON.stringify([level_id, var_to_str(manifest), _tag, var_to_str(checkpoints)]).sha256_text()

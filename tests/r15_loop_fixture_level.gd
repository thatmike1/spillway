extends Node3D
## fixture, not a course: a labelled level with the r14 level interface for tests/test_r15_loop*.gd.
## a start pad, then `stages - 1` flat decks along -z tagged progress_stage 1.., then a finish
## deck and a void. walls line both sides. a bay to the right of the start holds a slot 0.7 m
## wide: the r13 capsule (0.6 m) fits, the source box (0.81 m) does not. walking right (+x)
## from the start drops through a hole in the bay floor.
## params (static, read in build): "spawn" = "start" | "slot"; "tag" changes the geometry
## identity without moving anything; "stages" (default 3); "gate" = y of the bottom of a trigger
## box hovering over the start pad, which becomes stage 1's bounds instead of its deck;
## "no_kill" leaves kill_bounds unset so the game derives them; "lift" raises everything;
## "roof" adds a slab 1.5 m over the start pad across the route (z -2..2): the 72 u standing box
## (1.83 m) cannot pass under it, the 54 u duck box (1.37 m) can, and neither can stand up there.
## subclasses in r15_loop_fixture_maps.gd fix `stages` and the name for registry tests.

static var params: Dictionary = {}

var level_id := "r15-loop-fixture"
var level_name := "Loop fixture"
var level_version := 1
var variant := "fixture"
var stages := 0
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
var wheel_starts := 0
var resets := 0
var _finish_box := AABB()
var _tag := "v1"

func build() -> void:
	_tag = str(params.get("tag", "v1"))
	if stages <= 0:
		stages = int(params.get("stages", 3))
	var lift := Vector3.UP * float(params.get("lift", 0.0))
	var far := -10.0 - 10.0 * (stages - 1) - 14.0
	_box("fx_start", Vector3(-4, -1, -10), Vector3(12, 0, 6), -1, "route", lift)
	_box("fx_bay", Vector3(12, -1, -10), Vector3(14, 0, 2), -1, "route", lift)
	var gate: Variant = params.get("gate")
	for k: int in range(1, stages):
		var tagged := k if not (k == 1 and gate != null) else -1
		_box("fx_stage%d" % k, Vector3(-4, -1, -10 - 10 * k), Vector3(4, 0, -10 - 10 * (k - 1)), tagged, "route", lift)
	_box("fx_finish", Vector3(-4, -1, far), Vector3(4, 0, -10 - 10 * (stages - 1)), stages, "route", lift)
	_box("fx_wall_left", Vector3(-4.4, 0, far), Vector3(-4, 3, 6.4), -1, "wall", lift)
	_box("fx_wall_right", Vector3(4, 0, far), Vector3(4.4, 3, -10), -1, "wall", lift)
	_box("fx_wall_bay", Vector3(14, 0, -10.4), Vector3(14.4, 3, 6.4), -1, "wall", lift)
	_box("fx_wall_back", Vector3(-4.4, 0, 6), Vector3(14.4, 3, 6.4), -1, "wall", lift)
	_box("fx_wall_front", Vector3(4, 0, -10.4), Vector3(14.4, 3, -10), -1, "wall", lift)
	_box("fx_slot_a", Vector3(7, 0, -4), Vector3(8.65, 3, 0), -1, "wall", lift)
	_box("fx_slot_b", Vector3(9.35, 0, -4), Vector3(11, 3, 0), -1, "wall", lift)
	if bool(params.get("roof", false)):
		_box("fx_roof", Vector3(-4, 1.5, -2), Vector3(4, 1.8, 2), -1, "roof", lift)
	var start := Vector3(0, 0.04, 4) + lift
	if str(params.get("spawn", "start")) == "slot":
		start = Vector3(9, 0.04, -1) + lift
	spawn = Transform3D(Basis.IDENTITY, start)
	checkpoints = [{"pose": spawn, "title": "Fixture start"}]
	for k: int in range(1, stages):
		var point := {"pose": Transform3D(Basis.IDENTITY, Vector3(0, 0.04, -12 - 10 * (k - 1)) + lift), "title": "Deck %d" % k, "radius": 0.0}
		if k == 1 and gate != null:
			point["bounds"] = AABB(Vector3(-4, float(gate), -2) + lift, Vector3(8, 4, 8))
		checkpoints.append(point)
	finish_position = Vector3(0, 0, far + 3) + lift
	_finish_box = AABB(Vector3(-4, -0.5, far + 2) + lift, Vector3(8, 3.5, 2))
	segment_bounds = [AABB(Vector3(-4, -1, far) + lift, Vector3(18, 6, 6 - far))]
	if not bool(params.get("no_kill", false)):
		kill_bounds = AABB(Vector3(-30, -3, far - 20) + lift, Vector3(60, 40, 46 - far))
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.4, 0)
	add_child(light)

func _box(label: String, low: Vector3, high: Vector3, stage: int, role: String, lift: Vector3) -> void:
	low += lift
	high += lift
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
	return "Fixture: run on to %s." % (finish_title if stage >= stages - 1 else str(checkpoints[stage + 1].title))

func start_wheel() -> void:
	wheel_starts += 1

func reset_state() -> void:
	resets += 1

func geometry_hash() -> String:
	return JSON.stringify([level_id, var_to_str(manifest), _tag, var_to_str(checkpoints)]).sha256_text()

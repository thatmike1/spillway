extends SceneTree
const STAGE := preload("res://scripts/ui/run_review_stage.gd")
const MODEL := preload("res://scripts/recordings/run_review_model.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var recording := MODEL.load_attempt("res://tests/fixtures/original-map-parity/breakwater-basic/old/runs/golden.r16run")
	var pair := MODEL.compare(recording, recording)
	var stage := STAGE.new()
	root.add_child(stage)
	await process_frame
	check(not stage.load_pair(pair).is_empty(), "unattached map refused")
	var source := Node3D.new()
	root.add_child(source)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	source.add_child(mesh)
	stage.attach_map(source, recording.identity)
	check(stage.viewport.find_world_3d() != root.find_world_3d(), "review has an isolated world")
	check(stage.scenery.get_child_count() == 1, "only rendered geometry copied")
	check(stage.load_pair(pair).is_empty(), "matching map accepted")
	for time: float in [0.0, 1.0, 2.0, recording.duration, recording.duration + 100]:
		stage.scrub_to(time)
		check(stage.actors[0].position.is_equal_approx(stage.actors[1].position), "same recording overlaps at common time")
	var start := 0
	while recording.run.columns.flags[start] & 1 == 0: start += 1
	var initial: Vector3 = recording.run.columns.p[maxi(start - 1, 0)]
	check(stage.pose_at(stage.tracks[0], 0.0).is_equal_approx(initial), "time zero holds last pre-start feet")
	var track: Dictionary = stage.tracks[0]
	var midpoint: float = (track.times[4] + track.times[5]) * 0.5
	var halfway: Vector3 = (track.poses[4] as Vector3).lerp(track.poses[5], 0.5)
	check(stage.pose_at(track, midpoint).is_equal_approx(halfway), "scrub interpolates between recorded feet")
	check(stage.actors[0].layers == STAGE.REVIEW_LAYER, "ghosts on review-only render layer")
	var index: int = recording.run.columns.elapsed.size() - 1
	var expected: Vector3 = recording.run.columns.p[index] + Vector3.UP * 0.875
	check(stage.actors[0].position.is_equal_approx(expected), "scrub after finish holds exact recorded pose")
	var identity: Dictionary = recording.identity.duplicate(true)
	identity.geometry = "different"
	stage.attach_map(source, identity)
	check(not stage.load_pair(pair).is_empty() and stage.tracks.is_empty() and not stage.actors[0].visible, "mismatch clears old ghosts")
	var crouch := MODEL.load_attempt("res://tests/fixtures/original-map-parity/whiteout-crouch/old/runs/golden.r16run")
	stage.attach_map(source, crouch.identity)
	check(stage.load_pair(MODEL.compare(crouch, crouch)).is_empty(), "real crouch recording accepted")
	var saw_duck := false
	for i: int in crouch.run.columns.flags.size():
		if crouch.run.columns.flags[i] & 17 == 17:
			stage.scrub_to(crouch.run.columns.elapsed[i])
			check(is_equal_approx((stage.actors[0].mesh as CapsuleMesh).height, 1.30), "recorded crouch changes ghost height")
			saw_duck = true
			break
	check(saw_duck, "fixture contains a timed crouch")
	source.queue_free()
	stage.queue_free()
	await process_frame
	print("RUN_REVIEW_3D: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

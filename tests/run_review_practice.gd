extends SceneTree
const SUPPORT := preload("res://tests/run_review_test_support.gd")
var test_output := ""
const MODEL := preload("res://scripts/recordings/run_review_model.gd")
const PRACTICE := preload("res://scripts/recordings/run_review_practice.gd")
var failures := 0
func check(value: bool, why: String) -> void:
	if not value:
		failures += 1
		push_error(why)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	test_output = SUPPORT.output()
	var best := MODEL.load_attempt("res://tests/fixtures/original-map-parity/breakwater-basic/old/runs/golden.r16run")
	var attempt := MODEL.load_attempt("res://tests/fixtures/original-map-parity/breakwater-return/old/runs/golden.r16run")
	var before := FileAccess.get_sha256(best.path)
	var request := MODEL.practice_request(MODEL.compare(attempt, best))
	check(request.ok and request.stage == 1, "largest real loss starts at checkpoint one")
	check(is_equal_approx(request.pb_start, 5.7421875) and is_equal_approx(request.pb_end, 12.2734375), "practice uses real best checkpoint clocks")
	check(not MODEL.practice_request(MODEL.compare(best, best)).ok, "no loss offers no practice action")
	var host := preload("res://scripts/game.gd").new()
	host.record_runs = true
	host.recordings_dir = test_output.path_join("practice-live")
	root.add_child(host)
	await process_frame
	host.set_physics_process(false)
	host.player.set_physics_process(false)
	host.set_paused(true)
	var settings_before := JSON.stringify(host.settings, "", true)
	var previous: int = host.attempts
	var bad := request.duplicate(true)
	bad.identity.geometry = "wrong"
	check(not PRACTICE.start(host, bad).ok and host.attempts == previous and host.paused, "mismatch refuses before changing the attempt")
	var missing := request.duplicate(true)
	missing.best_path = test_output.path_join("missing-best.r16run")
	check(not PRACTICE.start(host, missing).ok and host.attempts == previous and host.paused, "missing best refuses before changing the attempt")
	var result := PRACTICE.start(host, request)
	check(result.ok, "existing host practice command succeeds")
	if result.ok:
		var controller = result.controller
		check(host.attempts == previous + 1 and host.practice_stage == 1 and not host.clean_eligible and not host.paused, "starts exactly one ordinary non-best practice attempt")
		var authored: Transform3D = host.level.checkpoints[1].pose
		check(host.player.global_position.is_equal_approx(authored.origin), "practice uses authored checkpoint pose")
		var row: int = best.run.columns.elapsed.bsearch(5.7421875)
		var expected: Vector3 = best.run.columns.p[row]
		var body: MeshInstance3D = controller.ghost.get_node("Body")
		check((body.position - Vector3.UP * (body.mesh as CapsuleMesh).height * 0.5).is_equal_approx(expected), "best ghost starts at checkpoint course-clock offset")
		host.elapsed = 100.0
		controller._process(0)
		check(is_equal_approx(controller.ghost.get("_time"), 12.2734375), "ghost holds segment end instead of running into later segments")
		check(JSON.stringify(host.settings, "", true) == settings_before, "practice ghost never persists a ghost toggle")
		host.session.boundary("quit")
		var record := MODEL.READER.read(host.session.last_begin.path.trim_suffix(".part"), true)
		check(record.ok and record.header.metadata.practice_stage == 1 and not record.header.metadata.clean_at_start and record.header.metadata.start_reason == "practice", "existing recorder format marks new attempt as practice")
		host.attempts += 1
		controller._process(0)
		check(controller.is_queued_for_deletion(), "new attempt retires segment ghost")
	check(FileAccess.get_sha256(best.path) == before, "personal best recording remains byte-identical")
	host.queue_free()
	await process_frame
	for file: String in DirAccess.get_files_at(test_output.path_join("practice-live")):
		DirAccess.remove_absolute(test_output.path_join("practice-live").path_join(file))
	DirAccess.remove_absolute(test_output.path_join("practice-live"))
	print("RUN_REVIEW_PRACTICE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

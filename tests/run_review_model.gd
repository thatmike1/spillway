extends SceneTree
const MODEL := preload("res://scripts/recordings/run_review_model.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _init() -> void:
	var absent := "/tmp/r22-08-run-review/no-recordings-created"
	check(not DirAccess.dir_exists_absolute(absent), "missing-directory precondition")
	check(MODEL.list_attempts(absent).is_empty(), "missing recordings folder is an empty library")
	check(not DirAccess.dir_exists_absolute(absent), "review does not create a recordings directory")
	var root := "res://tests/fixtures/original-map-parity"
	var pair: Dictionary = {}
	for route: String in DirAccess.get_directories_at(root):
		var path := root.path_join(route).path_join("old/runs/golden.r16run")
		if FileAccess.file_exists(path):
			var candidate := MODEL.load_attempt(path)
			if candidate.ok and MODEL.READER.clean_finish(candidate.run).ok:
				pair = candidate
				break
	check(not pair.is_empty(), "real clean fixture exists")
	if pair.is_empty():
		quit(1)
		return
	var real_return := MODEL.load_attempt("res://tests/fixtures/original-map-parity/breakwater-return/old/runs/golden.r16run")
	var real_comparison := MODEL.compare(real_return, pair)
	check(real_comparison.ok, "two distinct real finishes compare")
	check(is_equal_approx(real_comparison.splits.back().delta, 10.875), "real finish difference is 10.875 seconds")
	var compared := MODEL.compare(pair, pair)
	check(compared.ok and not compared.splits.is_empty(), "real pair produces splits")
	for split: Dictionary in compared.splits:
		check(is_zero_approx(split.loss) and is_zero_approx(split.delta), "identical tracks have zero loss")
	check(pair.speed.size() > 10, "speed trace has real samples")
	var slower := pair.duplicate(true)
	for mark: Dictionary in slower.marks:
		mark.time += 1.25
	var loss := MODEL.compare(slower, pair)
	check(loss.ok and is_equal_approx(loss.splits[0].loss, 1.25), "segment difference uses adjacent checkpoint clocks")
	if loss.splits.size() > 1:
		check(is_zero_approx(loss.splits[1].loss), "cumulative loss is not counted twice")
	var missing := pair.duplicate(true)
	missing.identity.erase("timing")
	check(not MODEL.compare(missing, missing).ok, "missing timing identity refused")
	check(MODEL.biggest_loss(loss).contains("1.250 s between Start"), "largest individual segment loss named")
	check(MODEL.biggest_loss(compared).begins_with("No time lost"), "no positive loss does not invent a loss")
	var incompatible := pair.duplicate(true)
	incompatible.identity.geometry = "different"
	check(not MODEL.compare(incompatible, pair).ok, "different geometry refused")
	var bytes := FileAccess.get_file_as_bytes(pair.path)
	for kind: String in ["partial", "damaged"]:
		var changed := bytes.slice(0, bytes.size() / 2) if kind == "partial" else bytes.duplicate()
		if kind == "damaged":
			changed[changed.size() / 2] ^= 1
		var path := "/tmp/r22-08-run-review/%s.r16run" % kind
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(changed)
		file.close()
		check(not MODEL.load_attempt(path).ok, kind + " refused")
		DirAccess.remove_absolute(path)
	print("RUN_REVIEW_MODEL: ", "PASS" if failures == 0 else "FAIL", " fixture=", pair.path)
	quit(0 if failures == 0 else 1)

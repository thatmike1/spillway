extends Node3D
## explicit practice command after review closes; existing host owns the new attempt lifecycle.
const GHOST := preload("res://scripts/recordings/ghost.gd")
const READER := preload("res://scripts/recordings/reader.gd")
var game: Node
var ghost: Node3D
var attempt := -1
var checkpoint := -1
var pb_start := 0.0
var pb_end := 0.0
var identity := {}

static func start(host: Node, request: Dictionary) -> Dictionary:
	if not is_instance_valid(host) or not host.has_method("practise_stage") or not host.has_method("motion_identity"):
		return {"ok": false, "error": "Practice is unavailable in this host."}
	if not bool(host.get("paused")):
		return {"ok": false, "error": "Open the paused run review before practising a segment."}
	if not request.get("ok", false) or not request.get("identity") is Dictionary:
		return {"ok": false, "error": "Choose a completed segment with time lost first."}
	var why := READER.identity_matches(request.identity, host.call("motion_identity"))
	if not why.is_empty():
		return {"ok": false, "error": "Load this recording's map, movement preset and layout before practising."}
	var stage: int = request.get("stage", -1)
	if stage < 0 or stage >= int(host.call("stage_count")):
		return {"ok": false, "error": "This checkpoint is unavailable in the current map."}
	for key: String in ["pb_start", "pb_end"]:
		if not (request.get(key) is float or request.get(key) is int) or not is_finite(float(request[key])):
			return {"ok": false, "error": "The best's segment timing is unavailable."}
	var playback := GHOST.new()
	var loaded := playback.load_run(str(request.get("best_path", "")), request.identity)
	if not loaded.ok:
		playback.free()
		return {"ok": false, "error": "The best recording is unavailable: " + str(loaded.error)}
	if float(request.pb_start) < 0 or float(request.pb_end) <= float(request.pb_start) or float(request.pb_end) > playback.run_time + 0.000001:
		playback.free()
		return {"ok": false, "error": "The requested segment is outside the best recording."}
	for child: Node in host.get_children():
		if child.get_meta("run_review_practice", false):
			child.call("stop")
	host.call("practise_stage", stage)
	var controller = load("res://scripts/recordings/run_review_practice.gd").new()
	controller.name = "RunReviewPractice"
	controller.set_meta("run_review_practice", true)
	controller.game = host
	controller.attempt = int(host.get("attempts"))
	controller.checkpoint = stage
	controller.pb_start = float(request.pb_start)
	controller.pb_end = float(request.pb_end)
	controller.identity = request.identity.duplicate(true)
	controller.ghost = playback
	controller.process_mode = Node.PROCESS_MODE_ALWAYS
	controller.process_priority = 100
	controller.add_child(playback)
	host.add_child(controller)
	controller._process(0.0)
	return {"ok": true, "controller": controller}

func _process(_delta: float) -> void:
	if not is_instance_valid(game) or int(game.get("attempts")) != attempt or int(game.get("practice_stage")) != checkpoint or bool(game.get("finished")):
		stop()
		return
	if not READER.identity_matches(identity, game.call("motion_identity")).is_empty():
		stop()
		return
	# keep the ordinary spawn-clock ghost unchanged; only its presentation is suppressed here.
	var normal: Node3D = game.get("session").get("ghost")
	if is_instance_valid(normal): normal.visible = false
	if not bool(game.get("paused")):
		ghost.call("set_time", minf(pb_end, pb_start + float(game.get("elapsed"))))

func stop() -> void:
	set_process(false)
	set_meta("run_review_practice", false)
	if is_instance_valid(game) and not game.is_queued_for_deletion():
		var normal: Node3D = game.get("session").get("ghost")
		if is_instance_valid(normal): normal.visible = bool(game.call("ghost_shown"))
	ghost.visible = false
	queue_free()

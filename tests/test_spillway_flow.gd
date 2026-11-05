extends SceneTree
## isolated run-flow fixture, not authored-route or movement proof.
## the real main, motor and HUD run against three checkpoints on one collision floor.
## only fixture placement and elapsed time are seeded; actions and controls use engine input.

const MAIN := preload("res://scripts/spillway_main.gd")
const ACTIONS: Array[String] = ["restart", "practice", "pause", "move_forward", "jump", "ui_accept"]
var game: Node3D
var checks: int = 0
var failures: int = 0
var case_name: String = "setup"
var saved_profile: Dictionary

class FlowLevel:
	extends Node3D
	var spawn := Transform3D(Basis.IDENTITY, Vector3(-8, 100.025, 0))
	var checkpoints: Array[Dictionary] = [
		{"pose": Transform3D(Basis.IDENTITY, Vector3(-8, 100.025, 0)), "title": "Fixture crest", "radius": 1.0},
		{"pose": Transform3D(Basis.IDENTITY, Vector3(0, 100.025, -8)), "title": "Fixture yard", "radius": 1.0},
		{"pose": Transform3D(Basis.IDENTITY, Vector3(8, 100.025, -16)), "title": "Fixture outflow", "radius": 1.0},
	]
	var finish_position := Vector3(8, 100.025, -24)
	var finish_radius: float = 1.0
	var water_regions: Array[Dictionary] = []

	func _ready() -> void:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(100, 1, 100)
		collision.shape = shape
		body.position = Vector3(0, 99.5, -16)
		body.add_child(collision)
		add_child(body)

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("%s [%s] %s" % ["PASS" if ok else "FAIL", case_name, label])
	if not ok:
		failures += 1

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func pulse(name: String) -> void:
	action(name, true)
	await frames(2)
	action(name, false)
	await frames(1)

func mouse_x(pixels: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(pixels, 0)
	event.screen_relative = event.relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	# process_frame deliberately keeps pause checks and menu input from hanging.
	for i: int in count:
		await process_frame

func ticks(count: int) -> void:
	for i: int in count:
		await physics_frame
	await process_frame

func profile_snapshot() -> Dictionary:
	var path: String = ProjectSettings.globalize_path(MAIN.SAVE_PATH)
	if not FileAccess.file_exists(path):
		return {"exists": false}
	return {"exists": true, "sha256": FileAccess.get_sha256(path), "modified": FileAccess.get_modified_time(path)}

func records() -> Dictionary:
	return {"best": game.get("best_time"), "splits": game.get("best_splits").duplicate(),
		"segments": game.get("best_segments").duplicate()}

func checkpoint_position(index: int) -> Vector3:
	return (game.get("level").get("checkpoints")[index]["pose"] as Transform3D).origin

func visit(position: Vector3, at_time: float) -> void:
	# flow fixture: teleport to supported trigger positions and seed the clock, never route proof.
	game.set("elapsed", at_time)
	game.get("player").call("reset_to", Transform3D(Basis.IDENTITY, position))
	await ticks(3)

func finish_run(times: Array[float]) -> void:
	await visit(checkpoint_position(1), times[0])
	await visit(checkpoint_position(2), times[1])
	await visit(game.get("level").get("finish_position"), times[2])

func restart(label: String) -> void:
	case_name = label
	await pulse("restart")

func button(text: String) -> Button:
	for node: Node in game.get("hud").find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null

func activate(control: BaseButton) -> void:
	control.grab_focus()
	await frames(1)
	await pulse("ui_accept")

func _run() -> void:
	print("spillway flow: engine=%s display=%s bot=%s; ISOLATED FLOW FIXTURE, NOT ROUTE PROOF" % [
		Engine.get_version_info().string, DisplayServer.get_name(), OS.get_cmdline_user_args().has("--bot")])
	saved_profile = profile_snapshot()
	game = MAIN.new()
	root.add_child(game)
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--bot"):
		check(not bool(game.get("_persist")), "headless/bot startup disables profile writes before any test override")
	# native runs must also disable writes before changing any settings or finishing a run.
	game.set("_persist", false)
	if game.get("bot") != null:
		game.get("bot").process_mode = Node.PROCESS_MODE_DISABLED
	var authored_level: Node3D = game.get("level")
	# retain native resource lifetime; the flow collision floor sits above the authored world.
	authored_level.hide()
	authored_level.process_mode = Node.PROCESS_MODE_DISABLED
	var flow_level := FlowLevel.new()
	game.add_child(flow_level)
	game.set("level", flow_level)
	# records loaded from the real profile are replaced only in memory.
	game.set("best_time", -1.0)
	game.get("best_splits").clear()
	game.get("best_segments").clear()
	await restart("restart and timer")
	await ticks(15)
	check(is_zero_approx(float(game.get("elapsed"))), "timer stays idle at spawn")
	action("move_forward", true)
	await ticks(36)
	action("move_forward", false)
	check(float(game.get("elapsed")) > 0.0, "real movement away from spawn starts timer")
	await ordered_checkpoints()
	await clean_records()
	await practice_records()
	await recovery_records()
	await paused_controls()
	for name: String in ACTIONS:
		action(name, false)
	game.call("set_paused", false)
	case_name = "profile isolation"
	check(profile_snapshot() == saved_profile, "settings and clean/practice finishes never create or change saved profile")
	game.queue_free()
	await frames(2)
	print("spillway flow: %d/%d checks passed; failures=%d; isolated flow fixture, route playback separate" % [checks - failures, checks, failures])
	quit(1 if failures else 0)

func ordered_checkpoints() -> void:
	await restart("ordered checkpoints")
	await visit(checkpoint_position(2), 3.0)
	check(int(game.get("checkpoint_index")) == 0 and game.get("splits").is_empty(), "visiting checkpoint two first grants no split")
	await visit(game.get("level").get("finish_position"), 5.0)
	check(not bool(game.get("finished")) and float(game.get("best_time")) < 0.0, "finish cannot bypass both ordered checkpoints")
	await visit(checkpoint_position(1), 10.0)
	check(int(game.get("checkpoint_index")) == 1 and game.get("splits").size() == 1, "checkpoint one records exactly one split")
	await visit(game.get("level").get("finish_position"), 12.0)
	check(not bool(game.get("finished")), "finish cannot bypass checkpoint two")
	await visit(checkpoint_position(1), 14.0)
	check(game.get("splits").size() == 1, "revisiting a checkpoint cannot duplicate a split")
	await visit(checkpoint_position(2), 25.0)
	await visit(game.get("level").get("finish_position"), 45.0)
	check(bool(game.get("finished")) and game.get("splits").size() == 3, "ordered traversal finishes with three splits")
	var previous := records()
	await ticks(10)
	check(game.get("splits").size() == 3 and records() == previous, "standing at finish cannot append splits or replace records repeatedly")

func clean_records() -> void:
	await restart("clean record improvements")
	await finish_run([10.0, 25.0, 45.0])
	check(absf(float(game.get("best_time")) - 45.0) < 0.1, "clean finish establishes full-run best near controlled 45s")
	var first := records()
	check(first.splits.size() == 3 and first.segments.size() == 3, "clean finish establishes all three cumulative and segment records")
	if first.segments.size() == 3:
		check(absf(first.segments[0] - 10.0) < 0.1 and absf(first.segments[1] - 15.0) < 0.1 and absf(first.segments[2] - 20.0) < 0.1,
			"segment records reflect 10s / 15s / 20s rather than cumulative times")
	await restart("slower clean run with faster middle segment")
	await finish_run([12.0, 24.0, 50.0])
	check(game.get("best_time") == first.best and game.get("best_splits") == first.splits, "slower clean total preserves best time and matching split set")
	if game.get("best_segments").size() == 3:
		check(absf(game.get("best_segments")[1] - 12.0) < 0.1 and game.get("best_segments")[0] == first.segments[0] and game.get("best_segments")[2] == first.segments[2],
			"slower total may improve only its genuinely faster clean segment")
	await restart("faster clean run")
	await finish_run([8.0, 18.0, 30.0])
	check(absf(float(game.get("best_time")) - 30.0) < 0.1 and game.get("best_splits") == game.get("splits"), "faster clean finish replaces best and its matching split set")

func practice_records() -> void:
	for segment: int in [0, 1, 2]:
		await restart("F segment %d practice" % segment)
		if segment >= 1:
			await visit(checkpoint_position(1), 1.0)
		if segment >= 2:
			await visit(checkpoint_position(2), 2.0)
		var before := records()
		await pulse("practice")
		check(not bool(game.get("clean_eligible")) and not bool(game.get("finished")), "F immediately invalidates clean eligibility")
		check(game.get("player").global_position.distance_to(checkpoint_position(segment)) < 0.1, "F restores current segment pose")
		if segment == 0:
			await visit(checkpoint_position(1), 1.0)
		if segment <= 1:
			await visit(checkpoint_position(2), 2.0)
		await visit(game.get("level").get("finish_position"), 3.0)
		check(bool(game.get("finished")) and records() == before, "faster practice finish preserves clean best, splits and every segment record")
		check("PRACTICE FINISH" in game.get("hud").get("finish_label").text, "practice result visibly identifies assistance")
		await restart("R after assisted finish")
		check(bool(game.get("clean_eligible")) and not bool(game.get("finished")) and int(game.get("checkpoint_index")) == 0,
			"R restores eligibility and returns to first segment")
		check(game.get("splits").is_empty() and game.get("split_deltas").is_empty() and int(game.get("respawn_count")) == 0,
			"R clears attempt splits, comparisons and respawn count")
		check(float(game.get("elapsed")) == 0.0 and records() == before, "R clears timer while preserving clean records")

func recovery_records() -> void:
	await restart("out-of-bounds checkpoint recovery")
	await visit(checkpoint_position(1), 1.0)
	var before := records()
	# flow fixture: a genuine out-of-bounds body pose triggers the runtime recovery path.
	game.get("player").call("reset_to", Transform3D(Basis.IDENTITY, Vector3(0, -30, -8)))
	await ticks(24)
	check(int(game.get("respawn_count")) == 1 and not bool(game.get("clean_eligible")), "out-of-bounds recovery counts respawn and invalidates clean eligibility")
	check(int(game.get("checkpoint_index")) == 1 and game.get("player").global_position.distance_to(checkpoint_position(1)) < 0.1,
		"recovery restores the reached checkpoint rather than the start")
	await visit(checkpoint_position(2), 2.0)
	await visit(game.get("level").get("finish_position"), 3.0)
	check(bool(game.get("finished")) and records() == before, "faster respawn-assisted finish cannot overwrite any clean record")
	await restart("R after respawn")
	check(bool(game.get("clean_eligible")) and int(game.get("respawn_count")) == 0 and game.get("splits").is_empty(),
		"R after respawn restores a fresh clean attempt")
	await finish_run([5.0, 10.0, 15.0])
	check(absf(float(game.get("best_time")) - 15.0) < 0.1, "fresh R attempt after assistance can establish a new clean best")

func paused_controls() -> void:
	await restart("pause blocks movement and timer")
	action("move_forward", true)
	await ticks(30)
	await pulse("pause")
	check(paused and bool(game.get("paused")) and game.get("hud").get("pause_panel").visible, "Escape pauses the tree and shows settings")
	var position: Vector3 = game.get("player").global_position
	var elapsed: float = game.get("elapsed")
	action("jump", true)
	await frames(30)
	check(game.get("player").global_position.is_equal_approx(position) and game.get("elapsed") == elapsed, "held run and jump cannot move player or advance clock while paused")
	action("jump", false)
	action("move_forward", false)
	await settings_controls()
	var resume := button("Resume")
	check(resume != null, "pause exposes a Resume control")
	if resume != null:
		await activate(resume)
		check(not paused and not bool(game.get("paused")), "focused Resume receives real ui_accept while paused")
	if paused:
		await pulse("pause")
	await sensitivity_response()
	action("move_forward", true)
	await ticks(20)
	action("move_forward", false)
	check(game.get("player").global_position.distance_to(position) > 0.05, "movement becomes live after resume")
	await pulse("pause")
	await pulse("pause")
	check(not paused, "Escape remains live and can resume a paused game")
	await pulse("practice")
	await pulse("pause")
	var clean_restart := button("Restart clean run")
	check(clean_restart != null, "pause exposes a clean restart control")
	if clean_restart != null:
		await activate(clean_restart)
		check(not paused and bool(game.get("clean_eligible")) and game.get("splits").is_empty(), "focused clean restart works while paused and resets assistance")
	if paused:
		await pulse("pause")

func sensitivity_response() -> void:
	var before: float = game.get("player").get("yaw")
	mouse_x(40.0)
	await frames(2)
	var first_turn: float = absf(angle_difference(before, game.get("player").get("yaw")))
	await pulse("pause")
	var sliders: Array[Node] = game.get("hud").find_children("*", "HSlider", true, false)
	if sliders.size() != 3:
		await pulse("pause")
		return
	(sliders[0] as HSlider).value = 0.5
	await frames(2)
	await pulse("pause")
	before = game.get("player").get("yaw")
	mouse_x(40.0)
	await frames(2)
	var second_turn: float = absf(angle_difference(before, game.get("player").get("yaw")))
	check(second_turn > 0.0 and first_turn > second_turn * 1.5,
		"lower sensitivity slider causes a smaller turn for identical real mouse motion: %.4f / %.4f" % [first_turn, second_turn])

func settings_controls() -> void:
	case_name = "distinct live settings controls"
	var sliders: Array[Node] = game.get("hud").find_children("*", "HSlider", true, false)
	check(sliders.size() == 3, "pause exposes sensitivity, horizontal FOV and volume sliders")
	if sliders.size() != 3:
		return
	var keys: Array[String] = ["sensitivity", "fov", "volume"]
	var values: Array[float] = [1.65, 103.0, 0.25]
	for i: int in sliders.size():
		var slider := sliders[i] as HSlider
		var before: Dictionary = game.get("settings").duplicate(true)
		var before_camera_fov: float = game.get("player").get("camera").fov
		if is_equal_approx(float(before[keys[i]]), values[i]):
			values[i] = [0.75, 81.0, 0.85][i]
		slider.value = values[i]
		await frames(2)
		var actual: Dictionary = game.get("settings")
		var intended_only: bool = is_equal_approx(float(actual[keys[i]]), values[i])
		for key: String in before:
			if key != keys[i] and actual[key] != before[key]:
				intended_only = false
		check(intended_only, "%s slider changes only its intended setting while paused: %s" % [keys[i], actual])
		if keys[i] == "fov":
			var camera_fov: float = game.get("player").get("camera").fov
			check((camera_fov - before_camera_fov) * (values[i] - float(before.fov)) > 0.0, "FOV slider visibly changes camera projection in intended direction")
		elif keys[i] == "volume":
			check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(values[i])), "volume slider changes actual master output gain")
	var comfort := button("Comfort camera (less impact and no speed FOV)") as CheckButton
	check(comfort != null, "pause exposes comfort camera control")
	if comfort != null:
		var before: bool = game.get("settings").comfort
		await activate(comfort)
		check(bool(game.get("settings").comfort) != before and bool(game.get("player").get("comfort")) != before,
			"focused comfort control receives real input and changes camera setting while paused")

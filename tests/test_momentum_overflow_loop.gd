extends SceneTree
## p / r13 overflow product loop: run lifecycle, hud labels, records and settings. every run is
## played with ordinary key and relative-mouse events through Input; nothing calls the game's
## finish or writes the runner's pose or velocity. lifecycle runs on a labelled, parameterised
## FIXTURE level with the overflow level interface, so course revisions cannot break or tune
## these checks. one group builds the current overflow course only for interface and motion
## smoke checks, without coordinates. persistence runs in fresh child processes, each with
## its own isolated XDG profile, so save and reload cross a real process boundary.
## godot --headless --audio-driver Dummy --fixed-fps 120 --path . \
##   --script res://tests/test_momentum_overflow_loop.gd -- --out=DIR [--only=GROUPS] [--course-level=PATH]
## groups: identity, clean, retry, practice, respawn, open, explore, pause, hint, speed, driver,
## course, persist. exits 1 on any failed check; DIR/summary.json lists every check.

const MAIN := preload("res://scripts/momentum_overflow_main.gd")
const SCENE := "res://scenes/momentum_overflow.tscn"
const TITLES := ["Alpha weir", "Beta lock", "Gamma steps"]
const FINISH_TITLE := "Fixture gate"
## words that belong to r12, to the lab factories or to the motor's internals.
const FOREIGN := ["r12", "R12", "surf", "Surf", "SURF", "slide", "Slide", "broad", "BROAD", "CARRY", "carry", "records disabled", "EXPERIMENT", "narrow"]

## FIXTURE, not the course: a straight 8 m deck with stage boxes every 12 m and a finish box,
## then the deck ends over a void. `pocket` moves one stage's box off the deck, so a straight
## run skips it; `tag` changes the geometry identity without moving anything.
class Fixture:
	extends Node3D
	static var params: Dictionary = {}
	var spawn := Transform3D.IDENTITY
	var checkpoints: Array[Dictionary] = []
	var segment_bounds: Array[AABB] = []
	var water_regions: Array[Dictionary] = []
	var water_audio_sources: Array[Vector3] = []
	var finish_position := Vector3.ZERO
	var finish_radius := 2.0
	var finish_title := FINISH_TITLE
	var manifest: Array[Dictionary] = []
	var wheel_starts := 0
	var resets := 0
	var _finish_box := AABB()
	var _titles: Array = []
	var _pocket := -1
	var _tag := ""

	func build() -> void:
		_titles = params.get("titles", TITLES)
		_pocket = int(params.get("pocket", -1))
		_tag = str(params.get("tag", "v1"))
		var spacing := 12.0
		var finish_z := -(_titles.size() + 1) * spacing
		var deck_end := finish_z - 14.0
		var body := StaticBody3D.new()
		body.name = "fixture_deck"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(8.0, 1.0, 6.0 - deck_end)
		shape.shape = box
		shape.position = Vector3(0, -0.5, (6.0 + deck_end) * 0.5)
		body.add_child(shape)
		add_child(body)
		manifest.append({"name": "fixture_deck", "kind": "deck"})
		var mesh := MeshInstance3D.new()
		var visual := BoxMesh.new()
		visual.size = box.size
		mesh.mesh = visual
		mesh.position = shape.position
		add_child(mesh)
		spawn = Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 0))
		checkpoints = [{"pose": spawn, "title": "Fixture start"}]
		for i: int in _titles.size():
			var z := -(i + 1) * spacing
			var x0 := 20.0 if i + 1 == _pocket else -4.0
			checkpoints.append({"pose": Transform3D(Basis.IDENTITY, Vector3(0, 0.04, z)), "title": _titles[i],
				"bounds": AABB(Vector3(x0, -0.5, z - 1.5), Vector3(8, 4, 3))})
		finish_position = Vector3(0, 0, finish_z)
		_finish_box = AABB(Vector3(-4, -0.5, finish_z - 1.0), Vector3(8, 3.5, 2.0))
		segment_bounds = [AABB(Vector3(-4, -1, deck_end), Vector3(8, 6, 6.0 - deck_end))]

	func is_finish_at(feet: Vector3) -> bool:
		return _finish_box.has_point(feet)

	func segment_at(_position: Vector3) -> int:
		return 0

	func route_hint(stage: int, feet: Vector3) -> String:
		if absf(feet.x) > 1.5:
			return "Fixture: back to the middle of the deck."
		return "Fixture: run on to %s." % (_titles[stage] if stage < _titles.size() else FINISH_TITLE)

	func start_wheel() -> void:
		wheel_starts += 1

	func reset_state() -> void:
		resets += 1

	func geometry_hash() -> String:
		return JSON.stringify(["fixture", _titles, _pocket, _tag]).sha256_text()

var out_dir := ""
var results: Array[Dictionary] = []
var only: Array = []
var phase := ""
var course_level := ""
var _group := ""
var game: Node

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
		elif arg.begins_with("--course-level="):
			course_level = arg.trim_prefix("--course-level=")
	if out_dir.is_empty():
		printerr("usage: --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_main.call_deferred()

func _main() -> void:
	if not phase.is_empty():
		await _child_phase()
		return
	for group: String in ["identity", "clean", "retry", "practice", "respawn", "open", "explore", "pause", "hint", "speed", "driver", "course", "persist"]:
		if only.is_empty() or group in only:
			_group = group
			print("group: ", group)
			await call("_group_" + group)
			await _drop_game()
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	var summary := {"checks": results.size(), "failed": failed.size(), "results": results,
		"engine": Engine.get_version_info(), "physics_hz": Engine.physics_ticks_per_second, "fixed_fps": Engine.max_fps}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	file.close()
	for r: Dictionary in failed:
		printerr("FAIL %s / %s: %s" % [r.group, r.name, r.detail])
	print("overflow loop: %d checks, %d failed" % [results.size(), failed.size()])
	quit(1 if failed.size() > 0 else 0)

func check(name: String, ok: bool, detail: Variant = "") -> bool:
	results.append({"group": _group, "name": name, "ok": ok, "detail": str(detail)})
	if not ok:
		printerr("  fail: %s (%s)" % [name, detail])
	return ok

# --- input and stepping --------------------------------------------------------------------------

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key) -> void:
	key(code, true)
	await physics_frame
	key(code, false)
	await physics_frame

func mouse(dx: float, dy: float = 0.0) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.screen_relative = Vector2(dx, dy)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

## a left click at the centre of a visible control, through the viewport's gui picking. the
## headless display has a 0x0 window, so the event is given in viewport coordinates; under a
## real display the same click arrives through Input (see the native capture).
func click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)
		await process_frame

func ticks(n: int) -> void:
	for i: int in n:
		await physics_frame

## steps until cond() holds; returns the ticks taken, or -1 at the limit.
func until(cond: Callable, limit: int) -> int:
	for i: int in limit:
		if cond.call():
			return i
		await physics_frame
	return -1 if not cond.call() else limit

func release_all() -> void:
	for code: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_CTRL]:
		key(code, false)

func make_game(params: Dictionary = {}, from_scene: bool = false) -> Node:
	Fixture.params = params
	game = (load(SCENE) as PackedScene).instantiate() if from_scene else MAIN.new()
	game.set("level_script", Fixture)
	root.add_child(game)
	await ticks(3)
	return game

func _drop_game() -> void:
	release_all()
	if is_instance_valid(game):
		if bool(game.paused):
			game.call("set_paused", false)
		game.queue_free()
		game = null
	paused = false
	await ticks(3)

func run_clean(limit: int = 3000) -> bool:
	key(KEY_W, true)
	var taken := await until(func() -> bool: return bool(game.finished), limit)
	key(KEY_W, false)
	return taken >= 0

func hud_texts(visible_only: bool = true) -> Array[String]:
	var texts: Array[String] = []
	for node: Node in (game.hud as Node).find_children("*", "", true, false):
		if node is Label or node is Button:
			var control := node as Control
			if not visible_only or control.is_visible_in_tree():
				texts.append(str(control.get("text")))
	return texts

func foreign_words(texts: Array[String]) -> Array:
	var found: Array = []
	for text: String in texts:
		for word: String in FOREIGN:
			if text.contains(word):
				found.append("%s in '%s'" % [word, text.left(60)])
	return found

# --- groups --------------------------------------------------------------------------------------

func _group_identity() -> void:
	await make_game()
	var hud: Node = game.hud
	check("build id is r13 overflow", str(game.BUILD_ID).contains("r13") and str(game.BUILD_ID).contains("overflow"), game.BUILD_ID)
	check("profile path is the r13 file", str(game.SAVE_PATH) == "user://spillway_r13.cfg" and str(game.profile_path) == "user://spillway_r13.cfg", game.profile_path)
	check("new() builds a game with records off", not bool(game.persist) and str(game.profile_state) == "off", game.profile_state)
	check("runner is the original air law", str(game.player.get("air_policy")) == "carry-air-candidate", game.player.get("air_policy"))
	var launch := hud_texts()
	check("launch names Spillway and Overflow", "SPILLWAY" in launch and launch.any(func(t: String) -> bool: return t.contains("OVERFLOW") and t.contains("R13")), launch)
	check("launch shows the controls", launch.any(func(t: String) -> bool: return t.contains("WASD") and t.contains("Esc pause") and t.contains("S brakes")), launch)
	check("no r12, lab or motor-profile words at launch", foreign_words(launch).is_empty(), foreign_words(launch))
	await tap(KEY_ESCAPE)
	var paused_texts := hud_texts()
	check("pause shows the build id", paused_texts.any(func(t: String) -> bool: return t.contains(str(game.BUILD_ID))), paused_texts)
	check("pause heading is r13 overflow", paused_texts.any(func(t: String) -> bool: return t.begins_with("SPILLWAY R13") and t.contains("OVERFLOW")), paused_texts)
	check("no r12, lab or motor-profile words in pause", foreign_words(paused_texts).is_empty(), foreign_words(paused_texts))
	await tap(KEY_ESCAPE)
	var all_texts := hud_texts(false)
	check("no foreign words anywhere in the hud tree", foreign_words(all_texts).is_empty(), foreign_words(all_texts))
	check("split names come from the level", game.call("segment_title", 0) == TITLES[0] and game.call("segment_title", TITLES.size()) == FINISH_TITLE and int(game.call("stage_count")) == TITLES.size() + 1, [game.call("segment_title", 0), game.call("segment_title", TITLES.size())])
	await _drop_game()
	# a level with other stages renders other names, with no code change.
	await make_game({"titles": ["One", "Two", "Three", "Four", "Five"]})
	check("five-stage fixture: six timed segments", int(game.call("stage_count")) == 6 and game.call("segment_title", 4) == "Five", game.call("stage_count"))
	var finished := await run_clean()
	var card := str(game.hud.finish_body.text)
	check("five-stage finish lists every stage", finished and ["One", "Two", "Three", "Four", "Five", FINISH_TITLE].all(func(t: String) -> bool: return card.contains(t)), card)
	check("five-stage finish has no inherited stage names", not card.contains("Crest") and not card.contains("Sluice yard") and not card.contains("Outflow"), card)

func _group_clean() -> void:
	await make_game()
	var order: Array = []
	var times: Array = []
	key(KEY_W, true)
	for i: int in 3000:
		if order.is_empty() or order[-1] != int(game.checkpoint_index):
			order.append(int(game.checkpoint_index))
		if bool(game.finished):
			break
		await physics_frame
	key(KEY_W, false)
	for value: float in game.stage_times:
		times.append(value)
	check("stages collected in order", order == [0, 1, 2, 3], order)
	check("clean finish", bool(game.finished) and str(game.finish_kind) == "clean", game.finish_kind)
	var increasing := true
	for i: int in times.size():
		if times[i] <= 0.0 or (i > 0 and times[i] <= times[i - 1]):
			increasing = false
	check("every stage measured, increasing", increasing and times.size() == 4, times)
	check("finish time is the last stage time", is_equal_approx(float(game.elapsed), float(times[-1])), [game.elapsed, times])
	check("first clean finish sets the best", is_equal_approx(float(game.best_time), float(game.elapsed)) and float(game.open_best_time) == float(game.best_time), [game.best_time, game.open_best_time])
	check("finish card visible", game.hud.finish_panel.visible and str(game.hud.finish_title.text).contains("WATER RUNNING"), game.hud.finish_title.text)
	var card := str(game.hud.finish_body.text)
	check("finish card names each stage with its time", TITLES.all(func(t: String) -> bool: return card.contains(t)) and card.contains(FINISH_TITLE), card)
	check("finish card says first clean run", card.contains("First clean run"), card)
	check("finish card offers R and F", str(game.hud.finish_footer.text).contains("R  run again") and str(game.hud.finish_footer.text).contains("F  practise"), game.hud.finish_footer.text)
	check("level was told to start its finish", int(game.level.wheel_starts) == 1, game.level.wheel_starts)
	check("nothing saved from a records-off game", not bool(game.last_save_ok), game.last_save_ok)
	var at_finish: float = game.elapsed
	await ticks(60)
	check("clock stops at the finish", float(game.elapsed) == at_finish, [at_finish, game.elapsed])

func _group_retry() -> void:
	await make_game()
	await run_clean()
	var first: float = game.best_time
	key(KEY_R, true)
	await physics_frame
	key(KEY_R, false)
	check("R resets the run at once", not bool(game.finished) and float(game.elapsed) == 0.0 and int(game.checkpoint_index) == 0 and bool(game.clean_eligible), [game.finished, game.elapsed])
	check("R hides the finish card", not game.hud.finish_panel.visible)
	check("R returns the runner to the spawn", game.player.global_position.distance_to((game.level.spawn as Transform3D).origin) < 0.1, game.player.global_position)
	check("R resets the level", int(game.level.resets) >= 2, game.level.resets)
	var start: Vector3 = game.player.global_position
	key(KEY_W, true)
	await ticks(12)
	check("W moves the runner within 0.1 s of R", game.player.global_position.distance_to(start) > 0.05, game.player.global_position.distance_to(start))
	await until(func() -> bool: return bool(game.finished), 3000)
	key(KEY_W, false)
	check("second clean finish", str(game.finish_kind) == "clean")
	check("best is the faster of the two", is_equal_approx(float(game.best_time), minf(first, float(game.elapsed))), [first, game.elapsed, game.best_time])
	var card := str(game.hud.finish_body.text)
	check("second finish compares with the best", card.contains("vs best") or card.contains("New best"), card)
	check("segment deltas exist on the second run", game.split_deltas.size() == 4 and game.split_deltas.all(func(d: float) -> bool: return is_finite(d)), game.split_deltas)
	# R in the middle of a run, while W is still held.
	key(KEY_W, true)
	await tap(KEY_R)
	await ticks(40)
	check("restart mid-run keeps running from the spawn", not bool(game.finished) and int(game.checkpoint_index) == 0 and float(game.elapsed) > 0.0, [game.checkpoint_index, game.elapsed])
	key(KEY_W, false)

func _group_practice() -> void:
	await make_game()
	await run_clean()
	var best: float = game.best_time
	var open_best: float = game.open_best_time
	await tap(KEY_R)
	key(KEY_W, true)
	await until(func() -> bool: return int(game.checkpoint_index) == 2, 3000)
	key(KEY_W, false)
	await tap(KEY_F)
	check("F starts practice", not bool(game.clean_eligible) and int(game.practice_stage) == 2, [game.clean_eligible, game.practice_stage])
	var pose: Transform3D = (game.level.checkpoints[2] as Dictionary)["pose"]
	check("F places the runner at the stage reached", game.player.global_position.distance_to(pose.origin) < 0.2, game.player.global_position)
	check("practice clock restarts", float(game.elapsed) < 0.05, game.elapsed)
	check("hud marks practice", str(game.hud.practice_tag.text).contains("PRACTICE"), game.hud.practice_tag.text)
	await run_clean()
	check("practice finish", str(game.finish_kind) == "practice", game.finish_kind)
	check("practice sets no record", float(game.best_time) == best and float(game.open_best_time) == open_best, [best, game.best_time])
	check("practice finish card says not recorded", str(game.hud.finish_body.text).contains("Not recorded"), game.hud.finish_body.text)
	var card := str(game.hud.finish_body.text)
	check("practice card shows only practised segments", not card.contains(TITLES[0]) and card.contains(TITLES[2]) and card.contains(FINISH_TITLE), card)
	check("practice segment time is the segment, not the run", float(game.call("segment_time", 2)) > 0.5 and float(game.call("segment_time", 2)) < float(game.best_segments[2]) + 2.0, [game.call("segment_time", 2), game.best_segments])
	# F after a finish practises the last stage reached; R gets back to a clean run.
	await tap(KEY_F)
	check("F after a finish practises the last stage", not bool(game.finished) and int(game.practice_stage) == int(game.checkpoint_index), game.practice_stage)
	await tap(KEY_R)
	check("R after practice is a clean run", bool(game.clean_eligible) and int(game.practice_stage) == -1 and str(game.hud.practice_tag.text).is_empty())

func _group_respawn() -> void:
	await make_game()
	await run_clean()
	var best: float = game.best_time
	await tap(KEY_R)
	# turn a quarter right with the mouse, then run off the deck's side into the void.
	for i: int in 36:
		mouse((PI * 0.5 / 0.0022) / 36.0)
		await physics_frame
	key(KEY_W, true)
	var taken := await until(func() -> bool: return int(game.respawn_count) > 0, 900)
	key(KEY_W, false)
	check("falling out of the course respawns", taken >= 0 and int(game.respawn_count) == 1, game.respawn_count)
	check("a respawn makes the run practice", not bool(game.clean_eligible))
	check("respawn lands back on the last stage", game.player.global_position.distance_to((game.level.spawn as Transform3D).origin) < 0.2, game.player.global_position)
	await ticks(30)
	check("runner stands on the deck after respawn", game.player.call("is_grounded") and game.player.global_position.y > -0.1, game.player.global_position)
	check("hud says practice after respawn", str(game.hud.practice_tag.text).contains("PRACTICE"))
	await run_clean()
	check("finish after a respawn is practice", str(game.finish_kind) == "practice" and float(game.best_time) == best, [game.finish_kind, game.best_time])

func _group_open() -> void:
	await make_game({"pocket": 2})
	await run_clean()
	check("a skipped stage finishes as an open line", str(game.finish_kind) == "open", game.finish_kind)
	check("the skipped stage has no time", float(game.stage_times[1]) < 0.0 and float(game.stage_times[0]) > 0.0 and float(game.stage_times[2]) > 0.0, game.stage_times)
	check("open line sets the open best only", float(game.open_best_time) > 0.0 and float(game.best_time) < 0.0 and game.best_splits.is_empty() and game.best_segments.is_empty(), [game.open_best_time, game.best_time])
	check("no segment comparison is invented", game.split_deltas.is_empty(), game.split_deltas)
	var card := str(game.hud.finish_body.text)
	check("open finish names the skipped stage", card.contains("%s   skipped" % TITLES[1]) and card.contains("Open line"), card)
	check("segment after a skip shows no fabricated time", float(game.call("segment_time", 2)) < 0.0, game.call("segment_time", 2))

func _group_explore() -> void:
	await make_game()
	await run_clean()
	var result := [game.finish_kind, game.elapsed, game.best_time, game.stage_times.duplicate()]
	# keep running past the finish and off the end of the deck.
	key(KEY_W, true)
	var fell := await until(func() -> bool: return game.player.global_position.y < -3.0, 1200)
	var back := await until(func() -> bool: return game.player.global_position.y > -1.0, 600)
	key(KEY_W, false)
	check("exploration can leave the course", fell >= 0)
	check("a fall after the finish returns to the finish", back >= 0 and game.player.global_position.distance_to(game.level.finish_position) < 1.0, game.player.global_position)
	check("the finish result is unchanged", [game.finish_kind, game.elapsed, game.best_time, game.stage_times] == result and int(game.respawn_count) == 0, [game.finish_kind, game.elapsed])
	check("still finished, card still up", bool(game.finished) and game.hud.finish_panel.visible)

func _group_pause() -> void:
	await make_game()
	key(KEY_W, true)
	await ticks(60)
	await tap(KEY_ESCAPE)
	check("Esc pauses", bool(game.paused) and paused and game.hud.pause_panel.visible)
	var held: Vector3 = game.player.global_position
	var clock: float = game.elapsed
	await ticks(60)
	check("nothing moves or times while paused, W held", game.player.global_position == held and float(game.elapsed) == clock, [held, game.player.global_position])
	await tap(KEY_ESCAPE)
	await ticks(20)
	check("Esc resumes the run", not bool(game.paused) and not paused and game.player.global_position.distance_to(held) > 0.1)
	key(KEY_W, false)
	await tap(KEY_ESCAPE)
	await ticks(2)
	await click(game.hud.restart_button)
	await ticks(2)
	check("pause Restart button restarts and resumes", not bool(game.paused) and float(game.elapsed) == 0.0 and int(game.checkpoint_index) == 0, [game.paused, game.elapsed])
	key(KEY_W, true)
	await until(func() -> bool: return int(game.checkpoint_index) == 1, 2000)
	key(KEY_W, false)
	await tap(KEY_ESCAPE)
	await ticks(2)
	check("pause offers practice of the stage reached", str(game.hud.practice_button.text).contains(TITLES[0]), game.hud.practice_button.text)
	await click(game.hud.practice_button)
	await ticks(2)
	check("pause Practise button starts practice", not bool(game.paused) and not bool(game.clean_eligible) and int(game.practice_stage) == 1, [game.paused, game.practice_stage])
	await tap(KEY_ESCAPE)
	await ticks(2)
	await click(game.hud.resume_button)
	await ticks(2)
	check("pause Resume button resumes", not bool(game.paused))
	await tap(KEY_ESCAPE)
	await tap(KEY_R)
	check("R from the pause panel restarts unpaused", not bool(game.paused) and bool(game.clean_eligible))
	# settings sliders reach the runner; this game has records off, so nothing is written.
	await tap(KEY_ESCAPE)
	var slider := game.hud.find_child("Setting_sensitivity", true, false) as HSlider
	slider.value = 1.5
	var fov := game.hud.find_child("Setting_fov", true, false) as HSlider
	fov.value = 100.0
	check("sensitivity setting reaches the runner", is_equal_approx(float(game.player.mouse_sensitivity), 0.0022 * 1.5), game.player.mouse_sensitivity)
	check("fov setting reaches the runner", is_equal_approx(float(game.player.fov_horizontal), 100.0), game.player.fov_horizontal)
	var autohop := game.hud.find_child("Setting_autohop", true, false) as CheckButton
	await click(autohop)
	check("autohop toggle reaches the runner", not bool(game.player.autohop), game.player.autohop)
	check("records-off game writes no settings", not bool(game.last_save_ok))
	await tap(KEY_ESCAPE)

func _group_hint() -> void:
	await make_game()
	await ticks(30)
	check("first clear shows the route reminder", game.hud.hint.modulate.a > 0.5 and str(game.hud.hint.text).begins_with("Fixture: run on"), [game.hud.hint.modulate.a, game.hud.hint.text])
	await run_clean()
	await tap(KEY_R)
	key(KEY_W, true)
	await ticks(90)
	check("ordinary line after a clean finish: no reminder", game.hud.hint.modulate.a < 0.05, game.hud.hint.modulate.a)
	key(KEY_W, false)
	# drift toward the edge: the level's recovery hint for this spot differs from its usual one.
	key(KEY_D, true)
	await until(func() -> bool: return absf(game.player.global_position.x) > 1.6, 600)
	key(KEY_D, false)
	await ticks(60)
	check("recovery shows the level's hint", game.hud.hint.modulate.a > 0.5 and str(game.hud.hint.text).contains("back to the middle"), [game.hud.hint.modulate.a, game.hud.hint.text])
	check("intro stays hidden on retries once a best exists", game.hud.title.modulate.a < 0.05, game.hud.title.modulate.a)

func _group_speed() -> void:
	await make_game()
	key(KEY_W, true)
	var probe := await speed_probe(400)
	key(KEY_W, false)
	check("hud speed is measured travel (mean of 12 finite-difference steps)", probe.compared > 300 and probe.worst < 1e-3, "worst %.6f over %d ticks" % [probe.worst, probe.compared])
	check("hud shows the measured speed", str(game.hud.speed_label.text) == "%.1f" % float(game.display_speed), game.hud.speed_label.text)
	check("run speed reached on the flat", float(game.display_speed) > 8.0 and float(game.display_speed) < 9.0, game.display_speed)
	await tap(KEY_R)
	check("speed clears on restart", float(game.display_speed) < 0.5, game.display_speed)

## steps n ticks, comparing the game's shown speed with travel the test measures itself from
## the runner's positions. returns the worst gap, the ticks compared and the top speed shown.
func speed_probe(n: int) -> Dictionary:
	var positions: Array[Vector3] = []
	var worst := 0.0
	var compared := 0
	var top := 0.0
	for i: int in n:
		positions.append(game.player.global_position)
		top = maxf(top, float(game.display_speed))
		var count := positions.size()
		if count > 14:
			# at the start of tick n the game has averaged the runner's last 12 finished steps.
			var total := 0.0
			for k: int in range(count - 13, count - 1):
				var d := positions[k] - positions[k - 1]
				total += Vector2(d.x, d.z).length() * Engine.physics_ticks_per_second
			worst = maxf(worst, absf(total / 12.0 - float(game.display_speed)))
			compared += 1
		await physics_frame
	return {"worst": worst, "compared": compared, "top": top}

func _group_driver() -> void:
	# a driver or comparison builds the node with new(): with an r13 profile present it still
	# neither reads nor writes it, even outside headless.
	var path := "user://spillway_r13.cfg"
	var existed := FileAccess.file_exists(path)
	var before := FileAccess.get_sha256(path) if existed else ""
	await make_game()
	await run_clean()
	check("driver game reads no profile", str(game.profile_state) == "off")
	check("driver game leaves any profile untouched", FileAccess.file_exists(path) == existed and (FileAccess.get_sha256(path) if existed else "") == before)
	await _drop_game()
	# the launch scene, headless, with no explicit profile: records stay off.
	await make_game({}, true)
	var probe: Node = (load(SCENE) as PackedScene).instantiate()
	check("launch scene asks for records", probe.get("persist") == true)
	probe.free()
	check("headless scene without --r13-profile keeps records off", not bool(game.persist), game.profile_state)

func _group_course() -> void:
	# the current overflow course, or a frozen copy: interface and motion smoke only.
	game = MAIN.new()
	if not course_level.is_empty():
		game.set("level_script", course_level)
	root.add_child(game)
	await ticks(3)
	var points: Array = game.level.checkpoints
	check("course has stages", points.size() >= 2, points.size())
	var titles: Array = []
	for i: int in int(game.call("stage_count")):
		titles.append(game.call("segment_title", i))
	check("course stage titles are named", titles.all(func(t: String) -> bool: return not t.is_empty() and not t.begins_with("Stage ")), titles)
	check("course interface", game.level.has_method("is_finish_at") and game.level.has_method("route_hint") and game.level.has_method("geometry_hash") and game.level.get("finish_position") is Vector3, "")
	check("course key covers the geometry", str(game.course_geometry) == str(game.level.call("geometry_hash")) and str(game.course_key).length() == 16, game.course_key)
	await ticks(20)
	check("course shows a first-clear reminder", game.hud.hint.modulate.a > 0.3 and not str(game.hud.hint.text).is_empty(), game.hud.hint.text)
	var start: Vector3 = game.player.global_position
	key(KEY_W, true)
	var probe := await speed_probe(360)
	key(KEY_W, false)
	check("W runs down the course", game.player.global_position.distance_to(start) > 15.0 and int(game.respawn_count) == 0, game.player.global_position.distance_to(start))
	check("descent gains speed beyond run speed", float(probe.top) > 8.6, probe.top)
	# on slopes the motor's own speed is along the surface; the hud must still show travel.
	check("course hud speed is measured travel on slopes and landings", probe.worst < 1e-3, "worst %.6f over %d ticks" % [probe.worst, probe.compared])
	check("course run started the clock", float(game.elapsed) > 2.0 and not bool(game.finished), game.elapsed)
	var texts := hud_texts()
	check("no foreign words on the course", foreign_words(texts).is_empty(), foreign_words(texts))
	results[-1]["detail"] += " level=%s titles=%s key=%s" % [course_level if not course_level.is_empty() else "res://scripts/momentum_overflow_level.gd", titles, game.course_key]

# --- persistence across fresh processes ---------------------------------------------------------

func _group_persist() -> void:
	var godot := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://")
	var base := out_dir.path_join("profiles")
	var r12_text := "[settings]\n\nsensitivity=1.7\nfov=100.0\nvolume=0.4\ncomfort=true\nautohop=true\n\n[records_r12]\n\nclean_best=12.34\nopen_best=11.0\nclean_splits=[1.0, 2.0, 12.34]\nclean_segments=[1.0, 1.0, 10.34]\n"
	# profile A: an existing r12 player. profile B: nobody has run r12 here.
	var user_a := _user_dir(base.path_join("a"))
	var user_b := _user_dir(base.path_join("b"))
	for dir: String in [user_a, user_b]:
		DirAccess.make_dir_recursive_absolute(dir)
	var r12 := FileAccess.open(user_a.path_join("spillway_r12.cfg"), FileAccess.WRITE)
	r12.store_string(r12_text)
	r12.close()
	var r12_hash := FileAccess.get_sha256(user_a.path_join("spillway_r12.cfg"))
	var r12_mtime := FileAccess.get_modified_time(user_a.path_join("spillway_r12.cfg"))
	var steps := [
		["a", "first", ["--r13-profile=user://spillway_r13.cfg"]],
		["a", "reload", ["--r13-profile=user://spillway_r13.cfg"]],
		["a", "changed", ["--r13-profile=user://spillway_r13.cfg", "--fixture-tag=v2"]],
		["a", "revert", ["--r13-profile=user://spillway_r13.cfg"]],
		["a", "norecords", ["--r13-profile=user://spillway_r13.cfg", "--no-records"]],
		["b", "bare", ["--r13-profile=user://spillway_r13.cfg"]],
	]
	var reports := {}
	for step: Array in steps:
		var xdg := base.path_join(step[0])
		var args := PackedStringArray(["XDG_DATA_HOME=" + xdg.path_join("data"), "XDG_CONFIG_HOME=" + xdg.path_join("config"), "XDG_CACHE_HOME=" + xdg.path_join("cache"),
			godot, "--headless", "--audio-driver", "Dummy", "--fixed-fps", "120", "--path", project, "--script", "res://tests/test_momentum_overflow_loop.gd", "--",
			"--phase=" + step[1], "--out=" + out_dir.path_join("phase-" + step[1])])
		args.append_array(step[2])
		var output: Array = []
		var code := OS.execute("env", args, output, true)
		var log := FileAccess.open(out_dir.path_join("phase-%s.log" % step[1]), FileAccess.WRITE)
		log.store_string("\n".join(output))
		log.close()
		var report_path := out_dir.path_join("phase-" + step[1]).path_join("report.json")
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path)) if FileAccess.file_exists(report_path) else {}
		reports[step[1]] = report
		check("phase %s exits 0" % step[1], code == 0, "exit %d" % code)
		for item: Dictionary in report.get("checks", []):
			check("%s: %s" % [step[1], item.name], bool(item.ok), item.detail)
		check("phase %s used the isolated profile" % step[1], str(report.get("user_dir", "")).simplify_path() == _user_dir(xdg).simplify_path(), report.get("user_dir", ""))
	var first: Dictionary = reports.get("first", {})
	var reload: Dictionary = reports.get("reload", {})
	var changed: Dictionary = reports.get("changed", {})
	var revert: Dictionary = reports.get("revert", {})
	check("fresh process reloads the clean best", float(reload.get("loaded_best", -2)) > 0.0 and is_equal_approx(float(reload.get("loaded_best", -2)), float(first.get("best", -1))), [first.get("best"), reload.get("loaded_best")])
	check("fresh process reloads the changed setting", is_equal_approx(float(reload.get("loaded_sensitivity", 0)), 1.25), reload.get("loaded_sensitivity"))
	check("changed geometry starts without the old best", float(changed.get("loaded_best", 0)) < 0.0 and str(changed.get("key")) != str(first.get("key")), [changed.get("loaded_best"), changed.get("key"), first.get("key")])
	check("reverted geometry gets its own best back", is_equal_approx(float(revert.get("loaded_best", -2)), float(reload.get("best", -1))), [revert.get("loaded_best"), reload.get("best")])
	var profile := ConfigFile.new()
	profile.load(user_a.path_join("spillway_r13.cfg"))
	check("profile keeps both courses' records", profile.has_section("course_" + str(first.get("key"))) and profile.has_section("course_" + str(changed.get("key"))), profile.get_sections())
	check("profile has no r12 record namespace", not profile.has_section("records_r12"), profile.get_sections())
	check("r12 profile byte-for-byte unchanged", FileAccess.get_sha256(user_a.path_join("spillway_r12.cfg")) == r12_hash and FileAccess.get_modified_time(user_a.path_join("spillway_r12.cfg")) == r12_mtime, r12_hash)
	check("no r11 profile created", not FileAccess.file_exists(user_a.path_join("spillway_v1.cfg")) and not FileAccess.file_exists(user_b.path_join("spillway_v1.cfg")))
	check("a fresh machine gets no r12 profile from r13", not FileAccess.file_exists(user_b.path_join("spillway_r12.cfg")) and FileAccess.file_exists(user_b.path_join("spillway_r13.cfg")), DirAccess.get_files_at(user_b))
	check("bare first launch uses default settings", is_equal_approx(float(reports.get("bare", {}).get("loaded_sensitivity", 0)), 1.0), reports.get("bare", {}).get("loaded_sensitivity"))

func _user_dir(xdg: String) -> String:
	return xdg.path_join("data/godot/app_userdata").path_join(str(ProjectSettings.get_setting("application/config/name")))

func _child_phase() -> void:
	var report := {"phase": phase, "user_dir": ProjectSettings.globalize_path("user://"), "checks": []}
	var tag := "v1"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture-tag="):
			tag = arg.trim_prefix("--fixture-tag=")
	var checks: Array = report.checks
	var path := "user://spillway_r13.cfg"
	var existed_before := FileAccess.file_exists(path)
	var hash_before := FileAccess.get_sha256(path) if existed_before else ""
	await make_game({"tag": tag}, true)
	report["key"] = game.course_key
	report["loaded_best"] = game.best_time
	report["loaded_sensitivity"] = game.settings.sensitivity
	report["profile_state"] = game.profile_state
	match phase:
		"first":
			checks.append({"name": "first launch seeds settings from r12", "ok": is_equal_approx(float(game.settings.sensitivity), 1.7) and is_equal_approx(float(game.settings.fov), 100.0) and bool(game.settings.comfort), "detail": str(game.settings)})
			checks.append({"name": "first launch takes no r12 records", "ok": float(game.best_time) < 0.0 and float(game.open_best_time) < 0.0, "detail": str(game.best_time)})
			checks.append({"name": "runner uses the seeded sensitivity", "ok": is_equal_approx(float(game.player.mouse_sensitivity), 0.0022 * 1.7), "detail": str(game.player.mouse_sensitivity)})
		"reload":
			checks.append({"name": "hud shows the reloaded best", "ok": str(game.hud.best_line.text).begins_with("best "), "detail": game.hud.best_line.text})
		"changed", "bare":
			checks.append({"name": "no best for a course without records", "ok": float(game.best_time) < 0.0 and str(game.hud.best_line.text) == "first run", "detail": game.hud.best_line.text})
		"norecords":
			checks.append({"name": "--no-records reads nothing", "ok": str(game.profile_state) == "off" and float(game.best_time) < 0.0, "detail": game.profile_state})
	var finished := await run_clean()
	checks.append({"name": "clean run finishes by keys", "ok": finished and str(game.finish_kind) == "clean", "detail": game.finish_kind})
	report["best"] = game.best_time
	if phase == "reload":
		# a practice finish after a clean one changes nothing on disk.
		var saved := FileAccess.get_sha256(path)
		await tap(KEY_R)
		key(KEY_W, true)
		await until(func() -> bool: return int(game.checkpoint_index) == 1, 3000)
		await tap(KEY_F)
		await until(func() -> bool: return bool(game.finished), 3000)
		key(KEY_W, false)
		checks.append({"name": "practice finish writes nothing", "ok": str(game.finish_kind) == "practice" and FileAccess.get_sha256(path) == saved, "detail": game.finish_kind})
	if phase == "norecords":
		checks.append({"name": "--no-records leaves the profile untouched", "ok": FileAccess.file_exists(path) == existed_before and (FileAccess.get_sha256(path) if existed_before else "") == hash_before, "detail": ""})
	else:
		checks.append({"name": "clean finish saved", "ok": bool(game.last_save_ok) and FileAccess.file_exists(path), "detail": str(game.profile_state)})
	# settings go through the pause panel, then quit with a mouse click on Quit.
	await tap(KEY_ESCAPE)
	if phase == "first":
		(game.hud.find_child("Setting_sensitivity", true, false) as HSlider).value = 1.25
	report["paused_identity"] = game.hud.pause_identity.text
	if phase == "reload":
		checks.append({"name": "pause shows the reloaded best", "ok": str(game.hud.pause_records.text).begins_with("Best "), "detail": game.hud.pause_records.text})
	checks.append({"name": "pause identity names this build and course", "ok": str(game.hud.pause_identity.text).contains(str(game.BUILD_ID)) and str(game.hud.pause_identity.text).contains(str(game.course_key).left(8)), "detail": game.hud.pause_identity.text})
	var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	await ticks(2)
	await click(game.hud.quit_button)
	# the Quit button ends the process; still running here means it did not.
	await ticks(240)
	checks.append({"name": "Quit button ends the process", "ok": false, "detail": "still running"})
	file = FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	quit(3)

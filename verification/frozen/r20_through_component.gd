extends SceneTree
## labelled collision fixtures cover refusals and boundaries; accepted routes live in the separate input-only driver.
const SCENE := preload("res://scenes/r20.tscn")
const PLAYER := preload("res://scripts/r20_through_player.gd")
const R19 := preload("res://scenes/r19.tscn")
const OLD_MAPS := preload("res://scripts/r19_map_catalog.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
const SESSION := preload("res://scripts/r16_run_session.gd")
var output := ""
var scene: PackedScene = SCENE
var game: Node3D
var hook: Post
var checks: Array = []
var observations: Array = []
var inputs: Array = []
var case_name := ""
var counter := 0
var episodes: Array = []

class Post:
	extends Node
	signal ticked
	var driver: Object
	func _physics_process(_dt: float) -> void:
		driver.observe()
		ticked.emit()

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func observe() -> void:
	if game == null:
		return
	counter += 1
	observations.append({"t": counter, "physical": snapshot(), "motion": READER.json_safe(game.player.get_motion_state())})

func snapshot() -> Dictionary:
	return {"p": READER.json_safe(game.player.position), "v": READER.json_safe(game.player.velocity), "grounded": game.player.is_grounded(), "yaw": game.player.yaw,
		"pitch": game.player.pitch, "elapsed": game.elapsed, "checkpoint": game.checkpoint_index, "motion_tick": game.player.motion_tick,
		"attempts": game.attempts, "respawns": game.respawn_count, "session_tick": game.session.tick, "identity": game.motion_identity()}

func ticks(n: int) -> void:
	for i: int in n:
		await hook.ticked

func check(ok: bool, text: String) -> void:
	checks.append({"ok": ok, "check": text, "case": case_name})
	print("ok " if ok else "FAIL ", case_name, " · ", text)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	inputs.append({"t": counter, "event": SESSION.describe(event)})
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: int) -> void:
	key(code, true)
	key(code, false)

func new_case(label: String, at := Vector3(0, 4.04, 12), speed := Vector3.ZERO, map := "through-line") -> void:
	if game != null:
		close_case()
	case_name = label
	observations = []
	inputs = []
	counter = 0
	game = scene.instantiate()
	game.map_id = map
	game.motor = "server128"
	game.persist = false
	game.record_runs = true
	game.seed_from_r15 = false
	game.set_window_title = false
	game.recordings_dir = output.path_join(label + "-recordings")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection.cfg")
	root.add_child(game)
	game.hud.dismiss_title()
	if map == "through-line" and (at != Vector3(0, 4.04, 12) or speed != Vector3.ZERO):
		# explicitly labelled fixture setup, before observed ticks; never used by whole-route acceptance.
		game.level.spawn = Transform3D(Basis.IDENTITY, at)
		game.course_geometry = "r20-through-fixture-" + label
		game._refresh_records()
		game.restart_run("fixture_" + label)
		game.player.velocity = speed * 0.0254

func close_case() -> void:
	game.session.boundary("quit")
	var reads := []
	for sealed: Dictionary in game.session.sealed:
		var rec := READER.read(str(sealed.path))
		check(rec.ok, "original strict Godot reader accepts sealed fixture")
		reads.append({"path": sealed.path, "ok": rec.ok, "header": rec.header, "seal": rec.seal, "events": rec.events})
	var file := FileAccess.open(output.path_join(case_name + ".json.gz"), FileAccess.WRITE)
	file.store_buffer(JSON.stringify({"observations": observations, "inputs": inputs, "recordings": reads}, "", false, true).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	episodes.append({"case": case_name, "samples": observations.size(), "recordings": reads.size()})
	for code: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_L, KEY_F9, KEY_R, KEY_F, KEY_ESCAPE]:
		key(code, false)
	root.remove_child(game)
	game.free()
	game = null

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.render_loop_enabled = false
	Engine.physics_ticks_per_second = 128
	hook = Post.new()
	hook.driver = self
	hook.process_physics_priority = 1001
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	new_case("integration")
	await ticks(33)
	check(game.map_ids() == ["breakwater", "whiteout-relay", "sunken-court", "rainline", "night-shift", "practice", "overflow", "experiment", "saltglass", "tether-yard", "through-line"], "production catalog retains original8, revised Saltglass/Tether, shelves old experiments, appends Through Line")
	check(game.hud.map_buttons.has("through-line") and game.hud.map_buttons["through-line"].get_parent() == game.hud.experiments_grid, "actual production card is in Experiments")
	check(not game.runner_is_standin() and game.runner_path() == "res://scripts/r20_through_player.gd", "trusted experiment-only runner selected")
	check(game.lab_moves().is_empty() and not game.hud.tether_section.visible, "no lab mechanics or Tether settings leak into Through Line")
	check(game.mechanics() == [PLAYER.LAW] and PLAYER.VERSION in game.family_version(), "full speed law and version enter normal timing/ghost identity")
	check(game.look_layer != null and game.look_layer.get_parent() == game.level and game.look_layer.enabled, "automatic practice Look C is attached exactly by inherited host")
	check(game.level.find_children("first_run_*", "StaticBody3D", true, false).size() > 0 and game.level.find_children("second_start_*", "StaticBody3D", true, false).size() > 0, "both segments are collidable simultaneously")
	check(game.hull_fits(game.preset, game.level.spawn.origin), "authored spawn clears inherited F2 hull")
	for id: String in ["line-drive", "fall-line"]:
		game.select_map(id)
		check(game.map_id == "through-line" and not game.hud.map_buttons.has(id), "shelved direct selection refused: " + id)
	for fixture: Dictionary in [
		{"id": "below_minimum", "at": Vector3(0, 5, -39.96), "v": Vector3(0, 0, -220)},
		{"id": "reverse", "at": Vector3(0, 5, -40.04), "v": Vector3(0, 0, 500)},
		{"id": "near_miss", "at": Vector3(5.1, 5, -39.96), "v": Vector3(0, 0, -500)},
		{"id": "high_miss", "at": Vector3(0, 10, -39.96), "v": Vector3(0, 0, -500)},
		{"id": "misaligned", "at": Vector3(0, 5, -39.96), "v": Vector3(300, 0, -300)}]:
		new_case(fixture.id, fixture.at, fixture.v)
		await ticks(4)
		check(not game.player.used and game.player.cue_serial == 0, "physical crossing refusal with labelled initial condition")
	new_case("unsupported_air_gate", Vector3(0, 6, -39.96), Vector3(0, 80, -500))
	await ticks(1)
	check(game.player.used and game.player.launched_airborne, "physical gate explicitly accepts a bhop with no grounded support")
	var launch: Dictionary = game.player.last_launch
	check(launch.before_mps.x == launch.after_mps.x and launch.before_mps.z == launch.after_mps.z, "actual launch changes only vertical velocity")
	check(game.player.cue_player.playing and game.player.cue_player.stream == game.player.cue and game.player.cue.data.size() > 10000, "real generated PCM AudioStreamPlayer activation on Dummy")
	await process_frame
	await process_frame
	check(game.hud.through_cue.visible and game.player.cue_left_s > 0.0, "actual cream screen cue activates")
	await ticks(2)
	var before := snapshot()
	tap(KEY_L)
	check(snapshot() == before and not game.look_enabled, "actual moving L leaves full physical state and identity unchanged")
	tap(KEY_L)
	tap(KEY_F9)
	check(snapshot() == before and game.look_enabled and game.hud.telemetry, "moving L restoration and F9 remain observational")
	game.set_paused(true)
	before = snapshot()
	await ticks(20)
	check(snapshot() == before and game.player.used and game.player.cue_left_s == 0.0 and not game.player.cue_player.playing, "pause freezes body clock ticks and consumed gate; cue clears")
	tap(KEY_L)
	tap(KEY_F9)
	await ticks(3)
	check(snapshot() == before and not game.look_enabled and not game.hud.telemetry, "actual paused L/F9 leave physical state unchanged")
	game.set_paused(false)
	await ticks(1)
	check(game.player.motion_tick == int(before.motion_tick) + 1 and game.player.cue_serial == 1, "resume continues same ballistic flight without duplicate impulse")
	# deliberate recross stress placement, with used state preserved, challenges duplicate launches.
	game.player.position = Vector3(0, 6, -39.96)
	game.player.velocity = Vector3(0, 0, -500) * 0.0254
	await ticks(2)
	check(game.player.cue_serial == 1, "labelled same-attempt recross cannot launch or farm twice")
	game.level.spawn = Transform3D(Basis.IDENTITY, Vector3(0, 4.04, -34))
	game.level.checkpoints[0].pose = game.level.spawn
	for reason: String in ["restart", "practice", "respawn"]:
		match reason:
			"restart": tap(KEY_R)
			"practice": tap(KEY_F)
			"respawn": game.respawn()
		check(not game.player.used and game.player.last_launch.is_empty() and game.player.cue_left_s == 0.0, reason + " rearms through public lifecycle")
		key(KEY_W, true)
		await ticks(160)
		key(KEY_W, false)
		check(game.player.used, reason + " rearmed fixture spawn physically launches again with real W input")
	var consumed: int = game.player.cue_serial
	game.select_preset("server128_aa1000")
	check(game.preset_id == "server128_aa1000" and game.player.used and game.player.cue_left_s == 0.0, "same-body preset boundary clears cue and cannot rearm/farm")
	await ticks(2)
	check(game.player.cue_serial == consumed, "preset boundary leaves no queued launch")
	var previous_body: int = game.player.get_instance_id()
	game.select_map("tether-yard")
	await ticks(2)
	check(game.map_id == "tether-yard" and not game.player.has_signal("through_diagnostic") and game.player.get_instance_id() != previous_body, "actual map boundary removes Through runner and cue")
	game.select_map("through-line")
	await ticks(2)
	check(not game.player.used and game.player.cue_left_s == 0.0, "returning to Through Line creates a fresh rearmed attempt")
	new_case("wrong_map", Vector3(0, 6, -39.96), Vector3(0, 0, -500))
	game.level.level_id = "labelled-wrong-map-fixture"
	await ticks(4)
	check(not game.player.used, "real runner refuses a gate crossing outside its level identity")
	for map: String in game.map_ids().duplicate():
		if map == "through-line":
			continue
		new_case("isolation_" + map, Vector3(0, 4.04, 12), Vector3.ZERO, map)
		await ticks(2)
		check(game.startup_error.is_empty() and not game.player.has_signal("through_diagnostic"), "current map works without Through runner: " + map)
		var motion_before := snapshot()
		tap(KEY_L)
		tap(KEY_L)
		tap(KEY_F9)
		tap(KEY_F9)
		check(snapshot() == motion_before, "L/F9 retain physical state on " + map)
		check(game.map_id == "tether-yard" if game.hud.tether_section.visible else game.map_id != "tether-yard", "Tether preferences remain Tether-only")
		var old: Node3D = R19.instantiate()
		old.map_id = map
		old.motor = "server128"
		old.persist = false
		old.record_runs = false
		old.seed_from_r15 = false
		old.set_window_title = false
		old.ghosts_directory = output.path_join("oldghosts")
		old.ghost_share_storage = output.path_join("oldselection")
		root.add_child(old)
		if map not in ["saltglass", "tether-yard"]:
			check(READER.identity_matches(old.motion_identity(), game.motion_identity()).is_empty(), "original complete motion identity unchanged: " + map)
		root.remove_child(old)
		old.free()
	close_case()
	var ok := checks.all(func(row: Dictionary) -> bool: return bool(row.ok))
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks, "episodes": episodes, "limits": "negative/lifecycle stress fixtures only; input-earned whole routes separately verified"}, "\t"))
	file.close()
	print("through component: ", checks.size(), " checks; ok=", ok)
	quit(0 if ok else 1)

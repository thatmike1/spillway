extends SceneTree
## independent adversarial loop review; fixture placements are labelled in the trace.
## observes real runner callbacks, positions, applied input and the public stats panel.

const MAIN = preload("res://scripts/r14_main.gd")
const FIXTURE = preload("res://tests/r14_loop_fixture_level.gd")
const U = 0.0254
var out := ""
var game: Node
var phase := ""
var checks: Array = []
var samples: Array = []
var trace: FileAccess
var recorder: Node

class Observer extends Node:
	var owner_review: SceneTree
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_physics_priority = 200
	func _physics_process(dt: float) -> void:
		owner_review.sample(dt)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	trace = FileAccess.open(out.path_join("trace.jsonl"), FileAccess.WRITE)
	recorder = Observer.new()
	recorder.owner_review = self
	root.add_child.call_deferred(recorder)
	run.call_deferred()

func v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func sample(dt: float) -> void:
	if game == null or not is_instance_valid(game) or game.player == null or game.paused:
		return
	var p: CharacterBody3D = game.player
	var state: Dictionary = p.get_motion_state()
	var row := {"phase": phase, "dt": dt, "preset": game.preset_id, "calls": game.physics_calls,
		"p": v(p.global_position), "v": v(p.velocity), "requested": v(state.get("requested_velocity", Vector3.ZERO)),
		"post": v(state.get("post_contact_velocity", p.velocity)), "yaw": p.yaw, "pitch": p.pitch,
		"start_velocity": v(state.get("start_velocity", Vector3.ZERO)),
		"side": Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		"forward": Input.get_action_strength("move_forward") - Input.get_action_strength("move_back"),
		"jump": Input.is_action_pressed("jump"), "grounded": p.is_grounded(), "jump_count": p.jump_count,
		"events": state.get("events", []), "motion_tick": state.get("tick"),
		"stats": game.stats.snapshot(), "hud": game.hud.strafe_live.text,
		"speed": game.display_speed_u(), "key": game.course_key, "clean": game.clean_eligible,
		"motor_flight": state.get("flight", {}), "motor_hop": state.get("last_hop", {}),
		"contacts": state.get("contacts", []), "state_takeoff": p.state.get("takeoff_speed", 0) if "state" in p else null}
	samples.append(row)
	trace.store_line(JSON.stringify(row))

func check(name: String, ok: bool, detail: Variant = null) -> void:
	var frozen: Variant = detail.duplicate(true) if detail is Dictionary or detail is Array else detail
	checks.append({"phase": phase, "name": name, "ok": ok, "detail": frozen})
	print("PASS " if ok else "FAIL ", name, " ", detail if not ok else "")

func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func mouse(radians: float, pitch_radians := 0.0) -> void:
	var p: Node = game.player
	var sensitivity: float = p.tape_radians_per_count if "tape_radians_per_count" in p else p.mouse_sensitivity
	var e := InputEventMouseMotion.new()
	e.screen_relative = Vector2(-radians / sensitivity, -pitch_radians / sensitivity)
	e.relative = e.screen_relative
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func wheel() -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_UP
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()

func ticks(n: int) -> void:
	for i in n:
		await physics_frame

func release() -> void:
	for code in [KEY_W, KEY_A, KEY_D, KEY_S, KEY_SPACE, KEY_CTRL]:
		key(code, false)

func make(alias := "server128", actual_map := false) -> void:
	release()
	if game != null:
		game.set_paused(false)
		game.free()
		game = null
		await ticks(2)
	FIXTURE.params = {}
	game = MAIN.new()
	game.motor = alias
	if not actual_map:
		game.level_script = FIXTURE
	root.add_child(game)
	await ticks(15)

func hop(turn := 0.0, side := 0, delay := 0) -> Dictionary:
	await ticks(delay)
	var before: int = game.stats.hop_count
	if side != 0:
		key(KEY_A if side < 0 else KEY_D, true)
	key(KEY_SPACE, true)
	await ticks(2)
	key(KEY_SPACE, false)
	for i in 200:
		if turn != 0.0:
			mouse(turn)
		await ticks(1)
		if game.player.is_grounded() and game.stats.hop_count > before:
			break
	release()
	return game.stats.last_hop.duplicate(true)

func run() -> void:
	phase = "default-late-rate"
	# reproduces project.godot's untouched 120 Hz before scene _ready, with no launch helper.
	Engine.physics_ticks_per_second = 120
	game = (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate()
	root.add_child(game)
	await ticks(12)
	check("default scene is R14 server128 and settles at actual 1/128", game.preset_id == "server128" and game.rate_ok and absf(game.last_delta - 1.0 / 128) < 1e-7, game.rate_log)
	check("untouched default spawn remains record eligible", game.clean_eligible, game.practice_reason)
	phase = "manual-held"
	await make("vanilla64")
	key(KEY_SPACE, true)
	await ticks(130)
	key(KEY_SPACE, false)
	check("vanilla held jump has one real takeoff", game.player.state.jump_count == 1, game.player.state.jump_count)
	wheel()
	await ticks(60)
	check("wheel released before a tick causes another real hop", game.player.state.jump_count == 2, game.player.state.jump_count)
	# the preceding negative attempt had no neutral command after releasing held Space.
	await ticks(1)
	wheel()
	await ticks(60)
	check("wheel with a neutral command after held Space jumps", game.player.state.jump_count == 2, game.player.state.jump_count)
	phase = "first-hop-after-switch"
	await make("server128")
	game.select_preset("vanilla64")
	wheel()
	await ticks(3)
	check("immediate post-switch wheel really leaves the ground", not game.player.is_grounded() and game.player.global_position.y > 0.08, v(game.player.global_position))
	await ticks(70)
	check("first immediate hop after switch is counted by HUD", game.stats.hop_count == 1, {"hops": game.stats.hop_count, "motor": game.player.last_hop, "hud": game.hud.strafe_live.text})
	phase = "early-midflight-switch"
	await make("server128")
	key(KEY_SPACE, true)
	await ticks(6)
	key(KEY_SPACE, false)
	check("initial hop really moves before timer arms", not game.player.is_grounded() and game.player.global_position.y > 0.2 and not game._started, {"p": v(game.player.global_position), "started": game._started})
	game.select_preset("vanilla64")
	await ticks(20)
	check("mixed-preset initial airborne attempt is practice", not game.clean_eligible, {"p": v(game.player.global_position), "started": game._started, "clean": game.clean_eligible, "reason": game.practice_reason, "rate_log": game.rate_log})
	game.persist = true
	game.profile_path = out.path_join("early-mixed-records.cfg")
	key(KEY_W, true)
	for i in 3000:
		await ticks(1)
		if game.finished:
			break
	key(KEY_W, false)
	check("mixed-preset actual finish cannot save a vanilla clean record", game.finished and game.finish_kind == "practice" and not game.last_save_ok, {"kind": game.finish_kind, "clean": game.clean_eligible, "saved": game.last_save_ok, "preset": game.preset_id, "key": game.course_key, "splits": game.stage_times})
	phase = "midflight-preserve"
	await make("server128")
	key(KEY_W, true)
	await ticks(55)
	key(KEY_W, false)
	key(KEY_SPACE, true)
	await ticks(12)
	key(KEY_SPACE, false)
	mouse(0.3, 0.2)
	await ticks(1)
	for id in ["vanilla64", "r13_original120", "server128"]:
		var before: Vector3 = game.player.global_position
		var vel: Vector3 = game.player.velocity
		var yaw: float = game.player.yaw
		var pitch: float = game.player.pitch
		game.select_preset(id)
		check("switch %s preserves feet, velocity and view immediately" % id, game.player.global_position == before and game.player.velocity == vel and game.player.yaw == yaw and absf(game.player.pitch - pitch) < 1e-6)
		await ticks(3)
		check("switch %s actually continues horizontal travel" % id, Vector2(game.player.global_position.x - before.x, game.player.global_position.z - before.z).length() > 0.02, v(game.player.global_position - before))
		check("airborne switch %s HUD says airborne" % id, game.player.is_grounded() or game.hud.strafe_live.text.begins_with("in the air"), {"grounded": game.player.is_grounded(), "hud": game.hud.strafe_live.text, "p": v(game.player.global_position)})
	check("active switched attempt is practice", not game.clean_eligible)
	phase = "independent-stats-coast"
	await make()
	key(KEY_W, true)
	await ticks(55)
	key(KEY_W, false)
	var coast := await hop(0.012)
	check("coast sync has no eligible ticks", coast.get("eligible", -1) == 0 and coast.get("sync") == null, coast)
	check("coast actual open-air speed retained", absf(float(coast.get("gain", 999))) < 0.05, coast)
	phase = "independent-stats-opposite"
	await make()
	key(KEY_W, true)
	await ticks(55)
	key(KEY_W, false)
	var opposite := await hop(-0.012, -1)
	check("opposite A plus right turn is zero sync", opposite.get("good", -1) == 0 and opposite.get("eligible", 0) > 20 and opposite.get("sync") == 0.0, opposite)
	phase = "independent-stats-good"
	await make()
	key(KEY_W, true)
	await ticks(55)
	key(KEY_W, false)
	var good := await hop(0.012, -1)
	check("same-direction A plus left turn is high sync", good.get("sync", 0) != null and float(good.get("sync", 0)) > 0.95, good)
	phase = "independent-stats-wall"
	await make()
	mouse(PI / 2)
	key(KEY_W, true)
	await ticks(45)
	key(KEY_W, false)
	var wall := await hop(0.004, -1)
	check("wall contact is separate from sync", wall.get("contact", 0) < -20 and wall.get("wall_ticks", 0) > 0 and wall.get("sync", 0) != null and wall.get("sync", 0) > 0.9, wall)
	phase = "independent-stats-ground"
	await make("vanilla64")
	key(KEY_W, true)
	await ticks(30)
	key(KEY_W, false)
	await hop(0.02, -1)
	await ticks(14)
	wheel()
	await ticks(3)
	check("late vanilla hop books ground loss", game.stats.last_hop.get("ground", 0) < -5 and game.stats.last_hop.get("ground_ticks", 0) >= 14, game.stats.last_hop)
	phase = "restart-counter"
	game.restart_run()
	await ticks(8)
	await hop()
	check("restart jump counter discontinuity still counts a real hop", game.stats.hop_count == 1, game.stats.snapshot())
	phase = "drop-labelled-placement"
	await make()
	# a fixture placement creates a drop, without fabricating a jump or motion callback.
	game.player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 4)))
	game.stats.reset()
	await ticks(8)
	check("drop really moves vertically while airborne", not game.player.is_grounded() and game.player.global_position.y < 1.49, v(game.player.global_position))
	check("falling with no jump HUD says airborne", game.hud.strafe_live.text.begins_with("in the air"), game.hud.strafe_live.text)
	await ticks(70)
	phase = "tiny-air-labelled-placement"
	game.player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.06, 4)))
	game.stats.reset()
	await ticks(8)
	check("tiny drop does not invent jump stats", game.stats.hop_count == 0 and game.player.state.jump_count == 0, game.stats.snapshot())
	phase = "one-tick-hop-labelled-ceiling"
	await make()
	var roof := StaticBody3D.new()
	var roof_shape := CollisionShape3D.new()
	var roof_box := BoxShape3D.new()
	roof_box.size = Vector3(3, 0.2, 3)
	roof_shape.shape = roof_box
	roof_shape.position = Vector3(0, 1.975, 4)
	roof.add_child(roof_shape)
	game.add_child(roof)
	await ticks(2)
	wheel()
	await ticks(2)
	var short_rows: Array = samples.filter(func(r: Dictionary) -> bool: return r.phase == phase and "jump" in r.events)
	check("ceiling fixture produces a real one-step jump and landing", short_rows.size() == 1 and "land" in short_rows[0].events, short_rows)
	check("one-step hop is counted once", game.stats.hop_count == 1 and game.stats.last_hop.get("air_ticks", 0) == 1, game.stats.snapshot())
	phase = "pending-cancel"
	await make("r13")
	game.player.reset_to(Transform3D(Basis.IDENTITY, Vector3(9, 0.04, -1)))
	await ticks(8)
	game.select_preset("server128")
	check("source hull waits in 0.7m slot", game.pending_preset == "server128" and game.preset_id == "r13_original120", game.pending_message)
	game.select_preset("r13")
	check("active preset cancels pending switch", game.pending_preset == "")
	phase = "pending-move-out"
	game.select_preset("server128")
	key(KEY_W, true)
	for i in 180:
		await ticks(1)
		if game.pending_preset == "":
			break
	key(KEY_W, false)
	check("pending switch applies when actual movement exits narrow slot", game.preset_id == "server128" and game.pending_preset == "" and game.player.global_position.z < -4, v(game.player.global_position))
	phase = "pending-map"
	await make("r13")
	game.player.reset_to(Transform3D(Basis.IDENTITY, Vector3(9, 0.04, -1)))
	await ticks(8)
	game.select_preset("server128")
	game.select_map("practice")
	await ticks(8)
	check("map change keeps selected active preset", game.preset_id == "r13_original120", {"preset": game.preset_id, "pending": game.pending_preset})
	phase = "pending-restart"
	await make("r13")
	game.player.reset_to(Transform3D(Basis.IDENTITY, Vector3(9, 0.04, -1)))
	await ticks(8)
	game.select_preset("server128")
	game.restart_run()
	await ticks(8)
	check("restart applies pending at open spawn cleanly", game.preset_id == "server128" and game.pending_preset == "" and game.clean_eligible)
	phase = "pause-switch-resume"
	for id in ["vanilla64", "r13_original120", "server128"]:
		game.set_paused(true)
		game.select_preset(id)
		var at: Vector3 = game.player.global_position
		var elapsed: float = game.elapsed
		await ticks(10)
		check("paused %s preserves position and clock" % id, game.player.global_position == at and game.elapsed == elapsed)
		game.set_paused(false)
		await ticks(8)
		check("resume %s delivers actual selected delta" % id, absf(game.last_delta - 1.0 / game.physics_hz) < 1e-7, game.rate_log)
	phase = "records-full-splits"
	await make()
	game.persist = true
	game.profile_path = out.path_join("records.cfg")
	var first_key: String = game.course_key
	key(KEY_W, true)
	for i in 3000:
		await ticks(1)
		if game.finished:
			break
	key(KEY_W, false)
	check("actual fixture route finishes cleanly", game.finished and game.finish_kind == "clean", game.stage_times)
	var expected_splits: Array = game.stage_times.duplicate()
	var expected_segments: Array = game.best_segments.duplicate()
	var expected_best: float = game.best_time
	var cfg := ConfigFile.new()
	check("full split and segment values persist", cfg.load(game.profile_path) == OK and cfg.get_value("course_" + first_key, "clean_splits", []) == expected_splits and cfg.get_value("course_" + first_key, "clean_segments", []) == expected_segments, {"splits": expected_splits, "segments": expected_segments})
	game.select_preset("vanilla64")
	check("preset keys isolate all record values", game.course_key != first_key and game.best_time < 0 and game.best_splits.is_empty() and game.best_segments.is_empty())
	game.select_preset("server128")
	check("switching back restores full split values", game.best_splits == expected_splits and game.best_segments == expected_segments and game.best_time == expected_best)
	phase = "practice-after-finish"
	var record_before := FileAccess.get_sha256(game.profile_path)
	game.practice_restart()
	await ticks(4)
	check("F after finish starts last-stage practice with reset feedback", game.practice_stage == 2 and not game.clean_eligible and not game.finished and game.stats.hop_count == 0)
	key(KEY_W, true)
	for i in 1000:
		await ticks(1)
		if game.finished:
			break
	key(KEY_W, false)
	check("practice finish leaves full stored splits untouched", game.finished and game.finish_kind == "practice" and FileAccess.get_sha256(game.profile_path) == record_before, {"kind": game.finish_kind, "splits": game.stage_times})
	phase = "records-reload"
	# reloading records into a new instance, with identical fixture geometry and cvars.
	await make()
	game.persist = true
	game.profile_path = out.path_join("records.cfg")
	game._load_records()
	check("fresh runner loads complete record values", game.best_splits == expected_splits and game.best_segments == expected_segments and game.best_time == expected_best)
	var original_key: String = game.course_key
	game.change_setting("source_sensitivity", 4.25)
	game.change_setting("source_fov", 105)
	check("look changes preserve record identity", game._course_key() == original_key)
	game.select_map("overflow")
	check("map isolates records and resets attempt stats", game.course_key != original_key and game.best_time < 0 and game.stats.hop_count == 0 and game.clean_eligible)
	release()
	game.set_paused(false)
	game.free()
	game = null
	trace.close()
	var file := FileAccess.open(out.path_join("checks.json"), FileAccess.WRITE)
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.ok)
	file.store_string(JSON.stringify({"checks": checks, "total": checks.size(), "failed": failed.size(), "samples": samples.size()}, "  "))
	file.close()
	print("review: %d/%d passed, %d callbacks" % [checks.size() - failed.size(), checks.size(), samples.size()])
	quit(1 if failed.size() else 0)

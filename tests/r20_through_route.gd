extends "res://tests/r14_practice_driver.gd"
## real production spawn; input-only route discovery or exact replay of saved binary input rows.
const SCENE := preload("res://scenes/r20.tscn")
const READER := preload("res://scripts/r16_run_reader.gd")
const EXTRA_KEYS := {"l": KEY_L, "f9": KEY_F9, "r": KEY_R, "f": KEY_F, "esc": KEY_ESCAPE}
var game: Node3D
var replay_frames := {}
var telemetry := PackedStringArray()
var closing := false
var launch := {}
var landing := {}
var flight_apex := {}
var baseline_ids := []
var observations := 0
var look_checked := false
var failure := ""

func _start() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	Engine.physics_ticks_per_second = 128
	RenderingServer.render_loop_enabled = false
	game = SCENE.instantiate()
	game.map_id = "through-line"
	game.motor = "server128"
	game.seed_from_r15 = false
	game.source_sensitivity_override = 2.5
	game.set_window_title = false
	game.persist = false
	game.record_runs = true
	game.recordings_dir = out_dir.path_join("recordings")
	game.ghosts_directory = out_dir.path_join("ghosts")
	game.ghost_share_storage = out_dir.path_join("ghost-selection.cfg")
	root.add_child(game)
	game.hud.dismiss_title()
	lab = game
	level = game.level
	player = game.player
	source = true
	hz = Engine.physics_ticks_per_second
	warmup = 33
	max_ticks = 5000
	radians_per_count = float(player.tape_radians_per_count)
	turn_cap = deg_to_rad(480.0) / hz
	amp = deg_to_rad(20.0)
	node_from = Vector2(player.position.x, player.position.z)
	nodes = [{"p": Vector2(0, -40), "r": 0.1, "hop": true, "vt": float(opts.get("speed", "500"))},
		{"p": Vector2(0, -134), "r": 1.0, "hop": true, "vt": 500.0}]
	baseline_ids = [player.get_instance_id(), level.get_instance_id(), game.session.get_instance_id()]
	player.cue.save_to_wav(out_dir.path_join("launch-cue.wav"))
	if opts.has("tape"):
		_load_tape(str(opts.tape))
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)

func late_step() -> void:
	if player == null or done:
		return
	step += 1
	if not armed:
		if step < warmup:
			return
		armed = true
		arm_step = step
	var tick := step - arm_step
	if tick > 0:
		_observe(tick - 1)
	if done:
		return
	if tick >= max_ticks or finish_tick >= 0:
		_end("finished" if finish_tick >= 0 else "budget", tick)
		return
	if not replay.is_empty():
		for event: Dictionary in replay_frames.get(tick, []):
			_raw_input(event.raw)
	else:
		if opts.has("look") and tick in [100, 101, 600, 601]:
			_key("l", tick % 2 == 0, tick)
		if player.used and player.last_landing.is_empty():
			# no air steering in the transfer: a measured ballistic flight at the earned incoming speed.
			_want({}, tick)
		else:
			if player.used:
				node_index = 1
				node_from = Vector2(0, -60)
			super._control_source(tick)

func _observe(tick: int) -> void:
	super._observe(tick)
	var motion: Dictionary = player.get_motion_state()
	observations += 1
	if launch.is_empty() and not player.last_launch.is_empty():
		launch = plain(player.last_launch)
		launch["route_tick"] = tick
	if landing.is_empty() and not player.last_landing.is_empty():
		landing = plain(player.last_landing)
		landing["route_tick"] = tick
	if flight_apex.is_empty() and not player.apex.is_empty():
		flight_apex = plain(player.apex)
		flight_apex["route_tick"] = tick
	assert(baseline_ids == [player.get_instance_id(), level.get_instance_id(), game.session.get_instance_id()])
	telemetry.append(JSON.stringify({"tick": tick, "p": plain(player.position), "reference_p": plain(game.body_reference()), "v": plain(player.velocity),
		"yaw": player.yaw, "pitch": player.pitch, "grounded": player.is_grounded(), "motion": plain(motion), "checkpoint": game.checkpoint_index,
		"elapsed": game.elapsed, "respawns": game.respawn_count, "style": plain(game.session.style.snapshot()), "session_tick": game.session.tick,
		"attempts": game.attempts, "physics_calls": game.physics_calls}, "", false, true))
	if game.respawn_count > 0:
		failure = "respawn"
		_end(failure, tick + 1)

func _end(reason: String, tick: int) -> void:
	if closing:
		return
	closing = true
	done = true
	_want({}, tick)
	await process_frame
	await process_frame
	var recordings := []
	for sealed: Dictionary in game.session.sealed:
		var rec: Dictionary = READER.read(str(sealed.path))
		recordings.append({"path": sealed.path, "ok": rec.ok, "errors": rec.errors, "clean_finish": READER.clean_finish(rec), "header": rec.header, "seal": rec.seal, "events": rec.events})
	var passed: bool = game.finished and game.finish_kind == "clean" and game.respawn_count == 0 and not launch.is_empty() and not landing.is_empty() and not flight_apex.is_empty() and player.continued and game.session.actual_v_mismatches == 0 and game.rate_mismatch_ticks == 0
	_write("summary.json", {"pass": passed, "reason": reason, "failure": failure, "elapsed": game.elapsed, "ticks": tick, "launch": launch, "landing": landing, "apex": flight_apex,
		"finished": game.finished, "finish_kind": game.finish_kind, "clean": game.clean_eligible, "respawns": game.respawn_count, "continued": player.continued,
		"identity": game.motion_identity(), "mechanics": plain(game.mechanics()), "recordings": recordings, "geometry_hash": level.geometry_hash(), "runner": game.runner_path(),
		"actual_v_mismatches": game.session.actual_v_mismatches, "rate_mismatch_ticks": game.rate_mismatch_ticks, "physics_hz": hz,
		"setup": "one authored spawn; no later test pose, velocity, view, score or progress writes; inputs only", "mode": "open-loop binary saved input" if not replay.is_empty() else "input route finder"})
	_write("events.tape.json", {"version": 2, "physics_hz": hz, "duration_ticks": tick, "events": events})
	var file := FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(telemetry) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("through: pass=", passed, " time=", game.elapsed, " launch=", launch, " apex=", flight_apex, " landing=", landing, " final=", player.position)
	game.request_quit(0 if passed else 1)

func _load_tape(path: String) -> void:
	replay = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(int(replay.version) == 2 and int(replay.physics_hz) == hz)
	for event: Dictionary in replay.events:
		var tick := int(event.tick)
		if not replay_frames.has(tick):
			replay_frames[tick] = []
		replay_frames[tick].append(event)
	max_ticks = int(replay.duration_ticks)

func _raw_input(row: Dictionary) -> void:
	var input: InputEvent
	if int(row.kind) == 1:
		var key := InputEventKey.new()
		key.keycode = int(row.code)
		key.physical_keycode = int(row.aux)
		key.pressed = (int(row.flags) & 1) != 0
		key.echo = (int(row.flags) & 2) != 0
		input = key
	elif int(row.kind) == 2:
		var button := InputEventMouseButton.new()
		button.button_index = int(row.code)
		button.pressed = (int(row.flags) & 1) != 0
		button.double_click = (int(row.flags) & 4) != 0
		button.factor = float(row.x)
		input = button
	else:
		var motion := InputEventMouseMotion.new()
		motion.screen_relative = Vector2(float(row.x), float(row.y))
		motion.relative = Vector2(float(row.x2), float(row.y2))
		input = motion
	Input.parse_input_event(input)
	Input.flush_buffered_events()
	events.append({"tick": step - arm_step, "raw": row})

func _mouse2(counts: Vector2) -> void:
	if counts == Vector2.ZERO:
		return
	var event := InputEventMouseMotion.new()
	event.relative = counts
	event.screen_relative = counts
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	# preserve the actual event sequence, including float32 relative values.
	events.append({"tick": step - arm_step, "mouse": [event.relative.x, event.relative.y]})

func _key(key: String, pressed: bool, tick: int) -> void:
	if key in ["lmb", "rmb"]:
		if pressed == held.has(key):
			return
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT if key == "lmb" else MOUSE_BUTTON_RIGHT
		button.pressed = pressed
		Input.parse_input_event(button)
		Input.flush_buffered_events()
		if pressed:
			held[key] = true
		else:
			held.erase(key)
		events.append({"tick": tick, "button": button.button_index, "edge": "press" if pressed else "release"})
		return
	if not EXTRA_KEYS.has(key):
		super(key, pressed, tick)
		return
	if pressed == held.has(key):
		return
	var event := InputEventKey.new()
	event.keycode = EXTRA_KEYS[key]
	event.physical_keycode = EXTRA_KEYS[key]
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed:
		held[key] = true
	else:
		held.erase(key)
	events.append({"tick": tick, "key": key, "edge": "press" if pressed else "release"})

func _want(want: Dictionary, tick: int) -> void:
	for key: String in ["lmb", "rmb"] + EXTRA_KEYS.keys():
		if want.has(key) != held.has(key):
			_key(key, want.has(key), tick)
	super._want(want, tick)

static func plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Array:
		return value.map(func(v: Variant) -> Variant: return plain(v))
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = plain(value[key])
		return out
	return value

extends "res://tests/r14_practice_driver.gd"
## coordinate-aware input route finder; saved input replays open loop with no control observations.
const SCENE := preload("res://scenes/r20.tscn")
const READER := preload("res://scripts/r16_run_reader.gd")
const GEOMETRY := preload("res://tests/r19_tether_geometry.gd")
const TETHER_LEVEL := preload("res://scripts/r19_tether_level.gd")
const EXTRA_KEYS := {"e": KEY_E, "shift": KEY_SHIFT, "one": KEY_1, "two": KEY_2, "three": KEY_3, "r": KEY_R, "esc": KEY_ESCAPE}
var game: Node3D
var telemetry := PackedStringArray()
var replay_frames := {}
var attached_ticks := 0
var pull_ticks := 0
var rope_ticks := 0
var attaches := {}
var releases: Array = []
var phases: Array = []
var last_phase := -1
var closing := false
var max_height := -INF
var failure := ""

func _start() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	Engine.physics_ticks_per_second = 128
	RenderingServer.render_loop_enabled = false
	max_ticks = int(opts.get("max-ticks", "6000"))
	game = SCENE.instantiate()
	game.map_id = "tether-yard"
	if opts.has("old-e"):
		game.source_runner = load(str(opts.baseline))
	game.name = "R20"
	game.motor = "server128"
	game.seed_from_r15 = false
	game.source_sensitivity_override = 2.5
	game.set_window_title = false
	game.persist = true
	game.profile_path = out_dir.path_join("profile.cfg")
	game.record_runs = true
	game.recordings_dir = out_dir.path_join("recordings")
	game.ghosts_directory = out_dir.path_join("ghosts")
	game.ghost_share_storage = out_dir.path_join("ghost-selection.cfg")
	root.add_child(game)
	if not opts.has("old-e"):
		# use the actual pause buttons and their production setting handlers before route setup.
		game.set_paused(true)
		if str(opts.get("model", "classic")) != "classic":
			game.hud.tether_models[str(opts.model)].pressed.emit()
		if opts.has("auto"):
			game.hud.reel_automatic.pressed.emit()
		game.set_paused(false)
	lab = game
	level = game.level
	player = game.player
	_write("geometry.json", GEOMETRY.audit(level))
	source = true
	hz = Engine.physics_ticks_per_second
	warmup = 33
	radians_per_count = float(player.tape_radians_per_count)
	turn_cap = deg_to_rad(480.0) / hz
	amp = deg_to_rad(20.0)
	node_from = Vector2(player.position.x, player.position.z)
	nodes = [
		{"p": Vector2(0, 1), "r": 0.25},
		{"anchor": 0},
		{"p": Vector2(0, -22), "fall": 4.2},
		{"p": Vector2(4, -29), "r": 0.25},
		{"anchor": 1},
		{"p": Vector2(12, -52), "fall": 4.2},
		{"p": Vector2(10, -59), "r": 0.25},
		{"anchor": 2},
		{"p": Vector2(-4, -83), "fall": 4.2},
		{"p": Vector2(-4, -87), "r": 0.5},
	]
	if str(opts.get("model", "classic")) != "classic":
		# land near the front of the final deck before entering its high finish volume.
		nodes[6].p = Vector2(6, -57)
		nodes[8].p = Vector2(-4, -78)
	if opts.has("tape"):
		_load_tape(str(opts.tape))
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("tether route: configured R20 scene/session; normal authored spawn; input only; ", "open-loop replay" if not replay.is_empty() else "coordinate-aware route finder")

func _load_tape(path: String) -> void:
	replay = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(int(replay.version) == 2 and int(replay.physics_hz) == hz)
	for event: Dictionary in replay.events:
		var tick := int(event.tick)
		if not replay_frames.has(tick):
			replay_frames[tick] = []
		replay_frames[tick].append(event)
	max_ticks = int(replay.duration_ticks)

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
	if tick >= max_ticks or _route_finished(tick):
		_end("finished" if finish_tick >= 0 else "budget", tick)
		return
	if not replay.is_empty():
		for event: Dictionary in replay_frames.get(tick, []):
			if event.has("raw"):
				_raw_input(event.raw)
			elif event.has("key"):
				_key(str(event.key), str(event.edge) == "press", tick)
			elif event.has("button"):
				_key("lmb" if int(event.button) == 1 else "rmb", str(event.edge) == "press", tick)
			else:
				_mouse2(Vector2(float(event.mouse[0]), float(event.mouse[1])))
	else:
		_control_source(tick)

func _route_finished(_tick: int) -> bool:
	return finish_tick >= 0

func _control_source(tick: int) -> void:
	if node_index != last_phase:
		phases.append({"node": node_index, "tick": tick, "p": plain(player.position)})
		last_phase = node_index
	if node_index < nodes.size() and nodes[node_index].has("anchor"):
		var index := int(nodes[node_index].anchor)
		var anchor: Vector3 = TETHER_LEVEL.ANCHORS[index]
		var release_height := 4.1 if str(opts.get("model", "classic")) == "pendulum" and index == 2 else 5.0
		if player.position.z <= anchor.z + float(opts.get("release-before", "0")) and player.position.y > release_height:
			_want({}, tick)
			_next(Vector2(player.position.x, player.position.z), tick)
			return
		_aim_point(anchor)
		_want(_rope_want(player.is_grounded()), tick)
		return
	# keep the view level when the ordinary route finder moves toward a deck.
	_pitch_to(0.0)
	super._control_source(tick)

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

func _rope_want(jump: bool) -> Dictionary:
	var want := {"e": true} if opts.has("old-e") else {"lmb": true, "rmb": not opts.has("auto")}
	if jump:
		want["space"] = true
	return want

func _aim_point(target: Vector3) -> void:
	var to: Vector3 = target - player._eye()
	_turn_to(atan2(-to.x, -to.z))
	_pitch_to(atan2(to.y, Vector2(to.x, to.z).length()))

func _pitch_to(target: float) -> void:
	var change := clampf(float(player.pitch) - target, -turn_cap, turn_cap)
	if absf(change) > 1e-7:
		_mouse2(Vector2(0, change / radians_per_count))

func _mouse(px: float, _tick: int) -> void:
	_mouse2(Vector2(px, 0))

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

func _observe(tick: int) -> void:
	super._observe(tick)
	var motion: Dictionary = player.get_motion_state()
	var experiment: Dictionary = motion.experiment
	if bool(experiment.grapple.attached):
		attached_ticks += 1
		attaches[experiment.grapple.anchor] = int(attaches.get(experiment.grapple.anchor, 0)) + 1
	if (experiment.impulses_u.get("grapple_pull", Vector3.ZERO) as Vector3).length() > 1e-8:
		pull_ticks += 1
	if (experiment.impulses_u.get("grapple_rope", Vector3.ZERO) as Vector3).length() > 1e-8:
		rope_ticks += 1
	if "grapple_release" in experiment.events:
		releases.append({"tick": tick, "reason": experiment.grapple.release, "p": plain(player.position), "v": plain(player.velocity)})
	max_height = maxf(max_height, player.position.y)
	telemetry.append(JSON.stringify({"tick": tick, "p": plain(player.position), "reference_p": plain(game.body_reference()), "v": plain(player.velocity),
		"yaw": player.yaw, "pitch": player.pitch, "grounded": player.is_grounded(), "held": held.keys(), "motion": plain(motion),
		"checkpoint": game.checkpoint_index, "elapsed": game.elapsed, "respawns": game.respawn_count, "style": plain(game.session.style.snapshot())}, "", false, true))
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
	var reads: Array = []
	for sealed: Dictionary in game.session.sealed:
		var run: Dictionary = READER.read(str(sealed.path))
		reads.append({"path": sealed.path, "ok": run.ok, "errors": run.errors, "clean_finish": READER.clean_finish(run), "status": run.status, "seal": run.seal, "header": run.header, "events": run.events, "columns": run.columns, "inputs": run.inputs})
	var summary := {"finished": game.finished, "finish_kind": game.finish_kind, "clean": game.clean_eligible, "elapsed": game.elapsed, "respawns": game.respawn_count,
		"reason": reason, "failure": failure, "ticks": tick, "node": node_index, "phases": phases, "final": plain(player.position), "max_height": max_height,
		"attached_ticks": attached_ticks, "pull_ticks": pull_ticks, "rope_ticks": rope_ticks, "anchors": attaches, "releases": releases,
		"identity": game.motion_identity(), "geometry_hash": level.geometry_hash(), "mechanics": plain(game.mechanics()), "runner": game.runner_path(),
		"recordings": reads, "actual_v_mismatches": game.session.actual_v_mismatches, "rate_mismatch_ticks": game.rate_mismatch_ticks,
		"style": game.session.style.summary(), "mode": "open-loop saved input" if not replay.is_empty() else "coordinate-aware input only",
		"options": opts, "setup": "one host-authored spawn; no test body/camera/progress/velocity writes", "physics_hz": hz}
	var passed := _accept(summary)
	summary["pass"] = passed
	_write("summary.json", summary)
	_write("events.tape.json", {"format": "spillway-momentum-tape", "version": 2, "name": "r19-tether-yard", "physics_hz": hz, "duration_ticks": tick, "events": events})
	var file := FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(telemetry) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("tether: pass=", passed, " finish=", game.finished, " time=", game.elapsed, " anchors=", attaches, " releases=", releases, " node=", node_index, " final=", player.position)
	# request_quit owns its asynchronous eight-frame drain and actual process exit.
	game.request_quit(0 if passed else 1)

func _accept(summary: Dictionary) -> bool:
	return bool(summary.finished) and str(summary.finish_kind) == "clean" and int(summary.respawns) == 0 and attaches.size() == 3 \
		and (pull_ticks > 100 or str(opts.get("model", "classic")) == "pendulum") and releases.size() >= 3 and int(summary.actual_v_mismatches) == 0 and int(summary.rate_mismatch_ticks) == 0 \
		and reads_clean(summary.recordings)

static func reads_clean(reads: Array) -> bool:
	return reads.any(func(r: Dictionary) -> bool: return bool(r.ok) and bool(r.clean_finish.get("ok", false)))

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

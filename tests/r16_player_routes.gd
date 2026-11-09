extends "res://tests/r15_whiteout_driver.gd"
## input-only, coordinate-aware bots on the production r16 host; no post-spawn state restores.
## route data and the ordinary course controller are inherited, never patched.

const HOST16 := preload("res://scripts/r16_main.gd")
const READER16 := preload("res://scripts/r16_run_reader.gd")
const ALL_KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL, "shift": KEY_SHIFT, "e": KEY_E}
var route_name := ""
var phase := "approach"
var phase_tick := 0
var jump_at := -1
var passage_done := false
var terminal_waiting := false
var rows := PackedStringArray()
var phases: Array = []
var lab_events: Array = []

func _start() -> void:
	route_name = str(opts.get("route", "whiteout-apron"))
	max_ticks = int(opts.get("max-ticks", "24000"))
	amp = deg_to_rad(5.0 if route_name == "lab-flow" else 30.0)
	game = HOST16.new()
	game.name = "R16"
	game.map_id = "experiment" if route_name == "lab-flow" else "whiteout-relay"
	game.motor = "server128"
	game.seed_from_r15 = false
	game.source_sensitivity_override = 2.5
	game.set_window_title = false
	game.persist = true
	game.recordings_dir = out_dir.path_join("recordings")
	game.record_runs = true
	game.profile_path = out_dir.path_join("profile.cfg")
	root.add_child(game)
	lab = game
	level = game.level
	player = game.player
	source = true
	hz = Engine.physics_ticks_per_second
	warmup = 33
	radians_per_count = float(player.tape_radians_per_count)
	turn_cap = deg_to_rad(600.0) / hz
	nodes = [{"p": Vector2(-4.5, -18.5), "r": 0.25}, {"p": Vector2(-8, -22.5), "r": 0.2}]
	node_from = Vector2(player.global_position.x, player.global_position.z)
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("r16 player bot route=", route_name, " normal spawn, warmup=", warmup, " source sensitivity=2.5")

func _route_finished(_tick: int) -> bool:
	return finish_tick >= 0

func _phase(next: String, tick: int) -> void:
	phases.append({"phase": next, "tick": tick, "p": plain(player.global_position), "v": plain(player.velocity)})
	phase = next
	phase_tick = tick

func _control_source(tick: int) -> void:
	if route_name == "lab-flow":
		_lab_control(tick)
		return
	if passage_done or node_index < nodes.size():
		super._control_source(tick)
		return
	var p := player.global_position
	var here := Vector2(p.x, p.z)
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var want := {}
	if jump_at < 0:
		_look(here, Vector2(-8, -40))
		want = {"w": true}
		if player.is_grounded() and p.z + 28.0 <= speed * 0.375 and p.z > -28.0:
			want["space"] = true
			jump_at = tick
	else:
		if not player.is_grounded() and tick >= jump_at + 2:
			want["ctrl"] = true
	if p.z < -31.0 and player.is_grounded():
		passage_done = true
		nodes = [{"p": Vector2(0, -39)}, {"p": Vector2(0, -44)}] + ROAD + PYLONS + CATWALK + RING + WEAVE + RELAY
		node_index = 0
		node_from = here
		_phase("ordinary route after earned apron passage", tick)
	_want(want, tick)

func _lab_control(tick: int) -> void:
	var p := player.global_position
	var g: bool = player.is_grounded()
	var ex: Dictionary = player.get_motion_state().experiment
	var want := {"w": true}
	match phase:
		"approach":
			if p.z < -3.0:
				_phase("bhop lead-in", tick)
				want["space"] = true
		"bhop lead-in":
			want = _air(Vector2(p.x, p.z), Vector2(0, -40), 280.0, false) if not g else {"w": true}
			want["space"] = true
			if g and p.z < -7.0:
				_phase("bhop", tick)
		"bhop":
			want = _air(Vector2(p.x, p.z), Vector2(0, -40), 280.0, false) if not g else {"w": true}
			want["space"] = true
			if not g and player.velocity.y < 0.0 and p.z < -17.5 and p.y < 0.5:
				want["shift"] = true
				_phase("landing slide", tick)
		"landing slide":
			want.merge({"space": true, "shift": true})
			if p.z < -27.45 and g:
				want.erase("space")
				_phase("space released", tick)
		"space released":
			want.merge({"space": true, "shift": true})
			_phase("fresh hop", tick)
		"fresh hop":
			if g and p.z < -30.6:
				_phase("chamber runin", tick)
		"chamber runin":
			_look(Vector2(p.x, p.z), Vector2(0, -60))
			if p.z < -45.0:
				_phase("chamber strafe runup", tick)
		"chamber strafe runup":
			want["a"] = true
			if p.z < -50.3:
				want["space"] = true
				_phase("strafe hop to west face", tick)
		"strafe hop to west face":
			want = {"a": true}
			_mouse(1.0, tick)
			if not g and player.velocity.y / U < 30.0:
				want["space"] = true
				_phase("west kick A held", tick)
		"west kick A held":
			want = {"a": true}
			if tick - phase_tick >= 6:
				want = {"d": true}
				_phase("cross to east", tick)
		"cross to east":
			want = {"d": true}
			if not g and p.x > 1.6 - 0.405 - 0.03:
				want["space"] = true
				_phase("east kick D held", tick)
		"east kick D held":
			want = {"d": true}
			if tick - phase_tick >= 6:
				want = {"w": true}
				_phase("mezzanine", tick)
		"mezzanine":
			_look(Vector2(p.x, p.z), Vector2(0, -90))
			if g and p.y > 3.0:
				_phase("grapple runup", tick)
		"grapple runup":
			if p.z < -69.6:
				want["space"] = true
				_phase("grapple jump", tick)
		"grapple jump":
			_aim_at(Vector3(0, 10.5, -80), tick)
			want["e"] = true
			if bool(ex.grapple.attached):
				_phase("grapple swing", tick)
		"grapple swing":
			want["e"] = true
			if p.z < -83.0:
				want.erase("e")
				_phase("dispatch finish", tick)
		"dispatch finish":
			_aim_at(Vector3(0, p.y + 64.0 * U, -98), tick)
	_want(want, tick)

func _aim_at(target: Vector3, _tick: int) -> void:
	var delta := target - (player.global_position + Vector3.UP * 64.0 * U)
	var error := wrapf(float(player.yaw) - atan2(-delta.x, -delta.z), -PI, PI)
	var x := roundi(clampf(error, -turn_cap, turn_cap) / radians_per_count)
	var pitch_target := atan2(delta.y, Vector2(delta.x, delta.z).length())
	_mouse_xy(x, roundi((float(player.pitch) - pitch_target) / radians_per_count))

func _key(key: String, pressed: bool, tick: int) -> void:
	if pressed == held.has(key):
		return
	var event := InputEventKey.new()
	event.keycode = ALL_KEYS[key]
	event.physical_keycode = ALL_KEYS[key]
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed:
		held[key] = true
	else:
		held.erase(key)
	events.append({"tick": tick, "key": key, "edge": "press" if pressed else "release"})

func _want(want: Dictionary, tick: int) -> void:
	for key: String in ALL_KEYS:
		_key(key, want.has(key), tick)

func _mouse(px: float, _tick: int) -> void:
	_mouse_xy(roundi(px), 0)

func _mouse_xy(x: int, y: int) -> void:
	if x == 0 and y == 0:
		return
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(x, y)
	event.screen_relative = event.relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var tick := step - arm_step
	if not events.is_empty() and events[-1].has("mouse") and int(events[-1].tick) == tick:
		assert(false, "one emitted mouse event per tape tick; do not hide input rows by merging")
	else:
		events.append({"tick": tick, "mouse": [x, y]})

func _observe(tick: int) -> void:
	var motion: Dictionary = player.get_motion_state()
	ground_ticks = ground_ticks + 1 if player.is_grounded() else 0
	var cp := int(game.checkpoint_index)
	if cp != last_checkpoint:
		checkpoint_ticks.append({"checkpoint": cp, "tick": tick, "elapsed": game.elapsed})
		last_checkpoint = cp
	if bool(game.finished) and finish_tick < 0:
		finish_tick = tick
	var row := {"tick": tick, "p": plain(player.global_position), "v": plain(player.velocity), "ref": plain(game.body_reference()),
		"yaw": player.yaw, "pitch": player.pitch, "grounded": player.is_grounded(), "motion": plain(motion),
		"held": held.keys(), "checkpoint": cp, "elapsed": game.elapsed, "finished": game.finished, "respawns": game.respawn_count,
		"style": game.session.style.snapshot(), "stats": plain(game.stats.snapshot())}
	rows.append(JSON.stringify(row, "", false, true))
	if motion.has("experiment") and not (motion.experiment.events as Array).is_empty():
		lab_events.append({"tick": tick, "p": plain(player.global_position), "v": plain(player.velocity), "held": held.keys(), "experiment": plain(motion.experiment)})

func _end(reason: String, tick: int) -> void:
	if not terminal_waiting:
		# capture the final neutral-input tick as well as exposing its release edges to the tape.
		_want({}, tick)
		terminal_waiting = true
		return
	done = true
	_want({}, tick)
	if not game.finished:
		game.session.boundary("quit", {"reason": reason})
	var session: Node = game.session
	var reads: Array = []
	for sealed: Dictionary in session.sealed:
		var run: Dictionary = READER16.read(str(sealed.path))
		var clean: Dictionary = READER16.clean_finish(run)
		reads.append({"path": sealed.path, "ok": run.ok, "status": run.status, "errors": run.errors,
			"clean_finish": clean, "seal": run.seal, "events": run.events})
	var fastest: Dictionary = READER16.fastest_clean(game.recordings_dir, game.motion_identity())
	var config := ConfigFile.new()
	var profile_error := config.load(game.profile_path)
	var saved := {"load_error": profile_error}
	if profile_error == OK:
		saved["style_best"] = config.get_value(game._style_section(), "score", -1)
		saved["time_ticks"] = config.get_value(game._section(), "clean_best_ticks", -1)
		saved["ghost_ticks"] = config.get_value(game._ghost_section(), "time_ticks", -1)
		saved["ghost_path"] = config.get_value(game._ghost_section(), "path", "")
		saved["style_identity"] = config.get_value(game._style_section(), "style_identity", "")
	var summary := {"label": "coordinate-aware input-only bot, actual production r16_main, normal spawn; no fixtures/restores", "route": route_name,
		"reason": reason, "ticks": tick, "finish_tick": finish_tick, "finished": game.finished, "finish_kind": game.finish_kind,
		"elapsed": game.elapsed, "respawns": game.respawn_count, "checkpoints": checkpoint_ticks, "stage_times": game.stage_times,
		"warmup": warmup, "sensitivity": game.look_metadata(), "runner": (player.get_script() as Script).resource_path,
		"standin": game.runner_is_standin(), "phase": phase, "phases": phases, "final": plain(player.global_position),
		"saved_profile": saved, "best_time": game.best_time, "style_summary": session.style.summary(), "style_best": game.style_best, "finish_style": game.finish_style,
		"ghost_pointer": game.ghost_pointer, "ghost_ticks": session.ghost_ticks, "fastest": fastest,
		"recordings": reads, "actual_v_checks": session.actual_v_checks, "actual_v_mismatches": session.actual_v_mismatches,
		"lab_events": lab_events, "identity": game.motion_identity()}
	_write("summary.json", summary)
	var tape := {"format": "spillway-momentum-tape", "version": 2, "name": "r16-" + route_name,
		"description": "coordinate-aware input-only bot on production R16; normal spawn; integer mouse counts; sensitivity 2.5; warmup 33",
		"physics_hz": hz, "input_profile": "physics_tick", "duration_ticks": tick, "duration_s": float(tick) / hz, "events": events}
	_write("events.tape.json", tape)
	var file := FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(rows) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("r16 player bot ", route_name, " ", reason, " finished=", game.finished, " kind=", game.finish_kind, " time=", game.elapsed, " respawns=", game.respawn_count, " phase=", phase)
	game.request_quit(0)
	quit(0)

static func plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = plain(value[key])
		return result
	if value is Array:
		return value.map(func(v: Variant) -> Variant: return plain(v))
	return value

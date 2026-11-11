extends "res://tests/r14_practice_driver.gd"
## state-aware input-only route finder. --tape= replays captured keys/mouse open loop.
## the real r19 host owns the single normal spawn and all progress/recording decisions.

const PRODUCTION := preload("res://scenes/r21.tscn")
const GEOMETRY := preload("res://tests/r21_surf_geometry.gd")
const RUN_READER := preload("res://scripts/r16_run_reader.gd")
var game: Node3D
var telemetry := PackedStringArray()
var contact_ticks := {"west": 0, "east": 0}
var surf_runs: Array = []
var contact_pieces := {}
var current_surf := {}
var bad_ground_ticks := 0
var phase_changes: Array = []
var previous_phase := -1
var seam_losses: Array = []
var last_surf_piece := ""
var last_surf_tick := -2
var last_surf_speed := 0.0
var _closing := false
var trace_file: FileAccess
var first_failure := ""

func _start() -> void:
	Engine.physics_ticks_per_second = 128
	if DisplayServer.get_name() == "headless":
		RenderingServer.render_loop_enabled = false
	max_ticks = int(opts.get("max-ticks", "12000"))
	amp = deg_to_rad(20.0)
	game = (load("res://scenes/r20.tscn") if opts.get("exit-geometry", "r21") == "r20" else PRODUCTION).instantiate()
	game.map_id = "saltglass"
	assert(game.persist and game.record_runs, "production scene must enable persistence and recordings")
	game.name = "R21"
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
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/r21.tscn")
	assert(game.get_script().resource_path == ("res://scripts/r20_main.gd" if opts.get("exit-geometry", "r21") == "r20" else "res://scripts/r21_main.gd"))
	assert(game.map_id == "saltglass" and game.runner_path() == "res://scripts/r15_source_player.gd")
	if opts.has("old-look"):
		game.look_enabled = false
		game.look_layer.set_enabled(false)
	var geometry := GEOMETRY.audit(game.level)
	_write("geometry.json", geometry)
	assert(geometry.ok or opts.get("exit-geometry", "r21") == "r20", "geometry audit: " + str(geometry.errors))
	lab = game
	level = game.level
	player = game.player
	source = true
	hz = Engine.physics_ticks_per_second
	warmup = 33
	radians_per_count = float(player.tape_radians_per_count)
	turn_cap = deg_to_rad(480.0) / hz
	node_from = Vector2(player.position.x, player.position.z)
	nodes = [
		{"entry": "west", "end": -0.6, "heading": 0.0},
		{"surf": "west", "end": -168.0, "heading": 0.0},
		{"p": Vector2(6, -186), "fall": 7.2},
		{"land": Vector2(12, -212), "e": Vector2(12, -196.4), "drop": -0.9},
	]
	for i: int in range(1, 9):
		var x := 4.0 + 13.0 * i
		nodes.append({"land": Vector2(x + 5, -212), "e": Vector2(x - 2.1, -212), "drop": -0.9})
	nodes.append_array([
		{"land": Vector2(119, -192), "e": Vector2(119, -200.6), "drop": -0.4},
		{"p": Vector2(122.3, -174), "r": 0.35},
		{"entry": "east", "end": -167.4, "heading": PI},
		{"surf": "east", "end": 0.0, "heading": PI},
		{"p": Vector2(126, 18), "fall": 7.2},
		{"land": Vector2(138, 43), "e": Vector2(138, 28.4), "drop": 0.5},
	])
	for i: int in range(1, 9):
		var x := 128.0 + 19.0 * i
		var z := 36.0 if i in [4, 5] else 43.0
		nodes.append({"land": Vector2(x + 8, z), "e": Vector2(x - 3.6, z), "drop": 0.3, "chain": true, "fit": true, "win": 4.0, "vt": 3000.0})
	nodes.append({"p": Vector2(310, 38), "hop": true, "vt": 3000.0})
	# no dwell or slow target: each pan calls for a real rising hop; earned cuts remain legal.
	trace_file = FileAccess.open(out_dir.path_join("trace.jsonl"), FileAccess.WRITE)

	if opts.has("tape"):
		_load_tape(str(opts.tape))
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("saltglass driver: ", game.scene_file_path, ", r15 source, 128 Hz; input only after declared setup")

func _load_tape(path: String) -> void:
	replay = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(int(replay.version) == 2 and int(replay.physics_hz) == hz)
	max_ticks = int(replay.duration_ticks)
	for event: Dictionary in replay.events:
		var tick := int(event.tick)
		if not replay_keys.has(tick):
			replay_keys[tick] = []
		replay_keys[tick].append(event)

func late_step() -> void:
	if replay.is_empty():
		super.late_step()
		return
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
		_end("finished" if finish_tick >= 0 else "tape_done", tick)
		return
	for event: Dictionary in replay_keys.get(tick, []):
		if event.has("key"):
			_key(str(event.key), str(event.edge) == "press", tick)
		else:
			_mouse(float(event.mouse[0]), tick)

func _mouse(px: float, _tick: int) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(px, 0)
	event.screen_relative = event.relative
	if event.relative.x == 0:
		return
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	events.append({"tick": step - arm_step, "mouse": [event.relative.x, 0.0]})

func _control_source(tick: int) -> void:
	if node_index != previous_phase:
		phase_changes.append({"node": node_index, "tick": tick, "p": plain(player.position), "speed_u": Vector2(player.velocity.x, player.velocity.z).length() / U})
		previous_phase = node_index
	if node_index < nodes.size() and nodes[node_index].has("entry"):
		var node: Dictionary = nodes[node_index]
		if (node.entry == "west" and player.position.z <= float(node.end)) or (node.entry == "east" and player.position.z >= float(node.end)):
			_next(Vector2(player.position.x, player.position.z), tick)
			_control_source(tick)
			return
		# align on the headrace, then run straight off its edge. no airborne waypoint steering into an end face.
		var heading := float(node.heading)
		if node.entry == "east":
			var desired_x_speed := clampf(((74.3 if opts.get("exit-geometry", "r21") == "r20" else 122.3) - player.position.x) * 4.0 - player.velocity.x * 0.8, -4, 4)
			heading += atan2(desired_x_speed, 6.35)
		_turn_to(heading)
		_want({"w": true}, tick)
		return
	if node_index < nodes.size() and nodes[node_index].has("surf"):
		var node: Dictionary = nodes[node_index]
		var west: bool = node.surf == "west"
		if (west and player.position.z <= float(node.end)) or (not west and player.position.z >= float(node.end)):
			_next(Vector2(player.position.x, player.position.z), tick)
			super._control_source(tick)
			return
		# local right presses into the steep face; mouse is genuine relative input.
		var centre := 84.0 if opts.get("exit-geometry", "r21") == "r20" else 132.0
		var local_x := player.position.x if west else centre - player.position.x
		var fraction := clampf((-player.position.z if west else player.position.z + 168.0) / 168.0, 0, 1)
		var target_x := lerpf(9.7, float(opts.get("exit-target", "5.3")), clampf((fraction - 0.1) / 0.9, 0.0, 1.0))
		var local_vx := player.velocity.x if west else -player.velocity.x
		var along_speed := maxf(1.0, absf(player.velocity.z))
		# correct the face line without pointing the strafe wish backward along the fin.
		var angle := maxf(0.0, atan2(0.52 - local_vx + (local_x - target_x) * 1.5, along_speed))
		_turn_to(float(node.heading) + angle)
		_want({"d": true}, tick)
		return
	if node_index < nodes.size() and bool(nodes[node_index].get("chain", false)):
		var node: Dictionary = nodes[node_index]
		var here := Vector2(player.position.x, player.position.z)
		var target: Vector2 = node.land
		var passed := (here - target).dot(target - node_from) > 0.0
		if (here.distance_to(target) < 4.0 or passed) and player.position.y >= float(node.get("target_y", -100.0)) - 0.1:
			_next(here, tick)
			_control_source(tick)
			return
		if player.is_grounded():
			_look(here, target)
			_want({"w": true, "space": true}, tick)
		else:
			var want := _air(here, target, 3000.0, false)
			want["space"] = true
			_want(want, tick)
		return
	super._control_source(tick)

func _route_finished(_tick: int) -> bool:
	return finish_tick >= 0

func _observe(tick: int) -> void:
	super._observe(tick)
	trace_lines.clear()
	var motion: Dictionary = player.get_motion_state()
	var speed := float(motion.actual_speed_u)
	var contact: Array = []
	for c: Dictionary in motion.contacts:
		if str(c.body).begins_with("Surf_") and (c.normal as Vector3).y > 0.45 and (c.normal as Vector3).y < 0.65:
			contact.append(plain(c))
			contact_pieces[c.body] = int(contact_pieces.get(c.body, 0)) + 1
	var fin := ""
	if not contact.is_empty():
		fin = "west" if "west" in str(contact[0].body) else "east"
		contact_ticks[fin] += 1
		if player.is_grounded():
			bad_ground_ticks += 1
		if current_surf.is_empty():
			current_surf = {"fin": fin, "start_tick": tick, "entry_speed_u": speed, "entry": plain(player.position)}
		current_surf["end_tick"] = tick
		current_surf["exit_speed_u"] = speed
		current_surf["exit"] = plain(player.position)
		var piece := str(contact[0].body)
		if tick - last_surf_tick <= 16 and piece != last_surf_piece:
			seam_losses.append({"tick": tick, "from": last_surf_piece, "to": piece, "gap_ticks": tick - last_surf_tick, "before_u": last_surf_speed, "after_u": speed, "loss_u": last_surf_speed - speed})
		last_surf_piece = piece
		last_surf_tick = tick
		last_surf_speed = speed
	elif not current_surf.is_empty():
		surf_runs.append(current_surf)
		current_surf = {}
	trace_file.store_line(JSON.stringify({"tick": tick, "p": plain(player.position), "reference_p": plain(game.body_reference()), "v": plain(player.velocity), "yaw": player.yaw, "pitch": player.pitch,
		"grounded": player.is_grounded(), "support": _support(player.position) if player.is_grounded() else "", "support_normal": plain(_ground_hit(player.position).get("normal", Vector3.ZERO)) if player.is_grounded() else [], "held": held.keys(), "motion": plain(motion), "surf_contacts": contact, "checkpoint": game.checkpoint_index,
		"respawns": game.respawn_count, "elapsed": game.elapsed, "style": plain(game.session.style.snapshot()), "stats": plain(game.stats.snapshot())}, "", false, true))
	if int(game.respawn_count) > 0 or (not opts.has("probe") and player.position.y < -9.5):
		first_failure = "" if opts.has("probe") else "fell or respawned at node %d tick %d" % [node_index, tick]
		_end("probe_respawn" if opts.has("probe") else "failed", tick + 1)

func _end(reason: String, tick: int) -> void:
	if _closing:
		return
	_closing = true
	done = true
	_want({}, tick)
	if not game.finished:
		game.session.boundary("quit", {"reason": reason})
	# the session seals finish after the host; its deferred receipt needs a process turn.
	await process_frame
	await process_frame
	if not current_surf.is_empty():
		surf_runs.append(current_surf)
	var reads: Array = []
	for sealed: Dictionary in game.session.sealed:
		var run: Dictionary = RUN_READER.read(str(sealed.path))
		reads.append({"path": sealed.path, "ok": run.ok, "errors": run.errors, "status": run.status, "clean_finish": RUN_READER.clean_finish(run), "seal": run.seal})
	var summary := {"finished": game.finished, "reason": reason, "failure": first_failure, "finish_kind": game.finish_kind, "elapsed": game.elapsed,
		"clean_eligible": game.clean_eligible, "respawns": game.respawn_count, "checkpoints": checkpoint_ticks, "stage_times": game.stage_times, "ticks": tick,
		"physics_hz": hz, "engine_hz": Engine.physics_ticks_per_second, "rate_mismatch_ticks": game.rate_mismatch_ticks, "runner": (player.get_script() as Script).resource_path,
		"geometry_hash": level.geometry_hash(), "piece_count": level.manifest.size(), "identity": game.motion_identity(), "contact_ticks": contact_ticks, "contact_pieces": contact_pieces,
		"surf_runs": surf_runs, "grounded_steep_ticks": bad_ground_ticks, "seam_losses": seam_losses, "hops": hops, "flights": flights,
		"max_speed_u": max_speed / U, "final": plain(player.position), "node": node_index, "phases": phase_changes, "style": game.session.style.summary(), "recordings": reads,
		"actual_v_checks": game.session.actual_v_checks, "actual_v_mismatches": game.session.actual_v_mismatches, "look": game.look_layer.report,
		"build_label": game.recording_metadata("proof").build_label, "window_title": game.window_title(), "startup": game.interface_startup_message(),
		"configured_scene": game.scene_file_path, "configured_main": game.get_script().resource_path, "mode": "open loop saved input" if not replay.is_empty() else "coordinate-aware input only", "setup": "host normal authored spawn, rest; no driver body/camera/progress writes"}
	var passed := _accept(summary)
	summary["pass"] = passed
	_write("summary.json", summary)
	_write("events.tape.json", {"format": "spillway-momentum-tape", "version": 2, "name": "r21-saltglass", "description": "input-only normal spawn on configured R21; 128 Hz, warmup 33, sensitivity 2.5", "physics_hz": hz, "input_profile": "physics_tick", "duration_ticks": tick, "duration_s": float(tick) / hz, "events": events})
	trace_file.close()
	print("saltglass: pass=", passed, " finish=", game.finished, " kind=", game.finish_kind, " time=", game.elapsed, " contacts=", contact_ticks, " node=", node_index, " final=", player.position, " reason=", reason)
	# the host seals the attempt and drains eight frames before shutting down.
	game.request_quit(0 if passed else 1)

func _accept(summary: Dictionary) -> bool:
	return bool(summary.finished) and str(summary.finish_kind) == "clean" and int(summary.respawns) == 0 \
		and summary.elapsed >= 40.0 and summary.elapsed <= 70.0 and bad_ground_ticks == 0 \
		and int(contact_ticks.west) >= 128 and int(contact_ticks.east) >= 128 \
		and (summary.recordings as Array).any(func(r: Dictionary) -> bool: return bool(r.ok) and bool(r.clean_finish.get("ok", false))) \
		and not seam_losses.any(func(r: Dictionary) -> bool: return float(r.loss_u) > 20.0) \
		and int(summary.actual_v_mismatches) == 0 and int(summary.rate_mismatch_ticks) == 0

static func plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Array:
		return value.map(func(v: Variant) -> Variant: return plain(v))
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = plain(value[key])
		return result
	return value

func _write(name: String, data: Variant) -> void:
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, " ", false, true))
	file.close()

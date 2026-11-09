extends "res://tests/r14_practice_driver.gd"
## earned input route finder or open-loop tape replay; production impulses belong to the new runner.
const HOST := preload("res://tests/r19_line_drive_host.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
var game: Node
var rows := PackedStringArray()
var closing := false
var record_observations: Array[Dictionary] = []
var replay_ordered := {}

static func plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[str(key)] = plain(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(plain(item))
		return result
	return value

func _start() -> void:
	Engine.physics_ticks_per_second = 128
	if DisplayServer.get_name() == "headless":
		RenderingServer.render_loop_enabled = false
	max_ticks = int(opts.get("max-ticks", "8000"))
	game = HOST.new()
	game.motor = "server128"
	game.seed_from_r15 = false
	game.source_sensitivity_override = 2.5
	game.persist = true
	game.profile_path = out_dir.path_join("profile.cfg")
	game.record_runs = true
	game.recordings_dir = out_dir.path_join("recordings")
	game.ghosts_directory = out_dir.path_join("ghosts")
	game.ghost_share_storage = out_dir.path_join("ghost-state")
	root.add_child(game)
	lab = game
	level = game.level
	player = game.player
	source = true
	hz = 128
	warmup = 33
	radians_per_count = float(player.tape_radians_per_count)
	turn_cap = deg_to_rad(480.0) / hz
	node_from = Vector2(player.position.x, player.position.z)
	nodes = [{"p": Vector2(0, -31), "hop": true, "vt": 450.0},
		{"p": Vector2(0, -56), "transfer": "LaunchWest", "stage": 1},
		{"p": Vector2(39, -58), "hop": true, "vt": 450.0},
		{"p": Vector2(79, -58), "transfer": "LaunchEast", "stage": 2},
		{"p": Vector2(79, -25), "hop": true, "vt": 450.0},
		{"p": Vector2(79, 14), "transfer": "LaunchHome", "stage": 3}]
	if opts.has("tape"):
		_load_tape(str(opts.tape))
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("line drive: input-only route; new experiment runner on actual R19 host")

## keep original within-tick mouse/key order as well as values; the inherited generic
## replay groups keys before mouse, which preserves physics but changes recorded edge order.
func _load_tape(path: String) -> void:
	super(path)
	for event: Dictionary in replay.events:
		var t := int(event.tick)
		if not replay_ordered.has(t):
			replay_ordered[t] = []
		replay_ordered[t].append(event)

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
	tick_mouse = 0.0
	if tick > 0:
		_observe(tick - 1)
	if done:
		return
	if tick >= max_ticks or _route_finished(tick):
		_end("finished" if finish_tick >= 0 else "budget", tick)
		return
	if not replay.is_empty():
		for event: Dictionary in replay_ordered.get(tick, []):
			if event.has("key"):
				_key(str(event.key), str(event.edge) == "press", tick)
			else:
				_mouse(float(event.mouse[0]), tick)
		return
	_control_source(tick)

func _control_source(tick: int) -> void:
	if node_index < nodes.size() and nodes[node_index].has("transfer"):
		var node: Dictionary = nodes[node_index]
		var here := Vector2(player.position.x, player.position.z)
		if player.used_pads.has(node.transfer) and player.is_grounded() and game.checkpoint_index >= int(node.stage):
			_next(here, tick)
			_control_source(tick)
			return
		if player.is_grounded():
			_look(here, node.p)
			_want({"w": true}, tick)
		else:
			_want(_air(here, node.p, 0.0, false), tick)
		return
	super._control_source(tick)

func _route_finished(_tick: int) -> bool:
	return finish_tick >= 0

func _observe(tick: int) -> void:
	super._observe(tick)
	record_observations.append({"p": player.position, "v": player.velocity, "yaw": player.yaw, "pitch": player.pitch, "elapsed": game.elapsed, "checkpoint": game.checkpoint_index, "respawns": game.respawn_count})
	rows.append(JSON.stringify({"tick": tick, "p": plain(player.position), "v": plain(player.velocity), "yaw": player.yaw, "pitch": player.pitch,
		"motion": plain(player.get_motion_state()), "pad_probes": pad_probes(), "checkpoint": game.checkpoint_index, "respawns": game.respawn_count,
		"elapsed": game.elapsed, "node": node_index, "clean": game.clean_eligible, "started": game._started, "finished": game.finished, "finish_kind": game.finish_kind, "stats": plain(game.stats.snapshot()), "style": plain(game.session.style.snapshot()), "held": held.keys()}, "", false, true))
	if game.respawn_count > 0 or player.position.y < 3:
		_end("missed", tick + 1)

func pad_probes() -> Array:
	var probes: Array = []
	for pad: Dictionary in level.launch_pads:
		if (pad.bounds as AABB).has_point(player.global_position):
			var h := Vector3(player.velocity.x, 0, player.velocity.z) / U
			probes.append({"id": pad.id, "speed_u": h.length(), "alignment": h.normalized().dot(pad.direction),
				"grounded": player.is_grounded(), "support": plain(player.pad_support(pad)), "used": player.used_pads.has(pad.id)})
	return probes

func _end(reason: String, tick: int) -> void:
	if closing:
		return
	closing = true
	done = true
	_want({}, tick)
	if not game.finished:
		game.session.boundary("quit", {"reason": reason})
	await process_frame
	await process_frame
	var recordings: Array = []
	for sealed: Dictionary in game.session.sealed:
		var run: Dictionary = READER.read(str(sealed.path))
		var offsets: Array = []
		if run.ok:
			for offset: int in range(30, 37):
				var matching: bool = (run.columns.p as PackedVector3Array).size() >= record_observations.size() + offset
				for i: int in record_observations.size():
					if not matching:
						break
					var obs: Dictionary = record_observations[i]
					var j := i + offset
					matching = obs.p == run.columns.p[j] and obs.v == run.columns.v[j] and obs.yaw == run.columns.yaw[j] and obs.pitch == run.columns.pitch[j] and obs.elapsed == run.columns.elapsed[j] and obs.checkpoint == run.columns.checkpoint[j] and obs.respawns == run.columns.respawns[j]
				if matching:
					offsets.append(offset)
		recordings.append({"path": sealed.path, "ok": run.ok, "clean": READER.clean_finish(run), "errors": run.errors, "observation_offsets": offsets})
	var ok: bool = game.finished and game.finish_kind == "clean" and game.respawn_count == 0 and player.launch_events.size() == 3 and game.session.actual_v_mismatches == 0
	var summary := {"ok": ok, "reason": reason, "time": game.elapsed, "finish": game.finish_kind, "respawns": game.respawn_count,
		"node": node_index, "position": plain(player.position), "launches": plain(player.launch_events), "ticks": tick, "samples": rows.size(),
		"hops": hops, "max_speed_u": max_speed / U, "identity": game.motion_identity(), "recordings": recordings,
		"rate_mismatch_ticks": game.rate_mismatch_ticks, "actual_v_checks": game.session.actual_v_checks, "actual_v_mismatches": game.session.actual_v_mismatches, "style": game.session.style.summary()}
	_write("summary.json", summary)
	_write("geometry.json", level.geometry_identity())
	_write("events.tape.json", {"format": "spillway-momentum-tape", "version": 2, "name": "r19-line-drive", "physics_hz": hz,
		"input_profile": "physics_tick", "duration_ticks": tick, "duration_s": float(tick) / hz, "events": events})
	var file := FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(rows) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("line drive ok=", ok, " seconds=", game.elapsed, " launches=", player.launch_events.size(), " samples=", rows.size())
	game.request_quit(0 if ok else 1)

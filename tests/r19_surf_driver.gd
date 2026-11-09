extends "res://tests/r14_practice_driver.gd"
## state-aware input-only route finder. --tape= replays captured keys/mouse open loop.
## the real r19 host owns the single normal spawn and all progress/recording decisions.

const SURF_HOST := preload("res://tests/r19_surf_host.gd")
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
var first_failure := ""

func _start() -> void:
	Engine.physics_ticks_per_second = 128
	if DisplayServer.get_name() == "headless":
		RenderingServer.render_loop_enabled = false
	max_ticks = int(opts.get("max-ticks", "12000"))
	amp = deg_to_rad(20.0)
	game = SURF_HOST.new()
	game.name = "R19"
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
		{"p": Vector2(2, -1.0), "r": 0.15},
		{"surf": "west", "end": -84.0, "heading": 0.0},
		{"p": Vector2(6, -96), "fall": 10.2},
		{"land": Vector2(6, -111), "e": Vector2(6, -103.4), "drop": 1.5},
		{"p": Vector2(8, -116), "hop": true},
		{"land": Vector2(23, -116), "e": Vector2(15.4, -116), "drop": 1.0},
		{"p": Vector2(31, -116), "hop": true},
		{"land": Vector2(46, -116), "e": Vector2(37.4, -116), "drop": 1.0},
		{"p": Vector2(58, -116), "hop": true},
		{"land": Vector2(58, -98), "e": Vector2(58, -106.6), "drop": 0.5},
		{"p": Vector2(58, -83.0), "r": 0.15},
		{"surf": "east", "end": 0.0, "heading": PI},
		{"p": Vector2(54, 12), "fall": 10.2},
		{"p": Vector2(54, 32), "hop": true},
		{"land": Vector2(35, 37), "e": Vector2(42.6, 35), "drop": 1.0},
		{"p": Vector2(26, 39), "hop": true},
		{"land": Vector2(11, 35), "e": Vector2(18.6, 37), "drop": 1.0},
		{"p": Vector2(2, 32), "hop": true},
		{"land": Vector2(-13, 37), "e": Vector2(-5.4, 35), "drop": 1.0},
		{"p": Vector2(-22, 39), "hop": true},
		{"land": Vector2(-37, 35), "e": Vector2(-29.4, 37), "drop": 1.0},
		{"p": Vector2(-46, 32), "hop": true},
		{"land": Vector2(-61, 37), "e": Vector2(-53.4, 35), "drop": 1.0},
		{"p": Vector2(-68, 39), "hop": true},
	]
	if opts.has("tape"):
		_load_tape(str(opts.tape))
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("saltglass driver: actual r19 host, r15 source, normal spawn, 128 Hz; input only")

func _control_source(tick: int) -> void:
	if node_index != previous_phase:
		phase_changes.append({"node": node_index, "tick": tick, "p": plain(player.position), "speed_u": Vector2(player.velocity.x, player.velocity.z).length() / U})
		previous_phase = node_index
	if node_index < nodes.size() and nodes[node_index].has("surf"):
		var node: Dictionary = nodes[node_index]
		var west: bool = node.surf == "west"
		if (west and player.position.z <= float(node.end)) or (not west and player.position.z >= float(node.end)):
			_next(Vector2(player.position.x, player.position.z), tick)
			super._control_source(tick)
			return
		# local right presses into the steep face; mouse is genuine relative input.
		_turn_to(float(node.heading) + deg_to_rad(float(opts.get("surf-angle", "1"))))
		_want({"d": true}, tick)
		return
	super._control_source(tick)

func _route_finished(_tick: int) -> bool:
	return finish_tick >= 0

func _observe(tick: int) -> void:
	super._observe(tick)
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
	telemetry.append(JSON.stringify({"tick": tick, "p": plain(player.position), "reference_p": plain(game.body_reference()), "v": plain(player.velocity), "yaw": player.yaw, "pitch": player.pitch,
		"grounded": player.is_grounded(), "held": held.keys(), "motion": plain(motion), "surf_contacts": contact, "checkpoint": game.checkpoint_index,
		"respawns": game.respawn_count, "elapsed": game.elapsed, "style": plain(game.session.style.snapshot()), "stats": plain(game.stats.snapshot())}, "", false, true))
	if int(game.respawn_count) > 0 or player.position.y < -6.0:
		first_failure = "fell or respawned at node %d tick %d" % [node_index, tick]
		_end("failed", tick + 1)

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
		"mode": "open loop saved input" if not replay.is_empty() else "coordinate-aware input only", "setup": "host normal authored spawn, rest; no driver body/camera/progress writes"}
	var passed := _accept(summary)
	summary["pass"] = passed
	_write("summary.json", summary)
	_write("events.tape.json", {"format": "spillway-momentum-tape", "version": 2, "name": "r19-saltglass", "description": "input-only normal spawn on actual R19; 128 Hz, warmup 33, sensitivity 2.5", "physics_hz": hz, "input_profile": "physics_tick", "duration_ticks": tick, "duration_s": float(tick) / hz, "events": events})
	var file := FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(telemetry) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("saltglass: pass=", passed, " finish=", game.finished, " kind=", game.finish_kind, " time=", game.elapsed, " contacts=", contact_ticks, " node=", node_index, " final=", player.position, " reason=", reason)
	game.request_quit(0)
	quit(0 if passed else 1)

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

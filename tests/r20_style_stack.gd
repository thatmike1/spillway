extends "res://tests/r19_style_bhop.gd"
## earned-input component proof through the actual configured R20 PackedScene and frozen motor.
const SCENE := preload("res://scenes/r20.tscn")
const READER := preload("res://scripts/r16_run_reader.gd")
var host_rows: Array = []
var current_name := ""
var host_events: Array = []
var baseline_events: Array = []
var parity_active := false
var parity_ok := true
var parity_samples := 0
var pending_frame: Dictionary = {}
var pause_before: Dictionary = {}
var mode_override := ""
var did_action := false
var action_tick := -1
var action_before: Dictionary = {}
var action_after: Dictionary = {}
var host_style: RefCounted
var observers: Array = []
var native := false
var observer := false
var size_arg := Vector2i(1280, 720)
var cases := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--baseline="):
			baseline_path = arg.trim_prefix("--baseline=")
		elif arg.begins_with("--cases="):
			cases = arg.trim_prefix("--cases=")
		elif arg == "--observer":
			observer = true
		elif arg == "--native":
			native = true
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size_arg = Vector2i(int(parts[0]), int(parts[1]))
	assert(out_dir.is_absolute_path())
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("episodes"))
	Engine.physics_ticks_per_second = 128
	root.size = size_arg
	if not native:
		RenderingServer.render_loop_enabled = false
	baseline = (load(baseline_path) as Script).new()
	for spec: Array in [["early_tick", -1000], ["pre_style", 998], ["late_tick", 1001]]:
		var hook := Hook.new()
		hook.suite = self
		hook.phase = spec[0]
		hook.process_physics_priority = spec[1]
		root.add_child(hook)
	for n: int in [1, 6, 12, 20]:
		check("formula_%d" % n, STYLE.pending_points("backward_bhop", n) == 160 * n * (n - 1) / 2 and STYLE.pending_points("sideways_bhop", n) == 50 * n * (n - 1) / 2)
	if not cases.is_empty():
		for action: String in cases.split(","):
			await run_case(action, action, 2700)
	elif native or observer:
		await run_case("native_bank", "bank", 1500)
		await run_case("native_loss", "stall", 1500)
	else:
		for kind: String in ["back", "side"]:
			var result := await run_case("long_" + kind, "bank", 2600, kind)
			var pendings: Array = result.diagnostics.filter(func(e: Dictionary) -> bool: return e.kind == "direction_pending")
			var banks: Array = result.events.filter(func(e: Dictionary) -> bool: return str(e.kind).ends_with("_bank"))
			check(kind + "_earned_20_hops", pendings.any(func(e: Dictionary) -> bool: return int(e.hops) >= 20), pendings.map(func(e: Dictionary) -> int: return int(e.hops)))
			check(kind + "_exact_bank_once", banks.size() == 1 and int(banks[0].points) == STYLE.pending_points(kind_name(kind), int(banks[0].m.hops)) and int(banks[0].m.hops) >= 20, banks)
			check(kind + "_pending_excluded_from_score", result.rows.all(func(r: Dictionary) -> bool: return int(r.score) == int(r.event_total)))
			check(kind + "_first_hop_arms_zero", not pendings.is_empty() and int(pendings[0].hops) == 1 and int(pendings[0].pending) == 0)
		for action: String in ["facing", "combo_bank", "ground", "stall", "restart", "respawn", "practice", "settings", "paused_settings_quit", "map", "preset", "loadout", "quit", "respawn_revisit", "pause", "pause_invalid", "rearm", "noop", "forward", "idle", "walk", "tiny", "tinyhop", "loop", "heading"]:
			await run_case(action, action, (2000 if action == "ground" else 1300) if action not in ["loop", "heading", "respawn_revisit"] else 2700)
		await finish_case()
	check("observer_never_writes_body", write_violations.is_empty(), write_violations)
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.pass)
	var report := {"ok": failed.is_empty(), "checks": checks, "failed": failed.size(), "identity": STYLE.identity(), "identity_key": STYLE.identity_key(),
		"fixtures": episodes, "native_markers": observers, "forward_samples": parity_samples, "baseline_path": baseline_path,
		"baseline_sha256": FileAccess.get_sha256(baseline_path), "baseline_identity": baseline.identity(), "host_sha256": FileAccess.get_sha256("res://scripts/r20_main.gd")}
	write_json(out_dir.path_join("summary.json"), report)
	print("r20 style: %d checks, %d failed" % [checks.size(), failed.size()])
	quit(0 if failed.is_empty() else 1)

func kind_name(kind: String) -> String:
	return "sideways_bhop" if kind == "side" else "backward_bhop"

func create_host(lab := false) -> void:
	game = SCENE.instantiate()
	game.persist = false
	game.seed_from_r15 = false
	game.record_runs = true
	game.recordings_dir = out_dir.path_join("recordings").path_join(current_name)
	game.profile_path = out_dir.path_join("profiles").path_join(current_name + ".cfg")
	game.ghosts_directory = out_dir.path_join("ghosts")
	game.ghost_share_storage = out_dir.path_join("share.cfg")
	game.motor = "server128"
	game.set_window_title = false
	var maps: Dictionary = preload("res://scripts/r20_map_catalog.gd").make().duplicate(true)
	maps.catalog["style-fixture"] = {"name": "Style fixture", "theme": "Collision proof", "kind": "lab" if lab else "course", "script": FIX}
	maps.order.append("style-fixture")
	game.map_registry = maps
	game.map_id = "style-fixture"
	root.add_child(game)
	game.hud.dismiss_title()
	level = game.level
	host_style = game.session.style
	rpc = float(game.player.tape_radians_per_count)

func run_case(label: String, action: String, length: int, kind := "back", spec: Dictionary = {}) -> Dictionary:
	current_name = label
	mode_override = action
	did_action = false
	action_tick = -1
	action_before = {}
	action_after = {}
	host_rows = []
	host_events = []
	baseline_events = []
	baseline.reset()
	parity_active = action == "forward"
	create_host(action in ["loadout", "noop"])
	var floor_spec := FIX.flat_spec() if spec.is_empty() else spec
	# a long fixture, set once before restart; no pose, velocity, view or stats writes afterward.
	if spec.is_empty():
		floor_spec.pieces = [FIX.deck("long_floor", -150, 150, -800, 400, 0.0)]
		if action == "tinyhop":
			floor_spec.pieces.append(FIX.deck("low_ceiling", -150, 150, -800, -42.8, 3.0, 2.0))
	level.configure(floor_spec)
	game.course_geometry = game._geometry_id()
	game._kill_bounds = level.kill_bounds
	game._refresh_records()
	game.restart_run()
	ep = {"tick": 0, "length": length + SETTLE, "last_row": {}, "controller": Callable(), "tape": {}, "recorded": {}, "memory": {"mode": kind}, "rows": []}
	running = true
	await episode_done
	for key: String in KEYS:
		send([key, false])
	var end_snap: Dictionary = host_style.snapshot()
	if game.session.attempt_live:
		game.restart_run()
	var seals: Array = game.session.sealed.duplicate(true)
	var decoded := []
	var diagnostics := []
	var wire_style := []
	for seal: Dictionary in seals:
		var rec: Dictionary = READER.read(str(seal.path))
		check(label + "_reader_" + str(decoded.size()), bool(rec.ok), rec.get("errors", []))
		decoded.append({"path": seal.path, "header": rec.header, "seal": rec.seal, "events": rec.events})
		for e: Dictionary in rec.events:
			if e.k == "style":
				wire_style.append(e.d)
			elif e.k == "direction":
				diagnostics.append(e.d)
		var points := 0
		var tally := {}
		for e: Dictionary in rec.events:
			if e.k != "style":
				continue
			points += int(e.d.points)
			var row: Dictionary = tally.get(str(e.d.kind), {"n": 0, "points": 0})
			row.n += 1
			row.points += int(e.d.points)
			tally[str(e.d.kind)] = row
		var outcome: Dictionary = rec.seal.outcome.style
		check(label + "_sealed_tally_" + str(decoded.size()), int(outcome.score) == points and equivalent(tally, outcome.by_kind))
		check(label + "_dense_wire_order_" + str(decoded.size()), rec.events.all(func(e: Dictionary) -> bool: return int(e.q) == rec.events.find(e)))
	var banks := wire_style.filter(func(e: Dictionary) -> bool: return str(e.kind).ends_with("_bank"))
	if action in ["restart", "respawn", "practice", "settings", "paused_settings_quit", "map", "preset", "loadout", "quit", "stall"]:
		check(label + "_earned_before_action", did_action and int(action_before.direction.pending) > 0)
		check(label + "_refuses_cashout", banks.is_empty(), banks)
		check(label + "_loss_recorded_once", diagnostics.filter(func(d: Dictionary) -> bool: return d.kind == "direction_lost" and int(d.pending) > 0).size() == 1, diagnostics.filter(func(d: Dictionary) -> bool: return d.kind == "direction_lost"))
	if action in ["facing", "ground", "combo_bank"]:
		check(label + "_banks_exact_once", banks.size() == 1 and int(banks[0].points) == int(action_before.direction.pending), banks)
		check(label + "_bank_unmultiplied", banks.size() == 1 and banks[0].mult == 1.0 and banks[0].combo == 0)
	if action == "combo_bank":
		check("bank_ignores_active_ordinary_combo", float(action_before.mult) > 1.0 and banks.size() == 1 and int(banks[0].points) == 160)
	if action == "pause":
		check("pause_no_time_score_or_position_gain", bool(action_after.get("unchanged", false)))
		check("pause_next_sample_keeps_valid_stack", host_rows.any(func(r: Dictionary) -> bool: return int(r.t) > action_tick + 2 and int(r.direction.hops) > int(action_before.direction.hops)))
		check("pause_no_bank_or_loss", banks.is_empty() and diagnostics.filter(func(d: Dictionary) -> bool: return d.kind == "direction_lost" and d.reason != "restart").is_empty())
	if action in ["rearm", "pause_invalid"]:
		var arms := diagnostics.filter(func(d: Dictionary) -> bool: return d.kind == "direction_pending" and int(d.hops) == 1)
		check("rearm_needs_new_real_hops", arms.size() >= 2 and banks.size() == 1 and host_rows.any(func(r: Dictionary) -> bool: return int(r.t) > action_tick + 200 and int(r.direction.hops) >= 2), arms)
	if action == "noop":
		check("invalid_and_noop_controls_preserve_pending", bool(action_after.get("unchanged", false)))
	if action == "tinyhop":
		check("real_low_ceiling_rejects_tiny_hops", host_rows.any(func(r: Dictionary) -> bool: return str(r.diag.last.get("verdict", "")) in ["flight_short", "travel_short", "rise_short", "fall_short"] and r.spd >= 300.0))
	if action == "respawn_revisit":
		check("respawn_keeps_attempt_novelty", did_action and int(end_snap.diag.farm_blocked.get("direction", 0)) >= 4 and diagnostics.filter(func(d: Dictionary) -> bool: return d.kind == "direction_pending" and d.tick > int(action_before.diag.direction.last.tick) and d.tick < action_tick + 800).is_empty())
	if action == "heading":
		check("actual_curved_hops_reject_heading", host_rows.any(func(r: Dictionary) -> bool: return r.diag.last.get("verdict", "") == "heading"))
	if action == "loop":
		check("physical_loop_rejects_used_landings", int(end_snap.diag.farm_blocked.get("direction", 0)) > 0)
	if action == "forward":
		check("forward_exact_frozen_r19", parity_ok and parity_samples > 1000, parity_samples)
		check("forward_sync_and_speed_present", wire_style.any(func(e: Dictionary) -> bool: return e.kind == "sync") and wire_style.any(func(e: Dictionary) -> bool: return e.kind == "speed"))
	if action in ["idle", "walk", "tiny"]:
		check(action + "_no_eligible_hops", diagnostics.filter(func(d: Dictionary) -> bool: return d.kind == "direction_pending").is_empty())
	var result := {"events": wire_style, "diagnostics": diagnostics, "rows": host_rows, "snapshot": end_snap, "seals": seals,
		"action_tick": action_tick, "before": action_before, "after": action_after, "fixture_sha256": level.geometry_hash() if is_instance_valid(level) else "", "tape": ep.recorded}
	episodes[label] = {"samples": host_rows.size(), "events": wire_style.size(), "banks": banks, "diagnostics": diagnostics, "snapshot": end_snap, "seals": seals,
		"action_tick": action_tick, "before": action_before, "after": action_after, "fixture_sha256": result.fixture_sha256}
	write_json(out_dir.path_join("episodes").path_join(label + ".json"), {"observations": host_rows, "recordings": decoded, "fixture": _plain(floor_spec), "tape": ep.recorded})
	parity_active = false
	# exit via public quit after observation, then free before its asynchronous tree quit runs.
	game.request_quit(0)
	root.remove_child(game)
	game.free()
	await process_frame
	return result

func direction_controller(t: int, row: Dictionary, m: Dictionary) -> Array:
	var mode := str(m.mode)
	if mode in ["back", "side"]:
		if not m.has("turned"):
			m["coast_ups"] = 650.0 if mode_override == "ground" else 360.0
			var commands := ctl_strafe(t, row, m)
			if m.has("coast"):
				m["turned"] = true
				var v: Vector3 = row.v
				var travel_yaw := atan2(-v.x, -v.z)
				var target := travel_yaw + (PI * 0.5 if mode == "side" else PI)
				commands.append(["mouse", -angle_difference(float(row.yaw), target) / rpc])
			return commands
		if mode_override in ["loop", "heading"]:
			# source air strafing around a circle, facing opposite actual travel throughout.
			return [["d", true], ["mouse", -(float(row.spd) * U / 14.0 / 128.0 if mode_override == "loop" else 0.014) / rpc]]
		return []
	return super(t, row, m)

func early_tick() -> void:
	if not running:
		return
	ep.tick = int(ep.tick) + 1
	var t := int(ep.tick) - SETTLE
	if t < 1 or game.paused:
		return
	var commands: Array = []
	if mode_override == "forward":
		commands = ctl_strafe(t, ep.last_row, ep.memory)
	elif mode_override in ["idle", "walk", "tiny"]:
		commands = direction_controller(t, ep.last_row, {"mode": mode_override})
	else:
		commands = direction_controller(t, ep.last_row, ep.memory)
	var snap: Dictionary = host_style.snapshot()
	var target := (8 if native or observer else 20) if mode_override == "bank" else (2 if mode_override == "combo_bank" else (8 if native or observer else 4))
	if not did_action and int(snap.direction.hops) >= target and (bool(ep.last_row.get("g", false)) or mode_override == "pause"):
		did_action = true
		action_tick = t
		action_before = snap
		match mode_override:
			"bank", "facing", "combo_bank", "rearm", "pause_invalid":
				var velocity: Vector3 = ep.last_row.v
				commands.append(["mouse", -angle_difference(float(ep.last_row.yaw), atan2(-velocity.x, -velocity.z)) / rpc])
				if mode_override == "pause_invalid":
					pause_probe.call_deferred()
			"ground":
				commands.append(["space", false])
			"stall":
				commands.append(["space", false])
				commands.append(["w", true])
			"restart": game.restart_run()
			"respawn": game.respawn()
			"respawn_revisit":
				game.respawn()
				for key: String in KEYS:
					commands.append([key, false])
				ep.memory.clear()
				ep.memory.mode = "back"
				ep.memory.t0 = t
			"practice": game.practise_stage(0)
			"settings": game.change_setting("source_fov", 97.0)
			"paused_settings_quit":
				game.set_paused(true)
				game.change_setting("source_fov", 97.0)
				game.request_quit(0)
				game.set_paused(false)
			"map": game.select_map("whiteout-relay")
			"preset": game.select_preset("aa1000")
			"loadout": game.set_mechanic("wall_jump", false)
			"quit": game.request_quit(0)
			"pause":
				pause_probe.call_deferred()
			"noop":
				var before: Dictionary = host_style.snapshot()
				game.select_map(game.map_id)
				game.select_map("absent-style-map")
				game.select_preset(game.preset_id)
				game.select_preset("absent-style-preset")
				game.set_mechanic("absent", true)
				game.set_mechanic("wall_jump", bool(game.lab_moves().wall_jump))
				action_after = {"unchanged": host_style.snapshot() == before}
	if did_action and mode_override in ["rearm", "pause_invalid"] and t == action_tick + 100:
		commands.append(["mouse", PI / rpc])
	if did_action and mode_override in ["restart", "respawn", "practice", "settings", "paused_settings_quit", "map", "preset", "loadout", "quit"]:
		commands = []
		for key: String in KEYS:
			commands.append([key, false])
		# stop observing at the public boundary; the file is already sealed or loss queued.
		if mode_override in ["quit", "paused_settings_quit"]:
			running = false
			episode_done.emit.call_deferred()
	for command: Array in commands:
		if command[0] == "mouse":
			command[1] = Vector2(float(command[1]), 0.0).x
		send(command)
	if not commands.is_empty():
		ep.recorded[t] = commands

func pre_style() -> void:
	if running:
		var player: CharacterBody3D = game.player
		_pre_write = {"p": player.global_position, "v": player.velocity, "yaw": player.yaw, "g": player.is_grounded()}

func late_tick() -> void:
	if not running or game.paused:
		return
	var player: CharacterBody3D = game.player
	var now := {"p": player.global_position, "v": player.velocity, "yaw": player.yaw, "g": player.is_grounded()}
	if not _pre_write.is_empty() and now != _pre_write:
		write_violations.append(current_name + ":" + str(ep.tick))
	var snap: Dictionary = host_style.snapshot()
	var sample: Dictionary = game.session.last_sample
	if sample.is_empty():
		return
	if parity_active:
		var old: Array = baseline.step(sample, game.player, game.level)
		var fresh: Array = host_style.events.filter(func(e: Dictionary) -> bool: return int(e.tick) == int(sample.tick))
		parity_ok = parity_ok and old == fresh and baseline.score == host_style.score
		parity_samples += 1
	var motion: Dictionary = player.get_motion_state()
	var t := int(ep.tick) - SETTLE
	var total := 0
	for e: Dictionary in host_style.events:
		total += int(e.points)
	var row := {"t": t, "sample_tick": sample.tick, "p": player.global_position, "v": player.velocity / U, "spd": Vector2(sample.actual_v.x, sample.actual_v.z).length() / U,
		"g": player.is_grounded(), "yaw": player.yaw, "respawns": game.respawn_count, "direction": snap.direction, "diag": snap.diag.direction,
		"score": snap.score, "event_total": total, "events": motion.events, "time_s": snap.time_s, "elapsed": game.elapsed}
	host_rows.append(row)
	ep.last_row = row
	if native or observer:
		var transition: Dictionary = snap.direction.last
		if int(snap.direction.hops) == 6 and not pending_frame.has(current_name):
			pending_frame[current_name] = true
			observers.append({"episode": current_name, "state": "pending", "observation": _plain(row), "sample_tick": sample.tick, "episode_tick": t, "simulation_s": snap.time_s})
			if native:
				capture_marker.call_deferred("pending", row)
		if not transition.is_empty() and int(transition.pending) > 0 and not pending_frame.has(current_name + ":end"):
			pending_frame[current_name + ":end"] = true
			var state := "banked" if transition.kind == "direction_banked" else "lost"
			observers.append({"episode": current_name, "state": state, "observation": _plain(row), "sample_tick": sample.tick, "episode_tick": t, "simulation_s": snap.time_s})
			if native:
				capture_marker.call_deferred(state, row)
	if int(ep.tick) >= int(ep.length):
		running = false
		episode_done.emit()

func pause_probe() -> void:
	game.set_paused(true)
	var before := [host_style.snapshot(), game.player.global_position, game.player.velocity, game.elapsed, game.session.tick]
	for i: int in 12:
		await process_frame
	game.set_paused(true)
	var after := [host_style.snapshot(), game.player.global_position, game.player.velocity, game.elapsed, game.session.tick]
	action_after = {"unchanged": before == after, "before": before, "after": after}
	game.set_paused(false)

func capture_marker(label: String, row: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(current_name + "-" + label + ".png")
	root.get_texture().get_image().save_png(path)
	observers.append({"state": label, "path": path, "observation": _plain(row), "physics_frame": Engine.get_physics_frames()})

func finish_case() -> void:
	# calibrate an earned input trajectory, then place the trigger before replay begins.
	var calibration := await run_case("finish_calibration", "pause", 1300)
	var rows: Array = calibration.rows
	var target: Dictionary = rows.filter(func(r: Dictionary) -> bool: return int(r.direction.hops) >= 6)[0]
	var at: Vector3 = target.p
	var spec := {"pieces": [FIX.deck("long_floor", -150, 150, -800, 400, 0.0)], "spawn": Transform3D(Basis.IDENTITY, Vector3(0, 0, 4)),
		"finish": AABB(at - Vector3(0.3, 4, 0.2), Vector3(0.6, 8, 0.4))}
	var result := await run_case("finish", "finish", 1300, "back", spec)
	var banks: Array = result.events.filter(func(e: Dictionary) -> bool: return str(e.kind).ends_with("_bank"))
	check("first_inclusive_finish_banks_exact_once", banks.size() == 1 and banks[0].m.reason == "finish" and int(banks[0].points) == STYLE.pending_points("backward_bhop", int(banks[0].m.hops)), banks)

	var stall_spec := {"pieces": [FIX.deck("long_floor", -150, 150, -800, 400, 0.0), FIX.block("finish_wall", Vector3(-150, 0, -56), Vector3(150, 6, -55))],
		"spawn": Transform3D(Basis.IDENTITY, Vector3(0, 0, 4)), "finish": AABB(Vector3(-150, -4, -55), Vector3(300, 8, 0.45))}
	var stalled := await run_case("finish_stall", "finish", 1300, "back", stall_spec)
	check("finish_at_low_actual_speed_loses_before_bank", stalled.snapshot.finished and stalled.events.filter(func(e: Dictionary) -> bool: return str(e.kind).ends_with("_bank")).is_empty() and stalled.diagnostics.any(func(d: Dictionary) -> bool: return d.kind == "direction_lost" and d.reason == "stall" and int(d.pending) > 0))

func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_plain(value), "\t"))
	file.close()

func equivalent(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key: Variant in a:
			if not b.has(key) or not equivalent(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i: int in a.size():
			if not equivalent(a[i], b[i]):
				return false
		return true
	return a == b

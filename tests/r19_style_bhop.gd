extends "res://tests/test_r16_style.gd"
## real unchanged r15 motor on the existing collision fixture; only key/mouse input earns hops.
var baseline: RefCounted
var baseline_path := ""
var forward_parity := true
var compare_forward := false
var compared := 0
var special := ""
var injected := false
var split_tick := -1
var loop_pose := Vector3.ZERO
var fake_style := STYLE.new()

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		if arg.begins_with("--baseline="):
			baseline_path = arg.trim_prefix("--baseline=")
	assert(out_dir.is_absolute_path())
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("episodes"))
	Engine.physics_ticks_per_second = 128
	game = MAIN.new()
	game.level_script = FIX
	game.motor = "server128"
	game.set_window_title = false
	root.add_child(game)
	level = game.level
	probe = PROBE.new(game)
	root.add_child(probe)
	for spec: Array in [["early_tick", -1000], ["pre_style", 999], ["late_tick", 1001]]:
		var hook := Hook.new()
		hook.suite = self
		hook.phase = spec[0]
		hook.process_physics_priority = spec[1]
		root.add_child(hook)
	rpc = float(game.player.tape_radians_per_count)
	await process_frame
	await physics_frame
	var back := await episode("backwards", FIX.flat_spec(), 1100, {}, direction_controller, {"mode": "back"})
	var side := await episode("half_sideways", FIX.flat_spec(), 1100, {}, direction_controller, {"mode": "side"})
	var backs := of_kind(back.events, "backward_bhop")
	var sides := of_kind(side.events, "sideways_bhop")
	check("backwards_earned_and_growing", backs.size() >= 4 and float(backs[1].direction_mult) > float(backs[0].direction_mult), backs.map(func(e: Dictionary) -> float: return float(e.direction_mult)))
	check("sideways_earned_and_smaller", sides.size() >= 4 and float(sides[0].direction_mult) < float(backs[0].direction_mult) and int(sides[0].points) < int(backs[0].points), sides.map(func(e: Dictionary) -> float: return float(e.direction_mult)))
	check("multiplier_caps", not backs.is_empty() and not sides.is_empty() and float(backs[-1].direction_mult) == 4.0 and float(sides[-1].direction_mult) <= 1.8)
	check("actual_hops_and_real_speed", back.rows.any(func(r: Dictionary) -> bool: return not r.g and r.spd >= 300.0) and not backs.is_empty() and int(backs[0].m.hops) == 2)
	for mode: String in ["idle", "slow", "walk", "tiny"]:
		var neg := await episode("negative_" + mode, FIX.flat_spec(), 650, {}, direction_controller, {"mode": mode})
		check(mode + "_no_direction_award", directional(neg.events).is_empty())
	fake_style.reset()
	special = "fake"
	await episode("fake_hops_walking", FIX.flat_spec(), 650, {}, direction_controller, {"mode": "walk"})
	check("fake_hop_counters_and_grounded_jump_events_do_not_pay", directional(fake_style.events).is_empty())
	special = "respawn"
	injected = false
	var respawn := await episode("respawn_chain", FIX.flat_spec(), 900, {}, direction_controller, {"mode": "back"})
	check("respawn_requires_two_new_hops", after_break_safe(respawn.events), "break %d" % split_tick)
	special = "teleport"
	injected = false
	var teleport := await episode("teleport_chain", FIX.flat_spec(), 900, {}, direction_controller, {"mode": "back"})
	check("teleport_detected", int(teleport.snapshot.diag.auto_breaks) > 0)
	check("teleport_requires_two_new_hops", after_break_safe(teleport.events), "break %d" % split_tick)
	special = "loop"
	injected = false
	var loop := await episode("repeat_line", FIX.flat_spec(), 1100, {}, direction_controller, {"mode": "back"})
	var repeat_events := directional(loop.events).filter(func(e: Dictionary) -> bool: return ep_t(e) > 800)
	check("revisited_line_cannot_farm", injected and repeat_events.is_empty() and int(loop.snapshot.diag.farm_blocked.get("direction", 0)) > 0, loop.snapshot.diag.farm_blocked)
	special = "oscillation"
	injected = false
	var oscillation := await episode("oscillation", FIX.flat_spec(), 1000, {}, direction_controller, {"mode": "back"})
	check("reversing_heading_breaks_chain", directional(oscillation.events).filter(func(e: Dictionary) -> bool: return ep_t(e) > split_tick + 100).is_empty())
	special = ""
	if not baseline_path.is_empty():
		baseline = (load(baseline_path) as Script).new()
		compare_forward = true
		var forward := await episode("forward_parity", FIX.flat_spec(), 2000, {}, ctl_strafe, {"run_ticks": 110})
		compare_forward = false
		check("forward_exact_r18_events_and_score", compared > 1000 and forward_parity, "%d compared samples" % compared)
		check("forward_existing_events_present", of_kind(forward.events, "sync").size() > 2 and of_kind(forward.events, "speed").size() > 0)
	check("observer_never_writes_body", write_violations.is_empty(), write_violations)
	root.remove_child(probe)
	probe.free()
	game.request_quit(0)
	root.remove_child(game)
	game.free()
	await process_frame
	await host_recording_check()
	await metadata_check()
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.pass)
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed.size(), "episodes": episodes, "identity": STYLE.identity()}, "\t"))
	file.close()
	print("r19 style: %d checks, %d failed" % [checks.size(), failed.size()])
	quit(0 if failed.is_empty() else 1)

func directional(items: Array) -> Array:
	return items.filter(func(e: Dictionary) -> bool: return str(e.kind) in ["backward_bhop", "sideways_bhop"])

func after_break_safe(items: Array) -> bool:
	var after := directional(items).filter(func(e: Dictionary) -> bool: return ep_t(e) > split_tick)
	return not after.is_empty() and int(after[0].m.hops) == 2 and ep_t(after[0]) - split_tick > 80

func early_tick() -> void:
	super()
	if not running:
		return
	var t := int(ep.tick) - SETTLE
	if special == "loop" and t == 400:
		loop_pose = game.player.global_position
	if special in ["respawn", "teleport", "loop", "oscillation"] and t == (800 if special == "loop" else 650) and not injected:
		injected = true
		split_tick = t
		if special == "respawn":
			probe.style.discontinuity("respawn")
		elif special == "teleport":
			game.player.global_position.x += 8.0
		elif special == "loop":
			# labelled placement replays the same earned line; novelty must survive this break.
			game.player.global_position = loop_pose
			probe.style.discontinuity("respawn")
		else:
			send(["s", false])
			send(["w", true])

func late_tick() -> void:
	if running and compare_forward:
		if int(ep.tick) == 1:
			baseline.reset()
		var sample := PROBE.sample_of(game, probe.tick - 1)
		var old: Array = baseline.step(sample, game.player, level)
		var fresh: Array = probe.style.events.filter(func(e: Dictionary) -> bool: return int(e.tick) == probe.tick - 1)
		for event: Dictionary in fresh:
			var copy := event.duplicate(true)
			copy.erase("direction_mult")
			copy.erase("combo_mult")
			var index := fresh.find(event)
			if index >= old.size() or copy != old[index]:
				forward_parity = false
		forward_parity = forward_parity and fresh.size() == old.size() and baseline.score == probe.style.score
		compared += 1
	if running and special == "fake":
		var sample := PROBE.sample_of(game, probe.tick - 1)
		sample.stats = {"hops": probe.tick, "last_hop": {}}
		sample.motion = sample.motion.duplicate(true)
		sample.motion.events = ["jump"]
		fake_style.step(sample, game.player, level)
	super()

func direction_controller(t: int, row: Dictionary, m: Dictionary) -> Array:
	var mode := str(m.mode)
	if mode in ["back", "side"]:
		if not m.has("turned"):
			m["coast_ups"] = 360.0
			var commands := ctl_strafe(t, row, m)
			if m.has("coast"):
				m["turned"] = true
				var v: Vector3 = row.v
				var travel_yaw := atan2(-v.x, -v.z)
				var target := travel_yaw + (PI * 0.5 if mode == "side" else PI)
				commands.append(["mouse", -angle_difference(float(row.yaw), target) / rpc])
			return commands
		return []
	if t == 1:
		return [["w", true]] if mode != "idle" else []
	if t == 110 and mode != "idle":
		var turn := PI * 0.5 if mode == "side" else PI
		var commands: Array = [["w", false], ["mouse", -turn / rpc], ["d" if mode == "side" else "s", true]]
		if mode != "walk":
			commands.append(["space", true])
		if mode in ["slow", "tiny"]:
			commands.append(["ctrl", true])
		return commands
	return []

func host_recording_check() -> void:
	game = preload("res://scripts/r17_main.gd").new()
	game.level_script = FIX
	game.motor = "server128"
	game.persist = false
	game.seed_from_r15 = false
	game.record_runs = true
	game.recordings_dir = out_dir.path_join("actual-host-recordings")
	root.add_child(game)
	level = game.level
	probe = PROBE.new(game)
	root.add_child(probe)
	var run := await episode("actual_r18_host", FIX.flat_spec(), 950, {}, direction_controller, {"mode": "back"})
	var expected := directional(run.events)
	var observed := directional(game.session.style.events)
	check("actual_host_earns_direction_bonus", expected.size() >= 3 and observed.size() == expected.size())
	game.restart_run()
	var seal: Dictionary = game.session.sealed[-1]
	var recording: Dictionary = preload("res://scripts/r16_run_reader.gd").read(str(seal.path))
	var recorded := []
	for event: Dictionary in recording.events:
		if event.k == "style" and str(event.get("d", {}).get("kind", "")) == "backward_bhop":
			recorded.append(event)
	check("actual_recording_contains_direction_events", bool(recording.ok) and recorded.size() == expected.size(), "recorded %d / expected %d" % [recorded.size(), expected.size()])
	check("actual_recording_new_scoring_same_motion", recording.header.metadata.scoring.style.version == STYLE.STYLE_VERSION and preload("res://scripts/r16_run_reader.gd").identity_matches(recording.header.identity, game.motion_identity()).is_empty())
	root.remove_child(probe)
	probe.free()
	game.request_quit(0)
	root.remove_child(game)
	game.free()
	await process_frame

func metadata_check() -> void:
	var host := preload("res://scripts/r17_main.gd").new()
	host.persist = false
	host.record_runs = false
	host.seed_from_r15 = false
	root.add_child(host)
	host.set_paused(true)
	var meta: Dictionary = host.recording_metadata("test")
	check("recording_uses_new_style_identity", meta.scoring.style == STYLE.identity() and str(meta.scoring.style_key).begins_with("r19-style-1/"))
	if baseline != null:
		check("old_style_bests_separate", baseline.identity_key() != STYLE.identity_key())
	var physical := var_to_str([host.course_key, host.record_identity(), host.motion_identity(), host.physics_fingerprint()])
	var recorder := preload("res://scripts/r16_run_recorder.gd").new()
	var begin: Dictionary = recorder.begin_run(meta, out_dir.path_join("recordings"))
	var sample: Dictionary = host.session.build_sample(1.0 / 128.0)
	recorder.capture(sample, [])
	var seal: Dictionary = recorder.finish({"kind": "test", "finished": false, "clean": false})
	var recorded: Dictionary = preload("res://scripts/r16_run_reader.gd").read(str(seal.get("path", "")))
	check("recording_file_roundtrip_new_scoring_identity", bool(begin.ok) and bool(seal.ok) and bool(recorded.ok) and recorded.header.metadata.scoring.style.version == STYLE.STYLE_VERSION)
	var style_key: String = host._style_section()
	check("style_best_section_is_new", not style_key.is_empty())
	check("time_identity_excludes_scoring", not physical.contains("r19-style") and meta.identity == host.motion_identity())
	host.set_paused(false)
	host.request_quit(0)
	root.remove_child(host)
	host.free()

extends "res://tests/r20_tether_component.gd"
## additional real-input lifecycle, old-ghost and pending-style boundaries; parent may render this seam.
var native := false

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	Engine.physics_ticks_per_second = 128
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			root.size = Vector2i(int(parts[0]), int(parts[1]))
	native = OS.get_cmdline_user_args().has("--native")
	RenderingServer.render_loop_enabled = native
	hook = Post.new()
	hook.driver = self
	hook.process_physics_priority = 1001
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	new_case("extra_boundaries")
	await ticks(33)
	for reason: String in ["practice", "respawn", "preset"]:
		rope(false)
		await ticks(1)
		aim(LEVEL.ANCHORS[0])
		rope(true)
		await ticks(10)
		check(not game.player.grapple.is_empty(), "earned attachment before " + reason)
		match reason:
			"practice": game.practise_stage(0)
			"respawn": game.respawn()
			"preset": game.select_preset("server128_aa1000")
		await ticks(15)
		check(game.player.grapple.is_empty(), reason + " clears attachment and held input cannot reacquire")
		game.restart_run()
		await ticks(1)
	# physically activate a pause-menu preference by pointer, while it owns the input.
	rope(false)
	await ticks(1)
	game.set_paused(true)
	await ticks(2)
	var control: Button = game.hud.reel_automatic
	control.grab_focus()
	game.hud._pause_scroll.ensure_control_visible(control)
	await process_frame
	await process_frame
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	send(motion)
	var click := InputEventMouseButton.new()
	click.position = point
	click.global_position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	send(click)
	click = click.duplicate()
	click.pressed = false
	send(click)
	await process_frame
	check(game.settings.tether_auto_reel, "actual mouse click on real pause control selects automatic reel")
	if native:
		# the setting refresh rebuilds the pause sheet; restore the tested control into view.
		game.hud._pause_scroll.ensure_control_visible(control)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("pause-preference.png"))
	game.set_paused(false)
	await ticks(10)
	check(game.player.grapple.is_empty(), "menu pointer click does not leak into rope acquisition")
	for reason: String in ["time", "range", "obstructed", "released"]:
		var cue: AudioStreamWAV = game.player.cues[reason]
		check(cue.save_to_wav(output.path_join("cue-" + reason + ".wav")) == OK, "export actual self-made cue PCM for parent listening: " + reason)
	# physical ghost identity checks use completed files from this suite's actual course routes.
	game.select_preset("server128")
	await ticks(1)
	var route_root := output.get_base_dir()
	var ghost_receipts: Array = []
	for label: String in ["classic", "pendulum", "elastic", "old_e", "automatic"]:
		var summary: Variant = JSON.parse_string(FileAccess.get_file_as_string(route_root.path_join(label + "/summary.json")))
		if summary is not Dictionary:
			check(false, "required earned ghost route exists: " + label)
			continue
		var rec: Dictionary = summary.recordings.filter(func(r: Dictionary) -> bool: return bool(r.clean_finish.get("ok", false)))[0]
		var result: Dictionary = game.session.ghost.load_run(rec.path, game.motion_identity())
		var should_load := label == "automatic"
		check(bool(result.ok) == should_load, "actual ghost loader identity accepts only matching model/reel: " + label)
		ghost_receipts.append({"label": label, "result": result})
	var actual_old := "/home/thatmike1/foldrunner-build-2026-11-05/playtest-r19/userdata-spillway/r16_runs/tether-yard_server128_20261110-075454_795_d73c2888.r16run"
	var actual_read := READER.read(actual_old)
	var old_result: Dictionary = game.session.ghost.load_run(actual_old, game.motion_identity())
	check(bool(actual_read.ok) and bool(READER.clean_finish(actual_read).ok) and not bool(old_result.ok) and "identity differs" in str(old_result.get("error", "")), "actual delivered R19 playtest clean ghost is refused for identity")
	ghost_receipts.append({"label": "actual_delivered_r19", "path": actual_old, "sha256": FileAccess.get_sha256(actual_old), "header_identity": actual_read.header.identity, "result": old_result})
	var receipt := FileAccess.open(output.path_join("ghosts.json"), FileAccess.WRITE)
	receipt.store_string(JSON.stringify(ghost_receipts, "\t"))
	receipt.close()
	for model_id: String in ["pendulum", "elastic"]:
		new_case(model_id + "_hold")
		game.set_paused(true)
		activate(game.hud.tether_models[model_id])
		game.set_paused(false)
		await ticks(33)
		aim(LEVEL.ANCHORS[0])
		button(1, true)
		await ticks(1)
		var rest: float = game.player.grapple_length_u
		key(KEY_S, true)
		key(KEY_SPACE, true)
		await ticks(100)
		key(KEY_SPACE, false)
		key(KEY_S, false)
		check(not game.player.grapple.is_empty() and game.player.grapple_length_u == rest, model_id + " LMB swing holds fixed unreelled rest length")
		if model_id == "pendulum":
			check(game.player.impulse_totals.grapple_rope.length() > 0.0 and game.player.impulse_totals.grapple_pull == Vector3.ZERO, "pendulum has taut radial correction and no spring pull")
		else:
			check(game.player.impulse_totals.grapple_pull.length() > 0.0 and game.player.impulse_totals.grapple_rope == Vector3.ZERO, "elastic has spring pull and no hard radial correction")
		var state: String = game.player.experiment_status()
		check(model_id.capitalize() in state and "swinging" in state and "left" in state, "model, reel and remaining time readable in actual HUD state")
	new_case("pending_style")
	# an explicitly identified, wide flat continuation exists only in this input fixture.
	var floor_body := StaticBody3D.new()
	floor_body.name = "FixtureWideFlat"
	floor_body.set_meta("role", "route")
	floor_body.set_meta("surface", "r20_fixture_flat")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 500)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, 3.5, 0)
	game.level.add_child(floor_body)
	game._kill_bounds = AABB(Vector3(-200, -100, -200), Vector3(400, 300, 500))
	game.course_geometry = "r20-tether-wideflat-pending-boundary-v1"
	game._refresh_records()
	game.restart_run("fixture_pending")
	await ticks(33)
	key(KEY_W, true)
	var air_started := -1
	var coasting := false
	for tick: int in range(1, 1000):
		if tick == 110:
			key(KEY_SPACE, true)
		if tick >= 110 and air_started < 0 and not game.player.is_grounded():
			air_started = tick
			key(KEY_W, false)
		if air_started >= 0 and not coasting:
			var velocity: Vector3 = game.player.velocity
			var scale: float = game.player.tape_radians_per_count
			var motion_event := InputEventMouseMotion.new()
			if Vector2(velocity.x, velocity.z).length() / 0.0254 >= 360.0 and not game.player.is_grounded():
				coasting = true
				key(KEY_A, false)
				key(KEY_D, false)
				var target := atan2(-velocity.x, -velocity.z) + PI
				motion_event.relative = Vector2(-angle_difference(float(game.player.yaw), target) / scale, 0)
			else:
				var target := deg_to_rad(28.0) * sin(float(tick - air_started) / 96.0 * TAU)
				var turn := clampf(target - float(game.player.yaw), -0.04, 0.04)
				motion_event.relative = Vector2(-turn / scale, 0)
				key(KEY_A, turn > 0.0)
				key(KEY_D, turn <= 0.0)
			motion_event.screen_relative = motion_event.relative
			send(motion_event)
		await ticks(1)
		if int(game.session.style.snapshot().direction.pending) > 0:
			break
	key(KEY_SPACE, false)
	var pending: int = game.session.style.snapshot().direction.pending
	check(pending > 0, "backwards hops earn real pending style before rope-setting boundary")
	game.set_paused(true)
	activate(game.hud.reel_automatic)
	check(game.session.style.snapshot().direction.pending == 0 and game.session.style.summary().score == 0, "rope setting restarts discard pending and cannot cash it out")
	var prior: Dictionary = READER.read(game.session.sealed[-1].path)
	check(prior.events.any(func(e: Dictionary) -> bool: return e.k == "direction" and e.d.kind == "direction_lost" and e.d.reason == "tether_settings"), "pending loss records before old attempt seals")
	check(not prior.events.any(func(e: Dictionary) -> bool: return e.k == "style" and str(e.d.kind).ends_with("_bank")), "no direction bank on rope model/reel boundary")
	close_case()
	# quit is asynchronous in production; its rope clearing runs before its final drain.
	new_case("quit")
	await ticks(33)
	aim(LEVEL.ANCHORS[0])
	rope(true)
	await ticks(15)
	check(not game.player.grapple.is_empty(), "earned attachment before real request_quit")
	game.request_quit(0)
	check(game.player.grapple.is_empty() and game.player.last_cue.reason == "quit", "real quit clears attachment before recorder drain")
	var quit_reads: Array = []
	for sealed: Dictionary in game.session.sealed:
		var rec := READER.read(str(sealed.path))
		quit_reads.append({"path": sealed.path, "ok": rec.ok, "header": rec.header, "seal": rec.seal, "columns": rec.columns, "inputs": rec.inputs, "events": rec.events})
	var quit_file := FileAccess.open(output.path_join("quit.json.gz"), FileAccess.WRITE)
	quit_file.store_buffer(JSON.stringify({"recordings": quit_reads, "observations": observations, "inputs": inputs}).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	quit_file.close()
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks, "episodes": episodes, "scope": "production boundaries and pointer menu; parent owns native/listening"}, "\t"))
	file.close()
	if not ok:
		# the production drain still owns process shutdown.
		game.get_tree().quit(1)

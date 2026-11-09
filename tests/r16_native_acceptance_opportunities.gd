extends "res://tests/r16_opportunities_driver.gd"
## real R16 session/panel and authored maps; inherited input-only passage controller.
const ACTUAL16 := preload("res://scripts/r16_main.gd")

func _start() -> void:
	trial = str(opts.get("case", "breakwater-crouch"))
	max_ticks = 2200
	amp = deg_to_rad(8.0)
	game = ACTUAL16.new()
	game.map_id = "whiteout-relay" if trial.begins_with("whiteout") else "breakwater"
	game.motor = str(opts.get("preset", "server128"))
	game.set_window_title = false
	game.set("persist", false)
	game.set("recordings_dir", out_dir.path_join("runs"))
	game.set("record_runs", true)
	root.add_child(game)
	lab = game
	level = game.level
	player = game.player
	source = true
	hz = Engine.physics_ticks_per_second
	warmup = 33
	radians_per_count = float(player.tape_radians_per_count)
	turn_cap = deg_to_rad(600.0) / hz
	overlay_report = game.opportunities
	style = game.session.style
	if game.map_id == "breakwater":
		game.practise_stage(3)
		setup = {"kind": "authored stage practice", "stage": 3, "movement_writes_after_setup": 0}
		opportunity = Vector3(-81.3, 0, -198 if trial.contains("thread") else -166)
		nodes = [{"p": Vector2(-81.3, -126), "r": 0.3}]
		if trial.contains("thread"):
			amp = deg_to_rad(3.0)
			nodes = [{"p": Vector2(-78, -174), "r": 0.2}, {"p": Vector2(-81.3, -183), "r": 0.2}, {"p": Vector2(-81.3, -194), "hop": true, "vt": 430.0, "r": 0.3}]
	else:
		setup = {"kind": "normal map spawn", "movement_writes_after_setup": 0}
		opportunity = Vector3(-8, 0, -28)
		nodes = [{"p": Vector2(-4.5, -18.5), "r": 0.25}, {"p": Vector2(-8, -22.5), "r": 0.2}]
	node_from = Vector2(player.global_position.x, player.global_position.z)
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	root.size = Vector2i(1280, 720)
	game.hud.visible = true

func _observe(tick: int) -> void:
	# the session already scored this post-step tick at priority 999; do not step style twice.
	var sample: Dictionary = game.session.last_sample
	var fresh: Array = sample.get("style_events", [])
	var motion: Dictionary = player.get_motion_state()
	if absf(player.global_position.z - opportunity.z) < 1.0:
		crossing.append({"tick": tick, "p": _v(player.global_position), "v": _v(player.velocity), "grounded": player.is_grounded(), "ducked": player.ducked})
	rows.append(JSON.stringify({"tick": tick, "p": _v(player.global_position), "v": _v(player.velocity), "yaw": player.yaw, "pitch": player.pitch,
		"grounded": player.is_grounded(), "ducked": player.ducked, "held": held.keys(), "score": style.snapshot(), "motion": plain(motion)}))

func _end(reason: String, tick: int) -> void:
	done = true
	_want({}, tick)
	await process_frame
	if capture_busy:
		await RenderingServer.frame_post_draw
	_write("opportunity.json", {"label": "actual R16 host and session, inherited closed-loop input controller; player-camera proof; practice explicitly labelled",
		"case": trial, "reason": reason, "ticks": tick, "setup": setup, "crossing": crossing, "captures": captures,
		"overlay": overlay_report, "style": style.snapshot(), "style_summary": style.summary(), "host": game.get_script().resource_path,
		"runner": player.get_script().resource_path, "finished": game.finished, "practice_reason": game.practice_reason})
	var file := FileAccess.open(out_dir.path_join("trace.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(rows) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	game.request_quit(0 if reason == "passed" else 1)

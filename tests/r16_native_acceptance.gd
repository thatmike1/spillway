extends "res://tools/momentum-tape.gd"
## actual R16 host, inherited tick delivery, compact post-step traces and player-camera evidence.
## engine-injected tape input is distinct from the separate OS-input observer tour.

const HOST16 := preload("res://scripts/r16_main.gd")
const READER16 := preload("res://scripts/r16_run_reader.gd")
const LAB_VIEWS := preload("res://tests/r16_native_acceptance_lab.gd")
var shots: Array = []
var checks: Array = []
var tour_rows: Array = []
var shot_busy := false
var shot_tags := {}
var tour := false
var tour_tick := 0
var event_count := 0
var freeze_info := {}
var overlap_replay := false
var overlap_at := 0
var overlap_warmup := 0
var overlap_rows: Array = []

func _build_world() -> Array:
	world_kind = "lab"
	game = HOST16.new()
	game.set("map_id", str(opts.get("map", "breakwater")))
	game.set("motor", "server128")
	game.set("source_sensitivity_override", 2.5)
	game.set("persist", true)
	game.set("seed_from_r15", false)
	game.set("recordings_dir", out_dir.path_join("runs"))
	game.set("record_runs", true)
	root.add_child(game)
	player = game.player
	if game.is_lab() and DisplayServer.get_name() != "headless":
		var layer := CanvasLayer.new()
		layer.layer = 30
		game.add_child(layer)
		var label := LAB_VIEWS.ReadOnlyOverlay.new()
		label.host = game
		label.position = Vector2(800, 100)
		label.add_theme_font_size_override("font_size", 13)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.02, 0.04, 0.06, 0.8)
		box.set_content_margin_all(6.0)
		label.add_theme_stylebox_override("normal", box)
		layer.add_child(label)
	setup_writes.append("actual r16_main.gd _ready: normal authored spawn; F2; recorded to isolated output")
	return []

func early_step(delta: float) -> void:
	if overlap_replay:
		_deliver_mouse(overlap_at, "overlap_early_physics")
		return
	super(delta)

func late_step(delta: float) -> void:
	if overlap_warmup > 0:
		overlap_warmup -= 1
		if overlap_warmup == 0:
			overlap_replay = true
			_deliver_keys(0, "overlap_exact_warmup_arm")
		return
	if overlap_replay:
		overlap_rows.append({"tick": overlap_at, "p": _v3(player.global_position), "v": _v3(player.velocity), "yaw": player.yaw, "pitch": player.pitch, "grounded": player.is_grounded(), "events": player.get_motion_state().events, "ghost": ghost_info()})
		if overlap_at > 400 and "land" in player.get_motion_state().events:
			shot("overlap-landing-fade", overlap_at)
		if overlap_at in [700, 750, 800]:
			shot("overlap-landing-%d" % overlap_at, overlap_at)
		overlap_at += 1
		_deliver_keys(overlap_at, "overlap_late_physics")
		return
	if finished or row.is_empty():
		return
	var tick := int(row.tick)
	var is_tape := str(row.phase) == "tape"
	if not _rate_ok("late", delta):
		_finish("rate_changed", 5)
		return
	var state: Dictionary = game.session.style.snapshot()
	var compact := {"tick": tick, "p": _v3(player.global_position), "v": _v3(player.velocity), "yaw": player.yaw, "pitch": player.pitch,
		"keys": row.get("keys", []), "mouse": row.get("mouse", {}), "grounded": player.is_grounded(), "ducked": player.ducked, "elapsed": game.elapsed, "checkpoint": game.checkpoint_index,
		"finished": game.finished, "finish_kind": game.finish_kind, "respawns": game.respawn_count, "style": state,
		"held": game.session.last_sample.get("held", {}), "motion_events": player.get_motion_state().events, "lab": _plain(player.get_motion_state().get("experiment", {}))}
	if is_tape:
		trace.store_line(JSON.stringify(compact, "", false, true))
		if tick in [30, 250, 700, 1400, 2400, 3600, 4700]:
			shot("course-%05d" % tick, tick)
		if game.map_id == "whiteout-relay" and player.global_position.x < -6.5:
			if player.global_position.z < -18.0:
				shot("whiteout-crouch-approach", tick)
			if player.global_position.z < -27.6:
				shot("whiteout-crouch-passage", tick)
			if player.global_position.z < -31.0:
				shot("whiteout-crouch-exit", tick)
		if game.is_lab():
			var lab_state: Dictionary = player.get_motion_state().experiment
			for event: String in ["slide_armed", "slide_landing", "wall_jump", "wall_refill"]:
				if event in lab_state.events and (event != "wall_refill" or int(lab_state.counts.wall_jump) > 0):
					shot("lab-" + event + ("-budget%d" % lab_state.wall_jump.budget if event == "wall_jump" else ""), tick)
			if int(lab_state.counts.get("slide_landing", 0)) > 0 and "jump" in player.get_motion_state().events:
				shot("lab-fresh-hop", tick)
		var count := int(state.get("events", 0))
		if int(state.get("score", 0)) > 0 and not shot_tags.has("first-style"):
			shot("first-style", tick)
		if int(state.get("combo", 0)) >= 2:
			shot("first-combo", tick)
		var last: Dictionary = state.get("last", {})
		if str(last.get("kind", "")) in ["crouch_save", "near_miss", "sync"]:
			shot("style-" + str(last.kind), tick)
		last_tick = tick
		tape_dt_sum += delta
		if tick + 1 >= duration:
			_finish("completed", 0)
			return
		_deliver_keys(tick + 1, "late_physics")
	elif not armed and step >= warmup:
		# arm at the exact settled step, independent of process/render cadence.
		armed = true
		arm_step = step
		_deliver_keys(0, "exact_warmup_late_arm")
	row = {}

func _on_draw() -> void:
	# the parent writes frame telemetry only for movie/readback modes; this harness owns selected shots.
	pass

func _process(delta: float) -> bool:
	return false

func shot(tag: String, tick: int = -1) -> void:
	if shot_tags.has(tag):
		return
	shot_tags[tag] = tick
	if DisplayServer.get_name() == "headless":
		return
	if shot_busy:
		return
	shot_busy = true
	await RenderingServer.frame_post_draw
	var file := tag + ".jpg"
	root.get_texture().get_image().save_jpg(out_dir.path_join(file), 0.88)
	var camera: Camera3D = player.camera
	shots.append({"file": file, "requested_tick": tick, "physics_frame": Engine.get_physics_frames(), "camera": _v3(camera.global_position),
		"feet": _v3(player.global_position), "actual_player_camera": root.get_camera_3d() == camera,
		"elapsed": game.elapsed, "paused": game.paused, "map": game.map_id, "style": game.session.style.snapshot(), "ghost": ghost_info()})
	shot_busy = false

func ghost_info() -> Dictionary:
	var ghost: Node3D = game.session.ghost
	return {"state": game.session.ghost_state, "path": game.session.ghost_path, "ticks": game.session.ghost_ticks,
		"shown": game.ghost_shown(), "visible": ghost.visible, "loaded": ghost.loaded, "fade": ghost.fade(),
		"feet": READER16.json_safe(ghost.pose_at(game.elapsed).get("feet", Vector3.ZERO)), "body_visible": ghost.get_node("Body").visible,
		"pose": READER16.json_safe(ghost.pose_at(game.elapsed)), "camera": _v3(player.camera.global_position)}

func raw_key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func wait_ticks(n: int) -> void:
	for i: int in n:
		await physics_frame
		tour_tick += 1
		if i % 4 == 0:
			tour_rows.append({"tick": tour_tick, "p": _v3(player.global_position), "v": _v3(player.velocity), "elapsed": game.elapsed, "ghost": ghost_info(),
				"style": game.session.style.snapshot(), "held": game.session.last_sample.get("held", {})})

func tap(code: Key) -> void:
	raw_key(code, true)
	await wait_ticks(1)
	raw_key(code, false)
	await wait_ticks(1)

func _finish(reason: String, code: int) -> void:
	if finished:
		return
	finished = true
	tour = true
	trace.flush()
	trace.close()
	frames_log.close()
	freeze_info = {"reason": reason, "code": code, "last_tick": last_tick, "finished": game.finished, "finish_kind": game.finish_kind,
		"respawns": game.respawn_count, "time": game.elapsed, "best_time": game.best_time, "style_best": game.style_best,
		"finish_style": game.finish_style, "last_seal": game.session.last_seal, "ghost": ghost_info(), "runner": player.get_script().resource_path,
		"main": game.get_script().resource_path, "setup_writes": setup_writes}
	_run_tour.call_deferred(code)

func _run_tour(code: int) -> void:
	for key: String in held.keys():
		_send_key(key, false)
	held.clear()
	await wait_ticks(16)
	shot("finish-time-style-bests")
	await wait_ticks(32)
	if opts.has("tape-only"):
		_write_json("summary.json", {"label": "actual R16 host, unchanged supplied tape, player camera", "finish": freeze_info, "shots": shots})
		game.request_quit(code if bool(freeze_info.finished) and freeze_info.finish_kind == "clean" else 1)
		return
	# the R key goes through the game's real input and restart/session APIs; no best file is fabricated.
	await tap(KEY_R)
	await wait_ticks(20)
	shot("ghost-overlap-faded")
	await wait_ticks(12)
	raw_key(KEY_CTRL, true)
	raw_key(KEY_W, true)
	await wait_ticks(112)
	shot("ghost-ahead-near-fade")
	await wait_ticks(110)
	shot("ghost-ahead-clear")
	await wait_ticks(16)
	await tap(KEY_G)
	shot("ghost-hidden-G")
	await wait_ticks(32)
	await tap(KEY_G)
	shot("ghost-shown-G")
	await wait_ticks(32)
	raw_key(KEY_W, false)
	raw_key(KEY_CTRL, false)
	await wait_ticks(20)
	delivered.clear()
	pending.clear()
	overlap_at = 0
	await process_frame
	raw_key(KEY_R, true)
	raw_key(KEY_R, false)
	overlap_warmup = 33
	while overlap_warmup > 0:
		await physics_frame
	while overlap_at < 830:
		await physics_frame
	overlap_replay = false
	for key: String in held.keys():
		_send_key(key, false)
	held.clear()
	await wait_ticks(20)
	await tap(KEY_ESCAPE)
	shot("escape-menu-map-recording-ghost")
	await wait_ticks(32)
	checks.append({"name": "unchanged accepted tape clean finish", "ok": bool(freeze_info.finished) and freeze_info.finish_kind == "clean" and int(freeze_info.respawns) == 0})
	checks.append({"name": "real finish populated time and style best", "ok": float(freeze_info.best_time) > 0 and int(freeze_info.style_best) >= 0})
	checks.append({"name": "sealed fastest clean recording automatically loaded", "ok": bool(game.session.ghost.loaded) and not str(game.session.ghost_path).is_empty()})
	_write_json("summary.json", {"label": "actual R16 host, player camera, engine-injected unchanged accepted R15 tape then slower crouch walk and G/Esc; no human latency/feel claim",
		"finish": freeze_info, "checks": checks, "shots": shots, "tour": tour_rows, "overlap_replay": overlap_rows, "source_sha256": FileAccess.get_sha256("res://scripts/r16_main.gd")})
	game.request_quit(code if checks.all(func(c: Dictionary) -> bool: return c.ok) else 1)

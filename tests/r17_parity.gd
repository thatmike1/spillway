extends "res://tools/momentum-tape.gd"
## source-only parity adapter: complete retained input, normal host spawn, observational samples.
## configuration below selects map/preset/sensitivity and isolated recording output before ready.
const READER := preload("res://scripts/r16_run_reader.gd")
var variant := ""
var checks: Array = []
var tour_rows: Array = []
var tour_at := -1
var frozen := {}
var toggle_rows: Array = []
var max_speed := 0.0
var movie_ticks := -1
var ghost_trace: FileAccess

func _build_world() -> Array:
	variant = str(opts.get("variant", "r16"))
	var host: Script = load("res://scripts/r16_main.gd" if variant == "r16" else "res://scripts/r17_main.gd")
	game = host.new()
	game.map_id = str(opts.get("map", "breakwater"))
	game.motor = str(opts.get("preset", "server128"))
	game.source_sensitivity_override = float(opts.get("sensitivity", "2.5"))
	game.persist = false
	game.seed_from_r15 = false
	game.record_runs = true
	game.recordings_dir = out_dir.path_join("runs")
	root.add_child(game)
	player = game.player
	if opts.has("ghost"):
		check(game.session.ghost.loaded, "same golden ghost discovered before moving tape")
		check(FileAccess.get_sha256(game.session.ghost_path) == FileAccess.get_sha256(str(opts.ghost)), "discovered golden ghost bytes match baseline")
	ghost_trace = FileAccess.open(out_dir.path_join("evaluator/ghost.jsonl"), FileAccess.WRITE)
	world_kind = "lab"
	movie_ticks = int(opts.get("movie-ticks", "-1"))
	setup_writes.append("normal authored spawn via actual host ready; map/preset/sensitivity configured before ready; isolated recordings; no body/progress writes")
	return []

func raw_key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key) -> void:
	raw_key(code, true)
	raw_key(code, false)

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "name": label})

func gameplay() -> Dictionary:
	return {"p": _v3(player.global_position), "v": _v3(player.velocity), "yaw": player.yaw, "pitch": player.pitch,
		"grounded": player.is_grounded(), "ducked": game.is_crouched(), "motion": _plain(player.get_motion_state()),
		"elapsed": game.elapsed, "checkpoint": game.checkpoint_index, "finished": game.finished, "finish_kind": game.finish_kind,
		"respawns": game.respawn_count, "started": game._started, "clean": game.clean_eligible, "paused": game.paused,
		"attempts": game.attempts, "practice_stage": game.practice_stage, "practice_reason": game.practice_reason,
		"style": game.session.style.snapshot(), "stats": game.stats.snapshot(), "course_key": game.course_key,
		"identity": game.motion_identity(), "map": game.map_id, "preset": game.preset_id}

func look_toggle(label: String) -> void:
	if variant == "r16":
		return
	var before := JSON.stringify(gameplay(), "", true, true)
	var prior: bool = game.look_enabled
	tap(KEY_L)
	check(game.look_enabled != prior, label + ": actual Input L changed look")
	check(before == JSON.stringify(gameplay(), "", true, true), label + ": L preserved immediate gameplay")
	toggle_rows.append({"at": last_tick, "label": label, "before": prior, "after": game.look_enabled, "speed_m_s": player.velocity.length(), "finished": game.finished})

func early_step(delta: float) -> void:
	if tour_at >= 0:
		return
	super(delta)

func late_step(delta: float) -> void:
	if tour_at >= 0:
		_tour_step()
		return
	if finished or row.is_empty():
		return
	if not _rate_ok("late", delta):
		_finish("rate_changed", 5)
		return
	var tick := int(row.tick)
	if str(row.phase) == "tape":
		var sample := gameplay()
		sample["tick"] = tick
		sample["dt"] = delta
		sample["physics_hz"] = Engine.physics_ticks_per_second
		sample["input"] = READER.json_safe(game.session.last_sample.get("input_events", []).map(func(e: Variant) -> Dictionary: return game.session.describe(e)))
		sample["held"] = game.session.last_sample.get("held", {})
		sample["reference_p"] = _v3(game.body_reference())
		sample["actual_v"] = READER.json_safe(game.session.last_sample.get("actual_v", Vector3.ZERO))
		trace.store_line(JSON.stringify(sample, "", false, true))
		var ghost: Node3D = game.session.ghost
		ghost_trace.store_line(JSON.stringify({"tick": tick, "loaded": ghost.loaded, "visible": ghost.visible, "shown": game.ghost_shown(),
			"pose_at_clock": READER.json_safe(ghost.pose_at(game.elapsed)), "body_position": _v3(ghost.get_node("Body").position),
			"body_visible": ghost.get_node("Body").visible, "fade": ghost.fade()}, "", false, true))
		max_speed = maxf(max_speed, Vector2(player.velocity.x, player.velocity.z).length())
		last_tick = tick
		tape_dt_sum += delta
		if variant == "toggle" and tick in [40, 113, 381, 700, 1200, 1900, 2600, 3400, 4400]:
			look_toggle("moving tick %d" % tick)
		if tick + 1 >= duration or (movie_ticks > 0 and tick + 1 >= movie_ticks):
			_finish("completed", 0)
			return
		_deliver_keys(tick + 1, "late_physics")
	elif not armed and step >= warmup:
		armed = true
		arm_step = step
		_deliver_keys(0, "exact_warmup_late_arm")
	row = {}

func _process(_delta: float) -> bool:
	return false

func _on_draw() -> void:
	pass

func _finish(reason: String, code: int) -> void:
	if finished:
		return
	finished = true
	trace.flush()
	trace.close()
	ghost_trace.close()
	frames_log.close()
	frozen = gameplay()
	frozen["reason"] = reason
	frozen["code"] = code
	frozen["last_tick"] = last_tick
	frozen["max_speed_m_s"] = max_speed
	frozen["record_path"] = str(game.session.last_seal.get("path", ""))
	check(code == 0, "tape completed at declared physics rate")
	if variant == "toggle":
		check(toggle_rows.any(func(t: Dictionary) -> bool: return float(t.speed_m_s) > 0.1 and not bool(t.finished)), "actual L dispatch occurred during moving unfinished run")
	if movie_ticks > 0:
		_write_summary()
		game.request_quit(code)
		return
	check(game.finished and game.finish_kind == "clean" and game.respawn_count == 0, "complete earned-input clean finish")
	check(game.session.ghost.loaded, "actual finish has matching loaded clean ghost")
	var file := str(opts.get("ghost", frozen.record_path))
	var read := READER.read(file, true)
	check(read.ok, "Godot reader validates complete clean recording")
	var loaded: Dictionary = game.session.ghost.load_run(file, game.motion_identity())
	check(bool(loaded.ok), "same golden recording loads against actual motion identity")
	check(game.session.ghost.find_children("*", "CollisionObject3D", true, false).is_empty(), "live ghost has no physical objects")
	var probes: Array = []
	for at: float in [-1.0, 0.0, 0.00390625, 0.453125, 1.00390625, game.elapsed * 0.5 + 0.00390625, game.elapsed, game.elapsed + 1.0]:
		var before := JSON.stringify(gameplay(), "", true, true)
		game.session.ghost.set_time(at)
		probes.append({"time": at, "pose": READER.json_safe(game.session.ghost.pose_at(at)), "body": _v3(game.session.ghost.get_node("Body").position),
			"fade": game.session.ghost.fade(), "visible": game.session.ghost.visible})
		check(before == JSON.stringify(gameplay(), "", true, true), "ghost interpolation never changes gameplay")
	frozen["ghost_probes"] = probes
	# no new player attempt before the complete route and its recording have been frozen.
	for key: String in held.keys():
		_send_key(key, false)
	held.clear()
	row = {}
	tour_at = 0

func _tour_step() -> void:
	player = game.player
	var ghost: Node3D = game.session.ghost
	var body: MeshInstance3D = ghost.get_node("Body")
	tour_rows.append({"tick": tour_at, "game": gameplay(), "ghost": {"loaded": ghost.loaded, "shown": game.ghost_shown(),
		"visible": ghost.visible, "pose": READER.json_safe(ghost.pose_at(game.elapsed)), "body_visible": body.visible, "fade": ghost.fade()}})
	match tour_at:
		0:
			tap(KEY_R)
		4:
			check(not game.finished and game.clean_eligible and game.checkpoint_index == 0, "actual R restarts clean at spawn")
			check(ghost.loaded, "actual R keeps matching live ghost")
		8:
			tap(KEY_G)
		10:
			check(not game.ghost_shown() and not ghost.visible, "actual G hides live ghost")
		12:
			tap(KEY_G)
		14:
			check(game.ghost_shown() and ghost.visible, "actual G restores live ghost")
		16:
			tap(KEY_ESCAPE)
		18:
			check(game.paused, "actual Escape pauses")
			if variant == "toggle":
				look_toggle("paused")
		22:
			tap(KEY_ESCAPE)
		24:
			check(not game.paused, "actual Escape resumes")
		28:
			tap(KEY_F)
		30:
			check(not game.clean_eligible, "actual F enters recorded practice")
		32:
			tap(KEY_R)
		36:
			tap(KEY_F5)
		40:
			check(game.preset_id == "server128_aa1000", "actual F5 selects AA1000")
			tap(KEY_R)
		44:
			tap(KEY_F2)
		48:
			tap(KEY_R)
		52:
			tap(KEY_ESCAPE)
		54:
			var next_map := "experiment" if game.map_id != "experiment" else "breakwater"
			var button: Button = game.hud.find_child("Map_" + next_map, true, false)
			check(button != null, "real pause map control exists")
			if button != null:
				button.pressed.emit()
		56:
			check(game.map_id == ("experiment" if str(opts.get("map")) != "experiment" else "breakwater"), "pause map button loads selected map")
			check(not ghost.loaded, "map identity rejects old ghost")
			if variant == "toggle":
				look_toggle("after map change")
		60:
			var bad: Dictionary = game.motion_identity().duplicate(true)
			bad["look"] = "invented presentation identity"
			var bad_load: Dictionary = ghost.load_run(str(opts.get("ghost", frozen.record_path)), bad)
			check(not bool(bad_load.ok) and not ghost.loaded, "strict reader rejects different identity")
		64:
			_write_summary()
			game.request_quit(0 if checks.all(func(c: Dictionary) -> bool: return c.ok) else 1)
			tour_at = -2
	if tour_at >= 0:
		tour_at += 1

func _write_summary() -> void:
	_write_json("summary.json", {"scope": "headless source-only actual-host engine Input replay; no visual or enjoyment acceptance", "variant": variant,
		"finish": frozen, "checks": checks, "toggles": toggle_rows, "tour": tour_rows, "setup_writes": setup_writes})

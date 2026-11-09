extends "res://tests/test_r16_loop.gd"
## independent reductions on the actual r16 session. inherited helpers only deliver input,
## observe files and create labelled fixtures; production files are never patched.

const REVIEW_FIX := preload("res://tests/r16_host_review_fixture.gd")
const REVIEW_STYLE := preload("res://scripts/r16_style.gd")
var review_rows: Array = []
var review_ctl: Callable
var review_t := 0
var review_memory := {}
var before_style := {}
var readonly_failures := 0
var shadow: RefCounted
var shadow_events: Array = []
var sent_late := false

class ReviewHook extends Node:
	var suite: Object
	var callback: String
	func _physics_process(delta: float) -> void:
		suite.call(callback, delta)

func _main() -> void:
	_observer = Observer.new(self)
	root.add_child(_observer)
	for entry: Array in [["review_early", -1000], ["review_before", 998], ["review_late", 1000]]:
		var hook := ReviewHook.new()
		hook.suite = self
		hook.callback = entry[0]
		hook.process_physics_priority = entry[1]
		hook.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(hook)
	for group: String in ["lifecycle", "preset", "pending", "ghost", "lab", "overlay"]:
		_group = "inherited_" + group
		await call("_group_" + group)
		await _drop_game()
	_group = "independent"
	await attribution()
	await boundary_bursts()
	await disk_failure()
	await corrupt_ghost_neighbors()
	await crouch_challenges()
	await gap_edge_challenges()
	await finish_challenge()
	check("production session never changed motor state at priorities 998..1000", readonly_failures == 0, readonly_failures)
	await _drop_game()
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	var report := {"checks": results.size(), "failed": failed.size(), "results": results, "notes": notes,
		"engine": Engine.get_version_info(), "source": {}}
	for path: String in ["scripts/r16_main.gd", "scripts/r16_run_session.gd", "scripts/r16_hud.gd", "scripts/r16_style.gd", "scripts/r16_run_reader.gd", "scripts/r16_run_recorder.gd", "scripts/r16_ghost.gd"]:
		report.source[path] = FileAccess.get_sha256("res://" + path)
	write_json("summary.json", report)
	print("host review: %d checks, %d failures" % [results.size(), failed.size()])
	quit(1 if not failed.is_empty() else 0)

func write_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(READER.json_safe(value), "  "))
	file.close()

func review_early(_delta: float) -> void:
	if review_ctl.is_valid() and is_instance_valid(game) and not game.paused:
		review_t += 1
		review_ctl.call()

func motor_pose() -> Dictionary:
	return {"p": p().global_position, "v": p().velocity, "g": p().call("is_grounded"), "yaw": p().get("yaw"), "pitch": p().get("pitch"), "duck": p().get("ducked")}

func review_before(_delta: float) -> void:
	before_style = motor_pose() if is_instance_valid(game) else {}

func review_late(_delta: float) -> void:
	if not is_instance_valid(game) or game.paused:
		return
	if not before_style.is_empty() and before_style != motor_pose():
		readonly_failures += 1
	if not review_ctl.is_valid():
		return
	var s: Dictionary = game.session.last_sample
	if s.is_empty():
		return
	if shadow != null:
		var copy := s.duplicate(true)
		copy.finished = false
		shadow_events.append_array(shadow.step(copy, p(), game.level))
	var snap: Dictionary = game.session.style.snapshot()
	var row := {"t": review_t, "tick": s.tick, "p": s.p, "v": s.v, "actual_v": s.actual_v, "g": s.grounded, "d": s.ducked,
		"started": s.started, "finished": s.finished, "score": snap.score, "hops": s.stats.hops, "contacts": s.motion.contacts,
		"crouch": snap.diag.crouch, "input": game.session.describe_all(s.input_events), "motion_events": s.motion.events}
	review_rows.append(row)
	if bool(review_memory.get("late_input", false)) and not sent_late and review_t == 30:
		key(KEY_A, true)
		mouse(7.0)
		sent_late = true

func attribution() -> void:
	await make_game({"runs": runs_dir("attribution")})
	review_rows = []
	review_t = 0
	sent_late = false
	review_memory = {"late_input": true}
	review_ctl = func() -> void:
		if review_t == 1:
			key(KEY_W, true)
	await ticks(70)
	review_ctl = Callable()
	var before: Dictionary = review_rows.filter(func(r: Dictionary) -> bool: return r.t == 30)[0]
	var after: Dictionary = review_rows.filter(func(r: Dictionary) -> bool: return r.t == 31)[0]
	check("priority 1000 key belongs to the next post-motor sample", not before.input.any(func(e: Dictionary) -> bool: return e.get("keycode") == KEY_A) and after.input.any(func(e: Dictionary) -> bool: return e.get("keycode") == KEY_A and e.pressed), [before.input, after.input])
	check("priority 1000 mouse belongs to the next post-motor sample", not before.input.any(func(e: Dictionary) -> bool: return e.type == "mouse_motion") and after.input.any(func(e: Dictionary) -> bool: return e.type == "mouse_motion"), [before.input, after.input])
	write_json("attribution.json", review_rows)
	await _drop_game()

func disk_failure() -> void:
	await make_game({"runs": runs_dir("disk")})
	await run_clean()
	await ticks(3)
	var old_path: String = game.session.ghost_path
	var old_hash := FileAccess.get_sha256(old_path)
	await tap(KEY_R)
	# labelled recorder fault injection: the production writer fails on its next chunk.
	game.session.recorder.fail_after_bytes = 0
	await run_clean()
	await ticks(3)
	check("disk-failed recording does not stop a real clean finish", game.finished and game.finish_kind == "clean" and game.session.recorder.status == "disk-error", [game.finished, game.finish_kind, game.session.recorder.status])
	check("disk-failed recording retains older best ghost and its bytes", game.session.ghost_path == old_path and FileAccess.get_sha256(old_path) == old_hash and game.session.ghost.loaded, [old_path, game.session.ghost_path])
	check("disk-failed host counts the uncaptured tail", int(game.session.last_seal.get("dropped_ticks", 0)) > 0, game.session.last_seal)
	notes.disk = {"old_path": old_path, "old_sha256": old_hash, "failure": game.session.last_seal, "warning": game.session.last_error}
	await _drop_game()

func corrupt_ghost_neighbors() -> void:
	var directory := runs_dir("disk")
	var baseline: String = str(notes.disk.old_path)
	var bytes := FileAccess.get_file_as_bytes(baseline)
	# labelled external disk fixtures: a truncated file and a broken stored pointer, never
	# fabricated samples passed to the production recorder.
	var corrupt := directory.path_join("corrupt-neighbor.r16run")
	var handle := FileAccess.open(corrupt, FileAccess.WRITE)
	handle.store_buffer(bytes.slice(0, bytes.size() - 40))
	handle.close()
	await make_game({"runs": directory})
	check("actual host scans past corrupt and disk-failed neighbors to its older clean ghost", game.session.ghost_state == "loaded" and game.session.ghost_path == baseline, [game.session.ghost_state, game.session.ghost_path])
	check("actual host promoted a dense clean recording under the repaired reader", READER.clean_finish(READER.read(baseline, true)).ok)
	var section: String = game.call("_ghost_section")
	var identity: String = game.call("record_identity_text")
	var ghost_ticks: int = game.session.ghost_ticks
	await _drop_game()
	for candidate: String in [directory.path_join("missing.r16run"), corrupt]:
		var profile := out_dir.path_join("ghost-fixture.cfg")
		var config := ConfigFile.new()
		config.set_value(section, "identity", identity)
		config.set_value(section, "time_ticks", ghost_ticks)
		config.set_value(section, "path", candidate)
		config.save(profile)
		game = MAIN.new()
		game.set("level_script", FIXTURE)
		game.set("recordings_dir", directory)
		game.set("record_runs", true)
		game.set("profile_path", profile)
		game.set("persist", true)
		root.add_child(game)
		_observer.set("watched", game)
		await ticks(16)
		check("stored %s pointer recovers the older clean ghost through actual host startup" % candidate.get_file(), game.session.ghost_state == "loaded" and game.session.ghost_path == baseline, [game.session.ghost_state, game.session.ghost_path])
		key(KEY_W, true)
		await ticks(10)
		check("bad stored ghost pointer does not stop play", p().velocity.length() > 0.0)
		await _drop_game()

func episode(label: String, spec: Dictionary, length: int, ctl: Callable) -> Dictionary:
	await _drop_game()
	REVIEW_FIX.review_spec = spec
	await make_game({"level": REVIEW_FIX, "runs": runs_dir(label), "settle": 12})
	review_rows = []
	review_t = 0
	review_memory = {}
	review_ctl = ctl
	shadow = REVIEW_STYLE.new()
	shadow_events = []
	await ticks(length)
	review_ctl = Callable()
	var result := {"label": label, "rows": review_rows.duplicate(true), "events": game.session.style.events.duplicate(true),
		"shadow_events": shadow_events.duplicate(true), "snapshot": game.session.style.snapshot(), "finished": game.finished,
		"finish_kind": game.finish_kind, "finish_style": game.finish_style, "style_best": game.style_best, "ghost": game.session.ghost_state,
		"last_seal": game.session.last_seal}
	shadow = null
	write_json(label + ".json", result)
	return result

func beam_spec() -> Dictionary:
	var spec := REVIEW_FIX.flat_spec()
	spec.pieces.append(REVIEW_FIX.block("review_beam", Vector3(-2, 1.48, -16.0), Vector3(2, 2.6, -15.0)))
	return spec

func crouch_controller() -> void:
	if review_t == 1:
		key(KEY_W, true)
	if p().global_position.z < -14.45 and not review_memory.has("duck"):
		key(KEY_CTRL, true)
		review_memory.duck = review_t

func crouch_challenges() -> void:
	var positive := await episode("crouch_positive", beam_spec(), 800, crouch_controller)
	check("actual host crouch pass earns one geometry-backed save", positive.events.filter(func(e: Dictionary) -> bool: return e.kind == "crouch_save").size() == 1, positive.events)
	var air_ctl := func() -> void:
		if review_t == 1:
			key(KEY_W, true)
		if p().global_position.z < -10.0 and not review_memory.has("jump"):
			review_memory.jump = review_t
			key(KEY_SPACE, true)
		if review_memory.has("jump") and review_t == int(review_memory.jump) + 4:
			key(KEY_CTRL, true)
	var cal := await episode("crouch_scrape_calibration", REVIEW_FIX.flat_spec(), 600, air_ctl)
	var entry: Dictionary = {}
	for row: Dictionary in cal.rows:
		if row.d and not row.g and (row.v as Vector3).y < 3.0 and (row.v as Vector3).y > 2.0:
			entry = row
			break
	check("scrape calibration supplies a rising airborne duck", not entry.is_empty(), entry.get("t"))
	if entry.is_empty():
		return
	var spec := REVIEW_FIX.flat_spec()
	var front: float = (entry.p as Vector3).z - 16.0 * U - 0.03
	var bottom: float = (entry.p as Vector3).y + 54.0 * U + 0.05
	spec.pieces.append(REVIEW_FIX.block("review_beam", Vector3(-2, bottom, front - 2.0), Vector3(2, bottom + 1.0, front)))
	var slope := await episode("crouch_scrape", spec, 600, air_ctl)
	var hits: Array = slope.rows.filter(func(r: Dictionary) -> bool: return (r.contacts as Array).any(func(c: Dictionary) -> bool: return str(c.get("body", "")) == "review_beam"))
	var bad: Array = slope.events.filter(func(e: Dictionary) -> bool: return e.kind == "crouch_save" and bool(e.m.duck_contact))
	check("scrape challenge reached the same obstacle with the actual duck hull", not hits.is_empty(), hits.slice(0, 2))
	check("a passage that hit its obstacle cannot earn a crouch save", bad.is_empty(), bad)
	# repeated tiny taps are actual engine key events, with no body or sample edits.
	var taps := await episode("tiny_taps", REVIEW_FIX.flat_spec(), 650, func() -> void:
		if review_t == 1:
			key(KEY_W, true)
		if review_t > 100:
			key(KEY_CTRL, review_t % 2 == 0))
	check("tiny repeated crouch taps on floor earn no crouch gap or edge", taps.events.all(func(e: Dictionary) -> bool: return not e.kind in ["crouch_save", "gap", "edge"]), taps.events)

func gap_edge_challenges() -> void:
	var ctl := func() -> void:
		if review_t == 1:
			key(KEY_W, true)
		if p().global_position.z < -14.0 and not review_memory.has("jump"):
			key(KEY_SPACE, true)
			review_memory.jump = review_t
		if review_memory.has("jump") and review_t == int(review_memory.jump) + 1:
			key(KEY_SPACE, false)
	var cal := await episode("gap_calibration", REVIEW_FIX.flat_spec(), 620, ctl)
	var air := -1
	var landing := -1
	for i: int in cal.rows.size():
		if not cal.rows[i].g and air < 0:
			air = i
		if air >= 0 and i > air and cal.rows[i].g:
			landing = i
			break
	check("gap calibration contains a complete earned hop", air > 0 and landing > air, [air, landing])
	if air <= 0 or landing <= air:
		return
	var near_lip: float = (cal.rows[air - 1].p as Vector3).z - 16.0 * U - 0.1
	var far_lip: float = (cal.rows[landing].p as Vector3).z - 16.0 * U + 3.0 * U
	var spec := {"pieces": [REVIEW_FIX.deck("near", -6, 6, 8, near_lip, 0), REVIEW_FIX.deck("far", -6, 6, far_lip, -200, 0)], "spawn": Transform3D(Basis.IDENTITY, Vector3(0, 0, 4))}
	var run := await episode("gap_edge", spec, 620, ctl)
	var gaps: Array = run.events.filter(func(e: Dictionary) -> bool: return e.kind == "gap")
	var edges: Array = run.events.filter(func(e: Dictionary) -> bool: return e.kind == "edge")
	check("actual host gap measures the authored collision void", gaps.size() == 1 and absf(float(gaps[0].m.cleared_m) - (near_lip - far_lip)) < 0.002, gaps)
	check("actual host edge measures the authored three-unit landing slack", edges.size() == 1 and absf(float(edges[0].m.slack_u) - 3.0) < 0.05, edges)
	(spec.pieces as Array).append(REVIEW_FIX.deck("shallow", -6, 6, near_lip, far_lip, -0.5, -1.5))
	var shallow := await episode("gap_shallow", spec, 620, ctl)
	check("shallow trench is not a gap or edge on actual host", shallow.events.all(func(e: Dictionary) -> bool: return not e.kind in ["gap", "edge"]), shallow.events)
	var farm_spec := {"pieces": [REVIEW_FIX.deck("near", -6, 6, 8, near_lip, 0), REVIEW_FIX.deck("far", -6, 6, far_lip, far_lip - 4, 0)], "spawn": Transform3D(Basis.IDENTITY, Vector3(0, 0, 4))}
	var farm := await episode("gap_respawn_repeat", farm_spec, 1800, func() -> void:
		if int(game.respawn_count) != int(review_memory.get("respawns", 0)):
			review_memory.respawns = int(game.respawn_count)
			review_memory.erase("jump")
		ctl.call())
	check("actual-host respawn repeat reaches a second crossing", int(game.respawn_count) > 0 and int(farm.snapshot.diag.farm_blocked.get("gap", 0)) > 0, farm.snapshot.diag)
	check("actual-host repeated geometry never pays another gap", farm.events.filter(func(e: Dictionary) -> bool: return e.kind == "gap").size() == 1, farm.events)

func finish_challenge() -> void:
	var ctl := func() -> void:
		if review_t == 1:
			key(KEY_W, true)
		if review_t == 95:
			key(KEY_SPACE, true)
		if review_t > 95 and not p().call("is_grounded"):
			key(KEY_W, false)
			var sign_turn := 1.0 if review_t % 160 < 80 else -1.0
			key(KEY_A, sign_turn > 0)
			key(KEY_D, sign_turn < 0)
			mouse(-sign_turn * 4.0)
	var cal := await episode("finish_calibration", REVIEW_FIX.flat_spec(), 600, ctl)
	var speeds: Array = cal.events.filter(func(e: Dictionary) -> bool: return e.kind == "sync")
	check("finish calibration earned a high-gain sync event from actual strafe hops", not speeds.is_empty(), cal.events)
	if speeds.is_empty():
		return
	var target: Dictionary = speeds[0]
	var idx := -1
	for i: int in cal.rows.size():
		if int(cal.rows[i].tick) == int(target.tick):
			idx = i
	if idx < 2:
		check("finish calibration supplies a prior sample", false, idx)
		return
	# labelled geometry setup: finish volume enters on the body from the prior motor step,
	# so the host declares finish on exactly the next motor step that earns sync in calibration.
	var last: Vector3 = cal.rows[idx - 1].p
	var prior: Vector3 = cal.rows[idx - 2].p
	var half := minf(0.01, last.distance_to(prior) * 0.2)
	var spec := REVIEW_FIX.flat_spec()
	spec.finish = AABB(last - Vector3.ONE * half, Vector3.ONE * half * 2.0)
	var run := await episode("finish_scoring", spec, int(cal.rows[idx].t) + 10, ctl)
	var final_rows: Array = run.rows.filter(func(r: Dictionary) -> bool: return r.finished)
	check("finish reduction actually reached the host finish volume", not final_rows.is_empty() and run.finish_kind == "clean", [run.finished, run.finish_kind, last])
	var prod_speed: Array = run.events.filter(func(e: Dictionary) -> bool: return e.kind == "sync")
	var shadow_speed: Array = run.shadow_events.filter(func(e: Dictionary) -> bool: return e.kind == "sync")
	check("the earned finish-tick sync event is scored before the style best seals", not prod_speed.is_empty(), {"cal_event": target, "production": prod_speed, "shadow": shadow_speed, "finish_style": run.finish_style})
	check("finish-tick reward is sealed as the clean style best", int(run.style_best) == int(target.points) and int(run.finish_style.get("score", -1)) == int(target.points) and run.last_seal.get("ok", false) == true \
		and int((READER.read(str(run.last_seal.get("path", ""))).seal.get("outcome", {}).get("style", {}) as Dictionary).get("score", -1)) == int(target.points), run.last_seal)
	notes.finish_scoring = {"cal_event": target, "production": prod_speed, "shadow": shadow_speed, "finish_rows": final_rows.slice(0, 2), "seal": run.last_seal}

func boundary_bursts() -> void:
	await make_game({"runs": runs_dir("bursts")})
	var sealed: Array = game.session.sealed
	# all four events enter through Input in one batch before the next motor step.
	key(KEY_W, true)
	mouse(3.0)
	key(KEY_CTRL, true)
	key(KEY_R, true)
	await ticks(3)
	key(KEY_R, false)
	key(KEY_CTRL, false)
	key(KEY_W, false)
	await ticks(3)
	key(KEY_A, true)
	mouse(-2.0)
	key(KEY_F, true)
	await ticks(3)
	key(KEY_F, false)
	key(KEY_A, false)
	await ticks(3)
	await _drop_game()
	var runs := filesFrom(sealed)
	for pair: Array in [[0, "restart", KEY_R, KEY_W], [1, "practice", KEY_F, KEY_A]]:
		var boundary: Dictionary = events_of(runs[pair[0]], pair[1])[0].d
		check("burst %s keeps its terminating edge in the old attempt" % pair[1], int(boundary.edge[0].keycode) == pair[2] and bool(boundary.edge[0].pressed), boundary)
		check("burst %s keeps prior inputs with the discarded old body step" % pair[1], (boundary.inputs as Array).any(func(e: Dictionary) -> bool: return e.get("keycode") == pair[3] and bool(e.get("pressed", false))) and (boundary.inputs as Array).any(func(e: Dictionary) -> bool: return e.type == "mouse_motion"), boundary)
		check("burst %s does not relabel the old press as new-step input" % pair[1], not has_key(inputs_at(runs[int(pair[0]) + 1], 0), pair[3], 1), inputs_at(runs[int(pair[0]) + 1], 0))

extends SceneTree
## p / r16 product loop on the actual r16 main: attempt boundaries, the post-step sample, style
## best, recordings, the ghost and records across processes. every run is played with ordinary
## key and relative-mouse events through Input, and menu controls are clicked through the
## viewport; nothing calls the game's finish, select, practise or session methods, or writes the
## runner's pose or velocity. the drivers are closed loop where named (for example "W until the
## feet pass z -9, then Space"): they read the game to decide when to press, never to move it.
##
## what plays here: the production r15 runner on the labelled fixture tests/r16_loop_fixture_level.gd
## (a start deck, a void, a landing deck and a finish deck), the frozen r15 loop fixture for the
## hull-wait group, and the real registry's Movement Lab for the lab group. fixture evidence says
## the host keeps its contract; it says nothing about a course route or how anything feels.
## godot --headless --audio-driver Dummy --fixed-fps 128 --path . \
##   --script res://tests/test_r16_loop.gd -- --out=DIR [--only=GROUPS]

const MAIN := preload("res://scripts/r16_main.gd")
const SCENE := "res://scenes/r16.tscn"
const FIXTURE := preload("res://tests/r16_loop_fixture_level.gd")
const SLOT_FIXTURE := preload("res://tests/r15_loop_fixture_level.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
const STYLE := preload("res://scripts/r16_style.gd")
const PRESETS := preload("res://scripts/r15_presets.gd")
const MAPS := preload("res://scripts/r15_maps.gd")
## the overlay builder's accepted report hashes (docs/r16/OPPORTUNITIES.md).
const OVERLAY_HASHES := {"breakwater": "2590f2e57702c52cc4f48231b1dad5ddcf9be64174dfe1d3463dada882ce053e", "whiteout-relay": "8f71afface3d8bc1b17edabc5a3d9ea54a88dd16ec3928b8765f7127df6d956e"}
const U := 0.0254
const GROUPS := ["isolated", "lifecycle", "preset", "pending", "ghost", "lab", "hud", "overlay", "persist"]

var out_dir := ""
var results: Array[Dictionary] = []
var only: Array = []
var phase := ""
var _group := ""
var game: Node
var notes: Dictionary = {}
## one row per sample the session took: what the observer saw right after it.
var observed: Array[Dictionary] = []
var _observer: Node

class Observer extends Node:
	var owner_test: Object
	## the game being watched; kept here so its last frames before it is freed are still seen.
	var watched: Node
	var _last: Dictionary = {}
	func _init(test: Object) -> void:
		owner_test = test
		process_physics_priority = 1001
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _physics_process(_delta: float) -> void:
		var g: Node = watched
		if g == null or not is_instance_valid(g) or g.get("session") == null or g.session == null:
			return
		var s: Node = g.session
		if s.last_sample.is_empty() or is_same(s.last_sample, _last):
			return
		_last = s.last_sample
		var ghost: Node3D = s.ghost
		(owner_test.get("observed") as Array).append({"run_id": str(s.recorder.run_id), "tick": int(_last.tick), "p": _last.p, "v": _last.v, "yaw": float(_last.yaw),
			"elapsed": float(_last.elapsed), "checkpoint": int(_last.checkpoint), "script": (g.player.get_script() as Script).resource_path,
			"preset": str(g.preset_id), "ghost_feet": (ghost.call("pose_at", float(_last.elapsed)) as Dictionary).get("feet") if ghost.get("loaded") == true else null,
			"ghost_fade": float(ghost.call("fade")) if ghost.get("loaded") == true else -1.0, "ghost_visible": ghost.visible})

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	if out_dir.is_empty():
		printerr("usage: --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_main.call_deferred()

func _main() -> void:
	_observer = Observer.new(self)
	root.add_child(_observer)
	if not phase.is_empty():
		await _child_phase()
		return
	var started := Time.get_ticks_msec()
	for group: String in GROUPS:
		if only.is_empty() or group in only:
			_group = group
			print("group: ", group)
			await call("_group_" + group)
			await _drop_game()
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	var summary := {"checks": results.size(), "failed": failed.size(), "results": results, "seconds": (Time.get_ticks_msec() - started) / 1000.0,
		"engine": Engine.get_version_info(), "notes": notes, "style_identity": STYLE.identity()}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(READER.json_safe(summary), "  "))
	file.close()
	for r: Dictionary in failed:
		printerr("FAIL %s / %s: %s" % [r.group, r.name, r.detail])
	print("r16 loop: %d checks, %d failed" % [results.size(), failed.size()])
	quit(1 if failed.size() > 0 else 0)

func check(name: String, ok: bool, detail: Variant = "") -> bool:
	results.append({"group": _group, "name": name, "ok": ok, "detail": str(detail).left(900)})
	if not ok:
		printerr("  fail: %s (%s)" % [name, str(detail).left(400)])
	return ok

# --- input and stepping -----------------------------------------------------------------------

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key) -> void:
	key(code, true)
	await physics_frame
	key(code, false)
	await physics_frame

func mouse(dx: float, dy: float = 0.0) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.screen_relative = Vector2(dx, dy)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)
		await process_frame

func click_visible(control: Control) -> bool:
	var scroll: ScrollContainer = game.hud.get("_pause_scroll")
	for i: int in 80:
		var view := scroll.get_global_rect()
		var rect := control.get_global_rect()
		if view.encloses(rect):
			break
		var at := view.get_center()
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_WHEEL_DOWN if rect.position.y > view.position.y else MOUSE_BUTTON_WHEEL_UP
			event.pressed = pressed
			event.position = at
			event.global_position = at
			event.factor = 1.0
			root.push_input(event, true)
		await process_frame
	var inside := scroll.get_global_rect().encloses(control.get_global_rect())
	await click(control)
	return inside

func ticks(n: int) -> void:
	for i: int in n:
		await physics_frame

func until(cond: Callable, limit: int) -> int:
	for i: int in limit:
		if cond.call():
			return i
		await physics_frame
	return -1 if not cond.call() else limit

func release_all() -> void:
	for code: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_CTRL, KEY_SHIFT]:
		key(code, false)

func p() -> CharacterBody3D:
	return game.player

func session() -> Node:
	return game.session

func runs_dir(name: String) -> String:
	return out_dir.path_join("runs").path_join(name)

## a game on the r16 fixture (or opts.level / opts.map on the real registry), recording into
## out/runs/<group> unless opts.record is false.
func make_game(opts: Dictionary = {}) -> Node:
	FIXTURE.params = opts.get("params", {})
	SLOT_FIXTURE.params = opts.get("slot_params", {})
	game = (load(SCENE) as PackedScene).instantiate() if bool(opts.get("scene", false)) else MAIN.new()
	if opts.has("map"):
		game.set("map_id", opts.map)
	else:
		game.set("level_script", opts.get("level", FIXTURE))
	if bool(opts.get("record", true)):
		game.set("recordings_dir", str(opts.get("runs", runs_dir(_group))))
		game.set("record_runs", true)
	if opts.has("motor"):
		game.set("motor", opts.motor)
	root.add_child(game)
	_observer.set("watched", game)
	await ticks(int(opts.get("settle", 16)))
	return game

func _drop_game() -> void:
	release_all()
	if is_instance_valid(game):
		if bool(game.paused):
			game.call("set_paused", false)
		game.queue_free()
		game = null
	paused = false
	await ticks(3)

## the clean line on the fixture: W from the spawn, Space held once the feet pass z -9 (just
## before the lip), held until the finish. closed loop on the feet; the same motion repeats it.
func run_clean(limit: int = 2400) -> void:
	key(KEY_W, true)
	await until(func() -> bool: return p().global_position.z < -9.0, 600)
	key(KEY_SPACE, true)
	await until(func() -> bool: return bool(game.finished), limit)
	key(KEY_SPACE, false)
	key(KEY_W, false)

static func outcome(run: Dictionary) -> Dictionary:
	return ((run.get("seal", {}) as Dictionary).get("outcome", {}) as Dictionary) if run.get("seal") is Dictionary else {}

static func events_of(run: Dictionary, kind: String) -> Array:
	return (run.get("events", []) as Array).filter(func(e: Dictionary) -> bool: return str(e.get("k", "")) == kind)

## input rows of a run at a tick: [[kind, code, pressed]].
static func inputs_at(run: Dictionary, tick: int) -> Array:
	var i: Dictionary = run.get("inputs", {})
	var out: Array = []
	if i.is_empty():
		return out
	for k: int in (i.tick as PackedInt32Array).size():
		if (i.tick as PackedInt32Array)[k] == tick:
			out.append([(i.kind as PackedInt32Array)[k], (i.code as PackedInt64Array)[k], (i.flags as PackedInt32Array)[k] & 1])
	return out

static func has_key(rows: Array, code: int, pressed: int) -> bool:
	return rows.any(func(r: Array) -> bool: return r[0] == 1 and r[1] == code and r[2] == pressed)

func observed_for(run_id: String) -> Array:
	return observed.filter(func(o: Dictionary) -> bool: return o.run_id == run_id)

## every sample of a file equals what the observer saw right after the session took it.
func file_matches_observer(run: Dictionary) -> String:
	var rows := observed_for(str((run.header as Dictionary).get("run_id", "")))
	var c: Dictionary = run.columns
	var n := (c.tick as PackedInt32Array).size()
	if rows.size() != n:
		return "observer saw %d samples, file has %d" % [rows.size(), n]
	for k: int in n:
		if (c.p as PackedVector3Array)[k] != rows[k].p or (c.tick as PackedInt32Array)[k] != k or (c.elapsed as PackedFloat64Array)[k] != rows[k].elapsed:
			return "tick %d differs" % k
	return ""

# --- groups -----------------------------------------------------------------------------------

func _group_isolated() -> void:
	var user := ProjectSettings.globalize_path("user://")
	var before := DirAccess.get_files_at(user)
	await make_game({"record": false})
	check("new() records nothing and keeps no profile", not bool(game.persist) and not bool(game.record_runs) and not bool(session().recorder.enabled) and str(game.profile_state) == "off")
	await run_clean()
	await ticks(10)
	check("a clean finish on a new() game wrote no file in user://", DirAccess.get_files_at(user) == before and not DirAccess.dir_exists_absolute(user.path_join("r16_runs")), [before, DirAccess.get_files_at(user)])
	check("bests stay in memory: time and style best kept", float(game.best_time) > 0.0 and int(game.style_best) >= 0, [game.best_time, game.style_best])
	check("no ghost without a recording", str(session().ghost_state) != "loaded")
	check("headless new() has no window title or startup error", str(game.startup_error).is_empty())

func _group_lifecycle() -> void:
	await make_game()
	var s := session()
	var sealed: Array = s.sealed
	check("the spawn opened attempt 1 with a recording", bool(s.attempt_live) and bool((s.last_begin as Dictionary).get("ok", false)) and str(s.attempt_reason) == "spawn", s.last_begin)
	await ticks(20)
	await run_clean()
	await ticks(2)
	check("the clean line finishes clean", str(game.finish_kind) == "clean" and int(game.respawn_count) == 0, [game.finish_kind, game.respawn_count])
	var sealed_at_finish: int = (s.sealed as Array).size()
	key(KEY_W, true)
	await ticks(60)
	key(KEY_W, false)
	check("untimed play after the finish opens no new file", (s.sealed as Array).size() == sealed_at_finish and not bool(s.attempt_live))
	# R, a short run, R again: the first R is the boundary of nothing (the finish sealed it).
	await tap(KEY_R)
	key(KEY_W, true)
	await ticks(30)
	key(KEY_W, false)
	await tap(KEY_R)
	key(KEY_W, true)
	await until(func() -> bool: return p().global_position.z < -9.0, 600)
	key(KEY_SPACE, true)
	await until(func() -> bool: return int(game.checkpoint_index) >= 1, 600)
	key(KEY_SPACE, false)
	key(KEY_W, false)
	await tap(KEY_F)
	check("F starts checkpoint practice from the landing deck", int(game.practice_stage) == 1 and not bool(game.clean_eligible))
	await run_clean_from_here()
	check("the practice run finishes as practice", str(game.finish_kind) == "practice")
	check("a practice finish shows its style but keeps no style best", not bool((game.finish_style as Dictionary).get("eligible", true)) and not bool(game.style_new_best), game.finish_style)
	await tap(KEY_R)
	# W alone runs into the void: a fall and a respawn inside the attempt, then the clean line.
	key(KEY_W, true)
	await until(func() -> bool: return int(game.respawn_count) > 0, 900)
	key(KEY_W, false)
	await ticks(10)
	check("the fall respawned inside the same attempt", int(game.respawn_count) == 1 and bool(s.attempt_live))
	check("the style service saw the respawn as a discontinuity", ((s.style.snapshot() as Dictionary).diag.discontinuities as Array).has("respawn"), (s.style.snapshot() as Dictionary).diag.discontinuities)
	await run_clean()
	check("a run with a respawn finishes as practice", str(game.finish_kind) == "practice" and str(game.practice_reason) == "respawn")
	await tap(KEY_R)
	key(KEY_W, true)
	await ticks(20)
	key(KEY_W, false)
	var frames_before := observed.size()
	await tap(KEY_ESCAPE)
	await ticks(40)
	check("paused frames take no sample", observed.size() == frames_before and bool(game.paused), [observed.size(), frames_before])
	await tap(KEY_ESCAPE)
	await ticks(20)
	var travel := {"checks": s.actual_v_checks, "mismatches": s.actual_v_mismatches, "worst_m_s": s.actual_v_worst}
	await _drop_game()
	var runs := filesFrom(sealed)
	notes["lifecycle_files"] = runs.map(func(r: Dictionary) -> Array: return [r.sealed_kind, r.status, outcome(r).get("kind")])
	var kinds := runs.map(func(r: Dictionary) -> String: return str(outcome(r).get("kind", "")))
	check("one file per attempt, sealed with its outcome", kinds == ["finish", "restart", "practice", "finish", "finish", "quit"], kinds)
	check("every file reads strictly complete", runs.all(func(r: Dictionary) -> bool: return bool(r.ok) and str(r.status) == "complete"), runs.map(func(r: Dictionary) -> String: return str(r.status)))
	check("every file equals the samples the observer saw", runs.all(func(r: Dictionary) -> bool: return file_matches_observer(r).is_empty()), runs.map(func(r: Dictionary) -> String: return file_matches_observer(r)))
	var first: Dictionary = runs[0]
	var seal: Dictionary = first.seal
	var flags: PackedInt32Array = first.columns.flags
	check("idle ticks before the timer are recorded, then timer_start", int(seal.timer_start_tick) >= 20 and flags[0] & 1 == 0 and events_of(first, "timer_start").size() == 1, [seal.timer_start_tick, flags[0]])
	check("the finish tick is the last tick and the seal is clean", int(seal.finish_tick) == int(seal.last_tick) and bool(outcome(first).clean) and str(outcome(first).finish_kind) == "clean", seal)
	var style_events := (first.events as Array).filter(func(e: Dictionary) -> bool: return str(e.get("s", "")) == "capture")
	var style_sum := 0
	for e: Dictionary in style_events:
		style_sum += int((e.d as Dictionary).get("points", 0))
	check("the void crossing scored a gap before the finish", style_events.any(func(e: Dictionary) -> bool: return str(e.k) == "gap" or str((e.d as Dictionary).get("kind", "")) == "gap") and style_events.all(func(e: Dictionary) -> bool: return int(e.t) < int(seal.finish_tick)), style_events.map(func(e: Dictionary) -> String: return str(e.d.kind)))
	check("the seal's style score is the sum of its events and became the style best", int((outcome(first).style as Dictionary).score) == style_sum and style_sum > 0 and bool((outcome(first).style as Dictionary).best_eligible), [outcome(first).style, style_sum])
	var restart: Dictionary = runs[1]
	var edge: Array = (events_of(restart, "restart")[0].d as Dictionary).edge if not events_of(restart, "restart").is_empty() else []
	check("R's press is the restart event's edge in the old file", edge.size() >= 1 and int((edge[0] as Dictionary).keycode) == KEY_R and bool((edge[0] as Dictionary).pressed), edge)
	var last_tick: int = int((restart.seal as Dictionary).last_tick)
	check("the old file holds no R press as an input row", not has_key(inputs_at(restart, last_tick), KEY_R, 1))
	var practice: Dictionary = runs[2]
	var after_restart: Dictionary = practice
	check("the next attempt's first tick holds no R press", not has_key(inputs_at(after_restart, 0), KEY_R, 1), inputs_at(after_restart, 0))
	check("F's press is the practice event's edge", not events_of(practice, "practice").is_empty() and int(((events_of(practice, "practice")[0].d as Dictionary).edge[0] as Dictionary).keycode) == KEY_F)
	var practice_run: Dictionary = runs[3]
	check("the practice file starts at stage 1 as practice", str((practice_run.header.metadata as Dictionary).start_reason) == "practice" and int(practice_run.header.metadata.practice_stage) == 1 and not bool(practice_run.header.metadata.clean_at_start))
	var fall: Dictionary = runs[4]
	check("the fall is a respawn event inside the attempt file", events_of(fall, "respawn").size() == 1 and events_of(fall, "respawn_count").size() == 1 and int((fall.seal.final as Dictionary).respawns) == 1)
	var paused_run: Dictionary = runs[5]
	var ticks_col: PackedInt32Array = paused_run.columns.tick
	var contiguous := true
	for k: int in ticks_col.size():
		contiguous = contiguous and ticks_col[k] == k
	check("pause and resume are events and the paused frames left no ticks", events_of(paused_run, "pause").size() == 1 and events_of(paused_run, "resume").size() == 1 and contiguous)
	check("leaving the tree sealed the open attempt as quit", str(outcome(paused_run).kind) == "quit" and str(paused_run.status) == "complete")
	check("the host's travel check agreed with the runner on every continuous tick", int(travel.mismatches) == 0 and int(travel.checks) > 1000, travel)
	notes["actual_v"] = travel

## the files a game sealed, read strictly, in order. takes the session's own array, which
## outlives the session, so the quit sealed while the game leaves the tree is included.
func filesFrom(sealed: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in sealed:
		var run := READER.read(str(row.path), true)
		run["sealed_kind"] = row.kind
		out.append(run)
	return out

## from a checkpoint on the landing deck: W to the finish.
func run_clean_from_here() -> void:
	key(KEY_W, true)
	await until(func() -> bool: return bool(game.finished), 2400)
	key(KEY_W, false)

func _group_preset() -> void:
	await make_game()
	var s := session()
	var sealed: Array = s.sealed
	key(KEY_W, true)
	await ticks(40)
	# F5 and Space in one batch: F5 ends the old file, Space reaches the new attempt's first step.
	key(KEY_F5, true)
	key(KEY_SPACE, true)
	await physics_frame
	key(KEY_F5, false)
	await ticks(30)
	key(KEY_SPACE, false)
	check("F5 switched mid-run and made it practice", str(game.preset_id) == "server128_aa1000" and str(game.practice_reason) == "preset")
	# Space then F2 in one batch: Space was delivered before the edge, the body continues, so it
	# is carried into the new file.
	key(KEY_SPACE, true)
	key(KEY_F2, true)
	await physics_frame
	key(KEY_F2, false)
	key(KEY_SPACE, false)
	await ticks(20)
	key(KEY_W, false)
	await tap(KEY_R)
	await tap(KEY_F5)
	check("F5 on an untouched spawn keeps the attempt clean", bool(game.clean_eligible) and str(game.preset_id) == "server128_aa1000")
	await _drop_game()
	var runs := filesFrom(sealed)
	var kinds := runs.map(func(r: Dictionary) -> String: return str(outcome(r).get("kind", "")))
	check("a preset switch ends the file and the attempt continues in a new one", kinds == ["preset", "preset", "restart", "preset", "quit"], kinds)
	var presets := runs.map(func(r: Dictionary) -> String: return str((r.header.metadata as Dictionary).preset))
	check("each file is labelled with the preset its ticks ran", presets == ["server128", "server128_aa1000", "server128", "server128", "server128_aa1000"], presets)
	var mislabelled := []
	for r: Dictionary in runs:
		var want := str((r.header.metadata as Dictionary).preset)
		for o: Dictionary in observed_for(str(r.header.run_id)):
			if str(o.preset) != want:
				mislabelled.append([r.header.run_id, o.tick, o.preset])
	check("no sample was taken under another preset than its file's", mislabelled.is_empty(), mislabelled.slice(0, 4))
	var first: Dictionary = runs[0]
	var edge: Array = (events_of(first, "preset")[0].d as Dictionary).edge
	check("the F5 press is the old file's boundary edge", int((edge[0] as Dictionary).keycode) == KEY_F5 and bool((edge[0] as Dictionary).pressed), edge)
	var second: Dictionary = runs[1]
	check("the Space pressed with F5 is in the new file's first tick", has_key(inputs_at(second, 0), KEY_SPACE, 1) and not has_key(inputs_at(first, int(first.seal.last_tick)), KEY_SPACE, 1), [inputs_at(second, 0), inputs_at(first, int(first.seal.last_tick))])
	var hops := events_of(second, "motion").filter(func(e: Dictionary) -> bool: return int(e.t) <= 1 and str(e.d).contains("jump"))
	check("the immediate post-switch hop is recorded under the new preset", not hops.is_empty(), events_of(second, "motion").slice(0, 3))
	check("the new file starts as practice mid-run", str(second.header.metadata.start_reason) == "preset" and not bool(second.header.metadata.clean_at_start) and bool(second.header.metadata.timer_running_at_start))
	var carried := events_of(second, "preset")
	check("Space before the F2 edge was carried to the next file", not carried.is_empty() and int((carried[0].d as Dictionary).inputs_carried) >= 1 and has_key(inputs_at(runs[2], 0), KEY_SPACE, 1), [carried, inputs_at(runs[2], 0)])
	check("the untouched F5 file starts clean", bool(runs[4].header.metadata.clean_at_start))

func _group_pending() -> void:
	# the r13 capsule fits the 0.7 m slot, the source box does not: F2 waits for room.
	await make_game({"level": SLOT_FIXTURE, "slot_params": {"spawn": "slot"}, "motor": "r13_original120"})
	var s := session()
	var sealed: Array = s.sealed
	check("starts on the advanced r13 preset in the slot", str(game.preset_id) == "r13_original120")
	await tap(KEY_F2)
	await ticks(5)
	check("F2 waits for room in the slot", str(game.preset_id) == "r13_original120" and str(game.pending_preset) == "server128")
	# S backs out of the slot. Space goes down on the frame the game's own room test (a read-only
	# query) first passes for the feet, so in that frame's callback the switch is applied before
	# any motor sees Space: the hop is the new body's first.
	key(KEY_S, true)
	await until(func() -> bool: return bool(game.call("hull_fits", PRESETS.entry("server128"), p().global_position)), 600)
	key(KEY_SPACE, true)
	await until(func() -> bool: return str(game.preset_id) == "server128", 10)
	await ticks(60)
	key(KEY_S, false)
	key(KEY_SPACE, false)
	await _drop_game()
	var runs := filesFrom(sealed)
	var kinds := runs.map(func(r: Dictionary) -> String: return str(outcome(r).get("kind", "")))
	check("the switch inside the physics callback ended the r13 file", kinds.size() == 2 and kinds[0] == "preset", kinds)
	var wrong := []
	for r: Dictionary in runs:
		var runner := str((r.header.metadata.physics as Dictionary).runner)
		for o: Dictionary in observed_for(str(r.header.run_id)):
			if str(o.script) != runner:
				wrong.append([str(r.header.metadata.preset), o.tick, o.script])
	check("every sample's body is its file's runner (no old motor step in the new file)", wrong.is_empty(), wrong.slice(0, 4))
	check("the r13 file holds the waiting event", events_of(runs[0], "preset_waiting").size() == 1)
	if runs.size() < 2:
		return
	var hops := (runs[1].events as Array).filter(func(e: Dictionary) -> bool: return str(e.k) == "motion" and str(e.d).contains("jump"))
	check("Space pressed on the switch frame hops on the new body's first step, in the new file", not hops.is_empty() and int(hops[0].t) <= 1, hops.slice(0, 2))
	var old_air := (runs[0].events as Array).filter(func(e: Dictionary) -> bool: return str(e.k) == "context" and str((e.d as Dictionary).get("mode", "")) == "air" and int(e.t) > 0)
	check("the r13 body never left the ground in its file after settling", old_air.is_empty(), old_air)
	check("the old file's boundary carries no edge (the switch came from the callback)", ((events_of(runs[0], "preset")[0].d as Dictionary).edge as Array).is_empty())

func _group_ghost() -> void:
	await make_game()
	var s := session()
	# every run starts the same way (R, then 16 ticks at the spawn), so equal inputs give equal runs.
	await tap(KEY_R)
	await ticks(16)
	await run_clean()
	await ticks(2)
	check("the first clean finish became the ghost", str(s.ghost_state) == "loaded" and bool(game.ghost_new) and int(game.ghost_pointer.ticks) == int(game.call("_record_ticks", float(game.elapsed))), [s.ghost_state, game.ghost_pointer])
	var first_ghost := str(s.ghost_path)
	var traces: Array = []
	for variant: String in ["shown", "hidden", "none"]:
		if variant == "hidden":
			await tap(KEY_G)
		if variant == "none":
			s.ghost.call("clear")
		await tap(KEY_R)
		await ticks(16)
		var from := observed.size()
		await run_clean()
		await ticks(2)
		traces.append(observed.slice(from))
	check("G hid the ghost; the setting says so", not bool(game.settings.ghost))
	var differ := []
	for k: int in mini((traces[0] as Array).size(), mini((traces[1] as Array).size(), (traces[2] as Array).size())):
		for field: String in ["p", "v", "yaw", "elapsed", "checkpoint"]:
			if traces[0][k][field] != traces[1][k][field] or traces[0][k][field] != traces[2][k][field]:
				differ.append([k, field])
	check("motion with the ghost shown, hidden or absent is equal tick for tick", differ.is_empty() and (traces[0] as Array).size() == (traces[1] as Array).size() and (traces[0] as Array).size() == (traces[2] as Array).size(), [differ.slice(0, 3), (traces[0] as Array).size(), (traces[1] as Array).size()])
	var misaligned := (traces[0] as Array).filter(func(o: Dictionary) -> bool: return o.ghost_feet != null and float(o.elapsed) > 0.0 and o.ghost_feet != o.p)
	check("the ghost of an equal run stands on the live feet at every timed sample", misaligned.is_empty() and (traces[0] as Array).any(func(o: Dictionary) -> bool: return float(o.elapsed) > 1.0), misaligned.slice(0, 2))
	check("the overlapping ghost fades out at the eye", (traces[0] as Array).filter(func(o: Dictionary) -> bool: return float(o.elapsed) > 1.0).all(func(o: Dictionary) -> bool: return float(o.ghost_fade) < 0.01))
	check("an equal time does not replace the ghost", str(s.ghost_path) != "" and not bool(game.ghost_new))
	await tap(KEY_G)
	await tap(KEY_R)
	await tap(KEY_F5)
	check("another preset has no ghost from F2's runs", str(s.ghost_state) != "loaded" and not bool(s.ghost.get("loaded")), s.ghost_state)
	await tap(KEY_F2)
	check("back on F2 the ghost loads again from the cache", str(s.ghost_state) == "loaded" and str(s.ghost_path) == first_ghost, [s.ghost_state, s.ghost_path, first_ghost])
	var motion: Dictionary = game.call("motion_identity")
	check("the motion identity holds no style rule", not JSON.stringify(motion).contains(STYLE.STYLE_VERSION) and not str(game.call("record_identity_text")).contains(STYLE.STYLE_VERSION), motion)
	var header: Dictionary = READER.read(first_ghost, false).header
	check("the recording keeps the style rules beside, not inside, the identity", str((header.metadata.scoring as Dictionary).style_key) == STYLE.identity_key() and READER.identity_matches(header.identity, motion).is_empty())

func _group_lab() -> void:
	await make_game({"map": "experiment", "settle": 24})
	var s := session()
	var sealed: Array = s.sealed
	check("the lab plays the r16 lab runner through the r16 main", (p().get_script() as Script).resource_path == "res://scripts/r16_experiment_player.gd", (p().get_script() as Script).resource_path)
	check("its motor identity names the lab movement version", str(game.call("family_version")).ends_with("+r16-lab-moves-1"), game.call("family_version"))
	check("its laws are labelled experimental", str((game.call("law_labels") as Dictionary).course_law) == "experimental")
	var key_before := str(game.course_key)
	key(KEY_W, true)
	await ticks(60)
	await tap(KEY_2)
	key(KEY_W, false)
	check("key 2 mid-run turned the wall jump off as practice with a new key", not bool((game.call("lab_moves") as Dictionary).wall_jump) and str(game.practice_reason) == "mechanics" and str(game.course_key) != key_before)
	await tap(KEY_2)
	await tap(KEY_R)
	# bhop into a landing slide: W to speed, one hop, Shift pressed and held on the way down.
	key(KEY_W, true)
	await ticks(90)
	key(KEY_SPACE, true)
	await until(func() -> bool: return not bool(p().call("is_grounded")), 40)
	key(KEY_SPACE, false)
	await until(func() -> bool: return p().velocity.y < 0.0, 120)
	key(KEY_SHIFT, true)
	var slid := await until(func() -> bool: return str(p().get("slide_kind")) == "landing", 200)
	await ticks(20)
	key(KEY_SPACE, true)
	var hopped := await until(func() -> bool: return not bool(p().call("is_grounded")), 40)
	key(KEY_SPACE, false)
	key(KEY_SHIFT, false)
	key(KEY_W, false)
	check("a bhop landing with Shift held slid, then Space hopped out (through the r16 main)", slid >= 0 and hopped >= 0, [slid, hopped, p().get("slide_kind")])
	await _drop_game()
	var runs := filesFrom(sealed)
	var kinds := runs.map(func(r: Dictionary) -> String: return str(outcome(r).get("kind", "")))
	check("the loadout change ended the file and a new one continued", kinds.size() >= 3 and kinds[0] == "loadout", kinds)
	var landing := (runs[runs.size() - 1].events as Array).filter(func(e: Dictionary) -> bool: return str(e.k) == "motion" and str(e.d).contains("slide_landing"))
	check("the recording holds the landing slide event", not landing.is_empty())

func _group_hud() -> void:
	await make_game()
	var hud: Node = game.hud
	await tap(KEY_ESCAPE)
	await process_frame
	check("the menu is R16's", str((hud.pause_panel.find_child("PauseHeading", true, false) as Label).text).begins_with("SPILLWAY R16"))
	check("the menu says where attempts are recorded", str(hud.recording_line.text).contains(ProjectSettings.globalize_path(runs_dir("hud"))), hud.recording_line.text)
	check("the menu shows the style best line", str(hud.pause_records.text).contains("style best"), hud.pause_records.text)
	check("checkpoint practice reads recorded, never a best", hud.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == "Checkpoint practice  (recorded, never a best)"))
	var shown := bool(game.settings.ghost)
	await click_visible(hud.ghost_switch)
	check("clicking the ghost switch in the menu toggles the ghost", bool(game.settings.ghost) != shown)
	await click_visible(hud.ghost_switch)
	await click_visible(hud.resume_button)
	check("resume closes the menu", not bool(game.paused))
	await run_clean()
	await process_frame
	check("the finish panel shows the style line", str(hud.finish_body.text).contains("Style ") and str(hud.finish_body.text).contains("new style best"), hud.finish_body.text)
	check("the style panel is drawn", hud.style_panel != null and (hud.style_panel as Control).is_visible_in_tree())
	await tap(KEY_F)
	await process_frame
	check("practice reads no best", str(hud.practice_tag.text).contains("no best") and str(hud.best_line.text) == "practice · no best", [hud.practice_tag.text, hud.best_line.text])
	check("the window title is R16's", str(root.get_window().title).begins_with("Spillway R16"), root.get_window().title)

# --- persistence across processes -------------------------------------------------------------

## the optional style passages: added once to Breakwater and Whiteout after the build, named in
## every identity beside the frozen base geometry hash, absent with an explicit "none" elsewhere.
func _group_overlay() -> void:
	await make_game()
	check("the fixture gets no passages and says so", str(game.overlay_id) == "r16-opportunities-1:none (non_target_map)" and not game.level.has_node("R16Opportunities"), game.overlay_id)
	await _drop_game()
	await make_game({"map": "breakwater", "settle": 40})
	var keys := {}
	for id: String in ["breakwater", "whiteout-relay", "sunken-court"]:
		if id != "breakwater":
			game.call("select_map", id)
			await ticks(40)
		var level: Node3D = game.level
		var bare: Node3D = MAPS.instantiate(MAPS.make(), id)
		root.add_child(bare)
		bare.call("build")
		var base := str(bare.call("geometry_hash"))
		bare.free()
		var want := ("r16-opportunities-1:" + str(OVERLAY_HASHES[id])) if OVERLAY_HASHES.has(id) else "r16-opportunities-1:none (non_target_map)"
		check("%s: the overlay id names the accepted passages (or none)" % id, str(game.overlay_id) == want, [game.overlay_id, want])
		check("%s: the passages were added once, only where they belong" % id, level.has_node("R16Opportunities") == OVERLAY_HASHES.has(id) and level.find_children("R16Opportunities", "", false, false).size() <= 1)
		check("%s: the base geometry hash is the bare map's" % id, str(game.course_geometry) == base and str(level.call("geometry_hash")) == base, [game.course_geometry, base])
		var identity: Dictionary = game.call("motion_identity")
		check("%s: the ghost identity holds base geometry and overlay side by side" % id, str(identity.geometry) == base and str(identity.overlay) == want, identity)
		check("%s: the record identity holds both" % id, (game.call("record_identity") as Array).has(base) and (game.call("record_identity") as Array).has(want))
		keys[id] = str(game.course_key)
		await tap(KEY_R)
		await ticks(4)
		var runs := filesFrom(session().sealed)
		var meta: Dictionary = (runs[-1].header.metadata as Dictionary) if not runs.is_empty() else {}
		var report: Dictionary = meta.get("opportunities", {})
		check("%s: the recording header carries the overlay report beside the base hash" % id, str(meta.get("overlay", "")) == want and str(report.get("base_geometry", "")) == base and str(report.get("hash", "")) == str(OVERLAY_HASHES.get(id, "")) and bool(report.get("applied", false)) == OVERLAY_HASHES.has(id), report)
	check("each map keeps its own record key", keys.values().size() == 3 and keys.values().all(func(k: String) -> bool: return keys.values().count(k) == 1), keys)

func _user_dir(xdg: String) -> String:
	return xdg.path_join("data/godot/app_userdata").path_join(str(ProjectSettings.get_setting("application/config/name")))

func _run_child(base: String, step: String, extra: Array = []) -> Dictionary:
	var args := PackedStringArray(["XDG_DATA_HOME=" + base.path_join("data"), "XDG_CONFIG_HOME=" + base.path_join("config"), "XDG_CACHE_HOME=" + base.path_join("cache"),
		OS.get_executable_path(), "--headless", "--audio-driver", "Dummy", "--fixed-fps", "128", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/test_r16_loop.gd", "--",
		"--phase=" + step, "--out=" + out_dir.path_join("phase-" + step), "--r16-profile=user://spillway_r16.cfg"])
	if not "--no-run-recordings" in extra:
		args.append("--r16-recordings=user://r16_runs/")
	args.append_array(extra)
	var output: Array = []
	var code := OS.execute("env", args, output, true)
	var log := FileAccess.open(out_dir.path_join("phase-%s.log" % step), FileAccess.WRITE)
	log.store_string("\n".join(output))
	log.close()
	var path := out_dir.path_join("phase-" + step).path_join("report.json")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	report["exit"] = code
	report["engine_errors"] = Array("\n".join(output).split("\n")).filter(func(l: String) -> bool: return l.contains("ERROR"))
	return report

static func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

func _runs(user: String) -> PackedStringArray:
	return DirAccess.get_files_at(user.path_join("r16_runs")) if DirAccess.dir_exists_absolute(user.path_join("r16_runs")) else PackedStringArray()

func _group_persist() -> void:
	var base := out_dir.path_join("profiles")
	var user := _user_dir(base)
	DirAccess.make_dir_recursive_absolute(user)
	var r15 := user.path_join("spillway_r15.cfg")
	var r16 := user.path_join("spillway_r16.cfg")
	var r15_text := "[profile]\n\nformat=1\nbuild=\"spillway-2026.11.08-r15\"\n\n[settings]\n\nsource_sensitivity=3.7\nsource_fov=100.0\nvolume=0.4\nshow_ms=false\n\n[course_0123456789abcdef]\n\nclean_best_ticks=1000\nclean_best=7.8125\n"
	var file := FileAccess.open(r15, FileAccess.WRITE)
	file.store_string(r15_text)
	file.close()
	var r15_hash := _hash(r15)
	var first := _run_child(base, "first")
	check("first: exits 0 with no engine error", first.exit == 0 and (first.engine_errors as Array).is_empty(), [first.exit, first.engine_errors])
	check("first: the first launch read r15's look settings, no record", bool(first.get("seeded", false)) and is_equal_approx(float(first.get("source_sensitivity", 0)), 3.7) and float(first.get("best_on_start", 0)) < 0.0, first)
	check("first: a clean finish kept time, style best and ghost", str(first.get("finish_kind")) == "clean" and bool(first.get("saved", false)) and int(first.get("style_best", -1)) > 0 and str(first.get("ghost_state")) == "loaded", first)
	check("first: the r15 profile is byte-for-byte unchanged and no r14 file appeared", _hash(r15) == r15_hash and not FileAccess.file_exists(user.path_join("spillway_r14.cfg")))
	var config := ConfigFile.new()
	config.load(r16)
	var sections := Array(config.get_sections())
	var course: Array = sections.filter(func(n: String) -> bool: return n.begins_with("course_"))
	var styled: Array = sections.filter(func(n: String) -> bool: return n.begins_with("style_"))
	var ghosted: Array = sections.filter(func(n: String) -> bool: return n.begins_with("ghost_"))
	check("first: one time, one style and one ghost section", course.size() == 1 and styled.size() == 1 and ghosted.size() == 1, sections)
	if course.size() != 1 or styled.size() != 1 or ghosted.size() != 1:
		return
	var stored := {"clean": config.get_value(course[0], "clean_best_ticks"), "score": config.get_value(styled[0], "score"), "ghost_ticks": config.get_value(ghosted[0], "time_ticks"), "ghost": config.get_value(ghosted[0], "path")}
	check("first: time, style score and ghost time are stored as integers", typeof(stored.clean) == TYPE_INT and typeof(stored.score) == TYPE_INT and typeof(stored.ghost_ticks) == TYPE_INT and stored.clean == stored.ghost_ticks and stored.clean == int(first.best_ticks) and stored.score == int(first.style_best), stored)
	check("first: the ghost pointer names the sealed finish file", FileAccess.file_exists(str(stored.ghost)) and str(stored.ghost).ends_with(".r16run") and str(stored.ghost).get_file() in Array(_runs(user)), [stored.ghost, _runs(user)])
	check("first: no temporary profile is left", not FileAccess.file_exists(r16 + ".tmp"))
	var reload := _run_child(base, "reload")
	check("reload: a fresh process loads time, style best and ghost exactly", reload.exit == 0 and str(reload.get("record_state")) == "loaded" and int(reload.get("best_ticks", -2)) == stored.clean
		and int(reload.get("style_best", -2)) == stored.score and str(reload.get("style_state")) == "loaded" and str(reload.get("ghost_state")) == "loaded" and int(reload.get("ghost_ticks", -2)) == stored.ghost_ticks
		and str(reload.get("ghost_path")) == str(stored.ghost), reload)
	check("reload: r16's own settings win; nothing is seeded again", not bool(reload.get("seeded", true)))
	var before := _hash(r16)
	var practice := _run_child(base, "practice")
	check("practice: a practice finish keeps nothing and saves nothing", practice.exit == 0 and str(practice.get("finish_kind")) == "practice" and _hash(r16) == before and int(practice.get("style_best", -2)) == stored.score, [practice.get("finish_kind"), _hash(r16) == before])
	var files_before := _runs(user).size()
	var norecords := _run_child(base, "norecords", ["--no-records"])
	check("--no-records: the profile is untouched, the attempt is still recorded", norecords.exit == 0 and str(norecords.get("profile_state")) == "off" and _hash(r16) == before and _runs(user).size() > files_before, [norecords.get("profile_state"), _runs(user).size(), files_before])
	files_before = _runs(user).size()
	var noruns := _run_child(base, "noruns", ["--no-run-recordings"])
	check("--no-run-recordings: no file is written, records still are", noruns.exit == 0 and _runs(user).size() == files_before and not bool(noruns.get("recording", true)) and bool(noruns.get("saved", false)), [_runs(user).size(), files_before, noruns])
	# the whole folder is copied away (as Mike copies it off his desktop): the pointer names a
	# missing file, play continues, and the next clean run becomes the ghost.
	DirAccess.rename_absolute(user.path_join("r16_runs"), user.path_join("r16_runs_copied"))
	notes["copied_folder"] = user.path_join("r16_runs_copied")
	var moved := _run_child(base, "moved")
	check("moved: a missing ghost file is said, not a crash", moved.exit == 0 and str(moved.get("ghost_state_on_start", "")).begins_with("stored run missing") and (moved.engine_errors as Array).is_empty(), [moved.get("ghost_state_on_start"), moved.engine_errors])
	check("moved: the next clean run becomes the ghost", str(moved.get("ghost_state")) == "loaded" and str(moved.get("ghost_path")) != str(stored.ghost) and FileAccess.file_exists(str(moved.get("ghost_path"))), moved)
	config = ConfigFile.new()
	config.load(r16)
	check("moved: the saved pointer now names the new file", str(config.get_value(ghosted[0], "path", "")) == str(moved.get("ghost_path")), config.get_value(ghosted[0], "path", ""))
	# a damaged ghost file: truncated in place.
	var damaged := str(moved.get("ghost_path", ""))
	var bytes := FileAccess.get_file_as_bytes(damaged)
	var handle := FileAccess.open(damaged, FileAccess.WRITE)
	handle.store_buffer(bytes.slice(0, bytes.size() - 40))
	handle.close()
	var corrupt := _run_child(base, "corrupt")
	check("corrupt: a truncated ghost file is refused by name, not a crash", corrupt.exit == 0 and str(corrupt.get("ghost_state_on_start", "")).begins_with("stored run refused"), corrupt.get("ghost_state_on_start"))
	var quit := _run_child(base, "quit")
	check("quit: the menu Quit ends the process with exit 0 and seals the attempt", quit.exit == 0 and bool(quit.get("clicked", false)) and not bool(quit.get("survived", false)), quit)
	var newest := ""
	var newest_time := 0
	for name: String in _runs(user):
		var at := FileAccess.get_modified_time(user.path_join("r16_runs").path_join(name))
		if at >= newest_time:
			newest_time = at
			newest = name
	var last := READER.read(user.path_join("r16_runs").path_join(newest), false)
	check("quit: the last file is a complete quit recording", str(last.status) == "complete" and str(outcome(last).get("kind", "")) == "quit", [newest, last.status, outcome(last)])
	check("no .part file is left by any process", Array(_runs(user)).all(func(n: String) -> bool: return not n.ends_with(".part")), _runs(user))
	check("the r15 profile ended byte-for-byte unchanged", _hash(r15) == r15_hash)
	notes["persist_runs"] = Array(_runs(user))
	notes["persist_user_dir"] = user

## the child side: the real scene with persistence and recording on, on the fixture.
func _child_phase() -> void:
	var report := {"phase": phase, "user_dir": ProjectSettings.globalize_path("user://")}
	var write := func() -> void:
		DirAccess.make_dir_recursive_absolute(out_dir)
		var f := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(READER.json_safe(report), "  "))
		f.close()
	FIXTURE.params = {}
	game = (load(SCENE) as PackedScene).instantiate()
	game.set("level_script", FIXTURE)
	root.add_child(game)
	await ticks(16)
	report["profile_state"] = game.profile_state
	report["seeded"] = game.seeded_settings
	report["best_on_start"] = game.best_time
	report["record_state"] = game.record_state
	report["style_state"] = game.style_state
	report["recording"] = bool(game.session.recorder.enabled)
	report["ghost_state_on_start"] = str(game.session.ghost_state)
	report["source_sensitivity"] = game.settings.source_sensitivity
	report["best_ticks"] = game.call("_record_ticks", float(game.best_time))
	report["style_best"] = game.style_best
	report["ghost_state"] = str(game.session.ghost_state)
	report["ghost_ticks"] = int(game.session.ghost_ticks)
	report["ghost_path"] = str(game.session.ghost_path)
	match phase:
		"first", "moved", "norecords", "noruns":
			await run_clean()
			await ticks(3)
		"practice":
			key(KEY_W, true)
			await until(func() -> bool: return p().global_position.z < -9.0, 600)
			key(KEY_SPACE, true)
			await until(func() -> bool: return int(game.checkpoint_index) >= 1, 600)
			key(KEY_SPACE, false)
			key(KEY_W, false)
			await tap(KEY_F)
			await run_clean_from_here()
			await ticks(3)
		"quit":
			write.call()
			await tap(KEY_ESCAPE)
			report["clicked"] = true
			write.call()
			await click_visible(game.hud.quit_button)
			await ticks(120)
			report["survived"] = true
			write.call()
			quit(5)
			return
	if phase != "reload" and phase != "corrupt":
		report["finish_kind"] = game.finish_kind
		report["saved"] = game.last_save_ok
		report["best_ticks"] = game.call("_record_ticks", float(game.best_time))
		report["style_best"] = game.style_best
		report["ghost_state"] = str(game.session.ghost_state)
		report["ghost_ticks"] = int(game.session.ghost_ticks)
		report["ghost_path"] = str(game.session.ghost_path)
		report["last_seal"] = game.session.last_seal
	write.call()
	game.call("request_quit")
	await ticks(30)

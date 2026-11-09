extends SceneTree
## p / r16 recordings: recorder, reader and ghost. groups:
## - format: labelled synthetic samples (not gameplay) covering every column, input kind, event
##   source, a deliberate tick gap and a missing field, written over several chunks and read back
##   exactly; writes expected.json beside the file for the python cross-reader.
## - states: abort, a crashed .part copy, refusals (double begin, disabled, idle finish, header bound).
## - disk: a write failure through the labelled byte-limit hook and an unwritable directory. the
##   real OS write failure is test_r16_record_format.py running --phase=rlimit under RLIMIT_FSIZE.
## - host: the real, unchanged R15 host on the loop fixture, driven only by key and mouse events
##   through Input: a clean finish, a restart, a fall and practice, a practice finish and a quit,
##   each sealed by the labelled adapter (tests/r16_record_adapter.gd), then the ghost: the clean
##   run's inputs replayed with and without a ghost, which must agree exactly, and refusals.
## - breakwater: the real default map and preset, strafing hops, air crouch and a restart.
## godot --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/test_r16_record.gd -- --out=DIR [--only=a,b] [--phase=rlimit]

const RECORDER := preload("res://scripts/r16_run_recorder.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
const GHOST := preload("res://scripts/r16_ghost.gd")
const ADAPTER := preload("res://tests/r16_record_adapter.gd")
const MAIN := preload("res://scripts/r15_main.gd")
const FIXTURE := preload("res://tests/r15_loop_fixture_level.gd")
const GROUPS := ["format", "states", "disk", "host", "breakwater"]
const U := 0.0254

var out_dir := ""
var only: Array = []
var phase := ""
var results: Array[Dictionary] = []
var notes := {}
var _group := ""
var game: Node
var adapter: Node

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = Array(arg.trim_prefix("--only=").split(","))
		elif arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	if out_dir.is_empty():
		printerr("usage: --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_main.call_deferred()

func _main() -> void:
	if phase == "rlimit":
		_phase_rlimit()
		return
	var started := Time.get_ticks_msec()
	for group: String in GROUPS:
		if only.is_empty() or group in only:
			_group = group
			print("group: ", group)
			await call("_group_" + group)
			await _drop_game()
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	var summary := {"checks": results.size(), "failed": failed.size(), "results": results, "notes": notes,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0, "engine": Engine.get_version_info()}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(READER.json_safe(summary), "  "))
	file.close()
	for r: Dictionary in failed:
		printerr("FAIL %s / %s: %s" % [r.group, r.name, r.detail])
	print("r16 record: %d checks, %d failed" % [results.size(), failed.size()])
	quit(1 if failed.size() > 0 else 0)

func check(name: String, ok: bool, detail: Variant = "") -> bool:
	results.append({"group": _group, "name": name, "ok": ok, "detail": str(detail).left(900)})
	if not ok:
		printerr("  fail: %s (%s)" % [name, str(detail).left(400)])
	return ok

# --- synthetic samples (labelled, not gameplay) -----------------------------------------------

static func f32(x: float) -> float:
	return PackedFloat32Array([x])[0]

func synthetic(i: int) -> Dictionary:
	var p := Vector3(0.1 + i * 0.0123, sin(i * 0.1) * 3.0, -i * 0.37)
	var held := {"move_forward": i % 3 == 0, "jump": i % 5 < 2}
	if i >= 300:
		held["crouch"] = i % 7 == 0
	var sample := {
		"tick": i if i < 400 else i + 3, "dt": 1.0 / 128.0, "physics_hz": 128, "elapsed": maxf(0.0, (i - 10) / 128.0),
		"started": i >= 10, "finished": i >= 690, "clean": i < 500, "practice_reason": "" if i < 500 else "respawn",
		"checkpoint": i / 200, "respawns": 0 if i < 500 else 1,
		"p": p, "reference_p": p + Vector3(0, 0.001 * (i % 2), 0), "v": Vector3(i * 0.5, -0.0, 1e-30 * i), "actual_v": Vector3(-i * 0.25, 7.125, 3.0e38),
		"yaw": 1.0 / 3.0 + i * 1e-9, "pitch": -0.123456789012345 * (i % 4), "grounded": i % 2 == 0, "ducked": i % 11 == 0,
		"motion": {"mode": "air" if i % 40 < 20 else "ground", "events": ["jump"] if i % 40 == 0 else [], "motor_version": "fixture"},
		"stats": {"hops": i / 50, "last_hop": {"gain": float(i), "sync": 0.5}},
		"held": held, "input_events": synthetic_inputs(i),
	}
	if i == 650:
		sample.erase("pitch")
	return sample

func synthetic_inputs(i: int) -> Array:
	var out: Array = []
	if i % 9 == 0:
		var key := InputEventKey.new()
		key.keycode = KEY_W
		key.physical_keycode = KEY_W
		key.pressed = i % 18 == 0
		out.append(key)
	if i % 4 == 1:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(i * 0.75, -1.5)
		motion.screen_relative = Vector2(i * 1.5, -3.0)
		out.append(motion)
		out.append({"type": "mouse_motion", "relative": [0.25, 0.5], "screen_relative": Vector2(1.0, 2.0)})
	if i == 33:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_WHEEL_DOWN
		button.pressed = true
		button.factor = 1.25
		out.append(button)
		var action := InputEventAction.new()
		action.action = &"jump"
		action.pressed = true
		out.append(action)
		var joy := InputEventJoypadButton.new()
		joy.button_index = JOY_BUTTON_A
		joy.pressed = true
		out.append(joy)
		var axis := InputEventJoypadMotion.new()
		axis.axis = JOY_AXIS_LEFT_X
		axis.axis_value = -0.75
		out.append(axis)
		out.append({"type": "key", "keycode": KEY_SPACE, "physical_keycode": KEY_SPACE, "pressed": true, "echo": true})
		out.append({"type": "action", "action": "crouch", "pressed": false})
		out.append(InputEventMagnifyGesture.new())
	return out

## one expected input row as the format stores it, built from the event independently of the recorder.
static func input_row(tick: int, e: Variant) -> Array:
	if e is InputEventKey:
		return [tick, 1, int(e.pressed) | int(e.echo) << 1, e.keycode, e.physical_keycode, 0.0, 0.0, 0.0, 0.0]
	if e is InputEventMouseButton:
		return [tick, 2, int(e.pressed) | int(e.double_click) << 2, e.button_index, 0, f32(e.factor), 0.0, 0.0, 0.0]
	if e is InputEventMouseMotion:
		return [tick, 3, 0, 0, 0, e.screen_relative.x, e.screen_relative.y, e.relative.x, e.relative.y]
	if e is InputEventAction:
		return [tick, 4, int(e.pressed), 0, 0, 0.0, 0.0, 0.0, 0.0]
	if e is InputEventJoypadButton:
		return [tick, 5, int(e.pressed), e.button_index, e.device, 0.0, 0.0, 0.0, 0.0]
	if e is InputEventJoypadMotion:
		return [tick, 6, 0, e.axis, e.device, f32(e.axis_value), 0.0, 0.0, 0.0]
	if e is Dictionary:
		match str(e.type):
			"mouse_motion":
				return [tick, 3, 0, 0, 0, f32(e.screen_relative.x), f32(e.screen_relative.y), f32(e.relative[0]), f32(e.relative[1])]
			"key":
				return [tick, 1, int(e.pressed) | int(e.echo) << 1, e.keycode, e.physical_keycode, 0.0, 0.0, 0.0, 0.0]
			"action":
				return [tick, 4, int(e.pressed), 1, 0, 0.0, 0.0, 0.0, 0.0]
	return [tick, 7, 0, 0, 0, 0.0, 0.0, 0.0, 0.0]

func _group_format() -> void:
	var dir := out_dir.path_join("format")
	var rec := RECORDER.new()
	var meta := {"map": "Synthetic Fixture!", "preset": "server128", "identity": {"map": "synthetic", "preset": "server128", "geometry": "g1", "mechanics": "m1"},
		"note": "labelled synthetic samples, not gameplay", "vector": Vector3(1, 2, 3), "nan": NAN, "object": RefCounted.new()}
	var opened := rec.begin_run(meta, dir)
	check("begin_run opens a .part file", bool(opened.ok) and str(opened.path).ends_with(".r16run.part") and FileAccess.file_exists(str(opened.path)), opened)
	check("run id names the map and preset safely", str(opened.run_id).begins_with("synthetic-fixture-_server128_"), opened.run_id)
	var expected := {"tick": [], "flags": [], "dt": [], "elapsed": [], "physics_hz": [], "checkpoint": [], "respawns": [], "yaw": [], "pitch": [], "held": [],
		"p": [], "reference_p": [], "v": [], "actual_v": []}
	var inputs: Array = []
	var names: Array[String] = []
	for i: int in 700:
		var s := synthetic(i)
		var style: Array = [{"kind": "edge", "points": 50, "at": Vector3(i, 0, 0)}] if i % 100 == 7 else []
		rec.capture(s, style)
		if i == 120:
			rec.event("pause", {"why": "synthetic"})
			rec.event("resume")
		expected.tick.append(int(s.tick))
		var flags := 0
		for bit: int in READER.FLAG_KEYS.size():
			if bool(s.get(READER.FLAG_KEYS[bit], false)):
				flags |= 1 << bit
		expected.flags.append(flags)
		expected.dt.append(s.dt)
		expected.elapsed.append(s.elapsed)
		expected.physics_hz.append(s.physics_hz)
		expected.checkpoint.append(s.checkpoint)
		expected.respawns.append(s.respawns)
		expected.yaw.append(s.yaw)
		expected.pitch.append(float(s.get("pitch", 0.0)))
		var fresh: Array[String] = []
		for key: String in s.held:
			if not key in names:
				fresh.append(key)
		fresh.sort()
		names.append_array(fresh)
		var mask := 0
		for key: String in s.held:
			if bool(s.held[key]):
				mask |= 1 << names.find(key)
		expected.held.append(mask)
		for g: String in ["p", "reference_p", "v", "actual_v"]:
			expected[g].append(s[g])
		for e: Variant in s.input_events:
			inputs.append(input_row(int(s.tick), e))
	var done := rec.finish({"kind": "finish", "clean": false, "note": "synthetic"})
	check("finish seals and renames to .r16run", bool(done.ok) and str(done.path).ends_with(".r16run") and not FileAccess.file_exists(str(done.path) + ".part") and str(rec.status) == "complete", done)
	check("several chunks were written", int(done.counts.chunks) >= 4, done.counts)
	var run := READER.read(str(done.path))
	check("strict read: complete, no errors", bool(run.ok) and str(run.status) == "complete" and (run.errors as Array).is_empty(), [run.status, run.errors])
	var c: Dictionary = run.columns
	var mismatch := []
	for name: String in expected:
		var got: Variant = c[name]
		var want: Array = expected[name]
		if (got as Variant).size() != want.size():
			mismatch.append("%s size %d != %d" % [name, got.size(), want.size()])
			continue
		for k: int in want.size():
			var w: Variant = want[k]
			var stored: Variant = w
			if not got[k] == stored:
				mismatch.append("%s[%d] %s != %s" % [name, k, got[k], stored])
				break
	check("every tick column reads back exactly (vectors as the engine's float32, f64 views and clock)", mismatch.is_empty(), mismatch)
	check("double views keep 1e-9 steps", absf((c.yaw as PackedFloat64Array)[699] - (1.0 / 3.0 + 699e-9)) == 0.0, (c.yaw as PackedFloat64Array)[699])
	var got_inputs: Dictionary = run.inputs
	var input_bad := []
	if (got_inputs.tick as PackedInt32Array).size() != inputs.size():
		input_bad.append("count %d != %d" % [(got_inputs.tick as PackedInt32Array).size(), inputs.size()])
	else:
		for k: int in inputs.size():
			var row: Array = inputs[k]
			var have := [got_inputs.tick[k], got_inputs.kind[k], got_inputs.flags[k], got_inputs.code[k], got_inputs.aux[k], got_inputs.x[k], got_inputs.y[k], got_inputs.x2[k], got_inputs.y2[k]]
			for j: int in row.size():
				if not is_equal_approx(float(have[j]), float(row[j])) or (j >= 5 and float(have[j]) != f32(float(row[j]))):
					input_bad.append([k, have, row])
					break
			if input_bad.size() > 3:
				break
	check("every input edge and motion reads back in order with its kind, code and deltas", input_bad.is_empty(), input_bad)
	var kinds := {}
	for e: Dictionary in run.events:
		kinds[e.k] = int(kinds.get(e.k, 0)) + 1
	check("derived events: timer start, finish line, clean lost, checkpoints, respawn count", kinds.has("timer_start") and kinds.has("finish_line") and kinds.has("clean_lost") and int(kinds.get("checkpoint", 0)) == 3 and kinds.has("respawn_count"), kinds)
	check("the tick gap and the missing pitch are recorded, not hidden", int(kinds.get("tick_gap", 0)) == 1 and int(kinds.get("sample_missing", 0)) == 1 and int((run.seal.counts as Dictionary).gaps) == 1, kinds)
	check("style events, lifecycle events, motion and hops are recorded", int(kinds.get("style", 0)) == 7 and kinds.has("pause") and kinds.has("resume") and int(kinds.get("motion", 0)) == 18 and int(kinds.get("hop", 0)) == 13, kinds)
	check("held names are announced, unknown inputs labelled", int(kinds.get("held_names", 0)) == 2 and kinds.has("input_other") and kinds.has("action_name"), kinds)
	var seq_ok := true
	for k: int in (run.events as Array).size():
		if int(run.events[k].q) != k:
			seq_ok = false
	check("event sequence numbers are dense and ordered", seq_ok)
	check("header carries identity, units and safe metadata", (run.header.identity as Dictionary).get("map") == "synthetic" and run.header.units.length == "m" and run.header.metadata.vector == [1.0, 2.0, 3.0] and run.header.metadata.nan == "NaN" and str(run.header.metadata.object).begins_with("<"), run.header.metadata)
	check("seal records outcome, counts, timer and finish ticks", run.seal.outcome.kind == "finish" and int(run.seal.counts.ticks) == 700 and int(run.seal.timer_start_tick) == 10 and int(run.seal.finish_tick) == 693, run.seal)
	var size := FileAccess.get_file_as_bytes(str(done.path)).size()
	notes["format_bytes"] = size
	notes["format_bytes_per_tick"] = float(size) / 700.0
	# the python cross-reader compares its own decode against these hex bytes.
	var hex := {}
	for name: String in expected:
		var arr: Variant = c[name]
		hex[name] = (arr as Variant).to_byte_array().hex_encode()
	var input_hex := {}
	for name: String in got_inputs:
		input_hex[name] = (got_inputs[name] as Variant).to_byte_array().hex_encode()
	var side := FileAccess.open(dir.path_join("expected.json"), FileAccess.WRITE)
	side.store_string(JSON.stringify({"file": str(done.path).get_file(), "columns_hex": hex, "inputs_hex": input_hex, "event_count": (run.events as Array).size(),
		"kinds": kinds, "seal_ticks": 700, "header_identity": run.header.identity}, " "))
	side.close()

func _group_states() -> void:
	var dir := out_dir.path_join("states")
	var rec := RECORDER.new()
	var meta := {"map": "states", "preset": "server128", "identity": {"map": "states", "preset": "server128"}}
	rec.begin_run(meta, dir)
	var again := rec.begin_run(meta, dir)
	check("a second begin while open is refused", not bool(again.ok) and rec.is_open(), again)
	for i: int in 300:
		rec.capture(synthetic(i))
	# a crash leaves the .part as it stands: copy it now, before abort renames it.
	var part := FileAccess.get_file_as_bytes(rec.path)
	var crash := dir.path_join("crashed.r16run.part")
	var f := FileAccess.open(crash, FileAccess.WRITE)
	f.store_buffer(part)
	f.close()
	var aborted := rec.abort("test abort")
	check("abort keeps the stream as .r16run.aborted", bool(aborted.ok) and str(aborted.path).ends_with(".r16run.aborted") and str(rec.status) == "aborted", aborted)
	var run := READER.read(str(aborted.path))
	check("an aborted file reads as aborted, not complete", not bool(run.ok) and str(run.status) == "aborted" and str(run.abort.reason) == "test abort" and (run.columns.tick as PackedInt32Array).size() == 300, [run.status, run.errors])
	var partial := READER.read(crash)
	check("a crashed .part recovers its whole flushed chunks only, labelled partial", not bool(partial.ok) and str(partial.status) == "partial" and (partial.columns.tick as PackedInt32Array).size() == 256, [partial.status, partial.errors, (partial.columns.tick as PackedInt32Array).size()])
	check("finish without an open run is refused", not bool(rec.finish({}).ok))
	var off := RECORDER.new()
	off.enabled = false
	var none := off.begin_run(meta, dir)
	check("a disabled recorder writes nothing", not bool(none.ok) and str(off.status) == "disabled")
	off.capture(synthetic(0))
	var big := RECORDER.new()
	var huge := big.begin_run({"map": "big", "preset": "x", "blob": "x".repeat(70000)}, dir)
	check("oversized header metadata is refused and leaves no file", not bool(huge.ok) and not FileAccess.file_exists(str(huge.path)), huge)
	var empty := RECORDER.new()
	empty.begin_run(meta, dir)
	var sealed := empty.finish({"kind": "quit"})
	var zero := READER.read(str(sealed.path))
	check("an attempt with no ticks still seals and reads complete", bool(sealed.ok) and bool(zero.ok) and int(zero.seal.counts.ticks) == 0, [zero.status, zero.errors])
	var names := DirAccess.get_files_at(dir)
	notes["states_files"] = Array(names)

func _group_disk() -> void:
	var dir := out_dir.path_join("disk")
	var rec := RECORDER.new()
	rec.fail_after_bytes = 3000
	rec.begin_run({"map": "disk", "preset": "server128"}, dir)
	for i: int in 600:
		rec.capture(synthetic(i))
	check("a failed write sets disk-error and keeps the .part", str(rec.status) == "disk-error" and str(rec.path).ends_with(".part") and FileAccess.file_exists(rec.path) and not str(rec.last_error).is_empty(), [rec.status, rec.last_error])
	check("ticks after the failure are counted as dropped, not silent", int(rec.dropped_ticks) == 600 - 256, rec.dropped_ticks)
	var done := rec.finish({"kind": "finish"})
	check("finish after a disk error reports it and seals nothing", not bool(done.ok) and str(done.status) == "disk-error" and not FileAccess.file_exists(str(rec.path).trim_suffix(".part")), done)
	var run := READER.read(rec.path)
	check("the failed file reads as partial, never complete", not bool(run.ok) and str(run.status) == "partial", [run.status, run.errors])
	var locked := out_dir.path_join("locked")
	DirAccess.make_dir_recursive_absolute(locked)
	OS.execute("chmod", ["555", ProjectSettings.globalize_path(locked)])
	var shut := RECORDER.new()
	var refused := shut.begin_run({"map": "locked", "preset": "x"}, locked.path_join("inner"))
	var refused2 := shut.begin_run({"map": "locked", "preset": "x"}, locked)
	OS.execute("chmod", ["755", ProjectSettings.globalize_path(locked)])
	check("an unwritable directory is refused at begin with the reason", not bool(refused.ok) and not bool(refused2.ok) and str(shut.status) == "error" and not str(refused2.error).is_empty(), [refused, refused2])

## run by test_r16_record_format.py under RLIMIT_FSIZE with SIGXFSZ ignored: the OS refuses the
## write past the limit. prints one JSON line with what the recorder reported.
func _phase_rlimit() -> void:
	var dir := out_dir.path_join("rlimit")
	var rec := RECORDER.new()
	var opened := rec.begin_run({"map": "rlimit", "preset": "server128"}, dir)
	# keep feeding after the failure, as a game would: those ticks must be counted as dropped.
	for i: int in 4000:
		rec.capture(synthetic(i % 700))
	var done := rec.finish({"kind": "finish"})
	print("RLIMIT " + JSON.stringify({"opened": opened.ok, "status": rec.status, "error": rec.last_error, "path": rec.path, "dropped": rec.dropped_ticks, "finish_ok": done.ok}))
	quit(0)

# --- real host --------------------------------------------------------------------------------

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse(dx: float, dy: float = 0.0) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.screen_relative = Vector2(dx, dy)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release_all() -> void:
	for code: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_CTRL, KEY_R, KEY_F]:
		key(code, false)

func make_game(fixture: bool, dir: String) -> void:
	FIXTURE.params = {}
	game = MAIN.new()
	if fixture:
		game.set("level_script", FIXTURE)
	root.add_child(game)
	adapter = ADAPTER.new(game, dir)
	root.add_child(adapter)
	for i: int in 16:
		await physics_frame

func _drop_game() -> void:
	release_all()
	if is_instance_valid(adapter):
		adapter.call("close", "quit")
		adapter.queue_free()
		adapter = null
	if is_instance_valid(game):
		if bool(game.paused):
			game.call("set_paused", false)
		game.queue_free()
		game = null
	paused = false
	for i: int in 3:
		await physics_frame

## a fixed schedule: tick -> list of [kind, a, b]. keys are [k, code, pressed], mouse [m, dx, dy].
func play(schedule: Dictionary, length: int, until_finish: bool = false) -> int:
	for t: int in length:
		for step: Array in schedule.get(t, []):
			if step[0] == "k":
				key(step[1], step[2])
			else:
				mouse(step[1], step[2])
		await physics_frame
		if until_finish and bool(game.finished):
			return t
	return length

func clean_schedule() -> Dictionary:
	# hold W to the fixture gate, sweep the view, one jump with an air crouch on the way.
	var s := {0: [["k", KEY_W, true]], 60: [["m", 40.0, 0.0]], 61: [["m", -40.0, 3.0]], 120: [["k", KEY_SPACE, true]], 124: [["k", KEY_SPACE, false], ["k", KEY_CTRL, true]],
		160: [["k", KEY_CTRL, false]], 200: [["m", 25.0, -3.0], ["m", -25.0, 0.0]]}
	return s

func _trace_of(rows: Array, attempt: int) -> Array:
	return rows.filter(func(r: Dictionary) -> bool: return int(r.attempt) == attempt)

func _same(a: Array, b: Array) -> Dictionary:
	if a.size() != b.size():
		return {"ok": false, "why": "lengths %d and %d" % [a.size(), b.size()]}
	for i: int in a.size():
		for k: String in ["p", "v", "yaw", "pitch", "elapsed", "checkpoint"]:
			if a[i][k] != b[i][k]:
				return {"ok": false, "why": "tick %d %s: %s != %s" % [i, k, a[i][k], b[i][k]]}
	return {"ok": true, "ticks": a.size()}

static func _detick(r: Dictionary) -> Dictionary:
	var out := r.duplicate()
	out.erase("tick")
	return out

func _group_host() -> void:
	var runs := out_dir.path_join("host/runs")
	await make_game(true, runs)
	check("the R15 host starts on the loop fixture with the crouch runner", str(game.map_id) == "fixture" and str(game.preset_id) == "server128", [game.map_id, game.preset_id])
	var first_attempt := int(game.attempts)
	var finished_at := await play(clean_schedule(), 3000, true)
	release_all()
	await physics_frame
	check("attempt 1 finishes clean through key and mouse input", bool(game.finished) and str(game.finish_kind) == "clean", [game.finished, game.finish_kind, finished_at])
	var clean_trace := _trace_of(adapter.trace, first_attempt)
	var clean_result: Dictionary = (adapter.results as Array).back() if not (adapter.results as Array).is_empty() else {}
	check("the finish seals a complete recording", bool(clean_result.get("ok", false)) and str(clean_result.path).ends_with(".r16run"), clean_result)
	# attempt 2: restart with R, walk, restart again.
	await play({0: [["k", KEY_R, true]], 1: [["k", KEY_R, false]], 2: [["k", KEY_W, true]], 80: [["m", 15.0, 0.0]], 120: [["k", KEY_W, false], ["k", KEY_R, true]], 121: [["k", KEY_R, false]]}, 124)
	# attempt 3: strafe right into the bay hole, fall, respawn, then F for practice.
	await play({0: [["k", KEY_D, true]], 300: [["k", KEY_D, false]]}, 500)
	var fell := int(game.respawn_count)
	await play({0: [["k", KEY_F, true]], 1: [["k", KEY_F, false]]}, 4)
	check("attempt 3 fell and respawned before practice", fell >= 1, fell)
	# attempt 4: the practice attempt runs to the gate; a practice finish is never ghost material.
	await play({0: [["k", KEY_W, true]]}, 3000, true)
	release_all()
	await physics_frame
	check("the practice attempt finishes as practice", bool(game.finished) and str(game.finish_kind) == "practice", game.finish_kind)
	# attempt 5: R, a little walking, then quit.
	await play({0: [["k", KEY_R, true]], 1: [["k", KEY_R, false]], 3: [["k", KEY_W, true]], 40: [["k", KEY_W, false]]}, 50)
	adapter.call("close", "quit")
	var outcomes := (adapter.results as Array).map(func(r: Dictionary) -> String: return "%s:%s" % [r.status, READER.read(str(r.path), false).seal.get("outcome", {}).get("kind", "?")])
	check("every attempt sealed with its outcome: finish, restart, practice, finish (practice), quit", outcomes == ["complete:finish", "complete:restart", "complete:practice", "complete:finish", "complete:quit"], outcomes)
	var files := Array(DirAccess.get_files_at(runs)).filter(func(n: String) -> bool: return n.ends_with(".r16run"))
	check("five complete files, nothing left .part", files.size() == 5 and Array(DirAccess.get_files_at(runs)).all(func(n: String) -> bool: return n.ends_with(".r16run")), DirAccess.get_files_at(runs))
	var clean_path := str(clean_result.get("path", ""))
	var clean_run := READER.read(clean_path)
	check("the clean file holds every sampled tick of attempt 1", bool(clean_run.ok) and (clean_run.columns.tick as PackedInt32Array).size() == clean_trace.size(), [(clean_run.columns.tick as PackedInt32Array).size(), clean_trace.size()])
	var exact := true
	for i: int in clean_trace.size():
		var row: Dictionary = clean_trace[i]
		var p: Vector3 = clean_run.columns.p[i]
		if p != row.p or clean_run.columns.yaw[i] != row.yaw or clean_run.columns.pitch[i] != row.pitch or clean_run.columns.elapsed[i] != row.elapsed:
			exact = false
			notes["clean_mismatch"] = [i, p, row.p]
			break
	check("recorded feet, view and clock equal the live game exactly", exact)
	var kinds := {}
	var inputs: Dictionary = clean_run.inputs
	for k: int in (inputs.kind as PackedInt32Array).size():
		kinds[inputs.kind[k]] = int(kinds.get(inputs.kind[k], 0)) + 1
	# W, Space down/up and Ctrl down/up before the gate; four scheduled mouse motions.
	check("the clean file holds the real key edges and mouse motions", int(kinds.get(READER.INPUT_KEY, 0)) == 5 and int(kinds.get(READER.INPUT_MOUSE_MOTION, 0)) == 4, kinds)
	var motion_names := {}
	for e: Dictionary in clean_run.events:
		if e.k == "motion":
			for n: String in e.d.events:
				motion_names[n] = true
	check("the runner's own jump, land and duck events are in the stream", motion_names.has("jump") and motion_names.has("land"), motion_names.keys())
	var cost: PackedInt64Array = adapter.capture_usec
	var sorted_cost := Array(cost)
	sorted_cost.sort()
	notes["capture_usec"] = {"calls": cost.size(), "median": sorted_cost[sorted_cost.size() / 2], "p99": sorted_cost[int(sorted_cost.size() * 0.99)], "max": sorted_cost.back(),
		"note": "headless, includes chunk compression, hashing and the write every 256 ticks; excludes building the sample"}
	notes["clean_time"] = clean_run.seal.final.elapsed
	notes["host_files"] = files
	var identity: Dictionary = adapter.call("identity")
	var best := READER.fastest_clean(runs, identity)
	check("fastest_clean picks the clean finish, never the practice finish", bool(best.ok) and str(best.path) == clean_path and int(best.considered) == 5, best)
	await _drop_game()
	# ghost: the same inputs three times. 1 without, 2 with a ghost, 3 without.
	var traces: Array = []
	var ghost_notes := {}
	for pass_index: int in 3:
		await make_game(true, out_dir.path_join("host/replay-%d" % pass_index))
		var attempt := int(game.attempts)
		var ghost: Node3D = null
		if pass_index == 1:
			ghost = GHOST.new()
			game.add_child(ghost)
			var loaded: Dictionary = ghost.call("load_run", clean_path, identity)
			ghost_notes["load"] = loaded
			check("the ghost loads the clean finish for this identity", bool(loaded.ok) and is_equal_approx(float(loaded.time), float(notes.clean_time)), loaded)
			check("the ghost has no collision object and no physics body", ghost.find_children("*", "CollisionObject3D", true, false).is_empty() and ghost.find_children("*", "CollisionShape3D", true, false).is_empty())
			adapter.set("ghost", ghost)
		await play(clean_schedule(), 3000, true)
		release_all()
		await physics_frame
		traces.append(_trace_of(adapter.trace, attempt))
		if ghost != null:
			var at: Dictionary = ghost.call("pose_at", 1.0)
			var idx := -1
			for i: int in clean_trace.size():
				if absf(float(clean_trace[i].elapsed) - 1.0) < 1e-9:
					idx = i
			check("at a recorded tick time the ghost stands exactly on the recorded feet", idx >= 0 and (at.feet as Vector3) == clean_trace[idx].p, [idx, at])
			var mid: Dictionary = ghost.call("pose_at", (float(clean_trace[idx].elapsed) + float(clean_trace[idx + 1].elapsed)) * 0.5)
			check("between ticks the ghost interpolates", (mid.feet as Vector3).is_equal_approx((clean_trace[idx].p as Vector3).lerp(clean_trace[idx + 1].p, 0.5)), mid)
			var before: Dictionary = ghost.call("pose_at", -1.0)
			var after: Dictionary = ghost.call("pose_at", 1e6)
			check("before the timer it waits at the start pose, after the finish it holds the finish pose", (before.feet as Vector3).distance_to(clean_trace[0].p) < 0.6 and (after.feet as Vector3) == (clean_trace.back().p as Vector3), [before, after])
			# the replay follows the ghost's own inputs, so at the line the ghost stands in the eye.
			var camera := root.get_viewport().get_camera_3d()
			ghost_notes["camera"] = camera.get_path() if camera != null else null
			ghost.call("set_time", float(game.elapsed))
			ghost.call("_apply_fade")
			check("on the player's own eye the ghost body is hidden", camera != null and float(ghost.call("fade")) < 0.01 and not (ghost.get_node("Body") as Node3D).visible, [ghost.call("fade"), camera])
			ghost.call("set_time", 0.0)
			ghost.call("_apply_fade")
			check("far from the eye the ghost is shown", float(ghost.call("fade")) > 0.99 and (ghost.get_node("Body") as Node3D).visible, ghost.call("fade"))
			ghost.visible = false
			check("visible=false hides the ghost", not ghost.is_visible_in_tree())
		await _drop_game()
	notes["trace_sizes"] = [clean_trace.size(), (traces[0] as Array).size(), (traces[1] as Array).size(), (traces[2] as Array).size()]
	# the first game of the process settles one tick differently; the replays all start alike.
	notes["original_vs_replay"] = _same(clean_trace, traces[0])
	notes["original_vs_replay_less_first_tick"] = _same(clean_trace.slice(1).map(func(r: Dictionary) -> Dictionary: return _detick(r)), (traces[0] as Array).slice(2).map(func(r: Dictionary) -> Dictionary: return _detick(r)))
	var base := _same(traces[0], traces[2])
	var with_ghost := _same(traces[0], traces[1])
	check("baseline: the same inputs replay identically without a ghost", bool(base.ok), base)
	check("with the ghost running, motion is identical tick for tick", bool(with_ghost.ok), with_ghost)
	notes["ghost"] = ghost_notes
	# refusals.
	var probe: Node3D = GHOST.new()
	root.add_child(probe)
	var wrong := identity.duplicate()
	wrong["preset"] = "f5"
	var r1: Dictionary = probe.call("load_run", clean_path, wrong)
	var wrong_geo := identity.duplicate()
	wrong_geo["geometry"] = "other"
	var r2: Dictionary = probe.call("load_run", clean_path, wrong_geo)
	var restart_path := str((READER.read(clean_path, false).header as Dictionary).get("run_id", ""))
	var others := Array(DirAccess.get_files_at(runs)).filter(func(n: String) -> bool: return n.ends_with(".r16run") and runs.path_join(n) != clean_path)
	var refused_all := true
	for n: String in others:
		var r: Dictionary = probe.call("load_run", runs.path_join(n), identity)
		if bool(r.ok):
			refused_all = false
	var copy := out_dir.path_join("host/flip.r16run")
	var bytes := FileAccess.get_file_as_bytes(clean_path)
	bytes[bytes.size() / 2] ^= 0x10
	var w := FileAccess.open(copy, FileAccess.WRITE)
	w.store_buffer(bytes)
	w.close()
	var r3: Dictionary = probe.call("load_run", copy, identity)
	var part_copy := out_dir.path_join("host/clean-copy.r16run.part")
	w = FileAccess.open(part_copy, FileAccess.WRITE)
	w.store_buffer(FileAccess.get_file_as_bytes(clean_path))
	w.close()
	var r4: Dictionary = probe.call("load_run", part_copy, identity)
	var r5: Dictionary = probe.call("load_run", clean_path, {})
	check("the ghost refuses another preset or geometry identity", not bool(r1.ok) and not bool(r2.ok), [r1, r2])
	check("the ghost refuses restart, practice and quit recordings", refused_all and others.size() == 4, others)
	check("the ghost refuses a corrupted copy, a .part name and an empty identity", not bool(r3.ok) and not bool(r4.ok) and not bool(r5.ok), [r3, r4, r5])
	check("after a refusal no ghost lingers", not bool(probe.get("loaded")) and not (probe.get_node("Body") as Node3D).visible)
	probe.queue_free()
	DirAccess.remove_absolute(copy)
	DirAccess.remove_absolute(part_copy)
	notes["restart_header"] = restart_path

func _group_breakwater() -> void:
	var runs := out_dir.path_join("breakwater/runs")
	await make_game(false, runs)
	check("breakwater on server128 is the default host", str(game.map_id) == "breakwater" and str(game.preset_id) == "server128", [game.map_id, game.preset_id])
	var attempt := int(game.attempts)
	var s := {0: [["k", KEY_W, true]], 40: [["k", KEY_SPACE, true]], 90: [["k", KEY_W, false], ["k", KEY_D, true]]}
	# strafe hops: alternate A/D with matching mouse turns while autohop holds space.
	for k: int in 8:
		var at := 90 + k * 70
		s[at] = [["k", KEY_D if k % 2 == 0 else KEY_A, true], ["k", KEY_A if k % 2 == 0 else KEY_D, false]]
		for j: int in range(1, 60, 3):
			var row: Array = s.get(at + j, [])
			row.append(["m", 6.0 if k % 2 == 0 else -6.0, 0.0])
			s[at + j] = row
	s[300] = (s.get(300, []) as Array) + [["k", KEY_CTRL, true]]
	s[330] = (s.get(330, []) as Array) + [["k", KEY_CTRL, false]]
	s[452] = (s.get(452, []) as Array) + [["k", KEY_CTRL, true]]
	s[475] = (s.get(475, []) as Array) + [["k", KEY_CTRL, false]]
	s[700] = [["k", KEY_SPACE, false], ["k", KEY_A, false], ["k", KEY_D, false]]
	await play(s, 760)
	var moved := _trace_of(adapter.trace, attempt)
	await play({0: [["k", KEY_R, true]], 1: [["k", KEY_R, false]], 2: [["k", KEY_W, true]], 120: [["k", KEY_W, false]]}, 130)
	adapter.call("close", "quit")
	var results: Array = adapter.results
	check("both breakwater attempts sealed complete", results.size() == 2 and results.all(func(r: Dictionary) -> bool: return bool(r.ok)), results)
	var run := READER.read(str(results[0].path))
	check("the breakwater recording reads strictly and holds every sampled tick", bool(run.ok) and (run.columns.tick as PackedInt32Array).size() == moved.size(), [run.status, (run.columns.tick as PackedInt32Array).size(), moved.size()])
	var travel := Vector3(moved.back().p).distance_to(moved[0].p)
	check("the strafing run actually moved", travel > 10.0, travel)
	var ducks := 0
	for e: Dictionary in run.events:
		if e.k == "motion" and ((e.d.events as Array).has("duck_air") or (e.d.events as Array).has("unduck_air")):
			ducks += 1
	check("the strafing run air-crouched at least once", ducks >= 1, ducks)
	notes["breakwater"] = {"ticks": moved.size(), "bytes": FileAccess.get_file_as_bytes(str(results[0].path)).size(), "travel_m": travel, "air_ducks": ducks,
		"max_speed_u": moved.reduce(func(m: float, r: Dictionary) -> float: return maxf(m, Vector2(r.v.x, r.v.z).length() / U), 0.0)}

extends RefCounted
## p / r16 per-attempt run recorder. one open file per played attempt, written as a versioned
## stream of bounded chunks (docs/r16/RECORDINGS.md has the byte layout). the recorder observes:
## it receives the post-step sample and lifecycle/style events from its owner and never reads or
## writes the body, its input, physics or progress.
##
## - begin_run(metadata, directory) opens `<directory>/<run_id>.r16run.part` and writes the header.
## - capture(sample, events) appends one physics tick, its input edges and the given style events.
## - event(kind, data) appends a lifecycle event after the last captured tick.
## - finish(outcome) seals: the last chunk, a SEAL chunk, close, then an atomic rename to
##   `<run_id>.r16run`. only a sealed file is a complete recording.
## - abort(reason) writes an ABORT chunk and renames to `<run_id>.r16run.aborted`.
## a write failure stops the stream, keeps the `.part` file as it stands, sets `status` to
## "disk-error" and `last_error`, and every later call reports it; nothing else is written. ticks
## that arrive after a failure are counted in `dropped_ticks`, never silently discarded.
## the cost per tick is appends to packed columns; compression, hashing and the write happen once
## per chunk (CHUNK_TICKS ticks, or sooner when inputs or events fill their bounds).

const READER := preload("res://scripts/r16_run_reader.gd")
const FORMAT := READER.FORMAT
const VERSION := READER.VERSION
const CHUNK_TICKS := 256
const CHUNK_INPUTS := 4096
const CHUNK_EVENT_BYTES := 65536
const DEFAULT_DIRECTORY := "user://r16_runs/"
const REQUIRED := ["tick", "dt", "physics_hz", "elapsed", "started", "finished", "clean", "checkpoint", "respawns", "p", "reference_p", "v", "actual_v", "yaw", "pitch", "grounded", "ducked", "held", "input_events"]

## false makes every call a no-op that reports "disabled"; the owner decides when to record.
var enabled := true
## "idle", "open", "complete", "aborted", "disk-error", "error", "disabled".
var status := "idle"
var last_error := ""
var run_id := ""
var path := ""
var final_path := ""
var dropped_ticks := 0
## test hook, labelled: a write fails once the file would pass this many bytes (-1 = never). the
## real disk-error path is exercised separately with an OS file-size limit.
var fail_after_bytes := -1

var _file: FileAccess
var _bytes := 0
var _chain := PackedByteArray()
var _seq := 0
var _event_seq := 0
var _counts := {}
var _last_tick := -1
var _first_tick := -1
var _held_names: Array[String] = []
var _action_names: Array[String] = []
var _prev := {}
var _missing_noted := {}
var _timer_tick := -1
var _finish_tick := -1
var _final := {}
# the open chunk's columns. packed arrays are values in GDScript, so each is its own member:
# appending through a dictionary or a cast would grow a copy.
var _tick_col := PackedInt32Array()
var _flags_col := PackedInt32Array()
var _dt_col := PackedFloat64Array()
var _elapsed_col := PackedFloat64Array()
var _hz_col := PackedInt32Array()
var _checkpoint_col := PackedInt32Array()
var _respawns_col := PackedInt32Array()
var _p_col := PackedVector3Array()
var _r_col := PackedVector3Array()
var _v_col := PackedVector3Array()
var _a_col := PackedVector3Array()
var _yaw_col := PackedFloat64Array()
var _pitch_col := PackedFloat64Array()
var _held_col := PackedInt64Array()
var _in_tick := PackedInt32Array()
var _in_kind := PackedInt32Array()
var _in_flags := PackedInt32Array()
var _in_code := PackedInt64Array()
var _in_aux := PackedInt64Array()
var _in_x := PackedFloat32Array()
var _in_y := PackedFloat32Array()
var _in_x2 := PackedFloat32Array()
var _in_y2 := PackedFloat32Array()
var _events: Array = []
var _event_bytes := 0

func is_open() -> bool:
	return status == "open"

## metadata: what root knows of the attempt (map, preset, identity, build, attempt, reason...).
## `identity` is the dictionary a ghost must match exactly. directory defaults to user://r16_runs/.
func begin_run(metadata: Dictionary, directory: String = DEFAULT_DIRECTORY) -> Dictionary:
	if not enabled:
		status = "disabled"
		return {"ok": false, "status": status, "error": "recording is disabled"}
	if status == "open":
		return {"ok": false, "status": status, "error": "a run is already open: finish or abort it first", "path": path}
	_reset()
	if PackedInt32Array([1]).to_byte_array()[0] != 1:
		return _fail("error", "this platform is not little-endian; the r16 format is little-endian only")
	if Vector3(1.0 + 1e-9, 0, 0).x != 1.0:
		return _fail("error", "this engine stores vectors in double precision; format version 1 holds float32 vectors only")
	var dir := ProjectSettings.globalize_path(directory if not directory.is_empty() else DEFAULT_DIRECTORY)
	var made := DirAccess.make_dir_recursive_absolute(dir)
	if made != OK and not DirAccess.dir_exists_absolute(dir):
		return _fail("error", "cannot create recording directory %s (%s)" % [dir, error_string(made)])
	var created := Time.get_unix_time_from_system()
	run_id = _make_id(metadata, created)
	path = dir.path_join(run_id + ".r16run.part")
	final_path = dir.path_join(run_id + ".r16run")
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		return _fail("error", "cannot open %s for writing (%s)" % [path, error_string(FileAccess.get_open_error())])
	var header := {
		"format": FORMAT, "version": VERSION, "run_id": run_id, "created_unix": created,
		"created_utc": Time.get_datetime_string_from_unix_time(int(created)) + "Z",
		"engine": Engine.get_version_info().get("string", ""), "os": OS.get_name(),
		"vector_precision": "single",
		"units": {"length": "m", "velocity": "m/s", "angle": "rad", "time": "s"},
		"metadata": READER.json_safe(metadata),
		"identity": READER.json_safe(metadata.get("identity", {})),
	}
	var text := JSON.stringify(header, "", true, true).to_utf8_buffer()
	if text.size() > READER.MAX_HEADER:
		_file.close()
		_file = null
		DirAccess.remove_absolute(path)
		return _fail("error", "header metadata is %d bytes, above the %d byte bound" % [text.size(), READER.MAX_HEADER])
	var head := StreamPeerBuffer.new()
	head.put_data(READER.MAGIC.to_ascii_buffer())
	head.put_u16(VERSION)
	head.put_u16(0)
	head.put_u32(text.size())
	head.put_data(text)
	var bytes := head.data_array
	_chain = READER.sha256(bytes)
	status = "open"
	if not _write(bytes + _chain):
		return {"ok": false, "status": status, "error": last_error, "path": path, "run_id": run_id}
	return {"ok": true, "status": status, "path": path, "run_id": run_id, "final_path": final_path}

## one post-step sample (see docs/r16/INTERFACES.md). events are style (or other scored) events
## produced on this tick; each is a Dictionary, recorded with kind `record_kind` or "style".
func capture(sample: Dictionary, events: Array = []) -> void:
	if status != "open":
		if status == "disk-error":
			dropped_ticks += 1
		return
	for key: String in REQUIRED:
		if not sample.has(key) and not _missing_noted.has(key):
			_missing_noted[key] = true
			push_warning("r16 recorder: sample has no '%s'; recording its zero value" % key)
			_add_event("sample_missing", {"field": key}, _last_tick, "recorder")
	var tick := int(sample.get("tick", _last_tick + 1))
	if _last_tick >= 0 and tick != _last_tick + 1:
		_add_event("tick_gap", {"expected": _last_tick + 1, "got": tick}, tick, "recorder")
	if _first_tick < 0:
		_first_tick = tick
	_last_tick = tick
	var flags := 0
	for bit: int in READER.FLAG_KEYS.size():
		if bool(sample.get(READER.FLAG_KEYS[bit], false)):
			flags |= 1 << bit
	var p := _vec(sample.get("p"))
	var r := _vec(sample.get("reference_p", p))
	var v := _vec(sample.get("v"))
	var a := _vec(sample.get("actual_v", v))
	_tick_col.append(tick)
	_flags_col.append(flags)
	_dt_col.append(float(sample.get("dt", 0.0)))
	_elapsed_col.append(float(sample.get("elapsed", 0.0)))
	_hz_col.append(int(sample.get("physics_hz", 0)))
	_checkpoint_col.append(int(sample.get("checkpoint", 0)))
	_respawns_col.append(int(sample.get("respawns", 0)))
	_p_col.append(p)
	_r_col.append(r)
	_v_col.append(v)
	_a_col.append(a)
	_yaw_col.append(float(sample.get("yaw", 0.0)))
	_pitch_col.append(float(sample.get("pitch", 0.0)))
	_held_col.append(_held_mask(sample.get("held", {}), tick))
	for input: Variant in sample.get("input_events", []):
		_add_input(tick, input)
	_derive(sample, tick, flags)
	for e: Variant in events:
		if e is Dictionary:
			_add_event(str((e as Dictionary).get("record_kind", "style")), e, tick, "capture")
		else:
			_add_event("unrecognized_event", {"text": str(e).left(200)}, tick, "capture")
	_counts.ticks += 1
	_final = {"tick": tick, "elapsed": float(sample.get("elapsed", 0.0)), "started": bool(sample.get("started", false)),
		"finished": bool(sample.get("finished", false)), "clean": bool(sample.get("clean", false)),
		"checkpoint": int(sample.get("checkpoint", 0)), "respawns": int(sample.get("respawns", 0)), "p": READER.json_safe(p)}
	if _tick_col.size() >= CHUNK_TICKS or _in_tick.size() >= CHUNK_INPUTS or _event_bytes >= CHUNK_EVENT_BYTES:
		_flush_ticks()

## a lifecycle event (restart, practice, respawn, fall, pause, resume, settings, map, preset,
## loadout, quit, timer...). it belongs after the last captured tick: `t` is that tick, -1 before
## the first sample.
func event(kind: String, data: Dictionary = {}) -> void:
	if status != "open":
		return
	_add_event(kind, data, _last_tick, "event")
	if _event_bytes >= CHUNK_EVENT_BYTES:
		_flush_ticks()

## seals the attempt. outcome: {"kind": "finish"|"restart"|"practice"|"map"|"preset"|"quit"|..., ...}
## from root. returns ok, path (the sealed file), run_id, status and counts.
func finish(outcome: Dictionary = {}) -> Dictionary:
	if status != "open":
		return _result(false, "no open run to finish (%s)" % status)
	if not _flush_ticks():
		return _result(false, last_error)
	var seal := {
		"outcome": READER.json_safe(outcome), "counts": _counts.duplicate(), "first_tick": _first_tick, "last_tick": _last_tick,
		"timer_start_tick": _timer_tick, "finish_tick": _finish_tick, "final": _final.duplicate(),
		"ended_unix": Time.get_unix_time_from_system(),
	}
	if not _write_chunk(READER.CHUNK_SEAL, JSON.stringify(seal, "", true, true).to_utf8_buffer(), 0, 0, false):
		return _result(false, last_error)
	return _close_as(final_path, "complete")

## ends the attempt without a seal: the stream so far is kept and labelled aborted.
func abort(reason: String = "") -> Dictionary:
	if status != "open":
		return _result(false, "no open run to abort (%s)" % status)
	if not _flush_ticks():
		return _result(false, last_error)
	var body := {"reason": reason, "counts": _counts.duplicate(), "last_tick": _last_tick, "final": _final.duplicate(), "ended_unix": Time.get_unix_time_from_system()}
	if not _write_chunk(READER.CHUNK_ABORT, JSON.stringify(body, "", true, true).to_utf8_buffer(), 0, 0, false):
		return _result(false, last_error)
	return _close_as(final_path + ".aborted", "aborted")

func counts() -> Dictionary:
	return _counts.duplicate()

# --- internals ------------------------------------------------------------------------------

func _reset() -> void:
	status = "idle"
	last_error = ""
	run_id = ""
	path = ""
	final_path = ""
	dropped_ticks = 0
	_file = null
	_bytes = 0
	_seq = 0
	_event_seq = 0
	_counts = {"ticks": 0, "chunks": 0, "inputs": 0, "events": 0, "gaps": 0, "bytes": 0}
	_last_tick = -1
	_first_tick = -1
	_held_names.clear()
	_action_names.clear()
	_prev = {}
	_missing_noted = {}
	_timer_tick = -1
	_finish_tick = -1
	_final = {}
	_new_chunk()

func _new_chunk() -> void:
	_tick_col = PackedInt32Array()
	_flags_col = PackedInt32Array()
	_dt_col = PackedFloat64Array()
	_elapsed_col = PackedFloat64Array()
	_hz_col = PackedInt32Array()
	_checkpoint_col = PackedInt32Array()
	_respawns_col = PackedInt32Array()
	_p_col = PackedVector3Array()
	_r_col = PackedVector3Array()
	_v_col = PackedVector3Array()
	_a_col = PackedVector3Array()
	_yaw_col = PackedFloat64Array()
	_pitch_col = PackedFloat64Array()
	_held_col = PackedInt64Array()
	_in_tick = PackedInt32Array()
	_in_kind = PackedInt32Array()
	_in_flags = PackedInt32Array()
	_in_code = PackedInt64Array()
	_in_aux = PackedInt64Array()
	_in_x = PackedFloat32Array()
	_in_y = PackedFloat32Array()
	_in_x2 = PackedFloat32Array()
	_in_y2 = PackedFloat32Array()
	_events = []
	_event_bytes = 0

func _make_id(metadata: Dictionary, created: float) -> String:
	var parts: Array[String] = []
	for key: String in ["map", "preset"]:
		var word := str(metadata.get(key, "")).to_lower()
		var clean := ""
		for ch: String in word:
			clean += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "-" else "-"
		if not clean.is_empty():
			parts.append(clean.left(32))
	var stamp := Time.get_datetime_string_from_unix_time(int(created)).replace("-", "").replace(":", "").replace("T", "-")
	parts.append(stamp)
	parts.append("%03d" % (int(created * 1000.0) % 1000))
	parts.append("%08x" % (randi() & 0xffffffff))
	return "_".join(parts)

static func _vec(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

static func _vec2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

func _held_mask(held: Variant, tick: int) -> int:
	var mask := 0
	if not held is Dictionary:
		return mask
	var dict := held as Dictionary
	var fresh: Array[String] = []
	for name: Variant in dict:
		if not str(name) in _held_names:
			fresh.append(str(name))
	if not fresh.is_empty():
		fresh.sort()
		for name: String in fresh:
			if _held_names.size() < 64:
				_held_names.append(name)
		_add_event("held_names", {"names": _held_names.duplicate()}, tick, "recorder")
	var extra := {}
	for name: Variant in dict:
		var index := _held_names.find(str(name))
		if index >= 0:
			if bool(dict[name]):
				mask |= 1 << index
		elif bool(dict[name]):
			extra[str(name)] = true
	if extra != _prev.get("held_extra", {}):
		_add_event("held_extra", {"held": extra.keys()}, tick, "recorder")
		_prev["held_extra"] = extra
	return mask

func _add_input(tick: int, input: Variant) -> void:
	var kind := 0
	var flags := 0
	var code := 0
	var aux := 0
	var at := Vector2.ZERO
	var at2 := Vector2.ZERO
	if input is InputEventKey:
		var key := input as InputEventKey
		kind = READER.INPUT_KEY
		flags = int(key.pressed) | int(key.echo) << 1
		code = key.keycode
		aux = key.physical_keycode
	elif input is InputEventMouseButton:
		var button := input as InputEventMouseButton
		kind = READER.INPUT_MOUSE_BUTTON
		flags = int(button.pressed) | int(button.double_click) << 2
		code = button.button_index
		at = Vector2(button.factor, 0.0)
	elif input is InputEventMouseMotion:
		# the source look reads screen_relative; relative is kept beside it.
		kind = READER.INPUT_MOUSE_MOTION
		at = (input as InputEventMouseMotion).screen_relative
		at2 = (input as InputEventMouseMotion).relative
	elif input is InputEventAction:
		kind = READER.INPUT_ACTION
		flags = int((input as InputEventAction).pressed)
		code = _action_index(str((input as InputEventAction).action), tick)
	elif input is InputEventJoypadButton:
		kind = READER.INPUT_JOY_BUTTON
		flags = int((input as InputEventJoypadButton).pressed)
		code = (input as InputEventJoypadButton).button_index
		aux = (input as InputEventJoypadButton).device
	elif input is InputEventJoypadMotion:
		kind = READER.INPUT_JOY_MOTION
		code = (input as InputEventJoypadMotion).axis
		aux = (input as InputEventJoypadMotion).device
		at = Vector2((input as InputEventJoypadMotion).axis_value, 0.0)
	elif input is Dictionary:
		var d := input as Dictionary
		match str(d.get("type", "")):
			"key":
				kind = READER.INPUT_KEY
				flags = int(bool(d.get("pressed", false))) | int(bool(d.get("echo", false))) << 1
				code = int(d.get("keycode", 0))
				aux = int(d.get("physical_keycode", 0))
			"mouse_button":
				kind = READER.INPUT_MOUSE_BUTTON
				flags = int(bool(d.get("pressed", false))) | int(bool(d.get("double_click", false))) << 2
				code = int(d.get("button_index", 0))
				at = Vector2(float(d.get("factor", 1.0)), 0.0)
			"mouse_motion":
				kind = READER.INPUT_MOUSE_MOTION
				at2 = _vec2(d.get("relative", Vector2.ZERO))
				at = _vec2(d.get("screen_relative", at2))
			"action":
				kind = READER.INPUT_ACTION
				flags = int(bool(d.get("pressed", false)))
				code = _action_index(str(d.get("action", "")), tick)
	if kind == 0:
		kind = READER.INPUT_OTHER
		_add_event("input_other", {"text": str(input).left(200)}, tick, "recorder")
	_in_tick.append(tick)
	_in_kind.append(kind)
	_in_flags.append(flags)
	_in_code.append(code)
	_in_aux.append(aux)
	_in_x.append(at.x)
	_in_y.append(at.y)
	_in_x2.append(at2.x)
	_in_y2.append(at2.y)
	_counts.inputs += 1

func _action_index(name: String, tick: int) -> int:
	var index := _action_names.find(name)
	if index < 0:
		_action_names.append(name)
		index = _action_names.size() - 1
		_add_event("action_name", {"index": index, "name": name}, tick, "recorder")
	return index

## recorder-derived events from sample changes, so the analysis never depends on root remembering
## to announce them: timer start, finish line, clean lost, checkpoint, respawn count, practice
## reason, physics rate and the runner's own motion events (jump, land, duck, lab moves).
func _derive(sample: Dictionary, tick: int, flags: int) -> void:
	var prev_flags := int(_prev.get("flags", -1))
	var started := flags & 1 != 0
	var finished := flags & 2 != 0
	var clean := flags & 4 != 0
	if prev_flags >= 0:
		if started and prev_flags & 1 == 0:
			_timer_tick = tick
			_add_event("timer_start", {"elapsed": float(sample.get("elapsed", 0.0))}, tick, "recorder")
		elif not started and prev_flags & 1 != 0:
			_add_event("timer_reset", {}, tick, "recorder")
		if finished and prev_flags & 2 == 0:
			_finish_tick = tick
			_add_event("finish_line", {"elapsed": float(sample.get("elapsed", 0.0)), "clean": clean}, tick, "recorder")
		if not clean and prev_flags & 4 != 0:
			_add_event("clean_lost", {"practice_reason": str(sample.get("practice_reason", ""))}, tick, "recorder")
	else:
		if started:
			_timer_tick = tick
		if finished:
			_finish_tick = tick
	_prev["flags"] = flags
	var context := {"checkpoint": int(sample.get("checkpoint", 0)), "respawns": int(sample.get("respawns", 0)),
		"practice_reason": str(sample.get("practice_reason", "")), "physics_hz": int(sample.get("physics_hz", 0)), "dt": float(sample.get("dt", 0.0))}
	var motion: Variant = sample.get("motion", {})
	if motion is Dictionary:
		context["mode"] = str((motion as Dictionary).get("mode", ""))
		context["motor_version"] = str((motion as Dictionary).get("motor_version", ""))
		var experiment: Variant = (motion as Dictionary).get("experiment")
		if experiment is Dictionary:
			context["lab_enabled"] = READER.json_safe((experiment as Dictionary).get("enabled", {}))
	var before: Dictionary = _prev.get("context", {})
	var changed := {}
	for key: String in context:
		if not before.has(key) or before[key] != context[key]:
			changed[key] = context[key]
	if not changed.is_empty():
		if before.has("checkpoint") and changed.has("checkpoint"):
			_add_event("checkpoint", {"from": before.checkpoint, "to": changed.checkpoint, "elapsed": float(sample.get("elapsed", 0.0))}, tick, "recorder")
		if before.has("respawns") and changed.has("respawns") and int(changed.respawns) > int(before.respawns):
			_add_event("respawn_count", {"respawns": changed.respawns}, tick, "recorder")
		_add_event("context", changed, tick, "recorder")
		_prev["context"] = context
	if motion is Dictionary:
		# the motor's own list first; the duck and lab lists add only names it did not report, as
		# r15 also files its duck events in the motor list.
		var m := motion as Dictionary
		var names: Array = []
		if m.get("events") is Array:
			for name: Variant in m.events:
				names.append(str(name))
		for part: String in ["duck", "experiment"]:
			var events: Variant = (m[part] as Dictionary).get("events") if m.get(part) is Dictionary else null
			if events is Array:
				for name: Variant in events:
					if not str(name) in names:
						names.append(str(name))
		if not names.is_empty():
			_add_event("motion", {"events": names}, tick, "recorder")
	var stats: Variant = sample.get("stats", {})
	if stats is Dictionary and (stats as Dictionary).has("hops"):
		var hops := int((stats as Dictionary).hops)
		if _prev.has("hops") and hops > int(_prev.hops):
			_add_event("hop", READER.json_safe((stats as Dictionary).get("last_hop", {})), tick, "recorder")
		_prev["hops"] = hops

func _add_event(kind: String, data: Variant, tick: int, source: String) -> void:
	var row := {"t": tick, "q": _event_seq, "k": kind, "s": source, "d": READER.json_safe(data)}
	_event_seq += 1
	_events.append(row)
	_event_bytes += 48 + str(row.d).length()
	_counts.events += 1
	if kind == "tick_gap":
		_counts.gaps += 1

func _flush_ticks() -> bool:
	if status != "open":
		return false
	var n := _tick_col.size()
	var m := _in_tick.size()
	if n == 0 and m == 0 and _events.is_empty():
		return true
	var out := StreamPeerBuffer.new()
	out.put_u32(n)
	for column: Variant in [_tick_col, _flags_col, _dt_col, _elapsed_col, _hz_col, _checkpoint_col, _respawns_col, _p_col, _r_col, _v_col, _a_col, _yaw_col, _pitch_col, _held_col]:
		out.put_data(column.to_byte_array())
	out.put_u32(m)
	for column: Variant in [_in_tick, _in_kind, _in_flags, _in_code, _in_aux, _in_x, _in_y, _in_x2, _in_y2]:
		out.put_data(column.to_byte_array())
	var text := JSON.stringify(_events, "", false, true).to_utf8_buffer()
	out.put_u32(text.size())
	out.put_data(text)
	var first := _tick_col[0] if n > 0 else maxi(_last_tick, 0)
	_new_chunk()
	return _write_chunk(READER.CHUNK_TICKS, out.data_array, first, n, true)

func _write_chunk(type: int, raw: PackedByteArray, first_tick: int, tick_count: int, compress: bool) -> bool:
	if raw.size() > READER.MAX_CHUNK_RAW:
		_fail("disk-error", "chunk of %d bytes exceeds the %d byte bound" % [raw.size(), READER.MAX_CHUNK_RAW])
		return false
	var stored := raw.compress(FileAccess.COMPRESSION_DEFLATE) if compress else raw
	var head := StreamPeerBuffer.new()
	head.put_data(READER.CHUNK_MAGIC.to_ascii_buffer())
	head.put_u8(type)
	head.put_u8(READER.CODEC_ZLIB if compress else READER.CODEC_RAW)
	head.put_u16(0)
	head.put_u32(_seq)
	head.put_u32(raw.size())
	head.put_u32(stored.size())
	head.put_u32(first_tick)
	head.put_u32(tick_count)
	var fixed := head.data_array
	_chain = READER.chunk_digest(_chain, fixed, stored)
	if not _write(fixed + _chain + stored):
		return false
	_seq += 1
	_counts.chunks += 1
	return true

func _write(bytes: PackedByteArray) -> bool:
	if fail_after_bytes >= 0 and _bytes + bytes.size() > fail_after_bytes:
		var room := fail_after_bytes - _bytes
		if room > 0:
			_file.store_buffer(bytes.slice(0, room))
			_file.flush()
		_bytes += maxi(room, 0)
		_fail("disk-error", "test hook: write refused after %d bytes" % fail_after_bytes)
		return false
	var stored := _file.store_buffer(bytes)
	_file.flush()
	_bytes += bytes.size()
	_counts.bytes = _bytes
	# a buffered write can report success and fail at flush; the length on disk is the proof.
	if not stored or _file.get_error() != OK or _file.get_length() != _bytes:
		_fail("disk-error", "write to %s failed at byte %d (%s; on disk %d)" % [path, _bytes, error_string(_file.get_error()), _file.get_length()])
		return false
	return true

func _close_as(target: String, end_status: String) -> Dictionary:
	_file.close()
	_file = null
	if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):
		return _fail_result("disk-error", "cannot seal: %s already exists; the stream stays at %s" % [target, path])
	var moved := DirAccess.rename_absolute(path, target)
	if moved != OK:
		return _fail_result("disk-error", "cannot rename %s to %s (%s); the stream stays there unsealed" % [path, target, error_string(moved)])
	path = target
	status = end_status
	return _result(true, "")

func _fail(kind: String, message: String) -> Dictionary:
	status = kind
	last_error = message
	push_error("r16 recorder: " + message)
	if _file != null:
		_file.close()
		_file = null
	return {"ok": false, "status": status, "error": message, "path": path, "run_id": run_id}

func _fail_result(kind: String, message: String) -> Dictionary:
	_fail(kind, message)
	return _result(false, message)

func _result(ok: bool, error: String) -> Dictionary:
	return {"ok": ok, "status": status, "error": error, "path": path, "run_id": run_id, "counts": _counts.duplicate(), "dropped_ticks": dropped_ticks}

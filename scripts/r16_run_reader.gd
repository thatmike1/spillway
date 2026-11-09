extends RefCounted
## p / r16 run reader: strict validation and labelled partial recovery of `.r16run` streams
## (docs/r16/RECORDINGS.md). the file is data only: the header and event sections are parsed as
## JSON, the rest as fixed little-endian columns. nothing in a recording is ever loaded as a
## resource, decoded as a variant or executed. every length is bounded before it is read.
##
## read(path, decode) returns:
## - ok: true only for a whole, sealed stream whose hash chain verifies and whose file name ends
##   in `.r16run`;
## - status: "complete", "aborted" (an ABORT chunk ended it), "partial" (the stream stops or breaks
##   before any end chunk; everything before the first bad chunk is returned), "sealed-unrenamed"
##   (a valid seal in a file still named `.part`: the writer died between seal and rename), or
##   "invalid" (no usable header);
## - errors: why it is not complete; header, seal or abort; columns, inputs and events of every
##   valid chunk; valid_bytes, the length of the verified prefix.

const FORMAT := "foldrunner-r16-run"
const VERSION := 1
const MAGIC := "FRR16RUN"
const CHUNK_MAGIC := "CHNK"
const CHUNK_TICKS := 1
const CHUNK_SEAL := 2
const CHUNK_ABORT := 3
const CODEC_RAW := 0
const CODEC_ZLIB := 1
const PREFIX_SIZE := 16
const CHUNK_HEAD_SIZE := 28
const DIGEST_SIZE := 32
const MAX_HEADER := 65536
const MAX_CHUNK_RAW := 8 * 1024 * 1024
const MAX_FILE := 1024 * 1024 * 1024
## bit i of a tick's flags is FLAG_KEYS[i] of the sample.
const FLAG_KEYS := ["started", "finished", "clean", "grounded", "ducked"]
const INPUT_KEY := 1
const INPUT_MOUSE_BUTTON := 2
const INPUT_MOUSE_MOTION := 3
const INPUT_ACTION := 4
const INPUT_JOY_BUTTON := 5
const INPUT_JOY_MOTION := 6
const INPUT_OTHER := 7
const SUFFIX := ".r16run"
const INPUT_ROW := 44

static func sha256(bytes: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish()

## each chunk's digest is sha256(previous digest + its 28-byte head + its stored payload bytes),
## so a damaged chunk is refused before anything inflates it; zlib's own adler-32 then checks the
## inflated bytes. the first previous digest is sha256 of the 16-byte prefix and header JSON.
static func chunk_digest(previous: PackedByteArray, head: PackedByteArray, stored: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(previous)
	ctx.update(head)
	if not stored.is_empty():
		ctx.update(stored)
	return ctx.finish()

## a JSON-safe copy: vectors become arrays, non-finite floats become the strings "NaN", "Infinity"
## and "-Infinity", objects and callables become a type label. no variant encoding is ever used.
static func json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return value
		TYPE_FLOAT:
			if is_nan(value):
				return "NaN"
			if is_inf(value):
				return "Infinity" if value > 0 else "-Infinity"
			return value
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [json_safe(value.x), json_safe(value.y)]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [json_safe(value.x), json_safe(value.y), json_safe(value.z)]
		TYPE_VECTOR4, TYPE_QUATERNION:
			return [json_safe(value.x), json_safe(value.y), json_safe(value.z), json_safe(value.w)]
		TYPE_BASIS:
			return [json_safe(value.x), json_safe(value.y), json_safe(value.z)]
		TYPE_TRANSFORM3D:
			return {"basis": json_safe(value.basis), "origin": json_safe(value.origin)}
		TYPE_AABB:
			return {"position": json_safe(value.position), "size": json_safe(value.size)}
		TYPE_DICTIONARY:
			var out := {}
			for key: Variant in value:
				out[str(key)] = json_safe(value[key])
			return out
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
				TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			var list: Array = []
			for item: Variant in value:
				list.append(json_safe(item))
			return list
	return "<%s>" % type_string(typeof(value))

static func status_from_name(path: String) -> String:
	if path.ends_with(SUFFIX):
		return "complete"
	if path.ends_with(SUFFIX + ".aborted"):
		return "aborted"
	if path.ends_with(SUFFIX + ".part"):
		return "partial"
	return "unknown"

static func is_recording_name(path: String) -> bool:
	return status_from_name(path) != "unknown"

## decode false verifies the whole hash chain and reads header, seal and abort without
## decompressing tick chunks (a quick scan); true also returns columns, inputs and events.
static func read(path: String, decode: bool = true) -> Dictionary:
	var out := {"ok": false, "status": "invalid", "errors": [], "path": path, "header": {}, "seal": {}, "abort": {},
		"chunks": 0, "valid_bytes": 0, "columns": {}, "inputs": {}, "events": []}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		out.errors.append("cannot open: %s" % error_string(FileAccess.get_open_error()))
		return out
	var size := file.get_length()
	if size > MAX_FILE:
		out.errors.append("file is %d bytes, above the %d byte bound" % [size, MAX_FILE])
		return out
	var data := file.get_buffer(size)
	file.close()
	return parse(data, path, decode, out)

static func parse(data: PackedByteArray, path: String = "", decode: bool = true, out: Dictionary = {}) -> Dictionary:
	if out.is_empty():
		out = {"ok": false, "status": "invalid", "errors": [], "path": path, "header": {}, "seal": {}, "abort": {},
			"chunks": 0, "valid_bytes": 0, "columns": {}, "inputs": {}, "events": []}
	var errors: Array = out.errors
	if data.size() < PREFIX_SIZE + DIGEST_SIZE or data.slice(0, 8).get_string_from_ascii() != MAGIC:
		errors.append("not an r16 recording (bad magic or shorter than the prefix)")
		return out
	var version := data.decode_u16(8)
	var header_len := data.decode_u32(12)
	if version != VERSION:
		errors.append("unsupported format version %d (this reader knows %d)" % [version, VERSION])
		out["version"] = version
		return out
	if data.decode_u16(10) != 0 or header_len > MAX_HEADER or PREFIX_SIZE + header_len + DIGEST_SIZE > data.size():
		errors.append("header length %d is out of bounds or truncated" % header_len)
		return out
	var head_bytes := data.slice(0, PREFIX_SIZE + header_len)
	var chain := sha256(head_bytes)
	if data.slice(PREFIX_SIZE + header_len, PREFIX_SIZE + header_len + DIGEST_SIZE) != chain:
		errors.append("header digest mismatch")
		return out
	var header: Variant = JSON.parse_string(data.slice(PREFIX_SIZE, PREFIX_SIZE + header_len).get_string_from_utf8())
	if not header is Dictionary or str((header as Dictionary).get("format", "")) != FORMAT or int((header as Dictionary).get("version", -1)) != VERSION:
		errors.append("header JSON is not an r16 run header")
		return out
	out.header = header
	out.status = "partial"
	var at := PREFIX_SIZE + header_len + DIGEST_SIZE
	out.valid_bytes = at
	var columns := _empty_bytes(TICK_LAYOUT)
	var inputs := _empty_bytes(INPUT_LAYOUT)
	var events: Array = out.events
	var seq := 0
	var ended := ""
	while at < data.size():
		if at + CHUNK_HEAD_SIZE + DIGEST_SIZE > data.size():
			errors.append("truncated chunk head at byte %d" % at)
			break
		var head := data.slice(at, at + CHUNK_HEAD_SIZE)
		if head.slice(0, 4).get_string_from_ascii() != CHUNK_MAGIC:
			errors.append("bad chunk magic at byte %d" % at)
			break
		var type := head.decode_u8(4)
		var codec := head.decode_u8(5)
		var raw_len := head.decode_u32(12)
		var stored_len := head.decode_u32(16)
		var first_tick := head.decode_u32(20)
		var tick_count := head.decode_u32(24)
		if head.decode_u16(6) != 0 or head.decode_u32(8) != seq or not type in [CHUNK_TICKS, CHUNK_SEAL, CHUNK_ABORT] or not codec in [CODEC_RAW, CODEC_ZLIB] \
				or raw_len > MAX_CHUNK_RAW or stored_len > MAX_CHUNK_RAW or (codec == CODEC_RAW and stored_len != raw_len):
			errors.append("chunk %d at byte %d has an invalid head (type %d, codec %d, sequence %d)" % [seq, at, type, codec, head.decode_u32(8)])
			break
		var body_at := at + CHUNK_HEAD_SIZE + DIGEST_SIZE
		if body_at + stored_len > data.size():
			errors.append("chunk %d is truncated (%d of %d stored bytes)" % [seq, data.size() - body_at, stored_len])
			break
		var stored := data.slice(body_at, body_at + stored_len)
		var digest := chunk_digest(chain, head, stored)
		if data.slice(at + CHUNK_HEAD_SIZE, body_at) != digest:
			errors.append("chunk %d digest mismatch" % seq)
			break
		var raw := stored
		if codec == CODEC_ZLIB and (decode or type != CHUNK_TICKS):
			raw = stored.decompress(raw_len, FileAccess.COMPRESSION_DEFLATE)
			if raw.size() != raw_len:
				errors.append("chunk %d does not inflate to %d bytes" % [seq, raw_len])
				break
		if type == CHUNK_TICKS:
			if decode:
				var problem := _decode_ticks(raw, first_tick, tick_count, columns, inputs, events)
				if not problem.is_empty():
					errors.append("chunk %d: %s" % [seq, problem])
					break
		else:
			var body: Variant = JSON.parse_string(raw.get_string_from_utf8())
			if not body is Dictionary:
				errors.append("chunk %d end record is not a JSON object" % seq)
				break
			out["seal" if type == CHUNK_SEAL else "abort"] = body
			ended = "complete" if type == CHUNK_SEAL else "aborted"
		chain = digest
		seq += 1
		at = body_at + stored_len
		out.valid_bytes = at
		if not ended.is_empty():
			break
	out.chunks = seq
	if decode:
		out.columns = _convert(columns, TYPES)
		out.inputs = _convert(inputs, INPUT_TYPES)
	if ended.is_empty():
		if out.valid_bytes == data.size():
			errors.append("the stream ends without a seal or abort chunk")
		out.status = "partial"
	elif out.valid_bytes != data.size():
		errors.append("%d bytes follow the end chunk" % (data.size() - int(out.valid_bytes)))
		out.status = "partial"
	else:
		out.status = ended
	if out.status == "complete" and not path.is_empty() and not path.ends_with(SUFFIX):
		out.status = "sealed-unrenamed" if path.ends_with(SUFFIX + ".part") else "complete"
		if out.status == "sealed-unrenamed":
			errors.append("sealed stream still named .part: the rename never happened")
	if out.status == "complete" and decode:
		var seal: Dictionary = out.seal
		var count := (out.columns.tick as PackedInt32Array).size()
		if int((seal.get("counts", {}) as Dictionary).get("ticks", -1)) != count:
			errors.append("seal counts %s ticks, the stream holds %d" % [str((seal.get("counts", {}) as Dictionary).get("ticks")), count])
			out.status = "partial"
	out.ok = out.status == "complete" and errors.is_empty()
	return out

## column name -> bytes per row, in payload order. vectors are three little-endian float32 (x, y, z).
const TICK_LAYOUT := [["tick", 4], ["flags", 4], ["dt", 8], ["elapsed", 8], ["physics_hz", 4], ["checkpoint", 4], ["respawns", 4],
	["p", 12], ["reference_p", 12], ["v", 12], ["actual_v", 12], ["yaw", 8], ["pitch", 8], ["held", 8]]
const INPUT_LAYOUT := [["tick", 4], ["kind", 4], ["flags", 4], ["code", 8], ["aux", 8], ["x", 4], ["y", 4], ["x2", 4], ["y2", 4]]
const TYPES := {"tick": "i32", "flags": "i32", "dt": "f64", "elapsed": "f64", "physics_hz": "i32", "checkpoint": "i32", "respawns": "i32",
	"p": "vec3", "reference_p": "vec3", "v": "vec3", "actual_v": "vec3", "yaw": "f64", "pitch": "f64", "held": "i64"}
const INPUT_TYPES := {"tick": "i32", "kind": "i32", "flags": "i32", "code": "i64", "aux": "i64", "x": "f32", "y": "f32", "x2": "f32", "y2": "f32"}

static func _row_size(layout: Array) -> int:
	var row := 0
	for item: Array in layout:
		row += int(item[1])
	return row

static func _empty_bytes(layout: Array) -> Dictionary:
	var out := {}
	for item: Array in layout:
		out[item[0]] = PackedByteArray()
	return out

static func _convert(bytes: Dictionary, types: Dictionary) -> Dictionary:
	var out := {}
	for name: String in bytes:
		var raw: PackedByteArray = bytes[name]
		match str(types[name]):
			"i32":
				out[name] = raw.to_int32_array()
			"i64":
				out[name] = raw.to_int64_array()
			"f32":
				out[name] = raw.to_float32_array()
			"f64":
				out[name] = raw.to_float64_array()
			"vec3":
				var flat := raw.to_float32_array()
				var vecs := PackedVector3Array()
				vecs.resize(flat.size() / 3)
				for i: int in vecs.size():
					vecs[i] = Vector3(flat[i * 3], flat[i * 3 + 1], flat[i * 3 + 2])
				out[name] = vecs
	return out

## TICKS payload: u32 n; n-row columns; u32 m; m-row input columns; u32 j; j bytes of JSON events.
## the chunk's bytes join `columns`/`inputs` (name -> PackedByteArray) only when all of it decodes.
static func _decode_ticks(raw: PackedByteArray, first_tick: int, tick_count: int, columns: Dictionary, inputs: Dictionary, events: Array) -> String:
	if raw.size() < 4:
		return "payload shorter than its count"
	var n := raw.decode_u32(0)
	var row := _row_size(TICK_LAYOUT)
	if n != tick_count or n > MAX_CHUNK_RAW / row:
		return "tick count %d disagrees with the head (%d)" % [n, tick_count]
	var at := 4
	if at + n * row + 4 > raw.size():
		return "tick columns are truncated"
	var fresh := {}
	for item: Array in TICK_LAYOUT:
		fresh[item[0]] = raw.slice(at, at + n * int(item[1]))
		at += n * int(item[1])
	if n > 0 and (fresh.tick as PackedByteArray).decode_s32(0) != first_tick:
		return "first tick %d disagrees with the head (%d)" % [(fresh.tick as PackedByteArray).decode_s32(0), first_tick]
	var m := raw.decode_u32(at)
	at += 4
	if m > MAX_CHUNK_RAW / INPUT_ROW or at + m * INPUT_ROW + 4 > raw.size():
		return "input columns are truncated"
	var fresh_inputs := {}
	for item: Array in INPUT_LAYOUT:
		fresh_inputs[item[0]] = raw.slice(at, at + m * int(item[1]))
		at += m * int(item[1])
	var j := raw.decode_u32(at)
	at += 4
	if at + j != raw.size():
		return "event section is %d bytes, the payload leaves %d" % [j, raw.size() - at]
	var parsed: Variant = JSON.parse_string(raw.slice(at, at + j).get_string_from_utf8()) if j > 0 else []
	if not parsed is Array:
		return "event section is not a JSON array"
	for item: Variant in parsed:
		if not item is Dictionary:
			return "event section holds a non-object"
	for name: String in fresh:
		columns[name] = (columns[name] as PackedByteArray) + (fresh[name] as PackedByteArray)
	for name: String in fresh_inputs:
		inputs[name] = (inputs[name] as PackedByteArray) + (fresh_inputs[name] as PackedByteArray)
	events.append_array(parsed)
	return ""

## the exact identity comparison a ghost uses: equal JSON-normalized dictionaries, non-empty and
## naming at least the map and the preset.
static func identity_matches(recorded: Variant, expected: Dictionary) -> String:
	if expected.is_empty() or not expected.has("map") or not expected.has("preset"):
		return "the expected identity must name at least map and preset"
	if not recorded is Dictionary:
		return "the recording has no identity"
	var a := JSON.stringify(_canon(json_safe(recorded)), "", true, true)
	var b := JSON.stringify(_canon(json_safe(expected)), "", true, true)
	if a != b:
		return "identity differs: recorded %s, expected %s" % [a.left(300), b.left(300)]
	return ""

## JSON numbers come back as floats; an integral float compares as the integer it was written as.
static func _canon(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floorf(value) and absf(value) < 9.0e15:
		return int(value)
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[str(key)] = _canon(value[key])
		return out
	if value is Array:
		var list: Array = []
		for item: Variant in value:
			list.append(_canon(item))
		return list
	return value

## whether a strictly read recording is a clean finished run (ghost material), and its time.
static func clean_finish(run: Dictionary) -> Dictionary:
	if not bool(run.get("ok", false)) or str(run.get("status", "")) != "complete":
		return {"ok": false, "error": "not a complete sealed recording (%s)" % str(run.get("status", ""))}
	var seal: Dictionary = run.seal
	var outcome: Variant = seal.get("outcome", {})
	var final: Variant = seal.get("final", {})
	if not outcome is Dictionary or str((outcome as Dictionary).get("kind", "")) != "finish" or not bool((outcome as Dictionary).get("clean", false)):
		return {"ok": false, "error": "the outcome is not a clean finish"}
	if not final is Dictionary or not bool((final as Dictionary).get("finished", false)) or not bool((final as Dictionary).get("clean", false)) or int((final as Dictionary).get("respawns", 1)) != 0:
		return {"ok": false, "error": "the last sample is not a clean finished state"}
	if int(seal.get("timer_start_tick", -1)) < 0 or int(seal.get("finish_tick", -1)) < 0:
		return {"ok": false, "error": "the run has no timer start or finish line tick"}
	return {"ok": true, "time": float((final as Dictionary).get("elapsed", 0.0))}

## fastest clean complete run in a directory for this identity, by the recorded course clock.
## every candidate is fully verified (chain and seal); ties keep the earlier file name.
static func fastest_clean(directory: String, expected_identity: Dictionary) -> Dictionary:
	var dir := ProjectSettings.globalize_path(directory)
	var best := {"ok": false, "path": "", "time": INF, "considered": 0, "rejected": []}
	var names := DirAccess.get_files_at(dir)
	names.sort()
	for name: String in names:
		if not name.ends_with(SUFFIX):
			continue
		best.considered += 1
		var run := read(dir.path_join(name), false)
		var why := identity_matches(run.header.get("identity") if run.header is Dictionary else null, expected_identity) if run.ok else str(run.errors)
		var clean := clean_finish(run) if why.is_empty() else {"ok": false, "error": why}
		if not clean.ok:
			(best.rejected as Array).append({"path": name, "why": str(clean.error).left(200)})
			continue
		if float(clean.time) < float(best.time):
			best.time = float(clean.time)
			best.path = dir.path_join(name)
			best.ok = true
	return best

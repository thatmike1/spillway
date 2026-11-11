extends Node
## bounded data-only sharing around unchanged sealed r16 recordings. never owns local bests.

const READER := preload("res://scripts/r16_run_reader.gd")
const GHOST := preload("res://scripts/r16_ghost.gd")
const BUILD := "spillway-2026.11.11-r21"
const MAGIC := "SWGHOST1"
const SCHEMA := 1
const SUFFIX := ".spillghost"
const MAX_META := 4096
const MAX_RUN := 4 * 1024 * 1024
const MAX_DECODE := 12 * 1024 * 1024
const MAX_TICKS := 80000
const MAX_FILES := 64
const MAX_SCAN := 16 * 1024 * 1024
const MAX_EXPORT_FILES := 512
const MAX_EXPORT_SCAN := 64 * 1024 * 1024

var game: Node
var folder := ""
var storage := "user://r19_ghost_share"
## tests inject this before ready; production always asks the OS to open the canonical folder.
var folder_opener: Callable
var rows: Array[Dictionary] = []
var status := ""
var player_name := "Player"
var selected := ""
var active := ""
var friend: Node3D
var scan_count := 0
var read_count := 0
var _identity: Dictionary = {}

static func default_folder(release: bool, executable: String) -> String:
	return executable.get_base_dir().path_join("ghosts") if release else ProjectSettings.globalize_path("user://r19_ghosts")

func setup(host: Node, directory: String = "", state_directory: String = "") -> void:
	game = host
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not state_directory.is_empty():
		storage = state_directory
	storage = ProjectSettings.globalize_path(storage).simplify_path()
	folder = ProjectSettings.globalize_path(directory).simplify_path() if not directory.is_empty() else default_folder(OS.has_feature("template"), OS.get_executable_path())
	friend = GHOST.new()
	friend.name = "FriendGhost"
	add_child(friend)
	var prefs: Variant = _json(_read_file(storage.path_join("selection.json"), MAX_META).get_string_from_utf8())
	if prefs is Dictionary:
		player_name = clean_name(str(prefs.get("player", "Player")))
		var saved := str(prefs.get("selected", ""))
		if _filename(saved):
			selected = saved

static func _json(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null

static func clean_name(value: String) -> String:
	var result := ""
	for c: String in value.strip_edges().left(32):
		if c.unicode_at(0) >= 32 and c.unicode_at(0) != 127 and not c in ["\u202a", "\u202b", "\u202c", "\u202d", "\u202e", "\u2066", "\u2067", "\u2068", "\u2069"]:
			result += c
	return result.strip_edges()

static func _filename(value: String) -> bool:
	return not value.is_empty() and value == value.get_file() and not "/" in value and not "\\" in value and not ":" in value and value.ends_with(SUFFIX)

func _save_preferences() -> void:
	if DirAccess.make_dir_recursive_absolute(storage) != OK:
		status = "Could not save ghost selection. It stays in memory."
		return
	var file := FileAccess.open(storage.path_join("selection.json"), FileAccess.WRITE)
	if file == null:
		status = "Could not save ghost selection. It stays in memory."
		return
	file.store_string(JSON.stringify({"player": player_name, "selected": selected}))
	file.close()

func _ensure_folder() -> bool:
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		status = "Ghosts folder is not writable. Move the release to a writable folder."
		return false
	return true

func open_folder() -> void:
	if not _ensure_folder():
		return
	var error: int = folder_opener.call(folder) if folder_opener.is_valid() else OS.shell_open(folder)
	status = "Drop .spillghost files here, then Refresh." if error == OK else "Could not open the folder (%s). The path above can be copied." % error_string(error)

## preflight before the existing reader inflates anything: cumulative raw/tick/chunk limits.
static func run_bounds(raw: PackedByteArray) -> String:
	if raw.size() < 48 or raw.size() > MAX_RUN or raw.slice(0, 8).get_string_from_ascii() != READER.MAGIC:
		return "Recording size or magic is invalid"
	var at := 16 + raw.decode_u32(12) + 32
	if at > raw.size() or raw.decode_u32(12) > READER.MAX_HEADER:
		return "Recording header exceeds its bound"
	var total := 0
	var ticks := 0
	var chunks := 0
	while at < raw.size():
		if at + 60 > raw.size():
			return "Truncated recording chunk"
		var count := raw.decode_u32(at + 24)
		var stored := raw.decode_u32(at + 16)
		var decoded := raw.decode_u32(at + 12)
		total += decoded
		ticks += count
		chunks += 1
		if total > MAX_DECODE or ticks > MAX_TICKS or chunks > 512 or stored > MAX_RUN or decoded > READER.MAX_CHUNK_RAW:
			return "Recording decode budget exceeded"
		at += 60 + stored
	return "" if at == raw.size() else "Truncated recording payload"

static func verify_run(raw: PackedByteArray, identity: Dictionary = {}) -> Dictionary:
	var problem := run_bounds(raw)
	if not problem.is_empty():
		return {"ok": false, "note": problem}
	var run := READER.parse(raw, "shared.r16run", true)
	if not bool(run.ok):
		return {"ok": false, "note": "Invalid recording: " + str(run.errors).left(160)}
	if not identity.is_empty() and not READER.identity_matches(run.header.get("identity"), identity).is_empty():
		return {"ok": false, "note": "Different map revision, preset or movement identity"}
	var clean := READER.clean_finish(run)
	if not bool(clean.ok):
		return {"ok": false, "note": "Not a verified clean finish: " + str(clean.error)}
	if not run.header.get("identity") is Dictionary or not run.header.identity.has_all(["map", "preset", "geometry", "course_key", "physics_hz", "motor", "runner", "timing", "overlay", "format"]):
		return {"ok": false, "note": "Missing motion identity fields"}
	var motion: Dictionary = run.header.identity
	for key: String in ["map", "preset", "geometry", "course_key", "motor", "runner", "timing", "overlay", "format"]:
		if not motion[key] is String or str(motion[key]).is_empty() or str(motion[key]).length() > 256:
			return {"ok": false, "note": "Invalid motion identity field: " + key}
	if motion.format != "r16-motion-1" or typeof(motion.physics_hz) not in [TYPE_INT, TYPE_FLOAT] or motion.physics_hz != run.columns.physics_hz[0]:
		return {"ok": false, "note": "Motion identity version or physics rate differs from the recording"}
	var metadata: Variant = run.header.get("metadata", {})
	if not metadata is Dictionary:
		return {"ok": false, "note": "Missing recording build metadata"}
	return {"ok": true, "time": clean.time, "identity": run.header.identity, "build": str(metadata.get("build", "")), "raw": raw}

static func envelope(raw: PackedByteArray, name: String, build: String = BUILD) -> PackedByteArray:
	var meta := JSON.stringify({"format": "spillway-shared-ghost", "schema": SCHEMA, "build": build, "player": name}).to_utf8_buffer()
	var bytes := MAGIC.to_ascii_buffer()
	bytes.resize(16)
	bytes.encode_u32(8, meta.size())
	bytes.encode_u32(12, raw.size())
	bytes.append_array(meta)
	bytes.append_array(raw)
	return bytes

static func inspect(bytes: PackedByteArray) -> Dictionary:
	var bad := {"ok": false, "note": "Invalid ghost file", "player": "Unknown", "time": -1.0}
	if bytes.size() < 16 or bytes.size() > MAX_RUN + MAX_META + 16 or bytes.slice(0, 8).get_string_from_ascii() != MAGIC:
		return bad
	var meta_size := bytes.decode_u32(8)
	var raw_size := bytes.decode_u32(12)
	if meta_size > MAX_META or raw_size > MAX_RUN or 16 + meta_size + raw_size != bytes.size():
		bad.note = "Ghost file lengths exceed bounds or are truncated"
		return bad
	var meta: Variant = _json(bytes.slice(16, 16 + meta_size).get_string_from_utf8())
	if not meta is Dictionary or meta.get("format") != "spillway-shared-ghost" or not meta.get("player") is String or not meta.get("build") is String:
		return bad
	bad.player = clean_name(meta.player)
	if bad.player.is_empty() or meta.player != bad.player or str(meta.build).length() > 96:
		bad.note = "Invalid player name or build metadata"
		return bad
	if typeof(meta.get("schema")) not in [TYPE_INT, TYPE_FLOAT] or meta.schema != SCHEMA:
		bad.note = "Unsupported ghost schema; use the same game version"
		return bad
	var checked := verify_run(bytes.slice(16 + meta_size))
	if not bool(checked.ok):
		bad.note = checked.note
		return bad
	checked.player = meta.player
	checked.note = ""
	if meta.build != BUILD or checked.build != BUILD:
		checked.ok = false
		checked.note = "Different game version (%s / recording %s); use the same build" % [str(meta.build), str(checked.build)]
	return checked

func _read_file(path: String, limit: int) -> PackedByteArray:
	read_count += 1
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null or dir.is_link(path.get_file()):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > limit:
		return PackedByteArray()
	return file.get_buffer(file.get_length())

## an older PB must not prevent sharing the fastest clean run earned on this build.
## the export scan never promotes or replaces the local pointer.
func _export_candidate() -> Dictionary:
	var expected: Dictionary = game.call("motion_identity")
	var pointer := str(game.session.ghost_path)
	var raw := _read_file(pointer, MAX_RUN) if not pointer.is_empty() else PackedByteArray()
	var checked := verify_run(raw, expected)
	if bool(checked.ok) and str(checked.get("build", "")) == BUILD and int(game.session.ghost_ticks) == roundi(float(checked.time) * float(game.physics_hz)):
		return checked
	var directory := ProjectSettings.globalize_path(str(game.recordings_dir))
	var dir := DirAccess.open(directory)
	if dir == null:
		return {"ok": false}
	var best := {"ok": false}
	var bytes_read := 0
	var entries := 0
	dir.list_dir_begin()
	var filename := dir.get_next()
	while not filename.is_empty():
		entries += 1
		if entries > MAX_EXPORT_FILES or bytes_read >= MAX_EXPORT_SCAN:
			dir.list_dir_end()
			return {"ok": false, "note": "Too many local recordings to verify an R19 best. Archive older runs outside the recordings folder, then export again."}
		if filename.ends_with(READER.SUFFIX) and not dir.current_is_dir() and not dir.is_link(filename):
			raw = _read_file(directory.path_join(filename), mini(MAX_RUN, MAX_EXPORT_SCAN - bytes_read))
			bytes_read += raw.size()
			if run_bounds(raw).is_empty():
				var summary := READER.parse(raw, filename, false)
				var meta: Variant = summary.header.get("metadata", {})
				if bool(summary.ok) and meta is Dictionary and meta.get("build") == BUILD and READER.identity_matches(summary.header.get("identity"), expected).is_empty():
					checked = verify_run(raw, expected)
					if bool(checked.ok) and (not bool(best.ok) or float(checked.time) < float(best.time)):
						best = checked
		filename = dir.get_next()
	dir.list_dir_end()
	return best

func export_best(name: String) -> Dictionary:
	player_name = clean_name(name)
	if player_name.is_empty():
		status = "Enter a player name (1 to 32 characters)."
		return {"ok": false}
	_save_preferences()
	var checked := _export_candidate()
	if not bool(checked.ok):
		status = str(checked.get("note", "No verified clean best from this build for this exact map and preset. Finish a clean run first."))
		return {"ok": false}
	if not _ensure_folder():
		return {"ok": false}
	var filename := "spillway-%s-%s" % [str(game.map_id).validate_filename(), Crypto.new().generate_random_bytes(12).hex_encode()] + SUFFIX
	var target := folder.path_join(filename)
	if FileAccess.file_exists(target):
		status = "Export name already exists; nothing was overwritten. Try again."
		return {"ok": false}
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		status = "Could not write the export. Move the release to a writable folder."
		return {"ok": false}
	var bytes := envelope(checked.raw, player_name)
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or _read_file(target, MAX_RUN + MAX_META + 16) != bytes:
		status = "Export failed verification; this file must not be shared."
		return {"ok": false}
	status = "Exported %s. Send this one file to your friend." % filename
	return {"ok": true, "path": target}

func scan() -> void:
	scan_count += 1
	rows.clear()
	if not _ensure_folder():
		return
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	dir.list_dir_begin()
	var bytes_read := 0
	var entries := 0
	var filename := dir.get_next()
	while not filename.is_empty():
		entries += 1
		if entries > 1024 or rows.size() >= MAX_FILES or bytes_read >= MAX_SCAN:
			status = "Folder scan limit reached. Keep at most 64 ghost files here and Refresh."
			break
		if _filename(filename) and not dir.current_is_dir():
			var bytes := _read_file(folder.path_join(filename), mini(MAX_RUN + MAX_META + 16, MAX_SCAN - bytes_read))
			bytes_read += bytes.size()
			var row := inspect(bytes)
			row.erase("raw")
			row.digest = READER.sha256(bytes).hex_encode()
			row.file = filename
			rows.append(row)
		filename = dir.get_next()
	dir.list_dir_end()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.file) < str(b.file))
	sync_identity()

func note_for(row: Dictionary) -> String:
	if not bool(row.ok):
		return str(row.note)
	if not READER.identity_matches(row.identity, _identity).is_empty():
		return "Different map revision, map or preset. Switch to its matching course to race."
	return "Ready to race"

## a preset can settle inside physics. suspend immediately, then read outside the physics step.
func identity_changed() -> void:
	_identity = game.call("motion_identity")
	active = ""
	if friend != null:
		friend.call("clear")
	sync_identity.call_deferred()

func sync_identity() -> void:
	_identity = game.call("motion_identity")
	active = ""
	if friend == null:
		return
	friend.call("clear")
	if selected.is_empty():
		return
	for row: Dictionary in rows:
		if str(row.file) == selected and note_for(row) == "Ready to race":
			_activate(row)
			return

func choose(filename: String) -> void:
	if filename.is_empty():
		selected = ""
		active = ""
		friend.call("clear")
		_save_preferences()
		status = "Racing your local best again. G shows or hides it."
		return
	if not _filename(filename):
		return
	for row: Dictionary in rows:
		if str(row.file) == filename and note_for(row) == "Ready to race":
			if _activate(row):
				selected = filename
				_save_preferences()
				status = "Racing %s. G shows or hides the chosen ghost." % str(row.player)
			return

func _activate(row: Dictionary) -> bool:
	var bytes := _read_file(folder.path_join(str(row.file)), MAX_RUN + MAX_META + 16)
	var checked := inspect(bytes)
	if READER.sha256(bytes).hex_encode() != str(row.get("digest", "")) or not bool(checked.ok) or not READER.identity_matches(checked.get("identity"), _identity).is_empty():
		status = "Chosen file changed or no longer matches. Refresh the folder."
		return false
	var raw: PackedByteArray = checked.raw
	var cache := storage.path_join("cache")
	if DirAccess.make_dir_recursive_absolute(cache) != OK:
		status = "Could not prepare the ghost cache."
		return false
	var target := cache.path_join(READER.sha256(raw).hex_encode() + ".r16run")
	if FileAccess.file_exists(target):
		if _read_file(target, MAX_RUN) != raw:
			status = "Ghost cache conflict; nothing was overwritten."
			return false
	else:
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			status = "Could not cache the chosen ghost."
			return false
		file.store_buffer(raw)
		file.close()
	active = ""
	var loaded: Dictionary = friend.call("load_run", target, _identity)
	if not bool(loaded.ok):
		status = "Chosen ghost could not be loaded: " + str(loaded.get("error", ""))
		return false
	active = str(row.file)
	return true

func _process(_delta: float) -> void:
	if friend == null:
		return
	friend.visible = not active.is_empty() and bool(game.settings.ghost) and int(game.practice_stage) <= 0
	if friend.visible:
		var fraction := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
		friend.call("set_time", lerpf(float(game.session.get("_clock_prev")), float(game.session.get("_clock_cur")), fraction))

extends RefCounted
## local, bounded, data-only run collection. construction and setup never write files.
const FORMAT := "spillway-run-bundle"
const SCHEMA := 1
const MAX_FILES := 4096
const MAX_FILE := 64 * 1024 * 1024
const MAX_TOTAL := 512 * 1024 * 1024
const MAX_MANIFEST := 1024 * 1024
const CHUNK := 64 * 1024
const SAFETY_MARGIN := 16 * 1024 * 1024
const SETTINGS := ["spillway_r12.cfg", "spillway_r13.cfg", "spillway_r15.cfg", "spillway_r16.cfg", "spillway_v1.cfg"]
var folder_opener: Callable
var free_space_probe: Callable
## fault/race seams used only by isolated fixtures, never read from imported data.
var before_copy: Callable
var fail_after_bytes := -1
var _written := 0
var _scanned := 0
var _source_bytes := 0
var _error := ""

static func safe_name(path: String) -> bool:
	if path.is_empty() or path.to_utf8_buffer().size() > 240 or path.begins_with("/") or "\\" in path or ":" in path:
		return false
	for ch: String in path:
		if ch.unicode_at(0) < 32 or (ch.unicode_at(0) >= 127 and ch.unicode_at(0) <= 159) or ch in ['<', '>', '"', '|', '?', '*']:
			return false
	for part: String in path.split("/"):
		if part in ["", ".", ".."] or part.ends_with(".") or part.ends_with(" "):
			return false
		var stem := part.get_slice(".", 0).to_upper()
		if stem in ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]:
			return false
	return true

static func hash_bytes(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		hash.update(bytes)
	return hash.finish().hex_encode()

static func slug(label: String) -> String:
	var out := ""
	for ch: String in label.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "-"
	return out.left(40) if not out.is_empty() else "player"

func _bad(text: String) -> Dictionary:
	_error = text
	return {"ok": false, "error": text}

func _hash(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _bad("Cannot read %s: %s" % [path.get_file(), error_string(FileAccess.get_open_error())])
	var size := f.get_length()
	if size > MAX_FILE:
		f.close()
		return _bad("File exceeds 64 MiB: " + path.get_file())
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	var count := 0
	while count < size:
		var bytes := f.get_buffer(mini(CHUNK, size - count))
		if bytes.is_empty() or hash.update(bytes) != OK:
			f.close()
			return _bad("Read/hash failed: " + path.get_file())
		count += bytes.size()
	if count != size or f.get_length() != size or f.get_error() != OK:
		f.close()
		return _bad("File changed or read failed: " + path.get_file())
	f.close()
	return {"ok": true, "size": size, "sha256": hash.finish().hex_encode()}

func _add(rows: Array, path: String, relative: String) -> bool:
	if rows.size() >= MAX_FILES or not safe_name(relative):
		_error = "Too many files (4096 maximum), or unsafe filename: " + relative
		return false
	var parent := DirAccess.open(path.get_base_dir())
	if parent == null or parent.is_link(path.get_file()):
		_error = "Linked/unreadable source refused: " + relative
		return false
	var info := _hash(path)
	if not info.ok:
		return false
	_source_bytes += int(info.size)
	if _source_bytes > MAX_TOTAL:
		_error = "Collection exceeds 512 MiB. No files were omitted."
		return false
	rows.append({"path": relative, "source": path, "size": info.size, "sha256": info.sha256})
	return true

func _walk(rows: Array, root: String, relative := "", depth := 0) -> bool:
	if depth > 12:
		_error = "Recording folder nesting exceeds 12 levels."
		return false
	var dir := DirAccess.open(root.path_join(relative))
	if dir == null:
		_error = "Cannot read recording folder."
		return false
	if dir.list_dir_begin() != OK:
		_error = "Cannot list recording folder."
		return false
	var names: Array[String] = []
	var name := dir.get_next()
	while not name.is_empty():
		if names.size() >= MAX_FILES:
			_error = "Recording folder exceeds 4096 entries. No files were omitted."
			dir.list_dir_end()
			return false
		_scanned += 1
		if _scanned > MAX_FILES:
			_error = "Recording tree exceeds 4096 entries. No files were omitted."
			dir.list_dir_end()
			return false
		names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for child: String in names:
		var rel := relative.path_join(child) if not relative.is_empty() else child
		if not safe_name(rel) or dir.is_link(child):
			_error = "Unsafe/linked recording entry: " + rel
			return false
		if dir.dir_exists(child):
			if not _walk(rows, root, rel, depth + 1):
				return false
		elif child.ends_with(".r16run") or child.ends_with(".part") or child.ends_with(".aborted"):
			if not _add(rows, root.path_join(rel), "recordings/" + rel):
				return false
	return true

func inventory(directory: String, settings_root: String, profile: String) -> Dictionary:
	_error = ""
	_scanned = 0
	_source_bytes = 0
	var rows: Array = []
	var root := ProjectSettings.globalize_path(directory).simplify_path()
	if not directory.is_empty() and DirAccess.dir_exists_absolute(root):
		if not _walk(rows, root):
			return _bad(_error)
	for name: String in SETTINGS:
		var path := settings_root.path_join(name)
		if FileAccess.file_exists(path) and not _add(rows, path, "settings/" + name):
			return _bad(_error)
	var current := ProjectSettings.globalize_path(profile).simplify_path()
	var profile_member := ""
	if not profile.is_empty() and FileAccess.file_exists(current):
		for row: Dictionary in rows:
			if row.source == current:
				profile_member = row.path
		if profile_member.is_empty():
			profile_member = "settings/current-profile.cfg"
			if not _add(rows, current, profile_member):
				return _bad(_error)
	var total := 0
	var seen := {}
	for row: Dictionary in rows:
		total += int(row.size)
		if seen.has(str(row.path).to_lower()):
			return _bad("Colliding filenames: " + str(row.path))
		seen[str(row.path).to_lower()] = true
	if total > MAX_TOTAL or rows.size() >= MAX_FILES:
		return _bad("Collection exceeds 512 MiB / 4096 files. No files were omitted.")
	return {"ok": true, "rows": rows, "total": total, "profile": profile_member}

## explicit bridge to the unchanged frozen recorder; callers must already pause gameplay.
func flush_open_attempt(recorder: RefCounted) -> Dictionary:
	if recorder == null or not recorder.is_open():
		return {"ok": true}
	if not recorder.call("_flush_ticks") or not recorder.is_open():
		return _bad("Active recording could not be flushed: " + str(recorder.last_error))
	return {"ok": true}

func _write(zip: ZIPPacker, bytes: PackedByteArray) -> bool:
	if fail_after_bytes >= 0 and _written + bytes.size() > fail_after_bytes:
		_error = "Injected archive write failure."
		return false
	var err := zip.write_file(bytes)
	_written += bytes.size()
	if err != OK:
		_error = "Archive write failed: " + error_string(err)
	return err == OK

func _entry(zip: ZIPPacker, row: Dictionary) -> bool:
	if zip.start_file(row.path) != OK:
		_error = "Cannot start archive member: " + str(row.path)
		return false
	var f := FileAccess.open(row.source, FileAccess.READ)
	var good := f != null
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	var count := 0
	if good:
		good = f.get_length() == int(row.size)
	while good and count < int(row.size):
		var bytes := f.get_buffer(mini(CHUNK, int(row.size) - count))
		good = not bytes.is_empty() and hash.update(bytes) == OK and _write(zip, bytes)
		count += bytes.size()
	if f != null:
		good = good and f.get_length() == int(row.size) and f.get_error() == OK
		f.close()
	good = good and count == int(row.size) and hash.finish().hex_encode() == row.sha256
	var closed := zip.close_file()
	if not good or closed != OK:
		_error = "Source changed or archive I/O failed: " + str(row.path) + ("; " + _error if not _error.is_empty() else "")
	return good and closed == OK

## level zero uses RFC1951 stored Deflate blocks in pinned Godot (ZIP method 8).
## read them directly so verification never inflates or buffers a whole recording.
func _verify_payload(f: FileAccess, stored: int, raw: int, method: int, expected: String) -> bool:
	var end := f.get_position() + stored
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	var count := 0
	var final := false
	while not final:
		var length := raw
		if method == 8:
			if f.get_position() + 5 > end:
				return false
			var block := f.get_buffer(5)
			if block.size() != 5 or block[0] & 0xfe != 0:
				return false
			final = block[0] & 1 != 0
			length = block.decode_u16(1)
			if length ^ block.decode_u16(3) != 0xffff:
				return false
		else:
			final = true
		if f.get_position() + length > end or count + length > raw:
			return false
		var remaining := length
		while remaining > 0:
			var bytes := f.get_buffer(mini(CHUNK, remaining))
			if bytes.is_empty() or hash.update(bytes) != OK:
				return false
			remaining -= bytes.size()
			count += bytes.size()
	return f.get_position() == end and count == raw and hash.finish().hex_encode() == expected

## minizip can return OK after an OS short write. independently read the level-zero ZIP
## with bounded buffers, matching every payload hash and central/local header before publish.
func _verify_archive(path: String, entries: Array, manifest: PackedByteArray) -> bool:
	var expected := {"manifest.json": {"size": manifest.size(), "sha256": hash_bytes(manifest)}}
	var directories := {}
	for entry: Dictionary in entries:
		expected[entry.path] = entry
		var parent: String = str(entry.path).get_base_dir()
		while not parent.is_empty() and parent != ".":
			directories[parent + "/"] = true
			parent = parent.get_base_dir()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var length := f.get_length()
	if length > MAX_TOTAL + 8 * 1024 * 1024:
		f.close()
		return false
	var local := {}
	var good := true
	var central_at := -1
	while good and f.get_position() + 4 <= length:
		var offset := f.get_position()
		var head := f.get_buffer(30)
		if head.size() < 30:
			good = false
			break
		if head.decode_u32(0) == 0x02014b50:
			central_at = offset
			f.seek(offset)
			break
		if head.decode_u32(0) != 0x04034b50:
			good = false
			break
		var flags := head.decode_u16(6)
		var method := head.decode_u16(8)
		var crc := head.decode_u32(14)
		var stored := head.decode_u32(18)
		var raw := head.decode_u32(22)
		var name_size := head.decode_u16(26)
		var extra := head.decode_u16(28)
		if flags & 9 != 0 or method not in [0, 8] or stored > raw + CHUNK or raw > MAX_FILE or name_size > 240 or f.get_position() + name_size + extra + raw > length:
			good = false
			break
		var name := f.get_buffer(name_size).get_string_from_utf8()
		f.seek(f.get_position() + extra)
		if local.has(name) or local.size() >= MAX_FILES * 2 + 1:
			good = false
			break
		local[name] = {"offset": offset, "flags": flags, "method": method, "crc": crc, "raw": raw, "stored": stored}
		var expected_hash := hash_bytes(PackedByteArray())
		if name.ends_with("/"):
			good = directories.has(name) and raw == 0 and crc == 0
		else:
			if not expected.has(name) or raw != int(expected[name].size):
				good = false
				break
			expected_hash = expected[name].sha256
		good = good and _verify_payload(f, stored, raw, method, expected_hash)
	var central := {}
	while good and central_at >= 0 and f.get_position() + 4 <= length:
		var offset := f.get_position()
		var magic := f.get_buffer(4).decode_u32(0)
		f.seek(offset)
		if magic == 0x06054b50:
			break
		var head := f.get_buffer(46)
		if head.size() != 46 or magic != 0x02014b50:
			good = false
			break
		var name_size := head.decode_u16(28)
		var extra := head.decode_u16(30)
		var comment := head.decode_u16(32)
		if name_size > 240 or f.get_position() + name_size + extra + comment > length:
			good = false
			break
		var name := f.get_buffer(name_size).get_string_from_utf8()
		f.seek(f.get_position() + extra + comment)
		if not local.has(name) or central.has(name):
			good = false
			break
		central[name] = true
		var info: Dictionary = local[name]
		good = head.decode_u16(8) == int(info.flags) and head.decode_u16(10) == int(info.method) and head.decode_u32(16) == int(info.crc) and head.decode_u32(20) == int(info.stored) and head.decode_u32(24) == int(info.raw) and head.decode_u32(42) == int(info.offset) and head.decode_u16(34) == 0
	var end_at := f.get_position()
	var end := f.get_buffer(22)
	good = good and end.size() == 22
	if good:
		good = end.decode_u32(0) == 0x06054b50 and end.decode_u16(4) == 0 and end.decode_u16(6) == 0 and end.decode_u16(8) == local.size() and end.decode_u16(10) == local.size() and end.decode_u32(12) == end_at - central_at and end.decode_u32(16) == central_at and end.decode_u16(20) == 0 and f.get_position() == length and central.size() == local.size() and f.get_error() == OK
		for name: String in expected:
			good = good and local.has(name)
	f.close()
	return good

func _space(path: String) -> int:
	if free_space_probe.is_valid():
		return int(free_space_probe.call(path))
	var dir := DirAccess.open(path)
	return -1 if dir == null else dir.get_space_left()

func open_folder(folder: String) -> int:
	return int(folder_opener.call(folder)) if folder_opener.is_valid() else OS.shell_open(folder)

func collect(directory: String, settings_root: String, profile: String, effective_settings: Dictionary, output: String, label: String, build: String) -> Dictionary:
	_error = ""
	_written = 0
	for ch: String in label:
		if ch.unicode_at(0) < 32 or (ch.unicode_at(0) >= 127 and ch.unicode_at(0) <= 159):
			return _bad("Player name contains a control character.")
	if label.strip_edges().is_empty() or label.length() > 64 or label.contains("\n") or label.contains("\r"):
		return _bad("Enter a player name (1–64 characters).")
	var listing := inventory(directory, settings_root, profile)
	if not listing.ok:
		return listing
	var live := JSON.stringify({"format": "spillway-effective-settings", "schema": 1, "settings": effective_settings}, "", true, true).to_utf8_buffer()
	if live.size() > MAX_MANIFEST or int(listing.total) + live.size() > MAX_TOTAL:
		return _bad("Settings/collection exceed bundle bounds.")
	var estimate: int = int(listing.total) + live.size() + MAX_MANIFEST + (listing.rows.size() + 2) * 1024
	var folder := ProjectSettings.globalize_path(output)
	var volume := folder
	while not DirAccess.dir_exists_absolute(volume) and volume != volume.get_base_dir():
		volume = volume.get_base_dir()
	if _space(volume) < estimate + SAFETY_MARGIN:
		return _bad("Not enough space on the export volume: need %d bytes plus 16 MiB safety margin. Nothing was exported." % estimate)
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return _bad("Cannot create export folder: " + folder)
	if _space(folder) < estimate + SAFETY_MARGIN:
		return _bad("Not enough space on the export volume.")
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var basename := "Spillway-runs-%s-%s-%08x.zip" % [slug(label), stamp, randi()]
	var target := folder.path_join(basename)
	var temporary := target + ".partial"
	if FileAccess.file_exists(target) or FileAccess.file_exists(temporary):
		return _bad("Export filename collision; try again.")
	var entries: Array = []
	for row: Dictionary in listing.rows:
		entries.append({"path": row.path, "size": row.size, "sha256": row.sha256})
	entries.append({"path": "settings/effective-settings.json", "size": live.size(), "sha256": hash_bytes(live)})
	var manifest := {"format": FORMAT, "schema": SCHEMA, "player": label.strip_edges(), "build": build, "created_utc": Time.get_datetime_string_from_system(true) + "Z", "current_profile": listing.profile, "entries": entries}
	var text := JSON.stringify(manifest, "", true, true).to_utf8_buffer()
	if text.size() > MAX_MANIFEST:
		return _bad("Manifest exceeds 1 MiB.")
	var zip := ZIPPacker.new()
	zip.compression_level = ZIPPacker.COMPRESSION_NONE
	var opened := zip.open(temporary)
	if opened != OK:
		DirAccess.remove_absolute(temporary)
		return _bad("Cannot open ZIP: " + error_string(opened))
	var good := true
	if before_copy.is_valid():
		before_copy.call()
	for row: Dictionary in listing.rows:
		if not _entry(zip, row):
			good = false
			break
	if good:
		good = zip.start_file("settings/effective-settings.json") == OK
		if good:
			good = _write(zip, live)
			good = zip.close_file() == OK and good
	if good:
		good = zip.start_file("manifest.json") == OK
		if good:
			good = _write(zip, text)
			good = zip.close_file() == OK and good
	var closed := zip.close()
	good = good and closed == OK and _verify_archive(temporary, entries, text)
	var after := inventory(directory, settings_root, profile)
	good = good and after.ok and after.get("rows") == listing.rows
	if not good:
		DirAccess.remove_absolute(temporary)
		return _bad("Export failed; incomplete ZIP removed. " + (_error if not _error.is_empty() else "Source inventory changed, archive verification failed, or ZIP I/O failed."))
	var renamed := DirAccess.rename_absolute(temporary, target)
	if renamed != OK:
		DirAccess.remove_absolute(temporary)
		return _bad("Could not publish ZIP: " + error_string(renamed))
	var result := {"ok": true, "path": target, "folder": folder, "files": entries.size(), "bytes": int(listing.total) + live.size(), "manifest": manifest}
	var code := open_folder(folder)
	result["folder_opened"] = code == OK
	result["message"] = ("Exported %d files. Send this ZIP to Mike." % entries.size()) if code == OK else "ZIP saved. Folder could not open (%s). Select the path below and copy it, or retry Open folder." % error_string(code)
	return result

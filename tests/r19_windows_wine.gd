extends Node
## data/service fixture only: no game movement, input route or native windows claim.

class Host extends Node:
	var identity: Dictionary
	var map_id := ""
	var physics_hz := 128
	var recordings_dir := ""
	var settings := {"ghost": true}
	var practice_stage := 0
	var session := {"ghost_path": "", "ghost_ticks": 0, "_clock_prev": 0.0, "_clock_cur": 0.0}
	func motion_identity() -> Dictionary:
		return identity

var checks: Array[Dictionary] = []
var opts: Dictionary = {}
var opened: Array[String] = []
var share_script: Script
var reader: Script

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var split := arg.trim_prefix("--").split("=", true, 1)
			opts[split[0]] = split[1]
	_main.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"name": label, "ok": ok, "detail": str(detail).left(600)})
	if not ok:
		printerr("FAIL ", label, ": ", detail)

func put(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check("write opens", file != null, path)
	if file != null:
		file.store_buffer(bytes)
		file.close()

func columns_digest(columns: Dictionary, layout: Array) -> String:
	var bytes := PackedByteArray()
	for item: Array in layout:
		bytes.append_array(columns[item[0]].to_byte_array())
	return reader.sha256(bytes).hex_encode()

func _main() -> void:
	var out: String = opts["out"]
	DirAccess.make_dir_recursive_absolute(out)
	share_script = load("res://scripts/r19_ghost_share.gd")
	reader = load("res://scripts/r16_run_reader.gd")
	check("actual service and reader load", share_script != null and reader != null)
	if share_script == null or reader == null:
		get_tree().quit(1)
		return
	check("expected OS", OS.get_name() == opts["expect-os"], OS.get_name())
	check("release template feature", OS.has_feature("template") == (opts["expect-os"] == "Windows"), OS.has_feature("template"))
	var raw := FileAccess.get_file_as_bytes(opts["input"])
	var verified: Dictionary = share_script.verify_run(raw)
	check("sealed source recording accepted", bool(verified.get("ok", false)), verified.get("note"))
	if not bool(verified.get("ok", false)):
		put(out.path_join("report.json"), JSON.stringify({"ok": false, "checks": checks}).to_utf8_buffer())
		get_tree().quit(1)
		return
	var parsed: Dictionary = reader.parse(raw, "input.r16run", true)
	var host := Host.new()
	host.identity = verified.identity.duplicate(true)
	host.map_id = str(host.identity.map)
	host.physics_hz = int(host.identity.physics_hz)
	host.recordings_dir = out.path_join("empty-recordings")
	host.session.ghost_path = opts["input"]
	host.session.ghost_ticks = roundi(float(verified.time) * host.physics_hz)
	get_tree().root.add_child(host)
	var service: Node = share_script.new()
	host.add_child(service)
	service.folder_opener = func(path: String) -> int:
		opened.append(path)
		return OK
	# use setup's actual default on windows; linux editor has a private explicit directory.
	var directory := "" if OS.get_name() == "Windows" else out.path_join("ghosts")
	service.setup(host, directory, out.path_join("state"))
	service.open_folder()
	check("injected opener receives canonical folder only", opened == [service.folder], opened)
	if OS.get_name() == "Windows":
		check("windows release default folder beside executable", service.folder == OS.get_executable_path().get_base_dir().path_join("ghosts"), service.folder)
	var exported: Dictionary = service.export_best("Jindra Žluťoučký")
	check("actual service exports Unicode name", bool(exported.ok), service.status)
	var envelope := PackedByteArray()
	if bool(exported.ok):
		envelope = FileAccess.get_file_as_bytes(exported.path)
		put(out.path_join("export.spillghost"), envelope)
		var decoded: Dictionary = share_script.inspect(envelope)
		check("export retains exact sealed bytes identity time and name", bool(decoded.ok) and decoded.raw == raw and decoded.identity == verified.identity and decoded.time == verified.time and decoded.player == "Jindra Žluťoučký", decoded.get("note"))
		put(service.folder.path_join("selected.spillghost"), envelope)
		service.scan()
		service.choose("selected.spillghost")
		check("actual imported ghost loads", service.active == "selected.spillghost" and service.friend.loaded, service.status)
		var restored: Node = share_script.new()
		host.add_child(restored)
		restored.setup(host, service.folder, out.path_join("state"))
		restored.scan()
		check("selected friend persists and reactivates", restored.selected == "selected.spillghost" and restored.active == "selected.spillghost" and restored.player_name == "Jindra Žluťoučký", restored.status)
		restored.free()
		var other: Dictionary = share_script.inspect(share_script.envelope(raw, "Other", "different-game-version"))
		check("different build refused with service note", not bool(other.ok) and "Different game version" in str(other.note), other.note)
		host.identity.geometry = str(host.identity.geometry) + "-different"
		service.sync_identity()
		var revision_note := ""
		for row: Dictionary in service.rows:
			if row.file == "selected.spillghost":
				revision_note = service.note_for(row)
		check("different map revision refused with service note", service.active.is_empty() and "Different map revision" in revision_note, revision_note)
		host.identity = verified.identity.duplicate(true)
		service.sync_identity()
	if opts.has("incoming"):
		var incoming := FileAccess.get_file_as_bytes(opts.incoming)
		var received: Dictionary = share_script.inspect(incoming)
		check("other OS envelope preserves bytes identity time Unicode name", bool(received.get("ok", false)) and received.get("raw") == raw and received.get("identity") == verified.identity and received.get("time") == verified.time and received.get("player") == "Jindra Žluťoučký", received.get("note"))
		put(service.folder.path_join("other-os.spillghost"), incoming)
		service.scan()
		service.choose("other-os.spillghost")
		check("other OS envelope activates actual ghost", service.active == "other-os.spillghost" and service.friend.loaded, service.status)
	var corrupted := raw.duplicate()
	corrupted[corrupted.size() - 1] ^= 1
	var corrupt_result: Dictionary = share_script.verify_run(corrupted)
	check("corrupt sealed raw refuses hash chain", not bool(corrupt_result.get("ok", false)), corrupt_result.get("note"))
	var bad_lengths := envelope.duplicate()
	if bad_lengths.size() >= 16:
		bad_lengths.encode_u32(8, 0xffffffff)
	var malformed := [PackedByteArray(), "not a ghost".to_utf8_buffer(), envelope.slice(0, 15), envelope.slice(0, maxi(0, envelope.size() - 1)), bad_lengths]
	for i: int in malformed.size():
		var rejected: Dictionary = share_script.inspect(malformed[i])
		check("bounded malformed envelope refused %d" % i, not bool(rejected.get("ok", false)), rejected.get("note"))
	for n: int in [0, 15, 47, maxi(0, raw.size() - 1)]:
		var rejected: Dictionary = share_script.verify_run(raw.slice(0, n))
		check("bounded truncated raw refused %d" % n, not bool(rejected.get("ok", false)), rejected.get("note"))
	var c: Dictionary = parsed.columns
	var report_file := FileAccess.open(out.path_join("report.json"), FileAccess.WRITE)
	check("report output writable", report_file != null)
	var ok := true
	for item: Dictionary in checks:
		ok = ok and bool(item.ok)
	var report := {"ok": ok, "os": OS.get_name(), "engine": Engine.get_version_info(), "template": OS.has_feature("template"),
		"executable": OS.get_executable_path(), "default_folder": service.folder, "checks": checks,
		"recording": {"sha256": reader.sha256(raw).hex_encode(), "bytes": raw.size(), "identity": verified.identity,
			"time": verified.time, "ticks": c.tick.size(), "run_id": parsed.header.get("run_id"),
			"first_elapsed": c.elapsed[0], "last_elapsed": c.elapsed[-1], "build": verified.build,
			"columns_sha256": columns_digest(c, reader.TICK_LAYOUT),
			"inputs_sha256": columns_digest(parsed.inputs, reader.INPUT_LAYOUT)},
		"limits": ["service fixture host; no full game/menu execution", "Wine is not native Windows", "headless data test; no renderer or feel proof"]}
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	host.free()
	print("R19_WINDOWS_PROOF ", JSON.stringify({"ok": ok, "os": OS.get_name(), "checks": checks.size()}))
	get_tree().quit(0 if ok else 1)

extends "res://tests/r20_through_route.gd"
## actual production pause button during an earned route, then continued clean finish.
const EXPORT := preload("res://scripts/r20_run_export.gd")
const RECORDER := preload("res://scripts/r16_run_recorder.gd")
var checks: Array = []
var export_busy := false
var exported := false
var opener_calls: Array = []
var bundle := ""
var before_state := {}
var opener_success := false
var bundles: Array = []

func check(ok: bool, text: String) -> void:
	checks.append({"ok": ok, "check": text})
	print("ok " if ok else "FAIL ", text)

func _start() -> void:
	super()
	game.profile_path = out_dir.path_join("current.cfg")
	game.persist = true
	game.change_setting("volume", 0.37)
	game.run_export_directory = out_dir.path_join("exports")
	game.run_export_folder_opener = func(folder: String) -> int:
		opener_calls.append(folder)
		return OK if opener_success else ERR_UNAVAILABLE
	check(not DirAccess.dir_exists_absolute(game.run_export_directory), "startup creates no export folder or ZIP")
	for name: String in EXPORT.SETTINGS:
		var cfg := FileAccess.open(OS.get_user_data_dir().path_join(name), FileAccess.WRITE)
		cfg.store_string("[settings]\nfixture=true\n")
		cfg.close()
	var ignored := FileAccess.open(OS.get_user_data_dir().path_join("unrelated.txt"), FileAccess.WRITE)
	ignored.store_string("must not collect this")
	ignored.close()
	game.restart_run("restart")
	var recorder := RECORDER.new()
	var begun := recorder.begin_run(game.recording_metadata("empty"), game.recordings_dir)
	check(begun.ok, "real recorder creates a valid empty attempt")
	var empty := recorder.finish({"kind": "quit", "finished": false})
	check(empty.ok, "zero-sample quit is sealed data")
	var copy: String = game.recordings_dir.path_join("older-copied.r16run")
	check(DirAccess.copy_absolute(empty.path, copy) == OK, "older copied recording fixture")
	recorder.begin_run(game.recording_metadata("aborted"), game.recordings_dir)
	check(recorder.abort("fixture aborted").ok, "real recorder aborted fixture")
	var invalid := FileAccess.open(game.recordings_dir.path_join("malformed.r16run"), FileAccess.WRITE)
	invalid.store_buffer("not a recording; exact bytes must survive".to_utf8_buffer() + PackedByteArray([0, 255]))
	invalid.close()
	var broken_bytes := FileAccess.get_file_as_bytes(copy)
	broken_bytes[broken_bytes.size() - 1] ^= 1
	var broken := FileAccess.open(game.recordings_dir.path_join("damaged-seal.r16run"), FileAccess.WRITE)
	broken.store_buffer(broken_bytes)
	broken.close()
	var bytes := FileAccess.get_file_as_bytes(copy)
	bytes[8] = 99
	var unsupported := FileAccess.open(game.recordings_dir.path_join("unsupported.r16run"), FileAccess.WRITE)
	unsupported.store_buffer(bytes)
	unsupported.close()

func late_step() -> void:
	if not export_busy:
		super()

func _observe(tick: int) -> void:
	super(tick)
	if tick == 500 and not exported:
		export_busy = true
		exported = true
		exercise.call_deferred()

func state() -> Dictionary:
	return {"p": player.position, "v": player.velocity, "yaw": player.yaw, "pitch": player.pitch, "grounded": player.is_grounded(),
		"elapsed": game.elapsed, "checkpoint": game.checkpoint_index, "respawns": game.respawn_count, "attempts": game.attempts,
		"tick": game.session.tick, "motion_tick": player.motion_tick, "motion": player.get_motion_state().duplicate(true), "style": game.session.style.snapshot().duplicate(true),
		"pending": preload("res://scripts/r16_run_session.gd").describe_all(game.session.pending), "record_ticks": game.session.recorder.counts().ticks,
		"path": game.session.recorder.path, "run_id": game.session.recorder.run_id, "status": game.session.recorder.status}

func exercise() -> void:
	game.set_paused(true)
	await process_frame
	await process_frame
	before_state = state()
	var rec: RefCounted = game.session.recorder
	var tail: int = rec.get("_tick_col").size()
	check(tail > 0, "active recorder has unflushed live sample tail")
	var count: int = rec.counts().ticks
	var source: String = rec.path
	game.hud.export_name.text = "Autoplay Friend"
	var button: Button = game.hud.export_button
	check(button.text == "Export my runs" and button.is_visible_in_tree(), "actual visible production pause button")
	check(root.get_visible_rect().encloses(button.get_global_rect()), "export button inside 720px upper pause sheet")
	check(button.get_parent().get_parent().get_index() == game.hud.recording_line.get_index() + 1, "button directly follows recording note before maps/settings")
	var at := button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		root.push_input(click, true)
	await process_frame
	var result: Dictionary = game.last_run_export
	check(result.get("ok", false), "real GUI click calls service and publishes ZIP")
	if not result.get("ok", false):
		_write("export-checks.json", {"ok": false, "checks": checks, "result": result})
		game.request_quit(1)
		return
	bundle = result.path
	bundles.append(bundle)
	var zip := ZIPReader.new()
	check(zip.open(bundle) == OK, "Godot opens real service ZIP")
	var expected: Array = []
	for name: String in DirAccess.get_files_at(game.recordings_dir):
		var member := "recordings/" + name
		check(zip.read_file(member) == FileAccess.get_file_as_bytes(str(game.recordings_dir).path_join(name)), "every recording byte equals source: " + name)
		expected.append(member)
	for name: String in EXPORT.SETTINGS:
		var member := "settings/" + name
		check(zip.read_file(member) == FileAccess.get_file_as_bytes(OS.get_user_data_dir().path_join(name)), "every historical settings byte equals source: " + name)
		expected.append(member)
	check(zip.read_file("settings/current-profile.cfg") == FileAccess.get_file_as_bytes(game.profile_path), "actual current custom persisted profile exported exactly")
	var live: Dictionary = JSON.parse_string(zip.read_file("settings/effective-settings.json").get_string_from_utf8())
	check(live.settings == game.settings and float(live.settings.volume) == 0.37, "effective settings are actual current game values")
	for entry: Dictionary in result.manifest.entries:
		var bytes := zip.read_file(entry.path)
		check(bytes.size() == int(entry.size) and EXPORT.hash_bytes(bytes) == entry.sha256, "manifest size/hash matches exported bytes: " + str(entry.path))
	check(result.manifest.entries.size() == expected.size() + 2, "complete exact inventory without cache/log/unrelated data")
	zip.close()
	check(opener_calls.size() == 1 and opener_calls[0] == result.folder and not result.folder_opened, "injected opener receives actual production folder and failure is candid")
	check(game.hud.export_path.text == bundle and game.hud.export_path.visible and not game.hud.export_path.editable and game.hud.export_open.visible, "folder failure provides selectable copyable ZIP path and retry")
	check("could not open" in game.hud.export_status.text, "folder failure reported as failure to open, not export failure")
	check(state() == before_state, "export leaves entire paused physics/style/session/inputs/attempt unchanged")
	check(rec.is_open() and rec.path == source and rec.get("_tick_col").is_empty(), "flush empties only buffer, leaves same attempt open")
	var partial := READER.read(source)
	check(partial.status == "partial" and partial.columns.tick.size() == count, "original Godot reader recovers every buffered tick from honest open .part")
	check(game.session.actual_v_mismatches == 0, "no actual velocity mismatch")
	# text shortcuts must not leak from either export field to gameplay/global actions.
	for field: LineEdit in [game.hud.export_name, game.hud.export_path]:
		field.grab_focus()
		var before := state()
		var look: bool = game.look_enabled
		tap_export_key(KEY_R)
		tap_export_key(KEY_F)
		tap_export_key(KEY_L)
		check(state() == before and game.look_enabled == look and game.paused, "text focus safeguards " + field.name)
		field.release_focus()
	var look: bool = game.look_enabled
	tap_export_key(KEY_L)
	check(game.look_enabled != look, "paused L still works outside text fields")
	tap_export_key(KEY_L)
	var tele: bool = game.hud.telemetry
	tap_export_key(KEY_F9)
	check(game.hud.telemetry != tele, "paused F9 retained")
	tap_export_key(KEY_F9)
	# a second actual service/button export proves distinct sessions and successful opening.
	opener_success = true
	game.change_setting("volume", 0.38)
	game.hud.export_button.pressed.emit()
	var second: Dictionary = game.last_run_export
	check(second.ok and second.path != bundle and second.folder_opened, "second real button export has unique session ZIP and opens folder")
	bundles.append(second.path)
	await export_observation()
	_write("export-checks.json", {"ok": checks.all(func(row: Dictionary) -> bool: return row.ok), "checks": checks, "bundle": bundle, "bundles": bundles,
		"source": source, "active_ticks": count, "buffered_tail": tail, "partial": {"status": partial.status, "ticks": partial.columns.tick.size()}, "result": result})
	game.set_paused(false)
	export_busy = false

func tap_export_key(code: int) -> void:
	for pressed: bool in [true, false]:
		var input := InputEventKey.new()
		input.keycode = code
		input.physical_keycode = code
		input.pressed = pressed
		Input.parse_input_event(input)
		Input.flush_buffered_events()

func export_observation() -> void:
	pass

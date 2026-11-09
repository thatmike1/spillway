extends SceneTree
## synthetic clean fixtures test sharing contracts; they are not completed gameplay routes.
const MAIN := preload("res://scripts/r19_main.gd")
const SHARE := preload("res://scripts/r19_ghost_share.gd")
const REC := preload("res://scripts/r16_run_recorder.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
var out := ""
var game: Node
var results: Array[Dictionary] = []
var opened: Array[String] = []
var exported := ""
var second := ""
var identity: Dictionary

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	_main.call_deferred()

func check(label: String, condition: bool, detail: Variant = "") -> void:
	results.append({"name": label, "ok": condition, "detail": str(detail).left(700)})
	if not condition:
		printerr("FAIL ", label, ": ", detail)

func make_game(earned: bool = false) -> void:
	game = MAIN.new()
	game.map_id = "rainline"
	game.persist = false
	game.record_runs = earned
	if earned:
		game.level_script = preload("res://tests/r16_loop_fixture_level.gd")
		game.recordings_dir = out.path_join("earned-routes")
	game.seed_from_r15 = false
	game.set_window_title = false
	game.ghosts_directory = out.path_join("ghosts")
	game.ghost_share_storage = out.path_join("state")
	game.ghost_folder_opener = func(path: String) -> int:
		opened.append(path)
		return OK
	root.add_child(game)
	await process_frame
	await physics_frame
	check("actual R19 host starts", str(game.startup_error).is_empty(), game.startup_error)

func press(name: String) -> void:
	var button := game.hud.find_child(name, true, false) as Button
	check("button exists: " + name, button != null)
	if button != null:
		button.grab_focus()
		await process_frame
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ENTER
		event.keycode = KEY_ENTER
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
	await process_frame

func put(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func fixture(id: Dictionary, build: String, directory: String, n: int = 24) -> String:
	var recorder := REC.new()
	var begun := recorder.begin_run({"identity": id, "build": build, "fixture": "synthetic, not a gameplay completion"}, directory)
	check("synthetic recorder opens", bool(begun.ok), begun)
	for i: int in n:
		recorder.capture({"tick": i, "dt": 1.0 / 128, "physics_hz": 128, "elapsed": float(i) / 128,
			"started": i > 0, "finished": i == n - 1, "clean": true, "practice_reason": "", "checkpoint": 0, "respawns": 0,
			"p": Vector3(0, 1, -i), "reference_p": Vector3(0, 1, -i), "v": Vector3(0, 0, -128), "actual_v": Vector3(0, 0, -128),
			"yaw": 0.0, "pitch": 0.0, "grounded": true, "ducked": false, "held": {}, "input_events": [], "motion": {}, "stats": {}})
	var sealed := recorder.finish({"kind": "finish", "clean": true, "time": float(n - 1) / 128, "respawns": 0})
	check("synthetic clean seal", bool(sealed.ok), sealed)
	return str(sealed.path)

func _main() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await make_game()
	identity = game.motion_identity()
	var service: Node = game.ghost_share
	game.set_paused(true)
	await press("OpenGhostFolder")
	check("folder opener seam gets exact canonical path without launching shell", opened == [out.path_join("ghosts")], opened)
	await press("ExportGhost")
	check("no clean best refuses export", str(service.status).begins_with("No verified clean best"), service.status)
	var local := fixture(identity, SHARE.BUILD, out.path_join("local"))
	var raw := FileAccess.get_file_as_bytes(local)
	var verified := SHARE.verify_run(raw, identity)
	check("synthetic clean fixture passes strict reader", bool(verified.ok), verified.get("note"))
	game.session.offer_ghost(local, 23)
	game.settings.ghost = true
	(game.hud.find_child("GhostPlayerName", true, false) as LineEdit).text = "Jindra Žluťoučký"
	await press("ExportGhost")
	check("real export button exports", str(service.status).begins_with("Exported"), service.status)
	if service.rows.is_empty():
		_finish()
		return
	exported = str(service.rows[0].file)
	var exported_bytes := FileAccess.get_file_as_bytes(service.folder.path_join(exported))
	var inspected := SHARE.inspect(exported_bytes)
	check("one-file wrapper preserves raw run bytes exactly", inspected.get("raw") == raw)
	check("UTF-8 player name survives", inspected.get("player") == "Jindra Žluťoučký", inspected.get("player"))
	put(out.path_join("cross-export.r16run"), inspected.raw)
	var unknown_path: String = service.folder.path_join("unknown.txt")
	put(unknown_path, "do not overwrite".to_utf8_buffer())
	await press("ExportGhost")
	check("second export uses new name", service.rows.size() == 2)
	check("unknown file preserved", FileAccess.get_file_as_string(unknown_path) == "do not overwrite")
	# actual dropfiles: a second name, another identity, a version mismatch, a geometry mismatch.
	second = "friend-b" + SHARE.SUFFIX
	put(service.folder.path_join(second), SHARE.envelope(raw, "Mike"))
	game.select_preset("server128_aa1000")
	await process_frame
	var other_id: Dictionary = game.motion_identity()
	game.select_preset("server128")
	await process_frame
	var other := fixture(other_id, SHARE.BUILD, out.path_join("other"))
	put(service.folder.path_join("other" + SHARE.SUFFIX), SHARE.envelope(FileAccess.get_file_as_bytes(other), "Alice"))
	var old := fixture(identity, "spillway-r18", out.path_join("old"))
	put(service.folder.path_join("version" + SHARE.SUFFIX), SHARE.envelope(FileAccess.get_file_as_bytes(old), "Old build", "spillway-r18"))
	var geometry := identity.duplicate(true)
	geometry.geometry = "older-breakwater-geometry"
	var old_map := fixture(geometry, SHARE.BUILD, out.path_join("old-map"))
	put(service.folder.path_join("revision" + SHARE.SUFFIX), SHARE.envelope(FileAccess.get_file_as_bytes(old_map), "Old map"))
	put(service.folder.path_join("broken" + SHARE.SUFFIX), "not executable; not data".to_utf8_buffer())
	await press("RefreshGhosts")
	check("visible drop folder discovers all neighbors", service.rows.size() == 7, service.rows.size())
	for row: Dictionary in service.rows:
		if str(row.file).begins_with("version"):
			check("version mismatch explicitly labelled with name and time", str(row.note).begins_with("Different game version") and row.player == "Old build" and row.time > 0, row)
		if str(row.file).begins_with("revision"):
			check("map revision mismatch labelled", "revision" in service.note_for(row), row)
		if str(row.file).begins_with("other"):
			check("second identity cannot race current course", service.note_for(row) != "Ready to race", row)
	var before_pointer: String = game.session.ghost_path
	await press("Friend_" + exported.sha256_text().left(16))
	check("real friend button selects Jindra", service.active == exported and service.friend.loaded)
	check("friend selection leaves local pointer unchanged", game.session.ghost_path == before_pointer)
	check("only chosen ghost draws", not game.ghost_shown())
	await press("Friend_" + second.sha256_text().left(16))
	check("second friend replaces chosen friend", service.active == second and service.selected == second)
	check("HUD and menu name the chosen friend rather than local time", "Mike" in game.hud._run_text() and "Mike" in game.hud.ghost_menu_state())
	service.choose("version" + SHARE.SUFFIX)
	service.choose("revision" + SHARE.SUFFIX)
	check("mismatched version or revision never replaces active friend", service.active == second and service.selected == second)
	var refused := game.hud.find_child("Friend_" + ("version" + SHARE.SUFFIX).sha256_text().left(16), true, false) as Button
	check("mismatched ghost menu button disabled", refused != null and refused.disabled)
	var old_ghost := preload("res://scripts/r16_ghost.gd").new()
	root.add_child(old_ghost)
	var old_loaded: Dictionary = old_ghost.load_run(old, identity)
	check("local R18 run remains usable on unchanged time identity", bool(old_loaded.ok), old_loaded)
	old_ghost.free()
	check("friend has no collision bodies", not has_collision(service.friend))
	game.toggle_ghost()
	await process_frame
	check("G setting hides selected friend", not service.friend.visible and not game.settings.ghost)
	game.toggle_ghost()
	await process_frame
	check("G setting restores selected friend", service.friend.visible and game.settings.ghost)
	var state := {"p": game.player.position, "v": game.player.velocity, "tick": game.session.tick, "elapsed": game.elapsed, "stage": game.checkpoint_index}
	service.friend.set_time(0.12)
	check("ghost never changes physics/input/progress", state == {"p": game.player.position, "v": game.player.velocity, "tick": game.session.tick, "elapsed": game.elapsed, "stage": game.checkpoint_index})
	var scans: int = service.scan_count
	for i: int in 4:
		await process_frame
	check("no per-frame scans", service.scan_count == scans)
	game.restart_run()
	check("selection survives run restart", service.selected == second and service.active == second)
	game.set_paused(true)
	game.select_map("breakwater")
	check("map switch suspends mismatching friend without discarding choice", service.active.is_empty() and service.selected == second)
	check("new Breakwater revision explanation preserved", "Older Breakwater" in game.map_revision_description())
	game.select_map("rainline")
	await process_frame
	check("return to matching map restores chosen friend", service.active == second)
	game.select_preset("server128_aa1000")
	check("preset switch suspends friend", service.active.is_empty() and service.selected == second)
	await process_frame
	game.set_paused(true)
	game.hud._refresh_share()
	await press("Friend_" + ("other" + SHARE.SUFFIX).sha256_text().left(16))
	check("second motion identity becomes selectable on its real preset", service.active == "other" + SHARE.SUFFIX and service.friend.loaded, [service.active, service.status, other_id, game.motion_identity()])
	game.select_preset("server128")
	await process_frame
	check("another identity's friend never plays after returning to F2", service.active.is_empty())
	game.hud._refresh_share()
	await press("Friend_" + second.sha256_text().left(16))
	check("can return to previous named friend on F2", service.active == second)
	game.set_paused(false)
	root.remove_child(game)
	game.free()
	await process_frame
	await make_game()
	service = game.ghost_share
	check("app restart restores chosen filename and name", service.selected == second and service.active == second and service.player_name == "Jindra Žluťoučký")
	game.session.offer_ghost(local, 23)
	game.settings.ghost = true
	game.set_paused(true)
	await press("ClearFriendGhost")
	check("clearing friend restores local ghost", service.active.is_empty() and service.selected.is_empty() and game.session.ghost.loaded and game.ghost_shown())
	service.choose("../external.spillghost")
	check("arbitrary external selection ignored", service.selected.is_empty())
	await bounds_tests(raw)
	await older_best_export()
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3440, 1440)]:
		root.size = resolution
		game.hud._layout()
		await process_frame
		await process_frame
		var section: Control = game.hud.share_section
		var outer: Control = game.hud._pause_scroll
		check("sharing section stays within scrolling sheet at " + str(resolution), section.size.x <= outer.size.x and section.get_minimum_size().x <= outer.size.x, [section.size, section.get_minimum_size(), outer.size])
		if DisplayServer.get_name() != "headless":
			game.hud._pause_scroll.scroll_vertical = 200
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("menu-%dx%d.png" % [resolution.x, resolution.y]))
	check("base map cards and Advanced preserved", game.hud.map_buttons.size() == game.maps.catalog.size() and is_instance_valid(game.hud.advanced_toggle))
	check("F9 look label stays hidden without telemetry", not game.look_label.visible)
	# screenshot uses Godot readback on a private display only, never the desktop.
	if DisplayServer.get_name() != "headless":
		for i: int in 5:
			await process_frame
		game.hud._pause_scroll.scroll_vertical = 200
		for i: int in 5:
			await process_frame
		root.get_texture().get_image().save_png(out.path_join("menu.png"))
	game.set_paused(false)
	root.remove_child(game)
	game.free()
	await process_frame
	await earned_routes()
	_finish()

func older_best_export() -> void:
	var service: Node = game.ghost_share
	var expected: Dictionary = game.motion_identity()
	var prior_directory: String = game.recordings_dir
	var local := fixture(expected, "spillway-2026.11.09-r16", out.path_join("older-fast-best"), 12)
	check("older faster local fixture becomes the local best", game.session.offer_ghost(local, 11))
	game.recordings_dir = out.path_join("r19-export-candidates")
	var fastest := fixture(expected, SHARE.BUILD, game.recordings_dir, 48)
	fixture(expected, SHARE.BUILD, game.recordings_dir, 60)
	check("slower R19 finish cannot replace the older local PB", not game.session.offer_ghost(fastest, 47) and game.session.ghost_path == local)
	var saved := await export_from_button(service)
	check("export chooses fastest clean R19 run despite older faster PB", bool(saved.get("ok", false)) and saved.get("raw") == FileAccess.get_file_as_bytes(fastest), saved.get("note", ""))
	if bool(saved.get("ok", false)):
		put(out.path_join("cross-older-pb-fallback.r16run"), saved.raw)
	check("export preserves old local best pointer and ticks", game.session.ghost_path == local and game.session.ghost_ticks == 11)
	game.recordings_dir = prior_directory

func export_from_button(service: Node) -> Dictionary:
	var before: Array = DirAccess.get_files_at(service.folder)
	await press("ExportGhost")
	for name: String in DirAccess.get_files_at(service.folder):
		if name.ends_with(SHARE.SUFFIX) and not name in before:
			return SHARE.inspect(FileAccess.get_file_as_bytes(str(service.folder).path_join(name)))
	return {"ok": false, "note": service.status}

func has_collision(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child: Node in node.get_children():
		if has_collision(child):
			return true
	return false

func bounds_tests(raw: PackedByteArray) -> void:
	var good := SHARE.envelope(raw, "Bounds")
	check("trailing garbage refused", not SHARE.inspect(good + PackedByteArray([0])).ok)
	check("truncation refused", not SHARE.inspect(good.slice(0, good.size() - 1)).ok)
	var bad := good.duplicate()
	bad.encode_u32(8, SHARE.MAX_META + 1)
	check("metadata bound refused before read", not SHARE.inspect(bad).ok)
	bad = good.duplicate()
	bad.encode_u32(12, SHARE.MAX_RUN + 1)
	check("run byte bound refused", not SHARE.inspect(bad).ok)
	bad = raw.duplicate()
	var at := 16 + bad.decode_u32(12) + 32
	bad.encode_u32(at + 12, SHARE.MAX_DECODE + 1)
	check("inflate budget refused before decode", not SHARE.verify_run(bad).ok)
	bad = raw.duplicate()
	bad.encode_u32(at + 24, SHARE.MAX_TICKS + 1)
	check("tick budget refused before decode", not SHARE.verify_run(bad).ok)
	bad = raw.duplicate()
	bad[bad.size() - 1] ^= 1
	check("damaged recording chain refused", not SHARE.inspect(SHARE.envelope(bad, "Damaged")).ok)
	var unsupported := SHARE.envelope(raw, "Schema")
	var metadata := JSON.stringify({"format": "spillway-shared-ghost", "schema": 99, "build": SHARE.BUILD, "player": "Schema"}).to_utf8_buffer()
	unsupported = SHARE.MAGIC.to_ascii_buffer()
	unsupported.resize(16)
	unsupported.encode_u32(8, metadata.size())
	unsupported.encode_u32(12, raw.size())
	unsupported.append_array(metadata)
	unsupported.append_array(raw)
	check("unsupported schema explicitly labelled", "schema" in SHARE.inspect(unsupported).note)
	check("bad names refused", not SHARE.inspect(SHARE.envelope(raw, "bad\nname")).ok)
	check("linux portable folder", SHARE.default_folder(true, "/tmp/release/Spillway") == "/tmp/release/ghosts")
	check("windows portable folder", SHARE.default_folder(true, "C:/Games/Spillway/Spillway.exe") == "C:/Games/Spillway/ghosts")
	check("source folder never beside editor binary", SHARE.default_folder(false, "/opt/godot/editor") == ProjectSettings.globalize_path("user://r19_ghosts"))
	var service: Node = game.ghost_share
	var bytes := FileAccess.get_file_as_bytes(service.folder.path_join(second))
	put(service.folder.path_join(second), SHARE.envelope(raw, "Changed after scan"))
	service.choose(second)
	check("changed file needs fresh scan before selection", str(service.active).is_empty() and "changed" in str(service.status))
	put(service.folder.path_join(second), bytes)
	for i: int in 70:
		put(service.folder.path_join("bound-%03d" % i + SHARE.SUFFIX), PackedByteArray([0]))
	service.scan()
	check("folder listing is bounded", service.rows.size() == SHARE.MAX_FILES and "limit" in str(service.status), [service.rows.size(), service.status])
	for i: int in 70:
		DirAccess.remove_absolute(service.folder.path_join("bound-%03d" % i + SHARE.SUFFIX))
	service.scan()

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func earned_line() -> Array:
	game.set_paused(false)
	await physics_frame
	game.restart_run()
	for i: int in 16:
		await physics_frame
	var trace: Array = []
	key(KEY_W, true)
	var jumped := false
	for i: int in 2400:
		await physics_frame
		trace.append([game.player.position, game.player.velocity, game.player.get("yaw"), game.elapsed, game.checkpoint_index])
		if not jumped and game.player.position.z < -9:
			key(KEY_SPACE, true)
			jumped = true
		if game.finished:
			break
	key(KEY_W, false)
	key(KEY_SPACE, false)
	await physics_frame
	await physics_frame
	check("earned fixture route finishes clean through real input", game.finished and game.finish_kind == "clean", [game.finished, game.finish_kind])
	return trace

func earned_routes() -> void:
	await make_game(true)
	var first := await earned_line()
	var service: Node = game.ghost_share
	var local: String = game.session.ghost_path
	check("actual session seals and promotes earned fixture run", not local.is_empty() and game.session.ghost_ticks > 0)
	put(out.path_join("cross-earned.r16run"), FileAccess.get_file_as_bytes(local))
	game.set_paused(true)
	(game.hud.find_child("GhostPlayerName", true, false) as LineEdit).text = "Earned fixture"
	await press("ExportGhost")
	var choice := ""
	for row: Dictionary in service.rows:
		if row.player == "Earned fixture" and service.note_for(row) == "Ready to race":
			choice = str(row.file)
	check("actual earned clean best exports through menu", not choice.is_empty())
	await press("Friend_" + choice.sha256_text().left(16))
	game.settings.ghost = true
	var scans: int = service.scan_count
	var reads: int = service.read_count
	var with_friend := await earned_line()
	var differences: Array = []
	for i: int in mini(first.size(), with_friend.size()):
		if first[i] != with_friend[i]:
			differences.append([i, first[i], with_friend[i]])
			if differences.size() >= 3:
				break
	check("friend-present and friend-absent physics/input trajectory exactly equal", first == with_friend, [first.size(), with_friend.size(), differences])
	check("no sharing reads or scans during earned route", service.scan_count == scans and service.read_count == reads)
	check("chosen friend stays chosen after new local best offer", service.selected == choice and service.active == choice)
	root.remove_child(game)
	game.free()
	await process_frame

func _finish() -> void:
	var failed := results.filter(func(row: Dictionary) -> bool: return not row.ok)
	var file := FileAccess.open(out.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": results.size(), "failed": failed.size(), "results": results, "fixture": "synthetic clean recordings, not genuine course completions"}, "  "))
	file.close()
	print("r19 sharing: ", results.size(), " checks, ", failed.size(), " failed")
	quit(0 if failed.is_empty() else 1)

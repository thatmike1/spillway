extends "r20-pack-probe.gd"
## r21 overrides only identity-bearing observers; all inherited physical/input audits run.
## final component observers compose the original controls without changing their assertions.

func _check_identity() -> void:
	var player: Node = game.get("player")
	var id := {"main_script": _script_path(game), "build": game.get("BUILD_ID"), "save_path": game.get("SAVE_PATH"),
		"profile_path": game.get("profile_path"), "persist": game.get("persist"), "profile_state": game.get("profile_state"),
		"map": game.get("map_id"), "preset": game.get("preset_id"), "physics_hz": game.get("physics_hz"),
		"engine_hz": Engine.physics_ticks_per_second, "course_key": game.get("course_key"), "runner_chain": _script_chain(player),
		"hud_script": _script_path(game.get("hud")), "stats_script": _script_path(game.get("stats")), "audio_script": _script_path(game.get("audio")),
		"rate_log": game.get("rate_log"), "title": get_window().title, "window_title": game.call("window_title")}
	report["identity"] = id
	var frozen: Dictionary = expect.identity
	var route: Dictionary = spec.get("route", {})
	var want_map := str(route.get("map", frozen.start.map))
	var want_preset := str(route.get("preset", frozen.start.preset))
	check("main script", id.main_script == str(frozen.main_script), id.main_script)
	check("build id", str(id.build) == str(expect.build), id.build)
	check("records namespace", str(id.save_path) == str(expect.save_path) and str(id.profile_path) == str(expect.save_path), [id.save_path, id.profile_path])
	check("launch scene asks for records", bool(id.persist), id.persist)
	check("starts on the requested map and preset", str(id.map) == want_map and str(id.preset) == want_preset, [id.map, id.preset])
	var key: Dictionary = frozen.keys.get(want_map, {}).get(want_preset, {})
	check("rate is the preset's frozen rate", int(id.physics_hz) == int(key.get("physics_hz", -1)) and int(id.engine_hz) == int(id.physics_hz), [id.physics_hz, id.engine_hz])
	check("record key equals the frozen source key", str(id.course_key) == str(key.get("course_key", "")), [id.course_key, key.get("course_key")])
	check("record identity and fingerprint equal the frozen source", JSON.stringify(game.call("record_identity"), "", false, true) == str(key.get("record_identity", ""))
		and JSON.stringify(game.call("physics_fingerprint"), "", true) == str(key.get("fingerprint", "")), "")
	check("runner script chain", id.runner_chain == key.get("runner_chain", []), id.runner_chain)
	check("hud, stats and audio scripts", id.hud_script == str(frozen.hud_script) and id.stats_script == str(frozen.stats_script) and id.audio_script == str(frozen.audio_script), [id.hud_script, id.stats_script, id.audio_script])
	if expect.has("profile_state"):
		check("profile state at launch", str(id.profile_state) == str(expect.profile_state), id.profile_state)
	check("window title names build, map, preset and rate", str(id.title) == str(id.window_title) and str(id.title).begins_with(str(expect.title_prefix))
		and str(id.title).contains(str(game.call("map_name"))) and str(id.title).contains(str((game.get("preset") as Dictionary).label)), id.title)

	var runtime: Dictionary = spec.r21.runtime
	check("R21 host preserves the full R20 chain", _script_chain(game) == [runtime.main_script,
		"res://scripts/r20_main.gd", "res://scripts/r19_main.gd", "res://scripts/r17_main.gd", "res://scripts/r16_main.gd"], _script_chain(game))
	check("R21 HUD retains the R18 interface chain", _script_chain(game.hud).has("res://scripts/r20_hud.gd")
		and _script_chain(game.hud).has("res://scripts/r19_hud.gd") and _script_chain(game.hud).has("res://scripts/r18_hud.gd"))
	check("R21 project and title identity", str(ProjectSettings.get_setting("application/config/version")) == str(runtime.version)
		and game.window_title().begins_with("Spillway R21 · "))
	check("R21 recording build and retained behavioral build", str(game.recording_metadata("probe").build) == str(runtime.build)
		and str(game.BUILD_ID) == "spillway-2026.11.09-r16")
	check("normal scene records and persists", bool(game.record_runs) and bool(game.persist))
	check("portable friend folder is next to release executable", str(game.ghost_share.folder) == OS.get_executable_path().get_base_dir().path_join("ghosts"), game.ghost_share.folder)
	check("inherited session, style, recorder and ghost services", _script_path(game.session) == "res://scripts/r16_run_session.gd"
		and _script_path(game.session.style) == "res://scripts/r16_style.gd"
		and _script_path(game.session.recorder) == "res://scripts/r16_run_recorder.gd"
		and _script_path(game.session.ghost) == "res://scripts/r16_ghost.gd")
	for map: String in game.PRESENTATION.PALETTES.MAPS:
		var sky: String = game.PRESENTATION.PALETTES.MAPS[map].sky
		check(map+": critical painted sky loads", ResourceLoader.exists(sky) and load(sky) is Texture2D, sky)

func _identity() -> void:
	await super._identity()
	# these are current production methods, not a guessed final variant/assist interface.
	var home: String = game.map_id
	game.select_map("tether-yard")
	await _physics(4)
	var actual: Dictionary = {}
	var models: Array = ["classic", "pendulum", "elastic"]
	for variant: Dictionary in spec.r21.models.elastic_variants:
		models.append(str(variant.id))
	var previous_model: String = game.player.model
	var previous_reel: bool = game.player.auto_reel
	for model: String in models:
		game.player.configure_tether(model, false)
		check(model+": production runner accepts exact model", str(game.player.model) == model)
		actual[model] = _tether_rules(game.player.tether_identity())
	game.player.configure_tether(previous_model, previous_reel)
	var reference: CharacterBody3D = load("res://scripts/r20_tether_player.gd").new()
	var original: Dictionary = {}
	for model: String in ["classic", "pendulum", "elastic"]:
		reference.call("configure_tether", model, false)
		original[model] = _tether_rules(reference.call("tether_identity"))
	reference.free()
	report["r21_models"] = actual
	report["r20_models"] = original
	if home != game.map_id:
		game.select_map(home)
		await _physics(4)

func _tether_rules(identity: Dictionary) -> Dictionary:
	# separate actual rules/control objects from the revised runner's version/selection labels.
	var alternative: Dictionary = identity.alternative
	var classic: Dictionary = identity.classic
	var reel: Variant = identity.get("reel_ups", alternative.get("reel_ups", classic.get("reel_ups", -1.0)))
	return RUN_READER.json_safe({"classic": classic, "alternative": alternative, "controls": identity.controls,
		"effective_reel_ups": reel})

func _friend_release() -> void:
	var begin := checks.size()
	var service: Node = game.ghost_share
	var folder: String = service.folder
	if not check("friend source is a real recorded clean best",FileAccess.file_exists(str(game.session.ghost_path))):
		report["friend"] = {"ok":false,"reason":"no real recorded clean best"}
		return
	var raw := FileAccess.get_file_as_bytes(str(game.session.ghost_path))
	await _tap(KEY_ESCAPE)
	var before := _behavior()
	check("friend file controls initially collapsed",not game.hud.share_section.visible)
	await _friend_button("GhostSharingToggle")
	check("actual disclosure opens friend file controls",game.hud.share_section.is_visible_in_tree())
	# intercept only opening a file manager; the button and real portable folder still run.
	service.folder_opener = func(path: String) -> int:
		_folder_opened = path
		return OK
	await _friend_button("OpenGhostFolder")
	check("Open ghosts folder targets actual portable directory",_folder_opened == folder and DirAccess.dir_exists_absolute(folder),_folder_opened)
	await _friend_type_name("RFLG release probe")
	await _friend_type_name("Release probe")
	await _friend_button("ExportGhost")
	var exported := ""
	for row: Dictionary in service.rows:
		if str(row.player) == "Release probe" and bool(row.ok):
			exported = str(row.file)
	check("export button produced one compatible named real clean run",not exported.is_empty(),service.status)
	if not exported.is_empty():
		var bytes := FileAccess.get_file_as_bytes(folder.path_join(exported))
		var checked: Dictionary = service.inspect(bytes)
		check("export wraps actual clean recording bytes",bool(checked.ok) and checked.raw == raw and checked.build == str(spec.r21.runtime.build))
		_put(folder.path_join("release-import.spillghost"),bytes)
		_put(folder.path_join("release-wrong-version.spillghost"),service.envelope(raw,"Other version","spillway-2026.11.09-r19"))
		await _friend_button("RefreshGhosts")
		var imported := false
		var wrong := false
		for row: Dictionary in service.rows:
			var button := game.hud.find_child("Friend_"+str(row.file).sha256_text().left(16),true,false) as Button
			if str(row.file) == "release-import.spillghost":
				imported = button != null and not button.disabled and button.text.contains("Release probe") and button.text.contains("Ready to race") and button.text.contains(str(game.hud.call("_time",float(row.time))))
			if str(row.file) == "release-wrong-version.spillghost":
				wrong = button != null and button.disabled and button.text.contains("Different game version")
		check("dropped same-version file listed with player and time",imported)
		check("dropped wrong-version file visibly refused",wrong)
		await _friend_button("Friend_"+"release-import.spillghost".sha256_text().left(16))
		check("actual selection activates imported nonphysical friend",service.active == "release-import.spillghost" and service.friend.find_children("*","CollisionObject3D",true,false).is_empty())
		var run: Dictionary = RUN_READER.read(str(game.session.ghost_path))
		var sample := -1
		for i: int in run.columns.elapsed.size()-1:
			if float(run.columns.elapsed[i+1]) > float(run.columns.elapsed[i]) and run.columns.flags[i] & 1:
				sample = i
				break
		if check("earned friend run has started adjacent samples",sample >= 0):
			var at := (float(run.columns.elapsed[sample])+float(run.columns.elapsed[sample+1]))*0.5
			var pose: Dictionary = service.friend.call("pose_at",at)
			var wanted: Vector3 = (run.columns.p[sample] as Vector3).lerp(run.columns.p[sample+1],0.5)
			check("selected friend interpolates earned recording",(pose.feet as Vector3).distance_to(wanted)<1e-5)
		await _friend_button("ClearFriendGhost")
		check("actual button restores local best",str(service.active).is_empty() and str(service.selected).is_empty())
		for name: String in [exported,"release-import.spillghost","release-wrong-version.spillghost"]:
			DirAccess.remove_absolute(folder.path_join(name))
		await _friend_button("RefreshGhosts")
	check("friend UI never writes physical state, records or scoring",before == _behavior())
	var files := {}
	var prefs: String = service.storage.path_join("selection.json")
	if check("real sharing flow writes preferences",FileAccess.file_exists(prefs)):
		files["Spillway/r19_ghost_share/selection.json"] = FileAccess.get_sha256(prefs)
	var cached: String = service.storage.path_join("cache").path_join(RUN_READER.sha256(raw).hex_encode()+".r16run")
	if FileAccess.file_exists(cached):
		files["Spillway/r19_ghost_share/cache/"+cached.get_file()] = FileAccess.get_sha256(cached)
	report["friend_profile_files"] = files
	await _friend_button("GhostSharingToggle")
	check("actual disclosure restores collapsed friend controls",not game.hud.share_section.visible)
	report["friend"] = {"ok":checks.slice(begin).all(func(c: Dictionary) -> bool: return c.ok),"portable_folder":folder,"file_manager_intercepted":true,"real_clean_recording":true}
	service.folder_opener = Callable()
	await _tap(KEY_ESCAPE)

func _r20_features() -> void:
	var begin := checks.size()
	var metadata: Dictionary = game.recording_metadata("release")
	var style: Dictionary = metadata.scoring.style
	check("earned route retains the R20 recording and stack identity", metadata.build == str(spec.r21.runtime.build)
		and metadata.build_label == "Spillway R21" and style.version == "r20-style-stack-1"
		and int(style.event_format) == 2 and style.rules_sha256 == "b133b80f118247cf944f1c48bbe9f1a65e2b71653adff52d41563904be661688")
	check("earned route remains clean after friend sharing", game.finished and game.finish_kind == "clean" and game.respawn_count == 0)
	check("earned route uses unchanged F2 and the observed map identity", game.preset_id == "server128"
		and game.course_geometry == expect.identity.maps[game.map_id].geometry
		and game.course_key == expect.identity.keys[game.map_id][game.preset_id].course_key)
	if game.map_id == "saltglass":
		check("earned Saltglass route retained its packed surf observations", report.has("saltglass")
			and report.saltglass.pieces.size() == 16 and report.saltglass.steep_grounded_ticks == 0)
	report["r20_route_identity"] = {"ok":checks.slice(begin).all(func(c: Dictionary) -> bool:return c.ok),
		"map":game.map_id,"geometry":game.course_geometry,"scoring":metadata.scoring}

func _controls() -> void:
	# all original eleven-map L, stack, export, Tether, Through Line and profile controls.
	await super._controls()
	await _r21_saltglass_controls()
	await _r21_tether_controls()

func _r21_saltglass_controls() -> void:
	var begin := checks.size()
	var home: String = game.map_id
	if home != "saltglass":
		await _pause_menu_click("Map_saltglass", "R21 Saltglass geometry")
	await _physics(2)
	check("R21 Saltglass packed production module and geometry", _script_path(game.level) == "res://scripts/r21_surf_level.gd"
		and game.level.geometry_hash() == spec.r21.map_versions.saltglass.geometry
		and game.runner_path() == "res://scripts/r15_source_player.gd")
	var fins := 0
	var shapes := 0
	for piece: Dictionary in game.level.manifest:
		if str(piece.name).begins_with("Surf_"):
			fins += 1
	for node: Node in game.level.find_children("*", "CollisionShape3D", true, false):
		if not node.disabled and node.shape != null:
			shapes += 1
	check("R21 Saltglass actual sixteen fin colliders and authored geometry", fins == 16 and shapes >= game.level.manifest.size(), [fins, shapes])
	if home != "saltglass":
		await _pause_menu_click("Map_" + home, "restore after R21 Saltglass geometry")
	report["r21_saltglass_controls"] = {"ok": checks.slice(begin).all(func(c: Dictionary) -> bool: return c.ok),
		"checks": checks.slice(begin), "scope": "packed geometry; semantic exit/outside/bail acceptance is bound through exact source replay"}

class R21PreviewObserver:
	extends Node
	var probe: Variant
	func _physics_process(_delta: float) -> void:
		probe._r21_observe_preview()

var _r21_observing := false
var _r21_preview: Dictionary = {}
var _r21_preview_count := 0
var _r21_readiness_agreements := 0
var _r21_preview_pure := true
var _r21_hud_agrees := true
var _r21_ids_agree := true

func _r21_observe_preview() -> void:
	if not _r21_observing or not _tether_active or not _tether_armed:
		return
	var next: Dictionary = game.player.r21_acquisition_snapshot()
	if not _r21_preview.is_empty() and next.attached and not _r21_preview.attached and next.assist:
		_r21_ids_agree = _r21_ids_agree and _r21_preview.ready and next.id == _r21_preview.id
		_r21_readiness_agreements += 1
	var before := var_to_str([game.player.get_motion_state(), game.player.r21_acquisition_snapshot()])
	game.hud._refresh_anchor_readout()
	_r21_preview_pure = _r21_preview_pure and before == var_to_str([game.player.get_motion_state(), game.player.r21_acquisition_snapshot()])
	var shown: bool = not game.finished and str(next.state) == "ok" and (next.attached or next.ready)
	_r21_hud_agrees = _r21_hud_agrees and (game.hud.displayed_anchor == next if shown else game.hud.displayed_anchor.is_empty())
	_r21_preview = next.duplicate(true)
	_r21_preview_count += 1

func _r21_preference(button: Button, label: String) -> void:
	if not button.disabled:
		await _reveal(button)
		check(label + ": actual native preference click", await _click(button))
		await _tap(KEY_ESCAPE)
		await _physics(1)
		check(label + ": no held attachment after preference boundary", game.player.grapple.is_empty())
		await _tap(KEY_ESCAPE)

func _r21_tether_controls() -> void:
	var begin := checks.size()
	var fixtures: Dictionary = spec.get("feature_tapes", {})
	var on: Dictionary = fixtures.get("tether", {})
	var off: Dictionary = fixtures.get("r21_tether_off", {})
	var references: Dictionary = fixtures.get("r21_tether_reference", {})
	var models: Array = ["classic", "pendulum", "elastic", "elastic-soft", "elastic-firm", "elastic-arc"]
	if not check("R21 exact six-model and four assist-off reader-derived tapes", on.keys() == models
		and off.keys() == models.slice(2) and references.size() == 10, [on.keys(), off.keys()]):
		return
	var home: String = game.map_id
	var preset: String = game.preset_id
	var previous_model: String = game.settings.tether_model
	var previous_auto: bool = game.settings.tether_auto_reel
	var previous_assist: bool = game.settings.tether_anchor_assist
	if home != "tether-yard":
		await _pause_menu_click("Map_tether-yard", "R21 Tether production routes")
	await _restore_preset("server128")
	check("R21 packed actual host/HUD/runner interfaces", _script_path(game) == "res://scripts/r21_main.gd"
		and _script_path(game.hud) == "res://scripts/r21_hud.gd" and game.runner_path() == "res://scripts/r21_tether_player.gd")
	check("R21 six selectable packed models in exact order", game.hud.tether_models.keys() == models)
	var late := Late.new()
	late.run = self
	late.process_physics_priority = 1001
	late.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(late)
	var observer := R21PreviewObserver.new()
	observer.probe = self
	observer.process_physics_priority = 1000
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(observer)
	var routes: Dictionary = {}
	for model: String in models:
		for assist: bool in ([true] if model in ["classic", "pendulum"] else [true, false]):
			var label := model if assist else model + "-assist-off"
			await _tap(KEY_ESCAPE)
			await _r21_preference(game.hud.tether_models[model], label + " model")
			await _r21_preference(game.hud.reel_manual, label + " manual reel")
			if bool(game.settings.tether_anchor_assist) != assist and model not in ["classic", "pendulum"]:
				await _r21_preference(game.hud.anchor_assist_switch, label + " independent assist")
			check(label + ": exact model/assist/reel selected in production", game.player.model == model
				and not game.player.auto_reel and game.player.r21_assist_active() == (assist and model not in ["classic", "pendulum"]))
			check(label + ": Classic/Pendulum disable assist preference", game.hud.anchor_assist_switch.disabled == (model in ["classic", "pendulum"]))
			await captured("r21-" + label + "-preferences", {"paused": true})
			await _tap(KEY_ESCAPE)
			_tether_driver = RAW_DRIVER.new()
			var tape: String = str(on[model] if assist else off[model])
			if not check(label + ": load exact source reader-derived tape", _tether_driver.configure(tape, false)):
				break
			_tether_tick = 0
			_tether_armed = false
			_tether_trace = []
			_tether_attaches = {}
			_tether_cues = []
			_r21_preview = {}
			_r21_preview_count = 0
			_r21_readiness_agreements = 0
			_r21_preview_pure = true
			_r21_hud_agrees = true
			_r21_ids_agree = true
			_tether_motor_start = game.player.tape_step_count
			_tether_active = true
			_r21_observing = true
			await _tap(KEY_R)
			while _tether_active:
				await tether_step
			_r21_observing = false
			_tether_driver.release()
			check(label + ": earned packed clean finish through three anchors", game.finished and game.finish_kind == "clean"
				and game.respawn_count == 0 and _tether_attaches.size() == 3 and _r21_preview_count > 0)
			check(label + ": every physics preview is pure and HUD agrees", _r21_preview_pure and _r21_hud_agrees and _r21_ids_agree)
			if assist and model not in ["classic", "pendulum"]:
				check(label + ": three native ready-preview exact-id attachment agreements", _r21_readiness_agreements >= 3)
			var ref: Dictionary = references[label]
			# the JSON trace is the pinned diagnostic; parsed JSON numbers are not the recorded bits.
			var reference: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(ref.trace)))
			check(label + ": pinned diagnostic JSON trace is bound and complete", FileAccess.get_sha256(str(ref.trace)) == str(ref.get("trace_sha256", ""))
				and reference is Array and (reference as Array).size() == _tether_trace.size())
			var source: Dictionary = r21_source_trace(ref)
			var differs: String = r21_trace_mismatch(_tether_trace, source.rows) if source.ok else str(source.error)
			check(label + ": every packed physical sample equals earned source", differs.is_empty(), differs)
			check(label + ": raw tape SHA remains bound", FileAccess.get_sha256(tape) == str(ref.tape_sha256))
			routes[label] = {"model": model, "assist": assist, "trace": _tether_trace.duplicate(true),
				"tape_sha256": FileAccess.get_sha256(tape), "identity": game.motion_identity()}
			var clean: Array = game.session.sealed.filter(func(r: Dictionary) -> bool: return str(r.get("kind", "")) == "finish")
			check(label + ": earned packed recording is available for ghost boundary", not clean.is_empty())
			if not clean.is_empty():
				var path: String = str(clean[-1].path)
				routes[label]["recording"] = path
				check(label + ": matching packed recording ghost loads", game.session.ghost.load_run(path, game.motion_identity()).ok)
				await _r21_wrong_loadout_ghosts(label, path, model, assist)
	late.queue_free()
	observer.queue_free()
	await _tap(KEY_R)
	await _r21_acquisition_controls()
	await _r21_lifecycle_controls()
	# restore preferences through the actual UI, leaving each sampled boundary intact.
	await _tap(KEY_ESCAPE)
	await _r21_preference(game.hud.tether_models["elastic"], "restore assist-capable model")
	if bool(game.settings.tether_anchor_assist) != previous_assist:
		await _r21_preference(game.hud.anchor_assist_switch, "restore assist")
	await _r21_preference(game.hud.tether_models[previous_model], "restore model")
	await _r21_preference(game.hud.reel_automatic if previous_auto else game.hud.reel_manual, "restore reel")
	await _tap(KEY_ESCAPE)
	await _restore_preset(preset)
	if home != "tether-yard":
		await _pause_menu_click("Map_" + home, "restore after R21 Tether")
	for map: String in expect.required_maps:
		if map in ["tether-yard", "saltglass"]:
			continue
		if game.map_id != map:
			await _pause_menu_click("Map_" + map, "R21 original-map isolation")
		check(map + ": no revised Tether runner on original maps", not game.player.has_method("r21_acquisition_snapshot"))
		_check_map("R21 unchanged map " + map)
	if game.map_id != home:
		await _pause_menu_click("Map_" + home, "restore R21 control home")
	_controls_profile()
	_r21_settings_profile()
	report["r21_tether_controls"] = {"ok": checks.slice(begin).all(func(c: Dictionary) -> bool: return c.ok),
		"checks": checks.slice(begin), "routes": routes, "scope": "native packed production routes/UI plus labelled acquisition fixtures"}

## each loadout change opens an attempt; the next boundary waits until that attempt holds a sample.
func _r21_wrong_loadout_ghosts(label: String, path: String, model: String, assist: bool) -> void:
	var before: Dictionary = game.motion_identity()
	game.change_setting("tether_auto_reel", true)
	await game.get_tree().physics_frame
	check(label + ": wrong reel ghost refuses", not game.session.ghost.load_run(path, game.motion_identity()).ok and before != game.motion_identity())
	await _r21_recorded(label + " wrong reel")
	game.change_setting("tether_auto_reel", false)
	await game.get_tree().physics_frame
	await _r21_recorded(label + " restored reel")
	if model not in ["classic", "pendulum"]:
		game.change_setting("tether_anchor_assist", not assist)
		await game.get_tree().physics_frame
		check(label + ": wrong assist ghost refuses", not game.session.ghost.load_run(path, game.motion_identity()).ok)
		await _r21_recorded(label + " wrong assist")
		game.change_setting("tether_anchor_assist", assist)
		await game.get_tree().physics_frame
		await _r21_recorded(label + " restored assist")

## physics_frame is emitted before node callbacks, so one awaited frame can end before the session
## (priority 999) samples a just-opened attempt. wait, bounded, for this attempt's own recorder sample.
func _r21_recorded(label: String, limit: int = 8) -> bool:
	var session: Node = game.session
	var recorder: RefCounted = session.recorder
	var run_id := str(recorder.run_id)
	for frame: int in limit + 1:
		if not session.attempt_live or not recorder.is_open() or str(recorder.run_id) != run_id or run_id.is_empty():
			break
		if int(recorder.counts().get("ticks", 0)) >= 1 and int(session.tick) >= 1:
			return check(label + ": open attempt recorded a sample before the next boundary", true, {"run_id": run_id, "frames": frame})
		if frame < limit:
			await game.get_tree().physics_frame
	return check(label + ": open attempt recorded a sample before the next boundary", false,
		{"run_id": run_id, "now": str(recorder.run_id), "open": recorder.is_open(), "live": session.attempt_live, "ticks": recorder.counts().get("ticks", 0)})

const R21_WARMUP_TICKS := 33
const R21_TRACE_FIELDS := ["tick", "p", "v", "yaw", "pitch", "grounded", "checkpoint", "elapsed", "respawns"]

## the bound source recording's observed rows, rebuilt from its strictly read binary columns in the
## shape _tether_late() records. returns {ok, error, rows}.
static func r21_source_trace(ref: Dictionary) -> Dictionary:
	var out := {"ok": false, "error": "", "rows": []}
	for key: String in ["recording", "recording_sha256", "tape", "tape_sha256", "trace", "trace_sha256", "identity"]:
		if not ref.has(key):
			out.error = "source reference has no " + key
			return out
	var ticks: Variant = ref.get("ticks")
	if typeof(ticks) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(ticks)) or float(ticks) != floorf(float(ticks)) or float(ticks) < 1 or float(ticks) > 80000:
		out.error = "source reference tick count is not a positive whole number"
		return out
	for key: String in ["recording", "tape", "trace"]:
		if FileAccess.get_sha256(str(ref[key])) != str(ref[key + "_sha256"]) or str(ref[key + "_sha256"]).length() != 64:
			out.error = "source %s SHA-256 differs from its binding" % key
			return out
	var run: Dictionary = RUN_READER.read(str(ref.recording))
	if not bool(run.ok) or str(run.status) != "complete" or not (run.errors as Array).is_empty():
		out.error = "source recording is not a strict complete read: %s" % str(run.errors).left(200)
		return out
	var why := RUN_READER.identity_matches((run.header as Dictionary).get("identity"), ref.identity)
	if not why.is_empty():
		out.error = "source recording " + why
		return out
	var c: Dictionary = run.columns
	var n := (c.tick as PackedInt32Array).size()
	if n != R21_WARMUP_TICKS + int(ticks):
		out.error = "source recording holds %d ticks, not %d warmup plus %d observed" % [n, R21_WARMUP_TICKS, int(ticks)]
		return out
	for name: String in ["flags", "elapsed", "checkpoint", "respawns", "p", "v", "yaw", "pitch"]:
		if c[name].size() != n:
			out.error = "source column %s holds %d rows, not %d" % [name, c[name].size(), n]
			return out
	var rows: Array = []
	for j: int in n:
		if c.tick[j] != j:
			out.error = "source tick %d is not contiguous at row %d" % [c.tick[j], j]
			return out
		if j < R21_WARMUP_TICKS:
			continue
		var p: Vector3 = c.p[j]
		var v: Vector3 = c.v[j]
		rows.append({"tick": int(c.tick[j]) - R21_WARMUP_TICKS, "p": [p.x, p.y, p.z], "v": [v.x, v.y, v.z],
			"yaw": float(c.yaw[j]), "pitch": float(c.pitch[j]), "grounded": (int(c.flags[j]) & 8) != 0,
			"checkpoint": int(c.checkpoint[j]), "elapsed": float(c.elapsed[j]), "respawns": int(c.respawns[j])})
	out.rows = rows
	out.ok = true
	return out

## "" when both traces hold the same rows, field set, types and float64 bytes (signed zero included).
static func r21_trace_mismatch(native: Array, source: Array) -> String:
	if native.size() != source.size():
		return "packed trace holds %d rows, source %d" % [native.size(), source.size()]
	for i: int in native.size():
		if not native[i] is Dictionary or not source[i] is Dictionary:
			return "row %d is not an object" % i
		var why := _r21_row_mismatch(native[i], source[i])
		if not why.is_empty():
			return "row %d: %s" % [i, why]
	return ""

static func _r21_row_mismatch(a: Dictionary, b: Dictionary) -> String:
	var wanted: Array = R21_TRACE_FIELDS.duplicate()
	wanted.sort()
	for row: Dictionary in [a, b]:
		var keys: Array = row.keys()
		if keys.any(func(k: Variant) -> bool: return typeof(k) != TYPE_STRING):
			return "field names are not strings"
		keys.sort()
		if keys != wanted:
			return "fields %s" % str(keys)
	for key: String in ["tick", "checkpoint", "respawns"]:
		if typeof(a[key]) != TYPE_INT or typeof(b[key]) != TYPE_INT or a[key] != b[key]:
			return "%s %s (%s) != %s (%s)" % [key, str(a[key]), type_string(typeof(a[key])), str(b[key]), type_string(typeof(b[key]))]
	if typeof(a.grounded) != TYPE_BOOL or typeof(b.grounded) != TYPE_BOOL or a.grounded != b.grounded:
		return "grounded %s != %s" % [str(a.grounded), str(b.grounded)]
	var bits := [_r21_float_bytes(a), _r21_float_bytes(b)]
	if bits[0].is_empty() or bits[1].is_empty():
		return "a float field is missing, not a float or not finite"
	if bits[0] != bits[1]:
		var x: PackedFloat64Array = bits[0].to_float64_array()
		var y: PackedFloat64Array = bits[1].to_float64_array()
		for k: int in x.size():
			if PackedFloat64Array([x[k]]).to_byte_array() != PackedFloat64Array([y[k]]).to_byte_array():
				return "float %d of p,v,yaw,pitch,elapsed: %s != %s (bytes %s != %s)" % [k, String.num(x[k], 17), String.num(y[k], 17),
					PackedFloat64Array([x[k]]).to_byte_array().hex_encode(), PackedFloat64Array([y[k]]).to_byte_array().hex_encode()]
	return ""

static func _r21_float_bytes(row: Dictionary) -> PackedByteArray:
	var values: Array = []
	for key: String in ["p", "v"]:
		if not row[key] is Array or (row[key] as Array).size() != 3:
			return PackedByteArray()
		values.append_array(row[key])
	values.append_array([row.yaw, row.pitch, row.elapsed])
	var out := PackedFloat64Array()
	for value: Variant in values:
		if typeof(value) != TYPE_FLOAT or not is_finite(value):
			return PackedByteArray()
		out.append(value)
	return out.to_byte_array()

func _r21_settings_profile() -> void:
	var config := ConfigFile.new()
	check("R21 actual shared profile can be reopened", config.load(game.profile_path) == OK)
	var actual: Array = Array(config.get_section_keys("settings"))
	var expected: Array = game.settings.keys()
	actual.sort()
	expected.sort()
	check("R21 persisted settings contain exactly the known keys", actual == expected)
	check("R21 separate persisted anchor assist is a boolean", typeof(config.get_value("settings", "tether_anchor_assist", null)) == TYPE_BOOL)

func _r21_mouse(pressed: bool, receiver: Node = null) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if receiver != null:
		# the isolated SubViewport receives the same real event and global button state.
		receiver.call("_unhandled_input", event)

func _r21_lifecycle_controls() -> void:
	# boundaries use a normal production spawn and mouse input, never a body pose.
	game.change_setting("tether_model", "elastic")
	await _physics(1)
	for boundary: String in ["pause", "restart", "practice", "respawn", "preset", "model", "automatic_reel", "anchor_assist", "map"]:
		_r21_mouse(false)
		game.change_setting("tether_model", "elastic")
		await _physics(1)
		game.change_setting("tether_anchor_assist", true)
		await _physics(1)
		game.change_setting("tether_auto_reel", false)
		await _physics(1)
		game.restart_run("restart")
		await _physics(34)
		# use the first anchor's actual authored position through raw mouse counts.
		var target: Vector3 = game.level.ANCHORS[0]
		var delta: Vector3 = target - game.player._eye()
		var desired_yaw := atan2(-delta.x, -delta.z)
		var desired_pitch := atan2(delta.y, Vector2(delta.x, delta.z).length())
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(wrapf(game.player.yaw - desired_yaw, -PI, PI), game.player.pitch - desired_pitch) / game.player.tape_radians_per_count
		motion.screen_relative = motion.relative
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await _physics(2)
		var preview: Dictionary = game.player.r21_acquisition_snapshot()
		check(boundary + ": normal-spawn preview is ready before fresh press", preview.ready)
		_r21_mouse(true)
		await _physics(2)
		check(boundary + ": earned real attachment before boundary", not game.player.grapple.is_empty()
			and game.player.r21_acquisition_snapshot().id == preview.id)
		match boundary:
			"pause": game.set_paused(true); game.set_paused(false)
			"restart": game.restart_run("restart")
			"practice": game.practise_stage(0)
			"respawn": game.respawn()
			"preset":
				game.select_preset("server128_aa1000")
				await _physics(1)
				game.select_preset("server128")
			"model": game.change_setting("tether_model", "elastic-soft")
			"automatic_reel": game.change_setting("tether_auto_reel", true)
			"anchor_assist": game.change_setting("tether_anchor_assist", false)
			"map":
				game.select_map("breakwater")
				await _physics(1)
				game.select_map("tether-yard")
		await _physics(4)
		check(boundary + ": held press cannot cross actual production boundary", game.player.grapple.is_empty()
			and not game.player.r21_acquisition_snapshot().ready)
	_r21_mouse(false)
	await _physics(2)

func _r21_acquisition_controls() -> void:
	# labelled isolated packed-runner fixture, never a normal-spawn earned route.
	game.set_paused(true)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var player: CharacterBody3D = load("res://scripts/r21_tether_player.gd").new()
	world.add_child(player)
	player.position = Vector3(10000, 10000, 10000)
	player.set_physics_process(false)
	player.set_process(false)
	player.input_enabled = true
	player.configure_tether("elastic", false)
	player.configure_anchor_assist(true)
	_r21_mouse(false, player)
	player.block_tether("restart")
	var anchor := Node3D.new()
	anchor.name = "R21PackedAnchor"
	anchor.set_meta("r21_anchor_id", "r21-packed-anchor")
	anchor.set_meta("anchor_name", "packed fixture")
	world.add_child(anchor)
	anchor.add_to_group(player.ANCHOR_GROUP)
	anchor.global_position = player._eye() + Vector3(0, 0, -20)
	var invalid := [Vector3(0, 0, -31), Vector3(0, 0, 20), Vector3(8, 0, -20)]
	for offset: Vector3 in invalid:
		anchor.global_position = player._eye() + offset
		player._grapple_step(Vector3.ZERO, false, 1.0 / 128)
		check("R21 packed invalid range/view/cone refuses preview", not player.r21_acquisition_snapshot().ready, offset)
	anchor.global_position = player._eye() + Vector3(sin(deg_to_rad(17.0)), 0, -cos(deg_to_rad(17.0))) * 20
	player.settings.fov = 10.0
	player._grapple_step(Vector3.ZERO, false, 1.0 / 128)
	check("R21 packed narrow viewport rejects an otherwise in-cone target", not player.r21_acquisition_snapshot().ready)
	player.settings.fov = 92.0
	anchor.global_position = player._eye() + Vector3(0, 0, -20)
	player._grapple_step(Vector3.ZERO, false, 1.0 / 128)
	var ready: Dictionary = player.r21_acquisition_snapshot()
	check("R21 packed fixture publishes ready id after physics", ready.ready and ready.id == "r21-packed-anchor")
	var frozen := var_to_str([player.get_motion_state(), player.r21_acquisition_snapshot()])
	for cadence: int in [0, 1, 3]:
		for frame: int in cadence:
			player._process(1.0 / 60)
		check("R21 packed rendering cadence cannot change candidate or mechanics", frozen == var_to_str([player.get_motion_state(), player.r21_acquisition_snapshot()]), cadence)
	_r21_mouse(true, player)
	player._grapple_step(Vector3.ZERO, false, 1.0 / 128)
	player._grapple_press = false
	check("R21 packed fresh press latches ready published id", player.r21_acquisition_snapshot().attached and player.r21_acquisition_snapshot().id == ready.id)
	_r21_mouse(false, player)
	player._grapple_step(Vector3.ZERO, false, 1.0 / 128)
	var blocker := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 2, 0.05)
	collision.shape = box
	blocker.add_child(collision)
	world.add_child(blocker)
	blocker.global_position = anchor.global_position + Vector3(0, 0, 0.1)
	await _physics(2)
	player._grapple_step(Vector3.ZERO, false, 1.0 / 128)
	check("R21 packed endpoint occlusion refuses prospective anchor", not player.r21_acquisition_snapshot().ready)
	blocker.free()
	await _physics(2)
	player._grapple_step(Vector3.ZERO, false, 1.0 / 128)
	check("R21 packed preview recovers after actual blocker removal", player.r21_acquisition_snapshot().ready)
	_r21_mouse(false, player)
	viewport.queue_free()
	await _frames(2)
	game.set_paused(false)

func _end(reason: String) -> void:
	# a failed observer must never exit zero by clicking the production Quit button.
	if reason.is_empty() and checks.any(func(c: Dictionary) -> bool: return not c.ok):
		reason = "R21 observer checks failed"
	await super._end(reason)

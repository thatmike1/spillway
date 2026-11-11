extends "r20-pack-probe.gd"
## r21 overrides only identity-bearing observers; all inherited physical/input audits run.
## source and packed component fixtures remain explicit, individually closed seams.

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
	return RUN_READER.json_safe({"classic": identity.classic, "alternative": identity.alternative, "controls": identity.controls})

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
	# replace this seam only after reading the final actual surf contract and fixtures.
	check("R21 revised Saltglass final packed exit/outside/no-skip contract is not bound", false,
		{"scene": game.scene_file_path, "host": _script_path(game), "map": game.map_id})

func _r21_tether_controls() -> void:
	# new variant/assist APIs do not exist in the currently frozen integration host.
	check("R21 final six-model/assist/preview/occlusion/clearance contract is not bound", false,
		{"model": game.settings.get("tether_model"), "host": _script_path(game)})

func _end(reason: String) -> void:
	# a failed observer must never exit zero by clicking the production Quit button.
	if reason.is_empty() and checks.any(func(c: Dictionary) -> bool: return not c.ok):
		reason = "R21 observer checks failed"
	await super._end(reason)

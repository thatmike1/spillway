extends "r16-pack-probe.gd"
## exact R19 delivery observer. inherited controls, input/recording and real local ghost
## checks stay behavioral. the new checks use the packed host and its actual buttons.
var _telemetry_pressed := false
var _folder_opened := ""

func _check_identity() -> void:
	super._check_identity()
	check("R19 host inherits R17 and R16", _script_chain(game).slice(0,3) == ["res://scripts/r19_main.gd", "res://scripts/r17_main.gd", "res://scripts/r16_main.gd"], _script_chain(game))
	check("R19 HUD inherits R18 interface", _script_chain(game.hud).slice(0,2) == ["res://scripts/r19_hud.gd", "res://scripts/r18_hud.gd"], _script_chain(game.hud))
	check("R19 project and title identity", str(ProjectSettings.get_setting("application/config/version")) == "2026.11.09-r19" and game.window_title().begins_with("Spillway R19 · "))
	check("R19 recording build distinct from behavioral BUILD_ID", str(game.recording_metadata("probe").build) == "spillway-2026.11.09-r19" and str(game.BUILD_ID) == "spillway-2026.11.09-r16")
	check("R19 recording enabled in normal scene", bool(game.record_runs) and bool(game.persist))
	check("portable friend folder is next to release executable", str(game.ghost_share.folder) == OS.get_executable_path().get_base_dir().path_join("ghosts"), game.ghost_share.folder)
	for map: String in game.PRESENTATION.PALETTES.MAPS:
		var sky: String = game.PRESENTATION.PALETTES.MAPS[map].sky
		check(map+": critical painted sky loads", ResourceLoader.exists(sky) and load(sky) is Texture2D, sky)

func _check_hud_words(when: String) -> void:
	if not _telemetry_pressed:
		check("telemetry and Look label hidden by default", not bool(game.hud.telemetry) and not game.look_label.is_visible_in_tree())
		_key(KEY_F9,true)
		_key(KEY_F9,false)
		_telemetry_pressed = true
		check("F9 enables actual telemetry", bool(game.hud.telemetry) and game.hud.strafe_live.is_visible_in_tree())
	super._check_hud_words(when)

func captured(name: String, wanted: Dictionary) -> Dictionary:
	var state: Dictionary = await super.captured(name,wanted)
	if game.look_label.is_visible_in_tree():
		check(name+": Look label stays in viewport", get_viewport().get_visible_rect().encloses(game.look_label.get_global_rect()))
		for field: String in ["lab_tag", "lab_panel", "practice_tag"]:
			var control := game.hud.get(field) as Control
			check(name+": Look label clears "+field, not control.is_visible_in_tree() or not game.look_label.get_global_rect().intersects(control.get_global_rect()))
	if bool(game.paused):
		check(name+": paused Look label hidden", not game.look_label.is_visible_in_tree())
	return state

func _geometry() -> String:
	var rows: Array = [game.level.manifest, game.level.spawn, game.level.checkpoints, game.level.segment_bounds, game.course_geometry, game.overlay_id, game.course_key, game.motion_identity()]
	for node: Node in game.level.find_children("*", "CollisionShape3D", true, false):
		rows.append([str(game.level.get_path_to(node.get_parent())),node.global_transform,node.disabled,node.shape.get_debug_mesh().get_faces()])
	return var_to_str(rows).sha256_text()

func _behavior() -> String:
	return var_to_str([game.player.global_transform, game.player.velocity, game.elapsed, game.checkpoint_index, game.attempts, game.finished, game.clean_eligible, game.session.style.snapshot(), game.session.ghost_state, game.record_identity(), game.motion_identity()])

func _controls() -> void:
	await _tap(KEY_ESCAPE)
	check("Advanced settings collapsed by default",not game.hud.advanced_box.visible)
	var advanced := game.hud.find_child("AdvancedToggle",true,false) as Button
	await _reveal(advanced)
	check("click Advanced through actual GUI",await _click(advanced))
	await _frames(3)
	check("Advanced contains R13 sliders",game.hud.advanced_box.visible)
	check("collapse Advanced through actual GUI",await _click(advanced))
	await _frames(3)
	check("Advanced collapsed again",not game.hud.advanced_box.visible)
	await _tap(KEY_ESCAPE)

	await super._controls()
	var maps: Array = expect.identity.registry.maps
	var required: Array = expect.required_maps
	check("catalog equals explicit frozen required maps", maps.size() == required.size() and maps.all(func(m: String) -> bool: return m in required))
	var home: String = game.map_id
	var results: Array = []
	for map: String in maps:
		if game.map_id != map:
			await _pause_menu_click("Map_"+map,"R19 map "+map)
			await _physics(5)
		await _tap(KEY_ESCAPE)
		check(map+": paused for atomic L comparison",game.paused)
		var card := game.hud.find_child("Map_"+map,true,false) as Button
		var new_experiment: bool = map != "experiment" and map in expect.get("experimental_maps",[])
		check(map+": card is in its actual main or Experiments section",card != null and card.get_parent() == (game.hud.experiments_grid if new_experiment else game.hud.map_grid))
		check(map+": Experiments heading is presented in the pause menu",game.hud.experiments_heading.is_visible_in_tree())
		var geometry := _geometry()
		var state := _behavior()
		var original: bool = game.look_enabled
		await captured("r19-"+map+"-paint",{"map":map,"paused":true})
		await _tap(KEY_L)
		check(map+": L selects original presentation",game.look_enabled != original and not game.look_layer.enabled and game.look_label.text.contains("original R16"))
		check(map+": L preserves collision, progress, scoring and identities",geometry == _geometry() and state == _behavior())
		var restored := true
		for swap: Dictionary in game.look_layer.swaps:
			var material: Material = swap.node.get_surface_override_material(swap.surface) if swap.has("surface") else swap.node.material_override
			restored = restored and material == swap.old
		if game.look_layer.world != null:
			restored = restored and game.look_layer.world.environment == game.look_layer.old_environment
		for light: Dictionary in game.look_layer.light_states:
			restored = restored and light.node.rotation == light.rotation and light.node.light_color == light.color and light.node.light_energy == light.energy
		check(map+": original materials, environment and lights restored",restored)
		await captured("r19-"+map+"-original",{"map":map,"paused":true})
		await _tap(KEY_L)
		check(map+": second L restores paint without gameplay writes",game.look_enabled == original and game.look_layer.enabled and geometry == _geometry() and state == _behavior())
		await captured("r19-"+map+"-restored",{"map":map,"paused":true})
		if map in expect.get("experimental_maps",["experiment"]) or bool(game.is_lab()) or str(game.map_kind()) == "experimental":
			check(map+": experimental title suffix retained",str(game.window_title()).ends_with("EXPERIMENTAL"),game.window_title())
		results.append({"map":map,"geometry_sha256":geometry,"look":game.look_layer.report})
		await _tap(KEY_ESCAPE)
	if game.map_id != home:
		await _pause_menu_click("Map_"+home,"restore R19 start map")
		await _physics(5)
	report["r19_maps"] = results

func _friend_button(name: String) -> bool:
	var button := game.hud.find_child(name,true,false) as Button
	await _reveal(button)
	var clicked := await _click(button)
	await _frames(4)
	check("clicked friend button "+name,clicked and game.paused)
	return clicked

func _put(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if not check("friend drop writable: "+path.get_file(),file != null):
		return
	file.store_buffer(bytes)
	file.close()

func _friend_text_event(code: int, down: bool, unicode: int = 0, control: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode if down else 0
	event.ctrl_pressed = control
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(1)

func _friend_type_name(value: String) -> void:
	var field: LineEdit = game.hud.share_name
	await _reveal(field)
	check("click actual player-name field",await _click(field))
	await _frames(2)
	check("player-name field has actual GUI focus",field.has_focus())
	var before := _behavior()
	var look: bool = game.look_enabled
	var telemetry: bool = game.hud.telemetry
	await _friend_text_event(KEY_CTRL,true,0,true)
	await _friend_text_event(KEY_A,true,0,true)
	await _friend_text_event(KEY_A,false,0,true)
	await _friend_text_event(KEY_CTRL,false)
	for i: int in value.length():
		var letter := value.substr(i,1)
		var code := letter.to_upper().unicode_at(0)
		await _friend_text_event(code,true,letter.unicode_at(0))
		await _friend_text_event(code,false)
	check("actual key input enters the export player name",field.text == value,field.text)
	check("name typing cannot trigger game, look or telemetry shortcuts",game.paused and before == _behavior() and game.look_enabled == look and game.hud.telemetry == telemetry)

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
		check("export wraps actual clean recording bytes",bool(checked.ok) and checked.raw == raw and checked.build == "spillway-2026.11.09-r19")
		_put(folder.path_join("release-import.spillghost"),bytes)
		_put(folder.path_join("release-wrong-version.spillghost"),service.envelope(raw,"Other version","spillway-2026.11.09-r18"))
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

func _wrap_up() -> void:
	if str(report.mode) == "play":
		await _friend_release()
	await super._wrap_up()

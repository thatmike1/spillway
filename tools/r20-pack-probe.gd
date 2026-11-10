extends "r16-pack-probe.gd"
## adapted from r19-pack-probe.gd at 065f7b279; exact R20 delivery observer. inherited controls, input/recording and real local ghost
## checks stay behavioral. the new checks use the packed host and its actual buttons.
const RAW_DRIVER := preload("r20-raw-input-driver.gd")
signal through_step
var _through_active := false
var _through_armed := false
var _through_driver: RefCounted
var _through_tick := 0
var _through_motor_start := 0
var _through_trace: Array = []
var _through_ids: Array = []
var _through_ids_ok := true
var _through_clock_ok := true
var _through_clock := 0.0
var _through_captures: Dictionary = {}
signal tether_step
var _tether_active := false
var _tether_armed := false
var _tether_driver: RefCounted
var _tether_tick := 0
var _tether_motor_start := 0
var _tether_trace: Array = []
var _tether_attaches: Dictionary = {}
var _tether_cues: Array = []
const DIRECTION_DRIVER := preload("r20-direction-driver.gd")
signal direction_step
var _direction_active := false
var _direction_driver: RefCounted
var _direction_tick := 0
var _direction_row: Dictionary = {}
var _direction_moving_l := false
var _telemetry_pressed := false
var _folder_opened := ""
var _salt_first: Dictionary = {}
var _salt_landings: Dictionary = {}
var _salt_pieces: Dictionary = {}
var _salt_contacts := {"west": 0, "east": 0}
var _salt_steep_grounded := 0

func observe_actual(delta: float) -> void:
	var count := observed_samples.size()
	super.observe_actual(delta)
	if observed_samples.size() == count:
		return
	var host := get_tree().current_scene
	var snapshot: Dictionary = host.get("session").get("style").call("snapshot")
	observed_samples[-1]["style_direction"] = RUN_READER.json_safe(snapshot.direction)
	observed_samples[-1]["style_time_s"] = snapshot.time_s
	observed_samples[-1]["style_direction_verdict"] = RUN_READER.json_safe(snapshot.diag.direction.last)

func early_step(delta: float) -> void:
	if not _direction_active:
		super.early_step(delta)
		return
	_direction_tick += 1
	for command: Array in _direction_driver.commands(_direction_tick, _direction_row):
		_direction_input(command)
	if _direction_tick == 200:
		var before := _behavior()
		var look: bool = game.look_enabled
		_key(KEY_L, true)
		_key(KEY_L, false)
		check("direction route: moving L changes only presentation", game.look_enabled != look and _behavior() == before)
		_key(KEY_L, true)
		_key(KEY_L, false)
		check("direction route: second moving L restores paint", game.look_enabled == look and _behavior() == before)
		_direction_moving_l = true

func late_step(delta: float) -> void:
	if _through_active:
		_through_late()
		return
	if _tether_active:
		_tether_late()
		return
	if _direction_active:
		var sample: Dictionary = game.session.last_sample
		_direction_row = {"p": game.player.global_position, "v": game.player.velocity,
			"speed": Vector2(sample.actual_v.x, sample.actual_v.z).length() / 0.0254,
			"yaw": game.player.yaw, "g": game.player.is_grounded(), "direction": game.session.style.snapshot().direction}
		_direction_driver.observe(_direction_row)
		direction_step.emit()
		return
	if not _row.is_empty() and game.map_id == "saltglass":
		_observe_saltglass(int(_row.tick))
	super.late_step(delta)

func _observe_saltglass(tick: int) -> void:
	var player: CharacterBody3D = game.player
	var motion: Dictionary = player.call("get_motion_state")
	for contact: Dictionary in motion.get("contacts", []):
		var normal: Vector3 = contact.normal
		var body := str(contact.body)
		if not body.begins_with("Surf_") or normal.y <= 0.45 or normal.y >= 0.65:
			continue
		var fin := "west" if body.contains("west") else "east"
		_salt_pieces[body] = true
		_salt_contacts[fin] += 1
		if bool(player.call("is_grounded")):
			_salt_steep_grounded += 1
		if not _salt_first.has(fin):
			_salt_first[fin] = {"tick": tick, "feet": _v3(game.body_reference()),
				"contact": _v3(contact.position), "normal": _v3(normal)}
	if bool(player.call("is_grounded")):
		for fin: String in _salt_first:
			if _salt_landings.has(fin) or tick <= int(_salt_first[fin].tick):
				continue
			var feet: Vector3 = player.global_position
			var hit := player.get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.6, feet + Vector3.DOWN * 0.6))
			_salt_landings[fin] = {"tick": tick, "body": str((hit.collider as Node).name) if not hit.is_empty() else "",
				"normal": _v3(hit.get("normal", Vector3.ZERO))}

func _judge_run() -> void:
	super._judge_run()
	if game.map_id != "saltglass":
		return
	check("Saltglass packed route takes 40 to 70 seconds", game.elapsed >= 40.0 and game.elapsed <= 70.0, game.elapsed)
	check("Saltglass packed route contacts every fin piece without walkable surf faces", _salt_pieces.size() == 16
		and int(_salt_contacts.west) >= 128 and int(_salt_contacts.east) >= 128 and _salt_steep_grounded == 0, [_salt_pieces.keys(), _salt_contacts, _salt_steep_grounded])
	for fin: String in ["west", "east"]:
		var first: Dictionary = _salt_first.get(fin, {})
		check(fin+": packed first feet and contact exceed 80 percent of crest", not first.is_empty()
			and float(first.feet[1]) >= 14.4 and float(first.contact[1]) >= 14.4, first)
		var landing: Dictionary = _salt_landings.get(fin, {})
		check(fin+": packed first landing is the flat exit deck", not landing.is_empty()
			and str(landing.body).begins_with(fin+"_landing_") and float(landing.normal[1]) > 0.99999, landing)
	report["saltglass"] = {"first_contacts": _salt_first, "first_landings": _salt_landings,
		"pieces": _salt_pieces.keys(), "contacts": _salt_contacts, "steep_grounded_ticks": _salt_steep_grounded,
		"elapsed": game.elapsed, "geometry": game.course_geometry}

func _input(event: InputEvent) -> void:
	super._input(event)
	if not event is InputEventMouseButton:
		return
	var host := get_tree().current_scene
	if host == null or not ("session" in host) or host.get("session") == null or bool(host.get("paused")):
		return
	var session: Node = host.get("session")
	if not bool(session.get("attempt_live")) or not session.get("recorder").call("is_open"):
		return
	delivered_inputs.append({"run_id": session.get("recorder").get("run_id"), "tick": session.get("tick"),
		"data": {"type": "mouse_button", "button_index": event.button_index, "pressed": event.pressed,
			"double_click": event.double_click, "factor": event.factor}})

func _check_identity() -> void:
	super._check_identity()
	check("R20 host inherits R17 and R16", _script_chain(game).slice(0,4) == ["res://scripts/r20_main.gd", "res://scripts/r19_main.gd", "res://scripts/r17_main.gd", "res://scripts/r16_main.gd"], _script_chain(game))
	check("R20 HUD inherits R18 interface", _script_chain(game.hud).slice(0,3) == ["res://scripts/r20_hud.gd", "res://scripts/r19_hud.gd", "res://scripts/r18_hud.gd"], _script_chain(game.hud))
	check("R20 project and title identity", str(ProjectSettings.get_setting("application/config/version")) == "2026.11.10-r20" and game.window_title().begins_with("Spillway R20 · "))
	check("R20 recording build distinct from behavioral BUILD_ID", str(game.recording_metadata("probe").build) == "spillway-2026.11.10-r20" and str(game.BUILD_ID) == "spillway-2026.11.09-r16")
	check("R20 recording enabled in normal scene", bool(game.record_runs) and bool(game.persist))
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
	for shelved: String in ["line-drive", "fall-line"]:
		check(shelved+": absent from runtime selection and menu", shelved not in game.map_ids() and not game.maps.catalog.has(shelved) and game.hud.find_child("Map_"+shelved,true,false) == null)
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
	check("catalog equals explicit frozen required maps", maps == required)
	var home: String = game.map_id
	var results: Array = []
	for map: String in maps:
		if game.map_id != map:
			await _pause_menu_click("Map_"+map,"R20 map "+map)
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
		await captured("r20-"+map+"-paint",{"map":map,"paused":true})
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
		await captured("r20-"+map+"-original",{"map":map,"paused":true})
		await _tap(KEY_L)
		check(map+": second L restores paint without gameplay writes",game.look_enabled == original and game.look_layer.enabled and geometry == _geometry() and state == _behavior())
		await captured("r20-"+map+"-restored",{"map":map,"paused":true})
		if map in expect.get("experimental_maps",["experiment"]) or bool(game.is_lab()) or str(game.map_kind()) == "experimental":
			check(map+": experimental title suffix retained",str(game.window_title()).ends_with("EXPERIMENTAL"),game.window_title())
		results.append({"map":map,"geometry_sha256":geometry,"look":game.look_layer.report})
		await _tap(KEY_ESCAPE)
	if game.map_id != home:
		await _pause_menu_click("Map_"+home,"restore R20 start map")
		await _physics(5)
	report["r20_maps"] = results
	await _directional_controls()
	await _tether_controls()
	await _through_controls()

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
		check("export wraps actual clean recording bytes",bool(checked.ok) and checked.raw == raw and checked.build == "spillway-2026.11.10-r20")
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

func _wrap_up() -> void:
	if str(report.mode) == "play":
		await _friend_release()
		await _r20_features()
	await super._wrap_up()

# the parent must implement these against final controls before clearing the pending gate.
# this intentionally fails closed rather than accepting invented field assignments.
func _r20_features() -> void:
	check("R20 exact-pack feature integration pending", false, ["saltglass-route", "directional-stack", "tether-controls", "through-line", "export-my-runs"])

func _direction_input(command: Array) -> void:
	if command[0] == "mouse":
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(float(command[1]), 0.0)
		event.screen_relative = event.relative
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	else:
		_key(int(KEYS[command[0]]), bool(command[1]))

func _directional_controls() -> void:
	var begin := checks.size()
	var home: String = game.map_id
	var preset: String = game.preset_id
	if home != "practice":
		await _pause_menu_click("Map_practice", "direction route Penstock")
	await _restore_preset("server128")
	var early := Early.new()
	early.run = self
	early.process_physics_priority = -1000
	early.process_mode = Node.PROCESS_MODE_ALWAYS
	var late := Late.new()
	late.run = self
	late.process_physics_priority = 1001
	late.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(early)
	add_child(late)
	var results: Array = []
	for item: Array in [["back", "bank"], ["side", "bank"], ["back", "stall"], ["side", "stall"]]:
		var label: String = "direction-" + str(item[0]) + "-" + str(item[1])
		await _stage_picker_controls("practice", 3, false)
		if game.practice_stage != 3 or game.paused:
			check(label+": refuse route from a wrong stage", false, game.practice_stage)
			break
		_direction_driver = DIRECTION_DRIVER.new()
		_direction_driver.configure(game.player.global_position, game.player.yaw, game.player.tape_radians_per_count, item[0], item[1])
		_direction_tick = 0
		_direction_row = {}
		_direction_moving_l = false
		var paused_pending := false
		_direction_active = true
		while not _direction_driver.done and _direction_tick < 2400 and game.respawn_count == 0:
			await direction_step
			if not paused_pending and int(_direction_row.direction.hops) >= 6:
				_direction_active = false
				await _tap(KEY_ESCAPE)
				var pending: Dictionary = game.session.style.snapshot().direction.duplicate(true)
				check(label+": pending is separate from banked score", int(pending.pending) > 0 and int(game.session.style.summary().score) < int(pending.pending), pending)
				await captured(label+"-pending", {"paused":true,"clean":false})
				await _tap(KEY_L)
				await _tap(KEY_L)
				check(label+": pause and L preserve pending exactly", game.session.style.snapshot().direction == pending)
				await _tap(KEY_ESCAPE)
				paused_pending = true
				_direction_active = true
		_direction_active = false
		for command: Array in _direction_driver.release():
			_direction_input(command)
		var snapshot: Dictionary = game.session.style.snapshot()
		var transition: Dictionary = snapshot.direction.last
		var kind := "backward_bhop" if item[0] == "back" else "sideways_bhop"
		var unit := 160 if item[0] == "back" else 50
		var expected_kind := "direction_banked" if item[1] == "bank" else "direction_lost"
		check(label+": actual authored route earns six eligible hops", _direction_driver.done and paused_pending and _direction_moving_l and game.respawn_count == 0 and int(transition.get("hops",0)) >= 6, transition)
		check(label+": triangular terminal and category", transition.get("kind","") == expected_kind and transition.get("direction","") == kind and int(transition.get("pending",-1)) == unit * int(transition.get("hops",0)) * (int(transition.get("hops",0))-1) / 2, transition)
		check(label+": only a bank scores the pending amount", int(snapshot.by_kind.get(kind+"_bank",{}).get("points",0)) == (int(transition.get("pending",0)) if item[1] == "bank" else 0), snapshot)
		await captured(label+"-terminal", {"paused":false,"clean":false})
		results.append({"label":label,"ticks":_direction_tick,"transition":transition,"snapshot":snapshot,"position":_v3(game.player.global_position)})
		await _tap(KEY_R)
	early.queue_free()
	late.queue_free()
	await _restore_preset(preset)
	if home != "practice":
		await _pause_menu_click("Map_"+home, "restore after directional routes")
	report["directional_stack"] = {"ok": checks.slice(begin).all(func(c: Dictionary) -> bool:return c.ok), "routes":results, "geometry":"authored Penstock straight, actual GUI stage practice, input-only"}

func _tether_late() -> void:
	if not _tether_armed:
		if game.player.tape_step_count - _tether_motor_start < 33:
			return
		check("Tether raw route arms after exactly 33 untouched motor steps", game.player.tape_step_count - _tether_motor_start == 33, [game.player.tape_step_count,_tether_motor_start])
		_tether_armed = true
	else:
		var motion: Dictionary = game.player.get_motion_state()
		var experiment: Dictionary = motion.experiment
		_tether_trace.append({"tick":_tether_tick-1,"p":_v3(game.player.global_position),"v":_v3(game.player.velocity),
			"yaw":game.player.yaw,"pitch":game.player.pitch,"grounded":game.player.is_grounded(),
			"checkpoint":game.checkpoint_index,"elapsed":game.elapsed,"respawns":game.respawn_count})
		if bool(experiment.grapple.attached):
			_tether_attaches[str(experiment.grapple.anchor)] = true
		if "grapple_release" in experiment.events:
			_tether_cues.append(experiment.tether.last_cue.duplicate(true))
		if _tether_tick in [350, 650, 900]:
			_capture = {"name":"tether-"+str(game.settings.tether_model)+"-"+str(_tether_tick)}
	if _tether_tick >= _tether_driver.duration or game.respawn_count > 0:
		_tether_active = false
		tether_step.emit()
		return
	_tether_driver.step(_tether_tick)
	_tether_tick += 1
	tether_step.emit()

func _tether_controls() -> void:
	var begin := checks.size()
	var fixtures: Dictionary = spec.get("feature_tapes", {}).get("tether", {})
	if not check("Tether controls have explicit reader-derived fixture tapes", fixtures.has("classic") and fixtures.has("pendulum") and fixtures.has("elastic"), fixtures.keys()):
		return
	var home: String = game.map_id
	var preset: String = game.preset_id
	if home != "tether-yard":
		await _pause_menu_click("Map_tether-yard", "Tether mouse routes")
	await _restore_preset("server128")
	var late := Late.new()
	late.run = self
	late.process_physics_priority = 1001
	late.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(late)
	var routes: Array = []
	var classic: Array = []
	for label: String in ["classic", "pendulum", "elastic", "automatic"]:
		var model := "classic" if label == "automatic" else label
		await _tap(KEY_ESCAPE)
		var button: Button = game.hud.tether_models[model]
		var changed_model := not button.disabled
		if changed_model:
			await _reveal(button)
			check(label+": choose actual model button", await _click(button))
		button = game.hud.reel_automatic if label == "automatic" else game.hud.reel_manual
		if changed_model and not button.disabled:
			# keep the inherited sampled-attempt audit and exercise held-input isolation between changes.
			await _tap(KEY_ESCAPE)
			await _physics(1)
			check(label+": resuming between preference changes cannot attach", game.player.grapple.is_empty())
			await _tap(KEY_ESCAPE)
		if not button.disabled:
			await _reveal(button)
			check(label+": choose actual reel preference", await _click(button))
		check(label+": actual preferences selected", str(game.settings.tether_model) == model and bool(game.settings.tether_auto_reel) == (label == "automatic"))
		await _reveal(button)
		await captured("tether-"+label+"-preferences", {"paused":true})
		await _tap(KEY_ESCAPE)
		_tether_driver = RAW_DRIVER.new()
		if not check(label+": load bounded reader-derived tape", _tether_driver.configure(str(fixtures[model]), label == "automatic")):
			break
		_tether_tick = 0
		_tether_armed = false
		_tether_trace = []
		_tether_attaches = {}
		_tether_cues = []
		_tether_motor_start = game.player.tape_step_count
		_tether_active = true
		await _tap(KEY_R)
		while _tether_active:
			await tether_step
		_tether_driver.release()
		check(label+": real packed route finishes cleanly through three anchors", game.finished and game.finish_kind == "clean" and game.respawn_count == 0 and _tether_attaches.size() == 3, [game.elapsed,_tether_attaches])
		check(label+": every exercised release activates a self-made cue", _tether_cues.size() >= 3 and _tether_cues.all(func(c: Dictionary) -> bool:return c.get("active",false) and str(c.get("pcm_sha256","")).length() == 64), _tether_cues)
		if label == "classic":
			classic = _tether_trace.duplicate(true)
		if label == "automatic":
			check("automatic reel exactly preserves both-button physical trace", classic == _tether_trace)
		await captured("tether-"+label+"-finished", {"finished":true,"clean":true})
		routes.append({"label":label,"ticks":_tether_trace.size(),"elapsed":game.elapsed,"anchors":_tether_attaches.keys(),"cues":_tether_cues})
		report["tether_trace_"+label] = _tether_trace.duplicate(true)
	late.queue_free()
	await _tap(KEY_R)
	await _restore_preset(preset)
	if home != "tether-yard":
		await _pause_menu_click("Map_"+home, "restore after Tether routes")
	report["tether_controls"] = {"ok":checks.slice(begin).all(func(c: Dictionary) -> bool:return c.ok) and routes.size() == 4,"routes":routes}

func _through_late() -> void:
	if not _through_armed:
		if game.player.tape_step_count - _through_motor_start < 33:
			return
		check("Through Line raw route arms after exactly 33 relative motor steps", game.player.tape_step_count - _through_motor_start == 33)
		_through_armed = true
	else:
		_through_ids_ok = _through_ids_ok and _through_ids == [game.get_instance_id(),game.level.get_instance_id(),game.player.get_instance_id(),game.session.get_instance_id(),game.attempts]
		_through_clock_ok = _through_clock_ok and game.elapsed >= _through_clock
		_through_clock = game.elapsed
		_through_trace.append({"tick":_through_tick-1,"p":_v3(game.player.global_position),"v":_v3(game.player.velocity),
			"elapsed":game.elapsed,"checkpoint":game.checkpoint_index,"respawns":game.respawn_count})
		var label := ""
		if not game.player.last_landing.is_empty():label = "landing"
		elif not game.player.apex.is_empty():label = "apex"
		elif not game.player.last_launch.is_empty():label = "launch"
		if not label.is_empty() and not _through_captures.has(label):
			_through_captures[label] = true
			_capture = {"name":"through-"+str(_through_driver.duration)+"-"+label}
	if _through_tick >= _through_driver.duration or game.respawn_count > 0:
		_through_active = false
		through_step.emit()
		return
	_through_driver.step(_through_tick)
	_through_tick += 1
	through_step.emit()

func _through_controls() -> void:
	var begin := checks.size()
	var fixtures: Dictionary = spec.get("feature_tapes", {}).get("through", {})
	if not check("Through Line controls have both reader-derived speed fixtures", fixtures.has("slow") and fixtures.has("fast")):
		return
	var home: String = game.map_id
	var preset: String = game.preset_id
	if home != "through-line":
		await _pause_menu_click("Map_through-line", "Through Line transfer routes")
	await _restore_preset("server128")
	var late := Late.new()
	late.run = self
	late.process_physics_priority = 1001
	late.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(late)
	var routes: Array = []
	for label: String in ["slow", "fast"]:
		_through_driver = RAW_DRIVER.new()
		if not check(label+": load bounded Through Line input", _through_driver.configure(str(fixtures[label]))):break
		_through_tick = 0
		_through_armed = false
		_through_trace = []
		_through_ids = [game.get_instance_id(),game.level.get_instance_id(),game.player.get_instance_id(),game.session.get_instance_id(),game.attempts+1]
		_through_ids_ok = true
		_through_clock_ok = true
		_through_clock = 0.0
		_through_captures = {}
		_through_motor_start = game.player.tape_step_count
		_through_active = true
		await _tap(KEY_R)
		while _through_active:await through_step
		_through_driver.release()
		var launch: Dictionary = game.player.last_launch
		var apex: Dictionary = game.player.apex
		var landing: Dictionary = game.player.last_landing
		check(label+": clean packed transfer and continued second-segment run", game.finished and game.finish_kind == "clean" and game.respawn_count == 0 and game.player.continued and not launch.is_empty() and not apex.is_empty() and not landing.is_empty())
		check(label+": transfer retains scene, level, runner, session, attempt and continuous clock", _through_ids_ok and _through_clock_ok)
		if not launch.is_empty() and not landing.is_empty() and not apex.is_empty():
			var before: Vector3 = launch.before_mps
			var after: Vector3 = launch.after_mps
			var at_land: Vector3 = landing.v
			check(label+": launch and actual ballistic landing retain exact horizontal components", before.x == after.x and before.z == after.z and after.x == at_land.x and after.z == at_land.z and after.y > before.y, [before,after,at_land])
			check(label+": grounded second start support and activated self-made audio", str(landing.support.body).begins_with("second_start_") and bool(launch.cue.playing) and str(launch.cue.pcm_sha256).length() == 64)
			routes.append({"label":label,"speed_u":launch.speed_u,"rise_m":float(apex.reference_p.y)-float(launch.reference_p.y),
				"distance_m":Vector2(landing.reference_p.x-launch.reference_p.x,landing.reference_p.z-launch.reference_p.z).length(),
				"elapsed":game.elapsed,"ticks":_through_trace.size(),"launch":RUN_READER.json_safe(launch),"landing":RUN_READER.json_safe(landing)})
		await captured("through-"+label+"-finished", {"finished":true,"clean":true})
		report["through_trace_"+label] = _through_trace.duplicate(true)
	if routes.size() == 2:
		check("faster packed entry earns more height and distance", routes[1].speed_u > routes[0].speed_u and routes[1].rise_m > routes[0].rise_m and routes[1].distance_m > routes[0].distance_m, routes)
	late.queue_free()
	await _tap(KEY_R)
	await _restore_preset(preset)
	if home != "through-line":await _pause_menu_click("Map_"+home, "restore after Through Line")
	report["through_controls"] = {"ok":routes.size() == 2 and checks.slice(begin).all(func(c: Dictionary) -> bool:return c.ok),"routes":routes}

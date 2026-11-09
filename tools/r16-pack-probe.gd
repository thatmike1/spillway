extends Node
## p / packed r16 probe: a harness autoload for the exact shipped release runtime and pack, and
## (identity mode only) for the frozen source copy under the pinned editor.
## official release templates ignore --script and refuse --main-pack, but read an override.cfg
## beside the executable. tools/package-r16.py writes one into a harness copy of the extracted
## package, pointing here; the shipped folder itself never carries it. the engine then loads
## the pack's own run/main_scene as a player's launch does.
##
## modes (spec "mode"):
##   identity  source copy, headless: the registry, map identities, rates, record keys and
##             fingerprints, drawn node names, shaders, textures and loaded modules, read
##             through the game's own api. this is the frozen table the pack is judged against.
##   startup   identity, pack contents, drawn geometry, pause and Quit.
##   controls  real F-key, R, F, Esc and pause-menu clicks: every available preset and map,
##             practice purity after old-law motion before the timer starts, frame captures
##             that record the state actually drawn in that frame.
##   play      an expanded tape through Input at the executor's tick boundaries and the tape's
##             declared rate, records judged against the saved profile, a strict trace compare.
##   reload    a second process on the play profile: records loaded, shown and not rewritten.
## it never writes pose, velocity, progress or records and never calls the finish. identity
## mode calls select_map/select_preset; every other mode drives the game only through input.
## spec: -- --pack-probe=/abs/spec.json, written by package-r16.py.

const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL, "shift": KEY_SHIFT, "e": KEY_E}
const ACTIONS := {"w": "move_forward", "a": "move_left", "s": "move_back", "d": "move_right", "space": "jump", "ctrl": "crouch", "shift": "r15_slide", "e": "r15_grapple"}
## the screen points (fractions of the view) whose physics hit must be a drawn floor.
const FLOOR_PROBES := [Vector2(0.5, 0.92), Vector2(0.5, 0.82), Vector2(0.5, 0.72), Vector2(0.38, 0.88), Vector2(0.62, 0.88)]
const CAPTURE_SCALE := 0.5

class Early:
	extends Node
	var run: Variant
	func _physics_process(delta: float) -> void:
		run.early_step(delta)

class Late:
	extends Node
	var run: Variant
	func _physics_process(delta: float) -> void:
		run.late_step(delta)

signal drawn

var spec: Dictionary = {}
var expect: Dictionary = {}
var out_dir := ""
var checks: Array = []
var report: Dictionary = {}
var game: Node
var frames: Array = []
var _capture: Dictionary = {}
var _wall_start := 0

# tape state, as in tools/momentum-tape.gd
var keys_at: Dictionary = {}
var mouse_at: Dictionary = {}
var duration := 0
var tape_hz := 0
var arm_steps := 0
var next_tick := 0
var armed := false
var tape_done := false
var held: Dictionary = {}
var delivered_keys: Dictionary = {}
var trace: Array = []
var checkpoint_sequence: Array = []
var capture_ticks: Dictionary = {}
var _row: Dictionary = {}
var _mismatch_at_arm := 0
var _recorded_ticks_seen := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wall_start = Time.get_ticks_msec()
	var path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pack-probe="):
			path = arg.trim_prefix("--pack-probe=")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if path != "" else null
	if not parsed is Dictionary:
		printerr("r16 pack probe: no spec at ", path)
		get_tree().quit(2)
		return
	spec = parsed
	expect = spec.get("expect", {})
	out_dir = str(spec.get("out", ""))
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("frames"))
	var observer := SampleObserver.new()
	observer.probe = self
	observer.process_physics_priority = 1000
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(observer)
	RenderingServer.frame_post_draw.connect(_on_draw)
	# the main scene enters the tree after the autoloads; start once it is ready.
	await get_tree().process_frame
	_start()

func check(name: String, ok: bool, detail: Variant = "") -> bool:
	# details are frozen as text at assertion time, so later mutation cannot rewrite them.
	checks.append({"name": name, "ok": ok, "detail": JSON.parse_string(JSON.stringify(detail, "", false, true)) if detail is Dictionary or detail is Array else detail})
	print("%s r16 pack probe: %s %s" % ["PASS" if ok else "FAIL", name, "" if str(detail) == "" else "(" + str(detail).left(400) + ")"])
	return ok

func _start() -> void:
	game = get_tree().current_scene
	report["mode"] = str(spec.get("mode", "startup"))
	report["runtime"] = {"executable": OS.get_executable_path(), "template": OS.has_feature("template"),
		"template_release": OS.has_feature("template_release"), "debug_build": OS.is_debug_build(),
		"editor": OS.has_feature("editor"), "version": Engine.get_version_info(), "display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
		"res_root": ProjectSettings.globalize_path("res://"), "user_dir": OS.get_user_data_dir(),
		"project_name": str(ProjectSettings.get_setting("application/config/name")),
		"custom_user_dir": bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)),
		"cmdline": OS.get_cmdline_args(), "user_args": OS.get_cmdline_user_args(), "probe": (get_script() as Script).resource_path,
		"pack_sha256": FileAccess.get_sha256(str(spec.get("pack", ""))) if str(spec.get("pack", "")) != "" else ""}
	if report.mode == "reader":
		_reader_mode()
		return
	if report.mode == "source_features":
		await _source_features()
		return
	if report.mode == "identity":
		if game == null or not ("player" in game):
			_end("no r16 main")
			return
		await _identity()
		_end("")
		return
	var runtime: Dictionary = report.runtime
	check("release runtime, not the editor", runtime.template_release and not runtime.debug_build and not runtime.editor, runtime.executable)
	check("pack is the expected file", runtime.pack_sha256 == str(expect.get("pack_sha256", "")), runtime.pack_sha256)
	check("res:// has no loose root", runtime.res_root == "", runtime.res_root)
	check("profile identity is the shipped project's", runtime.project_name == str(expect.project_name) and not runtime.custom_user_dir
		and str(runtime.user_dir).ends_with("app_userdata/" + str(expect.project_name)), [runtime.project_name, runtime.user_dir])
	check("pack main scene", str(ProjectSettings.get_setting("application/run/main_scene")) == str(expect.main_scene), ProjectSettings.get_setting("application/run/main_scene"))
	check("engine runs that scene", game != null and game.scene_file_path == str(expect.main_scene), game.scene_file_path if game != null else "none")
	if game == null or not ("player" in game) or game.get("player") == null:
		_end("no r16 main")
		return
	_check_identity()
	_check_pack()
	_check_registry()
	if str(report.mode) == "play":
		# the executor's warmup is a handful of steps: attach before any wait.
		_arm_tape()
	# the camera follows the runner once it has stepped; judge the view after that.
	await _physics(3)
	_check_hud_words("startup")
	_r16_hud("startup")
	_check_map("startup")
	match str(report.mode):
		"controls":
			await _controls()
			_wrap_up.call_deferred()
		"play":
			pass
		_:
			_wrap_up.call_deferred()

# --- helpers --------------------------------------------------------------------------------

func _script_path(node: Object) -> String:
	var script := node.get_script() as Script if node != null else null
	return script.resource_path if script != null else ""

func _script_chain(node: Object) -> Array:
	var chain: Array = []
	var script := node.get_script() as Script if node != null else null
	while script != null:
		chain.append(script.resource_path)
		script = script.get_base_script()
	return chain

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _physics(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

## a key tap between frames, as a player's press and release would arrive.
func _tap(code: int) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)
	await _frames(2)

func _ui_tap(code: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		var picker := _hud().get("stage_picker") as OptionButton
		var popup := picker.get_popup() if picker != null else null
		if popup != null and popup.visible and not popup.is_embedded():
			# native subwindows receive their own window id, as real display events do.
			event.window_id = popup.get_window_id()
			Input.parse_input_event(event)
			Input.flush_buffered_events()
		else:
			get_viewport().push_input(event, true)
		await get_tree().process_frame

## a left click through the viewport's gui picking, at the centre of a visible control.
func _click(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var at := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	return true

## scrolls the pause menu with wheel events over it until the control is fully in view.
func _reveal(control: Control) -> void:
	if control == null:
		return
	var scroll: ScrollContainer = _hud().get("_pause_scroll")
	if scroll == null:
		return
	for i: int in 60:
		var view := scroll.get_global_rect()
		var rect := control.get_global_rect()
		if view.encloses(rect):
			return
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN if rect.position.y > view.position.y else MOUSE_BUTTON_WHEEL_UP
		event.pressed = true
		event.factor = 1.0
		event.position = view.get_center()
		event.global_position = view.get_center()
		get_viewport().push_input(event, true)
		event = event.duplicate()
		event.pressed = false
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	check("pause menu scrolled to " + str(control.name), false, [control.get_global_rect(), scroll.get_global_rect()])

func _hud() -> Node:
	return game.get("hud")

func _hud_text(field: String) -> String:
	var hud := _hud()
	var label: Variant = hud.get(field) if hud != null else null
	return str((label as Control).get("text")) if label is Control else ""

func _state() -> Dictionary:
	var hud := _hud()
	var tag: Variant = hud.get("practice_tag") if hud != null else null
	var pause: Variant = hud.get("pause_panel") if hud != null else null
	var message: Variant = hud.get("message") if hud != null else null
	var player: Node3D = game.get("player")
	var hull := _hull_observation(player)
	return {"process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames(),
		"map": str(game.get("map_id")), "preset": str(game.get("preset_id")), "physics_hz": int(game.get("physics_hz")),
		"engine_hz": Engine.physics_ticks_per_second, "rate_ok": bool(game.get("rate_ok")), "last_delta": float(game.get("last_delta")),
		"paused": bool(game.get("paused")), "clean": bool(game.get("clean_eligible")), "practice_reason": str(game.get("practice_reason")),
		"started": bool(game.get("_started")), "finished": bool(game.get("finished")), "attempts": int(game.get("attempts")),
		"checkpoint": int(game.get("checkpoint_index")), "practice_stage": int(game.get("practice_stage")),
		"course_key": str(game.get("course_key")), "runner": _script_path(player), "feet": _v3(player.global_position),
		"lab": bool(game.call("is_lab")), "lab_moves": game.call("lab_moves"),
		"grounded": player.call("is_grounded"), "hull": hull, "crouched": bool(game.call("is_crouched")),
		"stand_blocked": bool(game.call("stand_blocked")), "crouch_text": _hud_text("crouch_tag") if _label_drawn("crouch_tag") else "",
		"identity_text": _hud_text("identity"),
		"practice_tag": str((tag as Label).text) if tag is Label and (tag as Label).visible else "",
		"message": str((message as Label).text) if message is Label and (message as Label).modulate.a > 0.05 else "",
		"pause_visible": pause is Control and (pause as Control).visible, "title": get_window().title}

func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _plain(value: Variant) -> Variant:
	# motor reports remain distinct from the independently observed hull and input.
	if value is Vector3:
		return _v3(value)
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[str(key)] = _plain(value[key])
		return out
	if value is Array:
		return (value as Array).map(_plain)
	return value

func _input_observation() -> Dictionary:
	var out := {"actions": [], "physical": [], "just_pressed": [], "just_released": []}
	for key: String in ACTIONS:
		if Input.is_action_pressed(ACTIONS[key]):
			out.actions.append(key)
		if Input.is_physical_key_pressed(KEYS[key]):
			out.physical.append(key)
		if Input.is_action_just_pressed(ACTIONS[key]):
			out.just_pressed.append(key)
		if Input.is_action_just_released(ACTIONS[key]):
			out.just_released.append(key)
	return out

func _hull_observation(player: Node3D) -> Dictionary:
	if not player.has_method("hull_height_u") or not player.has_method("air_lift_u"):
		return {}
	var node: Variant = player.get("collision")
	var settings: Variant = player.get("settings")
	if not node is CollisionShape3D or not node.shape is BoxShape3D or not settings is Dictionary:
		return {}
	return {"box_size_m": _v3(node.shape.size), "box_center_m": _v3(node.position),
		"scale": _v3(node.global_transform.basis.get_scale()), "ducked": player.get("ducked"),
		"standing_u": settings.get("hull_height"), "duck_u": settings.get("duck_hull_height"),
		"anchor": settings.get("duck_air_anchor"), "interp_current": _v3(player.get("_current_position"))}

## json text with integral numbers written as integers: the frozen identity reaches the probe
## through json, which reads every number as a float.
func _canon(value: Variant) -> String:
	return JSON.stringify(_plain_numbers(value), "", true)

func _plain_numbers(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floorf(value) and absf(value) < 1e15:
		return int(value)
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[str(key)] = _plain_numbers(value[key])
		return out
	if value is Array:
		return (value as Array).map(_plain_numbers)
	return value

# --- identity -------------------------------------------------------------------------------

## the registry as the running game holds it: order, families and every entry's words.
func _registry() -> Dictionary:
	var presets: Script = game.get("PRESETS")
	var constants := presets.get_script_constant_map()
	var order: Array = constants.ORDER
	var entries := {}
	for id: String in order:
		var entry: Dictionary = presets.call("entry", id)
		entry["available"] = bool(presets.call("available", id))
		entries[id] = entry
	var families: Dictionary = constants.FAMILIES
	var slots := {}
	for id: String in order:
		slots[str(int(entries[id].slot))] = id
	return {"order": order, "presets": entries, "families": families, "slots": slots,
		"record_ticks_version": int(game.get("RECORD_TICKS_VERSION")),
		"default_preset": str(game.get("DEFAULT_PRESET")), "default_map": str((game.get("MAPS") as Script).call("default_id", game.get("maps"))),
		"maps": game.call("map_ids"), "timing_rules": str(game.get("TIMING_RULES")), "build": str(game.get("BUILD_ID")),
		"save_path": str(game.get("SAVE_PATH")), "hud_keys_line": str(_hud().get("R16_KEYS_LINE")) if _hud() != null else ""}

## the active map's identity, without anything that needs a renderer.
func _map_identity() -> Dictionary:
	var level: Node = game.get("level")
	var titles: Array = []
	var practice_points: Array = []
	for i: int in int(game.call("stage_count")):
		titles.append(game.call("segment_title", i))
		var point: Dictionary = (level.get("checkpoints") as Array)[i]
		var pose: Transform3D = point.pose
		practice_points.append({"title": str(game.call("stage_title", i)), "feet": _v3(pose.origin), "yaw": pose.basis.get_euler().y})
	var art: Dictionary = level.get_meta("overflow_art", {})
	var drawn := _drawn(level, false)
	return {"map": str(game.get("map_id")), "name": str(game.call("map_name")), "level_script": _script_path(level),
		"level_id": level.get("level_id"), "level_version": level.get("level_version"), "variant": level.get("variant"),
		"geometry": str(game.get("course_geometry")), "stages": int(game.call("stage_count")), "titles": titles,
		"practice_points": practice_points,
		"art": {"version": art.get("version", ""), "applied": bool(art.get("applied", false)), "reason": art.get("reason", "")},
		# engine-numbered names (@MeshInstance3D@283) depend on creation order across the process; they are counted.
		"meshes": drawn.nodes.keys().filter(func(n: String) -> bool: return not n.begins_with("@")),
		"unnamed_meshes": drawn.nodes.keys().filter(func(n: String) -> bool: return n.begins_with("@")).size(),
		"shaders": drawn.shaders.keys(), "textures": drawn.textures.keys()}

## the active preset's identity on the active map.
func _preset_identity() -> Dictionary:
	var player: Node = game.get("player")
	return {"preset": str(game.get("preset_id")), "physics_hz": int(game.get("physics_hz")), "engine_hz": Engine.physics_ticks_per_second,
		"course_key": str(game.get("course_key")), "record_identity": JSON.stringify(game.call("record_identity"), "", false, true),
		"fingerprint": JSON.stringify(game.call("physics_fingerprint"), "", true), "runner_chain": _script_chain(player),
		"clean": bool(game.get("clean_eligible")), "pending": str(game.get("pending_preset")),
		"family_version": str(game.call("family_version")), "runner": str(game.call("runner_path")),
		"hull": game.call("hull_identity"), "mechanics": game.call("mechanics"), "map_kind": game.call("map_kind") }

func _identity() -> void:
	await _physics(4)
	var start := {"map": str(game.get("map_id")), "preset": str(game.get("preset_id")), "physics_hz": int(game.get("physics_hz")),
		"course_key": str(game.get("course_key")), "runner_chain": _script_chain(game.get("player"))}
	var loaded: Array = []
	for path: String in spec.get("committed_resources", []):
		if ResourceLoader.has_cached(path):
			loaded.append(path)
	var registry := _registry()
	var maps := {}
	var keys := {}
	for map: String in registry.maps:
		if map == "fixture":
			continue
		if map != str(game.get("map_id")):
			game.call("select_map", map)
			await _physics(4)
		maps[map] = _map_identity()
		keys[map] = {}
		for id: String in registry.order:
			if not bool(registry.presets[id].available) or (bool(game.call("is_lab")) and not id in ["server128", "server128_aa1000"]):
				continue
			if id != str(game.get("preset_id")):
				game.call("select_preset", id)
				await _physics(6)
			keys[map][id] = _preset_identity()
		game.call("select_preset", start.preset)
		await _physics(6)
	if str(game.get("map_id")) != start.map:
		game.call("select_map", start.map)
		await _physics(4)
	report["identity"] = {"start": start, "loaded_at_start": loaded, "registry": registry, "maps": maps, "keys": keys,
		"main_script": _script_path(game), "hud_script": _script_path(game.get("hud")), "stats_script": _script_path(game.get("stats")),
		"audio_script": _script_path(game.get("audio")), "project_name": str(ProjectSettings.get_setting("application/config/name"))}

# --- startup identity, pack and world ------------------------------------------------------

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

func _check_hud_words(when: String) -> void:
	var texts: Array = []
	_collect_text(_hud(), texts)
	var joined := "\n".join(texts)
	report["hud_text_" + when] = texts
	var preset: Dictionary = game.get("preset")
	var line := _hud_text("identity")
	for field: String in ["identity", "speed_label", "speed_unit", "strafe_live", "strafe_last", "strafe_split", "strafe_chain"]:
		check(when + ": visible on-screen HUD " + field, _label_drawn(field), _hud_text(field))
	check(when + ": hud names map, preset key, label, rate and air", line.contains(str(game.call("map_name")).to_upper()) and line.contains("F%d %s" % [int(preset.slot), str(preset.label)])
		and line.contains("%d Hz" % int(game.get("physics_hz"))) and line.contains(str(preset.air)), line)
	for word: String in expect.get("hud_forbidden", []):
		check(when + ": hud never says " + word, not joined.to_lower().contains(word.to_lower()), "")

func _label_drawn(field: String) -> bool:
	return _drawn_label(_hud().get(field))

func _drawn_label(label: Variant) -> bool:
	if not label is Label or not label.is_visible_in_tree() or str(label.text).strip_edges().is_empty() \
		or (label.visible_characters >= 0 and label.visible_characters < label.get_total_character_count()):
		return false
	if label.lines_skipped > 0 or label.get_visible_line_count() < label.get_line_count():
		return false
	var rect: Rect2 = label.get_global_rect()
	var own_rect := Rect2(Vector2.ZERO, label.size).grow(0.5)
	for index: int in label.text.length():
		if label.text.substr(index, 1).strip_edges().is_empty():
			continue
		var glyph: Rect2 = label.get_character_bounds(index)
		if not glyph.has_area() or ((label.clip_text or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING) and not own_rect.encloses(glyph)):
			return false
		rect = rect.merge(label.get_global_transform() * glyph)
	var alpha := 1.0
	var node: Node = label
	while node != null:
		if node is Control and node.clip_contents and not node.get_global_rect().encloses(rect):
			return false
		if node is CanvasItem:
			# arbitrary canvas shaders can discard glyphs; this structural check supports plain labels only.
			if node.material != null or node.use_parent_material:
				return false
			alpha *= node.modulate.a
		node = node.get_parent()
	alpha *= label.self_modulate.a * label.get_theme_color("font_color").a
	return alpha > 0.05 and label.get_theme_font_size("font_size") > 0 and rect.size.x > 0.0 and rect.size.y > 0.0 and get_viewport().get_visible_rect().encloses(rect)

func _hud_feedback(when: String) -> void:
	_check_hud_words(when)
	var stats: Variant = game.get("stats")
	if stats == null:
		check(when + ": live strafe observer exists", false)
		return
	check(when + ": displayed speed agrees with measured travel", _hud_text("speed_label") == "%d" % roundi(float(game.call("display_speed_u"))) and _hud_text("speed_unit") == "u/s", _hud_text("speed_label"))
	var flight: Dictionary = stats.get("flight")
	var eligible := int(flight.get("eligible", 0)) if not flight.is_empty() else int(stats.get("total_eligible"))
	var good := int(flight.get("good", 0)) if not flight.is_empty() else int(stats.get("total_good"))
	var sync := "—" if eligible <= 0 else "%d %% (%d/%d)" % [roundi(100.0 * good / eligible), good, eligible]
	check(when + ": live sync agrees with sampled A/D counts", _hud_text("strafe_live").contains("sync " + sync), [good, eligible, _hud_text("strafe_live")])
	var hop: Dictionary = stats.get("last_hop")
	var expected := "last hop  —"
	if not hop.is_empty():
		var gain := roundi(float(hop.gain))
		var signed_gain := "±0" if gain == 0 else ("+" if gain > 0 else "-") + "%d" % absi(gain)
		var last_sync := "—" if int(hop.eligible) <= 0 else "%d %% (%d/%d)" % [roundi(100.0 * int(hop.good) / int(hop.eligible)), int(hop.good), int(hop.eligible)]
		expected = "last hop  %s u/s  ·  sync %s  ·  %d ticks" % [signed_gain, last_sync, int(hop.air_ticks)]
	check(when + ": displayed jump gain and sync agree with the completed hop", _hud_text("strafe_last") == expected, [_hud_text("strafe_last"), expected])

func _collect_text(node: Node, texts: Array) -> void:
	if node == null:
		return
	if node is Label or node is Button or node is RichTextLabel:
		var text := str(node.get("text"))
		if text != "":
			texts.append(text)
	for child: Node in node.get_children():
		_collect_text(child, texts)

func _list(path: String, out: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			_list(path.path_join(name), out)
		else:
			out[path.path_join(name)] = true
		name = dir.get_next()

func _check_pack() -> void:
	# with a pack mounted, DirAccess on res:// lists the pack only, never a loose fallback.
	var listed: Dictionary = {}
	_list("res://", listed)
	report["pack_files"] = listed.size()
	var missing: Array = []
	for path: String in expect.get("pack_required", []):
		var present := listed.has(path) or listed.has(path + ".remap") or listed.has(path + ".import")
		if path.ends_with(".gd"):
			present = listed.has(path + ".remap") and listed.has(path.get_basename() + ".gdc")
		if not present:
			missing.append(path)
	check("required resources are inside the pack", missing.is_empty(), missing)
	var stray: Array = []
	for path: String in listed:
		for prefix: String in expect.get("pack_forbidden_prefixes", []):
			if path.begins_with(prefix):
				stray.append(path)
		if path.ends_with(".gd") or path.get_file() == "override.cfg":
			stray.append(path)
	check("no tests, tools, docs, override or plain scripts in the pack", stray.is_empty(), stray)
	var unloaded: Array = []
	for path: String in expect.get("loaded_required", []):
		if not ResourceLoader.has_cached(path):
			unloaded.append(path)
	check("the running game loaded the frozen startup modules", unloaded.is_empty(), unloaded)

func _check_registry() -> void:
	var live := _registry()
	var frozen: Dictionary = expect.identity.registry
	for field: String in ["order", "slots", "default_preset", "default_map", "maps", "timing_rules", "build", "save_path", "hud_keys_line", "record_ticks_version"]:
		check("registry %s equals the frozen source" % field, _canon(live[field]) == _canon(frozen[field]), live[field])
	check("every preset entry and family equals the frozen source", _canon(live.presets) == _canon(frozen.presets) and _canon(live.families) == _canon(frozen.families), "")

## drawable geometry under a node: names with vertices, shaders and textures. with `vertices`
## off it lists what is meant to be drawn without reading mesh arrays (headless has none).
func _drawn(root: Node, vertices: bool) -> Dictionary:
	var out := {"nodes": {}, "shaders": {}, "textures": {}, "in_view": {}, "surfaces": {}, "instances": {}}
	_scan(root, out, vertices)
	return out

func _scan(node: Node, out: Dictionary, vertices: bool) -> void:
	if node == null:
		return
	var camera := get_viewport().get_camera_3d()
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		var mesh: Mesh
		if node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
		elif node is MultiMeshInstance3D:
			var mm := (node as MultiMeshInstance3D).multimesh
			if mm != null and mm.instance_count > 0 and mm.visible_instance_count != 0:
				mesh = mm.mesh
		var visible := mesh != null and geometry.is_visible_in_tree() and geometry.transparency < 1.0 \
			and geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY \
			and (camera == null or geometry.layers & camera.cull_mask != 0)
		if visible:
			var count := 0
			var in_view := 0
			var surfaces: Array = []
			for i: int in mesh.get_surface_count():
				var material := (node as MeshInstance3D).get_active_material(i) if node is MeshInstance3D else geometry.material_override
				if material == null:
					material = mesh.surface_get_material(i)
				if not _material_drawable(material):
					continue
				surfaces.append(i)
				_materials(material, out)
				if vertices:
					var arrays := mesh.surface_get_arrays(i)
					var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()
					count += points.size()
					if camera != null and node is MeshInstance3D:
						var to_world := (node as Node3D).global_transform
						for k: int in range(0, points.size(), maxi(1, points.size() / 400)):
							if camera.is_position_in_frustum(to_world * points[k]):
								in_view += 1
			if not surfaces.is_empty() and (not vertices or count >= 3):
				out.nodes[str(node.name)] = count
				out.surfaces[str(node.name)] = surfaces
				out.instances[str(node.get_instance_id())] = {"path": str(node.get_path()), "surfaces": surfaces}
			if in_view > 0:
				out.in_view[str(node.name)] = in_view
	for child: Node in node.get_children():
		_scan(child, out, vertices)

## reject known invisible standard materials; shader visibility still needs native inspection.
func _material_drawable(material: Material) -> bool:
	if material is BaseMaterial3D:
		var visible := true
		match material.transparency:
			BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				visible = material.albedo_color.a >= material.alpha_scissor_threshold
			BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
				visible = material.albedo_color.a > 0.0
		if not visible:
			return material.next_pass != null and _material_drawable(material.next_pass)
	return true

func _materials(material: Material, out: Dictionary) -> void:
	if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		var shader := (material as ShaderMaterial).shader
		out.shaders[shader.resource_path if shader.resource_path != "" else "<built-in>"] = true
		for uniform: Dictionary in shader.get_shader_uniform_list():
			var value: Variant = (material as ShaderMaterial).get_shader_parameter(uniform.name)
			if value is Texture2D and (value as Texture2D).resource_path != "":
				out.textures[(value as Texture2D).resource_path] = true
	elif material is BaseMaterial3D:
		for slot: int in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_ROUGHNESS, BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION, BaseMaterial3D.TEXTURE_ORM]:
			var texture := (material as BaseMaterial3D).get_texture(slot)
			if texture != null and texture.resource_path != "":
				out.textures[texture.resource_path] = true

## the active map's drawn world against the frozen source, plus a drawn floor where the
## physics says the view meets walkable ground.
func _check_map(when: String) -> void:
	var map := str(game.get("map_id"))
	var frozen: Dictionary = expect.identity.maps.get(map, {})
	var live := _map_identity()
	for field: String in ["level_script", "level_id", "level_version", "variant", "geometry", "stages", "titles", "art", "practice_points"]:
		check("%s: %s %s equals the frozen source" % [when, map, field], _canon(live[field]) == _canon(frozen.get(field)), live[field])
	var drawn := _drawn(game.get("level"), true)
	var empty: Array = []
	for name: String in frozen.get("meshes", []):
		if int(drawn.nodes.get(name, 0)) < 3:
			empty.append(name)
	check("%s: %s every frozen mesh is visible with real vertices" % [when, map], empty.is_empty() and not drawn.nodes.is_empty(), empty)
	var unnamed: int = drawn.nodes.keys().filter(func(n: String) -> bool: return n.begins_with("@") and int(drawn.nodes[n]) >= 3).size()
	check("%s: %s as many unnamed drawn meshes as the frozen source" % [when, map], unnamed == int(frozen.get("unnamed_meshes", -1)), [unnamed, frozen.get("unnamed_meshes")])
	check("%s: %s drawn with the frozen shaders and textures" % [when, map], _canon(live.shaders) == _canon(frozen.get("shaders")) and _canon(live.textures) == _canon(frozen.get("textures")), [live.shaders.size(), live.textures.size()])
	var kit := (live.textures as Array).filter(func(p: String) -> bool: return p.begins_with(str(expect.asset_prefix)))
	check("%s: %s textures come from the licensed asset kits" % [when, map], not kit.is_empty(), kit.size())
	check("%s: %s mesh vertices inside the camera view" % [when, map], drawn.in_view.size() > 0, drawn.in_view)
	var floors := _floor_hits(drawn)
	report["floor_" + when + "_" + map] = floors
	var good := floors.filter(func(f: Dictionary) -> bool: return bool(f.walkable) and str(f.drawn_by) != "")
	check("%s: %s the view meets walkable ground that is actually drawn" % [when, map], not good.is_empty(), floors)

func _floor_hits(drawn: Dictionary) -> Array:
	var hits: Array = []
	var camera := get_viewport().get_camera_3d()
	var player: CollisionObject3D = game.get("player")
	if camera == null:
		return hits
	var size := get_viewport().get_visible_rect().size
	for at: Vector2 in FLOOR_PROBES:
		var screen := Vector2(size.x * at.x, size.y * at.y)
		var from := camera.project_ray_origin(screen)
		var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen) * 300.0, 1, [player.get_rid()])
		var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			hits.append({"screen": [at.x, at.y], "hit": false, "walkable": false, "drawn_by": ""})
			continue
		var point: Vector3 = hit.position
		var normal: Vector3 = hit.normal
		var body := hit.collider as Node
		var surface := _triangle_hit(game.get("level"), point, drawn)
		hits.append({"screen": [at.x, at.y], "hit": true, "point": _v3(point), "normal": _v3(normal), "collider": str(body.name) if body != null else "",
			"role": str(body.get_meta("surface", "")) if body != null else "", "walkable": normal.y > 0.7,
			"drawn_by": str(surface.get("mesh", "")), "drawn_path": str(surface.get("path", "")), "drawn_surface": int(surface.get("surface", -1))})
	return hits

## the name of a drawn mesh with a triangle through this point (within 3 cm), or "".
func _triangle_at(root: Node, point: Vector3, drawn: Dictionary) -> String:
	return str(_triangle_hit(root, point, drawn).get("mesh", ""))

func _triangle_hit(root: Node, point: Vector3, drawn: Dictionary) -> Dictionary:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var eligible: Dictionary = drawn.get("instances", {}).get(str(instance.get_instance_id()), {})
		if eligible.is_empty() or instance.mesh == null:
			continue
		var box := instance.global_transform * instance.mesh.get_aabb()
		if not box.grow(0.05).has_point(point):
			continue
		var local := instance.global_transform.affine_inverse() * point
		for i: int in instance.mesh.get_surface_count():
			if not i in eligible.get("surfaces", []):
				continue
			var arrays := instance.mesh.surface_get_arrays(i)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := index.size() if not index.is_empty() else points.size()
			for t: int in range(0, count - 2, 3):
				var a := points[index[t] if not index.is_empty() else t]
				var b := points[index[t + 1] if not index.is_empty() else t + 1]
				var c := points[index[t + 2] if not index.is_empty() else t + 2]
				if _on_triangle(local, a, b, c, 0.03):
					return {"mesh": str(instance.name), "path": str(eligible.path), "surface": i}
	return {}

func _on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3, tolerance: float) -> bool:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return false
	n = n.normalized()
	if absf((p - a).dot(n)) > tolerance:
		return false
	var q := p - n * (p - a).dot(n)
	var c1 := (b - a).cross(q - a).dot(n)
	var c2 := (c - b).cross(q - b).dot(n)
	var c3 := (a - c).cross(q - c).dot(n)
	return (c1 >= -1e-6 and c2 >= -1e-6 and c3 >= -1e-6) or (c1 <= 1e-6 and c2 <= 1e-6 and c3 <= 1e-6)

# --- frame-synchronized captures ------------------------------------------------------------

## asks for the next drawn frame and returns the state read while that frame was drawn.
func capture(name: String) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return _state()
	_capture = {"name": name}
	await drawn
	return frames[-1].state

func _on_draw() -> void:
	if _capture.is_empty() or out_dir == "":
		return
	var name := str(_capture.name)
	_capture = {}
	var state := _state()
	if str(report.get("mode")) == "play" and not bool(state.paused):
		_hud_feedback("draw " + name)
	var image := get_viewport().get_texture().get_image()
	var full := Vector2i(image.get_width(), image.get_height())
	image.resize(maxi(1, int(full.x * CAPTURE_SCALE)), maxi(1, int(full.y * CAPTURE_SCALE)), Image.INTERPOLATE_BILINEAR)
	var file := out_dir.path_join("frames/%03d_%s.png" % [frames.size(), name])
	image.save_png(file)
	# a uniform or splash frame has almost no spread; a drawn course has plenty.
	var total := 0.0
	var squares := 0.0
	var samples := 0
	for y: int in range(4, image.get_height(), maxi(1, image.get_height() / 12)):
		for x: int in range(4, image.get_width(), maxi(1, image.get_width() / 16)):
			var value := image.get_pixel(x, y).get_luminance()
			total += value
			squares += value * value
			samples += 1
	var mean := total / maxf(1.0, samples)
	frames.append({"name": name, "file": file, "size": [full.x, full.y], "sha256": FileAccess.get_sha256(file),
		"luminance_spread": sqrt(maxf(0.0, squares / maxf(1.0, samples) - mean * mean)), "state": state})
	drawn.emit()

## a capture whose drawn-frame state must hold the expected values.
func captured(name: String, wanted: Dictionary) -> Dictionary:
	var state: Dictionary = await capture(name)
	var wrong := {}
	for key: String in wanted:
		var value: Variant = state.get(key)
		var want: Variant = wanted[key]
		var ok: bool = value == want
		if want is String and str(want).begins_with("~"):
			ok = str(value).contains(str(want).substr(1))
		if not ok:
			wrong[key] = [value, want]
	var spread := float(frames[-1].luminance_spread) if not frames.is_empty() and DisplayServer.get_name() != "headless" else 1.0
	check("frame %s shows the state it is named for" % name, wrong.is_empty() and spread > 0.02, {"wrong": wrong, "spread": spread})
	return state

# --- controls -------------------------------------------------------------------------------

func _slot_key(id: String) -> int:
	return KEY_F1 + int((expect.identity.registry.presets[id] as Dictionary).slot) - 1

func _available() -> Array:
	var registry: Dictionary = expect.identity.registry
	var available: Dictionary = expect.identity.keys.get(str(game.get("map_id")), {})
	return (registry.order as Array).filter(func(id: String) -> bool: return available.has(id))

func _controls() -> void:
	var registry: Dictionary = expect.identity.registry
	var keys: Dictionary = expect.identity.keys
	var start_map := str(game.get("map_id"))
	var start_preset := str(game.get("preset_id"))
	await _physics(8)
	await captured("startup", {"map": start_map, "preset": start_preset, "clean": true, "paused": false, "rate_ok": true})
	# every available preset by its own key at the untouched spawn: clean stays clean.
	for map: String in [start_map] + (registry.maps as Array).filter(func(m: String) -> bool: return m != start_map and m != "fixture"):
		if map != str(game.get("map_id")):
			await _pause_menu_click("Map_" + map, "map %s from the pause menu" % map)
			await _physics(6)
			await captured("map-" + map, {"map": map, "preset": str(game.get("preset_id")), "clean": true, "paused": false, "attempts": int(game.get("attempts"))})
			_check_map("map " + map)
		for id: String in _available():
			if id == str(game.get("preset_id")):
				continue
			var feet: Array = _v3((game.get("player") as Node3D).global_position)
			_key(_slot_key(id), true)
			await _frames(2)
			_key(_slot_key(id), false)
			await _physics(maxi(8, int(registry.presets[id].rate) / 8))
			var key: Dictionary = keys[map][id]
			var entry: Dictionary = registry.presets[id]
			var state: Dictionary = await captured("%s-%s" % [map, id], {"map": map, "preset": id, "physics_hz": int(key.physics_hz), "engine_hz": int(key.physics_hz),
				"clean": true, "course_key": str(key.course_key), "rate_ok": true, "identity_text": "~F%d %s" % [int(entry.slot), str(entry.label)]})
			check("%s %s: callbacks run at the preset's rate after the switch" % [map, id], is_equal_approx(float(state.last_delta), 1.0 / float(key.physics_hz)) and float(state.last_delta) == 1.0 / float(key.physics_hz), state.last_delta)
			check("%s %s: runner is the frozen family's" % [map, id], _script_chain(game.get("player")) == key.runner_chain, _script_chain(game.get("player")))
			check("%s %s: switch at the untouched spawn kept the feet" % [map, id], _same_feet(feet, state.feet), [feet, state.feet])
			check("%s %s: window title follows the preset" % [map, id], str(state.title) == str(game.call("window_title")) and str(state.title).contains("%d Hz" % int(key.physics_hz)), state.title)
			_check_hud_words("%s %s" % [map, id])
		await _restore_preset(start_preset)
		await _stage_picker_controls(map)
		if map == "experiment":
			await _lab_controls(start_map, start_preset)
	if str(game.get("map_id")) != start_map:
		await _pause_menu_click("Map_" + start_map, "map %s from the pause menu" % start_map)
		await _physics(6)
	# a reserved slot says what it is and changes nothing.
	for slot: String in registry.slots:
		var id: String = registry.slots[slot]
		if bool(registry.presets[id].available):
			continue
		var before := str(game.get("preset_id"))
		_key(KEY_F1 + int(slot) - 1, true)
		await _frames(2)
		_key(KEY_F1 + int(slot) - 1, false)
		await _frames(3)
		await captured("reserved-f" + slot, {"preset": before, "clean": true, "message": "~F%s:" % slot})
	await _purity()
	await _crouch_controls()
	# use F for practice from the reached stage, R: a clean attempt again.
	await _tap(KEY_F)
	await _physics(4)
	await captured("practice-key", {"clean": false, "practice_reason": "practice", "practice_tag": "~PRACTICE"})
	await _tap(KEY_R)
	await _physics(4)
	await captured("restart-key", {"clean": true, "practice_reason": "", "practice_tag": "", "started": false})
	# a preset button in the pause menu switches like its key; the menu stays open.
	var others := _available().filter(func(id: String) -> bool: return id != str(game.get("preset_id")))
	if not others.is_empty():
		var id: String = others[0]
		await _pause_menu_click("Preset_" + id, "preset %s from the pause menu" % id, false)
		await _physics(8)
		await captured("menu-preset-" + id, {"preset": id, "paused": true, "pause_visible": true})
		_key(KEY_ESCAPE, true)
		await _frames(2)
		_key(KEY_ESCAPE, false)
		await _frames(3)
		await _restore_preset(start_preset)
	await _physics(6)
	await captured("controls-done", {"map": start_map, "preset": start_preset, "paused": false})

func _lab_controls(home_map: String, home_preset: String) -> void:
	# exercise the real lab keys, menu and host transitions, never a runner setter.
	await _restore_preset("server128")
	await _tap(KEY_R)
	await _physics(4)
	var all_on := {"slide": true, "wall_jump": true, "grapple": true}
	var default_key := str(game.get("course_key"))
	await captured("lab-default", {"map": "experiment", "lab": true, "lab_moves": all_on, "clean": true,
		"runner": "res://scripts/r16_experiment_player.gd", "message": ""})
	check("lab title and visible HUD identify the experiment", str(game.call("window_title")).contains("EXPERIMENTAL")
		and _label_drawn("lab_tag") and _hud_text("lab_tag").contains("EXPERIMENTAL")
		and _label_drawn("lab_panel") and _label_drawn("reticle"), _hud_text("lab_panel"))
	for slot: int in [3, 4]:
		await _tap(KEY_F1 + slot - 1)
		await captured("lab-refuses-f%d" % slot, {"preset": "server128", "clean": true, "message": "~F2 and F5 only"})
	var ids := ["slide", "wall_jump", "grapple"]
	for i: int in ids.size():
		var off := all_on.duplicate()
		off[ids[i]] = false
		await _tap(KEY_1 + i)
		await captured("lab-" + str(ids[i]) + "-off", {"lab_moves": off, "clean": true})
		check("lab %s has a separate record key" % ids[i], str(game.get("course_key")) != default_key, game.get("course_key"))
		await _tap(KEY_1 + i)
		await captured("lab-" + str(ids[i]) + "-restored", {"lab_moves": all_on, "clean": true, "course_key": default_key})
	await _pause_menu_click("LabMove_grapple", "lab grapple switch", false)
	var menu_off := all_on.duplicate()
	menu_off.grapple = false
	await captured("lab-menu-grapple-off", {"lab_moves": menu_off, "paused": true, "clean": true})
	await _tap(KEY_ESCAPE)
	await _tap(KEY_3)
	await captured("lab-menu-key-agree", {"lab_moves": all_on, "paused": false, "course_key": default_key})
	await _tap(KEY_2)
	var wall_off := all_on.duplicate()
	wall_off.wall_jump = false
	await _tap(KEY_F5)
	await _physics(4)
	await captured("lab-f5-keeps-loadout", {"preset": "server128_aa1000", "lab_moves": wall_off, "clean": true,
		"runner": "res://scripts/r16_experiment_player.gd"})
	await _restore_preset("server128")
	await _tap(KEY_2)
	await _tap(KEY_R)
	_key(KEY_W, true)
	await _physics(4)
	_key(KEY_W, false)
	var used := bool(game.get("_used_preset_physics"))
	var started := bool(game.get("_started"))
	await _tap(KEY_1)
	await captured("lab-moved-toggle-is-practice", {"clean": false, "practice_reason": "mechanics", "practice_tag": "~lab moves changed"})
	check("lab toggle purity includes motion before the timer starts", used and not started, [used, started])
	await _tap(KEY_R)
	await _tap(KEY_1)
	await captured("lab-reset-default-loadout", {"clean": true, "lab_moves": all_on, "course_key": default_key})
	await _r16_slide_chain()
	await _tap(KEY_R)
	await _stage_picker_controls("experiment", 2, false)
	await _r16_wall_chamber()
	await _tap(KEY_R)
	await _pause_menu_click("Map_" + home_map, "leave lab for the normal course")
	await _physics(6)
	check("leaving the lab restores the frozen approved runner", _script_chain(game.get("player")) == expect.identity.keys[home_map]["server128"].runner_chain)
	check("normal course hides experimental state and restores its record key", game.call("lab_moves").is_empty()
		and not _label_drawn("lab_tag") and not _label_drawn("lab_panel") and not _label_drawn("reticle")
		and str(game.get("course_key")) == str(expect.identity.keys[home_map]["server128"].course_key))
	_key(KEY_SHIFT, true)
	_key(KEY_E, true)
	await _physics(4)
	await captured("course-ignores-lab-keys", {"lab": false, "lab_moves": {}, "crouched": false, "clean": true})
	_key(KEY_SHIFT, false)
	_key(KEY_E, false)
	await _tap(KEY_F3)
	await _physics(8)
	await _pause_menu_click("Map_experiment", "enter lab from the R13 comparison")
	await _physics(6)
	await captured("lab-from-f3-uses-f2", {"map": "experiment", "preset": "server128", "lab": true,
		"lab_moves": all_on, "clean": true, "runner": "res://scripts/r16_experiment_player.gd", "message": "~switched from"})
	await _pause_menu_click("Map_" + home_map, "return from lab")
	await _restore_preset(home_preset)
	var input := _input_observation()
	check("lab controls leave all keys neutral", input.actions.is_empty() and input.physical.is_empty(), input)

func _crouch_controls() -> void:
	# actual controls on the default course, without a diagnostic hull or test-only roof.
	var start := str(game.get("preset_id"))
	await _restore_preset("server128")
	await _tap(KEY_R)
	await _physics(8)
	_key(KEY_C, true)
	await _physics(4)
	var state := await captured("ground-crouch-c", {"crouched": true, "grounded": true, "crouch_text": "~CROUCH"})
	check("C changes the real standing box to the 54 u crouched box", _crouch_box(state, 54.0), state.hull)
	_key(KEY_C, false)
	await _physics(4)
	state = await captured("ground-stand", {"crouched": false, "grounded": true, "crouch_text": ""})
	check("releasing C restores the real 72 u standing box", _crouch_box(state, 72.0), state.hull)
	_key(KEY_SPACE, true)
	await _physics(5)
	_key(KEY_SPACE, false)
	_key(KEY_CTRL, true)
	await _physics(3)
	state = await captured("air-crouch-ctrl", {"crouched": true, "grounded": false, "crouch_text": "~CROUCH"})
	check("Ctrl changes the real box while airborne", _crouch_box(state, 54.0), state.hull)
	_key(_slot_key("server128_aa1000"), true)
	await _frames(2)
	_key(_slot_key("server128_aa1000"), false)
	await _physics(3)
	state = await captured("air-crouch-f5", {"preset": "server128_aa1000", "crouched": true, "clean": false,
		"practice_reason": "preset", "crouch_text": "~CROUCH"})
	check("F2 to F5 keeps the crouched box", _crouch_box(state, 54.0), state.hull)
	_key(KEY_CTRL, false)
	await _physics(4)
	state = await captured("air-stand", {"crouched": false, "grounded": false, "crouch_text": ""})
	check("releasing Ctrl restores the box in clear air", _crouch_box(state, 72.0), state.hull)
	await _tap(KEY_R)
	await _restore_preset(start)
	await _physics(4)
	await captured("crouch-controls-reset", {"preset": start, "clean": true, "started": false, "crouched": false})
	await _tap(KEY_F1)
	await captured("vanilla-retired", {"preset": start, "clean": true, "started": false, "message": "~F1:"})
	var input := _input_observation()
	check("crouch controls leave neutral keys", input.actions.is_empty() and input.physical.is_empty() and not Input.is_physical_key_pressed(KEY_C), input)

func _crouch_box(state: Dictionary, height_u: float) -> bool:
	var hull: Dictionary = state.get("hull", {})
	var size: Array = hull.get("box_size_m", [])
	var center: Array = hull.get("box_center_m", [])
	if size.size() != 3 or center.size() != 3:
		return false
	return absf(float(size[0]) - 32.0 * 0.0254) < 1e-6 and absf(float(size[2]) - 32.0 * 0.0254) < 1e-6 \
		and absf(float(size[1]) - height_u * 0.0254) < 1e-6 and absf(float(center[1]) - height_u * 0.0254 * 0.5) < 1e-6

func _stage_picker_controls(map: String, requested_stage: int = -1, restart_after: bool = true) -> void:
	await _tap(KEY_ESCAPE)
	var picker := _hud().get("stage_picker") as OptionButton
	var button := _hud().get("stage_practice_button") as Button
	check(map + ": stage picker exists", picker != null and button != null)
	if picker == null or button == null:
		return
	var points: Array = expect.identity.maps[map].practice_points
	var stage := mini(3, points.size() - 1) if requested_stage < 0 else requested_stage
	check(map + ": stage picker lists the frozen stages", picker.item_count == points.size())
	for i: int in mini(picker.item_count, points.size()):
		check("%s: picker stage %d title" % [map, i], picker.get_item_id(i) == i and picker.get_item_text(i).contains(str(points[i].title)), picker.get_item_text(i))
	await _reveal(picker)
	check(map + ": stage picker clicked", await _click(picker))
	var popup := picker.get_popup()
	check(map + ": stage picker popup opened", popup.visible)
	check(map + ": Linux release picker uses the native focus workaround", not (OS.get_name() == "Linux" and OS.has_feature("template_release") and DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS)) or not popup.is_embedded())
	for i: int in popup.item_count * 2 + 2:
		var focus := popup.get_focused_item()
		if focus == stage:
			break
		await _ui_tap(KEY_DOWN if focus < stage else KEY_UP)
	await _ui_tap(KEY_ENTER)
	check(map + ": keyboard selected the requested stage", picker.get_selected_id() == stage, picker.get_selected_id())
	await captured(map + "-stage-picker", {"paused": true, "pause_visible": true})
	await _reveal(button)
	check(map + ": Practise here clicked", await _click(button))
	await _physics(4)
	var state := await captured(map + "-stage-practice", {"paused": false, "clean": false, "practice_reason": "practice", "practice_stage": stage, "checkpoint": stage,
		"practice_tag": "~checkpoint practice from " + str(points[stage].title)})
	check(map + ": checkpoint practice is visibly labelled", _label_drawn("practice_tag"), state.practice_tag)
	var feet: Array = points[stage].feet
	var target := Vector3(float(feet[0]), float(feet[1]), float(feet[2]))
	check(map + ": practice reached the frozen stage pose", (game.get("player") as Node3D).global_position.distance_to(target) < 0.15, [state.feet, feet])
	if restart_after:
		await _tap(KEY_R)
		await _physics(4)
		await captured(map + "-stage-practice-restart", {"paused": false, "clean": true, "practice_stage": -1, "checkpoint": 0, "started": false, "message": ""})

func _same_feet(a: Array, b: Array) -> bool:
	return Vector3(a[0], a[1], a[2]).distance_to(Vector3(b[0], b[1], b[2])) < 0.05

func _restore_preset(id: String) -> void:
	if str(game.get("preset_id")) == id:
		return
	await _tap(KEY_R)
	_key(_slot_key(id), true)
	await _frames(2)
	_key(_slot_key(id), false)
	await _physics(8)
	await _tap(KEY_R)
	await _physics(4)
	check("restored preset %s with a clean attempt" % id, str(game.get("preset_id")) == id and bool(game.get("clean_eligible")), [game.get("preset_id"), game.get("clean_eligible")])

## press Esc, a click on a named pause-menu button, and (unless the button keeps it open) the
## menu closed again by what the button did.
func _pause_menu_click(button_name: String, what: String, closes: bool = true) -> void:
	if str(report.mode) in ["play", "reload"]:
		await _ghost_checks()
	_key(KEY_ESCAPE, true)
	await _frames(2)
	_key(KEY_ESCAPE, false)
	await _frames(4)
	await captured("pause-for-" + button_name.to_lower(), {"paused": true, "pause_visible": true})
	var button := _hud().find_child(button_name, true, false) as Button
	await _reveal(button)
	var clicked := await _click(button)
	await _frames(4)
	check("clicked " + what, clicked and (not closes or not bool(game.get("paused"))), [clicked, game.get("paused")])

## a preset switch after any motion under the old law is practice, even before the timer's
## 0.5 m start threshold; one at the untouched spawn is not. same body and cross-family.
func _purity() -> void:
	var registry: Dictionary = expect.identity.registry
	var start := str(game.get("preset_id"))
	var family := str(registry.presets[start].family)
	var same := _available().filter(func(id: String) -> bool: return id != start and str(registry.presets[id].family) == family)
	var cross := _available().filter(func(id: String) -> bool: return str(registry.presets[id].family) != family)
	var cases: Array = []
	if not same.is_empty():
		cases.append({"name": "walk-then-same-family", "to": same[0], "motion": "w"})
	if not cross.is_empty():
		cases.append({"name": "hop-then-cross-family", "to": cross[0], "motion": "space"})
	check("purity cases cover the families present", not cases.is_empty(), cases)
	for case: Dictionary in cases:
		await _restore_preset(start)
		await _tap(KEY_R)
		await _physics(6)
		var spawn: Array = _v3((game.get("player") as Node3D).global_position)
		_key(KEYS[case.motion], true)
		await _physics(4)
		_key(KEYS[case.motion], false)
		await _physics(3)
		var moved := bool(game.get("_used_preset_physics"))
		var before_started := bool(game.get("_started"))
		_key(_slot_key(case.to), true)
		await _frames(2)
		_key(_slot_key(case.to), false)
		await _physics(6)
		var state: Dictionary = await captured("purity-" + str(case.name), {"preset": str(case.to), "clean": false, "practice_reason": "preset", "practice_tag": "~PRACTICE (preset switched mid-run)"})
		check("purity %s: old-law motion happened before the timer started" % case.name, moved and not before_started, [moved, before_started, spawn, state.feet])
	await _restore_preset(start)

# --- tape -----------------------------------------------------------------------------------

func _arm_tape() -> void:
	var tape: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(spec.get("tape", ""))))
	var player: Node = game.get("player")
	if not tape is Dictionary or not tape.get("expanded", false) or tape.has("curves"):
		check("tape is an expanded tape", false, spec.get("tape"))
		_end("bad tape")
		return
	tape_hz = int(tape.get("physics_hz", 0))
	check("tape rate is the active preset's and the engine's", tape_hz == int(game.get("physics_hz")) and tape_hz == Engine.physics_ticks_per_second, [tape_hz, game.get("physics_hz"), Engine.physics_ticks_per_second])
	duration = int(tape.duration_ticks)
	arm_steps = int(spec.get("arm_motor_steps", 0))
	for event: Dictionary in tape.events:
		var tick := int(event.tick)
		if event.has("key"):
			if not keys_at.has(tick):
				keys_at[tick] = []
			keys_at[tick].append({"key": str(event.key), "edge": str(event.edge)})
		elif event.has("mouse"):
			mouse_at[tick] = Vector2(float(event.mouse[0]), float(event.mouse[1]))
	for tick: Variant in spec.get("capture_ticks", []):
		capture_ticks[int(tick)] = true
	report["tape"] = {"path": spec.tape, "sha256": FileAccess.get_sha256(str(spec.tape)), "ticks": duration, "physics_hz": tape_hz, "arm_motor_steps": arm_steps}
	if not "tape_step_count" in player or int(player.get("tape_step_count")) >= arm_steps:
		check("probe attached before the motor's warmup ended", false, player.get("tape_step_count"))
		_end("late attach")
		return
	var early := Early.new()
	early.name = "ProbeEarly"
	early.run = self
	early.process_physics_priority = -1000
	early.process_mode = Node.PROCESS_MODE_ALWAYS
	var late := Late.new()
	late.name = "ProbeLate"
	late.run = self
	late.process_physics_priority = 1000
	late.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(early)
	get_tree().root.add_child(late)

func _process(_delta: float) -> void:
	if armed or tape_done or duration == 0 or game == null:
		return
	var motor_steps := int(game.get("player").get("tape_step_count"))
	if motor_steps >= arm_steps:
		# between physics steps, as the executor arms: tick 0 opens the next physics step.
		armed = true
		_mismatch_at_arm = int(game.get("rate_mismatch_ticks"))
		var player: Node3D = game.get("player")
		var spawn: Transform3D = game.get("level").get("spawn")
		report.tape["armed_after_motor_steps"] = motor_steps
		report.tape["rate_log_before_arm"] = game.get("rate_log")
		check("tape armed on a frame boundary after exactly the reference warmup", motor_steps == arm_steps, [motor_steps, arm_steps])
		check("normal spawn: first attempt at the map's spawn", int(game.get("attempts")) == 1 and int(game.get("checkpoint_index")) == 0
			and Vector2(player.global_position.x - spawn.origin.x, player.global_position.z - spawn.origin.z).length() < 0.05 and not bool(game.get("_started")), _v3(player.global_position))
		_deliver_keys(0)

func early_step(delta: float) -> void:
	if not armed or tape_done:
		_row = {}
		return
	var player: Node3D = game.get("player")
	_row = {"tick": next_tick, "dt": delta, "pre_p": _v3(player.global_position), "pre_steps": player.get("tape_step_count")}
	var audit := {"physics_frame": Engine.get_physics_frames(), "in_physics_early": Engine.is_in_physics_frame(),
		"pre": {"p": _v3(player.global_position), "grounded": player.call("is_grounded"),
			"interp_current": _v3(player.get("_current_position")), "yaw": player.get("yaw"), "pitch": player.get("pitch")},
		"input_early": _input_observation(), "keys": delivered_keys.get(next_tick, []), "mouse": {}}
	var hull := _hull_observation(player)
	if not hull.is_empty():
		audit["hull_origin"] = {"before": hull}
	_row["audit"] = audit
	delivered_keys.erase(next_tick)
	if mouse_at.has(next_tick):
		var event := InputEventMouseMotion.new()
		event.relative = mouse_at[next_tick]
		event.screen_relative = mouse_at[next_tick]
		var yaw_before := float(player.get("yaw"))
		var pitch_before := float(player.get("pitch"))
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		audit.mouse = {"relative": [event.relative.x, event.relative.y], "screen_relative": [event.screen_relative.x, event.screen_relative.y],
			"yaw_before": yaw_before, "pitch_before": pitch_before, "yaw_after": player.get("yaw"), "pitch_after": player.get("pitch")}

func late_step(delta: float) -> void:
	if _row.is_empty():
		return
	var tick := int(_row.tick)
	var player: Node3D = game.get("player")
	next_tick = tick + 1
	var index := int(game.get("checkpoint_index"))
	if checkpoint_sequence.is_empty() or checkpoint_sequence[-1] != index:
		checkpoint_sequence.append(index)
	var current_sample: Dictionary = game.get("session").get("last_sample")
	var recorded_id := str(game.get("session").get("recorder").get("run_id"))
	var recorded_tick := int(current_sample.get("tick", -1))
	if int(_recorded_ticks_seen.get(recorded_id, -1)) == recorded_tick:
		recorded_tick = -1
	else:
		_recorded_ticks_seen[recorded_id] = recorded_tick
	_row.merge({"recording_tick": recorded_tick, "run_id": game.get("session").get("recorder").get("run_id"), "dt_late": delta, "engine_hz": Engine.physics_ticks_per_second, "rate_ok": game.get("rate_ok"),
		"physics_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(), "motor_steps": player.get("tape_step_count"),
		"p": _v3(player.global_position), "v": _v3((player as CharacterBody3D).velocity), "yaw": player.get("yaw"), "pitch": player.get("pitch"), "checkpoint": index,
		"elapsed": game.get("elapsed"), "finished": game.get("finished"), "finish_kind": game.get("finish_kind"),
		"respawns": game.get("respawn_count"), "clean": game.get("clean_eligible")})
	var audit: Dictionary = _row.audit
	audit["post"] = _input_observation()
	var motion: Dictionary = player.call("get_motion_state") if player.has_method("get_motion_state") else {}
	audit.post["motion_state"] = _plain({"duck_shift": motion.get("duck_shift", Vector3.ZERO), "duck": motion.get("duck", {})})
	audit["order"] = {"same_physics_frame": int(audit.physics_frame) == Engine.get_physics_frames(), "in_physics": Engine.is_in_physics_frame(),
		"motor_prev_matches_pre": _v3(player.get("_previous_position")) == audit.pre.interp_current,
		"motor_cur_matches_body": player.get("_current_position") == player.global_position,
		"step_count_delta": int(player.get("tape_step_count")) - int(_row.pre_steps)}
	if audit.has("hull_origin"):
		audit.hull_origin["after"] = _hull_observation(player)
		audit.hull_origin["motor_previous"] = _v3(player.get("_previous_position"))
	trace.append(_row)
	_row = {}
	if capture_ticks.has(tick):
		_capture = {"name": "tick_%05d" % tick}
	if tick + 1 >= duration:
		_end_tape()
		return
	_deliver_keys(tick + 1)

func _deliver_keys(tick: int) -> void:
	for edge: Dictionary in keys_at.get(tick, []):
		var pressed: bool = edge.edge == "press"
		_key(KEYS[edge.key], pressed)
		if not delivered_keys.has(tick):
			delivered_keys[tick] = []
		delivered_keys[tick].append({"key": edge.key, "edge": edge.edge, "motor_steps": game.get("player").get("tape_step_count"),
			"physics_frame": Engine.get_physics_frames(), "in_physics": Engine.is_in_physics_frame()})
		if pressed:
			held[edge.key] = true
		else:
			held.erase(edge.key)

func _end_tape() -> void:
	tape_done = true
	for key: String in KEYS:
		_key(KEYS[key], false)
	held.clear()
	var still: Array = []
	for key: String in ACTIONS:
		if Input.is_action_pressed(ACTIONS[key]):
			still.append(key)
	check("neutral input after the tape", still.is_empty(), still)
	_judge_run()
	_wrap_up.call_deferred()

func _judge_run() -> void:
	var stages := int(game.call("stage_count"))
	var times: Array = game.get("stage_times")
	var elapsed := float(game.get("elapsed"))
	var bad_rate := trace.filter(func(r: Dictionary) -> bool: return float(r.dt) != 1.0 / float(tape_hz) or float(r.dt_late) != 1.0 / float(tape_hz) or int(r.engine_hz) != tape_hz or not bool(r.rate_ok))
	check("every tape tick ran at the declared rate, exactly", bad_rate.is_empty() and int(game.get("rate_mismatch_ticks")) == _mismatch_at_arm and trace.size() == duration, [bad_rate.slice(0, 3), trace.size(), duration])
	var steps_ok := true
	for row: Dictionary in trace:
		steps_ok = steps_ok and int(row.motor_steps) - int(row.pre_steps) == 1
	check("exactly one motor step per tape tick", steps_ok, "")
	report["run"] = {"finished": game.get("finished"), "finish_kind": game.get("finish_kind"), "elapsed": elapsed,
		"respawns": game.get("respawn_count"), "checkpoint_sequence": checkpoint_sequence, "stage_times": times,
		"best_time": game.get("best_time"), "open_best_time": game.get("open_best_time"), "best_splits": game.get("best_splits"), "best_segments": game.get("best_segments"),
		"previous_best": game.get("previous_best"), "last_save_ok": game.get("last_save_ok"), "profile_state": game.get("profile_state"),
		"course_key": game.get("course_key"), "map": game.get("map_id"), "preset": game.get("preset_id"), "physics_hz": game.get("physics_hz"), "style_best": game.get("style_best"), "ghost_pointer": game.get("ghost_pointer")}
	var run: Dictionary = report.run
	check("the run finished clean", bool(run.finished) and str(run.finish_kind) == "clean", [run.finished, run.finish_kind])
	check("zero respawns", int(run.respawns) == 0, run.respawns)
	check("stages reached in order", checkpoint_sequence == range(stages), checkpoint_sequence)
	var increasing := times.size() == stages
	for i: int in times.size():
		increasing = increasing and float(times[i]) > (float(times[i - 1]) if i > 0 else 0.0)
	check("every stage measured, increasing", increasing, times)
	check("finish time is the last split", times.size() == stages and float(times[-1]) == elapsed, elapsed)
	var split_ticks: Array[int] = []
	var segment_ticks: Array[int] = []
	var previous := 0
	for time: float in times:
		var current := roundi(time * tape_hz)
		split_ticks.append(current)
		segment_ticks.append(current - previous)
		previous = current
	var elapsed_ticks := roundi(elapsed * tape_hz)
	run["record_ticks"] = {"clean_best": elapsed_ticks, "open_best": elapsed_ticks, "splits": split_ticks, "segments": segment_ticks}
	check("first clean run becomes the exact-tick best", float(run.previous_best) < 0.0 and float(run.best_time) == float(elapsed_ticks) / tape_hz and float(run.open_best_time) == float(elapsed_ticks) / tape_hz and run.best_splits == _seconds_from_ticks(split_ticks, tape_hz), [run.previous_best, run.best_time, run.open_best_time])
	check("first run records its actual segment ticks", run.best_segments == _seconds_from_ticks(segment_ticks, tape_hz), run.best_segments)
	check("records saved to the profile", bool(run.last_save_ok) and str(run.profile_state) == "saved", run.profile_state)
	check("clean style best includes this final sealed score", typeof(game.get("style_best")) == TYPE_INT and int(game.get("style_best")) >= 0 and int(game.get("style_best")) == int((game.get("finish_style") as Dictionary).get("score", -1)), game.get("finish_style"))
	check("fastest clean recorded ghost is promoted", game.get("session").get("ghost_state") == "loaded" and not (game.get("ghost_pointer") as Dictionary).is_empty())
	_check_saved(elapsed)
	if str(spec.get("reference_trace", "")) != "":
		_compare_reference(str(spec.reference_trace))

## the saved section, value by value, against the live game and the frozen source key.
func _check_saved(elapsed: float) -> void:
	var file := ProjectSettings.globalize_path(str(expect.save_path))
	var config := ConfigFile.new()
	var loaded := config.load(file) == OK
	var section := "course_" + str(game.get("course_key"))
	var key: Dictionary = expect.identity.keys.get(str(game.get("map_id")), {}).get(str(game.get("preset_id")), {})
	var map: Dictionary = expect.identity.maps.get(str(game.get("map_id")), {})
	var registry: Dictionary = expect.identity.registry
	var preset: Dictionary = registry.presets.get(str(game.get("preset_id")), {})
	var family: Dictionary = registry.families.get(str(preset.get("family", "")), {})
	var courses := (config.get_sections() as Array).filter(func(s: String) -> bool: return s.begins_with("course_")) if loaded else []
	report["profile"] = {"file": file, "sha256": FileAccess.get_sha256(file), "sections": config.get_sections() if loaded else []}
	check("profile holds exactly this key's section", loaded and courses == [section] and section == "course_" + str(key.get("course_key", "")), courses)
	var wanted := {"map": str(game.get("map_id")), "map_name": str(map.get("name")), "map_kind": str(key.get("map_kind")),
		"identity": str(key.get("record_identity")), "geometry": str(map.get("geometry")), "rules": str(registry.timing_rules),
		"preset": str(game.get("preset_id")), "preset_label": str(preset.get("label")), "family": str(preset.get("family")),
		"family_version": str(key.get("family_version")), "runner": str(key.get("runner")), "standin": false,
		"physics_hz": int(key.get("physics_hz", -1)), "stages": int(map.get("stages", -1)),
		"clean_best": _as_saved(game.get("best_time")), "open_best": _as_saved(game.get("open_best_time"))}
	var ticks: Dictionary = report.run.record_ticks
	wanted.merge({"time_ticks_version": int(registry.record_ticks_version), "clean_best_ticks": int(ticks.clean_best),
		"open_best_ticks": int(ticks.open_best), "clean_split_ticks": ticks.splits, "clean_segment_ticks": ticks.segments})
	# float summaries may round in configfile; integer fields, independently derived above,
	# are authoritative and get a strict type/value comparison instead of a rounding allowance.
	var loss := 0.0
	var lived: Array = [game.get("best_time"), game.get("open_best_time")]
	var trip: Array = [wanted.clean_best, wanted.open_best]
	for i: int in lived.size():
		var gap := absf(float(trip[i]) - float(lived[i]))
		loss = maxf(loss, gap)
	report["record_text_loss_s"] = loss
	var saved := {}
	for name: String in wanted:
		saved[name] = config.get_value(section, name, null) if loaded else null
		var exact := name in ["physics_hz", "time_ticks_version", "clean_best_ticks", "open_best_ticks", "clean_split_ticks", "clean_segment_ticks"]
		check("profile saves %s" % name, _same_ticks(saved[name], wanted[name]) if exact else _same_record(saved[name], wanted[name]), saved[name])
	report.profile["records"] = saved
	check("profile names this build and format", loaded and str(config.get_value("profile", "build", "")) == str(expect.build) and int(config.get_value("profile", "format", -1)) == int(expect.profile_format), "")
	var override := float(game.get("source_sensitivity_override"))
	check("a replay's sensitivity override is not saved", override <= 0.0 or not (loaded and config.has_section_key("settings", "source_sensitivity")), override)

func _as_read(value: float) -> float:
	# godot's json reader is not correctly rounded (it reads 0.008333333333333333 one ulp low), so
	# the live clock goes through the same text trip as the reference before the exact compare.
	# package-r16.py compares the written trace again with python's exact reader.
	return float(JSON.parse_string(JSON.stringify(value, "", false, true)))

func _finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))

func _valid_vector(value: Variant) -> bool:
	return value is Array and value.size() == 3 and value.all(_finite_number)

func _trace_valid(rows: Array, packed: bool) -> bool:
	if rows.is_empty():
		return false
	for tick: int in rows.size():
		var row: Variant = rows[tick]
		if not row is Dictionary or not _finite_number(row.get("tick")) or float(row.tick) != float(tick):
			return false
		if packed and (typeof(row.tick) != TYPE_INT or not _valid_vector(row.get("pre_p"))):
			return false
		var motion: Variant = row if packed else row.get("post")
		var state: Variant = row if packed else row.get("game")
		if not motion is Dictionary or not _valid_vector(motion.get("p")) or not _valid_vector(motion.get("v")) or not _finite_number(motion.get("yaw")) or not _finite_number(motion.get("pitch")) or not state is Dictionary:
			return false
		for field: String in ["checkpoint", "elapsed", "finished", "finish_kind", "respawns"]:
			if not state.has(field):
				return false
		if not _finite_number(state.elapsed) or float(state.elapsed) < 0.0 or not state.finished is bool or not state.finish_kind is String:
			return false
		for field: String in ["checkpoint", "respawns"]:
			if not _finite_number(state[field]) or float(state[field]) < 0.0 or float(state[field]) != floorf(float(state[field])):
				return false
	return true

func _compare_reference(path: String) -> void:
	# the source executor's run of the same tape on the frozen commit. positions must match
	# exactly; yaw allows 1e-12 rad for its trip through json text.
	var reference: Dictionary = {}
	var reference_rows: Array = []
	var parsed_ok := true
	var file := FileAccess.open(path, FileAccess.READ)
	while file != null and not file.eof_reached():
		var line := file.get_line()
		if line == "":
			continue
		var row: Variant = JSON.parse_string(line)
		if not row is Dictionary:
			parsed_ok = false
		if row is Dictionary and row.get("phase") == "tape":
			reference_rows.append(row)
	var valid := parsed_ok and _trace_valid(trace, true) and _trace_valid(reference_rows, false) and trace.size() == reference_rows.size()
	check("both trace sequences are complete, ordered and finite", valid, [trace.size(), reference_rows.size()])
	if not valid:
		return
	for row: Dictionary in reference_rows:
		reference[int(row.tick)] = row
	var worst := 0.0
	var worst_velocity := 0.0
	var worst_yaw := 0.0
	var worst_pitch := 0.0
	var first_diff := -1
	var game_diff: Array = []
	var compared := 0
	for row: Dictionary in trace:
		var other: Variant = reference.get(int(row.tick))
		if other == null:
			continue
		compared += 1
		var a := Vector3(row.p[0], row.p[1], row.p[2])
		var b := Vector3(other.post.p[0], other.post.p[1], other.post.p[2])
		var gap := a.distance_to(b)
		if gap > 0.0 and first_diff < 0:
			first_diff = int(row.tick)
		worst = maxf(worst, gap)
		worst_velocity = maxf(worst_velocity, Vector3(row.v[0], row.v[1], row.v[2]).distance_to(Vector3(other.post.v[0], other.post.v[1], other.post.v[2])))
		worst_yaw = maxf(worst_yaw, absf(float(row.yaw) - float(other.post.yaw)))
		worst_pitch = maxf(worst_pitch, absf(float(row.pitch) - float(other.post.pitch)))
		var g: Dictionary = other.get("game", {})
		if game_diff.size() < 5 and (int(g.get("checkpoint", -1)) != int(row.checkpoint) or float(g.get("elapsed", -1.0)) != _as_read(row.elapsed) or bool(g.get("finished", false)) != bool(row.finished) or str(g.get("finish_kind", "")) != str(row.finish_kind) or int(g.get("respawns", -1)) != int(row.respawns)):
			game_diff.append({"tick": row.tick, "pack": [row.checkpoint, row.elapsed, row.finished], "source": [g.get("checkpoint"), g.get("elapsed"), g.get("finished")]})
	var start: Variant = reference.get(0)
	var pre_gap := -1.0
	if start != null and not trace.is_empty():
		pre_gap = Vector3(trace[0].pre_p[0], trace[0].pre_p[1], trace[0].pre_p[2]).distance_to(Vector3(start.pre.p[0], start.pre.p[1], start.pre.p[2]))
	report["reference"] = {"path": path, "ticks_compared": compared, "reference_ticks": reference.size(), "max_position_m": worst, "max_velocity_m_s": worst_velocity, "max_yaw_rad": worst_yaw, "max_pitch_rad": worst_pitch,
		"first_position_difference_tick": first_diff, "tick0_pre_position_gap_m": pre_gap, "game_state_differences": game_diff, "tolerance_m": 0.0}
	check("packed run matches the source executor tick for tick", compared == trace.size() and compared == reference.size() and worst == 0.0 and worst_velocity == 0.0 and worst_yaw <= 1e-12 and worst_pitch <= 1e-12 and pre_gap == 0.0, report.reference)
	check("progress, clock and finish match the source executor every tick", game_diff.is_empty(), game_diff)

# --- end: records shown, pause, quit through the panel --------------------------------------

func _as_saved(value: Variant) -> Variant:
	# a value as the records file gives it back: written and parsed by ConfigFile.
	var out := ConfigFile.new()
	out.set_value("v", "v", value)
	var back := ConfigFile.new()
	back.parse(out.encode_to_text())
	return back.get_value("v", "v")

func _same_record(actual: Variant, wanted: Variant) -> bool:
	if (actual is Array or actual is PackedFloat64Array or actual is PackedFloat32Array or actual is PackedStringArray) and (wanted is Array or wanted is PackedFloat64Array or wanted is PackedFloat32Array or wanted is PackedStringArray):
		if actual.size() != wanted.size():
			return false
		for i: int in actual.size():
			if not _same_record(actual[i], wanted[i]):
				return false
		return true
	if (actual is float or actual is int) and (wanted is float or wanted is int):
		return is_finite(float(actual)) and absf(float(actual) - float(wanted)) <= 1e-9
	return typeof(actual) == typeof(wanted) and actual == wanted or (actual is String and wanted is String and actual == wanted)

func _same_ticks(actual: Variant, wanted: Variant) -> bool:
	if wanted is Array:
		if not actual is Array or actual.size() != wanted.size():
			return false
		for i: int in wanted.size():
			if not _same_ticks(actual[i], wanted[i]):
				return false
		return true
	return typeof(actual) == TYPE_INT and typeof(wanted) == TYPE_INT and actual == wanted

func _seconds_from_ticks(ticks: Array, hz: int) -> Array:
	var seconds: Array = []
	for value: Variant in ticks:
		# the probe's json spec carries integral numbers as floats, so cast once before division.
		seconds.append(float(int(value)) / hz)
	return seconds

func _clock(value: float) -> String:
	return "%02d:%05.2f" % [int(value) / 60, fmod(value, 60.0)]

func _wrap_up() -> void:
	await _frames(int(spec.get("settle_frames", 45)))
	if str(report.mode) in ["play", "reload"]:
		_r16_hud("settled")
	await capture("settled")
	if str(report.mode) == "reload":
		var records: Dictionary = expect.get("records", {})
		check("reload restores the profile", str(game.get("profile_state")) == "loaded", game.get("profile_state"))
		var ticks: Dictionary = records.get("record_ticks", {})
		var hz := int(game.get("physics_hz"))
		var wanted := {"best_time": float(int(ticks.get("clean_best", -1))) / hz,
			"open_best_time": float(int(ticks.get("open_best", -1))) / hz,
			"best_splits": _seconds_from_ticks(ticks.get("splits", []), hz),
			"best_segments": _seconds_from_ticks(ticks.get("segments", []), hz)}
		check("reload restores clean style best exactly", int(game.get("style_best")) == int(records.get("style_best", -2)), game.get("style_best"))
		check("reload restores fastest recorded ghost in a separate process", not (records.get("ghost_pointer", {}) as Dictionary).is_empty() and game.get("session").get("ghost_state") == "loaded" and game.get("session").get("ghost_path") == str((records.ghost_pointer as Dictionary).get("path", "")), game.get("ghost_pointer"))
		for key: String in wanted:
			check("reload restores exact-tick " + key, not ticks.is_empty() and game.get(key) == wanted[key], game.get(key))
	if str(report.mode) in ["play", "reload"]:
		await _ghost_checks()
	_key(KEY_ESCAPE, true)
	await _frames(2)
	_key(KEY_ESCAPE, false)
	await _frames(4)
	var hud := _hud()
	var identity := _hud_text("pause_identity")
	var records := _hud_text("pause_records")
	report["pause"] = {"paused": game.get("paused"), "identity": identity, "records": records}
	check("Esc pauses", bool(game.get("paused")), "")
	check("pause names this build, record key and preset", identity.contains(str(expect.build)) and identity.contains(str(game.get("course_key")).left(8))
		and identity.contains(str((game.get("preset") as Dictionary).label)), identity)
	if str(report.mode) in ["play", "reload"]:
		var wanted := "Best %s" % _clock(float(game.get("best_time")))
		if float(game.get("open_best_time")) > 0.0:
			wanted += "  ·  open line %s" % _clock(float(game.get("open_best_time")))
		wanted += "  ·  style best %s" % str((_hud().get("style_panel") as Control).call("points_text", int(game.get("style_best")))) if int(game.get("style_best")) >= 0 else "  ·  no style best yet"
		check("pause shows the actual best values", records == wanted, [records, wanted])
	await captured("pause", {"paused": true, "pause_visible": true})
	_end("")

func _end(reason: String) -> void:
	if game != null and "session" in game and game.get("session") != null and str(report.mode) not in ["identity", "reader"]:
		report["recordings"] = _recording_receipt()
		report["recorded_tape_inputs"] = trace.filter(func(r: Dictionary) -> bool: return int(r.get("recording_tick", -1)) >= 0).map(func(r: Dictionary) -> Dictionary: return {"tape_tick": r.tick, "run_id": r.get("run_id", ""), "recording_tick": r.recording_tick, "keys": r.audit.keys, "mouse": r.audit.mouse})
		report["recorded_tape_tick_count"] = report.recorded_tape_inputs.size()
	report["checks"] = checks
	report["frames"] = frames
	report["failures"] = checks.filter(func(c: Dictionary) -> bool: return not c.ok).size() + (1 if reason != "" else 0)
	report["abort"] = reason
	report["trace_ticks"] = trace.size()
	report["wall_s"] = (Time.get_ticks_msec() - _wall_start) / 1000.0
	var file := FileAccess.open(out_dir.path_join("probe.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ", false, true))
	file.close()
	if not trace.is_empty():
		var lines := FileAccess.open(out_dir.path_join("trace.jsonl"), FileAccess.WRITE)
		for row: Dictionary in trace:
			lines.store_line(JSON.stringify(row, "", false, true))
		lines.close()
	print("r16 pack probe: %s, %d failures" % [report.mode, report.failures])
	var hud: Node = game.get("hud") if game != null else null
	var quit_button: Variant = hud.get("quit_button") if hud != null else null
	if reason == "" and quit_button is Button and (quit_button as Button).is_visible_in_tree():
		# the player's way out: a left click on Quit, through the viewport's gui picking.
		await _reveal(quit_button)
		await _click(quit_button)
		# the Quit button ends the process; still running means it did not.
		await _frames(240)
		print("FAIL r16 pack probe: Quit did not end the process")
	get_tree().quit(3 if report.mode not in ["identity", "reader", "source_features"] or reason != "" else 0)

# --- r16 observation and feature gates -------------------------------------------------------

const RUN_READER := preload("res://scripts/r16_run_reader.gd")
const HELD_ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "r15_slide", "r15_grapple", "look_left", "look_right", "look_up", "look_down"]
var observed_samples: Array = []
var lab_observations: Array = []
var _seen_sample: Dictionary = {}
var delivered_inputs: Array = []
var _style_seen: Dictionary = {}

## independent raw motion-input receipt, before serialization; lifecycle edges have their own audit.
func _input(event: InputEvent) -> void:
	var host := get_tree().current_scene
	if host == null or not ("session" in host) or host.get("session") == null or bool(host.get("paused")):
		return
	var session: Node = host.get("session")
	if not bool(session.get("attempt_live")) or not session.get("recorder").call("is_open"):
		return
	var data := {}
	if event is InputEventKey and not event.echo and (event.physical_keycode in KEYS.values() or event.keycode in KEYS.values()):
		data = {"type": "key", "keycode": event.keycode, "physical_keycode": event.physical_keycode, "pressed": event.pressed, "echo": event.echo}
	elif event is InputEventMouseMotion:
		data = {"type": "mouse_motion", "relative": [event.relative.x, event.relative.y], "screen_relative": [event.screen_relative.x, event.screen_relative.y]}
	if not data.is_empty():
		delivered_inputs.append({"run_id": session.get("recorder").get("run_id"), "tick": session.get("tick"), "data": data})

class SampleObserver extends Node:
	var probe: Node
	func _physics_process(delta: float) -> void:
		probe.observe_actual(delta)

func observe_actual(delta: float) -> void:
	var host := get_tree().current_scene
	if host == null or not ("session" in host) or host.get("session") == null or host.get("player") == null:
		return
	var session: Node = host.get("session")
	var sample: Dictionary = session.get("last_sample")
	if sample.is_empty() or is_same(sample, _seen_sample):
		return
	_seen_sample = sample
	var player := host.get("player") as CharacterBody3D
	var held_now := {}
	for action: String in HELD_ACTIONS:
		held_now[action] = InputMap.has_action(action) and Input.is_action_pressed(action)
	var exact := {}
	for field: String in ["yaw", "pitch"]:
		exact[field] = PackedFloat64Array([float(player.get(field))]).to_byte_array().hex_encode()
	exact["dt"] = PackedFloat64Array([delta]).to_byte_array().hex_encode()
	exact["elapsed"] = PackedFloat64Array([float(host.get("elapsed"))]).to_byte_array().hex_encode()
	var run_id := str(session.get("recorder").get("run_id"))
	var style: RefCounted = session.get("style")
	var all_style: Array = style.get("events")
	var scored: Array = RUN_READER.json_safe(all_style.slice(int(_style_seen.get(run_id, 0))))
	_style_seen[run_id] = all_style.size()
	observed_samples.append({"style_events": scored, "style_score": style.get("score"), "scalar_hex": exact,"run_id": session.get("recorder").get("run_id"), "tick": int(sample.tick), "p": _v3(player.global_position),
		"v": _v3(player.velocity), "yaw": player.get("yaw"), "pitch": player.get("pitch"), "dt": delta,
		"physics_hz": Engine.physics_ticks_per_second, "elapsed": host.get("elapsed"), "checkpoint": host.get("checkpoint_index"),
		"respawns": host.get("respawn_count"), "held": held_now})
	if bool(host.call("is_lab")):
		var motion: Dictionary = player.call("get_motion_state")
		var lab: Dictionary = motion.get("experiment", {})
		lab_observations.append({"p": _v3(player.global_position), "v": _v3(player.velocity), "grounded": player.call("is_grounded"),
			"held": held_now, "events": lab.get("events", []), "wall": lab.get("wall_jump", {}), "slide": lab.get("slide", {})})

func _recording_receipt() -> Dictionary:
	var session: Node = game.get("session")
	var attempts: Array = (session.get("sealed") as Array).duplicate(true)
	var recorder: RefCounted = session.get("recorder")
	if bool(session.get("attempt_live")) and recorder.call("is_open"):
		attempts.append({"kind": "quit", "ok": true, "path": recorder.get("final_path"), "run_id": recorder.get("run_id")})
	return {"audit_version": 2, "delivered_inputs": delivered_inputs, "attempts": attempts, "observed": observed_samples, "lab": RUN_READER.json_safe(lab_observations)}

func _reader_mode() -> void:
	var decoded := {}
	for path: String in spec.get("paths", []):
		var run: Dictionary = RUN_READER.read(path)
		check("current reader validates " + path.get_file(), bool(run.ok), run.errors)
		var item: Dictionary = RUN_READER.json_safe(run)
		item["column_hex"] = {}
		item["input_hex"] = {}
		for key: String in run.columns:
			item.column_hex[key] = run.columns[key].to_byte_array().hex_encode()
		for key: String in run.inputs:
			item.input_hex[key] = run.inputs[key].to_byte_array().hex_encode()
		decoded[path] = item
	report["reader_runs"] = decoded
	_end("")

func _r16_hud(when: String) -> void:
	var panel: Control = _hud().get("style_panel")
	check(when + ": full style score glyphs are drawn", panel != null and _drawn_label(panel.get("score_label")))
	if panel != null:
		var score: Label = panel.get("score_label")
		var live: Dictionary = game.get("session").get("style").call("snapshot")
		check(when + ": visible score equals actual style total", score.text == str(panel.call("points_text", int(live.score))), [score.text, live.score])
	check(when + ": recorder after stats and before next-tick input", int(game.get("session").get("process_physics_priority")) > int(game.get("stats").get("process_physics_priority"))
		and int(game.get("session").get("process_physics_priority")) < 1000)

func _source_features() -> void:
	await _physics(12)
	check("source feature host is actual R16", _script_path(game) == "res://scripts/r16_main.gd")
	check("source explicitly enabled isolated attempt files", bool(game.get("record_runs")))
	_key(KEY_W, true)
	_key(KEY_SPACE, true)
	for i: int in 100:
		var mouse := InputEventMouseMotion.new()
		mouse.relative = Vector2(3.0, -0.2)
		mouse.screen_relative = mouse.relative
		Input.parse_input_event(mouse)
		Input.flush_buffered_events()
		await _physics(1)
	_key(KEY_W, false)
	_key(KEY_SPACE, false)
	await _tap(KEY_R)
	await _physics(5)
	await _tap(KEY_F)
	await _physics(5)
	await _tap(KEY_F5)
	await _physics(5)
	await _tap(KEY_F2)
	await _physics(5)
	game.call("select_map", "experiment")
	await _physics(5)
	check("source lab uses actual R16 law", _script_path(game.get("player")) == "res://scripts/r16_experiment_player.gd")
	await _r16_slide_chain()
	await _tap(KEY_R)
	game.call("practise_stage", 2)
	await _physics(4)
	await _r16_wall_chamber()
	await _tap(KEY_R)
	await _physics(3)
	await _frames(4)
	_r16_hud("source")
	await _tap(KEY_ESCAPE)
	await _frames(3)
	_end("")

func _lab_grounded() -> bool:
	return bool(game.get("player").call("is_grounded"))

func _lab_feet() -> Vector3:
	return (game.get("player") as Node3D).global_position

func _lab_wait(done: Callable, limit: int) -> bool:
	for i: int in limit:
		if done.call():
			return true
		await _physics(1)
	return done.call()

func _r16_slide_chain() -> void:
	# p / earned spawn circle strafe, then Shift during descent while Space remains held.
	_key(KEY_W, true)
	await _physics(50)
	_key(KEY_SPACE, true)
	await _lab_wait(func() -> bool: return not _lab_grounded(), 60)
	_key(KEY_W, false)
	_key(KEY_D, true)
	var built := false
	for i: int in 1500:
		var v: Vector3 = game.get("player").get("velocity")
		if Vector2(v.x, v.z).length() / 0.0254 >= 330.0 and absf(wrapf(atan2(-v.x, -v.z), -PI, PI)) < 0.05 and not _lab_grounded():
			built = true
			break
		var mouse := InputEventMouseMotion.new()
		mouse.relative = Vector2(24.0, 0.0)
		mouse.screen_relative = mouse.relative
		Input.parse_input_event(mouse)
		Input.flush_buffered_events()
		await _physics(1)
	_key(KEY_D, false)
	await _lab_wait(_lab_grounded, 200)
	await _lab_wait(func() -> bool: return not _lab_grounded(), 10)
	await _lab_wait(func() -> bool: return (game.get("player").get("velocity") as Vector3).y < 0.0 and _lab_feet().y < 0.45, 200)
	_key(KEY_SHIFT, true)
	var entered := await _lab_wait(func() -> bool: return str(game.get("player").get("slide_kind")) == "landing", 100)
	await _physics(20)
	var stayed := _lab_grounded()
	_key(KEY_SPACE, false)
	await _physics(1)
	_key(KEY_SPACE, true)
	var hopped := await _lab_wait(func() -> bool: return not _lab_grounded(), 20)
	_key(KEY_SHIFT, false)
	_key(KEY_SPACE, false)
	check("lab earned >330 u/s circle strafe", built)
	check("lab descent Shift catches held-Space bhop and keeps grounded", entered and stayed)
	check("lab a fresh Space hops out of the landing slide", hopped)

func _r16_wall_chamber() -> void:
	# the shipped station, no fixture walls: held A to west face, held D to east face.
	var begin := lab_observations.size()
	_key(KEY_W, true)
	await _lab_wait(func() -> bool: return _lab_feet().z < -45.0, 900)
	_key(KEY_A, true)
	await _lab_wait(func() -> bool: return _lab_feet().z < -50.3, 900)
	_key(KEY_SPACE, true)
	await _physics(1)
	_key(KEY_SPACE, false)
	_key(KEY_W, false)
	var stage := 0
	for i: int in 500:
		await _physics(1)
		var air := not _lab_grounded()
		var v: Vector3 = game.get("player").get("velocity")
		if stage == 0 and air and v.y / 0.0254 < 30.0:
			await _tap(KEY_SPACE)
			await _physics(4)
			_key(KEY_A, false)
			_key(KEY_D, true)
			stage = 1
		elif stage == 1 and air and _lab_feet().x > 1.6 - 16.0 * 0.0254 - 0.03:
			await _tap(KEY_SPACE)
			await _physics(4)
			_key(KEY_D, false)
			_key(KEY_W, true)
			stage = 2
		elif stage == 2 and air and _lab_feet().z < -55.6:
			await _tap(KEY_SPACE)
			stage = 3
		if _lab_grounded() and i > 20:
			break
	await _physics(30)
	_key(KEY_W, false)
	_key(KEY_A, false)
	_key(KEY_D, false)
	var rows := lab_observations.slice(begin)
	var kicks := rows.filter(func(r: Dictionary) -> bool: return "wall_jump" in r.events)
	var refused := rows.filter(func(r: Dictionary) -> bool: return "wall_refused" in r.events and str(r.wall.get("refusal", "")) == "budget spent")
	var refill := rows.filter(func(r: Dictionary) -> bool: return "wall_refill" in r.events and r.grounded and int(r.wall.get("budget", -1)) == 2)
	check("lab two kicks with A/D held, no W in air at kicks", kicks.size() == 2 and kicks.all(func(r: Dictionary) -> bool: return not bool(r.held.move_forward) and (r.held.move_left or r.held.move_right)), RUN_READER.json_safe(kicks))
	check("lab third wall refused by bounded budget", not refused.is_empty())
	check("lab budget refills on a real landing", not refill.is_empty())
	check("lab kicks reach the station mezzanine", _lab_feet().y > 3.1 and _lab_feet().z < -56.0, _v3(_lab_feet()))

func _ghost_checks() -> void:
	var session: Node = game.get("session")
	var ghost: Node3D = session.get("ghost")
	var path := str(session.get("ghost_path"))
	var run: Dictionary = RUN_READER.read(path)
	if not check("ghost current recording is complete", bool(run.ok), run.errors):
		return
	var c: Dictionary = run.columns
	var flags: PackedInt32Array = c.flags
	var start := -1
	for i: int in flags.size():
		if flags[i] & 1 != 0:
			start = i
			break
	var valid := start >= 0 and flags.size() > start + 1
	if valid:
		for i: int in range(maxi(start, 1), flags.size() - 1, maxi(1, flags.size() / 11)):
			var time := (float(c.elapsed[i]) + float(c.elapsed[i + 1])) * 0.5
			var pose: Dictionary = ghost.call("pose_at", time)
			var expected_p: Vector3 = (c.p[i] as Vector3).lerp(c.p[i + 1], 0.5)
			valid = valid and (pose.feet as Vector3).distance_to(expected_p) < 1e-5
	check("ghost interpolates between the recorded tick positions on course time", valid)
	var physical := ghost.find_children("*", "CollisionObject3D", true, false)
	check("ghost has no physical or progress trigger body", physical.is_empty(), physical)
	var before := bool(game.call("ghost_shown"))
	await _tap(KEY_G)
	await _frames(3)
	check("G toggles ghost drawing through actual input", bool(game.call("ghost_shown")) != before and ghost.visible != before)
	await _tap(KEY_G)
	await _frames(3)
	check("G restores the ghost", bool(game.call("ghost_shown")) == before and ghost.visible == before)
	# a separate, never-attached service tests refusals without changing the active ghost.
	var challenger: Node3D = load("res://scripts/r16_ghost.gd").new()
	var identity: Dictionary = game.call("motion_identity")
	var wrong := identity.duplicate(true)
	wrong["preset"] = "wrong-preset"
	check("ghost refuses wrong motion identity", not bool((challenger.call("load_run", path, wrong) as Dictionary).ok))
	check("ghost refuses incomplete filename", not bool((challenger.call("load_run", path + ".part", identity) as Dictionary).ok))
	var bytes := FileAccess.get_file_as_bytes(path)
	bytes[bytes.size() / 2] ^= 1
	var corrupt := out_dir.path_join("corrupt-ghost.r16run")
	var file := FileAccess.open(corrupt, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	check("ghost refuses corrupted complete file", not bool((challenger.call("load_run", corrupt, identity) as Dictionary).ok))
	DirAccess.remove_absolute(corrupt)
	challenger.free()

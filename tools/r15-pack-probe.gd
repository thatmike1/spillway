extends Node
## p / packed r15 probe: a harness autoload for the exact shipped release runtime and pack, and
## (identity mode only) for the frozen source copy under the pinned editor.
## official release templates ignore --script and refuse --main-pack, but read an override.cfg
## beside the executable. tools/package-r15.py writes one into a harness copy of the extracted
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
## spec: -- --pack-probe=/abs/spec.json, written by package-r15.py.

const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL}
const ACTIONS := {"w": "move_forward", "a": "move_left", "s": "move_back", "d": "move_right", "space": "jump", "ctrl": "crouch"}
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
var trace: Array = []
var checkpoint_sequence: Array = []
var capture_ticks: Dictionary = {}
var _row: Dictionary = {}
var _mismatch_at_arm := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wall_start = Time.get_ticks_msec()
	var path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pack-probe="):
			path = arg.trim_prefix("--pack-probe=")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if path != "" else null
	if not parsed is Dictionary:
		printerr("r15 pack probe: no spec at ", path)
		get_tree().quit(2)
		return
	spec = parsed
	expect = spec.get("expect", {})
	out_dir = str(spec.get("out", ""))
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("frames"))
	RenderingServer.frame_post_draw.connect(_on_draw)
	# the main scene enters the tree after the autoloads; start once it is ready.
	await get_tree().process_frame
	_start()

func check(name: String, ok: bool, detail: Variant = "") -> bool:
	# details are frozen as text at assertion time, so later mutation cannot rewrite them.
	checks.append({"name": name, "ok": ok, "detail": JSON.parse_string(JSON.stringify(detail, "", false, true)) if detail is Dictionary or detail is Array else detail})
	print("%s r15 pack probe: %s %s" % ["PASS" if ok else "FAIL", name, "" if str(detail) == "" else "(" + str(detail).left(400) + ")"])
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
	if report.mode == "identity":
		if game == null or not ("player" in game):
			_end("no r15 main")
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
		_end("no r15 main")
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
	return {"process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames(),
		"map": str(game.get("map_id")), "preset": str(game.get("preset_id")), "physics_hz": int(game.get("physics_hz")),
		"engine_hz": Engine.physics_ticks_per_second, "rate_ok": bool(game.get("rate_ok")), "last_delta": float(game.get("last_delta")),
		"paused": bool(game.get("paused")), "clean": bool(game.get("clean_eligible")), "practice_reason": str(game.get("practice_reason")),
		"started": bool(game.get("_started")), "finished": bool(game.get("finished")), "attempts": int(game.get("attempts")),
		"checkpoint": int(game.get("checkpoint_index")), "practice_stage": int(game.get("practice_stage")),
		"course_key": str(game.get("course_key")), "runner": _script_path(player), "feet": _v3(player.global_position),
		"identity_text": _hud_text("identity"),
		"practice_tag": str((tag as Label).text) if tag is Label and (tag as Label).visible else "",
		"message": str((message as Label).text) if message is Label and (message as Label).modulate.a > 0.05 else "",
		"pause_visible": pause is Control and (pause as Control).visible, "title": get_window().title}

func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

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
		"save_path": str(game.get("SAVE_PATH")), "hud_keys_line": str(_hud().get("KEYS_LINE")) if _hud() != null else ""}

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
			if not bool(registry.presets[id].available):
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
	var label: Variant = _hud().get(field)
	if not label is Label or not label.is_visible_in_tree() or str(label.text).strip_edges().is_empty() or label.visible_characters == 0:
		return false
	var rect: Rect2 = label.get_global_rect()
	var alpha := 1.0
	var node: Node = label
	while node != null:
		if node is CanvasItem:
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
	var out := {"nodes": {}, "shaders": {}, "textures": {}, "in_view": {}}
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
			for i: int in mesh.get_surface_count():
				var material := (node as MeshInstance3D).get_active_material(i) if node is MeshInstance3D else geometry.material_override
				if material == null:
					material = mesh.surface_get_material(i)
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
			if not vertices or count >= 3:
				out.nodes[str(node.name)] = count
			if in_view > 0:
				out.in_view[str(node.name)] = in_view
	for child: Node in node.get_children():
		_scan(child, out, vertices)

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
		hits.append({"screen": [at.x, at.y], "hit": true, "point": _v3(point), "normal": _v3(normal), "collider": str(body.name) if body != null else "",
			"role": str(body.get_meta("surface", "")) if body != null else "", "walkable": normal.y > 0.7,
			"drawn_by": _triangle_at(game.get("level"), point, drawn)})
	return hits

## the name of a drawn mesh with a triangle through this point (within 3 cm), or "".
func _triangle_at(root: Node, point: Vector3, drawn: Dictionary) -> String:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if not drawn.nodes.has(str(instance.name)) or instance.mesh == null:
			continue
		var box := instance.global_transform * instance.mesh.get_aabb()
		if not box.grow(0.05).has_point(point):
			continue
		var local := instance.global_transform.affine_inverse() * point
		for i: int in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(i)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := index.size() if not index.is_empty() else points.size()
			for t: int in range(0, count - 2, 3):
				var a := points[index[t] if not index.is_empty() else t]
				var b := points[index[t + 1] if not index.is_empty() else t + 1]
				var c := points[index[t + 2] if not index.is_empty() else t + 2]
				if _on_triangle(local, a, b, c, 0.03):
					return str(instance.name)
	return ""

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
	return (registry.order as Array).filter(func(id: String) -> bool: return bool(registry.presets[id].available))

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

func _stage_picker_controls(map: String) -> void:
	await _tap(KEY_ESCAPE)
	var picker := _hud().get("stage_picker") as OptionButton
	var button := _hud().get("stage_practice_button") as Button
	check(map + ": stage picker exists", picker != null and button != null)
	if picker == null or button == null:
		return
	var points: Array = expect.identity.maps[map].practice_points
	var stage := mini(3, points.size() - 1)
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
	var state := await captured(map + "-stage-practice", {"paused": false, "clean": false, "practice_reason": "practice", "practice_stage": stage, "checkpoint": stage, "practice_tag": "~stage practice"})
	var feet: Array = points[stage].feet
	var target := Vector3(float(feet[0]), float(feet[1]), float(feet[2]))
	check(map + ": practice reached the frozen stage pose", (game.get("player") as Node3D).global_position.distance_to(target) < 0.15, [state.feet, feet])
	await _tap(KEY_R)
	await _physics(4)
	await captured(map + "-stage-practice-restart", {"paused": false, "clean": true, "practice_stage": -1, "checkpoint": 0, "started": false})

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
	if mouse_at.has(next_tick):
		var event := InputEventMouseMotion.new()
		event.relative = mouse_at[next_tick]
		event.screen_relative = mouse_at[next_tick]
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func late_step(delta: float) -> void:
	if _row.is_empty():
		return
	var tick := int(_row.tick)
	var player: Node3D = game.get("player")
	next_tick = tick + 1
	var index := int(game.get("checkpoint_index"))
	if checkpoint_sequence.is_empty() or checkpoint_sequence[-1] != index:
		checkpoint_sequence.append(index)
	_row.merge({"dt_late": delta, "engine_hz": Engine.physics_ticks_per_second, "rate_ok": game.get("rate_ok"),
		"physics_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(), "motor_steps": player.get("tape_step_count"),
		"p": _v3(player.global_position), "v": _v3((player as CharacterBody3D).velocity), "yaw": player.get("yaw"), "pitch": player.get("pitch"), "checkpoint": index,
		"elapsed": game.get("elapsed"), "finished": game.get("finished"), "finish_kind": game.get("finish_kind"),
		"respawns": game.get("respawn_count"), "clean": game.get("clean_eligible")})
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
		if pressed:
			held[edge.key] = true
		else:
			held.erase(edge.key)

func _end_tape() -> void:
	tape_done = true
	for key: String in held.keys():
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
		"course_key": game.get("course_key"), "map": game.get("map_id"), "preset": game.get("preset_id"), "physics_hz": game.get("physics_hz")}
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
	# package-r15.py compares the written trace again with python's exact reader.
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
		if not motion is Dictionary or not _valid_vector(motion.get("p")) or not _valid_vector(motion.get("v")) or not _finite_number(motion.get("yaw")) or not state is Dictionary:
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
		var g: Dictionary = other.get("game", {})
		if game_diff.size() < 5 and (int(g.get("checkpoint", -1)) != int(row.checkpoint) or float(g.get("elapsed", -1.0)) != _as_read(row.elapsed) or bool(g.get("finished", false)) != bool(row.finished) or str(g.get("finish_kind", "")) != str(row.finish_kind) or int(g.get("respawns", -1)) != int(row.respawns)):
			game_diff.append({"tick": row.tick, "pack": [row.checkpoint, row.elapsed, row.finished], "source": [g.get("checkpoint"), g.get("elapsed"), g.get("finished")]})
	var start: Variant = reference.get(0)
	var pre_gap := -1.0
	if start != null and not trace.is_empty():
		pre_gap = Vector3(trace[0].pre_p[0], trace[0].pre_p[1], trace[0].pre_p[2]).distance_to(Vector3(start.pre.p[0], start.pre.p[1], start.pre.p[2]))
	report["reference"] = {"path": path, "ticks_compared": compared, "reference_ticks": reference.size(), "max_position_m": worst, "max_velocity_m_s": worst_velocity, "max_yaw_rad": worst_yaw,
		"first_position_difference_tick": first_diff, "tick0_pre_position_gap_m": pre_gap, "game_state_differences": game_diff, "tolerance_m": 0.0}
	check("packed run matches the source executor tick for tick", compared == trace.size() and compared == reference.size() and worst == 0.0 and worst_velocity == 0.0 and worst_yaw <= 1e-12 and pre_gap == 0.0, report.reference)
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
		for key: String in wanted:
			check("reload restores exact-tick " + key, not ticks.is_empty() and game.get(key) == wanted[key], game.get(key))
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
		check("pause shows the actual best values", records == wanted, [records, wanted])
	await captured("pause", {"paused": true, "pause_visible": true})
	_end("")

func _end(reason: String) -> void:
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
	print("r15 pack probe: %s, %d failures" % [report.mode, report.failures])
	var hud: Node = game.get("hud") if game != null else null
	var quit_button: Variant = hud.get("quit_button") if hud != null else null
	if reason == "" and quit_button is Button and (quit_button as Button).is_visible_in_tree():
		# the player's way out: a left click on Quit, through the viewport's gui picking.
		await _reveal(quit_button)
		await _click(quit_button)
		# the Quit button ends the process; still running means it did not.
		await _frames(240)
		print("FAIL r15 pack probe: Quit did not end the process")
	get_tree().quit(3 if report.mode != "identity" or reason != "" else 0)

extends Node
## p / packed r13 probe: a harness autoload for the exact shipped release runtime and pack.
## official release templates ignore --script and refuse --main-pack, but read an override.cfg
## beside the executable. tools/package-overflow.py writes one into a harness copy of the
## extracted package, pointing here; the shipped folder itself never carries it. the engine
## then loads the pack's own run/main_scene as a player's launch does.
##
## it observes and judges: identity, pack contents, resources the running game loaded, labels
## and, with a tape, a real key and relative-mouse run through Input. tape delivery follows
## tools/momentum-tape.gd: key edges for tick N at the end of step N-1, mouse motion early in
## step N. like the executor, tick 0 is the first physics step after a render frame, once the
## motor has run at least the executor's warmup (read from its trace). the frame phase matters:
## measured on the overflow course, tick 0 one step off a frame boundary drifts up to 17 mm from
## the same tape. it never writes pose, velocity, progress or records, never calls the finish,
## and leaves through Esc and a click on the pause panel's Quit.
## spec: -- --pack-probe=/abs/spec.json, written by package-overflow.py.

const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL}
const ACTIONS := {"w": "move_forward", "a": "move_left", "s": "move_back", "d": "move_right", "space": "jump", "ctrl": "crouch"}

class Early:
	extends Node
	var run: Variant
	func _physics_process(_delta: float) -> void:
		run.early_step()

class Late:
	extends Node
	var run: Variant
	func _physics_process(_delta: float) -> void:
		run.late_step()

var spec: Dictionary = {}
var expect: Dictionary = {}
var out_dir := ""
var checks: Array = []
var report: Dictionary = {}
var game: Node
var player: CharacterBody3D

# tape state, as in the executor
var keys_at: Dictionary = {}
var mouse_at: Dictionary = {}
var duration := 0
var arm_steps := 10
var next_tick := 0
var armed := false
var tape_done := false
var held: Dictionary = {}
var pending_mouse: Dictionary = {}
var trace: Array = []
var checkpoint_sequence: Array = []
var capture_ticks: Dictionary = {}
var capture_next := ""
var frames: Array = []
var _row_armed := false
var _row_tick := -1
var _wall_start := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wall_start = Time.get_ticks_msec()
	var path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pack-probe="):
			path = arg.trim_prefix("--pack-probe=")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if path != "" else null
	if not parsed is Dictionary:
		printerr("pack probe: no spec at ", path)
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

func check(name: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print("%s pack probe: %s %s" % ["PASS" if ok else "FAIL", name, "" if str(detail) == "" else "(" + str(detail) + ")"])

func _start() -> void:
	game = get_tree().current_scene
	report["mode"] = spec.get("mode", "startup")
	report["runtime"] = {"executable": OS.get_executable_path(), "template": OS.has_feature("template"),
		"template_release": OS.has_feature("template_release"), "debug_build": OS.is_debug_build(),
		"editor": OS.has_feature("editor"), "version": Engine.get_version_info(), "display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
		"res_root": ProjectSettings.globalize_path("res://"), "user_dir": OS.get_user_data_dir(),
		"cmdline": OS.get_cmdline_args(), "user_args": OS.get_cmdline_user_args(),
		"pack_sha256": FileAccess.get_sha256(str(spec.get("pack", ""))), "probe": (get_script() as Script).resource_path}
	check("release runtime, not the editor", OS.has_feature("template_release") and not OS.is_debug_build() and not OS.has_feature("editor"), report.runtime.executable)
	check("pack is the expected file", report.runtime.pack_sha256 == str(expect.get("pack_sha256", "")), report.runtime.pack_sha256)
	check("res:// has no loose root", report.runtime.res_root == "", report.runtime.res_root)
	check("pack main scene", str(ProjectSettings.get_setting("application/run/main_scene")) == str(expect.main_scene), ProjectSettings.get_setting("application/run/main_scene"))
	check("engine runs that scene", game != null and game.scene_file_path == str(expect.main_scene), game.scene_file_path if game != null else "none")
	if game == null or not ("player" in game) or game.get("player") == null:
		_end("no r13 main")
		return
	player = game.get("player")
	_check_identity()
	_check_pack()
	_check_world()
	match str(report.mode):
		"play":
			_arm_tape()
		_:
			_wrap_up.call_deferred()

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

func _check_identity() -> void:
	var main_script := game.get_script() as Script
	report["identity"] = {"main_script": _script_path(game), "build": game.get("BUILD_ID"), "save_path": game.get("SAVE_PATH"),
		"profile_path": game.get("profile_path"), "persist": game.get("persist"), "profile_state": game.get("profile_state"),
		"course_key": game.get("course_key"), "stages": game.call("stage_count"), "runner_policy": player.get("air_policy"),
		"level_script": _script_path(game.get("level")), "runner_chain": _script_chain(player),
		"hud_script": _script_path(game.get("hud")), "audio_script": _script_path(game.get("audio"))}
	var id: Dictionary = report.identity
	check("main script", id.main_script == str(expect.main_script), id.main_script)
	check("build id", str(id.build) == str(expect.build), id.build)
	check("records namespace", str(id.save_path) == str(expect.save_path) and str(id.profile_path) == str(expect.save_path), [id.save_path, id.profile_path])
	check("launch scene asks for records", bool(id.persist) == bool(expect.get("persist", true)), id.persist)
	check("level script", id.level_script == str(expect.level_script), id.level_script)
	check("runner script and base", id.runner_chain.size() >= 2 and id.runner_chain[0] == str(expect.runner_script) and id.runner_chain.has(str(expect.runner_base)), id.runner_chain)
	check("runner policy", str(id.runner_policy) == str(expect.runner_policy), id.runner_policy)
	check("hud and audio scripts", id.hud_script == str(expect.hud_script) and id.audio_script == str(expect.audio_script), [id.hud_script, id.audio_script])
	var titles: Array = []
	for i: int in int(id.stages):
		titles.append(game.call("segment_title", i))
	id["stage_titles"] = titles
	check("stage labels", titles == expect.stages, titles)
	if expect.has("course_key"):
		check("course key matches source startup", str(id.course_key) == str(expect.course_key), id.course_key)
	if expect.has("profile_state"):
		check("profile state at launch", str(id.profile_state) == str(expect.profile_state), id.profile_state)
	var texts: Array = []
	_collect_text(game.get("hud"), texts)
	var joined := "\n".join(texts)
	report["hud_text"] = texts
	for needle: String in expect.get("hud_required", []):
		check("hud shows " + needle, joined.contains(needle), "")
	for word: String in expect.get("hud_forbidden", []):
		check("hud never says " + word, not joined.to_lower().contains(word.to_lower()), "")

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
		if path.ends_with(".gd"):
			stray.append(path)
	check("no tests, tools, docs or plain scripts in the pack", stray.is_empty(), stray)
	var unloaded: Array = []
	for path: String in expect.get("loaded_required", []):
		if not ResourceLoader.has_cached(path):
			unloaded.append(path)
	check("the running game loaded its r13 modules and assets", unloaded.is_empty(), unloaded)

func _check_world() -> void:
	# which licensed kit shader, textures and props the built course is actually drawn with.
	var shaders: Dictionary = {}
	var textures: Dictionary = {}
	var props: Dictionary = {}
	_scan(game.get("level"), shaders, textures, props)
	report["world"] = {"shaders": shaders.keys(), "textures": textures.keys(), "props": props.keys()}
	var kit := str(expect.get("material_shader", ""))
	check("course uses the kit surface shader", shaders.has(kit), shaders.keys())
	var prefix := str(expect.get("asset_prefix", ""))
	var kit_textures := textures.keys().filter(func(p: String) -> bool: return p.begins_with(prefix))
	check("course textures come from the licensed kit", not kit_textures.is_empty(), kit_textures.size())
	var kit_props := props.keys().filter(func(p: String) -> bool: return p.begins_with(prefix))
	check("course places kit props", not kit_props.is_empty() or not bool(expect.get("props_required", true)), kit_props)

func _scan(node: Node, shaders: Dictionary, textures: Dictionary, props: Dictionary) -> void:
	if node == null:
		return
	if node.scene_file_path != "":
		props[node.scene_file_path] = true
	if node is GeometryInstance3D:
		var materials: Array = [(node as GeometryInstance3D).material_override]
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh := (node as MeshInstance3D).mesh
			for i: int in mesh.get_surface_count():
				materials.append((node as MeshInstance3D).get_active_material(i))
		for material: Variant in materials:
			if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
				var shader := (material as ShaderMaterial).shader
				shaders[shader.resource_path if shader.resource_path != "" else "<built-in>"] = true
				for uniform: Dictionary in shader.get_shader_uniform_list():
					var value: Variant = (material as ShaderMaterial).get_shader_parameter(uniform.name)
					if value is Texture2D and (value as Texture2D).resource_path != "":
						textures[(value as Texture2D).resource_path] = true
	for child: Node in node.get_children():
		_scan(child, shaders, textures, props)

# --- tape ----------------------------------------------------------------------------------

func _arm_tape() -> void:
	var tape: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(spec.get("tape", ""))))
	if not tape is Dictionary or not tape.get("expanded", false) or tape.has("curves") or int(tape.get("physics_hz", 0)) != Engine.physics_ticks_per_second:
		check("tape is an expanded 120 Hz tape", false, spec.get("tape"))
		_end("bad tape")
		return
	duration = int(tape.duration_ticks)
	arm_steps = int(spec.get("arm_motor_steps", 10))
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
	report["tape"] = {"path": spec.tape, "sha256": FileAccess.get_sha256(str(spec.tape)), "ticks": duration, "arm_motor_steps": arm_steps}
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

func early_step() -> void:
	_row_armed = armed and not tape_done
	if not _row_armed:
		return
	_row_tick = next_tick
	if mouse_at.has(_row_tick):
		var event := InputEventMouseMotion.new()
		event.relative = mouse_at[_row_tick]
		event.screen_relative = mouse_at[_row_tick]
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _process(_delta: float) -> void:
	if armed or tape_done or duration == 0 or player == null:
		return
	var motor_steps := int(player.get("tape_step_count"))
	if motor_steps >= arm_steps:
		# between physics steps, as the executor arms: tick 0 opens the next render frame.
		armed = true
		report.tape["armed_after_motor_steps"] = motor_steps
		check("tape armed on a frame boundary after the reference warmup", true, motor_steps)
		_deliver_keys(0)

func late_step() -> void:
	if not _row_armed:
		return
	_row_armed = false
	var tick := _row_tick
	next_tick = tick + 1
	var p := player.global_position
	var index := int(game.get("checkpoint_index"))
	if checkpoint_sequence.is_empty() or checkpoint_sequence[-1] != index:
		checkpoint_sequence.append(index)
	trace.append({"tick": tick, "physics_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(),
		"motor_steps": player.get("tape_step_count"), "p": [p.x, p.y, p.z], "yaw": player.get("yaw"), "checkpoint": index,
		"elapsed": game.get("elapsed"), "finished": game.get("finished"), "finish_kind": game.get("finish_kind"),
		"respawns": game.get("respawn_count")})
	if capture_ticks.has(tick):
		capture_next = "tick_%05d" % tick
	if tick + 1 >= duration:
		_end_tape()
		return
	_deliver_keys(tick + 1)

func _deliver_keys(tick: int) -> void:
	for edge: Dictionary in keys_at.get(tick, []):
		var pressed: bool = edge.edge == "press"
		_send_key(KEYS[edge.key], pressed)
		if pressed:
			held[edge.key] = true
		else:
			held.erase(edge.key)

func _send_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _end_tape() -> void:
	tape_done = true
	for key: String in held.keys():
		_send_key(KEYS[key], false)
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
	report["run"] = {"finished": game.get("finished"), "finish_kind": game.get("finish_kind"), "elapsed": elapsed,
		"respawns": game.get("respawn_count"), "checkpoint_sequence": checkpoint_sequence, "stage_times": times,
		"best_time": game.get("best_time"), "open_best_time": game.get("open_best_time"), "best_splits": game.get("best_splits"),
		"previous_best": game.get("previous_best"), "last_save_ok": game.get("last_save_ok"), "profile_state": game.get("profile_state")}
	var run: Dictionary = report.run
	check("the run finished clean", bool(run.finished) and str(run.finish_kind) == "clean", [run.finished, run.finish_kind])
	check("zero respawns", int(run.respawns) == 0, run.respawns)
	var ordered := range(stages)
	check("stages reached in order", checkpoint_sequence == ordered, checkpoint_sequence)
	var increasing := times.size() == stages
	for i: int in times.size():
		increasing = increasing and float(times[i]) > (float(times[i - 1]) if i > 0 else 0.0)
	check("every stage measured, increasing", increasing, times)
	check("finish time is the last split", times.size() == stages and is_equal_approx(float(times[-1]), elapsed), elapsed)
	if expect.has("fresh_profile") and bool(expect.fresh_profile):
		check("first clean run becomes the best", float(run.previous_best) < 0.0 and float(run.best_time) == elapsed and float(run.open_best_time) == elapsed and run.best_splits == times, [run.previous_best, run.best_time, run.open_best_time])
	check("records saved to the profile", bool(run.last_save_ok) and str(run.profile_state) == "saved", run.profile_state)
	var file := ProjectSettings.globalize_path(str(expect.save_path))
	var config := ConfigFile.new()
	var section := "course_" + str(game.get("course_key"))
	var loaded := config.load(file) == OK
	report["profile"] = {"file": file, "sha256": FileAccess.get_sha256(file), "sections": config.get_sections() if loaded else []}
	check("profile file holds this course's clean best", loaded and config.has_section(section) and float(config.get_value(section, "clean_best", -1.0)) == elapsed and str(config.get_value("profile", "build", "")) == str(expect.build), report.profile)
	if spec.has("reference_trace") and str(spec.reference_trace) != "":
		_compare_reference(str(spec.reference_trace))

func _compare_reference(path: String) -> void:
	# the source-mode tape executor's run of the same tape on the same commit. yaw allows 1e-12
	# rad for its trip through json text; positions must match exactly.
	var reference: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	while file != null and not file.eof_reached():
		var line := file.get_line()
		if line == "":
			continue
		var row: Variant = JSON.parse_string(line)
		if row is Dictionary and row.get("phase") == "tape":
			reference[int(row.tick)] = row
	var worst := 0.0
	var worst_yaw := 0.0
	var compared := 0
	for row: Dictionary in trace:
		var other: Variant = reference.get(int(row.tick))
		if other == null:
			continue
		compared += 1
		var a := Vector3(row.p[0], row.p[1], row.p[2])
		var b := Vector3(other.post.p[0], other.post.p[1], other.post.p[2])
		worst = maxf(worst, a.distance_to(b))
		worst_yaw = maxf(worst_yaw, absf(float(row.yaw) - float(other.post.yaw)))
	report["reference"] = {"path": path, "ticks_compared": compared, "max_position_m": worst, "max_yaw_rad": worst_yaw}
	check("packed run matches the source executor tick for tick", compared == trace.size() and compared == reference.size() and worst <= float(spec.get("reference_tolerance_m", 0.0)) and worst_yaw <= 1e-12, report.reference)

# --- end: records shown, pause, quit through the panel --------------------------------------

func _wrap_up() -> void:
	await _frames(int(spec.get("settle_frames", 45)))
	capture_next = "settled"
	await _frames(3)
	if str(report.mode) == "reload":
		var best := float(game.get("best_time"))
		check("reload restores the clean best", str(game.get("profile_state")) == "loaded" and absf(best - float(expect.get("best_time", -2.0))) < 1e-9, [game.get("profile_state"), best])
		check("reload restores every split", (game.get("best_splits") as Array).size() == int(game.call("stage_count")), game.get("best_splits"))
	_send_key(KEY_ESCAPE, true)
	await _frames(2)
	_send_key(KEY_ESCAPE, false)
	await _frames(4)
	var hud: Node = game.get("hud")
	var identity := str(hud.get("pause_identity").text) if hud != null and hud.get("pause_identity") != null else ""
	var records := str(hud.get("pause_records").text) if hud != null and hud.get("pause_records") != null else ""
	report["pause"] = {"paused": game.get("paused"), "identity": identity, "records": records}
	check("Esc pauses", bool(game.get("paused")), "")
	check("pause names this build and course", identity.contains(str(expect.build)) and identity.contains(str(game.get("course_key")).left(8)), identity)
	if str(report.mode) != "startup":
		check("pause shows the best", records.begins_with("Best "), records)
	capture_next = "pause"
	await _frames(3)
	_end("")

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _on_draw() -> void:
	if capture_next == "" or out_dir == "" or DisplayServer.get_name() == "headless":
		return
	var name := capture_next
	capture_next = ""
	var file := out_dir.path_join("frames/%s.png" % name)
	get_viewport().get_texture().get_image().save_png(file)
	frames.append(file)

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
	print("pack probe: %s, %d failures" % [report.mode, report.failures])
	var hud: Node = game.get("hud") if game != null else null
	var quit_button: Variant = hud.get("quit_button") if hud != null else null
	if reason == "" and quit_button is Button and (quit_button as Button).is_visible_in_tree():
		# the player's way out: a left click on Quit, through the viewport's gui picking.
		var at := (quit_button as Button).get_global_rect().get_center()
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = at
			event.global_position = at
			get_viewport().push_input(event, true)
			await get_tree().process_frame
		# the Quit button ends the process; still running means it did not.
		await _frames(240)
		print("FAIL pack probe: Quit did not end the process")
	get_tree().quit(3)

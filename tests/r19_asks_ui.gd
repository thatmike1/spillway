extends SceneTree
## the actual r18 host and controls, with isolated persistence and no fabricated label objects.
const MAIN := preload("res://scripts/r17_main.gd")
const BASE := preload("res://scripts/r16_main.gd")
var game: Node
var checks: Array = []
var output := ""
var asks := "maps,advanced,look"

class LeakProbe:
	extends Node
	var leaked: Array = []
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.physical_keycode in [KEY_L, KEY_F9]:
			leaked.append([event.physical_keycode, event.pressed, event.echo])

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg.begins_with("--asks="):
			asks = arg.trim_prefix("--asks=")
	run.call_deferred()

func check(ok: bool, name: String, detail: Variant = "") -> void:
	checks.append({"pass": ok, "name": name, "detail": str(detail)})
	print("%s %s %s" % ["ok" if ok else "FAIL", name, str(detail)])

func frames(count := 3) -> void:
	for i: int in count:
		await process_frame

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	game = MAIN.new()
	game.persist = false
	game.seed_from_r15 = false
	game.record_runs = false
	root.add_child(game)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await frames()
	if asks.contains("maps"):
		await maps_check()
	if asks.contains("advanced"):
		await advanced_check()
	if asks.contains("look"):
		await look_check()
	await finish()

func maps_check() -> void:
	game.set_paused(true)
	for id: String in ["practice", "overflow"]:
		var card: Button = game.hud.map_buttons[id]
		check(not card.text.contains("R14") and not card.text.contains("R13"), id + " card has player-facing description", card.text)
		check(card.tooltip_text == game.map_entry(id).theme, id + " tooltip uses same description")
		var frozen: Dictionary = game.MAPS.entry(game.maps, id)
		var shown: Dictionary = game.map_entry(id)
		shown.theme = frozen.theme
		check(shown == frozen, id + " presentation metadata changes only theme")
		game.select_map(id)
		game.set_paused(true)
		await frames()
		var reference := BASE.new()
		reference.map_id = id
		reference.persist = false
		reference.seed_from_r15 = false
		reference.record_runs = false
		root.add_child(reference)
		reference.set_paused(true)
		check(game.course_geometry == reference.course_geometry and game.course_key == reference.course_key and game.motion_identity() == reference.motion_identity(), id + " physical map hashes and time identity match frozen host")
		check(game.map_kind() == "legacy" and game.map_id == id, id + " physical map id and kind preserved")
		reference.set_paused(false)
		reference.request_quit(0)
		root.remove_child(reference)
		reference.free()
		game.set_paused(true)

func tap(code: Key) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.keycode = code
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()
	await frames()

func advanced_check() -> void:
	game.set_paused(true)
	await frames()
	var hud: Node = game.hud
	var legacy_sens := hud.pause_panel.find_child("Setting_r13_sensitivity", true, false) as HSlider
	var legacy_fov := hud.pause_panel.find_child("Setting_r13_fov", true, false) as HSlider
	var source_sens := hud.pause_panel.find_child("Setting_source_sensitivity", true, false) as HSlider
	var source_fov := hud.pause_panel.find_child("Setting_source_fov", true, false) as HSlider
	check(legacy_sens != null and legacy_fov != null and source_sens != null and source_fov != null, "actual setting sliders exist")
	check(not legacy_sens.is_visible_in_tree() and not legacy_fov.is_visible_in_tree(), "R13 sliders hidden in collapsed Advanced")
	check(source_sens.is_visible_in_tree() and source_fov.is_visible_in_tree(), "main sensitivity and FOV remain visible")
	await save_ui("advanced-collapsed", source_fov)
	check(hud.advanced_box.is_ancestor_of(legacy_sens) and hud.advanced_box.is_ancestor_of(legacy_fov) and hud.advanced_box.is_ancestor_of(hud.preset_buttons.r13_original120), "legacy sliders and preset share Advanced")
	hud.advanced_toggle.grab_focus()
	await tap(KEY_SPACE)
	check(hud.advanced_toggle.button_pressed and legacy_sens.is_visible_in_tree() and legacy_fov.is_visible_in_tree(), "actual keyboard dispatch opens Advanced")
	await save_ui("advanced-expanded", legacy_fov)
	game.profile_path = output.path_join("settings.cfg")
	game.persist = true
	var before_sens: float = game.settings.r13_sensitivity
	var before_fov: float = game.settings.r13_fov
	legacy_sens.grab_focus()
	await tap(KEY_RIGHT)
	legacy_fov.grab_focus()
	await tap(KEY_RIGHT)
	check(is_equal_approx(float(game.settings.r13_sensitivity), before_sens + legacy_sens.step) and is_equal_approx(legacy_sens.value, float(game.settings.r13_sensitivity)), "R13 sensitivity actual slider dispatch stays bound")
	check(is_equal_approx(float(game.settings.r13_fov), before_fov + legacy_fov.step) and is_equal_approx(legacy_fov.value, float(game.settings.r13_fov)), "R13 FOV actual slider dispatch stays bound")
	var config := ConfigFile.new()
	check(config.load(game.profile_path) == OK and is_equal_approx(float(config.get_value("settings", "r13_sensitivity", -1)), legacy_sens.value) and is_equal_approx(float(config.get_value("settings", "r13_fov", -1)), legacy_fov.value), "same legacy setting keys persist values")
	var reloaded := MAIN.new()
	reloaded.persist = true
	reloaded.profile_path = game.profile_path
	reloaded.seed_from_r15 = false
	reloaded.record_runs = false
	root.add_child(reloaded)
	reloaded.set_paused(true)
	check(is_equal_approx(float(reloaded.settings.r13_sensitivity), legacy_sens.value) and is_equal_approx(float(reloaded.settings.r13_fov), legacy_fov.value), "fresh host reloads same persisted R13 values")
	reloaded.set_paused(false)
	reloaded.request_quit(0)
	root.remove_child(reloaded)
	reloaded.free()
	game.set_paused(true)
	hud.advanced_toggle.grab_focus()
	await tap(KEY_SPACE)
	check(not legacy_sens.is_visible_in_tree() and not legacy_fov.is_visible_in_tree() and source_sens.is_visible_in_tree() and source_fov.is_visible_in_tree(), "closing Advanced hides only legacy sliders")
	game.persist = false

func edge(code: Key, pressed: bool, echo := false) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.keycode = code
	key.pressed = pressed
	key.echo = echo
	Input.parse_input_event(key)
	Input.flush_buffered_events()

func live_state() -> String:
	return var_to_str([game.player.global_transform, game.player.velocity, game.player.yaw, game.player.pitch,
		game.elapsed, game.attempts, game.checkpoint_index, game.session.pending, game.session.style.snapshot(), game.motion_identity()])

func look_check() -> void:
	game.set_paused(false)
	root.remove_child(game)
	game.free()
	game = MAIN.new()
	game.persist = false
	game.seed_from_r15 = false
	game.record_runs = false
	root.add_child(game)
	await frames()
	var leak := LeakProbe.new()
	leak.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(leak)
	check(not game.hud.telemetry and not game.look_label.is_visible_in_tree(), "look label hidden by default and on title")
	check(game.hud.title_card.is_visible_in_tree(), "actual title still visible before telemetry")
	var state := live_state()
	edge(KEY_L, true)
	check(not game.look_enabled and game.look_label.text.contains("original R16") and not game.look_label.is_visible_in_tree(), "L changes look while label remains hidden")
	check(state == live_state(), "L press does not write game state or recording inputs")
	edge(KEY_L, true, true)
	check(not game.look_enabled, "held L echo does not toggle again")
	edge(KEY_L, false)
	edge(KEY_F9, true)
	check(game.hud.telemetry and game.look_label.is_visible_in_tree(), "F9 reveals actual hidden label immediately")
	check(not game.hud.title_card.is_visible_in_tree(), "telemetry dismisses title")
	edge(KEY_F9, true, true)
	check(game.hud.telemetry, "held F9 echo does not toggle again")
	edge(KEY_F9, false)
	check(state == live_state(), "F9 does not write movement, style, identity or recording inputs")
	edge(KEY_L, true)
	edge(KEY_L, false)
	check(game.look_enabled and game.look_label.text.contains("Look C") and game.look_label.is_visible_in_tree(), "L restores look with telemetry visible")
	await save_ui("look-telemetry", game.look_label)
	edge(KEY_F9, true)
	edge(KEY_F9, false)
	check(not game.hud.telemetry and not game.look_label.is_visible_in_tree(), "second F9 hides label immediately")
	await frames(5)
	check(not game.look_label.is_visible_in_tree(), "frame updates keep telemetry-off label hidden")
	edge(KEY_F9, true)
	edge(KEY_F9, false)
	await frames(5)
	check(game.look_label.is_visible_in_tree(), "F9 can show label again after hidden frame updates")
	game.set_paused(true)
	await frames()
	check(not game.look_label.is_visible_in_tree(), "look label hidden while paused with telemetry on")
	state = live_state()
	edge(KEY_L, true)
	edge(KEY_L, false)
	check(not game.look_enabled and state == live_state(), "paused L changes only presentation")
	edge(KEY_F9, true)
	edge(KEY_F9, false)
	check(not game.hud.telemetry and not game.look_label.is_visible_in_tree(), "paused F9 hides telemetry without showing label")
	edge(KEY_F9, true)
	edge(KEY_F9, false)
	await frames()
	check(game.hud.telemetry and not game.look_label.is_visible_in_tree(), "paused F9 can enable telemetry while label stays hidden")
	game.set_paused(false)
	await frames()
	check(game.look_label.is_visible_in_tree(), "unpausing restores telemetry label")
	check(leak.leaked.is_empty(), "L and F9 press, echo and release never reach unhandled gameplay", leak.leaked)
	root.remove_child(leak)
	leak.free()

func save_ui(label: String, control: Control) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if bool(game.paused):
		control.grab_focus()
		await frames(3)
		game.hud._pause_scroll.ensure_control_visible(control)
	await frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))

func finish() -> void:
	var failed := checks.filter(func(row: Dictionary) -> bool: return not row.pass)
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed.size(), "asks": asks}, "\t"))
	file.close()
	game.set_paused(false)
	game.request_quit(0)
	root.remove_child(game)
	game.free()
	await frames(8)
	print("r19 asks: %d checks, %d failed" % [checks.size(), failed.size()])
	quit(0 if failed.is_empty() else 1)

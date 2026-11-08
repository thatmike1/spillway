extends SceneTree
## p / r15 product loop: runner policy, map registry and chooser, presets, hot switches, hull
## waits, checkpoint practice, the stage picker, records and quit. every run is played with
## ordinary key, wheel and relative-mouse events through Input, and menu controls are clicked or
## scrolled through the viewport; nothing calls the game's finish, select or practise methods or
## writes the runner's pose or velocity.
##
## what plays here: the production r15 runner (res://scripts/r15_source_player.gd, real duck
## hull) everywhere except the `standin` group, which checks the labelled r14 stand-in, and the
## `missing` group, which checks the refusal when a runner module is absent. lifecycle and the
## chooser run on labelled FIXTURE levels and fixture registries (tests/r15_loop_fixture_*.gd);
## the `legacy` group loads the real Penstock Yard and Overflow as smoke checks only. `crouch`
## and `offset` press the real crouch key on fixture geometry (a roof, a hovering trigger); they
## check the shell's handling of the duck hull, not the runner's own law (test_r15_crouch.gd).
## persistence and quit run in fresh child processes with isolated XDG profiles. nothing here
## says a course route is playable or how anything feels.
## godot --headless --audio-driver Dummy --fixed-fps 128 --path . \
##   --script res://tests/test_r15_loop.gd -- --out=DIR [--only=GROUPS]

const MAIN := preload("res://scripts/r15_main.gd")
const MAPS := preload("res://scripts/r15_maps.gd")
const PRESETS := preload("res://scripts/r15_presets.gd")
const HUD := preload("res://scripts/r15_hud.gd")
const SCENE := "res://scenes/r15.tscn"
const FIXTURE := preload("res://tests/r15_loop_fixture_level.gd")
const FIXTURE_MAPS := preload("res://tests/r15_loop_fixture_maps.gd")
const R15_RUNNER := "res://scripts/r15_source_player.gd"
const U := 0.0254
const GROUPS := ["default", "standin", "missing", "crouch", "registry", "chooser", "legacy", "hook", "switch", "purity", "hull", "offset", "kill", "lifecycle", "stages", "rapid", "persist", "quit"]
const SIZES := [Vector2i(1280, 720), Vector2i(800, 600), Vector2i(2560, 1080), Vector2i(3840, 1080)]

var out_dir := ""
var results: Array[Dictionary] = []
var only: Array = []
var phase := ""
var _group := ""
var game: Node
var notes: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	if out_dir.is_empty():
		printerr("usage: --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_main.call_deferred()

func _main() -> void:
	if not phase.is_empty():
		await _child_phase()
		return
	var started := Time.get_ticks_msec()
	for group: String in GROUPS:
		if only.is_empty() or group in only:
			_group = group
			print("group: ", group)
			await call("_group_" + group)
			await _drop_game()
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	var summary := {"checks": results.size(), "failed": failed.size(), "results": results, "seconds": (Time.get_ticks_msec() - started) / 1000.0,
		"engine": Engine.get_version_info(), "fixed_fps": Engine.max_fps, "notes": notes,
		"r15_runner_present": ResourceLoader.exists(PRESETS.SOURCE_PLAYER), "missing_maps": MAPS.missing(MAPS.make())}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	file.close()
	for r: Dictionary in failed:
		printerr("FAIL %s / %s: %s" % [r.group, r.name, r.detail])
	print("r15 loop: %d checks, %d failed" % [results.size(), failed.size()])
	quit(1 if failed.size() > 0 else 0)

func check(name: String, ok: bool, detail: Variant = "") -> bool:
	results.append({"group": _group, "name": name, "ok": ok, "detail": str(detail).left(900)})
	if not ok:
		printerr("  fail: %s (%s)" % [name, str(detail).left(400)])
	return ok

# --- input and stepping -----------------------------------------------------------------------

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key) -> void:
	key(code, true)
	await physics_frame
	key(code, false)
	await physics_frame

func mouse(dx: float, dy: float = 0.0) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.screen_relative = Vector2(dx, dy)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)
		await process_frame

## a key through the viewport, so an open popup that has focus receives it.
func ui_key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

## wheel the pause menu until the control is fully inside its scroll view, then click it.
func click_visible(control: Control) -> bool:
	var scroll: ScrollContainer = hud().get("_pause_scroll")
	for i: int in 80:
		var view := scroll.get_global_rect()
		var rect := control.get_global_rect()
		if view.encloses(rect):
			break
		var at := view.get_center()
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_WHEEL_DOWN if rect.position.y > view.position.y else MOUSE_BUTTON_WHEEL_UP
			event.pressed = pressed
			event.position = at
			event.global_position = at
			event.factor = 1.0
			root.push_input(event, true)
		await process_frame
	var inside := scroll.get_global_rect().encloses(control.get_global_rect())
	await click(control)
	return inside

func ticks(n: int) -> void:
	for i: int in n:
		await physics_frame

func until(cond: Callable, limit: int) -> int:
	for i: int in limit:
		if cond.call():
			return i
		await physics_frame
	return -1 if not cond.call() else limit

func release_all() -> void:
	for code: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_CTRL]:
		key(code, false)

## a game on a fixture level (or the real registry with fixture=false), the production runner
## unless `runner` names the stand-in.
func make_game(params: Dictionary = {}, alias: String = "", opts: Dictionary = {}) -> Node:
	FIXTURE.params = params
	game = (load(SCENE) as PackedScene).instantiate() if bool(opts.get("scene", false)) else MAIN.new()
	if bool(opts.get("fixture", true)) and not opts.has("registry"):
		game.set("level_script", opts.get("level", FIXTURE))
	if opts.has("registry"):
		game.set("map_registry", opts.registry)
	game.set("source_runner", opts.get("runner", ""))
	if opts.has("map"):
		game.set("map_id", opts.map)
	if not alias.is_empty():
		game.set("motor", alias)
	root.add_child(game)
	await ticks(16)
	return game

func _drop_game() -> void:
	release_all()
	if is_instance_valid(game):
		if bool(game.paused):
			game.call("set_paused", false)
		game.queue_free()
		game = null
	paused = false
	await ticks(3)

func p() -> CharacterBody3D:
	return game.player

func hud() -> Node:
	return game.hud

func grounded() -> bool:
	return bool(p().call("is_grounded"))

func hspeed_u() -> float:
	return Vector2(p().velocity.x, p().velocity.z).length() / U

func counts_for(radians: float) -> float:
	if "tape_radians_per_count" in p():
		return radians / float(p().get("tape_radians_per_count"))
	return radians / float(p().get("mouse_sensitivity"))

func hud_texts(visible_only: bool = true) -> Array[String]:
	var texts: Array[String] = []
	for node: Node in (game.hud as Node).find_children("*", "", true, false):
		if node is Label or node is Button:
			var control := node as Control
			if not visible_only or control.is_visible_in_tree():
				texts.append(str(control.get("text")))
	return texts

func pose() -> Dictionary:
	return {"feet": p().global_position, "velocity": p().velocity, "yaw": float(p().get("yaw")), "pitch": float(p().get("pitch")), "node": p().get_instance_id(), "script": (p().get_script() as Script).resource_path}

func run_up(target: float, limit: int = 400) -> void:
	key(KEY_W, true)
	await until(func() -> bool: return hspeed_u() >= target, limit)
	key(KEY_W, false)

func open_menu() -> void:
	if not bool(game.paused):
		await tap(KEY_ESCAPE)

func run_to_finish(limit: int = 3000) -> void:
	key(KEY_W, true)
	await until(func() -> bool: return bool(game.finished), limit)
	key(KEY_W, false)

func at_spawn() -> bool:
	return p().global_position.distance_to((game.level.spawn as Transform3D).origin) < 0.1

func set_window(size: Vector2i) -> void:
	root.size = size
	await process_frame
	await process_frame

# --- groups -----------------------------------------------------------------------------------

func _group_default() -> void:
	await set_window(Vector2i(1280, 720))
	await make_game({}, "", {"fixture": false})
	var breakwater := MAPS.available(MAPS.make(), "breakwater")
	notes["default_map"] = game.map_id
	if breakwater:
		check("breakwater exists, so it is the default, without the stand-in label", str(game.map_id) == "breakwater" and not bool(game.default_map_standin), game.map_id)
	else:
		check("breakwater absent: Penstock Yard is the default", str(game.map_id) == "practice" and str(game.call("map_name")) == "Penstock Yard", game.map_id)
		check("the hud labels Penstock the development stand-in", str(hud().call("identity_text")).contains("PENSTOCK YARD (development stand-in until Breakwater exists)"), hud().call("identity_text"))
	check("default preset is the bhop server at 128 Hz", str(game.preset_id) == "server128" and Engine.physics_ticks_per_second == 128 and int(game.physics_hz) == 128, [game.preset_id, Engine.physics_ticks_per_second])
	check("the runner is the r15 crouch runner, not a stand-in", (p().get_script() as Script).resource_path == R15_RUNNER and not bool(game.call("runner_is_standin")) and not str(hud().call("identity_text")).contains("STAND-IN") and not str(root.get_window().title).contains("STAND-IN"), [hud().call("identity_text"), root.get_window().title])
	var cvars: Dictionary = p().get("settings")
	check("server cvars: AA100, autohop, no stamina", float(cvars.sv_airaccelerate) == 100.0 and bool(cvars.sv_autobunnyhopping) and float(cvars.sv_staminamax) == 0.0, cvars.sv_airaccelerate)
	check("new() builds a game with records off and the r15 profile path", not bool(game.persist) and str(game.profile_state) == "off" and str(game.profile_path) == "user://spillway_r15.cfg", [game.profile_state, game.profile_path])
	var ident := str(hud().call("identity_text"))
	check("hud names F2, the preset, the rate and AA", ident.contains("F2 CS:GO bhop server") and ident.contains("128 Hz") and ident.contains("AA 100"), ident)
	var start: Vector3 = p().global_position
	var steps := int(p().get("tape_step_count"))
	key(KEY_W, true)
	await ticks(128)
	key(KEY_W, false)
	check("W moves the runner on the default map", p().global_position.distance_to(start) > 3.0, p().global_position.distance_to(start))
	check("one motor step per physics tick", int(p().get("tape_step_count")) - steps == 128, int(p().get("tape_step_count")) - steps)
	check("ground run reaches about 250 u/s and the hud shows it", absf(hspeed_u() - 250.0) < 2.0 and str(hud().speed_label.text).to_int() > 200, [hspeed_u(), hud().speed_label.text])
	await tap(KEY_F1)
	check("F1 does not start vanilla: it says vanilla is not in R15", str(game.preset_id) == "server128" and Engine.physics_ticks_per_second == 128 and str(hud().message.text).contains("not part of R15"), [game.preset_id, hud().message.text])
	await tap(KEY_F5)
	ident = str(hud().call("identity_text"))
	check("F5 runs AA 1000 and the hud names it", str(game.preset_id) == "server128_aa1000" and float((p().get("settings") as Dictionary).sv_airaccelerate) == 1000.0 and ident.contains("F5 Bhop server AA 1000") and ident.contains("AA 1000"), ident)
	check("title follows F5", str(root.get_window().title).contains("Bhop server AA 1000"), root.get_window().title)
	await tap(KEY_F2)
	check("F2 returns to the bhop server", str(game.preset_id) == "server128" and str(hud().call("identity_text")).contains("F2 CS:GO bhop server"))
	await open_menu()
	var texts := hud_texts()
	check("menu shows F2 and F5 as the main presets", "F2  CS:GO bhop server" in texts and "F5  Bhop server AA 1000" in texts, texts)
	check("advanced presets start folded away", not (hud().preset_buttons["quake3_inspired128"] as Button).is_visible_in_tree() and not (hud().preset_buttons["r13_original120"] as Button).is_visible_in_tree())
	check("no vanilla preset button anywhere", not texts.any(func(t: String) -> bool: return t.contains("CS:GO vanilla")) and not hud().preset_buttons.has("vanilla64"), hud().preset_buttons.keys())
	await click_visible(hud().advanced_toggle)
	check("the advanced toggle shows F4 and F3", (hud().preset_buttons["quake3_inspired128"] as Button).is_visible_in_tree() and (hud().preset_buttons["r13_original120"] as Button).is_visible_in_tree())
	await click_visible(hud().preset_buttons["quake3_inspired128"])
	check("clicking F4 runs the Q3-inspired projection on the same body", str(game.preset_id) == "quake3_inspired128" and float((p().get("settings") as Dictionary).sv_air_max_wishspeed) == 320.0)
	await click_visible(hud().resume_button)
	check("resume closes the menu", not bool(game.paused))

func _group_standin() -> void:
	await make_game({}, "", {"runner": MAIN.STANDIN})
	var standin_key := str(game.course_key)
	check("the r14 stand-in is said on screen, in the title and in the menu", (p().get_script() as Script).resource_path == "res://scripts/r14_source_player.gd" and str(hud().call("identity_text")).contains("STAND-IN runner (R14, no crouch hull)") and str(root.get_window().title).contains("STAND-IN"), hud().call("identity_text"))
	check("its record identity names the r14 motor, not the r15 one", str(game.call("family_version")) == "r14-source-motion-3" and str(game.call("runner_path")).ends_with("r14_source_player.gd"))
	await open_menu()
	check("the menu names the stand-in runner", str(hud().pause_identity.text).contains("STAND-IN"), hud().pause_identity.text)
	await _drop_game()
	await make_game()
	check("the stand-in and the r15 runner never share a record key", str(game.course_key) != standin_key, [game.course_key, standin_key])

func _ducked() -> bool:
	return bool(p().get("ducked"))

func _group_crouch() -> void:
	await make_game({"roof": true})
	check("starts standing in the open", not _ducked() and not (hud().crouch_tag as Label).visible)
	key(KEY_CTRL, true)
	await ticks(20)
	await process_frame
	check("Ctrl on the ground ducks and the hud says CROUCH", _ducked() and (hud().crouch_tag as Label).visible and str(hud().crouch_tag.text) == "CROUCH")
	check("a crouch on the spawn starts no timer and moves no reference", not bool(game.get("_started")) and float(game.elapsed) == 0.0 and (game.call("hull_origin_offset") as Vector3) == Vector3.ZERO)
	key(KEY_CTRL, false)
	await ticks(20)
	await tap(KEY_F5)
	check("a switch after crouching in place is still clean", bool(game.clean_eligible) and str(game.preset_id) == "server128_aa1000", [game.clean_eligible, game.practice_reason])
	await tap(KEY_F2)
	# standing, the roof stops the box at its edge.
	key(KEY_W, true)
	await ticks(200)
	key(KEY_W, false)
	check("standing, the 1.5 m roof stops the runner at its edge", p().global_position.z > 2.3 and p().global_position.z < 2.6, p().global_position)
	await tap(KEY_R)
	key(KEY_CTRL, true)
	key(KEY_W, true)
	await until(func() -> bool: return p().global_position.z < -3.0, 600)
	key(KEY_W, false)
	check("ducked, it passes under the roof", p().global_position.z < -3.0 and _ducked(), p().global_position)
	key(KEY_CTRL, false)
	await tap(KEY_R)
	check("R stands the runner at the spawn", not _ducked() and at_spawn())
	key(KEY_CTRL, true)
	key(KEY_W, true)
	await until(func() -> bool: return p().global_position.z < 0.2, 600)
	key(KEY_W, false)
	await ticks(60)
	key(KEY_CTRL, false)
	await ticks(4)
	await process_frame
	check("crouch released under the roof: the hull stays ducked and the hud says why", _ducked() and bool(p().get("stand_blocked")) and str(hud().crouch_tag.text).contains("no room to stand"), [_ducked(), hud().crouch_tag.text])
	await tap(KEY_F3)
	check("F3 waits: a standing R13 capsule does not fit under the roof", str(game.pending_preset) == "r13_original120" and str(game.preset_id) == "server128" and str(game.pending_message).contains("waits for room"), game.pending_message)
	await tap(KEY_F5)
	check("F5 on the same body applies at once and keeps the duck hull", str(game.preset_id) == "server128_aa1000" and str(game.pending_preset) == "" and _ducked() and bool(p().get("stand_blocked")))
	await tap(KEY_F3)
	key(KEY_W, true)
	var seen := {"z": 0.0, "stood_z": INF}
	await until(func() -> bool:
		if str(game.preset_id) == "r13_original120":
			seen.z = p().global_position.z
			return true
		if not _ducked() and seen.stood_z == INF:
			seen.stood_z = p().global_position.z
		return false, 800)
	key(KEY_W, false)
	# the 0.6 m capsule fits once 0.3 m past the roof edge at z = -2; the 0.81 m box needs 0.41 m.
	check("walking out with crouch up, F3 applies only where the capsule clears the roof", str(game.preset_id) == "r13_original120" and float(seen.z) < -2.3 and float(seen.z) > -2.6, seen)
	await tap(KEY_F2)
	await tap(KEY_R)
	key(KEY_CTRL, true)
	key(KEY_W, true)
	await until(func() -> bool: return p().global_position.z < 0.5, 600)
	key(KEY_W, false)
	key(KEY_CTRL, false)
	await ticks(4)
	check("ducked under the roof before F", _ducked() and bool(p().get("stand_blocked")))
	await tap(KEY_F)
	check("F from under the roof restarts standing at the checkpoint", not _ducked() and not bool(p().get("stand_blocked")) and at_spawn())

func _group_missing() -> void:
	var present := ResourceLoader.exists(PRESETS.SOURCE_PLAYER)
	notes["r15_runner_present"] = present
	FIXTURE.params = {}
	game = MAIN.new()
	game.set("level_script", FIXTURE)
	root.add_child(game)
	await ticks(4)
	if present:
		check("the r15 runner exists and the default plays it", str(game.startup_error).is_empty() and (p().get_script() as Script).resource_path == PRESETS.SOURCE_PLAYER, game.startup_error)
		check("it is not labelled a stand-in", not bool(game.call("runner_is_standin")) and not str(hud().call("identity_text")).contains("STAND-IN"))
		var hull: Dictionary = game.call("hull_identity")
		var fingerprint: Dictionary = game.call("physics_fingerprint")
		check("its record identity carries the motor version and both hulls", str(game.call("family_version")) == "r15-source-crouch-2" and float(hull.duck_height_u) == 54.0 and float(hull.height_u) == 72.0, [game.call("family_version"), hull])
		check("the six duck settings enter the physics fingerprint", ["duck_hull_height", "duck_eye_height", "duck_air_anchor", "duck_eye_time", "duck_eye_clearance", "duck_air_crop"].all(func(k: String) -> bool: return fingerprint.has(k)), fingerprint.keys())
	else:
		check("without the r15 runner the default game does not start", game.player == null and game.level == null and str(game.startup_error).contains("r15_source_player.gd"), game.startup_error)
		var label := game.find_child("StartupErrorText", true, false) as Label
		check("it says why on screen", label != null and label.text.contains("missing") and label.text.contains("nothing falls back"), label.text if label != null else "no label")
		check("no runner was borrowed", game.find_children("Runner", "", true, false).is_empty())
	await _drop_game()
	game = MAIN.new()
	game.set("level_script", FIXTURE)
	game.set("source_runner", "res://scripts/no_such_runner.gd")
	root.add_child(game)
	await ticks(4)
	check("a named runner that is missing also refuses to start", game.player == null and str(game.startup_error).contains("no_such_runner.gd"), game.startup_error)

func _group_registry() -> void:
	var real := MAPS.make()
	var truth: Array = []
	for id: String in MAPS.ORDER:
		if FileAccess.file_exists(str((MAPS.CATALOG[id] as Dictionary).script)):
			truth.append(id)
	await make_game({}, "", {"fixture": false})
	check("the chooser offers exactly the registered maps whose modules exist", game.call("map_ids") == truth, [game.call("map_ids"), truth])
	check("the old two maps are offered", "practice" in game.call("map_ids") and "overflow" in game.call("map_ids"))
	await open_menu()
	check("a card per playable map and none for missing ones", hud().map_buttons.keys() == truth, hud().map_buttons.keys())
	for id: String in MAPS.missing(real):
		check("%s is not shown while its module is absent" % id, not hud_texts(false).any(func(t: String) -> bool: return t.begins_with(str((MAPS.CATALOG[id] as Dictionary).name))))
	await _drop_game()
	# a registered breakwater module becomes the default, without the stand-in label.
	var extra := {"breakwater": {"name": "Breakwater (FIXTURE)", "theme": "fixture standing in for the module", "kind": "course", "script": FIXTURE_MAPS.Long},
		"practice": MAPS.CATALOG.practice, "broken": {"name": "Not a level", "kind": "course", "script": "res://scripts/r15_presets.gd"},
		"rainline": MAPS.CATALOG.rainline}
	var fixtures := FIXTURE_MAPS.registry(2, ["breakwater", "practice"], extra)
	await make_game({}, "", {"registry": fixtures})
	check("with a breakwater module, breakwater is the default", str(game.map_id) == "breakwater" and not bool(game.default_map_standin) and int(game.call("stage_count")) == 6, [game.map_id, game.default_map_standin])
	check("a module that is not a level is not playable", not "broken" in game.call("map_ids"), game.call("map_ids"))
	check("rainline is listed only if its module exists", ("rainline" in game.call("map_ids")) == FileAccess.file_exists(str(MAPS.CATALOG.rainline.script)))
	await _drop_game()
	fixtures.catalog.erase("breakwater")
	await make_game({}, "", {"registry": fixtures})
	check("without breakwater the chain falls to Penstock, labelled", str(game.map_id) == "practice" and bool(game.default_map_standin), [game.map_id, game.default_map_standin])
	await _drop_game()
	await make_game({}, "", {"registry": fixtures, "map": "rainline"})
	if not FileAccess.file_exists(str(MAPS.CATALOG.rainline.script)):
		check("asking for an unbuilt map starts the default instead", str(game.map_id) == "practice", game.map_id)

func _chooser_geometry(label: String) -> Dictionary:
	var side: Control = hud().get("_pause_side")
	var cards: Array = hud().map_buttons.values()
	var rects: Array[Rect2] = []
	for card: Button in cards:
		rects.append(card.get_global_rect())
	var inside := rects.all(func(r: Rect2) -> bool: return r.position.x >= side.get_global_rect().position.x - 0.5 and r.end.x <= side.get_global_rect().end.x + 0.5)
	var overlap := false
	for i: int in rects.size():
		for j: int in range(i + 1, rects.size()):
			if rects[i].grow(-0.5).intersects(rects[j].grow(-0.5)):
				overlap = true
	var xs := {}
	for r: Rect2 in rects:
		xs[roundi(r.position.x)] = true
	var texts_fit := cards.all(func(card: Button) -> bool: return card.size.y >= card.get_combined_minimum_size().y - 0.5)
	return {"label": label, "visible": root.get_visible_rect().size, "panel": side.size, "columns": xs.size(), "grid_columns": int(hud().map_grid.columns), "inside": inside, "overlap": overlap, "texts_fit": texts_fit, "cards": rects.size()}

func _group_chooser() -> void:
	var registry := FIXTURE_MAPS.registry(8)
	await set_window(Vector2i(1280, 720))
	await make_game({}, "", {"registry": registry})
	await open_menu()
	var layouts: Array = []
	for size: Vector2i in SIZES:
		await set_window(size)
		await process_frame
		var g := _chooser_geometry(str(size))
		layouts.append(g)
		check("%s: eight cards, all inside the panel, none overlapping, text fits" % size, g.cards == 8 and g.inside and not g.overlap and g.texts_fit, g)
		check("%s: the cards use the grid's columns" % size, g.columns == g.grid_columns and g.columns >= 2, g)
	notes["chooser_layouts"] = layouts
	check("a wider window gives more columns", int(layouts[3].columns) > int(layouts[0].columns), layouts)
	await set_window(Vector2i(1280, 720))
	await process_frame
	var keys := {}
	var stage_counts := {}
	for id: String in registry.order:
		await open_menu()
		var card: Button = hud().map_buttons[id]
		var loaded := str(game.map_id) == id
		var reached := await click_visible(card)
		await ticks(2)
		if loaded:
			check("clicking the loaded map's card keeps the menu and says so", bool(game.paused) and str(hud().message.text).contains("already loaded"), hud().message.text)
			await tap(KEY_ESCAPE)
		else:
			var ok := str(game.map_id) == id and at_spawn() and not bool(game.paused) and str(game.preset_id) == "server128"
			check("clicking %s's card loads it at its spawn, keeps the preset, closes the menu" % id, ok and reached, [game.map_id, game.paused, reached])
		keys[str(game.course_key)] = id
		stage_counts[id] = int(game.call("stage_count"))
	check("eight maps, eight record keys", keys.size() == 8, keys)
	check("stage counts follow each fixture (2, 3, 5 and 6 stages present)", [2, 3, 5, 6].all(func(n: int) -> bool: return n in stage_counts.values()), stage_counts)
	await open_menu()
	check("the stage picker lists the loaded map's stages", hud().stage_picker.item_count == int(game.call("stage_count")), [hud().stage_picker.item_count, game.call("stage_count")])
	check("the lab-kind card says it is not a course", (hud().map_buttons["fixture-08"] as Button).text.contains("not a course"), (hud().map_buttons["fixture-08"] as Button).text)
	await _drop_game()
	# twelve maps: more than fit at once, so the last card is reached by scrolling the menu.
	await make_game({}, "", {"registry": FIXTURE_MAPS.registry(12)})
	await open_menu()
	var g12 := _chooser_geometry("12 maps")
	check("twelve cards fit the panel without overlap", g12.cards == 12 and g12.inside and not g12.overlap, g12)
	var last: Button = hud().map_buttons["fixture-12"]
	var reached := await click_visible(last)
	await ticks(2)
	check("the twelfth card is reached with the wheel and loads", reached and str(game.map_id) == "fixture-12", [reached, game.map_id])

func _group_legacy() -> void:
	await make_game({}, "", {"fixture": false, "map": "practice"})
	check("Penstock Yard loads with the r14 readability pass", str(game.map_id) == "practice" and bool((game.level.get_meta("practice_readability", {}) as Dictionary).get("applied", false)))
	var practice_key := str(game.course_key)
	await open_menu()
	check("its card says it is an R14 map", (hud().map_buttons["practice"] as Button).text.contains("R14 map"), (hud().map_buttons["practice"] as Button).text)
	await click_visible(hud().map_buttons["overflow"])
	await ticks(2)
	check("Overflow loads from the chooser with the r14 art", str(game.map_id) == "overflow" and str(game.level.get("variant")) == "course" and bool((game.level.get_meta("overflow_art", {}) as Dictionary).get("applied", false)))
	check("Overflow starts at its spawn with its own key", at_spawn() and str(game.course_key) != practice_key)
	check("Overflow keeps its own kill bounds", game.call("kill_bounds") == game.level.get("kill_bounds"))
	for slot: Key in [KEY_F2, KEY_F5]:
		await tap(slot)
		await tap(KEY_R)
		var start := p().global_position
		key(KEY_W, true)
		await ticks(90)
		key(KEY_W, false)
		check("Overflow runs with %s" % game.preset_id, p().global_position.distance_to(start) > 2.0 and int(game.respawn_count) == 0, p().global_position)
	await open_menu()
	await click_visible(hud().map_buttons["practice"])
	await ticks(2)
	check("back on Penstock Yard with its own kill box, as in r14", str(game.map_id) == "practice" and game.call("kill_bounds") == game.level.get("kill_bounds"), [game.map_id, game.call("kill_bounds"), game.paused])
	check("a revisited key is the same key", str(game.course_key) != practice_key or str(game.preset_id) == "server128", [game.course_key, practice_key, game.preset_id])

func _group_hook() -> void:
	game = MAIN.new()
	game.set("level_script", FIXTURE)
	game.set("source_runner", MAIN.STANDIN)
	game.set("source_sensitivity_override", 5.7295779513)
	root.add_child(game)
	await ticks(4)
	check("a replay's source sensitivity applies for the run", is_equal_approx(float(p().get("tape_radians_per_count")), 0.0022), p().get("tape_radians_per_count"))
	check("the game exposes the tape hooks", "motor" in game and "physics_hz" in game and "level_script" in game and "tape_step_count" in p() and "_previous_position" in p() and "_current_position" in p())
	await _drop_game()
	for alias: Array in [["server", "server128", 128], ["aa1000", "server128_aa1000", 128], ["quake", "quake3_inspired128", 128], ["r13", "r13_original120", 120],
			["csgo_vanilla", "server128", 128], ["vanilla64", "server128", 128], ["f1", "server128", 128]]:
		await make_game({}, alias[0])
		check("motor %s selects %s at %d Hz" % alias, str(game.preset_id) == alias[1] and int(game.physics_hz) == alias[2] and Engine.physics_ticks_per_second == alias[2], [game.preset_id, game.physics_hz])
		await _drop_game()

func _group_switch() -> void:
	await make_game()
	await run_up(240.0)
	key(KEY_SPACE, true)
	await ticks(10)
	key(KEY_SPACE, false)
	mouse(-40, 12)
	await ticks(2)
	check("airborne before the switches", not grounded())
	var before := pose()
	key(KEY_F5, true)
	var after := pose()
	key(KEY_F5, false)
	check("F5 in the air keeps feet, velocity, view and the body exactly", before.feet == after.feet and before.velocity == after.velocity and before.yaw == after.yaw and before.pitch == after.pitch and before.node == after.node, [before, after])
	check("F5 applies AA 1000 at 128 Hz and the attempt becomes practice", float((p().get("settings") as Dictionary).sv_airaccelerate) == 1000.0 and Engine.physics_ticks_per_second == 128 and not bool(game.clean_eligible) and str(game.practice_reason) == "preset")
	await ticks(2)
	check("hud says practice and why", str(hud().practice_tag.text).contains("PRACTICE") and str(hud().practice_tag.text).contains("preset"), hud().practice_tag.text)
	await until(func() -> bool: return not grounded(), 10)
	before = pose()
	key(KEY_F3, true)
	after = pose()
	key(KEY_F3, false)
	check("F3 replaces the runner in place", before.node != after.node and after.script == "res://scripts/momentum_carry_air_candidate.gd" and before.feet == after.feet and before.velocity == after.velocity, [before, after])
	check("F3 runs 120 Hz and one runner remains", Engine.physics_ticks_per_second == 120 and game.find_children("Runner", "", false, false).size() == 1)
	await ticks(6)
	before = pose()
	key(KEY_F2, true)
	after = pose()
	key(KEY_F2, false)
	check("F2 back to the source body keeps feet, velocity and view", str(game.preset_id) == "server128" and before.feet == after.feet and before.velocity == after.velocity and before.yaw == after.yaw, [before, after])
	check("the source body is the r15 runner again", after.script == R15_RUNNER)
	await tap(KEY_R)
	check("R starts a clean attempt at the spawn", bool(game.clean_eligible) and str(game.practice_reason) == "" and float(game.elapsed) == 0.0 and at_spawn())

func _group_purity() -> void:
	await make_game()
	mouse(200, 0)
	await tap(KEY_F5)
	check("a switch at the untouched spawn stays clean", bool(game.clean_eligible) and str(game.preset_id) == "server128_aa1000")
	await tap(KEY_F2)
	# a few ticks of W: the body moves, but less than the timer's 0.5 m.
	key(KEY_W, true)
	await ticks(3)
	key(KEY_W, false)
	await ticks(2)
	var moved := Vector2(p().global_position.x - (game.level.spawn as Transform3D).origin.x, p().global_position.z - (game.level.spawn as Transform3D).origin.z).length()
	check("early movement did not start the timer", not bool(game.get("_started")) and float(game.elapsed) == 0.0 and moved > 0.001 and moved < 0.5, [moved, game.elapsed])
	await tap(KEY_F5)
	check("a switch after early movement makes the attempt practice", not bool(game.clean_eligible) and str(game.practice_reason) == "preset", [game.clean_eligible, game.practice_reason])
	await run_to_finish()
	check("that attempt finishes as practice", bool(game.finished) and str(game.finish_kind) == "practice" and float(game.best_time) < 0.0, [game.finish_kind, game.best_time])
	await tap(KEY_R)
	await ticks(30)
	var jumps := int(p().get("jump_count"))
	await tap(KEY_SPACE)
	await until(grounded, 300)
	await ticks(4)
	var back := p().global_position.distance_to((game.level.spawn as Transform3D).origin)
	await tap(KEY_F2)
	check("a jump in place before the run also counts as acting: the switch is practice", int(p().get("jump_count")) == jumps + 1 and not bool(game.clean_eligible), [back, game.clean_eligible])
	await tap(KEY_R)
	await run_to_finish()
	check("R then W is a clean finish with a best", str(game.finish_kind) == "clean" and float(game.best_time) > 0.0)
	var best := float(game.best_time)
	await tap(KEY_F)
	await run_to_finish()
	check("F practice finishes are not recorded", str(game.finish_kind) == "practice" and float(game.best_time) == best)
	await tap(KEY_R)
	mouse(counts_for(PI * 0.5))
	await ticks(1)
	key(KEY_W, true)
	await until(func() -> bool: return int(game.respawn_count) > 0, 1500)
	await until(func() -> bool: return bool(game.finished), 3000)
	key(KEY_W, false)
	check("a run with a respawn finishes as practice", int(game.respawn_count) > 0 and str(game.finish_kind) == "practice" and str(game.practice_reason) == "respawn", [game.respawn_count, game.finish_kind])

func _group_hull() -> void:
	await make_game({"spawn": "slot"}, "r13")
	var at := p().global_position
	await tap(KEY_F2)
	check("F2 waits in the 0.7 m slot: the standing source box does not fit", str(game.preset_id) == "r13_original120" and str(game.pending_preset) == "server128" and str(game.pending_message).contains("waits for room"), game.pending_message)
	check("waiting moves nothing", p().global_position.distance_to(at) < 0.01)
	await tap(KEY_F3)
	check("pressing the active preset cancels the wait", str(game.pending_preset) == "")
	await tap(KEY_F5)
	check("F5 waits too", str(game.pending_preset) == "server128_aa1000")
	await tap(KEY_F)
	check("checkpoint practice cancels the wait and keeps r13", str(game.pending_preset) == "" and str(game.preset_id) == "r13_original120" and str(hud().message.text).contains("request cancelled"), hud().message.text)
	await tap(KEY_F2)
	check("pending again before R", str(game.pending_preset) == "server128")
	await tap(KEY_R)
	check("R cannot apply it at a spawn where it does not fit", str(game.preset_id) == "r13_original120" and str(game.pending_preset) == "server128")
	key(KEY_W, true)
	var seen := {"at": Vector3.ZERO}
	var taken := await until(func() -> bool:
		if str(game.preset_id) == "server128":
			seen.at = p().global_position
			return true
		return false, 400)
	key(KEY_W, false)
	check("the switch happens once the runner walks out, without moving it sideways", taken >= 0 and absf((seen.at as Vector3).x - 9.0) < 0.2 and (seen.at as Vector3).z < -4.0 - 0.40, seen.at)
	await _drop_game()
	await make_game({"spawn": "slot"}, "r13", {"registry": FIXTURE_MAPS.registry(2, [], {"slot-a": {"name": "Slot A", "kind": "course", "script": FIXTURE}, "slot-b": {"name": "Slot B", "kind": "course", "script": FIXTURE}}), "map": "slot-a"})
	await tap(KEY_F2)
	check("pending on Slot A", str(game.pending_preset) == "server128")
	await open_menu()
	await click_visible(hud().map_buttons["slot-b"])
	await ticks(2)
	check("a map change cancels the wait, keeps r13 and says so", str(game.map_id) == "slot-b" and str(game.pending_preset) == "" and str(game.preset_id) == "r13_original120" and str(hud().message.text).contains("pending preset cancelled"), hud().message.text)

## one hop from a 240 u/s run-up; crouch pressed on the way up when `duck`. returns per-tick
## displayed speed and raw feet until landing.
func _hop_series(duck: bool, gate: AABB) -> Dictionary:
	await tap(KEY_R)
	await run_up(240.0)
	var out := {"speed": [], "raw_in_gate": false, "max_y": -INF, "stage": 0}
	key(KEY_SPACE, true)
	await physics_frame
	key(KEY_SPACE, false)
	await until(func() -> bool:
		(out.speed as Array).append(float(game.display_speed))
		return p().velocity.y < 1.2, 200)
	if duck:
		key(KEY_CTRL, true)
	await until(func() -> bool:
		(out.speed as Array).append(float(game.display_speed))
		out.max_y = maxf(out.max_y, p().global_position.y)
		if gate.has_point(p().global_position):
			out.raw_in_gate = true
		out.stage = maxi(out.stage, int(game.checkpoint_index))
		return grounded(), 300)
	key(KEY_CTRL, false)
	out["counts"] = (p().get("duck_counts") as Dictionary).duplicate()
	return out

func _group_offset() -> void:
	# a plain hop peaks about 56 u (1.42 m); a crouch on the way up lifts the feet 9 u (0.23 m)
	# without travel. the trigger's floor sits between the two peaks, wide across the deck.
	await make_game({"gate": 1.50})
	var gate: AABB = (game.level.checkpoints[1] as Dictionary).bounds
	var plain: Dictionary = await _hop_series(false, gate)
	var ducked: Dictionary = await _hop_series(true, gate)
	check("the real air crouch lifted the raw feet into the trigger", int(ducked.counts.duck_air) == 1 and ducked.raw_in_gate and not plain.raw_in_gate and float(ducked.max_y) - float(plain.max_y) > 0.2, [ducked.max_y, plain.max_y, ducked.counts])
	check("the lift alone does not reach the checkpoint", int(ducked.stage) == 0 and int(plain.stage) == 0, [ducked.stage, plain.stage])
	var n := mini((plain.speed as Array).size(), (ducked.speed as Array).size())
	var worst := 0.0
	for i: int in n:
		worst = maxf(worst, absf(float(plain.speed[i]) - float(ducked.speed[i])))
	check("the hud's actual-travel speed is the same tick for tick with and without the air crouch", n > 40 and worst < 1e-6, [n, worst])
	await _drop_game()
	await make_game({"gate": 1.25})
	gate = (game.level.checkpoints[1] as Dictionary).bounds
	var reach: Dictionary = await _hop_series(false, gate)
	check("control: a plain hop into a trigger it reaches counts", int(reach.stage) == 1, reach.stage)

func _group_kill() -> void:
	for lift: float in [0.0, 40.0]:
		var registry := FIXTURE_MAPS.registry(1, [], {"high": {"name": "High fixture", "kind": "course", "script": FIXTURE}})
		registry.default_chain = ["high"]
		await make_game({"no_kill": true, "lift": lift}, "", {"registry": registry})
		var bounds: AABB = game.call("kill_bounds")
		check("lift %d: a map without kill bounds gets its own, 12 m under its lowest solid" % lift, is_equal_approx(bounds.position.y, lift - 1.0 - 12.0), bounds)
		mouse(counts_for(PI * 0.5))
		await ticks(1)
		key(KEY_W, true)
		var low := {"y": INF}
		await until(func() -> bool:
			low.y = minf(low.y, p().global_position.y)
			return int(game.respawn_count) > 0, 2000)
		key(KEY_W, false)
		check("lift %d: falling out respawns at that map's scale" % lift, int(game.respawn_count) == 1 and float(low.y) < lift - 13.0 and float(low.y) > lift - 16.0 and absf(p().global_position.y - (lift + 0.04)) < 0.5, [low.y, p().global_position])
		await _drop_game()

func _group_lifecycle() -> void:
	await make_game()
	var order: Array = []
	key(KEY_W, true)
	for i: int in 3000:
		if order.is_empty() or order[-1] != int(game.checkpoint_index):
			order.append(int(game.checkpoint_index))
		if bool(game.finished):
			break
		await physics_frame
	key(KEY_W, false)
	check("checkpoints collected in order by standing on decks", order == [0, 1, 2], order)
	check("clean finish with every split", bool(game.finished) and str(game.finish_kind) == "clean" and (game.stage_times as Array).all(func(t: float) -> bool: return t > 0.0), [game.finish_kind, game.stage_times])
	check("finish card names map, preset and rate", str(hud().finish_body.text).contains("Loop fixture · CS:GO bhop server · 128 Hz"), hud().finish_body.text)
	check("nothing saved from a records-off game", not bool(game.last_save_ok))
	var best := float(game.best_time)
	await tap(KEY_F5)
	check("F5 has no best of its own yet", float(game.best_time) < 0.0)
	await tap(KEY_F2)
	check("switching back restores the server best only", float(game.best_time) == best)
	await tap(KEY_R)
	key(KEY_W, true)
	await until(func() -> bool: return int(game.checkpoint_index) >= 1, 2000)
	key(KEY_W, false)
	await tap(KEY_F)
	check("F retries from the last checkpoint reached, as practice", not bool(game.clean_eligible) and str(game.practice_reason) == "practice" and p().global_position.distance_to(((game.level.checkpoints[1] as Dictionary).pose as Transform3D).origin) < 0.1)
	await ticks(2)
	check("hud says checkpoint practice", str(hud().practice_tag.text).contains("checkpoint practice from Deck 1"), hud().practice_tag.text)

func pick_stage(index: int) -> int:
	await open_menu()
	await click_visible(hud().stage_picker)
	var popup: PopupMenu = hud().stage_picker.get_popup()
	if not popup.visible:
		check("picker popup opened on click", false)
		return hud().stage_picker.selected
	for i: int in popup.item_count * 2 + 2:
		var focus := popup.get_focused_item()
		if focus == index:
			break
		await ui_key(KEY_DOWN if focus < index else KEY_UP)
	await ui_key(KEY_ENTER)
	return hud().stage_picker.selected

func _group_stages() -> void:
	var registry := FIXTURE_MAPS.registry(4)
	await make_game({}, "", {"registry": registry, "map": "fixture-03"})
	check("a six-stage fixture is loaded", int(game.call("stage_count")) == 6)
	var chosen := await pick_stage(4)
	check("the picker took stage 4 by keys", chosen == 4, chosen)
	await click_visible(hud().stage_practice_button)
	await ticks(2)
	check("Practise here starts at stage 4's pose, as practice", int(game.checkpoint_index) == 4 and int(game.practice_stage) == 4 and not bool(game.clean_eligible) and p().global_position.distance_to(((game.level.checkpoints[4] as Dictionary).pose as Transform3D).origin) < 0.1 and not bool(game.paused))
	await run_to_finish()
	check("a stage practice finish is practice, never a best", str(game.finish_kind) == "practice" and float(game.best_time) < 0.0)
	await tap(KEY_F)
	check("F after it retries stage 5, the last reached", int(game.checkpoint_index) == 5 or int(game.checkpoint_index) == 4, game.checkpoint_index)
	await open_menu()
	await click_visible(hud().map_buttons["fixture-02"])
	await ticks(2)
	await open_menu()
	check("after a map change the picker lists the new map's two stages", hud().stage_picker.item_count == 2 and hud().stage_picker.selected == 0, hud().stage_picker.item_count)
	await click_visible(hud().resume_button)

func _group_rapid() -> void:
	var registry := FIXTURE_MAPS.registry(8)
	await make_game({}, "", {"registry": registry})
	var expected_map := str(game.map_id)
	var started := Time.get_ticks_msec()
	key(KEY_W, true)
	for i: int in 48:
		await tap(KEY_F5 if i % 2 == 0 else KEY_F2)
		if i % 3 == 0:
			await tap(KEY_SPACE)
		if i % 6 == 5:
			key(KEY_W, false)
			await open_menu()
			var id: String = registry.order[(i / 6) % 8]
			await click_visible(hud().map_buttons[id])
			expected_map = id
			if bool(game.paused):
				await tap(KEY_ESCAPE)
			key(KEY_W, true)
	key(KEY_W, false)
	await ticks(20)
	check("after 48 rapid switches and 8 map changes: one runner, one map", game.find_children("Runner", "", false, false).size() == 1 and game.find_children("Map", "", false, false).size() == 1)
	check("the last clicked map is loaded", str(game.map_id) == expected_map, [game.map_id, expected_map])
	check("the preset is the last key pressed and the rate settled", str(game.preset_id) == "server128" and Engine.physics_ticks_per_second == 128 and is_equal_approx(float(game.last_delta), 1.0 / 128.0), [game.preset_id, game.last_delta])
	check("no switch is left pending on the same body", str(game.pending_preset) == "")
	check("audio was rebuilt, not stacked", game.find_children("Audio", "", false, false).size() == 1, game.find_children("Audio", "", false, false).size())
	check("the current camera is the runner's", root.get_viewport().get_camera_3d() == p().get("camera"))
	notes["rapid_ms"] = Time.get_ticks_msec() - started
	await tap(KEY_R)
	await run_to_finish()
	check("a clean run still finishes after the churn", str(game.finish_kind) == "clean", game.finish_kind)

# --- persistence and quit across processes ----------------------------------------------------

func _user_dir(xdg: String) -> String:
	return xdg.path_join("data/godot/app_userdata").path_join(str(ProjectSettings.get_setting("application/config/name")))

func _run_child(base: String, step: String, extra: Array = [], profile: String = "user://spillway_r15.cfg") -> Dictionary:
	var godot := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://")
	var args := PackedStringArray(["XDG_DATA_HOME=" + base.path_join("data"), "XDG_CONFIG_HOME=" + base.path_join("config"), "XDG_CACHE_HOME=" + base.path_join("cache"),
		godot, "--headless", "--audio-driver", "Dummy", "--fixed-fps", "128", "--path", project, "--script", "res://tests/test_r15_loop.gd", "--",
		"--phase=" + step, "--out=" + out_dir.path_join("phase-" + step), "--r15-profile=" + profile])
	args.append_array(extra)
	var output: Array = []
	var began := Time.get_ticks_msec()
	var code := OS.execute("env", args, output, true)
	var log := FileAccess.open(out_dir.path_join("phase-%s.log" % step), FileAccess.WRITE)
	log.store_string("\n".join(output))
	log.close()
	var path := out_dir.path_join("phase-" + step).path_join("report.json")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	report["exit"] = code
	report["wall_ms"] = Time.get_ticks_msec() - began
	report["engine_errors"] = Array("\n".join(output).split("\n")).filter(func(l: String) -> bool: return l.contains("ERROR"))
	return report

## json reports carry numbers as floats; ticks are compared as the integers they encode.
static func _ints(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for v: Variant in value:
			out.append(int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] and float(v) == floorf(float(v)) else v)
	return out

static func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

func _group_persist() -> void:
	var base := out_dir.path_join("profiles")
	var user := _user_dir(base)
	DirAccess.make_dir_recursive_absolute(user)
	var r15 := user.path_join("spillway_r15.cfg")
	var r14 := user.path_join("spillway_r14.cfg")
	var r14_text := "[profile]\n\nformat=1\nbuild=\"spillway-2026.11.08-r14\"\n\n[settings]\n\nsource_sensitivity=3.7\nsource_fov=100.0\nvolume=0.4\nshow_ms=false\n\n[course_0123456789abcdef]\n\nclean_best_ticks=1000\nclean_best=7.8125\n"
	var file := FileAccess.open(r14, FileAccess.WRITE)
	file.store_string(r14_text)
	file.close()
	var r14_hash := _hash(r14)
	var seed := _run_child(base, "seed")
	check("seed: exits 0 on the isolated profile", seed.exit == 0 and str(seed.get("user_dir", "")).simplify_path() == user.simplify_path(), [seed.exit, seed.get("user_dir")])
	check("seed: first launch reads the r14 look settings", is_equal_approx(float(seed.get("source_sensitivity", 0)), 3.7) and is_equal_approx(float(seed.get("source_fov", 0)), 100.0) and not bool(seed.get("show_ms", true)) and bool(seed.get("seeded", false)), seed)
	check("seed: no r14 best is imported", float(seed.get("best", 0)) < 0.0 and str(seed.get("record_state", "x")) == "", seed)
	check("seed: the r14 profile is unchanged and nothing was written", _hash(r14) == r14_hash and not FileAccess.file_exists(r15), [_hash(r14), FileAccess.file_exists(r15)])
	var first := _run_child(base, "first")
	check("first: a clean finish was saved", first.exit == 0 and bool(first.get("saved", false)) and str(first.get("finish_kind")) == "clean", first)
	var config := ConfigFile.new()
	config.load(r15)
	var sections := Array(config.get_sections()).filter(func(s: String) -> bool: return s.begins_with("course_"))
	check("first: one record section", sections.size() == 1, config.get_sections())
	var section: String = sections[0] if not sections.is_empty() else ""
	var stored := {"clean": config.get_value(section, "clean_best_ticks", null), "open": config.get_value(section, "open_best_ticks", null), "splits": config.get_value(section, "clean_split_ticks", null), "segments": config.get_value(section, "clean_segment_ticks", null)}
	check("first: times are stored as integer ticks", typeof(stored.clean) == TYPE_INT and typeof(stored.open) == TYPE_INT and (stored.splits as Array).all(func(t: Variant) -> bool: return typeof(t) == TYPE_INT) and (stored.segments as Array).all(func(t: Variant) -> bool: return typeof(t) == TYPE_INT), stored)
	check("first: the stored ticks are the finish's ticks", stored.clean == int(first.get("best_ticks", -2)) and stored.splits == _ints(first.get("split_ticks")) and (stored.splits as Array).size() == 3 and (stored.segments as Array).size() == 3, [stored, first.get("best_ticks"), first.get("split_ticks")])
	check("first: the section carries its full identity with the r15 runner and its duck settings", str(config.get_value(section, "identity", "")) == str(first.get("identity")) and not bool(config.get_value(section, "standin", true)) and str(config.get_value(section, "runner", "")) == R15_RUNNER and str(first.get("identity")).contains("duck_hull_height") and str(config.get_value(section, "family_version", "")) == "r15-source-crouch-2")
	check("first: the r14 profile is still unchanged", _hash(r14) == r14_hash)
	var reload := _run_child(base, "reload")
	check("reload: a fresh process loads the best, splits and segments exactly", reload.exit == 0 and str(reload.get("record_state")) == "loaded" and int(reload.get("loaded_best_ticks", -2)) == stored.clean and _ints(reload.get("loaded_split_ticks")) == stored.splits and _ints(reload.get("loaded_segment_ticks")) == stored.segments, [reload.get("record_state"), reload.get("loaded_best_ticks"), reload.get("loaded_split_ticks")])
	check("reload: the r15 profile's own settings win over r14 now", is_equal_approx(float(reload.get("source_sensitivity", 0)), 3.0) and not bool(reload.get("seeded", true)), reload.get("source_sensitivity"))
	check("reload: F5 has no best from F2's key", float(reload.get("aa_best_on_switch", 0)) < 0.0 and str(reload.get("aa_key")) != str(reload.get("server_key")))
	check("reload: an F5 clean finish saved its own section", bool(reload.get("aa_saved", false)))
	var before := _hash(r15)
	var practice := _run_child(base, "practice")
	check("practice: checkpoint practice, respawn and mixed-preset finishes save nothing", practice.exit == 0 and practice.get("kinds") == ["practice", "practice", "practice"] and _hash(r15) == before, [practice.get("kinds"), _hash(r15) == before])
	var again := _run_child(base, "again")
	check("again: both sections reload after the practice process", str(again.get("record_state")) == "loaded" and int(again.get("loaded_best_ticks", -2)) == stored.clean and str(again.get("aa_record_state")) == "loaded", again)
	var norecords := _run_child(base, "norecords", ["--no-records"])
	check("--no-records finishes without writing", norecords.exit == 0 and str(norecords.get("profile_state")) == "off" and _hash(r15) == before)
	# malformed sections: each copy differs from the saved one in one way and must be refused whole.
	var good := FileAccess.get_file_as_string(r15)
	var mutations := {
		"control": func(c: ConfigFile) -> void: pass,
		"float best": func(c: ConfigFile) -> void: c.set_value(section, "clean_best_ticks", float(stored.clean)),
		"missing split": func(c: ConfigFile) -> void: c.set_value(section, "clean_split_ticks", (stored.splits as Array).slice(0, 2)),
		"splits out of order": func(c: ConfigFile) -> void: c.set_value(section, "clean_split_ticks", [stored.splits[1], stored.splits[0], stored.splits[2]]),
		"last split not the best": func(c: ConfigFile) -> void: c.set_value(section, "clean_best_ticks", int(stored.clean) - 1),
		"segment longer than its split": func(c: ConfigFile) -> void: c.set_value(section, "clean_segment_ticks", [int(stored.segments[0]) + 50, stored.segments[1], stored.segments[2]]),
		"open slower than clean": func(c: ConfigFile) -> void: c.set_value(section, "open_best_ticks", int(stored.clean) + 1),
		"negative tick": func(c: ConfigFile) -> void: c.set_value(section, "clean_segment_ticks", [-1, stored.segments[1], stored.segments[2]]),
		"string ticks": func(c: ConfigFile) -> void: c.set_value(section, "clean_split_ticks", (stored.splits as Array).map(func(t: int) -> String: return str(t))),
		"other rate": func(c: ConfigFile) -> void: c.set_value(section, "physics_hz", 64),
		"tick version 2": func(c: ConfigFile) -> void: c.set_value(section, "time_ticks_version", 2),
		"identity edited": func(c: ConfigFile) -> void: c.set_value(section, "identity", str(c.get_value(section, "identity")).replace("r15-timing-1", "r15-timing-0")),
		"no identity": func(c: ConfigFile) -> void: c.set_value(section, "identity", null),
	}
	var rows := {}
	for name: String in mutations:
		var mutated := ConfigFile.new()
		mutated.parse(good)
		(mutations[name] as Callable).call(mutated)
		var path := user.path_join("mutated.cfg")
		mutated.save(path)
		var report := _run_child(base, "inspect", [], "user://mutated.cfg")
		rows[name] = {"state": report.get("record_state"), "best": report.get("loaded_best_ticks"), "splits": report.get("loaded_split_ticks")}
		if name == "control":
			check("malformed control: the unmodified copy loads", str(report.get("record_state")) == "loaded" and int(report.get("loaded_best_ticks", -2)) == stored.clean, rows[name])
		else:
			check("malformed '%s' is refused whole" % name, str(report.get("record_state", "")).begins_with("rejected") and int(report.get("loaded_best_ticks", 0)) == -1 and (report.get("loaded_split_ticks", [0]) as Array).is_empty(), rows[name])
	notes["malformed"] = rows
	DirAccess.remove_absolute(user.path_join("mutated.cfg"))
	check("the r14 profile ended byte-for-byte unchanged", _hash(r14) == r14_hash)

func _group_quit() -> void:
	var base := out_dir.path_join("quit-profile")
	var report := _run_child(base, "quit")
	check("clicking Quit in the menu ends the process with exit 0", report.exit == 0 and bool(report.get("clicked", false)) and not bool(report.get("survived", false)), report)
	check("no engine errors on the way out", (report.engine_errors as Array).is_empty(), report.engine_errors)

## the child side: a game from the real scene with persistence on, on the fixture.
func _child_phase() -> void:
	var report := {"phase": phase, "user_dir": ProjectSettings.globalize_path("user://")}
	var write := func() -> void:
		DirAccess.make_dir_recursive_absolute(out_dir)
		var f := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	await make_game({}, "", {"scene": true})
	report["profile_state"] = game.profile_state
	report["server_key"] = game.course_key
	report["record_state"] = game.record_state
	report["seeded"] = game.seeded_settings
	report["best"] = game.best_time
	for k: String in ["source_sensitivity", "source_fov", "show_ms"]:
		report[k] = game.settings[k]
	report["loaded_best_ticks"] = game.call("_record_ticks", float(game.best_time))
	report["loaded_split_ticks"] = game.call("_record_tick_array", game.best_splits)
	report["loaded_segment_ticks"] = game.call("_record_tick_array", game.best_segments)
	match phase:
		"first":
			game.call("change_setting", "source_sensitivity", 3.0)
			await run_to_finish()
			report["finish_kind"] = game.finish_kind
			report["saved"] = game.last_save_ok
			report["best_ticks"] = game.call("_record_ticks", float(game.best_time))
			report["split_ticks"] = game.call("_record_tick_array", game.best_splits)
			report["identity"] = game.call("record_identity_text")
		"reload":
			await tap(KEY_F5)
			report["aa_best_on_switch"] = game.best_time
			report["aa_key"] = game.course_key
			await tap(KEY_R)
			await run_to_finish()
			report["aa_saved"] = game.last_save_ok and str(game.finish_kind) == "clean"
		"practice":
			var kinds: Array = []
			key(KEY_W, true)
			await until(func() -> bool: return int(game.checkpoint_index) >= 1, 2000)
			await tap(KEY_F)
			await run_to_finish()
			kinds.append(game.finish_kind)
			await tap(KEY_R)
			mouse(counts_for(PI * 0.5))
			key(KEY_W, true)
			await until(func() -> bool: return int(game.respawn_count) > 0, 1500)
			await run_to_finish()
			kinds.append(game.finish_kind)
			await tap(KEY_R)
			key(KEY_W, true)
			await ticks(60)
			await tap(KEY_F5)
			await run_to_finish()
			kinds.append(game.finish_kind)
			report["kinds"] = kinds
		"again":
			await tap(KEY_F5)
			report["aa_record_state"] = game.record_state
		"norecords":
			await run_to_finish()
		"quit":
			write.call()
			await open_menu()
			report["clicked"] = true
			write.call()
			await click_visible(hud().quit_button)
			await ticks(120)
			report["survived"] = true
			write.call()
			quit(5)
			return
	write.call()
	await _drop_game()
	quit(0)

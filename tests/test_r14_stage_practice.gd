extends SceneTree
## p / r14 stage practice from the pause menu (docs/r14/STAGE-PRACTICE.md). every route is driven
## by ordinary key and relative-mouse events through Input, and the pause menu's stage picker,
## its "Practise here" button and the preset and map buttons are operated by clicks pushed
## through the viewport and arrow/Enter keys in the picker's popup. nothing calls practise_stage
## except the one labelled index-clamp check, and nothing writes the runner's pose or velocity.
## penstock, overflow and order build the real maps; keys, stats, purity, pending and control run
## on the labelled FIXTURE level (tests/r14_loop_fixture_level.gd), whose flat decks finish under
## held W. purity and control persist into an isolated profile file in --out and compare its
## hash. none of this says anything about how a stage or a preset feels.
## godot --headless --audio-driver Dummy --fixed-fps 120 --path . \
##   --script res://tests/test_r14_stage_practice.gd -- --out=DIR [--only=GROUPS]
## groups: penstock, overflow, order, keys, stats, purity, pending, control.
## --tour: a native pause/player tour for frames (run under a private Xvfb with --write-movie).

const MAIN := preload("res://scripts/r14_main.gd")
const SCENE := "res://scenes/r14.tscn"
const FIXTURE := preload("res://tests/r14_loop_fixture_level.gd")
const PRESETS := preload("res://scripts/r14_presets.gd")
const U := 0.0254
const GROUPS := ["penstock", "overflow", "order", "keys", "stats", "purity", "pending", "control"]
const PENSTOCK_TITLES := ["Gatehouse", "Stop logs", "Valve bend", "Penstock straight", "Weir gauges", "Pump bend", "Tail race"]
const OVERFLOW_TITLES := ["Crest", "Pier", "Chute", "Tail race"]
const RUNWAY := 3

var out_dir := ""
var results: Array[Dictionary] = []
var only: Array = []
var tour := false
var _group := ""
var game: Node
var _frames: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg == "--tour":
			tour = true
	if out_dir.is_empty():
		printerr("usage: --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_main.call_deferred()

func _main() -> void:
	var started := Time.get_ticks_msec()
	if tour:
		_group = "tour"
		await _tour()
	else:
		for group: String in GROUPS:
			if only.is_empty() or group in only:
				_group = group
				print("group: ", group)
				await call("_group_" + group)
				await _drop_game()
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	var summary := {"checks": results.size(), "failed": failed.size(), "results": results, "frames": _frames,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0, "engine": Engine.get_version_info(), "display": DisplayServer.get_name()}
	var file := FileAccess.open(out_dir.path_join("summary.json" if not tour else "tour.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	file.close()
	for r: Dictionary in failed:
		printerr("FAIL %s / %s: %s" % [r.group, r.name, r.detail])
	print("r14 stage practice: %d checks, %d failed" % [results.size(), failed.size()])
	await _drop_game()
	quit(1 if failed.size() > 0 else 0)

func check(name: String, ok: bool, detail: Variant = "") -> bool:
	results.append({"group": _group, "name": name, "ok": ok, "detail": str(detail)})
	if not ok:
		printerr("  fail: %s (%s)" % [name, detail])
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

## a key through the viewport, so an open popup menu that has focus receives it.
func ui_key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

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

func make_game(params: Dictionary = {}, alias: String = "", fixture: bool = true, profile: String = "") -> Node:
	FIXTURE.params = params
	game = MAIN.new()
	if fixture:
		game.set("level_script", FIXTURE)
	if not alias.is_empty():
		game.set("motor", alias)
	if not profile.is_empty():
		# an explicit file in --out: the game persists into it and nowhere else.
		game.set("persist", true)
		game.set("profile_path", profile)
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

func grounded() -> bool:
	return bool(p().call("is_grounded"))

func hud() -> Node:
	return game.hud

func picker() -> OptionButton:
	return game.hud.stage_picker

func picker_items() -> Array[String]:
	var items: Array[String] = []
	for i: int in picker().item_count:
		items.append(picker().get_item_text(i))
	return items

func stage_pose(stage: int) -> Transform3D:
	return (game.level.checkpoints[stage] as Dictionary).pose

## horizontal distance from a stage's authored feet, and the yaw difference to its facing.
func off_pose(stage: int) -> Array:
	var pose := stage_pose(stage)
	var feet: Vector3 = p().global_position
	var yaw_target := pose.basis.get_euler().y
	return [Vector2(feet.x - pose.origin.x, feet.z - pose.origin.z).length(), absf(feet.y - pose.origin.y), absf(angle_difference(float(p().get("yaw")), yaw_target))]

## `slack` metres for a sloped stage deck, where the runner settles in the ticks after the reset.
func at_pose(stage: int, slack: float = 0.0) -> bool:
	var off := off_pose(stage)
	return off[0] < 0.05 + slack and off[1] < 0.1 + slack and off[2] < 1e-4

func counts_for(radians: float) -> float:
	if "tape_radians_per_count" in p():
		return radians / float(p().get("tape_radians_per_count"))
	return radians / float(p().get("mouse_sensitivity"))

func hspeed_u() -> float:
	return Vector2(p().velocity.x, p().velocity.z).length() / U

## press Esc unless already paused; the menu must be open afterwards.
func open_menu() -> void:
	if not bool(game.paused):
		await tap(KEY_ESCAPE)

## opens the picker with a click, walks the popup's highlight with arrow keys to `index` and
## takes it with Enter, as a keyboard player would. returns the selection afterwards.
func pick_stage(index: int) -> int:
	await open_menu()
	await click_visible(picker())
	var popup := picker().get_popup()
	if not check_quiet(popup.visible, "picker popup opened on click", picker().get_global_rect()):
		return picker().selected
	await walk_popup(popup, index)
	await ui_key(KEY_ENTER)
	return picker().selected

## arrow keys until the popup highlights `index`; the first press may only focus the list.
func walk_popup(popup: PopupMenu, index: int) -> void:
	for i: int in popup.item_count * 2 + 2:
		var focus := popup.get_focused_item()
		if focus == index:
			return
		await ui_key(KEY_DOWN if focus < index else KEY_UP)

## a failing check is recorded; a passing one is not, so helpers do not inflate the count.
func check_quiet(ok: bool, name: String, detail: Variant = "") -> bool:
	if not ok:
		check(name, false, detail)
	return ok

## the pause menu scrolls: wheel over it until the control is inside its view, then click.
func click_visible(control: Control) -> void:
	var scroll: ScrollContainer = hud().get("_pause_scroll")
	for i: int in 60:
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
	await click(control)

## the menu route Mike takes: Esc, pick the stage, click Practise here.
func practise_from_menu(index: int) -> bool:
	var chosen := await pick_stage(index)
	await click_visible(hud().stage_practice_button)
	await ticks(2)
	return chosen == index

## hold W until the level reports a finish (fixture decks run straight to the gate).
func run_to_finish(limit: int = 4000) -> bool:
	key(KEY_W, true)
	await until(func() -> bool: return bool(game.finished), limit)
	key(KEY_W, false)
	await ticks(2)
	return bool(game.finished)

func hop(side: int, dx: float, limit: int = 300) -> void:
	key(KEY_SPACE, true)
	await physics_frame
	key(KEY_SPACE, false)
	if side < 0:
		key(KEY_A, true)
	elif side > 0:
		key(KEY_D, true)
	await until(func() -> bool:
		if dx != 0.0:
			mouse(dx)
		return grounded(), limit)
	key(KEY_A, false)
	key(KEY_D, false)
	await physics_frame

func file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

# --- groups -----------------------------------------------------------------------------------

## the brief's route: from the default start, reach Penstock's runway directly and compare presets there.
func _group_penstock() -> void:
	await make_game({}, "", false)
	check("starts on Penstock Yard with the server preset", str(game.map_id) == "practice" and str(game.preset_id) == "server128")
	var attempts := int(game.attempts)
	var chosen := await practise_from_menu(RUNWAY)
	check("picker item 3 is the runway", chosen and picker().get_item_text(RUNWAY) == "3  Penstock straight", picker().get_item_text(RUNWAY))
	check("Practise here closes the menu and returns control", not bool(game.paused) and not hud().pause_panel.visible and bool(p().get("input_enabled")))
	check("runner is at the runway's authored pose and facing", at_pose(RUNWAY), off_pose(RUNWAY))
	check("practice attempt: new, clock zero, not armed", int(game.attempts) == attempts + 1 and float(game.elapsed) == 0.0 and not bool(game.get("_started")), [game.attempts, game.elapsed])
	check("practice state names the stage", not bool(game.clean_eligible) and str(game.practice_reason) == "practice" and int(game.practice_stage) == RUNWAY and int(game.checkpoint_index) == RUNWAY)
	await ticks(2)
	check("hud labels unrecorded stage practice", str(hud().practice_tag.text).contains("stage practice from Penstock straight") and str(hud().best_line.text) == "practice · not recorded", [hud().practice_tag.text, hud().best_line.text])
	check("practice notice says not recorded", str(hud().message.text).contains("Stage practice from Penstock straight · not recorded"), hud().message.text)
	# compare presets on the runway: each one from the menu, then Practise here again.
	for id: String in ["server128", "vanilla64", "r13_original120", "quake3_inspired128"]:
		await open_menu()
		await click_visible(hud().preset_buttons[id])
		check("%s: picker still offers the runway after the preset click" % id, picker().selected == RUNWAY, picker().selected)
		await click_visible(hud().stage_practice_button)
		await ticks(2)
		var start: Vector3 = p().global_position
		check("%s: back at the runway pose" % id, str(game.preset_id) == id and at_pose(RUNWAY) and Engine.physics_ticks_per_second == int(PRESETS.entry(id).rate), [game.preset_id, off_pose(RUNWAY)])
		check("%s: active preset and practice status do not overlap" % id, not hud().identity.get_global_rect().intersects(hud().practice_tag.get_global_rect()), [hud().identity.get_global_rect(), hud().practice_tag.get_global_rect()])
		key(KEY_W, true)
		await ticks(int(PRESETS.entry(id).rate) * 2)
		key(KEY_W, false)
		var moved: Vector3 = p().global_position - start
		# the runway runs along -x from the stage pose (r14_practice_level.gd, yaw pi/2).
		check("%s: W runs along the runway with no fall" % id, moved.x < -8.0 and absf(moved.z) < 0.5 and absf(moved.y) < 0.2 and int(game.respawn_count) == 0 and bool(game.get("_started")), [moved, game.respawn_count])
		check("%s: still unrecorded practice" % id, not bool(game.clean_eligible) and str(game.practice_reason) == "practice")
	_frames.append({"group": _group, "note": "runway compare done", "feet": str(p().global_position)})

func _group_overflow() -> void:
	await make_game({}, "", false)
	await open_menu()
	await click_visible(hud().map_buttons["overflow"])
	check("map button loads Overflow at its spawn", str(game.map_id) == "overflow" and not bool(game.paused))
	await open_menu()
	check("picker lists Overflow's stages in order", picker_items() == ["Start  Crest", "1  Pier", "2  Chute", "3  Tail race"], picker_items())
	check("picker starts on Overflow's start after the switch", picker().selected == 0, picker().selected)
	var chosen := await practise_from_menu(2)
	# the chute deck slopes, so the runner has slid a few centimetres in the two ticks since.
	check("Overflow: Chute chosen and practised", chosen and at_pose(2, 0.15) and int(game.practice_stage) == 2, [chosen, off_pose(2)])
	check("Overflow: labelled unrecorded", str(hud().practice_tag.text).contains("stage practice from Chute"), hud().practice_tag.text)
	var start: Vector3 = p().global_position
	key(KEY_W, true)
	await ticks(120)
	key(KEY_W, false)
	check("Overflow: W moves from the Chute pose", p().global_position.distance_to(start) > 2.0, p().global_position - start)
	check("Overflow: still practice", not bool(game.clean_eligible) and str(game.preset_id) == "server128")

func _group_order() -> void:
	await make_game({}, "", false)
	await open_menu()
	var expected: Array[String] = []
	for i: int in PENSTOCK_TITLES.size():
		expected.append(hud().call("stage_item_text", i, PENSTOCK_TITLES[i]))
	check("Penstock: one item per stage, in stage order", picker_items() == expected and picker().item_count == int(game.call("stage_count")), picker_items())
	var titles: Array[String] = []
	for i: int in int(game.call("stage_count")):
		titles.append(str(game.call("stage_title", i)))
	check("Penstock: items come from the map's checkpoints", titles == PENSTOCK_TITLES, titles)
	check("Penstock: item ids are stage indices", range(picker().item_count).all(func(i: int) -> bool: return picker().get_item_id(i) == i))
	await click_visible(hud().map_buttons["overflow"])
	await open_menu()
	check("Overflow replaces the items", picker().item_count == OVERFLOW_TITLES.size() and picker().get_item_text(3) == "3  Tail race", picker_items())
	await click_visible(hud().map_buttons["practice"])
	await open_menu()
	check("back on Penstock: seven items again, start selected", picker().item_count == 7 and picker().selected == 0, [picker().item_count, picker().selected])
	# a stage index from outside the menu is clamped: the one direct call in this file.
	game.call("set_paused", false)
	game.call("practise_stage", 99)
	check("index above the map is clamped to the last stage", int(game.practice_stage) == 6 and at_pose(6), game.practice_stage)
	game.call("practise_stage", -4)
	check("negative index is clamped to the start", int(game.practice_stage) == 0 and at_pose(0), game.practice_stage)

## the F key still practises the last reached stage; R always starts clean at the normal spawn.
func _group_keys() -> void:
	await make_game()
	key(KEY_W, true)
	await until(func() -> bool: return int(game.checkpoint_index) >= 1, 2000)
	key(KEY_W, false)
	await ticks(4)
	await tap(KEY_F)
	check("F practises the reached stage (Alpha)", at_pose(1) and int(game.practice_stage) == 1 and not bool(game.clean_eligible), off_pose(1))
	await practise_from_menu(2)
	check("menu practises Beta", at_pose(2) and int(game.practice_stage) == 2)
	await tap(KEY_F)
	check("F after a menu practice repeats that stage", at_pose(2) and int(game.practice_stage) == 2, game.practice_stage)
	await tap(KEY_R)
	check("R: clean attempt at the normal spawn", at_pose(0) and p().global_position.distance_to((game.level.spawn as Transform3D).origin) < 0.05 and bool(game.clean_eligible)
		and str(game.practice_reason) == "" and int(game.practice_stage) == -1 and int(game.checkpoint_index) == 0 and float(game.elapsed) == 0.0, [game.clean_eligible, game.practice_reason, game.practice_stage])
	await open_menu()
	check("menu opens on the last reached stage, which R reset to start", picker().selected == 0, picker().selected)
	await click_visible(hud().restart_button)
	check("Restart button is R", bool(game.clean_eligible) and at_pose(0) and not bool(game.paused))
	check("R run finishes clean", await run_to_finish() and str(game.finish_kind) == "clean", game.finish_kind)

func _group_stats() -> void:
	await make_game()
	key(KEY_W, true)
	await until(func() -> bool: return int(game.checkpoint_index) >= 1, 2000)
	await hop(-1, -counts_for(0.01))
	await hop(1, counts_for(0.01))
	key(KEY_W, false)
	await tap(KEY_R)
	mouse(counts_for(PI * 0.5))
	await ticks(1)
	key(KEY_W, true)
	await until(func() -> bool: return int(game.respawn_count) > 0, 1500)
	key(KEY_W, false)
	await ticks(4)
	key(KEY_W, true)
	await ticks(30)
	await hop(-1, -counts_for(0.01))
	key(KEY_W, false)
	var before := {"hops": int(game.stats.hop_count), "eligible": int(game.stats.total_eligible), "last": (game.stats.last_hop as Dictionary).size(), "respawns": int(game.respawn_count),
		"elapsed": float(game.elapsed), "resets": int(game.stats.resets)}
	check("setup produced hops, sync samples, a respawn and a running clock", before.hops > 0 and before.eligible > 0 and before.last > 0 and before.respawns == 1 and before.elapsed > 0.0, before)
	await practise_from_menu(1)
	check("practice resets the strafe stats", int(game.stats.resets) > int(before.resets) and int(game.stats.hop_count) == 0 and int(game.stats.total_eligible) == 0 and (game.stats.last_hop as Dictionary).is_empty() and (game.stats.flight as Dictionary).is_empty(),
		[game.stats.resets, game.stats.hop_count, game.stats.total_eligible])
	check("practice clears respawns, splits and the clock", int(game.respawn_count) == 0 and (game.stage_times as Array).all(func(t: float) -> bool: return t < 0.0) and (game.split_deltas as Array).is_empty() and float(game.elapsed) == 0.0,
		[game.respawn_count, game.stage_times, game.elapsed])
	check("hud strafe panel is back to its empty state", str(hud().strafe_last.text) == "last hop  —", hud().strafe_last.text)
	check("speed readout cleared", float(game.display_speed) < 0.01 or hspeed_u() < 1.0, game.display_speed)

## practice never saves a best, whichever way it is entered, on a source, the r13 and the f4 law.
func _group_purity() -> void:
	for id: String in ["server128", "r13_original120", "quake3_inspired128"]:
		var path := ProjectSettings.globalize_path(out_dir).path_join("purity-%s.cfg" % id)
		DirAccess.remove_absolute(path)
		await make_game({}, id, true, path)
		check("%s: profile is an isolated file" % id, bool(game.persist) and str(game.profile_path) == path and str(game.preset_id) == id, [game.persist, game.profile_path, game.preset_id])
		# 1. before the timer started: straight from the fresh spawn, through the menu.
		await practise_from_menu(1)
		check("%s: untouched spawn practice is practice" % id, not bool(game.clean_eligible) and not bool(game.get("_started")))
		var done := await run_to_finish()
		check("%s: practice before the timer finishes unrecorded" % id, done and str(game.finish_kind) == "practice" and not bool(game.last_save_ok) and float(game.best_time) < 0.0 and file_hash(path).is_empty(), [game.finish_kind, game.last_save_ok, game.best_time, file_hash(path)])
		check("%s: practice finish card says not recorded" % id, str(hud().finish_body.text).contains("Not recorded (stage practice from Alpha deck)"), hud().finish_body.text)
		# 2. F at the start of a fresh R attempt.
		await tap(KEY_R)
		await tap(KEY_F)
		done = await run_to_finish()
		check("%s: F at the start finishes unrecorded" % id, done and str(game.finish_kind) == "practice" and file_hash(path).is_empty(), [game.finish_kind, file_hash(path)])
		# 3. mid-run, with the clock going.
		await tap(KEY_R)
		key(KEY_W, true)
		await until(func() -> bool: return int(game.checkpoint_index) >= 1, 2000)
		key(KEY_W, false)
		check("%s: clock running before the mid-run practice" % id, bool(game.get("_started")) and float(game.elapsed) > 0.0)
		await practise_from_menu(1)
		done = await run_to_finish()
		check("%s: mid-run practice finishes unrecorded" % id, done and str(game.finish_kind) == "practice" and file_hash(path).is_empty(), [game.finish_kind, file_hash(path)])
		# 4. control: a clean R run saves, so the file check can see a save.
		await tap(KEY_R)
		done = await run_to_finish()
		var saved := file_hash(path)
		var best := float(game.best_time)
		check("%s: control: a clean R finish saves a best" % id, done and str(game.finish_kind) == "clean" and bool(game.last_save_ok) and best > 0.0 and not saved.is_empty(), [game.finish_kind, game.last_save_ok, best])
		# 5. after the finish: practise from the finish card's state.
		await practise_from_menu(2)
		check("%s: after-finish practice clears the finish" % id, not bool(game.finished) and str(game.finish_kind) == "" and not hud().finish_panel.visible)
		done = await run_to_finish()
		var config := ConfigFile.new()
		config.load(path)
		var section := "course_" + str(game.course_key)
		# last_save_ok still reports the clean run's save; the file's hash is the proof here.
		check("%s: after-finish practice finishes unrecorded" % id, done and str(game.finish_kind) == "practice" and file_hash(path) == saved and float(game.best_time) == best,
			[game.finish_kind, file_hash(path) == saved, game.best_time, best])
		check("%s: profile best is still the clean run" % id, is_equal_approx(float(config.get_value(section, "clean_best", -1.0)), best) and is_equal_approx(float(config.get_value(section, "open_best", -1.0)), best), config.get_sections())
		await _drop_game()

## p: a waiting preset request is cancelled by stage practice and the active law is retained.
func _group_pending() -> void:
	var path := ProjectSettings.globalize_path(out_dir).path_join("pending.cfg")
	DirAccess.remove_absolute(path)
	for request: Array in [[KEY_F2, "server128"], [KEY_F4, "quake3_inspired128"]]:
		await make_game({"spawn": "slot"}, "r13", true, path)
		await tap(request[0])
		check("%s waits in the slot" % request[1], str(game.pending_preset) == request[1] and str(game.preset_id) == "r13_original120" and not str(game.pending_message).is_empty(), [game.pending_preset, game.preset_id])
		await practise_from_menu(2)
		check("%s: menu practice cancels the request" % request[1], str(game.pending_preset).is_empty() and str(game.pending_message).is_empty() and str(game.preset_id) == "r13_original120", [game.pending_preset, game.preset_id])
		check("%s: notice says cancelled and staying" % request[1], str(hud().message.text).contains("request cancelled, staying on R13 Overflow"), hud().message.text)
		# beta deck is open: a source hull fits there, so a kept request would have applied by now.
		check("%s: the source hull would fit at the stage" % request[1], bool(game.call("hull_fits", PRESETS.entry(request[1]), p().global_position)))
		var done := await run_to_finish()
		check("%s: the law never changed during practice" % request[1], str(game.preset_id) == "r13_original120" and (p().get_script() as Script).resource_path.contains("momentum"), [game.preset_id, (p().get_script() as Script).resource_path])
		check("%s: pending-entry practice finishes unrecorded" % request[1], done and str(game.finish_kind) == "practice" and file_hash(path).is_empty(), [game.finish_kind, file_hash(path)])
		# the F key takes the same path: request, then F in the slot.
		await tap(KEY_R)
		await tap(request[0])
		check("%s waits again after R" % request[1], str(game.pending_preset) == request[1])
		await tap(KEY_F)
		check("%s: F cancels it the same way" % request[1], str(game.pending_preset).is_empty() and str(game.preset_id) == "r13_original120")
		await _drop_game()

## negative controls: without practice the same request applies once there is room, and a
## menu without "Practise here" changes nothing.
func _group_control() -> void:
	await make_game({"spawn": "slot"}, "r13")
	await tap(KEY_F2)
	check("control: request waits in the slot", str(game.pending_preset) == "server128")
	key(KEY_W, true)
	await until(func() -> bool: return str(game.preset_id) == "server128", 600)
	key(KEY_W, false)
	check("control: without practice the request applies when room appears", str(game.preset_id) == "server128" and str(game.pending_preset).is_empty(), game.preset_id)
	await _drop_game()
	await make_game()
	var attempts := int(game.attempts)
	var chosen := await pick_stage(2)
	await tap(KEY_ESCAPE)
	check("control: picking without Practise here moves nothing and stays clean", chosen == 2 and at_pose(0) and bool(game.clean_eligible) and int(game.practice_stage) == -1 and int(game.attempts) == attempts and not bool(game.paused),
		[chosen, off_pose(0), game.clean_eligible, game.practice_stage, game.attempts, game.paused])
	check("control: R run from there finishes clean", await run_to_finish() and str(game.finish_kind) == "clean", game.finish_kind)

# --- native tour --------------------------------------------------------------------------------

func _snap(name: String, note: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(out_dir.path_join("frames").path_join(name + ".png"))
	_frames.append({"name": name, "note": note, "map": game.map_id, "preset": game.preset_id, "paused": game.paused, "feet": str(p().global_position),
		"practice_tag": str(hud().practice_tag.text), "message": str(hud().message.text)})

func _tour() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("frames"))
	Engine.physics_ticks_per_second = int(PRESETS.entry("server128").rate)
	game = (load(SCENE) as PackedScene).instantiate()
	game.set("profile_path", ProjectSettings.globalize_path(out_dir).path_join("tour-profile.cfg"))
	root.add_child(game)
	current_scene = game
	await ticks(40)
	await _snap("01-spawn", "default start on Penstock Yard")
	await open_menu()
	await click_visible(picker())
	await ticks(4)
	await _snap("02-picker-open", "pause menu with the stage picker's popup")
	await walk_popup(picker().get_popup(), RUNWAY)
	await ui_key(KEY_ENTER)
	await _snap("03-runway-chosen", "picker on 3 Penstock straight")
	await click_visible(hud().stage_practice_button)
	await ticks(30)
	check("tour: at the runway", at_pose(RUNWAY), off_pose(RUNWAY))
	await _snap("04-runway-practice", "player view at the runway pose, practice label")
	key(KEY_W, true)
	await ticks(200)
	await hop(0, 0.0)
	await hop(-1, -counts_for(0.006))
	await hop(1, counts_for(0.006))
	key(KEY_W, false)
	await _snap("05-runway-running", "after running and three hops along the runway")
	await open_menu()
	await click_visible(hud().preset_buttons["vanilla64"])
	await ticks(4)
	await _snap("06-menu-vanilla", "menu after the F1 click, picker still on the runway")
	await click_visible(hud().stage_practice_button)
	await ticks(30)
	await _snap("07-runway-vanilla", "vanilla at the runway pose")
	await open_menu()
	await click_visible(hud().map_buttons["overflow"])
	await ticks(30)
	await open_menu()
	await click_visible(picker())
	await ticks(4)
	await _snap("08-overflow-picker", "Overflow's stages in the picker")
	await walk_popup(picker().get_popup(), 2)
	await ui_key(KEY_ENTER)
	await click_visible(hud().stage_practice_button)
	await ticks(30)
	check("tour: at Overflow's Chute", at_pose(2, 1.0), off_pose(2))
	await _snap("09-overflow-chute", "player view at Overflow's Chute")
	await tap(KEY_R)
	await ticks(30)
	await _snap("10-overflow-R", "R: clean start at Overflow's spawn")
	check("tour: R is clean at the spawn", bool(game.clean_eligible) and at_pose(0))

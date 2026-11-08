extends SceneTree
## p / short native preset comparison on Penstock Yard's runway (stage 3), for frames, not proof
## of feel. the real launch scene runs with records off. every step is ordinary input: F1-F5 key
## events switch the preset live, Esc opens the menu, the stage picker is clicked and walked with
## arrows/Enter, and the Practise here button is clicked through the viewport. the same strafe
## pattern runs on every preset: a short W run-up, then alternate A/D hops with the mouse turning
## the same way, which is what the A/D sync counts. F1 taps Space for each hop (no autohop), the
## others hold it. F4 then repeats with W held through the hops, the Quake strafe-jump input. nothing writes pose, velocity or the runner's state, and no finish is reached.
## run under a private Xvfb with --write-movie (tests/r14_native_acceptance.py --tour).
## godot --audio-driver Dummy --fixed-fps 30 --path . --write-movie M.avi \
##   --script res://tests/r14_native_acceptance_tour.gd -- --out=DIR

const SCENE := "res://scenes/r14.tscn"
const PRESETS := preload("res://scripts/r14_presets.gd")
const U := 0.0254
const RUNWAY := 3
const HOPS := 6
const TURN_RAD_S := 2.0
const ORDER := ["vanilla64", "server128", "r13_original120", "quake3_inspired128", "server128_aa1000"]

var out_dir := ""
var results: Array[Dictionary] = []
var runs: Array[Dictionary] = []
var _frames: Array[Dictionary] = []
var game: Node
var profile := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	if out_dir.is_empty():
		printerr("usage: --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("frames"))
	_main.call_deferred()

func check(name: String, ok: bool, detail: Variant = "") -> bool:
	results.append({"name": name, "ok": ok, "detail": str(detail)})
	if not ok:
		printerr("  fail: %s (%s)" % [name, detail])
	return ok

# --- input, as in tests/test_r14_stage_practice.gd ----------------------------------------------

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

func mouse(dx: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, 0.0)
	event.screen_relative = Vector2(dx, 0.0)
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

func release_all() -> void:
	for code: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_CTRL]:
		key(code, false)

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

func walk_popup(popup: PopupMenu, index: int) -> void:
	for i: int in popup.item_count * 2 + 2:
		var focus := popup.get_focused_item()
		if focus == index:
			return
		await ui_key(KEY_DOWN if focus < index else KEY_UP)

## press Esc, the runway in the picker (clicked and walked only when it is not already selected),
## then a click on Practise here.
func practise_runway() -> bool:
	if not bool(game.paused):
		await tap(KEY_ESCAPE)
	var picker: OptionButton = hud().stage_picker
	if picker.selected != RUNWAY:
		await click_visible(picker)
		await ticks(2)
		await walk_popup(picker.get_popup(), RUNWAY)
		await ui_key(KEY_ENTER)
	var chosen := picker.selected == RUNWAY
	await click_visible(hud().stage_practice_button)
	await ticks(30)
	return chosen

# --- frames ---------------------------------------------------------------------------------------

func _snap(name: String, note: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var size := Vector2i.ZERO
	if image != null and not image.is_empty():
		size = image.get_size()
		image.save_jpg(out_dir.path_join("frames").path_join(name + ".jpg"), 0.9)
	_frames.append({"name": name, "note": note, "size": [size.x, size.y], "preset": game.preset_id, "paused": game.paused,
		"feet": str(p().global_position), "speed_u": hspeed_u(), "identity": str(hud().identity.text), "practice_tag": str(hud().practice_tag.text),
		"strafe": [str(hud().strafe_live.text), str(hud().strafe_last.text), str(hud().strafe_split.text), str(hud().strafe_chain.text)]})

# --- the strafe pattern ---------------------------------------------------------------------------

## one airborne hop: the side key held and the view turning toward it at TURN_RAD_S until the
## runner lands. `scale` halves the first hop's turn so the zig-zag stays centred on the runway.
func air_strafe(side: int, scale: float, limit: int) -> int:
	var per_tick := counts_for(TURN_RAD_S * scale / float(Engine.physics_ticks_per_second))
	key(KEY_A if side < 0 else KEY_D, true)
	var n := 0
	# leave the ground first, then strafe until the landing step.
	while grounded() and n < 12:
		mouse(per_tick * side)
		await physics_frame
		n += 1
	while not grounded() and n < limit:
		mouse(per_tick * side)
		await physics_frame
		n += 1
	key(KEY_A if side < 0 else KEY_D, false)
	return n

func run_preset(id: String, hold_w: bool = false) -> void:
	var entry := PRESETS.entry(id)
	var slot := int(entry.slot)
	var tag := "F%d%s" % [slot, "w" if hold_w else ""]
	var row := {"preset": id, "slot": slot, "hold_w": hold_w, "hops": []}
	if str(game.preset_id) != id:
		# the live hot key, as a player presses it on the runway.
		await tap(KEY_F1 + slot - 1)
		await ticks(4)
	row["switched_by_key"] = str(game.preset_id) == id
	check("%s runs %s" % [tag, id], row.switched_by_key, game.preset_id)
	row["picker_on_runway"] = await practise_runway()
	check(tag + ": Esc, runway picked, Practise here", row.picker_on_runway and not bool(game.paused) and int(game.practice_stage) == RUNWAY, [game.practice_stage, game.paused])
	row["rate"] = Engine.physics_ticks_per_second
	row["identity"] = str(hud().identity.text)
	check(tag + " identity names the preset and its rate", row.identity.contains("F%d" % slot) and row.identity.contains("%d Hz" % int(entry.rate)), row.identity)
	await _snap(tag + "-a-runway", "%s at the runway pose after Practise here" % tag)
	var start: Vector3 = p().global_position
	var hz := Engine.physics_ticks_per_second
	key(KEY_W, true)
	await ticks(int(hz * 0.6))
	var autohop := id != "vanilla64"
	if autohop:
		key(KEY_SPACE, true)
	for hop: int in HOPS:
		if not autohop:
			# for F1: one press per hop, on the first grounded step.
			while not grounded():
				await physics_frame
			key(KEY_SPACE, true)
		if hop == 0 and not hold_w:
			key(KEY_W, false)
		var before := int(game.stats.hop_count)
		var side := -1 if hop % 2 == 0 else 1
		var n := await air_strafe(side, 0.5 if hop == 0 else 1.0, int(hz * 2))
		if not autohop:
			key(KEY_SPACE, false)
		await physics_frame
		var snap: Dictionary = game.stats.call("snapshot")
		var last: Dictionary = snap.last_hop
		row.hops.append({"hop": hop + 1, "side": "A" if side < 0 else "D", "strafe_ticks": n, "hops_counted": int(game.stats.hop_count) - before,
			"takeoff_u": last.get("takeoff"), "landing_u": last.get("landing"), "gain_u": last.get("gain"), "air_u": last.get("air"),
			"contact_u": last.get("contact"), "sync": last.get("sync"), "good": last.get("good"), "eligible": last.get("eligible"),
			"ground_u": last.get("ground"), "ground_ticks": last.get("ground_ticks")})
		if hop == 2:
			await _snap(tag + "-b-hop3", "%s after the third hop" % tag)
	key(KEY_SPACE, false)
	release_all()
	await ticks(2)
	row["end_speed_u"] = hspeed_u()
	row["forward_m"] = start.distance_to(p().global_position)
	row["respawns"] = int(game.respawn_count)
	row["run_sync"] = game.stats.call("run_sync")
	row["finish_kind"] = str(game.finish_kind)
	await _snap(tag + "-c-end", "%s after %d hops" % [tag, HOPS])
	check(tag + ": no fall, no finish, still practice", row.respawns == 0 and not bool(game.finished) and not bool(game.clean_eligible), [row.respawns, game.finished, game.clean_eligible])
	runs.append(row)

func _main() -> void:
	var started := Time.get_ticks_msec()
	profile = ProjectSettings.globalize_path(out_dir).path_join("never-written.cfg")
	Engine.physics_ticks_per_second = int(PRESETS.entry("server128").rate)
	game = (load(SCENE) as PackedScene).instantiate()
	# records off for this tour; the profile path only proves nothing was written.
	game.set("persist", false)
	game.set("profile_path", profile)
	root.add_child(game)
	current_scene = game
	await ticks(40)
	check("starts on Penstock Yard with the server preset", str(game.map_id) == "practice" and str(game.preset_id) == "server128", [game.map_id, game.preset_id])
	await _snap("00-spawn", "default start")
	# the runway first with the default preset, so the picker holds 3 for the rest.
	check("menu route to the runway", await practise_runway(), hud().stage_picker.selected)
	for id: String in ORDER:
		await run_preset(id)
		if id == "quake3_inspired128":
			await run_preset(id, true)
	check("no record file written", not FileAccess.file_exists(profile), profile)
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	var summary := {"checks": results.size(), "failed": failed.size(), "results": results, "runs": runs, "frames": _frames,
		"turn_rad_s": TURN_RAD_S, "hops": HOPS, "seconds": (Time.get_ticks_msec() - started) / 1000.0,
		"engine": Engine.get_version_info(), "display": DisplayServer.get_name(), "rendering": RenderingServer.get_current_rendering_method(),
		"viewport": [root.get_visible_rect().size.x, root.get_visible_rect().size.y]}
	var file := FileAccess.open(out_dir.path_join("tour.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	file.close()
	print("r14 native acceptance tour: %d checks, %d failed" % [results.size(), failed.size()])
	release_all()
	game.queue_free()
	await ticks(3)
	quit(1 if failed.size() > 0 else 0)

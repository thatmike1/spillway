extends SceneTree
## p / r14 product loop: presets, hot switches, maps, rate, records and the strafe hud. every run
## is played with ordinary key, wheel and relative-mouse events through Input, and pause-menu
## buttons are clicked through the viewport; nothing calls the game's finish or writes the
## runner's pose or velocity. lifecycle and statistics run on the labelled FIXTURE level
## (tests/r14_loop_fixture_level.gd); the default group builds the real Penstock Yard and the
## map group loads Overflow, as smoke checks only. persistence runs in fresh child processes,
## each with its own isolated XDG profile. these checks say nothing about whether a source
## course route is playable or about how anything feels.
## godot --headless --audio-driver Dummy --fixed-fps 120 --path . \
##   --script res://tests/test_r14_loop.gd -- --out=DIR [--only=GROUPS]
## groups: default, hook, switch, hull, rate, wheel, stats, lifecycle, pause, maps, persist.

const MAIN := preload("res://scripts/r14_main.gd")
const SCENE := "res://scenes/r14.tscn"
const FIXTURE := preload("res://tests/r14_loop_fixture_level.gd")
const U := 0.0254
const GROUPS := ["default", "hook", "switch", "hull", "rate", "wheel", "stats", "lifecycle", "pause", "maps", "persist"]

var out_dir := ""
var results: Array[Dictionary] = []
var only: Array = []
var phase := ""
var _group := ""
var game: Node

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
		"engine": Engine.get_version_info(), "fixed_fps": Engine.max_fps}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	file.close()
	for r: Dictionary in failed:
		printerr("FAIL %s / %s: %s" % [r.group, r.name, r.detail])
	print("r14 loop: %d checks, %d failed" % [results.size(), failed.size()])
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

func wheel(up: bool) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = pressed
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

func make_game(params: Dictionary = {}, alias: String = "", fixture: bool = true, from_scene: bool = false) -> Node:
	FIXTURE.params = params
	game = (load(SCENE) as PackedScene).instantiate() if from_scene else MAIN.new()
	if fixture:
		game.set("level_script", FIXTURE)
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

func grounded() -> bool:
	return bool(p().call("is_grounded"))

func hspeed_u() -> float:
	return Vector2(p().velocity.x, p().velocity.z).length() / U

## counts per mouse step that turn the view by `radians` on the active family.
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

## W until the horizontal speed reaches `target` u/s (or the limit), then release W.
func run_up(target: float, limit: int = 400) -> void:
	key(KEY_W, true)
	await until(func() -> bool: return hspeed_u() >= target, limit)
	key(KEY_W, false)

## one hop: tap jump, then hold `side` (-1 A, 1 D, 0 none) and turn `dx` counts per tick until landing.
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

# --- groups -----------------------------------------------------------------------------------

func _group_default() -> void:
	await make_game({}, "", false)
	check("default map is Penstock Yard", str(game.map_id) == "practice" and str(game.call("map_name")) == "Penstock Yard", game.map_id)
	check("default preset is the bhop server", str(game.preset_id) == "server128", game.preset_id)
	check("engine and game run 128 Hz", Engine.physics_ticks_per_second == 128 and int(game.physics_hz) == 128, [Engine.physics_ticks_per_second, game.physics_hz])
	check("runner is the source player", (p().get_script() as Script).resource_path == "res://scripts/r14_source_player.gd")
	var cvars: Dictionary = p().get("settings")
	check("server cvars: AA100, autohop, bhop on, no stamina", float(cvars.sv_airaccelerate) == 100.0 and bool(cvars.sv_autobunnyhopping) and bool(cvars.sv_enablebunnyhopping) and float(cvars.sv_staminamax) == 0.0, cvars)
	check("source sensitivity starts at 2.5 source units", is_equal_approx(float(cvars.sensitivity), 2.5) and is_equal_approx(float(cvars.m_yaw), 0.022), cvars.sensitivity)
	check("source wheel jump is on", bool(cvars.wheel_jump))
	check("tape radians/count = 2.5 × 0.022 degrees", is_equal_approx(float(p().get("tape_radians_per_count")), deg_to_rad(2.5 * 0.022)), p().get("tape_radians_per_count"))
	check("runner declares step count, pitch limit and fixed hull", "tape_step_count" in p() and is_equal_approx(float(p().get("pitch_limit")), deg_to_rad(89.0)) and str(p().get("tape_body_yaw_policy")) == "axis_aligned")
	check("new() builds a game with records off", not bool(game.persist) and str(game.profile_state) == "off", game.profile_state)
	check("profile path is the r14 file", str(game.profile_path) == "user://spillway_r14.cfg")
	var ident := str(game.hud.call("identity_text"))
	check("hud names map, preset and rate", ident.contains("PENSTOCK YARD") and ident.contains("CS:GO bhop server") and ident.contains("128 Hz"), ident)
	check("window title names map, preset and rate", str(root.get_window().title).contains("Penstock Yard") and str(root.get_window().title).contains("CS:GO bhop server") and str(root.get_window().title).contains("128 Hz"), root.get_window().title)
	var start: Vector3 = p().global_position
	var steps := int(p().get("tape_step_count"))
	key(KEY_W, true)
	await ticks(128)
	key(KEY_W, false)
	var travelled := p().global_position.distance_to(start)
	check("W moves the runner on Penstock Yard", travelled > 3.0, travelled)
	check("one motor step per physics tick", int(p().get("tape_step_count")) - steps == 128, int(p().get("tape_step_count")) - steps)
	check("ground run reaches about 250 u/s", absf(hspeed_u() - 250.0) < 2.0, hspeed_u())
	check("hud speed shows u/s", str(game.hud.speed_label.text).to_int() > 200 and str(game.hud.speed_unit.text) == "u/s", game.hud.speed_label.text)
	check("hud shows m/s as the secondary value", str(game.hud.speed_metric.text).ends_with("m/s"), game.hud.speed_metric.text)
	await tap(KEY_F3)
	check("F3 runs the unchanged r13 candidate", str(p().get("air_policy")) == "carry-air-candidate" and (p().get_script() as Script).resource_path == "res://scripts/momentum_carry_air_candidate.gd", p().get("air_policy"))
	check("r13 keeps its original 0.0022 rad/count and 90 degree horizontal fov", is_equal_approx(float(p().get("mouse_sensitivity")), 0.0022) and is_equal_approx(float(p().get("fov_horizontal")), 90.0) and bool(p().get("autohop")) and not bool(p().get("comfort")))
	check("r13 runs 120 Hz", Engine.physics_ticks_per_second == 120 and int(game.physics_hz) == 120)
	check("title follows the switch", str(root.get_window().title).contains("R13") and str(root.get_window().title).contains("120 Hz"), root.get_window().title)
	check("look line keeps the families' units apart", str(game.call("look_description")).begins_with("R13 mouse") and str(game.call("look_description")).contains("rad/count"), game.call("look_description"))

func _group_hook() -> void:
	game = MAIN.new()
	game.set("level_script", FIXTURE)
	game.set("source_sensitivity_override", 5.7295779513)
	root.add_child(game)
	await ticks(4)
	check("a replay's source sensitivity applies for the run", is_equal_approx(float((p().get("settings") as Dictionary).sensitivity), 5.7295779513) and is_equal_approx(float(p().get("tape_radians_per_count")), 0.0022), p().get("tape_radians_per_count"))
	await _drop_game()
	for alias: Array in [["csgo_vanilla", "vanilla64", 64], ["r13", "r13_original120", 120], ["server128_aa1000", "server128_aa1000", 128]]:
		await make_game({}, alias[0])
		check("motor %s selects %s" % [alias[0], alias[1]], str(game.preset_id) == alias[1], game.preset_id)
		check("motor %s declares and runs %d Hz" % [alias[0], alias[2]], int(game.physics_hz) == alias[2] and Engine.physics_ticks_per_second == alias[2], [game.physics_hz, Engine.physics_ticks_per_second])
		if alias[1] == "server128_aa1000":
			check("aa1000 changes only air acceleration from the server", float((p().get("settings") as Dictionary).sv_airaccelerate) == 1000.0 and bool((p().get("settings") as Dictionary).sv_autobunnyhopping))
			check("aa1000 is labelled a P server config", str(game.preset.label).begins_with("P server config"), game.preset.label)
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
	# server -> vanilla: same body, new cvars and rate.
	var before := pose()
	key(KEY_F1, true)
	var after := pose()
	key(KEY_F1, false)
	check("F1 keeps feet exactly", before.feet == after.feet, [before.feet, after.feet])
	check("F1 keeps velocity exactly", before.velocity == after.velocity, [before.velocity, after.velocity])
	check("F1 keeps yaw and pitch exactly", before.yaw == after.yaw and before.pitch == after.pitch, [before.yaw, after.yaw, before.pitch, after.pitch])
	check("F1 keeps the same source body", before.node == after.node)
	check("F1 applies vanilla cvars", str(game.preset_id) == "vanilla64" and float((p().get("settings") as Dictionary).sv_airaccelerate) == 12.0 and not bool((p().get("settings") as Dictionary).sv_autobunnyhopping))
	check("F1 sets 64 Hz", Engine.physics_ticks_per_second == 64 and int(game.physics_hz) == 64)
	check("vanilla identity carries its qualifier", str(game.hud.call("identity_text")).contains("CS:GO vanilla") and str(game.hud.call("identity_text")).contains("vanilla cvars · stamina reconstructed"), game.hud.call("identity_text"))
	check("a started attempt becomes practice", not bool(game.clean_eligible) and str(game.practice_reason) == "preset", game.practice_reason)
	var deltas: Array = []
	for i: int in 16:
		await physics_frame
		deltas.append(float(game.last_delta))
	check("hud says practice and why", str(game.hud.practice_tag.text).contains("PRACTICE") and str(game.hud.practice_tag.text).contains("preset"), game.hud.practice_tag.text)
	check("after F1 every callback settles to 1/64", is_equal_approx(float(deltas[-1]), 1.0 / 64.0), deltas)
	check("source motor reports the 64 Hz delta", is_equal_approx(float((p().call("get_motion_state") as Dictionary).delta), 1.0 / 64.0) and bool((p().call("get_motion_state") as Dictionary).rate_matches))
	# vanilla -> r13: a new body in the same place.
	await until(func() -> bool: return not grounded(), 10)
	before = pose()
	key(KEY_F3, true)
	after = pose()
	key(KEY_F3, false)
	check("F3 replaces the runner", before.node != after.node and after.script == "res://scripts/momentum_carry_air_candidate.gd", after.script)
	check("F3 keeps feet, velocity and view exactly", before.feet == after.feet and before.velocity == after.velocity and before.yaw == after.yaw and before.pitch == after.pitch, [before, after])
	check("F3 sets 120 Hz", Engine.physics_ticks_per_second == 120 and int(game.physics_hz) == 120)
	var at := p().global_position
	var v: Vector3 = p().velocity
	await physics_frame
	await physics_frame
	var moved := p().global_position - at
	check("motion continues along the kept velocity", Vector2(moved.x, moved.z).normalized().dot(Vector2(v.x, v.z).normalized()) > 0.95 and Vector2(moved.x, moved.z).length() > 0.05, [moved, v])
	check("only one runner and one current camera", game.find_children("Runner", "", false, false).size() == 1 and root.get_viewport().get_camera_3d() == p().get("camera"))
	# r13 -> server: back to a source body.
	await ticks(6)
	before = pose()
	key(KEY_F2, true)
	after = pose()
	key(KEY_F2, false)
	var cleared: bool = game.pending_preset == ""
	check("F2 from r13 applies at once in open space", cleared and str(game.preset_id) == "server128", game.pending_message)
	check("F2 keeps feet, velocity and view exactly", before.feet == after.feet and before.velocity == after.velocity and before.yaw == after.yaw and before.pitch == after.pitch, [before, after])
	check("F2 sets 128 Hz", Engine.physics_ticks_per_second == 128)
	check("stats were reset by the switch", int(game.stats.hop_count) == 0 and (game.stats.last_hop as Dictionary).is_empty())
	await ticks(20)
	check("mismatched callbacks after switches are logged, not hidden", game.rate_log is Array, game.rate_log)
	await tap(KEY_R)
	check("R starts a clean attempt in the same preset", bool(game.clean_eligible) and str(game.practice_reason) == "" and str(game.preset_id) == "server128" and float(game.elapsed) == 0.0)
	check("R returns to the spawn", p().global_position.distance_to((game.level.spawn as Transform3D).origin) < 0.1, p().global_position)
	await _drop_game()
	# a switch before the first move keeps the attempt clean.
	await make_game()
	mouse(200, 0)
	await tap(KEY_F1)
	check("switch at the untouched spawn stays clean", bool(game.clean_eligible) and str(game.preset_id) == "vanilla64")
	await tap(KEY_F4)
	check("F4 selects the Quake III-inspired projection on the same body, still clean", str(game.preset_id) == "quake3_inspired128" and float((p().get("settings") as Dictionary).sv_air_max_wishspeed) == 320.0 and Engine.physics_ticks_per_second == 128 and bool(game.clean_eligible), [game.preset_id, game.hud.message.text])
	await tap(KEY_F5)
	check("F5 selects the AA 1000 config", str(game.preset_id) == "server128_aa1000" and float((p().get("settings") as Dictionary).sv_airaccelerate) == 1000.0)
	var ident := str(game.hud.call("identity_text"))
	check("hud names the F5 config, its rate and AA", ident.contains("P server config AA 1000") and ident.contains("128 Hz") and ident.contains("AA 1000"), ident)

func _group_hull() -> void:
	await make_game({"spawn": "slot"}, "r13")
	check("r13 starts inside the 0.7 m slot", str(game.preset_id) == "r13_original120" and absf(p().global_position.x - 9.0) < 0.05)
	var at := p().global_position
	key(KEY_F2, true)
	key(KEY_F2, false)
	await physics_frame
	check("F2 waits: the source box does not fit", str(game.preset_id) == "r13_original120" and str(game.pending_preset) == "server128", game.pending_preset)
	check("the wait is explained on screen", str(game.pending_message).contains("waits for room") and str(game.pending_message).contains("0.81 m"), game.pending_message)
	check("waiting moves nothing", p().global_position.distance_to(at) < 0.01, p().global_position)
	await ticks(30)
	check("still waiting while in the slot", str(game.preset_id) == "r13_original120")
	key(KEY_F3, true)
	key(KEY_F3, false)
	check("pressing the active preset cancels the wait", str(game.pending_preset) == "", game.pending_preset)
	await tap(KEY_F1)
	check("F1 waits too", str(game.pending_preset) == "vanilla64")
	key(KEY_W, true)
	# lambdas capture locals by value: the switch position goes into a shared dictionary.
	var seen := {"at": Vector3.ZERO}
	var taken := await until(func() -> bool:
		if str(game.preset_id) == "vanilla64":
			seen.at = p().global_position
			return true
		return false, 400)
	key(KEY_W, false)
	var switched_at: Vector3 = seen.at
	check("the switch happens once the runner walks out", taken >= 0, game.pending_message)
	check("it happened clear of the slot", switched_at.z < -4.0 - 0.40 or absf(switched_at.x - 9.0) > 0.75, switched_at)
	check("the runner was not moved by the switch", absf(switched_at.x - 9.0) < 0.2, switched_at)
	await _drop_game()
	# R with a waiting switch applies it at the spawn of a map where it fits.
	await make_game({"spawn": "slot"}, "r13")
	await tap(KEY_F2)
	check("pending before R", str(game.pending_preset) == "server128")
	await tap(KEY_R)
	check("R cannot apply it at a spawn where it does not fit either", str(game.preset_id) == "r13_original120" and str(game.pending_preset) == "server128")

func _group_rate() -> void:
	# startup: record every callback delta before any input.
	await make_game({}, "csgo_vanilla")
	var log: Array = game.rate_log.duplicate()
	check("startup mismatches happened before the attempt started", log.all(func(e: Dictionary) -> bool: return not bool(e.started)), log)
	check("startup settles at 1/64", is_equal_approx(float(game.last_delta), 1.0 / 64.0), game.last_delta)
	var file := FileAccess.open(out_dir.path_join("rate-startup.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"log": log, "calls": game.physics_calls}, "  "))
	file.close()
	# a live switch while moving: every mismatched callback after it must make the attempt practice.
	await tap(KEY_R)
	key(KEY_W, true)
	await ticks(40)
	var mismatches_before := int(game.rate_mismatch_ticks)
	var observed: Array = []
	await tap(KEY_F2)
	for i: int in 30:
		await physics_frame
		observed.append(float(game.last_delta))
	key(KEY_W, false)
	var stale := int(game.rate_mismatch_ticks) - mismatches_before
	check("a started attempt switched is practice either way", not bool(game.clean_eligible))
	check("callback deltas after the live switch end at 1/128", is_equal_approx(float(observed[-1]), 1.0 / 128.0), observed)
	file = FileAccess.open(out_dir.path_join("rate-switch.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"stale_callbacks": stale, "deltas": observed, "log": game.rate_log}, "  "))
	file.close()
	# R right after a switch: if a stale callback lands after the move starts, the attempt is practice.
	await tap(KEY_F1)
	await tap(KEY_R)
	var calls_at_r := int(game.physics_calls)
	key(KEY_W, true)
	await ticks(30)
	key(KEY_W, false)
	var late: Array = (game.rate_log as Array).filter(func(e: Dictionary) -> bool: return int(e.call) > calls_at_r and bool(e.started))
	check("clean only when no stale callback reached the started attempt", bool(game.clean_eligible) == late.is_empty(), [game.clean_eligible, late])

func _group_wheel() -> void:
	await make_game({}, "csgo_vanilla")
	await ticks(10)
	var jumps := int(p().get("jump_count"))
	wheel(true)
	await ticks(2)
	check("vanilla: one wheel-up notch jumps once", int(p().get("jump_count")) == jumps + 1, p().get("jump_count"))
	await until(grounded, 200)
	await ticks(4)
	jumps = int(p().get("jump_count"))
	wheel(false)
	await ticks(2)
	check("vanilla: one wheel-down notch jumps once", int(p().get("jump_count")) == jumps + 1)
	await until(grounded, 200)
	await ticks(4)
	jumps = int(p().get("jump_count"))
	key(KEY_SPACE, true)
	await ticks(200)
	key(KEY_SPACE, false)
	check("vanilla: held space jumps once, no hidden autohop", int(p().get("jump_count")) == jumps + 1, int(p().get("jump_count")) - jumps)
	await tap(KEY_F2)
	await until(grounded, 200)
	jumps = int(p().get("jump_count"))
	key(KEY_SPACE, true)
	await ticks(200)
	key(KEY_SPACE, false)
	check("server: held space keeps hopping", int(p().get("jump_count")) >= jumps + 2, int(p().get("jump_count")) - jumps)

func _group_stats() -> void:
	await make_game()
	var hud: Node = game.hud
	check("no hop yet shows an em dash", str(hud.strafe_last.text).contains("—"), hud.strafe_last.text)
	# coasting: no keys, the mouse turning. nothing is eligible.
	await run_up(240.0)
	await hop(0, counts_for(-0.01))
	var coast: Dictionary = game.stats.last_hop
	check("coast hop: no eligible ticks, sync null", int(coast.get("eligible", -1)) == 0 and coast.get("sync") == null, coast)
	await ticks(2)
	check("coast hop shows an em dash, not 0 %", str(hud.strafe_last.text).contains("sync —") and not str(hud.strafe_last.text).contains("0 %"), hud.strafe_last.text)
	check("coast hop keeps its speed (no air law without keys)", absf(float(coast.air)) < 0.01, coast)
	# keys without the mouse: still nothing eligible.
	await tap(KEY_R)
	await run_up(240.0)
	await hop(-1, 0.0)
	var keys_only: Dictionary = game.stats.last_hop
	check("A without turning: no eligible ticks", int(keys_only.eligible) == 0 and keys_only.sync == null, keys_only)
	# synced: A with a left turn.
	await tap(KEY_R)
	await run_up(240.0)
	await hop(-1, counts_for(0.012) * -1.0)
	var synced: Dictionary = game.stats.last_hop
	var motor: Dictionary = p().get("last_hop")
	check("synced A + left turn: sync near 100 %", synced.sync != null and float(synced.sync) > 0.95 and int(synced.eligible) > 50, synced)
	check("synced hop gains in the air", float(synced.gain) > 5.0 and float(synced.air) > 5.0, synced)
	check("no contact loss on open flat ground", absf(float(synced.contact)) < 0.01, synced.contact)
	check("observer matches the motor's eligible ticks", int(synced.eligible) == int(motor.eligible), [synced.eligible, motor.eligible])
	check("observer matches the motor's sync", is_equal_approx(float(synced.sync), float(motor.sync)), [synced.sync, motor.sync])
	check("observer air ticks match the motor's", int(synced.air_ticks) == int(motor.air_ticks), [synced.air_ticks, motor.air_ticks])
	check("takeoff and landing are the motor's endpoints", is_equal_approx(float(synced.takeoff), float(motor.takeoff)) and is_equal_approx(float(synced.landing), float(motor.landing)), [synced, motor])
	await ticks(2)
	check("hud shows the sync percentage and counts", str(hud.strafe_last.text).contains("%d %% (%d/%d)" % [roundi(float(synced.sync) * 100.0), int(synced.good), int(synced.eligible)]), hud.strafe_last.text)
	# opposite: A with a right turn.
	await tap(KEY_R)
	await run_up(240.0)
	await hop(-1, counts_for(0.012))
	var opposite: Dictionary = game.stats.last_hop
	check("A + right turn: sync near 0 %", opposite.sync != null and float(opposite.sync) < 0.05 and int(opposite.eligible) > 50, opposite)
	await ticks(2)
	check("hud shows 0 % with its counts, not a dash", str(hud.strafe_last.text).contains("0 % (0/"), hud.strafe_last.text)
	# a wall: synced strafing into the left wall loses speed to contact, not to sync.
	await tap(KEY_R)
	mouse(counts_for(PI * 0.5) * -1.0)
	await ticks(1)
	key(KEY_W, true)
	await ticks(45)
	key(KEY_W, false)
	await hop(-1, counts_for(0.004) * -1.0)
	var wall: Dictionary = game.stats.last_hop
	check("wall hop: contact loss is booked", float(wall.contact) < -20.0 and int(wall.wall_ticks) > 0, wall)
	check("wall hop: sync stays high", wall.sync != null and float(wall.sync) > 0.9, wall)
	await ticks(2)
	check("hud names the wall ticks and the contact loss apart from sync", str(hud.strafe_split.text).contains("wall ") and str(hud.strafe_split.text).contains("contact -") and str(hud.strafe_last.text).contains("sync 1"), [hud.strafe_last.text, hud.strafe_split.text])
	var panel_right: float = (hud.get("_strafe_shade") as Control).get_global_rect().end.x
	check("strafe panel stays clear of the speed readout", panel_right < (hud.speed_label as Control).get_global_rect().position.x, [panel_right, (hud.speed_label as Control).get_global_rect()])
	# vanilla, a late jump: friction shows as ground loss between hops, not in the hop's sync.
	await tap(KEY_F1)
	await tap(KEY_R)
	await run_up(240.0)
	await hop(-1, counts_for(0.02) * -1.0)
	await ticks(12)
	await tap(KEY_SPACE)
	await ticks(3)
	var late: Dictionary = game.stats.last_hop
	check("late jump: the waiting is ground ticks", int(late.get("ground_ticks", 0)) >= 12, late)
	check("late jump: friction is ground loss", float(late.get("ground", 0.0)) < -5.0, late)
	check("late jump: the hop's own sync is unchanged", late.sync != null and float(late.sync) > 0.9, late)
	await ticks(2)
	check("hud shows the ground loss and ticks", str(hud.strafe_chain.text).contains("ground -") and str(hud.strafe_chain.text).contains("ticks"), hud.strafe_chain.text)
	# r13: the same definitions through the observer.
	await until(grounded, 200)
	await tap(KEY_F3)
	await tap(KEY_R)
	check("r13 stats come from the observer", str(game.stats.takeoff_source) == "observer")
	await run_up(300.0, 200)
	await hop(-1, counts_for(0.012) * -1.0)
	var r13_synced: Dictionary = game.stats.last_hop
	check("r13 synced A + left turn: sync near 100 %", r13_synced.sync != null and float(r13_synced.sync) > 0.95 and int(r13_synced.eligible) > 20, r13_synced)
	await tap(KEY_R)
	await run_up(300.0, 200)
	await hop(-1, counts_for(0.012))
	var r13_opposite: Dictionary = game.stats.last_hop
	check("r13 opposite turn: sync near 0 %", r13_opposite.sync != null and float(r13_opposite.sync) < 0.05, r13_opposite)
	# resets.
	var resets := int(game.stats.resets)
	await tap(KEY_R)
	check("restart resets the stats", int(game.stats.resets) > resets and (game.stats.last_hop as Dictionary).is_empty() and int(game.stats.hop_count) == 0)
	await run_up(300.0, 200)
	await hop(0, 0.0)
	resets = int(game.stats.resets)
	await tap(KEY_F2)
	check("a preset switch resets the stats", int(game.stats.resets) > resets and (game.stats.last_hop as Dictionary).is_empty())

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
	check("stages collected in order by standing on decks", order == [0, 1, 2], order)
	check("clean finish by running", bool(game.finished) and str(game.finish_kind) == "clean", game.finish_kind)
	check("every split measured", (game.stage_times as Array).all(func(t: float) -> bool: return t > 0.0), game.stage_times)
	check("first clean finish sets the best", is_equal_approx(float(game.best_time), float(game.elapsed)))
	check("finish card names map, preset and rate", str(game.hud.finish_body.text).contains("Loop fixture · CS:GO bhop server · 128 Hz"), game.hud.finish_body.text)
	check("level told to start its finish", int(game.level.wheel_starts) == 1)
	check("nothing saved from a records-off game", not bool(game.last_save_ok))
	var best := float(game.best_time)
	await tap(KEY_R)
	key(KEY_W, true)
	await ticks(200)
	await tap(KEY_F1)
	key(KEY_W, true)
	await until(func() -> bool: return bool(game.finished), 3000)
	key(KEY_W, false)
	check("a switched attempt finishes as practice", str(game.finish_kind) == "practice" and str(game.hud.finish_body.text).contains("Not recorded"), game.finish_kind)
	check("vanilla has no best of its own yet", float(game.best_time) < 0.0, game.best_time)
	await tap(KEY_F2)
	check("switching back restores the server best only", is_equal_approx(float(game.best_time), best), [game.best_time, best])
	# practice from a stage.
	await tap(KEY_R)
	key(KEY_W, true)
	await until(func() -> bool: return int(game.checkpoint_index) >= 1, 2000)
	key(KEY_W, false)
	await tap(KEY_F)
	check("F practises from the reached stage", not bool(game.clean_eligible) and str(game.practice_reason) == "practice" and p().global_position.distance_to(((game.level.checkpoints[1] as Dictionary).pose as Transform3D).origin) < 0.1)
	# a fall: back to the stage, as practice.
	await tap(KEY_R)
	mouse(counts_for(PI * 0.5))
	await ticks(1)
	key(KEY_W, true)
	await until(func() -> bool: return int(game.respawn_count) > 0, 1500)
	key(KEY_W, false)
	check("walking into the bay hole respawns as practice", int(game.respawn_count) == 1 and str(game.practice_reason) == "respawn", [game.respawn_count, game.practice_reason])

func _group_pause() -> void:
	await make_game()
	await tap(KEY_ESCAPE)
	check("Esc pauses", bool(game.paused) and game.hud.pause_panel.visible and not bool(p().get("input_enabled")))
	var texts := hud_texts()
	check("pause lists every preset with rate and air acceleration", ["F1  CS:GO vanilla", "F2  CS:GO bhop server", "F3  R13 Overflow (unchanged)", "F4  Quake III-inspired", "F5  P server config AA 1000"].all(func(t: String) -> bool: return t in texts), texts)
	check("pause details name AA, rate and jump policy", texts.any(func(t: String) -> bool: return t.contains("vanilla cvars · AA 12 · 64 Hz · manual jump") and t.contains("reconstructed")) and texts.any(func(t: String) -> bool: return t.contains("autohop")), texts)
	check("pause shows the build and record key", texts.any(func(t: String) -> bool: return t.contains(str(game.BUILD_ID)) and t.contains("record key")))
	check("F4 button is enabled", not bool((game.hud.preset_buttons["quake3_inspired128"] as Button).disabled))
	check("source look line uses source units", str(game.hud.pause_look.text).begins_with("Source sensitivity 2.50 × m_yaw 0.022"), game.hud.pause_look.text)
	var feet: Vector3 = p().global_position
	await click(game.hud.preset_buttons["vanilla64"])
	check("clicking a preset switches it", str(game.preset_id) == "vanilla64" and Engine.physics_ticks_per_second == 64)
	check("switching in the menu keeps the menu open and the runner still", bool(game.paused) and p().global_position == feet and not bool(p().get("input_enabled")))
	await click(game.hud.preset_buttons["r13_original120"])
	check("clicking R13 replaces the runner paused", str(game.preset_id) == "r13_original120" and not bool(p().get("input_enabled")))
	check("r13 look line uses r13 units", str(game.hud.pause_look.text).begins_with("R13 mouse 1.00 × 0.0022"), game.hud.pause_look.text)
	var elapsed := float(game.elapsed)
	await ticks(30)
	check("the clock stops while paused", float(game.elapsed) == elapsed)
	await click(game.hud.resume_button)
	check("resume unpauses", not bool(game.paused) and bool(p().get("input_enabled")))
	await tap(KEY_ESCAPE)
	await click(game.hud.map_buttons["practice"])
	check("map button loads Penstock Yard at its spawn", str(game.map_id) == "practice" and p().global_position.distance_to((game.level.spawn as Transform3D).origin) < 0.1 and not bool(game.paused))
	check("map switch keeps the preset", str(game.preset_id) == "r13_original120")
	check("map switch title", str(root.get_window().title).contains("Penstock Yard") and str(root.get_window().title).contains("R13"), root.get_window().title)
	await tap(KEY_ESCAPE)
	check("quit button is offered", game.hud.quit_button.is_visible_in_tree() and str(game.hud.quit_button.text) == "Quit")
	await tap(KEY_ESCAPE)

func _group_maps() -> void:
	await make_game({}, "", false)
	var practice_key := str(game.course_key)
	await tap(KEY_ESCAPE)
	await click(game.hud.map_buttons["overflow"])
	check("overflow loads from the selector", str(game.map_id) == "overflow" and str(game.level.get("variant")) == "course")
	check("overflow starts at its spawn", p().global_position.distance_to((game.level.spawn as Transform3D).origin) < 0.1)
	check("overflow key differs from penstock's", str(game.course_key) != practice_key)
	check("hud names overflow", str(game.hud.call("identity_text")).begins_with("OVERFLOW"), game.hud.call("identity_text"))
	for slot: Key in [KEY_F1, KEY_F3, KEY_F2]:
		await tap(slot)
		var start := p().global_position
		key(KEY_W, true)
		await ticks(90)
		key(KEY_W, false)
		check("overflow is playable with %s" % game.preset_id, p().global_position.distance_to(start) > 2.0 and int(game.respawn_count) == 0, p().global_position)
		await tap(KEY_R)
	await _drop_game()
	await make_game()
	var fixture_key := str(game.course_key)
	await tap(KEY_ESCAPE)
	await click(game.hud.map_buttons["practice"])
	check("a fixture override is its own record key", str(game.course_key) != fixture_key and str(game.map_id) == "practice")

# --- persistence across processes -------------------------------------------------------------

func _group_persist() -> void:
	var godot := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://")
	var base := out_dir.path_join("profiles")
	var user := _user_dir(base)
	DirAccess.make_dir_recursive_absolute(user)
	var foreign := {"spillway_r12.cfg": "[settings]\n\nsensitivity=1.7\n\n[records_r12]\n\nclean_best=12.34\n", "spillway_r13.cfg": "[settings]\n\nsensitivity=1.3\n\n[course_abc]\n\nclean_best=9.5\n"}
	var hashes := {}
	for name: String in foreign:
		var file := FileAccess.open(user.path_join(name), FileAccess.WRITE)
		file.store_string(foreign[name])
		file.close()
		hashes[name] = FileAccess.get_sha256(user.path_join(name))
	var reports := {}
	for step: Array in [["first", []], ["reload", []], ["again", []], ["norecords", ["--no-records"]]]:
		var args := PackedStringArray(["XDG_DATA_HOME=" + base.path_join("data"), "XDG_CONFIG_HOME=" + base.path_join("config"), "XDG_CACHE_HOME=" + base.path_join("cache"),
			godot, "--headless", "--audio-driver", "Dummy", "--fixed-fps", "120", "--path", project, "--script", "res://tests/test_r14_loop.gd", "--",
			"--phase=" + step[0], "--out=" + out_dir.path_join("phase-" + step[0]), "--r14-profile=user://spillway_r14.cfg"])
		args.append_array(step[1])
		var output: Array = []
		var before := FileAccess.get_sha256(user.path_join("spillway_r14.cfg")) if FileAccess.file_exists(user.path_join("spillway_r14.cfg")) else ""
		var code := OS.execute("env", args, output, true)
		var log := FileAccess.open(out_dir.path_join("phase-%s.log" % step[0]), FileAccess.WRITE)
		log.store_string("\n".join(output))
		log.close()
		var path := out_dir.path_join("phase-" + step[0]).path_join("report.json")
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
		report["profile_before"] = before
		report["profile_after"] = FileAccess.get_sha256(user.path_join("spillway_r14.cfg")) if FileAccess.file_exists(user.path_join("spillway_r14.cfg")) else ""
		reports[step[0]] = report
		check("phase %s exits 0" % step[0], code == 0, "exit %d" % code)
		check("phase %s used the isolated profile" % step[0], str(report.get("user_dir", "")).simplify_path() == user.simplify_path(), report.get("user_dir", ""))
	var first: Dictionary = reports.get("first", {})
	var reload: Dictionary = reports.get("reload", {})
	var again: Dictionary = reports.get("again", {})
	check("first: a clean server finish was saved", float(first.get("server_best", -1)) > 0.0 and bool(first.get("saved", false)), first)
	check("reload: a fresh process loads the server best", is_equal_approx(float(reload.get("loaded_server_best", -2)), float(first.get("server_best", -1))), [reload.get("loaded_server_best"), first.get("server_best")])
	check("reload: the changed source sensitivity came back", is_equal_approx(float(reload.get("loaded_source_sensitivity", 0)), 3.0), reload.get("loaded_source_sensitivity"))
	check("reload: a source sensitivity change kept the record key", str(reload.get("server_key")) == str(first.get("server_key")), [reload.get("server_key"), first.get("server_key")])
	check("reload: vanilla starts without the server's best", float(reload.get("vanilla_best_on_switch", 0)) < 0.0, reload.get("vanilla_best_on_switch"))
	check("again: vanilla's own best reloads", is_equal_approx(float(again.get("loaded_vanilla_best", -2)), float(reload.get("vanilla_best", -1))) and float(reload.get("vanilla_best", -1)) > 0.0, [again.get("loaded_vanilla_best"), reload.get("vanilla_best")])
	check("again: server and vanilla keys differ", str(again.get("vanilla_key")) != str(again.get("server_key")))
	var norecords: Dictionary = reports.get("norecords", {})
	check("--no-records writes nothing", str(norecords.get("profile_before")) == str(norecords.get("profile_after")) and str(norecords.get("profile_state")) == "off", norecords)
	var profile := ConfigFile.new()
	profile.load(user.path_join("spillway_r14.cfg"))
	var sections := profile.get_sections()
	var courses := Array(sections).filter(func(s: String) -> bool: return s.begins_with("course_"))
	check("profile holds one section per preset key", courses.size() == 2 and courses.all(func(s: String) -> bool: return str(profile.get_value(s, "preset", "")) in ["server128", "vanilla64"]), sections)
	check("sections record rate, family version and physics", courses.all(func(s: String) -> bool: return int(profile.get_value(s, "physics_hz", 0)) in [64, 128] and str(profile.get_value(s, "family_version", "")).begins_with("r14-source") and str(profile.get_value(s, "physics", "")).contains("sv_airaccelerate")), sections)
	check("profile has no r12 or r13 namespace", not profile.has_section("records_r12") and not profile.has_section("course_abc"), sections)
	for name: String in foreign:
		check("%s byte-for-byte unchanged" % name, FileAccess.get_sha256(user.path_join(name)) == hashes[name])

func _user_dir(xdg: String) -> String:
	return xdg.path_join("data/godot/app_userdata").path_join(str(ProjectSettings.get_setting("application/config/name")))

func _child_phase() -> void:
	var report := {"phase": phase, "user_dir": ProjectSettings.globalize_path("user://")}
	await make_game({}, "", true, true)
	report["profile_state"] = game.profile_state
	report["server_key"] = game.course_key
	report["loaded_server_best"] = game.best_time
	report["loaded_source_sensitivity"] = game.settings.source_sensitivity
	match phase:
		"first":
			game.call("change_setting", "source_sensitivity", 3.0)
			key(KEY_W, true)
			await until(func() -> bool: return bool(game.finished), 3000)
			key(KEY_W, false)
			report["server_best"] = game.best_time
			report["saved"] = game.last_save_ok
		"reload":
			await tap(KEY_F1)
			report["vanilla_best_on_switch"] = game.best_time
			await tap(KEY_R)
			key(KEY_W, true)
			await until(func() -> bool: return bool(game.finished), 3000)
			key(KEY_W, false)
			report["vanilla_best"] = game.best_time
			report["vanilla_finish"] = game.finish_kind
		"again":
			await tap(KEY_F1)
			report["loaded_vanilla_best"] = game.best_time
			report["vanilla_key"] = game.course_key
		"norecords":
			key(KEY_W, true)
			await until(func() -> bool: return bool(game.finished), 3000)
			key(KEY_W, false)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	await _drop_game()
	quit(0)

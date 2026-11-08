extends SceneTree
## p / r14 F4 checks: the quake iii-inspired projection preset (docs/r14/QUAKE.md). the vectors
## group feeds an independent closed-form prediction file (an outside json, never generated from
## this game) through the shared source tick with F4's own settings, plus self-contained
## closed-form peaks against F2. the other groups play the actual r14 main with ordinary key,
## wheel and relative-mouse events through Input, on the labelled loop FIXTURE level or, as
## smoke only, the real maps; nothing writes the runner's pose or velocity or calls the finish.
## none of this says anything about quake fidelity or how F4 feels.
## godot --headless --audio-driver Dummy --fixed-fps 128 --path . \
##   --script res://tests/test_r14_quake.gd -- --out=DIR [--oracle=ORACLE.json] [--only=GROUPS]
## groups: vectors, preset, ballistics, switch, strafe, records, pause, maps.

const MAIN := preload("res://scripts/r14_main.gd")
const PRESETS := preload("res://scripts/r14_presets.gd")
const MOTION := preload("res://scripts/r14_source_motion.gd")
const FIXTURE := preload("res://tests/r14_loop_fixture_level.gd")
const U := 0.0254
const F4 := "quake3_inspired128"
const GROUPS := ["vectors", "preset", "ballistics", "switch", "strafe", "records", "pause", "maps"]
## the values the comparison was specified with: q3's declared constants plus the labelled choices.
const EXPECTED := {"sv_accelerate": 10.0, "sv_airaccelerate": 1.0, "sv_friction": 6.0, "sv_stopspeed": 100.0,
	"player_maxspeed": 320.0, "sv_maxspeed": 320.0, "sv_air_max_wishspeed": 320.0, "sv_gravity": 800.0,
	"sv_jump_impulse": 270.0, "jump_order": "ideal", "air_surface": "constant", "stamina_model": "off",
	"ground_speed_clamp": false, "sv_enablebunnyhopping": true, "sv_autobunnyhopping": true, "tickrate": 128}

var out_dir := ""
var oracle_path := ""
var results: Array[Dictionary] = []
var only: Array = []
var measured := {}
var _group := ""
var game: Node

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--oracle="):
			oracle_path = arg.trim_prefix("--oracle=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	if out_dir.is_empty():
		printerr("usage: --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_main.call_deferred()

func _main() -> void:
	var started := Time.get_ticks_msec()
	for group: String in GROUPS:
		if only.is_empty() or group in only:
			_group = group
			print("group: ", group)
			await call("_group_" + group)
			await _drop_game()
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	var summary := {"checks": results.size(), "failed": failed.size(), "results": results, "measured": measured,
		"oracle": oracle_path, "seconds": (Time.get_ticks_msec() - started) / 1000.0, "engine": Engine.get_version_info(),
		"sources_sha256": {"res://scripts/r14_presets.gd": FileAccess.get_sha256("res://scripts/r14_presets.gd"),
			"res://scripts/r14_source_motion.gd": FileAccess.get_sha256("res://scripts/r14_source_motion.gd"),
			"res://scripts/r14_source_player.gd": FileAccess.get_sha256("res://scripts/r14_source_player.gd")}}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	file.close()
	for r: Dictionary in failed:
		printerr("FAIL %s / %s: %s" % [r.group, r.name, r.detail])
	print("r14 quake: %d checks, %d failed" % [results.size(), failed.size()])
	quit(1 if failed.size() > 0 else 0)

func check(name: String, ok: bool, detail: Variant = "") -> bool:
	results.append({"group": _group, "name": name, "ok": ok, "detail": str(detail)})
	if not ok:
		printerr("  fail: %s (%s)" % [name, detail])
	return ok

# --- input and stepping, as tests/test_r14_loop.gd ---------------------------------------------

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

func make_game(alias: String = "", fixture: bool = true, profile: String = "") -> Node:
	FIXTURE.params = {}
	game = MAIN.new()
	if fixture:
		game.set("level_script", FIXTURE)
	if not alias.is_empty():
		game.set("motor", alias)
	if not profile.is_empty():
		# an absolute profile of this test's own: the main persists only into a path named for it.
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

func cvars() -> Dictionary:
	return p().get("settings")

func grounded() -> bool:
	return bool(p().call("is_grounded"))

func hspeed_u() -> float:
	return Vector2(p().velocity.x, p().velocity.z).length() / U

## counts per mouse step that turn the view by `radians`, from the runner's own source units.
func counts_for(radians: float) -> float:
	return radians / float(p().get("tape_radians_per_count"))

func pose() -> Dictionary:
	return {"feet": p().global_position, "velocity": p().velocity, "yaw": float(p().get("yaw")), "pitch": float(p().get("pitch")), "node": p().get_instance_id(), "script": (p().get_script() as Script).resource_path}

func same_pose(a: Dictionary, b: Dictionary) -> bool:
	return a.feet == b.feet and a.velocity == b.velocity and a.yaw == b.yaw and a.pitch == b.pitch

## W until the horizontal speed reaches `target` u/s (or the limit), then release W.
func run_up(target: float, limit: int = 400) -> void:
	key(KEY_W, true)
	await until(func() -> bool: return hspeed_u() >= target, limit)
	key(KEY_W, false)

## one hop from a run: tap jump, hold `keys` and turn `dx` counts each tick until landing.
## returns the motor's own last_hop plus the observer's and the air ticks seen.
func hop(keys: Array, dx: float, limit: int = 300) -> Dictionary:
	key(KEY_SPACE, true)
	await physics_frame
	key(KEY_SPACE, false)
	for code: Key in keys:
		key(code, true)
	var start := hspeed_u()
	await until(func() -> bool:
		if dx != 0.0:
			mouse(dx)
		return grounded(), limit)
	for code: Key in keys:
		key(code, false)
	await physics_frame
	var motor: Dictionary = p().get("last_hop")
	var observed: Dictionary = game.stats.last_hop
	return {"motor": motor.duplicate(), "observer": observed.duplicate(), "start_u": start}

# --- groups -----------------------------------------------------------------------------------

func _group_vectors() -> void:
	var settings := PRESETS.source_settings(F4, {"sensitivity": 2.5, "fov": 90.0})
	var exact := EXPECTED.keys().all(func(k: String) -> bool: return settings[k] == EXPECTED[k])
	check("F4 settings carry exactly the specified values", exact, settings)
	check("F4 keeps the shared source hull, step and walkable rule", float(settings.hull_width) == 32.0 and float(settings.hull_height) == 72.0 and float(settings.sv_stepsize) == 18.0 and float(settings.sv_walkable_normal) == 0.7, settings)
	check("F4 names itself in the motor state, not as the server", str(settings.preset) == "quake3_inspired")
	check("F2's settings are untouched by F4", PRESETS.source_settings("server128", {}).sv_air_max_wishspeed == 30.0 and float(PRESETS.source_settings("server128", {}).sv_airaccelerate) == 100.0 and float(PRESETS.source_settings("server128", {}).player_maxspeed) == 250.0)
	# no free diagonal: W, A and W+A all ask for the same 320 u wish.
	var speeds: Array = []
	for keys: Array in [[1.0, 0.0], [0.0, -1.0], [1.0, -1.0], [1.0, 1.0]]:
		speeds.append(float(MOTION.wish(keys[0], keys[1], 0.3, settings).speed))
	check("W, A, W+A and W+D all wish exactly 320 u/s", speeds.all(func(s: float) -> bool: return s == 320.0), speeds)
	# the independent closed-form vectors, through the shared tick with F4's own settings.
	if oracle_path.is_empty():
		check("independent vector file given (--oracle=)", false, "pass --oracle=…/quake-prototype/oracle.json")
	else:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
		var cases: Array = data.get("cases", []) if data is Dictionary else []
		var worst := 0.0
		var failures: Array = []
		for row: Dictionary in cases:
			var config := settings.duplicate()
			config.tickrate = int(row.hz)
			var state := MOTION.new_state(Vector3(0, 10000, 0))
			state.velocity = Vector3(row.velocity_u_s[0], 0, row.velocity_u_s[1])
			var wishdir := Vector3(row.wish_direction[0], 0, row.wish_direction[1])
			# D at this yaw wishes along the supplied vector; no steering helper is involved.
			var yaw := MOTION.yaw_for_side(wishdir, 1.0)
			MOTION.step(state, {"side": 1.0, "yaw": yaw}, config, 1.0 / float(row.hz), MOTION.FlatWorld.new())
			var error := Vector2(state.velocity.x, state.velocity.z).distance_to(Vector2(row.after_u_s[0], row.after_u_s[1]))
			worst = maxf(worst, error)
			if error >= 0.00015:
				failures.append([row.hz, row.velocity_u_s, row.wish_direction, error])
		measured["oracle_cases"] = cases.size()
		measured["oracle_worst_error_u_s"] = worst
		check("all independent vectors read (64)", cases.size() == 64, cases.size())
		check("every independent vector agrees within 1.5e-4 u/s", failures.is_empty(), failures.slice(0, 5))
	# closed-form peaks at 320 u/s and 128 Hz, swept over the wish angle off travel.
	var f4 := _peak(settings, 320.0)
	var f2 := _peak(PRESETS.source_settings("server128", {}), 320.0)
	measured["peak_f4"] = f4
	measured["peak_f2"] = f2
	# full projection: budget 320/128 = 2.5 u/s fits while cos(a) <= 1 - 2.5/320.
	var limit := rad_to_deg(acos(1.0 - 2.5 / 320.0))
	var best := sqrt(320.0 * 320.0 + 6.25 + 2.0 * 320.0 * 2.5 * (1.0 - 2.5 / 320.0)) - 320.0
	check("F4 best one-tick gain at 320 u/s is the closed form 2.480620", absf(float(f4.gain) - best) < 2e-4 and absf(best - 2.480620) < 1e-6, [f4, best])
	check("F4 gains best a few degrees off travel (7.17)", absf(float(f4.angle) - limit) < 0.06 and absf(limit - 7.166) < 0.01, [f4.angle, limit])
	check("F2's 30 u cap instead rewards a near-perpendicular wish", float(f2.angle) > 85.0 and float(f2.gain) < 1.41, f2)
	check("F4 still gains at 45 degrees off travel, F2 does not", _gain_at(settings, 320.0, 45.0) > 1.7 and _gain_at(PRESETS.source_settings("server128", {}), 320.0, 45.0) == 0.0, [_gain_at(settings, 320.0, 45.0), _gain_at(PRESETS.source_settings("server128", {}), 320.0, 45.0)])
	# no keys in the air keeps the line exactly.
	var coast := MOTION.new_state(Vector3(0, 10000, 0))
	coast.velocity = Vector3(200, 0, -250)
	for i: int in 64:
		MOTION.step(coast, {"yaw": i * 0.05}, settings, 1.0 / 128.0, MOTION.FlatWorld.new())
	check("no keys in the air keeps horizontal velocity exactly", Vector2(coast.velocity.x, coast.velocity.z) == Vector2(200, -250), coast.velocity)

## the best one-tick air gain over wish angles 0-180 degrees off travel, in 0.01 degree steps.
func _peak(settings: Dictionary, speed: float) -> Dictionary:
	var best := {"gain": -INF, "angle": 0.0}
	for i: int in 18001:
		var gain := _gain_at(settings, speed, i * 0.01)
		if gain > float(best.gain):
			best = {"gain": gain, "angle": i * 0.01}
	return best

func _gain_at(settings: Dictionary, speed: float, degrees: float) -> float:
	var v := Vector3(0, 0, -speed)
	var dir := Vector3(-sin(deg_to_rad(degrees)), 0, -cos(deg_to_rad(degrees)))
	var w := MOTION.wish(0.0, 1.0, MOTION.yaw_for_side(dir, 1.0), settings)
	var after := MOTION.air_accelerate(v, w.dir, w.speed, settings, 1.0 / 128.0)
	return Vector2(after.x, after.z).length() - speed

func _group_preset() -> void:
	for alias: String in ["quake", "f4", "F4", F4]:
		await make_game(alias)
		check("motor %s selects F4 at 128 Hz" % alias, str(game.preset_id) == F4 and int(game.physics_hz) == 128 and Engine.physics_ticks_per_second == 128, [game.preset_id, Engine.physics_ticks_per_second])
		await _drop_game()
	await make_game()
	check("default stays F2", str(game.preset_id) == "server128", game.preset_id)
	var body := p().get_instance_id()
	await tap(KEY_F4)
	check("F4 switches live on the same source body", str(game.preset_id) == F4 and p().get_instance_id() == body and (p().get_script() as Script).resource_path == "res://scripts/r14_source_player.gd")
	check("F4 runs 128 Hz", Engine.physics_ticks_per_second == 128 and int(p().get("physics_hz")) == 128)
	check("live F4 settings carry exactly the specified values", EXPECTED.keys().all(func(k: String) -> bool: return cvars()[k] == EXPECTED[k]), cvars())
	check("source look units carry over: 2.5 × 0.022 degrees per count", is_equal_approx(float(p().get("tape_radians_per_count")), deg_to_rad(2.5 * 0.022)))
	var ident := str(game.hud.call("identity_text"))
	measured["identity"] = ident
	check("hud names F4, its rate and the full wish", ident.contains("F4 Quake III-inspired  ·") and ident.contains("128 Hz") and ident.contains("320 u wish, not 30 u") and ident.contains("not Quake"), ident)
	check("keys line offers F4", str(game.hud.keys_line.text).contains("F4 Q3-inspired"), game.hud.keys_line.text)
	check("controls name W with A or D and coasting", str(game.hud.controls.text).contains("hold W with A or D") and str(game.hud.controls.text).contains("coast"), game.hud.controls.text)
	check("window title names F4", str(root.get_window().title).contains("Quake III-inspired") and str(root.get_window().title).contains("128 Hz"), root.get_window().title)
	check("motor state reports the F4 configuration", str((p().call("get_motion_state") as Dictionary).preset) == "quake3_inspired")
	var start: Vector3 = p().global_position
	key(KEY_W, true)
	await ticks(128)
	key(KEY_W, false)
	measured["f4_ground_run_u_s"] = hspeed_u()
	check("W runs at 320 u/s on F4", absf(hspeed_u() - 320.0) < 0.5, hspeed_u())
	check("W moves the F4 runner", p().global_position.distance_to(start) > 5.0, p().global_position.distance_to(start))
	await tap(KEY_F2)
	await ticks(128)
	await tap(KEY_R)
	key(KEY_W, true)
	await ticks(128)
	key(KEY_W, false)
	measured["f2_ground_run_u_s"] = hspeed_u()
	check("back on F2, the same W runs at 250 u/s", absf(hspeed_u() - 250.0) < 0.5, hspeed_u())

func _group_ballistics() -> void:
	# one tapped hop on flat ground: F4's 270 impulse, 800 gravity, exact ballistic order.
	for row: Array in [[F4, 270.0], ["server128", 301.993377]]:
		await make_game(row[0])
		await ticks(20)
		var floor_y: float = p().global_position.y
		var jumps := int(p().get("jump_count"))
		key(KEY_SPACE, true)
		await physics_frame
		key(KEY_SPACE, false)
		var apex := floor_y
		var air := 0
		var left := false
		for i: int in 200:
			await physics_frame
			apex = maxf(apex, p().global_position.y)
			if not grounded():
				left = true
				air += 1
			elif left:
				break
		var height_u := (apex - floor_y) / U
		measured["apex_%s_u" % row[0]] = height_u
		measured["air_ticks_%s" % row[0]] = air
		var impulse: float = row[1]
		if row[0] == F4:
			# sampled apex of J t - g t² / 2 at t = k / 128.
			var best := 0.0
			for k: int in 200:
				var t := k / 128.0
				best = maxf(best, 270.0 * t - 400.0 * t * t)
			check("F4 apex is the 270/800 ballistic peak (45.56 u)", absf(height_u - best) < 0.05, [height_u, best])
			check("F4 flight lasts about 2 J / g = 0.675 s (86 ticks)", air >= 84 and air <= 87, air)
		else:
			check("F2 keeps its own higher jump", height_u > 55.0, height_u)
		check("%s: one jump" % row[0], int(p().get("jump_count")) == jumps + 1)
		await _drop_game()

func _group_switch() -> void:
	# mid-air F2 -> F4 -> F3 -> F4 -> F2: exact pose each time, practice afterwards.
	await make_game()
	await run_up(240.0)
	key(KEY_SPACE, true)
	await ticks(10)
	key(KEY_SPACE, false)
	mouse(-40, 12)
	await ticks(2)
	check("airborne before the switches", not grounded())
	var before := pose()
	key(KEY_F4, true)
	var after := pose()
	key(KEY_F4, false)
	check("F2 -> F4 keeps feet, velocity, yaw and pitch exactly", same_pose(before, after), [before, after])
	check("F2 -> F4 keeps the body", before.node == after.node)
	check("a started attempt switched to F4 is practice", not bool(game.clean_eligible) and str(game.practice_reason) == "preset")
	check("F4 applies at once in the air", str(game.preset_id) == F4 and float(cvars().sv_air_max_wishspeed) == 320.0)
	await ticks(2)
	before = pose()
	key(KEY_F3, true)
	after = pose()
	key(KEY_F3, false)
	check("F4 -> F3 replaces the runner and keeps the pose", before.node != after.node and same_pose(before, after) and str(game.preset_id) == "r13_original120", [before, after])
	await ticks(2)
	before = pose()
	key(KEY_F4, true)
	after = pose()
	key(KEY_F4, false)
	check("F3 -> F4 builds a source body in place", before.node != after.node and after.script == "res://scripts/r14_source_player.gd" and same_pose(before, after) and str(game.preset_id) == F4, [before, after])
	check("only one runner", game.find_children("Runner", "", false, false).size() == 1)
	await ticks(2)
	before = pose()
	key(KEY_F2, true)
	after = pose()
	key(KEY_F2, false)
	check("F4 -> F2 keeps everything and restores the 30 u cap", same_pose(before, after) and float(cvars().sv_air_max_wishspeed) == 30.0 and float(cvars().player_maxspeed) == 250.0)
	await tap(KEY_R)
	check("R is clean again", bool(game.clean_eligible) and str(game.practice_reason) == "")
	await _drop_game()
	# a hop begun under F2 before the 0.5 m timer threshold cannot become a clean F4 attempt.
	await make_game()
	key(KEY_SPACE, true)
	await ticks(6)
	key(KEY_SPACE, false)
	check("the early hop has not armed the timer", not bool(game.get("_started")) and not grounded(), game.get("_started"))
	await tap(KEY_F4)
	check("an early hop switched to F4 is practice", not bool(game.clean_eligible) and str(game.practice_reason) == "preset", game.practice_reason)
	await _drop_game()
	# untouched spawn: a switch stays clean; the first immediate hop counts.
	await make_game()
	await tap(KEY_F4)
	check("F4 at the untouched spawn stays clean", bool(game.clean_eligible) and str(game.preset_id) == F4)
	await _drop_game()
	await make_game()
	await ticks(10)
	key(KEY_F4, true)
	key(KEY_F4, false)
	wheel(true)
	await until(func() -> bool: return not grounded(), 6)
	await until(grounded, 200)
	await ticks(2)
	check("the first hop right after switching to F4 is counted", int(game.stats.hop_count) == 1 and not (game.stats.last_hop as Dictionary).is_empty(), [game.stats.hop_count, game.stats.last_hop])
	await _drop_game()
	# rate: from 64 Hz vanilla to F4's 128 Hz while moving.
	await make_game("csgo_vanilla")
	await tap(KEY_R)
	key(KEY_W, true)
	await ticks(40)
	var mismatches := int(game.rate_mismatch_ticks)
	await tap(KEY_F4)
	var deltas: Array = []
	for i: int in 24:
		await physics_frame
		deltas.append(float(game.last_delta))
	key(KEY_W, false)
	measured["f1_to_f4_deltas"] = deltas
	measured["f1_to_f4_stale_callbacks"] = int(game.rate_mismatch_ticks) - mismatches
	check("F1 -> F4 settles every callback to 1/128", is_equal_approx(float(deltas[-1]), 1.0 / 128.0) and bool(game.rate_ok), deltas)
	check("the motor reports 128 Hz and a matching delta", bool((p().call("get_motion_state") as Dictionary).rate_matches))
	check("the switched attempt is practice", not bool(game.clean_eligible))
	check("stale callbacks are logged, not hidden", int(game.rate_mismatch_ticks) - mismatches == (game.rate_log as Array).filter(func(e: Dictionary) -> bool: return str(e.preset) == F4).size(), game.rate_log)

func _group_strafe() -> void:
	# the same keys and mouse on both laws, from each one's own run speed.
	var rows := {}
	for row: Array in [["W+A synced", [KEY_W, KEY_A], -0.004], ["A synced", [KEY_A], -0.004], ["W+A no mouse", [KEY_W, KEY_A], 0.0], ["coast, mouse turning", [], -0.004]]:
		for preset: String in [F4, "server128"]:
			await make_game(preset)
			await run_up(319.0 if preset == F4 else 249.0)
			var result := await hop(row[1], counts_for(absf(row[2])) * signf(row[2]))
			var motor: Dictionary = result.motor
			var observer: Dictionary = result.observer
			rows["%s / %s" % [row[0], preset]] = {"takeoff": motor.get("takeoff"), "landing": motor.get("landing"), "gain": motor.get("gain"), "air_ticks": motor.get("air_ticks"),
				"sync": motor.get("sync"), "observer_gain": observer.get("gain"), "contact": observer.get("contact"), "wall_ticks": observer.get("wall_ticks"), "x": p().global_position.x}
			await _drop_game()
	measured["strafe"] = rows
	var f4: Dictionary = rows["W+A synced / %s" % F4]
	var f2: Dictionary = rows["W+A synced / server128"]
	check("F4: W+A with a left turn gains well beyond 320 in one hop", float(f4.landing) > 400.0 and float(f4.gain) > 80.0, f4)
	check("F2: the same W+A input gains nothing under the 30 u cap", absf(float(f2.gain)) < 0.5, f2)
	check("F4 W+A hop touched no wall (gain is air, not contact)", absf(float(f4.contact)) < 0.01 and int(f4.wall_ticks) == 0, f4)
	var side_f4: Dictionary = rows["A synced / %s" % F4]
	var side_f2: Dictionary = rows["A synced / server128"]
	check("A alone with the same turn: F2 gains, F4 gains far less than with W+A (a different skill)", float(side_f2.gain) > 5.0 and float(side_f4.gain) < float(f4.gain) - 50.0, [side_f2, side_f4])
	check("F4 W+A without the mouse still curves and gains", float(rows["W+A no mouse / %s" % F4].gain) > 40.0, rows["W+A no mouse / %s" % F4])
	for preset: String in [F4, "server128"]:
		var coast: Dictionary = rows["coast, mouse turning / %s" % preset]
		check("%s: letting go of every key keeps the line" % preset, absf(float(coast.gain)) < 0.01, coast)
	check("observer and motor agree on F4's gain", absf(float(f4.gain) - float(f4.observer_gain)) < 1e-3, f4)

func _group_records() -> void:
	var profile := out_dir.path_join("records.cfg")
	if FileAccess.file_exists(profile):
		DirAccess.remove_absolute(profile)
	# a clean F2 finish, then a clean F4 finish, in one process with an isolated profile.
	await make_game("", true, profile)
	var f2_key := str(game.course_key)
	key(KEY_W, true)
	await until(func() -> bool: return bool(game.finished), 3000)
	key(KEY_W, false)
	check("F2 clean finish by running", str(game.finish_kind) == "clean" and bool(game.last_save_ok), game.finish_kind)
	var f2_best := float(game.best_time)
	await tap(KEY_F4)
	check("F4 has its own record key", str(game.course_key) != f2_key, [game.course_key, f2_key])
	check("F4 shows no F2 best", float(game.best_time) < 0.0, game.best_time)
	await tap(KEY_R)
	key(KEY_W, true)
	await until(func() -> bool: return bool(game.finished), 3000)
	key(KEY_W, false)
	var f4_key := str(game.course_key)
	var f4_best := float(game.best_time)
	measured["fixture_clean_f2_s"] = f2_best
	measured["fixture_clean_f4_s"] = f4_best
	check("F4 clean finish by running sets F4's best", str(game.finish_kind) == "clean" and f4_best > 0.0 and bool(game.last_save_ok), [game.finish_kind, f4_best])
	check("F4's 320 u/s run is faster than F2's 250 on the same fixture", f4_best < f2_best, [f4_best, f2_best])
	# a mixed attempt: started on F2, finished on F4. it must not touch F4's best.
	await tap(KEY_F2)
	check("switching back shows F2's best only", is_equal_approx(float(game.best_time), f2_best))
	await tap(KEY_R)
	key(KEY_W, true)
	await ticks(100)
	await tap(KEY_F4)
	key(KEY_W, true)
	await until(func() -> bool: return bool(game.finished), 3000)
	key(KEY_W, false)
	check("a mixed F2 -> F4 attempt finishes as practice", str(game.finish_kind) == "practice", game.finish_kind)
	check("it leaves F4's best alone", is_equal_approx(float(game.best_time), f4_best), [game.best_time, f4_best])
	# practice from a stage never records.
	await tap(KEY_R)
	key(KEY_W, true)
	await until(func() -> bool: return int(game.checkpoint_index) >= 1, 2000)
	key(KEY_W, false)
	await tap(KEY_F)
	key(KEY_W, true)
	await until(func() -> bool: return bool(game.finished), 3000)
	key(KEY_W, false)
	check("F4 stage practice finishes unrecorded", str(game.finish_kind) == "practice" and is_equal_approx(float(game.best_time), f4_best))
	await _drop_game()
	var config := ConfigFile.new()
	check("profile written", config.load(profile) == OK)
	var section := "course_" + f4_key
	check("F4 section names its preset, family, version and rate", str(config.get_value(section, "preset", "")) == F4 and str(config.get_value(section, "family", "")) == "source" and str(config.get_value(section, "family_version", "")) == str(PRESETS.FAMILIES.source.version) and int(config.get_value(section, "physics_hz", 0)) == 128, section)
	var physics: Variant = JSON.parse_string(str(config.get_value(section, "physics", "{}")))
	check("F4 record key holds the full projection configuration", physics is Dictionary and float(physics.sv_air_max_wishspeed) == 320.0 and float(physics.sv_airaccelerate) == 1.0 and str(physics.preset) == "quake3_inspired" and not physics.has("sensitivity"), physics)
	check("F2 section keeps its own physics", float((JSON.parse_string(str(config.get_value("course_" + f2_key, "physics", "{}"))) as Dictionary).get("sv_air_max_wishspeed", 0)) == 30.0)
	check("the profile holds exactly the two clean keys", Array(config.get_sections()).filter(func(s: String) -> bool: return s.begins_with("course_")).size() == 2, config.get_sections())
	# a fresh game on the same profile: F4 loads only its own best.
	await make_game(F4, true, profile)
	check("a fresh F4 game loads F4's best", is_equal_approx(float(game.best_time), f4_best) and str(game.course_key) == f4_key, [game.best_time, f4_best])
	await tap(KEY_F5)
	check("AA 1000 has neither best", float(game.best_time) < 0.0 and str(game.course_key) != f4_key and str(game.course_key) != f2_key)

func _group_pause() -> void:
	await make_game()
	await tap(KEY_ESCAPE)
	var button: Button = game.hud.preset_buttons[F4]
	check("F4 is listed and enabled", str(button.text) == "F4  Quake III-inspired" and not button.disabled, button.text)
	var texts: Array[String] = []
	for node: Node in (game.hud as Node).find_children("*", "Label", true, false):
		if (node as Control).is_visible_in_tree():
			texts.append(str((node as Label).text))
	check("its menu entry names the full wish, the source body and the limits", texts.any(func(t: String) -> bool: return t.contains("full 320 u wish") and t.contains("Source hull and collision") and t.contains("not Quake or CPMA") and t.contains("hold W with A or D")), texts)
	var feet: Vector3 = p().global_position
	await click(button)
	check("clicking F4 switches it paused, the runner still", str(game.preset_id) == F4 and bool(game.paused) and p().global_position == feet)
	await click(game.hud.resume_button)
	check("resume runs F4", not bool(game.paused) and bool(p().get("input_enabled")))

func _group_maps() -> void:
	# smoke only, on the geometry at this checkout: W moves on each real map without a respawn.
	for id: String in ["practice", "overflow"]:
		await make_game(F4, false)
		if id != str(game.map_id):
			await tap(KEY_ESCAPE)
			await click(game.hud.map_buttons[id])
		measured["geometry_%s" % id] = game.course_geometry
		check("%s loads with F4" % id, str(game.map_id) == id and str(game.preset_id) == F4)
		var start := p().global_position
		key(KEY_W, true)
		await ticks(90)
		key(KEY_W, false)
		check("%s is runnable with F4" % id, p().global_position.distance_to(start) > 2.0 and int(game.respawn_count) == 0, p().global_position)
		await _drop_game()

extends SceneTree
## p / r16 movement lab checks, headless, through a labelled host: the real r15 host (r15_main.gd)
## on the real lab map with `source_runner` set to the r16 runner (r16_experiment_player.gd). that
## is r15's own factory for a runner override, so the r16 host can later replay the same episodes
## through the r16 main; until then the host identity is r15's with the r16 runner in it.
## every episode starts from one labelled setup (a fresh game, R, or the stage picker's own
## practise_stage, plus, where named, fixture geometry added to the lab hall) and is then played
## only with key and relative-mouse events through Input. the actor reads the body's state to time
## a press, as a player watching the screen would, and never writes a pose, velocity or progress.
## comparisons replay the exact recorded event list (tick, key edge, mouse delta) on each runner.
##
## groups: identity, parity, wall_ad (the A/D defect and its repair), wall_rules (budget, planes,
## echoes, refusals, reset, toggle), slide_chain (bhop, landing slide, hop, old failure), slide_world
## (roof, edge, false floor, reset, toggle, crouch hop), combos (wall and slide together), grapple
## (same inputs, same outcome on both runners). nothing here says how anything feels.
## godot --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/test_r16_lab.gd -- --out=DIR [--only=GROUPS]

const MAIN := preload("res://scripts/r15_main.gd")
const LAB15 := preload("res://scripts/r15_experiment_player.gd")
const LAB16 := preload("res://scripts/r16_experiment_player.gd")
const SOURCE := preload("res://scripts/r15_source_player.gd")
const LEVEL := preload("res://scripts/r15_experiment_level.gd")
const U := 0.0254
const HALF_HULL := 16.0 * U
const GROUPS := ["identity", "parity", "wall_ad", "wall_rules", "slide_chain", "slide_world", "combos", "grapple"]
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL, "shift": KEY_SHIFT, "e": KEY_E}
const OTHER_KEYS := {"r": KEY_R, "f": KEY_F, "esc": KEY_ESCAPE, "f2": KEY_F2, "f5": KEY_F5, "1": KEY_1, "2": KEY_2, "3": KEY_3}
## mouse counts per tick for a strafe turn: 40 × 0.055° = 2.2° a tick, 282°/s at sensitivity 2.5.
const TURN := 40.0

var out_dir := ""
var only: Array = []
var results: Array[Dictionary] = []
var notes: Dictionary = {}
var _group := ""
var game: Node
var ep: Dictionary = {}
var _held: Dictionary = {}
var _pending: Array = []
var _jumps_at_slide: int = 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	if out_dir.is_empty():
		printerr("usage: --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("episodes"))
	_main.call_deferred()

func _main() -> void:
	var started := Time.get_ticks_msec()
	for group: String in GROUPS:
		if only.is_empty() or group in only:
			_group = group
			print("group: ", group)
			await call("_group_" + group)
			await drop_game()
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	var summary := {"checks": results.size(), "failed": failed.size(), "results": results, "notes": notes,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0, "engine": Engine.get_version_info(),
		"host": "r15_main.gd with source_runner = r16_experiment_player.gd (labelled r15 factory host)"}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_plain(summary), "  "))
	file.close()
	for r: Dictionary in failed:
		print("FAIL %s / %s: %s" % [r.group, r.name, r.detail])
	print("r16 lab: %d checks, %d failed" % [results.size(), failed.size()])
	quit(1 if failed.size() > 0 else 0)

func check(name: String, ok: bool, detail: Variant = "") -> bool:
	results.append({"group": _group, "name": name, "ok": ok, "detail": str(_plain(detail)).left(900)})
	if not ok:
		print("  fail: %s (%s)" % [name, str(_plain(detail)).left(400)])
	return ok

func note(key: String, value: Variant) -> void:
	notes["%s.%s" % [_group, key]] = _plain(value)

# --- game and input -------------------------------------------------------------------------

## the labelled host: r15_main on the lab map; runner "r16" sets source_runner to the r16 script,
## "r15" leaves the host's own lab runner, "source" plays the approved course runner on the lab.
func make_game(runner_kind: String, map: String = "experiment") -> void:
	await drop_game()
	Engine.physics_ticks_per_second = 128
	game = MAIN.new()
	game.set("set_window_title", false)
	game.set("map_id", map)
	match runner_kind:
		"r16":
			game.set("source_runner", LAB16)
		"source":
			game.set("source_runner", SOURCE)
	root.add_child(game)
	await ticks(3)

func drop_game() -> void:
	release_all()
	if game != null and is_instance_valid(game):
		if bool(game.get("paused")):
			paused = false
			game.set("paused", false)
		root.remove_child(game)
		game.free()
	game = null
	await process_frame
	await physics_frame

func runner() -> CharacterBody3D:
	return game.get("player") as CharacterBody3D

func level() -> Node3D:
	return game.get("level") as Node3D

func send_key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(name: String, pressed: bool) -> void:
	if pressed == _held.has(name):
		return
	send_key(KEYS[name], pressed)
	if pressed:
		_held[name] = true
	else:
		_held.erase(name)
	_pending.append({"key": name, "edge": "press" if pressed else "release"})

## an os key repeat of a held key: pressed and echo, delivered as the os would.
func echo(name: String) -> void:
	send_key(KEYS[name], true, true)
	_pending.append({"key": name, "edge": "echo"})

func tap(name: String) -> void:
	send_key(OTHER_KEYS[name], true)
	_pending.append({"key": name, "edge": "tap"})
	await physics_frame
	send_key(OTHER_KEYS[name], false)
	await physics_frame

func look(dx: float, dy: float = 0.0) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.screen_relative = Vector2(dx, dy)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_pending.append({"mouse": [dx, dy]})

func wheel() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	_pending.append({"wheel": 1})

func release_all() -> void:
	for name: String in _held.keys():
		send_key(KEYS[name], false)
	_held.clear()
	for name: String in OTHER_KEYS:
		send_key(OTHER_KEYS[name], false)

func ticks(n: int) -> void:
	for i: int in n:
		await step()

## one physics tick with whatever was sent since the last one; the row is the post-step state.
func step() -> void:
	var sent := _pending
	_pending = []
	await physics_frame
	if ep.is_empty() or game == null:
		return
	var body := runner()
	var tick := int(ep.tick)
	if not sent.is_empty():
		(ep.events as Array).append({"tick": tick, "sent": sent})
	var motion: Dictionary = body.call("get_motion_state")
	var row := {"t": tick, "p": body.global_position, "v": body.velocity, "g": bool(body.call("is_grounded")), "duck": body.get("ducked"),
		"blocked": body.get("stand_blocked"), "yaw": body.get("yaw"), "pitch": body.get("pitch"), "disp": motion.displacement,
		"ev": motion.events, "cp": game.get("checkpoint_index"), "resp": game.get("respawn_count"), "held": _held.keys(), "sent": sent,
		"contacts": (motion.contacts as Array).map(func(c: Dictionary) -> Variant: return c.get("normal", null))}
	var lab: Variant = motion.get("experiment")
	if lab is Dictionary:
		var l: Dictionary = lab
		row["lab"] = {"events": l.events, "imp": l.impulses_u, "slide": l.slide.active, "kind": l.slide.get("kind", ""), "armed": l.slide.get("armed", false),
			"latch": l.slide.get("held_space_ignored", false), "line": l.grapple.attached, "anchor": l.grapple.anchor, "release": l.grapple.release,
			"target": l.grapple.target.get("state", ""), "budget": l.wall_jump.get("budget", -1), "flight": l.wall_jump.flight,
			"refusal": l.wall_jump.refusal, "guard": l.wall_jump.get("guard_ticks", 0), "end": l.slide.end, "disarm": l.slide.get("disarm", ""),
			"wj": l.wall_jump.get("last", {}) if "wall_jump" in l.events else {}, "probe_key": str(l.wall_jump.probe.get("key", "")),
			"used": (l.wall_jump.get("used", []) as Array).map(func(w: Dictionary) -> String: return str(w.key)), "landing": l.slide.get("last_landing", {}) if "slide_landing" in l.events or "slide_refused" in l.events else {}}
	(ep.rows as Array).append(row)
	ep.tick = tick + 1

func begin(name: String, setup: String) -> void:
	release_all()
	ep = {"name": name, "group": _group, "setup": setup, "tick": 0, "events": [], "rows": [], "map": game.get("map_id"), "preset": game.get("preset_id"),
		"runner": (runner().get_script() as Script).resource_path, "moves": game.call("lab_moves"), "start": runner().global_position}

func finish_episode() -> Dictionary:
	release_all()
	var done := ep
	ep = {}
	var file := FileAccess.open(out_dir.path_join("episodes/%s.json" % str(done.name)), FileAccess.WRITE)
	file.store_string(JSON.stringify(_plain(done)))
	file.close()
	return done

## replays a recorded event list tick for tick (keys, echoes, mouse, wheel), then `extra` ticks.
func replay(events: Array, length: int) -> void:
	var by_tick := {}
	for entry: Dictionary in events:
		by_tick[int(entry.tick)] = entry.sent
	for t: int in length:
		for item: Dictionary in by_tick.get(t, []):
			if item.has("mouse"):
				look(float(item.mouse[0]), float(item.mouse[1]))
			elif item.has("wheel"):
				wheel()
			elif str(item.edge) == "echo":
				echo(str(item.key))
			elif str(item.edge) == "tap":
				await tap(str(item.key))
			else:
				key(str(item.key), str(item.edge) == "press")
		await step()

func until(done: Callable, limit: int) -> bool:
	for i: int in limit:
		if done.call():
			return true
		await step()
	return done.call()

func feet() -> Vector3:
	return runner().global_position

func grounded() -> bool:
	return bool(runner().call("is_grounded"))

func speed_u() -> float:
	var v := runner().velocity
	return Vector2(v.x, v.z).length() / U

func lab_state() -> Dictionary:
	return (runner().call("get_motion_state") as Dictionary).get("experiment", {})

func rows_with(done: Dictionary, event: String) -> Array:
	return (done.rows as Array).filter(func(r: Dictionary) -> bool: return r.has("lab") and event in r.lab.events)

func first_with(done: Dictionary, event: String) -> int:
	for r: Dictionary in done.rows:
		if r.has("lab") and event in r.lab.events:
			return int(r.t)
	return -1

func clear_now() -> bool:
	var body := runner()
	return not body.test_move(body.global_transform, Vector3.ZERO, null, 0.0001, true, 1)

func hspeed(v: Vector3) -> float:
	return Vector2(v.x, v.z).length() / U

## per-tick rows as [position, velocity, yaw] for exact comparison.
func trace(done: Dictionary) -> Array:
	return (done.rows as Array).map(func(r: Dictionary) -> Array: return [r.p, r.v, r.yaw])

func same(a: Array, b: Array) -> bool:
	return a.size() == b.size() and first_diff(a, b) == -1

func first_diff(a: Array, b: Array) -> int:
	for i: int in mini(a.size(), b.size()):
		if a[i][0] != b[i][0] or a[i][1] != b[i][1] or a[i][2] != b[i][2]:
			return i
	return -1 if a.size() == b.size() else mini(a.size(), b.size())

## labelled fixture geometry for one episode: a named static convex body in the running lab level.
func fixture(name: String, points: PackedVector3Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "r16_fixture_" + name
	var shape := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	convex.points = points
	shape.shape = convex
	body.add_child(shape)
	level().add_child(body)
	return body

func box_points(lo: Vector3, hi: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for x: float in [lo.x, hi.x]:
		for y: float in [lo.y, hi.y]:
			for z: float in [lo.z, hi.z]:
				out.append(Vector3(x, y, z))
	return out

# --- the strafe actor -----------------------------------------------------------------------

## from a standstill: W and held Space for the first hop, then strafe hops, each flight one side
## key with the mouse turning the same way, switching side on each landing. `sides` lists the
## side per flight ("a" or "d"); returns when the last listed flight has landed (body grounded).
func strafe_hops(sides: Array, turn: float = TURN, release_w: bool = true) -> void:
	key("w", true)
	key("space", true)
	await until(func() -> bool: return not grounded(), 60)
	if release_w:
		key("w", false)
	for side: String in sides:
		key("a" if side == "a" else "d", true)
		key("d" if side == "a" else "a", false)
		var sign := -1.0 if side == "a" else 1.0
		var airborne := false
		for t: int in 200:
			look(sign * turn)
			await step()
			if not grounded():
				airborne = true
			elif airborne:
				break
	key("a", false)
	key("d", false)

## from a standstill: W on the ground for `run` ticks, then held Space and a circle strafe: one
## side key with the mouse turning that way at `turn` counts a tick, until horizontal speed is at
## least `min_ups` and the flight heads within `tol` of `exit_yaw`. returns the tick, or -1.
func circle_build(side: String, min_ups: float, exit_yaw: float, limit: int = 1500, turn: float = 24.0, run: int = 50, tol: float = 0.05) -> int:
	key("w", true)
	await ticks(run)
	key("space", true)
	await until(func() -> bool: return not grounded(), 60)
	key("w", false)
	key(side, true)
	var sign := -1.0 if side == "a" else 1.0
	for t: int in limit:
		var v := runner().velocity
		var heading := atan2(-v.x, -v.z)
		if speed_u() >= min_ups and absf(wrapf(heading - exit_yaw, -PI, PI)) < tol and not grounded():
			return int(ep.tick)
		look(sign * turn)
		await step()
	return -1

## the drift: after the circle, switch to `side` (the key toward the wall) and turn gently that
## way (`turn` counts a tick) until `stop` holds. returns the tick, or -1.
func drift(side: String, turn: float, stop: Callable, limit: int) -> int:
	key(side, true)
	key("d" if side == "a" else "a", false)
	var sign := -1.0 if side == "a" else 1.0
	for t: int in limit:
		if stop.call():
			return int(ep.tick)
		look(sign * turn)
		await step()
	return -1

# --- identity -------------------------------------------------------------------------------

func _group_identity() -> void:
	var s15: Script = LAB15
	var s16: Script = LAB16
	var r15_map := s15.get_script_constant_map()
	var probe: Node = LAB16.new()
	var probe15: Node = LAB15.new()
	check("r16 runner extends the frozen r15 lab runner", s16.get_base_script() == s15)
	check("movement_version() names the r16 lab law", str(probe.call("movement_version")) == "r16-lab-moves-1")
	var mechanics: Array = probe.get("mechanics")
	var by_id := {}
	for m: Dictionary in mechanics:
		by_id[str(m.id)] = m
	check("grapple tuning is the exact r15 table", by_id.grapple.tuning == LAB15.GRAPPLE and str(by_id.grapple.tuning.law) == "r15-lab-grapple-1", by_id.grapple)
	check("wall tuning is the r16 law", str(by_id.wall_jump.tuning.law) == "r16-lab-wall-jump-2" and int(by_id.wall_jump.tuning.budget) == 2, by_id.wall_jump)
	check("slide tuning is the r16 law over the r15 slide values", str(by_id.slide.tuning.law) == "r16-lab-slide-2" and float(by_id.slide.tuning.friction) == float(LAB15.SLIDE.friction)
		and float(by_id.slide.tuning.min_entry_ups) == float(LAB15.SLIDE.min_entry_ups) and float(by_id.slide.tuning.buffer_s) == 0.4, by_id.slide)
	for name: String in ["GRAPPLE", "GRAPPLE_ACTION", "SLIDE_ACTION", "ANCHOR_GROUP", "SLIDE", "WALL", "MOVES", "PROBES", "EXPERIMENT_VERSION"]:
		check("inherited constant %s unchanged" % name, r15_map.has(name) and probe.get(name) == r15_map[name] and probe15.get(name) == r15_map[name], [probe.get(name), r15_map.get(name)])
	var own := s16.get_script_constant_map()
	check("r16 declares only new constant names", own.keys().all(func(k: String) -> bool: return not r15_map.has(k)), own.keys())
	# every grapple routine is inherited: the r16 script defines none of them.
	var own_methods := s16.get_script_method_list().filter(func(m: Dictionary) -> bool: return true).map(func(m: Dictionary) -> String: return str(m.name))
	var r16_source := s16.source_code
	for routine: String in ["_grapple_step", "_find_target", "_release", "_clear_line", "_hull_centre", "_eye", "_aim", "_process", "_ready", "ensure_actions", "_unhandled_input"]:
		check("grapple routine %s is inherited, not redefined" % routine, not r16_source.contains("func %s(" % routine))
	note("own_constants", own.keys())
	probe15.free()
	probe.free()
	var r15_probe: Node = LAB15.new()
	var r15_mech: Array = r15_probe.get("mechanics")
	check("the r15 lab runner's identity is untouched by r16", str(r15_mech[1].tuning.law) == "r15-lab-wall-jump-1" and str(r15_mech[0].tuning.law) == "r15-lab-slide-1")
	r15_probe.free()
	await make_game("r16")
	var body := runner()
	check("labelled host plays the r16 runner on the lab", body.get_script() == LAB16 and bool(game.call("is_lab")))
	check("host identity carries the r16 runner path and laws", str(game.call("runner_path")).ends_with("r16_experiment_player.gd") and JSON.stringify(game.call("mechanics")).contains("r16-lab-wall-jump-2"))
	check("host lab toggles reach the r16 runner", game.call("lab_moves") == {"slide": true, "wall_jump": true, "grapple": true})
	var lab := lab_state()
	check("motion state experiment reports r16 version and state", str(lab.version) == "r16-lab-moves-1" and lab.wall_jump.has("budget") and lab.slide.has("armed"), lab.keys())
	check("actions are the inherited ones (Shift slide, E grapple)", InputMap.has_action("r15_slide") and InputMap.has_action("r15_grapple"))
	note("mechanics", game.call("mechanics"))

# --- parity ---------------------------------------------------------------------------------

## r15's parity input (strafe hops with the mouse, a crouch hop, then optional air Space against
## the hub's east rack), plus optional Shift presses in the air: the same events on each runner.
func _parity_run(kind: String, moves_off: bool, wall_presses: bool, shift_presses: bool) -> Array:
	await make_game(kind)
	if moves_off:
		for k: String in ["1", "2", "3"]:
			await tap(k)
	await tap("r")
	await ticks(4)
	begin("parity_%s_%s_%s%s" % [kind, "off" if moves_off else "on", "walls" if wall_presses else "open", "_shift" if shift_presses else ""], "make_game(%s), %sR, 4 ticks" % [kind, "keys 1 2 3, " if moves_off else ""])
	key("w", true)
	key("space", true)
	for t: int in 520:
		if t == 90:
			key("w", false)
			key("a", true)
		if t >= 90 and t < 200:
			look(-6.0)
		if t == 200:
			key("a", false)
			key("d", true)
		if t >= 200 and t < 310:
			look(6.0)
		if t == 260:
			key("ctrl", true)
		if t == 300:
			key("ctrl", false)
		if shift_presses and (t == 150 or t == 240):
			key("shift", true)
		if shift_presses and (t == 156 or t == 246):
			key("shift", false)
		if t == 310:
			key("d", false)
			key("space", false)
		if wall_presses and t == 330:
			key("d", true)
			look(400.0)
		if wall_presses and t >= 360 and t % 12 == 0:
			key("space", true)
		if wall_presses and t >= 360 and t % 12 == 6:
			key("space", false)
		await step()
	return [trace(ep), finish_episode()]

func _group_parity() -> void:
	var approved: Array = await _parity_run("source", false, false, false)
	var on: Array = await _parity_run("r16", false, false, false)
	var r15: Array = await _parity_run("r15", false, false, false)
	check("r16, moves on, ordinary input: every tick equals the approved runner", same(approved[0], on[0]), first_diff(approved[0], on[0]))
	check("r16 and r15 lab runners agree on ordinary input", same(r15[0], on[0]), first_diff(r15[0], on[0]))
	check("no lab event on the ordinary run", rows_with(on[1], "wall_jump").is_empty() and rows_with(on[1], "slide").is_empty() and rows_with(on[1], "wall_guard").is_empty())
	var approved_walls: Array = await _parity_run("source", true, true, true)
	var off: Array = await _parity_run("r16", true, true, true)
	check("r16, moves off, air Space at a wall and air Shift: every tick equals the approved runner", same(approved_walls[0], off[0]), first_diff(approved_walls[0], off[0]))
	check("moves off: no lab event at all", (off[1].rows as Array).all(func(r: Dictionary) -> bool: return (r.lab.events as Array).is_empty()))
	var hops := (on[1].rows as Array).filter(func(r: Dictionary) -> bool: return "jump" in r.ev).size()
	var crouch := (on[1].rows as Array).filter(func(r: Dictionary) -> bool: return r.duck == true).size()
	check("the parity run hopped and crouch-hopped", hops > 3 and crouch > 10, [hops, crouch])
	# disabled input: input_enabled false is the inherited early return, the body does not move.
	await make_game("r16")
	await ticks(4)
	var body := runner()
	body.set("input_enabled", false)
	begin("parity_disabled", "make_game(r16), input_enabled false (the host's pause/menu state)")
	var at := feet()
	key("w", true)
	key("space", true)
	key("shift", true)
	await ticks(40)
	var still := feet() == at and (lab_state().events as Array).is_empty() and not bool(lab_state().slide.armed)
	finish_episode()
	body.set("input_enabled", true)
	check("disabled input: no motion and no lab state change", still, [at, feet()])

# --- wall jump: the A/D defect --------------------------------------------------------------

## from the normal spawn: a circle strafe (the other side key) builds speed, it exits heading -z
## along a labelled fixture wall 3 m to the side (west for A, east for D), then the side key toward
## the wall with the mouse turning gently drifts the flight into it. at contact Space is released
## and pressed again with the side key still held and the mouse still turning.
func _wall_ad_live(side: String) -> Dictionary:
	await make_game("r16")
	await tap("r")
	await ticks(4)
	var sign := -1.0 if side == "a" else 1.0
	var wall_x := sign * 3.0
	_fixture_wall(side)
	begin("wall_ad_plan_" + side, "make_game(r16), R, 4 ticks: normal spawn standstill; fixture wall r16_fixture_wall_%s, face x = %.1f, z 0..-24" % [side, wall_x])
	var exit := await circle_build("d" if side == "a" else "a", 330.0, 0.0)
	var reach := func() -> bool: return absf(feet().x - wall_x) - HALF_HULL < 4.0 * U and not grounded()
	var hit := await drift(side, 4.0, reach, 600) if exit >= 0 else -1
	var press := -1
	if hit >= 0:
		key("space", false)
		look(sign * 4.0)
		await step()
		key("space", true)
		press = int(ep.tick)
		for t: int in 96:
			look(sign * 4.0)
			await step()
	var done := finish_episode()
	done["press"] = press
	done["side"] = side
	done["wall_x"] = wall_x
	done["exit_tick"] = exit
	return done

## the labelled fixture wall for the A/D drift: a 0.6 m thick, 6 m tall, 24 m long slab whose
## inner face is x = -3 (A, west) or x = 3 (D, east), from z 0 to -24.
func _fixture_wall(side: String) -> void:
	var face := -3.0 if side == "a" else 3.0
	var lo := Vector3(face - 0.6 if side == "a" else face, -1.0, -24.0)
	fixture("wall_" + side, box_points(lo, lo + Vector3(0.6, 7.0, 24.0)))

## replays the planned events on `kind`, swapping the keys after the press for `after`.
func _wall_ad_replay(plan: Dictionary, kind: String, after: String, moves_off: bool = false) -> Dictionary:
	await make_game(kind)
	if moves_off:
		await tap("2")
	await tap("r")
	await ticks(4)
	_fixture_wall(plan.side)
	var name := "wall_ad_%s_%s_%s%s" % [plan.side, kind, after, "_off" if moves_off else ""]
	begin(name, "make_game(%s)%s, R, 4 ticks; events of %s" % [kind, ", key 2" if moves_off else "", plan.name])
	var press := int(plan.press)
	var events: Array = []
	for entry: Dictionary in plan.events:
		if int(entry.tick) <= press or after == "hold":
			events.append(entry)
		else:
			var kept: Array = (entry.sent as Array).filter(func(i: Dictionary) -> bool: return not i.has("mouse") and i.get("key", "") == "space")
			if not kept.is_empty():
				events.append({"tick": entry.tick, "sent": kept})
	if after == "w":
		# from the tick after the press: side key up, W down, no more turning.
		events.append({"tick": press + 1, "sent": [{"key": plan.side, "edge": "release"}, {"key": "w", "edge": "press"}]})
	await replay(events, press + 96)
	var done := finish_episode()
	done["press"] = press
	done["side"] = plan.side
	done["wall_x"] = plan.wall_x
	return done

## measured from the rows: distance of the hull side from the wall face, m, and travel.
func _wall_measure(done: Dictionary) -> Dictionary:
	var rows: Array = done.rows
	var press := int(done.press)
	var wall_x: float = done.wall_x
	var gap := func(r: Dictionary) -> float: return absf((r.p as Vector3).x - wall_x) - HALF_HULL
	var at := press
	var peak_25 := 0.0
	var peak_50 := 0.0
	var out_25 := 0.0
	for r: Dictionary in rows:
		var t := int(r.t)
		if t < at:
			continue
		if t <= at + 32:
			peak_25 = maxf(peak_25, gap.call(r))
			out_25 += -signf(wall_x) * (r.disp as Vector3).x
		if t <= at + 64:
			peak_50 = maxf(peak_50, gap.call(r))
	var before: Dictionary = rows[maxi(press - 1, 0)]
	var p_row: Dictionary = rows[press]
	var r32: Dictionary = rows[mini(press + 32, rows.size() - 1)]
	var r64: Dictionary = rows[mini(press + 64, rows.size() - 1)]
	var along_before := absf((before.v as Vector3).z) / U
	var top := -INF
	for r: Dictionary in rows.slice(press, mini(press + 64, rows.size())):
		top = maxf(top, (r.p as Vector3).y)
	var wj: Dictionary = p_row.get("lab", {}).get("wj", {})
	return {"impulse": wj, "along_032_u": absf((r32.v as Vector3).z) / U, "gap_before_m": gap.call(before), "gap_peak_025_m": peak_25, "gap_peak_050_m": peak_50, "gap_025_m": gap.call(r32), "gap_050_m": gap.call(r64),
		"outward_travel_025_m": out_25, "speed_before_u": hspeed(before.v), "speed_press_u": hspeed(p_row.v), "speed_050_u": hspeed(r64.v),
		"along_before_u": along_before, "along_press_u": absf((p_row.v as Vector3).z) / U, "rise_050_m": top - (before.p as Vector3).y,
		"wall_jump": "wall_jump" in p_row.get("lab", {}).get("events", []), "guard_ticks": rows.filter(func(r: Dictionary) -> bool: return r.has("lab") and "wall_guard" in r.lab.events).size(),
		"guard_u": _guard_total(rows), "held_side": done.side in p_row.held}

func _guard_total(rows: Array) -> float:
	var total := Vector3.ZERO
	for r: Dictionary in rows:
		if r.has("lab"):
			total += r.lab.imp.get("wall_guard", Vector3.ZERO)
	return total.length()

func _group_wall_ad() -> void:
	for side: String in ["a", "d"]:
		var plan := await _wall_ad_live(side)
		check("%s: an earned strafe flight drifted into the %s fixture wall and Space was pressed there" % [side.to_upper(), "west" if side == "a" else "east"], int(plan.press) > 0, plan.press)
		if int(plan.press) <= 0:
			continue
		var r16_hold := await _wall_ad_replay(plan, "r16", "hold")
		var r15_hold := await _wall_ad_replay(plan, "r15", "hold")
		var r15_w := await _wall_ad_replay(plan, "r15", "w")
		var r16_w := await _wall_ad_replay(plan, "r16", "w")
		var r16_off := await _wall_ad_replay(plan, "r16", "hold", true)
		var m := {"r16_hold": _wall_measure(r16_hold), "r15_hold": _wall_measure(r15_hold), "r15_w": _wall_measure(r15_w), "r16_w": _wall_measure(r16_w), "r16_off": _wall_measure(r16_off)}
		note("measure_" + side, m)
		var pre := int(plan.press)
		check("%s: replays agree up to the press on every runner" % side, first_diff(trace(r16_hold), trace(r15_hold)) >= pre and first_diff(trace(r16_hold), trace(r16_off)) >= pre,
			[first_diff(trace(r16_hold), trace(r15_hold)), first_diff(trace(r16_hold), trace(r16_off)), pre])
		check("%s: the replay is the plan on the r16 runner, tick for tick" % side, same(trace(plan), trace(r16_hold)), first_diff(trace(plan), trace(r16_hold)))
		check("%s: speed was earned (>= 300 u/s at the wall)" % side, float(m.r16_hold.speed_before_u) >= 300.0, m.r16_hold.speed_before_u)
		check("%s: the side key was still held at the press" % side, bool(m.r16_hold.held_side) and bool(m.r15_hold.held_side))
		check("%s: r15 fires a wall jump with the key held" % side, bool(m.r15_hold.wall_jump))
		check("%s: r15 old failure reproduced: held key pulls back within 0.25 s (peak < 0.25 m)" % side, float(m.r15_hold.gap_peak_025_m) < 0.25, m.r15_hold)
		check("%s: r15 with W along the wall works (peak > 0.6 m)" % side, float(m.r15_w.gap_peak_050_m) > 0.6, m.r15_w)
		check("%s: r16 fires a wall jump with the key held" % side, bool(m.r16_hold.wall_jump))
		check("%s: r16 kicks off with the key held (peak > 1.0 m in 0.25 s)" % side, float(m.r16_hold.gap_peak_025_m) > 1.0, m.r16_hold)
		check("%s: r16 actual outward travel matches the kick (> 1.0 m in 0.25 s)" % side, float(m.r16_hold.outward_travel_025_m) > 1.0, m.r16_hold.outward_travel_025_m)
		check("%s: r16 guard worked only inside its window" % side, int(m.r16_hold.guard_ticks) > 0 and int(m.r16_hold.guard_ticks) <= 32, m.r16_hold.guard_ticks)
		var imp: Dictionary = m.r16_hold.impulse
		check("%s: r16 kick kept the along-wall (tangent) speed in full" % side, not imp.is_empty() and float(imp.tangent_after_u) >= float(imp.tangent_before_u) - 0.01, imp)
		check("%s: r16 along-wall speed after 0.25 s no lower than the same keys without the kick" % side, float(m.r16_hold.along_032_u) >= float(m.r16_off.along_032_u) - 5.0, [m.r16_hold.along_032_u, m.r16_off.along_032_u])
		check("%s: r16 with W still works" % side, float(m.r16_w.gap_peak_050_m) > 0.6, m.r16_w)
		check("%s: r16 wall jump off: no wall jump, stays on the wall" % side, not bool(m.r16_off.wall_jump) and float(m.r16_off.gap_peak_050_m) < 0.25, m.r16_off)
		check("%s: r16 rose higher than without the wall jump" % side, float(m.r16_hold.rise_050_m) > float(m.r16_off.rise_050_m) + 0.3, [m.r16_hold.rise_050_m, m.r16_off.rise_050_m])
		var gain := float(m.r16_hold.speed_press_u) - float(m.r16_hold.speed_before_u)
		var kick_gain := hspeed(Vector3(imp.get("v_after_u", Vector3.ZERO)) * U) - hspeed(Vector3(imp.get("v_before_u", Vector3.ZERO)) * U)
		check("%s: r16 kick's horizontal gain bounded (<= 80 u/s, or up to 340)" % side, kick_gain <= 80.01 or hspeed(Vector3(imp.get("v_after_u", Vector3.ZERO)) * U) <= 340.01, kick_gain)

# --- wall jump: rules ----------------------------------------------------------------------

## the wall chamber station, played without W in the air: run in on W, jump, let go of W and hold
## A into the west face; at the top press Space with A still held, switch to D `react` ticks
## later, press Space at the east face with D held, then W onto the mezzanine. `third` adds a
## press at the mezzanine face. returns the episode.
func _chamber_ad(kind: String, react: int = 6, third: bool = false) -> Dictionary:
	await make_game(kind)
	await tap("r")
	game.call("practise_stage", 2)
	await ticks(4)
	begin("wall_chamber_ad_%s%s" % [kind, "_third" if third else ""], "make_game(%s), R, practise_stage(2): Wall chamber" % kind)
	key("w", true)
	await until(func() -> bool: return feet().z < -45.0, 900)
	key("a", true)
	await until(func() -> bool: return feet().z < -50.3, 900)
	key("space", true)
	await step()
	key("space", false)
	key("w", false)
	var stage := 0
	var east := 1.6 - HALF_HULL - 0.03
	for t: int in 500:
		await step()
		var airborne := not grounded()
		var vy := runner().velocity.y / U
		if stage == 0 and airborne and vy < 30.0:
			key("space", true)
			await step()
			key("space", false)
			await ticks(react - 1)
			key("a", false)
			key("d", true)
			stage = 1
		elif stage == 1 and airborne and feet().x > east:
			key("space", true)
			await step()
			key("space", false)
			await ticks(react - 1)
			key("d", false)
			key("w", true)
			stage = 2
		elif stage == 2 and third and airborne and feet().z < -55.6:
			key("space", true)
			await step()
			key("space", false)
			stage = 3
		if grounded() and t > 20:
			break
	await ticks(30)
	key("w", false)
	await ticks(10)
	var done := finish_episode()
	done["end"] = feet()
	done["up"] = feet().y > 3.1 and feet().z < -56.0
	return done

func _group_wall_rules() -> void:
	var r16 := await _chamber_ad("r16")
	var r15 := await _chamber_ad("r15")
	note("chamber", {"r16_end": r16.end, "r15_end": r15.end, "r16_jumps": rows_with(r16, "wall_jump").size(), "r15_jumps": rows_with(r15, "wall_jump").size()})
	check("chamber with A then D held: r16 reaches the mezzanine", bool(r16.up), r16.end)
	check("chamber with A then D held: two r16 wall jumps off different faces", rows_with(r16, "wall_jump").size() == 2)
	check("chamber with A then D held: r15 does not reach the mezzanine (the old defect on the station)", not bool(r15.up), r15.end)
	# budget: a third face (the mezzanine wall) in the same flight is refused.
	var third := await _chamber_ad("r16", 6, true)
	var refused := rows_with(third, "wall_refused").map(func(r: Dictionary) -> String: return str(r.lab.refusal))
	check("budget: a third wall in one flight is refused (budget spent)", rows_with(third, "wall_jump").size() == 2 and "budget spent" in refused, refused)
	var contact_rows := (third.rows as Array).filter(func(r: Dictionary) -> bool: return not r.g and int(r.lab.budget) == 0 and not (r.contacts as Array).is_empty())
	check("budget: wall contacts in the air never refill it", contact_rows.size() > 0 and contact_rows.all(func(r: Dictionary) -> bool: return int(r.lab.budget) == 0), contact_rows.size())
	var landed := (third.rows as Array).filter(func(r: Dictionary) -> bool: return r.g and int(r.t) > first_with(third, "wall_jump"))
	check("budget: the landing refills it to 2", not landed.is_empty() and int(landed[0].lab.budget) == 2 and first_with(third, "wall_refill") >= 0)
	await _wall_seam()
	await _wall_spam_echo()
	await _wall_misc()

## two coplanar fixture pieces (a seam at z -3). a kick off the first; when the guard is over the
## actor strafes back hard (A, the mouse turning 40 counts a tick) to the plane over the second
## piece in the same flight and presses there. r16 refuses it (same plane), r15 (keyed by body)
## does not.
func _wall_seam() -> void:
	var plan := {}
	for kind: String in ["r16", "r15"]:
		await make_game(kind)
		await tap("r")
		await ticks(4)
		fixture("seam_1", box_points(Vector3(-3.6, -1.0, -3.0), Vector3(-3.0, 6.0, 0.0)))
		fixture("seam_2", box_points(Vector3(-3.6, -1.0, -24.0), Vector3(-3.0, 6.0, -3.0)))
		begin("wall_seam_" + kind, "make_game(%s), R, 4 ticks; fixture walls r16_fixture_seam_1 (z 0..-3) and _2 (z -3..-24), one plane x = -3" % kind)
		if kind == "r16":
			var exit := await circle_build("d", 330.0, 0.0)
			var reach := func() -> bool: return absf(feet().x + 3.0) - HALF_HULL < 4.0 * U and not grounded()
			var first := await drift("a", 4.0, reach, 600) if exit >= 0 else -1
			if first >= 0:
				key("space", false)
				await step()
				key("space", true)
				await ticks(32)
				var back := func() -> bool: return (absf(feet().x + 3.0) - HALF_HULL < 4.0 * U and feet().z < -3.3) or grounded()
				await drift("a", 40.0, back, 200)
				if not grounded():
					key("space", false)
					await step()
					key("space", true)
			await ticks(30)
			plan = finish_episode()
		else:
			await replay(plan.events, (plan.rows as Array).size())
			var done := finish_episode()
			var refused: Array = rows_with(plan, "wall_refused").filter(func(r: Dictionary) -> bool: return str(r.lab.refusal) == "same wall")
			var r15_jumps: Array = rows_with(done, "wall_jump")
			note("seam", {"r16_jumps": rows_with(plan, "wall_jump").size(), "r16_refused": refused.map(func(r: Dictionary) -> Array: return [r.t, r.p, r.lab.probe_key, r.lab.used]),
				"r15_replay_jumps": r15_jumps.size()})
			check("seam: r16 refuses the second piece of the same plane in the same flight", rows_with(plan, "wall_jump").size() == 1 and not refused.is_empty())
			if not refused.is_empty():
				var r: Dictionary = refused[0]
				# r15's rule refuses only str(wall.key) == the last key (body:normal): a different body passes it.
				check("seam: the refused piece is another body, which r15's key rule would allow", r.lab.probe_key.begins_with("r16_fixture_seam_2") and r.lab.used == ["r16_fixture_seam_1:8:0"], [r.lab.probe_key, r.lab.used])
			check("seam: r15 replay of the same events (its own kick is cancelled, so its path differs) never wall-jumps twice off one body in a row", r15_jumps.size() <= 2)
	# the plane matcher itself, on probe-shaped dictionaries.
	var probe: Node = LAB16.new()
	var used_wall := {"key": "a:8:0", "body": "a", "normal": Vector3(1, 0, 0), "offset_u": -118.0}
	probe.set("walls_used", [used_wall] as Array[Dictionary])
	var same_plane := {"key": "b:8:0", "normal": Vector3(1, 0, 0), "offset_u": -118.0 + 6.0}
	var parallel := {"key": "a:8:0", "normal": Vector3(1, 0, 0), "offset_u": -118.0 + 40.0}
	var facing := {"key": "c:-8:0", "normal": Vector3(-1, 0, 0), "offset_u": 118.0}
	var bent := {"key": "d:7:3", "normal": Vector3(cos(0.6), 0, sin(0.6)), "offset_u": -118.0}
	check("plane matcher: another body on the same plane is the same wall", bool(probe.call("_used_wall", same_plane)))
	check("plane matcher: a parallel face 1 m away is another wall", not bool(probe.call("_used_wall", parallel)))
	check("plane matcher: the facing wall is another wall", not bool(probe.call("_used_wall", facing)))
	check("plane matcher: a face turned 34 degrees is another wall", not bool(probe.call("_used_wall", bent)))
	probe.free()

## one wall: Space spam, OS key repeat echoes while held, held autohop along the wall.
func _wall_spam_echo() -> void:
	await make_game("r16")
	await tap("r")
	game.call("practise_stage", 2)
	await ticks(4)
	begin("wall_spam_echo", "practise_stage(2)")
	key("w", true)
	await until(func() -> bool: return feet().z < -49.0, 400)
	key("w", false)
	key("a", true)
	await until(func() -> bool: return feet().x < -1.19 and speed_u() < 1.0, 300)
	key("space", true)
	await step()
	var floor_row: Dictionary = (ep.rows as Array).back()
	await ticks(2)
	key("space", false)
	# spam: a fresh press every 3 ticks for the whole flight, A held into the west face.
	for i: int in 30:
		key("space", true)
		await ticks(1)
		key("space", false)
		await ticks(2)
		if grounded():
			break
	await until(func() -> bool: return grounded(), 300)
	await ticks(4)
	# echoes: jump, then hold Space in the air against the wall and deliver os repeats.
	key("space", true)
	await ticks(20)
	for i: int in 30:
		echo("space")
		await step()
	var echo_state := lab_state()
	await until(func() -> bool: return grounded(), 300)
	# held autohop along the wall for 2 s: no fresh press, no wall jump.
	await ticks(256)
	key("space", false)
	key("a", false)
	var done := finish_episode()
	var jumps := rows_with(done, "wall_jump")
	var reasons := {}
	for r: Dictionary in rows_with(done, "wall_refused"):
		reasons[str(r.lab.refusal)] = int(reasons.get(str(r.lab.refusal), 0)) + 1
	note("spam", {"jumps": jumps.size(), "refusals": reasons})
	check("a press on the floor beside a wall is the ordinary jump", not ("wall_jump" in floor_row.lab.events) and "jump" in floor_row.ev)
	check("spam at one wall: one wall jump in the flight, every other press refused", jumps.size() == 1 and rows_with(done, "wall_refused").size() >= 8, reasons)
	check("spam at one wall: presses still in reach after the kick are refused as the same wall", int(reasons.get("same wall", 0)) >= 1, reasons)
	check("held Space with os key echoes beside a wall: no wall jump", rows_with(done, "wall_jump").filter(func(r: Dictionary) -> bool: return int(r.t) > int(jumps[0].t) + 10 if not jumps.is_empty() else true).is_empty() and int(echo_state.counts.wall_jump) == 1, echo_state.counts)

## open air and the press buffer, reset and toggle mid-guard, a cooldown between two faces.
func _wall_misc() -> void:
	await make_game("r16")
	await tap("r")
	await ticks(4)
	fixture("buffer_wall", box_points(Vector3(-3.6, -1.0, -24.0), Vector3(-3.0, 6.0, 0.0)))
	begin("wall_open_buffer", "make_game(r16), R, 4 ticks; fixture wall r16_fixture_buffer_wall, face x = -3")
	# open air: a hop in the middle of the hub, a press at the top: refused, the buffer runs out.
	key("space", true)
	await step()
	key("space", false)
	await ticks(30)
	key("space", true)
	await step()
	key("space", false)
	var open_air := lab_state()
	await until(func() -> bool: return grounded(), 200)
	var expired := first_with(ep, "wall_buffer_expired")
	# buffered: drift toward the wall with A, press 4 ticks before reach; it fires on reaching it.
	var exit := await circle_build("d", 300.0, 0.0)
	var pressed_at := -1
	var fired_at := -1
	for t: int in 600:
		var gap := absf(feet().x + 3.0) - HALF_HULL
		var vx := -runner().velocity.x
		if pressed_at < 0 and not grounded() and vx > 0.0 and gap > 6.0 * U and gap < 6.0 * U + vx * 4.0 / 128.0:
			key("space", false)
			await step()
			key("space", true)
			pressed_at = int(ep.tick)
		key("a", true)
		key("d", false)
		look(-4.0)
		await step()
		if pressed_at >= 0 and "wall_jump" in lab_state().events:
			fired_at = int(ep.tick)
			break
		if pressed_at >= 0 and int(ep.tick) - pressed_at > 20:
			break
	var buffered := lab_state()
	# reset mid-guard: R clears the guard, the budget and the used walls.
	await tap("r")
	var after_reset := lab_state()
	await ticks(2)
	var done := finish_episode()
	note("buffer", {"pressed": pressed_at, "fired": fired_at, "exit": exit, "last": buffered.wall_jump.last})
	check("open air: refused, no wall in reach", str(open_air.wall_jump.refusal) == "no wall in reach" and int(open_air.counts.wall_jump) == 0, open_air.wall_jump)
	check("open air: the press buffer runs out (0.1 s) without a jump", expired >= 0)
	check("a press up to 0.1 s early fires on reaching the wall (buffered)", fired_at > pressed_at and fired_at - pressed_at <= 13 and bool(buffered.wall_jump.last.get("buffered", false)), [pressed_at, fired_at])
	check("R mid-guard clears guard, budget and walls", int(after_reset.wall_jump.guard_ticks) == 0 and int(after_reset.wall_jump.budget) == 2 and (after_reset.wall_jump.used as Array).is_empty(), after_reset.wall_jump)
	# toggle mid-guard: key 2 off right after a kick ends the guard; presses do nothing; on again works.
	await make_game("r16")
	await tap("r")
	game.call("practise_stage", 2)
	await ticks(4)
	begin("wall_toggle", "practise_stage(2)")
	key("w", true)
	await until(func() -> bool: return feet().z < -49.0, 400)
	key("w", false)
	key("a", true)
	await until(func() -> bool: return feet().x < -1.19 and speed_u() < 1.0, 300)
	key("space", true)
	await ticks(3)
	key("space", false)
	await ticks(20)
	key("space", true)
	await step()
	key("space", false)
	var kicked := lab_state()
	await tap("2")
	var off_state := lab_state()
	var x_off := feet().x
	await ticks(3)
	key("space", true)
	await step()
	key("space", false)
	var off_press := lab_state()
	await until(func() -> bool: return grounded(), 300)
	await tap("2")
	await ticks(4)
	key("space", true)
	await ticks(3)
	key("space", false)
	await ticks(20)
	key("space", true)
	await step()
	key("space", false)
	var back_on := lab_state()
	key("a", false)
	finish_episode()
	check("toggle: a kick happened before the toggle", int(kicked.counts.wall_jump) == 1 and int(kicked.wall_jump.guard_ticks) > 0, kicked.wall_jump)
	check("toggle off mid-guard ends the guard at once", int(off_state.wall_jump.guard_ticks) == 0 and not bool(off_state.enabled.wall_jump), off_state.wall_jump)
	check("toggle off: a press at the wall does nothing", int(off_press.counts.wall_jump) == 1 and (off_press.events as Array).is_empty(), off_press.events)
	check("toggle on again: the wall jump works after a landing", int(back_on.counts.wall_jump) == 2, back_on.counts)
	note("toggle_x_off", x_off)

# --- slide: the chain -----------------------------------------------------------------------

## from a standstill at the spawn: a circle strafe builds speed and exits heading -z; the side key
## is let go and the flight runs straight on held Space. on the descent of the next flight Shift
## is pressed (`shift_h` m above the floor, descending) and held. `manual` lets go of Space on
## that descent instead (a manual entry). after `slide_ticks` of slide, Space is released and
## pressed again (`hop`), and the run keeps hopping on held Space for `tail` ticks.
func _chain(kind: String, manual: bool, plan: Dictionary = {}, slide_ticks: int = 40, hop: bool = true, tail: int = 160) -> Dictionary:
	await make_game(kind)
	await tap("r")
	await ticks(4)
	var name := "slide_chain_%s_%s" % ["manual" if manual else "autohop", kind]
	begin(name, "make_game(%s), R, 4 ticks: normal spawn standstill%s" % [kind, "" if plan.is_empty() else "; events of " + str(plan.name)])
	if not plan.is_empty():
		await replay(plan.events, (plan.rows as Array).size())
		var replayed := finish_episode()
		replayed["shift_tick"] = plan.shift_tick
		replayed["hop_tick"] = plan.hop_tick
		replayed["exit"] = plan.exit
		return replayed
	var exit := await circle_build("d", 330.0, 0.0)
	key("d", false)
	# one straight hop: wait for its landing, then the next flight's descent.
	await until(func() -> bool: return grounded(), 200)
	await until(func() -> bool: return not grounded(), 10)
	await until(func() -> bool: return runner().velocity.y < 0.0 and feet().y < 0.45, 200)
	key("shift", true)
	if manual:
		key("space", false)
	var shift_tick := int(ep.tick)
	await until(func() -> bool: return grounded(), 100)
	await ticks(slide_ticks)
	if hop:
		key("space", false)
		await step()
		key("space", true)
	var hop_tick := int(ep.tick)
	await step()
	key("shift", false)
	await ticks(tail)
	key("space", false)
	var done := finish_episode()
	done["exit"] = exit
	done["shift_tick"] = shift_tick
	done["hop_tick"] = hop_tick
	return done

## measured from the rows around the landing slide: landing speed, the slide's actual travel speed
## (displacement / dt, not the stored velocity), jumps during the slide, the hop's takeoff speed.
func _slide_measure(done: Dictionary) -> Dictionary:
	var rows: Array = done.rows
	var land := -1
	for r: Dictionary in rows:
		if int(r.t) >= int(done.get("shift_tick", 0)) and "land" in r.ev:
			land = int(r.t)
			break
	var start := first_with(done, "slide_landing")
	var out := {"land_tick": land, "slide_tick": start}
	if land < 0:
		return out
	out["landing_speed_u"] = hspeed(rows[land].v)
	out["landing_actual_u"] = hspeed(rows[land].disp * 128.0)
	var jumps_between: Array = []
	var travel: Array = []
	var ducked := true
	var grounded_all := true
	var end := start
	if start >= 0:
		for i: int in range(start, rows.size()):
			var r: Dictionary = rows[i]
			if not bool(r.lab.slide):
				break
			end = i
			travel.append(hspeed(r.disp * 128.0))
			ducked = ducked and r.duck == true
			grounded_all = grounded_all and bool(r.g)
	for i: int in range(land + 1, rows.size()):
		if "jump" in rows[i].ev:
			jumps_between.append(int(rows[i].t))
	out["first_jump_after_land"] = jumps_between[0] if not jumps_between.is_empty() else -1
	out["slide_ticks"] = travel.size()
	out["slide_actual_first_u"] = travel[0] if not travel.is_empty() else -1.0
	out["slide_actual_last_u"] = travel.back() if not travel.is_empty() else -1.0
	out["slide_ducked"] = ducked
	out["slide_grounded"] = grounded_all
	var hop := int(out.first_jump_after_land)
	if hop >= 0:
		out["hop_takeoff_u"] = hspeed(rows[hop].v)
		out["hop_actual_u"] = hspeed(rows[hop].disp * 128.0)
		out["hop_events"] = rows[hop].lab.events
		var flights := 0
		for i: int in range(hop + 1, rows.size()):
			if "jump" in rows[i].ev:
				flights += 1
		out["hops_after"] = flights
	return out

func _group_slide_chain() -> void:
	var auto16 := await _chain("r16", false)
	var auto15 := await _chain("r15", false, auto16)
	var manual16 := await _chain("r16", true)
	var manual15 := await _chain("r15", true, manual16)
	var m := {"auto16": _slide_measure(auto16), "auto15": _slide_measure(auto15), "manual16": _slide_measure(manual16), "manual15": _slide_measure(manual15)}
	note("measure", m)
	for pair: Array in [["autohop", auto16, m.auto16], ["manual", manual16, m.manual16]]:
		var d: Dictionary = pair[1]
		var x: Dictionary = pair[2]
		var label: String = pair[0]
		check("%s: speed earned from the standstill (>= 330 u/s at the circle exit)" % label, int(d.exit) > 0)
		check("%s: Shift armed in the air on the way down" % label, first_with(d, "slide_armed") >= 0 and first_with(d, "slide_armed") < int(x.land_tick))
		check("%s: the landing became a slide on the next tick" % label, int(x.slide_tick) == int(x.land_tick) + 1, [x.land_tick, x.slide_tick])
		check("%s: no jump between the landing and the deliberate hop" % label, int(x.first_jump_after_land) > int(x.slide_tick) + 30, x.first_jump_after_land)
		check("%s: slide entered at the landing's speed (actual travel within 2%%)" % label, float(x.slide_actual_first_u) >= 0.98 * float(x.landing_speed_u), [x.landing_speed_u, x.slide_actual_first_u])
		check("%s: slide on the ground with the duck hull throughout" % label, bool(x.slide_ducked) and bool(x.slide_grounded) and int(x.slide_ticks) >= 30, [x.slide_ducked, x.slide_grounded, x.slide_ticks])
		check("%s: the fresh Space press hopped out at the slide's speed" % label, float(x.get("hop_takeoff_u", 0.0)) >= 0.98 * float(x.slide_actual_last_u) and "slide_end" in x.get("hop_events", []), [x.get("hop_takeoff_u"), x.slide_actual_last_u])
		check("%s: hopping continues on held Space after the slide" % label, int(x.get("hops_after", 0)) >= 1, x.get("hops_after"))
	check("autohop: Space was held into the landing and ignored", rows_with(auto16, "hop_held_ignored").size() > 0 and "space" in (auto16.rows as Array)[int(m.auto16.land_tick)].held)
	check("manual: Space was up at the landing, nothing to ignore", rows_with(manual16, "hop_held_ignored").is_empty() and not ("space" in (manual16.rows as Array)[int(m.manual16.land_tick)].held))
	check("r15 replays reached the same landing tick", int(m.auto15.land_tick) == int(m.auto16.land_tick) and int(m.manual15.land_tick) == int(m.manual16.land_tick), [m.auto15.land_tick, m.manual15.land_tick])
	# the old failure on r15, same events.
	check("r15 old failure: Shift in the air is refused (airborne)", rows_with(auto15, "slide_refused").size() >= 1 and rows_with(auto15, "slide").is_empty())
	check("r15 old failure: held Space hops straight off the landing", int(m.auto15.first_jump_after_land) == int(m.auto15.land_tick) + 1, [m.auto15.land_tick, m.auto15.first_jump_after_land])
	check("r15 old failure, manual entry: no slide either", rows_with(manual15, "slide").is_empty())
	check("replays match the plans up to the landing", first_diff(trace(auto16), trace(auto15)) >= int(m.auto16.land_tick) and first_diff(trace(manual16), trace(manual15)) >= int(m.manual16.land_tick))
	await _slide_timing()

## late press (the tick after the landing), the arm buffer, the entry-tick press, held Space after a
## released slide.
func _slide_timing() -> void:
	# late: Shift on the tick right after a landing with Space held.
	await make_game("r16")
	await tap("r")
	await ticks(4)
	begin("slide_late_press", "make_game(r16), R, 4 ticks")
	key("w", true)
	await ticks(60)
	key("space", true)
	await until(func() -> bool: return not grounded(), 20)
	await until(func() -> bool: return grounded(), 200)
	key("shift", true)
	await ticks(20)
	var late := lab_state()
	key("shift", false)
	await ticks(4)
	finish_episode()
	check("a Shift press on the tick after the landing slides (late grace), Space held", int(late.counts.slide_landing) == 1 and bool(late.slide.last_landing.late), late.slide)
	# entry tick fresh press: manual descent, Space pressed on the slide's first tick: next tick hop.
	await tap("r")
	await ticks(4)
	begin("slide_entry_press", "R, 4 ticks")
	key("w", true)
	await ticks(60)
	key("space", true)
	await until(func() -> bool: return not grounded(), 20)
	key("space", false)
	await until(func() -> bool: return runner().velocity.y < 0.0, 200)
	key("shift", true)
	await until(func() -> bool: return grounded(), 200)
	key("space", true)
	await step()
	var entry: Dictionary = (ep.rows as Array).back()
	await step()
	var next: Dictionary = (ep.rows as Array).back()
	key("space", false)
	key("shift", false)
	await ticks(60)
	finish_episode()
	check("a fresh Space on the entry tick: the slide starts, no jump that tick", "slide_landing" in entry.lab.events and not ("jump" in entry.ev) and "hop_deferred" in entry.lab.events, [entry.lab.events, entry.ev])
	check("the deferred press hops on the next tick", "jump" in next.ev and "hop_out_deferred" in next.lab.events, [next.lab.events, next.ev])
	# held Space survives a released slide: Shift up, no hop until Space is pressed again.
	await tap("r")
	await ticks(4)
	begin("slide_release_latch", "R, 4 ticks")
	key("w", true)
	await ticks(60)
	key("space", true)
	await until(func() -> bool: return not grounded(), 20)
	await until(func() -> bool: return runner().velocity.y < 0.0, 200)
	key("shift", true)
	await until(func() -> bool: return grounded(), 200)
	await ticks(12)
	key("shift", false)
	await ticks(40)
	var still := feet().y < 0.05 and grounded()
	var latch := lab_state()
	key("space", false)
	await step()
	key("space", true)
	await ticks(3)
	var hopped := not grounded()
	key("space", false)
	key("w", false)
	var done := finish_episode()
	check("Shift released mid-slide with Space still held: no hop", still and rows_with(done, "slide_end").size() >= 1 and str(latch.slide.end) == "released", [still, latch.slide.end])
	check("then a fresh Space hops", hopped)
	# the arm buffer on a long drop (mezzanine edge into the pit, about 0.9 s down): Shift at the
	# apex expires before the landing; Shift 0.2 s before the landing slides on the pit floor.
	for late_arm: bool in [false, true]:
		await tap("r")
		game.call("practise_stage", 3)
		await ticks(4)
		begin("slide_arm_%s" % ("near_landing" if late_arm else "expiry"), "R, practise_stage(3): Grapple gap, a drop into the pit catch")
		key("w", true)
		await until(func() -> bool: return feet().z < -69.6, 400)
		key("space", true)
		await step()
		key("space", false)
		if late_arm:
			await until(func() -> bool: return runner().velocity.y < 0.0 and feet().y < -4.0 + 0.5 * 20.32 * 0.04 + absf(runner().velocity.y) * 0.2, 300)
		else:
			await until(func() -> bool: return runner().velocity.y <= 0.0 and not grounded(), 200)
		key("shift", true)
		var armed_at := int(ep.tick)
		await until(func() -> bool: return grounded(), 300)
		var landed_at := int(ep.tick)
		await ticks(4)
		var arm_state := lab_state()
		key("shift", false)
		key("w", false)
		var arm_done := finish_episode()
		note("arm_" + ("near" if late_arm else "apex"), {"armed": armed_at, "landed": landed_at, "y": feet().y, "disarm": arm_state.slide.disarm})
		if late_arm:
			check("arm buffer: Shift 0.2 s before a long drop's landing slides on the pit floor", rows_with(arm_done, "slide_landing").size() == 1 and feet().y < -3.5, [arm_state.slide.last_landing, feet()])
		else:
			check("arm buffer: armed at the apex of a long drop (> 0.40 s down), it expires before the landing", rows_with(arm_done, "slide_landing").is_empty() and str(arm_state.slide.disarm) == "buffer expired" and landed_at - armed_at > 52, [arm_state.slide.disarm, landed_at - armed_at, feet()])

# --- slide: world ---------------------------------------------------------------------------

## the slide lane from its checkpoint: run, hop, a landing slide just before the rack mouth with
## Space held, under the rack, a fresh Space at the run-out over the trench.
func _lane(kind: String, plan: Dictionary = {}, release_under: bool = false) -> Dictionary:
	await make_game(kind)
	await tap("r")
	game.call("practise_stage", 1)
	await ticks(4)
	var name := "slide_lane_%s%s" % [kind, "_release" if release_under else ""]
	begin(name, "make_game(%s), R, practise_stage(1)%s" % [kind, "" if plan.is_empty() else "; events of " + str(plan.name)])
	if not plan.is_empty():
		await replay(plan.events, (plan.rows as Array).size())
		return finish_episode()
	key("w", true)
	await until(func() -> bool: return feet().z < -15.7, 400)
	key("space", true)
	await until(func() -> bool: return not grounded(), 20)
	# hold Space; arm on the descent of the flight that lands just short of the mouth.
	await until(func() -> bool: return not grounded() and runner().velocity.y < 0.0 and feet().z < -17.5 and feet().y < 0.5, 400)
	key("shift", true)
	await until(func() -> bool: return grounded(), 200)
	var blocked := false
	var embedded := 0
	if release_under:
		await until(func() -> bool: return feet().z < -24.0, 300)
		key("shift", false)
		for t: int in 200:
			await step()
			blocked = blocked or bool(runner().get("stand_blocked"))
			embedded += 0 if clear_now() else 1
			if feet().z < -27.8 or feet().y < -0.5:
				break
	else:
		await until(func() -> bool: return feet().z < -27.45, 400)
		key("space", false)
		await step()
		key("space", true)
		await step()
		key("shift", false)
	await ticks(150)
	key("space", false)
	key("w", false)
	var done := finish_episode()
	done["blocked"] = blocked
	done["embedded"] = embedded
	return done

func _group_slide_world() -> void:
	var lane16 := await _lane("r16")
	var lane15 := await _lane("r15", lane16)
	var under := (lane16.rows as Array).filter(func(r: Dictionary) -> bool: return (r.p as Vector3).z < -22.5 and (r.p as Vector3).z > -26.5)
	var end16: Vector3 = (lane16.rows as Array).back().p
	var end15: Vector3 = (lane15.rows as Array).back().p
	note("lane", {"r16_end": end16, "r15_end": end15, "under_ticks": under.size(), "landing": _slide_measure(lane16)})
	check("roof: a landing slide with Space held carries under the 60 u rack, ducked and on the floor", under.size() > 10 and under.all(func(r: Dictionary) -> bool: return r.duck == true and r.g))
	check("roof: held Space never hopped under the rack", under.all(func(r: Dictionary) -> bool: return not ("jump" in r.ev)))
	check("roof: the fresh press at the run-out hopped the trench onto the deck", end16.z < -30.6 and end16.y > -0.5, end16)
	check("roof: r15 with the same events never slides and does not get through", rows_with(lane15, "slide").is_empty() and not (end15.z < -30.6 and end15.y > -0.5), end15)
	var release := await _lane("r16", {}, true)
	check("roof: Shift released under the rack waits for room (stand blocked), never embedded", bool(release.blocked) and int(release.embedded) == 0, [release.blocked, release.embedded])
	await _slide_edge()
	await _slide_false_floor()
	await _slide_reset_toggle()
	await _slide_crouch_hop()

## the lane end: a landing slide with Space held runs off the run-out into the trench, no hop.
func _slide_edge() -> void:
	await make_game("r16")
	await tap("r")
	game.call("practise_stage", 1)
	await ticks(4)
	begin("slide_edge", "R, practise_stage(1)")
	key("w", true)
	await until(func() -> bool: return feet().z < -16.6, 400)
	key("space", true)
	await until(func() -> bool: return not grounded(), 20)
	await until(func() -> bool: return not grounded() and runner().velocity.y < 0.0 and feet().z < -17.5 and feet().y < 0.5, 400)
	key("shift", true)
	var air_duck := 0
	for t: int in 400:
		await step()
		var duck: Dictionary = (runner().call("get_motion_state") as Dictionary).duck
		if "duck_air" in duck.events or "unduck_air" in duck.events:
			air_duck += 1
		if feet().y < -2.0 and grounded():
			break
	await ticks(10)
	var state := lab_state()
	key("shift", false)
	key("space", false)
	var done := finish_episode()
	var ends := rows_with(done, "slide_end").map(func(r: Dictionary) -> String: return str(r.lab.end))
	check("edge: the slide ends airborne off the run-out", "airborne" in ends, ends)
	check("edge: no air hull change from the slide", air_duck == 0, air_duck)
	var trench_hop := (done.rows as Array).any(func(r: Dictionary) -> bool: return (r.p as Vector3).y < -1.9 and "jump" in r.ev)
	check("edge: in the trench, held Space hops again (the flight spent the ignore)", trench_hop and not bool(state.slide.held_space_ignored))

## false floor: armed onto a steep fixture wedge (normal y 0.5, not walkable): no landing, no slide
## while on it. stale arm: an arm released before landing never carries to a later landing.
func _slide_false_floor() -> void:
	await make_game("r16")
	await tap("r")
	await ticks(4)
	# a 60 degree face (normal y 0.5, below the 0.7 walkable limit) rising from z 0.3 to z -1.2.
	var wedge := PackedVector3Array([Vector3(-3, 0, 0.3), Vector3(3, 0, 0.3), Vector3(-3, 0, -1.2), Vector3(3, 0, -1.2), Vector3(-3, 2.598, -1.2), Vector3(3, 2.598, -1.2)])
	fixture("steep_wedge", wedge)
	begin("slide_false_floor", "R, 4 ticks; fixture r16_fixture_steep_wedge: 60 degree face, foot z 0.3, top z -1.2 at 2.6 m, x -3..3")
	key("w", true)
	await ticks(40)
	key("space", true)
	await until(func() -> bool: return not grounded(), 20)
	key("space", false)
	await until(func() -> bool: return runner().velocity.y < 0.0, 200)
	key("shift", true)
	var on_wedge: Array = []
	for t: int in 200:
		await step()
		var contacts: Array = (runner().call("get_motion_state") as Dictionary).contacts
		for c: Dictionary in contacts:
			var n: Variant = c.get("normal")
			if n is Vector3 and (n as Vector3).y > 0.3 and (n as Vector3).y < 0.7:
				on_wedge.append(int(ep.tick))
		if grounded():
			break
	await ticks(10)
	key("shift", false)
	key("w", false)
	var done := finish_episode()
	var slides_on_wedge := rows_with(done, "slide").filter(func(r: Dictionary) -> bool: return int(r.t) in on_wedge)
	note("false_floor", {"wedge_ticks": on_wedge.size(), "slides": rows_with(done, "slide").size()})
	check("false floor: the flight touched the steep wedge", not on_wedge.is_empty(), on_wedge.size())
	check("false floor: no landing and no slide while on the steep face", slides_on_wedge.is_empty() and (done.rows as Array).filter(func(r: Dictionary) -> bool: return int(r.t) in on_wedge and "land" in r.ev).is_empty())
	# stale arm: arm, release Shift before landing, land, hop again: no slide on either landing.
	await make_game("r16")
	await tap("r")
	await ticks(4)
	begin("slide_stale_arm", "make_game(r16), R, 4 ticks (no fixture)")
	key("w", true)
	await ticks(60)
	key("space", true)
	await until(func() -> bool: return not grounded(), 20)
	await until(func() -> bool: return runner().velocity.y < 0.0, 200)
	key("shift", true)
	await ticks(5)
	key("shift", false)
	await until(func() -> bool: return grounded(), 200)
	await until(func() -> bool: return not grounded(), 20)
	await until(func() -> bool: return grounded(), 200)
	await ticks(3)
	key("space", false)
	key("w", false)
	var stale := finish_episode()
	check("stale arm: released before the landing, no slide on that or the next landing", rows_with(stale, "slide").is_empty() and rows_with(stale, "slide_disarmed").size() == 1)

## reset and toggle while armed, sliding and ignoring held Space.
func _slide_reset_toggle() -> void:
	await make_game("r16")
	await tap("r")
	await ticks(4)
	begin("slide_reset_toggle", "R, 4 ticks")
	key("w", true)
	await ticks(60)
	key("space", true)
	await until(func() -> bool: return not grounded(), 20)
	await until(func() -> bool: return runner().velocity.y < 0.0, 200)
	key("shift", true)
	await ticks(2)
	key("space", false)
	key("w", false)
	await tap("r")
	var reset_armed := lab_state()
	key("shift", false)
	await ticks(4)
	# a landing slide with Space held, then key 1 (slide off): the slide ends, held Space plays.
	key("w", true)
	await ticks(60)
	key("space", true)
	await until(func() -> bool: return not grounded(), 20)
	await until(func() -> bool: return runner().velocity.y < 0.0, 200)
	key("shift", true)
	await until(func() -> bool: return bool(lab_state().slide.active), 200)
	await ticks(5)
	var sliding := lab_state()
	_jumps_at_slide = int(runner().get("jump_count"))
	await tap("1")
	var off := lab_state()
	# a tap advances physics frames without a row, so the hop is read from the runner's jump count.
	await ticks(4)
	var hopped_after_off := int(runner().get("jump_count")) > int(_jumps_at_slide)
	await tap("1")
	key("shift", false)
	key("space", false)
	key("w", false)
	await until(func() -> bool: return grounded(), 200)
	await ticks(4)
	# R while sliding with held Space ignored: everything clears, held Space hops after R.
	key("w", true)
	await ticks(60)
	key("space", true)
	await until(func() -> bool: return not grounded(), 20)
	await until(func() -> bool: return runner().velocity.y < 0.0, 200)
	key("shift", true)
	await until(func() -> bool: return bool(lab_state().slide.active), 200)
	await ticks(4)
	await tap("r")
	var reset_slide := lab_state()
	key("shift", false)
	await ticks(6)
	# R zeroes the motor's jump count; any hop after it shows as a count above zero.
	var hop_after_reset := int(runner().get("jump_count")) > 0
	key("space", false)
	key("w", false)
	finish_episode()
	check("R while armed clears the arm", not bool(reset_armed.slide.armed) and int(reset_armed.counts.slide_armed) == 0, reset_armed.slide)
	check("a landing slide was running with Space held before the toggle", bool(sliding.slide.active) and bool(sliding.slide.held_space_ignored), sliding.slide)
	check("key 1 mid-slide ends it and stops ignoring held Space", not bool(off.slide.active) and not bool(off.slide.held_space_ignored) and not bool(off.enabled.slide), off.slide)
	check("with the slide off, held Space hops again", hopped_after_off)
	check("R mid-slide clears slide, arm and held-Space state", not bool(reset_slide.slide.active) and not bool(reset_slide.slide.held_space_ignored) and not bool(reset_slide.slide.armed), reset_slide.slide)
	check("after R, held Space hops as usual", hop_after_reset)

## Ctrl crouch hops, with and without Shift on other flights: Ctrl never arms or slides.
func _slide_crouch_hop() -> void:
	var traces := {}
	for kind: String in ["source", "r16"]:
		await make_game(kind)
		await tap("r")
		await ticks(4)
		begin("slide_crouch_hop_" + kind, "make_game(%s), R, 4 ticks" % kind)
		key("w", true)
		key("space", true)
		for t: int in 400:
			if t % 96 == 30:
				key("ctrl", true)
			if t % 96 == 70:
				key("ctrl", false)
			if t == 120:
				key("w", false)
				key("d", true)
			if t >= 120:
				look(6.0)
			await step()
		traces[kind] = finish_episode()
	check("Ctrl crouch hops: every tick equal to the approved runner", same(trace(traces.source), trace(traces.r16)), first_diff(trace(traces.source), trace(traces.r16)))
	check("Ctrl crouch hops: no lab event", (traces.r16.rows as Array).all(func(r: Dictionary) -> bool: return (r.lab.events as Array).is_empty()))

# --- combos ---------------------------------------------------------------------------------

func _group_combos() -> void:
	# an armed slide is disarmed by a wall jump; a fresh Shift after the kick lands into a slide.
	await make_game("r16")
	await tap("r")
	game.call("practise_stage", 2)
	await ticks(4)
	begin("combo_wall_slide", "practise_stage(2): Wall chamber")
	key("w", true)
	await until(func() -> bool: return feet().z < -45.0, 900)
	key("a", true)
	await until(func() -> bool: return feet().z < -50.3, 900)
	key("space", true)
	await step()
	key("space", false)
	key("w", false)
	await ticks(4)
	key("shift", true)
	await step()
	await until(func() -> bool: return runner().velocity.y < 30.0, 200)
	key("space", true)
	await step()
	key("space", false)
	var after_kick := lab_state()
	key("shift", false)
	key("a", false)
	await until(func() -> bool: return runner().velocity.y < 0.0 and feet().y < 0.6, 200)
	key("shift", true)
	await until(func() -> bool: return grounded(), 200)
	await ticks(3)
	var landed := lab_state()
	key("shift", false)
	await ticks(10)
	# a landing slide beside a wall: a fresh Space press is a ground hop, never a wall jump.
	finish_episode()
	check("a wall jump disarms a pending slide", int(after_kick.counts.wall_jump) == 1 and not bool(after_kick.slide.armed) and str(after_kick.slide.disarm) == "wall jump", after_kick.slide)
	check("a fresh Shift after the kick lands into a slide", int(landed.counts.slide_landing) == 1 or str(landed.slide.last_landing.get("refusal", "")) == "too slow", landed.slide)
	note("combo_landing", landed.slide.last_landing)
	# a landing slide beside a wall (the chamber's west face): a fresh press is a ground hop.
	await tap("r")
	game.call("practise_stage", 2)
	await ticks(4)
	begin("combo_slide_at_wall", "R, practise_stage(2): Wall chamber, run along the west face")
	key("w", true)
	await until(func() -> bool: return feet().z < -44.8, 600)
	key("a", true)
	await until(func() -> bool: return feet().x < -1.18, 300)
	key("a", false)
	await until(func() -> bool: return feet().z < -46.0, 300)
	key("space", true)
	await step()
	key("space", false)
	await until(func() -> bool: return not grounded() and runner().velocity.y < 0.0, 200)
	key("shift", true)
	await until(func() -> bool: return bool(lab_state().slide.active), 200)
	await ticks(6)
	var wall_gap := absf(feet().x + 1.6) - HALF_HULL
	var probe := (runner().call("_find_wall") as Dictionary)
	key("space", true)
	await step()
	var hop_row: Dictionary = (ep.rows as Array).back()
	key("shift", false)
	await ticks(20)
	key("space", false)
	key("w", false)
	var done := finish_episode()
	note("slide_at_wall", {"gap_m": wall_gap, "probe": probe, "hop": hop_row.lab.events, "landing": rows_with(done, "slide_landing").map(func(r: Dictionary) -> Variant: return r.lab.landing)})
	check("a landing slide beside a wall: the slide came from the landing", rows_with(done, "slide_landing").size() == 1 and bool(rows_with(done, "slide_landing")[0].g))
	check("a landing slide beside a wall: the west face was within reach", wall_gap < 6.0 * U and not probe.is_empty() and (probe.normal as Vector3).x > 0.9, [wall_gap, probe])
	check("a landing slide beside a wall: the fresh press is the ground hop, not a wall jump", "jump" in hop_row.ev and not ("wall_jump" in hop_row.lab.events), [hop_row.lab.events, hop_row.ev])
	check("the landing refilled the wall budget", int(hop_row.lab.budget) == 2)

# --- grapple --------------------------------------------------------------------------------

## r15's grapple station input: pitch at A1, jump off the edge, hold E once the target is valid,
## let go past `release_z` or after `hold_ticks`. recorded on r16, replayed on r15.
func _grapple_attempt(kind: String, name: String, plan: Dictionary = {}, release_z: float = -83.0, hold_ticks: int = -1) -> Dictionary:
	await make_game(kind)
	await tap("r")
	game.call("practise_stage", 3)
	await ticks(4)
	begin("%s_%s" % [name, kind], "make_game(%s), R, practise_stage(3): Grapple gap" % kind)
	if not plan.is_empty():
		await replay(plan.events, (plan.rows as Array).size())
		return finish_episode()
	key("w", true)
	await until(func() -> bool: return feet().z < -69.6, 400)
	key("space", true)
	await ticks(2)
	key("space", false)
	var body := runner()
	var a1 := Vector3(0.0, 10.5, -80.0)
	var to := a1 - (body.global_position + Vector3.UP * float(body.get("_eye_u")) * U)
	var per := deg_to_rad(float(body.get("settings").sensitivity) * 0.022)
	look(wrapf(float(body.get("yaw")) - atan2(-to.x, -to.z), -PI, PI) / per, (float(body.get("pitch")) - atan2(to.y, Vector2(to.x, to.z).length())) / per)
	var held := 0
	var attached_at := -1
	for t: int in 700:
		var target := str(lab_state().grapple.target.get("state", ""))
		if held == 0 and (target == "ok" or t > 30):
			key("e", true)
			held = 1
		await step()
		if bool(lab_state().grapple.attached) and attached_at < 0:
			attached_at = int(ep.tick)
		if held == 1 and ((hold_ticks < 0 and feet().z < release_z) or (hold_ticks >= 0 and attached_at >= 0 and int(ep.tick) - attached_at >= hold_ticks)):
			key("e", false)
			held = 2
		if grounded() and t > 20:
			break
	key("w", false)
	await ticks(30)
	return finish_episode()

func _group_grapple() -> void:
	for spec: Array in [["grapple_swing", -83.0, -1], ["grapple_time", -200.0, -1], ["grapple_short", -83.0, 40]]:
		var r16 := await _grapple_attempt("r16", spec[0], {}, spec[1], spec[2])
		var r15 := await _grapple_attempt("r15", spec[0], r16)
		var state16 := (r16.rows as Array).map(func(r: Dictionary) -> Array: return [r.lab.line, r.lab.anchor, r.lab.release, r.lab.target, r.lab.imp])
		var state15 := (r15.rows as Array).map(func(r: Dictionary) -> Array: return [r.lab.line, r.lab.anchor, r.lab.release, r.lab.target, r.lab.imp])
		var attached := state16.filter(func(x: Array) -> bool: return bool(x[0])).size()
		note(spec[0], {"ticks": (r16.rows as Array).size(), "attached_ticks": attached, "end": (r16.rows as Array).back().p, "release": state16.back()[2]})
		check("%s: the line attached" % spec[0], attached > 20, attached)
		check("%s: same inputs, every tick's position, velocity and view equal on r15 and r16" % spec[0], same(trace(r16), trace(r15)), first_diff(trace(r16), trace(r15)))
		check("%s: same grapple state, anchor, release and impulses every tick" % spec[0], state16 == state15, "differs")
		check("%s: no wall or slide event on the grapple run" % spec[0], rows_with(r16, "wall_jump").is_empty() and rows_with(r16, "slide").is_empty() and rows_with(r16, "wall_guard").is_empty())

func _plain(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR3:
			var v: Vector3 = value
			return [snappedf(v.x, 1e-6), snappedf(v.y, 1e-6), snappedf(v.z, 1e-6)]
		TYPE_VECTOR2:
			var v2: Vector2 = value
			return [v2.x, v2.y]
		TYPE_DICTIONARY:
			var out := {}
			for k: Variant in value:
				out[str(k)] = _plain(value[k])
			return out
		TYPE_ARRAY:
			return (value as Array).map(func(x: Variant) -> Variant: return _plain(x))
		TYPE_FLOAT:
			return snappedf(value, 1e-6)
	return value

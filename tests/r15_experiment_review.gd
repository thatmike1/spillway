extends SceneTree
## independent headless adversarial review of f3f23452; no release or feel acceptance.
## one labelled setup per episode, then only physical key/mouse events, including menu clicks.
## seeded contacts/velocities are diagnostics. normal-spawn route failures are labelled separately.

const MAIN := preload("res://scripts/r15_main.gd")
const LAB := preload("res://scripts/r15_experiment_player.gd")
const SOURCE := preload("res://scripts/r15_source_player.gd")
const U := 0.0254
const CODES := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL, "shift": KEY_SHIFT, "e": KEY_E,
	"r": KEY_R, "f": KEY_F, "esc": KEY_ESCAPE, "f2": KEY_F2, "f3": KEY_F3, "f4": KEY_F4, "f5": KEY_F5, "1": KEY_1, "2": KEY_2, "3": KEY_3}

class LateProbe:
	extends Node
	signal stepped
	func _physics_process(_dt: float) -> void:
		stepped.emit()

var out := ""
var game: Node
var probe: LateProbe
var checks: Array = []
var episodes: Array = []
var ep: Dictionary = {}
var trace: FileAccess
var held := {}
var sent: Array = []
var previous := {}
var travel_error := 0.0
var state_error := 0.0
var embed_ticks := 0
var contact_depths := {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	_run.call_deferred()

func _run() -> void:
	assert(not out.is_empty())
	probe = LateProbe.new()
	probe.process_mode = Node.PROCESS_MODE_ALWAYS
	probe.process_physics_priority = 1000
	root.add_child(probe)
	trace = FileAccess.open(out.path_join("trace.jsonl"), FileAccess.WRITE)
	await contact_cases()
	await grapple_cases()
	await slide_cases()
	await host_cases()
	await mixed_records()
	await drop()
	check("sampled travel equals physical displacement after duck compensation", travel_error < 0.00001, travel_error)
	check("stored motor position/velocity equal the body", state_error < 0.00001, state_error)
	check("no sampled current hull needs recovery beyond 2 mm", embed_ticks == 0, embed_ticks)
	trace.close()
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.ok)
	var summary := {"parent": "f3f23452", "checks": checks, "failed": failed, "episodes": episodes,
		"travel_error_m": travel_error, "state_error": state_error, "embed_ticks": embed_ticks, "contact_depths": contact_depths, "engine": Engine.get_version_info(),
		"limits": "headless source only; labelled setups; no native, rendering, pack, feel or release acceptance"}
	var f := FileAccess.open(out.path_join("summary.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(plain(summary), "  "))
	f.close()
	print("independent lab review: %d checks, %d failed" % [checks.size(), failed.size()])
	quit(0 if failed.is_empty() else 1)

func check(label: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"name": label, "ok": ok, "detail": plain(detail), "episode": ep.get("name", "")})
	print("%s %s: %s" % ["PASS" if ok else "FAIL", label, str(detail).left(700)])

func p() -> CharacterBody3D:
	return game.get("player")

func pos() -> Vector3:
	return p().global_position

func lab() -> Dictionary:
	return (p().call("get_motion_state") as Dictionary).get("experiment", {})

func start(label: String, setup: Dictionary = {}) -> void:
	await drop()
	Engine.physics_ticks_per_second = 128
	game = MAIN.new()
	game.set("map_id", setup.get("map", "experiment"))
	game.set("motor", setup.get("motor", "f2"))
	if setup.get("approved_control", false):
		game.set("source_runner", SOURCE)
	game.set("set_window_title", false)
	game.set("seed_from_r14", false)
	if setup.get("records", false):
		game.set("persist", true)
		game.set("profile_path", out.path_join(label + ".cfg"))
	root.add_child(game)
	await ticks(8)
	if setup.has("feet"):
		# the sole labelled pose/velocity seed, before recording or input for this episode.
		p().call("reset_to", Transform3D(Basis.IDENTITY, setup.feet))
		p().velocity = setup.get("velocity", Vector3.ZERO)
		var s: Dictionary = p().get("state")
		s.position = pos() / U
		s.velocity = p().velocity / U
		s.grounded = bool(setup.get("grounded", false))
		s.ground_normal = Vector3.UP if s.grounded else Vector3.ZERO
		p().set("_current_position", pos())
		p().set("_previous_position", pos())
		if setup.get("duck", false):
			p().call("_update_duck", true, true)
		if setup.get("overrange_line_seed", false):
			p().set("grapple", {"name": "A1", "position": Vector3(0, 10.5, -80)})
			p().set("grapple_length_u", 1181.0)
			p().set("grapple_ticks", 1)
		if setup.has("pitch"):
			p().set("pitch", setup.pitch)
	previous = {}
	ep = {"name": label, "setup": plain(setup), "type": "seeded diagnostic" if setup.has("feet") else "normal spawn input", "ticks": 0,
		"events": {}, "max_y": pos().y, "max_speed_u": 0.0}
	sent = []
	trace.store_line(JSON.stringify({"episode": label, "setup": plain(setup), "initial": snapshot()}))

func drop() -> void:
	if not ep.is_empty():
		episodes.append(ep.duplicate(true))
	ep = {}
	for name: String in held.keys():
		key(name, false)
	held.clear()
	if game != null and is_instance_valid(game):
		paused = false
		root.remove_child(game)
		game.free()
	game = null
	await process_frame

func key(name: String, down: bool) -> void:
	if down == held.has(name):
		return
	var event := InputEventKey.new()
	event.physical_keycode = CODES[name]
	event.keycode = CODES[name]
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if down:
		held[name] = true
	else:
		held.erase(name)
	sent.append({"key": name, "down": down})

func tap(name: String) -> void:
	key(name, true)
	await ticks(1)
	key(name, false)
	await ticks(1)

func mouse(dx: float, dy: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.screen_relative = event.relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	sent.append({"mouse": [dx, dy]})

func aim(point: Vector3) -> void:
	var to := point - (pos() + Vector3.UP * float(p().get("_eye_u")) * U)
	var unit := deg_to_rad(float(p().get("settings").sensitivity) * 0.022)
	mouse(wrapf(float(p().get("yaw")) - atan2(-to.x, -to.z), -PI, PI) / unit,
		(float(p().get("pitch")) - atan2(to.y, Vector2(to.x, to.z).length())) / unit)

func ticks(n: int) -> void:
	for i: int in n:
		await probe.stepped
		if game == null or ep.is_empty():
			continue
		var row := snapshot()
		row["sent"] = sent
		row["episode"] = ep.name
		row["t"] = ep.ticks
		sent = []
		var overlap := KinematicCollision3D.new()
		var hit := p().test_move(p().global_transform, Vector3.ZERO, overlap, 0.0001, true, 4)
		row["overlap"] = {"hit": hit, "recovery_m": overlap.get_travel().length() if hit else 0.0, "contacts": []}
		if hit:
			for j: int in overlap.get_collision_count():
				row.overlap.contacts.append({"normal": overlap.get_normal(j), "body": str((overlap.get_collider(j) as Node).name)})
		trace.store_line(JSON.stringify(plain(row)))
		ep.ticks += 1
		ep.max_y = maxf(float(ep.max_y), pos().y)
		ep.max_speed_u = maxf(float(ep.max_speed_u), p().velocity.length() / U)
		if not row.lab.is_empty():
			for event: String in row.lab.events:
				ep.events[event] = int(ep.events.get(event, 0)) + 1
		if not previous.is_empty() and row.node == previous.node and row.attempt == previous.attempt and row.respawns == previous.respawns and row.motion.has("duck_shift") and int(row.motion.tick) == int(previous.motion.tick) + 1:
			# host attempts/respawns and body/tick identity exclude legitimate spawn placement.
			var physical: Vector3 = row.p - previous.p - row.motion.duck_shift
			travel_error = maxf(travel_error, physical.distance_to(row.motion.displacement))
			state_error = maxf(state_error, pos().distance_to((p().get("state") as Dictionary).position * U))
			state_error = maxf(state_error, p().velocity.distance_to((p().get("state") as Dictionary).velocity * U))
		if not bool(game.get("paused")) and p().has_method("hull_height_u"):
			embed_ticks += int(hit and overlap.get_travel().length() > 0.002)
		contact_depths[ep.name] = maxf(float(contact_depths.get(ep.name, 0)), overlap.get_travel().length() if hit else 0.0)
		previous = row

func snapshot() -> Dictionary:
	var m: Dictionary = p().call("get_motion_state") if p().has_method("get_motion_state") else {}
	return {"node": p().get_instance_id(), "p": pos(), "v": p().velocity, "grounded": p().call("is_grounded"), "motion": m, "lab": m.get("experiment", {}),
		"map": game.get("map_id"), "preset": game.get("preset_id"), "paused": game.get("paused"), "clean": game.get("clean_eligible"),
		"reason": game.get("practice_reason"), "pending": game.get("pending_preset"), "finished": game.get("finished"), "kind": game.get("finish_kind"),
		"key": game.get("course_key"), "held": held.keys(), "attempt": game.get("attempts"), "respawns": game.get("respawn_count")}

func until(cond: Callable, cap: int) -> bool:
	for i: int in cap:
		if cond.call():
			return true
		await ticks(1)
	return cond.call()

func count(event: String) -> int:
	return int(ep.events.get(event, 0))

func contact_cases() -> void:
	# real authored surfaces, no fake collision reports: open floor, rack ceiling, chamber walls.
	for item: Array in [["floor_only", Vector3(0, 0.04, -49), true, 0],
		["wall_near", Vector3(-1.05, 1.0, -49), false, 1],
		["wall_far", Vector3(-1.00, 1.0, -49), false, 0]]:
		await start(item[0], {"feet": item[1], "grounded": item[2]})
		key("space", true)
		await ticks(1)
		key("space", false)
		await ticks(2)
		check(item[0] + " wall eligibility", count("wall_jump") == item[3], lab().wall_jump)
		await ticks(3)
		key("space", true)
		await ticks(1)
		key("space", false)
		if item[0] == "wall_near":
			check("near wall second press respects cooldown or distance", count("wall_jump") == 1, lab().wall_jump)
	# a real-input flight, repeated presses on one face cannot buy repeated height.
	await start("wall_repeats", {"feet": Vector3(-1.19, 0.04, -49), "grounded": true})
	key("a", true)
	await tap("space")
	for i: int in 40:
		await ticks(2)
		await tap("space")
	check("same-face spam bounded while floor contact resets flights", count("wall_jump") <= 3, {"events": ep.events, "max_y": ep.max_y})
	await start("wall_pressure_approved_control", {"feet": Vector3(-1.19, 0.04, -49), "grounded": true, "approved_control": true})
	key("a", true)
	await tap("space")
	for i: int in 40:
		await ticks(2)
		await tap("space")
	check("shallow wall recovery exists with approved runner too", float(contact_depths.get("wall_pressure_approved_control", 0)) > 0.0002,
		{"lab_max_m": contact_depths.get("wall_repeats"), "approved_max_m": contact_depths.get("wall_pressure_approved_control")})
	# stale press around pause: compare the chosen buffering behavior, without assuming it is a defect.
	await start("pause_wall_press", {"feet": Vector3(-1.19, 1, -49), "grounded": false})
	key("space", true)
	key("esc", true)
	key("esc", false)
	key("space", false)
	await ticks(10)
	check("pause stops all physics and impulses", count("wall_jump") == 0 and pos().distance_to(Vector3(-1.19, 1, -49)) < 1e-6)
	await tap("esc")
	check("pre-pause Space buffer observed", true, {"jumps_after_resume": count("wall_jump"), "note": "press preceded pause; inherited jump pulse is intentionally buffered too"})

	# alternating real faces earn the three-impulse flight limit; toggles cannot reset it.
	await start("wall_flight_limit", {"feet": Vector3(-1.19, 1.0, -49), "grounded": false})
	for i: int in 4:
		if i > 0:
			var target := 1.05 if i % 2 else -1.05
			var arrived := await until(func() -> bool: return pos().x >= target if target > 0 else pos().x <= target, 100)
			check("alternating wall actually reached " + str(i), arrived and not bool(p().call("is_grounded")), pos())
		await tap("space")
		if i == 1:
			await tap("2")
			await tap("2")
			await tap("f5")
			check("toggle and F5 preserve flight quota", int(lab().wall_jump.flight) == 2, lab().wall_jump)
	check("three alternating wall jumps then real fourth face refused", int(lab().wall_jump.flight) == 3 and int(lab().counts.wall_jump) == 3 and str(lab().wall_jump.refusal) == "limit this flight", lab().wall_jump)
	await until(func() -> bool: return bool(p().call("is_grounded")), 300)
	await ticks(2)
	check("real landing resets flight quota", int(lab().wall_jump.flight) == 0, lab().wall_jump)
	# the corner offers a different face before cooldown expires; no motion changes after setup.
	await start("wall_corner_cooldown", {"feet": Vector3(-1.19, 0.5, -55.45), "grounded": false})
	await tap("space")
	await tap("space")
	check("second corner face cannot bypass cooldown", int(lab().counts.wall_jump) == 1 and str(lab().wall_jump.refusal) == "cooldown", lab().wall_jump)

func grapple_cases() -> void:
	var a1 := Vector3(0, 10.5, -80)
	for mode: String in ["released", "disabled", "preset", "pause", "time", "restart", "checkpoint"]:
		await start("line_" + mode, {"feet": Vector3(0, 3.24, -68), "grounded": true})
		aim(a1)
		key("e", true)
		await ticks(8)
		check(mode + " has a real acquired line", bool(lab().grapple.attached), lab().grapple)
		if mode == "released":
			key("e", false)
			await ticks(3)
			check("E up removes rope and pull impulses", not bool(lab().grapple.attached) and (lab().impulses_u as Dictionary).is_empty(), lab())
		elif mode == "disabled":
			await tap("3")
			check("disable releases active grapple", not bool(lab().grapple.attached) and str(lab().grapple.release) == "off", lab().grapple)
			await tap("3")
			await ticks(4)
			check("re-enable with E held cannot relatch forced release", not bool(lab().grapple.attached), lab().grapple)
			key("e", false)
			await ticks(1)
			aim(a1)
			key("e", true)
			await ticks(1)
			check("fresh E reacquires after off", bool(lab().grapple.attached), lab().grapple)
		elif mode == "preset":
			var before_key: String = game.get("course_key")
			await tap("f5")
			check("F5 preserves live line and separates identity", bool(lab().grapple.attached) and before_key != game.get("course_key") and not bool(game.get("clean_eligible")), snapshot())
		elif mode == "pause":
			await tap("esc")
			var before := snapshot()
			key("e", false)
			await ticks(32)
			check("pause freezes rope time and position", pos() == before.p and lab().grapple.ticks == before.lab.grapple.ticks)
			await tap("esc")
			check("E released during pause stays released on resume", not bool(lab().grapple.attached) and str(lab().grapple.release) == "released", lab().grapple)
		elif mode == "time":
			await ticks(410)
			check("forced time release does not relatch held E", count("grapple") == 1 and str(lab().grapple.release) == "time", {"events": ep.events, "state": lab().grapple})
		else:
			await tap("r" if mode == "restart" else "f")
			check(mode + " clears the active line", not bool(lab().grapple.attached) and int(lab().counts.grapple) == 0 and not bool(lab().slide.active), lab())
	# range and obstruction, with a stationary labelled setup only.
	for item: Array in [["far", Vector3(0, 3.24, -48), a1], ["blocked", Vector3(0, 3.24, -62), Vector3(-7, 9.5, -88)]]:
		await start("target_" + item[0], {"feet": item[1], "grounded": false})
		aim(item[2])
		key("e", true)
		await ticks(2)
		check(item[0] + " target cannot acquire", not bool(lab().grapple.attached) and str(lab().grapple.target.state) == item[0], lab().grapple)
	# explicit branch diagnostic: one already-attached, overrange initial state. this is not
	# a claim that ordinary input can outrun the rope; a prior transverse overspeed try did not.
	await start("line_overrange_seed", {"feet": Vector3(0, 10, -45), "grounded": false, "overrange_line_seed": true})
	key("e", true)
	await ticks(8)
	check("seeded overrange line releases without impulse or relatch", not bool(lab().grapple.attached) and str(lab().grapple.release) == "range" and count("grapple") == 0 and (lab().impulses_u as Dictionary).is_empty(), lab().grapple)
	await start("line_break_real_column", {"feet": Vector3(-1.5, -3.96, -76), "grounded": true})
	aim(Vector3(-7, 9.5, -88))
	key("e", true)
	await ticks(2)
	check("column episode actually acquires before crossing", bool(lab().grapple.attached), lab().grapple)
	key("a", true)
	await until(func() -> bool: return str(lab().grapple.release) == "obstructed", 100)
	key("a", false)
	await ticks(6)
	check("real column breaks line and held E cannot reacquire", not bool(lab().grapple.attached) and str(lab().grapple.release) == "obstructed" and count("grapple") == 1, lab().grapple)

func slide_cases() -> void:
	for mode: String in ["edge", "disable_roof", "f5_roof", "pause_release", "ceiling_space"]:
		await start("slide_" + mode, {"feet": Vector3(0, 0.04, -18), "grounded": true})
		key("w", true)
		await until(func() -> bool: return pos().z < -21.0, 250)
		key("shift", true)
		await ticks(3)
		check(mode + " starts slide from input-earned speed", bool(lab().slide.active), lab().slide)
		await until(func() -> bool: return pos().z < -24.0, 120)
		if mode == "disable_roof":
			await tap("1")
			await ticks(2)
			check("disable slide under rack releases safely into blocked duck", not bool(lab().slide.active) and p().get("ducked") == true and p().get("stand_blocked") == true, lab().slide)
		elif mode == "f5_roof":
			await tap("f5")
			check("F5 preserves active slide and duck hull under roof", bool(lab().slide.active) and p().get("ducked") == true and str(game.get("preset_id")) == "server128_aa1000")
		elif mode == "pause_release":
			await tap("esc")
			var before := snapshot()
			key("shift", false)
			await ticks(10)
			check("pause freezes slide ticks", pos() == before.p and lab().slide.ticks == before.lab.slide.ticks)
			await tap("esc")
			check("Shift released during pause stops slide", not bool(lab().slide.active) and p().get("stand_blocked") == true, lab().slide)
		elif mode == "ceiling_space":
			key("w", false)
			key("shift", false)
			await ticks(100)
			await tap("space")
			await tap("space")
			check("real ceiling contact is not a wall impulse", count("wall_jump") == 0, lab().wall_jump)
		if mode == "edge":
			await until(func() -> bool: return not bool(p().call("is_grounded")), 250)
			check("running slide off trench edge ends slide", not bool(lab().slide.active) and str(lab().slide.end) == "airborne", lab().slide)
			key("shift", false)
			await ticks(12)
			check("edge fall retains slide duck without air-origin shift", p().get("ducked") == true and ((p().call("get_motion_state") as Dictionary).duck.shift_u as Vector3).length() == 0.0, snapshot())
			await until(func() -> bool: return bool(p().call("is_grounded")), 250)
			await ticks(2)
			check("landing releases slide duck when standing fits", not bool(p().get("ducked")), snapshot())

func click(control: Control) -> void:
	var scroll: ScrollContainer = (game.get("hud") as Node).get("_pause_scroll")
	for i: int in 100:
		if scroll.get_global_rect().encloses(control.get_global_rect()):
			break
		var at := scroll.get_global_rect().get_center()
		for down: bool in [true, false]:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if control.get_global_rect().position.y > at.y else MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = down
			wheel.position = at
			wheel.global_position = at
			root.push_input(wheel, true)
		await process_frame
	check("menu target reached by scrolling", scroll.get_global_rect().encloses(control.get_global_rect()), control.name)
	var at := control.get_global_rect().get_center()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		event.global_position = at
		root.push_input(event, true)
		sent.append({"click": str(control.name), "down": down, "at": at})
		await process_frame

func change_map(id: String) -> void:
	if not bool(game.get("paused")):
		await tap("esc")
	await process_frame
	await process_frame
	await click(((game.get("hud") as Node).get("map_buttons") as Dictionary)[id])
	await ticks(3)
	if bool(game.get("paused")):
		await tap("esc")
	check("map selected through viewport", str(game.get("map_id")) == id, id)

func host_cases() -> void:
	await start("host_live_transitions", {"feet": Vector3(0, 3.24, -68), "grounded": true})
	aim(Vector3(0, 10.5, -80))
	key("e", true)
	await ticks(8)
	check("transition starts with active grapple", bool(lab().grapple.attached))
	var old: WeakRef = weakref(p())
	await change_map("practice")
	check("map change frees active lab body", old.get_ref() == null)
	check("course restores approved body and audio/stats", p().get_script() == SOURCE and (game.get("audio") as Node).get("_player") == p() and (game.get("stats") as Node).get("player") == p(), snapshot())
	key("shift", true)
	key("1", true)
	key("2", true)
	key("3", true)
	await ticks(4)
	check("held lab inputs do not add normal-course mechanics", (game.call("lab_moves") as Dictionary).is_empty() and game.call("mechanics") == [])
	for name: String in ["e", "shift", "1", "2", "3"]:
		key(name, false)
	for preset: String in ["f3", "f4", "f5", "f2"]:
		await tap(preset)
		check("normal course retains " + preset, int(game.get("preset").slot) == int(preset.substr(1)))
	await tap("f3")
	await change_map("experiment")
	check("F3 entry restricts to F2 and starts all moves on", str(game.get("preset_id")) == "server128" and p().get_script() == LAB and game.call("lab_moves") == {"slide": true, "wall_jump": true, "grapple": true})
	check("F3 restriction notice survives map change", str((game.get("hud") as Node).get("message").text).contains("F2 and F5 only"))
	await change_map("breakwater")
	await tap("f4")
	await change_map("experiment")
	check("F4 entry restricts to F2", str(game.get("preset_id")) == "server128" and p().get_script() == LAB)
	await start("f5_course_to_lab", {"map": "rainline"})
	await tap("f5")
	await change_map("experiment")
	check("F5 map entry stays F5 with lab body", str(game.get("preset_id")) == "server128_aa1000" and p().get_script() == LAB)

	for exit: String in ["map", "f", "r", "f2"]:
		await start("pending_" + exit, {"map": "rainline", "feet": Vector3(51.5, -2.96, -38), "grounded": true, "duck": true})
		key("ctrl", true)
		await tap("f3")
		check("real duct defers F3 " + exit, str(game.get("pending_preset")) == "r13_original120" and str(game.get("preset_id")) == "server128", snapshot())
		if exit == "map":
			await change_map("experiment")
			check("lab entry cancels course pending preset", str(game.get("pending_preset")).is_empty() and p().get_script() == LAB and str(game.get("preset_id")) == "server128")
		else:
			await tap(exit)
			check("pending policy " + exit, str(game.get("pending_preset")).is_empty() and str(game.get("preset_id")) == ("r13_original120" if exit == "r" else "server128"), snapshot())

func wall_climb() -> void:
	key("w", true)
	await until(func() -> bool: return pos().z < -45.0, 900)
	key("a", true)
	await until(func() -> bool: return pos().z < -50.3, 900)
	await tap("space")
	var stage := 0
	for i: int in 400:
		await ticks(1)
		if stage == 0 and not bool(p().call("is_grounded")) and p().velocity.y / U < 30.0:
			key("a", false)
			await tap("space")
			stage = 1
		elif stage == 1 and not bool(p().call("is_grounded")) and pos().x > 1.165:
			await tap("space")
			stage = 2
			key("d", true)
			await ticks(2)
			key("d", false)
		if stage > 0 and bool(p().call("is_grounded")) and i > 20:
			break
	key("a", false)

func combined(toggle: String) -> void:
	key("w", true)
	await until(func() -> bool: return pos().z < -20.9, 900)
	key("shift", true)
	await until(func() -> bool: return pos().z < -27.45 and bool(p().call("is_grounded")), 300)
	await tap("space")
	key("shift", false)
	await until(func() -> bool: return bool(p().call("is_grounded")) and pos().z < -30.6, 200)
	await wall_climb()
	await until(func() -> bool: return bool(p().call("is_grounded")), 200)
	aim(Vector3(pos().x, pos().y + 64.0 * U, -90))
	await until(func() -> bool: return pos().z < -69.6, 400)
	await tap("space")
	aim(Vector3(0, 10.5, -80))
	key("e", true)
	await until(func() -> bool: return pos().z < -83.0 or bool(p().call("is_grounded")), 500)
	key("e", false)
	# all mechanics are behind us; a changed final loadout must not launder the mixed run.
	if not toggle.is_empty():
		for button: String in toggle.split(","):
			await tap(button)
	await until(func() -> bool: return bool(game.get("finished")), 900)
	key("w", false)
	await ticks(3)

func mixed_records() -> void:
	for mode: String in ["control", "mixed", "roundtrip", "preset_roundtrip"]:
		var control := mode == "control"
		await start("records_" + mode, {"records": true})
		var initial_key: String = game.get("course_key")
		await combined({"control": "", "mixed": "3", "roundtrip": "3,3", "preset_roundtrip": "f5,f2"}[mode])
		check("combined line actually finishes", bool(game.get("finished")) and int(game.get("respawn_count")) == 0, snapshot())
		var profile := out.path_join("records_" + mode + ".cfg")
		if control:
			check("control clean line saves integer ticks", str(game.get("finish_kind")) == "clean" and bool(game.get("last_save_ok")) and FileAccess.file_exists(profile), game.get("elapsed"))
			var seen := {}
			for mask: int in 8:
				# gray code changes only one move each time, all actual 1/2/3 events.
				var gray := mask ^ (mask >> 1)
				for bit: int in 3:
					var id: String = ["slide", "wall_jump", "grapple"][bit]
					if bool((game.call("lab_moves") as Dictionary)[id]) != not bool(gray & (1 << bit)):
						await tap(str(bit + 1))
				seen[game.get("course_key")] = true
				if mask > 0:
					check("other loadout has no inherited best " + str(mask), float(game.get("best_time")) < 0)
			check("all eight full-loadout record identities differ", seen.size() == 8, seen.keys())
			for bit: int in 3:
				if not bool((game.call("lab_moves") as Dictionary)[["slide", "wall_jump", "grapple"][bit]]):
					await tap(str(bit + 1))
			check("returning all-on restores its own clean best", str(game.get("course_key")) == initial_key and float(game.get("best_time")) > 0)
		else:
			check("mixed mechanics finish is practice and never saved", str(game.get("finish_kind")) == "practice" and not bool(game.get("clean_eligible")) and not FileAccess.file_exists(profile) and float(game.get("best_time")) < 0, snapshot())

static func plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var result := {}
		for k: Variant in value:
			result[str(k)] = plain(value[k])
		return result
	if value is Array:
		return value.map(plain)
	if value is float and not is_finite(value):
		return str(value)
	return value

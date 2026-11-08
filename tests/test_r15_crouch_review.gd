extends SceneTree
## p / independent adversarial review of a37636bb. each episode has one labelled setup;
## after that only physical key/mouse input drives the runner. f2/f5/r exercise the lab's
## public settings/reset operations. f6/f7 are explicitly diagnostic settings mutations,
## not product controls. no production script or historical test is changed.
## run with pinned godot --headless --fixed-fps 128 --path PROJECT --script
## res://tests/test_r15_crouch_review.gd -- --out=DIR [--only=substring]

const R15 := preload("res://scripts/r15_source_player.gd")
const R14 := preload("res://scripts/r14_source_player.gd")
const PRESETS := preload("res://scripts/r14_presets.gd")
const MAIN := preload("res://scripts/spillway_main.gd")
const LAB := preload("res://scripts/r14_source_lab.gd")
const R14_MAIN := preload("res://scripts/r14_main.gd")
const R15_TAPE_MAIN := preload("res://tests/r15_crouch_tape_game.gd")
const U := 0.0254
const SETTLE := 12
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE,
	"ctrl": KEY_CTRL, "f2": KEY_F2, "f5": KEY_F5, "r": KEY_R, "f6": KEY_F6, "f7": KEY_F7}

signal done

class Probe:
	extends Node
	var suite: Object
	var early := false
	func _physics_process(_dt: float) -> void:
		suite.call("early_tick" if early else "late_tick")
	func _process(_dt: float) -> void:
		if not early:
			suite.call("frame_tick")
	func _unhandled_input(e: InputEvent) -> void:
		if early:
			suite.call("control_input", e)

var out := "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/crouch-review/suite"
var only := ""
var world: Node3D
var player: CharacterBody3D
var twin: CharacterBody3D
var tick := 0
var ticks := 0
var tape: Dictionary
var running := false
var episode_name := ""
var reset_pose: Transform3D
var rows: Array[Dictionary] = []
var frames: Array[Dictionary] = []
var episodes: Dictionary = {}
var checks: Array[Dictionary] = []
var settings_actions: Array[Dictionary] = []
var probe_box := BoxShape3D.new()
var frame_hits := 0
var max_pdiff := 0.0
var max_vdiff := 0.0
var events_differ := 0
var first_steps := 0
var order_errors := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	_run.call_deferred()

func _run() -> void:
	MAIN.bind_inputs()
	DirAccess.make_dir_recursive_absolute(out)
	world = Node3D.new()
	root.add_child(world)
	box("floor", Vector3(0, -32, 0), Vector3(1600, 64, 8000))
	# p / an elevated edge ends at z=-600, with the floor 128 u below it.
	box("edge", Vector3(2000, 96, 0), Vector3(512, 64, 1200))
	box("edge_catch", Vector3(2000, -32, -1000), Vector3(1400, 64, 5000))
	# p / 62 u roof, entered from open deck and exited at z=-800.
	box("low_roof", Vector3(0, 78, -600), Vector3(256, 32, 400))
	# p / sloping roof falls from ~110 to ~55 u as forward input approaches it.
	box("slope_floor", Vector3(4000, -32, 0), Vector3(800, 64, 4000))
	box("slope_roof", Vector3(4000, 98, -300), Vector3(256, 24, 700), deg_to_rad(-5.0))
	# p / roof parallel to a 20-degree sloping floor, 62 u vertical clearance.
	var slope := deg_to_rad(20.0)
	var normal := Basis(Vector3.RIGHT, slope) * Vector3.UP
	var ramp_top := Vector3(6000, tan(slope) * 400.0, -400)
	box("ramp", ramp_top - normal * 32.0, Vector3(384, 64, 800.0 / cos(slope)), slope)
	box("ramp_roof", ramp_top + Vector3.UP * 62.0 + normal * 12.0, Vector3(384, 24, 500), slope)
	box("ramp_approach", Vector3(6000, -32, 350), Vector3(800, 64, 700))
	player = R15.new()
	twin = R14.new()
	root.add_child(player)
	root.add_child(twin)
	for runner: CharacterBody3D in [player, twin]:
		runner.collision_layer = 2
		runner.collision_mask = 1
	for early: bool in [true, false]:
		var p := Probe.new()
		p.suite = self
		p.early = early
		p.process_physics_priority = -1000 if early else 1000
		p.process_priority = 1000
		root.add_child(p)
	await process_frame
	await parity()
	await adversarial()
	await state_changes()
	identity()
	check("one_step_order", order_errors == 0, order_errors)
	var summary := {"engine": Engine.get_version_info(), "episodes": episodes, "checks": checks,
		"failed": checks.filter(func(c: Dictionary) -> bool: return not c.ok).size(),
		"note": "input-event collision fixtures; f6/f7 settings cases are seeded diagnostics; no native or feel claim"}
	var f := FileAccess.open(out.path_join("summary.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(summary, "\t"))
	f.close()
	print("review episodes=%d checks=%d failed=%d" % [episodes.size(), checks.size(), summary.failed])
	quit(0 if summary.failed == 0 else 1)

func box(label: String, center: Vector3, size: Vector3, tilt := 0.0) -> void:
	var b := StaticBody3D.new()
	b.name = label
	b.position = center * U
	b.rotation.x = tilt
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size * U
	c.shape = s
	b.add_child(c)
	world.add_child(b)

func cv(id := "server128") -> Dictionary:
	return PRESETS.source_settings(id, {"sensitivity": 5.729578, "fov": 90.0})

func check(label: String, ok: bool, detail: Variant) -> void:
	checks.append({"name": label, "ok": ok, "detail": detail})
	print("%s %s %s" % ["ok" if ok else "RED", label, str(detail)])

func send(e: Array) -> void:
	if e[0] == "mouse":
		var m := InputEventMouseMotion.new()
		m.relative = Vector2(e[1], e[2] if e.size() > 2 else 0)
		m.screen_relative = m.relative
		Input.parse_input_event(m)
	else:
		var k := InputEventKey.new()
		k.physical_keycode = KEYS[e[0]]
		k.pressed = e[1]
		Input.parse_input_event(k)
	Input.flush_buffered_events()

func control_input(e: InputEvent) -> void:
	if not running or not (e is InputEventKey) or not e.pressed:
		return
	var id := ""
	if e.physical_keycode == KEY_F2:
		id = "server128"
	if e.physical_keycode == KEY_F5:
		id = "server128_aa1000"
	if not id.is_empty():
		for runner: CharacterBody3D in [player, twin]:
			runner.call("apply_settings", cv(id))
			runner.call("apply_engine_rate")
		settings_actions.append({"tick": tick - SETTLE, "action": id})
	if e.physical_keycode == KEY_R:
		for runner: CharacterBody3D in [player, twin]:
			runner.call("reset_to", reset_pose)
		settings_actions.append({"tick": tick - SETTLE, "action": "reset_to_station"})
	# p / these exercise the exposed settings interface, not a shipped key binding.
	if e.physical_keycode in [KEY_F6, KEY_F7]:
		var next: Dictionary = player.get("settings").duplicate()
		if e.physical_keycode == KEY_F6:
			next.duck_air_anchor = "head"
		else:
			next.duck_hull_height = 70.0
		player.call("apply_settings", next)
		settings_actions.append({"tick": tick - SETTLE, "action": "diagnostic_anchor_head" if e.physical_keycode == KEY_F6 else "diagnostic_hull_70"})

func episode(label: String, at: Vector3, events: Dictionary, count: int, preset := "server128") -> Array[Dictionary]:
	if not only.is_empty() and not only in label:
		return []
	running = false
	for k: String in KEYS:
		send([k, false])
	reset_pose = Transform3D(Basis.IDENTITY, at * U)
	for runner: CharacterBody3D in [player, twin]:
		runner.call("apply_settings", cv(preset))
		runner.call("apply_engine_rate")
		runner.call("reset_to", reset_pose)
	tick = 0
	ticks = count + SETTLE
	tape = events
	rows = []
	frames = []
	settings_actions = []
	frame_hits = 0
	max_pdiff = 0
	max_vdiff = 0
	events_differ = 0
	episode_name = label
	running = true
	await done
	var lines := PackedStringArray()
	for row: Dictionary in rows:
		lines.append(JSON.stringify(row))
	LAB.write_gzip(out.path_join(label + ".jsonl.gz"), lines)
	lines = PackedStringArray()
	for row: Dictionary in frames:
		lines.append(JSON.stringify(row))
	LAB.write_gzip(out.path_join(label + "-frames.jsonl.gz"), lines)
	var overlaps := rows.filter(func(r: Dictionary) -> bool: return not r.overlap.is_empty())
	var error := 0.0
	var max_depen := 0.0
	var peak := -INF
	var blocked := 0
	var ducks := 0
	var stands := 0
	var jumps := 0
	for r: Dictionary in rows:
		error = maxf(error, float(r.accounting_error_u))
		max_depen = maxf(max_depen, float(r.depen_u))
		peak = maxf(peak, float(r.p[1]))
		blocked += int(r.blocked)
		ducks += int("duck" in r.e or "duck_air" in r.e)
		stands += int("unduck" in r.e or "unduck_air" in r.e)
		jumps += int("jump" in r.e)
	episodes[label] = {"setup_u": arr(at), "preset": preset, "events": events, "ticks": count,
		"overlap_ticks": overlaps.size(), "first_overlap": overlaps[0] if not overlaps.is_empty() else {},
		"max_accounting_error_u": error, "max_depenetration_u": max_depen,
		"camera_solid_frames": frame_hits, "peak_feet_u": peak, "end": rows[-1],
		"blocked_ticks": blocked, "ducks": ducks, "stands": stands, "jumps": jumps,
		"max_twin_pdiff_m": max_pdiff, "max_twin_vdiff_mps": max_vdiff,
		"event_difference_ticks": events_differ, "settings_actions": settings_actions}
	var first_hit := {}
	if not overlaps.is_empty():
		first_hit = overlaps[0].duplicate()
		first_hit.erase("contacts")
	check(label + "_no_overlap", overlaps.is_empty(), {"ticks": overlaps.size(), "first": first_hit})
	check(label + "_travel_accounts", error < 0.002, error)
	check(label + "_camera_clear", frame_hits == 0, frame_hits)
	return rows.duplicate(true)

func arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func overlaps_at(pos: Vector3, height: float) -> Array:
	# p / inset all faces by .02 u to reject standoff/float noise; geometry is layer 1.
	probe_box.size = Vector3(31.96, height - 0.04, 31.96) * U
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe_box
	query.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * height * U * 0.5)
	query.collision_mask = 1
	query.margin = 0.0
	var hits := world.get_world_3d().direct_space_state.intersect_shape(query)
	var names := []
	for hit: Dictionary in hits:
		names.append(str(hit.collider.name))
	return names

func early_tick() -> void:
	if not running:
		return
	tick += 1
	first_steps = int(player.get("tape_step_count"))
	for e: Array in tape.get(tick - SETTLE, []):
		send(e)

func late_tick() -> void:
	if not running:
		return
	if int(player.get("tape_step_count")) != first_steps + 1 and not tape.get(tick - SETTLE, []).has(["r", true]):
		order_errors += 1
	var s: Dictionary = player.call("get_motion_state")
	var t: Dictionary = twin.call("get_motion_state")
	max_pdiff = maxf(max_pdiff, (s.position as Vector3).distance_to(t.position))
	max_vdiff = maxf(max_vdiff, (s.post_contact_velocity as Vector3).distance_to(t.post_contact_velocity))
	if s.events != t.events:
		events_differ += 1
	var before := player.global_position if rows.is_empty() else Vector3(rows[-1].p[0], rows[-1].p[1], rows[-1].p[2]) * U
	var err := (player.global_position - before - (s.origin_delta as Vector3)).length() / U
	if tick == 1 or tape.get(tick - SETTLE, []).has(["r", true]):
		err = 0
	rows.append({"t": tick - SETTLE, "p": arr(s.position / U), "v": arr(s.velocity_u),
		"actual_v": arr(s.actual_velocity / U), "travel_u": arr(s.displacement / U),
		"origin_u": arr(s.origin_delta / U), "shift_u": arr(s.duck_shift / U),
		"comp_u": arr(s.duck.compensation_u), "height": s.hull.height_u, "ducked": s.duck.ducked,
		"held": s.duck.held, "blocked": s.duck.stand_blocked, "eye": s.duck.eye_u,
		"grounded": s.grounded, "e": s.events, "yaw": s.yaw, "contacts": s.contacts,
		"overlap": overlaps_at(s.position, s.hull.height_u), "accounting_error_u": err,
		"depen_u": (s.depenetration as Vector3).length() / U,
		"air_lift_u": s.duck.air_lift_u, "aa": s.cvars.sv_airaccelerate})
	if tick >= ticks:
		running = false
		done.emit.call_deferred()

func frame_tick() -> void:
	if not running:
		return
	var camera: Camera3D = player.get("camera")
	var q := PhysicsPointQueryParameters3D.new()
	q.position = camera.global_position
	q.collision_mask = 1
	var hits := world.get_world_3d().direct_space_state.intersect_point(q)
	frame_hits += int(not hits.is_empty())
	frames.append({"t": tick - SETTLE, "p": arr(camera.global_position / U), "inside_solid": not hits.is_empty(),
		"fraction": Engine.get_physics_interpolation_fraction()})

func parity() -> void:
	for preset: String in ["server128", "server128_aa1000"]:
		var e := {1: [["w", true]], 40: [["space", true]], 70: [["w", false], ["d", true]],
			100: [["mouse", 17]], 130: [["d", false], ["a", true]], 155: [["mouse", -31]],
			220: [["a", false], ["w", true]], 290: [["space", false]], 330: [["w", false]]}
		await episode("no_crouch_" + preset, Vector3(2000, 128.5, 100), e, 480, preset)
		if episodes.has("no_crouch_" + preset):
			check("no_crouch_exact_" + preset, max_pdiff == 0 and max_vdiff == 0 and events_differ == 0,
				{"position_m": max_pdiff, "velocity_mps": max_vdiff, "events": events_differ})
		await episode("no_crouch_edge_" + preset, Vector3(2000, 128.5, -300), {1: [["w", true]], 340: [["w", false]]}, 480, preset)
		if episodes.has("no_crouch_edge_" + preset):
			check("no_crouch_edge_exact_" + preset, max_pdiff == 0 and max_vdiff == 0 and events_differ == 0,
				{"position_m": max_pdiff, "velocity_mps": max_vdiff, "events": events_differ, "end": rows[-1].p})

func add_event(events: Dictionary, at: int, e: Array) -> void:
	if not events.has(at):
		events[at] = []
	events[at].append(e)

func adversarial() -> void:
	# p / phase sweep straddles first touchdown at ~80 ticks, then continues many hop cycles.
	for phase: int in range(0, 8):
		var e := {1: [["space", true]], 620: [["space", false]]}
		for n: int in range(2 + phase, 620, 4):
			e[n] = [["ctrl", true]]
			e[n + 2] = [["ctrl", false]]
		await episode("landing_spam_%d" % phase, Vector3(500, 0.5, 600), e, 720)
	for phase: int in range(0, 6):
		var e := {1: [["w", true]], 35: [["space", true]], 36: [["space", false]], 400: [["w", false]]}
		for n: int in range(2 + phase, 400, 6):
			add_event(e, n, ["ctrl", true])
			add_event(e, n + 3, ["ctrl", false])
		await episode("edge_spam_%d" % phase, Vector3(2000, 128.5, -300), e, 500)
	for mode: String in ["hold", "release", "spam"]:
		var e := {1: [["w", true], ["ctrl", true]], 1600: [["w", false]]}
		if mode == "release":
			e[1100] = [["ctrl", false]]
			e[1300] = [["s", true], ["w", false]]
			e[1700] = [["s", false]]
		if mode == "spam":
			for n: int in range(80, 990, 10):
				e[n] = [["ctrl", false]]
				e[n + 5] = [["ctrl", true]]
		await episode("sloping_roof_" + mode, Vector3(4000, 0.5, 180), e, 1750)
	var low := {1: [["w", true]], 90: [["ctrl", true]], 500: [["ctrl", false]], 1200: [["w", false]]}
	await episode("low_roof_release", Vector3(0, 0.5, 0), low, 1250)
	var ramp := {1: [["w", true], ["ctrl", true]], 1050: [["ctrl", false]],
		1400: [["w", false], ["s", true]], 1900: [["s", false]]}
	await episode("sloping_floor_roof_release", Vector3(6000, 0.5, 220), ramp, 2000)
	await episode("air_low_roof_release", Vector3(0, 0.5, -300),
		{1: [["w", true], ["ctrl", true]], 400: [["space", true]], 401: [["space", false]],
		410: [["ctrl", false]], 1250: [["w", false]]}, 1350)
	await episode("hop_chain_control", Vector3(500, 0.5, 600), {1: [["space", true]], 620: [["space", false]]}, 720)
	await episode("air_pair_control", Vector3(500, 0.5, 600), {1: [["space", true]], 2: [["space", false]]}, 140)
	var control: Array = rows.duplicate(true)
	await episode("air_pair", Vector3(500, 0.5, 600), {1: [["space", true]], 2: [["space", false]], 12: [["ctrl", true]], 40: [["ctrl", false]]}, 140)
	if episodes.has("air_pair") and episodes.has("air_pair_control"):
		var dv := 0.0
		for i: int in rows.size():
			dv = maxf(dv, Vector3(rows[i].v[0], rows[i].v[1], rows[i].v[2]).distance_to(Vector3(control[i].v[0], control[i].v[1], control[i].v[2])))
		check("air_pair_velocity_exact", dv == 0.0, dv)
		check("air_pair_rejoins", rows[-1].p == control[-1].p, [rows[-1].p, control[-1].p])

func state_changes() -> void:
	await episode("ducked_preset_switch", Vector3(0, 0.5, 0),
		{1: [["w", true], ["ctrl", true]], 850: [["ctrl", false]], 870: [["f5", true]],
		871: [["f5", false]], 900: [["f2", true]], 901: [["f2", false]], 1600: [["w", false]]}, 1650)
	await episode("ducked_reset_held_jump", Vector3(500, 0.5, 600),
		{1: [["ctrl", true]], 30: [["space", true]], 31: [["space", false]], 40: [["space", true], ["space", false], ["r", true]],
		41: [["r", false]], 45: [["ctrl", false]]}, 160)
	await episode("queued_jump_release", Vector3(500, 0.5, 600),
		{1: [["ctrl", true]], 30: [["space", true], ["space", false]], 60: [["ctrl", false]]}, 150)
	await episode("queued_duck_tap", Vector3(500, 0.5, 600),
		{1: [["space", true]], 2: [["space", false]], 12: [["ctrl", true], ["ctrl", false]]}, 140)
	await episode("diagnostic_anchor_switch", Vector3(500, 0.5, 600),
		{1: [["space", true]], 2: [["space", false]], 12: [["ctrl", true]], 20: [["f6", true]],
		21: [["f6", false]], 40: [["ctrl", false]]}, 140)
	if episodes.has("diagnostic_anchor_switch"):
		var released: Dictionary = rows.filter(func(r: Dictionary) -> bool: return "unduck_air" in r.e)[0]
		check("diagnostic_anchor_compensation_balances", absf(float(released.comp_u[1])) < 0.001, released.comp_u)
	await episode("diagnostic_hull_resize_low_roof", Vector3(0, 0.5, 0),
		{1: [["w", true], ["ctrl", true]], 1000: [["w", false]], 1010: [["f7", true]], 1011: [["f7", false]]}, 1060)
	coverage_checks()

func coverage_checks() -> void:
	for label: String in ["sloping_roof_release", "sloping_floor_roof_release", "low_roof_release", "air_low_roof_release", "ducked_preset_switch"]:
		if episodes.has(label):
			var e: Dictionary = episodes[label]
			check(label + "_reached_blocked_and_stood", e.blocked_ticks > 0 and e.stands > 0, {"blocked_ticks": e.blocked_ticks, "stands": e.stands})
	for label: String in episodes:
		if label.begins_with("edge_spam_"):
			check(label + "_jump_reached", episodes[label].jumps == 1, episodes[label].jumps)

func identity() -> void:
	var a := cv()
	var b := R15.with_duck(a)
	check("raw_presets_omit_duck", not PRESETS.physics_fingerprint(a).has("duck_air_anchor"), PRESETS.physics_fingerprint(a))
	check("runner_settings_include_duck", PRESETS.physics_fingerprint(b).has("duck_air_anchor"), PRESETS.physics_fingerprint(b))
	var omitted := []
	for key: String in R15.DUCK_DEFAULTS:
		var changed := b.duplicate()
		if changed[key] is float:
			changed[key] += 1.0
		elif changed[key] is bool:
			changed[key] = not changed[key]
		else:
			changed[key] = "feet"
		if PRESETS.physics_fingerprint(changed) == PRESETS.physics_fingerprint(b):
			omitted.append(key)
	check("all_duck_settings_affect_fingerprint", omitted.is_empty(), omitted)
	# p / actual existing main identity computation, persistence off. this does not create
	# a final r15 shell or certify saving/reloading its records.
	var main14 := R14_MAIN.new()
	main14.map_id = "overflow"
	main14.set_window_title = false
	root.add_child(main14)
	var main15 := R15_TAPE_MAIN.new()
	main15.set_window_title = false
	root.add_child(main15)
	var base_key: String = main14.call("_course_key")
	var duck_key: String = main15.call("_course_key")
	check("actual_main_record_key_separates_r14_r15", base_key != duck_key,
		{"r14": base_key, "r15_adapter": duck_key, "r14_identity": str(main14.call("record_identity")), "r15_identity": str(main15.call("record_identity"))})
	var active: Dictionary = main15.player.get("settings").duplicate()
	var missing_keys := []
	for key: String in R15.DUCK_DEFAULTS:
		var changed := active.duplicate()
		if changed[key] is float:
			changed[key] += 1.0
		elif changed[key] is bool:
			changed[key] = not changed[key]
		else:
			changed[key] = "feet"
		main15.player.call("apply_settings", changed)
		if str(main15.call("_course_key")) == duck_key:
			missing_keys.append(key)
	main15.player.call("apply_settings", active)
	check("actual_main_key_tracks_all_duck_settings", missing_keys.is_empty(), missing_keys)
	active.fov = 110.0
	active.sensitivity = 7.0
	main15.player.call("apply_settings", active)
	check("actual_main_ui_keeps_record_key", str(main15.call("_course_key")) == duck_key, str(main15.call("_course_key")))
	check("identity_checks_persistence_off", not main14.persist and not main15.persist,
		{"r14": main14.profile_state, "r15_adapter": main15.profile_state, "family_version": PRESETS.FAMILIES.source.version, "r15_motor": R15.MOTOR_VERSION})
	main14.free()
	main15.free()

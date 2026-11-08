extends SceneTree
## p / r14 source collision repair gates. the fixture repeats the independent review's labelled
## geometry (floor, 18/19 u steps, wall, inner corner, short 50 degree ramp to a flat floor),
## except that its single 20000 u floor box is two smaller floors: godot 4.7.2 motion casts miss
## diagonal sweeps into very large boxes (tests/r14_source_repair_probe.gd measures it), and these
## gates are about the motor, not that engine defect.
## seeded episodes declare every state write in setup; after that only key and mouse events
## reach the runner. expected values are computed here from the fixture's own geometry and the
## public plane rules, never from the production clip helpers. gates are repair acceptance;
## findings are measurements reported without a pass/fail verdict.
## godot --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/r14_source_repair.gd --
##   [--out=DIR] [--only=pure,ramp,earned,limit,events,rest,travel] [--visual --label=TEXT]

const M := preload("res://scripts/r14_source_motion.gd")
const P := preload("res://scripts/r14_source_player.gd")
const MAIN := preload("res://scripts/spillway_main.gd")
const U := 0.0254
const KEYS := {"w": KEY_W, "s": KEY_S, "a": KEY_A, "d": KEY_D, "space": KEY_SPACE}
const GROUPS := ["pure", "ramp", "earned", "limit", "events", "rest", "travel"]
const RAMP_DEGREES := 50.0
## p / input-earned descents onto the ramp base: pose only, zero velocity, one d tick.
const EARNED_Z := [14.5, 15.0, 15.5]
const EARNED_HEIGHTS := [40.0, 40.3, 40.6, 40.9, 61.0, 61.4, 61.8, 62.2, 100.0, 100.5, 101.0, 101.5]
signal finished

class FreeWorld:
	extends RefCounted
	var extra: Array = []
	func walk_move(s: Dictionary, dt: float) -> void:
		s.position += s.velocity * dt
		for e: String in extra:
			s.events.append(e)
	func air_move(s: Dictionary, dt: float) -> void:
		s.position += s.velocity * dt
	func probe_ground(_s: Dictionary) -> Vector3:
		return Vector3.ZERO

class ClockProbe:
	extends Node
	var suite: Object
	var early: bool
	func _physics_process(dt: float) -> void:
		suite.call("before" if early else "after", dt)

var out := "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/source-repair/repair"
var groups: Array = GROUPS.duplicate()
var visual := false
var label := ""
var player: CharacterBody3D
var world: Node3D
var hud: Label
var observer: Camera3D
var checks: Array = []
var findings: Dictionary = {}
var episodes: Dictionary = {}
var traces: Array = []
var frames: Array = []
var tick := 0
var active := false
var pre_step := 0
var start := Vector3.ZERO
var held: Array = []
var ordering_errors := 0
var rates: Array = []
var episode_name := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			groups = Array(arg.trim_prefix("--only=").split(","))
		elif arg == "--visual":
			visual = true
		elif arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
	_run.call_deferred()

func check(name: String, pass_: bool, detail: Variant = null) -> void:
	checks.append({"name": name, "pass": pass_, "detail": plain(detail)})
	print("%s %s %s" % ["ok  " if pass_ else "FAIL", name, JSON.stringify(plain(detail)) if detail != null else ""])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out.path_join("traces"))
	MAIN.bind_inputs()
	world = Node3D.new()
	root.add_child(world)
	box("floor", Vector3(2000, -32, 0), Vector3(4400, 64, 4000))
	box("floor_ramp", Vector3(5000, -32, 500), Vector3(800, 64, 2000))
	box("step18", Vector3(1000, 9, -500), Vector3(256, 18, 600))
	box("step19", Vector3(1500, 9.5, -500), Vector3(256, 19, 600))
	box("wall", Vector3(2500, 128, -250), Vector3(512, 256, 32))
	box("corner_x", Vector3(3700, 128, -100), Vector3(32, 256, 600))
	box("corner_z", Vector3(3500, 128, -400), Vector3(600, 256, 32))
	var a := deg_to_rad(RAMP_DEGREES)
	box("ramp50", Vector3(5000, 128 * tan(a), -128) - ramp_normal() * 32, Vector3(256, 64, 256 / cos(a)), a)
	player = P.new()
	root.add_child(player)
	for early: bool in [true, false]:
		var clock := ClockProbe.new()
		clock.suite = self
		clock.early = early
		clock.process_physics_priority = -1000 if early else 1000
		root.add_child(clock)
	if visual:
		build_visuals()
	await process_frame
	if visual:
		await visual_cases()
	else:
		for group: String in GROUPS:
			if group in groups:
				await call("group_" + group)
		check("one_motor_step_per_physics_tick", ordering_errors == 0, ordering_errors)
		check("actual_delta_matches_declared_rate", rates.all(func(r: Array) -> bool: return absf(r[0] - 1.0 / r[1]) < 1e-9 and r[1] == r[2]), rates.size())
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.pass)
	var f := FileAccess.open(out.path_join("summary.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(plain({"engine": Engine.get_version_info(), "label": label, "groups": groups, "checks": checks, "failed": failed.size(), "findings": findings, "episodes": episodes}), "\t"))
	f.close()
	for key: String in KEYS:
		send_key(key, false)
	print("source repair: %d checks, %d failed; %s" % [checks.size(), failed.size(), out])
	quit(0 if failed.is_empty() else 1)

static func ramp_normal() -> Vector3:
	return Basis(Vector3.RIGHT, deg_to_rad(RAMP_DEGREES)) * Vector3.UP

func box(name: String, center: Vector3, size: Vector3, tilt := 0.0) -> void:
	var b := StaticBody3D.new()
	b.name = name
	b.transform = Transform3D(Basis(Vector3.RIGHT, tilt), center * U)
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size * U
	c.shape = shape
	b.add_child(c)
	world.add_child(b)

# --- episode machinery ------------------------------------------------------------------------

func run_episode(name: String, hz: int, sequence: Array, pose: Vector3, seed := Vector3.ZERO, grounded := true, preset := "csgo_server") -> Array:
	active = false
	for key: String in KEYS:
		send_key(key, false)
	held = []
	episode_name = name
	player.call("apply_preset", preset)
	player.settings.tickrate = hz
	player.call("apply_engine_rate")
	player.call("reset_to", Transform3D(Basis.IDENTITY, pose * U))
	player.velocity = seed * U
	# labelled setup, never adjusted after input begins.
	player.state.grounded = grounded
	player.state.ground_ticks = 100 if grounded else 0
	player.state.ground_normal = Vector3.UP if grounded else Vector3.ZERO
	frames = sequence
	traces = []
	tick = 0
	active = true
	await finished
	var result := traces.duplicate(true)
	var lines := PackedStringArray()
	for row: Dictionary in result:
		lines.append(JSON.stringify(plain(row)))
	var f := FileAccess.open(out.path_join("traces").path_join(name + ".jsonl.gz"), FileAccess.WRITE)
	f.store_buffer(("\n".join(lines) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	f.close()
	episodes[name] = {"hz": hz, "preset": preset, "setup": {"position_u": pose, "velocity_u_s": seed, "grounded": grounded, "velocity_seed": seed != Vector3.ZERO}, "ticks": sequence.size(), "final": result[-1]}
	return result

func before(_dt: float) -> void:
	if not active:
		return
	pre_step = player.tape_step_count
	start = player.global_position / U
	var frame: Dictionary = frames[tick]
	var wanted: Array = frame.get("keys", [])
	for key: String in KEYS:
		if (key in held) != (key in wanted):
			send_key(key, key in wanted)
	held = wanted.duplicate()
	if frame.has("mouse"):
		var mouse := InputEventMouseMotion.new()
		mouse.relative = Vector2(frame.mouse, 0)
		mouse.screen_relative = mouse.relative
		Input.parse_input_event(mouse)
	Input.flush_buffered_events()

func after(dt: float) -> void:
	if not active:
		return
	if player.tape_step_count != pre_step + 1:
		ordering_errors += 1
	var s: Dictionary = player.call("get_motion_state")
	var pos: Vector3 = player.global_position / U
	var contacts: Array = []
	for c: Dictionary in s.contacts:
		contacts.append({"phase": c.phase, "bump": c.bump, "body": c.body, "normal": c.normal, "fraction": c.get("fraction", -1.0), "blocking": c.get("blocking", true)})
	traces.append({"tick": tick, "p": pos, "v": player.velocity / U, "fd": (pos - start) / dt, "d": pos - start, "requested": s.requested_velocity / U, "grounded": s.grounded, "events": s.events, "contacts": contacts, "steps": s.step_ups, "jumps": s.jump_count, "lands": s.land_count, "depenetration": s.get("depenetration", Vector3.ZERO) / U, "standoff": s.get("standoff", Vector3.ZERO) / U, "dt": dt, "input": frames[tick]})
	rates.append([dt, int(player.settings.tickrate), Engine.physics_ticks_per_second])
	if visual:
		update_hud(s)
	tick += 1
	if tick == frames.size():
		active = false
		finished.emit()

func send_key(key: String, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEYS[key]
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

static func idle(n: int, first := {}) -> Array:
	var seq: Array = []
	for i: int in n:
		seq.append(first if i == 0 else {})
	return seq

static func hv(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

## the public chronological rule for an airborne hull that meets the ramp and then the floor
## inside one tick: clip the requested velocity on the ramp, then clip that on the floor.
static func chronological(requested: Vector3) -> Vector3:
	var n := ramp_normal()
	var t := requested
	if t.dot(n) < 0.0:
		t -= n * t.dot(n)
	if t.y < 0.0:
		t.y = 0.0
	return t

## the first row whose contacts hit the ramp face and then, in a later bump, the floor.
static func two_plane_row(rows: Array) -> int:
	for i: int in rows.size():
		var ramp_bump := -1
		var floor_bump := -1
		for c: Dictionary in rows[i].contacts:
			var n: Vector3 = c.normal
			if c.body == "ramp50" and absf(n.y - cos(deg_to_rad(RAMP_DEGREES))) < 0.01 and c.blocking and ramp_bump < 0:
				ramp_bump = c.bump
			if (c.body as String).begins_with("floor") and n.y > 0.99 and c.blocking:
				floor_bump = c.bump
		if ramp_bump >= 0 and floor_bump > ramp_bump:
			return i
	return -1

## finite-difference resolution at a position: two float32 position steps per tick, in u/s.
static func fd_quantum(p_u: Vector3, hz: int) -> float:
	var biggest := maxf(absf(p_u.x), maxf(absf(p_u.y), absf(p_u.z))) * U
	var step := pow(2.0, floorf(log(maxf(biggest, 1e-3)) / log(2.0)) - 23.0)
	return 2.0 * step / U * hz + 1e-4

static func same_rows(a: Array, b: Array) -> float:
	var worst := 0.0
	for i: int in mini(a.size(), b.size()):
		worst = maxf(worst, (a[i].p as Vector3).distance_to(b[i].p))
		worst = maxf(worst, (a[i].v as Vector3).distance_to(b[i].v))
	return worst if a.size() == b.size() else INF

# --- pure: the plane rule, the velocity bound and the event report, no collision ---------------

func group_pure() -> void:
	var n := ramp_normal()
	for hz: int in [64, 128]:
		var requested := Vector3(30, -400.0 - 400.0 / hz, 250)
		# public order after two traces with positive travel between them. called by name so the
		# same suite runs, and reports the gap, against the code before the repair.
		var expected := chronological(requested)
		var motion_script: Object = load("res://scripts/r14_source_motion.gd")
		var has_rule := (motion_script as Script).get_script_method_list().any(func(m: Dictionary) -> bool: return m.name == "clip_to_planes")
		if has_rule:
			var first: Dictionary = motion_script.call("clip_to_planes", requested, requested, [n] as Array[Vector3], true)
			var second: Dictionary = motion_script.call("clip_to_planes", first.velocity, requested, [Vector3.UP] as Array[Vector3], true)
			check("pure_chronological_ramp_floor_%d" % hz, (second.velocity as Vector3).distance_to(expected) < 1e-4, {"got": second.velocity, "expected": expected})
		else:
			check("pure_chronological_ramp_floor_%d" % hz, false, "no pure plane rule in this motion module")
		# the old closest-cone rule's answer for the same two planes, kept as the negative case.
		check("pure_differs_from_primal_floor_clip_%d" % hz, absf(expected.z - requested.z) > 40.0, {"chronological_z": expected.z, "primal_z": requested.z})
		var cv := M.preset("csgo_server")
		var s := M.new_state(Vector3(0, 10000, 0))
		s.velocity = Vector3(4000, -4000, 4000)
		M.step(s, {}, cv, 1.0 / hz, FreeWorld.new())
		check("pure_stored_velocity_bounded_%d" % hz, absf(s.velocity.x) <= 3500.0 and absf(s.velocity.y) <= 3500.0 and absf(s.velocity.z) <= 3500.0, s.velocity)
		check("pure_travel_bounded_%d" % hz, (s.position as Vector3).distance_to(Vector3(3500, 10000.0 * hz - 3500, 3500) / hz) < 1e-3, s.position)
		var w := FreeWorld.new()
		w.extra = ["step"]
		var g := M.new_state()
		g.grounded = true
		g.ground_ticks = 5
		M.step(g, {"forward": 1.0}, cv, 1.0 / hz, w)
		var first_events: Array = (g.events as Array).duplicate()
		w.extra = []
		M.step(g, {"forward": 1.0}, cv, 1.0 / hz, w)
		check("pure_world_event_kept_then_fresh_%d" % hz, first_events == ["step"] and (g.events as Array).is_empty(), {"first": first_events, "next": g.events})

# --- live: the review's slope-to-floor reproduction --------------------------------------------

func group_ramp() -> void:
	var out_rows := {}
	for hz: int in [64, 128]:
		for speed: float in [250.0, 2000.0]:
			var trials: Array = []
			for trial: int in [1, 2]:
				var pose := Vector3(5000, 1.3, 15) if speed == 250.0 else Vector3(5000, 20, 0)
				var seed := Vector3(0, -400, 250) if speed == 250.0 else Vector3(0, -3000, 2000)
				var seq: Array = [{"keys": ["d"]}]
				for i: int in 7:
					seq.append({})
				var rows := await run_episode("ramp_floor_%d_speed%d_trial%d" % [hz, speed, trial], hz, seq, pose, seed, false)
				trials.append(rows)
				var at := two_plane_row(rows)
				var label_ := "%d_speed%d_trial%d" % [hz, speed, trial]
				check("ramp_floor_two_planes_one_tick_" + label_, at == 0, at)
				if at < 0:
					continue
				var row: Dictionary = rows[at]
				var expected := chronological(row.requested)
				var got: Vector3 = row.v
				check("ramp_floor_chronological_momentum_" + label_, hv(got).distance_to(hv(expected)) < 0.01, {"requested": row.requested, "stored": got, "expected": expected})
				# the retained momentum moves the body: the next released ground tick's friction
				# and its finite-difference travel both follow from the stored velocity.
				var next: Dictionary = rows[at + 1]
				var after_friction := hv(got) * (1.0 - 5.2 / hz)
				check("ramp_floor_next_tick_friction_" + label_, next.grounded and hv(next.v).distance_to(after_friction) < 0.01, {"stored": next.v, "expected": after_friction})
				check("ramp_floor_next_tick_travel_" + label_, hv(next.fd).distance_to(hv(next.v)) < fd_quantum(next.p, hz), {"fd": next.fd, "stored": next.v, "tolerance": fd_quantum(next.p, hz)})
				out_rows[label_] = {"requested": row.requested, "stored": got, "expected": expected, "contact_tick_fd": row.fd, "next_fd": next.fd, "depenetration": row.depenetration, "standoff": row.standoff}
			check("ramp_floor_repeatable_%d_speed%d" % [hz, speed], same_rows(trials[0], trials[1]) < 1e-6, same_rows(trials[0], trials[1]))
	findings["ramp_floor"] = out_rows

# --- live: an input-earned descent onto the ramp base ------------------------------------------

func group_earned() -> void:
	var out_rows := {}
	for hz: int in [64, 128]:
		var reproduced := 0
		var tried := 0
		for z: float in EARNED_Z:
			for height: float in EARNED_HEIGHTS:
				var seq: Array = [{"keys": ["d"]}]
				for i: int in int(hz * 0.6):
					seq.append({})
				var name := "earned_descent_%d_z%s_y%s" % [hz, z, height]
				var rows := await run_episode(name, hz, seq, Vector3(5000, height, z), Vector3.ZERO, false)
				tried += 1
				var at := two_plane_row(rows)
				if at < 0:
					out_rows[name] = {"two_planes": false}
					continue
				reproduced += 1
				var row: Dictionary = rows[at]
				var expected := chronological(row.requested)
				var err := hv(row.v).distance_to(hv(expected))
				var next: Dictionary = rows[at + 1] if at + 1 < rows.size() else row
				out_rows[name] = {"two_planes": true, "tick": at, "requested": row.requested, "stored": row.v, "expected": expected, "error": err, "next_fd": next.fd, "next_v": next.v}
				check("earned_chronological_momentum_" + name.trim_prefix("earned_descent_"), err < 0.01 and absf(expected.z) > 50.0, out_rows[name])
				check("earned_next_tick_travel_" + name.trim_prefix("earned_descent_"), hv(next.fd).distance_to(hv(next.v)) < fd_quantum(next.p, hz), {"fd": next.fd, "stored": next.v, "tolerance": fd_quantum(next.p, hz)})
		check("earned_two_plane_contacts_reached_%d" % hz, reproduced > 0, {"reproduced": reproduced, "tried": tried})
		# rerun the first reproduction: identical input, identical result.
		for name: String in out_rows:
			if name.begins_with("earned_descent_%d_" % hz) and out_rows[name].two_planes:
				var parts := name.trim_prefix("earned_descent_%d_z" % hz).split("_y")
				var seq: Array = [{"keys": ["d"]}]
				for i: int in int(hz * 0.6):
					seq.append({})
				var first: Array = await run_episode(name + "_repeat_a", hz, seq, Vector3(5000, float(parts[1]), float(parts[0])), Vector3.ZERO, false)
				var again: Array = await run_episode(name + "_repeat_b", hz, seq, Vector3(5000, float(parts[1]), float(parts[0])), Vector3.ZERO, false)
				check("earned_repeatable_%d" % hz, same_rows(first, again) < 1e-6 and two_plane_row(first) >= 0, {"episode": name, "difference": same_rows(first, again)})
				break
	findings["earned_descent"] = out_rows

# --- live: the per-axis limit after finish gravity ---------------------------------------------

func group_limit() -> void:
	for hz: int in [64, 128]:
		var finals: Array = []
		for trial: int in [1, 2]:
			var fall: Array = []
			for i: int in int(hz * 4.6):
				fall.append({"keys": ["d"]} if i < 3 else {})
			var rows := await run_episode("terminal_fall_%d_trial%d" % [hz, trial], hz, fall, Vector3(0, 10000, 0), Vector3.ZERO, false)
			var worst := 0.0
			for row: Dictionary in rows:
				worst = maxf(worst, (row.v as Vector3).abs()[(row.v as Vector3).abs().max_axis_index()])
			var last: Dictionary = rows[-1]
			check("earned_fall_stored_limit_%d_trial%d" % [hz, trial], worst <= 3500.0, {"worst_axis_u_s": worst, "final_v": last.v})
			check("earned_fall_travel_at_limit_%d_trial%d" % [hz, trial], absf(last.fd.y + 3500.0) < 0.1 and not last.grounded, {"fd": last.fd, "p": last.p})
			finals.append(rows)
		check("earned_fall_repeatable_%d" % hz, same_rows(finals[0], finals[1]) < 1e-6)
		var seeded := await run_episode("limit_seeded_%d" % hz, hz, [{"keys": ["d"]}, {}, {}], Vector3(0, 1000, 0), Vector3(4000, -4000, 4000), false)
		var ok := true
		for row: Dictionary in seeded:
			ok = ok and (row.v as Vector3).abs().x <= 3500.0 and (row.v as Vector3).abs().y <= 3500.0 and (row.v as Vector3).abs().z <= 3500.0
		check("seeded_all_axis_stored_limit_%d" % hz, ok and (seeded[0].fd as Vector3).distance_to(Vector3(3500, -3500, 3500)) < 0.1, {"v": seeded[0].v, "fd": seeded[0].fd})

# --- live: a fresh, truthful event report ------------------------------------------------------

func event_counts(rows: Array, start_counts: Dictionary) -> Dictionary:
	var seen := {"step": 0, "jump": 0, "land": 0}
	var duplicates := 0
	for row: Dictionary in rows:
		for e: String in seen:
			var n := (row.events as Array).count(e)
			seen[e] += n
			duplicates += maxi(0, n - 1)
	var last: Dictionary = rows[-1]
	return {"events": seen, "counters": {"step": last.steps - start_counts.step, "jump": last.jumps - start_counts.jump, "land": last.lands - start_counts.land}, "duplicates": duplicates}

func group_events() -> void:
	for hz: int in [64, 128]:
		for trial: int in [1, 2]:
			var seq: Array = []
			for i: int in int(hz * 3.2):
				seq.append({"keys": ["w"]})
			var rows := await run_episode("step_event_%d_trial%d" % [hz, trial], hz, seq, Vector3(1000, 0.5, 150))
			var step_rows := rows.filter(func(r: Dictionary) -> bool: return "step" in r.events)
			var counted := event_counts(rows, {"step": 0, "jump": 0, "land": 0})
			var rise := 0.0
			if not step_rows.is_empty():
				rise = (step_rows[0].d as Vector3).y
			check("step_event_matches_counter_%d_trial%d" % [hz, trial], step_rows.size() == 1 and counted.events.step == counted.counters.step and absf(rise - 18.0) < 0.05, {"rows": step_rows.size(), "counts": counted, "rise_u": rise})
		# an autohop chain with side strafes: jump/land/step events equal their counters.
		var chain: Array = []
		var runup := 80 if hz == 128 else 40
		for i: int in runup + hz * 3:
			var j := i - runup
			var keys: Array = ["w"] if j < 0 else ["space", "a" if (j / (hz / 4)) % 2 == 0 else "d"]
			chain.append({"keys": keys, "mouse": 0.0 if j < 0 else (-1.0 if (j / (hz / 4)) % 2 == 0 else 1.0) * (5.0 if hz == 128 else 10.0)})
		var rows := await run_episode("event_chain_%d" % hz, hz, chain, Vector3(0, 0.5, 0))
		var counted := event_counts(rows, {"step": 0, "jump": 0, "land": 0})
		check("chain_events_match_counters_%d" % hz, counted.events == counted.counters and counted.duplicates == 0 and counted.counters.jump >= 4, counted)
	var push: Array = []
	for i: int in 400:
		push.append({"keys": ["w"]})
	var lip := await run_episode("step19_blocks", 128, push, Vector3(1500, 0.5, 150))
	check("step_19_still_blocks", (lip[-1].p as Vector3).z > -200.0 and lip[-1].steps == 0, lip[-1].p)

# --- live: rest, wall and corner stops and their recoveries ------------------------------------

## position span per axis and the largest finite-difference speed over rows[from, to).
static func stillness(rows: Array, from: int, to: int) -> Dictionary:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var fd := 0.0
	var stored := 0.0
	var dep := 0.0
	for i: int in range(from, to):
		var p: Vector3 = rows[i].p
		lo = lo.min(p)
		hi = hi.max(p)
		fd = maxf(fd, (rows[i].fd as Vector3).length())
		stored = maxf(stored, (rows[i].v as Vector3).length())
		dep = maxf(dep, (rows[i].depenetration as Vector3).length())
	return {"span_u": hi - lo, "max_fd_u_s": fd, "max_stored_u_s": stored, "max_depenetration_u": dep}

func group_rest() -> void:
	var out_rows := {}
	for hz: int in [64, 128]:
		var rows := await run_episode("floor_rest_%d" % hz, hz, idle(hz * 3), Vector3(0, 0.5, 0))
		var still := stillness(rows, hz, rows.size())
		out_rows["floor_%d" % hz] = still
		check("floor_rest_still_%d" % hz, (still.span_u as Vector3).length() < 0.005 and still.max_fd_u_s < 0.5 and still.max_depenetration_u < 1e-4, still)
	for trial: int in [1, 2]:
		var crease: Array = []
		for i: int in 500:
			crease.append({"keys": ["w", "d"] if i < 400 else ["s", "a"]})
		var rows := await run_episode("corner_rest_recovery_trial%d" % trial, 128, crease, Vector3(3500, 0.5, 0))
		var still := stillness(rows, 300, 400)
		out_rows["corner_trial%d" % trial] = still
		check("corner_rest_still_trial%d" % trial, (still.span_u as Vector3).length() < 0.005 and still.max_fd_u_s < 0.5 and still.max_stored_u_s < 0.1, still)
		var at_rest: Vector3 = rows[399].p
		check("corner_within_limits_trial%d" % trial, at_rest.x <= 3668.0 + 0.005 and at_rest.z >= -368.0 - 0.005, at_rest)
		check("corner_recovers_trial%d" % trial, rows[-1].p.x < at_rest.x - 50 and rows[-1].p.z > at_rest.z + 50, rows[-1].p)
		var wall: Array = []
		for i: int in 560:
			wall.append({"keys": ["w"] if i < 400 else (["s", "space"] if i == 400 else ["s"]), "mouse": 15.0 if i >= 401 and i < 411 else 0.0})
		rows = await run_episode("wall_rest_recovery_trial%d" % trial, 128, wall, Vector3(2500, 0.5, 150))
		still = stillness(rows, 300, 400)
		out_rows["wall_trial%d" % trial] = still
		check("wall_rest_still_trial%d" % trial, (still.span_u as Vector3).length() < 0.005 and still.max_fd_u_s < 0.5 and still.max_stored_u_s < 0.1, still)
		check("wall_within_limit_trial%d" % trial, (rows[399].p as Vector3).z >= -218.0 - 0.005, rows[399].p)
		check("wall_recovers_trial%d" % trial, rows[-1].p.z > rows[399].p.z + 100 and rows[-1].jumps == 1, rows[-1].p)
	findings["rest"] = out_rows

# --- live: free flight travels exactly the requested velocity, takeoff included ----------------

func group_travel() -> void:
	var out_rows := {}
	for hz: int in [64, 128]:
		for mode: String in ["sync", "wrong", "coast"]:
			var seq: Array = []
			var runup := 80 if hz == 128 else 40
			for i: int in runup + hz * 2:
				var j := i - runup
				var keys: Array = ["w"] if j < 0 else ["space"]
				var mouse := 0.0
				if j >= 0:
					var left := (j / (hz / 4)) % 2 == 0
					if mode != "coast" or j < 12:
						keys.append("a" if left else "d")
					mouse = (-1.0 if left else 1.0) * (5.0 if hz == 128 else 10.0) + sin(float(j) * 0.7) * 0.8
					if mode == "wrong":
						mouse *= -1.0
				seq.append({"keys": keys, "mouse": mouse})
			var rows := await run_episode("free_travel_%d_%s" % [hz, mode], hz, seq, Vector3(0, 0.5, 0))
			var worst := 0.0
			var raw := 0.0
			var takeoff := 0.0
			var free_rows := 0
			var dep := 0.0
			for row: Dictionary in rows:
				dep = maxf(dep, (row.depenetration as Vector3).length())
				if row.grounded or not (row.contacts as Array).is_empty():
					continue
				free_rows += 1
				raw = maxf(raw, (row.fd as Vector3).distance_to(row.requested))
				# beyond the float32 position resolution at that point.
				var err := maxf(0.0, (row.fd as Vector3).distance_to(row.requested) - fd_quantum(row.p, hz))
				worst = maxf(worst, err)
				if "jump" in row.events:
					takeoff = maxf(takeoff, err)
			out_rows["%d_%s" % [hz, mode]] = {"free_rows": free_rows, "worst_beyond_quantum_u_s": worst, "worst_raw_u_s": raw, "worst_takeoff_beyond_quantum_u_s": takeoff, "max_depenetration_u": dep, "jumps": rows[-1].jumps}
			check("free_travel_exact_%d_%s" % [hz, mode], free_rows > hz and worst < 0.015 and rows[-1].jumps >= 3, out_rows["%d_%s" % [hz, mode]])
	findings["free_travel"] = out_rows

# --- native moving evidence: the same fixture with visible boxes and an observer ---------------

func build_visuals() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	root.add_child(sun)
	for body: Node in world.get_children():
		var shape: BoxShape3D = (body.get_child(0) as CollisionShape3D).shape
		var colour := Color(0.42, 0.42, 0.44) if String(body.name).begins_with("floor") else (Color(0.85, 0.5, 0.2) if body.name == "ramp50" else Color(0.3, 0.45, 0.75))
		add_mesh(body as Node3D, shape.size, colour)
	# visual-only floor stripes every 64 u so sliding speed is visible; no collision.
	for i: int in 80:
		var stripe := Node3D.new()
		stripe.position = Vector3(5000, 0.05, 40 + i * 64) * U
		world.add_child(stripe)
		add_mesh(stripe, Vector3(400, 0.1, 8) * U, Color(0.95, 0.95, 0.95))
	add_mesh(player, Vector3(32, 72, 32) * U, Color(0.2, 0.8, 0.35), Vector3(0, 36, 0) * U)
	observer = Camera3D.new()
	observer.fov = 60
	root.add_child(observer)
	observer.make_current()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 26)
	hud.add_theme_color_override("font_color", Color.WHITE)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(hud)

func add_mesh(parent: Node3D, size: Vector3, colour: Color, offset := Vector3.ZERO) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	shape.material = material
	mesh.mesh = shape
	mesh.position = offset
	parent.add_child(mesh)

func update_hud(s: Dictionary) -> void:
	var p: Vector3 = player.global_position
	observer.global_position = p + Vector3(-360, 80, -40) * U
	observer.look_at(p + Vector3(0, 10, 60) * U)
	var stored := hv(player.velocity / U).length()
	var travel := hv(s.actual_velocity / U).length()
	hud.text = "%s\n%s  tick %d at %d Hz (labelled fixture)\nstored horizontal %.1f u/s   travel %.1f u/s\ncontacts %d  events %s" % [label, episode_name, tick, int(player.settings.tickrate), stored, travel, (s.contacts as Array).size(), str(s.events)]

## the visible cases: one seeded high-speed and one input-earned slope-to-floor contact.
func visual_cases() -> void:
	var seq: Array = [{"keys": ["d"]}]
	for i: int in 160:
		seq.append({})
	await run_episode("visual_seeded_2000", 128, seq, Vector3(5000, 20, 0), Vector3(0, -3000, 2000), false)
	await run_episode("visual_seeded_250", 128, seq, Vector3(5000, 1.3, 15), Vector3(0, -400, 250), false)
	var earned: Array = [{"keys": ["d"]}]
	for i: int in 200:
		earned.append({})
	await run_episode("visual_earned_descent", 128, earned, Vector3(5000, 101.0, 15.5), Vector3.ZERO, false)

static func plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is float and (is_inf(value) or is_nan(value)):
		return str(value)
	if value is Dictionary:
		var d := {}
		for k: Variant in value:
			d[str(k)] = plain(value[k])
		return d
	if value is Array:
		var a := []
		for v: Variant in value:
			a.append(plain(v))
		return a
	return value

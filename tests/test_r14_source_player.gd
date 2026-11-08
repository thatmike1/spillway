extends SceneTree
## p / r14 source runner on real collision, driven only by input events. every episode has one
## labelled setup between motor steps (key releases, the profile, the engine rate, one
## reset_to pose and, for seeded episodes only, one velocity write), then settle ticks with no
## input, then key and relative-mouse events delivered before the motor (priority -1000) and
## the motor sampled after it (1000). nothing is reset or written during a proof.
## mouse curves come from an open-loop plan made with the pure module before the episode
## starts; the plan's own flat-plane prediction is stored beside the real result.
## gates are behavior the motor promises; findings are measurements reported for review.
## godot --headless --fixed-fps 128 --path . --script res://tests/test_r14_source_player.gd --
##   [--out=DIR] [--only=strafe,retention,ground,chain,jump,slopes,corner,seams,lips,gap,switch]

const MAIN := preload("res://scripts/spillway_main.gd")
const LAB := preload("res://scripts/r14_source_lab.gd")
const PLAYER := preload("res://scripts/r14_source_player.gd")
const M := preload("res://scripts/r14_source_motion.gd")
const U: float = M.U
const GROUPS := ["strafe", "retention", "ground", "chain", "jump", "slopes", "corner", "seams", "lips", "gap", "switch"]
const KEYS := ["w", "a", "s", "d", "space", "ctrl"]
const SETTLE := 8

signal episode_done

class Probe:
	extends Node
	var suite: Object
	var early: bool

	func _physics_process(_delta: float) -> void:
		suite.call("early_tick" if early else "late_tick")

var out_dir := "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/source-motor/player"
var groups: Array = GROUPS.duplicate()
var fixture: Node3D
var player: CharacterBody3D
var events: Dictionary = {}
var rows: Array[Dictionary] = []
var tick := 0
var length := 0
var running := false
var pre_steps := 0
var order_violations: Array[String] = []
var checks: Array[Dictionary] = []
var findings: Dictionary = {}
var episodes: Dictionary = {}
var await_rows: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			groups = Array(arg.trim_prefix("--only=").split(","))
	_run.call_deferred()

func _run() -> void:
	MAIN.bind_inputs()
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("traces"))
	fixture = LAB.Fixture.new()
	fixture.name = "SourceFixture"
	root.add_child(fixture)
	fixture.call("build", false)
	player = PLAYER.new()
	player.name = "SourceRunner"
	root.add_child(player)
	for early: bool in [true, false]:
		var probe := Probe.new()
		probe.suite = self
		probe.early = early
		probe.process_physics_priority = -1000 if early else 1000
		root.add_child(probe)
	await process_frame
	for group: String in GROUPS:
		if group in groups:
			await call("group_" + group)
	check("ordering_one_motor_step_per_tick", order_violations.is_empty(), "%d violations %s" % [order_violations.size(), order_violations.slice(0, 3)])
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.pass)
	var summary := {
		"engine": Engine.get_version_info(), "physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine", "<unset>"),
		"fixed_fps_note": "run with --fixed-fps 128; 64 Hz episodes step physics every other frame",
		"groups": groups, "checks": checks, "findings": findings, "episodes": episodes,
		"gates": checks.size(), "failed": failed.size(),
	}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_plain(summary), "\t"))
	file.close()
	print("r14 source player: %d checks, %d failed; summary %s" % [checks.size(), failed.size(), out_dir.path_join("summary.json")])
	for c: Dictionary in failed:
		print("FAIL ", c.name, ": ", c.detail)
	quit(0 if failed.is_empty() else 1)

func check(name: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"name": name, "pass": ok, "detail": str(detail)})
	print("%s %s %s" % ["ok  " if ok else "FAIL", name, str(detail)])

# --- episode machinery ----------------------------------------------------------------------

## the labelled setup, then the tape. returns the rows (one per motor step after setup).
func episode(name: String, preset: String, pose: Transform3D, tape: Dictionary, ticks: int, overrides := {}, seed_velocity_u := Vector3.ZERO) -> Array[Dictionary]:
	for key: String in KEYS:
		LAB.send([key, false])
	player.call("apply_preset", preset, overrides)
	player.call("apply_engine_rate")
	player.call("reset_to", pose)
	if seed_velocity_u != Vector3.ZERO:
		player.velocity = seed_velocity_u * U
	events = tape
	rows = []
	tick = 0
	length = ticks + SETTLE
	running = true
	await episode_done
	var lines := PackedStringArray()
	for r: Dictionary in rows:
		lines.append(JSON.stringify(_plain(r)))
	LAB.write_gzip(out_dir.path_join("traces").path_join(name + ".jsonl.gz"), lines)
	episodes[name] = {"preset": preset, "ticks": ticks, "settle": SETTLE, "pose_u": pose.origin / U, "seed_velocity_u": seed_velocity_u, "tape_events": tape.size()}
	return rows.duplicate()

func early_tick() -> void:
	if not running:
		return
	tick += 1
	pre_steps = int(player.get("tape_step_count"))
	for event: Array in events.get(tick - SETTLE, []):
		LAB.send(event)

func late_tick() -> void:
	if not running:
		return
	var steps := int(player.get("tape_step_count"))
	if steps != pre_steps + 1:
		order_violations.append("tick %d: %d -> %d" % [tick, pre_steps, steps])
	var s: Dictionary = player.call("get_motion_state")
	var r := LAB.row(s)
	r["pt"] = tick - SETTLE
	r["dt"] = s.delta
	r["req"] = (s.requested_velocity as Vector3) / U
	var hop: Dictionary = s.last_hop
	r["hop"] = hop if "land" in s.events and hop.has("landing") and int(hop.landing_tick) == int(player.get("state").tick) else null
	r["perfect"] = s.perfect_count
	r["steps"] = s.step_ups
	r["rate_ok"] = s.rate_matches
	rows.append(r)
	if tick >= length:
		running = false
		episode_done.emit()

## per-tick key sets and mouse counts to edge events: {tick: [[key, pressed] | ["mouse", n]]}.
static func to_tape(frames: Array) -> Dictionary:
	var tape := {}
	var held := {}
	for i: int in frames.size():
		var f: Dictionary = frames[i]
		var t := i + 1
		var list := []
		var want: Array = f.get("keys", [])
		for key: String in held.keys():
			if not key in want:
				list.append([key, false])
				held.erase(key)
		for key: String in want:
			if not held.has(key):
				list.append([key, true])
				held[key] = true
		if int(f.get("mouse", 0)) != 0:
			list.append(["mouse", int(f.mouse)])
		if not list.is_empty():
			tape[t] = list
	var last := frames.size() + 1
	for key: String in held.keys():
		tape[last] = tape.get(last, []) + [[key, false]]
	return tape

static func scaled(frames: Array, scale: float, delay := 0) -> Array:
	var out := []
	for f: Dictionary in frames:
		out.append({"keys": f.keys, "mouse": 0})
	for i: int in frames.size():
		if i + delay < out.size():
			out[i + delay].mouse = int(round(float(frames[i].mouse) * scale))
	return out

static func hops_of(r: Array[Dictionary]) -> Array:
	var out := []
	for row: Dictionary in r:
		if row.hop != null:
			out.append(row.hop)
	return out

static func speed(row: Dictionary) -> float:
	return Vector2(row.v[0], row.v[2]).length()

static func landing_speeds(r: Array[Dictionary]) -> Array:
	return hops_of(r).map(func(h: Dictionary) -> float: return float(h.landing))

func pose_u(at: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), at * U)

# --- groups -----------------------------------------------------------------------------------

## synchronized and mismatched a/d mouse curves, both profiles.
func group_strafe() -> void:
	var out := {}
	for config: Array in [["csgo_server", 72, 48, 3, 520], ["csgo_vanilla", 35, 24, 3, 260]]:
		var preset: String = config[0]
		var plan := LAB.plan_strafe(preset, config[1], config[3], config[2], "hold" if preset == "csgo_server" else "press", config[4])
		var variants := {"synced": plan.frames, "half_turn": scaled(plan.frames, 0.5), "double_turn": scaled(plan.frames, 2.0), "opposite_turn": scaled(plan.frames, -1.0), "late_mouse_8": scaled(plan.frames, 1.0, 8), "keys_no_mouse": scaled(plan.frames, 0.0)}
		var result := {"predicted_landings": plan.predicted_landings}
		for v: String in variants:
			var r := await episode("strafe_%s_%s" % [preset, v], preset, LAB.Fixture.pose("runway"), to_tape(variants[v]), config[4])
			if v == "synced":
				await_rows[preset] = r
			var hops := hops_of(r)
			result[v] = {"landings": landing_speeds(r), "sync": hops.map(func(h: Dictionary) -> Variant: return h.sync), "air_ticks": hops.map(func(h: Dictionary) -> int: return h.air_ticks), "final_u": speed(r[-1]), "perfect": r[-1].perfect, "jumps": int(player.get("jump_count"))}
		out[preset] = result
		var synced: Array = result.synced.landings
		var predicted: Array = plan.predicted_landings
		# the server chain keeps every gain; vanilla's takeoff clamp returns each hop to 275, so
		# there the promise is a positive air gain on every hop, not a rising landing speed.
		var gains: Array = hops_of(await_rows[preset]).map(func(h: Dictionary) -> float: return float(h.gain))
		if preset == "csgo_server":
			check("strafe_%s_synced_gains_each_hop" % preset, synced.size() >= 2 and _increasing(synced), synced)
		else:
			check("strafe_%s_synced_air_gain_each_hop" % preset, gains.size() >= 2 and gains.all(func(g: float) -> bool: return g > 20.0), gains)
		if synced.size() > 0 and predicted.size() > 0:
			var n := mini(synced.size(), predicted.size())
			var worst := 0.0
			for i: int in n:
				worst = maxf(worst, absf(float(synced[i]) - float(predicted[i])) / float(predicted[i]))
			check("strafe_%s_synced_matches_flat_prediction_1pct" % preset, worst < 0.01, "worst relative %.5f; real %s predicted %s" % [worst, synced, predicted.slice(0, n)])
		for v: String in ["half_turn", "double_turn", "opposite_turn", "keys_no_mouse"]:
			var best := _max(result[v].landings)
			check("strafe_%s_%s_below_synced" % [preset, v], best < _max(synced), "%s best %.2f vs synced %.2f" % [v, best, _max(synced)])
		check("strafe_%s_synced_sync_full" % preset, result.synced.sync.all(func(x: Variant) -> bool: return x != null and float(x) >= 0.95), result.synced.sync)
		check("strafe_%s_opposite_sync_low" % preset, result.opposite_turn.sync.all(func(x: Variant) -> bool: return x == null or float(x) <= 0.05), result.opposite_turn.sync)
	findings["strafe"] = out

## no-input airborne retention and w-only steering, after real strafe hops.
func group_retention() -> void:
	var out := {}
	for preset: String in ["csgo_server", "csgo_vanilla"]:
		var cv := M.preset(preset)
		var hz := int(cv.tickrate)
		var plan := LAB.plan_strafe(preset, 72 if hz == 128 else 35, 1, 48 if hz == 128 else 24, "press", 400)
		var frames: Array = plan.frames
		# after the first hop's take-off plus 20 air ticks: release everything, keep turning the view.
		var cut := (72 if hz == 128 else 35) + 20
		var released := frames.slice(0, cut)
		for i: int in range(cut, frames.size()):
			released.append({"keys": [], "mouse": 6 if (i / 30) % 2 == 0 else -6})
		var r := await episode("retention_%s" % preset, preset, LAB.Fixture.pose("runway"), to_tape(released), frames.size())
		var start := -1
		var drift := 0.0
		var reference := 0.0
		var air_ticks := 0
		for row: Dictionary in r:
			if row.pt > cut and not row.g:
				if start < 0:
					start = row.pt
					reference = speed(row)
				drift = maxf(drift, absf(speed(row) - reference))
				air_ticks += 1
			elif start >= 0 and row.g:
				break
		check("retention_%s_release_keeps_line" % preset, air_ticks > 10 and drift < 1e-3, "%d released air ticks, max speed drift %.6f u/s at %.3f" % [air_ticks, drift, reference])
		# w only with the view turning: projection rules give at most a 30 u/s wish projection.
		var w_frames := frames.slice(0, cut)
		for i: int in range(cut, frames.size()):
			w_frames.append({"keys": ["w"], "mouse": -8})
		var rw := await episode("w_turn_%s" % preset, preset, LAB.Fixture.pose("runway"), to_tape(w_frames), frames.size())
		var before := speed(rw[cut + SETTLE - 1])
		var peak := 0.0
		for row: Dictionary in rw:
			if row.pt > cut and not row.g:
				peak = maxf(peak, speed(row))
		out[preset] = {"release_air_ticks": air_ticks, "release_drift": drift, "release_speed": reference, "w_turn_before": before, "w_turn_peak": peak}
		check("w_turn_%s_mints_no_speed" % preset, peak <= before + 1e-3, "before %.3f, peak while w+turn %.3f" % [before, peak])
	findings["retention"] = out

## ground acceleration from rest and friction after release, against the pure module.
func group_ground() -> void:
	var out := {}
	for preset: String in ["csgo_vanilla", "csgo_server"]:
		var hz := int(M.preset(preset).tickrate)
		var frames := []
		for i: int in 120:
			frames.append({"keys": ["w"]})
		for i: int in 60:
			frames.append({"keys": []})
		var r := await episode("ground_%s" % preset, preset, LAB.Fixture.pose("runway"), to_tape(frames), frames.size())
		var reach := -1
		for row: Dictionary in r:
			if row.pt >= 1 and speed(row) >= 250.0 - 1e-3 and reach < 0:
				reach = row.pt
		var release_first := speed(r[120 + SETTLE])
		var flat := _flat_ground(preset, frames.size())
		var worst := 0.0
		for i: int in frames.size():
			worst = maxf(worst, absf(speed(r[i + SETTLE]) - float(flat[i])))
		out[preset] = {"reach_250_tick": reach, "release_first": release_first, "worst_vs_flat": worst, "release_curve": r.slice(120 + SETTLE, 152 + SETTLE).map(func(row: Dictionary) -> float: return speed(row))}
		check("ground_%s_runup_ticks" % preset, reach == (35 if hz == 64 else 72), "reached 250 at tick %d" % reach)
		check("ground_%s_release_first_tick" % preset, absf(release_first - (229.6875 if hz == 64 else 239.84375)) < 1e-2, release_first)
		check("ground_%s_matches_flat_module" % preset, worst < 1e-2, "worst %.5f u/s" % worst)
	findings["ground"] = out

func _flat_ground(preset: String, n: int) -> Array:
	var cv := M.preset(preset)
	var s := M.new_state()
	s.grounded = true
	s.ground_ticks = 100
	var out := []
	for i: int in n:
		M.step(s, {"forward": 1.0 if i < 120 else 0.0}, cv, 1.0 / float(cv.tickrate), M.FlatWorld.new())
		out.append(Vector2(s.velocity.x, s.velocity.z).length())
	return out

## standing-start chains: the oracle's fixture with the real ground probe and contacts.
func group_chain() -> void:
	var out := {}
	for config: Array in [["csgo_server", 72, 96, {}], ["csgo_server", 72, 96, {"air_surface": "constant"}], ["csgo_vanilla", 35, 48, {"sv_enablebunnyhopping": true, "sv_staminamax": 0.0, "stamina_model": "off", "sv_autobunnyhopping": true}]]:
		var preset: String = config[0]
		var label := preset + ("_" + "_".join(config[3].keys()) if not config[3].is_empty() else "")
		var plan := LAB.plan_strafe(preset, config[1], 5, config[2], "hold", config[1] + config[2] * 5 + 40, config[3])
		var r := await episode("chain_%s" % label.replace(",", ""), preset, LAB.Fixture.pose("runway"), to_tape(plan.frames), plan.frames.size(), config[3])
		var hops := hops_of(r)
		out[label] = {"landings": landing_speeds(r).slice(0, 5), "predicted": plan.predicted_landings.slice(0, 5), "air_ticks": hops.map(func(h: Dictionary) -> int: return h.air_ticks).slice(0, 5), "perfect": r[-1].perfect}
		check("chain_%s_five_landings" % label, hops.size() >= 5, out[label])
	findings["chain"] = out

## vanilla jump order: held key jumps once, a first-tick press chains, a late press walks one
## tick and meets the clamp, stamina lowers the next jump. scroll pulses give a measured rate.
func group_jump() -> void:
	var out := {}
	var held := []
	for i: int in 400:
		held.append({"keys": ["space"]})
	var r := await episode("jump_held_vanilla", "csgo_vanilla", LAB.Fixture.pose("runway"), to_tape(held), held.size())
	check("jump_vanilla_held_jumps_once", int(r[-1].perfect) == 0 and _count(r, "jump") == 1, "jumps %d" % _count(r, "jump"))
	var rs := await episode("jump_held_server", "csgo_server", LAB.Fixture.pose("runway"), to_tape(held), held.size())
	var auto_jumps := _count(rs, "jump")
	check("jump_server_held_autohops", auto_jumps >= 4 and int(rs[-1].perfect) == auto_jumps - 1, "jumps %d, first-tick %d" % [auto_jumps, rs[-1].perfect])
	# land before jump: every first-tick hop's jump tick directly follows a land tick.
	var adjacent := true
	for i: int in range(1, rs.size()):
		if "perfect" in rs[i].e:
			adjacent = adjacent and "land" in rs[i - 1].e
	check("jump_order_land_then_jump_next_tick", adjacent)
	var apexes := _apexes(rs)
	out["server_held_apex_u"] = apexes
	check("jump_server_apex_source_order", apexes.size() > 0 and absf(float(apexes[0]) - 55.8256) < 0.05, apexes)
	for mode: String in ["press", "late", "scroll"]:
		var plan := LAB.plan_strafe("csgo_vanilla", 35, 5, 24, mode, 420)
		var rv := await episode("jump_vanilla_%s" % mode, "csgo_vanilla", LAB.Fixture.pose("runway"), to_tape(plan.frames), plan.frames.size())
		var hops := hops_of(rv)
		var walk_ticks := 0
		var clamp_ok := true
		for i: int in range(1, rv.size()):
			if rv[i - 1].g and rv[i].g and rv[i].pt > 36:
				walk_ticks += 1
				clamp_ok = clamp_ok and speed(rv[i]) <= 250.0 + 1e-3
		out["vanilla_" + mode] = {"jumps": _count(rv, "jump"), "perfect": rv[-1].perfect, "walk_ticks": walk_ticks, "landings": landing_speeds(rv), "apex_u": _apexes(rv), "stamina_peak": rv.map(func(x: Dictionary) -> float: return float(x.st)).max(), "predicted_perfect": plan.predicted_perfect}
		check("jump_vanilla_%s_walk_clamped" % mode, clamp_ok, out["vanilla_" + mode])
	check("jump_vanilla_press_chains", int(out.vanilla_press.perfect) >= 4, out.vanilla_press)
	check("jump_vanilla_late_walks", int(out.vanilla_late.walk_ticks) >= 1 and int(out.vanilla_late.perfect) == 0, out.vanilla_late)
	var press_apex: Array = out.vanilla_press.apex_u
	check("jump_vanilla_stamina_lowers_next", press_apex.size() >= 2 and float(press_apex[1]) < float(press_apex[0]) - 5.0, press_apex)
	findings["jump"] = out

func _apexes(r: Array[Dictionary]) -> Array:
	var out := []
	var peak := -1e9
	var flying := false
	for row: Dictionary in r:
		if not row.g:
			flying = true
			peak = maxf(peak, float(row.p[1]))
		elif flying:
			out.append(peak)
			peak = -1e9
			flying = false
	return out

static func _count(r: Array[Dictionary], name: String) -> int:
	var n := 0
	for row: Dictionary in r:
		if name in row.e:
			n += 1
	return n

## walking up 20, 30 and 45 degree ramps holds ground; 50 degrees cannot be walked; a body
## dropped onto the 50 degree face is not grounded and slides down it.
func group_slopes() -> void:
	var out := {}
	var lane := 11520.0
	for degrees: int in [20, 30, 45, 50]:
		var frames := []
		for i: int in 640:
			frames.append({"keys": ["w"]})
		var r := await episode("slope_walk_%d" % degrees, "csgo_server", pose_u(Vector3(lane, 0.5, 256)), to_tape(frames), frames.size())
		var top := 0.0
		var air_on_ramp := 0
		var max_speed := 0.0
		var ramp_speeds := []
		for row: Dictionary in r:
			top = maxf(top, float(row.p[1]))
			max_speed = maxf(max_speed, speed(row))
			if float(row.p[2]) < -300 and row.g:
				ramp_speeds.append(Vector2(row.d[0], row.d[2]).length() / float(row.dt))
			if float(row.p[2]) < -256 and not row.g and float(row.p[1]) < 500 * tan(deg_to_rad(degrees)):
				air_on_ramp += 1
		out["walk_%d" % degrees] = {"ramp_horizontal_travel_u_s": [ramp_speeds.min() if not ramp_speeds.is_empty() else null, ramp_speeds.max() if not ramp_speeds.is_empty() else null], "top_u": top, "air_ticks_on_ramp": air_on_ramp, "max_speed": max_speed, "final": r[-1].p, "steps": r[-1].steps}
		if degrees < 46:
			check("slope_walk_%d_climbs" % degrees, top > 300.0 * tan(deg_to_rad(degrees)), out["walk_%d" % degrees])
		else:
			# held w into a 50 degree face is never support. the air rules alone can still carry
			# the body up it; that height is a reported finding, not a cs observation.
			var grounded_on_face := r.filter(func(row: Dictionary) -> bool: return row.g and float(row.p[2]) < -264.0).size()
			out["walk_50"]["grounded_ticks_on_face"] = grounded_on_face
			check("slope_walk_50_never_support", grounded_on_face == 0, out["walk_50"])
		lane += 320.0
	# drop onto the 50 degree face from above its middle, with no input.
	var r := await episode("slope_drop_50", "csgo_server", pose_u(Vector3(12480, 380, -500)), to_tape([{"keys": []}]), 240)
	var grounded_on_face := 0
	for row: Dictionary in r:
		if row.g and float(row.p[2]) < -256 - 8:
			grounded_on_face += 1
	out["drop_50"] = {"grounded_ticks_on_face": grounded_on_face, "final": r[-1].p, "final_speed": speed(r[-1])}
	check("slope_drop_50_slides_not_grounded", grounded_on_face == 0 and float(r[-1].p[2]) > -300.0, out["drop_50"])
	findings["slopes"] = out

## an inner corner stops a diagonal run without penetration; a wall glance keeps its tangent.
func group_corner() -> void:
	var out := {}
	var frames := []
	for i: int in 640:
		frames.append({"keys": ["w", "d"]})
	var r := await episode("corner_inner", "csgo_server", pose_u(Vector3(16000, 0.5, 0)), to_tape(frames), frames.size())
	var last: Dictionary = r[-1]
	var limit_x := 16000 + 512 - 16.0
	var limit_z := -512 + 16.0
	var inside := true
	for row: Dictionary in r:
		inside = inside and float(row.p[0]) <= limit_x + 0.05 and float(row.p[2]) >= limit_z - 0.05
	out["inner"] = {"final": last.p, "final_speed": speed(last), "inside": inside}
	check("corner_inner_no_penetration", inside, out.inner)
	check("corner_inner_stops", speed(last) < 1.0 and absf(float(last.p[0]) - limit_x) < 1.0 and absf(float(last.p[2]) - limit_z) < 1.0, out.inner)
	# seeded fixture: 400 u/s airborne at 30 degrees into the x wall, no input.
	# upward speed above 140 u/s, so the ground probe cannot catch the seeded flight at once.
	var seed := Vector3(sin(deg_to_rad(30.0)) * 400.0, 200.0, -cos(deg_to_rad(30.0)) * 400.0)
	var rg := await episode("corner_glance", "csgo_server", pose_u(Vector3(15700, 8, -440)), to_tape([{"keys": []}]), 60, {}, seed)
	var touched := -1
	for i: int in rg.size():
		if rg[i].c.size() > 0 and not rg[i].g and touched < 0:
			touched = i
	var after: Dictionary = rg[mini(touched + 2, rg.size() - 1)] if touched >= 0 else rg[-1]
	out["glance"] = {"touch_tick": touched, "after_v": after.v, "tangent_expected": seed.x}
	check("corner_glance_keeps_tangent", touched >= 0 and absf(float(after.v[0]) - seed.x) < 0.5 and absf(float(after.v[2])) < 0.5, out.glance)
	findings["corner"] = out

## sixteen coplanar bodies: walking and autohopping across seams loses nothing to them.
func group_seams() -> void:
	var out := {}
	var frames := []
	for i: int in 720:
		frames.append({"keys": ["w"]})
	var r := await episode("seams_walk", "csgo_server", pose_u(Vector3(20000, 0.5, 200)), to_tape(frames), frames.size())
	var min_speed := 1e9
	var bad := []
	for row: Dictionary in r:
		if row.pt > 80 and float(row.p[2]) > -2100:
			min_speed = minf(min_speed, speed(row))
		for c: Array in row.c:
			if float(c[3]) < 0.99:
				bad.append([row.pt, c])
	out["walk"] = {"min_speed_after_runup": min_speed, "non_floor_contacts": bad.slice(0, 8), "final": r[-1].p}
	check("seams_walk_no_loss", min_speed >= 249.9, out.walk)
	check("seams_walk_no_edge_contacts", bad.is_empty(), bad.slice(0, 4))
	var hop := []
	for i: int in 300:
		hop.append({"keys": ["space"] if i > 72 else ["w"]})
	var rh := await episode("seams_hop", "csgo_server", pose_u(Vector3(20000, 0.5, 200)), to_tape(hop), hop.size())
	var landings := landing_speeds(rh)
	out["hop"] = {"landings": landings, "final": rh[-1].p}
	check("seams_hop_landings_keep_speed", landings.size() >= 2 and landings.all(func(x: float) -> bool: return absf(x - float(landings[0])) < 1e-2), landings)
	findings["seams"] = out

## walking into 8, 16 and 18 u lips steps up; 19 and 24 u block a walk.
func group_lips() -> void:
	var out := {}
	var x := 23424.0
	for height: int in [8, 16, 18, 19, 24]:
		var frames := []
		for i: int in 400:
			frames.append({"keys": ["w"]})
		var r := await episode("lip_%d" % height, "csgo_server", pose_u(Vector3(x, 0.5, 300)), to_tape(frames), frames.size())
		var last: Dictionary = r[-1]
		out[str(height)] = {"final": last.p, "steps": last.steps, "final_speed": speed(last)}
		if height <= 18:
			check("lip_%d_steps_up" % height, absf(float(last.p[1]) - height) < 0.5 and int(last.steps) >= 1 and float(last.p[2]) < -300, out[str(height)])
		else:
			check("lip_%d_blocks_walk" % height, float(last.p[1]) < 1.0 and float(last.p[2]) > -260, out[str(height)])
		x += 288.0
	findings["lips"] = out

## a gap jump: real displacement across 160 u, with free-flight travel equal to the requested
## velocity each tick and every tick's step accounted for.
func group_gap() -> void:
	var out := {}
	# the jump tick comes from the flat prediction of when the feet pass z = -980 u.
	var cv := M.preset("csgo_server")
	var s := M.new_state(Vector3(0, 0, -500))
	s.grounded = true
	s.ground_ticks = 100
	var jump_at := 0
	for t: int in range(1, 1000):
		M.step(s, {"forward": 1.0}, cv, 1.0 / 128.0, M.FlatWorld.new())
		if s.position.z < -1010.0:
			jump_at = t
			break
	var frames := []
	for i: int in jump_at + 200:
		frames.append({"keys": ["w", "space"] if i + 1 == jump_at else (["w"] if i + 1 < jump_at else [])})
	var r := await episode("gap_jump", "csgo_server", pose_u(Vector3(28000, 0.5, -500)), to_tape(frames), frames.size())
	var worst_free := 0.0
	var path := 0.0
	for row: Dictionary in r:
		var d := Vector3(row.d[0], row.d[1], row.d[2])
		path += d.length()
		if row.c.is_empty() and not row.g and row.e.is_empty():
			# free flight: travel equals the velocity that entered the move times dt.
			var req: Vector3 = row.req
			worst_free = maxf(worst_free, (d - req * float(row.dt)).length())
	var last: Dictionary = r[-1]
	out = {"jump_tick": jump_at, "final": last.p, "landed_far": float(last.p[2]) < -1184.0 and absf(float(last.p[1])) < 1.0, "worst_free_flight_error_u": worst_free, "path_u": path}
	check("gap_jump_lands_far_deck", out.landed_far, out)
	check("gap_free_flight_travel_exact", worst_free < 1e-3, worst_free)
	check("cadence_rate_and_delta", r.all(func(x: Dictionary) -> bool: return x.rate_ok and absf(float(x.dt) - 1.0 / 128.0) < 1e-9), "128 Hz episode")
	findings["gap"] = out

## a profile switch mid-flight (an api call, labelled, not input) keeps position, velocity and
## view, and switching into the server profile clears stamina.
func group_switch() -> void:
	var frames := []
	for i: int in 200:
		frames.append({"keys": ["w"] if i < 40 else (["w", "space"] if i == 40 else [])})
	events = to_tape(frames)
	for key: String in KEYS:
		LAB.send([key, false])
	player.call("apply_preset", "csgo_vanilla")
	player.call("apply_engine_rate")
	player.call("reset_to", LAB.Fixture.pose("runway"))
	rows = []
	tick = 0
	length = 60 + SETTLE
	running = true
	await episode_done
	var before: Dictionary = player.call("get_motion_state")
	player.call("apply_preset", "csgo_server")
	var after: Dictionary = player.call("get_motion_state")
	check("switch_keeps_pose_velocity_view", (before.position as Vector3) == (after.position as Vector3) and (before.post_contact_velocity as Vector3) == (after.post_contact_velocity as Vector3) and before.yaw == after.yaw and not before.grounded, "%s %s" % [before.position, before.post_contact_velocity])
	check("switch_into_server_clears_stamina", float(before.stamina) > 0.0 and float(after.stamina) == 0.0, "%.3f -> %.3f" % [before.stamina, after.stamina])
	player.call("apply_engine_rate")

static func _increasing(values: Array) -> bool:
	for i: int in range(1, values.size()):
		if float(values[i]) <= float(values[i - 1]):
			return false
	return true

static func _max(values: Array) -> float:
	var best := 0.0
	for v: Variant in values:
		best = maxf(best, float(v))
	return best

static func _plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[str(key)] = _plain(value[key])
		return out
	if value is Array:
		var items := []
		for item: Variant in value:
			items.append(_plain(item))
		return items
	return value

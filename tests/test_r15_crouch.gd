extends SceneTree
## p / r15 crouch on real collision, driven only by input events. the r15 runner and an
## unchanged r14 runner stand in the same fixture and read the same key and mouse events every
## tick; they do not collide with each other (both are layer 2, mask 1). every episode has one
## labelled setup between motor steps (key releases, the profile, the engine rate, one
## reset_to pose per runner), then settle ticks with no input, then events delivered before the
## motors (priority -1000) and both motors sampled after them (1000). nothing is reset or
## written during a proof. press ticks come from the pure module's flat-plane prediction made
## before the episode starts, never from the runner.
## gates are behavior the runner promises; findings are measurements reported for review.
## godot --headless --fixed-fps 128 --path . --script res://tests/test_r15_crouch.gd --
##   [--out=DIR] [--only=settings,parity,fit,clearances,ground,air,spam,landing,ceiling,ledge,gap,
##   steps,slopes,corner,heights,eye]

const MAIN := preload("res://scripts/spillway_main.gd")
const LAB := preload("res://scripts/r14_source_lab.gd")
const LAB15 := preload("res://scripts/r15_movement_lab.gd")
const PRESETS := preload("res://scripts/r14_presets.gd")
const R14 := preload("res://scripts/r14_source_player.gd")
const R15 := preload("res://scripts/r15_source_player.gd")
const M := preload("res://scripts/r14_source_motion.gd")
const FIX := LAB15.CrouchFixture
const U: float = M.U
const GROUPS := ["settings", "parity", "fit", "clearances", "ground", "air", "spam", "landing", "ceiling", "ledge", "gap", "steps", "slopes", "corner", "heights", "eye"]
const KEYS := ["w", "a", "s", "d", "space", "ctrl"]
const SETTLE := 8
## p / the source look scale the r14 player proofs use (0.0022 rad per count).
const SENSITIVITY := 5.729578

signal episode_done

class Probe:
	extends Node
	var suite: Object
	var early: bool

	func _physics_process(_delta: float) -> void:
		suite.call("early_tick" if early else "late_tick")

## samples the r15 camera once per rendered frame, after the runners' _process.
class EyeProbe:
	extends Node
	var suite: Object

	func _process(_delta: float) -> void:
		suite.call("eye_frame")

var out_dir := "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/crouch/suite"
var groups: Array = GROUPS.duplicate()
var fixture: Node3D
var player: CharacterBody3D
var twin: CharacterBody3D
var events: Dictionary = {}
var rows: Array[Dictionary] = []
var twin_rows: Array[Dictionary] = []
var eye_rows: Array[Dictionary] = []
var tick := 0
var length := 0
var running := false
var pre_steps := 0
var order_violations: Array[String] = []
var checks: Array[Dictionary] = []
var findings: Dictionary = {}
var episodes: Dictionary = {}

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
	fixture = FIX.new()
	fixture.name = "CrouchFixture"
	root.add_child(fixture)
	fixture.call("build", false)
	player = R15.new()
	player.name = "R15Runner"
	root.add_child(player)
	twin = R14.new()
	twin.name = "R14Twin"
	root.add_child(twin)
	for early: bool in [true, false]:
		var probe := Probe.new()
		probe.suite = self
		probe.early = early
		probe.process_physics_priority = -1000 if early else 1000
		root.add_child(probe)
	var eye := EyeProbe.new()
	eye.suite = self
	eye.process_priority = 1000
	root.add_child(eye)
	await process_frame
	for group: String in GROUPS:
		if group in groups:
			await call("group_" + group)
	check("ordering_one_motor_step_per_tick", order_violations.is_empty(), "%d violations %s" % [order_violations.size(), order_violations.slice(0, 3)])
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.pass)
	var summary := {
		"engine": Engine.get_version_info(), "physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine", "<unset>"),
		"motor": R15.MOTOR_VERSION, "duck_defaults": R15.DUCK_DEFAULTS,
		"fixed_fps_note": "run with --fixed-fps 128", "groups": groups, "checks": checks,
		"findings": findings, "episodes": episodes, "gates": checks.size(), "failed": failed.size(),
	}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_plain(summary), "\t"))
	file.close()
	print("r15 crouch: %d checks, %d failed; summary %s" % [checks.size(), failed.size(), out_dir.path_join("summary.json")])
	for c: Dictionary in failed:
		print("FAIL ", c.name, ": ", c.detail)
	quit(0 if failed.is_empty() else 1)

func check(name: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"name": name, "pass": ok, "detail": str(detail)})
	print("%s %s %s" % ["ok  " if ok else "FAIL", name, str(detail)])

# --- episode machinery ----------------------------------------------------------------------

func settings_for(preset: String, overrides := {}) -> Dictionary:
	var cv := PRESETS.source_settings(preset, {"sensitivity": SENSITIVITY, "fov": 90.0})
	cv["wheel_jump"] = false
	cv.merge(overrides, true)
	return cv

## the labelled setup for both runners, then the tape. returns the r15 rows; twin_rows holds
## the r14 twin's rows for the same ticks.
func episode(name: String, pose: Transform3D, tape: Dictionary, ticks: int, preset := "server128", overrides := {}) -> Array[Dictionary]:
	for key: String in KEYS:
		LAB.send([key, false])
	for runner: CharacterBody3D in [player, twin]:
		runner.call("apply_settings", settings_for(preset, overrides))
		runner.call("apply_engine_rate")
		runner.call("reset_to", pose)
	events = tape
	rows = []
	twin_rows = []
	eye_rows = []
	tick = 0
	length = ticks + SETTLE
	running = true
	await episode_done
	var lines := PackedStringArray()
	for r: Dictionary in rows:
		var plain := r.duplicate()
		plain.erase("raw")
		lines.append(JSON.stringify(_plain(plain)))
	LAB.write_gzip(out_dir.path_join("traces").path_join(name + ".jsonl.gz"), lines)
	episodes[name] = {"preset": preset, "ticks": ticks, "settle": SETTLE, "pose_u": pose.origin / U, "yaw": pose.basis.get_euler().y, "tape_events": tape.size(), "overrides": overrides}
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
	var r := LAB15.row(s)
	r["pt"] = tick - SETTLE
	r["raw"] = {"p": s.position, "v": velocity_of(player), "d": s.displacement, "o": s.origin_delta, "top": float(s.hull.top_u), "feet": float(s.hull.feet_u), "ducked": bool(s.duck.ducked), "eye": float(s.duck.eye_u), "events": s.events, "contacts": s.contacts, "grounded": bool(s.grounded), "mode": s.mode, "speed": float(s.actual_speed_u)}
	rows.append(r)
	var t: Dictionary = twin.call("get_motion_state")
	twin_rows.append({"pt": tick - SETTLE, "p": t.position, "v": velocity_of(twin), "d": t.displacement, "events": t.events, "grounded": bool(t.grounded)})
	if tick >= length:
		running = false
		episode_done.emit()

func eye_frame() -> void:
	if not running:
		return
	var camera: Camera3D = player.get("camera")
	eye_rows.append({"pt": tick - SETTLE, "cam_y_u": camera.global_position.y / U, "feet_u": player.global_position.y / U})

static func velocity_of(runner: CharacterBody3D) -> Vector3:
	return runner.velocity / U

## {tape tick: [[key, pressed]...]} from [[tick, key, pressed]...].
static func tape_of(edges: Array) -> Dictionary:
	var tape := {}
	for e: Array in edges:
		var t := int(e[0])
		if not tape.has(t):
			tape[t] = []
		tape[t].append([e[1], e[2]])
	return tape

## the first tape tick at which a body running with `keys` from rest at `pose` starts its step
## at or past `z_u` (u, toward -z), from the pure module on a flat plane. `crouch_from` is the
## tape tick crouch starts being held (0: never), which crops the ground wish as the runner does.
func press_tick(pose: Transform3D, z_u: float, preset := "server128", crouch_from := 0) -> int:
	var cv := R15.with_duck(settings_for(preset))
	var dt := 1.0 / float(cv.tickrate)
	var world := M.FlatWorld.new()
	var s := M.new_state(Vector3(0, 0, pose.origin.z / U))
	s.grounded = true
	s.ground_normal = Vector3.UP
	s.ground_ticks = 100
	var yaw := pose.basis.get_euler().y
	for t: int in range(1, 6000):
		if (s.position as Vector3).z <= z_u:
			return t
		M.step(s, {"forward": 1.0, "yaw": yaw, "ducked": crouch_from > 0 and t >= crouch_from}, cv, dt, world)
	return -1

## the worst per-tick origin change over rows: horizontal and vertical apart, metres. r14's
## standoff makes a resting standing hull bob by about 0.002 u; it is reported, not hidden.
static func rest_motion(r: Array) -> Vector2:
	var out := Vector2.ZERO
	for row: Dictionary in r:
		var o: Vector3 = row.raw.o if row.has("raw") else row.d
		out.x = maxf(out.x, Vector2(o.x, o.z).length())
		out.y = maxf(out.y, absf(o.y))
	return out

## the standing hull at the runner's feet would overlap something (tested on a copy, read only).
func standing_overlaps(at: Vector3) -> bool:
	var probe := CharacterBody3D.new()
	probe.collision_layer = 0
	probe.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(32, 72, 32) * U
	shape.shape = box
	shape.position = Vector3(0, 36, 0) * U
	probe.add_child(shape)
	root.add_child(probe)
	probe.global_position = at
	var hit := probe.test_move(Transform3D(Basis.IDENTITY, at), Vector3.ZERO, null, 0.0001, true, 1)
	probe.queue_free()
	return hit

## the row index of motor step `pt` (rows start with the settle ticks).
static func at(pt: int) -> int:
	return pt + SETTLE - 1

## the first row with `event` at or after motor step `from_pt` (default: after the settle).
static func first(r: Array[Dictionary], event: String, from_pt := 1) -> int:
	for i: int in range(maxi(0, at(from_pt)), r.size()):
		if event in (r[i].raw.events as Array):
			return i
	return -1

static func count(r: Array[Dictionary], event: String) -> int:
	var n := 0
	for row: Dictionary in r.slice(at(1)):
		n += (row.raw.events as Array).count(event)
	return n

static func max_feet(r: Array[Dictionary]) -> float:
	var best := -INF
	for i: int in range(at(1), r.size()):
		best = maxf(best, float(r[i].raw.feet))
	return best

func pose_u(at: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), at * U)

# --- groups -----------------------------------------------------------------------------------

## the new settings exist on every profile and enter the record fingerprint; ui keys do not.
func group_settings() -> void:
	for preset: String in ["server128", "server128_aa1000"]:
		player.call("apply_settings", settings_for(preset))
		var cv: Dictionary = player.get("settings")
		var fp := PRESETS.physics_fingerprint(cv)
		var missing := R15.DUCK_DEFAULTS.keys().filter(func(k: String) -> bool: return not fp.has(k))
		check("settings_%s_duck_keys_in_fingerprint" % preset, missing.is_empty(), "missing %s" % [missing])
		var base := PRESETS.physics_fingerprint(settings_for(preset))
		var changed := []
		for key: String in base:
			if base[key] != fp[key]:
				changed.append(key)
		check("settings_%s_r14_keys_unchanged" % preset, changed.is_empty(), changed)
	player.call("apply_settings", settings_for("server128", {"duck_hull_height": 54.0}))
	var a := PRESETS.physics_fingerprint(player.get("settings"))
	player.call("apply_settings", settings_for("server128", {"duck_air_anchor": "head"}))
	var b := PRESETS.physics_fingerprint(player.get("settings"))
	check("settings_anchor_changes_fingerprint", JSON.stringify(a) != JSON.stringify(b), "center vs head")

## crouch never pressed: the r15 runner and the r14 twin, same events, exact per-tick equality.
func group_parity() -> void:
	var out := {}
	var cases := []
	for preset: String in ["server128", "server128_aa1000"]:
		var source := "csgo_server"
		var over := {} if preset == "server128" else {"sv_airaccelerate": 1000.0}
		var plan := LAB.plan_strafe(source, 72, 4, 48, "hold", 640, over)
		cases.append(["strafe_" + preset, preset, LAB.Fixture.pose("runway"), _frames_tape(plan.frames), 640])
		# keys only (no mouse): the same frames with every mouse count removed.
		var keys_only := []
		for f: Dictionary in plan.frames:
			keys_only.append({"keys": f.keys, "mouse": 0})
		cases.append(["keys_only_" + preset, preset, LAB.Fixture.pose("runway"), _frames_tape(keys_only), 640])
	cases.append(["idle_no_input", "server128", LAB.Fixture.pose("runway"), {}, 384])
	cases.append(["hold_jump_in_place", "server128", LAB.Fixture.pose("runway"), tape_of([[1, "space", true], [400, "space", false]]), 480])
	for i: int in 5:
		cases.append(["lips_walk_%d" % i, "server128", LAB.Fixture.pose("lips").translated(Vector3(-576 + 288 * i, 0, 0) * U), tape_of([[1, "w", true], [700, "w", false]]), 760])
	for i: int in 4:
		cases.append(["slope_lane_%d" % i, "server128", pose_u(Vector3(11520 + 320 * i, 0.5, 400)), tape_of([[1, "w", true], [60, "space", true], [61, "space", false], [600, "w", false]]), 660])
	cases.append(["corner_diagonal", "server128", pose_u(Vector3(16000, 0.5, 0), -0.6), tape_of([[1, "w", true], [1, "d", true], [420, "d", false], [420, "a", true], [600, "a", false], [600, "s", true], [760, "s", false], [760, "w", false]]), 800])
	cases.append(["seams_hops", "server128_aa1000", LAB.Fixture.pose("seams"), tape_of([[1, "w", true], [40, "space", true], [500, "space", false], [520, "w", false]]), 560])
	var gap_pose := LAB.Fixture.pose("gap")
	cases.append(["gap_jump", "server128", gap_pose, tape_of([[1, "w", true], [press_tick(gap_pose, -1024.0 + 12.0), "space", true], [1000, "space", false], [1000, "w", false]]), 1100])
	for c: Array in cases:
		var r := await episode("parity_" + c[0], c[2], c[3], c[4], c[1])
		var worst_p := 0.0
		var worst_v := 0.0
		var first_diff := -1
		var events_equal := true
		for i: int in r.size():
			var dp := ((r[i].raw.p as Vector3) - (twin_rows[i].p as Vector3)).length()
			var dv := ((r[i].raw.v as Vector3) - (twin_rows[i].v as Vector3)).length()
			if (dp > 0.0 or dv > 0.0) and first_diff < 0:
				first_diff = i
			worst_p = maxf(worst_p, dp)
			worst_v = maxf(worst_v, dv)
			var ev: Array = (r[i].raw.events as Array).duplicate()
			events_equal = events_equal and ev == twin_rows[i].events
		var jumps := count(r, "jump")
		var lands := count(r, "land")
		var crouched := r.any(func(row: Dictionary) -> bool: return row.raw.ducked)
		var steps := 0
		var contacts := 0
		for row: Dictionary in r:
			steps += 1 if "step" in (row.raw.events as Array) else 0
			contacts += (row.raw.contacts as Array).size()
		out[c[0]] = {"step_ups": steps, "contacts": contacts, "worst_position_m": worst_p, "worst_velocity_u": worst_v, "first_diff_row": first_diff, "jumps": jumps, "lands": lands, "end_u": (r[-1].raw.p as Vector3) / U, "end_speed_u": r[-1].raw.speed}
		check("parity_%s_exact" % c[0], worst_p == 0.0 and worst_v == 0.0 and events_equal and not crouched, "pos %s m vel %s u/s events %s first diff %d; %d jumps %d lands %d steps %d contacts; end %s u" % [worst_p, worst_v, events_equal, first_diff, jumps, lands, steps, contacts, (r[-1].raw.p as Vector3) / U])
	findings["parity"] = out

## frames from LAB.plan_strafe to an edge tape (same as the r14 suite's to_tape).
static func _frames_tape(frames: Array) -> Dictionary:
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

## standing does not fit the 62 u tunnel; ducked does, end to end, without contact on its roof.
func group_fit() -> void:
	var t := FIX.TUNNEL
	var pose := FIX.crouch_pose("tunnel")
	var r := await episode("fit_standing_tunnel", pose, tape_of([[1, "w", true], [700, "w", false]]), 760)
	var deepest := INF
	for row: Dictionary in r:
		deepest = minf(deepest, (row.raw.p as Vector3).z / U)
	check("fit_standing_stops_at_tunnel_mouth", absf(deepest - (float(t.front_z) + 16.0)) < 0.2, "deepest feet z %.3f u, mouth face %.1f + 16" % [deepest, t.front_z])
	var crouch_at := press_tick(pose, -100.0)
	var r2 := await episode("fit_crouched_tunnel", pose, tape_of([[1, "w", true], [crouch_at, "ctrl", true], [1800, "w", false], [1800, "ctrl", false]]), 1860)
	var through := (r2[-1].raw.p as Vector3).z / U
	var roof_hits := 0
	var inside_heights := []
	for row: Dictionary in r2:
		var z := (row.raw.p as Vector3).z / U
		if z < float(t.front_z) + 16.0 and z > float(t.back_z) - 16.0:
			inside_heights.append(row.raw.top)
		for c: Dictionary in row.raw.contacts:
			if (c.normal as Vector3).y < -0.5:
				roof_hits += 1
	check("fit_crouched_passes_tunnel", through < float(t.back_z) - 16.0, "end z %.2f u (tunnel back %.1f)" % [through, t.back_z])
	check("fit_crouched_no_roof_contact", roof_hits == 0, "%d downward-normal contacts" % roof_hits)
	check("fit_hull_inside_is_54", not inside_heights.is_empty() and inside_heights.all(func(top: float) -> bool: return top < float(t.ceiling)), "max top %.3f u over %d ticks" % [inside_heights.max() if not inside_heights.is_empty() else -1.0, inside_heights.size()])
	var inside := r2[at(press_tick(pose, -500.0, "server128", crouch_at))]
	check("fit_reports_hull", inside.hull[0] == 54.0 and absf(float(inside.hull[2]) - float(inside.hull[1]) - 54.0) < 0.002 and inside.duck.ducked, "inside row hull %s" % [inside.hull])
	findings["fit"] = {"standing_deepest_z_u": deepest, "crouched_end_z_u": through, "crouch_press_tick": crouch_at}

## roof boundaries: standing clears 73 u and not 72, ducked clears 55 u and not 54.
func group_clearances() -> void:
	var out := {}
	var heights: Array = FIX.CLEARANCES
	for i: int in heights.size():
		var h := float(heights[i])
		var pose := pose_u(Vector3(FIX.lane_x("clearances", i), 0.5, 128))
		var crouch_at := press_tick(pose, -100.0)
		for style: String in ["standing", "ducked"]:
			var edges := [[1, "w", true], [1400, "w", false]]
			if style == "ducked":
				edges.append([crouch_at, "ctrl", true])
			var r := await episode("clearance_%d_%s" % [int(h), style], pose, tape_of(edges), 1440)
			var end := (r[-1].raw.p as Vector3) / U
			out["%d_%s" % [int(h), style]] = {"end_z": end.z, "through": end.z < -768.0 - 16.0}
	findings["clearances"] = out
	check("clearance_standing_73_yes_72_no", out["73_standing"].through and not out["72_standing"].through and absf(float(out["72_standing"].end_z) + 240.0) < 0.2, out)
	check("clearance_ducked_55_yes_54_no", out["55_ducked"].through and not out["54_ducked"].through and absf(float(out["54_ducked"].end_z) + 240.0) < 0.2, out)

## ground press and release: no origin shift, eye eases, ducked ground wish converges to 85.
func group_ground() -> void:
	var pose := LAB.Fixture.pose("runway")
	var r := await episode("ground_press_release_idle", pose, tape_of([[20, "ctrl", true], [120, "ctrl", false]]), 200)
	var duck := first(r, "duck")
	var stand := first(r, "unduck")
	var drift := rest_motion(r.slice(at(1)))
	var standing := rest_motion(twin_rows.slice(at(1)))
	check("ground_duck_on_press_tick", duck >= 0 and int(r[duck].pt) == 20 and float(r[duck].duck.shift) == 0.0, "duck row pt %s shift %s" % [r[duck].pt if duck >= 0 else -1, r[duck].duck.shift if duck >= 0 else null])
	check("ground_unduck_on_release_tick", stand >= 0 and int(r[stand].pt) == 120 and float(r[stand].duck.shift) == 0.0, "unduck row pt %s" % [r[stand].pt if stand >= 0 else -1])
	check("ground_idle_crouch_no_origin_motion", drift.x == 0.0 and drift.y <= maxf(standing.y, 1e-4), "max per-tick change horizontal %s m, vertical %s m; standing r14 twin vertical %s m" % [drift.x, drift.y, standing.y])
	var eye_down := []
	for i: int in range(duck, duck + 16):
		eye_down.append(snappedf(float(r[i].raw.eye), 0.01))
	var monotone := true
	for i: int in range(1, eye_down.size()):
		monotone = monotone and eye_down[i] <= eye_down[i - 1]
	var settled := -1
	for i: int in range(duck, r.size()):
		if float(r[i].raw.eye) == 46.0:
			settled = i - duck
			break
	check("ground_eye_eases_to_46", monotone and settled >= 10 and settled <= 14, "ticks to 46: %d; %s" % [settled, eye_down])
	var up := -1
	for i: int in range(stand, r.size()):
		if float(r[i].raw.eye) == 64.0:
			up = i - stand
			break
	check("ground_eye_returns_to_64", up >= 10 and up <= 14, "ticks to 64: %d" % up)
	var r2 := await episode("ground_crouch_walk", pose, tape_of([[1, "ctrl", true], [1, "w", true], [300, "w", false], [300, "ctrl", false]]), 420)
	var crouch_speed := float(r2[at(290)].raw.speed)
	check("ground_crouch_walk_85", absf(crouch_speed - 85.0) < 0.01, "%.4f u/s" % crouch_speed)
	var after := r2.slice(at(310))
	var stop := after.all(func(row: Dictionary) -> bool: return (row.raw.d as Vector3).length() == 0.0 or float(row.raw.speed) < 85.0)
	check("ground_crouch_release_keeps_friction", stop, "speed after release decays")
	findings["ground"] = {"eye_ticks_down": settled, "eye_ticks_up": up, "crouch_speed_u": crouch_speed}

## a crouch in flight lifts the feet by exactly the anchor's lift without touching velocity or
## travel; standing again in open air lowers them by the same amount.
func group_air() -> void:
	var pose := LAB.Fixture.pose("runway")
	var out := {}
	for anchor: String in ["center", "head", "feet"]:
		var over := {"duck_air_anchor": anchor}
		var base := await episode("air_twin_%s" % anchor, pose, tape_of([[1, "w", true], [40, "space", true], [41, "space", false], [200, "w", false]]), 240, "server128", over)
		var plain := base.duplicate()
		var r := await episode("air_duck_%s" % anchor, pose, tape_of([[1, "w", true], [40, "space", true], [41, "space", false], [46, "ctrl", true], [70, "ctrl", false], [200, "w", false]]), 240, "server128", over)
		var lift := {"center": 9.0, "head": 18.0, "feet": 0.0}[anchor] as float
		var duck := first(r, "duck_air")
		var stand := first(r, "unduck_air")
		var worst_gap := 0.0
		var worst_v := 0.0
		var worst_d := 0.0
		for i: int in range(duck, stand):
			worst_gap = maxf(worst_gap, absf(float(r[i].raw.feet) - float(plain[i].raw.feet) - lift))
			worst_v = maxf(worst_v, ((r[i].raw.v as Vector3) - (plain[i].raw.v as Vector3)).length())
			worst_d = maxf(worst_d, ((r[i].raw.d as Vector3) - (plain[i].raw.d as Vector3)).length())
		var after := 0.0
		for i: int in range(stand, first(plain, "land")):
			after = maxf(after, ((r[i].raw.p as Vector3) - (plain[i].raw.p as Vector3)).length() / U)
		check("air_%s_duck_and_stand_events" % anchor, duck >= 0 and int(r[duck].pt) == 46 and stand >= 0 and int(r[stand].pt) == 70, "duck pt %s stand pt %s" % [r[duck].pt if duck >= 0 else -1, r[stand].pt if stand >= 0 else -1])
		# positions are single precision: a 9 u shift rounds by a few millionths of a unit.
		check("air_%s_lift_exact_no_velocity" % anchor, worst_gap < 1e-4 and worst_v == 0.0 and worst_d < 1e-6, "feet gap error %s u, velocity diff %s u/s, travel diff %s m" % [worst_gap, worst_v, worst_d])
		check("air_%s_shift_reported_not_travel" % anchor, absf(float(r[duck].duck.shift) - lift) < 1e-4 and absf(float(r[stand].duck.shift) + lift) < 1e-4 and absf(((r[duck].raw.o as Vector3) - (r[duck].raw.d as Vector3)).y / U - lift) < 1e-4, "shift %s / %s" % [r[duck].duck.shift, r[stand].duck.shift])
		check("air_%s_stand_rejoins_twin" % anchor, after < 1e-4, "max pose difference after standing %s u" % after)
		out[anchor] = {"duck_pt": r[duck].pt, "stand_pt": r[stand].pt, "feet_gap_err_u": worst_gap}
	findings["air"] = out

## duck spam: crouch toggled every tick in flight and on the floor gains no height or speed.
func group_spam() -> void:
	var pose := LAB.Fixture.pose("runway")
	var edges := [[1, "w", true], [40, "space", true], [41, "space", false]]
	for t: int in range(42, 120):
		edges.append([t, "ctrl", t % 2 == 0])
	edges.append([120, "ctrl", false])
	edges.append([240, "w", false])
	var plain := await episode("spam_twin", pose, tape_of([[1, "w", true], [40, "space", true], [41, "space", false], [240, "w", false]]), 260)
	var r := await episode("spam_air_every_tick", pose, tape_of(edges), 260)
	var land := first(plain, "land")
	var ok := true
	var worst := 0.0
	for i: int in range(0, land):
		if not r[i].raw.ducked:
			worst = maxf(worst, ((r[i].raw.p as Vector3) - (plain[i].raw.p as Vector3)).length() / U)
		ok = ok and ((r[i].raw.v as Vector3) - (plain[i].raw.v as Vector3)).length() == 0.0
	var ducks := count(r, "duck_air")
	var stands := count(r, "unduck_air")
	check("spam_air_no_gain", ok and worst < 1e-4, "standing-tick pose diff %s u; velocity identical %s; %d ducks %d stands" % [worst, ok, ducks, stands])
	check("spam_air_toggles_every_tick", ducks >= 30 and absi(ducks - stands) <= 1, "%d ducks %d stands" % [ducks, stands])
	check("spam_air_peak_bounded", max_feet(r) <= max_feet(plain) + 9.0 + 1e-4, "peak %.3f vs twin %.3f + 9" % [max_feet(r), max_feet(plain)])
	edges = []
	for t: int in range(1, 160):
		edges.append([t, "ctrl", t % 2 == 1])
	edges.append([160, "ctrl", false])
	var idle := await episode("spam_ground_idle", pose, tape_of(edges), 200)
	var moved := rest_motion(idle.slice(at(1)))
	var still := rest_motion(twin_rows.slice(at(1)))
	check("spam_ground_idle_no_motion", moved.x == 0.0 and moved.y <= maxf(still.y, 1e-4) and count(idle, "duck") >= 70, "horizontal %s m, vertical %s m (standing twin %s m); %d ducks" % [moved.x, moved.y, still.y, count(idle, "duck")])
	edges = [[1, "w", true]]
	for t: int in range(60, 220):
		edges.append([t, "ctrl", t % 2 == 0])
	edges.append([220, "ctrl", false])
	edges.append([300, "w", false])
	var walk := await episode("spam_ground_run_twin", pose, tape_of([[1, "w", true], [300, "w", false]]), 320)
	var run := await episode("spam_ground_run", pose, tape_of(edges), 320)
	var top := 0.0
	var twin_top := 0.0
	var lifted := 0.0
	for i: int in range(at(1), run.size()):
		top = maxf(top, float(run[i].raw.speed))
		twin_top = maxf(twin_top, float(walk[i].raw.speed))
		lifted = maxf(lifted, absf(float(run[i].raw.feet) - float(walk[i].raw.feet)))
	check("spam_ground_run_bounded", top <= twin_top and lifted < 0.01 and count(run, "jump") == 0, "top %.4f u/s vs standing run %.4f, feet drift vs standing %.4f u" % [top, twin_top, lifted])
	findings["spam"] = {"air_ducks": ducks, "air_stands": stands, "run_top_u": top}

## hold through landing, crouch hop chains and the duck crop's one jump tick.
func group_landing() -> void:
	var pose := LAB.Fixture.pose("runway")
	var r := await episode("landing_hold_through", pose, tape_of([[1, "w", true], [40, "space", true], [41, "space", false], [44, "ctrl", true], [300, "w", false], [300, "ctrl", false]]), 360)
	var land := first(r, "land", 41)
	var stayed := true
	for i: int in range(land, at(299)):
		stayed = stayed and r[i].raw.ducked and r[i].raw.grounded
	check("landing_lands_ducked_and_stays", land > 0 and stayed and r[land].raw.mode == "duck", "land row %d mode %s" % [land, r[land].raw.mode if land >= 0 else ""])
	check("landing_feet_on_floor", absf(float(r[land + 2].raw.feet)) < 0.06, "feet %.4f u" % float(r[land + 2].raw.feet))
	check("landing_ducked_slows_to_85", absf(float(r[at(290)].raw.speed) - 85.0) < 0.01, "%.3f u/s" % float(r[at(290)].raw.speed))
	# a hop chain with only space and crouch held equals the standing chain exactly in the plane.
	var plain := await episode("landing_hops_standing", pose, tape_of([[1, "w", true], [60, "space", true], [61, "w", false], [700, "space", false]]), 720)
	var chain := await episode("landing_hops_ducked", pose, tape_of([[1, "w", true], [60, "space", true], [60, "ctrl", true], [61, "w", false], [700, "space", false], [700, "ctrl", false]]), 720)
	var a := []
	var b := []
	for row: Dictionary in plain.slice(at(1)):
		if "land" in (row.raw.events as Array):
			a.append(snappedf(float(row.raw.speed), 0.0001))
	for row: Dictionary in chain.slice(at(1)):
		if "land" in (row.raw.events as Array):
			b.append(snappedf(float(row.raw.speed), 0.0001))
	var horizontal := 0.0
	for i: int in chain.size():
		var pa: Vector3 = plain[i].raw.p
		var pb: Vector3 = chain[i].raw.p
		horizontal = maxf(horizontal, Vector2(pa.x - pb.x, pa.z - pb.z).length() / U)
	var all_ducked := chain.slice(at(60), at(700)).all(func(row: Dictionary) -> bool: return row.raw.ducked)
	check("landing_crouch_hop_chain", count(chain, "jump") >= 6 and count(chain, "perfect") >= 5 and all_ducked, "%d jumps %d first-tick hops, ducked throughout %s" % [count(chain, "jump"), count(chain, "perfect"), all_ducked])
	check("landing_crouch_hop_matches_standing_plane", horizontal < 1e-6 and a.size() == b.size(), "max horizontal diff %s u; landings %s vs %s" % [horizontal, a, b])
	# strafed crouch hops: the crop applies on each jump tick (it starts grounded). a finding.
	var plan := LAB.plan_strafe("csgo_server", 72, 4, 48, "hold", 640)
	var tape := _frames_tape(plan.frames)
	var crouched := tape.duplicate(true)
	crouched[73] = crouched.get(73, []) + [["ctrl", true]]
	crouched[640] = crouched.get(640, []) + [["ctrl", false]]
	var strafe := await episode("landing_strafe_standing", LAB.Fixture.pose("runway"), tape, 640)
	var strafe_c := await episode("landing_strafe_ducked", LAB.Fixture.pose("runway"), crouched, 640)
	var sa := []
	var sb := []
	for row: Dictionary in strafe.slice(at(1)):
		if "land" in (row.raw.events as Array):
			sa.append(snappedf(float(row.raw.speed), 0.01))
	var strafed_ducked := 0
	for row: Dictionary in strafe_c.slice(at(1)):
		strafed_ducked += 1 if row.raw.ducked else 0
		if "land" in (row.raw.events as Array):
			sb.append(snappedf(float(row.raw.speed), 0.01))
	findings["landing"] = {"plain_landings": a, "ducked_landings": b, "strafed_standing_landings": sa, "strafed_ducked_landings": sb}
	check("landing_strafed_crouch_hops_gain", strafed_ducked > 500 and sb.size() >= 3 and float(sb[-1]) > float(sb[0]), "ducked %s vs standing %s; %d ducked ticks" % [sb, sa, strafed_ducked])

## releasing crouch under the tunnel roof is refused every tick until the standing hull is
## clear, with no drift while idle, then stands on the first clear tick.
func group_ceiling() -> void:
	var t := FIX.TUNNEL
	var pose := FIX.crouch_pose("tunnel")
	var crouch_at := press_tick(pose, -100.0)
	var release_at := press_tick(pose, -480.0, "server128", crouch_at)
	var r := await episode("ceiling_release_inside", pose, tape_of([[1, "w", true], [crouch_at, "ctrl", true], [release_at, "ctrl", false], [1500, "w", false]]), 1540)
	var blocked := first(r, "stand_blocked")
	var stand := first(r, "unduck")
	var overlap := false
	var stayed := true
	for i: int in range(blocked, stand):
		stayed = stayed and r[i].raw.ducked and r[i].duck.blocked
	var z_stand := (r[stand].raw.p as Vector3).z / U if stand >= 0 else 0.0
	var z_before := (r[stand - 1].raw.p as Vector3).z / U if stand > 0 else 0.0
	var clear_z := float(t.back_z) - 16.0
	check("ceiling_release_refused_inside", blocked >= 0 and int(r[blocked].pt) == release_at and stayed, "blocked at pt %s, release pt %d, held ducked %s" % [r[blocked].pt if blocked >= 0 else -1, release_at, stayed])
	check("ceiling_stand_refusal_counted_once", count(r, "stand_blocked") == 1 and int(r[stand - 1].duck.bt) == stand - blocked, "%d refusals, %s blocked ticks" % [count(r, "stand_blocked"), r[stand - 1].duck.bt if stand > 0 else -1])
	# the hull stands at the standoff, a margin before the exact clear plane; never inside it.
	check("ceiling_stands_on_first_clear_tick", stand > 0 and z_stand < clear_z + 0.05 and z_before > clear_z - 0.05 - 85.0 / 128.0, "stood at z %.4f u, previous %.4f u, clear plane %.1f" % [z_stand, z_before, clear_z])
	for row: Dictionary in r:
		if not row.raw.ducked:
			overlap = overlap or standing_overlaps(row.raw.p)
	check("ceiling_standing_never_overlaps", not overlap, "every standing tick's hull tested")
	var idle_at := press_tick(pose, -500.0, "server128", crouch_at)
	var idle := await episode("ceiling_idle_inside", pose, tape_of([[1, "w", true], [crouch_at, "ctrl", true], [idle_at, "ctrl", false], [idle_at, "w", false]]), idle_at + 400)
	var tail := idle.slice(at(idle_at + 60))
	var moved := rest_motion(tail)
	check("ceiling_idle_blocked_no_drift", tail.all(func(row: Dictionary) -> bool: return row.raw.ducked and row.duck.blocked) and moved.x == 0.0 and moved.y <= 1e-4, "horizontal %s m, vertical %s m over %d idle ticks" % [moved.x, moved.y, tail.size()])
	findings["ceiling"] = {"release_pt": release_at, "blocked_pt": r[blocked].pt if blocked >= 0 else null, "stand_pt": r[stand].pt if stand >= 0 else null, "stand_z_u": z_stand, "clear_plane_u": clear_z}

## the 60 u ledge: a standing jump and a ducked jump fall short; jump-then-crouch lands on it
## under its 62 u roof, a release there is refused, and walking on stands where it opens.
func group_ledge() -> void:
	var l := FIX.LEDGE
	var pose := FIX.crouch_pose("ledge")
	var takeoff := press_tick(pose, float(l.front_z) + 16.0 + 90.0)
	var stand := await episode("ledge_standing_jump", pose, tape_of([[1, "w", true], [takeoff, "space", true], [takeoff + 1, "space", false], [400, "w", false]]), 440)
	var low := await episode("ledge_crouch_then_jump", pose, tape_of([[1, "w", true], [takeoff - 1, "ctrl", true], [takeoff, "space", true], [takeoff + 1, "space", false], [400, "w", false], [400, "ctrl", false]]), 440)
	var r := await episode("ledge_jump_then_crouch", pose, tape_of([[1, "w", true], [takeoff, "space", true], [takeoff + 1, "space", false], [takeoff + 3, "ctrl", true], [takeoff + 160, "ctrl", false], [1200, "w", false]]), 1240)
	var on_ledge := func(rr: Array[Dictionary]) -> bool:
		return rr.any(func(row: Dictionary) -> bool: return row.raw.grounded and absf(float(row.raw.feet) - float(l.top)) < 0.1)
	check("ledge_standing_jump_fails", not on_ledge.call(stand), "peak feet %.3f u" % max_feet(stand))
	check("ledge_ducked_jump_fails", not on_ledge.call(low), "peak feet %.3f u" % max_feet(low))
	check("ledge_jump_then_crouch_lands", on_ledge.call(r), "peak feet %.3f u (lift 9)" % max_feet(r))
	var blocked := first(r, "stand_blocked")
	var up := first(r, "unduck")
	var z_up := (r[up].raw.p as Vector3).z / U if up >= 0 else 0.0
	check("ledge_release_under_roof_refused", blocked >= 0 and int(r[blocked].pt) == takeoff + 160 and r[blocked].raw.grounded, "blocked pt %s" % [r[blocked].pt if blocked >= 0 else -1])
	check("ledge_stands_past_roof", up > blocked and z_up < float(l.ceiling_back_z) - 16.0 + 0.05 and absf(float(r[up].raw.feet) - float(l.top)) < 0.1, "stood at z %.3f u feet %.3f u" % [z_up, float(r[up].raw.feet) if up >= 0 else 0.0])
	var peak_v := 0.0
	var plain_v := 0.0
	for row: Dictionary in r:
		peak_v = maxf(peak_v, (row.raw.v as Vector3).y)
	for row: Dictionary in stand:
		plain_v = maxf(plain_v, (row.raw.v as Vector3).y)
	check("ledge_no_extra_upward_velocity", peak_v <= plain_v, "peak vy %.4f vs standing %.4f u/s" % [peak_v, plain_v])
	findings["ledge"] = {"takeoff_tick": takeoff, "peak_standing": max_feet(stand), "peak_ducked_jump": max_feet(low), "peak_jump_then_crouch": max_feet(r), "stand_z_u": z_up}

## the 128 u pit under a 100 u roof: a standing jump bonks and falls in, a crouch hop crosses,
## and a release over the pit is refused until the standing hull clears the roof.
func group_gap() -> void:
	var g := FIX.LOW_GAP
	var pose := FIX.crouch_pose("low_gap")
	var takeoff := press_tick(pose, float(g.near_z) - 6.0)
	var stand := await episode("gap_standing_bonk", pose, tape_of([[1, "w", true], [takeoff, "space", true], [takeoff + 1, "space", false], [500, "w", false]]), 540)
	var hop := await episode("gap_crouch_hop", pose, tape_of([[1, "w", true], [takeoff, "space", true], [takeoff, "ctrl", true], [takeoff + 1, "space", false], [500, "w", false], [500, "ctrl", false]]), 540)
	var late := await episode("gap_release_over_pit", pose, tape_of([[1, "w", true], [takeoff, "space", true], [takeoff, "ctrl", true], [takeoff + 1, "space", false], [takeoff + 30, "ctrl", false], [500, "w", false]]), 540)
	var fell := (stand[-1].raw.p as Vector3).y / U < float(g.catch) + 1.0
	var bonk := stand.any(func(row: Dictionary) -> bool: return (row.raw.contacts as Array).any(func(c: Dictionary) -> bool: return (c.normal as Vector3).y < -0.5))
	check("gap_standing_bonks_and_falls", fell and bonk, "end y %.2f u, roof contact %s" % [(stand[-1].raw.p as Vector3).y / U, bonk])
	var crossed := absf((hop[-1].raw.p as Vector3).y / U) < 1.0 and (hop[-1].raw.p as Vector3).z / U < float(g.far_z)
	check("gap_crouch_hop_crosses", crossed, "end %s u" % [(hop[-1].raw.p as Vector3) / U])
	var blocked := first(late, "stand_blocked")
	var up := first(late, "unduck_air")
	var top_ok := true
	for row: Dictionary in late:
		top_ok = top_ok and float(row.raw.top) <= float(g.ceiling) + 0.001
	check("gap_air_release_refused_then_stands", blocked >= 0 and int(late[blocked].pt) == takeoff + 30 and up > blocked and float(late[up].raw.top) <= float(g.ceiling), "blocked pt %s, stood pt %s with top %.3f u" % [late[blocked].pt if blocked >= 0 else -1, late[up].pt if up >= 0 else -1, float(late[up].raw.top) if up >= 0 else 0.0])
	check("gap_hull_never_above_roof", top_ok, "every tick's hull top <= 100 u")
	var landed := absf((late[-1].raw.p as Vector3).y / U) < 1.0 and (late[-1].raw.p as Vector3).z / U < float(g.far_z)
	findings["gap"] = {"takeoff_tick": takeoff, "standing_end_u": (stand[-1].raw.p as Vector3) / U, "hop_end_u": (hop[-1].raw.p as Vector3) / U, "late_release_end_u": (late[-1].raw.p as Vector3) / U, "late_release_landed_far": landed}

## crouched step-up under roofs: 8, 16 and 18 u lips climb, 19 and 24 u stop; standing stops.
func group_steps() -> void:
	var out := {}
	var lips: Array = FIX.DUCK_STEP_LIPS
	for i: int in lips.size():
		var lip := float(lips[i])
		var pose := pose_u(Vector3(FIX.lane_x("duck_steps", i), 0.5, 512))
		var crouch_at := press_tick(pose, 64.0)
		var r := await episode("steps_ducked_%d" % int(lip), pose, tape_of([[1, "w", true], [crouch_at, "ctrl", true], [1100, "w", false]]), 1160)
		var end := (r[-1].raw.p as Vector3) / U
		var climbed := absf(end.y - lip) < 0.1 and end.z < -256.0 - 16.0
		out["ducked_%d" % int(lip)] = {"end_u": end, "crouch_press": crouch_at}
		if lip <= 18.0:
			check("steps_ducked_climbs_%d" % int(lip), climbed, "end %s" % [end])
		else:
			check("steps_ducked_stops_%d" % int(lip), not climbed and absf(end.z - (-256.0 + 16.0)) < 0.2, "end %s" % [end])
		if lip == 16.0 or lip == 18.0:
			var s := await episode("steps_standing_%d" % int(lip), pose, tape_of([[1, "w", true], [700, "w", false]]), 760)
			var se := (s[-1].raw.p as Vector3) / U
			check("steps_standing_roof_stops_%d" % int(lip), se.y < 1.0 and se.z > -256.0, "end %s" % [se])
			out["standing_%d" % int(lip)] = se
	findings["steps"] = out

## ducked up 20, 30 and 45 degree ramps, standing again mid-ramp: the slope never blocks the
## stand test. on the 50 degree face the approved r14 body, standing, already climbs airborne at
## a steady 23.75 u/s while w is held (an r14 finding, docs/r15/CROUCH.md); ducked it must do
## what the r14 twin does there, with the stand refused while the face is under it.
func group_slopes() -> void:
	var out := {}
	for i: int in 4:
		var pose := pose_u(Vector3(11520 + 320 * i, 0.5, 300))
		var crouch_at := press_tick(pose, 100.0)
		var release_at := press_tick(pose, -330.0, "server128", crouch_at)
		var r := await episode("slope_ducked_%d" % i, pose, tape_of([[1, "w", true], [crouch_at, "ctrl", true], [release_at, "ctrl", false], [release_at + 200, "w", false]]), release_at + 240)
		var stand := first(r, "unduck")
		var end := (r[-1].raw.p as Vector3) / U
		out[str(i)] = {"stand_pt": r[stand].pt if stand >= 0 else null, "stand_p_u": (r[stand].raw.p as Vector3) / U if stand >= 0 else null, "blocked": count(r, "stand_blocked"), "end_u": end}
		if i < 3:
			check("slope_%d_ducked_climbs_and_stands" % i, stand >= 0 and int(r[stand].pt) == release_at and count(r, "stand_blocked") == 0 and (r[stand].raw.p as Vector3).y / U > 5.0, out[str(i)])
		else:
			var twin_end := (twin_rows[-1].p as Vector3) / U
			out["3_twin_end_u"] = twin_end
			# the twin crops its air wish too (r14 applies the duck multiplier in flight), so the two
			# climbs start a few ticks apart; the climb rate is the same law.
			var vy := (r[-1].raw.v as Vector3).y
			var twin_vy := (twin_rows[-1].v as Vector3).y
			check("slope_50_ducked_matches_r14_twin", (end - twin_end).length() < 0.1 and absf(vy - twin_vy) < 1e-3 and count(r, "stand_blocked") == 1 and stand < 0, "ducked end %s vy %.4f, r14 twin end %s vy %.4f" % [end, vy, twin_end, twin_vy])
	findings["slopes"] = out

## a ducked body strafes into an inner corner, rests on both faces and leaves it.
func group_corner() -> void:
	var pose := pose_u(Vector3(16300, 0.5, -300), 0.0)
	var r := await episode("corner_ducked", pose, tape_of([[1, "ctrl", true], [1, "w", true], [1, "d", true], [700, "w", false], [700, "d", false], [720, "s", true], [720, "a", true], [1000, "s", false], [1000, "a", false], [1060, "ctrl", false]]), 1100)
	var rest := (r[at(695)].raw.p as Vector3) / U
	var away := (r[at(999)].raw.p as Vector3) / U
	check("corner_ducked_rests_in_corner", absf(rest.x - (16512.0 - 16.0)) < 0.1 and absf(rest.z - (-512.0 + 16.0)) < 0.1, "rest %s" % [rest])
	check("corner_ducked_leaves", away.x < rest.x - 10.0 and away.z > rest.z + 10.0, "away %s" % [away])
	check("corner_stands_after", not r[-1].raw.ducked, "ducked %s" % r[-1].raw.ducked)
	# release crouch while still pressing into both faces: the walls never block standing.
	var pressed := await episode("corner_release_pressed", pose, tape_of([[1, "ctrl", true], [1, "w", true], [1, "d", true], [640, "ctrl", false], [760, "w", false], [760, "d", false]]), 800)
	var stood := first(pressed, "unduck")
	check("corner_release_against_walls_stands", stood >= 0 and int(pressed[stood].pt) == 640 and count(pressed, "stand_blocked") == 0 and not standing_overlaps(pressed[stood].raw.p), "stood pt %s at %s" % [pressed[stood].pt if stood >= 0 else -1, (pressed[stood].raw.p as Vector3) / U if stood >= 0 else null])
	findings["corner"] = {"rest_u": rest, "away_u": away}

## reach boundaries on open blocks with one takeoff distance (90 u from the face).
func group_heights() -> void:
	var out := {}
	var heights: Array = FIX.HEIGHTS
	for i: int in heights.size():
		var h := float(heights[i])
		var pose := pose_u(Vector3(FIX.lane_x("heights", i), 0.5, 256))
		var takeoff := press_tick(pose, -256.0 + 16.0 + 90.0)
		var res := {}
		for style: String in ["standing", "jump_then_crouch"]:
			var edges := [[1, "w", true], [takeoff, "space", true], [takeoff + 1, "space", false], [500, "w", false]]
			if style == "jump_then_crouch":
				edges.append([takeoff + 3, "ctrl", true])
				edges.append([500, "ctrl", false])
			var r := await episode("heights_%d_%s" % [int(h), style], pose, tape_of(edges), 540)
			res[style] = {"on_top": r.any(func(row: Dictionary) -> bool: return row.raw.grounded and absf(float(row.raw.feet) - h) < 0.1), "peak": max_feet(r)}
		out[str(int(h))] = res
	findings["heights"] = out
	check("heights_standing_50_yes_56_no", out["50"].standing.on_top and not out["56"].standing.on_top, "%s" % [out])
	check("heights_jump_then_crouch_60_yes_66_no", out["56"].jump_then_crouch.on_top and out["60"].jump_then_crouch.on_top and not out["66"].jump_then_crouch.on_top, "64: %s" % [out["64"].jump_then_crouch])

## the camera never shows the lift: in the open the rendered eye moves at most one eye-rate step
## (18 u / 0.1 s at 128 hz = 1.406 u) per frame beyond physical travel, and settles at 46 u.
func group_eye() -> void:
	var pose := LAB.Fixture.pose("runway")
	var r := await episode("eye_air_duck", pose, tape_of([[1, "w", true], [40, "space", true], [41, "space", false], [50, "ctrl", true], [90, "ctrl", false], [200, "w", false]]), 220)
	var frames := eye_rows.duplicate()
	var worst := 0.0
	var at_duck := 0.0
	for i: int in range(1, frames.size()):
		var a: Dictionary = frames[i - 1]
		var b: Dictionary = frames[i]
		if int(b.pt) < 1:
			continue
		# camera motion minus physical vertical travel between the two frames.
		var travel := 0.0
		for row: Dictionary in r:
			if int(row.pt) > int(a.pt) and int(row.pt) <= int(b.pt):
				travel += (row.raw.d as Vector3).y / U
		var jump := absf(float(b.cam_y_u) - float(a.cam_y_u) - travel)
		worst = maxf(worst, jump)
		if int(b.pt) == 50:
			at_duck = jump
	var duck := first(r, "duck_air")
	var settled := float(r[duck + 14].raw.eye)
	check("eye_air_duck_no_lift_pop", at_duck <= 1.41 and worst <= 1.41, "duck-frame eye step %.3f u, worst %.3f u (lift is 9 u)" % [at_duck, worst])
	check("eye_air_duck_settles_46", settled == 46.0, "eye %.3f u" % settled)
	findings["eye"] = {"duck_frame_step_u": at_duck, "worst_frame_step_u": worst, "frames": frames.size()}

static func _plain(value: Variant) -> Variant:
	if value is Vector3:
		var v: Vector3 = value
		return [v.x, v.y, v.z]
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[str(key)] = _plain(value[key])
		return out
	if value is Array:
		var out := []
		for item: Variant in value:
			out.append(_plain(item))
		return out
	return value

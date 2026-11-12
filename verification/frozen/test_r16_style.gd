extends SceneTree
## p / r16 style on real collision, on the actual r15 main hosting a labelled fixture level
## (tests/r16_style_fixture_level.gd, convex prisms as the r15 maps build). every movement is
## earned from key and mouse events delivered before the motors (priority -1000); the style
## probe (tests/r16_style_probe.gd, priority 1000) builds the INTERFACES sample after them.
##
## method: a CALIBRATION episode runs a closed-loop controller (it reads the runner's state and
## answers with key edges and mouse counts, which are recorded as a tape) on open floor. the
## scored geometry (beam, window, ledge, gap, slab) is then placed from that trajectory with a
## designed number: headroom, slack, gap width, clearance. the SCORED episode replays the same
## tape open loop (same spawn, same settle, same ticks) with the geometry in place, so the
## trajectory is identical until it meets the geometry, and the measured number is checked
## against the designed one. negative controls replay edited tapes or change one piece.
## gates are promises; findings are measurements. setup between episodes is labelled: key
## releases, level.configure(spec), main.restart_run() (the R key's own path).
## godot --headless --audio-driver Dummy --path . --script res://verification/frozen/test_r16_style.gd --
##   --out=DIR [--only=crouch,window,lip,gap,near,flow,farm,nogain,panel,readonly]

const MAIN := preload("res://scripts/r15_main.gd")
const FIX := preload("res://verification/frozen/r16_style_fixture_level.gd")
const PROBE := preload("res://verification/frozen/r16_style_probe.gd")
const STYLE := preload("res://scripts/r16_style.gd")
const PANEL := preload("res://scripts/r16_style_panel.gd")
const R12_MAIN := preload("res://scripts/spillway_main.gd")
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL}
const GROUPS := ["readonly", "crouch", "window", "lip", "gap", "near", "flow", "farm", "nogain", "panel"]
const SETTLE := 8
const U := 0.0254
const HW := 16.0 * U
const DUCK := 54.0 * U
const STAND := 72.0 * U

signal episode_done

class Hook:
	extends Node
	var suite: Object
	var phase: String

	func _physics_process(_delta: float) -> void:
		suite.call(phase)

var out_dir := ""
var groups: Array = GROUPS.duplicate()
var game: Node
var level: Node3D
var probe: Node
var checks: Array[Dictionary] = []
var findings: Dictionary = {}
var episodes: Dictionary = {}
var ep: Dictionary = {}
var running := false
var rpc := 0.0022
var write_violations: Array[String] = []
var _pre_write: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			groups = Array(arg.trim_prefix("--only=").split(","))
	assert(out_dir.is_absolute_path(), "test_r16_style: pass --out=<absolute directory outside git>")
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("episodes"))
	Engine.physics_ticks_per_second = 128
	game = MAIN.new()
	game.name = "R15"
	game.set("level_script", FIX)
	game.set("motor", "server128")
	game.set("set_window_title", false)
	root.add_child(game)
	level = game.get("level")
	probe = PROBE.new(game)
	root.add_child(probe)
	for spec: Array in [["early_tick", -1000], ["pre_style", 999], ["late_tick", 1001]]:
		var hook := Hook.new()
		hook.suite = self
		hook.phase = spec[0]
		hook.process_physics_priority = spec[1]
		root.add_child(hook)
	rpc = float(game.get("player").get("tape_radians_per_count"))
	await process_frame
	await physics_frame
	for group: String in GROUPS:
		if group in groups:
			await call("group_" + group)
	check("style_never_wrote_the_body", write_violations.is_empty(), "%d ticks changed between the pre-style read and post-style read %s" % [write_violations.size(), write_violations.slice(0, 3)])
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.pass)
	var summary := {
		"label": "P actual r15 main (persistence off) hosting tests/r16_style_fixture_level.gd; inputs are key and mouse events only; probe = tests/r16_style_probe.gd",
		"engine": Engine.get_version_info(), "style_version": STYLE.STYLE_VERSION, "identity": STYLE.identity(), "groups": groups,
		"checks": checks, "findings": findings, "episodes": episodes, "gates": checks.size(), "failed": failed.size(),
		"sources_sha256": _sources(),
	}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_plain(summary), "\t"))
	file.close()
	print("r16 style: %d checks, %d failed; summary %s" % [checks.size(), failed.size(), out_dir.path_join("summary.json")])
	for c: Dictionary in failed:
		print("FAIL ", c.name, ": ", c.detail)
	game.call("request_quit", 0)
	quit(0 if failed.is_empty() else 1)

static func _sources() -> Dictionary:
	var out := {}
	for path: String in ["res://scripts/r16_style.gd", "res://scripts/r16_style_panel.gd", "res://verification/frozen/r16_style_probe.gd", "res://verification/frozen/r16_style_fixture_level.gd",
			"res://verification/frozen/test_r16_style.gd", "res://scripts/r15_main.gd", "res://scripts/r15_source_player.gd", "res://scripts/r14_source_player.gd",
			"res://scripts/r14_source_motion.gd", "res://scripts/r14_strafe_stats.gd"]:
		out[path] = FileAccess.get_sha256(path)
	return out

func check(name: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"name": name, "pass": ok, "detail": str(detail)})
	print("%s %s %s" % ["ok  " if ok else "FAIL", name, str(detail)])

func finding(name: String, value: Variant) -> void:
	findings[name] = value
	print("  finding %s %s" % [name, str(value)])

# --- episode machinery ----------------------------------------------------------------------

static func send(event: Array) -> void:
	if event[0] == "mouse":
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(float(event[1]), 0.0)
		motion.screen_relative = motion.relative
		Input.parse_input_event(motion)
	else:
		var key := InputEventKey.new()
		key.physical_keycode = KEYS[event[0]]
		key.pressed = event[1]
		Input.parse_input_event(key)
	Input.flush_buffered_events()

## one episode: the labelled setup, SETTLE ticks with no input, then `ticks` motor steps whose
## input comes from `tape` ({tick: [[key, pressed] | ["mouse", counts]]}) or, closed loop, from
## `controller.call(t, row, memory)`, which is recorded as the episode's tape.
func episode(name: String, spec: Dictionary, ticks: int, tape: Dictionary = {}, controller := Callable(), memory: Dictionary = {}) -> Dictionary:
	await process_frame
	for key: String in KEYS:
		send([key, false])
	level.call("configure", spec)
	game.call("restart_run")
	ep = {"name": name, "tick": 0, "length": ticks + SETTLE, "tape": tape, "controller": controller, "memory": memory, "recorded": {},
		"rows": [], "first_event": probe.scored.size(), "last_row": {}}
	running = true
	await episode_done
	for key: String in KEYS:
		send([key, false])
	var events: Array = probe.scored.slice(int(ep.first_event))
	var snap: Dictionary = probe.style.call("snapshot")
	var result := {"name": name, "rows": ep.rows, "events": events, "snapshot": snap, "tape": ep.recorded if controller.is_valid() else tape}
	episodes[name] = {"ticks": ticks, "settle": SETTLE, "mode": "closed loop (recorded)" if controller.is_valid() else "open loop tape", "tape_ticks": (result.tape as Dictionary).size(),
		"events": events.map(func(e: Dictionary) -> String: return "%s@%d %s +%d" % [e.kind, int(e.tick), str(e.label), int(e.points)]), "score": snap.score,
		"verdicts": snap.diag.verdicts, "crouch_counts": snap.diag.crouch.counts, "farm_blocked": snap.diag.farm_blocked, "discontinuities": snap.diag.discontinuities}
	var lines := PackedStringArray()
	for row: Dictionary in ep.rows:
		lines.append(JSON.stringify(_plain(row)))
	var file := FileAccess.open(out_dir.path_join("episodes").path_join(name + ".jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(lines) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	return result

func early_tick() -> void:
	if not running:
		return
	ep.tick = int(ep.tick) + 1
	var t := int(ep.tick) - SETTLE
	if t < 1:
		return
	var sent: Array = []
	if (ep.controller as Callable).is_valid():
		sent = (ep.controller as Callable).call(t, ep.last_row, ep.memory)
		if not sent.is_empty():
			(ep.recorded as Dictionary)[t] = sent
	else:
		sent = (ep.tape as Dictionary).get(t, [])
	for event: Array in sent:
		send(event)

func pre_style() -> void:
	if not running:
		return
	var player: CharacterBody3D = game.get("player")
	_pre_write = {"p": player.global_position, "v": player.velocity, "g": player.call("is_grounded"), "yaw": player.get("yaw"), "d": player.get("ducked")}

func late_tick() -> void:
	if not running:
		return
	var player: CharacterBody3D = game.get("player")
	var now := {"p": player.global_position, "v": player.velocity, "g": player.call("is_grounded"), "yaw": player.get("yaw"), "d": player.get("ducked")}
	if not _pre_write.is_empty() and now != _pre_write:
		write_violations.append("%s tick %d" % [ep.name, int(ep.tick)])
	var t := int(ep.tick) - SETTLE
	var motion: Dictionary = player.call("get_motion_state")
	var snap: Dictionary = probe.style.call("snapshot")
	var contacts: Array = []
	for c: Dictionary in motion.contacts:
		contacts.append([str(c.body), snappedf((c.normal as Vector3).y, 0.001), bool(c.blocking)])
	var row := {"t": t, "p": player.global_position, "v": player.velocity / U, "spd": Vector2((motion.actual_velocity as Vector3).x, (motion.actual_velocity as Vector3).z).length() / U,
		"g": bool(motion.grounded), "d": bool(player.get("ducked")), "yaw": float(player.get("yaw")), "events": motion.events, "contacts": contacts,
		"score": snap.score, "combo": snap.combo, "crouch": snap.diag.crouch.last.get("class", snap.diag.crouch.last.get("verdict", "")),
		"started": bool(game.get("_started")), "finished": bool(game.get("finished")), "respawns": int(game.get("respawn_count")),
		"hops": int((game.get("stats").call("snapshot") as Dictionary).hops)}
	(ep.rows as Array).append(row)
	ep.last_row = row
	if int(ep.tick) >= int(ep.length):
		running = false
		episode_done.emit()

# --- tapes and controllers -------------------------------------------------------------------

## a copy of `tape` without the edges of `key`.
static func without(tape: Dictionary, key: String) -> Dictionary:
	var out := {}
	for t: int in tape:
		var kept: Array = (tape[t] as Array).filter(func(e: Array) -> bool: return e[0] != key)
		if not kept.is_empty():
			out[t] = kept
	return out

## closed loop: hold W; one jump press when the feet pass `jump_z` (toward -z); crouch pressed
## when the feet pass `crouch_z`, or `crouch_after` ticks after the takeoff, or on the first air
## tick whose vertical speed falls under `crouch_vy` u/s; crouch held from then on.
func ctl_run(t: int, row: Dictionary, m: Dictionary) -> Array:
	var out: Array = []
	if t == 1:
		out.append(["w", true])
		if bool(m.get("crouch_at_start", false)):
			out.append(["ctrl", true])
			m["crouched"] = true
		return out
	if row.is_empty():
		return out
	var z: float = (row.p as Vector3).z
	if m.has("jump_z") and not m.has("jumped") and z <= float(m.jump_z):
		out.append(["space", true])
		m["jumped"] = t
		return out
	if m.has("jumped") and int(m.jumped) == t - 1:
		out.append(["space", false])
	if m.has("jumped") and not bool(row.g) and not m.has("takeoff"):
		m["takeoff"] = t
	if not m.has("crouched"):
		var go := false
		if m.has("crouch_z") and z <= float(m.crouch_z):
			go = true
		if m.has("crouch_after") and m.has("takeoff") and t - int(m.takeoff) >= int(m.crouch_after):
			go = true
		if m.has("crouch_vy") and m.has("takeoff") and float((row.v as Vector3).y) <= float(m.crouch_vy):
			go = true
		if go:
			out.append(["ctrl", true])
			m["crouched"] = t
	if m.has("stop_z") and z <= float(m.stop_z) and not m.has("stopped"):
		out.append(["w", false])
		m["stopped"] = t
	if m.has("release_ctrl_after_stop") and m.has("stopped") and t == int(m.stopped) + int(m.release_ctrl_after_stop):
		out.append(["ctrl", false])
	return out

## closed loop: walk up, then strafe-hop with a sine sweep of the view and the side key that
## agrees with it, until `coast_ups` (then release the side key and stop turning, holding Space)
## or forever. heading is kept toward -z around x = `lane_x`.
func ctl_strafe(t_abs: int, row: Dictionary, m: Dictionary) -> Array:
	var out: Array = []
	# a respawn restarts the plan from the spawn: keys up, time from zero (the farm control).
	if not row.is_empty() and int(row.respawns) > int(m.get("respawns", 0)):
		m["respawns"] = int(row.respawns)
		m["t0"] = t_abs
		for key: String in ["w", "a", "d", "space"]:
			out.append([key, false])
			m.erase("held_" + key)
		for key: String in ["air", "coast"]:
			m.erase(key)
		return out
	var t := t_abs - int(m.get("t0", 0))
	if t == 1:
		return [["w", true]]
	if row.is_empty():
		return out
	var run_ticks := int(m.get("run_ticks", 110))
	if t == run_ticks:
		out.append(["space", true])
	if t < run_ticks:
		return out
	if not m.has("air") and not bool(row.g):
		m["air"] = t
		out.append(["w", false])
	if not m.has("air"):
		return out
	if m.has("coast"):
		if m.has("stop_after") and t - int(m.coast) == int(m.stop_after):
			out.append(["space", false])
		return out
	if m.has("coast_ups") and float(row.spd) >= float(m.coast_ups) and not bool(row.g):
		m["coast"] = t
		for k: String in ["a", "d"]:
			if bool(m.get("held_" + k, false)):
				out.append([k, false])
				m["held_" + k] = false
		return out
	var period := float(m.get("period", 96.0))
	var amp := deg_to_rad(float(m.get("amp_deg", 28.0)))
	var phase := float(t - int(m.air)) / period * TAU
	var drift := clampf(((row.p as Vector3).x - float(m.get("lane_x", 0.0))) * 0.04, -0.12, 0.12)
	var target := amp * sin(phase) - drift
	var yaw := float(row.yaw)
	var turn := clampf(target - yaw, -0.04, 0.04)
	out.append(["mouse", -turn / rpc])
	var want := "a" if turn > 0.0 else "d"
	var other := "d" if want == "a" else "a"
	if bool(m.get("held_" + other, false)):
		out.append([other, false])
		m["held_" + other] = false
	if not bool(m.get("held_" + want, false)):
		out.append([want, true])
		m["held_" + want] = true
	return out

## closed loop, the no-gain control: W and A held in the air with the view turning left, so
## every eligible tick is in sync while the wish direction is mostly along the velocity.
func ctl_nogain(t: int, row: Dictionary, m: Dictionary) -> Array:
	if t == 1:
		return [["w", true]]
	if t == 110:
		return [["space", true], ["a", true]]
	if t > 110 and not row.is_empty() and not bool(row.g):
		return [["mouse", -0.0005 / rpc]]
	return []

## the first row index at or after `from` where `pred` holds, or -1.
static func find(rows: Array, pred: Callable, from := 0) -> int:
	for i: int in range(from, rows.size()):
		if pred.call(rows[i]):
			return i
	return -1

## an event's episode tick: the probe counts attempt ticks from the restart, which is episode
## tick 1 - SETTLE.
static func ep_t(event: Dictionary) -> int:
	return int(event.tick) - (SETTLE - 1)

static func of_kind(events: Array, kind: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return str(e.kind) == kind)

# --- groups ---------------------------------------------------------------------------------

## the probe never changes the body: checked every tick of every episode (pre_style vs late),
## and here a crouch run with the probe off is compared tick for tick with the probe on.
func group_readonly() -> void:
	var cal := await episode("readonly_on", FIX.flat_spec(), 420, {}, ctl_run, {"jump_z": -10.0, "crouch_after": 12})
	probe.set_physics_process(false)
	var off := await episode("readonly_off", FIX.flat_spec(), 420, cal.tape)
	probe.set_physics_process(true)
	var same: bool = cal.rows.size() == off.rows.size()
	var worst := 0.0
	for i: int in mini(cal.rows.size(), off.rows.size()):
		worst = maxf(worst, ((cal.rows[i].p as Vector3) - (off.rows[i].p as Vector3)).length())
		worst = maxf(worst, ((cal.rows[i].v as Vector3) - (off.rows[i].v as Vector3)).length() * U)
	check("readonly_trace_identical_with_and_without_style", same and worst == 0.0, "rows %d/%d, worst |dp|,|dv| %.9f m" % [cal.rows.size(), off.rows.size(), worst])

## a ground crouch under a beam the standing hull cannot pass, and its negative controls.
func group_crouch() -> void:
	var m := {"crouch_z": -14.0}
	var cal := await episode("crouch_cal", FIX.flat_spec(), 520, {}, ctl_run, m)
	var rows: Array = cal.rows
	var press := find(rows, func(r: Dictionary) -> bool: return bool(r.d))
	var at: Dictionary = rows[press + 2]
	var front := (at.p as Vector3).z - HW - 0.04
	var feet_y := (at.p as Vector3).y
	var bottom := feet_y + DUCK + 4.0 * U
	var spec := FIX.flat_spec()
	(spec.pieces as Array).append(FIX.block("beam", Vector3(-6, bottom, front - 0.3), Vector3(6, 2.4, front)))
	finding("crouch_design", {"press_t": rows[press].t, "beam_front_z": front, "beam_bottom_y": bottom, "designed_room_u": (bottom - feet_y - DUCK) / U, "speed_at_press_ups": rows[press].spd})
	var run := await episode("crouch_save", spec, 520, cal.tape)
	var saves := of_kind(run.events, "crouch_save")
	var ok := saves.size() == 1
	var e: Dictionary = saves[0] if ok else {}
	check("crouch_ground_save_pays_once", ok, run.events.map(func(x: Dictionary) -> String: return x.label))
	if ok:
		var room := float(e.m.room_u)
		var designed := (bottom - feet_y - DUCK) / U
		check("crouch_ground_save_is_head_slab_on_beam", str(e.m.slab) == "head" and str(e.geo.obstacle.path) == "beam" and not bool(e.m.airborne), e.m)
		check("crouch_ground_room_matches_design", absf(room - designed) < 0.06, "measured %.4f u, designed %.4f u (feet stand off one margin)" % [room, designed])
		check("crouch_ground_standing_intrusion", absf(float(e.m.standing_intrusion_u) - (18.0 - room)) < 0.01, e.m.standing_intrusion_u)
		check("crouch_ground_entry_speed", float(e.m.entry_ups) >= 200.0, e.m.entry_ups)
		var passed := find(run.rows, func(r: Dictionary) -> bool: return (r.p as Vector3).z < front - 0.3 - HW)
		check("crouch_ground_paid_after_passage", passed >= 0 and ep_t(e) >= int(run.rows[passed].t), "paid at episode tick %d, hull clear of the beam at tick %d" % [ep_t(e), int(run.rows[passed].t) if passed >= 0 else -1])
	# negative: the same tape without crouch bonks the beam standing.
	var stand := await episode("crouch_neg_standing", spec, 520, without(cal.tape, "ctrl"))
	var bonk := find(stand.rows, func(r: Dictionary) -> bool: return (r.contacts as Array).any(func(c: Array) -> bool: return c[0] == "beam"))
	check("crouch_neg_standing_hits_beam_no_save", bonk >= 0 and of_kind(stand.events, "crouch_save").is_empty(), "first beam contact row %d, events %s" % [bonk, stand.events.map(func(x: Dictionary) -> String: return x.kind)])
	# negative: crawling under with crouch held from the start (stationary-ish ducking speed).
	var near_spec := spec.duplicate()
	near_spec["spawn"] = Transform3D(Basis.IDENTITY, Vector3(0, 0.0, front + 3.0))
	var crawl := await episode("crouch_neg_crawl", near_spec, 700, {}, ctl_run, {"crouch_at_start": true, "stop_z": front - 0.15, "release_ctrl_after_stop": 200})
	var under: bool = crawl.rows.any(func(r: Dictionary) -> bool: return (r.p as Vector3).z < front and (r.p as Vector3).z > front - 0.3 - HW and bool(r.d))
	check("crouch_neg_crawl_reached_under_the_beam", under, under)
	var crawl_counts: Dictionary = crawl.snapshot.diag.crouch.counts
	check("crouch_neg_crawl_and_stand_still_under_beam_no_save", of_kind(crawl.events, "crouch_save").is_empty() and int(crawl_counts.slow) + int(crawl_counts.start_overlap) > 0,
		crawl_counts)
	finding("crouch_neg_crawl_counts", crawl_counts)
	# negative: bonk standing, then duck and walk under.
	var bonk_tape := without(cal.tape, "ctrl")
	if bonk >= 0:
		var t_bonk := int(stand.rows[bonk].t)
		bonk_tape[t_bonk + 2] = [["ctrl", true]]
	var late := await episode("crouch_neg_bonk_then_duck", spec, 700, bonk_tape)
	var late_counts: Dictionary = late.snapshot.diag.crouch.counts
	check("crouch_neg_bonk_then_duck_no_save", of_kind(late.events, "crouch_save").is_empty(), late_counts)
	finding("crouch_neg_bonk_counts", late_counts)
	# negative: the same crouch on open floor (no beam) never opens anything.
	var open := await episode("crouch_neg_open_floor", FIX.flat_spec(), 520, cal.tape)
	var open_counts: Dictionary = open.snapshot.diag.crouch.counts
	check("crouch_neg_open_floor_no_obstacle", of_kind(open.events, "crouch_save").is_empty() and int(open_counts.obstacle) == 0 and int(open_counts.ducked_ticks) > 50, open_counts)

## a jump with a crouch in flight through a window the duck hull fits and the standing hull
## (same centre, 9 u more at each end) does not.
func group_window() -> void:
	var m := {"jump_z": -14.0, "crouch_vy": 120.0}
	var cal := await episode("window_cal", FIX.flat_spec(), 520, {}, ctl_run, m)
	var rows: Array = cal.rows
	var ducked := rows.filter(func(r: Dictionary) -> bool: return bool(r.d) and not bool(r.g))
	var apex: Dictionary = ducked[0]
	for r: Dictionary in ducked:
		if (r.p as Vector3).y > (apex.p as Vector3).y:
			apex = r
	var t_wall := 0.1
	var z_front := (apex.p as Vector3).z + HW * 0.25
	var lo := INF
	var hi := -INF
	var standing_in_slab := 0
	for r: Dictionary in rows:
		var z := (r.p as Vector3).z
		if int(r.t) > 1 and z - HW < z_front and z + HW > z_front - t_wall:
			if not bool(r.d):
				standing_in_slab += 1
			lo = minf(lo, (r.p as Vector3).y)
			hi = maxf(hi, (r.p as Vector3).y + DUCK)
	check("window_design_hull_ducked_through_the_slab", standing_in_slab == 0, standing_in_slab)
	# the sill stays more than the 2 u ground probe under the duck feet, or the runner lands on it.
	var sill := lo - 3.0 * U
	var lintel := hi + 0.5 * U
	var spec := FIX.flat_spec()
	for piece: Dictionary in [FIX.block("win_left", Vector3(-6, -1, z_front - t_wall), Vector3(-1, 6, z_front)), FIX.block("win_right", Vector3(1, -1, z_front - t_wall), Vector3(6, 6, z_front)),
			FIX.block("win_sill", Vector3(-1, -1, z_front - t_wall), Vector3(1, sill, z_front)), FIX.block("win_lintel", Vector3(-1, lintel, z_front - t_wall), Vector3(1, 6, z_front))]:
		(spec.pieces as Array).append(piece)
	finding("window_design", {"opening_u": (lintel - sill) / U, "sill_y": sill, "lintel_y": lintel, "z_front": z_front, "duck_feet_range_u": [lo / U, (hi - DUCK) / U], "crouch_t": m.get("crouched")})
	check("window_opening_admits_duck_not_standing", (lintel - sill) / U < 72.0 and (lintel - sill) / U > 54.0, (lintel - sill) / U)
	var run := await episode("window_save", spec, 520, cal.tape)
	var saves := of_kind(run.events, "crouch_save")
	check("window_air_save_pays_once", saves.size() == 1, run.events.map(func(x: Dictionary) -> String: return x.label))
	if saves.size() == 1:
		var e: Dictionary = saves[0]
		check("window_air_save_airborne_on_window_piece", bool(e.m.airborne) and str(e.geo.obstacle.path) in ["win_sill", "win_lintel"] and absf(float(e.m.lift_u) - 9.0) < 1e-6, e.m)
		check("window_air_save_room_under_one_u", e.m.room_u != null and float(e.m.room_u) > 0.3 and float(e.m.room_u) < 3.0, e.m.room_u)
		var touched: bool = run.rows.any(func(r: Dictionary) -> bool: return (r.contacts as Array).any(func(c: Array) -> bool: return str(c[0]).begins_with("win")))
		check("window_duck_hull_never_touched_window", not touched, touched)
	var stand := await episode("window_neg_standing", spec, 520, without(cal.tape, "ctrl"))
	var hit: bool = stand.rows.any(func(r: Dictionary) -> bool: return (r.contacts as Array).any(func(c: Array) -> bool: return str(c[0]).begins_with("win")))
	check("window_neg_standing_hits_no_save", hit and of_kind(stand.events, "crouch_save").is_empty(), hit)
	# the standing ghost inside the floor: the same air crouch on open floor lands ducked; the
	# foot slab meets the floor (support) and nothing opens.
	var open := await episode("window_neg_open_floor", FIX.flat_spec(), 520, cal.tape)
	var counts: Dictionary = open.snapshot.diag.crouch.counts
	check("window_neg_air_duck_landing_is_support_not_save", of_kind(open.events, "crouch_save").is_empty() and int(counts.obstacle) == 0 and int(counts.support) > 0, counts)

## a crouch-jump onto a ledge too high for a standing jump (the foot slab hits its lip face).
func group_lip() -> void:
	var m := {"jump_z": -14.0, "crouch_after": 4}
	var cal := await episode("lip_cal", FIX.flat_spec(), 520, {}, ctl_run, m)
	var rows: Array = cal.rows
	var apex: Dictionary = {}
	for r: Dictionary in rows:
		if not bool(r.g) and (apex.is_empty() or (r.p as Vector3).y > (apex.p as Vector3).y):
			apex = r
	# the lip 2 cm past the hull's leading edge at the apex: it is crossed just after the apex.
	var lip_z := (apex.p as Vector3).z - HW - 0.02
	var top := (apex.p as Vector3).y - 2.0 * U
	var spec := FIX.flat_spec()
	(spec.pieces as Array).append(FIX.block("ledge", Vector3(-6, -1, lip_z - 6.0), Vector3(6, top, lip_z), "route"))
	finding("lip_design", {"ledge_top_u": top / U, "duck_apex_feet_u": (apex.p as Vector3).y / U, "standing_apex_feet_u": (apex.p as Vector3).y / U - 9.0, "lip_z": lip_z})
	var run := await episode("lip_save", spec, 520, cal.tape)
	var saves := of_kind(run.events, "crouch_save")
	check("lip_crouch_jump_save_pays_once", saves.size() == 1, run.events.map(func(x: Dictionary) -> String: return x.label))
	if saves.size() == 1:
		var e: Dictionary = saves[0]
		check("lip_save_is_foot_slab_on_ledge_side", str(e.m.slab) == "foot" and str(e.geo.obstacle.path) == "ledge" and absf(float((e.m.normal as Array)[1])) < 0.01, e.m)
	var landed: bool = run.rows.any(func(r: Dictionary) -> bool: return bool(r.g) and (r.p as Vector3).y > top - 0.01)
	check("lip_duck_hull_landed_on_ledge", landed, top)
	var stand := await episode("lip_neg_standing", spec, 520, without(cal.tape, "ctrl"))
	var stood_on: bool = stand.rows.any(func(r: Dictionary) -> bool: return bool(r.g) and (r.p as Vector3).y > top - 0.01)
	check("lip_neg_standing_jump_fails_no_save", not stood_on and of_kind(stand.events, "crouch_save").is_empty(), stand.events.map(func(x: Dictionary) -> String: return x.kind))
	var low_spec := FIX.flat_spec()
	var low := (apex.p as Vector3).y - 15.0 * U
	(low_spec.pieces as Array).append(FIX.block("ledge_low", Vector3(-6, -1, lip_z - 6.0), Vector3(6, low, lip_z), "route"))
	var easy := await episode("lip_neg_low_ledge", low_spec, 520, cal.tape)
	var counts: Dictionary = easy.snapshot.diag.crouch.counts
	check("lip_neg_low_ledge_standing_would_land_too_no_save", of_kind(easy.events, "crouch_save").is_empty(), counts)

## gaps and edge slack placed from one calibrated jump; shallow, narrow, repeat and respawn controls.
func group_gap() -> void:
	var m := {"jump_z": -14.0}
	var cal := await episode("gap_cal", FIX.flat_spec(), 620, {}, ctl_run, m)
	var rows: Array = cal.rows
	var air := find(rows, func(r: Dictionary) -> bool: return not bool(r.g) and int(r.t) > 2)
	var land := find(rows, func(r: Dictionary) -> bool: return bool(r.g), air)
	check("gap_cal_flight_landed", air > 0 and land > air, "air row %d, landing row %d" % [air, land])
	if land <= air:
		return
	var p0: Vector3 = rows[air - 1].p
	var p1: Vector3 = rows[land].p
	var slack := 3.0 * U
	var z_a := p0.z - HW - 0.10
	var z_b := p1.z - HW + slack
	var gap := z_a - z_b
	var spec := _gap_spec(z_a, z_b)
	finding("gap_design", {"takeoff_z": p0.z, "landing_z": p1.z, "near_lip_z": z_a, "far_lip_z": z_b, "gap_m": gap, "slack_u": 3.0})
	var run := await episode("gap_edge", spec, 620, cal.tape)
	var gaps := of_kind(run.events, "gap")
	var edges := of_kind(run.events, "edge")
	check("gap_pays_once", gaps.size() == 1, run.events.map(func(x: Dictionary) -> String: return x.label))
	if gaps.size() == 1:
		check("gap_cleared_matches_designed_width", absf(float(gaps[0].m.cleared_m) - gap) < 0.002, "measured %.5f m, designed %.5f m" % [float(gaps[0].m.cleared_m), gap])
		check("gap_pieces_named", str(gaps[0].geo.from.path) == "near" and str(gaps[0].geo.to.path) == "far", gaps[0].geo)
	check("edge_pays_once", edges.size() == 1, edges.map(func(x: Dictionary) -> String: return x.label))
	if edges.size() == 1:
		check("edge_slack_matches_design", absf(float(edges[0].m.slack_u) - 3.0) < 0.05, "measured %.4f u, designed 3 u" % float(edges[0].m.slack_u))
	# controls: a shallow trench (support within 1.25 m) and a narrow gap.
	var shallow := _gap_spec(z_a, z_b)
	(shallow.pieces as Array).append(FIX.deck("trench", -6, 6, z_a, z_b, -0.5, -1.5))
	var trench := await episode("gap_neg_shallow_trench", shallow, 620, cal.tape)
	check("gap_neg_shallow_trench_no_gap_no_edge", of_kind(trench.events, "gap").is_empty() and of_kind(trench.events, "edge").is_empty(), trench.snapshot.diag.gap)
	var narrow := await episode("gap_neg_narrow", _gap_spec(z_a, z_a - 1.0), 620, cal.tape)
	check("gap_neg_narrow_1m_no_gap", of_kind(narrow.events, "gap").is_empty(), narrow.snapshot.diag.gap)
	var far_landing := await episode("edge_neg_roomy", _gap_spec(z_a, z_b + 0.5), 620, cal.tape)
	check("edge_neg_roomy_landing_no_edge", of_kind(far_landing.events, "edge").is_empty() and of_kind(far_landing.events, "gap").size() == 1, far_landing.snapshot.diag.edge)
	# farm: cross, run off the far deck's end, respawn at the start, cross again. one attempt.
	var farm_spec := _gap_spec(z_a, z_b, z_b - 4.0)
	var farm := await episode("gap_farm_respawn_repeat", farm_spec, 1400, {}, ctl_jump_loop, {"jump_z": float(m.jump_z)})
	var farm_gaps := of_kind(farm.events, "gap")
	var respawned: bool = farm.rows.any(func(r: Dictionary) -> bool: return int(r.respawns) > 0)
	var crossings: int = farm.rows.filter(func(r: Dictionary) -> bool: return bool(r.g) and (r.p as Vector3).z < z_b and (r.p as Vector3).z > z_b - 1.0).size()
	check("gap_farm_second_crossing_not_paid", respawned and farm_gaps.size() == 1 and int((farm.snapshot.diag.farm_blocked as Dictionary).get("gap", 0)) >= 1,
		"respawned %s, gap events %d, blocked %s, verdicts %s" % [respawned, farm_gaps.size(), farm.snapshot.diag.farm_blocked, farm.snapshot.diag.verdicts])
	check("gap_farm_respawn_is_a_discontinuity", (farm.snapshot.diag.discontinuities as Array).has("respawn"), farm.snapshot.diag.discontinuities)
	finding("gap_farm_landing_rows_on_far_lip", crossings)
	# teleport mid-flight: the host's respawn while over the gap; no gap may come of it.
	var tele := await episode("gap_neg_respawn_mid_flight", spec, 620, {}, ctl_jump_respawn, {"jump_z": float(m.jump_z), "respawn_after": 20})
	check("gap_neg_respawn_mid_flight_no_gap", of_kind(tele.events, "gap").is_empty() and of_kind(tele.events, "edge").is_empty(), tele.snapshot.diag.discontinuities)

## the near deck up to z_a, a pit, and the far deck from z_b to far_end (both toward -z).
func _gap_spec(z_a: float, z_b: float, far_end: float = -200.0) -> Dictionary:
	var pieces: Array = [FIX.deck("near", -6, 6, 8.0, z_a, 0.0), FIX.deck("far", -6, 6, z_b, far_end, 0.0)]
	return {"pieces": pieces, "spawn": Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 4)), "kill_y": -3.0}

## closed loop: hold W, jump each time the feet pass `jump_z` going -z (re-armed by a respawn).
func ctl_jump_loop(t: int, row: Dictionary, m: Dictionary) -> Array:
	if t == 1:
		return [["w", true]]
	if row.is_empty():
		return []
	var z: float = (row.p as Vector3).z
	if z > float(m.jump_z) + 1.0:
		m["armed"] = true
	if bool(m.get("armed", false)) and z <= float(m.jump_z):
		m["armed"] = false
		m["release"] = t + 1
		return [["space", true]]
	if int(m.get("release", -1)) == t:
		return [["space", false]]
	return []

## closed loop: one jump, then the host's own respawn() `respawn_after` ticks into the flight.
func ctl_jump_respawn(t: int, row: Dictionary, m: Dictionary) -> Array:
	var out := ctl_jump_loop(t, row, m)
	if not row.is_empty() and not bool(row.g) and not m.has("air"):
		m["air"] = t
	if m.has("air") and t == int(m.air) + int(m.respawn_after):
		game.call("respawn")
	return out

## near misses: slabs parallel to a coasting strafe line at designed clearances.
func group_near() -> void:
	var m := {"coast_ups": 470.0, "run_ticks": 110}
	var cal := await episode("near_cal", FIX.flat_spec(), 1300, {}, ctl_strafe, m)
	var rows: Array = cal.rows
	if not m.has("coast"):
		check("near_cal_reached_coast_speed", false, "max %.1f u/s" % rows.reduce(func(a: float, r: Dictionary) -> float: return maxf(a, float(r.spd)), 0.0))
		return
	var start := find(rows, func(r: Dictionary) -> bool: return int(r.t) >= int(m.coast) + 70)
	var a: Dictionary = rows[start]
	var b: Dictionary = rows[start + 24]
	var d := Vector3((b.p as Vector3).x - (a.p as Vector3).x, 0, (b.p as Vector3).z - (a.p as Vector3).z).normalized()
	var right := Vector3(-d.z, 0, d.x)
	var extent := HW * (absf(d.x) + absf(d.z))
	var mid: Vector3 = b.p
	finding("near_design", {"coast_t": m.coast, "speed_ups": a.spd, "line": [d.x, d.z], "at": [mid.x, mid.z]})
	# [name, [[side sign, clearance u]...], expected events]; a negative clearance overlaps the hull's path.
	var cases := [["near_right_3u", [[1.0, 3.0]], 1], ["near_thread_4u", [[1.0, 4.0], [-1.0, 4.0]], 1], ["near_neg_wide_12u", [[1.0, 12.0]], 0], ["near_neg_scrape", [[1.0, -1.0]], 0]]
	for c: Array in cases:
		var spec := FIX.flat_spec()
		for pair: Array in (c[1] as Array):
			var side := right * float(pair[0])
			var face := mid + side * (extent + float(pair[1]) * U)
			(spec.pieces as Array).append(FIX.slab("pillar_%s" % ("r" if float(pair[0]) > 0.0 else "l"), face - d * 0.3, face + d * 0.3, side, 0.3, -1.0, 4.0))
		var run := await episode(str(c[0]), spec, 1300, cal.tape)
		var near := of_kind(run.events, "near_miss")
		var detail := {"events": run.events.map(func(x: Dictionary) -> String: return x.label), "last": run.snapshot.diag.near.last, "verdicts": run.snapshot.diag.verdicts.get("near_miss", {})}
		check("%s_events_%d" % [c[0], c[2]], near.size() == int(c[2]), detail)
		if near.size() == 1 and int(c[2]) == 1:
			var designed := float(((c[1] as Array)[0] as Array)[1])
			check("%s_clearance_matches_design" % c[0], absf(float(near[0].m.clear_u) - designed) < 0.15, "measured %.4f u, designed %.1f u" % [float(near[0].m.clear_u), designed])
			check("%s_thread_flag" % c[0], bool(near[0].m.thread) == ((c[1] as Array).size() == 2), near[0].m)
	# a long wall at 3 u: a hug, not a passage.
	var hug := FIX.flat_spec()
	(hug.pieces as Array).append(FIX.slab("long_wall", mid - d * 6.0 + right * (extent + 3.0 * U), mid + d * 6.0 + right * (extent + 3.0 * U), right, 0.3, -1.0, 4.0))
	var long := await episode("near_neg_long_wall", hug, 1300, cal.tape)
	check("near_neg_long_wall_no_event", of_kind(long.events, "near_miss").is_empty(), long.snapshot.diag.verdicts.get("near_miss", {}))

## speed, sync and the finish on a long straight strafe run; scoring stops at the line.
func group_flow() -> void:
	var spec := FIX.flat_spec()
	spec["finish"] = AABB(Vector3(-24, -0.5, -150), Vector3(48, 4, 4))
	var m := {"run_ticks": 110}
	var run := await episode("flow_strafe_finish", spec, 2600, {}, ctl_strafe, m)
	var fin := find(run.rows, func(r: Dictionary) -> bool: return bool(r.finished))
	var speed := of_kind(run.events, "speed")
	var sync := of_kind(run.events, "sync")
	check("flow_finished_clean", fin >= 0 and bool(run.snapshot.best_eligible), "finish row %d, best_eligible %s" % [fin, run.snapshot.best_eligible])
	check("flow_speed_events", speed.size() >= 2, speed.map(func(e: Dictionary) -> String: return e.label))
	check("flow_sync_events_have_real_gain", sync.size() >= 3 and sync.all(func(e: Dictionary) -> bool: return float(e.m.air_gain_ups) >= 8.0 and float(e.m.gain_ups) > 0.0 and float(e.m.sync) >= 0.8),
		sync.map(func(e: Dictionary) -> String: return e.label))
	var after: Array = run.events.filter(func(e: Dictionary) -> bool: return fin >= 0 and ep_t(e) > int(run.rows[fin].t))
	check("flow_nothing_scores_after_finish", fin >= 0 and after.is_empty(), after.size())
	check("flow_combo_multiplier_rose", run.events.any(func(e: Dictionary) -> bool: return float(e.mult) > 1.0), run.events.map(func(e: Dictionary) -> float: return e.mult))
	finding("flow_summary", {"score": run.snapshot.score, "by_kind": run.snapshot.by_kind, "verdicts": run.snapshot.diag.verdicts, "max_ups": run.rows.reduce(func(a: float, r: Dictionary) -> float: return maxf(a, float(r.spd)), 0.0)})

## farms on open floor: the same fast line run twice in one attempt (the deck ends, the fall
## respawns at the start, the controller restarts its plan), and idling after the timer starts.
func group_farm() -> void:
	var spec := FIX.flat_spec()
	spec.pieces = (spec.pieces as Array).filter(func(p: Dictionary) -> bool: return not str(p.name).begins_with("deck_3") and not str(p.name).begins_with("deck_4") \
		and not str(p.name).begins_with("deck_5") and not str(p.name).begins_with("deck_6"))
	var loop := await episode("farm_same_line_twice", spec, 3600, {}, ctl_strafe, {"run_ticks": 110})
	var rows: Array = loop.rows
	var first_respawn := find(rows, func(r: Dictionary) -> bool: return int(r.respawns) >= 1)
	var second_respawn := find(rows, func(r: Dictionary) -> bool: return int(r.respawns) >= 2)
	var t1 := int(rows[first_respawn].t) if first_respawn >= 0 else 1 << 30
	var t2 := int(rows[second_respawn].t) if second_respawn >= 0 else 1 << 30
	var pass1: Array = loop.events.filter(func(e: Dictionary) -> bool: return ep_t(e) < t1)
	var pass2: Array = loop.events.filter(func(e: Dictionary) -> bool: return ep_t(e) >= t1 and ep_t(e) < t2)
	var fast2: float = rows.filter(func(r: Dictionary) -> bool: return int(r.t) >= t1 and int(r.t) < t2).reduce(func(a: float, r: Dictionary) -> float: return maxf(a, float(r.spd)), 0.0)
	var speed2 := of_kind(pass2, "speed")
	var points1: int = pass1.reduce(func(a: int, e: Dictionary) -> int: return a + int(e.points), 0)
	var points2: int = pass2.reduce(func(a: int, e: Dictionary) -> int: return a + int(e.points), 0)
	finding("farm_same_line", {"pass1": pass1.map(func(e: Dictionary) -> String: return e.label), "pass2": pass2.map(func(e: Dictionary) -> String: return e.label),
		"pass1_points": points1, "pass2_points": points2, "pass2_max_ups": fast2, "stale_fast_m": loop.snapshot.diag.speed.stale_fast_m, "blocked": loop.snapshot.diag.farm_blocked})
	check("farm_same_line_second_pass_pays_no_speed_and_little_else", first_respawn >= 0 and fast2 > 450.0 and speed2.is_empty() and of_kind(pass1, "speed").size() >= 1 and points2 * 5 < points1,
		"pass 1 %d points, pass 2 %d points at up to %.0f u/s, pass 2 speed events %d" % [points1, points2, fast2, speed2.size()])
	var idle := await episode("farm_idle", FIX.flat_spec(), 1300, {1: [["w", true]], 60: [["w", false]]})
	check("farm_idle_after_start_pays_nothing", bool(idle.rows[-1].started) and idle.events.is_empty() and int(idle.snapshot.score) == 0, idle.snapshot.score)

## high sync without air gain: W + A with the view turning left.
func group_nogain() -> void:
	var run := await episode("nogain_sync", FIX.flat_spec(), 900, {}, ctl_nogain, {})
	var verdicts: Dictionary = run.snapshot.diag.verdicts.get("sync", {})
	var last: Dictionary = run.snapshot.diag.sync
	check("nogain_high_sync_without_gain_pays_nothing", of_kind(run.events, "sync").is_empty() and int(verdicts.get("no_gain", 0)) >= 2, "verdicts %s, last %s" % [verdicts, last])
	check("nogain_sync_really_was_high", last.get("sync") != null and float(last.sync) >= 0.8, last)

## the panel, read headless from an actual crouch save (labels only; not visual acceptance).
func group_panel() -> void:
	var panel: Control = probe.call("attach_panel")
	var m := {"crouch_z": -14.0}
	var cal := await episode("panel_cal", FIX.flat_spec(), 520, {}, ctl_run, m)
	var rows: Array = cal.rows
	var press := find(rows, func(r: Dictionary) -> bool: return bool(r.d))
	var front := (rows[press + 2].p as Vector3).z - HW - 0.04
	var spec := FIX.flat_spec()
	(spec.pieces as Array).append(FIX.block("beam", Vector3(-6, (rows[press + 2].p as Vector3).y + DUCK + 4.0 * U, front - 0.3), Vector3(6, 2.4, front)))
	var run := await episode("panel_crouch_save", spec, 520, cal.tape)
	await process_frame
	await process_frame
	var snap: Dictionary = probe.style.call("snapshot")
	var callout: Label = panel.get("callout")
	var score: Label = panel.get("score_label")
	var best: Label = panel.get("best_label")
	check("panel_shows_score", score.text == PANEL.points_text(int(snap.score)), "%s vs %d" % [score.text, int(snap.score)])
	check("panel_callout_names_the_save", callout.text.begins_with("Crouch save") and of_kind(run.events, "crouch_save").size() == 1, callout.text)
	panel.call("set_best", 12340)
	await process_frame
	check("panel_best_line_from_root_field", best.text == "style best " + PANEL.points_text(12340), best.text)
	var size := Vector2(root.get_visible_rect().size)
	var rect := Rect2(panel.get("shade").position, panel.get("shade").size)
	check("panel_block_low_right_clear_of_centre", rect.position.x > size.x * 0.5 and rect.end.y <= size.y - 78.0 and not rect.has_point(size * 0.5), "%s in %s" % [rect, size])
	finding("panel_texts", {"score": score.text, "mult": (panel.get("mult_label") as Label).text, "best": best.text, "callout": callout.text})
	panel.queue_free()

static func _plain(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[str(key)] = _plain(value[key])
		return out
	if value is Array:
		return (value as Array).map(func(v: Variant) -> Variant: return _plain(v))
	if value is Vector3:
		return [snappedf(value.x, 0.0001), snappedf(value.y, 0.0001), snappedf(value.z, 0.0001)]
	if value is Vector2:
		return [value.x, value.y]
	if value is float and not is_finite(value):
		return str(value)
	return value

extends SceneTree
## p / checks for the carry air candidate. every episode has one labelled setup before tick 0
## (a pose and, for seeded fixtures only, one velocity write); after it only key and
## relative-mouse input events reach the motor, sampled before (priority -1000) and after
## (1000) the motor in the same physics step. the candidate and carry's two profiles run the
## same fixtures and tapes. gates are what AIR-CANDIDATE.md claims; findings are measurements
## for review. each claim is also run on a policy it should reject, and must reject it.
## godot --headless --fixed-fps 120 --path . --script res://tests/test_carry_air_candidate.gd --
##   [--out=DIR] [--only=fixed,look,mouse,cadence,farm,brake,correct,mirror,game,coherence,reject]

const MAIN := preload("res://scripts/spillway_main.gd")
const CARRY := preload("res://scripts/momentum_carry_player.gd")
const CANDIDATE := preload("res://scripts/momentum_carry_air_candidate.gd")
const CARRY_LAB := preload("res://scripts/momentum_carry_lab.gd")
const AIR_LAB := preload("res://scripts/momentum_carry_air_lab.gd")
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL}
const ACTIONS := {"w": "move_forward", "a": "move_left", "s": "move_back", "d": "move_right", "space": "jump", "ctrl": "crouch"}
const DT := 1.0 / 120.0
const PX := 0.0022
const POLICIES := ["candidate", "broad", "narrow"]
const GROUPS := ["fixed", "look", "mouse", "cadence", "farm", "brake", "correct", "mirror", "game", "coherence", "reject"]
const RATES := [0.3, 0.75, 1.5, 3.0, 6.0]

signal episode_done

class Probe:
	extends Node
	var suite: Object
	var early: bool

	func _physics_process(_delta: float) -> void:
		suite.call("early_tick" if early else "late_tick")

var out_dir := "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/carry-air-candidate/test"
var groups: Array = GROUPS.duplicate()
var world: Node3D
var game: Node
var player: CharacterBody3D
var plan: Dictionary = {}
var rows: Array[Dictionary] = []
var tick := 0
var length := 0
var running := false
var pre: Dictionary = {}
var results: Array[Dictionary] = []
var current: Dictionary = {}
var order_violations: Array[String] = []
var gate_failures: Array[String] = []
## claim name -> policy -> {ok, detail}; the reject group reads it.
var claims: Dictionary = {}
## --air=key:value,... overrides the candidate's tuning for a labelled variant run.
var air_override: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			groups = Array(arg.trim_prefix("--only=").split(","))
		elif arg.begins_with("--air="):
			for pair: String in arg.trim_prefix("--air=").split(","):
				air_override[pair.get_slice(":", 0)] = float(pair.get_slice(":", 1))
	_run.call_deferred()

func _run() -> void:
	MAIN.bind_inputs()
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("traces"))
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
	var gates := 0
	var findings := 0
	for result: Dictionary in results:
		for item: Dictionary in result.checks:
			gates += 1 if item.gate else 0
	if not order_violations.is_empty():
		gate_failures.append("ordering: %d violations, first %s" % [order_violations.size(), order_violations[0]])
	var summary := {
		"engine": Engine.get_version_info(), "physics_hz": Engine.physics_ticks_per_second,
		"physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine", "<unset>"),
		"accumulated_input": Input.use_accumulated_input, "groups": groups, "air_tuning": CANDIDATE.AIR, "air_override": air_override,
		"ordering_violations": order_violations.slice(0, 20), "gate_failures": gate_failures, "claims": claims, "results": results,
	}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_numeric(summary), "  "))
	file.close()
	for result: Dictionary in results:
		for item: Dictionary in result.checks:
			if not item.gate and not item.ok:
				findings += 1
				print("FINDING %s: %s (%s)" % [result.name, item.label, item.detail])
	for failure: String in gate_failures:
		print("FAIL " + failure)
	print("air candidate tests: %d result records, %d gates, %d gate failures, %d findings; physics=%s; %s" % [results.size(), gates, gate_failures.size(), findings, summary.physics_engine, out_dir])
	quit(1 if not gate_failures.is_empty() else 0)

# ---------------------------------------------------------------- episode runner

## cfg: build (Callable on the world), policy (candidate, broad, narrow), air (candidate
## tuning overrides), pose, seed (seeded fixtures only), tape, ticks, game (a game script).
func run(name: String, cfg: Dictionary) -> Array[Dictionary]:
	world = Node3D.new()
	world.name = "World"
	root.add_child(world)
	if cfg.has("build"):
		(cfg.build as Callable).call(world)
	var policy: String = cfg.get("policy", "candidate")
	var setup: Array[String] = []
	if cfg.has("game"):
		game = (cfg.game as Script).new()
		if policy != "candidate":
			game.set("air_profile", policy)
		game.set("set_window_title", false)
		world.add_child(game)
		player = game.get("player")
		setup.append("game _ready places the runner at its normal spawn")
	else:
		game = null
		player = CANDIDATE.new() if policy == "candidate" else CARRY.new()
		if policy != "candidate":
			player.set("air_profile", policy)
		player.name = "Runner"
		world.add_child(player)
		var pose: Transform3D = cfg.get("pose", Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)))
		player.call("reset_to", pose)
		setup.append("reset_to %s yaw %.4f" % [pose.origin, pose.basis.get_euler().y])
	if policy == "candidate":
		var air: Dictionary = player.get("air_tuning")
		for key: String in air_override:
			air[key] = air_override[key]
		for key: String in cfg.get("air", {}):
			air[key] = cfg.air[key]
	player.set("autohop", true)
	if cfg.has("seed"):
		player.velocity = cfg.seed
		setup.append("seeded velocity %s" % cfg.seed)
	plan = _expand(cfg.get("tape", []))
	rows = []
	tick = 0
	length = cfg.ticks
	var label := policy + ("+" + JSON.stringify(cfg.air) if cfg.has("air") else "")
	current = {"name": name, "kind": "seeded" if cfg.has("seed") else ("game" if cfg.has("game") else "earned"), "policy": label, "setup": setup, "metrics": {}, "checks": []}
	_apply_keys(0)
	running = true
	await episode_done
	player.set("input_enabled", false)
	if game != null:
		current.game_end = {"finished": game.get("finished"), "finish_kind": game.get("finish_kind"), "checkpoint": game.get("checkpoint_index"), "elapsed": game.get("elapsed"), "respawns": game.get("respawn_count")}
	_release_all()
	var trace := rows
	_write_trace(name, trace)
	world.queue_free()
	world = null
	await process_frame
	await physics_frame
	await process_frame
	return trace

func finish(metrics: Dictionary, summary: String = "") -> Dictionary:
	if not summary.is_empty():
		current = {"name": summary, "kind": "summary", "policy": "", "setup": [], "metrics": {}, "checks": []}
	current.metrics = metrics
	results.append(current)
	var line := "%s [%s %s]" % [current.name, current.kind, current.policy]
	for key: String in metrics:
		var value: Variant = metrics[key]
		if value is Dictionary or value is Array:
			continue
		line += "  %s=%s" % [key, ("%.3f" % value) if value is float else str(value)]
	print(line)
	return current

func check(result: Dictionary, label: String, ok: bool, detail: String = "", gate: bool = true) -> void:
	result.checks.append({"label": label, "ok": ok, "detail": detail, "gate": gate})
	if gate and not ok:
		gate_failures.append("%s: %s (%s)" % [result.name, label, detail])

## a named claim: gated for the candidate, recorded for the others so `reject` can show that
## the same check fails a policy it is meant to exclude.
func claim(result: Dictionary, name: String, policy: String, ok: bool, detail: String) -> void:
	if not claims.has(name):
		claims[name] = {}
	claims[name][policy] = {"ok": ok, "detail": detail}
	check(result, "claim " + name, ok, detail, policy == "candidate")

func early_tick() -> void:
	if not running:
		return
	pre = {"tick": tick, "pre": player.global_position, "pre_current": player.get("_current_position"), "motor_tick": player.get("motion_tick"), "yaw_before": player.get("yaw")}
	var dx := 0.0
	for event: Array in plan.get(tick, []):
		if event[0] == "mouse":
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(event[1], 0.0)
			motion.screen_relative = motion.relative
			Input.parse_input_event(motion)
			Input.flush_buffered_events()
			dx += float(event[1])
		elif event[1] and not Input.is_action_just_pressed(ACTIONS[event[0]]):
			order_violations.append("%s tick %d: %s not just pressed" % [current.name, tick, event[0]])
	var expected_yaw: float = pre.yaw_before - dx * float(player.get("mouse_sensitivity"))
	if absf(angle_difference(expected_yaw, player.get("yaw"))) > 1e-5:
		order_violations.append("%s tick %d: view %.6f, planned %.6f" % [current.name, tick, player.get("yaw"), expected_yaw])
	pre.yaw = player.get("yaw")

func late_tick() -> void:
	if not running:
		return
	var state: Dictionary = player.call("get_motion_state")
	state.erase("contacts")
	if tick + 1 < length:
		state.erase("ledger_totals")
	var row := pre.duplicate()
	row.post = player.global_position
	row.state = state
	if int(state.tick) != int(pre.motor_tick) + 1:
		order_violations.append("%s tick %d: motor ran %d times" % [current.name, tick, int(state.tick) - int(pre.motor_tick)])
	if state.previous_position != pre.pre_current or player.get("_current_position") != player.global_position:
		order_violations.append("%s tick %d: interpolation samples do not bracket the motor step" % [current.name, tick])
	if (state.ledger_residual as Vector3).length() > 1e-4:
		order_violations.append("%s tick %d: unbooked velocity write %s" % [current.name, tick, state.ledger_residual])
	rows.append(row)
	tick += 1
	if tick >= length:
		running = false
		episode_done.emit()
		return
	_apply_keys(tick)

func _apply_keys(at: int) -> void:
	for event: Array in plan.get(at, []):
		if event[0] != "mouse":
			var key := InputEventKey.new()
			key.physical_keycode = KEYS[event[0]]
			key.pressed = event[1]
			Input.parse_input_event(key)
			Input.flush_buffered_events()

func _release_all() -> void:
	for name: String in KEYS:
		var key := InputEventKey.new()
		key.physical_keycode = KEYS[name]
		key.pressed = false
		Input.parse_input_event(key)
	Input.flush_buffered_events()

## tape steps: [tick, key, pressed], [tick, "mouse", pixels], ["sweep", start, ticks, pixels,
## every, phase] (constant rate, one event every `every` ticks), ["smooth", start, ticks,
## pixels, every, phase], ["sine", start, ticks, amplitude_pixels, period_ticks]. +x turns right.
func _expand(tape: Array) -> Dictionary:
	var out := {}
	for step: Array in tape:
		if not step[0] is String:
			_add(out, step[0], [step[1], step[2]])
			continue
		var start: int = step[1]
		var count: int = step[2]
		var total: float = step[3]
		match str(step[0]):
			"sweep", "smooth":
				var every: int = step[4] if step.size() > 4 else 1
				var phase: int = step[5] if step.size() > 5 else 0
				var deliveries := count / every
				var previous := 0.0
				for k: int in deliveries:
					var x := float(k + 1) / deliveries
					var reach := total * (x if step[0] == "sweep" else x * x * (3.0 - 2.0 * x))
					_add(out, start + phase + k * every, ["mouse", reach - previous])
					previous = reach
			"sine":
				var period: float = step[4]
				var previous := 0.0
				for i: int in count:
					var reach := total * sin(TAU * (i + 1) / period)
					_add(out, start + i, ["mouse", reach - previous])
					previous = reach
	return out

func _add(out: Dictionary, at: int, event: Array) -> void:
	if not out.has(at):
		out[at] = []
	out[at].append(event)

func _write_trace(name: String, trace: Array[Dictionary]) -> void:
	var file := FileAccess.open(out_dir.path_join("traces/%s.jsonl" % name), FileAccess.WRITE)
	file.store_line(JSON.stringify(_numeric({"episode": name, "setup": current.setup, "kind": current.kind, "policy": current.policy, "plan": plan})))
	for row: Dictionary in trace:
		file.store_line(JSON.stringify(_numeric(row)))
	file.close()

static func _numeric(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[str(key)] = _numeric(value[key])
		return out
	if value is Array:
		var items := []
		for item: Variant in value:
			items.append(_numeric(item))
		return items
	if value is float and not is_finite(value):
		return str(value)
	return value

# ---------------------------------------------------------------- measurements, from actual travel

static func hs(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()

static func actual(row: Dictionary) -> Vector3:
	return row.state.actual_velocity

static func heading(row: Dictionary) -> float:
	var v := actual(row)
	return atan2(-v.x, -v.z)

static func speeds(trace: Array[Dictionary]) -> Array[float]:
	var out: Array[float] = []
	for row: Dictionary in trace:
		out.append(hs(actual(row)))
	return out

static func controls(trace: Array[Dictionary]) -> Array[float]:
	var out: Array[float] = []
	for row: Dictionary in trace:
		out.append(hs(row.state.post_contact_velocity))
	return out

static func peak(values: Array[float]) -> float:
	var best := -INF
	for value: float in values:
		best = maxf(best, value)
	return best

static func turned(trace: Array[Dictionary], from: int, to: int) -> float:
	return rad_to_deg(angle_difference(heading(trace[from]), heading(trace[to])))

## peak finite-difference turn rate of travel (deg/s), over 4-tick windows.
static func turn_rate(trace: Array[Dictionary], from: int, to: int) -> float:
	var best := 0.0
	for i: int in range(from + 4, to + 1):
		best = maxf(best, absf(turned(trace, i - 4, i)) / (4 * DT))
	return best

static func yaw_pose(position: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), position)

static func along(yaw: float, speed: float) -> Vector3:
	return Vector3(-sin(yaw) * speed, 0.0, -cos(yaw) * speed)

static func keys_tape(keys: String, at: int = 0) -> Array:
	var tape: Array = []
	for key: String in keys:
		tape.append([at, key, true])
	return tape

# ---------------------------------------------------------------- geometry

func box(w: Node3D, label: String, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	var shape := CollisionShape3D.new()
	var resource := BoxShape3D.new()
	resource.size = size
	shape.shape = resource
	body.add_child(shape)
	w.add_child(body)

func flat(w: Node3D) -> void:
	box(w, "floor", Vector3(0, -0.5, -100), Vector3(600, 1, 600))

func drop(w: Node3D) -> void:
	# open air from y 40: two seconds before the floor.
	box(w, "floor", Vector3(0, -0.5, -100), Vector3(400, 1, 400))

const HIGH := Vector3(0, 40, 0)

# ---------------------------------------------------------------- groups

func group_fixed() -> void:
	# fixed view, equal seeded 13 m/s, 1.5 s of open air. 0.6 s is about one flat hop.
	for policy: String in POLICIES:
		var lateral := {}
		for keys: String in ["none", "w", "a", "d", "wa", "s", "sa"]:
			var trace := await run("fixed_%s_%s" % [keys, policy], {"build": drop, "pose": yaw_pose(HIGH, 0.0), "policy": policy, "seed": along(0.0, 13.0), "ticks": 180, "tape": keys_tape(keys.replace("none", ""))})
			var v0 := hs(actual(trace[0]))
			var r := finish({"gain_0_6s": hs(actual(trace[71])) - v0, "gain_1_5s": hs(actual(trace[-1])) - v0, "turn_0_6s_deg": turned(trace, 0, 71), "turn_1_5s_deg": turned(trace, 0, 179), "lateral_0_6s_m": trace[71].post.x, "lateral_1_5s_m": trace[-1].post.x, "peak_turn_rate_deg_s": turn_rate(trace, 0, 179)})
			lateral[keys] = trace[71].post.x
			var gain: float = r.metrics.gain_1_5s
			match keys:
				"none":
					claim(r, "no keys keeps the ballistic line", policy, absf(gain) < 1e-4 and absf(trace[-1].post.x) < 1e-4, "gain %.5f, drift %.5f m" % [gain, trace[-1].post.x])
				"w":
					claim(r, "w along travel is speed-neutral", policy, absf(gain) < 1e-4, "gain %.5f" % gain)
				"a":
					claim(r, "a with a fixed view corrects at least 1 m in one hop", policy, trace[71].post.x < -1.0, "%.3f m in 0.6 s" % trace[71].post.x)
					claim(r, "a fixed view earns no speed", policy, absf(gain) < 1e-3, "gain %.4f" % gain)
				"s":
					claim(r, "s brakes at least 2.5 m/s in one hop and never reverses", policy, r.metrics.gain_0_6s < -2.5 and actual(trace[-1]).z < 0.0, "gain %.3f" % r.metrics.gain_0_6s)
				"sa":
					check(r, "s with a side key still brakes and still bends", gain < -2.5 and trace[-1].post.x < -1.0, "gain %.3f, lateral %.3f" % [gain, trace[-1].post.x], policy == "candidate")
		var r := finish({"a": lateral.a, "d": lateral.d}, "fixed_mirror_%s" % policy)
		check(r, "a and d are mirror images", absf(lateral.a + lateral.d) < 1e-4, "a %.5f, d %.5f" % [lateral.a, lateral.d], policy == "candidate")

func group_coherence() -> void:
	# p / hostile seeded orientations from the independent review; these are not route claims.
	for keys: String in ["a", "w", "wa"]:
		var wish_heading := PI * 0.5 if keys == "a" else (PI * 0.25 if keys == "wa" else 0.0)
		for speed: float in [3.0, 8.49, 8.51]:
			var tape := keys_tape(keys)
			for key: String in keys:
				tape.append([96, key, false])
			var seed := along(wish_heading + PI, speed)
			var trace := await run("opposed_%s_%.2f" % [keys, speed], {"pose": yaw_pose(Vector3(0, 180, 0), 0.0), "seed": seed, "ticks": 120, "tape": tape})
			var slowest := INF
			var forward := INF
			for row: Dictionary in trace:
				slowest = minf(slowest, hs(actual(row)))
				forward = minf(forward, actual(row).dot(seed.normalized()))
			var result := finish({"start_speed": speed, "slowest": slowest, "forward": forward})
			check(result, "opposing steering cannot brake or reverse below the run threshold", slowest >= speed - 0.005 and forward > 0.0, "slowest %.5f, along original %.5f" % [slowest, forward])
	for wait: int in [6, 360]:
		var release := wait + (3 if wait == 6 else 60)
		var tape: Array = [[0, "a", true], [0, "mouse", -0.3 / PX], [wait, "w", true], [release, "w", false]]
		var trace := await run("stale_turn_%d" % wait, {"pose": yaw_pose(Vector3(0, 180, 0), 0.0), "seed": along(2.0, 13.0), "ticks": release + 100, "tape": tape})
		var result := finish({"bank_on_w": trace[wait].state.carve_bank, "bank_after_w": trace[release].state.carve_bank, "gain": trace[-1].state.carve_total})
		check(result, "changing forward intent starts a fresh carve", absf(result.metrics.bank_on_w) < 0.00001 and absf(result.metrics.bank_after_w) < 0.00001, str(result.metrics))
		check(result, "an earlier view turn cannot pay a later steering phase", result.metrics.gain < 0.00001, str(result.metrics.gain))
	var trace := await run("unspent_turn_expires", {"pose": yaw_pose(Vector3(0, 180, 0), 0.0), "seed": along(2.0, 13.0), "ticks": 60, "tape": [[0, "a", true], [0, "mouse", -0.3 / PX]]})
	var result := finish({"bank_after_half_second": trace[-1].state.carve_bank})
	check(result, "unspent positive view credit expires without a key change", result.metrics.bank_after_half_second <= 0.00001, str(result.metrics.bank_after_half_second))

func group_look() -> void:
	# no keys while the view turns 90 degrees left and 120 back right: the flight ignores it.
	for policy: String in POLICIES:
		var tape: Array = [["smooth", 10, 36, deg_to_rad(90.0) / PX], ["smooth", 60, 48, -deg_to_rad(120.0) / PX]]
		var trace := await run("look_free_%s" % policy, {"build": drop, "pose": yaw_pose(HIGH, 0.0), "policy": policy, "seed": along(0.0, 12.0), "ticks": 150, "tape": tape})
		var r := finish({"gain": hs(actual(trace[-1])) - hs(actual(trace[0])), "turn_deg": turned(trace, 0, 149), "drift_m": trace[-1].post.x})
		claim(r, "looking around with no keys is free", policy, absf(r.metrics.gain) < 1e-4 and absf(r.metrics.drift_m) < 1e-4, "gain %.5f, drift %.5f" % [r.metrics.gain, r.metrics.drift_m])
	# a short glance with keys released: w held, released for a 50 degree glance and back, re-held.
	for policy: String in POLICIES:
		var tape: Array = [[0, "w", true], [20, "w", false], ["smooth", 24, 20, deg_to_rad(50.0) / PX], ["smooth", 48, 20, -deg_to_rad(50.0) / PX], [72, "w", true]]
		var trace := await run("glance_released_%s" % policy, {"build": drop, "pose": yaw_pose(HIGH, 0.0), "policy": policy, "seed": along(0.0, 12.0), "ticks": 120, "tape": tape})
		var r := finish({"turn_during_glance_deg": turned(trace, 21, 71), "drift_after_m": trace[-1].post.x, "gain": hs(actual(trace[-1])) - hs(actual(trace[0]))})
		check(r, "a released glance leaves the line untouched", absf(r.metrics.turn_during_glance_deg) < 1e-3 and absf(r.metrics.drift_after_m) < 1e-3, "turn %.4f, drift %.4f" % [r.metrics.turn_during_glance_deg, r.metrics.drift_after_m], policy == "candidate")

func group_mouse() -> void:
	# keys with a constant view turn for 1.2 s, from an equal seeded 10 m/s.
	for policy: String in POLICIES:
		for keys: String in ["w", "a", "wa"]:
			var losses := 0.0
			var best := -INF
			var metrics := {}
			for rate: float in RATES:
				var tape: Array = keys_tape(keys)
				tape.append(["sweep", 0, 144, -rate * 1.2 / PX])
				var trace := await run("mouse_%s_%.2f_%s" % [keys, rate, policy], {"build": drop, "pose": yaw_pose(HIGH, 0.0), "policy": policy, "seed": along(0.0, 10.0), "ticks": 150, "tape": tape})
				var gain := hs(actual(trace[-1])) - hs(actual(trace[0]))
				var travel := turned(trace, 0, 149)
				var r := finish({"view_rate": rate, "gain": gain, "travel_turn_deg": travel, "view_turn_deg": rad_to_deg(rate * 1.2), "turn_0_6s_deg": turned(trace, 0, 71), "peak_turn_rate_deg_s": turn_rate(trace, 0, 149), "lateral_m": trace[-1].post.x})
				losses = minf(losses, gain)
				best = maxf(best, gain)
				metrics["%.2f" % rate] = {"gain": gain, "travel_turn_deg": travel}
				if keys == "w":
					claim(r, "w with the mouse mints no speed", policy, absf(gain) < 1e-4, "gain %.5f" % gain)
			var r := finish({"worst_gain": losses, "best_gain": best, "by_rate": metrics}, "mouse_%s_%s" % [keys, policy])
			if keys != "w":
				claim(r, "%s turned with the mouse never loses speed at any view rate" % keys, policy, losses > -1e-3, "worst %.3f" % losses)
			if keys == "a":
				claim(r, "a carve turned with the mouse earns at least 0.2 m/s", policy, best > 0.2, "best %.3f" % best)
	# how far w and a mouse turn bend travel in one hop: the placement authority.
	for policy: String in POLICIES:
		for degrees: int in [20, 45, 60, 90, 135]:
			var trace := await run("offset_w_%03d_%s" % [degrees, policy], {"build": drop, "pose": yaw_pose(HIGH, 0.0), "policy": policy, "seed": along(0.0, 12.0), "ticks": 73, "tape": [[0, "mouse", -deg_to_rad(degrees) / PX], [1, "w", true]]})
			var r := finish({"view_offset_deg": degrees, "travel_turn_0_6s_deg": turned(trace, 1, 72), "lateral_m": trace[-1].post.x, "gain": hs(actual(trace[-1])) - hs(actual(trace[1]))})
			if degrees == 45:
				claim(r, "w with the view 45 degrees off turns travel at least 30 degrees in one hop", policy, r.metrics.travel_turn_0_6s_deg > 30.0, "%.2f deg" % r.metrics.travel_turn_0_6s_deg)

func group_cadence() -> void:
	# the same left carve, 1 rad over 0.8 s, delivered at 120, 60 and 30 events per second in
	# every event phase, plus a smoothstep stroke at each rate. physics stays 120 hz.
	for policy: String in POLICIES:
		var gains := {}
		var headings := {}
		for shape: String in ["sweep", "smooth"]:
			for every: int in [1, 2, 4]:
				for phase: int in range(every):
					var name := "cadence_%s_%s_%d_%d" % [policy, shape, 120 / every, phase]
					var trace := await run(name, {"build": drop, "pose": yaw_pose(HIGH, 0.0), "policy": policy, "seed": along(0.0, 10.0), "ticks": 130, "tape": [[0, "a", true], [shape, 4, 96, -1.0 / PX, every, phase]]})
					gains["%s_%d_%d" % [shape, 120 / every, phase]] = hs(actual(trace[-1])) - hs(actual(trace[0]))
					headings["%s_%d_%d" % [shape, 120 / every, phase]] = turned(trace, 0, 129)
		var spread := 0.0
		var heading_spread := 0.0
		for key: String in gains:
			var reference: String = "sweep_120_0" if key.begins_with("sweep") else "smooth_120_0"
			spread = maxf(spread, absf(gains[key] - gains[reference]))
			heading_spread = maxf(heading_spread, absf(headings[key] - headings[reference]))
		var r := finish({"gain_120": gains.sweep_120_0, "gain_60": gains.sweep_60_0, "gain_30": gains.sweep_30_0, "smooth_120": gains.smooth_120_0, "smooth_30": gains.smooth_30_0, "max_spread": spread, "heading_spread_deg": heading_spread, "all": gains}, "cadence_%s" % policy)
		var base: float = gains.sweep_120_0
		claim(r, "mouse delivery rate changes the carve reward by under 5%", policy, base > 0.05 and spread < 0.05 * base + 0.005, "spread %.4f of %.4f" % [spread, base])
		check(r, "mouse delivery rate changes the flight heading by under 1 degree", heading_spread < 1.0, "%.3f deg" % heading_spread, policy == "candidate")

func group_farm() -> void:
	# fixed-view w+a with held hops for 20 s, from a seeded 10 m/s.
	for policy: String in POLICIES:
		var trace := await run("farm_wa_hops_%s" % policy, {"build": flat, "policy": policy, "seed": along(0.0, 10.0), "ticks": 2400, "tape": [[0, "w", true], [0, "a", true], [0, "space", true]]})
		var s := controls(trace)
		var r := finish({"peak": peak(s), "speed_1s": s[119], "speed_20s": s[-1]})
		claim(r, "a fixed-view w+a hop chain never grows", policy, peak(s) < 10.0 + 0.05 and s[-1] <= s[119] + 1e-3, "peak %.3f, 1 s %.3f, 20 s %.3f" % [peak(s), s[119], s[-1]])
	# a fixed-view a/d weave with held hops: the keys swap every 0.4 s, the view never moves.
	for variant: Array in [["candidate", {}], ["candidate", {"carve_unsynced": true}], ["broad", {}], ["narrow", {}]]:
		var tape: Array = [[0, "a", true], [0, "space", true]]
		var side := "a"
		for at: int in range(48, 2400, 48):
			tape.append([at, side, false])
			side = "d" if side == "a" else "a"
			tape.append([at, side, true])
		var tag: String = variant[0] + ("_unsynced" if not (variant[1] as Dictionary).is_empty() else "")
		var cfg := {"build": flat, "policy": variant[0], "seed": along(0.0, 10.0), "ticks": 2400, "tape": tape}
		if not (variant[1] as Dictionary).is_empty():
			cfg.air = variant[1]
		var trace := await run("farm_weave_%s" % tag, cfg)
		var s := controls(trace)
		var r := finish({"peak": peak(s), "speed_20s": s[-1]})
		claim(r, "a fixed-view a/d weave never farms speed", tag, peak(s) < 10.0 + 0.05, "peak %.3f, 20 s %.3f" % [peak(s), s[-1]])
	# a side key held while the mouse wiggles left and right with no net turn, held hops.
	for policy: String in POLICIES:
		var trace := await run("farm_wiggle_%s" % policy, {"build": flat, "policy": policy, "seed": along(0.0, 10.0), "ticks": 1200, "tape": [[0, "d", true], [0, "space", true], ["sine", 0, 1200, 0.3 / PX, 60]]})
		var s := controls(trace)
		var r := finish({"peak": peak(s), "speed_10s": s[-1]})
		check(r, "a net-zero mouse wiggle with a side key earns at most one bank (0.6 m/s)", peak(s) < 10.0 + 0.6, "peak %.3f" % peak(s), policy == "candidate")
	# continuous carving in a circle, d with a 1.2 rad/s right turn, held hops for 20 s.
	for policy: String in POLICIES:
		var trace := await run("carve_circle_%s" % policy, {"build": flat, "policy": policy, "seed": along(0.0, 10.0), "ticks": 2400, "tape": [[0, "d", true], [0, "space", true], ["sweep", 0, 2400, 1.2 * 20.0 / PX]]})
		var s := controls(trace)
		var r := finish({"peak": peak(s), "speed_5s": s[599], "speed_20s": s[-1], "carve_total": trace[-1].state.get("carve_total", 0.0), "safety": trace[-1].state.safety_interventions})
		if policy == "candidate":
			var ceiling: float = CANDIDATE.AIR.carve_zero
			check(r, "an endless carve approaches the carve ceiling and never passes it", peak(s) <= ceiling + 0.01 and s[-1] > 13.0, "peak %.3f, 20 s %.3f" % [peak(s), s[-1]])

func group_brake() -> void:
	# s through a flight and into the landing, from a seeded 12 m/s hop on flat.
	for policy: String in POLICIES:
		var trace := await run("brake_hop_%s" % policy, {"build": flat, "policy": policy, "seed": along(0.0, 12.0), "ticks": 180, "tape": [[0, "space", true], [6, "space", false], [10, "s", true]]})
		var s := speeds(trace)
		var land := -1
		for i: int in range(10, trace.size()):
			if bool(trace[i].state.grounded):
				land = i
				break
		var r := finish({"speed_at_landing": s[land] if land >= 0 else -1.0, "landing_tick": land, "speed_end": s[-1], "travel_m": -trace[-1].post.z})
		check(r, "s in the air brakes the hop and lands still moving forward", land > 0 and s[land] < 9.5 and actual(trace[land]).z < 0.0, "landing %.3f m/s at tick %d" % [s[land] if land >= 0 else -1.0, land], policy == "candidate")

func group_correct() -> void:
	# overshoot and correction: w, view 60 degrees left in 0.25 s, then 40 back right in 0.25 s.
	for policy: String in POLICIES:
		var tape: Array = [[0, "w", true], ["smooth", 0, 30, -deg_to_rad(60.0) / PX], ["smooth", 36, 30, deg_to_rad(40.0) / PX]]
		var trace := await run("overshoot_w_%s" % policy, {"build": drop, "pose": yaw_pose(HIGH, 0.0), "policy": policy, "seed": along(0.0, 11.0), "ticks": 150, "tape": tape})
		var final_view := rad_to_deg(float(trace[-1].state.yaw))
		var r := finish({"final_view_deg": final_view, "travel_end_deg": rad_to_deg(heading(trace[-1])), "travel_0_6s_deg": rad_to_deg(heading(trace[71])), "peak_travel_deg": rad_to_deg(heading(trace[40])), "gain": hs(actual(trace[-1])) - hs(actual(trace[0])), "lateral_m": trace[-1].post.x})
		check(r, "an overshoot corrected with the mouse settles on the view by 1.25 s", absf(r.metrics.travel_end_deg - final_view) < 1.0 and absf(r.metrics.gain) < 1e-3, "travel %.2f, view %.2f" % [r.metrics.travel_end_deg, final_view], policy == "candidate")
	# a late a/d swap: a held through most of a flight, d pressed while a is still held (overlap).
	for policy: String in POLICIES:
		var tape: Array = [[0, "w", true], [0, "a", true], [40, "d", true], [52, "a", false], [96, "d", false]]
		var trace := await run("overlap_swap_%s" % policy, {"build": drop, "pose": yaw_pose(HIGH, 0.0), "policy": policy, "seed": along(0.0, 11.0), "ticks": 140, "tape": tape})
		# while a and d overlap only w is left, so the flight bends back toward the view.
		var limit := rad_to_deg(float(CANDIDATE.AIR.bend) / 11.0) + 1.0
		var r := finish({"lateral_40_m": trace[40].post.x, "lateral_end_m": trace[-1].post.x, "heading_40_deg": rad_to_deg(heading(trace[40])), "heading_end_deg": rad_to_deg(heading(trace[-1])), "turn_during_overlap_deg": turned(trace, 40, 51), "peak_turn_rate_deg_s": turn_rate(trace, 0, 139), "gain": hs(actual(trace[-1])) - hs(actual(trace[0]))})
		check(r, "a late d over a held a corrects continuously, at no speed cost", r.metrics.peak_turn_rate_deg_s <= limit and r.metrics.heading_end_deg < r.metrics.heading_40_deg - 10.0 and absf(r.metrics.gain) < 1e-3, "peak %.1f deg/s of %.1f, heading %.2f -> %.2f" % [r.metrics.peak_turn_rate_deg_s, limit, r.metrics.heading_40_deg, r.metrics.heading_end_deg], policy == "candidate")

func group_mirror() -> void:
	# mirrored inputs give mirrored travel, measured from displacement.
	var cases := {
		"strafe": [[0, "a", true], ["sweep", 0, 120, -1.0 / PX]],
		"w_turn": [[0, "w", true], ["smooth", 0, 60, -0.8 / PX]],
		"wa_turn": [[0, "w", true], [0, "a", true], ["sweep", 0, 120, -1.2 / PX]],
	}
	for name: String in cases:
		var mirrored: Array = []
		for step: Array in cases[name]:
			var copy := step.duplicate()
			if copy[0] is String:
				copy[3] = -float(copy[3])
			elif copy[1] == "a":
				copy[1] = "d"
			mirrored.append(copy)
		var left := await run("mirror_%s_left" % name, {"build": drop, "pose": yaw_pose(HIGH, 0.0), "seed": along(0.0, 11.0), "ticks": 130, "tape": cases[name]})
		var right := await run("mirror_%s_right" % name, {"build": drop, "pose": yaw_pose(HIGH, 0.0), "seed": along(0.0, 11.0), "ticks": 130, "tape": mirrored})
		var x: float = left[-1].post.x + right[-1].post.x
		var z: float = left[-1].post.z - right[-1].post.z
		var r := finish({"left_x": left[-1].post.x, "right_x": right[-1].post.x, "speed_left": hs(actual(left[-1])), "speed_right": hs(actual(right[-1]))}, "mirror_%s" % name)
		check(r, "mirrored inputs give mirrored travel", absf(x) < 1e-3 and absf(z) < 1e-3 and absf(r.metrics.speed_left - r.metrics.speed_right) < 1e-4, "x sum %.5f, z diff %.5f" % [x, z])

func group_game() -> void:
	# the calibration line, w and three timed hops in the actual game factories: no side key,
	# so the candidate must leave carry's ground, hop and landing policy exactly as it was.
	var lines := {}
	for policy: String in ["candidate", "broad"]:
		var trace := await run("game_line_%s" % policy, {"game": AIR_LAB.Game if policy == "candidate" else CARRY_LAB.CalibrationGame, "policy": policy, "ticks": 1020, "tape": CARRY_LAB.DEMOS.line.duplicate()})
		lines[policy] = trace
		var end: Dictionary = current.game_end
		var hud_matches := true
		for row: Dictionary in trace:
			hud_matches = hud_matches and absf(float(row.state.actual_speed) - hs(actual(row))) < 1e-5
		var r := finish({"finished": end.finished, "elapsed": end.elapsed, "respawns": end.respawns, "peak": peak(speeds(trace)), "safety": trace[-1].state.safety_interventions, "air_policy": trace[-1].state.get("air_policy", trace[-1].state.air_profile)})
		check(r, "w and timed hops finish the calibration block", bool(end.finished) and int(end.respawns) == 0)
		check(r, "speed shown is the actual travel", hud_matches)
		if policy == "candidate":
			check(r, "the motion report names the candidate policy", trace[-1].state.air_policy == "carry-air-candidate" and trace[-1].state.air_profile == "carry-air-candidate")
	var gap := 0.0
	for i: int in lines.candidate.size():
		gap = maxf(gap, (lines.candidate[i].post as Vector3).distance_to(lines.broad[i].post))
	var r := finish({"max_position_difference_m": gap}, "game_line_attribution")
	check(r, "without side keys or a view offset the candidate line equals carry broad", gap < 1e-6, "%.8f m" % gap)
	# a deliberately poor landing: after a late hop, an a strafe with a left mouse stroke
	# overshoots the lower deck onto the catch floor. the same open-loop tape then stops, turns
	# round, walks the return ramp onto the landing deck, turns down the course and holds space
	# to the finish. it was authored against the candidate, so for broad it is a matched
	# baseline, not a fair test of broad's own recovery.
	for policy: String in ["candidate", "broad"]:
		var tape: Array = [[20, "w", true], [452, "space", true], [460, "space", false], [470, "w", false], [520, "a", true], [600, "a", false], [600, "w", true], [700, "w", false], [880, "w", true], [1600, "space", true],
			["smooth", 520, 80, -250.0], ["smooth", 780, 60, -1341.0], ["smooth", 1125, 30, 164.0], ["smooth", 1380, 40, -714.0], ["smooth", 1500, 40, -714.0]]
		var trace := await run("game_poor_landing_%s" % policy, {"game": AIR_LAB.Game if policy == "candidate" else CARRY_LAB.CalibrationGame, "policy": policy, "ticks": 2230, "tape": tape})
		var fell := first_index(trace, func(row: Dictionary) -> bool: return (row.post as Vector3).y < 1.0)
		var back := -1
		for i: int in range(maxi(fell, 0), trace.size()):
			var p: Vector3 = trace[i].post
			if fell >= 0 and p.y > 5.9 and p.z > -36.0 and p.z < -24.0 and absf(p.x) < 6.0 and bool(trace[i].state.grounded):
				back = i
				break
		var end: Dictionary = current.game_end
		var r2 := finish({"fell_tick": fell, "back_on_landing_deck_tick": back, "respawns": end.respawns, "finished": end.finished, "elapsed": end.elapsed, "end": trace[-1].post})
		check(r2, "a missed landing walks back by the ramp and still finishes, with no respawn", fell >= 0 and back > fell and int(end.respawns) == 0 and bool(end.finished), "fell %d, back %d, finished %s" % [fell, back, end.finished], policy == "candidate")
	# labels in the playable factory.
	var lab = AIR_LAB.Game.new()
	lab.set("set_window_title", false)
	root.add_child(lab)
	var pause_text := ""
	for node: Node in (lab.hud.get("pause_panel") as Node).find_children("*", "Label", true, false):
		pause_text += (node as Label).text + "\n"
	var r3 := finish({"identity": lab.call("identity_line"), "player_policy": lab.player.get("air_policy"), "player_script": (lab.player.get_script() as Script).resource_path}, "game_labels")
	check(r3, "window identity, pause panel and runner name the candidate", "AIR CANDIDATE" in str(lab.call("identity_line")) and "carry-air-candidate" in pause_text and not "broad air" in pause_text and lab.player.get("air_policy") == "carry-air-candidate", pause_text.replace("\n", " | "))
	lab.queue_free()
	await process_frame

static func first_index(trace: Array[Dictionary], test: Callable) -> int:
	for i: int in trace.size():
		if test.call(trace[i]):
			return i
	return -1

func group_reject() -> void:
	# every claim the candidate passes must be able to fail: at least one control fails it.
	# claims no control fails are listed as not discriminating, which is a finding.
	var expected := {
		"a with a fixed view corrects at least 1 m in one hop": "narrow",
		"a turned with the mouse never loses speed at any view rate": "broad",
		"mouse delivery rate changes the carve reward by under 5%": "narrow",
		"a fixed-view a/d weave never farms speed": "candidate_unsynced",
	}
	var r := finish({"claims": claims.keys()}, "reject_bad_policies")
	for name: String in expected:
		var row: Dictionary = claims.get(name, {})
		var bad: Dictionary = row.get(expected[name], {"ok": true, "detail": "not run"})
		check(r, "%s rejects %s" % [name, expected[name]], not bool(bad.ok), str(bad.detail))
	for name: String in claims:
		var fails: Array = []
		for policy: String in claims[name]:
			if policy != "candidate" and not bool(claims[name][policy].ok):
				fails.append(policy)
		check(r, "%s: a control fails it" % name, not fails.is_empty(), "rejects %s" % ", ".join(fails) if not fails.is_empty() else "no control fails", false)

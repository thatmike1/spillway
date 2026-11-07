extends SceneTree
## p / carry motor checks. every episode has one labelled setup before tick 0 (a pose and,
## for seeded fixtures only, one velocity write); after it only key and relative-mouse input
## events reach the motor. the body is sampled before (priority -1000) and after (1000) the
## motor in the same physics step. gates are behavior the policy promises; findings are
## measurements reported for review. traces and summary.json go outside git.
## godot --headless --fixed-fps 120 --path . --script res://tests/test_momentum_carry.gd --
##   [--out=DIR] [--only=ground,hop,air,window,contact,slope,cap,cadence,duck,flicker,backend,integration]

const MAIN := preload("res://scripts/spillway_main.gd")
const CARRY := preload("res://scripts/momentum_carry_player.gd")
const LAB := preload("res://scripts/momentum_carry_lab.gd")
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL}
const ACTIONS := {"w": "move_forward", "a": "move_left", "s": "move_back", "d": "move_right", "space": "jump", "ctrl": "crouch"}
const DT := 1.0 / 120.0
const PX := 0.0022
const PROFILES := ["broad", "narrow"]
const GROUPS := ["ground", "hop", "air", "window", "contact", "slope", "cap", "cadence", "duck", "flicker", "backend", "integration"]

signal episode_done

class Probe:
	extends Node
	var suite: Object
	var early: bool

	func _physics_process(_delta: float) -> void:
		suite.call("early_tick" if early else "late_tick")

var out_dir := "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/carry/test"
var groups: Array = GROUPS.duplicate()
var world: Node3D
var game: Node
var player: CharacterBody3D
var plan: Dictionary = {}
var rows: Array[Dictionary] = []
var tick := 0
var length := 0
var running := false
var record_contacts := false
var pre: Dictionary = {}
var results: Array[Dictionary] = []
var current: Dictionary = {}
var order_violations: Array[String] = []
var gate_failures: Array[String] = []

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
			if item.gate:
				gates += 1
	if not order_violations.is_empty():
		gate_failures.append("ordering: %d violations, first %s" % [order_violations.size(), order_violations[0]])
	var summary := {
		"engine": Engine.get_version_info(), "physics_hz": Engine.physics_ticks_per_second,
		"physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine", "<unset>"),
		"physics_server": PhysicsServer3D.get_class(), "project": ProjectSettings.globalize_path("res://"),
		"accumulated_input": Input.use_accumulated_input, "groups": groups,
		"ordering_violations": order_violations.slice(0, 20), "gate_failures": gate_failures, "results": results,
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
	print("carry tests: %d episodes, %d gates, %d gate failures, %d findings; physics=%s; %s" % [results.size(), gates, gate_failures.size(), findings, summary.physics_engine, out_dir])
	quit(1 if not gate_failures.is_empty() else 0)

# ---------------------------------------------------------------- episode runner

## cfg: build (Callable on the world), profile, pose, seed (seeded fixtures only), tape,
## ticks, tuning, autohop, game (a game script instead of a bare runner), contacts.
func run(name: String, cfg: Dictionary) -> Array[Dictionary]:
	world = Node3D.new()
	world.name = "World"
	root.add_child(world)
	if cfg.has("build"):
		(cfg.build as Callable).call(world)
	var setup: Array[String] = []
	if cfg.has("game"):
		game = (cfg.game as Script).new()
		game.set("air_profile", cfg.get("profile", "broad"))
		game.set("set_window_title", false)
		world.add_child(game)
		player = game.get("player")
		setup.append("game _ready places the runner at its normal spawn")
	else:
		game = null
		player = CARRY.new()
		player.set("air_profile", cfg.get("profile", "broad"))
		player.name = "Runner"
		world.add_child(player)
		var pose: Transform3D = cfg.get("pose", Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)))
		player.call("reset_to", pose)
		setup.append("reset_to %s yaw %.4f" % [pose.origin, pose.basis.get_euler().y])
	var tuning: Dictionary = player.get("tuning")
	for key: String in cfg.get("tuning", {}):
		tuning[key] = cfg.tuning[key]
	player.set("autohop", cfg.get("autohop", true))
	if cfg.has("seed"):
		player.velocity = cfg.seed
		setup.append("seeded velocity %s" % cfg.seed)
	record_contacts = cfg.get("contacts", false)
	plan = _expand(cfg.get("tape", []))
	rows = []
	tick = 0
	length = cfg.ticks
	current = {"name": name, "kind": "seeded" if cfg.has("seed") else ("game" if cfg.has("game") else "earned"), "profile": cfg.get("profile", "broad"), "setup": setup, "tuning": cfg.get("tuning", {}), "metrics": {}, "checks": []}
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
		# a comparison across episodes gets its own record rather than the last episode's.
		current = {"name": summary, "kind": "summary", "profile": "", "setup": [], "tuning": {}, "metrics": {}, "checks": []}
	current.metrics = metrics
	results.append(current)
	var line := "%s [%s %s]" % [current.name, current.kind, current.profile]
	for key: String in metrics:
		var value: Variant = metrics[key]
		line += "  %s=%s" % [key, ("%.3f" % value) if value is float else str(value)]
	print(line)
	return current

func check(result: Dictionary, label: String, ok: bool, detail: String = "", gate: bool = true) -> void:
	result.checks.append({"label": label, "ok": ok, "detail": detail, "gate": gate})
	if gate and not ok:
		gate_failures.append("%s: %s (%s)" % [result.name, label, detail])

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
		elif event[1]:
			# a press planned for this tick must be visible to the motor as just pressed.
			if not Input.is_action_just_pressed(ACTIONS[event[0]]):
				order_violations.append("%s tick %d: %s not just pressed" % [current.name, tick, event[0]])
	var expected_yaw: float = pre.yaw_before - dx * float(player.get("mouse_sensitivity"))
	if absf(angle_difference(expected_yaw, player.get("yaw"))) > 1e-5:
		order_violations.append("%s tick %d: view %.6f, planned %.6f" % [current.name, tick, player.get("yaw"), expected_yaw])
	pre.yaw = player.get("yaw")

func late_tick() -> void:
	if not running:
		return
	var state: Dictionary = player.call("get_motion_state")
	if not record_contacts:
		state.erase("contacts")
	if tick + 1 < length:
		state.erase("ledger_totals")
	var row := pre.duplicate()
	row.post = player.global_position
	row.camera = player.get("camera").global_position
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
## pixels], ["sine", start, ticks, amplitude_pixels, period_ticks]. +x pixels turn right.
func _expand(tape: Array) -> Dictionary:
	var out := {}
	for step: Array in tape:
		if step[0] is String:
			var start: int = step[1]
			var count: int = step[2]
			var total: float = step[3]
			match str(step[0]):
				"sweep":
					var every: int = step[4] if step.size() > 4 else 1
					var phase: int = step[5] if step.size() > 5 else 0
					var deliveries := count / every
					for k: int in deliveries:
						_add(out, start + phase + k * every, ["mouse", total / deliveries])
				"smooth":
					var previous := 0.0
					for i: int in count:
						var x := float(i + 1) / count
						var reach := total * x * x * (3.0 - 2.0 * x)
						_add(out, start + i, ["mouse", reach - previous])
						previous = reach
				"sine":
					var period: float = step[4]
					var previous := 0.0
					for i: int in count:
						var reach := total * sin(TAU * (i + 1) / period)
						_add(out, start + i, ["mouse", reach - previous])
						previous = reach
		else:
			_add(out, step[0], [step[1], step[2]])
	return out

func _add(out: Dictionary, at: int, event: Array) -> void:
	if not out.has(at):
		out[at] = []
	out[at].append(event)

func _write_trace(name: String, trace: Array[Dictionary]) -> void:
	var file := FileAccess.open(out_dir.path_join("traces/%s.jsonl" % name), FileAccess.WRITE)
	file.store_line(JSON.stringify(_numeric({"episode": name, "setup": current.setup, "kind": current.kind, "profile": current.profile, "plan": plan})))
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

# ---------------------------------------------------------------- measurements

static func hs(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()

static func actual(row: Dictionary) -> Vector3:
	return row.state.actual_velocity

static func heading(row: Dictionary) -> float:
	var v := actual(row)
	return atan2(-v.x, -v.z)

static func speeds(trace: Array[Dictionary], from: int = 0, to: int = -1) -> Array[float]:
	var out: Array[float] = []
	for row: Dictionary in trace.slice(from, to if to >= 0 else trace.size()):
		out.append(hs(actual(row)))
	return out

static func controls(trace: Array[Dictionary], from: int = 0) -> Array[float]:
	# the motor's own horizontal speed after contact, as opposed to measured travel.
	var out: Array[float] = []
	for row: Dictionary in trace.slice(from):
		out.append(hs(row.state.post_contact_velocity))
	return out

static func peak(values: Array[float]) -> float:
	var best := -INF
	for value: float in values:
		best = maxf(best, value)
	return best

static func least(values: Array[float]) -> float:
	var best := INF
	for value: float in values:
		best = minf(best, value)
	return best

static func total(trace: Array[Dictionary], cause: String, field: String = "horizontal") -> float:
	# one cause's booked change in horizontal speed (or vertical velocity) over the episode.
	var totals: Dictionary = trace[-1].state.get("ledger_totals", {})
	return float((totals.get(cause, {}) as Dictionary).get(field, 0.0))

static func first(trace: Array[Dictionary], test: Callable) -> int:
	for i: int in trace.size():
		if test.call(trace[i]):
			return i
	return -1

static func yaw_pose(position: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), position)

static func along(yaw: float, speed: float, vy: float = 0.0) -> Vector3:
	return Vector3(-sin(yaw) * speed, vy, -cos(yaw) * speed)

# ---------------------------------------------------------------- geometry

func box(w: Node3D, label: String, center: Vector3, size: Vector3, tilt: float = 0.0, body: StaticBody3D = null) -> StaticBody3D:
	var owner_body := body
	if owner_body == null:
		owner_body = StaticBody3D.new()
		owner_body.name = label
		w.add_child(owner_body)
	var shape := CollisionShape3D.new()
	shape.name = label + "_shape"
	var resource := BoxShape3D.new()
	resource.size = size
	shape.shape = resource
	var pose := Transform3D(Basis(Vector3.RIGHT, tilt), center)
	if body == null:
		owner_body.transform = pose
	else:
		shape.transform = pose
	owner_body.add_child(shape)
	return owner_body

func ramp(w: Node3D, label: String, a: Vector3, b: Vector3, width: float = 40.0) -> void:
	# a runs toward b along -z; the box's top face passes through both.
	var run := b - a
	var tilt := atan2(run.y, -run.z)
	var normal := Basis(Vector3.RIGHT, tilt) * Vector3.UP
	box(w, label, (a + b) * 0.5 - normal * 0.5, Vector3(width, 1, run.length()), tilt)

func flat(w: Node3D) -> void:
	box(w, "floor", Vector3(0, -0.5, -100), Vector3(400, 1, 400))

func drop(w: Node3D) -> void:
	# a long fall over open floor gives two seconds of uninterrupted air from y 40.
	box(w, "floor", Vector3(0, -0.5, -100), Vector3(400, 1, 400))
	box(w, "tall_wall", Vector3(3.0, 30, -100), Vector3(1, 60, 300))

func wall_world(w: Node3D) -> void:
	flat(w)
	box(w, "side_wall", Vector3(3.0, 1.5, -60), Vector3(1, 3, 140))

func front_wall(w: Node3D) -> void:
	flat(w)
	box(w, "front_wall", Vector3(0, 1.5, -3.5), Vector3(10, 3, 1))

func descent(w: Node3D) -> void:
	# a 16 degree, 8 m descent from a start deck onto a wide run-out.
	box(w, "top", Vector3(0, 7.5, 0), Vector3(40, 1, 10))
	ramp(w, "descent", Vector3(0, 8, -5), Vector3(0, 0, -5 - 8.0 / tan(deg_to_rad(16.0))))
	box(w, "runout", Vector3(0, -0.5, -150), Vector3(400, 1, 236))

func loop_world(w: Node3D) -> void:
	# flat, 16 degrees down 6 m, flat, 16 degrees up 6 m, flat.
	var run := 6.0 / tan(deg_to_rad(16.0))
	box(w, "flat_a", Vector3(0, 5.5, 0), Vector3(20, 1, 20))
	ramp(w, "down", Vector3(0, 6, -10), Vector3(0, 0, -10 - run), 20)
	box(w, "flat_b", Vector3(0, -0.5, -20 - run), Vector3(20, 1, 20))
	ramp(w, "up", Vector3(0, 0, -30 - run), Vector3(0, 6, -30 - 2 * run), 20)
	box(w, "flat_c", Vector3(0, 5.5, -80 - 2 * run), Vector3(20, 1, 100))

func kicker_world(w: Node3D) -> void:
	box(w, "approach", Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	ramp(w, "kicker", Vector3(0, 0, -10), Vector3(0, 5 * tan(deg_to_rad(12.0)), -15), 20)
	box(w, "below", Vector3(0, -3.5, -60), Vector3(40, 1, 80))

func downslope_world(w: Node3D) -> void:
	box(w, "deck", Vector3(0, 2.5, 0), Vector3(20, 1, 10))
	ramp(w, "downslope", Vector3(0, 1.0, -6), Vector3(0, 1.0 - 30 * tan(deg_to_rad(20.0)), -36), 20)
	box(w, "bottom", Vector3(0, 1.0 - 30 * tan(deg_to_rad(20.0)) - 0.5, -80), Vector3(40, 1, 88))

func cap_world(w: Node3D) -> void:
	box(w, "top", Vector3(0, 39.5, 0), Vector3(20, 1, 10))
	ramp(w, "steep", Vector3(0, 40, -5), Vector3(0, 0, -5 - 40.0 / tan(deg_to_rad(40.0))), 20)
	box(w, "runout", Vector3(0, -0.5, -200), Vector3(60, 1, 300))

func ceiling_world(w: Node3D) -> void:
	flat(w)
	box(w, "low_ceiling", Vector3(0, 1.3 + 0.25, -5.5), Vector3(10, 0.5, 5))

func deck_world(w: Node3D) -> void:
	box(w, "deck", Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	box(w, "below", Vector3(0, -3.5, -60), Vector3(40, 1, 100))

func steps_world(w: Node3D) -> void:
	# small up-steps and a flush seam between separate bodies, all at walking scale.
	box(w, "base", Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	box(w, "step_05", Vector3(0, -0.45, -15), Vector3(20, 1, 10))
	box(w, "seam_05", Vector3(0, -0.45, -25), Vector3(20, 1, 10))
	box(w, "drop_02", Vector3(0, -0.47, -55), Vector3(20, 1, 50))

func seam_world(w: Node3D, grouped: bool, rise: float) -> void:
	# two abutting slabs at z = -6, either separate bodies or one body with two shapes. a
	# rise lifts the far slab, so its front face is a lip of that height.
	if grouped:
		var body := StaticBody3D.new()
		body.name = "decks"
		w.add_child(body)
		box(w, "near", Vector3(0, -0.5, 0), Vector3(20, 1, 12), 0.0, body)
		box(w, "far", Vector3(0, -0.5 + rise, -36), Vector3(20, 1, 60), 0.0, body)
	else:
		box(w, "near", Vector3(0, -0.5, 0), Vector3(20, 1, 12))
		box(w, "far", Vector3(0, -0.5 + rise, -36), Vector3(20, 1, 60))

# ---------------------------------------------------------------- groups

func group_ground() -> void:
	# ordinary turning, earned: run up to speed, then a 90 degree mouse turn in 0.25 s.
	for profile: String in PROFILES:
		var trace := await run("ground_turn_ordinary_" + profile, {"build": flat, "profile": profile, "ticks": 150, "tape": [[0, "w", true], ["sweep", 60, 30, -PI * 0.5 / PX]]})
		var lag := first(trace.slice(90), func(row: Dictionary) -> bool: return absf(angle_difference(heading(row), row.yaw)) < deg_to_rad(2.0))
		var low := least(speeds(trace, 55, 150))
		var r := finish({"start_speed": hs(actual(trace[59])), "min_speed_in_turn": low, "heading_lag_ticks_after_view": lag})
		check(r, "ordinary turn keeps run speed (no chord loss)", low > 8.3, "min %.2f" % low)
		check(r, "heading follows the view within 0.15 s", lag >= 0 and lag <= 18, "lag %d ticks" % lag)
	# overspeed turning: seeded fixture at 14 m/s, and an earned run-out from a descent.
	# the earned variant's tape is timed from an earlier w-only run, never from live state.
	var descent_probe := await run("ground_descent_probe", {"build": descent, "pose": yaw_pose(Vector3(0, 8.02, 3), 0.0), "ticks": 700, "tape": [[0, "w", true]]})
	var runout := first(descent_probe, func(row: Dictionary) -> bool: return row.post.z < -36.0)
	finish({"runout_tick": runout, "runout_speed": hs(actual(descent_probe[runout]))})
	for variant: String in ["seeded", "earned"]:
		var cfg := {"build": flat, "ticks": 240, "tape": [[0, "w", true], ["sweep", 12, 30, -PI * 0.5 / PX]], "seed": along(0.0, 14.0)}
		if variant == "earned":
			cfg = {"build": descent, "pose": yaw_pose(Vector3(0, 8.02, 3), 0.0), "ticks": runout + 160, "tape": [[0, "w", true], ["sweep", runout, 30, -PI * 0.5 / PX]]}
		var trace := await run("ground_turn_overspeed_" + variant, cfg)
		var start := 12 if variant == "seeded" else runout
		var worst := 0.0
		var top_rate := 0.0
		for i: int in range(start + 1, mini(trace.size(), start + 150)):
			var speed := hs(actual(trace[i]))
			var rate := absf(angle_difference(heading(trace[i - 1]), heading(trace[i]))) / DT
			var grip := lerpf(60.0, 20.0, clampf((speed - 8.5) / 2.0, 0.0, 1.0))
			if trace[i].state.grounded and trace[i - 1].state.grounded:
				top_rate = maxf(top_rate, rate)
				worst = maxf(worst, rate * speed / grip)
		var s0 := hs(actual(trace[start]))
		var s1 := hs(actual(trace[start + 120]))
		var turned := rad_to_deg(absf(angle_difference(heading(trace[start]), heading(trace[start + 120]))))
		var r := finish({"speed_at_turn": s0, "speed_after_1s": s1, "turned_deg_in_1s": turned, "peak_rate_deg_s": rad_to_deg(top_rate), "peak_lateral_over_grip": worst, "turn_cost_beyond_push_drag": (s0 - s1) - 2.0})
		check(r, "overspeed lateral acceleration stays within grip", worst < 1.06, "%.3f of grip" % worst)
		check(r, "overspeed turn costs only the pushing drag", absf((s0 - s1) - 2.0) < 0.15, "lost %.3f in 1 s" % (s0 - s1))
	# release, brake, reversal and a side key, from an equal seeded 14 m/s.
	var stops := {}
	for keys: String in ["none", "w", "s", "a"]:
		var tape: Array = [] if keys == "none" else [[0, keys, true]]
		var trace := await run("ground_seeded_14_" + keys, {"build": flat, "seed": along(0.0, 14.0), "ticks": 300, "tape": tape})
		var forward := 0.0
		var stopped := -1
		var reversed_at := -1
		var reverse_speed := 0.0
		for i: int in trace.size():
			var v := actual(trace[i])
			forward += -v.z * DT
			if stopped < 0 and -v.z < 0.05:
				stopped = i
			if reversed_at < 0 and -v.z < -0.05:
				reversed_at = i
				reverse_speed = hs(actual(trace[maxi(0, i - 1)]))
		stops[keys] = forward
		var r := finish({"speed_1s": hs(actual(trace[120])), "speed_2_5s": hs(actual(trace[299])), "forward_m": forward, "stop_tick": stopped, "reverse_tick": reversed_at, "lateral_m": trace[-1].post.x})
		if keys == "s":
			check(r, "s stops before reversing", stopped >= 0 and reversed_at > stopped and reverse_speed < 1.6, "stop %d reverse %d at %.2f" % [stopped, reversed_at, reverse_speed])
		if keys == "a":
			check(r, "a side key bends the line without braking it", hs(actual(trace[60])) > 12.5 and trace[-1].post.x < -1.0, "x %.2f" % trace[-1].post.x)
	var rb := finish({"push_m": stops.w, "coast_m": stops.none, "brake_m": stops.s}, "ground_seeded_14_compare")
	check(rb, "coast and brake are distinct: braking stops shortest, pushing carries farthest", stops.s < stops.none and stops.none < stops.w)
	# earned release and brake from ordinary run speed.
	for keys: String in ["none", "s"]:
		var tape: Array = [[0, "w", true], [80, "w", false]]
		if keys == "s":
			tape.append([80, "s", true])
		var trace := await run("ground_earned_release_" + keys, {"build": flat, "ticks": 200, "tape": tape})
		var at := first(trace.slice(80), func(row: Dictionary) -> bool: return hs(actual(row)) < 0.05)
		var r := finish({"speed_at_release": hs(actual(trace[79])), "stop_ticks": at, "stop_m": absf(trace[80 + maxi(at, 0)].post.z - trace[79].post.z)})
		check(r, "ordinary release or brake stops within 0.4 s", at >= 0 and at < 48, "%d ticks" % at)

func group_hop() -> void:
	for profile: String in PROFILES:
		# held hop chain on flat with w: retained, never gifted.
		var trace := await run("hop_held_seeded_12_" + profile, {"build": flat, "profile": profile, "seed": along(0.0, 12.0), "ticks": 720, "tape": [[0, "w", true], [0, "space", true]]})
		var top := peak(controls(trace))
		var travel := speeds(trace)
		var r := finish({"hops": trace[-1].state.jump_count, "peak": top, "final": hs(actual(trace[-1])), "grace_landings": trace[-1].state.grace_count, "peak_travel": peak(travel), "least_travel_after_first_hop": least(speeds(trace, 10))})
		check(r, "held hops add no speed on flat", top < 12.0 + 1e-4, "peak %.5f" % top)
		check(r, "engine recovery moves the body under 1 mm per tick", peak(travel) < 12.0 + 0.12, "peak travel %.4f" % peak(travel), false)
		check(r, "held hops keep earned speed", hs(actual(trace[-1])) > 11.9, "final %.3f" % hs(actual(trace[-1])))
		var takeoffs: Array[int] = []
		for row: Dictionary in trace:
			if takeoffs.size() < int(row.state.jump_count):
				takeoffs.append(int(row.tick))
		var doubled := 0
		for i: int in range(1, takeoffs.size()):
			doubled += 1 if takeoffs[i] - takeoffs[i - 1] < 10 else 0
		check(r, "each landing fires one hop", doubled == 0, "%d hops within 10 ticks of the previous" % doubled)
		var earned := await run("hop_held_earned_" + profile, {"build": flat, "profile": profile, "ticks": 1200, "tape": [[0, "w", true], [0, "space", true]]})
		var top_earned := peak(controls(earned))
		check(finish({"hops": earned[-1].state.jump_count, "peak": top_earned}), "w and held hops never exceed run speed on flat", top_earned < 8.5 + 1e-3, "peak %.4f" % top_earned)
	# late and early second presses after a tapped hop: find the landing in a probe run.
	var probe := await run("hop_timing_probe", {"build": flat, "seed": along(0.0, 12.0), "ticks": 140, "tape": [[0, "w", true], [4, "space", true], [6, "space", false]]})
	var landing := first(probe.slice(10), func(row: Dictionary) -> bool: return row.state.grounded) + 10
	var first_hop := first(probe, func(row: Dictionary) -> bool: return int(row.state.jump_count) >= 1)
	var reference := hs(probe[first_hop].state.post_contact_velocity)
	var losses := {}
	for offset: int in [-24, -12, -6, 0, 6, 9, 12, 24, 48]:
		var at := landing + 1 + offset
		var trace := await run("hop_second_press_%+d" % offset, {"build": flat, "seed": along(0.0, 12.0), "ticks": landing + 80, "tape": [[0, "w", true], [4, "space", true], [6, "space", false], [at, "space", true], [at + 3, "space", false]]})
		var hopped := int(trace[-1].state.jump_count) >= 2
		var takeoff := first(trace.slice(landing), func(row: Dictionary) -> bool: return int(row.state.jump_count) >= 2)
		var speed := hs(trace[landing + takeoff].state.post_contact_velocity) if takeoff >= 0 else 0.0
		losses[offset] = reference - speed if hopped else -1.0
		var r := finish({"press_vs_landing_ms": offset * 1000.0 / 120.0, "hopped": hopped, "takeoff_speed": speed})
		if offset == -24:
			check(r, "a press 200 ms before landing has expired", not hopped)
		elif offset >= -12 and offset <= 9:
			check(r, "buffered or graced press keeps all speed", hopped and absf(reference - speed) < 1e-3, "loss %.4f" % (reference - speed))
		elif offset > 9:
			check(r, "a late press after grace pays ground drag", hopped and reference - speed > 0.0, "loss %.4f" % (reference - speed))
	check(finish({"reference_takeoff": reference, "loss_12": losses[12], "loss_24": losses[24], "loss_48": losses[48]}, "hop_second_press_compare"), "later presses cost more", losses[48] > losses[24] and losses[24] > losses[12])
	# coyote: walk off a deck edge and press shortly after.
	var walk := await run("coyote_probe", {"build": deck_world, "ticks": 260, "tape": [[0, "w", true]]})
	var leave := first(walk, func(row: Dictionary) -> bool: return row.tick > 20 and not row.state.grounded)
	for offset: int in [0, 4, 8, 11, 14, 20]:
		var trace := await run("coyote_press_%d" % offset, {"build": deck_world, "ticks": leave + 60, "tape": [[0, "w", true], [leave + offset, "space", true], [leave + offset + 3, "space", false]]})
		var hopped := int(trace[-1].state.jump_count) == 1
		var r := finish({"press_after_leaving_ms": offset * 1000.0 / 120.0, "hopped": hopped})
		check(r, "coyote window is 0.1 s", hopped == ((offset + 1) * DT <= 0.1 + 1e-6), "hopped %s" % hopped)

func group_air() -> void:
	# fixed view, equal seeded 13 m/s over two seconds of open air.
	var pose := yaw_pose(Vector3(0, 40, 0), 0.0)
	for profile: String in PROFILES:
		for keys: String in ["none", "w", "s", "a", "wa", "sa"]:
			var tape: Array = []
			for key: String in keys.replace("none", ""):
				tape.append([0, key, true])
			var trace := await run("air_fixed_%s_%s" % [keys, profile], {"build": drop, "pose": pose, "profile": profile, "seed": along(0.0, 13.0), "ticks": 180, "tape": tape})
			var v0 := hs(actual(trace[0]))
			var v1 := hs(actual(trace[-1]))
			var turned := rad_to_deg(angle_difference(heading(trace[0]), heading(trace[-1])))
			var r := finish({"gain": v1 - v0, "turned_deg": turned, "lateral_m": trace[-1].post.x})
			match keys:
				"none":
					check(r, "no keys keeps the ballistic line", absf(v1 - v0) < 1e-4 and absf(turned) < 1e-3)
				"w":
					check(r, "w alone is speed-neutral", absf(v1 - v0) < 1e-4, "gain %.5f" % (v1 - v0))
				"s":
					check(r, "s brakes and never reverses", v1 < v0 and actual(trace[-1]).z < 0.0)
				"a":
					check(r, "fixed-view side gain stays within the allowance", v1 <= sqrt(13.0 * 13.0 + 8.5 * 8.5) + 1e-3, "speed %.3f" % v1)
	# repeated hops on flat with w+a and the view fixed: the side allowance must stay
	# bounded. the diagnostic assist aims at camera-forward and is expected to loop.
	for variant: Array in [["broad", {}], ["narrow", {}], ["broad", {"assist_to_view": true}]]:
		var name := "air_wa_fixed_hops_%s%s" % [variant[0], "_view_assist_diagnostic" if not (variant[1] as Dictionary).is_empty() else ""]
		# seeded at 10 m/s: held hops from rest only build speed on their single ground ticks.
		var trace := await run(name, {"build": flat, "profile": variant[0], "tuning": variant[1], "seed": along(0.0, 10.0), "ticks": 2400, "tape": [[0, "w", true], [0, "a", true], [0, "space", true]]})
		var s := controls(trace)
		var r := finish({"peak": peak(s), "speed_1s": s[119], "speed_10s": s[1199], "speed_20s": s[-1], "turned_deg": rad_to_deg(angle_difference(heading(trace[1]), heading(trace[-1])))})
		if (variant[1] as Dictionary).is_empty():
			check(r, "fixed-view w+a cannot loop the side allowance", peak(s) < 11.0 and s[-1] - s[1199] < 0.05, "peak %.3f, 10-20 s %+.3f" % [peak(s), s[-1] - s[1199]])
		else:
			# measured: with travel pulled back onto the view each tick the side push stays at
			# 90 degrees, so the loop is second order. it grows, but slowly; reported, not gated.
			check(r, "diagnostic: assisting toward camera-forward grows without bound", s[-1] > s[1199] + 1e-3, "10 s %.4f, 20 s %.4f" % [s[1199], s[-1]], false)
	# view turns with keys, from an equal seeded 10 m/s. the rate a side key can follow is
	# the angular authority that separates the two laws; it is measured, not assumed.
	for profile: String in PROFILES:
		for keys: String in ["w", "a", "wa"]:
			var best := -INF
			for rate: float in [0.3, 0.75, 1.5, 3.0, 6.0]:
				var tape: Array = [["sweep", 0, 144, -rate * 1.2 / PX]]
				for key: String in keys:
					tape.append([0, key, true])
				var trace := await run("air_mouse_%s_%.1f_%s" % [keys, rate, profile], {"build": drop, "pose": pose, "profile": profile, "seed": along(0.0, 10.0), "ticks": 150, "tape": tape})
				var gain := hs(actual(trace[-1])) - hs(actual(trace[0]))
				var turned := rad_to_deg(angle_difference(heading(trace[0]), heading(trace[-1])))
				var r := finish({"view_rate": rate, "gain": gain, "turned_deg": turned, "view_turned_deg": rad_to_deg(rate * 1.2)})
				best = maxf(best, gain)
				if keys == "w":
					check(r, "w with the mouse mints no speed", absf(gain) < 1e-4, "gain %.5f" % gain)
				else:
					check(r, "this view rate earns speed with the side key", gain > 0.05, "gain %.3f" % gain, false)
			if keys == "a":
				check(finish({"best_gain": best}, "air_mouse_a_best_%s" % profile), "a strafe turned with the mouse earns speed at some rate", best > 0.05, "best %.3f" % best)

func group_window() -> void:
	# angular window: d at 13 m/s with the view offset by one relative mouse event at tick 0.
	for profile: String in PROFILES:
		# instantaneous gain on the first keyed tick, against the wish-to-travel angle, and the
		# sustained gain over 0.25 s with the view held still (fixed-view correction).
		var gains := {}
		var sustained := {}
		var best := 0.0
		var angles: Array[float] = []
		for degrees: int in range(0, 91, 5):
			angles.append(float(degrees))
		for tenth: int in range(10, 60, 5):
			angles.append(tenth * 0.1)
		for degrees: float in angles:
			var trace := await run("window_%s_%04.1f" % [profile, 90.0 - degrees], {"build": drop, "pose": yaw_pose(Vector3(0, 40, 0), 0.0), "profile": profile, "seed": along(0.0, 13.0), "ticks": 31, "tape": [[0, "mouse", -deg_to_rad(degrees) / PX], [1, "d", true]]})
			var gain := (hs(actual(trace[1])) - hs(actual(trace[0]))) / DT
			gains[90.0 - degrees] = gain
			sustained[90.0 - degrees] = (hs(actual(trace[30])) - hs(actual(trace[0]))) / (30 * DT)
			best = maxf(best, gain)
		var low := 180.0
		var high := 0.0
		for angle: float in gains:
			if gains[angle] >= best * 0.5:
				low = minf(low, angle)
				high = maxf(high, angle)
		finish({"best_gain_m_s2": best, "half_gain_from_deg": low, "half_gain_to_deg": high, "gains": gains, "sustained_fixed_view": sustained})
	# w assist authority with the view offset, shared by both profiles.
	var turned_by := {}
	for profile: String in PROFILES:
		for degrees: int in [20, 45, 60, 80, 100]:
			var trace := await run("assist_%s_%03d" % [profile, degrees], {"build": drop, "pose": yaw_pose(Vector3(0, 40, 0), 0.0), "profile": profile, "seed": along(0.0, 13.0), "ticks": 61, "tape": [[0, "mouse", -deg_to_rad(degrees) / PX], [1, "w", true]]})
			var turned := rad_to_deg(angle_difference(heading(trace[1]), heading(trace[-1])))
			turned_by["%s_%d" % [profile, degrees]] = turned
			finish({"view_offset_deg": degrees, "heading_turn_0_5s_deg": turned, "gain": hs(actual(trace[-1])) - hs(actual(trace[1]))})
	var same := true
	for degrees: int in [20, 45, 60, 80, 100]:
		same = same and absf(turned_by["broad_%d" % degrees] - turned_by["narrow_%d" % degrees]) < 1e-3
	check(finish({"assist_60_deg": turned_by["broad_60"], "assist_100_deg": turned_by["broad_100"]}, "assist_compare"), "w assist is identical in both profiles and fades out past 90 degrees", same and absf(turned_by["broad_100"]) < 1e-3)

func group_contact() -> void:
	var yaw := deg_to_rad(-15.0)
	for where: String in ["ground", "air"]:
		var trace := await run("glance_%s" % where, {"build": wall_world if where == "ground" else drop, "pose": yaw_pose(Vector3(0, 0.02 if where == "ground" else 40.0, 0), yaw), "seed": along(yaw, 12.0), "ticks": 120, "tape": [[0, "w", true]], "contacts": true})
		var into := 0.0
		var mismatch := 0.0
		var touched := -1
		for i: int in trace.size():
			var row: Dictionary = trace[i]
			for contact: Dictionary in row.state.contacts:
				if absf((contact.normal as Vector3).x) > 0.9:
					touched = i if touched < 0 else touched
					into = maxf(into, (row.state.post_contact_velocity as Vector3).x)
			if touched >= 0 and i > touched:
				mismatch = maxf(mismatch, absf(hs(actual(row)) - hs(trace[i - 1].state.post_contact_velocity)))
		var after := hs(actual(trace[-1]))
		# along-wall speed is the approach speed's tangent part, less pushing drag after it.
		var approach := hs(trace[maxi(touched - 1, 0)].state.post_contact_velocity)
		var drag := 2.0 * (trace.size() - touched) * DT if where == "ground" else 0.0
		var expected := approach * cos(deg_to_rad(15.0)) - drag
		var r := finish({"contact_tick": touched, "speed_after": after, "along_wall_expected": expected, "max_velocity_into_wall": into, "max_travel_vs_request": mismatch})
		check(r, "glance never keeps velocity into the wall", into < 1e-3, "%.4f" % into)
		check(r, "glance keeps the along-wall speed, less pushing drag", touched >= 0 and after > expected - 0.2, "%.3f vs %.3f" % [after, expected])
		check(r, "travel matches the velocity carried after contact", mismatch < 0.05, "%.4f" % mismatch)
	var trace := await run("wall_press_earned", {"build": front_wall, "ticks": 180, "tape": [[0, "w", true]], "contacts": true})
	var shown := peak(speeds(trace, 90))
	var requested := 0.0
	for row: Dictionary in trace.slice(90):
		requested = maxf(requested, hs(row.state.requested_velocity))
	var r := finish({"hud_speed_pressing": shown, "requested_speed_pressing": requested, "body": trace[-1].state.contacts[0].body if not trace[-1].state.contacts.is_empty() else ""})
	check(r, "hud speed reports the stationary body, not the request", shown < 0.3 and requested > shown, "shown %.3f requested %.3f" % [shown, requested])

func group_slope() -> void:
	# supported descent pays within physics; frictionless loop returns its speed.
	var drop_h := 8.0
	for keys: String in ["w", "none"]:
		# coasting below run speed stops, so the coasting case starts with earned overspeed.
		var v0 := 8.5 if keys == "w" else 12.0
		var trace := await run("descent_seeded_%s" % keys, {"build": descent, "pose": yaw_pose(Vector3(0, 8.02, 2), 0.0), "seed": along(0.0, v0), "ticks": 360, "tape": [[0, "w", true]] if keys == "w" else []})
		var bottom := first(trace, func(row: Dictionary) -> bool: return row.post.z < -5 - drop_h / tan(deg_to_rad(16.0)) - 1.0)
		var speed := hs(actual(trace[bottom]))
		var ideal := sqrt(v0 * v0 + 2.0 * 20.0 * drop_h)
		var r := finish({"bottom_speed": speed, "frictionless_bound": ideal, "slope_booked": total(trace, "slope"), "drag_booked": total(trace, "push_drag") + total(trace, "coast")})
		check(r, "descent pays without exceeding the frictionless bound", speed > v0 + 3.0 and speed <= ideal + 0.02, "%.3f vs %.3f" % [speed, ideal])
	for tuned: bool in [true, false]:
		var tuning := {"coast_drag": 0.0, "stop": 0.0, "push_drag": 0.0} if tuned else {}
		var trace := await run("loop_%s" % ("frictionless" if tuned else "default"), {"build": loop_world, "pose": yaw_pose(Vector3(0, 6.02, 5), 0.0), "seed": along(0.0, 12.0), "tuning": tuning, "ticks": 900, "tape": []})
		var start_i := first(trace, func(row: Dictionary) -> bool: return row.post.z < 0.0)
		var end_i := first(trace, func(row: Dictionary) -> bool: return row.post.z < -2 * 6.0 / tan(deg_to_rad(16.0)) - 40.0)
		var e0: float = trace[start_i].state.specific_energy
		var e1: float = trace[end_i].state.specific_energy if end_i >= 0 else NAN
		var v1 := hs(actual(trace[end_i])) if end_i >= 0 else 0.0
		var r := finish({"speed_in": hs(actual(trace[start_i])), "speed_out": v1, "energy_change": e1 - e0, "airborne_ticks": trace.filter(func(row: Dictionary) -> bool: return not row.state.grounded).size()})
		if tuned:
			check(r, "frictionless slope loop returns its speed: no numerical gift", end_i >= 0 and absf(v1 - 12.0) < 0.05, "out %.4f" % v1)
	# a real ramp edge carries its climb into the air; take-off conserves speed along it.
	var kick := await run("kicker_edge_seeded", {"build": kicker_world, "seed": along(0.0, 11.0), "ticks": 200, "tape": [[0, "w", true]]})
	var leave := first(kick, func(row: Dictionary) -> bool: return row.tick > 10 and not row.state.grounded)
	var on := actual(kick[leave - 1])
	var off := actual(kick[leave + 1])
	var rk := finish({"ramp_speed": on.length(), "air_speed": off.length(), "air_vertical": off.y, "ramp_vertical": on.y})
	check(rk, "a ramp edge keeps the surface's climb and speed", absf(off.length() - on.length()) < 0.25 and off.y > 0.8 * on.y, "ramp %s air %s" % [on, off])
	# a hop onto a downslope: the landing catches the fall along the surface.
	var land := await run("downslope_landing_seeded", {"build": downslope_world, "pose": yaw_pose(Vector3(0, 3.02, 2), 0.0), "seed": along(0.0, 8.5), "ticks": 200, "tape": [[0, "w", true], [20, "space", true], [23, "space", false]]})
	var touch := first(land, func(row: Dictionary) -> bool: return row.tick > 30 and row.state.grounded)
	var before_e: float = land[touch - 1].state.specific_energy
	var after_e: float = land[touch + 1].state.specific_energy
	var rl := finish({"speed_before": hs(actual(land[touch - 1])), "speed_after": hs(actual(land[touch + 1])), "catch_booked": total(land, "landing_catch"), "energy_change": after_e - before_e})
	check(rl, "a downslope landing catches the fall without adding energy", total(land, "landing_catch") > 0.0 and after_e <= before_e + 0.2, "dE %.3f" % (after_e - before_e))

func group_cap() -> void:
	var trace := await run("cap_steep_seeded", {"build": cap_world, "pose": yaw_pose(Vector3(0, 40.02, 2), 0.0), "seed": along(0.0, 20.0), "ticks": 400, "tape": [[0, "w", true]]})
	var count: int = trace[-1].state.safety_interventions
	var r := finish({"peak": peak(speeds(trace)), "safety_interventions": count, "safety_booked": total(trace, "safety_cap")})
	check(r, "every safety-cap intervention is counted and booked", count > 0 and total(trace, "safety_cap") < 0.0)

func group_cadence() -> void:
	# the same one-radian strafe sweep delivered at 120, 60 and 30 events per second.
	for profile: String in PROFILES:
		var gains := {}
		for every: int in [1, 2, 4]:
			for phase: int in range(every):
				# p / a rate each law can follow: broad's side key turns travel slowly, narrow's fast.
				var sweep := -(0.3 if profile == "broad" else 1.6) / PX
				var trace := await run("cadence_%s_%d_%d" % [profile, 120 / every, phase], {"build": drop, "pose": yaw_pose(Vector3(0, 40, 0), 0.0), "profile": profile, "seed": along(0.0, 10.0), "ticks": 110, "tape": [[0, "a", true], ["sweep", 4, 96, sweep, every, phase]]})
				gains["%d_%d" % [120 / every, phase]] = hs(actual(trace[-1])) - hs(actual(trace[0]))
		var spread := 0.0
		for key: String in gains:
			spread = maxf(spread, absf(gains[key] - gains["120_0"]))
		var r := finish({"gain_120": gains["120_0"], "gain_60": gains["60_0"], "gain_30": gains["30_0"], "max_spread": spread, "all": gains})
		check(r, "strafe earns at 120 Hz delivery", gains["120_0"] > 0.05, "%.3f" % gains["120_0"])
		check(r, "mouse delivery rate changes the strafe reward by under 10%", spread < 0.1 * absf(gains["120_0"]) + 0.01, "spread %.4f of %.4f" % [spread, gains["120_0"]], false)

func group_duck() -> void:
	var trace := await run("duck_under_ceiling", {"build": ceiling_world, "ticks": 420, "tape": [[0, "w", true], [0, "ctrl", true], [150, "ctrl", false]]})
	var forced := 0
	var eye_clear := true
	var stood := -1
	for i: int in trace.size():
		var row: Dictionary = trace[i]
		var under: bool = row.post.z < -3.0 + 0.3 and row.post.z > -8.0 - 0.3
		if i > 150 and under and row.state.crouched:
			forced += 1
		if under and row.camera.y > 1.3 - 0.06:
			eye_clear = false
		if i > 150 and stood < 0 and not row.state.crouched:
			stood = i
	var r := finish({"ticks_held_low_under_ceiling": forced, "stood_at_z": trace[stood].post.z if stood >= 0 else 0.0, "peak": peak(speeds(trace, 20))})
	check(r, "releasing crouch under a ceiling stays low until clear", forced > 0 and stood >= 0 and trace[stood].post.z < -8.0)
	check(r, "the eye never enters the ceiling", eye_clear)
	var slide := await run("duck_at_speed_seeded", {"build": flat, "seed": along(0.0, 12.0), "ticks": 120, "tape": [[0, "ctrl", true], [0, "w", true]]})
	var rising := 0.0
	var motor := controls(slide)
	for i: int in range(2, motor.size()):
		rising = maxf(rising, motor[i] - motor[i - 1])
	check(finish({"speed_0_5s": hs(actual(slide[60])), "largest_rise": rising}), "a duck at speed only slows: no slide", rising < 1e-4)

func group_flicker() -> void:
	for profile: String in PROFILES:
		var trace := await run("flicker_steps_" + profile, {"build": steps_world, "profile": profile, "pose": yaw_pose(Vector3(0, 0.02, 5), 0.0), "seed": along(0.0, 12.0), "ticks": 600, "tape": [[0, "w", true]], "contacts": true})
		var short_air := 0
		var unearned_grace := 0
		var run_length := 0
		var grace := 0
		for row: Dictionary in trace:
			if not row.state.grounded:
				run_length += 1
			else:
				if run_length > 0 and run_length < 6:
					short_air += 1
				if int(row.state.grace_count) > grace and run_length * DT < 0.05 - 1e-6:
					unearned_grace += 1
				grace = int(row.state.grace_count)
				run_length = 0
		var r := finish({"short_air_runs": short_air, "grace_landings": grace, "unearned_grace": unearned_grace, "peak": peak(speeds(trace, 2))})
		check(r, "support flickers never earn landing grace", unearned_grace == 0)
		check(r, "small steps and a seam add no speed", peak(speeds(trace, 2)) <= 12.0 + 1e-3, "peak %.4f" % peak(speeds(trace, 2)))

func group_backend() -> void:
	# lip and seam contact under this project's backend. the same cells run unchanged in
	# fixture projects that differ only in physics/3d/physics_engine.
	for grouped: bool in [false, true]:
		for rise: float in [0.0, 0.01, 0.03, 0.08, 0.15]:
			for speed: float in [8.5, 16.0]:
				var name := "seam_%s_rise%03d_%02d" % ["grouped" if grouped else "separate", int(rise * 100), int(speed)]
				var trace := await run(name, {"build": seam_world.bind(grouped, rise), "pose": yaw_pose(Vector3(0, 0.02, 3), 0.0), "seed": along(0.0, speed), "ticks": 150, "tape": [[0, "w", true]], "contacts": true})
				var cross := first(trace, func(row: Dictionary) -> bool: return row.post.z < -6.3)
				var low := least(speeds(trace, 6, maxi(cross + 20, 7)))
				var pop := 0.0
				var clearance := 0.0
				var air := 0
				# from tick 6, after the seeded spawn has settled; clearance away from the edge.
				for row: Dictionary in trace.slice(6):
					pop = maxf(pop, (row.state.actual_velocity as Vector3).y)
					if absf(row.post.z + 6.0) > 0.35:
						clearance = maxf(clearance, row.post.y - (rise if row.post.z < -6.0 else 0.0))
					air += 0 if row.state.grounded else 1
				var contact_loss := total(trace, "contact_engine") + total(trace, "contact_clip")
				var r := finish({"crossed_tick": cross, "min_speed": low, "peak_vertical_velocity": pop, "peak_clearance": clearance, "air_ticks": air, "contact_loss": contact_loss, "safety": trace[-1].state.safety_interventions})
				check(r, "crossing a seam or lip keeps speed", cross >= 0 and contact_loss > -0.3, "contact loss %.3f, crossed %d" % [contact_loss, cross], false)
				check(r, "crossing a seam or lip does not pop the runner", air == 0 and clearance < 0.02, "air %d ticks, clearance %.3f" % [air, clearance], false)

func group_integration() -> void:
	# the calibration block in the actual game factory, played by the lab's open-loop tape.
	for profile: String in PROFILES:
		var tape: Array = []
		for step: Array in LAB.DEMOS["line"]:
			tape.append(step)
		var trace := await run("calibration_line_" + profile, {"game": LAB.CalibrationGame, "profile": profile, "ticks": 1020, "tape": tape})
		var hud_matches := true
		for row: Dictionary in trace:
			hud_matches = hud_matches and absf(float(row.state.actual_speed) - hs(actual(row))) < 1e-5
		var end: Dictionary = current.game_end
		var r := finish({"finished": end.finished, "finish_kind": end.finish_kind, "checkpoint": end.checkpoint, "elapsed": end.elapsed, "respawns": end.respawns, "peak": peak(speeds(trace)), "safety": trace[-1].state.safety_interventions, "hops": trace[-1].state.jump_count})
		check(r, "w and timed hops finish the calibration block", bool(end.finished) and int(end.respawns) == 0)
		check(r, "the ordinary line never reaches the safety cap", int(r.metrics.safety) == 0)
		check(r, "speed shown is the actual travel", hud_matches)

extends "res://tests/test_momentum_carry.gd"
## independent carry contact review with the original scenario geometry and tapes.
## [--fixtures=absolute/path.gd] --out=absolute/path [--only=case-name-substring]
## a nonzero exit means a claimed movement invariant failed, including known review repros.

var fixtures_path := "res://tests/momentum_carry_review_fixtures.gd"
var case_filter := ""
var extra_reports := false
var review_traces: Dictionary = {}

func _initialize() -> void:
	out_dir = "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/carry-review-sol/final"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixtures="):
			fixtures_path = arg.trim_prefix("--fixtures=")
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			case_filter = arg.trim_prefix("--only=")
	_run.call_deferred()

func early_tick() -> void:
	if running and extra_reports:
		# read-only reports exercise the observation path without changing the motor.
		for i: int in 10:
			player.call("get_motion_state")
	super()

func _run() -> void:
	MAIN.bind_inputs()
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("traces"))
	var fixture_script := load(fixtures_path) as Script
	if fixture_script == null:
		push_error("review fixtures unavailable: " + fixtures_path)
		quit(2)
		return
	var fixtures: RefCounted = fixture_script.new()
	for early: bool in [true, false]:
		var probe := Probe.new()
		probe.suite = self
		probe.early = early
		probe.process_physics_priority = -1000 if early else 1000
		root.add_child(probe)
	await process_frame
	var cases: Array = fixtures.call("cases", self)
	for cfg: Dictionary in cases:
		if not case_filter.is_empty() and not case_filter in str(cfg.name):
			continue
		extra_reports = cfg.get("extra_reports", false)
		var trace := await run(cfg.name, cfg)
		review_traces[cfg.name] = trace
		var m := review_metrics(trace)
		var result := finish(m)
		if cfg.get("separating_support_gate", false):
			check(result, "a hop separating from this plane clears support", m.supported_departures.is_empty(), str(m.supported_departures))
			check(result, "one hop per support arrival", m.duplicate_hops.is_empty(), str(m.duplicate_hops))
		if cfg.get("contact_diagnostic", false):
			# a transient inward command alone does not establish invalid actual travel.
			check(result, "resolved surface motion stays outside rail planes", m.max_inward < 0.001, "%.6f" % m.max_inward, false)
		check(result, "motion report equals finite-difference travel", m.travel_report_error < 0.0001, str(m.travel_report_error))
		if cfg.has("same_as") and cfg.same_as != cfg.name and review_traces.has(cfg.same_as):
			var baseline: Array = review_traces[cfg.same_as]
			var error := 0.0
			if baseline.size() == trace.size():
				for i: int in trace.size():
					error = maxf(error, (trace[i].post as Vector3).distance_to(baseline[i].post))
			else:
				error = INF
			result.metrics.repeat_position_error = error
			check(result, "repeat or extra observation preserves movement exactly", error == 0.0, str(error))
	if not order_violations.is_empty():
		gate_failures.append("input/order violations: " + str(order_violations.size()))
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_numeric({"engine": Engine.get_version_info(), "physics_hz": Engine.physics_ticks_per_second, "physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine", "<unset>"), "fixtures": fixtures_path, "fixture_sha256": FileAccess.get_sha256(fixtures_path), "results": results, "order_violations": order_violations, "gate_failures": gate_failures}), "  "))
	file.close()
	for failure: String in gate_failures:
		print("FAIL " + failure)
	print("carry review: %d cases, %d failed gates; %s" % [results.size(), gate_failures.size(), out_dir])
	quit(1 if not gate_failures.is_empty() else 0)

func review_metrics(trace: Array[Dictionary]) -> Dictionary:
	var jumps: Array = []
	var supported: Array = []
	var duplicates: Array = []
	var inward := 0.0
	var error := 0.0
	var peak_speed := 0.0
	var target := -1
	var catch_tick := -1
	var travelled := 0.0
	var last_jump := -100
	for i: int in trace.size():
		var row: Dictionary = trace[i]
		var state: Dictionary = row.state
		var v: Vector3 = state.post_contact_velocity
		var measured: Vector3 = (row.post - row.pre) / DT
		error = maxf(error, measured.distance_to(state.actual_velocity))
		peak_speed = maxf(peak_speed, hs(measured))
		travelled += hs(measured) * DT
		if state.grounded:
			# ground commands encode surface length, so compare the reconstructed tangent.
			var n: Vector3 = state.support_normal
			var h := Vector3(v.x, 0, v.z)
			v = (h + Vector3.UP * (-n.dot(h) / n.y)).normalized() * h.length()
		for c: Dictionary in state.contacts:
			if c.body == "rail":
				inward = maxf(inward, -v.dot(c.normal))
			if state.grounded and c.body == "target" and target < 0:
				target = i
			if state.grounded and c.body == "catch" and catch_tick < 0:
				catch_tick = i
		if i > 0 and state.jump_count > trace[i - 1].state.jump_count:
			var support: Vector3 = trace[i - 1].state.support_normal
			var separation := (state.requested_velocity as Vector3).dot(support)
			jumps.append({"tick": i, "requested": state.requested_velocity, "actual": measured, "grounded": state.grounded, "separation": separation})
			if i - last_jump <= 2:
				duplicates.append(i)
			if state.grounded and separation > 0.01:
				supported.append(i)
			last_jump = i
	return {"hops": jumps, "supported_departures": supported, "duplicate_hops": duplicates, "max_inward": inward, "travel_report_error": error, "peak_actual_horizontal": peak_speed, "horizontal_travel": travelled, "target_landing": target, "catch_landing": catch_tick, "end": trace[-1].post}

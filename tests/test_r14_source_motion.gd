extends SceneTree
## p / r14 source motion, pure checks with no godot collision: the equations and the shared
## tick order on an infinite plane. predictions from docs/r14/SOURCE-REFERENCE.md's oracle are
## read as data when --oracle points at its json; nothing from the oracle is imported.
## gates are promised behavior; findings are measurements reported for review.
## godot --headless --path . --script res://tests/test_r14_source_motion.gd -- [--out=DIR] [--oracle=JSON]

const M := preload("res://scripts/r14_source_motion.gd")

var out_dir := "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/source-motor/motion"
var oracle: Dictionary = {}
var checks: Array[Dictionary] = []
var findings: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--oracle="):
			var text := FileAccess.get_file_as_string(arg.trim_prefix("--oracle="))
			oracle = JSON.parse_string(text) if not text.is_empty() else {}
	constants()
	air_rows()
	ground()
	independent_vectors()
	server_ground_retention()
	ballistics()
	hop_chains()
	vanilla()
	retention()
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.pass)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "findings": findings, "oracle_loaded": not oracle.is_empty()}, "\t"))
	file.close()
	print("r14 source motion: %d checks, %d failed, oracle %s; summary %s" % [checks.size(), failed.size(), "loaded" if not oracle.is_empty() else "absent", out_dir.path_join("summary.json")])
	for c: Dictionary in failed:
		print("FAIL ", c.name, ": ", c.detail)
	quit(0 if failed.is_empty() else 1)

func check(name: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"name": name, "pass": ok, "detail": str(detail)})
	print("%s %s %s" % ["ok  " if ok else "FAIL", name, str(detail)])

## vectors are single precision, as source's are, so tolerances also allow 2e-6 relative.
func near(name: String, value: float, expected: float, tolerance: float) -> void:
	tolerance = maxf(tolerance, 2e-6 * absf(expected))
	check(name, absf(value - expected) <= tolerance, "%.9f vs %.9f (tol %s)" % [value, expected, str(tolerance)])

func cvars_for(hz: int, aa: float, budget := "legacy", surface := "constant") -> Dictionary:
	var cv := M.preset("csgo_server")
	cv.tickrate = hz
	cv.sv_airaccelerate = aa
	cv.air_budget = budget
	cv.air_surface = surface
	return cv

func constants() -> void:
	var v := M.preset("csgo_vanilla")
	var s := M.preset("csgo_server")
	var expect := {"sv_accelerate": 5.5, "sv_friction": 5.2, "sv_stopspeed": 80.0, "sv_gravity": 800.0, "sv_jump_impulse": 301.993377, "sv_air_max_wishspeed": 30.0, "sv_maxspeed": 320.0, "sv_maxvelocity": 3500.0, "player_maxspeed": 250.0}
	for key: String in expect:
		check("const_" + key, is_equal_approx(float(v[key]), expect[key]) and is_equal_approx(float(s[key]), expect[key]), "%s %s" % [v[key], s[key]])
	check("const_vanilla_policy", v.tickrate == 64 and v.sv_airaccelerate == 12.0 and not v.sv_autobunnyhopping and not v.sv_enablebunnyhopping and v.sv_staminamax == 80.0 and v.sv_staminajumpcost == 0.08 and v.sv_staminalandcost == 0.05 and v.sv_staminarecoveryrate == 60.0)
	check("const_server_policy", s.tickrate == 128 and s.sv_airaccelerate == 100.0 and s.sv_autobunnyhopping and s.sv_enablebunnyhopping and s.sv_staminamax == 0.0)
	near("units_gravity_m", 800.0 * M.U, 20.32, 1e-9)
	near("units_impulse_m", 301.993377 * M.U, 7.670631776, 1e-8)

## these predictions were frozen by the independent oracle before this motor was accepted.
func independent_vectors() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/r14_source_vectors.json"))
	for i: int in data.air.size():
		var row: Dictionary = data.air[i]
		var cv := cvars_for(int(row.hz), float(row.airaccelerate))
		var initial := Vector3(row.velocity_before_u_s[0], 0, row.velocity_before_u_s[1])
		var direction := Vector3(row.wish_direction[0], 0, row.wish_direction[1])
		var result := M.air_accelerate(initial, direction, row.wishspeed_u_s, cv, 1.0 / row.hz, row.surface_friction)
		var expected := Vector3(row.velocity_after_u_s[0], 0, row.velocity_after_u_s[1])
		check("independent_air_%d" % i, result.distance_to(expected) <= 0.0001, "%s vs %s" % [result, expected])
	for i: int in data.friction.size():
		var row: Dictionary = data.friction[i]
		var cv := cvars_for(int(row.hz), 100.0)
		var result := Vector3(row.initial_speed_u_s, 0, 0)
		for tick: int in int(row.released_ticks):
			result = M.friction(result, cv, 1.0 / row.hz)
		near("independent_friction_%d" % i, result.x, row.speed_u_s, 0.0001)

## the actual shared tick must preserve the friction result above run speed, not only the helper.
func server_ground_retention() -> void:
	for hz: int in [64, 128]:
		var cv := cvars_for(hz, 100.0)
		var s := _flat_state(hz)
		s.velocity = Vector3(0, 0, -750)
		M.step(s, {}, cv, 1.0 / hz, M.FlatWorld.new())
		near("server_released_overspeed_%d" % hz, (s.velocity as Vector3).length(), 750.0 * (1.0 - 5.2 / hz), 0.0001)
		check("server_no_auxiliary_ground_clamp_%d" % hz, not s.ledger.has("ground_clamp"))

## best single tick by brute angle sweep through air_accelerate, and a 16-tick arc using the
## analytic optimum each tick. both read the module, not the oracle's own functions.
func air_rows() -> void:
	var rows: Array = oracle.get("air_rows", [])
	var found := []
	for hz: int in [64, 128]:
		for aa: float in [12.0, 100.0]:
			for budget: String in ["legacy", "capped"]:
				var cv := cvars_for(hz, aa, budget)
				var dt := 1.0 / hz
				var v := Vector3(0, 0, -250.0)
				var best := 0.0
				var best_angle := 0.0
				for i: int in 36001:
					var angle := PI * float(i) / 36000.0
					var dir := Vector3(-sin(angle), 0, -cos(angle))
					var after := M.air_accelerate(v, dir, 250.0, cv, dt)
					if after.length() - 250.0 > best:
						best = after.length() - 250.0
						best_angle = angle
				var arc := v
				for t: int in 16:
					arc = M.air_accelerate(arc, _optimal_dir(arc, cv, dt, 1.0), 250.0, cv, dt)
				var row := {"hz": hz, "aa": aa, "budget": budget, "gain": best, "angle_deg": rad_to_deg(best_angle), "arc16": arc.length()}
				found.append(row)
				for o: Dictionary in rows:
					if int(o.hz) == hz and float(o.aa) == aa and (str(o.budget_mode).begins_with("legacy") == (budget == "legacy")):
						near("air_gain_%d_aa%d_%s" % [hz, aa, budget], best, float(o.optimal_tick_gain_at_250_u_s), 2e-4)
						near("air_arc16_%d_aa%d_%s" % [hz, aa, budget], arc.length(), float(o.optimal_16_tick_arc_end_u_s), 1e-6)
	findings["air_rows"] = found
	# the discriminator the brief asks for: aa12 at 64 Hz gains three times more per ideal tick
	# with the uncapped budget than the capped one.
	var legacy: float = found[0].gain
	var capped: float = found[1].gain
	check("air_budget_uncapped_discriminates", legacy > 2.5 * capped, "legacy %.6f capped %.6f" % [legacy, capped])
	# the cap limits projection, not speed: aligned wish at 250 adds nothing; at 20 it adds 10.
	var cv := cvars_for(64, 12.0)
	check("air_cap_projection", M.air_accelerate(Vector3(0, 0, -250), Vector3(0, 0, -1), 250.0, cv, 1.0 / 64).is_equal_approx(Vector3(0, 0, -250)) and M.air_accelerate(Vector3(0, 0, -20), Vector3(0, 0, -1), 250.0, cv, 1.0 / 64).is_equal_approx(Vector3(0, 0, -30)))
	check("air_no_wish_no_change", M.air_accelerate(Vector3(3, 0, -250), Vector3.ZERO, 0.0, cv, 1.0 / 64) == Vector3(3, 0, -250))

## the ideal wish direction for this velocity and budget, on the side that keeps turning left.
func _optimal_dir(v: Vector3, cv: Dictionary, dt: float, surface: float) -> Vector3:
	var h := Vector3(v.x, 0, v.z)
	var speed := h.length()
	var c := 30.0
	var b := minf(M.air_budget(250.0, cv, dt, surface), c)
	if speed < 1e-6:
		return Vector3(0, 0, -1)
	var along := h / speed
	if speed < c - b:
		return along
	var angle := acos(clampf((c - b) / speed, -1.0, 1.0))
	return along.rotated(Vector3.UP, angle)

func _flat_state(hz: int) -> Dictionary:
	var s := M.new_state()
	s.grounded = true
	s.ground_normal = Vector3.UP
	s.ground_ticks = 100
	return s

func ground() -> void:
	var world := M.FlatWorld.new()
	for hz: int in [64, 128]:
		var cv := cvars_for(hz, 100.0)
		var dt := 1.0 / hz
		var s := _flat_state(hz)
		var ticks := 0
		while (s.velocity as Vector3).length() < 250.0 - 1e-9 and ticks < 500:
			M.step(s, {"forward": 1.0, "yaw": 0.0}, cv, dt, world)
			ticks += 1
		var key := str(hz)
		var expected: Dictionary = oracle.get("ground_release_250", {}).get(key, {})
		if not expected.is_empty():
			check("ground_runup_ticks_%d" % hz, ticks == int(expected.runup.ticks), "%d vs %s" % [ticks, expected.runup.ticks])
		var speeds := []
		for i: int in 32:
			M.step(s, {"yaw": 0.0}, cv, dt, world)
			speeds.append((s.velocity as Vector3).length())
		if not expected.is_empty():
			near("ground_release_first_%d" % hz, speeds[0], float(expected.first_tick_u_s), 1e-6)
			near("ground_release_32_%d" % hz, speeds[31], float(expected.after_32_ticks_u_s), 1e-6)
		findings["ground_%d" % hz] = {"runup_ticks": ticks, "release": speeds}
		check("ground_stays_grounded_%d" % hz, s.grounded and (s.position as Vector3).y == 0.0)

## one standing jump each: sampled apex, the tick the 2 u probe catches it, and the tick the
## plane is crossed. the oracle's crossing tick is conditional on no probe; the probe is real.
func ballistics() -> void:
	var out := {}
	for hz: int in [64, 128]:
		for order: String in ["source2013", "ideal"]:
			var cv := cvars_for(hz, 100.0)
			cv.jump_order = order
			cv.sv_autobunnyhopping = false
			var world := M.FlatWorld.new()
			var dt := 1.0 / hz
			var s := _flat_state(hz)
			M.step(s, {"jump": true}, cv, dt, world)
			var apex := 0.0
			var air := 1
			while not s.grounded and air < 400:
				M.step(s, {"jump": true}, cv, dt, world)
				apex = maxf(apex, (s.position as Vector3).y)
				air += 1
			var probe_height: float = (s.position as Vector3).y
			# the same jump with no probe, to the plane crossing.
			var plane := M.FlatWorld.new()
			plane.probe = -1.0
			var p := _flat_state(hz)
			M.step(p, {"jump": true}, cv, dt, plane)
			var cross := 1
			while (p.position as Vector3).y > 0.0 and cross < 400:
				M.step(p, {}, cv, dt, plane)
				cross += 1
			var name := "%d_%s" % [hz, order]
			out[name] = {"apex_u": apex, "probe_landing_tick": air, "probe_landing_height_u": probe_height, "plane_crossing_tick": cross}
			var expected: Dictionary = oracle.get("ballistic", {}).get(str(hz), {}).get("source_standing_order" if order == "source2013" else "ideal", {})
			if not expected.is_empty():
				near("apex_" + name, apex, float(expected.sampled_apex_u), 1e-6)
				check("crossing_tick_" + name, cross == int(expected.first_nonpositive_height_tick), "%d vs %s" % [cross, expected.first_nonpositive_height_tick])
			check("held_jump_blocked_" + name, s.jump_count == 1, "jumps %d with jump held through landing" % s.jump_count)
	findings["ballistics"] = out

## standing start: w to 250 on the ground, release, then autohop with ideal side wish each
## air tick. no stamina. measured air updates per hop are reported beside the oracle's.
func hop_chains() -> void:
	var out := {}
	for config: Array in [[128, 100.0, "constant"], [128, 100.0, "deadstrafe"], [64, 12.0, "constant"], [64, 12.0, "deadstrafe"], [128, 12.0, "constant"], [64, 100.0, "constant"]]:
		var hz: int = config[0]
		var cv := cvars_for(hz, config[1], "legacy", config[2])
		out["%d_aa%d_%s" % config] = _hop_chain(cv, hz, 5, M.FlatWorld.new())
		var plane := M.FlatWorld.new()
		plane.probe = 0.0
		out["%d_aa%d_%s_noprobe" % config] = _hop_chain(cv, hz, 5, plane)
	findings["hop_chains"] = out
	var r: Dictionary = out["128_aa100_constant"]
	var formula := sqrt(250.0 * 250.0 + float(r.air_updates_total) * 30.0 * 30.0)
	near("hop_chain_128_aa100_matches_closed_form_for_measured_updates", r.landing_speeds[4], formula, 1e-6)
	var exact: Dictionary = out["128_aa100_constant_noprobe"]
	var predicted: Array = []
	for o: Dictionary in oracle.get("air_rows", []):
		if int(o.hz) == 128 and float(o.aa) == 100.0 and str(o.budget_mode).begins_with("legacy"):
			predicted = o.five_hops_source_standing_order.landing_speeds_u_s
	if not predicted.is_empty():
		near("hop5_128_aa100_plane_crossing_matches_oracle", exact.landing_speeds[4], float(predicted[4]), 1e-4)
	# the first hop leaves from a long run-up, so only the four later ones are first-tick hops.
	check("hop_chain_all_perfect", r.perfect == 4 and r.ground_walk_ticks == 0, r)

func _hop_chain(cv: Dictionary, hz: int, hops: int, world: Object) -> Dictionary:
	var dt := 1.0 / hz
	var s := _flat_state(hz)
	var runup := 0
	while (s.velocity as Vector3).length() < 250.0 - 1e-9:
		M.step(s, {"forward": 1.0, "yaw": 0.0}, cv, dt, world)
		runup += 1
	var landings := []
	var updates := []
	var heights := []
	var takeoffs := []
	var walk := 0
	var air := 0
	var peak := 0.0
	var side := -1.0
	while landings.size() < hops:
		var h := Vector3(s.velocity.x, 0, s.velocity.z)
		var dir := _optimal_dir(h, cv, dt, float(s.surface))
		var cmd := {"jump": true, "side": side, "yaw": M.yaw_for_side(dir, side)}
		var was_grounded: bool = s.grounded
		M.step(s, cmd, cv, dt, world)
		if was_grounded and not "jump" in s.events:
			walk += 1
		if "jump" in s.events:
			takeoffs.append(s.takeoff_speed)
		if not was_grounded or "jump" in s.events:
			air += 1
		peak = maxf(peak, s.position.y)
		if "land" in s.events:
			landings.append(Vector2(s.velocity.x, s.velocity.z).length())
			updates.append(air)
			heights.append(peak)
			air = 0
			peak = 0.0
	var total := 0
	for n: int in updates:
		total += n
	return {"runup_ticks": runup, "landing_speeds": landings, "air_updates": updates, "air_updates_total": total, "apex_u": heights, "takeoffs": takeoffs, "perfect": s.perfect_count, "ground_walk_ticks": walk}

## vanilla: manual press on the first ground tick only, 275 takeoff clamp, the stamina fit.
func vanilla() -> void:
	var cv := M.preset("csgo_vanilla")
	var hz := 64
	var dt := 1.0 / hz
	var world := M.FlatWorld.new()
	# the gokz observation fixture: walk at 250, one standing jump, land, keep walking.
	var s := _flat_state(hz)
	for i: int in 60:
		M.step(s, {"forward": 1.0}, cv, dt, world)
	M.step(s, {"forward": 1.0, "jump": true}, cv, dt, world)
	while not s.grounded:
		M.step(s, {"forward": 1.0}, cv, dt, world)
	var fall: float = s.fall_speed
	M.step(s, {"forward": 1.0}, cv, dt, world)
	var walk_after: float = Vector2(s.velocity.x, s.velocity.z).length()
	var stamina_then: float = s.stamina
	M.step(s, {"forward": 1.0, "jump": true}, cv, dt, world)
	var apex := 0.0
	while not s.grounded:
		M.step(s, {"forward": 1.0}, cv, dt, world)
		apex = maxf(apex, s.position.y)
	findings["vanilla_stamina_fixture"] = {"fall_speed": fall, "first_walk_speed": walk_after, "stamina": stamina_then, "next_apex_u": apex, "gokz_observed": {"first_walk_speed": 183.05, "next_apex_u": 40.0, "first_apex_u": 55.0}}
	check("vanilla_landing_slows_walk", walk_after < 200.0 and walk_after > 170.0, "%.3f u/s (gokz observed 183.05)" % walk_after)
	check("vanilla_next_jump_lower", apex < 45.0 and apex > 35.0, "%.3f u (gokz observed about 40)" % apex)
	# perfect-timed manual chain with ideal strafes: press only on each first ground tick.
	var chain := _flat_state(hz)
	for i: int in 60:
		M.step(chain, {"forward": 1.0}, cv, dt, world)
	var speeds := []
	var heights := []
	var side := -1.0
	var peak := 0.0
	var jumps := 0
	var t := 0
	var jump_next := true
	while speeds.size() < 6 and t < 5000:
		var h := Vector3(chain.velocity.x, 0, chain.velocity.z)
		var dir := _optimal_dir(h, cv, dt, float(chain.surface))
		M.step(chain, {"side": side, "yaw": M.yaw_for_side(dir, side), "jump": chain.grounded}, cv, dt, world)
		peak = maxf(peak, chain.position.y)
		if "land" in chain.events:
			speeds.append(Vector2(chain.velocity.x, chain.velocity.z).length())
			heights.append(peak)
			peak = 0.0
		t += 1
	findings["vanilla_perfect_chain_64"] = {"landing_speeds": speeds, "apex_u": heights, "jumps": chain.jump_count, "perfect": chain.perfect_count, "stamina_end": chain.stamina, "label": "reconstruction: 275 takeoff clamp and gokz-fit stamina; not an exact vanilla maximum"}
	check("vanilla_chain_takeoff_clamped", chain.takeoff_speed <= 275.0 + 1e-6, "last takeoff %.3f" % chain.takeoff_speed)
	# a held key in vanilla jumps once; a missed tick walks once and meets the ground clamp.
	var held := _flat_state(hz)
	held.velocity = Vector3(0, 0, -270.0)
	M.step(held, {"jump": true}, cv, dt, world)
	for i: int in 120:
		M.step(held, {"jump": true}, cv, dt, world)
	check("vanilla_held_jump_once", held.jump_count == 1, "jumps %d" % held.jump_count)
	var missed := _flat_state(hz)
	missed.velocity = Vector3(0, 0, -300.0)
	M.step(missed, {}, cv, dt, world)
	check("ground_clamp_on_walk", Vector2(missed.velocity.x, missed.velocity.z).length() <= 250.0 + 1e-6, Vector2(missed.velocity.x, missed.velocity.z).length())
	# switching into the server preset clears any penalty.
	var server := M.preset("csgo_server")
	check("server_clears_stamina", M.add_stamina(40.0, 0.0, server) == 0.0)

## no input in the air keeps horizontal velocity exactly, whatever the view does.
func retention() -> void:
	for name: String in ["csgo_vanilla", "csgo_server"]:
		var cv := M.preset(name)
		var dt := 1.0 / float(cv.tickrate)
		var s := _flat_state(cv.tickrate)
		s.velocity = Vector3(120.0, 0, -260.0)
		M.step(s, {"jump": true, "yaw": 0.3}, cv, dt, M.FlatWorld.new())
		var after_jump := Vector2(s.velocity.x, s.velocity.z)
		var same := true
		var yaw := 0.3
		while not s.grounded:
			yaw += 0.05
			M.step(s, {"yaw": yaw}, cv, dt, M.FlatWorld.new())
			same = same and Vector2(s.velocity.x, s.velocity.z).is_equal_approx(after_jump)
		check("air_release_retains_" + name, same, after_jump)

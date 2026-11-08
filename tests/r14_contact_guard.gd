extends SceneTree
## p / r14 source adapter missed-support guard (docs/r14/CONTACT-GUARD.md). every episode runs
## twice from one labelled setup, guard off (the unguarded adapter) and on, so each red/green
## pair differs only in `cast_guard`. groups:
##   minimal   the independent review's seed s4_runin_dir0_64_157
##   seeds     every exact-grid raw cast miss on the practice map's walkable pieces, 18 motions
##   snap_strip direct walk_move calls (the adapter's world function, not a full tick) at 250 u/s
##             across the s4_runin strip where normal-spawn routes lost or sank their snap
##   decisions direct calls on _missed_support against a prism fixture: floor, 30° ramp, wall,
##             both top-edge orders, 50° face, overlapping start, clear end
##   controls  full ticks on the fixture: walk off a ledge, drop onto 50°, air into a wall,
##             30° ramp walk, 18 u step; guard on must equal guard off unless it caught a miss
##   earned    keys and mouse only after a pose: autohop strafes from rest on the runway
##   earned_box the same kind of open-loop hops the independent source review drives, on its
##             20000 u single-box floor (an oversized box godot's sweeps are known to miss)
## godot --headless --audio-driver Dummy --fixed-fps 128 --path . \
##   --script res://tests/r14_contact_guard.gd -- --out=DIR [--only=minimal,seeds,...] [--earned=N]
const LEVEL := preload("res://scripts/r14_practice_level.gd")
const PLAYER := preload("res://scripts/r14_source_player.gd")
const MAIN := preload("res://scripts/spillway_main.gd")
const M := preload("res://scripts/r14_source_motion.gd")
const U: float = M.U
const GROUPS := ["minimal", "seeds", "snap_strip", "decisions", "controls", "earned", "earned_box"]
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE}
## the review's minimal seed, feet in metres and velocity in u/s before half gravity.
const MINIMAL_P := Vector3(-160.380096, 0.0754363, -93.280594)
const MINIMAL_V := Vector3(300.0, -291.75, 0.0)

signal episode_done

class Hook:
	extends Node
	var suite: Object
	var early := false
	func _physics_process(_dt: float) -> void:
		suite.call("pre" if early else "post")

var out := ""
var groups: Array = GROUPS.duplicate()
var earned_cases := 24
var box_cases := 24
var world: Node3D
var player: CharacterBody3D
var checks: Array[Dictionary] = []
var findings: Dictionary = {}
var spec: Dictionary = {}
var rows: Array[Dictionary] = []
var held: Dictionary = {}
var active := false
var frame := 0
var rng := RandomNumberGenerator.new()
var trace_budget := 40

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			groups = Array(arg.trim_prefix("--only=").split(","))
		elif arg.begins_with("--earned="):
			earned_cases = int(arg.trim_prefix("--earned="))
		elif arg.begins_with("--box="):
			box_cases = int(arg.trim_prefix("--box="))
	assert(out.is_absolute_path(), "contact guard: --out=DIR is required")
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out.path_join("traces"))
	MAIN.bind_inputs()
	for early: bool in [true, false]:
		var hook := Hook.new()
		hook.suite = self
		hook.early = early
		hook.process_physics_priority = -1000 if early else 1000
		root.add_child(hook)
	var map_groups := ["minimal", "seeds", "snap_strip", "earned"].filter(func(g: String) -> bool: return g in groups)
	if not map_groups.is_empty():
		world = LEVEL.new()
		root.add_child(world)
		world.call("build")
		findings["geometry"] = world.call("geometry_hash")
		await _settle()
		for group: String in map_groups:
			await call("group_" + group)
		await _drop_world()
	if "decisions" in groups or "controls" in groups:
		world = _fixture()
		root.add_child(world)
		await _settle()
		for group: String in ["decisions", "controls"]:
			if group in groups:
				await call("group_" + group)
		await _drop_world()
	if "earned_box" in groups:
		world = Node3D.new()
		var body := StaticBody3D.new()
		body.name = "floor"
		body.position = Vector3(0, -32, 0) * U
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(20000, 64, 20000) * U
		shape.shape = box
		body.add_child(shape)
		world.add_child(body)
		root.add_child(world)
		await _settle()
		await group_earned_box()
		await _drop_world()
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.pass)
	var summary := {"engine": Engine.get_version_info(), "groups": groups, "player_sha256": FileAccess.get_sha256("res://scripts/r14_source_player.gd"),
		"motion_sha256": FileAccess.get_sha256("res://scripts/r14_source_motion.gd"), "checks": checks, "findings": findings, "gates": checks.size(), "failed": failed.size()}
	var f := FileAccess.open(out.path_join("summary.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(plain(summary), "\t"))
	f.close()
	print("r14 contact guard: %d checks, %d failed; summary %s" % [checks.size(), failed.size(), out.path_join("summary.json")])
	for c: Dictionary in failed:
		print("FAIL ", c.name, ": ", c.detail)
	quit(0 if failed.is_empty() else 1)

func check(name: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"name": name, "pass": ok, "detail": str(detail)})
	print("%s %s %s" % ["ok  " if ok else "FAIL", name, str(detail)])

func _settle() -> void:
	await physics_frame
	await physics_frame

func _drop_world() -> void:
	if player != null:
		player.queue_free()
		player = null
	world.queue_free()
	await _settle()

# --- episodes ---------------------------------------------------------------------------------

## one labelled setup (preset, rate, pose, velocity, grounded flag), then motor steps only.
## returns {rows, guards}; rows carry the feet, velocity, contacts and the sink under the feet.
func run_episode(s: Dictionary, guard: bool) -> Dictionary:
	active = false
	for k: String in KEYS:
		key(k, false)
	if player != null:
		player.queue_free()
		await process_frame
	player = PLAYER.new()
	player.input_enabled = false
	root.add_child(player)
	var hz := int(s.get("hz", 128))
	player.call("apply_preset", str(s.get("preset", "csgo_server" if hz == 128 else "csgo_vanilla")))
	player.settings.tickrate = hz
	player.call("apply_engine_rate")
	player.set("cast_guard", guard)
	player.call("reset_to", Transform3D(Basis(Vector3.UP, float(s.get("yaw", 0.0))), s.p))
	player.velocity = (s.get("v_u", Vector3.ZERO) as Vector3) * U
	var grounded := bool(s.get("grounded", false))
	player.state.grounded = grounded
	player.state.ground_normal = Vector3.UP if grounded else Vector3.ZERO
	player.state.ground_ticks = 100 if grounded else 0
	spec = s
	rows = []
	frame = 0
	rng.seed = int(s.get("seed", 1))
	await physics_frame
	player.input_enabled = true
	active = true
	await episode_done
	return {"rows": rows, "guards": (player.get("cast_guards") as Dictionary).duplicate()}

func pre() -> void:
	if not active:
		return
	var want := {}
	match str(spec.get("policy", "release")):
		"walk":
			want.w = true
		"strafe":
			_strafe(want)
		"open":
			# open loop: W run-up, then held jump with a/d every quarter second and the mouse
			# turning the same way, plus a bounded wobble.
			var j := frame - int(spec.runup)
			if j < 0:
				want.w = true
			else:
				var hz := int(spec.hz)
				var left := (j / (hz / 4)) % 2 == 0
				want.space = true
				want["a" if left else "d"] = true
				mouse(roundf((-1.0 if left else 1.0) * float(spec.mouse) + sin(float(j) * 0.7) * 0.8))
	for k: String in KEYS:
		key(k, want.has(k))

## coordinate-aware strafe controller: ground W and jump (an edge each landing for vanilla), air
## alternate A/D every `period` ticks with the view following the travel heading, so the wish
## stays near perpendicular. integer mouse counts, bounded noise. not human play.
func _strafe(want: Dictionary) -> void:
	var grounded: bool = player.call("is_grounded")
	var autohop := int(spec.hz) == 128
	if grounded:
		want.w = true
		if autohop or not held.has("space"):
			want.space = true
		return
	var v := player.velocity
	if Vector2(v.x, v.z).length() < 0.01:
		return
	var heading := atan2(-v.x, -v.z)
	# every `period` air ticks, pick the side that turns travel toward the course heading -x,
	# bent back toward the runway's centre line z = -98 (a larger yaw heads further +z).
	var period := int(spec.get("period", 6))
	if int(player.state.air_ticks) % period == 1 or not spec.has("side"):
		var desired := PI / 2 + clampf(-(float(player.global_position.z) + 98.0) * 0.08, -0.5, 0.5)
		spec["side"] = -1.0 if wrapf(desired - heading, -PI, PI) > 0.0 else 1.0
	want["a" if float(spec.side) < 0.0 else "d"] = true
	# the view follows travel, so the side key wishes near perpendicular to it.
	var target := heading + deg_to_rad(rng.randf_range(-0.3, 0.3))
	var rpc := float(player.get("tape_radians_per_count"))
	mouse(roundf(wrapf(float(player.get("yaw")) - target, -PI, PI) / rpc))

func post() -> void:
	if not active:
		return
	var s: Dictionary = player.call("get_motion_state")
	var p := player.global_position
	var hit := ray(p + Vector3.UP * 0.8, p + Vector3.DOWN * 6.0)
	var top := float(hit.position.y) if not hit.is_empty() else -INF
	rows.append({"t": frame, "p": p, "v": player.velocity / U, "g": player.call("is_grounded"), "e": s.events, "contacts": s.contacts,
		"under": str((hit.collider as Node).name) if not hit.is_empty() else "", "sink": top - p.y if is_finite(top) else null, "guards": s.cast_guards, "support": s.support_normal})
	frame += 1
	var stop := frame >= int(spec.get("ticks", 8))
	if spec.has("stop_x") and p.x < float(spec.stop_x):
		stop = true
	if stop:
		active = false
		episode_done.emit()

## peak sink below the face under the feet, metres (only a face within 1 m above counts).
static func peak_sink(r: Array) -> float:
	var peak := 0.0
	for row: Dictionary in r:
		if row.sink != null and float(row.sink) > 0.0 and float(row.sink) < 1.0:
			peak = maxf(peak, float(row.sink))
	return peak

static func first_land(r: Array) -> int:
	for row: Dictionary in r:
		if "land" in row.e:
			return int(row.t)
	return -1

static func same_rows(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if (a[i].p as Vector3) != (b[i].p as Vector3) or (a[i].v as Vector3) != (b[i].v as Vector3) or a[i].g != b[i].g:
			return false
	return true

static func _first_difference(a: Array, b: Array) -> int:
	for i: int in mini(a.size(), b.size()):
		if (a[i].p as Vector3) != (b[i].p as Vector3) or (a[i].v as Vector3) != (b[i].v as Vector3):
			return i
	return mini(a.size(), b.size())

static func guard_total(g: Dictionary) -> int:
	return int(g.slide) + int(g.probe) + int(g.snap) + int(g.snap_late)

func save_trace(name: String, pair: Dictionary) -> void:
	if trace_budget <= 0:
		return
	trace_budget -= 1
	var lines := PackedStringArray()
	for guard: String in ["off", "on"]:
		for row: Dictionary in pair[guard].rows:
			var r := row.duplicate()
			r["guard"] = guard
			lines.append(JSON.stringify(plain(r)))
	var f := FileAccess.open(out.path_join("traces").path_join(name + ".jsonl.gz"), FileAccess.WRITE)
	f.store_buffer(("\n".join(lines) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	f.close()

## guard off, then on. `repeats` adds further unguarded runs after them: godot 4.7.2 can give
## the same setup two outcomes in successive episodes where two bodies touch the hull at once
## (a 0.3 mm split at the 50° wedge's foot), so on/off equality is judged against every run.
func pair(s: Dictionary, repeats := 0) -> Dictionary:
	var off := await run_episode(s, false)
	var on := await run_episode(s, true)
	var r := {"off": off, "on": on, "off_runs": [off]}
	for i: int in repeats:
		(r.off_runs as Array).append(await run_episode(s, false))
	return r

## true when the guarded rows equal one of the unguarded runs'.
static func matches_any(on: Array, runs: Array) -> bool:
	return runs.any(func(run: Dictionary) -> bool: return same_rows(on, run.rows))

static func runs_agree(runs: Array) -> bool:
	return runs.all(func(run: Dictionary) -> bool: return same_rows(runs[0].rows, run.rows))

# --- groups -----------------------------------------------------------------------------------

func group_minimal() -> void:
	var s := {"name": "minimal_s4_runin_dir0_64_157", "hz": 64, "p": MINIMAL_P, "v_u": MINIMAL_V, "ticks": 8}
	var r := await pair(s)
	save_trace(s.name, r)
	var off: Array = r.off.rows
	var on: Array = r.on.rows
	var requested_x := MINIMAL_V.x / 64.0 * U
	findings["minimal"] = {"off_tick0": off[0], "on_tick0": on[0], "off_sink": peak_sink(off), "on_sink": peak_sink(on), "off_land": first_land(off), "on_land": first_land(on), "on_guards": r.on.guards}
	check("minimal_red_unguarded_sinks", float(off[0].sink) > 0.04 and (off[0].contacts as Array).is_empty(), "tick-0 feet %.7f m, sink %.6f m, contacts %d" % [off[0].p.y, off[0].sink, off[0].contacts.size()])
	check("minimal_green_feet_on_deck", float(on[0].p.y) >= 0.0 and float(on[0].p.y) < 0.002 and peak_sink(on) <= 0.0, "tick-0 feet %.7f m, peak sink %.6f m" % [on[0].p.y, peak_sink(on)])
	check("minimal_green_lands_first_tick", first_land(on) == 0 and bool(on[0].g), "off lands tick %d, on tick %d" % [first_land(off), first_land(on)])
	check("minimal_green_keeps_horizontal", absf(float(on[0].v.x) - 300.0) < 1e-3 and absf(float(on[0].v.y)) < 1e-6, "tick-0 velocity %s u/s" % [on[0].v])
	check("minimal_green_travels_full_tick", absf(float(on[0].p.x - MINIMAL_P.x) - requested_x) < 2e-5, "x travel %.7f m, requested %.7f m" % [on[0].p.x - MINIMAL_P.x, requested_x])
	var guarded := (on[0].contacts as Array).filter(func(c: Dictionary) -> bool: return bool(c.get("guard", false)))
	check("minimal_green_contact_is_deck", not guarded.is_empty() and str(guarded[0].body) == "s4_runin" and (guarded[0].normal as Vector3).is_equal_approx(Vector3.UP), "guarded contacts %s" % [plain(guarded)])

## raw misses: from each interior grid point of every walkable piece, a hull placed so that each
## of 18 motions ends 1.69 u (64 Hz) or 1.69 u × 64/128 below the face; a seed is a motion whose
## real cast reports nothing. the 296 review seeds come from the same rule.
func group_seeds() -> void:
	var motions := {"review64": Vector3(24.8896732, -298.0066223, -299.7286072) / 64.0, "review128": Vector3(24.8896732, -298.0066223, -299.7286072) / 128.0}
	for i: int in 8:
		var h := Vector3(cos(deg_to_rad(45.0 * i)), 0, -sin(deg_to_rad(45.0 * i)))
		for rate: int in [64, 128]:
			motions["dir%d_%d" % [i * 45, rate]] = (h * (300.0 if rate == 64 else 1100.0) + Vector3(0, -298.0, 0)) / rate
	player = PLAYER.new()
	player.input_enabled = false
	root.add_child(player)
	await _settle()
	var seeds: Array = []
	var overlapping := 0
	for entry: Dictionary in world.get("manifest"):
		if (entry.get("points", []) as Array).is_empty():
			continue
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var top := -INF
		for p: Vector3 in entry.points:
			top = maxf(top, p.y)
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		var spacing := maxf(0.5, sqrt((hi.x - lo.x) * (hi.y - lo.y) / 600.0))
		var x := lo.x + 0.6
		while x <= hi.x - 0.6:
			var z := lo.y + 0.6
			while z <= hi.y - 0.6:
				var hit := ray(Vector3(x, top + 1.0, z), Vector3(x, top - 30.0, z))
				var interior: bool = not hit.is_empty() and str((hit.collider as Node).name) == str(entry.name) and hit.normal.y >= 0.7
				for offset: Vector2 in [Vector2(0.6, 0), Vector2(-0.6, 0), Vector2(0, 0.6), Vector2(0, -0.6)]:
					var side_hit := ray(Vector3(x + offset.x, top + 1.0, z + offset.y), Vector3(x + offset.x, top - 30.0, z + offset.y))
					interior = interior and not side_hit.is_empty() and str((side_hit.collider as Node).name) == str(entry.name) and side_hit.normal.y >= 0.7
				if interior:
					for name: String in motions:
						var m: Vector3 = motions[name]
						var pos: Vector3 = hit.position + Vector3.UP * (2.97 / (298.0066223 / 64.0)) * -m.y * U
						player.global_position = pos
						if player.move_and_collide(m * U, true, 0.001, true, 4) == null:
							if player.test_move(Transform3D(Basis.IDENTITY, pos), Vector3.ZERO, null, 0.0001, true, 1):
								overlapping += 1
								continue
							var rate := 64 if name.ends_with("64") else 128
							seeds.append({"name": "%s_%s_%d" % [entry.name, name, seeds.size()], "piece": str(entry.name), "face_normal": hit.normal, "p": pos, "hz": rate,
								"v_u": m * rate + Vector3.UP * 800.0 * 0.5 / rate, "ticks": 8})
				z += spacing
			x += spacing
	player.queue_free()
	player = null
	await process_frame
	var per_rate := {}
	var worst := {}
	var unguarded := []
	for s: Dictionary in seeds:
		var r := await pair(s)
		var off: Array = r.off.rows
		var on: Array = r.on.rows
		var key := str(s.hz)
		if not per_rate.has(key):
			per_rate[key] = {"seeds": 0, "off_sinking": 0, "off_peak_m": 0.0, "on_sinking": 0, "on_peak_m": 0.0, "on_first_tick_land": 0, "off_first_tick_land": 0,
				"on_flat_speed_kept": 0, "flat": 0, "guard_slide": 0, "guard_probe": 0, "guard_snap": 0, "guard_snap_late": 0, "declined": 0}
		var b: Dictionary = per_rate[key]
		b.seeds += 1
		var so := peak_sink(off)
		var sn := peak_sink(on)
		b.off_sinking += 1 if so > 0.001 else 0
		b.on_sinking += 1 if sn > 0.0001 else 0
		b.off_peak_m = maxf(b.off_peak_m, so)
		b.on_peak_m = maxf(b.on_peak_m, sn)
		b.on_first_tick_land += 1 if first_land(on) == 0 else 0
		b.off_first_tick_land += 1 if first_land(off) == 0 else 0
		for k: String in ["slide", "probe", "snap", "snap_late", "declined"]:
			b["guard_" + k if k != "declined" else k] += int(r.on.guards[k])
		if (s.face_normal as Vector3).y > 0.9999:
			b.flat += 1
			var vh := Vector2(float(s.v_u.x), float(s.v_u.z)).length()
			if first_land(on) == 0 and absf(Vector2(float(on[0].v.x), float(on[0].v.z)).length() - vh) < 1e-3:
				b.on_flat_speed_kept += 1
		if sn > 0.0001 or first_land(on) != 0:
			unguarded.append({"name": s.name, "on_sink": sn, "on_land": first_land(on), "guards": r.on.guards, "tick0_contacts": on[0].contacts.size()})
		if so > float(worst.get("off_sink", 0.0)):
			worst = {"name": s.name, "off_sink": so, "on_sink": sn}
		if s.name.begins_with("s4_runin_dir0_64") or so > 0.02 or sn > 0.0001 or first_land(on) != 0:
			save_trace("seed_" + str(s.name), r)
	findings["seeds"] = {"selected": seeds.size(), "skipped_overlapping_start": overlapping, "per_rate": per_rate, "worst_unguarded": worst, "on_exceptions": unguarded}
	var total := 0
	var off_sinking := 0
	var on_sinking := 0
	var on_late := 0
	for k: String in per_rate:
		total += int(per_rate[k].seeds)
		off_sinking += int(per_rate[k].off_sinking)
		on_sinking += int(per_rate[k].on_sinking)
		on_late += int(per_rate[k].seeds) - int(per_rate[k].on_first_tick_land)
	check("seeds_selected_both_rates", per_rate.has("64") and per_rate.has("128") and total > 100, "%d clear seeds, %d overlapping starts skipped, %s" % [total, overlapping, plain(per_rate)])
	check("seeds_red_unguarded_sinks", off_sinking > 0, "%d of %d sink more than 1 mm without the guard; worst %s" % [off_sinking, total, plain(worst)])
	check("seeds_green_no_sink", on_sinking == 0, "%d of %d sink more than 0.1 mm with the guard; exceptions %s" % [on_sinking, total, plain(unguarded.slice(0, 6))])
	check("seeds_green_land_first_tick", on_late == 0, "%d of %d land after tick 0 with the guard" % [on_late, total])
	var kept := 0
	var flat := 0
	for k: String in per_rate:
		kept += int(per_rate[k].on_flat_speed_kept)
		flat += int(per_rate[k].flat)
	check("seeds_green_flat_landing_keeps_horizontal", kept == flat, "%d of %d flat-face landings keep the requested horizontal speed to 1e-3 u/s" % [kept, flat])

func group_snap_strip() -> void:
	player = PLAYER.new()
	player.input_enabled = false
	root.add_child(player)
	player.call("apply_preset", "csgo_server")
	await _settle()
	var result := {}
	for guard: bool in [false, true]:
		player.set("cast_guard", guard)
		player.set("cast_guards", {"slide": 0, "probe": 0, "snap": 0, "snap_late": 0, "declined": 0})
		var samples := 0
		var dips := 0
		var worst := 0.0
		var high := 0.0
		var x := -161.0
		while x > -163.2:
			for z: float in [-91.59, -91.62, -91.74, -93.0, -95.0]:
				player.global_position = Vector3(x, 0.001, z)
				player.set("_depenetration", Vector3.ZERO)
				player.set("_standoff", Vector3.ZERO)
				player.set("_contacts", [] as Array[Dictionary])
				player.call("walk_move", {"velocity": Vector3(-250, 0, 2.7), "events": []}, 1.0 / 128.0)
				var y := float(player.global_position.y)
				samples += 1
				if y < 0.0:
					dips += 1
					worst = minf(worst, y)
				high = maxf(high, y)
			x -= 0.0007
		result["on" if guard else "off"] = {"samples": samples, "dips_below_face": dips, "lowest_feet_m": worst, "highest_feet_m": high, "guards": (player.get("cast_guards") as Dictionary).duplicate()}
	findings["snap_strip"] = result
	check("snap_strip_red_unguarded_dips", int(result.off.dips_below_face) > 0, plain(result.off))
	# the guard only lowers a missed snap onto the face; it never leaves a hull higher.
	check("snap_strip_green_no_dip", int(result.on.dips_below_face) == 0 and float(result.on.highest_feet_m) <= float(result.off.highest_feet_m) + 1e-6, plain(result.on))
	player.queue_free()
	player = null
	await process_frame

## prism fixture in metres, built like the practice map's pieces (ConvexPolygonShape3D).
func _fixture() -> Node3D:
	var n := Node3D.new()
	n.name = "GuardFixture"
	_prism(n, "deck", [Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(12, 0, 12), Vector3(-12, 0, 12)], -1.0)
	_prism(n, "catch", [Vector3(-40, -4, -40), Vector3(40, -4, -40), Vector3(40, -4, 40), Vector3(-40, -4, 40)], -5.0)
	# a 3 m block on the deck: side walls and a top edge.
	_prism(n, "block", [Vector3(2, 3, -5), Vector3(3, 3, -5), Vector3(3, 3, 5), Vector3(2, 3, 5)], 0.0)
	# an 18 u step.
	_prism(n, "step", [Vector3(-6, 18 * U, 4), Vector3(-2, 18 * U, 4), Vector3(-2, 18 * U, 8), Vector3(-2 - 4, 18 * U, 8)], 0.0)
	# wedges rising toward -z from z = -2 over 4 m of run: 30° walkable, 50° steep.
	for deg: float in [30.0, 50.0]:
		var x0 := -10.0 if deg < 40.0 else -5.0
		var h := 4.0 * tan(deg_to_rad(deg))
		_wedge(n, "ramp%d" % int(deg), x0, x0 + 3.0, -2.0, -6.0, h)
	return n

func _prism(parent: Node3D, label: String, top: Array, base: float) -> void:
	var points := PackedVector3Array()
	for p: Vector3 in top:
		points.append(p)
	for p: Vector3 in top:
		points.append(Vector3(p.x, base, p.z))
	_body(parent, label, points)

func _wedge(parent: Node3D, label: String, x0: float, x1: float, z0: float, z1: float, h: float) -> void:
	_body(parent, label, PackedVector3Array([Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x0, h, z1), Vector3(x1, h, z1), Vector3(x0, 0, z1), Vector3(x1, 0, z1)]))

func _body(parent: Node3D, label: String, points: PackedVector3Array) -> void:
	var body := StaticBody3D.new()
	body.name = label
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	shape.shape = hull
	body.add_child(shape)
	parent.add_child(body)

## the fixture wedge's surface height at z, metres.
static func wedge_y(deg: float, z: float) -> float:
	return (-2.0 - z) * tan(deg_to_rad(deg))

## feet position of a hull whose +x face is `gap` metres short of the plane x = `face_x`.
static func beside(face_x: float, gap: float, feet_y: float, z := 0.0) -> Vector3:
	return Vector3(face_x - gap - 16.0 * U, feet_y, z)

func group_decisions() -> void:
	player = PLAYER.new()
	player.input_enabled = false
	root.add_child(player)
	player.call("apply_preset", "csgo_server")
	await _settle()
	var half := 16.0 * U
	var cases := [
		# name, from (feet), motion (m), expected: accept / decline / none, expected normal y
		["clear_end", Vector3(0, 1.0, 0), Vector3(0.1, -0.1, 0), "none", 0.0],
		["floor_from_above", Vector3(-1, 0.05, 0), Vector3(0.1, -0.12, 0), "accept", 1.0],
		["ramp30_from_above", Vector3(-8.5, wedge_y(30.0, -4.0 - half) + 0.05, -4.0), Vector3(0, -0.15, 0), "accept", cos(deg_to_rad(30.0))],
		["wall_side", beside(2.0, 0.05, 0.5), Vector3(0.12, 0, 0), "decline", 0.0],
		["wall_side_descending", beside(2.0, 0.05, 0.5), Vector3(0.12, -0.05, 0), "decline", 0.0],
		["top_edge_side_first", beside(2.0, 0.03, 2.95), Vector3(0.10, 0.02, 0), "decline", 0.0],
		["top_edge_top_first", Vector3(2.0 - half + 0.10, 3.03, 0), Vector3(0.05, -0.08, 0), "accept", 1.0],
		["steep50_from_above", Vector3(-3.5, wedge_y(50.0, -4.0 - half) + 0.05, -4.0), Vector3(0, -0.3, 0), "decline", 0.0],
		["start_overlapping", Vector3(-1, -0.01, 0), Vector3(0.05, -0.05, 0), "decline", 0.0],
	]
	var results := []
	for c: Array in cases:
		var before: Dictionary = (player.get("cast_guards") as Dictionary).duplicate()
		var got: Dictionary = player.call("_missed_support", c[1], c[2], "slide")
		var after: Dictionary = player.get("cast_guards")
		var declined := int(after.declined) - int(before.declined)
		var kind := "accept" if not got.is_empty() else ("decline" if declined > 0 else "none")
		var normal_y := -1.0
		var detail := {"case": c[0], "kind": kind, "declined": declined}
		if not got.is_empty():
			var hit: KinematicCollision3D = got.hit
			for i: int in hit.get_collision_count():
				normal_y = maxf(normal_y, hit.get_normal(i).y)
			detail["fraction"] = got.fraction
			detail["normal_y"] = normal_y
			var touch := (c[1] as Vector3) + (c[2] as Vector3) * float(got.fraction)
			detail["touch_feet"] = touch
		results.append(detail)
		var ok: bool = kind == c[3] and (kind != "accept" or absf(normal_y - float(c[4])) < 1e-4)
		if c[0] == "floor_from_above" and kind == "accept":
			# feet stop within the test margin above the deck: fraction (0.05 - gap) / 0.12.
			var feet_y := 0.05 - 0.12 * float(got.fraction)
			ok = ok and feet_y >= 0.0 and feet_y <= 0.00011
			detail["touch_y"] = feet_y
		check("decision_" + str(c[0]), ok, plain(detail))
	findings["decisions"] = results
	player.queue_free()
	player = null
	await process_frame

## guard on must reproduce guard off exactly, with no guard firing, unless it caught a miss that
## left the unguarded run inside a face.
func group_controls() -> void:
	var cases := []
	for hz: int in [64, 128]:
		cases.append({"name": "ledge_walk_off_%d" % hz, "hz": hz, "p": Vector3(0, 0.0012, 9.0), "yaw": PI, "grounded": true, "policy": "walk", "ticks": hz * 3})
		cases.append({"name": "ledge_skim_fast_%d" % hz, "hz": hz, "p": Vector3(5.0, 0.3, 10.0), "v_u": Vector3(0, 0, 600), "ticks": hz * 2})
		cases.append({"name": "steep50_drop_%d" % hz, "hz": hz, "p": Vector3(-3.5, 4.2, -4.0), "ticks": hz * 2})
		cases.append({"name": "wall_air_%d" % hz, "hz": hz, "p": Vector3(0.5, 0.6, 0.0), "v_u": Vector3(400, 150, 120), "ticks": hz})
		cases.append({"name": "wall_air_fast_%d" % hz, "hz": hz, "p": Vector3(-2.0, 1.5, 0.0), "v_u": Vector3(1100, -100, 300), "ticks": hz})
		cases.append({"name": "ramp30_walk_%d" % hz, "hz": hz, "p": Vector3(-8.5, 0.0012, 0.5), "yaw": 0.0, "grounded": true, "policy": "walk", "ticks": hz * 2})
		cases.append({"name": "step18_walk_%d" % hz, "hz": hz, "p": Vector3(-4.0, 0.0012, 1.0), "yaw": PI, "grounded": true, "policy": "walk", "ticks": hz * 2})
		cases.append({"name": "floor_land_fast_%d" % hz, "hz": hz, "p": Vector3(-8.0, 1.0, 8.0), "v_u": Vector3(900, -500, -200), "ticks": hz})
	var out_rows := []
	for s: Dictionary in cases:
		var r := await pair(s, 2)
		# with no guard activity the code path is the unguarded one, so keep sampling unguarded
		# runs (up to six more) for the outcome the guarded run drew.
		var extra := 0
		while not matches_any(r.on.rows, r.off_runs) and guard_total(r.on.guards) == 0 and extra < 6:
			(r.off_runs as Array).append(await run_episode(s, false))
			extra += 1
		var same := matches_any(r.on.rows, r.off_runs)
		var reproducible := runs_agree(r.off_runs)
		var fired := guard_total(r.on.guards)
		# support never steeper than walkable, and an airborne tick never gains upward speed.
		var steep_support := 0
		var lifted := 0
		var previous: Dictionary = {}
		for row: Dictionary in r.on.rows:
			if bool(row.g) and (row.support as Vector3).y < 0.7:
				steep_support += 1
			if not previous.is_empty() and not bool(row.g) and not bool(previous.g) and float(row.v.y) > float(previous.v.y) + 1e-3:
				lifted += 1
			previous = row
		var detail := {"case": s.name, "identical": same, "off_reproducible": reproducible, "off_runs": (r.off_runs as Array).size(), "guards": r.on.guards, "off_sink": peak_sink(r.off.rows), "on_sink": peak_sink(r.on.rows), "end": r.on.rows[-1].p,
			"steep_support_ticks": steep_support, "airborne_lift_ticks": lifted, "grounded_ticks": r.on.rows.filter(func(row: Dictionary) -> bool: return row.g).size()}
		out_rows.append(detail)
		if not same:
			save_trace("control_" + str(s.name), r)
		# a decline leaves the sweep as the engine made it, so it is allowed; a catch must have
		# repaired a sink the unguarded run shows.
		var ok := (same and fired == 0) or (fired > 0 and peak_sink(r.off.rows) > 0.0002 and peak_sink(r.on.rows) <= 0.0001)
		ok = ok and steep_support == 0
		var decline_ticks := []
		var last := 0
		for row: Dictionary in r.on.rows:
			if int(row.guards.declined) > last:
				decline_ticks.append({"t": row.t, "p": row.p, "v": row.v, "contacts": (row.contacts as Array).map(func(c: Dictionary) -> String: return "%s %s" % [c.body, c.normal])})
				last = int(row.guards.declined)
		detail["declines"] = decline_ticks
		if str(s.name).begins_with("wall_air"):
			# a vertical wall clips the normal part only; it lifts nothing.
			ok = ok and lifted == 0
		if str(s.name).begins_with("ledge"):
			ok = ok and float(r.on.rows[-1].p.y) < -3.9
		check("control_" + str(s.name), ok, plain(detail))
	findings["controls"] = out_rows

## input-earned fast hops: keys and mouse only after a standing pose on the runway.
func group_earned() -> void:
	var chooser := RandomNumberGenerator.new()
	chooser.seed = 20261108
	var summary := {}
	var exceptions := []
	for i: int in earned_cases:
		var hz := 128 if i % 2 == 0 else 64
		var s := {"name": "earned_%02d_%d" % [i, hz], "hz": hz, "p": Vector3(chooser.randf_range(-30.0, -22.0), 0.0012, chooser.randf_range(-100.0, -96.0)), "yaw": PI / 2 + chooser.randf_range(-0.1, 0.1),
			"grounded": true, "policy": "strafe", "period": chooser.randi_range(3, 9), "seed": chooser.randi(), "ticks": hz * 14, "stop_x": -157.0}
		var r := await pair(s)
		# a difference with no guard catch gets two more unguarded runs to tell engine variance.
		if not same_rows(r.off.rows, r.on.rows) and guard_total(r.on.guards) == 0:
			for k: int in 2:
				(r.off_runs as Array).append(await run_episode(s, false))
		var key := str(hz)
		if not summary.has(key):
			summary[key] = {"episodes": 0, "identical": 0, "landings": 0, "max_speed_u": 0.0, "max_landing_speed_u": 0.0, "guard_slide": 0, "guard_probe": 0, "guard_snap": 0, "guard_snap_late": 0, "declined": 0, "off_peak_sink_m": 0.0, "on_peak_sink_m": 0.0}
		var b: Dictionary = summary[key]
		b.episodes += 1
		var same := same_rows(r.off.rows, r.on.rows)
		b.identical += 1 if same else 0
		var variance := not runs_agree(r.off_runs) or matches_any(r.on.rows, r.off_runs)
		for row: Dictionary in r.on.rows:
			var sp := Vector2(float(row.v.x), float(row.v.z)).length()
			b.max_speed_u = maxf(b.max_speed_u, sp)
			if "land" in row.e:
				b.landings += 1
				b.max_landing_speed_u = maxf(b.max_landing_speed_u, sp)
		for k: String in ["slide", "probe", "snap", "snap_late", "declined"]:
			b["guard_" + k if k != "declined" else k] += int(r.on.guards[k])
		b.off_peak_sink_m = maxf(b.off_peak_sink_m, peak_sink(r.off.rows))
		b.on_peak_sink_m = maxf(b.on_peak_sink_m, peak_sink(r.on.rows))
		if not same:
			exceptions.append({"name": s.name, "guards": r.on.guards, "off_sink": peak_sink(r.off.rows), "on_sink": peak_sink(r.on.rows), "off_ticks": r.off.rows.size(), "on_ticks": r.on.rows.size(),
				"engine_variance": variance, "first_difference": _first_difference(r.off.rows, r.on.rows)})
			save_trace(str(s.name), r)
		elif i < 2:
			save_trace(str(s.name), r)
	findings["earned"] = {"per_rate": summary, "differing": exceptions}
	var on_peak := 0.0
	var fast := 0.0
	for k: String in summary:
		on_peak = maxf(on_peak, float(summary[k].on_peak_sink_m))
		fast = maxf(fast, float(summary[k].max_landing_speed_u))
	check("earned_fast_landings_reached", fast > 600.0, "fastest landing %.1f u/s; %s" % [fast, plain(summary)])
	check("earned_green_no_sink", on_peak <= 0.0001, "peak sink with the guard %.6f m" % on_peak)
	var unexplained := exceptions.filter(func(e: Dictionary) -> bool: return guard_total(e.guards) == 0 and not bool(e.engine_variance))
	check("earned_differences_only_from_guard", unexplained.is_empty(), "%d differing episodes, %d without a guard catch: %s" % [exceptions.size(), unexplained.size(), plain(exceptions.slice(0, 6))])

func group_earned_box() -> void:
	var chooser := RandomNumberGenerator.new()
	chooser.seed = 51108
	var per_rate := {}
	var sinking := []
	for i: int in box_cases:
		var hz := 64 if i % 2 == 0 else 128
		var s := {"name": "box_%02d_%d" % [i, hz], "hz": hz, "preset": "csgo_server", "p": Vector3(chooser.randf_range(-2000, 2000), 0.5, chooser.randf_range(-2000, 2000)) * U,
			"yaw": chooser.randf_range(-PI, PI), "grounded": true, "policy": "open", "runup": hz * 5 / 8, "mouse": chooser.randf_range(3.0, 6.0) * 128.0 / hz, "ticks": hz * 5 / 8 + hz * 2}
		var r := await pair(s)
		var key := str(hz)
		if not per_rate.has(key):
			per_rate[key] = {"episodes": 0, "off_sinking": 0, "off_peak_m": 0.0, "on_sinking": 0, "on_peak_m": 0.0, "guard_slide": 0, "guard_probe": 0, "guard_snap": 0, "guard_snap_late": 0, "declined": 0, "max_speed_u": 0.0}
		var b: Dictionary = per_rate[key]
		b.episodes += 1
		var so := peak_sink(r.off.rows)
		var sn := peak_sink(r.on.rows)
		b.off_sinking += 1 if so > 0.001 else 0
		b.on_sinking += 1 if sn > 0.0001 else 0
		b.off_peak_m = maxf(b.off_peak_m, so)
		b.on_peak_m = maxf(b.on_peak_m, sn)
		for k: String in ["slide", "probe", "snap", "snap_late", "declined"]:
			b["guard_" + k if k != "declined" else k] += int(r.on.guards[k])
		for row: Dictionary in r.on.rows:
			b.max_speed_u = maxf(b.max_speed_u, Vector2(float(row.v.x), float(row.v.z)).length())
		if so > 0.001 or sn > 0.0001:
			sinking.append({"name": s.name, "start_u": (s.p as Vector3) / U, "off_sink_m": so, "on_sink_m": sn, "guards": r.on.guards, "off_land_ticks": r.off.rows.filter(func(row: Dictionary) -> bool: return "land" in row.e).size(),
				"on_land_ticks": r.on.rows.filter(func(row: Dictionary) -> bool: return "land" in row.e).size()})
			save_trace(str(s.name), r)
	findings["earned_box"] = {"per_rate": per_rate, "sinking": sinking}
	var off_total := 0
	var on_total := 0
	for k: String in per_rate:
		off_total += int(per_rate[k].off_sinking)
		on_total += int(per_rate[k].on_sinking)
	check("earned_box_red_unguarded_sinks", off_total > 0, "%d unguarded episodes sink more than 1 mm; %s" % [off_total, plain(per_rate)])
	check("earned_box_green_no_sink", on_total == 0, "%d guarded episodes sink more than 0.1 mm; %s" % [on_total, plain(sinking.slice(0, 6))])

# --- io -----------------------------------------------------------------------------------------

func key(k: String, down: bool) -> void:
	if held.has(k) == down:
		return
	var e := InputEventKey.new()
	e.keycode = KEYS[k]
	e.physical_keycode = KEYS[k]
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	if down:
		held[k] = true
	else:
		held.erase(k)

func mouse(count: float) -> void:
	if count == 0.0:
		return
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(count, 0)
	e.screen_relative = e.relative
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	if player != null:
		q.exclude = [player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(q)

static func plain(v: Variant) -> Variant:
	if v is Vector3:
		return [v.x, v.y, v.z]
	if v is Vector2:
		return [v.x, v.y]
	if v is Dictionary:
		var d := {}
		for k: Variant in v:
			d[str(k)] = plain(v[k])
		return d
	if v is Array:
		return v.map(plain)
	if v is float and not is_finite(v):
		return str(v)
	return v

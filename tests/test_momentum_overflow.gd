extends SceneTree
## p / overflow geometry checks: envelope, collision tops and normals, flush running joins,
## ordinary gap clearance from the shared run/jump envelope, supported rails, and walking
## connectivity from every catch surface to the finish. no motor runs here; routes are
## driven by tests/momentum_overflow_driver.gd and tools/momentum-tape.py.
## godot --headless --path . --script res://tests/test_momentum_overflow.gd -- [--out=DIR]
##   [--worlds=course,block,block_mirror,block_offset] [--freeze]
## --freeze writes each variant's geometry manifest and hash to DIR before any profile runs.

const LEVEL := preload("res://scripts/momentum_overflow_level.gd")
const RUN := 8.5
const JUMP := 7.2
const GRAVITY := 20.0
## p / ordinary gaps must clear at run speed with the jump pressed this early and this much
## landing margin past the far edge (the body radius is 0.3 m).
const EARLY := 0.25
const LANDING := 0.5
const WALKABLE := 0.6946583 # cos 46 degrees
const STEP := 0.5

var out_dir := ""
var worlds := ["course", "block", "block_mirror", "block_offset"]
var freeze := false
var failures: Array[String] = []
var report := {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--worlds="):
			worlds = Array(arg.trim_prefix("--worlds=").split(","))
		elif arg == "--freeze":
			freeze = true
	_run.call_deferred()

func _run() -> void:
	for world: String in worlds:
		LEVEL.next_variant = world
		var level: Node3D = LEVEL.new()
		root.add_child(level)
		level.call("build")
		await physics_frame
		await physics_frame
		report[world] = _check(world, level)
		level.queue_free()
		await process_frame
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir)
		var file := FileAccess.open(out_dir.path_join("geometry-report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"failures": failures, "worlds": report}, " "))
		file.close()
	for failure: String in failures:
		printerr("FAIL: ", failure)
	print("overflow geometry: %d worlds, %d failures" % [worlds.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _check(world: String, level: Node3D) -> Dictionary:
	var result := {"geometry_hash": level.call("geometry_hash"), "pieces": (level.get("manifest") as Array).size()}
	if freeze and not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir.path_join("freeze"))
		var file := FileAccess.open(out_dir.path_join("freeze/%s.json" % world), FileAccess.WRITE)
		file.store_string(JSON.stringify({"variant": world, "geometry_hash": result.geometry_hash, "pieces": level.call("geometry_manifest")}, " "))
		file.close()
	_envelope(world, level)
	result["tops"] = _tops(world, level)
	result["gaps"] = _gaps(world, level)
	result["rails"] = _rails(world, level)
	result["connectivity"] = _connectivity(world, level)
	print("%s: hash %s, %d pieces, gaps %s" % [world, str(result.geometry_hash).substr(0, 12), result.pieces, JSON.stringify(result.gaps)])
	return result

func _fail(world: String, message: String) -> void:
	failures.append("%s: %s" % [world, message])

func _envelope(world: String, level: Node3D) -> void:
	# p / inherited main recovery limits: everything reachable stays inside them with catch
	# surfaces above the floor limit.
	var poses: Array = [level.get("spawn")]
	for point: Dictionary in level.get("checkpoints"):
		poses.append(point.pose)
	for pose: Transform3D in poses:
		if not _inside(pose.origin):
			_fail(world, "pose %s outside the recovery envelope" % pose.origin)
	for piece: Dictionary in level.get("manifest"):
		if piece.role in ["route", "catch", "recovery", "baffle"]:
			for p: Vector3 in (piece.points as Array).slice(0, 4):
				if not _inside(p) or p.y < -7.5:
					_fail(world, "%s top %s outside the envelope" % [piece.name, p])

func _inside(p: Vector3) -> bool:
	return p.y > -8.3 and absf(p.x) < 180.0 and p.z > -400.0 and p.z < 60.0

func _tops(world: String, level: Node3D) -> Dictionary:
	# every walkable top is where its prism says, walkable, and smooth: sample a grid and
	# compare the ray hit with the top plane through the prism's first three corners.
	var checked := 0
	var steepest := 0.0
	for piece: Dictionary in level.get("manifest"):
		if not piece.role in ["route", "catch", "recovery", "baffle"]:
			continue
		var top: Array = (piece.points as Array).slice(0, 4)
		var c0: Vector3 = top[0]
		var normal: Vector3 = ((top[1] as Vector3) - c0).cross((top[2] as Vector3) - c0).normalized()
		if normal.y < 0.0:
			normal = -normal
		steepest = maxf(steepest, rad_to_deg(acos(normal.y)))
		if normal.y < WALKABLE:
			_fail(world, "%s top is not walkable (%.1f degrees)" % [piece.name, rad_to_deg(acos(normal.y))])
		for u: float in [0.15, 0.5, 0.85]:
			for v: float in [0.15, 0.5, 0.85]:
				var a: Vector3 = (top[0] as Vector3).lerp(top[1], u)
				var b: Vector3 = (top[3] as Vector3).lerp(top[2], u)
				var p := a.lerp(b, v)
				var hit := _ray(level, p + Vector3.UP * 0.3, p + Vector3.DOWN * 0.3)
				checked += 1
				if hit.is_empty() or absf((hit.position as Vector3).y - p.y) > 0.002:
					_fail(world, "%s top at %s: hit %s" % [piece.name, p, hit.get("position")])
				elif (hit.normal as Vector3).dot(normal) < 0.9999:
					_fail(world, "%s normal at %s is %s, expected %s" % [piece.name, p, hit.normal, normal])
	return {"samples": checked, "steepest_degrees": snappedf(steepest, 0.01)}

func _gaps(world: String, level: Node3D) -> Array:
	# walk the ordinary line in 5 cm steps. a lip is any step up the surface does not explain;
	# a gap is where the support drops more than 0.5 m and returns. each gap is judged from
	# the shared envelope: run speed, jump speed, gravity, an early press and a landing margin.
	var route: Array = (level.get("routes") as Dictionary).get("ordinary", [])
	var gaps: Array = []
	var previous: Dictionary = {}
	var gap_start: Dictionary = {}
	var lips := 0
	for i: int in route.size() - 1:
		var a: Vector3 = route[i]
		var b: Vector3 = route[i + 1]
		var flat := Vector2(b.x - a.x, b.z - a.z)
		var n := int(ceil(flat.length() / 0.05))
		for k: int in n:
			var q := a.lerp(b, float(k) / n)
			var hit := _ray(level, Vector3(q.x, 30.0, q.z), Vector3(q.x, -6.0, q.z))
			if hit.is_empty():
				_fail(world, "no surface under the ordinary line at %s" % q)
				continue
			var role := str((hit.collider as Node).get_meta("surface", ""))
			if not previous.is_empty():
				var dy: float = (hit.position as Vector3).y - (previous.position as Vector3).y
				var step: Vector3 = (hit.position as Vector3) - (previous.position as Vector3)
				var normal: Vector3 = previous.normal
				var expected := -(normal.x * step.x + normal.z * step.z) / normal.y
				if dy < -0.5 and gap_start.is_empty():
					gap_start = previous
				elif dy > 0.5 and not gap_start.is_empty():
					gaps.append(_judge_gap(world, gap_start, hit))
					gap_start = {}
				elif gap_start.is_empty() and role != "wall" and absf(dy - expected) > 0.01 and dy > 0.0:
					lips += 1
					_fail(world, "lip of %.3f m on the ordinary line at %s" % [dy - expected, hit.position])
			previous = hit
	if lips == 0 and gaps.is_empty() and world == "course":
		_fail(world, "no gaps found on the ordinary line")
	return gaps

func _judge_gap(world: String, from: Dictionary, to: Dictionary) -> Dictionary:
	var a: Vector3 = from.position
	var b: Vector3 = to.position
	var distance := Vector2(b.x - a.x, b.z - a.z).length()
	var drop := a.y - b.y
	var flight := (JUMP + sqrt(JUMP * JUMP + 2.0 * GRAVITY * maxf(drop, -JUMP * JUMP / (2.0 * GRAVITY)))) / GRAVITY
	var reach := RUN * flight
	var spare := reach - distance - LANDING
	var verdict := {"at": [snappedf(a.x, 0.01), snappedf(a.z, 0.01)], "distance": snappedf(distance, 0.01), "drop": snappedf(drop, 0.01),
		"perfect_speed": snappedf(distance / flight, 0.01), "reach_at_run": snappedf(reach, 0.01), "early_tolerance_s": snappedf(spare / RUN, 0.001)}
	if spare / RUN < EARLY:
		_fail(world, "gap at %s: %.2f m, %.2f m drop leaves %.3f s early tolerance at run speed" % [a, distance, drop, spare / RUN])
	return verdict

func _rails(world: String, level: Node3D) -> Dictionary:
	# each kit rail's post foot stands on a deck and its proxy does not hang below it.
	var count := 0
	for piece: Dictionary in level.get("manifest"):
		if piece.role != "rail":
			continue
		count += 1
		var foot: Vector3 = piece.foot
		var hit := _ray(level, foot + Vector3.UP * 0.05, foot + Vector3.DOWN * 0.2, true)
		if hit.is_empty() or absf((hit.position as Vector3).y - foot.y) > 0.02:
			_fail(world, "%s foot %s is not on a deck (%s)" % [piece.name, foot, hit.get("position")])
		var lowest := INF
		for p: Vector3 in piece.points:
			lowest = minf(lowest, p.y)
		if lowest < foot.y - 0.01:
			_fail(world, "%s proxy hangs %.3f m below its foot" % [piece.name, foot.y - lowest])
	return {"rails": count}

func _connectivity(world: String, level: Node3D) -> Dictionary:
	# walking only: a 0.5 m grid of walkable tops joined where neighbours differ by under 6 cm.
	# every catch surface must walk to the finish; the ordinary line needs its hops.
	var tops := {}
	var bounds := AABB(Vector3(-50, -2, -160), Vector3(65, 30, 222))
	if world != "course":
		bounds = AABB(Vector3(-50, -2, -70), Vector3(100, 20, 80))
	var nx := int(bounds.size.x / STEP)
	var nz := int(bounds.size.z / STEP)
	for i: int in nx:
		for j: int in nz:
			var x := bounds.position.x + (i + 0.5) * STEP
			var z := bounds.position.z + (j + 0.5) * STEP
			var hit := _ray(level, Vector3(x, 30, z), Vector3(x, -6, z))
			if hit.is_empty() or (hit.normal as Vector3).y < WALKABLE:
				continue
			var role := str((hit.collider as Node).get_meta("surface", ""))
			if role in ["wall", "solid", "scenery", ""]:
				continue
			tops[Vector2i(i, j)] = {"y": (hit.position as Vector3).y, "role": role, "p": hit.position}
	var finish: AABB = level.get("_finish_box")
	var goal: Array = []
	for key: Vector2i in tops:
		if finish.grow(0.01).has_point(tops[key].p + Vector3.UP * 0.05):
			goal.append(key)
	if goal.is_empty():
		_fail(world, "no walkable surface inside the finish")
		return {}
	# flood backwards from the finish.
	var reached := {}
	var queue: Array = goal.duplicate()
	for key: Vector2i in goal:
		reached[key] = true
	while not queue.is_empty():
		var key: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var other := key + d
			# walking from `other` to `key`: any drop off a ledge, or a climb a slope allows
			# (36 degrees rises under 0.37 m per cell); a hop never counts.
			if tops.has(other) and not reached.has(other) and float(tops[key].y) - float(tops[other].y) < STEP * tan(deg_to_rad(36.0)) + 0.01:
				reached[other] = true
				queue.append(other)
	var stranded := {}
	var counts := {}
	for key: Vector2i in tops:
		var role: String = tops[key].role
		counts[role] = int(counts.get(role, 0)) + 1
		if not reached.has(key):
			stranded[role] = int(stranded.get(role, 0)) + 1
	for role: String in ["catch", "recovery"]:
		if int(stranded.get(role, 0)) > 0:
			_fail(world, "%d %s cells cannot walk to the finish" % [stranded[role], role])
	var spawn: Vector3 = (level.get("spawn") as Transform3D).origin
	var spawn_key := Vector2i(int((spawn.x - bounds.position.x) / STEP), int((spawn.z - bounds.position.z) / STEP))
	return {"cells": counts, "not_walkable_to_finish": stranded, "spawn_walks_to_finish": reached.has(spawn_key)}

func _ray(level: Node3D, from: Vector3, to: Vector3, include_walls := false) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := level.get_world_3d().direct_space_state.intersect_ray(query)
	if not include_walls and not hit.is_empty() and str((hit.collider as Node).get_meta("surface", "")) == "rail":
		query.exclude = [hit.rid]
		hit = level.get_world_3d().direct_space_state.intersect_ray(query)
	return hit

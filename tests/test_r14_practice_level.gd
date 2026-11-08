extends SceneTree
## p / r14 practice level checks. no motor runs here: these are geometry, interface and
## dimension checks, so they show what the layout allows, not how a jump plays.
##   identity and interface: every overflow level field and method the r13 consumers read,
##     stable unique piece names, a hash that repeats across builds.
##   envelope and tops: walkable source-style tops (normal y >= 0.7) where each prism says.
##   gaps: every declared gap is a real edge-to-edge gap in the collision, at its declared
##     width, and the declared tiers hold (basic clears at a vanilla run, advanced cannot).
##   walking: every pit walks back to its gap's take-off deck, and no gap can be walked round
##     except the pump bend's notch, whose inside band is its declared walkable alternative.
##   consumer: the actual r13 overflow main hosts the level (hud, audio, art, progress).
## godot --headless --path . --script res://tests/test_r14_practice_level.gd -- [--out=DIR]

const LEVEL := preload("res://scripts/r14_practice_level.gd")
const R13_MAIN := preload("res://scripts/momentum_overflow_main.gd")
## p / source walkable floors (normal y 0.7, 45.57 degrees) and the 18 u step.
const WALKABLE := 0.7
const STEP_UP := 18.0 * 0.0254
const CELL := 0.5
const GRID := AABB(Vector3(-260, -6, -170), Vector3(280, 20, 190))

var out_dir := ""
var failures: Array[String] = []
var report := {}
var checks := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	_run.call_deferred()

func _check(name: String, ok: bool, detail: Variant = "") -> void:
	checks += 1
	if not ok:
		failures.append("%s: %s" % [name, str(detail)])

func _run() -> void:
	var level: Node3D = LEVEL.new()
	root.add_child(level)
	level.call("build")
	await physics_frame
	await physics_frame
	var again: Node3D = LEVEL.new()
	again.call("build")
	_check("hash repeats across builds", str(again.call("geometry_hash")) == str(level.call("geometry_hash")))
	again.free()
	report["identity"] = _identity(level)
	report["envelope"] = _envelope(level)
	report["tops"] = _tops(level)
	report["gaps"] = _gaps(level)
	report["walking"] = _walking(level)
	var manifest: Dictionary = level.call("course_manifest")
	level.queue_free()
	await process_frame
	report["consumer"] = await _consumer()
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir)
		var file := FileAccess.open(out_dir.path_join("course-manifest.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest, " "))
		file.close()
		file = FileAccess.open(out_dir.path_join("level-report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "report": report}, " "))
		file.close()
	for failure: String in failures:
		printerr("FAIL: ", failure)
	print("r14 practice level: %d checks, %d failures, hash %s, %d pieces" % [checks, failures.size(), str(manifest.geometry_hash).left(12), manifest.pieces])
	quit(1 if not failures.is_empty() else 0)

# --- identity and interface -------------------------------------------------------------------

func _identity(level: Node3D) -> Dictionary:
	for field: String in ["spawn", "checkpoints", "segment_bounds", "finish_position", "finish_radius", "water_regions", "water_audio_sources", "routes", "jump_gaps", "kill_bounds", "manifest", "variant", "material_mode", "level_id", "level_name", "level_version", "finish_title"]:
		_check("field " + field, field in level)
	for method: String in ["build", "is_finish_at", "segment_at", "route_hint", "start_wheel", "reset_state", "geometry_manifest", "geometry_hash", "course_manifest"]:
		_check("method " + method, level.has_method(method))
	_check("spawn is a transform", level.get("spawn") is Transform3D)
	_check("kill bounds is an aabb", level.get("kill_bounds") is AABB)
	var names := {}
	for piece: Dictionary in level.get("manifest"):
		_check("unique piece " + str(piece.name), not names.has(piece.name))
		names[piece.name] = true
		_check("stable name " + str(piece.name), str(piece.name).begins_with("s") and str(piece.name).substr(2, 1) == "_")
	var points: Array = level.get("checkpoints")
	var titles: Array = []
	for i: int in points.size():
		var point: Dictionary = points[i]
		titles.append(point.title)
		_check("checkpoint %d has a pose" % i, point.get("pose") is Transform3D)
		if i > 0:
			_check("checkpoint %d is collected by standing only" % i, float(point.get("radius", 5.0)) == 0.0 and not point.has("bounds"))
			var decks := 0
			for piece: Dictionary in level.get("manifest"):
				decks += 1 if int(piece.stage) == i and piece.role == "route" else 0
			_check("checkpoint %d has stage decks" % i, decks > 0, decks)
		var hit := _ray(level, (point.pose as Transform3D).origin + Vector3.UP * 0.5, (point.pose as Transform3D).origin + Vector3.DOWN * 0.5)
		_check("checkpoint %d stands on a deck" % i, not hit.is_empty() and absf((hit.position as Vector3).y - (point.pose as Transform3D).origin.y) < 0.06 and str(hit.collider.get_meta("surface", "")) == "route", hit.get("position"))
		var forward := -(point.pose as Transform3D).basis.z
		var ahead := _ray(level, (point.pose as Transform3D).origin + forward * 3.0 + Vector3.UP * 0.5, (point.pose as Transform3D).origin + forward * 3.0 + Vector3.DOWN * 0.5)
		_check("checkpoint %d faces along its deck" % i, not ahead.is_empty() and str(ahead.collider.get_meta("surface", "")) == "route", forward)
	var finish: Vector3 = level.get("finish_position")
	_check("finish position stands on the platform", not _ray(level, finish + Vector3.UP * 0.5, finish + Vector3.DOWN * 0.5).is_empty())
	_check("finish band is on the basic and advanced lines", level.call("is_finish_at", ((level.get("routes") as Dictionary).basic as Array)[-2] + Vector3.UP * 0.05) and level.call("is_finish_at", ((level.get("routes") as Dictionary).advanced as Array)[-2] + Vector3.UP * 0.05))
	_check("finish not at spawn", not level.call("is_finish_at", (level.get("spawn") as Transform3D).origin))
	var hints := {}
	for i: int in points.size():
		hints[str(level.call("route_hint", i, ((points[i] as Dictionary).pose as Transform3D).origin))] = true
	_check("each stage has its own hint", hints.size() == points.size(), hints.keys())
	return {"level_id": level.get("level_id"), "version": level.get("level_version"), "pieces": names.size(), "stages": titles, "hash": level.call("geometry_hash")}

# --- envelope and tops ------------------------------------------------------------------------

func _envelope(level: Node3D) -> Dictionary:
	var kill: AABB = level.get("kill_bounds")
	var lowest := INF
	for piece: Dictionary in level.get("manifest"):
		if piece.role in ["route", "catch", "recovery"]:
			for p: Vector3 in (piece.points as Array).slice(0, 4):
				lowest = minf(lowest, p.y)
				_check("%s inside the kill envelope" % piece.name, kill.has_point(p) and p.y > kill.position.y + 1.5, p)
	return {"lowest_walkable_m": lowest, "kill_floor_m": kill.position.y}

func _tops(level: Node3D) -> Dictionary:
	var checked := 0
	var steepest := 0.0
	for piece: Dictionary in level.get("manifest"):
		if not piece.role in ["route", "catch", "recovery"]:
			continue
		var top: Array = (piece.points as Array).slice(0, 4)
		var c0: Vector3 = top[0]
		var normal: Vector3 = ((top[1] as Vector3) - c0).cross((top[2] as Vector3) - c0).normalized()
		if normal.y < 0.0:
			normal = -normal
		var planar := absf(normal.dot((top[3] as Vector3) - c0)) < 0.002
		_check("%s top is planar" % piece.name, planar)
		steepest = maxf(steepest, rad_to_deg(acos(normal.y)))
		_check("%s top is walkable" % piece.name, normal.y >= WALKABLE, rad_to_deg(acos(normal.y)))
		for u: float in [0.15, 0.5, 0.85]:
			for v: float in [0.15, 0.5, 0.85]:
				var p := (top[0] as Vector3).lerp(top[1], u).lerp((top[3] as Vector3).lerp(top[2], u), v)
				var hit := _ray(level, p + Vector3.UP * 0.3, p + Vector3.DOWN * 0.3)
				checked += 1
				_check("%s top at %s" % [piece.name, p], not hit.is_empty() and absf((hit.position as Vector3).y - p.y) < 0.003 and (hit.normal as Vector3).dot(normal) > 0.9999, hit.get("position"))
	return {"samples": checked, "steepest_degrees": snappedf(steepest, 0.01)}

# --- gaps ------------------------------------------------------------------------------------

func _gaps(level: Node3D) -> Array:
	# walk each declared line in 1 cm steps from 1 m before the edge to 1 m past the landing:
	# the measured gap is where no surface lies within 0.9 m below the take-off height.
	var results: Array = []
	var basic_sections := {}
	for gap: Dictionary in level.get("jump_gaps"):
		var edge: Vector3 = gap.edge
		var land: Vector3 = gap.land
		var flat := Vector3(land.x - edge.x, 0, land.z - edge.z)
		var along := flat.normalized()
		var length := flat.length()
		var start := -1.0
		var finish := -1.0
		var s := -1.0
		while s <= length + 1.0:
			var q := edge + along * s
			var hit := _ray(level, Vector3(q.x, edge.y + 3.0, q.z), Vector3(q.x, -8.0, q.z))
			var y := (hit.position as Vector3).y if not hit.is_empty() else -INF
			var role := str(hit.collider.get_meta("surface", "")) if not hit.is_empty() else ""
			var gone := y < minf(edge.y, land.y) - 0.9
			if gone and start < 0.0:
				start = s
			elif not gone and start >= 0.0 and finish < 0.0 and role == "route":
				finish = s
			s += 0.01
		var measured := finish - start if start >= 0.0 and finish >= 0.0 else -1.0
		var label := str(gap.label)
		_check(label + " is a real gap at its declared width", absf(measured - float(gap.width_m)) < 0.03 and absf(start) < 0.02, "measured %.3f from %.3f, declared %.3f" % [measured, start, gap.width_m])
		var landing := _ray(level, land + along * 0.3 + Vector3.UP * 0.5, land + along * 0.3 + Vector3.DOWN * 0.5)
		_check(label + " lands on a route deck at its declared height", not landing.is_empty() and absf((landing.position as Vector3).y - land.y) < 0.01 and str(landing.collider.get_meta("surface", "")) == "route")
		if gap.line == "basic":
			basic_sections[gap.section] = true
			_check(label + " (basic) clears at a vanilla run", gap.tier in ["vanilla_run", "vanilla_run_tight"] and float(gap.vanilla_run_slack_s) >= 0.03, "%s, %.3f s" % [gap.tier, gap.vanilla_run_slack_s])
		else:
			_check(label + " (advanced) cannot be cleared at a vanilla run", float(gap.clear_ups) > float(LEVEL.VANILLA.run_ups) and float(gap.width_m) > float(LEVEL.VANILLA.run_ups) * LEVEL.U * float(gap.flight_s), gap.clear_ups)
			_check(label + " (advanced) falls short at a vanilla run even with full box-hull credit", float(gap.run_box_hull_short_m) > 0.0, gap.run_box_hull_short_m)
			_check(label + " (advanced) clears with margin at its intended speed", float(gap.intended_ups) >= float(gap.comfortable_ups) and float(gap.intended_spare_m) >= 0.5, "%d vs %d" % [gap.intended_ups, gap.comfortable_ups])
		results.append({"label": label, "line": gap.line, "tier": gap.tier, "declared_m": gap.width_m, "measured_m": snappedf(measured, 0.001), "clear_ups": gap.clear_ups, "intended_ups": gap.intended_ups})
	for section: String in ["stop_logs", "valve_bend", "weir_gauges", "tail_race"]:
		_check("section %s has a basic line" % section, basic_sections.has(section))
	return results

# --- walking ---------------------------------------------------------------------------------

func _walking(level: Node3D) -> Dictionary:
	# a 0.5 m grid of walkable tops; a walk joins neighbours that differ by a step up to 18 u,
	# any drop, or a climb along a walkable slope. hops never count.
	var tops := {}
	var nx := int(GRID.size.x / CELL)
	var nz := int(GRID.size.z / CELL)
	for i: int in nx:
		for j: int in nz:
			var x := GRID.position.x + (i + 0.5) * CELL
			var z := GRID.position.z + (j + 0.5) * CELL
			var hit := _ray(level, Vector3(x, 14, z), Vector3(x, -7, z))
			if hit.is_empty() or (hit.normal as Vector3).y < WALKABLE:
				continue
			var body: Node = hit.collider
			var role := str(body.get_meta("surface", ""))
			if not role in ["route", "catch", "recovery"]:
				continue
			tops[Vector2i(i, j)] = {"y": (hit.position as Vector3).y, "role": role, "piece": str(body.name), "slope": (hit.normal as Vector3).y < 0.999}
	var result := {"cells": tops.size()}
	# every pit cell walks to a route deck.
	var stranded := 0
	var catch_cells: Array = []
	for key: Vector2i in tops:
		if tops[key].role == "catch":
			catch_cells.append(key)
	var from_catch := _flood(tops, catch_cells)
	# per gap: the pit under its middle walks back to where its declared recovery route ends
	# (the take-off deck, or the start of its section), never to its landing piece; and from
	# the take-off piece the landing piece cannot be walked to at all.
	var gaps: Array = []
	for gap: Dictionary in level.get("jump_gaps"):
		var edge: Vector3 = gap.edge
		var land: Vector3 = gap.land
		var along := Vector3(land.x - edge.x, 0, land.z - edge.z).normalized()
		# 0.6 m in from each edge: more than a grid cell's half diagonal, so the cell's own
		# sample ray lands on the deck whatever the grid's alignment with the edge.
		var take_key := _key(edge - along * 0.6)
		var land_key := _key(land + along * 0.6)
		var pit_key := _key(edge.lerp(land, 0.5))
		if not tops.has(take_key) or not tops.has(land_key) or not tops.has(pit_key):
			_check(str(gap.label) + " grid cells exist", false, [tops.has(take_key), tops.has(land_key), tops.has(pit_key)])
			continue
		var take_piece: String = tops[take_key].piece
		var land_piece: String = tops[land_key].piece
		var recovery: Array = (level.get("routes") as Dictionary).get(gap.recovery, [])
		var back_key := _key(recovery[-1]) if not recovery.is_empty() else take_key
		var back_piece: String = tops[back_key].piece if tops.has(back_key) else ""
		_check(str(gap.label) + " recovery ends on a deck at or before the take-off", not back_piece.is_empty() and tops[back_key].role == "route" and _stage(level, back_piece) <= _stage(level, take_piece), back_piece)
		var from_pit := _flood(tops, [pit_key])
		var from_take := _flood(tops, [take_key])
		var pit_back := _reaches_piece(tops, from_pit, back_piece)
		var pit_forward := _reaches_piece(tops, from_pit, land_piece)
		var walk_round := _reaches_piece(tops, from_take, land_piece)
		var optional := str(gap.section) == "pump_bend"
		_check(str(gap.label) + " pit walks back along its recovery", pit_back, back_piece)
		if not optional:
			_check(str(gap.label) + " pit does not lead forward", not pit_forward, land_piece)
			_check(str(gap.label) + " cannot be walked round", not walk_round, land_piece)
		else:
			_check(str(gap.label) + " has its walkable alternative", walk_round)
		gaps.append({"label": gap.label, "take_off": take_piece, "returns_to": back_piece, "landing": land_piece, "pit": tops[pit_key].piece, "pit_returns": pit_back, "pit_forward": pit_forward, "walk_round": walk_round, "optional": optional})
	# backwards from every deck: the cells that can walk to one.
	var decks: Array = []
	for key: Vector2i in tops:
		if tops[key].role == "route":
			decks.append(key)
	var to_deck := _flood(tops, decks, true)
	var stranded_at: Array = []
	for key: Vector2i in tops:
		if tops[key].role != "route" and not to_deck.has(key):
			stranded += 1
			if stranded_at.size() < 8:
				stranded_at.append([tops[key].piece, GRID.position.x + (key.x + 0.5) * CELL, GRID.position.z + (key.y + 0.5) * CELL])
	_check("every pit and return cell walks to a deck", stranded == 0, [stranded, stranded_at])
	var spawn_key := _key((level.get("spawn") as Transform3D).origin)
	var from_spawn := _flood(tops, [spawn_key])
	var finish_walkable := false
	for key: Vector2i in from_spawn:
		if level.call("is_finish_at", Vector3(GRID.position.x + (key.x + 0.5) * CELL, float(tops[key].y) + 0.05, GRID.position.z + (key.y + 0.5) * CELL)):
			finish_walkable = true
	_check("the finish cannot be walked to from the spawn", not finish_walkable)
	result["gaps"] = gaps
	result["catch_cells"] = catch_cells.size()
	result["catch_reached_cells"] = from_catch.size()
	return result

func _key(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x - GRID.position.x) / CELL)), int(floor((p.z - GRID.position.z) / CELL)))

func _flood(tops: Dictionary, seeds: Array, backwards := false) -> Dictionary:
	var reached := {}
	var queue: Array = []
	for key: Vector2i in seeds:
		if tops.has(key):
			reached[key] = true
			queue.append(key)
	while not queue.is_empty():
		var key: Vector2i = queue.pop_back()
		var here: Dictionary = tops[key]
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var other := key + d
			if not tops.has(other) or reached.has(other):
				continue
			var rise := float(tops[other].y) - float(here.y)
			if backwards:
				rise = -rise
			# walking from `here` onto `other`: a drop, a step, or a climb along a walkable slope.
			var slope_climb := (bool(here.slope) or bool(tops[other].slope)) and rise <= CELL * (sqrt(1.0 - WALKABLE * WALKABLE) / WALKABLE) + 0.01
			if rise <= STEP_UP or slope_climb:
				reached[other] = true
				queue.append(other)
	return reached

func _stage(level: Node3D, piece: String) -> int:
	for entry: Dictionary in level.get("manifest"):
		if entry.name == piece:
			return int(entry.stage)
	return 99

func _reaches_piece(tops: Dictionary, reached: Dictionary, piece: String) -> bool:
	for key: Vector2i in reached:
		if tops[key].piece == piece:
			return true
	return false

# --- the actual r13 consumer ------------------------------------------------------------------

func _consumer() -> Dictionary:
	# the r13 overflow main with this level as its level script: its hud, audio and art pass,
	# progress and course key run against the practice level unchanged.
	var game: Node3D = R13_MAIN.new()
	game.set("level_script", LEVEL)
	game.set("set_window_title", false)
	root.add_child(game)
	for i: int in 4:
		await physics_frame
	var level: Node3D = game.get("level")
	var player: Node3D = game.get("player")
	var stages := int(game.call("stage_count"))
	_check("consumer stage count", stages == (level.get("checkpoints") as Array).size(), stages)
	_check("consumer geometry id is the hash", str(game.get("course_geometry")) == str(level.call("geometry_hash")))
	_check("consumer course key", str(game.get("course_key")).length() == 16)
	_check("consumer spawned the runner at the spawn", player.global_position.distance_to((level.get("spawn") as Transform3D).origin) < 0.3, player.global_position)
	_check("consumer kill bounds from the level", game.get("_kill_bounds") == level.get("kill_bounds"))
	_check("consumer finish title", str(game.call("segment_title", stages - 1)) == "Tailwater")
	_check("consumer art pass skipped the practice level", not bool((level.get_meta("overflow_art", {}) as Dictionary).get("applied", true)))
	var hint := str((game.get("hud") as Node).call("_hint_text"))
	_check("consumer hud hint", not hint.is_empty(), hint)
	var titles: Array = []
	for i: int in stages:
		titles.append(game.call("segment_title", i))
	var result := {"stage_count": stages, "segment_titles": titles, "course_key": game.get("course_key"), "runner": (player.get_script() as Script).resource_path, "hint": hint}
	game.queue_free()
	await process_frame
	return result

func _ray(level: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return level.get_world_3d().direct_space_state.intersect_ray(query)

extends SceneTree
## p / Night Shift interface and geometry checks, headless. exact-state checks on the built level
## and on the actual r15 main hosting it as the named map; they say nothing about play, fun or
## rendering.
##   - the level interface: fields, six stages, finish, hints, identity, a stable hash;
##   - every manifest piece is a named static body with one convex prism, names unique;
##   - walkable pieces stay within 32 m; grounded decks reach 5 m under their tops, catches 2.5 m,
##     the declared elevated decks (flyover, knuckle) 0.6 m or more;
##   - every solid is drawn: a prism record over its top, or a placed train model of its size;
##   - every checkpoint pose stands on a route deck of its own stage, and every stage has decks;
##   - the kill envelope holds every walkable top, and the canal under the descent is outside it;
##   - headroom: nothing hangs lower over a deck than a standing hull plus a jump, except the
##     one declared low clearance, the shutter hatch, which a standing hull cannot pass at any
##     height a jump reaches and a duck hull can between the sill and the shutter, tested with
##     the runner's hull sizes against the built physics;
##   - the art pass committed every batch after all authored geometry (none pending), placed
##     every train, and keeps the lamp count inside the compatibility renderer's light budget;
##   - r15_main.gd hosts it as map "night-shift" with the runner at the labelled spawn.
## godot --headless --audio-driver Dummy --path . --script res://tests/test_r15_nightshift.gd

const LEVEL := preload("res://scripts/r15_nightshift_level.gd")
const MAIN := preload("res://scripts/r15_main.gd")
const WALKABLE := ["route", "catch", "recovery"]
## elevated decks with open space under them: 0.6 m is the floor, not 5 m.
const ELEVATED := ["s5_flyover_", "s4_knuckle_0", "s4_knuckle_1", "s4_knuckle_2", "s4_knuckle_3", "s4_knuckle_4", "s4_knuckle_5", "s4_knuckle_6", "s4_knuckle_7", "s4_knuckle_8"]
const U := 0.0254
## p / standing hull 72 u plus a jump's 57 u apex, in metres: nothing may hang lower over a deck.
const HEADROOM := (72.0 + 57.0) * U
const LOW_CLEARANCE := ["s3_shutter"]
## compatibility renderer default: 32 renderable lights in a frame.
const LIGHT_BUDGET := 32

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + what)

func _elevated(name: String) -> bool:
	for prefix: String in ELEVATED:
		if name.begins_with(prefix):
			return true
	return false

func _run() -> void:
	var level: Node3D = LEVEL.new()
	root.add_child(level)
	level.call("build")
	await physics_frame
	await physics_frame
	var space := level.get_world_3d().direct_space_state
	# interface
	for field: String in ["spawn", "checkpoints", "segment_bounds", "finish_position", "water_regions", "water_audio_sources", "routes", "jump_gaps", "kill_bounds", "manifest", "level_id", "level_name", "level_version", "variant", "finish_title", "progress_roles"]:
		_check(level.get(field) != null, "interface field " + field)
	for method: String in ["build", "is_finish_at", "segment_at", "route_hint", "geometry_hash", "geometry_manifest", "course_manifest", "reset_state", "start_wheel"]:
		_check(level.has_method(method), "interface method " + method)
	var points: Array = level.get("checkpoints")
	_check(points.size() == 6, "six stages, got %d" % points.size())
	_check((level.get("segment_bounds") as Array).size() == points.size(), "a segment bound per stage")
	_check(str(level.get("variant")) != "course", "variant is not the r14 overflow art pass's 'course'")
	_check(level.call("is_finish_at", level.get("finish_position")), "finish_position is in the finish box")
	_check(not level.call("is_finish_at", (points[5].pose as Transform3D).origin), "the last checkpoint is not in the finish")
	for stage: int in points.size():
		_check(not str(level.call("route_hint", stage, (points[stage].pose as Transform3D).origin)).is_empty(), "hint for stage %d" % stage)
		if stage > 0:
			_check(float(points[stage].get("radius", 5.0)) == 0.0, "stage %d collects by deck only" % stage)
	var other: Node3D = LEVEL.new()
	root.add_child(other)
	other.call("build")
	_check(level.call("geometry_hash") == other.call("geometry_hash"), "geometry hash stable across builds")
	other.queue_free()
	# pieces
	var names := {}
	var stage_decks := {}
	var drawn := {}
	for prism: Dictionary in level.get("prisms"):
		drawn[JSON.stringify(_key(prism.top))] = true
	var cars := {}
	for car: Dictionary in level.get("trains"):
		cars[str(car.name)] = car
	var kill: AABB = level.get("kill_bounds")
	var longest := 0.0
	var roles := {}
	for piece: Dictionary in level.get("manifest"):
		var name := str(piece.name)
		roles[piece.role] = int(roles.get(piece.role, 0)) + 1
		_check(not names.has(name), "unique name " + name)
		names[name] = true
		var body := level.get_node_or_null(NodePath(name)) as StaticBody3D
		_check(body != null and body.get_child_count() == 1 and body.get_child(0) is CollisionShape3D and (body.get_child(0) as CollisionShape3D).shape is ConvexPolygonShape3D, "static convex body " + name)
		if body != null:
			_check(str(body.get_meta("surface", "")) == str(piece.role), "surface meta is the role on " + name)
			_check(int(body.get_meta("progress_stage", -1)) == int(piece.stage), "stage meta on " + name)
		var pts: Array = piece.points
		var n := pts.size() / 2
		var top: Array = pts.slice(0, n)
		var lo := Vector2(INF, INF)
		var hi := -lo
		var top_min := INF
		var top_max := -INF
		for p: Vector3 in top:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
			top_min = minf(top_min, p.y)
			top_max = maxf(top_max, p.y)
		var depth := top_min - (pts[n] as Vector3).y
		if str(piece.kind) == "train":
			_check(cars.has(name), "train piece %s has a placed car" % name)
			if cars.has(name):
				_check(absf(float(cars[name].height) - (top_max - float((cars[name].feet as Vector3).y))) < 1e-3, "car %s prism is its drawn height" % name)
		else:
			_check(drawn.has(JSON.stringify(_key(top))), "drawn: " + name)
		if piece.role in WALKABLE:
			var extent := maxf(hi.x - lo.x, hi.y - lo.y)
			longest = maxf(longest, extent)
			_check(extent <= 32.0 + 1e-3, "%s spans %.2f m, over 32" % [name, extent])
			var need := 0.6 if _elevated(name) else (2.5 if piece.role == "catch" else 5.0)
			_check(depth >= need - 1e-3, "%s is %.2f m deep, needs %.1f" % [name, depth, need])
			for p: Vector3 in top:
				_check(kill.has_point(p + Vector3.UP * 0.01), "kill envelope holds %s" % name)
			if int(piece.stage) >= 0:
				_check(piece.role == "route", "only route decks carry a stage: " + name)
				stage_decks[int(piece.stage)] = int(stage_decks.get(int(piece.stage), 0)) + 1
			# headroom: rays up from a grid over the deck's interior meet nothing below HEADROOM,
			# except the declared low clearance.
			var x := lo.x + 0.5
			while x < hi.x - 0.4:
				var z := lo.y + 0.5
				while z < hi.y - 0.4:
					var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, top_max + 0.5, z), Vector3(x, top_min - 2.0, z)))
					if not down.is_empty() and down.collider == body:
						var y: float = down.position.y
						var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, y + 0.02, z), Vector3(x, y + HEADROOM, z)))
						var blocker := "" if up.is_empty() else str((up.collider as Node).name)
						_check(up.is_empty() or blocker in LOW_CLEARANCE, "headroom over %s at (%.1f, %.1f): %s" % [name, x, z, blocker])
					z += 1.0
				x += 1.0
	print("longest walkable piece %.3f m; roles %s" % [longest, roles])
	for stage: int in range(0, 6):
		_check(int(stage_decks.get(stage, 0)) > 0, "stage %d has decks" % stage)
	for stage: int in points.size():
		var at: Vector3 = (points[stage].pose as Transform3D).origin
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 2.0))
		var under := int((hit.collider as Node).get_meta("progress_stage", -1)) if not hit.is_empty() else -2
		_check(under == stage, "checkpoint %d pose stands on a stage %d deck" % [stage, under])
	# the canal: a drop off the flyover's end, or between the steps, leaves the kill envelope.
	for p: Vector3 in [Vector3(-30.6, 0.0, 6.5), Vector3(-38.75, 0.0, 6.5), Vector3(-45.0, 0.0, 6.5), Vector3(-35.0, 0.0, 1.0)]:
		var fall := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, Vector3(p.x, -7.9, p.z)))
		var lands_at: float = fall.position.y if not fall.is_empty() else -8.0
		_check(lands_at < float(LEVEL.KILL_Y) and not kill.has_point(Vector3(p.x, lands_at + 0.01, p.z)), "a fall at (%.1f, %.1f) reaches the kill floor, not a ledge (%.2f)" % [p.x, p.z, lands_at])
	# the hatch: a standing hull meets the wall or the shutter at every feet height from the
	# floor to a jump's apex; a duck hull fits with its feet between the sill and the shutter,
	# a window that holds the jump-then-crouch apex, and does not fit on the floor.
	var mid := Vector3((float(LEVEL.SHUTTER[0]) + float(LEVEL.E_TRAIN_X)) * 0.5, 0.0, float(LEVEL.SHED_S) + 0.25)
	var sill: float = LEVEL.SHUTTER_SILL
	var duck_top: float = float(LEVEL.SHUTTER_H) - 54.0 * U
	_check(sill < 64.0 * U and 64.0 * U < duck_top, "the jump-then-crouch apex (64 u) lies in the hatch's duck window")
	var cases: Array = [[54.0, 0.0, true], [54.0, sill + 0.01, false], [54.0, (sill + duck_top) * 0.5, false], [54.0, duck_top - 0.01, false], [54.0, duck_top + 0.03, true]]
	var feet := 0.0
	while feet <= 57.0 * U + 0.001:
		cases.append([72.0, feet, true])
		feet += 0.05
	for case: Array in cases:
		var box := BoxShape3D.new()
		box.size = Vector3(32.0 * U, float(case[0]) * U, 32.0 * U)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = box
		query.transform = Transform3D(Basis.IDENTITY, mid + Vector3.UP * (float(case[1]) + float(case[0]) * U * 0.5 + 0.002))
		var hits := space.intersect_shape(query, 4)
		_check(hits.is_empty() != bool(case[2]), "a %d u hull in the hatch, feet at %.2f m, %s" % [int(case[0]), float(case[1]), "is blocked" if case[2] else "fits"])
	# the art pass
	var art: Dictionary = level.get_meta("nightshift_art", {})
	_check(bool(art.get("committed", false)) and int(art.get("pending_after_dress", -1)) == 0, "every prism batch committed after all authored geometry")
	_check(int(art.get("lights", 99)) <= LIGHT_BUDGET - 2, "lamps (%d) inside the light budget" % int(art.get("lights", 99)))
	var placed := 0
	for model: String in (art.get("trains", {}) as Dictionary):
		placed += int(art.trains[model])
	_check(placed == (level.get("trains") as Array).size(), "every recorded car placed (%d of %d)" % [placed, (level.get("trains") as Array).size()])
	var meshes := level.find_children("Mesh_*", "MeshInstance3D", false, false)
	_check(meshes.size() == int(art.get("batches", -1)), "batches in the tree match the report")
	var visuals := 0
	for node: Node in level.find_children("*", "MeshInstance3D", true, false):
		visuals += 1
	print("pieces %d, trains %d, batches %d, mesh instances %d, lights %d, art %.1f ms" % [(level.get("manifest") as Array).size(), placed, meshes.size(), visuals, int(art.get("lights", 0)), float(art.get("apply_ms", 0.0))])
	print("gaps %s" % JSON.stringify((level.call("course_manifest") as Dictionary).gaps))
	print("geometry hash %s" % level.call("geometry_hash"))
	level.queue_free()
	await process_frame
	# hosted by the actual r15 main as the named map
	Engine.physics_ticks_per_second = 128
	var game: Node3D = MAIN.new()
	game.set("map_id", "night-shift")
	game.set("persist", false)
	game.set("set_window_title", false)
	root.add_child(game)
	await physics_frame
	await physics_frame
	_check(str(game.get("map_id")) == "night-shift" and str(game.call("map_name")) == "Night Shift", "r15 main hosts the named map night-shift")
	_check(str(game.call("map_kind")) == "course", "registered as a course")
	_check(int(game.call("stage_count")) == 6, "r15 main counts six stages")
	var spawn: Transform3D = (game.get("level") as Node3D).get("spawn")
	_check((game.get("player") as Node3D).global_position.distance_to(spawn.origin) < 0.1, "runner at the labelled spawn")
	_check(str(game.get("preset_id")) == "server128", "default preset is the approved bhop server")
	_check(str((game.get("player") as Node).get_script().resource_path) == "res://scripts/r15_source_player.gd", "the real crouch runner")
	_check((game.call("kill_bounds") as AABB) == (game.get("level") as Node3D).get("kill_bounds"), "the host uses the declared kill envelope")
	print("course key %s, identity %s" % [game.get("course_key"), game.call("record_identity")])
	print("%d checks, %d failures" % [checks, failures])
	game.call("request_quit", 1 if failures > 0 else 0)

static func _key(top: Array) -> Array:
	var out: Array = []
	for p: Vector3 in top:
		out.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
	return out

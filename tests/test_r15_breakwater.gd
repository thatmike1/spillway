extends SceneTree
## p / Breakwater interface and geometry checks, headless. exact-state checks on the built level and
## on the unchanged r14 main hosting it; they say nothing about play, fun or rendering.
##   - the r14 level interface: fields, five stages, finish, hints, identity, a stable hash;
##   - every manifest piece is a named static body with a convex prism, names unique;
##   - walkable pieces stay within 32 m, catches and decks reach 5 m under their tops (the gangway
##     and its parapet are the declared thin pieces, 0.6 m or more);
##   - every solid is drawn (a prism record, or container records filling its full height);
##   - every checkpoint pose stands on a deck of an earlier or equal stage, and stages 1-4 have decks;
##   - the kill envelope holds every walkable top; no walkable deck has a solid over it lower than
##     a standing hull plus a jump (no crouch requirement anywhere);
##   - r14_main.gd hosts it as map "fixture" with the runner at the labelled spawn.
## godot --headless --audio-driver Dummy --path . --script res://tests/test_r15_breakwater.gd

const LEVEL := preload("res://scripts/r15_breakwater_level.gd")
const MAIN := preload("res://scripts/r14_main.gd")
const WALKABLE := ["route", "catch", "recovery"]
const THIN := ["s4_gangway", "s4_gangway_parapet"]
## p / standing hull 72 u plus a jump's 57 u apex, in metres: nothing may hang lower over a deck.
const HEADROOM := (72.0 + 57.0) * 0.0254

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + what)

func _run() -> void:
	var level: Node3D = LEVEL.new()
	root.add_child(level)
	level.call("build")
	await physics_frame
	await physics_frame
	var space := level.get_world_3d().direct_space_state
	# interface
	for field: String in ["spawn", "checkpoints", "segment_bounds", "finish_position", "water_regions", "water_audio_sources", "routes", "jump_gaps", "kill_bounds", "manifest", "level_id", "level_name", "level_version", "variant", "finish_title"]:
		_check(level.get(field) != null, "interface field " + field)
	for method: String in ["build", "is_finish_at", "segment_at", "route_hint", "geometry_hash", "geometry_manifest", "course_manifest", "reset_state", "start_wheel"]:
		_check(level.has_method(method), "interface method " + method)
	var points: Array = level.get("checkpoints")
	_check(points.size() == 5, "five stages, got %d" % points.size())
	_check((level.get("segment_bounds") as Array).size() == points.size(), "a segment bound per stage")
	_check(str(level.get("variant")) != "course", "variant is not the r14 overflow art pass's 'course'")
	_check(level.call("is_finish_at", level.get("finish_position")), "finish_position is in the finish box")
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
	var heights := {}
	for box: Dictionary in level.get("containers"):
		heights[box.name] = float(heights.get(box.name, 0.0)) + float(LEVEL.CH)
	var kill: AABB = level.get("kill_bounds")
	var longest := 0.0
	for piece: Dictionary in level.get("manifest"):
		var name := str(piece.name)
		_check(not names.has(name), "unique name " + name)
		names[name] = true
		var body := level.get_node_or_null(NodePath(name)) as StaticBody3D
		_check(body != null and body.get_child(0) is CollisionShape3D and (body.get_child(0) as CollisionShape3D).shape is ConvexPolygonShape3D, "static convex body " + name)
		var pts: Array = piece.points
		var n := pts.size() / 2
		var top: Array = pts.slice(0, n)
		var lo := Vector2(INF, INF)
		var hi := -lo
		var top_min := INF
		for p: Vector3 in top:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
			top_min = minf(top_min, p.y)
		var depth := top_min - (pts[n] as Vector3).y
		if str(piece.kind) == "container":
			_check(absf(float(heights.get(name, 0.0)) - depth) < 1e-3, "containers drawn over the full height of " + name)
		else:
			_check(drawn.has(JSON.stringify(_key(top))), "drawn: " + name)
		if piece.role in WALKABLE:
			var extent := maxf(hi.x - lo.x, hi.y - lo.y)
			longest = maxf(longest, extent)
			_check(extent <= 32.0 + 1e-3, "%s spans %.2f m, over 32" % [name, extent])
			_check(depth >= (0.6 if name in THIN else 2.5) - 1e-3, "%s is %.2f m deep" % [name, depth])
			if piece.role != "catch":
				_check(depth >= (0.6 if name in THIN else 5.0) - 1e-3 or str(piece.kind) == "container", "%s deck depth %.2f m" % [name, depth])
			for p: Vector3 in top:
				_check(kill.has_point(p + Vector3.UP * 0.01), "kill envelope holds %s" % name)
			if int(piece.stage) >= 0:
				stage_decks[int(piece.stage)] = int(stage_decks.get(int(piece.stage), 0)) + 1
			# headroom: rays up from a grid over the deck's interior meet nothing below HEADROOM.
			var x := lo.x + 0.5
			while x < hi.x - 0.4:
				var z := lo.y + 0.5
				while z < hi.y - 0.4:
					var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, top_min + 3.0 + 1.0, z), Vector3(x, top_min - 2.0, z)))
					if not down.is_empty() and down.collider == body:
						var y: float = down.position.y
						var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, y + 0.02, z), Vector3(x, y + HEADROOM, z)))
						_check(up.is_empty(), "headroom over %s at (%.1f, %.1f): %s" % [name, x, z, "" if up.is_empty() else str((up.collider as Node).name)])
					z += 2.0
				x += 2.0
	print("longest walkable piece %.3f m" % longest)
	for stage: int in range(0, 5):
		_check(int(stage_decks.get(stage, 0)) > 0, "stage %d has decks" % stage)
	for stage: int in points.size():
		var at: Vector3 = (points[stage].pose as Transform3D).origin
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 2.0))
		var under := int((hit.collider as Node).get_meta("progress_stage", -1)) if not hit.is_empty() else -2
		_check(under >= 0 and under <= stage, "checkpoint %d pose stands on a stage %d deck" % [stage, under])
	var art: Dictionary = level.get_meta("breakwater_art", {})
	_check(int(art.get("containers_drawn", 0)) > (level.get("containers") as Array).size(), "art drew the route and scenery containers")
	print("pieces %d, containers %d drawn %d, scenery bodies %s, art %.1f ms" % [(level.get("manifest") as Array).size(), (level.get("containers") as Array).size(), int(art.get("containers_drawn", 0)), art.get("scenery_bodies"), float(art.get("apply_ms", 0.0))])
	level.queue_free()
	await process_frame
	# hosted by the unchanged r14 main
	Engine.physics_ticks_per_second = 128
	var game: Node3D = MAIN.new()
	game.set("level_script", LEVEL)
	game.set("set_window_title", false)
	root.add_child(game)
	await physics_frame
	await physics_frame
	_check(str(game.get("map_id")) == "fixture" and str(game.call("map_name")) == "Breakwater", "r14 main hosts it as fixture Breakwater")
	_check(int(game.call("stage_count")) == 5, "r14 main counts five stages")
	var spawn: Transform3D = (game.get("level") as Node3D).get("spawn")
	_check((game.get("player") as Node3D).global_position.distance_to(spawn.origin) < 0.1, "runner at the labelled spawn")
	_check(str(game.get("preset_id")) == "server128", "default preset is the approved bhop server")
	print("course key %s, identity %s" % [game.get("course_key"), game.call("record_identity")])
	print("%d checks, %d failures" % [checks, failures])
	game.call("request_quit", 1 if failures > 0 else 0)

static func _key(top: Array) -> Array:
	var out: Array = []
	for p: Vector3 in top:
		out.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
	return out

extends SceneTree
## p / Sunken Court interface and geometry checks, headless. exact-state checks on the built level and
## on the actual r15 main hosting it; they say nothing about play, fun or rendering.
##   - the level interface: fields, five stages collected by deck, finish, hints, identity, a stable hash;
##   - every manifest piece is a named static body with a convex prism, names unique;
##   - every piece is drawn: an own prism with the same top, or a placed library model that lists it;
##   - walkable pieces stay within 32 m and reach 0.6 m or more under their tops;
##   - every checkpoint pose stands on a deck of an earlier or equal stage; every stage has decks;
##   - the kill envelope holds every walkable top and the river is outside it;
##   - no walkable deck has a solid over it lower than a standing hull plus a jump;
##   - every library arch keeps its void: rays through each tower's two passages and under each
##     bridge span meet none of that model's own pieces;
##   - the causeway stands 60 u over the walks; no water region is declared (no traction change);
##   - the art placed every course model and the scenery;
##   - r15_main.gd lists sunken-court and hosts it with the runner at the labelled spawn on F2.
## godot --headless --audio-driver Dummy --path . --script res://tests/test_r15_sunken.gd

const LEVEL := preload("res://scripts/r15_sunken_level.gd")
const MAIN := preload("res://scripts/r15_main.gd")
const MAPS := preload("res://scripts/r15_maps.gd")
const WALKABLE := ["route", "catch", "recovery"]
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
	for field: String in ["spawn", "checkpoints", "segment_bounds", "finish_position", "water_regions", "water_audio_sources", "routes", "jump_gaps", "kill_bounds", "manifest", "level_id", "level_name", "level_version", "variant", "finish_title", "progress_roles"]:
		_check(level.get(field) != null, "interface field " + field)
	for method: String in ["build", "is_finish_at", "segment_at", "route_hint", "geometry_hash", "geometry_manifest", "course_manifest", "reset_state", "start_wheel"]:
		_check(level.has_method(method), "interface method " + method)
	var points: Array = level.get("checkpoints")
	_check(points.size() == 5, "five stages, got %d" % points.size())
	_check((level.get("segment_bounds") as Array).size() == points.size(), "a segment bound per stage")
	_check(str(level.get("variant")) != "course", "variant is not the r14 overflow art pass's 'course'")
	_check(level.call("is_finish_at", level.get("finish_position")), "finish_position is in the finish box")
	_check((level.get("water_regions") as Array).is_empty(), "no water region: the pools and the river change no movement")
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
	var model_pieces := {}
	var placed := {}
	for node: Node in level.find_children("Model_*", "Node3D", true, false):
		placed[str(node.get_meta("sunken_model_id", ""))] = node
	for m: Dictionary in level.get("models"):
		_check(placed.has(str(m.id)), "the art placed model " + str(m.id))
		for piece: String in m.get("pieces", []):
			model_pieces[piece] = str(m.id)
	var kill: AABB = level.get("kill_bounds")
	var longest := 0.0
	var thinnest := INF
	for piece: Dictionary in level.get("manifest"):
		var name := str(piece.name)
		_check(not names.has(name), "unique name " + name)
		names[name] = true
		var body := level.get_node_or_null(NodePath(name)) as StaticBody3D
		_check(body != null and body.get_child(0) is CollisionShape3D and (body.get_child(0) as CollisionShape3D).shape is ConvexPolygonShape3D, "static convex body " + name)
		var pts: Array = piece.points
		var n := pts.size() / 2
		var top: Array = pts.slice(0, n)
		var bottom: Array = pts.slice(n)
		var lo := Vector2(INF, INF)
		var hi := -lo
		var top_min := INF
		var bottom_max := -INF
		for p: Vector3 in top:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
			top_min = minf(top_min, p.y)
		for p: Vector3 in bottom:
			bottom_max = maxf(bottom_max, p.y)
		if str(piece.kind).begins_with("model:"):
			_check(model_pieces.has(name), "model piece %s belongs to a placed model" % name)
		else:
			_check(drawn.has(JSON.stringify(_key(top))), "drawn: " + name)
		if not piece.role in WALKABLE:
			continue
		var extent := maxf(hi.x - lo.x, hi.y - lo.y)
		var depth := top_min - bottom_max
		longest = maxf(longest, extent)
		thinnest = minf(thinnest, depth)
		_check(extent <= 32.0 + 1e-3, "%s spans %.2f m, over 32" % [name, extent])
		_check(depth >= 0.6 - 1e-3, "%s is %.2f m deep" % [name, depth])
		for p: Vector3 in top:
			_check(kill.has_point(p + Vector3.UP * 0.01), "kill envelope holds %s" % name)
		if int(piece.stage) >= 0:
			stage_decks[int(piece.stage)] = int(stage_decks.get(int(piece.stage), 0)) + 1
		# headroom: rays up from a grid over the piece's own face meet nothing below HEADROOM.
		var x := lo.x + 0.3
		while x < hi.x - 0.2:
			var z := lo.y + 0.3
			while z < hi.y - 0.2:
				var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, top_min + 4.0, z), Vector3(x, top_min - 2.0, z)))
				if not down.is_empty() and down.collider == body:
					var y: float = down.position.y
					var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, y + 0.02, z), Vector3(x, y + HEADROOM, z)))
					_check(up.is_empty(), "headroom over %s at (%.1f, %.1f): %s" % [name, x, z, "" if up.is_empty() else str((up.collider as Node).name)])
				z += 1.5
			x += 1.5
	print("longest walkable piece %.3f m, thinnest %.3f m" % [longest, thinnest])
	for stage: int in range(0, 5):
		_check(int(stage_decks.get(stage, 0)) > 0, "stage %d has decks" % stage)
	for stage: int in points.size():
		var at: Vector3 = (points[stage].pose as Transform3D).origin
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 2.0))
		var under := int((hit.collider as Node).get_meta("progress_stage", -1)) if not hit.is_empty() else -2
		_check(under >= 0 and under <= stage, "checkpoint %d pose stands on a stage %d deck" % [stage, under])
	_check(not kill.has_point(Vector3(20, float(LEVEL.RIVER_Y), -125)), "the river is outside the kill envelope")
	_check(kill.has_point(Vector3(0, float(LEVEL.COURT_Y) + 0.1, -80)), "the court floor is inside the kill envelope")
	# arch voids: through each tower's passages and under each bridge span.
	var voids := 0
	for m: Dictionary in level.get("models"):
		var xf: Transform3D = m.xf
		var own := {}
		for piece: String in m.get("pieces", []):
			own[piece] = true
		var rays: Array = []
		if str(m.model) == LEVEL.TOWER_MODEL:
			for h: float in [0.15, 0.35, 0.5]:
				rays.append([Vector3(0, h, -0.6), Vector3(0, h, 0.6)])
				rays.append([Vector3(-0.6, h, 0), Vector3(0.6, h, 0)])
				rays.append([Vector3(0.2, h, -0.6), Vector3(0.2, h, 0.6)])
		elif str(m.model) == LEVEL.BRIDGE_MODEL:
			for h: float in [0.1, 0.3, 0.6]:
				rays.append([Vector3(0, h, -0.6), Vector3(0, h, 0.6)])
				rays.append([Vector3(0.3, h * 0.5, -0.6), Vector3(0.3, h * 0.5, 0.6)])
		for ray: Array in rays:
			var a: Vector3 = xf * (ray[0] as Vector3)
			var b: Vector3 = xf * (ray[1] as Vector3)
			var blocked := _ray_hits_own(space, a, b, own)
			_check(blocked.is_empty(), "arch void of %s open at %s: %s" % [m.id, ray[0], blocked])
			voids += 1
	print("arch void rays %d" % voids)
	# and the piers really are there: a ray through a tower corner meets its pier.
	for m: Dictionary in level.get("models"):
		if str(m.model) == LEVEL.TOWER_MODEL:
			var xf: Transform3D = m.xf
			var own := {}
			for piece: String in m.get("pieces", []):
				own[piece] = true
			_check(not _ray_hits_own(space, xf * Vector3(0.36, 0.3, -0.6), xf * Vector3(0.36, 0.3, 0.6), own).is_empty(), "pier of %s is solid" % m.id)
	var causeway: Array = (level.get_node("s3_causeway_s").get_child(0).shape as ConvexPolygonShape3D).points
	var cy := -INF
	for p: Vector3 in causeway:
		cy = maxf(cy, p.y)
	_check(absf(cy - float(LEVEL.CLOISTER_Y) - 60.0 * 0.0254) < 1e-4, "the causeway stands 60 u over the walks (%.4f m)" % (cy - float(LEVEL.CLOISTER_Y)))
	var art: Dictionary = level.get_meta("sunken_art", {})
	_check(int(art.get("course_models", 0)) == (level.get("models") as Array).size(), "art placed every course model")
	var scenery := 0
	for key: String in (art.get("scenery", {}) as Dictionary):
		scenery += int(art.scenery[key])
	_check(scenery >= 100, "art placed the scenery (%d)" % scenery)
	print("pieces %d, models %d, scenery %d, art %.1f ms, hash %s" % [(level.get("manifest") as Array).size(), (level.get("models") as Array).size(), scenery, float(art.get("apply_ms", 0.0)), level.call("geometry_hash")])
	level.queue_free()
	await process_frame
	# hosted by the actual r15 main
	var maps: Dictionary = MAPS.make()
	_check(MAPS.available(maps, "sunken-court"), "the r15 registry lists sunken-court as playable")
	Engine.physics_ticks_per_second = 128
	var game: Node3D = MAIN.new()
	game.set("map_id", "sunken-court")
	game.set("set_window_title", false)
	root.add_child(game)
	await physics_frame
	await physics_frame
	_check(str(game.get("map_id")) == "sunken-court" and str(game.call("map_name")) == "Sunken Court", "r15 main hosts sunken-court")
	_check(str(game.call("map_kind")) == "course", "it is a course, not a lab or fixture")
	_check(int(game.call("stage_count")) == 5, "r15 main counts five stages")
	var hosted: Node3D = game.get("level")
	_check((game.get("player") as Node3D).global_position.distance_to((hosted.get("spawn") as Transform3D).origin) < 0.1, "runner at the labelled spawn")
	_check(str(game.get("preset_id")) == "server128", "default preset is the approved bhop server")
	_check(game.call("kill_bounds") == hosted.get("kill_bounds"), "the main uses the level's kill envelope")
	_check(str((game.get("player") as Node).get_script().resource_path) == "res://scripts/r15_source_player.gd", "the real crouch runner")
	print("course key %s, identity %s" % [game.get("course_key"), game.call("record_identity_text")])
	print("%d checks, %d failures" % [checks, failures])
	game.call("request_quit", 1 if failures > 0 else 0)

func _ray_hits_own(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, own: Dictionary) -> String:
	var exclude: Array[RID] = []
	for i: int in 16:
		var query := PhysicsRayQueryParameters3D.create(a, b)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return ""
		var name := str((hit.collider as Node).name)
		if own.has(name):
			return name
		exclude.append(hit.rid)
	return ""

static func _key(top: Array) -> Array:
	var out: Array = []
	for p: Vector3 in top:
		out.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
	return out

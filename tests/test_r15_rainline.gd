extends SceneTree
## p / Rainline interface and geometry checks, headless. exact-state checks on the built level and
## on the actual r15 main hosting it as map `rainline`; they say nothing about play, fun or rendering.
##   - the level interface: fields, five stages, finish, hints, identity, a stable hash;
##   - every manifest piece is a named static convex prism, names unique, roles known;
##   - route decks stay within 32 m; building roofs reach 5 m or more under their tops, the
##     declared thin pieces (bridges, scaffold boards) 0.8 m;
##   - every solid is drawn: a prism record of the same name, or a sourced model filling a prop box;
##   - checkpoint poses stand on decks of an earlier or equal stage; every stage has decks;
##   - the kill envelope holds every route top with 2.5 m or more below the lowest;
##   - headroom: nothing over a route deck lower than a standing hull plus a jump, except the
##     declared crouch duct, whose ceiling sits between the duck and standing hulls; a standing
##     box fits nowhere in the duct, a duck box everywhere along it, and both stand clear outside;
##   - lamp posts are solid, hung lamps sit over the headroom; no body carries a friction override;
##   - r15_main.gd hosts it by map id with the runner at the labelled spawn on F2.
## godot --headless --audio-driver Dummy --path . --script res://tests/test_r15_rainline.gd

const LEVEL := preload("res://scripts/r15_rainline_level.gd")
const MAIN := preload("res://scripts/r15_main.gd")
const MAPS := preload("res://scripts/r15_maps.gd")
const U := 0.0254
const ROLES := ["route", "wall", "prop", "ceiling", "canopy", "glass", "scenery"]
const THIN := ["s1_gantry_1", "s1_gantry_2", "s1_gantry_3", "s4_footbridge"]
const HULL_W := 32.0 * U
const STAND_H := 72.0 * U
const DUCK_H := 54.0 * U

var failures := 0
var checks := 0
var notes: Array[String] = []

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
	for field: String in ["spawn", "checkpoints", "segment_bounds", "finish_position", "water_regions", "water_audio_sources", "routes", "jump_gaps", "kill_bounds", "manifest",
			"level_id", "level_name", "level_version", "variant", "finish_title", "progress_roles", "crouch_passages"]:
		_check(level.get(field) != null, "interface field " + field)
	for method: String in ["build", "is_finish_at", "segment_at", "route_hint", "geometry_hash", "geometry_manifest", "course_manifest", "reset_state", "start_wheel"]:
		_check(level.has_method(method), "interface method " + method)
	var points: Array = level.get("checkpoints")
	_check(points.size() == 5, "five stages, got %d" % points.size())
	_check((level.get("segment_bounds") as Array).size() == points.size(), "a segment bound per stage")
	_check(str(level.get("variant")) != "course", "variant is not the r14 overflow art pass's 'course'")
	_check(level.call("is_finish_at", level.get("finish_position")), "finish_position is in the finish box")
	_check(not level.call("is_finish_at", (points[4].pose as Transform3D).origin), "the last checkpoint is not in the finish box")
	for stage: int in points.size():
		_check(not str(level.call("route_hint", stage, (points[stage].pose as Transform3D).origin)).is_empty(), "hint for stage %d" % stage)
		if stage > 0:
			_check(float(points[stage].get("radius", 5.0)) == 0.0, "stage %d collects by deck only" % stage)
	var other: Node3D = LEVEL.new()
	root.add_child(other)
	other.call("build")
	_check(level.call("geometry_hash") == other.call("geometry_hash"), "geometry hash stable across builds")
	# freed at once: a queued copy would stay in the physics space and catch every ray below.
	root.remove_child(other)
	other.free()
	var course: Dictionary = level.call("course_manifest")
	_check(course.crouch_required == false, "no crouch requirement on the course")
	# pieces
	var names := {}
	var drawn := {}
	for prism: Dictionary in level.get("prisms"):
		if not str(prism.name).is_empty():
			drawn[str(prism.name)] = true
	var modelled := {}
	for prop: Dictionary in level.get("props"):
		if prop.has("collision"):
			modelled[str(prop.collision)] = prop
	var kill: AABB = level.get("kill_bounds")
	var lowest := INF
	var longest := 0.0
	var stage_decks := {}
	var route_tops: Array = []
	for piece: Dictionary in level.get("manifest"):
		var name := str(piece.name)
		_check(not names.has(name), "unique name " + name)
		names[name] = true
		_check(str(piece.role) in ROLES, "known role %s on %s" % [piece.role, name])
		var body := level.get_node_or_null(NodePath(name)) as StaticBody3D
		_check(body != null and body.get_child(0) is CollisionShape3D and (body.get_child(0) as CollisionShape3D).shape is ConvexPolygonShape3D, "static convex body " + name)
		if body != null:
			_check(body.physics_material_override == null, "no friction override on " + name)
			_check(str(body.get_meta("surface", "")) == str(piece.role), "surface meta matches role on " + name)
		_check(drawn.has(name) or modelled.has(name), "drawn: " + name)
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
		if piece.role == "route":
			var extent := maxf(hi.x - lo.x, hi.y - lo.y)
			longest = maxf(longest, extent)
			lowest = minf(lowest, top_min)
			_check(extent <= 32.0 + 1e-3, "%s spans %.2f m, over 32" % [name, extent])
			var thin := name in THIN or name.begins_with("s2_scaf_")
			_check(depth >= (0.8 if thin else 5.0) - 1e-3, "%s is %.2f m deep" % [name, depth])
			for p: Vector3 in top:
				_check(kill.has_point(p + Vector3.UP * 0.01), "kill envelope holds %s" % name)
			stage_decks[int(piece.stage)] = int(stage_decks.get(int(piece.stage), 0)) + 1
			_check(int(piece.stage) >= 0, "route deck %s has a stage" % name)
			route_tops.append([name, lo, hi, top_min, body])
		elif piece.role == "scenery":
			_check(maxf(hi.x - lo.x, hi.y - lo.y) <= 32.0 + 1e-3, "scenery block %s within 32 m" % name)
	_check(lowest - kill.position.y >= 2.5, "kill floor %.2f m under the lowest deck" % (lowest - kill.position.y))
	print("longest route piece %.3f m, lowest deck %.2f m" % [longest, lowest])
	for stage: int in range(0, 5):
		_check(int(stage_decks.get(stage, 0)) > 0, "stage %d has decks" % stage)
	# headroom over every route deck; the duct is the declared exception.
	var passages: Array = level.get("crouch_passages")
	_check(passages.size() == 1, "one declared crouch passage")
	var duct: Dictionary = passages[0]
	var duct_hits := 0
	var hood_hits := 0
	for entry: Array in route_tops:
		var name: String = entry[0]
		var lo: Vector2 = entry[1]
		var hi: Vector2 = entry[2]
		var x := lo.x + 0.45
		while x < hi.x - 0.4:
			var z := lo.y + 0.45
			while z < hi.y - 0.4:
				# the duct floor and its approach are looked for from under the lid and hood.
				var from := float(entry[3]) + (1.0 if name == str(duct.name) or _under_hood(duct, x, z) else 5.0)
				var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, from, z), Vector3(x, float(entry[3]) - 2.0, z)))
				if not down.is_empty() and down.collider == entry[4]:
					var y: float = down.position.y
					var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, y + 0.02, z), Vector3(x, y + LEVEL.HEADROOM, z)))
					if name == str(duct.name):
						var clearance := float(up.position.y) - y if not up.is_empty() else INF
						_check(clearance > DUCK_H + 0.01 and clearance < STAND_H - 0.01, "duct clearance %.3f m at (%.1f, %.1f)" % [clearance, x, z])
						duct_hits += 1
					elif _under_hood(duct, x, z):
						# the hood over the duct's approach slopes from a jump's headroom down to the duct.
						var clearance := float(up.position.y) - y if not up.is_empty() else INF
						_check(clearance > DUCK_H + 0.2, "hood clearance %.3f m at (%.1f, %.1f)" % [clearance, x, z])
						hood_hits += 1
					else:
						_check(up.is_empty(), "headroom over %s at (%.1f, %.1f): %s" % [name, x, z, "" if up.is_empty() else str((up.collider as Node).name)])
				z += 1.0
			x += 1.0
	_check(duct_hits > 10, "duct floor sampled (%d)" % duct_hits)
	_check(hood_hits >= 6, "hood approach sampled (%d)" % hood_hits)
	# hull fits along the duct's centre line, and standing room at both ends.
	var cx := (float(duct.x[0]) + float(duct.x[1])) * 0.5
	var z0: float = duct.z[0]
	var z1: float = duct.z[1]
	var fy: float = duct.floor_y
	var z := z0 + 0.5
	var stand_blocked := 0
	var duck_clear := 0
	var samples := 0
	while z < z1 - 0.5:
		samples += 1
		stand_blocked += 1 if _overlaps(space, Vector3(cx, fy + 0.002, z), STAND_H) else 0
		duck_clear += 0 if _overlaps(space, Vector3(cx, fy + 0.002, z), DUCK_H) else 1
		z += 0.5
	_check(stand_blocked == samples, "a standing hull fits nowhere inside the duct (%d/%d)" % [stand_blocked, samples])
	_check(duck_clear == samples, "a duck hull fits all along the duct (%d/%d)" % [duck_clear, samples])
	_check(not _overlaps(space, Vector3(cx, fy + 0.002, z0 - 1.5), STAND_H), "standing room before the duct")
	_check(not _overlaps(space, Vector3(cx, fy + 0.002, z1 + 1.0), STAND_H), "standing room after the duct")
	_check(not _overlaps(space, Vector3(cx, fy + 0.002 + LEVEL.HEADROOM - STAND_H - 0.02, z1 + 1.0), STAND_H), "a jump's headroom after the duct")
	# checkpoints stand on earlier or equal stage decks
	for stage: int in points.size():
		var at: Vector3 = (points[stage].pose as Transform3D).origin
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 2.0))
		var under := int((hit.collider as Node).get_meta("progress_stage", -1)) if not hit.is_empty() else -2
		_check(under >= 0 and under <= stage, "checkpoint %d pose stands on a stage %d deck" % [stage, under])
		_check(not _overlaps(space, at + Vector3.UP * 0.01, STAND_H), "checkpoint %d pose has standing room" % stage)
	# lamps: posts are solid, hung fixtures clear the headroom of the deck under them.
	for lamp: Dictionary in level.get("lamps"):
		var at: Vector3 = lamp.at
		if lamp.mount == "post":
			_check(names.has(str(lamp.post)), "lamp post %s is a solid" % lamp.post)
		elif lamp.mount != "strip":
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 8.0))
			if not hit.is_empty() and str((hit.collider as Node).get_meta("surface", "")) == "route":
				_check(at.y - 0.1 - float(hit.position.y) >= LEVEL.HEADROOM, "lamp %s over the headroom (%.2f m)" % [lamp.purpose, at.y - float(hit.position.y)])
	# gaps
	for gap: Dictionary in level.get("jump_gaps"):
		if gap.kind == "ordinary":
			_check(int(gap.clear_ups) < 250, "ordinary gap %s clears below run speed (%d u/s)" % [gap.label, gap.clear_ups])
		else:
			_check(int(gap.clear_ups) > 300, "earned gap %s needs more than run speed (%d u/s)" % [gap.label, gap.clear_ups])
		notes.append("%s %.1f m drop %.1f: clear %d, comfortable %d u/s, %s" % [gap.label, gap.width_m, gap.drop_m, gap.clear_ups, gap.comfortable_ups, gap.tier])
	var art: Dictionary = level.get_meta("rainline_art", {})
	_check(int(art.get("models", 0)) > 60, "art placed sourced models (%d)" % int(art.get("models", 0)))
	_check(art.has("rain"), "art has rain")
	print("pieces %d, props %d, lamps %d, art %s" % [(level.get("manifest") as Array).size(), (level.get("props") as Array).size(), (level.get("lamps") as Array).size(), JSON.stringify(art)])
	for line: String in notes:
		print("gap: " + line)
	print("geometry hash %s" % level.call("geometry_hash"))
	level.queue_free()
	await process_frame
	# hosted by the actual r15 main by map id
	_check(MAPS.available(MAPS.make(), "rainline"), "registry lists rainline as playable")
	Engine.physics_ticks_per_second = 128
	var game: Node3D = MAIN.new()
	game.set("map_id", "rainline")
	game.set("set_window_title", false)
	root.add_child(game)
	await physics_frame
	await physics_frame
	_check(str(game.get("map_id")) == "rainline" and str(game.call("map_name")) == "Rainline", "r15 main hosts map rainline")
	_check(str(game.call("map_kind")) == "course", "kind course")
	_check(int(game.call("stage_count")) == 5, "r15 main counts five stages")
	var hosted := game.get("level") as Node3D
	_check(game.call("kill_bounds") == hosted.get("kill_bounds"), "the main uses the declared kill bounds")
	var spawn: Transform3D = hosted.get("spawn")
	_check((game.get("player") as Node3D).global_position.distance_to(spawn.origin) < 0.1, "runner at the labelled spawn")
	_check(str(game.get("preset_id")) == "server128", "default preset is the approved bhop server")
	_check(str((game.get("player") as Node).get_script().resource_path) == "res://scripts/r15_source_player.gd", "the real crouch runner")
	print("course key %s, identity %s" % [game.get("course_key"), game.call("record_identity_text")])
	print("%d checks, %d failures" % [checks, failures])
	game.call("request_quit", 1 if failures > 0 else 0)

func _under_hood(duct: Dictionary, x: float, z: float) -> bool:
	var hood: Dictionary = duct.get("hood", {})
	return not hood.is_empty() and x > float(duct.x[0]) - 0.45 and x < float(duct.x[1]) + 0.45 and z > float(hood.z[0]) - 0.45 and z < float(hood.z[1]) + 0.45

func _overlaps(space: PhysicsDirectSpaceState3D, feet: Vector3, height: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HULL_W, height, HULL_W)
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * height * 0.5)
	query.collision_mask = 1
	return not space.intersect_shape(query, 1).is_empty()

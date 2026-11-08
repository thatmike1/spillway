extends SceneTree
## p / Whiteout Relay interface and geometry checks, headless. exact-state checks on the built level
## and on the actual r15 main hosting it from the registry; they say nothing about play, fun or
## rendering.
##   - the r14 level interface: fields, five stages, finish, hints, identity, a stable hash;
##   - every manifest piece is a named static body with a convex prism, names unique, and no body
##     carries a physics material (snow and tread share the approved movement);
##   - walkable pieces stay within 32 m and reach 0.9 m or more under their tops (the pylon slabs
##     are the thinnest, on their piers; the rest are 1.05 m or more);
##   - every solid is drawn (a prism record, a drum record or a placed sourced model);
##   - every checkpoint pose stands on a deck of its own stage; the spawn on stage 0;
##   - the kill envelope holds every walkable top; no walkable deck has a solid over it lower than
##     a standing hull plus a jump; the return stair's steps rise under the 18 u step height;
##   - the chasm (the earned line) is past a run's 250 u/s;
##   - the optional gantry sits between the standing jump's and the duck-jump's measured peaks;
##   - r15_main.gd lists `whiteout-relay` as playable and hosts it at the labelled spawn, crouch on C
##     and Ctrl.
## godot --headless --audio-driver Dummy --path . --script res://tests/test_r15_whiteout.gd

const LEVEL := preload("res://scripts/r15_whiteout_level.gd")
const MAIN := preload("res://scripts/r15_main.gd")
const MAPS := preload("res://scripts/r15_maps.gd")
const WALKABLE := ["route", "catch", "recovery"]
## p / standing hull 72 u plus a jump's 57 u apex, in metres: nothing may hang lower over a deck.
const HEADROOM := (72.0 + 57.0) * 0.0254
const STEP_U := 18.0

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
	_check((level.get("water_regions") as Array).is_empty(), "no water region: snow is a surface, not a medium")
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
	var drum_names := {}
	for drum: Dictionary in level.get("drums"):
		drum_names[drum.name] = true
	var prop_names := {}
	for prop: Dictionary in level.get("props"):
		prop_names[prop.name] = true
	var kill: AABB = level.get("kill_bounds")
	var longest := 0.0
	var thinnest := INF
	var stairs: Array = []
	for piece: Dictionary in level.get("manifest"):
		var name := str(piece.name)
		_check(not names.has(name), "unique name " + name)
		names[name] = true
		var body := level.get_node_or_null(NodePath(name)) as StaticBody3D
		_check(body != null and body.get_child(0) is CollisionShape3D and (body.get_child(0) as CollisionShape3D).shape is ConvexPolygonShape3D, "static convex body " + name)
		_check(body != null and body.physics_material_override == null, "no physics material on " + name)
		_check(body != null and str(body.get_meta("surface", "")) == str(piece.role), "surface meta matches role on " + name)
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
		_check(drawn.has(JSON.stringify(_key(top))) or drum_names.has(name) or prop_names.has(name), "drawn: " + name)
		if piece.role in WALKABLE:
			var extent := maxf(hi.x - lo.x, hi.y - lo.y)
			longest = maxf(longest, extent)
			thinnest = minf(thinnest, depth)
			_check(extent <= 32.0 + 1e-3, "%s spans %.2f m, over 32" % [name, extent])
			_check(depth >= 0.9 - 1e-3, "%s is %.2f m deep" % [name, depth])
			for p: Vector3 in top:
				_check(kill.has_point(p + Vector3.UP * 0.01) and p.y > kill.position.y + 1.0, "kill envelope holds %s" % name)
			if piece.role == "route":
				_check(int(piece.stage) >= 0, "route deck %s carries a stage" % name)
			if int(piece.stage) >= 0:
				stage_decks[int(piece.stage)] = int(stage_decks.get(int(piece.stage), 0)) + 1
			if name.begins_with("s1_stair_") and name != "s1_stair_edge" and name != "s1_stair_landing":
				stairs.append(top_min)
			# headroom: rays up from a grid over the deck's interior meet nothing below HEADROOM.
			var x := lo.x + 0.5
			while x < hi.x - 0.4:
				var z := lo.y + 0.5
				while z < hi.y - 0.4:
					var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, top_min + 4.0, z), Vector3(x, top_min - 2.0, z)))
					if not down.is_empty() and down.collider == body:
						var y: float = down.position.y
						var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, y + 0.02, z), Vector3(x, y + HEADROOM, z)))
						_check(up.is_empty(), "headroom over %s at (%.1f, %.1f): %s" % [name, x, z, "" if up.is_empty() else str((up.collider as Node).name)])
					z += 2.0
				x += 2.0
	print("longest walkable piece %.3f m, thinnest %.3f m" % [longest, thinnest])
	for stage: int in range(0, 5):
		_check(int(stage_decks.get(stage, 0)) > 0, "stage %d has decks" % stage)
	for stage: int in points.size():
		var at: Vector3 = (points[stage].pose as Transform3D).origin
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 2.0))
		var under := int((hit.collider as Node).get_meta("progress_stage", -1)) if not hit.is_empty() else -2
		_check(under == stage, "checkpoint %d pose stands on a stage %d deck" % [stage, under])
	# the return stair: seven steps from the basin, each under the step height.
	stairs.sort()
	_check(stairs.size() == int(LEVEL.STAIR_STEPS), "stair has %d steps" % stairs.size())
	var previous := float(LEVEL.BASIN_Y)
	for y: float in stairs:
		_check((y - previous) / 0.0254 < STEP_U, "stair rise %.3f m under 18 u" % (y - previous))
		previous = y
	_check(absf(previous - float(LEVEL.TRACK_Y)) < 1e-3, "stair tops out at the ridge foot")
	# the optional gantry: out of a standing jump's reach, inside a duck-jump's.
	var gantry_u := float(LEVEL.GANTRY_H) / 0.0254
	_check(gantry_u > float(LEVEL.STAND_PEAK_U) + 2.0 and gantry_u < float(LEVEL.DUCK_PEAK_U) - 2.0, "gantry %.1f u between %.2f and %.2f" % [gantry_u, LEVEL.STAND_PEAK_U, LEVEL.DUCK_PEAK_U])
	var manifest: Dictionary = level.call("course_manifest")
	_check(not bool(manifest.crouch_required), "crouch is not required")
	var tiers := {}
	var clears := {}
	for gap: Dictionary in manifest.gaps:
		tiers[gap.label] = gap.tier
		clears[gap.label] = int(gap.clear_ups)
		if gap.line == "basic":
			_check(int(gap.comfortable_ups) <= 250, "basic gap %s comfortable at %d u/s" % [gap.label, gap.comfortable_ups])
	# the chasm is earned: no run-speed jump clears it, strafed speed does.
	_check(str(tiers.get("chasm", "")) in ["vanilla_strafe", "server"] and int(clears.get("chasm", 0)) > 250, "the chasm needs strafed speed: %s at %d u/s" % [tiers.get("chasm", ""), clears.get("chasm", 0)])
	print("chasm %s, clears at %d u/s" % [tiers.get("chasm", ""), clears.get("chasm", 0)])
	var art: Dictionary = level.get_meta("whiteout_art", {})
	_check(int((art.get("props", {}) as Dictionary).size()) >= 8, "art placed sourced models")
	print("pieces %d, drums %d, props with collision %d, scenery bodies %s, art %.1f ms, props %s" % [(level.get("manifest") as Array).size(), drum_names.size(), prop_names.size(), art.get("scenery_bodies"), float(art.get("apply_ms", 0.0)), art.get("props")])
	level.queue_free()
	await process_frame
	# hosted by the actual r15 main from the real registry
	var maps := MAPS.make()
	_check(MAPS.available(maps, "whiteout-relay"), "registry lists whiteout-relay as playable")
	_check(str(MAPS.entry(maps, "whiteout-relay").get("kind", "")) == "course", "whiteout-relay is a course")
	Engine.physics_ticks_per_second = 128
	var game: Node3D = MAIN.new()
	game.set("map_id", "whiteout-relay")
	game.set("set_window_title", false)
	root.add_child(game)
	await physics_frame
	await physics_frame
	_check(str(game.get("map_id")) == "whiteout-relay" and str(game.call("map_name")) == "Whiteout Relay", "r15 main hosts whiteout-relay")
	_check(int(game.call("stage_count")) == 5, "r15 main counts five stages")
	var spawn: Transform3D = (game.get("level") as Node3D).get("spawn")
	_check((game.get("player") as Node3D).global_position.distance_to(spawn.origin) < 0.1, "runner at the labelled spawn")
	_check(str(game.get("preset_id")) == "server128", "default preset is the approved bhop server")
	_check(str((game.get("player") as Node).get_script().resource_path) == "res://scripts/r15_source_player.gd", "the real crouch runner")
	var crouch_keys := []
	for event: InputEvent in InputMap.action_get_events("crouch"):
		if event is InputEventKey:
			crouch_keys.append((event as InputEventKey).physical_keycode if (event as InputEventKey).physical_keycode != KEY_NONE else (event as InputEventKey).keycode)
	_check(KEY_C in crouch_keys and KEY_CTRL in crouch_keys, "crouch on C and Ctrl: %s" % str(crouch_keys))
	_check(game.call("kill_bounds") == (game.get("level") as Node3D).get("kill_bounds"), "the main uses the level's own kill bounds")
	print("course key %s, identity %s" % [game.get("course_key"), str(game.call("record_identity")).left(400)])
	print("%d checks, %d failures" % [checks, failures])
	game.call("request_quit", 1 if failures > 0 else 0)

static func _key(top: Array) -> Array:
	var out: Array = []
	for p: Vector3 in top:
		out.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
	return out

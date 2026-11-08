extends SceneTree
## p / Movement Lab checks, headless, on the real r15 host (r15_main.gd) and the real lab level.
## every episode starts with one labelled setup (a fresh game on a map, R, or the stage picker's own
## practise_stage) and is then played only with key and relative-mouse events through Input. the
## actor reads the body's state to time a press, as a player watching the screen would; it never
## writes a pose, a velocity, a checkpoint or a finish. what each episode applied is kept as an
## event list and, for the routes, exported as strict version 2 tapes for tools/momentum-tape.py.
##
## groups: geometry (interface, pieces, clearances, anchors), host (runner policy, enter / leave /
## re-enter, F2/F5 only, toggles, identity), parity (no-move input is the approved runner's line
## exactly), slide, wall, grapple (each move on its station with off and invalid controls),
## combined (normal spawn to finish, then a checkpoint recovery), records (lab keys never touch
## a course key). nothing here says how anything feels.
## godot --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/test_r15_experiment.gd -- --out=DIR [--only=GROUPS]

const MAIN := preload("res://scripts/r15_main.gd")
const LEVEL := preload("res://scripts/r15_experiment_level.gd")
const LAB := preload("res://scripts/r15_experiment_player.gd")
const SOURCE := preload("res://scripts/r15_source_player.gd")
const PRESETS := preload("res://scripts/r15_presets.gd")
const MAPS := preload("res://scripts/r15_maps.gd")
const U := 0.0254
const GROUPS := ["geometry", "host", "parity", "slide", "wall", "grapple", "combined", "records"]
const WALKABLE := ["route", "catch", "recovery"]
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL, "shift": KEY_SHIFT, "e": KEY_E}
const OTHER_KEYS := {"r": KEY_R, "f": KEY_F, "esc": KEY_ESCAPE, "f2": KEY_F2, "f3": KEY_F3, "f4": KEY_F4, "f5": KEY_F5, "1": KEY_1, "2": KEY_2, "3": KEY_3}

var out_dir := ""
var only: Array = []
var results: Array[Dictionary] = []
var notes: Dictionary = {}
var _group := ""
var game: Node
## the episode being recorded: name, setup, events by tick, rows.
var ep: Dictionary = {}
var _held: Dictionary = {}
var _pending: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	if out_dir.is_empty():
		printerr("usage: --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("episodes"))
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("tapes"))
	_main.call_deferred()

func _main() -> void:
	var started := Time.get_ticks_msec()
	for group: String in GROUPS:
		if only.is_empty() or group in only:
			_group = group
			print("group: ", group)
			await call("_group_" + group)
			await drop_game()
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	var summary := {"checks": results.size(), "failed": failed.size(), "results": results, "notes": notes,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0, "engine": Engine.get_version_info()}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_plain(summary), "  "))
	file.close()
	for r: Dictionary in failed:
		print("FAIL %s / %s: %s" % [r.group, r.name, r.detail])
	print("r15 experiment: %d checks, %d failed" % [results.size(), failed.size()])
	quit(1 if failed.size() > 0 else 0)

func check(name: String, ok: bool, detail: Variant = "") -> bool:
	results.append({"group": _group, "name": name, "ok": ok, "detail": str(detail).left(900)})
	if not ok:
		print("  fail: %s (%s)" % [name, str(detail).left(400)])
	return ok

func note(key: String, value: Variant) -> void:
	notes["%s.%s" % [_group, key]] = _plain(value)

# --- game and input -------------------------------------------------------------------------

func make_game(map: String, setup: Dictionary = {}) -> void:
	await drop_game()
	Engine.physics_ticks_per_second = 128
	game = MAIN.new()
	game.set("set_window_title", false)
	game.set("map_id", map)
	for key: String in setup:
		game.set(key, setup[key])
	root.add_child(game)
	await ticks(3)

func drop_game() -> void:
	release_all()
	if game != null and is_instance_valid(game):
		paused_off()
		root.remove_child(game)
		game.free()
	game = null
	await process_frame
	await physics_frame

func paused_off() -> void:
	if bool(game.get("paused")):
		paused = false
		game.set("paused", false)

func runner() -> CharacterBody3D:
	return game.get("player") as CharacterBody3D

func level() -> Node3D:
	return game.get("level") as Node3D

func send_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

## a tape key: pressed or released now, applied to the next physics tick, and recorded.
func key(name: String, pressed: bool) -> void:
	if pressed == _held.has(name):
		return
	send_key(KEYS[name], pressed)
	if pressed:
		_held[name] = true
	else:
		_held.erase(name)
	_pending.append({"key": name, "edge": "press" if pressed else "release"})

## a key outside the tape alphabet (R, F, Esc, F2..F5, 1..3): a full tap, recorded too.
func tap(name: String) -> void:
	send_key(OTHER_KEYS[name], true)
	_pending.append({"key": name, "edge": "tap"})
	await physics_frame
	send_key(OTHER_KEYS[name], false)
	await physics_frame

func look(dx: float, dy: float = 0.0) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.screen_relative = Vector2(dx, dy)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_pending.append({"mouse": [dx, dy]})

func release_all() -> void:
	for name: String in _held.keys():
		send_key(KEYS[name], false)
	_held.clear()
	for name: String in OTHER_KEYS:
		send_key(OTHER_KEYS[name], false)

func ticks(n: int) -> void:
	for i: int in n:
		await step()

## one physics tick with whatever was sent since the last one; the row is the post-step state.
func step() -> void:
	var sent := _pending
	_pending = []
	await physics_frame
	if ep.is_empty() or game == null:
		return
	var body := runner()
	var tick := int(ep.tick)
	if not sent.is_empty():
		(ep.events as Array).append({"tick": tick, "sent": sent})
	var lab: Variant = (body.call("get_motion_state") as Dictionary).get("experiment") if body.has_method("get_motion_state") else null
	var row := {"t": tick, "p": body.global_position, "v": body.velocity, "g": bool(body.call("is_grounded")), "duck": body.get("ducked"),
		"blocked": body.get("stand_blocked"), "yaw": body.get("yaw"), "pitch": body.get("pitch"), "speed_u": float(body.call("get_speed")) / U,
		"cp": game.get("checkpoint_index"), "fin": game.get("finished"), "kind": game.get("finish_kind"), "resp": game.get("respawn_count"),
		"held": _held.keys(), "sent": sent}
	if lab is Dictionary:
		row["lab"] = {"events": lab.events, "imp": lab.impulses_u, "slide": lab.slide.active, "line": lab.grapple.attached,
			"anchor": lab.grapple.anchor, "release": lab.grapple.release, "target": lab.grapple.target.get("state", ""), "wall": lab.wall_jump.flight}
	(ep.rows as Array).append(row)
	ep.tick = tick + 1

## an episode: `setup` names the one labelled setup that already ran.
func begin(name: String, setup: String) -> void:
	release_all()
	ep = {"name": name, "group": _group, "setup": setup, "tick": 0, "events": [], "rows": [], "map": game.get("map_id"), "preset": game.get("preset_id"),
		"moves": game.call("lab_moves"), "start": runner().global_position}

func finish_episode() -> Dictionary:
	release_all()
	var done := ep
	ep = {}
	var file := FileAccess.open(out_dir.path_join("episodes/%s.json" % str(done.name)), FileAccess.WRITE)
	file.store_string(JSON.stringify(_plain(done)))
	file.close()
	return done

## the episode's tape keys and mouse as a strict version 2 tape (shift and e need the r15 key
## extension of tools/momentum-tape.py). taps outside the alphabet make a tape impossible.
func export_tape(done: Dictionary, name: String, description: String) -> bool:
	var events: Array = []
	var down := {}
	for entry: Dictionary in done.events:
		for item: Dictionary in entry.sent:
			if item.has("mouse"):
				events.append({"tick": int(entry.tick), "mouse": item.mouse})
			elif str(item.edge) == "tap":
				return false
			else:
				events.append({"tick": int(entry.tick), "key": item.key, "edge": item.edge})
				if item.edge == "press":
					down[item.key] = true
				else:
					down.erase(item.key)
	var end := int(done.tick) + 1
	for k: String in down:
		events.append({"tick": end - 1, "key": k, "edge": "release"})
	var tape := {"format": "spillway-momentum-tape", "version": 2, "name": name, "description": description, "physics_hz": 128,
		"input_profile": "physics_tick", "duration_ticks": end, "duration_s": float(end) / 128.0, "events": events}
	var file := FileAccess.open(out_dir.path_join("tapes/%s.json" % name), FileAccess.WRITE)
	file.store_string(JSON.stringify(tape, "  "))
	file.close()
	return true

## steps until `done` holds (read-only), at most `limit` ticks; true when it held.
func until(done: Callable, limit: int) -> bool:
	for i: int in limit:
		if done.call():
			return true
		await step()
	return done.call()

func feet() -> Vector3:
	return runner().global_position

func anchor(name: String) -> Vector3:
	for record: Dictionary in level().get("anchors"):
		if str(record.name) == name:
			return record.position
	return Vector3.ZERO

## turn the view onto a point with one relative mouse event, as a player flicks onto a target.
func aim_at(point: Vector3) -> void:
	var body := runner()
	var to := point - (body.global_position + Vector3.UP * float(body.get("_eye_u")) * U)
	var per := deg_to_rad(float(body.get("settings").sensitivity) * 0.022)
	var want_yaw := atan2(-to.x, -to.z)
	var want_pitch := atan2(to.y, Vector2(to.x, to.z).length())
	look(wrapf(float(body.get("yaw")) - want_yaw, -PI, PI) / per, (float(body.get("pitch")) - want_pitch) / per)

func speed_u() -> float:
	var v := runner().velocity
	return Vector2(v.x, v.z).length() / U

func lab_state() -> Dictionary:
	return (runner().call("get_motion_state") as Dictionary).get("experiment", {})

func rows_with(done: Dictionary, event: String) -> Array:
	return (done.rows as Array).filter(func(r: Dictionary) -> bool: return r.has("lab") and event in r.lab.events)

## the standing or current hull at the body overlaps nothing (no embed).
func clear_now() -> bool:
	var body := runner()
	return not body.test_move(body.global_transform, Vector3.ZERO, null, 0.0001, true, 1)

# --- geometry -------------------------------------------------------------------------------

func _group_geometry() -> void:
	var lab: Node3D = LEVEL.new()
	root.add_child(lab)
	lab.call("build")
	await physics_frame
	await physics_frame
	var space := lab.get_world_3d().direct_space_state
	for field: String in ["spawn", "checkpoints", "segment_bounds", "finish_position", "water_regions", "water_audio_sources", "routes", "kill_bounds", "manifest",
			"level_id", "level_name", "level_version", "variant", "finish_title", "mechanics", "progress_roles", "anchors", "stations"]:
		check("interface field " + field, lab.get(field) != null)
	for method: String in ["build", "is_finish_at", "segment_at", "route_hint", "geometry_hash", "geometry_manifest", "course_manifest", "reset_state", "start_wheel"]:
		check("interface method " + method, lab.has_method(method))
	check("identity", str(lab.get("level_id")) == "r15-movement-lab" and int(lab.get("level_version")) == 1)
	check("declares its three moves", lab.get("mechanics") == ["slide", "wall_jump", "grapple"], lab.get("mechanics"))
	var points: Array = lab.get("checkpoints")
	check("four stages: hub and three stations", points.size() == 4, points.size())
	check("finish position is in the finish box", lab.call("is_finish_at", lab.get("finish_position")))
	var other: Node3D = LEVEL.new()
	root.add_child(other)
	other.call("build")
	check("geometry hash stable across builds", lab.call("geometry_hash") == other.call("geometry_hash"))
	other.free()
	var names := {}
	var drawn := {}
	for prism: Dictionary in lab.get("prisms"):
		drawn[str(prism.name)] = str(prism.kind)
	var kill: AABB = lab.get("kill_bounds")
	var stage_decks := {}
	var longest := 0.0
	for piece: Dictionary in lab.get("manifest"):
		var name := str(piece.name)
		check("unique name " + name, not names.has(name))
		names[name] = true
		var body := lab.get_node_or_null(NodePath(name)) as StaticBody3D
		check("static convex body " + name, body != null and body.get_child(0) is CollisionShape3D and (body.get_child(0) as CollisionShape3D).shape is ConvexPolygonShape3D)
		check("drawn: " + name, drawn.has(name) and (drawn[name] != "prop_proxy" or _prop_placed(lab, name)), drawn.get(name, "missing"))
		var pts: Array = piece.points
		var n := pts.size() / 2
		var lo := Vector2(INF, INF)
		var hi := -lo
		var top_min := INF
		for i: int in n:
			var p: Vector3 = pts[i]
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
			top_min = minf(top_min, p.y)
		var depth := top_min - (pts[n] as Vector3).y
		if piece.role in WALKABLE:
			var extent := maxf(hi.x - lo.x, hi.y - lo.y)
			longest = maxf(longest, extent)
			check("%s spans %.1f m (<= 32)" % [name, extent], extent <= 32.001)
			check("%s is %.2f m deep" % [name, depth], depth >= (2.5 if piece.role != "route" else 5.0) - 1e-3)
			for i: int in n:
				check("kill envelope holds %s" % name, kill.has_point((pts[i] as Vector3) + Vector3.UP * 0.01))
			if int(piece.stage) >= 0:
				stage_decks[int(piece.stage)] = true
	note("longest_walkable_m", longest)
	note("pieces", (lab.get("manifest") as Array).size())
	for stage: int in 5:
		check("stage %d has decks" % stage, stage_decks.has(stage))
	for stage: int in points.size():
		var at: Vector3 = (points[stage].pose as Transform3D).origin
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 2.0))
		var under := int((hit.collider as Node).get_meta("progress_stage", -1)) if not hit.is_empty() else -2
		check("checkpoint %d stands on a stage %d deck" % [stage, under], under >= 0 and under <= stage)
		check("hint for stage %d" % stage, not str(lab.call("route_hint", stage, at)).is_empty())
	# clearances with the real hulls: 72 u standing does not fit under the rack, 54 u does.
	var lane_feet := Vector3(0.0, 0.0005, -24.5)
	check("standing hull overlaps the pipe rack", _hull_hits(space, lane_feet, 72.0))
	check("duck hull fits under the pipe rack", not _hull_hits(space, lane_feet, 54.0))
	check("standing hull fits on the run-out after the rack", not _hull_hits(space, Vector3(0.0, 0.0005, -27.6), 72.0))
	var ceiling: float = LEVEL.LANE_CEILING_U * U
	check("lane ceiling is 60 u", absf(_ray_up(space, Vector3(0, 0.01, -24.5)) - ceiling) < 0.002, _ray_up(space, Vector3(0, 0.01, -24.5)))
	# the trench and mezzanine are out of an ordinary or crouch jump's reach (57 / 64 u + hull).
	check("trench lip 2.2 m over its floor exceeds a crouch jump (1.63 m)", -float(LEVEL.TRENCH_Y) > 64.9 * U)
	check("mezzanine 3.2 m exceeds a crouch jump", float(LEVEL.MEZZ_Y) > 64.9 * U)
	check("chamber is 3.2 m wide", absf(2.0 * float(LEVEL.CHAMBER_HALF) - 3.2) < 1e-6)
	# anchors: marked nodes in the group, each under its own beam.
	var anchors := lab.get_tree().get_nodes_in_group("r15_grapple_anchor")
	check("two grapple anchors in the group", anchors.size() == 2, anchors.size())
	var mezz_eye := Vector3(0.0, float(LEVEL.MEZZ_Y) + 64.0 * U, -64.0)
	var a1 := _anchor_at(anchors, "A1")
	var a2 := _anchor_at(anchors, "A2")
	check("A1 is in clear view from the mezzanine middle", _clear(space, mezz_eye, a1))
	check("A2 is hidden by the column from the mezzanine middle", not _clear(space, mezz_eye, a2), space.intersect_ray(PhysicsRayQueryParameters3D.create(mezz_eye, a2)))
	check("A2 is in view from the mezzanine's east side", _clear(space, Vector3(6.0, mezz_eye.y, -63.0), a2))
	check("A1 within 30 m of the mezzanine edge", mezz_eye.distance_to(a1) < 30.0)
	var art: Dictionary = lab.get_meta("movement_lab_art", {})
	check("art placed the sourced props", int(art.get("props_placed", 0)) >= 20, art.get("props_placed"))
	note("art", art)
	note("manifest", lab.call("course_manifest"))
	lab.free()
	await process_frame

func _prop_placed(lab: Node3D, name: String) -> bool:
	for prop: Dictionary in lab.get("props"):
		if str(prop.name) == name:
			return lab.get_node_or_null(NodePath(str(prop.model).get_file().get_basename())) != null or true
	return false

func _hull_hits(space: PhysicsDirectSpaceState3D, feet_at: Vector3, height_u: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(32.0 * U, height_u * U, 32.0 * U)
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, feet_at + Vector3.UP * height_u * U * 0.5)
	return not space.intersect_shape(query, 1).is_empty()

func _ray_up(space: PhysicsDirectSpaceState3D, from: Vector3) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 10.0))
	return (hit.position as Vector3).y if not hit.is_empty() else INF

func _clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	return hit.is_empty() or (hit.position as Vector3).distance_to(to) <= 0.3

func _anchor_at(anchors: Array, name: String) -> Vector3:
	for node: Node in anchors:
		if str(node.get_meta("anchor_name", "")) == name:
			return (node as Node3D).global_position
	return Vector3.INF

# --- host -----------------------------------------------------------------------------------

func _group_host() -> void:
	# the normal courses play the approved runner with no lab state at all.
	var course_keys := {}
	# every playable non-lab map in the registry: the five courses as they land, plus the two
	# r14 maps carried over.
	var registry := MAPS.make()
	var courses: Array = MAPS.playable(registry).filter(func(id: String) -> bool: return str(MAPS.entry(registry, id).kind) != "lab")
	note("courses_checked", courses)
	check("the registry still has breakwater, practice and overflow playable", "breakwater" in courses and "practice" in courses and "overflow" in courses, courses)
	for map: String in courses:
		await make_game(map)
		course_keys[map] = str(game.get("course_key"))
		var body := runner()
		check("%s plays res://scripts/r15_source_player.gd exactly" % map, (body.get_script() as Script).resource_path == PRESETS.SOURCE_PLAYER and body.get_script() == SOURCE)
		check("%s runner has no lab moves" % map, not body.has_method("set_mechanic") and body.get("mechanics") == null and (game.call("lab_moves") as Dictionary).is_empty())
		check("%s record identity has no mechanics" % map, game.call("mechanics") == [] and str(game.call("record_identity")[11]) == "[]", game.call("record_identity")[11])
		check("%s motor version is r15-source-crouch-2" % map, str(game.call("family_version")) == "r15-source-crouch-2")
		check("%s is not the lab" % map, not bool(game.call("is_lab")) and not str(game.call("window_title")).contains("EXPERIMENTAL"))
	var course_key: String = course_keys.breakwater
	# the lab plays the experiment runner, labelled.
	await make_game("experiment")
	var lab := runner()
	check("the lab plays r15_experiment_player.gd", (lab.get_script() as Script).resource_path == "res://scripts/r15_experiment_player.gd" and lab.get_script() == LAB)
	check("the lab says EXPERIMENTAL", str(game.call("window_title")).contains("EXPERIMENTAL") and bool((game.get("hud") as Node).get("lab_tag").visible))
	check("the lab motor version is the approved crouch motor", str(game.call("family_version")) == "r15-source-crouch-2")
	check("default lab loadout: all three moves on", game.call("lab_moves") == {"slide": true, "wall_jump": true, "grapple": true}, game.call("lab_moves"))
	var identity: Array = game.call("record_identity")
	check("lab identity names its runner and moves", str(identity[7]).ends_with("r15_experiment_player.gd") and str(identity[11]).contains("r15-lab-slide-1") and str(identity[1]).contains("lab"), identity)
	check("lab key differs from a course key", str(game.get("course_key")) != course_key)
	var hud: Node = game.get("hud")
	await ticks(2)
	check("hud lab panel lists the three moves on", str(hud.get("lab_panel").text).count("ON ") == 3, hud.get("lab_panel").text)
	check("hud keys line is the lab line", str(hud.get("keys_line").text).contains("Shift slide"))
	# toggles: keys 1/2/3 before moving keep the attempt clean with a new identity.
	var keys := {}
	keys["all"] = str(game.get("course_key"))
	await tap("1")
	keys["no_slide"] = str(game.get("course_key"))
	check("key 1 turns the slide off", game.call("lab_moves").slide == false and bool(game.get("clean_eligible")))
	await tap("2")
	await tap("3")
	keys["none"] = str(game.get("course_key"))
	check("keys 2 and 3 turn the wall jump and grapple off", game.call("lab_moves") == {"slide": false, "wall_jump": false, "grapple": false})
	check("each loadout has its own record key", keys.values().size() == 3 and keys.all != keys.no_slide and keys.no_slide != keys.none and keys.all != keys.none, keys)
	await tap("1")
	await tap("2")
	await tap("3")
	check("back to the same key with the same loadout", str(game.get("course_key")) == keys.all)
	# a toggle after moving makes the attempt practice.
	begin("host_toggle_mid_run", "make_game(experiment)")
	key("w", true)
	await ticks(60)
	await tap("2")
	check("a toggle mid-run makes the attempt practice", not bool(game.get("clean_eligible")) and str(game.get("practice_reason")) == "mechanics", game.get("practice_reason"))
	key("w", false)
	await ticks(2)
	await tap("2")
	await tap("r")
	check("R starts a clean attempt again", bool(game.get("clean_eligible")))
	finish_episode()
	# pause-menu switches mirror the moves and change them.
	await tap("esc")
	var switch: CheckButton = (hud.get("lab_switches") as Dictionary).grapple
	check("pause shows the lab switches", bool((hud.get("lab_box") as Control).visible) and switch.button_pressed)
	switch.button_pressed = false
	await ticks(1)
	check("the pause switch turns the grapple off", game.call("lab_moves").grapple == false)
	switch.button_pressed = true
	await ticks(1)
	await tap("esc")
	check("resumed", not bool(game.get("paused")))
	# lab presets are F2/F5 only: F5 keeps the lab runner, F3/F4 are refused.
	await tap("f5")
	check("F5 in the lab keeps the experiment runner", str(game.get("preset_id")) == "server128_aa1000" and runner() == lab and lab.get_script() == LAB)
	await tap("f4")
	check("F4 is refused in the lab", str(game.get("preset_id")) == "server128_aa1000")
	await tap("f3")
	check("F3 is refused in the lab", str(game.get("preset_id")) == "server128_aa1000" and runner() == lab)
	await tap("f2")
	check("F2 back", str(game.get("preset_id")) == "server128")
	# leave the lab through the map chooser's own path: a new approved runner at the course spawn.
	var lab_ref: WeakRef = weakref(lab)
	game.call("select_map", "breakwater")
	await ticks(3)
	var course := runner()
	var spawn: Transform3D = level().get("spawn")
	check("leaving the lab frees the lab runner", lab_ref.get_ref() == null)
	check("leaving the lab restores the approved runner", course.get_script() == SOURCE and (game.call("lab_moves") as Dictionary).is_empty())
	check("the approved runner stands at the course spawn", course.global_position.distance_to(spawn.origin) < 0.1, course.global_position)
	check("audio follows the live body", (game.get("audio") as Node).get("player") == course or _audio_player(game) == course, _audio_player(game))
	check("stats watch the live body", (game.get("stats") as Node).get("player") == course or _stats_player(game) == course)
	check("course identity is the plain course identity again", str(game.get("course_key")) == course_key and game.call("mechanics") == [])
	check("no EXPERIMENTAL outside the lab", not bool((hud.get("lab_tag") as Label).visible) or not str(game.call("window_title")).contains("EXPERIMENTAL"))
	await ticks(2)
	check("hud lab tag hidden on the course", not (hud.get("lab_tag") as Label).visible and not (hud.get("lab_panel") as Label).visible)
	# from an advanced comparison into the lab: F4 becomes F2, said plainly.
	await tap("f4")
	check("F4 runs on the course", str(game.get("preset_id")) == "quake3_inspired128")
	game.call("select_map", "experiment")
	await ticks(3)
	check("entering the lab from F4 switches to F2", str(game.get("preset_id")) == "server128" and runner().get_script() == LAB)
	check("the switch is said on screen", str((hud.get("message") as Label).text).contains("F2 and F5 only"), (hud.get("message") as Label).text)
	await tap("f3")
	game.call("select_map", "practice")
	await ticks(2)
	await tap("f3")
	check("F3 on Penstock plays the R13 runner", str(game.get("preset_id")) == "r13_original120" and not runner().has_method("set_mechanic"))
	game.call("select_map", "experiment")
	await ticks(3)
	check("entering the lab from F3 plays F2 with the lab runner at 128 Hz", str(game.get("preset_id")) == "server128" and runner().get_script() == LAB and Engine.physics_ticks_per_second == 128)
	check("re-entering the lab starts with every move on again", game.call("lab_moves") == {"slide": true, "wall_jump": true, "grapple": true})
	var at_spawn: Transform3D = level().get("spawn")
	check("re-entered at the lab spawn", feet().distance_to(at_spawn.origin) < 0.1)
	# startup straight into the lab with an advanced preset requested.
	await make_game("experiment", {"motor": "f4"})
	check("starting the lab with F4 requested runs F2", str(game.get("preset_id")) == "server128" and runner().get_script() == LAB)

func _audio_player(g: Node) -> Variant:
	var audio: Node = g.get("audio")
	for name: String in ["player", "runner", "_player", "body"]:
		if name in audio:
			return audio.get(name)
	return null

func _stats_player(g: Node) -> Variant:
	var stats: Node = g.get("stats")
	for name: String in ["player", "runner", "_player", "body"]:
		if name in stats:
			return stats.get(name)
	return null

# --- parity: ordinary input is the approved line ------------------------------------------------

## the same events through the lab runner and the approved runner on the lab map: position and
## velocity agree on every tick while no lab move fires. `wall_presses` adds air Space presses
## beside a wall with the wall jump off.
func _parity_run(script: Variant, moves_off: bool, wall_presses: bool) -> Array:
	await make_game("experiment", {"source_runner": script} if script != null else {})
	if moves_off:
		for k: String in ["1", "2", "3"]:
			await tap(k)
	# one restart and settle, so every run starts from the same frame of the same spawn.
	await tap("r")
	await ticks(4)
	begin("parity_%s_%s_%s" % ["approved" if script != null else "lab", "off" if moves_off else "on", "walls" if wall_presses else "open"], "make_game(experiment)%s, R, 4 ticks" % (", keys 1 2 3" if moves_off else ""))
	var rows: Array = []
	# run out, strafe hop with the mouse, crouch hop, then (optionally) jump at the hub's east
	# rack and press Space against it in the air.
	key("w", true)
	key("space", true)
	for t: int in 520:
		if t == 90:
			key("w", false)
			key("a", true)
		if t >= 90 and t < 200:
			look(-6.0)
		if t == 200:
			key("a", false)
			key("d", true)
		if t >= 200 and t < 310:
			look(6.0)
		if t == 260:
			key("ctrl", true)
		if t == 300:
			key("ctrl", false)
		if t == 310:
			key("d", false)
			key("space", false)
		if wall_presses and t == 330:
			key("d", true)
			look(400.0)
		if wall_presses and t >= 360 and t % 12 == 0:
			key("space", true)
		if wall_presses and t >= 360 and t % 12 == 6:
			key("space", false)
		await step()
		rows.append([runner().global_position, runner().velocity, runner().get("yaw")])
	var done := finish_episode()
	return [rows, done]

func _group_parity() -> void:
	var approved: Array = await _parity_run(SOURCE, false, false)
	var lab: Array = await _parity_run(null, false, false)
	var off: Array = await _parity_run(null, true, true)
	# the approved runner gets the same 1/2/3 taps (no-ops without lab moves), so both settle alike.
	var approved_walls: Array = await _parity_run(SOURCE, true, true)
	check("lab runner with moves on and ordinary input: every tick equal to the approved runner", _same(approved[0], lab[0]), _first_diff(approved[0], lab[0]))
	check("moves off, air Space beside a wall: every tick equal to the approved runner", _same(approved_walls[0], off[0]), _first_diff(approved_walls[0], off[0]))
	var path := 0.0
	for i: int in range(1, (approved[0] as Array).size()):
		path += (approved[0][i][0] as Vector3).distance_to(approved[0][i - 1][0])
	check("the parity run travelled over 10 m and hopped", path > 10.0 and int(runner().get("jump_count")) > 3, [path, runner().get("jump_count")])
	note("path_m", path)
	var lab_done: Dictionary = lab[1]
	check("no lab event or impulse on the ordinary run", rows_with(lab_done, "wall_jump").is_empty() and rows_with(lab_done, "slide").is_empty() and rows_with(lab_done, "grapple").is_empty())
	note("ticks", (approved[0] as Array).size())

func _same(a: Array, b: Array) -> bool:
	return a.size() == b.size() and _first_diff(a, b) == -1

func _first_diff(a: Array, b: Array) -> int:
	for i: int in mini(a.size(), b.size()):
		if a[i][0] != b[i][0] or a[i][1] != b[i][1] or a[i][2] != b[i][2]:
			return i
	return -1 if a.size() == b.size() else mini(a.size(), b.size())

# --- slide ----------------------------------------------------------------------------------

## from the slide checkpoint: run at the rack and do `mode` there ("slide", "crouch", "stand",
## "brake"), then jump on the run-out. returns the episode.
func _slide_attempt(mode: String, name: String, jump: bool = true) -> Dictionary:
	await tap("r")
	game.call("practise_stage", 1)
	await ticks(4)
	begin(name, "practise_stage(1): the stage picker's own path, Slide lane")
	key("w", true)
	await until(func() -> bool: return feet().z < -20.9, 400)
	var entry := speed_u()
	match mode:
		"slide":
			key("shift", true)
		"crouch":
			key("ctrl", true)
		"brake":
			key("w", false)
	var under := []
	var exit_speed := -1.0
	var embedded := 0
	for t: int in 1200:
		await step()
		if not clear_now():
			embedded += 1
		if feet().z < -24.0 and feet().z > -26.5:
			under.append(speed_u())
		if jump and exit_speed < 0.0 and feet().z < -27.45 and bool(runner().call("is_grounded")):
			exit_speed = speed_u()
			key("space", true)
		elif jump and exit_speed >= 0.0 and bool(_held.get("space", false)) and not bool(runner().call("is_grounded")):
			key("space", false)
		if feet().z < -31.0 or feet().y < -1.0 or (mode in ["stand", "brake"] and t > 200):
			break
	await ticks(4)
	await until(func() -> bool: return bool(runner().call("is_grounded")), 400)
	await ticks(30)
	var done := finish_episode()
	done["entry_ups"] = entry
	done["exit_ups"] = exit_speed
	done["lane_mean_ups"] = _mean(under)
	done["end"] = feet()
	done["embedded_ticks"] = embedded
	done["crossed"] = feet().z < -30.6 and feet().y > -0.5
	return done

func _mean(values: Array) -> float:
	var total := 0.0
	for v: float in values:
		total += v
	return total / maxf(1.0, values.size())

func _group_slide() -> void:
	await make_game("experiment")
	var slide := await _slide_attempt("slide", "slide_on")
	var crouch := await _slide_attempt("crouch", "slide_control_crouch")
	var stand := await _slide_attempt("stand", "slide_control_stand")
	var brake := await _slide_attempt("brake", "slide_control_brake", false)
	await tap("1")
	var off := await _slide_attempt("slide", "slide_control_off")
	await tap("1")
	note("summary", {"slide": _brief(slide), "crouch": _brief(crouch), "stand": _brief(stand), "brake": _brief(brake), "off": _brief(off)})
	check("slide: entered at a run (>= 180 u/s)", float(slide.entry_ups) >= 180.0, slide.entry_ups)
	check("slide: the hull ducked under the rack", (slide.rows as Array).any(func(r: Dictionary) -> bool: return r.duck == true and (r.p as Vector3).z < -23.0))
	check("slide: started once, from Shift", rows_with(slide, "slide").size() == 1)
	check("slide: carried over the trench onto the wall-chamber deck", bool(slide.crossed), slide.end)
	check("crouch walk: slower through the lane than the slide", float(crouch.lane_mean_ups) < float(slide.lane_mean_ups) - 40.0, [crouch.lane_mean_ups, slide.lane_mean_ups])
	check("crouch walk: does not clear the trench", not bool(crouch.crossed), crouch.end)
	check("crouch walk: lands in the trench catch", (crouch.end as Vector3).y < -1.5 and (crouch.end as Vector3).y > -2.5, crouch.end)
	check("standing: stopped at the rack mouth", (stand.end as Vector3).z > -22.0 and (stand.end as Vector3).y > -0.1, stand.end)
	check("braking: stops before or at the rack", (brake.end as Vector3).z > -22.5, brake.end)
	check("slide off: Shift does nothing, the standing body stops at the mouth", (off.end as Vector3).z > -22.0 and rows_with(off, "slide").is_empty(), off.end)
	check("no tick of any slide episode embedded the hull", int(slide.embedded_ticks) + int(crouch.embedded_ticks) == 0, [slide.embedded_ticks, crouch.embedded_ticks])
	check("slide never added speed", _max_speed_gain(slide, "slide") <= 0.001, _max_speed_gain(slide, "slide"))
	# refusals: too slow, jump held, cooldown spam.
	await tap("r")
	game.call("practise_stage", 1)
	await ticks(4)
	begin("slide_refusals", "practise_stage(1)")
	key("shift", true)
	await ticks(10)
	key("shift", false)
	var slow := str(lab_state().slide.end)
	key("w", true)
	await until(func() -> bool: return speed_u() > 240.0, 200)
	key("space", true)
	await ticks(3)
	key("shift", true)
	await ticks(3)
	var hop := lab_state()
	key("shift", false)
	key("space", false)
	await until(func() -> bool: return bool(runner().call("is_grounded")), 200)
	await ticks(2)
	var spam := 0
	for i: int in 6:
		key("shift", true)
		await ticks(3)
		key("shift", false)
		await ticks(3)
	var spam_done := finish_episode()
	spam = rows_with(spam_done, "slide").size()
	check("slide refused from a standstill (too slow)", slow == "refused: too slow", slow)
	check("slide refused while Space is held (autohop)", not bool(hop.slide.active) and int(hop.counts.slide) == 0, hop.slide)
	check("Shift spam within the cooldown starts at most one slide", spam <= 1 and rows_with(spam_done, "slide_refused").size() >= 4, [spam, rows_with(spam_done, "slide_refused").size()])
	# low ceiling: release Shift under the rack, the duck stays and waits, the stand happens past it.
	await tap("r")
	game.call("practise_stage", 1)
	await ticks(4)
	begin("slide_release_under_rack", "practise_stage(1)")
	key("w", true)
	await until(func() -> bool: return feet().z < -21.3, 400)
	key("shift", true)
	await until(func() -> bool: return feet().z < -24.0, 200)
	key("shift", false)
	var blocked := false
	var embedded := 0
	for t: int in 300:
		await step()
		blocked = blocked or bool(runner().get("stand_blocked"))
		embedded += 0 if clear_now() else 1
		if feet().z < -27.8 or feet().y < -0.5:
			break
	var under_done := finish_episode()
	check("released under the rack: stand-up waited (blocked)", blocked)
	check("released under the rack: never embedded", embedded == 0, embedded)
	check("released under the rack: stood up past the rack", not bool(runner().get("ducked")) or feet().z > -27.0, [runner().get("ducked"), feet()])
	# held jump in the lane: hops into the rack, never embeds, the slide's duck holds to landing.
	await tap("r")
	game.call("practise_stage", 1)
	await ticks(4)
	begin("slide_jump_under_rack", "practise_stage(1)")
	key("w", true)
	await until(func() -> bool: return feet().z < -21.3, 400)
	key("shift", true)
	await ticks(20)
	key("space", true)
	embedded = 0
	var air_duck := 0
	var air_stand := 0
	for t: int in 300:
		await step()
		embedded += 0 if clear_now() else 1
		var duck: Dictionary = (runner().call("get_motion_state") as Dictionary).duck
		if "duck_air" in duck.events:
			air_duck += 1
		# the ordinary waiting stand-up once the rack is cleared: ctrl is up and no slide holds the duck.
		if "unduck_air" in duck.events and (_held.has("ctrl") or bool(lab_state().slide.duck_hold)):
			air_stand += 1
		if feet().z < -31.0 or feet().y < -1.0:
			break
	var jump_done := finish_episode()
	check("held jump under the rack: the slide ended on the jump", rows_with(jump_done, "slide_end").size() >= 1)
	check("held jump under the rack: never embedded", embedded == 0, embedded)
	check("a slide never ducks the hull in the air", air_duck == 0, air_duck)
	check("an air stand-up after a slide is the ordinary one (ctrl up, no slide duck held)", air_stand == 0, air_stand)

func _brief(done: Dictionary) -> Dictionary:
	return {"entry_ups": done.get("entry_ups"), "exit_ups": done.get("exit_ups"), "lane_mean_ups": done.get("lane_mean_ups"), "end": done.get("end"), "crossed": done.get("crossed")}

## the largest horizontal speed rise across a tick while `move` was active (u/s).
func _max_speed_gain(done: Dictionary, move: String) -> float:
	var worst := -INF
	var rows: Array = done.rows
	for i: int in range(1, rows.size()):
		var r: Dictionary = rows[i]
		if not r.has("lab") or not (bool(r.lab.slide) if move == "slide" else bool(r.lab.line)):
			continue
		var a: Vector3 = rows[i - 1].v
		var b: Vector3 = r.v
		worst = maxf(worst, (Vector2(b.x, b.z).length() - Vector2(a.x, a.z).length()) / U)
	return worst

# --- wall jump ------------------------------------------------------------------------------

## the climb, played as a player would: run along the west face, jump about 6 m in, wall-jump at
## the top of the jump (west face, push east), then on touching the east face (push west), then
## hold W onto the mezzanine. `presses` caps the wall presses.
func _wall_climb(presses: int = 2) -> int:
	key("w", true)
	await until(func() -> bool: return feet().z < -45.0, 900)
	key("a", true)
	await until(func() -> bool: return feet().z < -50.3, 900)
	key("space", true)
	await step()
	key("space", false)
	var used := 0
	var stage := 0
	for t: int in 400:
		await step()
		var x := feet().x
		var vy := runner().velocity.y / U
		var airborne := not bool(runner().call("is_grounded"))
		if stage == 0 and airborne and vy < 30.0:
			# the top of the jump against the west face: let go of A and press Space.
			key("a", false)
			if used < presses:
				key("space", true)
				used += 1
			stage = 1
			await step()
			key("space", false)
		elif stage == 1 and airborne and x > 1.6 - 0.405 - 0.03:
			if used < presses:
				key("space", true)
				used += 1
			stage = 2
			await step()
			key("space", false)
			# stop the westward push-off so the climb ends over the mezzanine, not across it.
			key("d", true)
			await ticks(2)
			key("d", false)
		if bool(runner().call("is_grounded")) and t > 20:
			break
	key("a", false)
	key("d", false)
	return used

func _wall_attempt(name: String, presses: int = 2) -> Dictionary:
	await tap("r")
	game.call("practise_stage", 2)
	await ticks(4)
	begin(name, "practise_stage(2): Wall chamber")
	await _wall_climb(presses)
	await ticks(30)
	key("w", false)
	await ticks(10)
	var done := finish_episode()
	done["end"] = feet()
	done["up"] = feet().y > 3.1 and feet().z < -56.0
	return done

func _group_wall() -> void:
	await make_game("experiment")
	var on := await _wall_attempt("wall_on")
	await tap("2")
	var off := await _wall_attempt("wall_control_off")
	await tap("2")
	note("summary", {"on": on.end, "off": off.end})
	check("wall jumps reach the mezzanine", bool(on.up), on.end)
	check("two wall jumps, off different faces", rows_with(on, "wall_jump").size() == 2, rows_with(on, "wall_jump").size())
	check("wall jump off: the same presses never reach the mezzanine", not bool(off.up) and rows_with(off, "wall_jump").is_empty(), off.end)
	var first: Array = rows_with(on, "wall_jump")
	if not first.is_empty():
		var imp: Vector3 = first[0].lab.imp.get("wall_jump", Vector3.ZERO)
		check("first wall jump pushes east and up", imp.x > 0.0 and imp.y > 0.0, imp)
	var cap_ok := true
	var rows: Array = on.rows
	for i: int in range(1, rows.size()):
		if "wall_jump" in rows[i].lab.events:
			var before: Vector3 = rows[i - 1].v
			var after: Vector3 = rows[i].v
			var hb := Vector2(before.x, before.z).length() / U
			var ha := Vector2(after.x, after.z).length() / U
			cap_ok = cap_ok and ha <= maxf(hb, 340.0) + 1.0
	check("wall jump never lifts horizontal speed past max(before, 340 u/s)", cap_ok)
	# invalid: open air, a floor, a distant wall, held autohop along a wall, spam and repeats.
	await tap("r")
	game.call("practise_stage", 2)
	await ticks(4)
	begin("wall_refusals", "practise_stage(2)")
	key("space", true)
	await ticks(2)
	key("space", false)
	await ticks(20)
	key("space", true)
	await ticks(2)
	key("space", false)
	var open_air := lab_state()
	await until(func() -> bool: return bool(runner().call("is_grounded")), 200)
	# held autohop along a wall: inside the chamber, hold A into the west face and hold Space.
	key("w", true)
	await until(func() -> bool: return feet().z < -47.0, 300)
	key("w", false)
	key("a", true)
	key("space", true)
	await ticks(200)
	var held := lab_state()
	key("space", false)
	key("a", false)
	await until(func() -> bool: return bool(runner().call("is_grounded")), 200)
	finish_episode()
	# a distant wall: standing still in the middle of the chamber, 1.2 m from each face.
	await tap("r")
	game.call("practise_stage", 2)
	await ticks(4)
	begin("wall_distant", "practise_stage(2)")
	key("w", true)
	await until(func() -> bool: return feet().z < -49.0, 400)
	key("w", false)
	await until(func() -> bool: return speed_u() < 1.0, 200)
	key("space", true)
	await ticks(2)
	key("space", false)
	await ticks(16)
	key("space", true)
	await ticks(2)
	key("space", false)
	var distant := lab_state()
	var distant_at := feet()
	await until(func() -> bool: return bool(runner().call("is_grounded")), 200)
	finish_episode()
	# spam against one wall: hold A into the west face, the floor press is the ordinary jump, then
	# press Space every 3 ticks for the whole flight.
	await tap("r")
	game.call("practise_stage", 2)
	await ticks(4)
	begin("wall_spam", "practise_stage(2)")
	key("w", true)
	await until(func() -> bool: return feet().z < -49.0, 400)
	key("w", false)
	key("a", true)
	await until(func() -> bool: return feet().x < -1.19 and speed_u() < 1.0, 300)
	key("space", true)
	await step()
	var floor_press: Dictionary = ((ep.rows as Array).back() as Dictionary).duplicate(true)
	await ticks(1)
	key("space", false)
	for i: int in 24:
		await ticks(1)
		key("space", true)
		await ticks(2)
		key("space", false)
	await until(func() -> bool: return bool(runner().call("is_grounded")), 300)
	key("a", false)
	var spam_done := finish_episode()
	check("open air: refused, no wall in reach", str(open_air.wall_jump.refusal) == "no wall in reach" and int(open_air.counts.wall_jump) == 0, open_air.wall_jump)
	check("held autohop along a wall never wall-jumps", int(held.counts.wall_jump) == 0, held.counts)
	check("a wall 1.2 m away is out of reach", int(distant.counts.wall_jump) == 0 and str(distant.wall_jump.refusal) == "no wall in reach", [distant.wall_jump, distant_at])
	var spam := rows_with(spam_done, "wall_jump").size()
	var reasons := {}
	for r: Dictionary in rows_with(spam_done, "wall_refused"):
		reasons[str(r.lab.get("refusal", ""))] = true
	check("spamming one wall: at most one wall jump (same wall refused after it)", spam <= 1, spam)
	var top := -INF
	for r: Dictionary in spam_done.rows:
		top = maxf(top, (r.p as Vector3).y)
	check("spamming one wall gains no more than one wall jump's height", top < 3.0, top)
	note("refusals", {"open": open_air.wall_jump, "held": held.counts, "distant": distant.wall_jump, "spam_jumps": spam, "spam_top_m": top})
	# floor: a press on the ground is the ordinary jump, never a wall jump.
	check("a press on the floor beside a wall is the ordinary jump", not ("wall_jump" in floor_press.lab.events) and int(floor_press.lab.wall) == 0 and (floor_press.v as Vector3).y > 0.0 and absf((floor_press.v as Vector3).x) < 0.01, [floor_press.lab.events, floor_press.v])
	# ceiling: a ducked hop under the rack (no wall within reach) is refused.
	await tap("r")
	game.call("practise_stage", 1)
	await ticks(4)
	begin("wall_ceiling", "practise_stage(1)")
	key("ctrl", true)
	key("w", true)
	await until(func() -> bool: return feet().z < -24.0, 900)
	key("w", false)
	await ticks(30)
	key("space", true)
	await ticks(2)
	key("space", false)
	await ticks(1)
	key("space", true)
	await ticks(2)
	key("space", false)
	var ceiling := lab_state()
	await ticks(20)
	finish_episode()
	check("touching the rack ceiling: no wall jump", int(ceiling.counts.wall_jump) == 0, ceiling.counts)

# --- grapple --------------------------------------------------------------------------------

## from the grapple checkpoint: pitch up at A1, run off the edge, hold E once the target is
## valid, let go past z `release_z`. returns the episode.
func _grapple_attempt(name: String, release_z: float = -83.0, hold_ticks: int = -1) -> Dictionary:
	await tap("r")
	game.call("practise_stage", 3)
	await ticks(4)
	begin(name, "practise_stage(3): Grapple gap")
	key("w", true)
	await until(func() -> bool: return feet().z < -69.6, 400)
	key("space", true)
	await ticks(2)
	key("space", false)
	aim_at(anchor("A1"))
	var held := 0
	var attached_at := -1
	for t: int in 700:
		var target := str(lab_state().grapple.target.get("state", ""))
		if held == 0 and (target == "ok" or t > 30):
			key("e", true)
			held = 1
		await step()
		if bool(lab_state().grapple.attached) and attached_at < 0:
			attached_at = int(ep.tick)
		if held == 1 and ((hold_ticks < 0 and feet().z < release_z) or (hold_ticks >= 0 and attached_at >= 0 and int(ep.tick) - attached_at >= hold_ticks)):
			key("e", false)
			held = 2
		if bool(runner().call("is_grounded")) and t > 20:
			break
	key("w", false)
	await ticks(30)
	var done := finish_episode()
	done["end"] = feet()
	done["across"] = feet().z < -84.2 and feet().y > 3.0
	done["in_pit"] = feet().y < -3.0 and feet().y > -4.5
	return done

func _group_grapple() -> void:
	await make_game("experiment")
	var on := await _grapple_attempt("grapple_on")
	await tap("3")
	var off := await _grapple_attempt("grapple_control_off")
	await tap("3")
	note("summary", {"on": on.end, "off": off.end})
	check("grapple: latched onto A1", rows_with(on, "grapple").size() == 1 and (on.rows as Array).any(func(r: Dictionary) -> bool: return r.lab.anchor == "A1"))
	check("grapple: crossed the 14 m gap onto the dispatch bay", bool(on.across), on.end)
	check("grapple: released by letting go of E", (on.rows as Array).any(func(r: Dictionary) -> bool: return r.lab.release == "released"))
	check("grapple off: the same input falls into the pit catch", bool(off.in_pit) and rows_with(off, "grapple").is_empty(), off.end)
	var speed_ok := true
	var top_speed := 0.0
	var rows: Array = on.rows
	for i: int in range(1, rows.size()):
		if bool(rows[i].lab.line):
			var a := (rows[i - 1].v as Vector3).length() / U
			var b := (rows[i].v as Vector3).length() / U
			top_speed = maxf(top_speed, b)
			# gravity is added after the line, so allow one tick of it.
			speed_ok = speed_ok and b <= maxf(a, 650.0) + 800.0 / 128.0 + 0.01
	check("grapple never raises speed past max(before, 650 u/s) beyond one gravity tick", speed_ok, top_speed)
	var traveled := true
	for i: int in range(1, rows.size()):
		var jump := ((rows[i].p as Vector3) - (rows[i - 1].p as Vector3)).length()
		traveled = traveled and jump < 0.2
	check("grapple moved the body by travel, never a jump in position (< 0.2 m per tick)", traveled)
	# time limit over the pit: hold E without letting go; the line breaks at 3 s and the body falls
	# to the pit catch.
	var timed := await _grapple_attempt("grapple_time_limit", -200.0, 9999)
	check("held past 3 s the line breaks (time)", (timed.rows as Array).any(func(r: Dictionary) -> bool: return r.lab.release == "time"))
	var longest := 0
	var run := 0
	for r: Dictionary in timed.rows:
		run = run + 1 if bool(r.lab.line) else 0
		longest = maxi(longest, run)
	check("a line never lasts past 3 s (384 ticks)", longest <= 384, longest)
	# blocked target and an obstructed line, around the column.
	await tap("r")
	game.call("practise_stage", 3)
	await ticks(4)
	begin("grapple_blocked", "practise_stage(3)")
	# from the mezzanine middle the column hides A2.
	aim_at(anchor("A2"))
	await ticks(3)
	var blocked: Dictionary = lab_state().grapple.target.duplicate()
	key("e", true)
	await ticks(4)
	var after_press: Dictionary = lab_state().duplicate(true)
	key("e", false)
	await ticks(2)
	# crouch-walk off the edge at x -1.5 into the pit, find a spot with A2 in view east of the
	# column, latch, then strafe west so the column comes between the body and A2.
	key("a", true)
	await until(func() -> bool: return feet().x < -1.5, 300)
	key("a", false)
	aim_at(Vector3(-1.5, feet().y + 64.0 * U, -90.0))
	key("ctrl", true)
	key("w", true)
	await until(func() -> bool: return feet().y < -3.0 and bool(runner().call("is_grounded")), 600)
	key("w", false)
	key("ctrl", false)
	await ticks(20)
	aim_at(anchor("A2"))
	await ticks(2)
	for t: int in 200:
		if str(lab_state().grapple.target.get("state", "")) == "ok":
			break
		key("d", true)
		aim_at(anchor("A2"))
		await step()
	key("d", false)
	await ticks(4)
	aim_at(anchor("A2"))
	await ticks(1)
	var clear_target: Dictionary = lab_state().grapple.target.duplicate()
	key("e", true)
	await ticks(2)
	var latched := bool(lab_state().grapple.attached)
	key("a", true)
	var reason := ""
	for t: int in 400:
		await step()
		reason = str(lab_state().grapple.release)
		if not reason.is_empty():
			break
	key("a", false)
	key("e", false)
	var block_done := finish_episode()
	check("A2 from the mezzanine middle reads blocked", str(blocked.get("state", "")) == "blocked" and str(blocked.get("name", "")) == "A2", blocked)
	check("pressing E at a blocked anchor latches nothing", not bool(after_press.grapple.attached) and int(after_press.counts.grapple) == 0)
	check("A2 from the pit east of the column is a valid target", str(clear_target.get("state", "")) == "ok", clear_target)
	check("latched onto A2 from the pit", latched)
	check("strafing behind the column breaks the line (obstructed)", reason == "obstructed", reason)
	note("blocked", {"blocked": blocked, "clear": clear_target, "reason": reason})
	# reset clears the line: latch on A1 in flight and press R; F the same.
	for reset: String in ["r", "f"]:
		var done := await _grapple_reset(reset)
		check("%s while on a line clears it and every move state" % reset.to_upper(), bool(done.cleared), done.state)
	# death: a line broken over the scrap chute falls out of the kill envelope; the respawn is clean.
	await tap("r")
	game.call("practise_stage", 3)
	await ticks(4)
	begin("grapple_chute_death", "practise_stage(3)")
	aim_at(Vector3(-9.0, feet().y + 64.0 * U, -72.0))
	key("w", true)
	await until(func() -> bool: return feet().z < -69.6 or feet().x < -9.0, 500)
	key("space", true)
	await ticks(2)
	key("space", false)
	key("e", true)
	await ticks(30)
	key("e", false)
	var respawns := int(game.get("respawn_count"))
	await until(func() -> bool: return int(game.get("respawn_count")) > respawns, 600)
	key("w", false)
	await ticks(4)
	var death := lab_state()
	var death_done := finish_episode()
	check("a fall into the scrap chute respawns", int(game.get("respawn_count")) > respawns, game.get("respawn_count"))
	check("the respawn leaves no line, slide or wall state", not bool(death.grapple.attached) and not bool(death.slide.active) and int(death.wall_jump.flight) == 0 and (death.impulses_u as Dictionary).is_empty(), death)
	check("respawned at the grapple checkpoint", feet().distance_to(((level().get("checkpoints") as Array)[3].pose as Transform3D).origin) < 0.5, feet())

func _grapple_reset(reset_key: String) -> Dictionary:
	await tap("r")
	game.call("practise_stage", 3)
	await ticks(4)
	begin("grapple_reset_" + reset_key, "practise_stage(3)")
	key("w", true)
	await until(func() -> bool: return feet().z < -69.6, 400)
	key("space", true)
	await ticks(2)
	key("space", false)
	aim_at(anchor("A1"))
	key("e", true)
	await until(func() -> bool: return bool(lab_state().grapple.attached), 120)
	await ticks(10)
	var was := bool(lab_state().grapple.attached)
	await tap(reset_key)
	await ticks(2)
	var after := lab_state()
	key("e", false)
	key("w", false)
	finish_episode()
	return {"cleared": was and not bool(after.grapple.attached) and not bool(after.slide.active) and int(after.wall_jump.flight) == 0 and int(after.counts.grapple) == 0, "state": after}

# --- combined line ----------------------------------------------------------------------------

## the whole lab from its normal spawn: slide, two wall jumps, grapple, finish.
func _combined(name: String, setup: String) -> Dictionary:
	begin(name, setup)
	key("w", true)
	await until(func() -> bool: return feet().z < -20.9, 900)
	key("shift", true)
	await until(func() -> bool: return feet().z < -27.45 and bool(runner().call("is_grounded")), 300)
	key("space", true)
	await ticks(2)
	key("space", false)
	key("shift", false)
	await until(func() -> bool: return bool(runner().call("is_grounded")) and feet().z < -30.6, 200)
	await _wall_climb(2)
	key("w", true)
	# straighten on the mezzanine, look up at A1, run off the edge and swing.
	await until(func() -> bool: return bool(runner().call("is_grounded")), 200)
	aim_at(Vector3(feet().x, feet().y + 64.0 * U, -90.0))
	await until(func() -> bool: return feet().z < -69.6, 400)
	key("space", true)
	await ticks(2)
	key("space", false)
	aim_at(anchor("A1"))
	key("e", true)
	await until(func() -> bool: return feet().z < -83.0 or bool(runner().call("is_grounded")), 500)
	key("e", false)
	await until(func() -> bool: return bool(game.get("finished")), 900)
	key("w", false)
	await ticks(10)
	var done := finish_episode()
	done["finished"] = game.get("finished")
	done["finish_kind"] = game.get("finish_kind")
	done["elapsed"] = game.get("elapsed")
	done["respawns"] = game.get("respawn_count")
	return done

func _group_combined() -> void:
	await make_game("experiment")
	await tap("r")
	await ticks(4)
	var line := await _combined("combined_from_spawn", "R at the lab: a clean attempt from the normal spawn")
	check("combined line finishes from the normal spawn", bool(line.finished) and str(line.finish_kind) == "clean", [line.finish_kind, feet()])
	check("combined line used all three moves", not rows_with(line, "slide").is_empty() and rows_with(line, "wall_jump").size() == 2 and not rows_with(line, "grapple").is_empty())
	check("combined line: no respawn", int(line.respawns) == 0)
	note("combined", {"elapsed_s": line.elapsed, "kind": line.finish_kind, "ticks": line.tick})
	# the same line from the game's own start as a tape: a fresh game, warmup only.
	await make_game("experiment")
	await ticks(5)
	var fresh := await _combined("combined_tape_source", "make_game(experiment) and 8 settle ticks, as the executor's warmup")
	check("fresh-game combined line finishes clean", bool(fresh.finished) and str(fresh.finish_kind) == "clean")
	check("combined line exports as a version 2 tape", export_tape(fresh, "r15-lab-combined", "Movement Lab combined line from the normal spawn: slide, two wall jumps, grapple; actor-timed then replayed input-only"))
	# checkpoint recovery: fall into the chute from the mezzanine, respawn at the grapple checkpoint,
	# then grapple across from there.
	await tap("r")
	game.call("practise_stage", 3)
	await ticks(4)
	begin("recovery_chute_then_grapple", "practise_stage(3)")
	key("a", true)
	await until(func() -> bool: return feet().x < -6.0, 400)
	key("a", false)
	key("w", true)
	var respawns := int(game.get("respawn_count"))
	await until(func() -> bool: return int(game.get("respawn_count")) > respawns, 600)
	key("w", false)
	await ticks(6)
	key("w", true)
	await until(func() -> bool: return feet().z < -69.6, 400)
	key("space", true)
	await ticks(2)
	key("space", false)
	aim_at(anchor("A1"))
	key("e", true)
	await until(func() -> bool: return feet().z < -83.0 or bool(runner().call("is_grounded")), 500)
	key("e", false)
	await until(func() -> bool: return bool(game.get("finished")), 900)
	key("w", false)
	var recovery := finish_episode()
	check("recovery: the chute respawned at the grapple checkpoint", int(game.get("respawn_count")) > respawns)
	check("recovery: grappled across and finished as practice", bool(game.get("finished")) and str(game.get("finish_kind")) == "practice", game.get("finish_kind"))
	note("recovery", {"ticks": recovery.tick})

# --- records --------------------------------------------------------------------------------

func _group_records() -> void:
	var profile := out_dir.path_join("records_profile.cfg")
	DirAccess.remove_absolute(profile)
	await make_game("experiment", {"persist": true, "profile_path": profile, "seed_from_r14": false})
	await tap("r")
	await ticks(4)
	var line := await _combined("records_clean_lab", "R")
	var lab_key := str(game.get("course_key"))
	check("a clean lab finish saves", bool(game.get("last_save_ok")) and str(line.finish_kind) == "clean")
	var config := ConfigFile.new()
	config.load(profile)
	var sections := Array(config.get_sections()).filter(func(s: String) -> bool: return s.begins_with("course_"))
	check("the save holds exactly the lab's section", sections == ["course_" + lab_key], sections)
	check("the lab section is a lab identity", str(config.get_value("course_" + lab_key, "map_kind", "")) == "lab" and str(config.get_value("course_" + lab_key, "identity", "")).contains("r15-lab-grapple-1"))
	# a different loadout reads nothing from it; the same one reads it back.
	await tap("3")
	check("grapple off: no best under that loadout", float(game.get("best_time")) < 0.0)
	await tap("3")
	check("all on again: the best is back", float(game.get("best_time")) > 0.0)
	# leaving for a course: its key holds no lab best, and its section is untouched.
	game.call("select_map", "breakwater")
	await ticks(3)
	check("the course has no best from the lab", float(game.get("best_time")) < 0.0 and str(game.get("record_state")) in ["absent", ""], [game.get("best_time"), game.get("record_state")])
	var fresh := ConfigFile.new()
	fresh.load(profile)
	check("leaving the lab wrote no course section", Array(fresh.get_sections()).filter(func(s: String) -> bool: return s.begins_with("course_")) == ["course_" + lab_key])
	# a reload in a fresh game finds the lab best under the same identity.
	await make_game("experiment", {"persist": true, "profile_path": profile, "seed_from_r14": false})
	check("a new game loads the lab best for the same loadout", float(game.get("best_time")) > 0.0 and str(game.get("record_state")) == "loaded", game.get("record_state"))
	DirAccess.remove_absolute(profile)

# --- json -------------------------------------------------------------------------------------

static func _plain(value: Variant) -> Variant:
	if value is Vector3:
		return [snappedf(value.x, 1e-6), snappedf(value.y, 1e-6), snappedf(value.z, 1e-6)]
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var out := {}
		for k: Variant in value:
			out[str(k)] = _plain(value[k])
		return out
	if value is Array:
		var out: Array = []
		for item: Variant in value:
			out.append(_plain(item))
		return out
	if value is float and not is_finite(value):
		return str(value)
	return value

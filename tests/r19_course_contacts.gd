extends SceneTree
## labelled collision queries at observed feet, not an input replay or a movement parity claim.

const BEFORE := preload("res://scripts/r17_main.gd")
const AFTER := preload("res://scripts/r19_main.gd")
var checks: Array = []
var rows: Array = []
var output := "/tmp/r19-playtest-analysis/contacts.json"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "name": label})
	print("PASS " if ok else "FAIL ", label)

func query(game: Node3D, x: float) -> Dictionary:
	var parameters := PhysicsTestMotionParameters3D.new()
	parameters.from = Transform3D(Basis.IDENTITY, Vector3(x, 0.62, -194.71))
	parameters.motion = Vector3(0, 0, -5.0)
	parameters.margin = 0.001
	var result := PhysicsTestMotionResult3D.new()
	var hit := PhysicsServer3D.body_test_motion(game.player.get_rid(), parameters, result)
	var names: Array = []
	for i: int in result.get_collision_count():
		var collider := result.get_collider(i) as Node
		names.append(str(game.level.get_path_to(collider)))
	return {"x": x, "hit": hit, "colliders": names, "travel_z": result.get_travel().z}

func run() -> void:
	RenderingServer.render_loop_enabled = false
	for map_id: String in ["breakwater", "whiteout-relay", "sunken-court", "rainline", "night-shift", "practice", "overflow", "experiment"]:
		var pair: Array = []
		for host: Script in [BEFORE, AFTER]:
			var game: Node3D = host.new()
			game.map_id = map_id
			game.persist = false
			game.seed_from_r15 = false
			game.record_runs = false
			root.add_child(game)
			game.set_paused(true)
			await physics_frame
			var row := {"identity": game.motion_identity(), "geometry": game.course_geometry,
				"spawn": var_to_str(game.level.spawn), "checkpoints": var_to_str(game.level.checkpoints),
				"finish": var_to_str(game.level.finish_position), "kill": var_to_str(game._kill_bounds),
				"queries": [], "presets": {}}
			for motor: String in ["server128", "server128_aa1000"]:
				game.select_preset(motor)
				row.presets[motor] = {"metadata": game.recording_metadata("revision_query"), "identity_text": game.record_identity_text()}
			game.select_preset("server128")
			if map_id == "breakwater":
				if host == AFTER:
					var installation := game.level.get_node("R16Opportunities/RunwayThread") as Node3D
					check(is_equal_approx(installation.get_node("Cue").position.x, installation.get_node("WestWall").position.x), "style cue stays on its moved wall")
				for x: float in [-80.8, -81.7, -77.98]:
					row.queries.append(query(game, x))
			pair.append(row)
			game.request_quit(0)
			root.remove_child(game)
			game.free()
		if map_id == "breakwater":
			check(pair[0].queries[0].hit and pair[0].queries[1].hit, "both observed low-speed positions meet original thread fronts")
			check(str(pair[0].queries[0].colliders).contains("RunwayThread") and str(pair[0].queries[1].colliders).contains("RunwayThread"), "original contacts name optional thread walls")
			check(not pair[1].queries[0].hit and not pair[1].queries[1].hit, "both observed lines clear widened thread")
			check(not pair[0].queries[2].hit and not pair[1].queries[2].hit, "Mike's fast successful east line remains clear")
			check(pair[0].identity != pair[1].identity and pair[0].geometry != pair[1].geometry, "changed geometry receives a distinct ghost and time identity")
		else:
			check(pair[0].identity == pair[1].identity, map_id + " identity unchanged")
		for key: String in ["spawn", "checkpoints", "finish", "kill"]:
			check(pair[0][key] == pair[1][key], map_id + " " + key + " unchanged")
		rows.append({"map": map_id, "before": pair[0], "after": pair[1]})
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.ok)
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed.size(), "maps": rows}, "\t"))
	file.close()
	quit(0 if failed.is_empty() else 1)

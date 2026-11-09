extends "res://tests/test_r16_style.gd"
## p / native views of the style panel on the actual r15 main with its hud, from the player's own
## camera: a strafe run with sync callouts and a rising multiplier to the finish, a ground crouch
## save under a beam, and the pause menu. same episodes and inputs as tests/test_r16_style.gd
## (closed-loop calibration then open-loop replay); frames are saved as JPEG a few frames after
## each scored event and at the finish and pause. run it with --fixed-fps 128 on a real display
## (tests/r16_style_native.py); headless it only proves the script runs.
## godot --fixed-fps 128 --path . --script res://tests/r16_style_views.gd -- --out=DIR

const SHOTS_AFTER := [4, 40]

var shots: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var seen_events := 0

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("episodes"))
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("shots"))
	Engine.physics_ticks_per_second = 128
	game = MAIN.new()
	game.name = "R15"
	game.set("level_script", FIX)
	game.set("motor", "server128")
	game.set("set_window_title", false)
	root.add_child(game)
	level = game.get("level")
	probe = PROBE.new(game)
	root.add_child(probe)
	probe.call("attach_panel")
	for spec: Array in [["early_tick", -1000], ["pre_style", 999], ["late_tick", 1001], ["shot_tick", 1002]]:
		var hook := Hook.new()
		hook.suite = self
		hook.phase = spec[0]
		hook.process_physics_priority = spec[1]
		root.add_child(hook)
	rpc = float(game.get("player").get("tape_radians_per_count"))
	await process_frame
	await physics_frame
	# a strafe run to the finish: sync callouts, the multiplier, speed and the finish state.
	var spec := FIX.flat_spec()
	spec["finish"] = AABB(Vector3(-24, -0.5, -150), Vector3(48, 4, 4))
	seen_events = probe.scored.size()
	var flow := await episode("views_flow", spec, 1700, {}, ctl_strafe, {"run_ticks": 110})
	_shot("finish")
	# a ground crouch save under a beam (calibrated as in group_crouch).
	var cal := await episode("views_crouch_cal", FIX.flat_spec(), 470, {}, ctl_run, {"crouch_z": -14.0})
	var rows: Array = cal.rows
	var press := find(rows, func(r: Dictionary) -> bool: return bool(r.d))
	var front := (rows[press + 2].p as Vector3).z - HW - 0.04
	var beam := FIX.flat_spec()
	(beam.pieces as Array).append(FIX.block("beam", Vector3(-6, (rows[press + 2].p as Vector3).y + DUCK + 4.0 * U, front - 0.3), Vector3(6, 2.4, front)))
	seen_events = probe.scored.size()
	var save := await episode("views_crouch_save", beam, 520, cal.tape)
	game.call("set_paused", true)
	for i: int in 6:
		await process_frame
	_shot("pause_menu")
	game.call("set_paused", false)
	var file := FileAccess.open(out_dir.path_join("shots.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_plain({"label": "player camera + r15 hud + r16 style panel; fixture level; inputs are key and mouse events", "shots": shots,
		"flow_events": flow.events.map(func(e: Dictionary) -> String: return e.label), "save_events": save.events.map(func(e: Dictionary) -> String: return e.label),
		"sources_sha256": _sources(), "display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method()}), "\t"))
	file.close()
	print("r16 style views: %d shots" % shots.size())
	game.call("request_quit", 0)
	quit(0)

## after the probe: queue frames a few physics ticks after each new event.
func shot_tick() -> void:
	if not running:
		return
	while seen_events < probe.scored.size():
		var event: Dictionary = probe.scored[seen_events]
		seen_events += 1
		for after: int in SHOTS_AFTER:
			pending.append({"at": int(ep.tick) + after, "name": "%s_%s_%d_plus%d" % [ep.name, event.kind, int(event.tick), after]})
	for item: Dictionary in pending.duplicate():
		if int(item.at) <= int(ep.tick):
			pending.erase(item)
			if shots.filter(func(s: Dictionary) -> bool: return str(s.name).begins_with(str(ep.name))).size() < 14:
				_shot(str(item.name))

func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		shots.append({"name": name, "file": "", "note": "headless: no frame"})
		return
	var image := root.get_texture().get_image()
	var path := out_dir.path_join("shots").path_join(name + ".jpg")
	image.save_jpg(path, 0.82)
	var snap: Dictionary = probe.style.call("snapshot")
	shots.append({"name": name, "file": "shots/" + name + ".jpg", "size": [image.get_width(), image.get_height()], "score": snap.score, "combo": snap.combo, "mult": snap.mult})

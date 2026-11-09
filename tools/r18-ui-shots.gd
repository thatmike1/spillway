extends SceneTree
## r18 ui stills: one fresh game per screen, posed through the host's own calls, saved from the
## real viewport. the finish card is staged with plausible values (it is a presentation check,
## not a run); everything else is the state the host itself produces.
## godot --path . --resolution WxH --script res://tools/r18-ui-shots.gd -- --out=DIR [--states=a,b] [--host=res://scripts/r17_main.gd]
const STATES := ["opening", "hints", "pause", "pause-lower", "toast", "practice", "finish", "lab", "telemetry"]
var output := ""
var host_path := "res://scripts/r17_main.gd"
var states: Array = STATES.duplicate()
var rows: Array = []

func _initialize() -> void:
	run.call_deferred()

func _frames(count: int) -> void:
	for i: int in count:
		await process_frame

func _game(map_id: String) -> Node:
	var game: Node = (load(host_path) as Script).new()
	game.set("map_id", map_id)
	game.set("seed_from_r15", false)
	game.set("persist", false)
	game.set("record_runs", false)
	root.add_child(game)
	return game

func _save(name: String, game: Node) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var file := output.path_join(name + ".png")
	image.save_png(file)
	rows.append({"state": name, "file": file, "size": [image.get_width(), image.get_height()], "map": str(game.get("map_id")),
		"viewport": var_to_str(root.get_visible_rect().size)})
	print("r18-ui-shots: %s %dx%d" % [name, image.get_width(), image.get_height()])

func _stage_finish(game: Node) -> void:
	var count: int = game.call("stage_count")
	var times: Array[float] = []
	var splits: Array[float] = []
	var total := 0.0
	for i: int in count:
		total += 44.6015625 / count + (0.4 if i % 2 == 0 else -0.4) * (1 if i < count - 1 else 0)
		times.append(total if i < count - 1 else 44.6015625)
		splits.append([-0.21, 0.08, -0.34, -0.05, 0.12, -0.02][i % 6])
	game.set("stage_times", times)
	game.set("elapsed", 44.6015625)
	game.set("finished", true)
	game.set("finish_kind", "clean")
	game.set("clean_eligible", true)
	game.set("previous_best", 45.1171875)
	game.set("best_time", 44.6015625)
	game.set("split_deltas", splits)
	game.set("finish_style", {"score": 937, "by_kind": {}, "eligible": true})
	game.set("previous_style_best", 812)
	game.set("style_best", 937)
	game.set("style_new_best", true)
	game.set("ghost_new", true)
	game.hud.call("show_finish", true, false)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		elif arg.begins_with("--states="):
			states = Array(arg.trim_prefix("--states=").split(","))
		elif arg.begins_with("--host="):
			host_path = arg.trim_prefix("--host=")
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	for state: String in states:
		var game := _game("experiment" if state == "lab" else "breakwater")
		await _frames(50)
		match state:
			"hints":
				if game.hud.has_method("dismiss_title"):
					game.hud.call("dismiss_title")
				await _frames(40)
			"pause":
				game.call("set_paused", true)
				await _frames(12)
			"pause-lower":
				game.call("set_paused", true)
				await _frames(6)
				var scroll := game.hud.get("_pause_scroll") as ScrollContainer
				scroll.scroll_vertical = 100000
				await _frames(10)
			"toast":
				if game.hud.has_method("dismiss_title"):
					game.hud.call("dismiss_title")
				await _frames(40)
				game.call("select_preset", "server128_aa1000")
				await _frames(12)
			"practice":
				if game.hud.has_method("dismiss_title"):
					game.hud.call("dismiss_title")
				game.call("practise_stage", 2)
				await _frames(30)
			"finish":
				if game.hud.has_method("dismiss_title"):
					game.hud.call("dismiss_title")
				_stage_finish(game)
				await _frames(40)
				# the session seals the staged attempt and shows its own finish; stage again over it.
				_stage_finish(game)
				await _frames(10)
			"telemetry":
				if game.hud.has_method("dismiss_title"):
					game.hud.call("dismiss_title")
				if game.hud.has_method("set_telemetry"):
					game.hud.call("set_telemetry", true)
				await _frames(30)
		await _save(state, game)
		if bool(game.get("paused")):
			game.call("set_paused", false)
		root.remove_child(game)
		game.free()
		await _frames(4)
	var file := FileAccess.open(output.path_join("stills.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"host": host_path, "rows": rows}, "  "))
	file.close()
	quit(0)

extends "res://tests/r20_through_component.gd"
## exercise the actual ghost loader on a sealed input-earned route and actual identity changes.
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.render_loop_enabled = false
	Engine.physics_ticks_per_second = 128
	hook = Post.new()
	hook.driver = self
	hook.process_physics_priority = 1001
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	new_case("ghost_identity")
	await ticks(33)
	var summary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.get_base_dir().path_join("fast/summary.json")))
	var path: String = summary.recordings[0].path
	var rec := READER.read(path)
	check(rec.ok and READER.clean_finish(rec).ok, "actual complete earned route is clean before ghost loading")
	var result: Dictionary = game.session.ghost.load_run(path, game.motion_identity())
	check(result.ok, "actual matching Through Line ghost loads")
	game.select_preset("server128_aa1000")
	result = game.session.ghost.load_run(path, game.motion_identity())
	check(not result.ok, "actual changed F5 identity refuses F2 ghost")
	game.select_preset("server128")
	var law := PLAYER.LAW.duplicate(true)
	law.version = "labelled-next-law-fixture"
	game.level.mechanics = [law]
	game._refresh_records()
	result = game.session.ghost.load_run(path, game.motion_identity())
	check(not result.ok, "actual mechanics change produces a new course key and refuses old-law ghost")
	game.level.mechanics = [PLAYER.LAW]
	game._refresh_records()
	result = game.session.ghost.load_run(path, game.motion_identity())
	check(result.ok, "restored mechanics restore matching identity")
	for map: String in ["breakwater", "saltglass", "tether-yard"]:
		game.select_map(map)
		result = game.session.ghost.load_run(path, game.motion_identity())
		check(not result.ok, "actual Through ghost refused on other map: " + map)
	close_case()
	var ok := checks.all(func(row: Dictionary) -> bool: return bool(row.ok))
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks, "episodes": episodes}, "\t"))
	file.close()
	quit(0 if ok else 1)

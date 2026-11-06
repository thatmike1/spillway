extends SceneTree
## p / r12 actual-course fast line: one continuous run from the normal spawn, driven only by
## key and mouse input through scripts/spillway_surf_driver.gd. no pose, velocity or stage
## writes. --evidence-dir=<abs> keeps route-fast-*.jsonl; --render-samples=N also saves one still
## every N ticks (render loop off between them; needs a display, e.g. xvfb + opengl3).
var game: Node3D
var driver: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	run.call_deferred()

func check(value: bool, text: String) -> void:
	checks += 1
	print("%s %s" % ["PASS" if value else "FAIL", text])
	if not value:
		failures += 1

func run() -> void:
	root.size = Vector2i(960, 540)
	var output := ""
	var every := 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			output = arg.trim_prefix("--evidence-dir=")
		elif arg.begins_with("--render-samples="):
			every = int(arg.trim_prefix("--render-samples="))
	if DisplayServer.get_name() == "headless":
		every = 0
	game = load("res://scripts/spillway_main.gd").new()
	root.add_child(game)
	game.set("_persist", false)
	var player: CharacterBody3D = game.get("player")
	var spawn: Vector3 = player.global_position
	driver = preload("res://scripts/spillway_surf_driver.gd").new()
	game.add_child(driver)
	driver.call("attach", game)
	var ticks := 0
	while not bool(driver.get("done")) and ticks < 7200:
		await physics_frame
		ticks += 1
		if every > 0 and ticks % every == 0 and not output.is_empty():
			RenderingServer.render_loop_enabled = true
			await RenderingServer.frame_post_draw
			RenderingServer.render_loop_enabled = false
			root.get_texture().get_image().save_jpg(output.path_join("%04d-%s.jpg" % [ticks, driver.get("phase")]), .88)

	var report: Dictionary = driver.get("surf_report")
	var splits: Array = game.get("splits")
	print("spawn=%s splits=%s time=%.3f jumps=%d surf=%s" % [spawn, splits, game.get("elapsed"), player.get("jump_count"), report])
	check(bool(driver.get("succeeded")), "the fast line finishes by input alone: %s" % driver.get("failure_reason"))
	check(str(game.get("finish_kind")) == "clean" and int(game.get("respawn_count")) == 0, "continuous from spawn: a clean result, no respawn")
	check(splits.size() == 3 and splits[0] < splits[1] and splits[1] < splits[2], "Crest, Yard and Outflow splits arrive in order")
	for label: String in ["CrestSurf", "YardSurf", "OutflowSweep", "OutflowSurf"]:
		var ride: Dictionary = report.get(label, {})
		# p / ridden, not flown over: in contact for at least 0.2 s and 40% of its ride. the
		# outflow's left curve is a 0.6 s piece the berm feeds at its coping, so it sits near both.
		var contact := int(ride.get("contact_ticks", 0))
		check(ride.has("exit_speed") and contact >= 24 and contact >= .4 * int(ride.get("ride_ticks", 1)),
			"%s is ridden end to end on contact: %s" % [label, ride])
	# p / a bank that is entered and left on a held line carries speed through.
	for label: String in ["CrestSurf", "YardSurf"]:
		var ride: Dictionary = report.get(label, {})
		check(float(ride.get("exit_speed", 0)) > float(ride.get("entry_speed", INF)), "%s ends faster than it starts" % label)
	var entry: Dictionary = report.get("OutflowSweep", {})
	var exit: Dictionary = report.get("OutflowSurf", {})
	check(float(entry.get("entry_y", -INF)) > 0.5, "outflow is entered high, near the run-up deck, not from the basin")
	check(float(exit.get("exit_y", -INF)) > -3.0, "outflow releases above the front walk, so the finish needs no climb")
	check(float(exit.get("exit_speed", 0)) > float(entry.get("entry_speed", INF)) * .9, "the outflow S keeps at least 90% of its entry speed")
	var kills: Array = []
	for drop: Dictionary in driver.get("speed_drops"):
		if float(drop.from) - float(drop.to) > 4.0:
			kills.append(drop)
	check(kills.is_empty(), "no single-tick speed kill above 4 m/s anywhere on the line: %s" % [kills])
	print("surf course: %d/%d checks passed; one continuous input run, not a fun claim" % [checks - failures, checks])
	quit(1 if failures else 0)

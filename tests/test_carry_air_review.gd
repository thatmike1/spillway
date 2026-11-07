extends "res://tests/momentum_overflow_driver.gd"
## p / independent review: retain the original closed-loop driver and allow the challenger.
## this produces labelled state-aware tapes; imperfect open-loop challenges use the tape executor.

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--export-review-tapes="):
			_export_review_tapes.call_deferred(arg.trim_prefix("--export-review-tapes="))
			return
	super()

func _export_review_tapes(directory: String) -> void:
	assert(directory.is_absolute_path(), "pass an absolute output directory outside the checkout")
	DirAccess.make_dir_recursive_absolute(directory)
	var fixtures := {
		"stale-bank": {"motor": "candidate:drop:13:2", "ticks": 520, "events": [
			{"tick": 0, "key": "a", "edge": "press"}, {"tick": 0, "mouse": [-0.3/0.0022, 0]},
			{"tick": 360, "key": "w", "edge": "press"}, {"tick": 420, "key": "w", "edge": "release"}]},
		"no-history": {"motor": "candidate:drop:13:2:0.3", "ticks": 520, "events": [
			{"tick": 0, "key": "a", "edge": "press"}, {"tick": 360, "key": "w", "edge": "press"},
			{"tick": 420, "key": "w", "edge": "release"}]},
	}
	for speed: float in [3.0, 8.49, 8.51]:
		fixtures["opposed-a-%.2f" % speed] = {"motor": "candidate:drop:%.2f:%.15f" % [speed,-PI/2], "ticks": 120,
			"events": [{"tick": 0,"key": "a","edge": "press"},{"tick": 96,"key": "a","edge": "release"}]}
	for label: String in fixtures:
		var cfg: Dictionary = fixtures[label]
		var tape := {"format": "spillway-momentum-tape", "version": 1, "name": "independent-air-review-"+label,
			"description": "seeded review characterization, not an input-earned route; use fixture_motor with carry_air_review_fixture.gd",
			"physics_hz": 120, "input_profile": "tick120", "duration_ticks": cfg.ticks,
			"fixture_motor": cfg.motor, "events": cfg.events}
		var file := FileAccess.open(directory.path_join(label+".json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(tape," "))
		file.close()
		print(label," motor=",cfg.motor)
	quit()

func _start() -> void:
	max_ticks = int(opts.get("max-ticks", "7200"))
	var world := str(opts.get("world", "course"))
	var classes := {"course": GAME, "block": GAME.Block, "block_mirror": GAME.BlockMirror, "block_offset": GAME.BlockOffset}
	game = (classes[world] as Script).new()
	game.name = "OverflowGame"
	game.set("motor", str(opts.get("air", "broad")))
	if str(opts.get("air", "broad")) == "candidate":
		game.set("player_script", preload("res://scripts/momentum_carry_air_candidate.gd"))
	game.set("set_window_title", false)
	root.add_child(game)
	player = game.get("player")
	level = game.get("level")
	nodes = _route(str(opts.get("route", "ordinary")), world)
	trace = FileAccess.open(out_dir.path_join("trace.jsonl"), FileAccess.WRITE)
	for early: bool in [true, false]:
		var hook := Hook.new()
		hook.driver = self
		hook.early = early
		hook.process_physics_priority = -1000 if early else 1000
		hook.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(hook)
	print("overflow driver: CLOSED LOOP world=%s air=%s route=%s nodes=%d geometry=%s" % [world, opts.get("air", "broad"), opts.get("route", "ordinary"), nodes.size(), level.call("geometry_hash")])

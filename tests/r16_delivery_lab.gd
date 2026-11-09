extends "res://tests/test_r16_lab.gd"
## p / replay the established lab challenges through the actual R16 host. R15/source controls
## retain the frozen labelled host. fixture geometry and input plans are inherited unchanged.
const HOST16 := preload("res://scripts/r16_main.gd")

func make_game(runner_kind: String, map: String = "experiment") -> void:
	if runner_kind != "r16":
		await super(runner_kind, map)
		return
	await drop_game()
	Engine.physics_ticks_per_second = 128
	game = HOST16.new()
	game.set("set_window_title", false)
	game.set("map_id", map)
	# explicit isolation: new() never records into the player's folder.
	game.set("recordings_dir", out_dir.path_join("recordings"))
	game.set("record_runs", true)
	root.add_child(game)
	await ticks(3)
	check("delivery lab uses actual R16 host and automatic R16 lab selection", game.get_script() == HOST16 and game.call("runner_is_standin") == false)

func _main() -> void:
	var start := Time.get_ticks_msec()
	for group: String in GROUPS:
		if only.is_empty() or group in only:
			_group = group
			await call("_group_" + group)
			await drop_game()
	var failed := results.filter(func(r: Dictionary) -> bool: return not r.ok)
	var summary := {"checks": results.size(), "failed": failed.size(), "results": results, "notes": notes,
		"host": "actual r16_main.gd with default lab selection; R15/source controls use the frozen labelled host",
		"seconds": (Time.get_ticks_msec() - start) / 1000.0}
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_plain(summary), "  "))
	file.close()
	print("r16 delivery lab: %d checks, %d failed" % [results.size(), failed.size()])
	quit(0 if failed.is_empty() else 1)

func fixture(name: String, points: PackedVector3Array) -> StaticBody3D:
	var body := super(name, points)
	# these labelled test bodies carry the surface metadata authored map colliders provide.
	body.set_meta("surface", "delivery-fixture")
	return body

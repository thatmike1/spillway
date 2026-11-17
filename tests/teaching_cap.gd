extends SceneTree
## check real teaching visibility at the default and per-map clock boundaries.
const HOST := preload("res://scripts/game.gd")
var output := ""
var checks: Array[Dictionary] = []
var original_entry: Dictionary

func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	if not ok:
		push_error(label)

func probe(game: Node, at: float, limit: Variant, visible: bool, label: String, speed_u := 0.0, last_elapsed := 0.0, started := true) -> void:
	var entry := original_entry.duplicate(true)
	if limit != null:
		entry["teach_until_clock"] = limit
	game.maps.catalog[game.map_id] = entry
	game.elapsed = at
	game.set("_started", started)
	game.display_speed = speed_u * HOST.U
	var hud: Node = game.hud
	hud.set("_title_alpha", 0.0)
	hud.set("_title_dismissed", true)
	hud.set("_teach_alpha", 0.0 if last_elapsed > at else 1.0)
	hud.set("_teach_gone", last_elapsed > at)
	hud.set("_last_elapsed", last_elapsed)
	var motion := var_to_bytes(game.player.get_motion_state())
	var identity: Dictionary = game.motion_identity()
	var style := var_to_bytes(game.session.style.snapshot())
	var attempts: int = game.attempts
	hud.call("_process", 1.0)
	check(is_equal_approx(hud.controls.modulate.a, 1.0 if visible else 0.0), label)
	check(var_to_bytes(game.player.get_motion_state()) == motion and game.motion_identity() == identity and var_to_bytes(game.session.style.snapshot()) == style and game.attempts == attempts, label + " is presentation only")

func run() -> void:
	var game := HOST.new()
	game.map_id = "breakwater"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output.path_join("absent.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.hud.set_process(false)
	game.set_paused(false)
	original_entry = game.map_entry().duplicate(true)
	var legacy := var_to_bytes(game.map_registry)
	probe(game, 0.76, null, true, "original default remains visible before four seconds")
	probe(game, 4.0, null, true, "original inclusive four-second boundary")
	probe(game, 4.01, null, false, "original fades after four seconds")
	probe(game, 0.74, 0.75, true, "declared cap retains teaching before boundary")
	probe(game, 0.75, 0.75, true, "declared cap retains inclusive boundary")
	probe(game, 0.76, 0.75, false, "declared cap fades after boundary")
	probe(game, 0.1, 100.0, true, "speed boundary remains inclusive", 280.0)
	probe(game, 0.1, 100.0, false, "speed still ends teaching before clock cap", 281.0)
	probe(game, 0.1, 0.75, true, "rewound attempt restores teaching", 0.0, 7.0)
	probe(game, 10.0, 0.75, true, "unstarted placement retains teaching", 0.0, 0.0, false)
	game.maps.catalog[game.map_id] = original_entry
	check(var_to_bytes(game.map_registry) == legacy, "presentation metadata leaves legacy registry untouched")
	game.request_quit(0)
	game.free()
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("teaching.json"), FileAccess.WRITE).store_string(JSON.stringify({"ok": ok, "checks": checks}, "\t"))
	print("TEACHING_CAP ", ok, " checks=", checks.size())
	quit(0 if ok else 1)

extends SceneTree
## a nonempty startup registry must remain an isolated caller-supplied menu.
const HOST := preload("res://scripts/game.gd")
const BASE := preload("res://scripts/maps/catalog.gd")
var output := ""
var checks: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	if not ok:
		push_error(label)

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var entry: Dictionary = BASE.make().catalog.practice.duplicate(true)
	entry.kind = "course"
	entry.dress = false
	var injected := {"catalog": {"injection-fixture": entry}, "order": ["injection-fixture"], "default_chain": ["injection-fixture"]}
	var game := HOST.new()
	game.map_registry = injected.duplicate(true)
	game.map_id = ""
	game.motor = "server128"
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
	check(game.startup_error.is_empty(), "injected host starts")
	check(game.map_id == "injection-fixture", "injected default selects its own map")
	check(game.map_ids() == ["injection-fixture"], "injected menu has no live additions")
	check(game.maps.catalog.keys() == ["injection-fixture"], "runtime catalog remains isolated")
	check(game.map_registry == injected, "startup input remains unchanged")
	check(game.motion_identity().map == "injection-fixture", "record identity follows injected map")
	game.request_quit(0)
	game.free()
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("injection.json"), FileAccess.WRITE).store_string(JSON.stringify({"ok": ok, "checks": checks}, "\t"))
	print("Explicit registry startup: ", ok, " checks=", checks.size())
	quit(0 if ok else 1)

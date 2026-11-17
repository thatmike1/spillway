extends SceneTree
## retain every delivered catalog entry while checking new menu maps in the live host.
const BASE := preload("res://scripts/maps/catalog.gd")
const LIVE := preload("res://scripts/maps/r22_catalog.gd")
const HOST := preload("res://scripts/game.gd")
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
	var original := BASE.make()
	var current := LIVE.make()
	check(current.default_chain == original.default_chain, "inherited defaults unchanged")
	check(current.order.slice(0, original.order.size()) == original.order, "inherited menu order unchanged")
	for id: String in original.catalog:
		check(current.catalog.has(id) and current.catalog[id] == original.catalog[id], "inherited entry unchanged: " + id)
	var seen: Dictionary = {}
	var identities: Dictionary = {}
	for id: String in current.order:
		check(not seen.has(id), "unique menu id: " + id)
		seen[id] = true
		check(current.catalog.has(id), "menu entry declared: " + id)
	for id: String in current.catalog:
		if original.catalog.has(id):
			continue
		check(id in current.order, "new entry is in menu: " + id)
		var game := HOST.new()
		game.map_id = id
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
		check(game.startup_error.is_empty(), "new map starts: " + id)
		if is_instance_valid(game.player):
			game.player.set_physics_process(false)
			var identity: Dictionary = game.motion_identity()
			check(identity.map == id, "new recording map identity: " + id)
			check(not identities.has(identity.course_key), "distinct new course identity: " + id)
			identities[identity.course_key] = id
			if game.map_has_capability("grapple"):
				check(game.player.has_method("configure_tether") and game.player.has_method("tether_identity"), "grapple runner contract: " + id)
				if game.map_entry().has("tether_model"):
					check(str(game.player.get("model")) == game.tether_model(), "fixed law reaches production runner: " + id)
		game.request_quit(0)
		game.free()
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("registration.json"), FileAccess.WRITE).store_string(JSON.stringify({"ok": ok, "checks": checks, "new_identities": identities}, "\t"))
	print("R22 registration: ", ok, " checks=", checks.size())
	quit(0 if ok else 1)

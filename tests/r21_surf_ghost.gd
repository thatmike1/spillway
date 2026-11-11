extends SceneTree
## load the real clean old run, then prove revision rejection clears a previously loaded new ghost.
const SCENE := preload("res://scenes/r21.tscn")
const GHOST := preload("res://scripts/r16_ghost.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
var opts := {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			opts[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	run.call_deferred()

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var output := str(opts.out)
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node3D = SCENE.instantiate()
	game.map_id = "saltglass"
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
	var old_path := str(opts["old-ghost"])
	var new_path := str(opts["new-ghost"])
	var old_sha := FileAccess.get_sha256(old_path)
	var old := READER.read(old_path)
	var current := READER.read(new_path)
	var ghost := GHOST.new()
	root.add_child(ghost)
	var old_good := ghost.load_run(old_path, old.header.identity)
	var new_good := ghost.load_run(new_path, game.motion_identity())
	var rejected := ghost.load_run(old_path, game.motion_identity())
	var ok: bool = old.ok and current.ok and READER.clean_finish(old).ok and old_good.ok and new_good.ok and not rejected.ok and not ghost.loaded and "geometry" in str(rejected.error).to_lower()
	ok = ok and old_sha == FileAccess.get_sha256(old_path)
	var report := {"ok": ok, "old_read_clean": READER.clean_finish(old), "old_load": old_good, "new_load": new_good, "old_rejected": rejected, "loaded_after_rejection": ghost.loaded, "old_sha256_before_after": old_sha, "old_identity": old.header.identity, "current_identity": game.motion_identity()}
	var file := FileAccess.open(output.path_join("ghost.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	game.request_quit(0)
	print("R21 actual old/new ghost lifecycle: ", ok)
	quit(0 if ok else 1)

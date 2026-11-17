extends Node
## opt-in release-package probe; refuses a normal profile or a desktop launch.
var output_path := ""
var game: Node
var failures: Array[String] = []
var checked_maps: Array = []

func _ready() -> void:
	game = get_parent()
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("PACKAGE FAILURE: " + message)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var profile := str(game.get("profile_path"))
	var explicit := args.has("--r16-profile=" + profile)
	if DisplayServer.get_name() != "headless" or not explicit or not profile.is_absolute_path() or not output_path.is_absolute_path() or profile.get_base_dir() != output_path.get_base_dir() or not args.has("--no-run-recordings"):
		printerr("PACKAGE FAILURE: probe requires headless mode, disabled recordings and a private absolute profile beside its receipt")
		get_tree().quit(1)
		return
	check(str(game.get("startup_error")).is_empty(), "startup")
	if not failures.is_empty():
		complete()
		return
	if args.has("--package-reload"):
		check(is_equal_approx(float(game.get("settings").volume), 0.37), "setting survived process restart")
		var saved := ConfigFile.new()
		check(saved.load(profile) == OK, "saved profile readable")
		var ticks: Variant = saved.get_value("package-other-map", "clean_best_ticks", -1)
		check(typeof(ticks) == TYPE_INT and ticks == 9007199254740993, "other-map integer best survived saves")
	else:
		var seed := ConfigFile.new()
		if FileAccess.file_exists(profile):
			check(seed.load(profile) == OK, "private seed readable")
		seed.set_value("package-other-map", "clean_best_ticks", 9007199254740993)
		check(seed.save(profile) == OK, "seed private other-map best")
		var ids: Array = game.call("map_ids")
		check(not ids.is_empty(), "menu has maps")
		for id: String in ids:
			game.call("select_map", id)
			await get_tree().process_frame
			check(str(game.get("map_id")) == id and is_instance_valid(game.get("level")) and is_instance_valid(game.get("player")), "load " + id)
			game.call("restart_run")
			await get_tree().physics_frame
			check(int(game.get("checkpoint_index")) == 0 and bool(game.get("clean_eligible")), "restart " + id)
			game.call("practice_restart")
			await get_tree().physics_frame
			check(not bool(game.get("clean_eligible")) and int(game.get("practice_stage")) >= 0, "practice " + id)
			checked_maps.append(id)
		game.call("change_setting", "volume", 0.37)
		check(bool(game.get("last_save_ok")), "setting saved")
	complete()

func complete() -> void:
	var receipt := {"ok": failures.is_empty(), "maps": checked_maps, "failures": failures, "reload": OS.get_cmdline_user_args().has("--package-reload")}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("PACKAGE FAILURE: cannot write receipt")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(receipt))
	file.close()
	print("PACKAGE RESULT " + JSON.stringify(receipt))
	game.call("request_quit", 0 if failures.is_empty() else 1)

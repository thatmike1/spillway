extends SceneTree
## full-host presentation toggles must preserve attempts, motion and style state.
const HOST := preload("res://scripts/game.gd")
const FEEDBACK := preload("res://scripts/fx/tether_feedback.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
const MAPS := preload("res://scripts/maps/r22_catalog.gd")
var output := ""
var menu_contract := ""
var checks: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg.begins_with("--menu-contract="):
			menu_contract = arg.trim_prefix("--menu-contract=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	if not ok:
		push_error(label)

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var game := HOST.new()
	game.map_id = "tether-yard"
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
	check(is_instance_valid(game.tether_feedback), "grapple host installs observer")
	check(game.map_registry == preload("res://scripts/maps/catalog.gd").make(), "legacy startup registry is unchanged")
	if not menu_contract.is_empty():
		var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(menu_contract))
		check(READER.json_safe(game.map_registry) == frozen.menu_registry, "startup registry exactly matches frozen menu fixture")
	var identity: Dictionary = game.motion_identity()
	var motion := var_to_bytes(game.player.get_motion_state())
	var style := var_to_bytes(game.session.style.snapshot())
	var attempt: int = game.attempts
	var rope: GeometryInstance3D = game.player.get("_tether")
	var layers := rope.layers
	for key: String in FEEDBACK.KEYS:
		check(not bool(game.settings[key]), "off default: " + key)
		game.change_setting(key, true)
		check(game.attempts == attempt, "toggle keeps attempt: " + key)
		check(game.motion_identity() == identity and var_to_bytes(game.player.get_motion_state()) == motion, "toggle preserves motor: " + key)
		check(var_to_bytes(game.session.style.snapshot()) == style, "toggle preserves style: " + key)
	check(rope.layers == 0, "new rope suppresses original visual layers")
	game.change_setting("tether_rope_visual", false)
	check(rope.layers == layers, "disabling restores original rope layers")
	var sound: Node = game.tether_feedback.get("_sound")
	var voices: Dictionary = sound.get("voices")
	voices.wind.play()
	check(voices.wind.playing, "pause test has an active voice")
	game.set_paused(true)
	check(not voices.wind.playing, "pause boundary stops observer audio")
	game.set_paused(false)
	game.select_map("breakwater")
	check(not is_instance_valid(game.tether_feedback), "original map has no observer")
	check(game.player.get("camera").current, "replacement runner owns current camera")
	var registry := MAPS.make()
	var entry: Dictionary = registry.catalog.practice.duplicate(true)
	entry.kind = "course"
	entry.dress = false
	entry.look_palette = "practice"
	game.maps.catalog["palette-fixture"] = entry
	game.maps.order.append("palette-fixture")
	game.select_map("palette-fixture")
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	check(is_instance_valid(game.look_layer), "course can declare a look palette")
	var before: Dictionary = game.motion_identity()
	var solids := game.level.find_children("*", "CollisionShape3D", true, false).size()
	game.set_look(false)
	check(not game.look_layer.enabled, "declared palette supports look off")
	game.set_look(true)
	check(game.look_layer.enabled and game.motion_identity() == before, "declared palette preserves identity through both modes")
	check(game.level.find_children("*", "CollisionShape3D", true, false).size() == solids, "declared palette preserves collision count")
	game.maps.catalog["palette-fixture"]["own_look"] = true
	game.select_map("breakwater")
	game.select_map("palette-fixture")
	check(not is_instance_valid(game.look_layer), "own look opts out of generic palette fallback")
	game.request_quit(0)
	game.free()
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("host.json"), FileAccess.WRITE).store_string(JSON.stringify({"ok": ok, "checks": checks}, "\t"))
	print("Host presentation capabilities: ", ok, " checks=", checks.size())
	quit(0 if ok else 1)

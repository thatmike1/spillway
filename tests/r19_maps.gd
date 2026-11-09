extends SceneTree
## exercise the configured production scene, including new-map registration and presentation.
const SCENE := preload("res://scenes/r19.tscn")
var output := ""
var checks: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func check(label: String, condition: bool) -> void:
	checks.append({"name": label, "ok": condition})
	if not condition:
		printerr("FAIL ", label)

func tap(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var game := SCENE.instantiate()
	check("production scene enables records and recordings", game.persist and game.record_runs)
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.map_id = "saltglass"
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection")
	root.add_child(game)
	game.set_paused(true)
	check("normal host loads Saltglass", game.startup_error.is_empty() and game.map_id == "saltglass")
	var required := ["breakwater", "whiteout-relay", "sunken-court", "rainline", "night-shift", "practice", "overflow", "experiment", "saltglass", "tether-yard", "fall-line", "line-drive"]
	check("explicit complete catalog retains default and new course", game.map_ids() == required and game.maps.default_chain == ["breakwater", "practice"] and game.map_kind() == "course")
	check("surf uses approved F2 body", game.player.get_script().resource_path == "res://scripts/r15_source_player.gd" and game.preset_id == "server128" and Engine.physics_ticks_per_second == 128)
	check("new course clears standing hull at spawn", game.hull_fits(game.preset, game.level.spawn.origin))
	var layers := 0
	for child: Node in game.level.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/r17_look.gd":
			layers += 1
	check("one presentation layer owns Saltglass", layers == 1 and game.look_layer.get_parent() == game.level)
	var identity: Dictionary = game.motion_identity()
	var feet: Vector3 = game.player.position
	var painted: Dictionary = game.look_layer.report.duplicate(true)
	check("calm painted sky and structural contours attached", painted.sky == "res://assets/look/r17/practice-sky.png" and painted.ink_segments > 0 and painted.jump_lips > 0)
	tap(KEY_L)
	check("actual L restores original look", not game.look_enabled and not game.look_layer.enabled)
	tap(KEY_L)
	check("actual L restores painted look", game.look_enabled and game.look_layer.enabled)
	check("L retains exact body and motion identity", game.player.position == feet and game.motion_identity() == identity)
	game.select_map("experiment")
	check("lab retains its experimental identity", game.is_lab() and "EXPERIMENTAL" in game.window_title())
	game.select_map("breakwater")
	check("default course restores faithful body and revision warning", not game.is_lab() and game.player.get_script().resource_path == "res://scripts/r15_source_player.gd" and "Older Breakwater" in game.map_revision_description())
	game.select_map("saltglass")
	check("return restores Saltglass identity", game.motion_identity() == identity)
	var ok := true
	for row: Dictionary in checks:
		ok = ok and bool(row.ok)
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks, "identity": identity, "look": painted, "scope": "configured source scene integration; final release and full route remain separate"}, "\t"))
	file.close()
	print("r19 maps: ", checks.size(), " checks; ok=", ok)
	game.set_paused(false)
	game.request_quit(0 if ok else 1)

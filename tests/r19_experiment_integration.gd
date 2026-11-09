extends SceneTree
## test-only catalog entry exercises the common wing before independently authored maps are ready.
const MAIN := preload("res://scripts/r19_main.gd")
const FIXTURE_ID := "r19-registry-fixture"
const FIXTURE_RUNNER := "res://tests/r19_experiment_runner_fixture.gd"
var output := ""
var checks: Array[Dictionary] = []
var game: Node

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func check(label: String, ok: bool) -> void:
	checks.append({"name": label, "ok": ok})
	if not ok:
		printerr("FAIL ", label)

func frames(count := 3) -> void:
	for i: int in count:
		await process_frame

func tap(code: Key) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.keycode = code
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game = MAIN.new()
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection")
	game.map_registry = game.R19_MAPS.make()
	game.map_registry.catalog[FIXTURE_ID] = {"name": "Registry fixture", "theme": "Test only, no new movement", "kind": "experiment", "experimental": true,
		"script": "res://scripts/r14_practice_level.gd", "variant": "practice", "runner": FIXTURE_RUNNER,
		"instructions": "EXPERIMENTAL registry fixture. No special keys."}
	game.map_registry.order.append(FIXTURE_ID)
	root.add_child(game)
	game.set_paused(true)
	await frames()
	var original: Dictionary = game.motion_identity()
	var hud: Node = game.hud
	var button: Button = hud.map_buttons[FIXTURE_ID]
	check("common wing has an explicitly named section", hud.experiments_heading.visible and hud.experiments_heading.text == "Experiments")
	check("only experiment cards move to separate grid", button.get_parent() == hud.experiments_grid and hud.map_buttons.breakwater.get_parent() == hud.map_grid and hud.map_buttons.experiment.get_parent() == hud.map_grid)
	check("experimental card says experimental", "EXPERIMENTAL" in button.text)
	check("fixture never replaces the default", game.map_id == "breakwater" and game.maps.default_chain == ["breakwater", "practice"])
	button.grab_focus()
	await tap(KEY_ENTER)
	await frames()
	game.set_paused(true)
	check("actual card input selects fixture", game.map_id == FIXTURE_ID and game.is_experiment_map())
	check("trusted entry chooses its distinct runner", game.player.get_script().resource_path == FIXTURE_RUNNER and not game.runner_is_standin())
	check("experiment time identity includes its runner version", "r19-registry-fixture-1" in str(game.motion_identity().motor))
	check("experiment title and HUD identify its own name", "EXPERIMENTAL" in game.window_title() and "REGISTRY FIXTURE" in hud.lab_tag.text)
	check("unrelated Lab switches stay hidden", game.lab_moves().is_empty() and not hud.lab_box.visible)
	check("instructions and keys do not claim Lab controls", "registry fixture" in hud.controls.text and not "Shift slide" in hud.keys_line.text and not "wall jumps" in hud.controls.text)
	check("experiment law metadata names the experiment", "Registry fixture" in JSON.stringify(game.law_labels()) and game.law_labels().course_law == "experimental")
	var layers := 0
	for child: Node in game.level.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/r17_look.gd":
			layers += 1
	check("one common presentation layer", layers == 1 and game.look_layer.enabled)
	var identity: Dictionary = game.motion_identity()
	var feet: Vector3 = game.player.position
	await tap(KEY_L)
	check("actual L disables experiment presentation", not game.look_layer.enabled)
	await tap(KEY_L)
	check("actual L retains experiment physics identity", game.look_layer.enabled and identity == game.motion_identity() and feet == game.player.position)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3440, 1440)]:
		root.size = resolution
		hud._layout()
		await frames()
		check("experiment grid fits pause sheet at " + str(resolution), hud.experiments_grid.columns == hud.map_grid.columns and hud.experiments_grid.get_minimum_size().x <= hud._pause_scroll.size.x)
		if DisplayServer.get_name() != "headless":
			hud._pause_scroll.ensure_control_visible(button)
			await frames()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("wing-%dx%d.png" % [resolution.x, resolution.y]))
	game.select_map("experiment")
	await frames()
	check("original Lab returns its own runner and three controls", game.player.get_script().resource_path == "res://scripts/r16_experiment_player.gd" and game.lab_moves().size() == 3 and hud.lab_box.visible)
	check("original Lab tag is restored", hud.lab_tag.text == "EXPERIMENTAL  ·  MOVEMENT LAB")
	game.select_map("breakwater")
	await frames()
	check("leaving wing restores exact original-map motion identity", game.motion_identity() == original and game.player.get_script().resource_path == "res://scripts/r15_source_player.gd")
	check("original map loses experimental tags and restrictions", not game.is_experiment_map() and not game.is_lab() and not "EXPERIMENTAL" in game.window_title() and not hud.lab_tag.visible)
	game.select_preset("r13_original120")
	check("existing map still offers advanced comparison", game.preset_id == "r13_original120")
	game.select_map(FIXTURE_ID)
	check("entering experiment restricts advanced preset to F2", game.preset_id == "server128" and game.player.get_script().resource_path == FIXTURE_RUNNER)
	game.select_map("breakwater")
	var ok := true
	for row: Dictionary in checks:
		ok = ok and bool(row.ok)
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks, "scope": "test-only catalog and no-mechanic runner exercise production integration; not a playable experiment proof"}, "\t"))
	file.close()
	print("R19 wing integration: ", checks.size(), " checks; ok=", ok)
	game.set_paused(false)
	game.request_quit(0 if ok else 1)

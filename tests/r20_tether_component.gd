extends SceneTree
## production scene acceptance; fixtures finish setup before the first observed motor tick.
const SCENE := preload("res://scenes/r20.tscn")
const OLD_HOST := preload("res://scripts/r19_main.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
const SESSION := preload("res://scripts/r16_run_session.gd")
const LEVEL := preload("res://scripts/r19_tether_level.gd")
var output := ""
var game: Node3D
var hook: Post
var checks: Array = []
var episodes: Array = []
var observations: Array = []
var case_name := ""
var counter := 0
var inputs: Array = []
var baseline := ""
var old := false

class Post:
	extends Node
	signal ticked
	var driver: Object
	func _physics_process(_dt: float) -> void:
		driver.observe()
		ticked.emit()

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		elif arg.begins_with("--baseline="):
			baseline = arg.trim_prefix("--baseline=")
		elif arg == "--old-e":
			old = true
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label, "case": case_name})
	print("ok " if ok else "FAIL ", case_name, " · ", label)

func observe() -> void:
	if game == null or game.player == null:
		return
	counter += 1
	var player: CharacterBody3D = game.player
	observations.append({"t": counter, "p": READER.json_safe(player.position), "v": READER.json_safe(player.velocity), "yaw": player.yaw, "pitch": player.pitch,
		"grounded": player.is_grounded(), "paused": game.paused, "motion": READER.json_safe(player.get_motion_state()),
		"checkpoint": game.checkpoint_index, "elapsed": game.elapsed, "identity": game.course_key})

func ticks(n: int) -> void:
	for i: int in n:
		await hook.ticked

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	send(event)

func button(index: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	send(event)

func send(event: InputEvent) -> void:
	inputs.append({"t": counter, "event": SESSION.describe(event)})
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func activate(control: BaseButton) -> void:
	control.grab_focus()
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)

func rope(left: bool, right: bool = true) -> void:
	if old:
		key(KEY_E, left)
	else:
		button(MOUSE_BUTTON_LEFT, left)
		button(MOUSE_BUTTON_RIGHT, right and left)

func aim(at: Vector3) -> void:
	var player: CharacterBody3D = game.player
	var to: Vector3 = at - player._eye()
	var target_yaw := atan2(-to.x, -to.z)
	var target_pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var event := InputEventMouseMotion.new()
	var scale: float = player.tape_radians_per_count
	event.relative = Vector2(wrapf(float(player.yaw) - target_yaw, -PI, PI), float(player.pitch) - target_pitch) / scale
	event.screen_relative = event.relative
	send(event)

func new_case(label: String, stress: String = "", profile: String = "") -> void:
	if game != null:
		close_case()
	case_name = label
	observations = []
	inputs = []
	counter = 0
	game = SCENE.instantiate()
	game.name = "R20Component"
	game.map_id = "tether-yard"
	game.motor = "server128"
	game.seed_from_r15 = false
	game.source_sensitivity_override = 2.5
	game.set_window_title = false
	game.persist = true
	game.profile_path = output.path_join(label + ".cfg") if profile.is_empty() else profile
	game.record_runs = true
	game.recordings_dir = output.path_join(label + "-recordings")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("share.cfg")
	if old:
		game.source_runner = load(baseline)
	root.add_child(game)
	if stress == "range":
		# labelled extreme tangential entry fixture: initial velocity only, never an after-setup write.
		game.level.spawn = Transform3D(Basis.IDENTITY, Vector3(29.975, 10.4, -8.0))
		game.level.kill_bounds = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
		game._kill_bounds = game.level.kill_bounds
		game.course_geometry = "r20-fixture-range-collisionless-tangent240-v1"
		game._refresh_records()
		game.restart_run("fixture_range")
		game.player.velocity = Vector3(0, 240.0, -240.0)
		for solid: Node in game.level.find_children("*", "StaticBody3D", true, false):
			solid.collision_layer = 0
	elif stress == "obstructed":
		# the eye ray clears this short physical block; the required centre ray does not.
		var block := StaticBody3D.new()
		block.name = "FixtureCentreRayBlock"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2, 0.22, 0.20)
		shape.shape = box
		block.add_child(shape)
		block.position = Vector3(0, 8.4577, 2.0)
		game.level.add_child(block)
		game.course_geometry = "r20-fixture-centre-obstruction-v1"
		game._refresh_records()
		game.restart_run("fixture_obstructed")
	game.hud.dismiss_title()
	# all subsequent player travel is input, except explicit public lifecycle boundaries under test.

func close_case() -> void:
	game.session.boundary("quit")
	var reads: Array = []
	for sealed: Dictionary in game.session.sealed:
		var rec := READER.read(str(sealed.path))
		reads.append({"path": sealed.path, "ok": rec.ok, "header": rec.header, "seal": rec.seal, "columns": rec.columns, "inputs": rec.inputs, "events": rec.events})
		check(rec.ok, "original Godot reader accepts sealed recording")
	var file := FileAccess.open(output.path_join(case_name + ".json.gz"), FileAccess.WRITE)
	file.store_buffer(JSON.stringify({"observations": observations, "inputs": inputs, "recordings": reads}).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	episodes.append({"case": case_name, "samples": observations.size(), "recordings": reads.size()})
	for code: int in [KEY_E, KEY_SPACE, KEY_W, KEY_S, KEY_A, KEY_D, KEY_SHIFT, KEY_R, KEY_1, KEY_2, KEY_3]:
		key(code, false)
	button(1, false)
	button(2, false)
	root.remove_child(game)
	game.free()
	game = null

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	Engine.physics_ticks_per_second = 128
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	RenderingServer.render_loop_enabled = false
	hook = Post.new()
	hook.driver = self
	hook.process_physics_priority = 1001
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	if old:
		await physical_cases()
	else:
		new_case("controls")
		await ticks(33)
		check(game.player.movement_version() == "r20-tether-mouse-1", "production registry selects mouse runner")
		check(game.hud.get_script().resource_path == "res://scripts/r20_hud.gd", "actual configured scene uses R20 pause UI")
		check(game.is_experiment_map() and game.lab_moves().is_empty(), "experiment fixed grapple-only without lab toggles")
		check(game.settings.tether_model == "classic" and not game.settings.tether_auto_reel, "classic manual-reel defaults")
		aim(LEVEL.ANCHORS[0])
		key(KEY_E, true)
		await ticks(45)
		check(game.player.grapple_count == 0, "E alone never attaches in Tether")
		key(KEY_E, false)
		button(2, true)
		await ticks(45)
		check(game.player.grapple_count == 0, "RMB alone never attaches")
		button(2, false)
		button(1, true)
		await ticks(1)
		var length: float = game.player.grapple_length_u
		await ticks(60)
		check(game.player.grapple_count == 1 and game.player.grapple_ticks == 61, "LMB acquires and holds")
		check(game.player.grapple_length_u == length and not game.player.get_motion_state().experiment.tether.reeling, "LMB alone preserves rest length and does not reel")
		button(2, true)
		await ticks(90)
		check(game.player.grapple_length_u < length and game.player.impulse_totals.grapple_pull.length() > 0.0, "RMB while held actually reels and pulls")
		button(1, false)
		await ticks(1)
		check(game.player.grapple.is_empty() and game.player.grapple_release_reason == "released", "LMB release detaches on next physics step even while RMB held")
		check(bool(game.player.last_cue.get("active", false)) and game.player.cue_player.stream != null, "manual release activates real AudioStreamPlayer resource on Dummy")
		button(2, false)
		await physical_cases()
		await lifecycle_cases()
	close_case()
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks, "episodes": episodes, "scope": "configured scene, headless Dummy component only", "old_e": old}, "\t"))
	file.close()
	print("tether component: ", checks.size(), " checks; ok=", ok)
	quit(0 if ok else 1)

func physical_cases() -> void:
	new_case("immediate_fresh")
	aim(LEVEL.ANCHORS[0])
	rope(true)
	await ticks(1)
	check(game.player.grapple_count == 1 and game.player.grapple_ticks == 1, "fresh gameplay press before first physics tick acquires without delay")
	new_case("ground_timeout")
	await ticks(33)
	aim(LEVEL.ANCHORS[0])
	rope(true)
	await ticks(180)
	var grounded_y: float = game.player.position.y
	check(game.player.is_grounded() and absf(grounded_y - 4.001) < 0.02 and game.player.position.z < 10.0, "ground reel travels under anchor without lifting in this sequence")
	key(KEY_SPACE, true)
	await ticks(30)
	key(KEY_SPACE, false)
	check(game.player.position.y > grounded_y + 0.5, "real Space jump lifts ground reel")
	await ticks(174)
	check(game.player.grapple_ticks == 384 and not game.player.grapple.is_empty(), "classic remains attached through tick 384")
	await ticks(1)
	check(game.player.grapple.is_empty() and game.player.grapple_release_reason == "time", "timeout detaches at exactly old tick 385")
	if not old:
		check(bool(game.player.last_cue.get("active", false)) and game.player.last_cue.reason == "time", "timeout plays actual distinct generated cue")
		check("expired" in game.player.experiment_status() and "Release mouse" in game.player.experiment_status(), "timeout visible reason and unarmed state")
	await ticks(150)
	check(game.player.grapple_count == 1, "held buttons after timeout never reacquire or farm fresh presses")
	rope(false)
	await ticks(1)
	aim(LEVEL.ANCHORS[0])
	rope(true)
	await ticks(1)
	check(game.player.grapple_count == 2, "release and fresh press re-arm after timeout")
	new_case("minimum")
	await ticks(33)
	aim(LEVEL.ANCHORS[0])
	rope(true)
	await ticks(370)
	check(is_equal_approx(game.player.grapple_length_u, 96.0) and not game.player.grapple.is_empty(), "minimum rope length is reached and remains attached")
	new_case("obstructed", "obstructed")
	await ticks(33)
	aim(LEVEL.ANCHORS[0])
	rope(true)
	await ticks(1)
	check(game.player.grapple_count == 1 and game.player.grapple_release_reason == "obstructed", "eye acquires but centre ray obstruction releases")
	if not old:
		check(bool(game.player.last_cue.get("active", false)) and game.player.last_cue.reason == "obstructed", "obstruction activates distinct real cue")
		check("blocked" in game.player.experiment_status(), "obstruction reason visible")
	new_case("range", "range")
	# no settling in the extreme airborne entry; first tick arms, next delivered input acquires.
	await ticks(1)
	aim(LEVEL.ANCHORS[0])
	rope(true)
	await ticks(300)
	check(game.player.grapple_count == 1 and game.player.grapple_release_reason == "range", "earned extreme tangential entry crosses range/stretch limit")
	if not old:
		check(game.player.last_cue.get("reason", "") == "range", "range uses its own actual generated cue")

func lifecycle_cases() -> void:
	new_case("lifecycle")
	await ticks(33)
	aim(LEVEL.ANCHORS[0])
	rope(true)
	await ticks(20)
	game.set_paused(true)
	var pose: Vector3 = game.player.position
	var remaining: int = game.player.grapple_count
	check(game.player.grapple.is_empty(), "pause immediately clears attachment")
	await ticks(20)
	check(game.player.position == pose, "pause freezes body")
	game.set_paused(false)
	await ticks(20)
	check(game.player.grapple_count == remaining and game.player.grapple.is_empty(), "held mouse across unpause cannot reacquire")
	rope(false)
	await ticks(1)
	aim(LEVEL.ANCHORS[0])
	rope(true)
	await ticks(1)
	check(not game.player.grapple.is_empty(), "fresh post-pause press acquires")
	key(KEY_R, true)
	key(KEY_R, false)
	await ticks(20)
	check(game.player.grapple.is_empty() and game.player.grapple_count == 0, "actual R clears rope and blocks held-button restart reacquisition")
	rope(false)
	await ticks(1)
	aim(LEVEL.ANCHORS[0])
	rope(true)
	await ticks(10)
	game.set_paused(true)
	var manual_key: String = game.course_key
	activate(game.hud.reel_automatic)
	check(game.paused and game.settings.tether_auto_reel and game.player.auto_reel, "actual pause automatic-reel button changes runner and keeps menu paused")
	check(game.course_key != manual_key and game.player.grapple.is_empty(), "reel preference has new motion identity and clears rope")
	var automatic_key: String = game.course_key
	activate(game.hud.tether_models.pendulum)
	check(game.player.model == "pendulum" and game.course_key != automatic_key, "actual model button changes law and motion identity")
	activate(game.hud.tether_models.elastic)
	check(game.player.model == "elastic", "elastic selectable through actual menu")
	activate(game.hud.tether_models.classic)
	check(game.player.model == "classic", "classic selectable and retained as named model")
	var cfg := ConfigFile.new()
	check(cfg.load(game.profile_path) == OK and cfg.get_value("settings", "tether_auto_reel", false) == true, "automatic preference actually saved in profile")
	game.set_paused(false)
	await ticks(20)
	check(game.player.grapple.is_empty(), "menu/held clicks cannot acquire after settings restart")
	rope(false)
	await ticks(1)
	aim(LEVEL.ANCHORS[0])
	button(1, true)
	await ticks(80)
	check(not game.player.grapple.is_empty() and game.player.impulse_totals.grapple_pull.length() > 0.0, "automatic reel actually pulls with LMB alone")
	var saved_profile: String = game.profile_path
	game.set_paused(true)
	activate(game.hud.reel_manual)
	check(not game.settings.tether_auto_reel and not game.player.auto_reel, "manual menu control restores manual law")
	activate(game.hud.reel_automatic)
	game.select_map("breakwater")
	await ticks(1)
	check(game.runner_path() == "res://scripts/r15_source_player.gd" and get_nodes_in_group("r15_grapple_anchor").is_empty(), "main map restores original runner and removes rope anchors")
	check(not game.hud.tether_section.visible, "Tether preference section hidden on main map")
	game.select_map("experiment")
	await ticks(1)
	check(game.runner_path() == "res://scripts/r16_experiment_player.gd" and game.lab_moves().size() == 3, "Movement Lab keeps original runner and three toggles")
	check(InputMap.action_get_events("r15_grapple").any(func(e: InputEvent) -> bool: return e is InputEventKey and e.physical_keycode == KEY_E), "Lab E InputMap binding unchanged")
	game.select_map("tether-yard")
	await ticks(20)
	check(game.player.grapple.is_empty(), "held mouse across map selections never acquires")
	game.player.set_mechanic("slide", true)
	game.player.set_mechanic("wall_jump", true)
	check(not game.player.mechanic_enabled("slide") and not game.player.mechanic_enabled("wall_jump"), "fixed loadout ignores old toggles")
	# reload the actual profile into a new production scene, not just ConfigFile parsing.
	close_case()
	new_case("reload", "", saved_profile)
	await ticks(33)
	check(game.settings.tether_auto_reel and game.player.auto_reel, "new production scene reloads saved automatic preference")
	await identity_cases()

func identity_cases() -> void:
	# compare all original full motion identities, with the same accepted R19 revisions.
	var original := OLD_HOST.new()
	original.persist = false
	original.record_runs = false
	original.seed_from_r15 = false
	original.set_window_title = false
	original.profile_path = output.path_join("old-absent.cfg")
	original.ghosts_directory = output.path_join("old-ghosts")
	original.ghost_share_storage = output.path_join("old-share.cfg")
	root.add_child(original)
	var ids: Array = preload("res://scripts/r15_maps.gd").ORDER
	var identity_rows: Array = []
	for id: String in ids:
		game.select_map(id)
		original.select_map(id)
		check(game.motion_identity() == original.motion_identity() and game.record_identity() == original.record_identity(), "full original-map identity unchanged: " + id)
		identity_rows.append({"id": id, "r20": game.motion_identity(), "r19": original.motion_identity(), "record_identity": game.record_identity()})
	var pin: Dictionary = game.PRESETS.physics_fingerprint(game.PRESETS.source_settings("server128", {}))
	check(pin.sv_accelerate == 5.5 and pin.sv_airaccelerate == 100.0 and pin.sv_friction == 5.2 and pin.sv_maxspeed == 320.0 and pin.sv_gravity == 800.0 and pin.sv_jump_impulse == 301.993377, "all six F2 pins unchanged")
	var file := FileAccess.open(output.path_join("identities.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(identity_rows, "\t"))
	file.close()
	original.session.boundary("quit")
	root.remove_child(original)
	original.free()

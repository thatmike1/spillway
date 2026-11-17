extends SceneTree
## save/load and ghost-plan checks use real files and a complete production-host recording.
const HOST := preload("res://scripts/game.gd")
const STORE := preload("res://scripts/plan/store.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
var output := ""
var readback := false
var game: Node
var started_ms := Time.get_ticks_msec()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started_ms > 30000:
		push_error("plan persistence watchdog: a check failed or the host did not finish")
		quit(1)
	return false
func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg == "--readback":
			readback = true
	run.call_deferred()
func key(code: String) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = OS.find_keycode_from_string(code)
		event.physical_keycode = event.keycode
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
func digest(path: String) -> String:
	return FileAccess.get_sha256(path)
func start_game(record: bool) -> void:
	game = HOST.new()
	game.map_id = "plan-yard"
	game.motor = "server128"
	game.persist = false
	game.record_runs = record
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output.path_join("profile.cfg")
	game.recordings_dir = output.path_join("runs")
	game.ghosts_directory = game.recordings_dir
	game.ghost_share_storage = output.path_join("ghost-selection.cfg")
	root.add_child(game)
	game.player.plan_store.path = output.path_join("plans.cfg")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	start_game(true)
	await process_frame
	if readback:
		key("Tab")
		key("F7")
		assert(game.level.plan == [0,3,6])
		key("Enter")
		await process_frame
		game.player.sync_ghost_plan()
		assert(game.session.ghost.loaded and game.player.best_plan.get("anchors") == [0,3,6])
		var loaded: Dictionary = game.player.plan_store.load_slot(1)
		assert(loaded.ok and loaded.design.anchors == [0,3,8])
		print("plan readback: slots and matching best ghost survive a fresh process")
		game.request_quit(0)
		return
	key("Tab")
	key("F6")
	assert(game.player.plan_store.load_slot(0).design.anchors == [0,3,6])
	key("7")
	key("9")
	key("BracketRight")
	key("F6")
	assert(game.player.plan_store.load_slot(1).design.anchors == [0,3,8])
	key("BracketLeft")
	key("F8")
	assert(game.level.budget == 1)
	key("F7")
	assert(game.level.plan == [0,3,6] and game.level.budget == 3)
	key("BracketLeft")
	assert(game.player.planner.active_slot == 2)
	var before: Dictionary = game.level.design()
	key("F7")
	assert(game.level.design() == before and game.elapsed == 0 and not game.session.attempt_live)
	key("BracketRight")
	check_bad_files()
	var driver := Playback.new()
	driver.game = game
	driver.events = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("tape.json")))
	assert(driver.events is Array and not driver.events.is_empty())
	driver.process_physics_priority = -100
	game.add_child(driver)
	var ticks := 0
	while not game.finished and ticks < 128*15:
		await physics_frame
		ticks += 1
	assert(game.finished and game.finish_kind == "clean" and game.respawn_count == 0)
	driver.done = true
	for action: String in ["move_forward","move_back","move_left","move_right","jump"]:
		Input.action_release(action)
	await process_frame
	await process_frame
	game.player.sync_ghost_plan()
	assert(game.session.ghost.loaded and game.player.best_plan.get("anchors") == [0,3,6])
	var path: String = game.session.ghost_path
	var hash_before := digest(path)
	var run_data: Dictionary = READER.read(path,true)
	assert(run_data.ok and READER.clean_finish(run_data).ok)
	var original_key: String = game.course_key
	key("Tab")
	for i: int in 20:
		game.player.sync_ghost_plan()
	assert(digest(path) == hash_before)
	key("7")
	key("9")
	key("Enter")
	await process_frame
	game.player.sync_ghost_plan()
	assert(game.course_key != original_key and not game.session.ghost.loaded and game.player.best_plan.is_empty())
	key("Tab")
	key("F7")
	key("Enter")
	await process_frame
	game.player.sync_ghost_plan()
	assert(game.course_key == original_key and game.session.ghost.loaded and game.player.best_plan.get("anchors") == [0,3,6])
	assert(digest(path) == hash_before)
	FileAccess.open(output.path_join("persistence.json"),FileAccess.WRITE).store_string(JSON.stringify({"ok":true,"ghost_path":path,"ghost_sha256":hash_before,"plan":game.player.best_plan,"time":run_data.seal.outcome.time},"\t"))
	print("plan persistence: two slots, empty-slot safety, corrupt/oversized/invalid rejection, full recording, ghost recipe, cross-plan refusal and immutable recording pass")
	game.request_quit(0)
func check_bad_files() -> void:
	var store := STORE.new()
	store.path = output.path_join("bad.cfg")
	FileAccess.open(store.path,FileAccess.WRITE).store_string("not a config [")
	var old := digest(store.path)
	var printing := Engine.print_error_messages
	Engine.print_error_messages = false
	var refused_load := store.load_slot(0)
	var refused_save := store.save_slot(0,game.level.design())
	Engine.print_error_messages = printing
	assert(not refused_load.ok and not refused_save.ok and digest(store.path) == old)
	FileAccess.open(store.path,FileAccess.WRITE).store_string("x".repeat(STORE.MAX_BYTES+1))
	old = digest(store.path)
	assert(not store.load_slot(0).ok and digest(store.path) == old)
	var invalid: Dictionary = game.level.design()
	invalid.anchors = [0,0]
	assert(not STORE.normalize(invalid).ok)
	invalid = game.level.design()
	invalid.block = 4
	invalid.blocks_enabled = false
	assert(not STORE.normalize(invalid).ok)

class Playback extends Node:
	var game: Node
	var events: Array
	var index := 0
	var tick := 0
	var done := false
	func _physics_process(_delta: float) -> void:
		if done:
			return
		while index < events.size() and roundi(float(events[index].time)*128) <= tick:
			var row: Dictionary = events[index]
			var input: InputEvent
			if row.has("key"):
				var key_event := InputEventKey.new()
				key_event.keycode = OS.find_keycode_from_string(row.key)
				key_event.physical_keycode = key_event.keycode
				key_event.pressed = row.pressed
				input = key_event
			elif row.has("button"):
				var button := InputEventMouseButton.new()
				button.button_index = row.button
				button.pressed = row.pressed
				input = button
			elif row.has("action"):
				var action := InputEventAction.new()
				action.action = row.action
				action.pressed = row.pressed
				action.strength = float(row.get("strength",1)) if action.pressed else 0.0
				input = action
			else:
				var motion := InputEventMouseMotion.new()
				motion.relative = Vector2(row.mouse[0],row.mouse[1])
				motion.screen_relative = motion.relative
				input = motion
			Input.parse_input_event(input)
			Input.flush_buffered_events()
			index += 1
		tick += 1

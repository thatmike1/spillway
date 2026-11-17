extends SceneTree
## replay copied user inputs without changing the source recording, motor or body poses.
const HOST := preload("res://scripts/game.gd")
const READER := preload("res://scripts/recordings/reader.gd")
var game: Node3D
var tape: Array = []
var recorded: Dictionary
var events_at := 0
var ticks := 0
var live := false
var source_path := ""
var tape_path := ""
var output := ""
var target_map := "saltglass"
var differences := 0
var worst := 0.0
var first_difference := -1
var first_samples: Array = []

class InputDriver extends Node:
	var suite: SceneTree
	func _physics_process(_dt: float) -> void:
		suite.feed_inputs()

class Observer extends Node:
	var suite: SceneTree
	func _physics_process(_dt: float) -> void:
		suite.observe()

func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	Engine.physics_ticks_per_second = 128
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--recording="):
			source_path = arg.trim_prefix("--recording=")
		elif arg.begins_with("--tape="):
			tape_path = arg.trim_prefix("--tape=")
		elif arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		elif arg.begins_with("--map="):
			target_map = arg.trim_prefix("--map=")
	start.call_deferred()

func start() -> void:
	assert(source_path.is_absolute_path() and tape_path.is_absolute_path() and output.is_absolute_path())
	recorded = READER.read(source_path, true)
	assert(recorded.ok and recorded.seal.outcome.kind == "finish")
	tape = JSON.parse_string(FileAccess.get_file_as_string(tape_path))
	game = HOST.new()
	game.map_id = target_map
	game.motor = "server128"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output + ".absent.cfg"
	game.ghosts_directory = output + ".ghosts"
	game.ghost_share_storage = output + ".selection.cfg"
	root.add_child(game)
	await process_frame
	await process_frame
	game.change_setting("source_sensitivity", recorded.header.metadata.look.sensitivity)
	game.change_setting("source_fov", recorded.header.metadata.look.fov)
	game.set_paused(false)
	game.restart_run("capture")
	var input_driver := InputDriver.new()
	input_driver.suite = self
	input_driver.process_physics_priority = -100
	root.add_child(input_driver)
	var observer := Observer.new()
	observer.suite = self
	observer.process_physics_priority = 1000
	root.add_child(observer)
	live = true

func feed_inputs() -> void:
	if not live:
		return
	var time := ticks / 128.0
	while events_at < tape.size() and float(tape[events_at].time) <= time + 0.0000001:
		var row: Dictionary = tape[events_at]
		var event: InputEvent
		if row.has("key"):
			var key := InputEventKey.new()
			key.keycode = int(row.keycode)
			key.physical_keycode = int(row.physical_keycode)
			key.pressed = row.pressed
			key.echo = row.get("echo", false)
			event = key
		elif row.has("button"):
			var button := InputEventMouseButton.new()
			button.button_index = int(row.button)
			button.pressed = row.pressed
			event = button
		elif row.has("mouse"):
			var mouse := InputEventMouseMotion.new()
			mouse.relative = Vector2(row.mouse[0], row.mouse[1])
			mouse.screen_relative = mouse.relative
			event = mouse
		else:
			var action := InputEventAction.new()
			action.action = row.action
			action.pressed = row.pressed
			action.strength = 1.0 if action.pressed else 0.0
			event = action
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		events_at += 1
	ticks += 1

func observe() -> void:
	if not live:
		return
	var index := ticks - 1
	if index >= 0 and index < recorded.columns.p.size():
		var expected: Vector3 = recorded.columns.p[index]
		var error: float = game.player.global_position.distance_to(expected)
		worst = maxf(worst, error)
		if index < 8:
			first_samples.append({"tick": index, "expected": str(expected), "actual": str(game.player.global_position), "error": error})
		if error > 0.00001:
			differences += 1
			if first_difference < 0:
				first_difference = index
	if game.finished or game.respawn_count > 0 or ticks > recorded.columns.p.size() + 128:
		live = false
		var must_match: bool = target_map == recorded.header.identity.map and game.level.geometry_hash() == recorded.header.identity.geometry
		var result := {"ok": game.finished and game.respawn_count == 0 and (not must_match or worst == 0.0), "exact_match_required": must_match, "map": target_map,
			"finished": game.finished, "respawns": game.respawn_count, "finish_kind": game.finish_kind,
			"elapsed": game.elapsed, "ticks": ticks, "replayed_events": events_at,
			"source": source_path, "source_sha256": FileAccess.get_sha256(source_path),
			"first_samples": first_samples, "position_differences": differences, "first_difference_tick": first_difference, "worst_position_error_m": worst,
			"limit": "actual recorded input replay, not a fastest line or preference verdict; variant may differ after its changed geometry"}
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
		print("saltglass human-input replay: ", result)
		game.request_quit(0 if result.ok else 1)

extends SceneTree
## real Escape/Tab events must keep pause focus separate from the outside-clock survey.
const HOST := preload("res://scripts/game.gd")
var output := ""
var snapshots: Array = []
var game: Node
var started_ms := Time.get_ticks_msec()
func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started_ms > 30000:
		push_error("plan pause watchdog: a host-state check failed")
		quit(1)
	return false
func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
func settle() -> void:
	await process_frame
	await process_frame
func paused_state() -> Dictionary:
	var files := {}
	for file: String in DirAccess.get_files_at(output.path_join("runs")):
		files[file] = FileAccess.get_sha256(output.path_join("runs").path_join(file))
	return {"identity":game.motion_identity(),"attempts":game.attempts,"elapsed":game.elapsed,
		"position":game.player.global_position,"design":game.level.design(),"files":files,
		"pending":game.session.pending.duplicate(true)}
func paused_tab() -> void:
	await settle()
	var before := paused_state()
	assert(not before.files.is_empty())
	key(KEY_TAB)
	await settle()
	var after := paused_state()
	assert(game.paused and before == after)
	snapshots.append({"identity":before.identity,"design":before.design,"recordings":before.files,"unchanged":true})
func run() -> void:
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	game = HOST.new()
	game.map_id = "plan-yard"
	game.motor = "server128"
	game.persist = false
	game.record_runs = true
	game.recordings_dir = output.path_join("runs")
	game.seed_from_r15 = false
	game.set_window_title = false
	root.add_child(game)
	await settle()
	var attempts: int = game.attempts
	key(KEY_ESCAPE)
	assert(game.paused)
	await paused_tab()
	assert(game.attempts == attempts and not game.player.planning)
	key(KEY_ESCAPE)
	key(KEY_TAB)
	assert(game.player.planning and not game.session.attempt_live and game.elapsed == 0)
	assert(not game.player.run_review_unavailable_reason().is_empty())
	game.player.planner.toggle_socket(0)
	var pending_design: Dictionary = game.level.design()
	key(KEY_ESCAPE)
	await paused_tab()
	assert(game.paused and not game.player.planner.visible and game.attempts == attempts+1)
	key(KEY_ESCAPE)
	await settle()
	assert(game.player.planner.visible and not game.player.input_enabled and not game.session.attempt_live)
	assert(game.level.design() == pending_design)
	key(KEY_ESCAPE)
	game.restart_run("restart")
	await settle()
	assert(game.player.planning and not game.session.attempt_live and game.elapsed == 0)
	key(KEY_ENTER)
	assert(not game.player.planning and not game.player.planner.visible and game.session.attempt_live)
	assert(game.player.run_review_unavailable_reason().is_empty())
	key(KEY_ESCAPE)
	attempts = game.attempts
	await paused_tab()
	assert(game.attempts == attempts and not game.player.planning)
	key(KEY_ESCAPE)
	assert(not game.paused and game.player.input_enabled)
	FileAccess.open(output.path_join("pause.json"),FileAccess.WRITE).store_string(JSON.stringify({"ok":true,"paused_tab":snapshots},"\t"))
	print("plan pause: Escape/Tab preserve focus, identity, design, position and recording SHA; survey resumes outside timing; menu restart cannot start its clock")
	game.request_quit(0)

extends SceneTree
## exercise the approved read-only gate through actual survey controls and a detached mode flag.
const HOST := preload("res://scripts/game.gd")
const PLAYER := preload("res://scripts/movement/plan_runner.gd")
class ModeLevel extends Node3D:
	var envelope_enabled := false
class ModeHost extends Node3D:
	var level: Node
var output := ""
var checks: Array[Dictionary] = []
var game: Node3D
func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"ok":ok,"check":label})
	if not ok: push_error(label)
func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
func state() -> Dictionary:
	var files := {}
	var folder := output.path_join("runs")
	if DirAccess.dir_exists_absolute(folder):
		for name: String in DirAccess.get_files_at(folder): files[name] = FileAccess.get_sha256(folder.path_join(name))
	return {"identity":game.motion_identity(),"design":game.level.design(),"motion":game.player.get_motion_state(),"attempts":game.attempts,"elapsed":game.elapsed,"pending":game.session.pending.duplicate(true),"recordings":files}
func probe(blocked: bool, label: String) -> void:
	var before := state()
	var reasons: Array[String] = []
	for i: int in 3:
		var reason: Variant = game.player.run_review_unavailable_reason()
		check(reason is String,label+": reason has the public string type")
		reasons.append(str(reason))
	check(reasons[0].is_empty() != blocked and reasons.all(func(s: String) -> bool:return s == reasons[0]),label)
	check(before == state(),label+": repeated reads preserve motor/design/identity/lifecycle/recordings")
func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	game = HOST.new()
	game.map_id = "plan-yard"
	game.motor = "server128"
	game.persist = false
	game.record_runs = true
	game.recordings_dir = output.path_join("runs")
	game.profile_path = output.path_join("absent.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection.cfg")
	game.seed_from_r15 = false
	game.set_window_title = false
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	probe(false,"committed normal startup remains available")
	key(KEY_TAB)
	check(game.player.planning and not game.session.attempt_live,"physical Tab opens outside-clock survey")
	probe(true,"pending survey blocks spatial/segment actions")
	check(game.player.run_review_unavailable_reason().contains("commit with Enter"),"survey gives actionable commit instruction")
	key(KEY_ENTER)
	check(not game.player.planning and game.session.attempt_live,"physical Enter commits normal run")
	probe(false,"committed normal plan becomes available again")
	var fake_host := ModeHost.new()
	var mode := ModeLevel.new()
	var old_level := Node3D.new()
	fake_host.level = mode
	var runner := PLAYER.new()
	fake_host.add_child(runner)
	check(runner.run_review_unavailable_reason().is_empty(),"detached normal mode is available")
	mode.envelope_enabled = true
	check(runner.run_review_unavailable_reason().contains("Turn it off in the survey"),"envelope flag blocks with actionable explanation")
	runner.planning = true
	check(runner.run_review_unavailable_reason().contains("commit with Enter"),"survey reason takes precedence while planning")
	runner.planning = false
	mode.envelope_enabled = false
	check(runner.run_review_unavailable_reason().is_empty(),"turning envelope flag off restores availability")
	fake_host.level = old_level
	check(runner.run_review_unavailable_reason().is_empty(),"old level without an envelope property remains available without script errors")
	fake_host.free()
	mode.free()
	old_level.free()
	game.request_quit(0)
	game.free()
	var ok := checks.all(func(row: Dictionary) -> bool:return row.ok)
	FileAccess.open(output.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"ok":ok,"checks":checks,"scope":"actual composed normal Plan host and physical Tab/Enter; detached typed mode plus old missing-property compatibility, not an envelope gameplay proof"},"\t"))
	print("PLAN REVIEW GUARD ",ok," checks=",checks.size())
	quit(0 if ok else 1)

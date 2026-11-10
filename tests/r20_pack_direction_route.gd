extends SceneTree
## source prototype: real R20 scene and Penstock checkpoint practice, with no world substitution.
const SCENE := preload("res://scenes/r20.tscn")
const DRIVER := preload("res://tools/r20-direction-driver.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
const KEYS := {"w": KEY_W, "a": KEY_A, "d": KEY_D, "space": KEY_SPACE}
var output := ""
var direction := "back"
var terminal := "bank"
var game: Node
var driver: RefCounted
var active := false
var tick := 0
var last: Dictionary = {}
var rows: Array = []
var delivered: Array = []
signal completed

class Hook extends Node:
	var controller: SceneTree
	var phase := ""
	func _physics_process(_delta: float) -> void:
		controller.call(phase)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		elif arg.begins_with("--direction="):
			direction = arg.trim_prefix("--direction=")
		elif arg.begins_with("--terminal="):
			terminal = arg.trim_prefix("--terminal=")
	run.call_deferred()

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	Engine.physics_ticks_per_second = 128
	RenderingServer.render_loop_enabled = false
	game = SCENE.instantiate()
	game.map_id = "practice"
	game.motor = "server128"
	game.persist = false
	game.seed_from_r15 = false
	game.record_runs = true
	game.recordings_dir = output.path_join("runs")
	game.profile_path = output.path_join("settings.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("share.cfg")
	game.set_window_title = false
	root.add_child(game)
	game.hud.dismiss_title()
	game.practise_stage(3)
	for i: int in 8:
		await physics_frame
	driver = DRIVER.new()
	driver.configure(game.player.global_position, game.player.yaw, game.player.tape_radians_per_count, direction, terminal)
	for item: Array in [["early", -1000], ["late", 1001]]:
		var hook := Hook.new()
		hook.controller = self
		hook.phase = item[0]
		hook.process_physics_priority = item[1]
		root.add_child(hook)
	active = true
	await completed
	for command: Array in driver.release():
		send(command)
	var snapshot: Dictionary = game.session.style.snapshot()
	var expected_kind := "direction_banked" if terminal == "bank" else "direction_lost"
	var transition: Dictionary = snapshot.direction.last
	var ok: bool = not transition.is_empty() and transition.kind == expected_kind and int(transition.hops) >= 6
	var expected_direction := "backward_bhop" if direction == "back" else "sideways_bhop"
	var unit := 160 if direction == "back" else 50
	ok = ok and transition.get("direction", "") == expected_direction and int(transition.get("pending", -1)) == unit * int(transition.get("hops", 0)) * (int(transition.get("hops", 0)) - 1) / 2
	ok = ok and game.respawn_count == 0 and game.map_id == "practice" and game.practice_stage == 3 and not game.clean_eligible
	game.request_quit(0 if ok else 1)
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "direction": direction, "terminal": terminal,
		"ticks": tick, "phase": driver.phase, "snapshot": snapshot, "rows": rows, "inputs": delivered,
		"seals": game.session.sealed, "map": game.map_id, "geometry": game.course_geometry,
		"scope": "source-only input feasibility on the unchanged authored Penstock straight; no packed/native claim"}, "", false, true))
	file.close()
	print("r20 Penstock direction ", direction, " ", terminal, " ", ok, " ticks=", tick)

func send(command: Array) -> void:
	delivered.append({"tick": tick, "command": command})
	if command[0] == "mouse":
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(float(command[1]), 0.0)
		event.screen_relative = event.relative
		Input.parse_input_event(event)
	else:
		var event := InputEventKey.new()
		event.keycode = KEYS[command[0]]
		event.physical_keycode = event.keycode
		event.pressed = bool(command[1])
		Input.parse_input_event(event)
	Input.flush_buffered_events()

func early() -> void:
	if not active:
		return
	tick += 1
	for command: Array in driver.commands(tick, last):
		send(command)

func late() -> void:
	if not active:
		return
	var sample: Dictionary = game.session.last_sample
	var snap: Dictionary = game.session.style.snapshot()
	last = {"p": game.player.global_position, "v": game.player.velocity,
		"speed": Vector2(sample.actual_v.x, sample.actual_v.z).length() / 0.0254,
		"yaw": game.player.yaw, "g": game.player.is_grounded(), "direction": snap.direction}
	rows.append(READER.json_safe(last))
	driver.observe(last)
	if driver.done or tick >= 2400 or game.respawn_count > 0:
		active = false
		completed.emit()

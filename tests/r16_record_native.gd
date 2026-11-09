extends SceneTree
## p / native ghost sample, run by tests/r16_record_native.py on the private display with the movie
## writer. the real R15 host on the labelled loop fixture records a clean finish through key and
## mouse events, then R and a second attempt with the ghost of that finish: the player crouch-walks
## (slower) so the ghost pulls ahead in view, then stands and follows. no clean-run or feel claim:
## this is a visual check of the ghost body, trail and eye fade from the player's own camera.
## godot --path . --script res://tests/r16_record_native.gd -- --out=DIR

const RECORDER := preload("res://scripts/r16_run_recorder.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
const GHOST := preload("res://scripts/r16_ghost.gd")
const ADAPTER := preload("res://tests/r16_record_adapter.gd")
const MAIN := preload("res://scripts/r15_main.gd")
const FIXTURE := preload("res://tests/r15_loop_fixture_level.gd")

var out_dir := ""
var game: Node
var adapter: Node
var samples: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_main.call_deferred()

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse(dx: float, dy: float = 0.0) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.screen_relative = Vector2(dx, dy)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func play(schedule: Dictionary, length: int, until_finish: bool, ghost: Node3D = null) -> void:
	for t: int in length:
		for step: Array in schedule.get(t, []):
			if step[0] == "k":
				key(step[1], step[2])
			else:
				mouse(step[1], step[2])
		await physics_frame
		if ghost != null and t % 32 == 0:
			var eye: Camera3D = root.get_viewport().get_camera_3d()
			var pose: Dictionary = ghost.call("pose_at", float(game.elapsed))
			samples.append({"tick": t, "elapsed": float(game.elapsed), "fade": ghost.call("fade"), "body_visible": (ghost.get_node("Body") as Node3D).visible,
				"ghost_feet": pose.get("feet"), "player_feet": game.player.global_position, "eye": eye.global_position if eye != null else null})
		if until_finish and bool(game.finished):
			return

func _main() -> void:
	FIXTURE.params = {}
	game = MAIN.new()
	game.set("level_script", FIXTURE)
	root.add_child(game)
	adapter = ADAPTER.new(game, out_dir.path_join("runs"))
	root.add_child(adapter)
	for i: int in 16:
		await physics_frame
	await play({0: [["k", KEY_W, true]], 60: [["m", 40.0, 0.0]], 61: [["m", -40.0, 3.0]], 120: [["k", KEY_SPACE, true]], 124: [["k", KEY_SPACE, false], ["k", KEY_CTRL, true]],
		160: [["k", KEY_CTRL, false]], 200: [["m", 25.0, -3.0], ["m", -25.0, 0.0]]}, 3000, true)
	key(KEY_W, false)
	await physics_frame
	var clean: Dictionary = (adapter.results as Array).back()
	var ghost: Node3D = GHOST.new()
	game.add_child(ghost)
	var loaded: Dictionary = ghost.call("load_run", str(clean.path), adapter.call("identity"))
	adapter.set("ghost", ghost)
	# a beat at the start with both standing on the spawn, then crouch-walk, then stand and run.
	await play({0: [["k", KEY_R, true]], 1: [["k", KEY_R, false]], 40: [["k", KEY_CTRL, true], ["k", KEY_W, true]], 40 + 128 * 3: [["k", KEY_CTRL, false]],
		40 + 128 * 3 + 20: [["m", 30.0, 0.0]], 40 + 128 * 3 + 60: [["m", -30.0, 0.0]]}, 128 * 12, true, ghost)
	key(KEY_W, false)
	await physics_frame
	adapter.call("close", "quit")
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(READER.json_safe({"ghost_load": loaded, "clean": clean, "samples": samples, "results": adapter.results,
		"finished": game.finished, "finish_kind": game.finish_kind}), " "))
	file.close()
	print("r16 native ghost: loaded=%s samples=%d" % [loaded.get("ok"), samples.size()])
	quit(0)

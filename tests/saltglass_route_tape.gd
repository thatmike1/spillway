extends SceneTree
## input-only west-fin observer; emits a reproducible camera tape without pose writes.
const HOST := preload("res://scripts/game.gd")
var game: Node3D
var tape: Array = []
var ticks := 0
var done := false
var held := ""
var output := "/tmp/r22-05/west-tape.json"
var samples: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	start.call_deferred()

func start() -> void:
	game = HOST.new()
	game.map_id = "saltglass"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	root.add_child(game)
	game.set_paused(false)

func _physics_process(_delta: float) -> bool:
	if game == null or done:
		return false
	ticks += 1
	var runner: Node3D = game.player
	var p := runner.global_position
	var action := "move_forward" if p.z > 0 else "move_right"
	if action != held:
		if not held.is_empty():
			key(held, false)
		key(action, true)
		held = action
	if p.z <= 0 and p.z > -168:
		var speed: float = maxf(-runner.velocity.z, 0.5)
		var lead := clampf(asin(clampf(0.75 / speed, 0, 1)) + 0.08 * (p.y - 8.0) + 0.03 * runner.velocity.y, 0.0, 0.6)
		var dx: float = -angle_difference(runner.yaw, lead) / runner.mouse_sensitivity
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(dx, 0)
		event.screen_relative = event.relative
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		tape.append({"time": ticks / 128.0, "mouse": [dx, 0]})
	if ticks % 64 == 0:
		samples.append({"time": ticks / 128.0, "position": [p.x, p.y, p.z], "speed": runner.velocity.length()})
	if ticks >= 128 * 14 or p.z < -177 or game.respawn_count > 0:
		done = true
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(tape))
		FileAccess.open(output + ".samples.json", FileAccess.WRITE).store_string(JSON.stringify(samples))
		print("saltglass input tape: ", output, " final=", p, " respawns=", game.respawn_count)
		game.request_quit(0)
	return false

func key(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	tape.append({"time": ticks / 128.0, "action": action, "pressed": pressed})

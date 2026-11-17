extends SceneTree
## approach every collection apron through normal f2 inputs; no body placement after spawn.
const HOST := preload("res://scripts/game.gd")
const POINTS := [
	[Vector3(0, 2, -8), -1], [Vector3(10, 2, -8), 0], [Vector3(0, 2, -8), -1],
	[Vector3(0, 2, -30), -1], [Vector3(-5, 2, -54.7), -1], [Vector3(-10, 2, -54.7), 1],
	[Vector3(-5, 2, -54.7), -1], [Vector3(0, 2, -70), -1], [Vector3(0, 2, -84), -1],
	[Vector3(10, 2, -84), 2], [Vector3(0, 2, -84), -1], [Vector3(0, 2, -130), -1]]
var game: Node
var frames := 0
var point := 0
var steering := false
var visited := 0
var travel := 0.0
var previous := Vector3.ZERO
var active_post := -1

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	game = HOST.new()
	game.map_id = "mail-run"
	game.persist = false
	game.record_runs = false
	root.add_child(game)
	previous = game.player.global_position

func _physics_process(_dt: float) -> bool:
	if game == null or game.player == null:
		return false
	frames += 1
	var runner: CharacterBody3D = game.player
	var flight: RefCounted = runner.mail_flight
	travel += Vector2(runner.global_position.x - previous.x, runner.global_position.z - previous.z).length()
	previous = runner.global_position
	if game.respawn_count != 0:
		push_error("collection court route fell off its supports point=" + str(point))
		quit(1)
	if steering:
		if flight.active:
			var target: Vector3 = game.level.mailboxes[active_post].position
			var desired: Vector3 = (target - flight.position).normalized()
			var right: Vector3 = flight.direction.cross(Vector3.UP).normalized()
			var correction: Vector3 = desired - flight.direction
			_mouse(runner, Vector2(correction.dot(right), -correction.y) * 20.0)
		elif flight.result == "hit":
			visited += 1
			print("MAIL COURT post=%d flight=%.3fs body=%s" % [active_post + 1, flight.age, runner.global_position])
			steering = false
			point += 1
		elif not flight.result.is_empty():
			push_error("court delivery failed post=%d reason=%s" % [active_post + 1, flight.result])
			quit(1)
	elif point < POINTS.size():
		var target: Vector3 = POINTS[point][0]
		var delta: Vector3 = target - runner.global_position
		delta.y = 0
		if delta.length() < 0.6:
			active_post = int(POINTS[point][1])
			if active_post >= 0:
				Input.action_release("move_forward")
				var aim: Vector3 = (game.level.mailboxes[active_post].position - (runner.global_position + Vector3.UP * runner._eye_u * runner.U)).normalized()
				_look(runner, atan2(-aim.x, -aim.z), asin(aim.y) + 0.03)
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = true
				runner._unhandled_input(event)
				steering = true
			else:
				point += 1
		else:
			_look(runner, atan2(-delta.x, -delta.z), 0)
			Input.action_press("move_forward")
	if game.finished:
		if visited != 3 or flight.delivered.size() != 3 or not game.clean_eligible:
			push_error("court route finished without three clean deliveries")
			quit(1)
		else:
			print("MAIL COURTS PASS: 3/3, clean finish, no falls; travel=%.2fm clock=%.3fs" % [travel, game.elapsed])
			Input.action_release("move_forward")
			game.queue_free()
			quit()
	if frames > 20000:
		push_error("court route timeout point=%d position=%s" % [point, runner.global_position])
		quit(1)
	return false

func _look(runner: CharacterBody3D, yaw: float, pitch: float) -> void:
	_mouse(runner, Vector2((runner.yaw - yaw) / runner.tape_radians_per_count, (runner.pitch - pitch) / runner.tape_radians_per_count))

func _mouse(runner: CharacterBody3D, counts: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = counts
	motion.screen_relative = counts
	runner._unhandled_input(motion)

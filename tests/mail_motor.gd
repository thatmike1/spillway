extends SceneTree
## earned high-speed inputs, not a velocity seed; no claim of human aiming skill.
const HOST := preload("res://scripts/game.gd")
const MOTION := preload("res://scripts/movement/source_motion.gd")
var game: Node
var frames := 0
var phase := "accelerate"
var body_mode := "hold"
var delivery := false
var kept_velocity := Vector3.ZERO
var kept_position := Vector3.ZERO
var flight_ticks := 0
var resume_ticks := 0
var top_u := 0.0

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	game = HOST.new()
	game.map_registry = preload("res://scripts/maps/r22_catalog.gd").make()
	game.map_id = "mail-run"
	game.persist = false
	game.record_runs = false
	root.add_child(game)
	game.player.set_mail_goal("optional")
	Input.action_press("move_forward")

func _physics_process(_dt: float) -> bool:
	if game == null or game.player == null:
		return false
	frames += 1
	var runner: CharacterBody3D = game.player
	var flight: RefCounted = runner.mail_flight
	top_u = maxf(top_u, runner.control_speed() / runner.U)
	if frames == 102:
		Input.action_press("jump")
	if phase == "accelerate":
		if frames > 102:
			_strafe(runner)
		if top_u >= 600.0 and not runner.is_grounded() and (not delivery or runner.global_position.z < -65):
			_release_horizontal()
			if delivery:
				var aim: Vector3 = (game.level.mailboxes[2].position - (runner.global_position + Vector3.UP * runner._eye_u * runner.U)).normalized()
				_mouse(runner, atan2(-aim.x, -aim.z), asin(aim.y) + 0.03)
			else:
				_mouse(runner, 0.0, 1.1)
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			runner._unhandled_input(click)
			kept_velocity = runner.velocity
			kept_position = runner.global_position
			phase = "launch"
	elif phase == "launch" and flight.active:
		phase = "flight"
	elif phase == "flight":
		flight_ticks += 1
		if delivery and flight.active:
			var desired: Vector3 = (game.level.mailboxes[2].position - flight.position).normalized()
			var right: Vector3 = flight.direction.cross(Vector3.UP).normalized()
			var error: Vector3 = desired - flight.direction
			var event := InputEventMouseMotion.new()
			event.relative = Vector2(error.dot(right), -error.y) * 20
			event.screen_relative = event.relative
			runner._unhandled_input(event)
		var a := Vector2(runner.velocity.x, runner.velocity.z)
		var b := Vector2(kept_velocity.x, kept_velocity.z)
		if a.distance_to(b) > 0.0001:
			push_error("mail altered earned horizontal velocity during " + body_mode)
			quit(1)
		if body_mode == "hold" and (runner.global_position != kept_position or runner.velocity != kept_velocity):
			push_error("held high-speed body changed")
			quit(1)
		if not flight.active:
			if flight.result != ("hit" if delivery else "timeout") or flight.misses != (0 if delivery else 1):
				push_error("high-speed flight did not produce its intended hit/miss")
				quit(1)
			if body_mode == "run" and runner.global_position.distance_to(kept_position) < 15:
				push_error("running body did not travel during steering")
				quit(1)
			print("MAIL HIGH SPEED body=%s result=%s earned=%.2fu/s flight_ticks=%d held_travel=%.3fm" % [body_mode, flight.result, b.length() / runner.U, flight_ticks, runner.global_position.distance_to(kept_position)])
			phase = "resume"
	elif phase == "resume":
		_strafe(runner)
		resume_ticks += 1
		if resume_ticks == 48:
			if runner.control_speed() / runner.U < 590 or game.session.actual_v_mismatches != 0:
				push_error("high-speed resume lost the hop or recording continuity")
				quit(1)
			if body_mode == "hold" or not delivery:
				if body_mode == "run":
					delivery = true
					body_mode = "hold"
				else:
					body_mode = "run"
				_release_horizontal()
				Input.action_release("jump")
				runner.set_mail_body(body_mode)
				frames = 0
				phase = "accelerate"
				flight_ticks = 0
				resume_ticks = 0
				top_u = 0
				Input.action_press("move_forward")
			else:
				_release_horizontal()
				Input.action_release("jump")
				_finish()
	if frames > 10000:
		push_error("high-speed tape timed out phase=" + phase + " top=" + str(top_u))
		quit(1)
	return false

func _strafe(runner: CharacterBody3D) -> void:
	Input.action_release("move_forward")
	Input.action_press("move_right")
	var velocity := Vector3(runner.velocity.x, 0, runner.velocity.z)
	if velocity.length_squared() < 0.01:
		return
	var desired_x: float = -runner.global_position.x * 1.5
	var angle := PI * 0.5 if runner.velocity.x > desired_x else -PI * 0.5
	var wish := velocity.normalized().rotated(Vector3.UP, angle)
	_mouse(runner, MOTION.yaw_for_side(wish, 1), 0)

func _mouse(runner: CharacterBody3D, yaw: float, pitch: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2((runner.yaw - yaw) / runner.tape_radians_per_count, (runner.pitch - pitch) / runner.tape_radians_per_count)
	event.screen_relative = event.relative
	runner._unhandled_input(event)

func _release_horizontal() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(action)

func _finish() -> void:
	var retired := game
	game = null
	retired.queue_free()
	await process_frame
	await process_frame
	quit()

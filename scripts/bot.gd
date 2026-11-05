extends Node
## a scripted runner that plays through ordinary inputs only: it holds W, sends
## mouse-motion events to steer and look, and presses Space at takeoff points.
## it never moves the player directly. Used by the traversal test and to
## record player-view footage with Movie Maker.

var main: Node
var player: CharacterBody3D
var level: Node3D
var quit_at_end: bool = false
var index: int = 0
var time: float = 0.0
var finished_at: float = -1.0
var jumps: int = 0
var log_lines: PackedStringArray = PackedStringArray()

var _turn_wait: float = 0
var _crouch_sent: bool = false
var _trace: FileAccess
var _look_phase: float = 0.0
var _jump_release: int = 0
var _sensitivity: float = 0.0022


func attach(owner_main: Node, runner: CharacterBody3D, route: Node3D, quit: bool) -> void:
	main = owner_main
	player = runner
	level = route
	quit_at_end = quit
	if OS.get_cmdline_user_args().has("--detour"):
		level.bot_path[6].point = Vector3(-5, -2.1, -112)
		level.bot_path[7].point = Vector3(-5, -2.1, -128)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--trace-run="):
			_trace = FileAccess.open(arg.trim_prefix("--trace-run="), FileAccess.WRITE)
			_trace.store_line("time,x,y,z,speed,move,waypoint,up_x,up_y,up_z,travel_speed,fov_extra,streak,wind,stride,landing_kind,fall_height")
	process_physics_priority = -100
	process_mode = Node.PROCESS_MODE_PAUSABLE


## starts from the first waypoint ahead of the player, for runs that begin at a checkpoint.
func skip_to_nearest() -> void:
	var path: Array = level.get("bot_path")
	index = 0
	while index < path.size() and Vector3(path[index]["point"]).z > player.global_position.z - 1.0:
		index += 1


func _physics_process(delta: float) -> void:
	if player == null:
		return
	time += delta
	if _trace != null:
		_trace.store_line("%.5f,%.5f,%.5f,%.5f,%.5f,%d,%d,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%s,%.5f" % [time, player.position.x, player.position.y, player.position.z, player.get_speed(), player.move, index, player.up_direction.x, player.up_direction.y, player.up_direction.z, player.get_presentation_speed(), player._fov_extra, player.sprint_effect, main.audio._wind_level, player.get_stride(), player.landing.kind, player.landing.height])
	if time > 130:
		print("bot timeout at ", player.position, " waypoint ", index)
		get_tree().quit(1)
		return
	_sensitivity = float(player.get("mouse_sensitivity"))
	if _jump_release > 0:
		_jump_release -= 1
		if _jump_release == 0:
			_send_action("jump", false)
	if bool(main.get("finished")):
		Input.action_release("move_forward")
		if finished_at < 0.0:
			finished_at = time
			for line: String in log_lines:
				print(line)
			print("route finished at ", main.elapsed, " seconds; respawns ", main.respawn_count)
			if _trace != null:
				_trace.flush()
		_turn_toward(Vector3(0, 25, -60), delta, 1.2)
		if quit_at_end and time - finished_at > 2.5:
			main.call("request_quit")
		return
	var path: Array = level.get("bot_path")
	if index >= path.size():
		return
	var step: Dictionary = path[index]
	var target: Vector3 = step["point"]
	var up: Vector3 = player.up_direction
	var offset: Vector3 = target - player.global_position
	var flat: Vector3 = offset.slide(up)
	if step.get("look_around", false) and _look_phase < 4.2:
		# stand and look around first: left, right, up at the tower, then run
		_look_phase += delta
		Input.action_release("move_forward")
		var yaw_rate: float = 0.0
		var pitch_rate: float = 0.0
		if _look_phase < 1.0:
			yaw_rate = 1.1
		elif _look_phase < 2.6:
			yaw_rate = -1.3
		elif _look_phase < 3.3:
			yaw_rate = 0.9
			pitch_rate = 0.55
		else:
			pitch_rate = -0.45
		_mouse(Vector2(-yaw_rate * delta / _sensitivity, -pitch_rate * delta / _sensitivity))
		return
	if step.get("turn", false) and (flat.length() < 1.5 or _turn_wait > 0):
		Input.action_release("move_forward")
		if _turn_wait == 0:
			_send_action("turn", true)
		_turn_wait += delta
		if _turn_wait > 1.10:
			_send_action("turn", false)
			_advance("180 turn")
		return
	Input.action_press("move_forward", .55 if step.get("slow", false) else 1.0)
	if step.get("slide", false):
		Input.action_press("crouch")
	elif step.get("roll", false):
		if _crouch_sent and player.move == player.Move.ROLL:
			Input.action_release("crouch")
		if player.velocity.dot(up) < -2 and player.position.y - target.y < 1.0 and not _crouch_sent:
			Input.action_press("crouch")
			_crouch_sent = true
		elif not _crouch_sent:
			Input.action_release("crouch")
	else:
		Input.action_release("crouch")
	_turn_toward(target, delta, 1.0)
	var look_down: float = deg_to_rad(15 if player.move == player.Move.GRAB else -8.0)
	if step.get("jump", false):
		look_down = deg_to_rad(-4.0)
	_aim_pitch(look_down, delta)
	var reach: float = 1.4
	if step.get("jump", false) or step.get("wall_jump", false):
		var forward: Vector3 = (-player.global_basis.z).slide(up).normalized()
		var ahead: float = offset.dot(forward)
		if ahead < .35 and (bool(player.get("grounded")) or (step.get("wall_jump", false) and player.move == player.Move.WALLRUN)):
			_send_action("jump", true)
			_jump_release = 6
			jumps += 1
			_advance("jump")
		elif ahead < -1.0:
			_advance("missed takeoff")
		return
	if flat.length() < reach:
		_advance("reached")


func _advance(reason: String) -> void:
	log_lines.append("t=%.2f waypoint %d %s at %s" % [time, index, reason, player.global_position])
	index += 1
	_turn_wait = 0
	_crouch_sent = false


func _turn_toward(target: Vector3, delta: float, gain: float) -> void:
	var up: Vector3 = player.up_direction
	var want: Vector3 = (target - player.global_position).slide(up)
	if want.length_squared() < 0.01:
		return
	var forward: Vector3 = (-player.global_basis.z).slide(up).normalized()
	var angle: float = forward.signed_angle_to(want.normalized(), up)
	var turn: float = clampf(angle * 7.0 * gain * delta, -5.0 * delta, 5.0 * delta)
	_mouse(Vector2(-turn / _sensitivity, 0.0))


func _aim_pitch(pitch: float, delta: float) -> void:
	var current: float = float(player.call("get_pitch"))
	var change: float = clampf((pitch - current) * 5.0 * delta, -2.0 * delta, 2.0 * delta)
	_mouse(Vector2(0.0, -change / _sensitivity))


func _mouse(relative: Vector2) -> void:
	if relative.length_squared() < 0.000001:
		return
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = relative
	motion.screen_relative = relative
	Input.parse_input_event(motion)


func _send_action(action: String, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	# flush injected actions before the next physics substep, including 10fps captures.
	Input.flush_buffered_events()

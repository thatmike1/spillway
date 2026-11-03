extends Node
## A scripted runner that plays through ordinary inputs only: it holds W, sends
## mouse-motion events to steer and look, and presses Space at takeoff points.
## It never moves the player directly. Used by the traversal test and to
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

var _look_phase: float = 0.0
var _waiting: float = 0.0
var _jump_release: int = 0
var _sensitivity: float = 0.0022


func attach(owner_main: Node, runner: CharacterBody3D, route: Node3D, quit: bool) -> void:
	main = owner_main
	player = runner
	level = route
	quit_at_end = quit
	process_physics_priority = -100
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Starts from the first waypoint ahead of the player, for runs that begin at a checkpoint.
func skip_to_nearest() -> void:
	var path: Array = level.get("bot_path")
	index = 0
	while index < path.size() and Vector3(path[index]["point"]).z > player.global_position.z - 1.0:
		index += 1


func _physics_process(delta: float) -> void:
	if player == null:
		return
	time += delta
	_sensitivity = float(player.get("mouse_sensitivity"))
	if _jump_release > 0:
		_jump_release -= 1
		if _jump_release == 0:
			_send_action("jump", false)
	if bool(main.get("finished")):
		Input.action_release("move_forward")
		if finished_at < 0.0:
			finished_at = time
		_turn_toward(Vector3(0, 25, -60), delta, 1.2)
		if quit_at_end and time - finished_at > 2.5:
			get_tree().quit(0)
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
	if step.get("wait_fold", false):
		var fold: Node = level.get("fold")
		if not bool(fold.call("is_done")) and flat.length() < 6.0:
			Input.action_release("move_forward")
			_waiting += delta
			_aim_pitch(deg_to_rad(12.0), delta)
			_turn_toward(Vector3(0, 0, -80), delta, 1.0)
			return
	Input.action_press("move_forward")
	_turn_toward(target, delta, 1.0)
	var look_down: float = deg_to_rad(-8.0)
	if step.get("jump", false):
		look_down = deg_to_rad(-4.0)
	_aim_pitch(look_down, delta)
	var reach: float = 1.4
	if step.get("jump", false):
		var forward: Vector3 = (-player.global_basis.z).slide(up).normalized()
		var ahead: float = offset.dot(forward)
		if ahead < 0.35 and bool(player.get("grounded")):
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

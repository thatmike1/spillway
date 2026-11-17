extends SceneTree
## deterministic input tape through the actual host and inherited f2 runner.
const HOST := preload("res://scripts/game.gd")
const MAP := preload("res://scripts/maps/mail_run.gd")
var game: Node
var frames := 0
var throws := 0
var variant := 0
var failures: Array[String] = []
var held := false
var hold_position := Vector3.ZERO
var hold_velocity := Vector3.ZERO
var identities: Array[String] = []
var events: Array = []
var tape_out := ""

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mail-tape-out="):
			tape_out = arg.trim_prefix("--mail-tape-out=")
	game = HOST.new()
	game.map_registry = preload("res://scripts/maps/catalog.gd").make()
	game.map_registry.catalog[MAP.MAP_ID] = MAP.MAP_ENTRY
	if not MAP.MAP_ID in game.map_registry.order:
		game.map_registry.order.append(MAP.MAP_ID)
	game.map_registry.default_chain = [MAP.MAP_ID]
	game.record_runs = false
	game.persist = false
	game.map_id = MAP.MAP_ID
	root.add_child(game)
	game.player.view_mode = "envelope"
	assert(game.level.checkpoints.size() == 4)
	assert(game.level.routes.advanced.size() > game.level.routes.basic.size())
	Input.action_press("move_forward")
	events = [{"time": 0.0, "action": "move_forward", "pressed": true}, {"time": 0.8, "action": "jump", "pressed": true}]

func _physics_process(_dt: float) -> bool:
	if game == null or game.player == null:
		return false
	frames += 1
	if frames == 102:
		Input.action_press("jump")
	var runner: CharacterBody3D = game.player
	var flight: RefCounted = runner.mail_flight
	if not flight.active:
		_mouse(runner, Vector2(runner.yaw / runner.tape_radians_per_count, runner.pitch / runner.tape_radians_per_count))
	if flight.active:
		if held and (runner.global_position != hold_position or runner.velocity != hold_velocity):
			failures.append("body changed during hold")
			quit(1)
		if not held:
			hold_position = runner.global_position
			hold_velocity = runner.velocity
		held = true
	else:
		held = false
	if flight.active:
		var target: Vector3 = game.level.mailboxes[throws - 1].position
		var desired: Vector3 = (target - flight.position).normalized()
		var right: Vector3 = flight.direction.cross(Vector3.UP).normalized()
		var correction: Vector3 = desired - flight.direction
		_mouse(runner, Vector2(correction.dot(right), -correction.y) * 20.0)
	if throws < 3 and not flight.active:
		var target: Vector3 = game.level.mailboxes[throws].position
		if runner.global_position.z < target.z + 14:
			var aim: Vector3 = (target - (runner.global_position + Vector3.UP * 1.6)).normalized()
			var desired_yaw := atan2(-aim.x, -aim.z)
			var desired_pitch := asin(aim.y) + 0.03
			_mouse(runner, Vector2((runner.yaw - desired_yaw) / runner.tape_radians_per_count, (runner.pitch - desired_pitch) / runner.tape_radians_per_count))
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			runner._unhandled_input(click)
			events.append({"time": frames / 128.0, "button": 1, "pressed": true})
			events.append({"time": (frames + 1) / 128.0, "button": 1, "pressed": false})
			throws += 1
	if game.finished:
		identities.append(game.course_key)
		if not tape_out.is_empty() and variant < 2:
			DirAccess.make_dir_recursive_absolute(tape_out)
			var file := FileAccess.open(tape_out.path_join(runner.view_mode + ".json"), FileAccess.WRITE)
			file.store_string(JSON.stringify(events))
		if game.session.actual_v_mismatches != 0:
			failures.append("recorded actual velocity mismatch")
		if flight.delivered.size() != (0 if variant == 2 else 3):
			failures.append("view %s delivered %d" % [runner.view_mode, flight.delivered.size()])
		print("MAIL TAPE view=%s delivered=%d misses=%d finished=%s ticks=%d" % [runner.view_mode, flight.delivered.size(), flight.misses, game.finished, frames])
		if variant == 0:
			variant = 1
			frames = 0
			throws = 0
			Input.action_release("jump")
			runner.set_mail_view("body")
			events = [{"time": 0.0, "action": "move_forward", "pressed": true}, {"time": 0.8, "action": "jump", "pressed": true}]
		elif variant == 1:
			if identities[0] == identities[1]:
				failures.append("view identities collided")
			variant = 2
			frames = 0
			throws = 3
			Input.action_release("jump")
			game.restart_run()
		else:
			Input.action_release("move_forward")
			Input.action_release("jump")
			for failure: String in failures:
				push_error(failure)
			game.queue_free()
			quit(0 if failures.is_empty() else 1)
	if frames > 12000:
		push_error("mail tape timed out: %s position=%s velocity=%s input=%s paused=%s throws=%d delivered=%s yaw=%s" % [failures, runner.global_position, runner.velocity, runner.input_enabled, game.paused, throws, flight.delivered, runner.yaw])
		quit(1)
	return false

func _mouse(runner: Node, counts: Vector2) -> void:
	if counts.length_squared() < 0.000001:
		return
	var motion := InputEventMouseMotion.new()
	motion.relative = counts
	motion.screen_relative = counts
	runner._unhandled_input(motion)
	events.append({"time": frames / 128.0, "mouse": [counts.x, counts.y]})

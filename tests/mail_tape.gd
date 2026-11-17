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
var moving_flight_ticks := 0
var combo_checked := false
var transitioning := true
var observed: Array = []

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
	game.set_paused(true)
	game.player.set_mail_goal("optional")
	assert(game.paused)
	game.player.set_mail_goal("deliver")
	assert(game.paused)
	game.set_paused(false)
	assert(game.level.checkpoints.size() == 4)
	assert(game.level.routes.advanced.size() > game.level.routes.basic.size())
	_begin_case(0)

func _begin_case(next: int) -> void:
	variant = next
	var runner: Node = game.player
	runner.set_mail_body("run" if next >= 4 else "hold")
	runner.set_mail_view("body" if next in [1, 2, 3, 5] else "envelope")
	runner.set_mail_goal("optional" if next in [2, 3] else "deliver")
	game.restart_run("mail_tape")
	frames = 0
	throws = 3 if next == 2 else 0
	held = false
	moving_flight_ticks = 0
	combo_checked = false
	_native_action("move_forward", true)
	_native_action("jump", false)
	events = [{"time": 0.0, "action": "move_forward", "pressed": true}, {"time": 0.0, "action": "jump", "pressed": false}]
	assert(not game.level.is_finish_at(game.level.finish_position) or next in [2, 3])
	observed = []
	transitioning = false

func _physics_process(_dt: float) -> bool:
	if transitioning or game == null or game.player == null:
		return false
	frames += 1
	if frames == 102:
		_action("jump", true)
	var runner: CharacterBody3D = game.player
	var flight: RefCounted = runner.mail_flight
	observed.append({"tick": frames - 1, "position": _v(runner.global_position), "velocity": _v(runner.velocity), "delivered": flight.delivered.keys(), "active": flight.active, "finished": game.finished})
	var delivery_phase := variant in [0, 1, 4, 5]
	if runner.body_mode == "run":
		if flight.active:
			_action("move_forward", false)
		else:
			_action("move_forward", true)
	if not flight.active:
		_mouse(runner, Vector2(runner.yaw / runner.tape_radians_per_count, runner.pitch / runner.tape_radians_per_count))
	if flight.active:
		if held and runner.body_mode == "hold" and (runner.global_position != hold_position or runner.velocity != hold_velocity):
			failures.append("body changed during hold")
			quit(1)
		if held and runner.body_mode == "run" and runner.global_position != hold_position:
			moving_flight_ticks += 1
		if not held:
			hold_position = runner.global_position
			hold_velocity = runner.velocity
		held = true
	else:
		held = false
	if flight.active and delivery_phase:
		var target: Vector3 = game.level.mailboxes[throws - 1].position
		var desired: Vector3 = (target - flight.position).normalized()
		var right: Vector3 = flight.direction.cross(Vector3.UP).normalized()
		var correction: Vector3 = desired - flight.direction
		_mouse(runner, Vector2(correction.dot(right), -correction.y) * 20.0)
	if variant == 3 and flight.result == "timeout" and not runner._style_suspended and not combo_checked:
		combo_checked = true
		if game.session.style.combo != 1:
			failures.append("held delivery broke a seeded combo")
	if throws < 3 and not flight.active:
		var target: Vector3 = game.level.mailboxes[throws].position
		if (runner.global_position.z < target.z - 7 if throws == 1 else runner.global_position.z < target.z + 14):
			var aim: Vector3 = (target - (runner.global_position + Vector3.UP * 1.6)).normalized()
			var desired_yaw := atan2(-aim.x, -aim.z)
			var desired_pitch := 1.0 if variant == 3 else asin(aim.y) + 0.03
			_mouse(runner, Vector2((runner.yaw - desired_yaw) / runner.tape_radians_per_count, (runner.pitch - desired_pitch) / runner.tape_radians_per_count))
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			if runner.body_mode == "run":
				_action("move_forward", false)
			if variant == 3:
				game.session.style.combo = 1
				game.session.style._last_combo_time = game.session.style._time
			Input.parse_input_event(click)
			Input.flush_buffered_events()
			events.append({"time": (frames - 1) / 128.0, "button": 1, "pressed": true})
			events.append({"time": frames / 128.0, "button": 1, "pressed": false})
			throws = 3 if variant == 3 else throws + 1
	if game.finished:
		if variant == 3:
			if game.course_key != identities[2]:
				failures.append("miss changed the optional timing category")
		elif game.course_key in identities:
			failures.append("different mail settings share a timing category")
		identities.append(game.course_key)
		if not game.clean_eligible or game.respawn_count != 0:
			failures.append("mail tape finish was not clean")
		if not tape_out.is_empty() and delivery_phase:
			DirAccess.make_dir_recursive_absolute(tape_out)
			var file := FileAccess.open(tape_out.path_join(runner.body_mode + "-" + runner.view_mode + ".json"), FileAccess.WRITE)
			var setup: Array = []
			if runner.body_mode == "run":
				setup.append({"time": 0.0, "key": "B", "pressed": true})
				setup.append({"time": 0.0, "key": "B", "pressed": false})
			if runner.view_mode == "body":
				setup.append({"time": 0.0, "key": "V", "pressed": true})
				setup.append({"time": 0.0, "key": "V", "pressed": false})
			setup.append_array(events)
			setup.append({"time": frames / 128.0, "action": "move_forward", "pressed": false})
			setup.append({"time": frames / 128.0, "action": "jump", "pressed": false})
			file.store_string(JSON.stringify(setup))
			var expected := FileAccess.open(tape_out.path_join(runner.body_mode + "-" + runner.view_mode + ".expected.json"), FileAccess.WRITE)
			expected.store_string(JSON.stringify({"course_key": game.course_key, "observations": observed}))
		if game.session.actual_v_mismatches != 0:
			failures.append("recorded actual velocity mismatch")
		if variant == 3 and flight.misses != 1:
			failures.append("miss did not cost exactly one miss")
		if flight.delivered.size() != (3 if delivery_phase else 0):
			failures.append("view %s delivered %d" % [runner.view_mode, flight.delivered.size()])
		print("MAIL TAPE body=%s view=%s goal=%s delivered=%d misses=%d finished=%s ticks=%d" % [runner.body_mode, runner.view_mode, runner.goal_mode, flight.delivered.size(), flight.misses, game.finished, frames])
		if variant < 5:
			if variant == 1 and identities[0] == identities[1]:
				failures.append("view identities collided")
			if variant == 3 and not combo_checked:
				failures.append("missing post-hold combo check")
			if variant == 4 and (identities[4] == identities[0] or moving_flight_ticks == 0):
				failures.append("running body missing distinct identity or movement")
			transitioning = true
			game.set_paused(true)
			_begin_case.call_deferred(variant + 1)
		else:
			var completed: Dictionary = flight.delivered.duplicate()
			runner.reset_to(Transform3D(Basis.IDENTITY, game.level.finish_position + Vector3.UP * 0.04))
			if flight.delivered != completed:
				failures.append("post-finish rescue cleared completed mail")
			game.practise_stage(3)
			if game.clean_eligible or not runner.delivery_goal_met() or not game.level.is_finish_at(game.level.finish_position):
				failures.append("last checkpoint practice inherited unreachable earlier mail")
			_action("move_forward", false)
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
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	events.append({"time": (frames - 1) / 128.0, "mouse": [counts.x, counts.y]})

func _action(name: String, pressed: bool) -> void:
	if Input.is_action_pressed(name) == pressed:
		return
	_native_action(name, pressed)
	events.append({"time": maxf(0, (frames - 1) / 128.0), "action": name, "pressed": pressed})

func _v(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

func _native_action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

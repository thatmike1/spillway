extends SceneTree
## two normal-spawn roof loops exercise player-chosen order and an earned curved delivery.
const PROBE := preload("res://tests/mail_roofs_probe.gd")
const HOST := preload("res://scripts/game.gd")
const MAP := preload("res://scripts/maps/mail_roofs.gd")
const CLOCKWISE := [[Vector3(12, 10, 4), 0], [Vector3(12, 10, -28), 1], [Vector3(12, 10, -60), 2], [Vector3(12, 10, -60), -1], [Vector3(-12, 10, -60), -1], [Vector3(-12, 10, -28), 3], [Vector3(-12, 10, 4), 4], [Vector3(-7, 10, 12), -1]]
const COUNTER := [[Vector3(-12, 10, 4), 4], [Vector3(-12, 10, -28), 3], [Vector3(-12, 10, -60), -1], [Vector3(0, 10, -59), 2], [Vector3(12, 10, -60), -1], [Vector3(12, 10, -28), 1], [Vector3(12, 10, 4), 0], [Vector3(-7, 10, 12), -1]]
var ticket_probe: Node
var baseline_runner := ""
var game: Node
var step := 0
var ticks := 0
var variant := 0
var steering := false
var post := -1
var curve_step := -1
const CURVE := [Vector3(6, 12, -66.4), Vector3(6, 12, -72), Vector3(0, 12, -72)]
var direct_blocked := false
var events: Array = []
var observations: Array = []
var out := ""
var transitioning := true
var order: Array = []

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mail-roofs-out="):
			out = arg.trim_prefix("--mail-roofs-out=")
		elif arg.begins_with("--mail-roofs-baseline="):
			baseline_runner = arg.trim_prefix("--mail-roofs-baseline=")
	game = HOST.new()
	game.map_registry = preload("res://scripts/maps/catalog.gd").make()
	var entry: Dictionary = MAP.ROOF_ENTRY.duplicate(true)
	if not baseline_runner.is_empty():
		entry.runner = baseline_runner
	game.map_registry.catalog[MAP.ROOF_ID] = entry
	game.map_registry.order.append(MAP.ROOF_ID)
	game.map_registry.default_chain = [MAP.ROOF_ID]
	game.map_id = MAP.ROOF_ID
	game.persist = false
	game.record_runs = false
	root.add_child(game)
	ticket_probe = PROBE.new()
	ticket_probe.game = game
	ticket_probe.process_physics_priority = 1000
	root.add_child(ticket_probe)
	_begin()

func _begin() -> void:
	ticket_probe.clear_counts()
	game.restart_run("roof_tape")
	step = 0
	ticks = 0
	steering = false
	direct_blocked = false
	events = []
	observations = []
	order = []
	transitioning = false
	assert(game.player.delivery_progress() == Vector2i(0, 5))
	assert(not game.level.is_finish_at(game.level.finish_position))

func _physics_process(_dt: float) -> bool:
	if transitioning or game == null:
		return false
	ticks += 1
	var runner: CharacterBody3D = game.player
	var flight: RefCounted = runner.mail_flight
	observations.append({"tick": ticks - 1, "position": [runner.position.x, runner.position.y, runner.position.z], "delivered": flight.delivered.keys(), "active": flight.active, "finished": game.finished})
	if game.respawn_count != 0:
		push_error("roof route fell step=%d position=%s" % [step, runner.position]); quit(1)
	var points: Array = CLOCKWISE if variant == 0 else COUNTER
	if steering:
		if flight.active:
			var target: Vector3 = game.level.mailboxes[post].position
			if curve_step >= 0 and curve_step < CURVE.size():
				target = CURVE[curve_step]
				if flight.position.distance_to(target) < 0.45:
					curve_step += 1
			var desired: Vector3 = (target - flight.position).normalized()
			var correction: Vector3 = desired - flight.direction
			_mouse(Vector2(correction.dot(flight.direction.cross(Vector3.UP).normalized()), -correction.y) * 60)
		elif flight.result == "hit":
			order.append(post + 1)
			print("MAIL ROOFS delivery=%d order=%s ticks=%d" % [post + 1, order, ticks])
			steering = false
			step += 1
		else:
			push_error("roof delivery failed post=%d result=%s at=%s" % [post + 1, flight.result, flight.position]); quit(1)
	elif step < points.size():
		var delta: Vector3 = points[step][0] - runner.position
		delta.y = 0
		if delta.length() < 0.5:
			_action("move_forward", false)
			post = int(points[step][1])
			if post < 0:
				step += 1
			else:
				var start: Vector3 = runner.position + Vector3.UP * runner._eye_u * runner.U
				var target: Vector3 = game.level.mailboxes[post].position
				curve_step = 0 if post == 2 else -1
				if curve_step == 0:
					var hit: Dictionary = runner._blocked(start, target)
					assert(not hit.is_empty(), "chamber must block the direct delivery")
					var inner_hit: Dictionary = runner._blocked(Vector3(6, 12, -66.4), target)
					assert(not inner_hit.is_empty() and "chimney" in str(inner_hit.collider.name), "chimney must occlude the window-to-slot line")
					assert(float(runner.settings.duck_hull_height) * runner.U > 0.8, "body must not fit through the envelope window")
					for wx: float in [5.21, 6.79]:
						for wy: float in [11.61, 12.39]:
							for tx: float in [-1.09, 1.09]:
								for ty: float in [11.21, 12.79]:
									var corner_hit: Dictionary = runner._blocked(Vector3(wx, wy, -66.4), Vector3(tx, ty, -73.5))
									assert(not corner_hit.is_empty() and "chimney" in str(corner_hit.collider.name), "a straight corner ray bypassed the chimney")
					print("MAIL ROOFS chamber: 16 entry/target corner rays blocked; crouched body taller than window")
					var straight := preload("res://scripts/mail/flight.gd").new()
					straight.launch(start, (target - start).normalized())
					while straight.active:
						straight.step(1.0 / 128.0, game.level.mailboxes, runner._blocked)
					assert(straight.result == "wall" and straight.delivered.is_empty(), "direct envelope must fail")
					direct_blocked = true
					target = CURVE[0]
				var aim: Vector3 = (target - start).normalized()
				_look(atan2(-aim.x, -aim.z), asin(aim.y) + 0.03)
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = true
				Input.parse_input_event(event); Input.flush_buffered_events()
				events.append({"time": (ticks - 1) / 128.0, "button": 1, "pressed": true})
				steering = true
		else:
			_look(atan2(-delta.x, -delta.z), 0)
			_action("move_forward", true)
	if game.finished:
		assert(flight.delivered.size() == 5 and flight.misses == 0 and game.clean_eligible and game.session.actual_v_mismatches == 0)
		assert(direct_blocked)
		assert(ticket_probe.flight_checks > 0, "late physics UI probe never observed a flight")
		print("MAIL ROOFS late UI PASS flight_samples=%d finish_samples=%d" % [ticket_probe.flight_checks, ticket_probe.finish_checks])
		_action("move_forward", false)
		if not out.is_empty():
			var name := "clockwise" if variant == 0 else "counterclockwise"
			var file := FileAccess.open(out.path_join(name + ".json"), FileAccess.WRITE)
			file.store_string(JSON.stringify(events))
			file = FileAccess.open(out.path_join(name + ".expected.json"), FileAccess.WRITE)
			file.store_string(JSON.stringify({"course_key": game.course_key, "observations": observations}))
		print("MAIL ROOFS PASS order=%s clean=true ticks=%d curved_occlusion=%s" % [order, ticks, direct_blocked])
		if variant == 0:
			variant = 1
			transitioning = true
			game.set_paused(true)
			_begin.call_deferred()
		else:
			ticket_probe.game = null
			ticket_probe.queue_free()
			game.queue_free(); quit()
	if ticks > 20000:
		push_error("roof tape timeout step=%d position=%s" % [step, runner.position]); quit(1)
	return false

func _look(yaw: float, pitch: float) -> void:
	var runner: Node = game.player
	_mouse(Vector2((runner.yaw - yaw) / runner.tape_radians_per_count, (runner.pitch - pitch) / runner.tape_radians_per_count))

func _mouse(delta: Vector2) -> void:
	if delta.length_squared() < 0.000001:
		return
	var event := InputEventMouseMotion.new()
	event.relative = delta
	event.screen_relative = delta
	Input.parse_input_event(event); Input.flush_buffered_events()
	events.append({"time": (ticks - 1) / 128.0, "mouse": [delta.x, delta.y]})

func _action(action: String, pressed: bool) -> void:
	if Input.is_action_pressed(action) == pressed:
		return
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event); Input.flush_buffered_events()
	events.append({"time": (ticks - 1) / 128.0, "action": action, "pressed": pressed})

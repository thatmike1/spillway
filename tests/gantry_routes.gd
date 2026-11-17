extends SceneTree
## earn and replay ordinary input in the production host, including spawn settling and lifecycle.
const HOST := preload("res://scripts/game.gd")
const LEVEL := preload("res://scripts/maps/gantry.gd")
var player
var output := "/tmp/r22-03-hop-into-swing/host-routes"
var release_after := 14.0
var jump_after := 50
var basic_target := 350.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func control(fast: bool, tick: int, slot: int) -> Dictionary:
	var p: Vector3 = player.position
	var attached: bool = not player.grapple.is_empty()
	var hold := false
	var aim := Vector3(0, p.y, -120) - p
	var edge := -12.0 - slot * 48.0
	if slot < 2 and p.z < edge + 4 and p.z > edge - release_after:
		hold = true
		if not attached:
			aim = LEVEL.ANCHORS[slot] - player._eye()
	var yaw := atan2(-aim.x, -aim.z)
	var pitch := atan2(aim.y, Vector2(aim.x, aim.z).length()) if hold else 0.0
	var action := "" if attached else "move_forward"
	if (fast or player.control_speed() / player.U < basic_target) and not hold and not attached and not player.state.grounded:
		var v: Vector2 = Vector2(player.velocity.x, player.velocity.z) / player.U
		var desired := Vector2(-p.x * 0.6, -10).normalized()
		if v.length() > 40:
			var angle := acos(clampf(0.0 / v.length(), 0, 1))
			var a: Vector2 = v.normalized().rotated(angle)
			var b: Vector2 = v.normalized().rotated(-angle)
			var wish: Vector2 = a if a.dot(desired) > b.dot(desired) else b
			var side := 1.0 if wish.x > 0 else -1.0
			yaw = atan2(-wish.y * side, wish.x * side)
			action = "move_right" if side > 0 else "move_left"
	return {"jump": tick > jump_after, "yaw": yaw, "pitch": clampf(pitch, -player.PITCH_LIMIT, player.PITCH_LIMIT), "hold": hold, "action": action}

class Driver extends Node:
	signal complete(result: Dictionary)
	var harness
	var game
	var fast := false
	var playback: Array = []
	var events: Array = []
	var transfers: Array = []
	var tick := 0
	var event_index := 0
	var prior_action := ""
	var prior_jump := false
	var prior_hold := false
	var prior_attached := false
	var peak := 0.0

	func emit_input(row: Dictionary) -> void:
		var event: InputEvent
		if row.has("action"):
			var action := InputEventAction.new()
			action.action = row.action
			action.pressed = row.pressed
			action.strength = 1.0 if row.pressed else 0.0
			event = action
		elif row.has("button"):
			var button := InputEventMouseButton.new()
			button.button_index = row.button
			button.pressed = row.pressed
			event = button
		else:
			var mouse := InputEventMouseMotion.new()
			mouse.relative = Vector2(row.mouse[0], row.mouse[1])
			mouse.screen_relative = mouse.relative
			event = mouse
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		events.append(row)

	func command(cmd: Dictionary) -> void:
		var stamp := tick / 128.0
		if cmd.action != prior_action:
			if not prior_action.is_empty():
				emit_input({"time": stamp, "action": prior_action, "pressed": false})
			if not str(cmd.action).is_empty():
				emit_input({"time": stamp, "action": cmd.action, "pressed": true})
		if cmd.jump != prior_jump:
			emit_input({"time": stamp, "action": "jump", "pressed": cmd.jump})
		var p = game.player
		var gain := deg_to_rad(2.5 * 0.022)
		var dx: float = -wrapf(cmd.yaw - p.yaw, -PI, PI) / gain
		var dy: float = -(cmd.pitch - p.pitch) / gain
		if absf(dx) > 0.00001 or absf(dy) > 0.00001:
			emit_input({"time": stamp, "mouse": [dx, dy]})
		if cmd.hold != prior_hold:
			for index in [1, 2]:
				emit_input({"time": stamp, "button": index, "pressed": cmd.hold})
		prior_action = cmd.action
		prior_jump = cmd.jump
		prior_hold = cmd.hold

	func end_attempt(ok: bool) -> void:
		set_physics_process(false)
		game.set_paused(true)
		complete.emit({"finished": ok, "ticks": tick, "input_seconds": tick / 128.0,
			"game_seconds": game.elapsed, "respawns": game.respawn_count,
			"peak_ups": peak, "transfers": transfers, "jumps": game.player.state.jump_count,
			"position": str(game.player.position), "tape": events})

	func _physics_process(_delta: float) -> void:
		var p = game.player
		var attached: bool = not p.grapple.is_empty()
		var speed: float = p.control_speed() / p.U
		peak = maxf(peak, speed)
		if attached != prior_attached:
			transfers.append({"tick": tick, "attached": attached, "speed_ups": speed,
				"z": p.position.z, "y": p.position.y})
		prior_attached = attached
		if game.finished:
			end_attempt(game.respawn_count == 0)
			return
		if game.respawn_count > 0 or p.position.y < -5 or tick >= 5000:
			end_attempt(false)
			return
		if playback.is_empty():
			var slot := 0 if p.position.z > -30 else (1 if p.position.z > -78 else 2)
			command(harness.control(fast, tick, slot))
		else:
			var stamp := tick / 128.0
			while event_index < playback.size() and float(playback[event_index].time) <= stamp:
				emit_input(playback[event_index])
				event_index += 1
		tick += 1

func attempt(fast: bool, tape: Array = []) -> Dictionary:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump"]:
		if InputMap.has_action(action):
			Input.action_release(action)
	for index in [1, 2]:
		var event := InputEventMouseButton.new()
		event.button_index = index
		event.pressed = false
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	var game := HOST.new()
	game.map_id = "gantry"
	game.motor = "server128"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output.path_join("absent.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection.cfg")
	root.add_child(game)
	await process_frame
	await process_frame
	player = game.player
	assert(game.startup_error.is_empty() and game.tether_model() == "elastic-arc")
	game.restart_run()
	game.set_paused(false)
	var driver := Driver.new()
	driver.harness = self
	driver.game = game
	driver.fast = fast
	driver.playback = tape
	driver.process_physics_priority = -100
	game.add_child(driver)
	var result: Dictionary = await driver.complete
	game.queue_free()
	await process_frame
	return result

func run() -> void:
	RenderingServer.render_loop_enabled = false
	Engine.physics_ticks_per_second = 128
	DirAccess.make_dir_recursive_absolute(output)
	var results: Array = []
	for fast: bool in [false, true]:
		var result: Dictionary = {}
		for phase: int in [50, 40, 60, 70, 80, 90, 100, 32, 24]:
			jump_after = phase
			for release_distance: float in [14.0, 16.0, 12.0]:
				release_after = release_distance
				result = await attempt(fast)
				print("HOST_SWEEP fast=", fast, " phase=", phase, " release=", release_after, " finished=", result.finished)
				if result.finished:
					break
			if result.finished:
				break
		result["jump_after_tick"] = jump_after
		result["release_after_m"] = release_after
		var tape: Array = result.tape
		result.erase("tape")
		if result.finished:
			var replay: Dictionary = await attempt(fast, tape)
			result["host_replay_exact"] = replay.finished and replay.ticks == result.ticks and replay.respawns == 0
		else:
			result["host_replay_exact"] = false
		FileAccess.open(output.path_join("fast-timeline.json" if fast else "basic-timeline.json"), FileAccess.WRITE).store_string(JSON.stringify(tape))
		print("RESULT ", JSON.stringify(result))
		results.append(result)
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	var ok: bool = results[0].finished and results[1].finished and results[0].host_replay_exact and results[1].host_replay_exact
	if ok:
		ok = results[1].ticks < results[0].ticks and results[0].transfers.size() >= 4 and results[1].transfers.size() >= 4
	quit(0 if ok else 1)

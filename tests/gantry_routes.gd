extends SceneTree
## controller records ordinary buttons and view angles; playback never writes position or velocity.
const LEVEL := preload("res://scripts/maps/gantry.gd")
const RUNNER := preload("res://scripts/movement/grapple_player.gd")
const PRESETS := preload("res://scripts/r14_presets.gd")
var player
var level
var output := "/tmp/gantry-routes"
var left := false
var release_after := 12.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func button(on: bool) -> void:
	if left == on:
		return
	left = on
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = on
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	player._unhandled_input(event)
	var reel := InputEventMouseButton.new()
	reel.button_index = MOUSE_BUTTON_RIGHT
	reel.pressed = on
	Input.parse_input_event(reel)
	Input.flush_buffered_events()

func command(cmd: Dictionary) -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump"]:
		Input.action_release(action)
	if cmd.jump:
		Input.action_press("jump")
	if not str(cmd.action).is_empty():
		Input.action_press(cmd.action)
	player.yaw = cmd.yaw
	player.pitch = cmd.pitch
	button(cmd.hold)

func control(fast: bool, tick: int, slot: int) -> Dictionary:
	var p: Vector3 = player.position
	var attached: bool = not player.grapple.is_empty()
	var hold := false
	var aim := Vector3(0, p.y, -120) - p
	var edge := -12.0 - slot * 48.0
	if slot < 2 and p.z < edge + 4 and p.z > edge - release_after:
		hold = true
		aim = LEVEL.ANCHORS[slot] - player._eye()
	var yaw := atan2(-aim.x, -aim.z)
	var pitch := atan2(aim.y, Vector2(aim.x, aim.z).length()) if hold else 0.0
	var action := "" if attached else "move_forward"
	if fast and not hold and not attached and not player.state.grounded:
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
	return {"jump": tick > 50, "yaw": yaw, "pitch": clampf(pitch, -player.PITCH_LIMIT, player.PITCH_LIMIT), "hold": hold, "action": action}

func attempt(fast: bool, tape: Array = []) -> Dictionary:
	button(false)
	player.reset_to(level.spawn)
	player.configure_tether("elastic-arc", false)
	var commands: Array = []
	var transfers: Array = []
	var slot := 0
	var previous := false
	var peak := 0.0
	for tick in (5000 if tape.is_empty() else tape.size()):
		if slot < 2 and player.position.z < -30.0 - slot * 48:
			slot += 1
		var cmd: Dictionary = tape[tick] if not tape.is_empty() else control(fast, tick, slot)
		command(cmd)
		player._physics_process(1.0 / 128)
		commands.append(cmd)
		var attached: bool = not player.grapple.is_empty()
		var speed: float = Vector2(player.velocity.x, player.velocity.z).length() / player.U
		peak = maxf(peak, speed)
		if attached != previous:
			transfers.append({"tick": tick, "attached": attached, "speed_ups": speed, "z": player.position.z, "y": player.position.y, "vy": player.velocity.y / player.U})
		previous = attached
		if tick % 256 == 0:
			print("route ", fast, " tick ", tick, " pos ", player.position, " speed ", speed, " rope ", attached)
		if level.is_finish_at(player.position):
			return {"finished": true, "ticks": tick + 1, "seconds": (tick + 1) / 128.0, "peak_ups": peak, "transfers": transfers, "jumps": player.state.jump_count, "tape": commands}
		if player.position.y < -6:
			break
	return {"finished": false, "position": str(player.position), "transfers": transfers, "tape": commands}

func save_timeline(tape: Array, path: String) -> void:
	var events: Array = []
	var prior := {"action": "", "jump": false, "hold": false, "yaw": 0.0, "pitch": 0.0}
	var gain := deg_to_rad(2.5 * 0.022)
	for tick: int in tape.size():
		var cmd: Dictionary = tape[tick]
		var time := tick / 128.0
		if cmd.action != prior.action:
			if not str(prior.action).is_empty():
				events.append({"time": time, "action": prior.action, "pressed": false})
			if not str(cmd.action).is_empty():
				events.append({"time": time, "action": cmd.action, "pressed": true})
		if cmd.jump != prior.jump:
			events.append({"time": time, "action": "jump", "pressed": cmd.jump})
		if cmd.yaw != prior.yaw or cmd.pitch != prior.pitch:
			events.append({"time": time, "mouse": [-wrapf(cmd.yaw - prior.yaw, -PI, PI) / gain, -(cmd.pitch - prior.pitch) / gain]})
		if cmd.hold != prior.hold:
			for index in [1, 2]:
				events.append({"time": time, "button": index, "pressed": cmd.hold})
		prior = cmd
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(events))

func run() -> void:
	Engine.physics_ticks_per_second = 128
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "look_left", "look_right", "look_up", "look_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	level = LEVEL.new()
	root.add_child(level)
	level.build()
	player = RUNNER.new()
	player.apply_settings(PRESETS.source_settings("server128", {}))
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.input_enabled = true
	await physics_frame
	DirAccess.make_dir_recursive_absolute(output)
	var results: Array = []
	for fast in [false, true]:
		var result: Dictionary = {}
		for release_distance: float in [12.0, 10.0, 14.0, 8.0, 16.0]:
			release_after = release_distance
			result = attempt(fast)
			print("RELEASE_SWEEP fast=", fast, " after=", release_after, " finished=", result.finished)
			if result.finished:
				break
		result["release_after_m"] = release_after
		var tape: Array = result.tape
		result.erase("tape")
		FileAccess.open(output + ("/fast.json" if fast else "/basic.json"), FileAccess.WRITE).store_string(JSON.stringify(tape))
		if result.finished:
			var replay := attempt(fast, tape)
			result["replay_exact_ticks"] = replay.finished and replay.ticks == result.ticks
		else:
			result["replay_exact_ticks"] = false
		save_timeline(tape, output + ("/fast-timeline.json" if fast else "/basic-timeline.json"))
		print("RESULT ", JSON.stringify(result))
		results.append(result)
	FileAccess.open(output + "/result.json", FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	var ok: bool = results[0].finished and results[1].finished and results[0].replay_exact_ticks and results[1].replay_exact_ticks
	if ok:
		ok = results[1].ticks < results[0].ticks and results[0].transfers.size() >= 4 and results[1].transfers.size() >= 4
	quit(0 if ok else 1)

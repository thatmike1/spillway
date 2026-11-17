extends "res://tests/saltglass_human_replay.gd"
## replay a normal-spawn human prefix, then drive the complete seaward choice with inputs only.
var steering := false
var braking := true
var settling := false
var phase := 0
var phase_jump := false
var receiver_landed := false
var next_pan_landed := false
var held_controls: Dictionary = {}
var route_samples: Array = []
var driven_tape: Array = []
const FORK_TICK := 4100
const STEPS := [
	{"x": 180.6, "z": 49.0}, {"x": 188.0, "z": 49.0, "jump": true},
	{"x": 199.6, "z": 49.0}, {"x": 207.0, "z": 49.0, "jump": true},
	{"x": 208.0, "z": 51.0}, {"x": 212.8, "z": 53.88},
	{"x": 221.0, "z": 58.8, "jump": true}, {"x": 224.0, "z": 56.5},
	{"x": 231.0, "z": 51.0, "jump": true}, {"x": 237.6, "z": 51.0},
	{"x": 245.0, "z": 51.0, "jump": true}, {"x": 256.6, "z": 51.0},
	{"x": 264.0, "z": 51.0, "jump": true}, {"x": 275.6, "z": 51.0},
	{"x": 283.0, "z": 51.0, "jump": true}, {"x": 295.5, "z": 51.0},
	{"x": 303.0, "z": 51.0, "jump": true}, {"x": 307.0, "z": 38.0}]

func _initialize() -> void:
	target_map = "saltglass-seaward"
	super._initialize()

func feed_inputs() -> void:
	if not live:
		return
	if ticks < FORK_TICK:
		super.feed_inputs()
		return
	if not steering:
		steering = true
		# release the replay prefix's physical keys before the independent input policy takes over.
		var released := {}
		for row: Dictionary in tape:
			if float(row.time) < FORK_TICK / 128.0:
				var copied: Dictionary = row.duplicate(true)
				if copied.has("button"):
					copied.button = int(copied.button)
				if copied.has("keycode"):
					copied.keycode = int(copied.keycode)
					copied.physical_keycode = int(copied.physical_keycode)
				driven_tape.append(copied)
			if row.has("key") and not released.has(row.key):
				released[row.key] = true
				var event := InputEventKey.new()
				event.keycode = int(row.keycode)
				event.physical_keycode = int(row.physical_keycode)
				event.pressed = false
				Input.parse_input_event(event)
		for name: String in released:
			driven_tape.append({"time": FORK_TICK / 128.0, "key": name, "pressed": false})
		Input.flush_buffered_events()
	var player: Node3D = game.player
	var p := player.global_position
	var velocity: Vector3 = player.velocity
	var flat := Vector2(velocity.x, velocity.z)
	if braking:
		control("move_forward", false)
		control("jump", false)
		if flat.length() > 0.5:
			aim(Vector3(velocity.x, 0, velocity.z))
			control("move_back", true)
		else:
			control("move_back", false)
			braking = false
			settling = true
	elif settling:
		if player.is_grounded():
			settling = false
	elif phase < STEPS.size():
		var step: Dictionary = STEPS[phase]
		var delta := Vector3(float(step.x) - p.x, 0, float(step.z) - p.z)
		if delta.length() < 0.38 and player.is_grounded():
			phase += 1
			phase_jump = false
			control("jump", false)
		else:
			aim(delta)
			control("move_forward", true)
			var aligned: bool = flat.length() > 4.5 and Vector3(velocity.x, 0, velocity.z).normalized().dot(delta.normalized()) > 0.97
			var launch: bool = step.get("jump", false) and not phase_jump and player.is_grounded() and aligned
			control("jump", launch)
			if launch:
				phase_jump = true
	Input.flush_buffered_events()
	ticks += 1

func observe() -> void:
	if not live:
		return
	if not steering:
		super.observe()
		return
	var player: Node3D = game.player
	var p := player.global_position
	var support := ""
	if player.is_grounded():
		var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.1, p - Vector3.UP * 0.3)
		query.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			support = str(hit.collider.name)
	receiver_landed = receiver_landed or support.begins_with("seaward_receiver")
	next_pan_landed = next_pan_landed or (receiver_landed and support.begins_with("salt_step_5"))
	if ticks % 16 == 0 or not support.is_empty():
		route_samples.append({"tick": ticks - 1, "phase": phase, "position": [p.x, p.y, p.z], "support": support})
	if game.finished or game.respawn_count > 0 or ticks >= 128 * 100:
		live = false
		var result := {"ok": game.finished and game.respawn_count == 0 and receiver_landed and next_pan_landed and differences == 0,
			"map": target_map, "normal_spawn": true, "finished": game.finished, "finish_kind": game.finish_kind,
			"elapsed": game.elapsed, "respawns": game.respawn_count, "ticks": ticks, "phase": phase,
			"prefix_ticks": FORK_TICK, "prefix_position_differences": differences, "receiver_landed": receiver_landed,
			"receiving_pan_landed": next_pan_landed, "samples": route_samples,
			"source_sha256": FileAccess.get_sha256(source_path),
			"limit": "normal-spawn input-only outside completion; scripted steering does not prove first-time discovery, fastest routing or preference"}
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
		FileAccess.open(output + ".tape.json", FileAccess.WRITE).store_string(JSON.stringify(driven_tape))
		print("saltglass full outside: ", result.ok, " phase=", phase, " receiver=", receiver_landed, " next_pan=", next_pan_landed, " finish=", game.finished, " respawns=", game.respawn_count)
		game.request_quit(0 if result.ok else 1)

func aim(direction: Vector3) -> void:
	var player: Node3D = game.player
	var yaw := atan2(-direction.x, -direction.z)
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(-angle_difference(player.yaw, yaw) / player.mouse_sensitivity, 0)
	mouse.screen_relative = mouse.relative
	Input.parse_input_event(mouse)
	driven_tape.append({"time": ticks / 128.0, "mouse": [mouse.relative.x, mouse.relative.y]})

func control(action: String, pressed: bool) -> void:
	if bool(held_controls.get(action, false)) == pressed:
		return
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	held_controls[action] = pressed
	driven_tape.append({"time": ticks / 128.0, "action": action, "pressed": pressed})

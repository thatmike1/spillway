extends SceneTree
## open-loop event tape replay: no route planner or view/position/velocity corrections.
const LEVEL := preload("res://scripts/maps/viaduct.gd")
const PLAYER := preload("res://scripts/movement/grapple_player.gd")
var tape_path := ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tape="):
			tape_path = arg.trim_prefix("--tape=")
	run.call_deferred()
func run() -> void:
	if not FileAccess.file_exists(tape_path):
		push_error("supply --tape=/absolute/input.json")
		quit(2)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(tape_path))
	if not parsed is Array or parsed.is_empty():
		push_error("event tape must be a nonempty array")
		quit(2)
		return
	var events: Array = parsed
	for action: String in ["move_forward","move_back","move_right","move_left","jump","crouch","look_left","look_right","look_down","look_up"]:
		InputMap.add_action(action)
	var level := LEVEL.new()
	root.add_child(level)
	level.build()
	var player := PLAYER.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.apply_settings(preload("res://scripts/r14_presets.gd").source_settings("server128",{}))
	player.apply_engine_rate()
	player.configure_tether("elastic-arc",false)
	player.reset_to(level.spawn)
	player.input_enabled = true
	var cursor := 0
	var finished := false
	var last_tick := 0
	await physics_frame
	for tick: int in 4000:
		last_tick = tick
		while cursor < events.size() and roundi(float(events[cursor].time)*128) <= tick:
			var event: Dictionary = events[cursor]
			if event.has("action"):
				if event.pressed:
					Input.action_press(event.action,float(event.get("strength",1.0)))
				else:
					Input.action_release(event.action)
			elif event.has("mouse"):
				var motion := InputEventMouseMotion.new()
				motion.screen_relative = Vector2(event.mouse[0],event.mouse[1])
				player._unhandled_input(motion)
			elif event.has("button"):
				var button := InputEventMouseButton.new()
				button.button_index = int(event.button)
				button.pressed = bool(event.pressed)
				Input.parse_input_event(button)
				player._unhandled_input(button)
			cursor += 1
		player._physics_process(1.0/128)
		if level.is_finish_at(player.global_position):
			finished = true
			break
		if cursor == events.size():
			break
		await physics_frame
	print("VIADUCT TAPE REPLAY ",finished," ticks=",last_tick+1," feet=",player.global_position," attachments=",player.grapple_count)
	var ok := finished and player.grapple_count >= 3
	player.free()
	level.free()
	quit(0 if ok else 1)

extends SceneTree
## open-loop event tape replay: no route planner or view/position/velocity corrections.
const LEVEL := preload("res://scripts/maps/viaduct.gd")
const PLAYER := preload("res://scripts/movement/grapple_player.gd")
var tape_paths: Array[String] = []
var expect_upper_landing := false
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--upper":
			expect_upper_landing = true
		if arg.begins_with("--tape="):
			tape_paths.append(arg.trim_prefix("--tape="))
	run.call_deferred()
func run() -> void:
	var all_ok := not tape_paths.is_empty()
	for path: String in tape_paths:
		all_ok = (await replay(path)) and all_ok
	quit(0 if all_ok else 1)

func replay(tape_path: String) -> bool:
	if not FileAccess.file_exists(tape_path):
		push_error("supply --tape=/absolute/input.json")
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(tape_path))
	if not parsed is Array or parsed.is_empty():
		push_error("event tape must be a nonempty array")
		return false
	var events: Array = parsed
	for action: String in ["move_forward","move_back","move_right","move_left","jump","crouch","look_left","look_right","look_down","look_up"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)
	for index: int in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		var release := InputEventMouseButton.new()
		release.button_index = index
		release.pressed = false
		Input.parse_input_event(release)
	Input.flush_buffered_events()
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
	var landed_upper := false
	var last_tick := 0
	var preview_run := [0,0,0]
	var preview_best := [0,0,0]
	await physics_frame
	for tick: int in 4000:
		last_tick = tick
		while cursor < events.size() and roundi(float(events[cursor].time)*128) <= tick:
			var event: Dictionary = events[cursor]
			inject_event(player,event)
			cursor += 1
		player._physics_process(1.0/128)
		landed_upper = landed_upper or (LEVEL.UPPER_LANDING.has_point(player.global_position) and player.is_grounded())
		for bay: int in 3:
			if not player.grapple.is_empty() and player.grapple.position == LEVEL.V_ANCHORS[bay]:
				var target: Vector3 = LEVEL.V_ANCHORS[bay+1] if bay < 2 else level.finish_position+Vector3(0,2,0)
				var visible: bool = player._r21_on_screen(target-player._eye()) and player._clear_line(player._eye(),target) and player._clear_line(player._hull_centre(),target)
				preview_run[bay] = int(preview_run[bay])+1 if visible else 0
				preview_best[bay] = maxi(int(preview_best[bay]),int(preview_run[bay]))
		if level.is_finish_at(player.global_position):
			finished = true
			break
		if cursor == events.size():
			break
		await physics_frame
	print("VIADUCT TAPE REPLAY ",finished," ticks=",last_tick+1," feet=",player.global_position," attachments=",player.grapple_count," visible-preview-ticks=",preview_best," geometry-version=",level.level_version," upper-landed=",landed_upper)
	var ok: bool = (not expect_upper_landing or landed_upper) and finished and player.grapple_count >= 3 and preview_best.all(func(ticks: int) -> bool: return ticks >= 16)
	player.free()
	level.free()
	await physics_frame
	return ok

static func inject_event(player: Node3D, event: Dictionary) -> void:
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

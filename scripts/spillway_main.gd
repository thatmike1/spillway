extends Node3D
## p / run provenance is separate from movement and presentation.

const BUILD_ID := "spillway-2026.11.05-r10"
const SAVE_PATH := "user://spillway_v1.cfg"
var player: CharacterBody3D
var level: Node3D
var hud: CanvasLayer
var audio: Node
var bot: Node
var elapsed: float = 0.0
var finished: bool = false
## finish kinds are clean, practice or exploration; empty during a run.
var finish_kind: String = ""
var checkpoint_index: int = 0
var respawn_count: int = 0
var clean_eligible: bool = true
var splits: Array[float] = []
var best_splits: Array[float] = []
var best_segments: Array[float] = []
var split_deltas: Array[float] = []
var best_time: float = -1.0
var settings: Dictionary = {"sensitivity": 1.0, "fov": 90.0, "volume": 0.70, "comfort": false}
var paused: bool = false
var _started: bool = false
var _spawn_origin: Vector3
var _persist: bool = true
var _recovery_time: float = 0.0
var _quitting: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	bind_inputs()
	_persist = not OS.get_cmdline_user_args().has("--bot") and DisplayServer.get_name() != "headless"
	_load()
	level = preload("res://scripts/spillway_level.gd").new()
	level.name = "Spillway"
	add_child(level)
	level.call("build")
	player = preload("res://scripts/spillway_player.gd").new()
	player.name = "Runner"
	add_child(player)
	player.connect("landed", func(_impact: float) -> void:
		if player.in_water and level.has_method("splash_at"):
			level.call("splash_at", player.global_position))
	hud = preload("res://scripts/spillway_hud.gd").new()
	add_child(hud)
	hud.call("attach", self)
	audio = preload("res://scripts/spillway_audio.gd").new()
	add_child(audio)
	audio.call("attach", player, level)
	_apply_settings()
	restart_run()
	var args := OS.get_cmdline_user_args()
	if args.has("--no-hud"):
		hud.hide()
	if args.has("--verify-startup"):
		print("startup: Spillway; build=%s; renderer=%s" % [BUILD_ID, RenderingServer.get_current_rendering_method()])
		await get_tree().physics_frame
		await get_tree().physics_frame
		request_quit()
	if args.has("--bot"):
		bot = preload("res://scripts/spillway_driver.gd").new()
		add_child(bot)
		bot.call("attach", self)

func restart_run() -> void:
	elapsed = 0.0
	finished = false
	finish_kind = ""
	checkpoint_index = 0
	respawn_count = 0
	clean_eligible = true
	splits.clear()
	split_deltas.clear()
	_started = false
	_recovery_time = 0.0
	_spawn_origin = level.get("spawn").origin
	player.call("reset_to", level.get("spawn"))
	if level.has_method("reset_state"):
		level.call("reset_state")
	set_paused(false)
	if hud != null:
		hud.call("notify", "")

func practice_restart() -> void:
	clean_eligible = false
	finished = false
	finish_kind = ""
	splits.resize(checkpoint_index)
	# p / practice starts a fresh segment clock; a fall respawn still keeps its penalty.
	elapsed = splits[-1] if not splits.is_empty() else 0.0
	_started = false
	_restore_checkpoint()
	_spawn_origin = player.global_position
	set_paused(false)
	hud.call("notify", "Segment practice · R starts a clean run")

func respawn() -> void:
	respawn_count += 1
	hud.call("blink")
	clean_eligible = false
	finished = false
	finish_kind = ""
	splits.resize(checkpoint_index)
	_restore_checkpoint()
	hud.call("notify", "Back on solid ground · practice attempt")

func _restore_checkpoint() -> void:
	split_deltas.clear()
	var points: Array = level.get("checkpoints")
	var pose: Transform3D = level.get("spawn")
	if checkpoint_index < points.size():
		pose = points[checkpoint_index]["pose"]
	player.call("reset_to", pose)
	_recovery_time = 0.0

func _physics_process(delta: float) -> void:
	if player == null or paused:
		return
	if not _started and player.global_position.distance_to(_spawn_origin) > 0.5:
		_started = true
	if _started and not finished:
		elapsed += delta
	var water := false
	for region: Dictionary in level.get("water_regions"):
		if (region["bounds"] as AABB).has_point(player.global_position):
			water = true
	player.set("in_water", water)
	if player.global_position.y < -8.3 or absf(player.global_position.x) > 180.0 or player.global_position.z < -400.0 or player.global_position.z > 60.0:
		_recovery_time += delta
		if _recovery_time > 0.12:
			if finished:
				# p / exploration after a finish cannot invalidate its result or restart time.
				var look_pitch: float = player.get("pitch")
				var look_yaw: float = player.get("yaw")
				var wheel_feet: Vector3 = level.get("finish_position") + Vector3.UP * .04
				player.call("reset_to", Transform3D(Basis(Vector3.UP, look_yaw), wheel_feet))
				player.set("pitch", look_pitch)
				_recovery_time = 0.0
			else:
				respawn()
	else:
		_recovery_time = 0.0
	if finished:
		return
	var points: Array = level.get("checkpoints")
	var next := checkpoint_index + 1
	if next < points.size():
		var point: Dictionary = points[next]
		var position: Vector3 = (point["pose"] as Transform3D).origin
		var radius := float(point.get("radius", 5.0))
		var reached := (point["bounds"] as AABB).has_point(player.global_position) if point.get("bounds") is AABB else player.global_position.distance_to(position) < radius
		if reached or _stands_on_stage(next):
			checkpoint_index = next
			splits.append(elapsed)
			hud.call("notify", point.get("title", "Next segment"))
	var finish_center: Vector3 = level.get("finish_position")
	var finish_box := AABB(finish_center - Vector3(2.0, 0.3, 0.8), Vector3(4.0, 3.0, 1.6))
	var at_finish: bool = level.call("is_finish_at", player.global_position) if level.has_method("is_finish_at") else finish_box.has_point(player.global_position)
	if at_finish:
		# p / physical arrival always starts the wheel; skipped stages only withhold the record.
		_finish(checkpoint_index == points.size() - 1)

func _stands_on_stage(stage: int) -> bool:
	# p / progress follows decks the runner actually stands on, never side-wall contact.
	if not player.is_on_floor():
		return false
	var feet: Vector3 = player.global_position
	for i: int in player.get_slide_collision_count():
		var contact: KinematicCollision3D = player.get_slide_collision(i)
		if contact.get_normal().y < cos(player.floor_max_angle) - 0.01:
			continue
		# contacts left over from before a reset or respawn are not under the feet.
		var point: Vector3 = contact.get_position()
		if absf(point.y - feet.y) > 0.3 or Vector2(point.x - feet.x, point.z - feet.z).length() > 0.8:
			continue
		var body := contact.get_collider() as Node
		if body == null or int(body.get_meta("progress_stage", -1)) != stage:
			continue
		# where a later deck overlaps an earlier one (the run-up wedge pokes up to ~0.3 m
		# through the guarded apron corner), the runner is still standing in the earlier stage.
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.05, point + Vector3.DOWN * 0.6)
		query.exclude = [contact.get_collider_rid()]
		var under: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
		var under_stage: int = int((under.collider as Node).get_meta("progress_stage", -1)) if not under.is_empty() and under.collider is Node else -1
		if under_stage < 0 or under_stage >= stage:
			return true
	return false

func _finish(ordered: bool) -> void:
	finished = true
	finish_kind = "exploration" if not ordered else ("clean" if clean_eligible else "practice")
	# an exploration finish keeps only splits actually measured; skipped stages get none.
	if ordered:
		splits.append(elapsed)
	var is_best := false
	var stages: int = (level.get("checkpoints") as Array).size()
	if finish_kind == "clean" and splits.size() == stages:
		var previous: float = 0.0
		for i: int in splits.size():
			var segment_time := splits[i] - previous
			previous = splits[i]
			split_deltas.append(segment_time - best_segments[i] if i < best_segments.size() else INF)
			if i >= best_segments.size():
				best_segments.append(segment_time)
			else:
				best_segments[i] = minf(best_segments[i], segment_time)
		is_best = best_time < 0.0 or elapsed < best_time
		if is_best:
			best_time = elapsed
			best_splits = splits.duplicate()
		_save()
	if level.has_method("start_wheel"):
		level.call("start_wheel")
	audio.call("finish")
	hud.call("show_finish", is_best)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_run()
	elif event.is_action_pressed("practice"):
		practice_restart()
	elif event.is_action_pressed("pause"):
		set_paused(not paused)
	elif event.is_action_pressed("fullscreen"):
		var is_full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event is InputEventMouseButton and event.pressed and not paused and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	if player != null:
		player.set("input_enabled", not value)
	if hud != null:
		hud.call("set_paused", value)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func request_quit(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	if audio != null:
		audio.call("stop_all")
	# let the audio server release loop playback before the tree is destroyed.
	for i: int in 8:
		await get_tree().process_frame
	get_tree().quit(exit_code)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()

func change_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_apply_settings()
	_save()

func _apply_settings() -> void:
	player.set("mouse_sensitivity", 0.0022 * float(settings.sensitivity))
	player.set("fov_horizontal", float(settings.fov))
	player.set("comfort", bool(settings.comfort))
	if audio != null:
		audio.call("set_volume", float(settings.volume))

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for key: String in settings:
		settings[key] = config.get_value("settings", key, settings[key])
	best_time = float(config.get_value("records", "clean_best", -1.0))
	var saved: Array = config.get_value("records", "clean_splits", [])
	for value: Variant in saved:
		best_splits.append(float(value))
	for value: Variant in config.get_value("records", "clean_segments", []):
		best_segments.append(float(value))

func _save() -> void:
	if not _persist:
		return
	var config := ConfigFile.new()
	for key: String in settings:
		config.set_value("settings", key, settings[key])
	config.set_value("records", "clean_best", best_time)
	config.set_value("records", "clean_splits", best_splits)
	config.set_value("records", "clean_segments", best_segments)
	config.save(SAVE_PATH)

static func bind_inputs() -> void:
	var keys := {"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D], "look_left": [KEY_LEFT], "look_right": [KEY_RIGHT], "look_up": [KEY_UP], "look_down": [KEY_DOWN], "jump": [KEY_SPACE], "crouch": [KEY_CTRL, KEY_C], "restart": [KEY_R], "practice": [KEY_F], "pause": [KEY_ESCAPE], "fullscreen": [KEY_F11]}
	for action: String in keys:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.18)
		for code: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0], "look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0], "look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0]}
	for action: String in axes:
		var event := InputEventJoypadMotion.new()
		event.axis = axes[action][0]
		event.axis_value = axes[action][1]
		InputMap.action_add_event(action, event)
	for action: String in {"jump": JOY_BUTTON_A, "crouch": JOY_BUTTON_LEFT_SHOULDER, "pause": JOY_BUTTON_START}:
		var event := InputEventJoypadButton.new()
		event.button_index = {"jump": JOY_BUTTON_A, "crouch": JOY_BUTTON_LEFT_SHOULDER, "pause": JOY_BUTTON_START}[action]
		InputMap.action_add_event(action, event)

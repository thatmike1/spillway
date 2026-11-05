extends Node3D
## Owns the run: input bindings, mouse capture, the timer, folds, checkpoints,
## route cues, falls, restart and settings. The game starts running at once:
## no click-to-start screen stands between the player and mouse look.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const LEVEL_SCRIPT: Script = preload("res://scripts/level.gd")
const HUD_SCRIPT: Script = preload("res://scripts/hud.gd")
const ARMS_SCRIPT: Script = preload("res://scripts/arms.gd")
const AUDIO_SCRIPT: Script = preload("res://scripts/audio.gd")
const BOT_SCRIPT: Script = preload("res://scripts/bot.gd")
const SETTINGS_PATH: String = "user://settings_me.cfg"
const FALL_FLOOR: float = -24.0

var player: CharacterBody3D
var level: Node3D
var hud: CanvasLayer
var arms: Node
var audio: Node
var bot: Node

var elapsed: float = 0.0
var timer_running: bool = false
var finished: bool = false
var run_paused: bool = false
var checkpoint_index: int = 0
var cue_progress: int = 0
var restart_count: int = 0
var respawn_count: int = 0
var best_time: float = -1.0
# bot and checkpoint-start runs are for recording; they never touch saved settings or the best time
var _persist: bool = true
var settings: Dictionary = {
	"sensitivity": 1.0, "fov": 85.0, "bank": 1.0, "speed_fov": false,
	"assists": false, "head_bob": false, "invert_y": false, "volume": 0.8,
}

var _headless: bool = false
var _capture_retry: float = 0.0
var _user_released: bool = false
var _time: float = 0.0
var _respawning: float = -1.0
var _spawn_origin: Vector3 = Vector3.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	bind_inputs()
	_load_settings()
	level = LEVEL_SCRIPT.new() as Node3D
	level.name = "Level"
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	level.call("build")
	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.transform = level.get("spawn")
	add_child(player)
	audio = AUDIO_SCRIPT.new()
	audio.name = "Audio"
	add_child(audio)
	audio.call("attach", player, level)
	if not _headless:
		arms = ARMS_SCRIPT.new()
		arms.name = "Arms"
		arms.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(arms)
		arms.call("attach", player)
	hud = HUD_SCRIPT.new() as CanvasLayer
	hud.name = "Hud"
	add_child(hud)
	hud.connect("resume_requested", func() -> void: set_paused(false))
	hud.connect("restart_requested", restart_run)
	hud.connect("quit_requested", func() -> void: get_tree().quit())
	hud.connect("setting_changed", _on_setting_changed)
	hud.call("load_settings", settings)
	for entry: Dictionary in level.get("fold_triggers"):
		(entry["area"] as Area3D).body_entered.connect(_on_fold_trigger.bind(entry["fold"]))
	(level.get("finish_trigger") as Area3D).body_entered.connect(_on_finish)
	var points: Array = level.get("checkpoints")
	for index: int in range(points.size()):
		var area: Area3D = points[index]["area"]
		if area != null:
			area.body_entered.connect(_on_checkpoint.bind(index))
	for block: Node in level.get("folds"):
		block.connect("fold_started", func() -> void: audio.call("fold_started", block))
		block.connect("fold_settled", func() -> void: audio.call("fold_settled", block))
	_apply_settings()
	restart_run()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		# development aid for recording: start at a checkpoint with the folds in their state there
		if arg.begins_with("--from="):
			_persist = false
			checkpoint_index = clampi(int(arg.get_slice("=", 1)), 0, (level.get("checkpoints") as Array).size() - 1)
			respawn()
			# a fold finished this instant only reaches the physics step after a tick or
			# two; place the runner again once the road is really there
			await get_tree().physics_frame
			await get_tree().physics_frame
			respawn()
			respawn_count = 0
			hud.call("flash_message", "")
	if args.has("--bot"):
		attach_bot(args.has("--bot-quit"), args.has("--no-bank"))
		if checkpoint_index > 0:
			bot.call("skip_to_nearest")


func attach_bot(quit_at_end: bool = false, no_bank: bool = false) -> Node:
	_persist = false
	bot = BOT_SCRIPT.new()
	bot.name = "Bot"
	add_child(bot)
	bot.call("attach", self, player, level, quit_at_end)
	if no_bank:
		_on_setting_changed("bank", 0.0)
	return bot


# ---------------------------------------------------------------- run flow

func restart_run() -> void:
	restart_count += 1
	elapsed = 0.0
	timer_running = false
	finished = false
	checkpoint_index = 0
	cue_progress = 0
	_respawning = -1.0
	level.call("reset_state")
	var spawn: Transform3D = level.get("spawn")
	_spawn_origin = spawn.origin
	player.call("reset_to", spawn, Vector3.UP)
	hud.call("reset_run", best_time)
	audio.call("reset")
	set_paused(false)


func respawn() -> void:
	respawn_count += 1
	var points: Array = level.get("checkpoints")
	var point: Dictionary = points[checkpoint_index]
	var folds: Array = level.get("folds")
	for index: int in range(folds.size()):
		if index < int(point["folds_down"]) and not bool(folds[index].call("is_done")):
			folds[index].call("finish_now")
	player.call("reset_to", point["pose"], Vector3.UP)
	hud.call("flash_message", "Back on the last roof")


func _physics_process(delta: float) -> void:
	if player == null or run_paused:
		return
	if not finished:
		if not timer_running and player.global_position.distance_to(_spawn_origin) > 0.6:
			timer_running = true
			hud.call("hide_title")
		if timer_running:
			elapsed += delta
	_check_fall(delta)
	_update_cues()


func _check_fall(delta: float) -> void:
	if _respawning >= 0.0:
		_respawning += delta
		if _respawning >= 0.18:
			_respawning = -1.0
			respawn()
		return
	var falling: bool = player.global_position.y < FALL_FLOOR
	var air: float = float(player.call("get_air_time"))
	if air > 3.2 or (air > 1.8 and not player.up_direction.is_equal_approx(Vector3.UP)):
		falling = true
	var away: Vector3 = player.global_position
	if absf(away.x) > 120.0 or away.z > 60.0 or away.z < -260.0 or away.y > 140.0:
		falling = true
	if falling:
		_respawning = 0.0
		hud.call("fade_blink")


func _update_cues() -> void:
	var count: int = level.get("cues").size()
	for index: int in range(cue_progress, count):
		var position: Vector3 = level.call("cue_position", index)
		var radius: float = float(level.get("cues")[index]["radius"])
		if player.global_position.distance_to(position) < radius:
			cue_progress = index + 1
	var pulse: float = 0.85 + 0.15 * sin(_time * 4.0)
	for index: int in range(count):
		var level_value: float = 1.0
		if index < cue_progress:
			level_value = 0.3
		elif index == cue_progress:
			level_value = 3.4 * pulse
		elif index == cue_progress + 1:
			level_value = 2.0
		level.call("set_cue_level", index, level_value)


func _process(delta: float) -> void:
	_time += delta
	if player == null:
		return
	hud.call("update_state", elapsed, float(player.call("get_speed")))
	_manage_capture(delta)


func _on_fold_trigger(body: Node3D, block: Node) -> void:
	if body != player:
		return
	block.call("start_fold")


func _on_checkpoint(body: Node3D, index: int) -> void:
	if body != player or index <= checkpoint_index:
		return
	checkpoint_index = index


func _on_finish(body: Node3D) -> void:
	if body != player or finished:
		return
	finished = true
	timer_running = false
	var best: bool = best_time < 0.0 or elapsed < best_time
	if best:
		best_time = elapsed
		_save_settings()
	hud.call("show_finish", elapsed, best_time, best)
	audio.call("finish")


# ---------------------------------------------------------------- pause and mouse

func set_paused(value: bool) -> void:
	run_paused = value
	get_tree().paused = value
	player.call("set_controls_enabled", not value)
	hud.call("set_paused", value)
	if value:
		_release_mouse()
	else:
		_user_released = false
		_capture_retry = 0.0


func _manage_capture(delta: float) -> void:
	if _headless or run_paused or _user_released:
		return
	_capture_retry -= delta
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and _capture_retry <= 0.0:
		_capture_retry = 0.4
		if DisplayServer.window_is_focused():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release_mouse() -> void:
	if not _headless:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not run_paused:
		# any click takes the mouse back, whatever released it
		_user_released = false
		if not _headless:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("restart"):
		restart_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		set_paused(not run_paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fullscreen"):
		var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_capture_retry = 0.0


# ---------------------------------------------------------------- settings

func _on_setting_changed(key: String, value: Variant) -> void:
	settings[key] = value
	_apply_settings()
	_save_settings()


func _apply_settings() -> void:
	if player == null:
		return
	player.set("mouse_sensitivity", 0.0022 * float(settings["sensitivity"]))
	player.set("fov_horizontal", float(settings["fov"]))
	player.set("bank_amount", float(settings["bank"]))
	player.set("speed_fov", bool(settings["speed_fov"]))
	player.set("head_bob_enabled", bool(settings["head_bob"]))
	player.set("assists_enabled", bool(settings["assists"]))
	player.set("invert_y", bool(settings["invert_y"]))
	if audio != null:
		audio.call("set_volume", float(settings["volume"]))


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for key: String in settings.keys():
		settings[key] = config.get_value("settings", key, settings[key])
	best_time = float(config.get_value("run", "best", -1.0))


func _save_settings() -> void:
	if _headless or not _persist:
		return
	var config: ConfigFile = ConfigFile.new()
	for key: String in settings.keys():
		config.set_value("settings", key, settings[key])
	config.set_value("run", "best", best_time)
	config.save(SETTINGS_PATH)


# ---------------------------------------------------------------- input map

static func bind_inputs() -> void:
	var keys: Dictionary = {
		"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"look_left": [KEY_LEFT], "look_right": [KEY_RIGHT], "look_up": [KEY_UP], "look_down": [KEY_DOWN],
		"jump": [KEY_SPACE], "crouch": [KEY_CTRL, KEY_C], "restart": [KEY_R],
		"turn": [KEY_Q], "pause": [KEY_ESCAPE], "fullscreen": [KEY_F11],
	}
	var axes: Dictionary = {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"crouch": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	}
	var buttons: Dictionary = {
		"jump": [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER], "crouch": [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER],
		"turn": [JOY_BUTTON_Y], "restart": [JOY_BUTTON_BACK], "pause": [JOY_BUTTON_START],
	}
	for action: String in keys.keys():
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.2)
		for code: int in keys[action]:
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)
	for action: String in axes.keys():
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.axis = axes[action][0]
		motion.axis_value = axes[action][1]
		InputMap.action_add_event(action, motion)
	for action: String in buttons.keys():
		for button: int in buttons[action]:
			var press: InputEventJoypadButton = InputEventJoypadButton.new()
			press.button_index = button
			InputMap.action_add_event(action, press)

extends Node3D
## One owner for run progression, controls, checkpoint/reset and presentation.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const CITY_SCRIPT: Script = preload("res://scripts/city_builder.gd")
const HUD_SCRIPT: Script = preload("res://scripts/hud.gd")
const SETTINGS_PATH: String = "user://comfort.cfg"
const OBJECTIVES: Array[String] = [
	"Run toward the amber edge. The city will make a way.",
	"Cross the folding facade. Keep your momentum.",
	"Follow the amber ribbon. Walls can become floors.",
	"Through the window. Trust the other skyline.",
	"Reach the beacon on the final roof.",
]

var player: CharacterBody3D
var city: Node3D
var hud: CanvasLayer
var route: Dictionary = {}
var stage: int = 0
var elapsed: float = 0.0
var finished: bool = false
var run_paused: bool = false
var has_checkpoint: bool = false
var restart_count: int = 0
var fold_started: bool = false
var _saved_comfort: float = 0.65

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_inputs()
	_load_settings()
	city = CITY_SCRIPT.new() as Node3D
	city.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(city)
	route = city.call("build") as Dictionary
	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Register the physics body at its real spawn, never briefly at world origin.
	player.transform = route.get("spawn", Transform3D.IDENTITY)
	add_child(player)
	player.add_to_group("player")
	hud = HUD_SCRIPT.new() as CanvasLayer
	add_child(hud)
	_connect_hud()
	_connect_trigger("fold_trigger", _on_fold_trigger)
	_connect_trigger("checkpoint_trigger", _on_checkpoint_trigger)
	_connect_trigger("finish_trigger", _on_finish_trigger)
	var seam: Node = route.get("entry_seam") as Node
	if seam != null and seam.has_signal("traveler_crossed"):
		seam.connect("traveler_crossed", _on_portal_crossed)
	player.set("comfort_roll", _saved_comfort)
	if hud.has_method("set_comfort"):
		hud.call("set_comfort", _saved_comfort)
	restart_run()
	if DisplayServer.get_name() == "headless":
		player.call("set_controls_enabled", false)
	else:
		_set_pause(true)
		hud.call("show_message", "Click to run. The city is waiting.")

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if not finished and not run_paused:
		elapsed += delta
		if player.global_position.y < -35.0:
			recover_checkpoint()
		var finish_pose: Transform3D = route.get("finish", Transform3D.IDENTITY)
		var entry_seam: Node3D = route.get("entry_seam") as Node3D
		if stage == 2 and entry_seam != null and player.global_position.distance_to(entry_seam.global_position) < 5.0:
			stage = 3
		if stage >= 2 and player.global_position.distance_to(finish_pose.origin) < 18.0:
			stage = 4
	var speed: float = float(player.call("get_speed"))
	hud.call("update_state", speed, OBJECTIVES[mini(stage, OBJECTIVES.size() - 1)], elapsed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_run()
	elif event.is_action_pressed("pause"):
		_set_pause(not run_paused)
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT and run_paused and not finished:
			_set_pause(false)

func restart_run() -> void:
	stage = 0
	elapsed = 0.0
	finished = false
	has_checkpoint = false
	fold_started = false
	restart_count += 1
	var fold: Node = route.get("fold") as Node
	if fold != null:
		fold.call("reset_fold")
	for key: String in ["entry_seam", "exit_seam"]:
		var seam: Node = route.get(key) as Node
		if seam != null:
			seam.call("reset_seam")
	var spawn: Transform3D = route.get("spawn", Transform3D.IDENTITY)
	player.call("reset_to", spawn, Vector3.UP)
	if hud.has_method("reset_run"):
		hud.call("reset_run")
	hud.call("show_message", "Follow the amber route. R restarts your run.")
	_set_pause(false)

func recover_checkpoint() -> void:
	var key: String = "checkpoint" if has_checkpoint else "spawn"
	var pose: Transform3D = route.get(key, Transform3D.IDENTITY)
	player.call("reset_to", pose, Vector3.UP)
	for seam_key: String in ["entry_seam", "exit_seam"]:
		var seam: Node = route.get(seam_key) as Node
		if seam != null:
			seam.call("reset_seam")
	stage = 2 if has_checkpoint else (1 if fold_started else 0)
	hud.call("show_message", "Back on the roof. Keep going." if has_checkpoint else "Try that line again.")

func _on_fold_trigger(body: Node3D) -> void:
	if body != player or fold_started:
		return
	fold_started = true
	stage = 1
	var fold: Node = route.get("fold") as Node
	if fold != null:
		fold.call("start_fold")
	hud.call("show_message", "The facade is opening. Find your landing.")

func _on_checkpoint_trigger(body: Node3D) -> void:
	if body != player or has_checkpoint:
		return
	has_checkpoint = true
	stage = 2
	hud.call("show_message", "Checkpoint. Follow the ribbon around the sky.")

func _on_portal_crossed(_body: Node3D = null) -> void:
	stage = 4
	hud.call("show_message", "Different sky. Same momentum.")

func _on_finish_trigger(body: Node3D) -> void:
	if body != player or finished:
		return
	finished = true
	stage = 4
	hud.call("set_finished", elapsed)
	_set_pause(true)

func _set_pause(value: bool) -> void:
	run_paused = value
	if player != null:
		player.call("set_controls_enabled", not value and DisplayServer.get_name() != "headless")
	if hud != null:
		hud.call("set_paused", value)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	# Pause the actual simulation: folding and timer must stop together.
	get_tree().paused = value
	process_mode = Node.PROCESS_MODE_ALWAYS
	if hud != null:
		hud.process_mode = Node.PROCESS_MODE_ALWAYS

func _connect_trigger(key: String, callback: Callable) -> void:
	var area: Area3D = route.get(key) as Area3D
	if area != null:
		area.body_entered.connect(callback)

func _connect_hud() -> void:
	if hud.has_signal("restart_requested"):
		hud.connect("restart_requested", restart_run)
	if hud.has_signal("resume_requested"):
		hud.connect("resume_requested", func() -> void: _set_pause(false))
	if hud.has_signal("comfort_changed"):
		hud.connect("comfort_changed", _on_comfort_changed)

func _on_comfort_changed(value: float) -> void:
	_saved_comfort = clampf(value, 0.0, 1.0)
	player.set("comfort_roll", _saved_comfort)
	var config := ConfigFile.new()
	config.set_value("camera", "roll", _saved_comfort)
	config.save(SETTINGS_PATH)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_saved_comfort = clampf(float(config.get_value("camera", "roll", 0.65)), 0.0, 1.0)

func _bind_inputs() -> void:
	var bindings: Dictionary = {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "crouch": [KEY_CTRL],
		"restart": [KEY_R], "pause": [KEY_ESCAPE], "interact": [KEY_E],
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code: int in bindings[action]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)

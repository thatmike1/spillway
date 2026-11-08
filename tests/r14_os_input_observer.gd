extends Node
## read-only observer for the shipped pack; all control comes from the private x server.

var out := ""
var trace: FileAccess
var phase := "startup"
var last_latest := 0
var identity_written := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 10000
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--os-observer="):
			out = arg.trim_prefix("--os-observer=")
	trace = FileAccess.open(out.path_join("telemetry.jsonl"), FileAccess.WRITE)

func emit(row: Dictionary) -> void:
	row["ms"] = Time.get_ticks_msec()
	row["phase"] = phase
	trace.store_line(JSON.stringify(row))
	trace.flush()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		emit({"kind": "motion", "screen_relative": [event.screen_relative.x, event.screen_relative.y]})
	elif event is InputEventKey:
		emit({"kind": "key", "physical": event.physical_keycode, "pressed": event.pressed, "echo": event.echo})
	elif event is InputEventMouseButton:
		emit({"kind": "button", "button": event.button_index, "pressed": event.pressed})

func v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _physics_process(_delta: float) -> void:
	var game := get_tree().current_scene
	if game == null or game.get("player") == null:
		return
	if FileAccess.file_exists(out.path_join("phase")):
		phase = FileAccess.get_file_as_string(out.path_join("phase")).strip_edges()
	var player = game.player
	var state: Dictionary = player.get_motion_state()
	var row := {"kind": "sample", "preset": game.preset_id, "map": game.map_id,
		"paused": game.paused, "position": v3(player.global_position), "velocity": v3(player.velocity),
		"yaw": player.view_yaw, "pitch": player.view_pitch, "grounded": player.is_grounded(),
		"jumps": state.get("jump_count", -1), "lands": state.get("land_count", -1),
		"tick": state.get("tick", -1), "hz": Engine.physics_ticks_per_second,
		"delta": game.last_delta, "rate_ok": game.rate_ok, "rate_mismatch_ticks": game.rate_mismatch_ticks,
		"practice_stage": game.practice_stage, "checkpoint": game.checkpoint_index,
		"respawns": game.respawn_count, "profile_state": game.profile_state,
		"keys": {"w": Input.is_physical_key_pressed(KEY_W), "a": Input.is_physical_key_pressed(KEY_A),
			"d": Input.is_physical_key_pressed(KEY_D), "space": Input.is_physical_key_pressed(KEY_SPACE)}}
	if player.get("settings") is Dictionary:
		row["sensitivity"] = player.settings.get("sensitivity", 0)
		row["m_yaw"] = player.settings.get("m_yaw", 0)
	var hud = game.hud
	row["hud"] = {}
	for key: String in ["identity", "speed_label", "controls", "practice_tag", "pause_identity"]:
		var label = hud.get(key)
		if label != null:
			row.hud[key] = label.text
	if game.paused:
		row["buttons"] = {}
		for key: String in ["stage_picker", "stage_practice_button", "quit_button", "resume_button"]:
			var control = hud.get(key)
			var at: Vector2 = get_viewport().get_final_transform() * (control.get_global_transform_with_canvas() * (control.size / 2.0))
			row.buttons[key] = [at.x, at.y]
		row["stage_selected"] = hud.stage_picker.get_selected_id()
		row["stage_items"] = []
		for i: int in hud.stage_picker.item_count:
			row.stage_items.append(hud.stage_picker.get_item_text(i))
	emit(row)
	if Time.get_ticks_msec() - last_latest > 50:
		last_latest = Time.get_ticks_msec()
		var latest := FileAccess.open(out.path_join("latest.json"), FileAccess.WRITE)
		latest.store_string(JSON.stringify(row))
		latest.close()
	if not identity_written:
		identity_written = true
		var identity := {"kind": "identity", "executable": OS.get_executable_path(),
			"release": OS.has_feature("template_release"), "editor": OS.has_feature("editor"),
			"debug": OS.is_debug_build(), "res_root": ProjectSettings.globalize_path("res://"),
			"main_scene": game.scene_file_path, "project_main_scene": ProjectSettings.get_setting("application/run/main_scene"),
			"runner": player.get_script().resource_path, "game_script": game.get_script().resource_path,
			"adapter": RenderingServer.get_video_adapter_name(), "version": Engine.get_version_info(),
			"user_dir": OS.get_user_data_dir(), "persist": game.persist}
		emit(identity)

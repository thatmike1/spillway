extends SceneTree
## p / observer for tests/test_r15_loop_native.py: launches the real r15 scene (records on, into
## the profile named on the command line) at its starting preset's rate and only reads it. every
## physics tick it appends one telemetry row to <observer>/trace.jsonl and rewrites
## <observer>/latest.json, including where the menu's map cards and Quit button sit in window
## pixels, so the native actor can time key presses and aim clicks like a player watching the
## screen. no input, pose, velocity or game method is touched here; the game quits itself.
## godot --path . --script res://tests/test_r15_loop_tour.gd -- --observer=DIR [--r15-profile=..]

const SCENE := "res://scenes/r15.tscn"
const PRESETS := preload("res://scripts/r15_presets.gd")
const MAIN := preload("res://scripts/r15_main.gd")

var observer := ""
var game: Node
var trace: FileAccess
var tick := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--observer="):
			observer = arg.trim_prefix("--observer=")
	DirAccess.make_dir_recursive_absolute(observer)
	Engine.physics_ticks_per_second = int(PRESETS.entry(MAIN.DEFAULT_PRESET).rate)
	game = (load(SCENE) as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	trace = FileAccess.open(observer.path_join("trace.jsonl"), FileAccess.WRITE)
	physics_frame.connect(_sample)

func _center(control: Control) -> Array:
	if control == null or not control.is_visible_in_tree():
		return []
	var c := control.get_global_rect().get_center() * control.get_viewport().get_final_transform().get_scale()
	return [roundi(c.x), roundi(c.y)]

func _sample() -> void:
	if game == null or not is_instance_valid(game) or game.get("player") == null:
		return
	tick += 1
	var p: CharacterBody3D = game.player
	var hud: Node = game.hud
	var cards := {}
	for id: String in hud.map_buttons:
		cards[id] = _center(hud.map_buttons[id])
	var row := {"t": tick, "map": game.map_id, "preset": game.preset_id, "hz": game.physics_hz, "engine_hz": Engine.physics_ticks_per_second,
		"paused": game.paused, "feet": [p.global_position.x, p.global_position.y, p.global_position.z], "v": [p.velocity.x, p.velocity.y, p.velocity.z],
		"grounded": p.call("is_grounded"), "ducked": p.get("ducked"), "stand_blocked": p.get("stand_blocked"), "duck_counts": p.get("duck_counts"),
		"speed_u": game.call("display_speed_u"), "hud_speed": hud.speed_label.text, "crouch_tag": hud.crouch_tag.text if hud.crouch_tag.visible else "",
		"identity": hud.call("identity_text"), "title": root.get_window().title, "checkpoint": game.checkpoint_index, "elapsed": game.elapsed,
		"clean": game.clean_eligible, "practice_reason": game.practice_reason, "practice_tag": hud.practice_tag.text if hud.practice_tag.visible else "",
		"runner": game.call("runner_path"), "standin": game.call("runner_is_standin"), "records": game.profile_state,
		"cards": cards, "columns": hud.map_grid.columns, "quit": _center(hud.quit_button), "resume": _center(hud.resume_button),
		"window": [root.size.x, root.size.y], "jumps": p.get("jump_count")}
	var text := JSON.stringify(row)
	trace.store_line(text)
	if tick % 2 == 0:
		var latest := FileAccess.open(observer.path_join("latest.tmp"), FileAccess.WRITE)
		latest.store_string(text)
		latest.close()
		DirAccess.rename_absolute(observer.path_join("latest.tmp"), observer.path_join("latest.json"))

func _finalize() -> void:
	if trace != null:
		trace.close()

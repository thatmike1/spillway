extends SceneTree
## short final-HUD text check on the actual R16 host, authored practice and player camera.
const HOST := preload("res://scripts/r16_main.gd")
var out := ""
var game: Node
var shots: Array = []
var checks: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	_start.call_deferred()

func ticks(n: int) -> void:
	for i: int in n:
		await physics_frame

func capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out.path_join(tag + ".jpg"), 0.88)
	shots.append({"file": tag + ".jpg", "actual_player_camera": root.get_camera_3d() == game.player.camera,
		"stage": game.practice_stage, "practice_reason": game.practice_reason, "hint": game.hud._hint_text(),
		"recording_line": game.hud.recording_line.text, "hud_sha256": FileAccess.get_sha256("res://scripts/r16_hud.gd")})

func key(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _start() -> void:
	game = HOST.new()
	game.set("map_id", "experiment")
	game.set("persist", false)
	game.set("seed_from_r15", false)
	game.set("record_runs", true)
	game.set("recordings_dir", out.path_join("runs"))
	root.add_child(game)
	await ticks(8)
	game.practise_stage(1)
	await ticks(16)
	await capture("final-hud-slide-practice")
	checks.append({"name": "stage 1 teaches descent Shift and fresh Space", "ok": game.hud._hint_text() == "Shift on descent: slide at landing speed. Release Space, then tap it to hop out."})
	game.practise_stage(2)
	await ticks(16)
	await capture("final-hud-wall-practice")
	checks.append({"name": "stage 2 teaches held A/D and the kick limit", "ok": game.hud._hint_text() == "Tap Space at a wall; A/D may stay held. Two kicks per landing, each wall once."})
	key(true)
	await ticks(1)
	key(false)
	await ticks(8)
	await capture("final-hud-recording-menu")
	checks.append({"name": "actual recording path plus final plain menu words", "ok": game.hud.recording_line.text.contains(out.path_join("runs")) and game.hud.recording_line.text.ends_with("Recordings stay on this machine. Copy the r16_runs folder back for analysis.")})
	var file := FileAccess.open(out.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"label": "final HUD text only; authored lab practice/player camera and actual Esc menu; engine-injected Esc, no full-route rerender", "checks": checks, "shots": shots}, " "))
	file.close()
	game.request_quit(0 if checks.all(func(c: Dictionary) -> bool: return c.ok) else 1)

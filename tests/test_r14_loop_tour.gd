extends SceneTree
## p / native ui tour of the r14 game for visual evidence: default play on Penstock Yard with the
## bhop server, a hop chain with A/D and mouse strafes, the F1, F3 and F2 hot switches in the air,
## the pause menu, the map selector to Overflow and back. driven only by ordinary key, wheel,
## mouse-motion and click events through Input. it sets the starting rate before building the
## world, as r14_launch.gd does, and saves a few selected frames plus a per-tick trace.
## run it through tests/test_r14_loop_native.py (private Xvfb, Dummy audio, isolated profile,
## bounded movie). it is a presentation record, not a course route or a feel claim.
## godot --audio-driver Dummy --fixed-fps 30 --write-movie OUT/movie.avi --path . \
##   --script res://tests/test_r14_loop_tour.gd -- --out=OUT

const SCENE := "res://scenes/r14.tscn"
const PRESETS := preload("res://scripts/r14_presets.gd")
const FPS := 30.0

var out_dir := ""
var game: Node
var moments: Array[Dictionary] = []
var trace: FileAccess
var _ticks := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	# the movie writer owns the window title while recording; the title pass runs without it.
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("frames"))
	Engine.physics_ticks_per_second = int(PRESETS.entry("server128").rate)
	game = (load(SCENE) as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	trace = FileAccess.open(out_dir.path_join("trace.jsonl"), FileAccess.WRITE)
	physics_frame.connect(_sample)
	_tour.call_deferred()

func _sample() -> void:
	if game == null or not is_instance_valid(game) or game.player == null:
		return
	_ticks += 1
	var p: CharacterBody3D = game.player
	trace.store_line(JSON.stringify({"t": _ticks, "map": game.map_id, "preset": game.preset_id, "hz": Engine.physics_ticks_per_second,
		"dt": game.last_delta, "rate_ok": game.rate_ok, "paused": game.paused, "p": _v(p.global_position), "v": _v(p.velocity),
		"yaw": p.get("yaw"), "pitch": p.get("pitch"), "g": p.call("is_grounded"), "speed_u": game.call("display_speed_u"),
		"live_sync": game.stats.call("live_sync"), "hops": game.stats.hop_count}))

func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func mouse(dx: float, dy: float = 0.0) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.screen_relative = Vector2(dx, dy)
	Input.parse_input_event(event)

func click(control: Control) -> void:
	# events through Input are in window pixels; the hud lays out in the stretched viewport.
	var at: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await process_frame

func scroll_menu(notches: int) -> void:
	var at: Vector2 = root.get_final_transform() * Vector2(300, 400)
	for i: int in absi(notches):
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_WHEEL_DOWN if notches > 0 else MOUSE_BUTTON_WHEEL_UP
			event.pressed = pressed
			event.position = at
			event.global_position = at
			Input.parse_input_event(event)
		await process_frame

func frames(seconds: float, per_frame: Callable = Callable()) -> void:
	for i: int in roundi(seconds * FPS):
		if per_frame.is_valid():
			per_frame.call(i)
		await process_frame

## counts per frame that turn the view by `degrees_per_second` on the active family.
func turn_counts(degrees_per_second: float) -> float:
	var p: Object = game.player
	var per_count: float = p.get("tape_radians_per_count") if "tape_radians_per_count" in p else float(p.get("mouse_sensitivity"))
	return deg_to_rad(degrees_per_second / FPS) / per_count

func snap(name: String, note: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("frames").path_join(name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	var p: CharacterBody3D = game.player
	moments.append({"frame": name, "note": note, "tick": _ticks, "map": game.map_id, "map_name": game.call("map_name"), "preset": game.preset_id,
		"physics_hz": game.physics_hz, "engine_hz": Engine.physics_ticks_per_second, "last_delta": game.last_delta, "rate_ok": game.rate_ok,
		"window_title": root.get_window().title, "identity": game.hud.call("identity_text"), "strafe": [game.hud.strafe_live.text, game.hud.strafe_last.text, game.hud.strafe_chain.text],
		"speed_text": game.hud.speed_label.text, "message": game.hud.message.text, "practice_tag": game.hud.practice_tag.text, "paused": game.paused,
		"clean": game.clean_eligible, "practice_reason": game.practice_reason, "feet": _v(p.global_position), "velocity": _v(p.velocity), "yaw": p.get("yaw"),
		"runner": (p.get_script() as Script).resource_path, "rate_log": game.rate_log.size(), "profile_state": game.profile_state})

## a strafe: hold one side key and turn the same way for `seconds`.
func strafe(side: int, seconds: float, rate: float) -> void:
	key(KEY_A if side < 0 else KEY_D, true)
	var counts := turn_counts(rate) * float(side)
	await frames(seconds, func(_i: int) -> void: mouse(counts))
	key(KEY_A if side < 0 else KEY_D, false)

func _tour() -> void:
	await frames(1.0)
	await snap("01-default-spawn", "launch: Penstock Yard, F2 bhop server, 128 Hz, intro controls")
	key(KEY_W, true)
	await frames(1.0)
	key(KEY_W, false)
	key(KEY_SPACE, true)
	for i: int in 3:
		await strafe(-1, 0.45, 110.0)
		await strafe(1, 0.45, 110.0)
	await snap("02-default-strafe", "server autohop chain with A/D + mouse strafes, mid-air")
	await strafe(-1, 0.45, 110.0)
	await strafe(1, 0.3, 110.0)
	key(KEY_SPACE, false)
	await frames(0.8)
	await snap("03-hop-stats", "after landing: last hop gain, contact, sync and chain lines")
	# F1 in the air.
	key(KEY_W, true)
	await frames(0.4)
	key(KEY_SPACE, true)
	await frames(0.15)
	key(KEY_SPACE, false)
	key(KEY_W, false)
	key(KEY_F1, true)
	await process_frame
	key(KEY_F1, false)
	await strafe(-1, 0.25, 80.0)
	await snap("04-switch-vanilla", "F1 mid-air: vanilla 64 Hz, practice tag, same speed and view")
	await frames(1.0)
	key(KEY_SPACE, true)
	await process_frame
	key(KEY_SPACE, false)
	await frames(0.2)
	key(KEY_F3, true)
	await process_frame
	key(KEY_F3, false)
	await strafe(1, 0.3, 80.0)
	await snap("05-switch-r13", "F3 mid-air: unchanged R13 runner and camera, 120 Hz")
	await frames(1.0)
	# head back toward the middle of the runway, then F2. a source box that does not fit beside a
	# wall waits for room with a message; that frame is kept when it happens.
	var centre := atan2(game.player.global_position.x, 10.0)
	mouse(-angle_difference(float(game.player.get("yaw")), centre) / float(game.player.get("mouse_sensitivity")))
	key(KEY_W, true)
	await frames(0.3)
	key(KEY_F2, true)
	await process_frame
	key(KEY_F2, false)
	await frames(0.2)
	if str(game.pending_preset) != "":
		await snap("05b-switch-waits", "F2 next to a wall: the source box does not fit yet, the switch waits")
	await frames(1.2, func(_i: int) -> void: pass)
	key(KEY_W, false)
	await snap("06-switch-server", "F2: back to the bhop server, 128 Hz")
	key(KEY_ESCAPE, true)
	await process_frame
	key(KEY_ESCAPE, false)
	await frames(0.5)
	await snap("07-pause", "pause menu: presets with AA, rate, jump policy and controls")
	await scroll_menu(12)
	await frames(0.3)
	await snap("08-pause-maps", "pause menu scrolled: map selector and separate look settings")
	await click(game.hud.map_buttons["overflow"])
	await frames(1.5)
	await snap("09-overflow", "map selector: Overflow at its spawn, same preset")
	key(KEY_W, true)
	await frames(1.2)
	key(KEY_SPACE, true)
	for i: int in 2:
		await strafe(-1, 0.4, 90.0)
		await strafe(1, 0.4, 90.0)
	key(KEY_SPACE, false)
	key(KEY_W, false)
	await snap("10-overflow-run", "Overflow played with the bhop server")
	key(KEY_ESCAPE, true)
	await process_frame
	key(KEY_ESCAPE, false)
	await frames(0.3)
	await scroll_menu(12)
	await click(game.hud.map_buttons["practice"])
	await frames(1.0)
	await snap("11-back-penstock", "map selector: back to Penstock Yard")
	var file := FileAccess.open(out_dir.path_join("tour.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"moments": moments, "rate_log": game.rate_log, "ticks": _ticks, "build": game.BUILD_ID, "renderer": RenderingServer.get_current_rendering_method(),
		"video_adapter": RenderingServer.get_video_adapter_name(), "profile_path": ProjectSettings.globalize_path(game.profile_path)}, "  "))
	file.close()
	trace.close()
	game.call("request_quit")

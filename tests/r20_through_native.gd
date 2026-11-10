extends "res://tests/r20_through_route.gd"
## observational native seam: exactly the production input route, no camera or physical writes.
var captured := {}
var frames := {}

func _start() -> void:
	super()
	RenderingServer.render_loop_enabled = true
	var parts := str(opts.get("size", "1280x720")).split("x")
	root.size = Vector2i(int(parts[0]), int(parts[1]))

func _observe(tick: int) -> void:
	super(tick)
	if DisplayServer.get_name() == "headless":
		return
	var label := ""
	if tick == 150:
		label = "first-run"
	elif player.cue_left_s > 0.30:
		label = "launch"
	elif player.used and player.apex.is_empty() and player.cue_left_s <= 0.0:
		label = "flight"
	elif not player.apex.is_empty() and player.last_landing.is_empty():
		label = "apex"
	elif not player.last_landing.is_empty() and not player.continued:
		label = "landing"
	elif player.continued:
		label = "continued-run"
	if not label.is_empty() and not captured.has(label):
		captured[label] = tick
		capture.call_deferred(label)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(label + ".png")
	root.get_texture().get_image().save_png(path)
	frames[label] = {"observed_route_tick": captured[label], "readback_motor_tick": player.motion_tick, "readback_p": plain(player.position),
		"readback_camera_p": plain(player.camera.global_position), "image_sha256": FileAccess.get_sha256(path), "size": [root.size.x, root.size.y]}
	_write("frames.json", frames)

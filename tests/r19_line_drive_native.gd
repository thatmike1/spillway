extends "res://tests/r19_line_drive_route.gd"
## actual moving launch frames, read back without presentation changes to body or camera.

func _start() -> void:
	super._start()
	if opts.has("old-look"):
		game.set_look(false)

func _observe(tick: int) -> void:
	super._observe(tick)
	if tick in [100, 450, 700, 1000, 1300, 1600] and DisplayServer.get_name() != "headless":
		capture.call_deferred(tick)

func capture(tick: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("frame-%05d.png" % tick))

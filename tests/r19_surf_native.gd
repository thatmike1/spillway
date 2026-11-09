extends "res://tests/r19_surf_route.gd"
## read back actual route frames without moving the camera or body for presentation.

func _start() -> void:
	super._start()
	if opts.has("old-look"):
		game.look_enabled = false
		game.look_layer.set_enabled(false)

func _observe(tick: int) -> void:
	super._observe(tick)
	if tick in [40, 500, 1500, 2300, 3000, 4500, 6000, 7300] and DisplayServer.get_name() != "headless":
		capture.call_deferred(tick)

func capture(tick: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("frame-%05d.png" % tick))

extends "res://tests/r19_tether_route.gd"
## actual rendered transfer frames; replay input owns camera aim, with no presentation posing.

func _start() -> void:
	super._start()
	RenderingServer.render_loop_enabled = true
	if opts.has("old-look"):
		game.set_look(false)

func _observe(tick: int) -> void:
	super._observe(tick)
	if tick in [100, 350, 650, 900, 1200, 1550] and DisplayServer.get_name() != "headless":
		capture.call_deferred(tick)

func capture(tick: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("frame-%05d.png" % tick))

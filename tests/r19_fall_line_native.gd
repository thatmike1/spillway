extends "res://tests/r19_fall_line_route.gd"
## read actual route frames and countdowns; no camera posing or platform state changes.

func _start() -> void:
	super._start()
	if opts.has("old-look"):
		game.set_look(false)

func _observe(tick: int) -> void:
	super._observe(tick)
	if tick in [100, 350, 650, 1000, 1500, 2000, 2500, 2900] and DisplayServer.get_name() != "headless":
		capture.call_deferred(tick)

func capture(tick: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("frame-%05d.png" % tick))

extends "res://tests/r21_surf_route.gd"
## native observation seam; never selects a display or changes the view/body.
func _observe(tick: int) -> void:
	super._observe(tick)
	if tick in [40, 500, 1700, 2400, 3900, 4300, 5600, 6400, 7300, 7750, 7900, 8150] and DisplayServer.get_name() != "headless":
		capture.call_deferred(tick)

func capture(tick: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("frame-%05d.png" % tick))

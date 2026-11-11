extends "res://tests/r21_surf_skill.gd"
## native observation only; parent supplies a verified private display and the frozen skill tape.
func _observe(tick: int) -> void:
	super._observe(tick)
	if tick in [340, 391, 450, 480, 510, 540, 560, 580, 587, 630, 680] and DisplayServer.get_name() != "headless":
		capture.call_deferred(tick)

func capture(tick: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("frame-%05d.png" % tick))

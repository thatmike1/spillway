extends "res://tests/r20_run_export_route.gd"
## parent-only observational seam; never opens a native display or file manager itself.
func _start() -> void:
	super()
	RenderingServer.render_loop_enabled = DisplayServer.get_name() != "headless"

func export_observation() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("pause-export.png")
	root.get_texture().get_image().save_png(path)
	_write("native-export-frame.json", {"image": path, "sha256": FileAccess.get_sha256(path), "paused": game.paused,
		"button": READER.json_safe(game.hud.export_button.get_global_rect()), "path": game.hud.export_path.text, "folder_opener": "injected; no file manager launched"})

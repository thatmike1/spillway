extends "res://tests/r21_tether_route.gd"
## parent-owned native seam: same earned route and exact input tape, no camera/body posing.
var captured := {}

func _start() -> void:
	opts["production"] = "1"
	super._start()
	RenderingServer.render_loop_enabled = true
	var parts := str(opts.get("size", "1280x720")).split("x")
	root.size = Vector2i(int(parts[0]), int(parts[1]))
	game.hud.dismiss_title()
	for reason: String in ["released","time","range","obstructed"]:
		var cue: AudioStreamWAV = player.cues[reason]
		assert(cue.save_to_wav(out_dir.path_join("cue-"+reason+".wav"))==OK)

func _observe(tick: int) -> void:
	super._observe(tick)
	if DisplayServer.get_name() == "headless":
		return
	var experiment: Dictionary = player.get_motion_state().experiment
	if tick in [100, 350, 650, 900, 1200, 1550]:
		capture.call_deferred("route-%05d" % tick)
	if "grapple_release" in experiment.events and not captured.has("release"):
		captured.release = tick
		capture.call_deferred("release-%05d" % tick)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))

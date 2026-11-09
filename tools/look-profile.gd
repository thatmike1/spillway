extends SceneTree
## identical cameras, alternating look order, GPU timestamps and uncapped frame intervals.
const MAIN := preload("res://scripts/look_main.gd")
const VIEWS := preload("res://tools/look-views.gd").VIEWS
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var game := MAIN.new()
	root.add_child(game)
	game.set_paused(true)
	game.get("hud").hide()
	game.get("look_label").hide()
	var camera := Camera3D.new()
	camera.fov = 73.739795
	camera.far = 1500
	root.add_child(camera)
	camera.make_current()
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	var result: Array = []
	for round_index: int in 2:
		for view: String in VIEWS:
			camera.look_at_from_position(VIEWS[view][0],VIEWS[view][1])
			for mode: bool in ([false,true] if round_index == 0 else [true,false]):
				game.set_look(mode)
				for i: int in 40:
					await RenderingServer.frame_post_draw
				var samples: Array = []
				var last := Time.get_ticks_usec()
				for i: int in 120:
					await RenderingServer.frame_post_draw
					var now := Time.get_ticks_usec()
					samples.append({"frame_ms":(now-last)/1000.0,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid),"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid)})
					last = now
				result.append({"round":round_index,"view":view,"look":"new" if mode else "old","samples":samples})
	var file := FileAccess.open(output.path_join("performance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"device":RenderingServer.get_video_adapter_name(),"method":"1280x720 private AMD X11, vsync disabled, fixed paused cameras, two alternating rounds, 40 warmup plus 120 measured frames each; includes host/compositor timing, no physical input/display latency claim","rows":result},"  "))
	game.request_quit(0)

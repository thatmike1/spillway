extends SceneTree
## p / r14 practice overview stills: the built level from a few fixed cameras, rendered in a
## real window (run under a private display), one png each. presentation evidence only.
## godot --path . --resolution 1280x720 --script res://tests/r14_practice_overview.gd -- --out=DIR

const LEVEL := preload("res://scripts/r14_practice_level.gd")
## name, eye, look-at, fov (0: orthographic top view with that size in metres).
const SHOTS := [
	["plan", Vector3(-118, 160, -77), Vector3(-118, 0, -77.01), 0.0],
	["stop_logs", Vector3(10, 8, -12), Vector3(-2, -1, -52), 70.0],
	["valve_bend", Vector3(12, 9, -68), Vector3(-10, -1, -92), 75.0],
	["runway", Vector3(-14, 5, -98), Vector3(-80, -1, -98), 75.0],
	["weir_gauges", Vector3(-146, 5, -98), Vector3(-190, -1, -98), 75.0],
	["pump_bend", Vector3(-205, 7, -94), Vector3(-232, -1, -112), 75.0],
	["tail_race", Vector3(-236, 5, -110), Vector3(-236, -2, -150), 75.0],
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	assert(out.is_absolute_path(), "overview: pass --out=<absolute directory outside git>")
	DirAccess.make_dir_recursive_absolute(out)
	var level: Node3D = LEVEL.new()
	root.add_child(level)
	level.call("build")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.far = 900.0
	camera.current = true
	for shot: Array in SHOTS:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP if float(shot[3]) > 0.0 else Vector3.FORWARD)
		if float(shot[3]) > 0.0:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = float(shot[3])
		else:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 190.0
		for i: int in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % shot[0]))
	print("overview: %d stills in %s" % [SHOTS.size(), out])
	quit(0)

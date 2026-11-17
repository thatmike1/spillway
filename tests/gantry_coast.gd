extends "res://tests/gantry_chain.gd"
## an earned win must coast on the receiving court without the host's finish rescue.
func _initialize() -> void:
	output = "/tmp/r22-03-hop-into-swing/coast"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	run.call_deferred()

func run() -> void:
	RenderingServer.render_loop_enabled = false
	Engine.physics_ticks_per_second = 128
	DirAccess.make_dir_recursive_absolute(output)
	chain_config()
	jump_after = 80
	release_after = 12
	third_release = 12
	coast_ticks = 160
	var result: Dictionary = await attempt(true)
	result.erase("tape")
	result.erase("motion_trace")
	FileAccess.open(output.path_join("coast.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("GANTRY_COAST ", JSON.stringify(result))
	quit(0 if result.finished and result.timer_finished and result.coast_min_feet >= 3.8 else 1)

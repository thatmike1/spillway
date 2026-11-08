extends SceneTree
## source-only execution of the exact release probe's lab UI coroutine. headless states are
## observations of the real main, not a rendered-frame or exported-runtime claim.

class Observer:
	extends "res://tools/r15-pack-probe.gd"
	func _ready() -> void:
		pass

var out := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	root.size = Vector2i(1280, 720)
	_run.call_deferred()

func _run() -> void:
	var main := preload("res://scripts/r15_main.gd").new()
	root.add_child(main)
	for i: int in 8:
		await process_frame
	var probe := Observer.new()
	probe.game = main
	probe.report.mode = "lab-source-component"
	probe.expect = {"identity": {"registry": probe._registry(), "keys": {"breakwater": {"server128": {
		"runner_chain": probe._script_chain(main.player), "course_key": main.course_key}}}}}
	root.add_child(probe)
	await probe._pause_menu_click("Map_experiment", "open the lab")
	await probe._lab_controls("breakwater", "server128")
	probe.check("normal course has the approved runner, not a sticky lab body", main.runner_path() == "res://scripts/r15_source_player.gd")
	probe.check("component never reads or writes a player profile", not main.persist)
	var failed := probe.checks.filter(func(c: Dictionary) -> bool: return not bool(c.ok))
	DirAccess.make_dir_recursive_absolute(out)
	var stream := FileAccess.open(out.path_join("RESULTS.json"), FileAccess.WRITE)
	stream.store_string(JSON.stringify({"checks": probe.checks, "failed": failed.size(),
		"scope": "source-only actual release lab-control coroutine; no drawing or exported runtime", "records": main.persist}, "  ", false, true))
	stream.close()
	print("r15 release lab source component: ", probe.checks.size(), " checks, ", failed.size(), " failed")
	probe.queue_free()
	main.queue_free()
	await process_frame
	await process_frame
	quit(0 if failed.is_empty() else 1)

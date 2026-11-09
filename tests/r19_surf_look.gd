extends SceneTree
## verify the new-map look hook and the actual inherited L input without changing identity.
const HOST := preload("res://tests/r19_surf_host.gd")
const GEOMETRY := preload("res://tests/r19_surf_geometry.gd")
var output := "/tmp/r19-surf-course/look"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_L
	event.physical_keycode = KEY_L
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	RenderingServer.render_loop_enabled = false
	DirAccess.make_dir_recursive_absolute(output)
	var host := HOST.new()
	host.persist = false
	host.record_runs = false
	host.seed_from_r15 = false
	host.ghosts_directory = output.path_join("ghosts")
	host.ghost_share_storage = output.path_join("selection.cfg")
	root.add_child(host)
	var before: Dictionary = host.motion_identity()
	var feet: Vector3 = host.player.position
	var painted: bool = host.look_enabled and host.look_layer.enabled
	key(true)
	key(false)
	var original: bool = not host.look_enabled and not host.look_layer.enabled
	key(true)
	key(false)
	var restored: bool = host.look_enabled and host.look_layer.enabled
	var geometry := GEOMETRY.audit(host.level)
	var report: Dictionary = host.look_layer.report
	var ok: bool = painted and original and restored and before == host.motion_identity() and feet == host.player.position and geometry.ok
	ok = ok and str(report.sky) == "res://assets/look/r17/practice-sky.png" and int(report.swaps) > 60 and int(report.ink_segments) > 0 and int(report.jump_lips) > 0
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "painted": painted, "original": original, "restored": restored, "same_identity": before == host.motion_identity(), "same_feet": feet == host.player.position, "geometry_ok": geometry.ok, "look": report, "limit": "headless material/toggle verification, not native visual acceptance"}, "\t"))
	file.close()
	print("saltglass look/toggle: ", ok, " ", report)
	host.request_quit(0)
	quit(0 if ok else 1)

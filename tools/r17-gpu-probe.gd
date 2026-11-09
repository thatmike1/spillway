extends Node
## external autoload in a harness copy of the exact release. the pack and executable stay unchanged.
var spec: Dictionary = {}
var game: Node
var result: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--r17-gpu-probe="):
			path = arg.trim_prefix("--r17-gpu-probe=")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if not path.is_empty() else null
	if not parsed is Dictionary:
		push_error("r17 gpu probe: missing spec")
		get_tree().quit(3)
		return
	spec = parsed
	result = {"ok":false,"spec":spec,"checks":[],"rows":[]}
	await get_tree().process_frame
	await get_tree().process_frame
	await run()

func check(ok: bool, name: String, value: Variant = null) -> bool:
	result.checks.append({"ok":ok,"name":name,"value":value})
	if not ok:
		push_error("r17 gpu probe: " + name)
	return ok

func finish(code: int) -> void:
	result.ok = code == 0
	var file := FileAccess.open(str(spec.out).path_join("performance.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result,"  "))
	if is_instance_valid(game) and game.has_method("request_quit"):
		game.request_quit(code)
	else:
		get_tree().quit(code)

func run() -> void:
	game = get_tree().current_scene
	var runtime := {"executable":OS.get_executable_path(),"release":OS.has_feature("template_release"),
		"editor":OS.has_feature("editor"),"debug":OS.is_debug_build(),"version":Engine.get_version_info(),
		"executable_sha256":FileAccess.get_sha256(OS.get_executable_path()),"pack_sha256":FileAccess.get_sha256(str(spec.pack)),
		"adapter":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"method":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),
		"scene":game.scene_file_path if game != null else "","script":(game.get_script() as Script).resource_path if game != null else ""}
	result.runtime = runtime
	if not check(runtime.release and not runtime.editor and not runtime.debug,"actual official release",runtime):
		finish(3)
		return
	if not check(runtime.executable_sha256 == spec.runtime_sha256 and runtime.pack_sha256 == spec.pack_sha256,"exact delivered executable and pack"):
		finish(3)
		return
	if not check(runtime.scene == "res://scenes/r17.tscn" and runtime.script == "res://scripts/r17_main.gd","packed R17 main scene"):
		finish(3)
		return
	if not check(game.map_id == spec.map,"requested actual map",game.map_id):
		finish(3)
		return
	game.set_paused(true)
	game.hud.hide()
	game.look_label.hide()
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var camera := Camera3D.new()
	camera.fov = 73.739795
	camera.far = 1500
	add_child(camera)
	camera.make_current()
	var views := {"spawn":game.level.spawn}
	var checkpoints: Array = game.level.checkpoints
	if checkpoints.size() > 1:
		views["route"] = checkpoints[mini(2,checkpoints.size()-1)].pose
	if game.map_id == "breakwater":
		views["concept"] = Transform3D.IDENTITY.looking_at(Vector3(-130,5,-139),Vector3.UP)
		views.concept.origin = Vector3(-70,1.3,-94)
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	for i: int in 4:
		await RenderingServer.frame_post_draw
	result.viewport = {"window":str(DisplayServer.window_get_size()),"texture":str(root.get_texture().get_size()),
		"visible_rect":str(root.get_visible_rect()),"screen":str(DisplayServer.screen_get_size()),
		"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps}
	var expected := Vector2i(int(spec.width),int(spec.height))
	if not check(DisplayServer.window_get_size() == expected and Vector2i(root.get_texture().get_size()) == expected,"actual requested viewport dimensions",result.viewport):
		finish(3)
		return
	result.identity = {"geometry":game.course_geometry,"overlay":game.overlay_id,"motion":game.motion_identity(),"look":game.look_layer.report}
	for round_index: int in 2:
		for view: String in views:
			camera.transform = views[view]
			camera.position += Vector3.UP*1.7
			for enabled: bool in ([false,true] if round_index == 0 else [true,false]):
				game.set_look(enabled)
				for i: int in 40:
					await RenderingServer.frame_post_draw
				var samples: Array = []
				var last := Time.get_ticks_usec()
				for i: int in 120:
					await RenderingServer.frame_post_draw
					var now := Time.get_ticks_usec()
					samples.append({"frame_ms":(now-last)/1000.0,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid),
						"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid)})
					last = now
				result.rows.append({"round":round_index,"view":view,"look":"new" if enabled else "old", "camera":var_to_str(camera.global_transform),"fov":camera.fov,"samples":samples})
	for row: Dictionary in result.rows:
		for sample: Dictionary in row.samples:
			if not check(is_finite(sample.gpu_ms) and sample.gpu_ms > 0.0,"valid positive GPU measurement",sample.gpu_ms):
				finish(3)
				return
	result.protocol = "fixed paused cameras; actual release and delivered PCK; uncapped, vsync disabled; two alternating orders; 40 warmup + 120 measured frames per look/view/order; GPU/CPU timestamps and frame intervals; no input/display latency claim"
	finish(0)

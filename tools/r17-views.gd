extends SceneTree
## matched native fixed views of one real r17 map. simulation is paused; this is not route play.
const MAIN := preload("res://scripts/r17_main.gd")
var output := ""
var map_id := "breakwater"
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	var game := MAIN.new()
	game.map_id = map_id
	game.seed_from_r15 = false
	root.add_child(game)
	game.set_paused(true)
	game.hud.hide()
	game.look_label.hide()
	var camera := Camera3D.new()
	camera.fov = 73.739795
	camera.far = 1500
	root.add_child(camera)
	camera.make_current()
	var views := {"spawn":game.level.spawn}
	var checkpoints: Array = game.level.checkpoints
	if checkpoints.size() > 1:
		views["route"] = checkpoints[mini(2,checkpoints.size()-1)].pose
	if map_id == "breakwater":
		views["concept"] = Transform3D.IDENTITY.looking_at(Vector3(-130,5,-139),Vector3.UP)
		views.concept.origin = Vector3(-70,1.3,-94)
	var rows: Array = []
	for view: String in views:
		camera.transform = views[view]
		camera.position += Vector3.UP*1.7
		for mode: bool in [false,true]:
			game.set_look(mode)
			for i: int in 35:
				await RenderingServer.frame_post_draw
			var file := output.path_join(view+("-new.png" if mode else "-old.png"))
			root.get_texture().get_image().save_png(file)
			rows.append({"view":view,"new":mode,"camera":var_to_str(camera.global_transform),"fov":camera.fov,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	var file := FileAccess.open(output.path_join("views.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"map":map_id,"geometry":game.course_geometry,"overlay":game.overlay_id,"look":game.look_layer.report,"views":rows},"  "))
	game.request_quit()

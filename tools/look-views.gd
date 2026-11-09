extends SceneTree
## fixed paired cameras; presentation evidence, never a claim of a played route.
const MAIN := preload("res://scripts/look_main.gd")
const VIEWS := {
	"concept": [Vector3(-70,3.0,-94),Vector3(-200,8,-233)],
	"breakwater": [Vector3(-73,1.7,-150),Vector3(-75,12,-256)],
	"box-rows": [Vector3(5,3.0,-22),Vector3(-2,-0.2,-58)],
	"breach": [Vector3(-75,1.7,-222),Vector3(-75,2,-250)],
}
var game: Node3D
var output := ""
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	Engine.physics_ticks_per_second = 128
	game = MAIN.new()
	root.add_child(game)
	game.get("hud").hide()
	game.get("look_label").hide()
	game.set_paused(true)
	var camera := Camera3D.new()
	camera.fov = 73.739795
	camera.far = 1500
	root.add_child(camera)
	camera.make_current()
	var measures: Array = []
	for view: String in VIEWS:
		camera.look_at_from_position(VIEWS[view][0],VIEWS[view][1])
		for mode: bool in [false,true]:
			game.set_look(mode)
			for i: int in 30:
				await process_frame
			await RenderingServer.frame_post_draw
			var file := output.path_join(view+("-new.png" if mode else "-old.png"))
			root.get_texture().get_image().save_png(file)
			measures.append({"view":view,"look":"new" if mode else "old","draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var out := FileAccess.open(output.path_join("views.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify({"method":"fixed cameras at identical poses and FOV, actual inherited R15 host, simulation paused; concept camera approximates supplied screenshot, generated concept changes perspective","views":VIEWS,"measures":measures},"  "))
	game.request_quit(0)

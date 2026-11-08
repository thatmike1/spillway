extends SceneTree
## p / Whiteout Relay fixed views: the map in the actual r15 main (records off, hud hidden), seen
## from authored cameras that are NOT the player's. art and readability frames only; the
## player-camera evidence is the driver's tape replayed with --write-movie. needs a real renderer.
## godot --audio-driver Dummy --display-driver x11 --rendering-driver opengl3 --resolution 1280x720
##   --path . --script res://tests/r15_whiteout_views.gd -- --out=DIR [--only=NAME,...] [--no-records]

const MAIN := preload("res://scripts/r15_main.gd")
const PRESETS := preload("res://scripts/r15_presets.gd")
## name: [eye, look-at]
const VIEWS := {
	"01-hangar": [Vector3(0.5, 1.7, 9.0), Vector3(0.0, 1.0, -40.0)],
	"02-apron": [Vector3(3.0, 1.7, -22.0), Vector3(0.0, 0.5, -80.0)],
	"03-trench": [Vector3(-2.0, 1.7, -72.0), Vector3(0.0, -0.5, -100.0)],
	"04-ridge": [Vector3(0.0, 1.7, -116.0), Vector3(0.0, 1.0, -165.0)],
	"05-basin": [Vector3(8.0, 4.5, -112.0), Vector3(0.0, -2.6, -150.0)],
	"06-saddle": [Vector3(0.0, 3.7, -166.0), Vector3(10.0, 2.0, -215.0)],
	"07-catwalk": [Vector3(-12.0, 3.7, -172.0), Vector3(-17.0, 1.5, -198.0)],
	"08-receiver": [Vector3(4.0, 2.7, -205.0), Vector3(45.0, 1.0, -195.0)],
	"09-shed": [Vector3(45.0, 2.7, -186.0), Vector3(45.0, 1.5, -140.0)],
	"10-gantry": [Vector3(40.0, 4.2, -170.0), Vector3(40.0, 2.5, -130.0)],
	"11-relay": [Vector3(45.0, 2.7, -124.0), Vector3(45.0, 4.0, -70.0)],
	"12-overview": [Vector3(-70.0, 60.0, 30.0), Vector3(15.0, 0.0, -130.0)],
	"13-overview-far": [Vector3(110.0, 50.0, -250.0), Vector3(10.0, 0.0, -110.0)],
}

var out := ""
var only: PackedStringArray = []
var game: Node3D
var camera: Camera3D
var queue: Array = []
var wait := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	assert(out.is_absolute_path(), "views: pass --out=<absolute directory outside git>")
	DirAccess.make_dir_recursive_absolute(out)
	Engine.physics_ticks_per_second = int(PRESETS.entry(MAIN.DEFAULT_PRESET).rate)
	game = MAIN.new()
	game.set("map_id", "whiteout-relay")
	game.set("set_window_title", false)
	root.add_child(game)
	_setup.call_deferred()

func _setup() -> void:
	(game.get("hud") as CanvasLayer).hide()
	camera = Camera3D.new()
	camera.fov = 75.0
	camera.far = 2000.0
	root.add_child(camera)
	for name: String in VIEWS:
		if only.is_empty() or only.has(name):
			queue.append(name)
	wait = 30

func _process(_delta: float) -> bool:
	if camera == null:
		return false
	if wait > 0:
		wait -= 1
		return false
	if queue.is_empty():
		game.call("request_quit", 0)
		return true
	var name: String = queue[0]
	if not camera.current:
		var view: Array = VIEWS[name]
		camera.look_at_from_position(view[0], view[1])
		camera.make_current()
		wait = 14
		return false
	var image := root.get_texture().get_image()
	image.save_jpg(out.path_join(name + ".jpg"), 0.86)
	print("views: %s" % name)
	queue.pop_front()
	camera.clear_current(false)
	return false

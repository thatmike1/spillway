extends SceneTree
## p / Rainline fixed views: the map in the actual r15 main (records off, hud hidden), seen from
## authored cameras that are NOT the player's. these are art and readability frames only; the
## player-camera evidence is the driver's tape replayed with --write-movie. needs a real renderer.
## godot --audio-driver Dummy --display-driver x11 --rendering-driver opengl3 --resolution 1280x720
##   --path . --script res://tests/r15_rainline_views.gd -- --out=DIR [--only=NAME,...] --no-records

const MAIN := preload("res://scripts/r15_main.gd")
const PRESETS := preload("res://scripts/r15_presets.gd")
## name: [eye, look-at]
const VIEWS := {
	"01-tannery": [Vector3(0.0, 1.7, 11.0), Vector3(0.0, -1.0, -30.0)],
	"02-gantry": [Vector3(5.0, -1.3, -46.0), Vector3(22.0, -3.0, -50.0)],
	"03-scaffold": [Vector3(24.0, -1.0, -56.0), Vector3(28.0, -3.0, -90.0)],
	"04-scaffold-south": [Vector3(30.0, -2.8, -118.0), Vector3(50.0, -3.0, -121.0)],
	"05-lamp-room": [Vector3(51.5, -1.3, -64.0), Vector3(51.5, -2.0, -50.0)],
	"06-duct": [Vector3(51.5, -1.8, -50.0), Vector3(51.5, -2.5, -32.0)],
	"07-runway-lip": [Vector3(52.0, -1.3, -14.0), Vector3(52.0, -5.0, 20.0)],
	"08-footbridge": [Vector3(63.0, -4.8, -6.0), Vector3(63.0, -5.0, 20.0)],
	"09-antenna-deck": [Vector3(50.0, -1.7, 28.0), Vector3(54.0, 4.0, 40.0)],
	"10-overview": [Vector3(100.0, 50.0, 40.0), Vector3(40.0, -5.0, -50.0)],
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
	game.set("map_id", "rainline")
	game.set("set_window_title", false)
	root.add_child(game)
	_setup.call_deferred()

func _setup() -> void:
	(game.get("hud") as CanvasLayer).hide()
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 1500.0
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
		wait = 12
		return false
	var image := root.get_texture().get_image()
	image.save_jpg(out.path_join(name + ".jpg"), 0.88)
	print("views: %s" % name)
	queue.pop_front()
	camera.clear_current(false)
	return false

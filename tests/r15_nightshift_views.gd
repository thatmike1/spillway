extends SceneTree
## p / Night Shift fixed views: the map in the actual r15 main (records off, hud hidden), seen from
## authored cameras that are NOT the player's. these are art and readability frames only; the
## player-camera evidence is the driver's tape replayed with --write-movie. needs a real renderer.
## godot --audio-driver Dummy --display-driver x11 --rendering-driver opengl3 --resolution 1280x720
##   --path . --script res://tests/r15_nightshift_views.gd -- --out=DIR [--only=NAME,...] [--nightshift-neutral]

const MAIN := preload("res://scripts/r15_main.gd")
const PRESETS := preload("res://scripts/r15_presets.gd")
## name: [eye, look-at]
const VIEWS := {
	"01-platform": [Vector3(0.5, 1.7, 21.0), Vector3(0.0, 2.0, -40.0)],
	"02-throat": [Vector3(-1.0, 1.7, -40.0), Vector3(1.0, -0.5, -75.0)],
	"03-loop-mouth": [Vector3(1.0, 1.7, -74.0), Vector3(14.0, 0.0, -100.0)],
	"04-loop-sweep": [Vector3(14.0, 1.7, -113.0), Vector3(42.0, 0.5, -96.0)],
	"05-traverser": [Vector3(2.0, 1.7, -90.5), Vector3(38.0, 0.0, -92.0)],
	"06-shed-door": [Vector3(43.0, 1.7, -97.0), Vector3(43.0, 2.0, -80.0)],
	"07-chicane": [Vector3(43.0, 1.7, -87.5), Vector3(35.0, 1.2, -84.5)],
	"08-shutter": [Vector3(46.8, 1.6, -91.8), Vector3(48.6, 1.4, -80.0)],
	"09-west-bay": [Vector3(35.8, 1.7, -82.0), Vector3(35.8, 1.5, -44.0)],
	"10-east-lane": [Vector3(48.7, 1.0, -84.0), Vector3(48.7, 1.0, -40.0)],
	"11-ramp": [Vector3(49.0, 1.7, -37.0), Vector3(47.0, 5.0, -2.0)],
	"12-flyover": [Vector3(36.0, 6.7, 6.5), Vector3(-20.0, 4.0, 6.5)],
	"13-crossing": [Vector3(2.0, 6.7, 6.5), Vector3(-6.0, -1.0, 24.0)],
	"14-canal": [Vector3(-24.0, 6.7, 6.5), Vector3(-48.0, 0.5, 6.5)],
	"15-terminus": [Vector3(-44.0, 1.7, 6.5), Vector3(-78.0, 4.0, 6.5)],
	"16-overview": [Vector3(70.0, 60.0, 50.0), Vector3(0.0, 0.0, -50.0)],
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
	game.set("map_id", "night-shift")
	game.set("persist", false)
	game.set("set_window_title", false)
	root.add_child(game)
	_setup.call_deferred()

func _setup() -> void:
	(game.get("hud") as CanvasLayer).hide()
	camera = Camera3D.new()
	camera.fov = 75.0
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

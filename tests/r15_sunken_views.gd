extends SceneTree
## p / Sunken Court fixed views: the map in the actual r15 main (records off, hud hidden), seen from
## authored cameras that are NOT the player's. art and readability frames only; the player-camera
## evidence is the driver's tape replayed with --write-movie. needs a real renderer.
## godot --audio-driver Dummy --display-driver x11 --rendering-driver opengl3 --resolution 1280x720
##   --path . --script res://tests/r15_sunken_views.gd -- --out=DIR [--only=NAME,...]

const MAIN := preload("res://scripts/r15_main.gd")
const PRESETS := preload("res://scripts/r15_presets.gd")
## name: [eye, look-at]
const VIEWS := {
	"01-gate": [Vector3(0.5, 9.7, 12.0), Vector3(0.0, 6.0, -30.0)],
	"02-steps": [Vector3(0.0, 9.7, -10.0), Vector3(0.0, 2.0, -60.0)],
	"03-court": [Vector3(3.0, 6.1, -45.0), Vector3(-2.0, 2.0, -95.0)],
	"04-court-floor": [Vector3(-7.0, -0.3, -96.0), Vector3(-4.0, 2.0, -60.0)],
	"05-head": [Vector3(0.0, 6.7, -96.0), Vector3(20.0, 2.0, -128.0)],
	"06-aqueduct": [Vector3(14.0, 6.7, -127.0), Vector3(40.0, 4.0, -100.0)],
	"07-chord": [Vector3(1.5, 6.7, -101.5), Vector3(30.5, 4.5, -109.5)],
	"08-leg": [Vector3(40.0, 6.7, -100.0), Vector3(40.0, 5.0, -60.0)],
	"09-cloister": [Vector3(40.0, 6.7, -60.0), Vector3(54.0, 5.0, -40.0)],
	"10-causeway": [Vector3(41.5, 6.4, -61.0), Vector3(47.0, 5.6, -45.0)],
	"11-rise": [Vector3(53.5, 6.7, -36.0), Vector3(50.0, 9.0, 4.0)],
	"12-sanctuary": [Vector3(45.0, 10.7, 2.5), Vector3(22.0, 10.0, 3.0)],
	"13-overview": [Vector3(110.0, 80.0, 50.0), Vector3(15.0, 0.0, -55.0)],
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
	game.set("map_id", "sunken-court")
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

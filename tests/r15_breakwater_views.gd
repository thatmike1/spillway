extends SceneTree
## p / Breakwater fixed views: the map in the actual r14 main (records off, hud hidden), seen from
## authored cameras that are NOT the player's. these are art and readability frames only; the
## player-camera evidence is the driver's tape replayed with --write-movie. needs a real renderer.
## godot --audio-driver Dummy --display-driver x11 --rendering-driver opengl3 --resolution 1280x720
##   --path . --script res://tests/r15_breakwater_views.gd -- --out=DIR [--only=NAME,...]

const MAIN := preload("res://scripts/r14_main.gd")
const PRESETS := preload("res://scripts/r14_presets.gd")
## name: [eye, look-at]
const VIEWS := {
	"01-gate": [Vector3(0.5, 1.7, 5.0), Vector3(-1.0, 0.0, -40.0)],
	"02-box-rows": [Vector3(5.0, 7.5, -22.0), Vector3(-2.0, -1.0, -58.0)],
	"03-bend-one": [Vector3(4.0, 5.0, -62.0), Vector3(-12.0, 0.0, -90.0)],
	"04-crane-line": [Vector3(-12.0, 1.7, -88.0), Vector3(-55.0, 6.0, -90.0)],
	"05-bend-two": [Vector3(-48.0, 7.0, -84.0), Vector3(-75.0, 0.0, -120.0)],
	"06-breakwater": [Vector3(-73.0, 1.7, -150.0), Vector3(-75.0, 12.0, -256.0)],
	"07-breach": [Vector3(-75.0, 1.7, -222.0), Vector3(-75.0, 2.0, -250.0)],
	"08-lighthouse": [Vector3(-52.0, 3.0, -236.0), Vector3(-75.0, 13.0, -258.0)],
	"09-overview": [Vector3(60.0, 70.0, 30.0), Vector3(-40.0, 0.0, -140.0)],
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
	game.set("level_script", load("res://scripts/r15_breakwater_level.gd"))
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

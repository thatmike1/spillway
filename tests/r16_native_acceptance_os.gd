extends SceneTree
## read-only observer of OS/XTest input on the actual R16 game; never injects gameplay events.
const HOST := preload("res://scripts/r16_main.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
var game: Node
var out := ""
var frames := 0
var samples: FileAccess
var inputs: FileAccess
var shot_pending := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	_start.call_deferred()

func _start() -> void:
	game = HOST.new()
	game.set("map_id", "breakwater")
	game.set("persist", false)
	game.set("seed_from_r15", false)
	game.set("recordings_dir", out.path_join("runs"))
	game.set("record_runs", true)
	root.add_child(game)
	var observer := Observer.new()
	observer.owner_run = self
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	observer.process_physics_priority = 1100
	root.add_child(observer)
	samples = FileAccess.open(out.path_join("observations.jsonl"), FileAccess.WRITE)
	inputs = FileAccess.open(out.path_join("os-inputs.jsonl"), FileAccess.WRITE)

class Observer:
	extends Node
	var owner_run: Variant
	func _physics_process(_delta: float) -> void:
		owner_run.observe()
	func _input(event: InputEvent) -> void:
		owner_run.input_observed(event)
	func _process(_delta: float) -> void:
		owner_run.capture_requested()

func input_observed(event: InputEvent) -> void:
	if inputs == null:
		return
	if event is InputEventKey:
		inputs.store_line(JSON.stringify({"frame": Engine.get_physics_frames(), "keycode": event.keycode,
			"physical_keycode": event.physical_keycode, "pressed": event.pressed, "echo": event.echo, "source": "OS window input; observer never injects"}))
		inputs.flush()

func ui_nodes(node: Node, found: Array) -> void:
	if node is Control and node.is_visible_in_tree():
		if node is BaseButton or node.name in ["RecordingLine", "PauseHeading"]:
			var rect: Rect2 = node.get_global_rect()
			found.append({"name": str(node.name), "text": str(node.text) if "text" in node else "", "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	for child: Node in node.get_children():
		ui_nodes(child, found)

func observe() -> void:
	if game == null or samples == null:
		return
	frames += 1
	if frames % 8 != 0:
		return
	var ui: Array = []
	ui_nodes(game.hud, ui)
	var state := {"frame": Engine.get_physics_frames(), "map": game.map_id, "paused": game.paused, "ghost_setting": game.settings.ghost,
		"focus": str(root.gui_get_focus_owner().name) if root.gui_get_focus_owner() != null else "", "p": READER.json_safe(game.player.global_position), "v": READER.json_safe(game.player.velocity),
		"held": game.session.last_sample.get("held", {}), "lab": READER.json_safe(game.player.get_motion_state().get("experiment", {})), "ui": ui}
	samples.store_line(JSON.stringify(state))
	samples.flush()
	var file := FileAccess.open(out.path_join("observer.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(state))
	file.close()

func capture_requested() -> void:
	var request := out.path_join("capture.txt")
	if shot_pending or not FileAccess.file_exists(request):
		return
	var tag := FileAccess.get_file_as_string(request).strip_edges().validate_filename()
	DirAccess.remove_absolute(request)
	shot_pending = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out.path_join(tag + ".jpg"), 0.88)
	shot_pending = false

extends Node
## a read-only external-pack observer; gameplay comes exclusively from the private X server.
const READER := preload("res://scripts/r16_run_reader.gd")
var game: Node
var directory := ""
var rows: FileAccess
var keys: FileAccess
var ticks := 0
var jumps := 0
var lands := 0
var shot_pending := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 1100
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lab-os-out="):
			directory = arg.trim_prefix("--lab-os-out=")
	DirAccess.make_dir_recursive_absolute(directory)
	rows = FileAccess.open(directory.path_join("observations.jsonl"), FileAccess.WRITE)
	keys = FileAccess.open(directory.path_join("inputs.jsonl"), FileAccess.WRITE)

func _input(event: InputEvent) -> void:
	if keys != null and event is InputEventKey:
		keys.store_line(JSON.stringify({"frame": Engine.get_physics_frames(), "physical": event.physical_keycode,
			"keycode": event.keycode, "pressed": event.pressed, "echo": event.echo}))
		keys.flush()

func _ui(node: Node, found: Array) -> void:
	if node is BaseButton and node.is_visible_in_tree():
		var item := {"name": str(node.name), "text": node.text}
		if node is OptionButton:
			item["selected"] = node.get_selected_id()
			item["popup"] = node.get_popup().visible
			item["focused_item"] = node.get_popup().get_focused_item()
		found.append(item)
	for child: Node in node.get_children():
		_ui(child, found)

func _physics_process(_delta: float) -> void:
	if game == null:
		for child: Node in get_tree().root.get_children():
			if child.get_script() != null and child.get_script().resource_path == "res://scripts/r16_main.gd":
				game = child
	if game == null or game.get("player") == null:
		return
	var body: CharacterBody3D = game.player
	var motion: Dictionary = body.get_motion_state()
	if "jump" in motion.get("events", []):
		jumps += 1
	if "land" in motion.get("events", []):
		lands += 1
	var held := {}
	for name: String in ["move_forward", "move_left", "move_right", "jump", "crouch", "r15_slide"]:
		held[name] = Input.is_action_pressed(name)
	var ui: Array = []
	if game.paused:
		_ui(game.hud, ui)
	var focus := get_tree().root.gui_get_focus_owner()
	var row := {"tick": ticks, "frame": Engine.get_physics_frames(), "map": game.map_id, "paused": game.paused,
		"p": READER.json_safe(body.global_position), "v": READER.json_safe(body.velocity), "g": body.is_grounded(),
		"yaw": body.yaw, "pitch": body.pitch, "events": motion.get("events", []),
		"lab": READER.json_safe(motion.get("experiment", {})), "held": held, "ui": ui,
		"focus": str(focus.name) if focus != null else "", "practice": game.practice_stage,
		"respawns": game.respawn_count, "elapsed": game.elapsed, "jumps": jumps, "lands": lands}
	rows.store_line(JSON.stringify(row))
	if ticks % 64 == 0:
		rows.flush()
	var pending := directory.path_join("latest.tmp")
	var latest := FileAccess.open(pending, FileAccess.WRITE)
	latest.store_string(JSON.stringify(row))
	latest.close()
	DirAccess.rename_absolute(pending, directory.path_join("latest.json"))
	ticks += 1

func _process(_delta: float) -> void:
	var request := directory.path_join("capture.txt")
	if shot_pending or directory.is_empty() or not FileAccess.file_exists(request):
		return
	var tag := FileAccess.get_file_as_string(request).strip_edges().validate_filename()
	DirAccess.remove_absolute(request)
	shot_pending = true
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_jpg(directory.path_join(tag + ".jpg"), 0.86)
	shot_pending = false

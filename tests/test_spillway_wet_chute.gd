extends SceneTree
## p / actual-level wet/dry comparison. one placed spawn on a labelled matching dry
## run-up fixture, then only W and crouch. water uses main's feet-in-AABB rule.
## usable with the frozen r11 pack too; do not infer route completion from this fixture.
var level: Node3D
var player: CharacterBody3D
var caption: Label
var output := ""
var wet := true
var capture := false
var version := ""
var trace: FileAccess
var held: Dictionary = {}
var a := Vector3.ZERO
var b := Vector3.ZERO
var mark := 0
var entry_speed := -1.0
var water_ticks := 0
var samples: Array = []
const MARKS: Array[float] = [.5, -4, -8, -12, -16, -20, -22]

func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	run.call_deferred()

func action(key: String, pressed: bool) -> void:
	if bool(held.get(key, false)) == pressed:
		return
	var event := InputEventAction.new()
	event.action = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	held[key] = pressed

func sample(tick: int) -> Dictionary:
	var pos := player.global_position
	return {"tick": tick, "engine_frame": Engine.get_physics_frames(), "keys": held.duplicate(),
		"yaw": float(player.get("yaw")), "position": [pos.x, pos.y, pos.z],
		"local_z": pos.z - a.z, "speed": float(player.call("get_speed")),
		"mode": str(player.get("mode")), "water": bool(player.get("in_water")), "floor": player.is_on_floor()}

func run() -> void:
	output = OS.get_environment("WET_PROBE_DIR")
	wet = OS.get_environment("WET_PROBE_DRY") != "1"
	capture = OS.get_environment("WET_PROBE_FRAMES") == "1" and DisplayServer.get_name() != "headless"
	version = OS.get_environment("WET_PROBE_VERSION")
	if not output.is_absolute_path():
		printerr("WET_PROBE_DIR must be an absolute evidence directory")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	trace = FileAccess.open(output.path_join("input.jsonl"), FileAccess.WRITE)
	(load("res://scripts/spillway_main.gd") as GDScript).call("bind_inputs")
	level = load("res://scripts/spillway_level.gd").new()
	root.add_child(level)
	level.call("build")
	var bed := level.find_child("WetSpillwayBed", false, false) as StaticBody3D
	if bed == null:
		printerr("the actual wet spillway collider is missing")
		quit(2)
		return
	var collision := bed.get_child(0) as CollisionShape3D
	var vertices: PackedVector3Array = (collision.shape as ConvexPolygonShape3D).points
	a = bed.global_transform * ((vertices[0] + vertices[1]) * .5)
	b = bed.global_transform * ((vertices[2] + vertices[3]) * .5)
	level.call("_slab", "WetProbeDryRunup", a + Vector3.BACK * 4, Vector2(3.2, 8), .5, "concrete")
	player = load("res://scripts/spillway_player.gd").new()
	root.add_child(player)
	player.call("reset_to", Transform3D(Basis.IDENTITY, a + Vector3(0, .025, 6.5)))
	root.size = Vector2i(960, 540)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(18, 14)
	caption.add_theme_font_size_override("font_size", 17)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 6)
	layer.add_child(caption)
	for i: int in 8:
		await physics_frame
	action("move_forward", true)
	var done := false
	for tick: int in 1500:
		var in_water := false
		for region: Dictionary in level.get("water_regions"):
			in_water = in_water or (region.bounds as AABB).has_point(player.global_position)
		player.set("in_water", wet and in_water)
		if wet and in_water:
			water_ticks += 1
		if player.global_position.z <= a.z + .5:
			action("crouch", true)
			if entry_speed < 0:
				entry_speed = player.call("get_speed")
		await physics_frame
		var row := sample(tick)
		trace.store_line(JSON.stringify(row))
		if mark < MARKS.size() and player.global_position.z <= a.z + MARKS[mark]:
			samples.append(row)
			if capture:
				caption.text = "%s · %s water\nlocal z %.2f m · %.2f m/s · %s · W + crouch\nlabelled actual-chute fixture; added dry run-up, one initial spawn" % [version, "wet" if wet else "disabled", row.local_z, row.speed, row.mode]
				RenderingServer.render_loop_enabled = true
				await RenderingServer.frame_post_draw
				RenderingServer.render_loop_enabled = false
				root.get_texture().get_image().save_png(output.path_join("%02d-z%.0f.png" % [mark, MARKS[mark]]))
			mark += 1
		if player.global_position.z <= a.z - 22:
			done = true
			break
	action("move_forward", false)
	action("crouch", false)
	trace.close()
	var summary := {"version": version, "wet": wet, "finished_local_chute": done, "fixture": "actual wet chute plus matching dry run-up; one initial spawn; no velocity or trajectory writes",
		"chute_a": [a.x, a.y, a.z], "chute_b": [b.x, b.y, b.z], "entry_speed": entry_speed,
		"end_speed": float(player.call("get_speed")), "end_mode": str(player.get("mode")), "water_ticks": water_ticks, "samples": samples}
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	print(JSON.stringify(summary))
	quit(0 if done and entry_speed > 8.4 and (not wet or water_ticks > 60) else 1)

extends SceneTree
## a small labelled ramp fixture, before course authoring. all motion after spawn is input earned.

const PLAYER := preload("res://scripts/r15_source_player.gd")
const PRESETS := preload("res://scripts/r15_presets.gd")
const BINDINGS := preload("res://scripts/spillway_main.gd")
var player: CharacterBody3D
var tick := 0
var running := false
var trace: Array = []
var output := "/tmp/r19-surf-proof"
var results: Array = []
var use_strafe := true
signal completed

class Hook:
	extends Node
	var suite: SceneTree
	var early := false
	func _physics_process(_delta: float) -> void:
		if early:
			suite.early()
		else:
			suite.late()

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func key(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func box(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Runup"
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func wedge(parent: Node3D, z: float) -> void:
	var body := StaticBody3D.new()
	body.name = "SurfRamp_%d" % int(absf(z))
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for end: float in [z, z - 24.0]:
		for xy: Vector2 in [Vector2(0, -5), Vector2(12, -5), Vector2(12, 18), Vector2(0, 0)]:
			points.append(Vector3(xy.x, xy.y, end))
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func run() -> void:
	RenderingServer.render_loop_enabled = false
	BINDINGS.bind_inputs()
	Engine.physics_ticks_per_second = 128
	DirAccess.make_dir_recursive_absolute(output)
	var fixture := Node3D.new()
	root.add_child(fixture)
	box(fixture, Vector3(2, 3, 15), Vector3(8, 6, 30))
	for i: int in 5:
		wedge(fixture, -24.0 * i)
	for is_early: bool in [true, false]:
		var hook := Hook.new()
		hook.suite = self
		hook.early = is_early
		hook.process_physics_priority = -1000 if is_early else 1000
		root.add_child(hook)
	for strafe: bool in [true, false]:
		use_strafe = strafe
		player = PLAYER.new()
		root.add_child(player)
		player.apply_settings(PRESETS.source_settings("server128", {"source_sensitivity": 2.5, "source_fov": 90.0}))
		player.reset_to(Transform3D(Basis.IDENTITY, Vector3(2, 6.01, 20)))
		tick = 0
		trace = []
		running = true
		await completed
		var contact := trace.filter(func(row: Dictionary) -> bool: return row.surf)
		var file := FileAccess.open(output.path_join("strafe.json" if strafe else "released.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(trace))
		file.close()
		results.append({"strafe": strafe, "contact_ticks": contact.size(),
			"entry_speed": contact[0].speed if not contact.is_empty() else 0.0,
			"exit_speed": contact[-1].speed if not contact.is_empty() else 0.0,
			"entry_z": contact[0].p[2] if not contact.is_empty() else 0.0,
			"exit_z": contact[-1].p[2] if not contact.is_empty() else 0.0,
			"grounded_on_ramp": contact.any(func(row: Dictionary) -> bool: return row.grounded),
			"end": trace[-1].p})
		for action: String in ["move_forward", "move_right"]:
			key(action, false)
		root.remove_child(player)
		player.free()
	var passed: bool = int(results[0].contact_ticks) >= 128 and not bool(results[0].grounded_on_ramp)
	passed = passed and float(results[0].entry_z) - float(results[0].exit_z) > 10.0
	passed = passed and float(results[0].exit_speed) > float(results[0].entry_speed) * 0.9
	passed = passed and int(results[0].contact_ticks) > int(results[1].contact_ticks) * 2
	var file := FileAccess.open(output.path_join("RESULT.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"pass": passed, "ramp_slope_degrees": rad_to_deg(atan(1.5)),
		"ramp_normal_y": 1.0 / sqrt(3.25), "walkable_normal": player_settings().sv_walkable_normal,
		"setup": "one reset to the runup; zero velocity seed; fixed W then D action events only; no writes during either episode", "results": results}, "\t"))
	file.close()
	print("surf proof: ", passed, " ", results)
	quit(0 if passed else 1)

func player_settings() -> Dictionary:
	return PRESETS.source_settings("server128", {"source_sensitivity": 2.5, "source_fov": 90.0})

func early() -> void:
	if not running:
		return
	if tick == 8:
		key("move_forward", true)
	if tick == 440:
		key("move_forward", false)
		if use_strafe:
			key("move_right", true)

func late() -> void:
	if not running:
		return
	var motion: Dictionary = player.get_motion_state()
	var contact := false
	for row: Dictionary in motion.contacts:
		if str(row.body).begins_with("SurfRamp") and float((row.normal as Vector3).y) > 0.45 and float((row.normal as Vector3).y) < 0.65:
			contact = true
	trace.append({"tick": tick, "p": [player.position.x, player.position.y, player.position.z],
		"v": [player.velocity.x, player.velocity.y, player.velocity.z], "speed": motion.actual_speed_u,
		"surf": contact, "grounded": player.is_grounded()})
	tick += 1
	if tick >= 1800:
		running = false
		completed.emit()

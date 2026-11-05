extends SceneTree
## labelled visual fixtures, not route-completion evidence. render with Movie Maker.
const MAIN = preload("res://scripts/main.gd")
var world: Node3D
var player: CharacterBody3D
var label: Label
var time: float = 0
var phase: int = -1
var jumped: bool = false
var arms: Node
var audio: Node
var quitting: bool = false
var eye_trace: FileAccess
var fixture_only: int = -1

func _initialize() -> void:
	_run.call_deferred()

func box(center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = center
	world.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	MAIN.bind_inputs()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			fixture_only = int(arg.trim_prefix("--fixture="))
			time = fixture_only * 3.0
		if arg.begins_with("--eye-trace="):
			eye_trace = FileAccess.open(arg.trim_prefix("--eye-trace="), FileAccess.WRITE)
			eye_trace.store_csv_line(["time", "phase", "eye_x", "eye_y", "eye_z", "floor_clearance", "roll_degrees", "move", "low", "left_wrist", "right_wrist", "left_weight", "left_contact_error"])
	world = Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#a6bbc9")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b8c9dc")
	env.ambient_light_energy = .7
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	world.add_child(sun)
	box(Vector3(130, -.5, -25), Vector3(360, 1, 90), Color("#53677b"))
	box(Vector3(30, .5, -6), Vector3(5, 1, .6), Color("#c93932"))
	box(Vector3(150, 1.5, -1), Vector3(6, 3, 2), Color("#c93932"))
	box(Vector3(180.7, 5, -10), Vector3(.4, 10, 30), Color("#c2c7ca"))
	box(Vector3(59.3, 5, -10), Vector3(.4, 10, 30), Color("#c2c7ca"))
	for i: int in 20:
		box(Vector3(-12 + i * 7, 8, -40), Vector3(5, 16, 6), Color("#24364b"))
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	arms = load("res://scripts/arms.gd").new()
	world.add_child(arms)
	arms.attach(player)
	audio = load("res://scripts/audio.gd").new()
	world.add_child(audio)
	audio.attach(player, world)
	audio.set_volume(.8) # match the shipped master-volume default.
	if fixture_only == 10:
		audio.effects_enabled = false
	var effects := CanvasLayer.new()
	effects.layer = 6
	world.add_child(effects)
	var streaks = load("res://scripts/streaks.gd").new()
	streaks.player = player
	effects.add_child(streaks)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 22)
	layer.add_child(label)

func _physics_process(dt: float) -> bool:
	if player == null or quitting:
		return false
	time += dt
	var next: int = int(time / 3)
	if next > (10 if fixture_only == 10 else 9) or (fixture_only >= 0 and next > fixture_only):
		quitting = true
		_finish.call_deferred()
		return false
	if next != phase:
		phase = next
		jumped = false
		Input.action_release("move_forward")
		Input.action_release("crouch")
		var positions: Array[Vector3] = [Vector3(0, .9, 0), Vector3(30, .9, 0), Vector3(60, 2.0, 0), Vector3(90, 4.9, 0), Vector3(120, .9, 0), Vector3(150, 2.0, .4), Vector3(180, 2.0, 0), Vector3(210, .9, 0), Vector3(240, .9, 0), Vector3(270, 6.9, 0), Vector3(0, .9, 0)]
		player.reset_to(Transform3D(Basis.IDENTITY, positions[phase]))
		player.look(0, -1.35 if phase == 8 else (.30 if phase == 5 else (-.13 if phase != 3 else -.28)))
		label.text = ["jump: original hands enter on takeoff", "vault: hands follow the actual red rail", "wall run: left contact, corrected Godot bank", "landing: normal impact and body recovery", "roll: safe retargeted eye, recovered root travel", "grab: two separate planted hands", "wall run: right contact, corrected Godot bank", "turn: angular-rate lazy spring", "look down: articulated legs and shoes", "hard landing: impact, release and ten-frame body recovery", "wind isolation: steady 7.2 m/s, effects muted"][phase]
		print("visual fixture ", phase, " begins at movie t=", time)
	var t: float = fmod(time, 3)
	match phase:
		10:
			Input.action_press("move_forward")
			if not jumped:
				player.velocity = Vector3(0, 0, -7.2)
				jumped = true
		0:
			Input.action_press("move_forward")
			if t > .65 and not jumped:
				player.queue_jump()
				jumped = true
		1:
			Input.action_press("move_forward")
		2:
			Input.action_press("move_forward")
			if not jumped:
				player.velocity = Vector3(0, 1, -6)
				player._jump_origin = player.position
				player.wall.start(player, Vector3.RIGHT, -1)
				jumped = true
		4:
			if not jumped:
				player.move = player.Move.ROLL
				player._crouched = true
				player.landing.kind = "roll"
				player.landing.time = 0
				player.landing.forward = Vector3.FORWARD
				player._set_low(true, false)
				jumped = true
		5:
			if not jumped:
				player.ledge.start(player, {"top": Vector3(150, 3, 0), "into": Vector3.FORWARD})
				jumped = true
			if t > 1.3:
				Input.action_press("move_forward")
		6:
			Input.action_press("move_forward")
			if not jumped:
				player.velocity = Vector3(0, 1, -6)
				player._jump_origin = player.position
				player.wall.start(player, Vector3.LEFT, 1)
				jumped = true
		7:
			Input.action_press("move_forward")
			if t > 1 and t < 1.35:
				player.look(dt * 6, 0)
		3:
			Input.action_press("move_forward")
			if t > 2 and not jumped:
				player.look(0, -.9)
				jumped = true
	return false

func _process(_dt: float) -> bool:
	if eye_trace != null and player != null:
		var eye: Vector3 = player.get_camera().global_position
		var probe: Vector3 = player.global_position + player.up_direction * .1
		var hit: Dictionary = player._ray(probe, probe - player.up_direction * 15)
		var clearance: float = (eye - Vector3(hit.position)).dot(player.up_direction) if not hit.is_empty() else -100
		eye_trace.store_csv_line([time, phase, eye.x, eye.y, eye.z, clearance, rad_to_deg(player._roll), player.move, player.is_low(), arms._arms[0].wrist, arms._arms[1].wrist, player.get_hand_weight(-1), arms._arms[0].hand.global_position.distance_to(player.get_hand_target(-1)) if player.get_hand_target(-1).is_finite() else -1])
	return false

func _finish() -> void:
	audio.stop_all()
	for i: int in 8:
		await process_frame
	quit()

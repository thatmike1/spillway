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
	MAIN.bind_inputs()
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
	box(Vector3(40, -.5, -25), Vector3(120, 1, 90), Color("#53677b"))
	box(Vector3(30, .5, -6), Vector3(5, 1, .6), Color("#c93932"))
	box(Vector3(59.3, 5, -10), Vector3(.4, 10, 30), Color("#c2c7ca"))
	for i: int in 20:
		box(Vector3(-12 + i * 7, 8, -40), Vector3(5, 16, 6), Color("#24364b"))
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	arms = load("res://scripts/arms.gd").new()
	world.add_child(arms)
	arms.attach(player)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 22)
	layer.add_child(label)

func _physics_process(dt: float) -> bool:
	if player == null:
		return false
	time += dt
	var next: int = int(time / 3)
	if next > 3:
		quit(0)
		return false
	if next != phase:
		phase = next
		jumped = false
		Input.action_release("move_forward")
		Input.action_release("crouch")
		var positions: Array[Vector3] = [Vector3(0, .9, 0), Vector3(30, .9, 0), Vector3(60, 2.0, 0), Vector3(90, 4.9, 0)]
		player.reset_to(Transform3D(Basis.IDENTITY, positions[phase]))
		player.look(0, -.13 if phase != 3 else -.28)
		label.text = ["jump: original hands enter on takeoff", "vault: hands follow the actual red rail", "wall run: left contact, +17.814 degree bank", "landing: normal impact and body recovery"][phase]
		print("visual fixture ", phase, " begins at movie t=", time)
	var t: float = fmod(time, 3)
	match phase:
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
		3:
			Input.action_press("move_forward")
			if t > 2 and not jumped:
				player.look(0, -.9)
				jumped = true
	return false

extends SceneTree
## input, gravity-surface and projection regressions. numeric movement lives in test_spec_*.

const MAIN_SCRIPT: Script = preload("res://scripts/main.gd")

var failures: int = 0
var checks: int = 0
var fixture: Node3D
var player: CharacterBody3D


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func ticks(count: int) -> void:
	for index: int in count:
		await physics_frame


func box(center: Vector3, size: Vector3, gravity: bool = false, parent: Node3D = null) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = center
	if gravity:
		body.set_meta("gravity_surface", true)
	(parent if parent != null else fixture).add_child(body)
	return body


func fresh(spawn: Vector3, yaw: float = 0.0) -> void:
	if fixture != null:
		fixture.queue_free()
		await process_frame
	release_all()
	fixture = Node3D.new()
	root.add_child(fixture)
	player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	fixture.add_child(player)
	player.call("reset_to", Transform3D(Basis(Vector3.UP, yaw), spawn), Vector3.UP)


func release_all() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "look_left", "look_right", "look_up", "look_down"]:
		Input.action_release(action)


func press_jump() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = "jump"
	event.pressed = true
	Input.parse_input_event(event)


func _run() -> void:
	MAIN_SCRIPT.call("bind_inputs")
	await _test_look()
	await _test_gravity_surface()
	_test_fov()
	release_all()
	print("player: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _test_look() -> void:
	await fresh(Vector3(0, 1.5, 0))
	box(Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	await ticks(10)
	# headless has no mouse capture at all: look must still answer to motion
	var before: Vector3 = -player.global_basis.z
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(200, 0)
	motion.screen_relative = Vector2(200, 0)
	Input.parse_input_event(motion)
	await ticks(2)
	var after: Vector3 = -player.global_basis.z
	var expected: float = 200.0 * float(player.get("mouse_sensitivity"))
	check(absf(before.angle_to(after) - expected) < 0.01, "mouse motion turns the view by sensitivity x pixels")
	check(before.signed_angle_to(after, Vector3.UP) < 0.0, "moving the mouse right turns right")
	var pitch_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	pitch_motion.screen_relative = Vector2(0, -5000)
	pitch_motion.relative = Vector2(0, -5000)
	Input.parse_input_event(pitch_motion)
	await ticks(2)
	check(absf(float(player.call("get_pitch")) - deg_to_rad(88.0)) < 0.001, "pitch clamps short of straight up")
	var camera: Camera3D = player.call("get_camera")
	await process_frame
	check((-camera.global_basis.z).dot(Vector3.UP) > 0.95, "camera follows the pitch")
	var yaw_before: Vector3 = -player.global_basis.z
	Input.action_press("look_left")
	await ticks(60)
	Input.action_release("look_left")
	check(yaw_before.signed_angle_to(-player.global_basis.z, Vector3.UP) > 0.5, "arrow keys turn the view")
	player.call("set_controls_enabled", false)
	var frozen: Vector3 = -player.global_basis.z
	Input.parse_input_event(motion)
	await ticks(2)
	check(frozen.is_equal_approx(-player.global_basis.z), "no look while paused")


func _test_gravity_surface() -> void:
	# a quarter pipe of chord slabs into a wall, all tagged as gravity surfaces
	await fresh(Vector3(0, 1.5, 6))
	box(Vector3(0, -0.5, 6), Vector3(8, 1, 12))
	var center: Vector3 = Vector3(0, 5, 0)
	var radius: float = 5.0
	var steps: int = 12
	var pipe: Node3D = Node3D.new()
	fixture.add_child(pipe)
	for index: int in range(steps):
		var angle: float = (float(index) + 0.5) / float(steps) * PI * 0.5
		var half: float = PI * 0.25 / float(steps)
		var normal: Vector3 = Vector3(0, cos(angle), sin(angle))
		var tangent: Vector3 = Vector3(0, sin(angle), -cos(angle))
		var point: Vector3 = center + Vector3(0, -cos(angle), -sin(angle)) * radius * cos(half)
		var slab: StaticBody3D = box(Vector3.ZERO, Vector3(8, 1, 2.0 * radius * sin(half) + 0.02), true, pipe)
		slab.transform = Transform3D(Basis(Vector3.RIGHT, normal, -tangent), point - normal * 0.5)
	box(Vector3(0, 15, -5.5), Vector3(8, 20, 1), true)
	await ticks(20)
	Input.action_press("move_forward")
	var max_turn: float = 0.0
	for index: int in range(720):
		await physics_frame
		max_turn = maxf(max_turn, player.up_direction.angle_to(Vector3.UP))
		if player.global_position.y > 12.0:
			break
	check(max_turn > deg_to_rad(85.0), "up turns to the wall's normal (%.0f deg)" % rad_to_deg(max_turn))
	check(player.global_position.y > 8.0, "runs up the wall (y %.1f)" % player.global_position.y)
	check(player.velocity.dot(Vector3.UP) > 6.0, "momentum is redirected up the wall, not lost")
	Input.action_release("move_forward")
	# an ordinary wall never captures gravity
	await fresh(Vector3(0, 1.5, 0))
	box(Vector3(0, -0.5, 0), Vector3(10, 1, 20))
	box(Vector3(0, 3, -6), Vector3(10, 6, 1))
	await ticks(20)
	Input.action_press("move_forward")
	await ticks(180)
	check(player.up_direction.is_equal_approx(Vector3.UP), "an untagged wall keeps world up")
	Input.action_release("move_forward")


func _test_fov() -> void:
	var player_script: Script = load("res://scripts/player.gd")
	var vertical: float = float(player_script.call("vertical_fov", 90.0))
	check(absf(vertical - 58.72) < 0.1, "90 degrees at 16:9 is 58.7 vertical (%.2f)" % vertical)
	# the camera keeps height, so a 21:9 screen shows more to the sides, not less above
	var half_v: float = deg_to_rad(vertical) * 0.5
	var wide: float = rad_to_deg(2.0 * atan(tan(half_v) * 21.0 / 9.0))
	check(wide > 104.0 and wide < 107.0, "21:9 widens to about 105 horizontal (%.1f)" % wide)
	var camera: Camera3D = player.call("get_camera")
	check(camera.keep_aspect == Camera3D.KEEP_HEIGHT, "camera keeps height for ultrawide")

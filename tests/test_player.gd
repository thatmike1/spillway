extends SceneTree
## Player movement on small fixtures with real physics: momentum, jump, coyote
## time, mouse/keyboard look without mouse capture, vault, climb, slide,
## wall-run and gravity surfaces. Feel is not tested here; numbers are.

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
	await _test_ground_and_momentum()
	await _test_jump_and_coyote()
	await _test_look()
	await _test_vault_and_climb()
	await _test_slide()
	await _test_wallrun()
	await _test_gravity_surface()
	_test_fov()
	release_all()
	print("player: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _test_ground_and_momentum() -> void:
	await fresh(Vector3(0, 1.5, 0))
	box(Vector3(0, -0.5, -100), Vector3(40, 1, 240))
	await ticks(60)
	check(player.is_on_floor(), "settles on the floor")
	check(absf(player.global_position.y - 0.9) < 0.05, "capsule stands 0.9 above the floor")
	Input.action_press("move_forward")
	await ticks(60)
	var early: float = float(player.call("get_speed"))
	check(early > 5.5 and early < 7.6, "half a second in, speed is near base (%.2f)" % early)
	await ticks(300)
	var late: float = float(player.call("get_speed"))
	check(late > 9.2, "holding forward builds to top speed (%.2f)" % late)
	check(float(player.get("momentum")) > 0.95, "momentum fills")
	Input.action_release("move_forward")
	await ticks(90)
	check(float(player.call("get_speed")) < 0.5, "stops when input is released")


func _test_jump_and_coyote() -> void:
	await fresh(Vector3(0, 1.5, 0))
	box(Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	await ticks(40)
	var start_y: float = player.global_position.y
	press_jump()
	var apex: float = start_y
	for index: int in range(120):
		await physics_frame
		apex = maxf(apex, player.global_position.y)
	check(apex - start_y > 1.0 and apex - start_y < 1.6, "jump apex is about a body height (%.2f)" % (apex - start_y))
	check(player.is_on_floor(), "lands again")
	# coyote time: run off an edge and jump a moment later
	await fresh(Vector3(0, 1.5, 0))
	box(Vector3(0, -0.5, 0), Vector3(4, 1, 6))
	await ticks(30)
	Input.action_press("move_forward")
	var left_edge_tick: int = -1
	var jumps: Array[int] = []
	player.connect("jumped", func() -> void: jumps.append(1))
	for index: int in range(240):
		await physics_frame
		if left_edge_tick < 0 and not player.is_on_floor() and player.global_position.z < -3.0:
			left_edge_tick = index
		if left_edge_tick >= 0 and index == left_edge_tick + 6:
			press_jump()
		if not jumps.is_empty():
			break
	check(not jumps.is_empty(), "a jump pressed just after leaving the edge still fires")
	Input.action_release("move_forward")


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


func _test_vault_and_climb() -> void:
	await fresh(Vector3(0, 1.5, 0))
	box(Vector3(0, -0.5, -20), Vector3(10, 1, 50))
	box(Vector3(0, 0.5, -10), Vector3(6, 1.0, 0.6))
	var kinds: Array[String] = []
	player.connect("move_started", func(kind: String) -> void: kinds.append(kind))
	await ticks(20)
	Input.action_press("move_forward")
	await ticks(240)
	check(kinds.has("vault"), "running into a waist-high rail vaults it")
	check(player.global_position.z < -12.0, "ends up past the rail (z %.1f)" % player.global_position.z)
	check(float(player.call("get_speed")) > 6.0, "keeps speed through the vault")
	Input.action_release("move_forward")
	# a high ledge reached from a jump is climbed, not bounced off
	await fresh(Vector3(0, 1.5, 0))
	box(Vector3(0, -0.5, 0), Vector3(10, 1, 20))
	box(Vector3(0, 0.85, -8), Vector3(10, 1.7, 4))
	var climbs: Array[String] = []
	player.connect("move_started", func(kind: String) -> void: climbs.append(kind))
	await ticks(20)
	Input.action_press("move_forward")
	for index: int in range(240):
		await physics_frame
		if player.global_position.z < -3.6 and player.is_on_floor() and climbs.is_empty() and float(player.get("_since_jump")) > 0.5:
			press_jump()
		if not climbs.is_empty() and int(player.get("move")) != 3:
			Input.action_release("move_forward")
	check(climbs.has("climb"), "jumping at a chest-high ledge climbs it")
	check(player.global_position.y > 2.0, "stands on top of the ledge (y %.2f)" % player.global_position.y)
	Input.action_release("move_forward")


func _test_slide() -> void:
	await fresh(Vector3(0, 1.5, 0))
	box(Vector3(0, -0.5, -40), Vector3(10, 1, 100))
	await ticks(20)
	Input.action_press("move_forward")
	await ticks(200)
	Input.action_press("crouch")
	await ticks(10)
	check(int(player.get("move")) == 4, "crouch at speed starts a slide")
	check(bool(player.call("is_low")), "slide lowers the body")
	var collider: CollisionShape3D = player.get_node("CollisionShape3D")
	check(((collider.shape as CapsuleShape3D).height) < 1.2, "slide shortens the capsule")
	Input.action_release("crouch")
	await ticks(90)
	check(int(player.get("move")) != 4 and not bool(player.call("is_low")), "releasing crouch stands back up")
	Input.action_release("move_forward")


func _test_wallrun() -> void:
	await fresh(Vector3(0, 1.5, 0))
	box(Vector3(0, -0.5, 0), Vector3(10, 1, 12))
	box(Vector3(-1.25, 3, -18), Vector3(0.4, 8, 26))
	var kinds: Array[String] = []
	player.connect("move_started", func(kind: String) -> void: kinds.append(kind))
	await ticks(20)
	Input.action_press("move_forward")
	var lowest_during: float = 100.0
	for index: int in range(300):
		await physics_frame
		if player.global_position.z < -5.2 and player.is_on_floor() and kinds.is_empty():
			press_jump()
		if int(player.get("move")) == 2:
			lowest_during = minf(lowest_during, player.global_position.y)
	check(kinds.has("wallrun"), "jumping along a wall starts a wall-run")
	check(lowest_during > 0.9, "the wall-run holds height above the floor level")
	Input.action_release("move_forward")


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
	for index: int in range(360):
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

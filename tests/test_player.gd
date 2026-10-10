extends SceneTree

class TransportFixture extends AnimatableBody3D:
	var linear_speed: float = 0.0
	var turn_rate: float = 0.0
	var distance: float = 0.0
	var turn: float = 0.0
	var start: Transform3D
	func _ready() -> void:
		process_physics_priority = -50
		start = transform
	func _physics_process(delta: float) -> void:
		distance += linear_speed * delta
		turn += turn_rate * delta
		transform = Transform3D(Basis(Vector3.BACK, turn) * start.basis, start.origin + Vector3(distance, 0, 0))

var failures: int = 0
var checks: int = 0
var player: CharacterBody3D
var fixture: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func ticks(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func box(position: Vector3, size: Vector3, moving: bool = false) -> PhysicsBody3D:
	var body: PhysicsBody3D = TransportFixture.new() if moving else StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	fixture.add_child(body)
	return body

func _run() -> void:
	for action: String in ["move_left", "move_right", "move_forward", "move_back", "jump", "sprint", "crouch"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	fixture = Node3D.new()
	root.add_child(fixture)
	var floor_body: PhysicsBody3D = box(Vector3(0, -0.5, 0), Vector3(100, 1, 100))
	player = load("res://scenes/player.tscn").instantiate()
	fixture.add_child(player)
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(0, 2, 0)))
	await ticks(45)
	check(player.is_on_floor(), "Player settles on actual collision floor")
	check(absf(player.position.y - 0.9) < 0.05, "Capsule settles at standing height")
	Input.action_press("move_forward")
	await ticks(35)
	check(player.position.z < -3.0, "Forward input moves through physics")
	check(absf(float(player.call("get_speed")) - 8.0) < 0.1, "Normal speed reaches configured 8m/s")
	Input.action_press("sprint")
	await ticks(30)
	check(absf(float(player.call("get_speed")) - 13.0) < 0.1, "Sprint reaches configured 13m/s")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await ticks(25)
	var grounded_y: float = player.position.y
	player.call("queue_jump")
	await ticks(10)
	check(player.position.y > grounded_y + 0.7, "Jump separates from floor under real physics")
	check(not player.is_on_floor(), "Jump clears grounded state")
	await ticks(55)
	Input.action_press("crouch")
	await ticks(2)
	var capsule: CapsuleShape3D = player.get_node("CollisionShape3D").shape
	check(is_equal_approx(capsule.height, 1.1), "Crouch resizes collision capsule")
	var ceiling: PhysicsBody3D = box(player.position + Vector3(0, 0.65, 0), Vector3(3, 0.2, 3))
	await ticks(2)
	Input.action_release("crouch")
	await ticks(2)
	check(is_equal_approx(capsule.height, 1.1), "Crouch refuses to stand inside solid ceiling")
	ceiling.queue_free()
	await ticks(3)
	check(is_equal_approx(capsule.height, 1.8), "Standing restores capsule")
	player.call("set_gravity", Vector3.ZERO)
	check(player.up_direction.is_finite(), "Invalid zero gravity direction cannot poison orientation")
	player.call("set_gravity", Vector3.RIGHT, 0.0)
	await ticks(60)
	check(player.up_direction.dot(Vector3.RIGHT) > 0.99, "Arbitrary gravity smoothly aligns body to world X")
	check(player.global_basis.is_finite() and player.velocity.is_finite(), "Gravity transition preserves finite body state")
	player.call("set_gravity", Vector3.LEFT, 0.0)
	await ticks(60)
	check(player.up_direction.dot(Vector3.LEFT) > 0.99, "Antipodal gravity transition remains valid")
	player.call("set_gravity", Vector3.DOWN, 0.0)
	player.set("comfort_roll", 0.5)
	await ticks(60)
	var camera: Camera3D = player.call("get_camera")
	check(camera.global_basis.is_finite() and absf(camera.global_basis.determinant() - 1.0) < 0.01, "Midpoint comfort roll remains valid on inverted gravity")
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(10, 2, 10)))
	check(player.velocity == Vector3.ZERO, "Reset immediately zeroes world velocity")
	check(player.up_direction.dot(Vector3.UP) > 0.99, "Reset restores up")
	check(is_equal_approx(float(player.get("gravity_strength")), 22.0), "Reset restores spawn gravity strength after gravity changes")
	check(not bool(player.get("wall_running")) and not bool(player.get("vaulting")), "Reset clears traversal modes")
	await ticks(40)
	player.call("teleport_state", Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(0, 10, 0)), Vector3(0, 0, -12), Vector3.RIGHT)
	check(player.velocity.is_equal_approx(Vector3(0, 0, -12)), "Portal handoff preserves mapped world velocity")
	check(player.up_direction.dot(Vector3.RIGHT) > 0.99, "Portal handoff snaps mapped up")
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)))
	await ticks(30)
	player.call("set_controls_enabled", false)
	Input.action_press("move_forward")
	await ticks(20)
	check(float(player.call("get_speed")) < 0.01, "Disabled controls cannot move body")
	Input.action_release("move_forward")
	player.call("set_controls_enabled", true)
	# Low obstacle at player's forward edge: vault must climb with collisions enabled.
	var obstacle: PhysicsBody3D = box(Vector3(0, 0.45, -1.15), Vector3(3, 0.9, 1.2))
	await ticks(3)
	player.call("queue_jump")
	await ticks(1)
	check(bool(player.get("vaulting")), "Vault detects real low obstacle and clear top")
	await ticks(30)
	check(player.position.z < -0.8 and player.position.y > 1.65, "Collision-swept vault lands on obstacle")
	obstacle.queue_free()
	await ticks(2)
	# Floor-following fixture, driven during physics frames; no manual platform velocity.
	floor_body.queue_free()
	var platform: PhysicsBody3D = box(Vector3(0, -0.5, 0), Vector3(8, 1, 8), true)
	platform.set_meta("traversal_up", true)
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(1, 1, 0)))
	await ticks(35)
	check(player.is_on_floor(), "Player stands on actual AnimatableBody3D fixture")
	var start_x: float = player.position.x
	platform.set("linear_speed", 1.5)
	await ticks(30)
	platform.set("linear_speed", 0.0)
	check(absf((player.position.x - start_x) - 0.75) < 0.12, "Moving platform displacement applied once")
	platform.set("turn_rate", 0.24)
	await ticks(60)
	platform.set("turn_rate", 0.0)
	check(player.up_direction.dot(platform.global_basis.y) > 0.98, "Grounded player follows rotating traversal support up")
	check(player.global_transform.is_finite() and player.velocity.is_finite(), "Rotating support produces finite state")
	# Wall-running requires a lateral wall, airborne forward momentum and sprint.
	platform.queue_free()
	box(Vector3(0.75, 4, -5), Vector3(0.2, 12, 30))
	player.call("teleport_state", Transform3D(Basis.IDENTITY, Vector3(0, 4, 0)), Vector3(0, 0, -8), Vector3.UP)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await ticks(4)
	check(bool(player.get("wall_running")), "Airborne sprint detects physical lateral wall")
	player.call("queue_jump")
	await ticks(2)
	check(player.velocity.x < -1.0 and player.velocity.y > 5.0, "Wall jump pushes away from wall and upward")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	check(player.call("get_camera") is Camera3D, "Public camera method returns valid camera")
	fixture.queue_free()
	await ticks(2)
	print("PLAYER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

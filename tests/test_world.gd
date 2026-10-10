extends SceneTree

const FOLD_SCRIPT: Script = preload("res://scripts/folding_sector.gd")
const ZONE_SCRIPT: Script = preload("res://scripts/gravity_zone.gd")
const SEAM_SCRIPT: Script = preload("res://scripts/portal_seam.gd")

var _failures: int = 0
var _checks: int = 0

class Traveler extends Node3D:
	var velocity: Vector3 = Vector3.ZERO
	var up_direction: Vector3 = Vector3.UP
	var teleport_count: int = 0

	func teleport_state(destination: Transform3D, mapped_velocity: Vector3, mapped_up: Vector3) -> void:
		global_transform = destination
		velocity = mapped_velocity
		up_direction = mapped_up
		teleport_count += 1

class PlatformRider extends CharacterBody3D:
	var platform: AnimatableBody3D

	func _physics_process(delta: float) -> void:
		up_direction = platform.global_basis.y.normalized()
		if is_on_floor():
			velocity = Vector3.ZERO
		else:
			velocity -= up_direction * 22.0 * delta
		move_and_slide()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_fold()
	await _test_rotating_rider()
	_test_gravity()
	_test_portal()
	print("World invariants: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_fold() -> void:
	var fold: AnimatableBody3D = FOLD_SCRIPT.new()
	fold.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	fold.position = Vector3(3.0, 4.0, -14.0)
	fold.set("duration", 0.1)
	root.add_child(fold)
	var original: Transform3D = fold.transform
	var corner: Vector3 = Vector3(0.0, 0.0, -12.0)
	var completions: Array[int] = [0]
	fold.connect("fold_completed", func() -> void: completions[0] += 1)
	fold.call("start_fold")
	for index: int in range(12):
		await physics_frame
	_check(not bool(fold.call("is_folding")), "Fold completes in live physics ticks")
	_check(completions[0] == 1, "Completion emitted once")
	var expected: Basis = original.basis * Basis(Vector3.RIGHT, PI / 2.0)
	_check(fold.basis.is_equal_approx(expected), "Fold honors authored initial rotation and local axis")
	_check(fold.position.is_equal_approx(original.origin), "Hinge remains fixed")
	_check((fold.transform * corner - fold.position).length() > 11.999, "Rigid fold preserves point distance")
	_check((fold.call("get_surface_up") as Vector3).is_equal_approx(Vector3.UP), "Fold surface normal follows collision basis")
	_check(bool(fold.get_meta("traversal_up", false)), "Grounded support advertises local up")
	fold.call("start_fold")
	await physics_frame
	_check(completions[0] == 1, "Completed fold cannot restart without reset")
	fold.call("reset_fold")
	await physics_frame
	await physics_frame
	_check(fold.transform.is_equal_approx(original), "Reset restores complete initial transform")
	_check(is_zero_approx(float(fold.call("get_progress"))), "Reset clears elapsed progress")
	fold.free()


func _test_rotating_rider() -> void:
	var fold: AnimatableBody3D = FOLD_SCRIPT.new()
	fold.position = Vector3(200.0, 0.0, 0.0)
	fold.set("duration", 0.7)
	fold.set("fold_angle", PI / 9.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var slab: BoxShape3D = BoxShape3D.new()
	slab.size = Vector3(8.0, 0.4, 8.0)
	collision.shape = slab
	collision.position = Vector3(0.0, -0.2, -2.0)
	fold.add_child(collision)
	root.add_child(fold)
	var rider: PlatformRider = PlatformRider.new()
	rider.platform = fold
	rider.position = fold.position + Vector3(0.0, 0.3, -2.0)
	rider.floor_snap_length = 0.3
	var body_collision: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.25
	body_collision.shape = sphere
	rider.add_child(body_collision)
	root.add_child(rider)
	for index: int in range(12):
		await physics_frame
	_check(rider.is_on_floor(), "Rider settles on fold collision")
	var initial_local: Vector3 = fold.global_transform.affine_inverse() * rider.global_position
	fold.call("start_fold")
	for index: int in range(55):
		await physics_frame
	var final_local: Vector3 = fold.global_transform.affine_inverse() * rider.global_position
	_check(rider.is_on_floor(), "Godot transport keeps rider grounded through rigid rotation")
	_check(final_local.distance_to(initial_local) < 0.2, "Physics-synchronized fold transports rider without doubled platform velocity")
	_check(rider.global_position.y > 0.75, "Rotation actually carries rider upward")
	rider.free()
	fold.free()


func _test_gravity() -> void:
	var zone: Area3D = ZONE_SCRIPT.new()
	zone.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	zone.set("local_up", Vector3.UP * 7.0)
	zone.priority = 5.0
	root.add_child(zone)
	_check((zone.call("get_world_up") as Vector3).is_equal_approx(Vector3.BACK), "Zone converts arbitrary local gravity into normalized world up")
	_check(zone.is_in_group("gravity_zone"), "Zone registers deterministic-query group")
	_check(zone.priority == 5.0 and zone.monitoring, "Zone retains authored priority and enables overlap monitoring")
	_check(zone.gravity_space_override == Area3D.SPACE_OVERRIDE_DISABLED, "Zone does not double-integrate body gravity")
	zone.set("local_up", Vector3.ZERO)
	_check((zone.call("get_world_up") as Vector3).is_equal_approx(Vector3.UP), "Degenerate authored gravity has safe fallback")
	zone.free()


func _test_portal() -> void:
	var entry: Node3D = SEAM_SCRIPT.new()
	var exit_node: Node3D = SEAM_SCRIPT.new()
	entry.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.0, 10.0, -30.0))
	exit_node.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(80.0, 2.0, -50.0))
	root.add_child(entry)
	root.add_child(exit_node)
	entry.set_physics_process(false)
	exit_node.set_physics_process(false)
	entry.set("exit_seam", exit_node)
	exit_node.set("exit_seam", entry)
	var traveler: Traveler = Traveler.new()
	root.add_child(traveler)
	var before: Vector3 = entry.global_transform * Vector3(0.0, 0.0, 8.0)
	var after: Vector3 = entry.global_transform * Vector3(0.0, 0.0, -9.0)
	traveler.global_transform = Transform3D(entry.global_basis, after)
	traveler.velocity = entry.global_basis * Vector3(2.0, 1.0, -13.0)
	traveler.up_direction = entry.global_basis.y
	var speed: float = traveler.velocity.length()
	var source_transform: Transform3D = traveler.global_transform
	var mapped: Transform3D = entry.call("map_transform", source_transform)
	var exit_local: Vector3 = exit_node.global_transform.affine_inverse() * mapped.origin
	_check(exit_local.is_equal_approx(Vector3(0.0, 0.0, 9.0)), "Portal preserves residual swept distance on exit front")
	var round_trip: Transform3D = exit_node.call("map_transform", mapped)
	_check(round_trip.is_equal_approx(source_transform), "Reciprocal mapping restores full pose")
	_check(is_equal_approx((entry.call("map_velocity", traveler.velocity) as Vector3).length(), speed), "Rigid seam preserves momentum magnitude")
	_check((entry.call("map_up", traveler.up_direction) as Vector3).is_equal_approx(exit_node.global_basis.y), "Upside-down entry becomes exit local up")
	_check(bool(entry.call("crosses_rectangle", before, after)), "Fast segment crosses portal despite ending far away")
	_check(not bool(entry.call("crosses_rectangle", after, before)), "Back-to-front traversal is rejected")
	var outside_before: Vector3 = entry.global_transform * Vector3(2.0, 0.0, 8.0)
	var outside_after: Vector3 = entry.global_transform * Vector3(2.0, 0.0, -9.0)
	_check(not bool(entry.call("crosses_rectangle", outside_before, outside_after)), "Outside rectangle cannot teleport")
	_check(bool(entry.call("try_crossing", traveler, before, after)), "Swept crossing teleports atomically")
	_check(traveler.global_transform.is_equal_approx(mapped) and traveler.teleport_count == 1, "Teleport applies mapped body pose once")
	_check(is_equal_approx(traveler.velocity.length(), speed), "Runtime teleport preserves speed")
	_check(traveler.up_direction.is_equal_approx(exit_node.global_basis.y), "Runtime teleport maps physical gravity")
	_check(not bool(entry.call("try_crossing", traveler, before, after)), "Source cooldown prevents repeat teleport")
	var exit_before: Vector3 = exit_node.global_transform * Vector3(0.0, 0.0, 2.0)
	var exit_after: Vector3 = exit_node.global_transform * Vector3(0.0, 0.0, -2.0)
	_check(not bool(exit_node.call("try_crossing", traveler, exit_before, exit_after)), "Destination cooldown prevents immediate ping-pong")
	entry.call("reset_seam")
	exit_node.call("reset_seam")
	traveler.global_transform = source_transform
	_check(bool(entry.call("try_crossing", traveler, before, after)), "Reset clears cooldown and traversal history")
	entry.call("reset_seam")
	exit_node.scale = Vector3(2.0, 2.0, 2.0)
	_check(not bool(entry.call("try_crossing", traveler, before, after)), "Scaled portal is rejected to preserve rigid momentum contract")
	traveler.free()
	entry.free()
	exit_node.free()


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)

extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var city: Node3D = load("res://scripts/city_builder.gd").new() as Node3D
	root.add_child(city)
	var layout: Dictionary = city.call("build")
	_check(layout.size() >= 6, "Layout contract exists")
	for key: String in ["spawn", "finish", "checkpoint", "fold", "entry_seam", "exit_seam", "fold_trigger", "checkpoint_trigger", "finish_trigger"]:
		_check(layout.has(key), "Required route key: " + key)
	var bounds: AABB = layout["route_bounds"]
	for key: String in ["spawn", "finish", "checkpoint"]:
		var marker: Transform3D = layout[key]
		_check(marker.origin.is_finite() and bounds.has_point(marker.origin), key + " inside finite route bounds")
	var fold: AnimatableBody3D = layout["fold"]
	_check(fold.position.is_equal_approx(Vector3(0, 0, -14)), "Fold has intended architectural hinge")
	_check((fold.basis * Vector3.UP).is_equal_approx(Vector3.FORWARD), "Initial bridge is vertical facade")
	var final_basis: Basis = fold.basis * Basis(Vector3.RIGHT, float(fold.get("fold_angle")))
	_check((final_basis * Vector3.UP).is_equal_approx(Vector3.UP), "Fold ends with traversable upward normal")
	for gap: float in layout["jump_gaps"]:
		_check(gap <= 5.0 and gap >= 0.0, "Jump gap obeys movement budget")
	var bridge_shape: CollisionShape3D = fold.get_child(1) as CollisionShape3D
	_check(bridge_shape != null and (bridge_shape.shape as BoxShape3D).size.z == 12.0, "Bridge collider has twelve-meter span")
	var zones: Array = layout["gravity_zones"]
	_check(zones.size() == 13, "All twelve arc panels and ceiling have gravity zones")
	_check((zones[0] as Area3D).call("get_world_up").dot(Vector3.UP) > 0.98, "Gravity starts near upright")
	_check((zones[-1] as Area3D).call("get_world_up").dot(Vector3.DOWN) > 0.99, "Ceiling gravity points down")
	var entry: Node3D = layout["entry_seam"]
	var exit: Node3D = layout["exit_seam"]
	_check(entry.get("exit_seam") == exit and exit.get("exit_seam") == entry, "Both seams connected")
	_check((entry.basis * Vector3.UP).is_equal_approx(Vector3.DOWN), "Portal aligns with ceiling route")
	_check(city.call("build")["fold"] == fold, "Build is idempotent")
	var packed_player: PackedScene = load("res://scenes/player.tscn") as PackedScene
	var player: CharacterBody3D = packed_player.instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	var fold_trigger: Area3D = layout["fold_trigger"]
	player.global_position = fold_trigger.global_position
	_check((fold_trigger.collision_mask & player.collision_layer) != 0, "Route trigger detects actual player's collision layer")
	for zone: Area3D in zones:
		_check((zone.collision_mask & player.collision_layer) != 0, "Gravity zone detects actual player's collision layer")
	await physics_frame
	await physics_frame
	_check(fold_trigger.overlaps_body(player), "Actual player registers in fold trigger")
	var first_zone: Area3D = zones[0] as Area3D
	player.global_position = first_zone.global_position
	await physics_frame
	await physics_frame
	_check(first_zone.overlaps_body(player), "Actual player registers in gravity zone")
	# Probe actual physics rather than trusting route marker metadata.
	var world: World3D = city.get_world_3d()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(0, 3, 3), Vector3(0, -2, 3))
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	_check(not hit.is_empty(), "Spawn has real collision support")
	query = PhysicsRayQueryParameters3D.create(Vector3(80, 3, 10), Vector3(80, -2, 10))
	hit = world.direct_space_state.intersect_ray(query)
	_check(not hit.is_empty(), "Finish has real collision support")
	for index: int in range(12):
		var panel: Node3D = city.get_node("GravityArc%02d" % index) as Node3D
		var surface: Vector3 = panel.global_position
		var normal: Vector3 = panel.global_basis.y
		query = PhysicsRayQueryParameters3D.create(surface + normal * 0.7, surface - normal * 0.7)
		hit = world.direct_space_state.intersect_ray(query)
		_check(not hit.is_empty(), "Arc panel %d has real collision" % index)
		if not hit.is_empty():
			_check(Vector3(hit["normal"]).dot(normal) > 0.99, "Arc collider and gravity normal agree %d" % index)
	var hud: CanvasLayer = load("res://scripts/hud.gd").new() as CanvasLayer
	root.add_child(hud)
	hud.call("update_state", 13.0, "Reach the far roof", 12.34)
	hud.call("set_paused", true)
	_check((hud.find_child("PausePanel", true, false) as PanelContainer).visible, "Pause menu opens")
	hud.call("set_finished", 25.6)
	hud.call("set_paused", false)
	_check(not (hud.find_child("PausePanel", true, false) as PanelContainer).visible, "Pause menu closes")
	hud.call("set_comfort", 0.2)
	_check(is_equal_approx((hud.find_child("ComfortSlider", true, false) as HSlider).value, 0.2), "Comfort setting applied")
	hud.call("reset_run")
	_check(not (hud.find_child("PausePanel", true, false) as PanelContainer).visible, "Restart hides completion panel")
	city.queue_free()
	hud.queue_free()
	player.queue_free()
	await process_frame
	print("City fixture: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(1 if failures > 0 else 0)

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

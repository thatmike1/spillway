extends SceneTree
## p / physical hardware, supported rails and retained water in the r12 course.
var level: Node3D
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])

func ray(a: Vector3, b: Vector3) -> Dictionary:
	return level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))

func top(at: Vector3, expected: float, label: String) -> void:
	var hit := ray(at + Vector3.UP * 0.5, at - Vector3.UP * 0.5)
	check(not hit.is_empty() and absf(hit.position.y - expected) < .012, label)

func run() -> void:
	level = load("res://scripts/spillway_level.gd").new()
	root.add_child(level)
	level.build()
	await physics_frame
	await physics_frame
	for valve: Array in [[Vector3(-3, 6.22, -37), .45], [Vector3(-36.5, 5.9, -82), .75], [Vector3(-18.5, 5.9, -82), .75], [Vector3(-35, 3.8, -76), .9]]:
		var center: Vector3 = valve[0]
		var radius: float = valve[1]
		for i: int in 16:
			var angle := TAU * (float(i) + .37) / 16.0
			var at := center + Vector3(cos(angle), 0, sin(angle)) * radius * .70
			top(at, center.y + radius * .0375, "valve %s has continuous support at sector %d" % [center, i])
	top(Vector3(-27.5, 7.25, -82), 7.25, "yard gate top beam supports the capsule")
	top(Vector3(2.5, 13.16, -13), 13.16, "drying frame cap is solid")
	top(Vector3(11, 7.51, -60.3), 7.51, "exit canopy is solid")
	top(Vector3(-17.65, 16.3, 7.5), 16.3, "gatehouse roof overhang is solid")
	top(Vector3(12.75, -1.875, -18), -1.875, "penstock thrust cap is solid")
	for x: float in [11.5, 14.0]:
		var midpoint := Vector3(x, 3.5, -6.5)
		check(not ray(midpoint + Vector3.RIGHT, midpoint - Vector3.RIGHT).is_empty(), "upper penstock at x %s is solid" % x)
	for edge: Array in [
		[Vector3(-5.5, 1.65, -50), Vector3(-7, 1.65, -50), "settling west"],
		[Vector3(5, 1.65, -55.5), Vector3(5, 1.65, -57), "settling south"],
		[Vector3(-7, 1.65, -42.5), Vector3(-7, 1.65, -44), "channel southwest"],
		[Vector3(-14, 8.7, 14), Vector3(-14, 8.7, 10), "reservoir dam"],
		[Vector3(-87, 8.7, 67), Vector3(-92, 8.7, 67), "reservoir west"],
		[Vector3(59, 8.7, 67), Vector3(64, 8.7, 67), "reservoir east"],
		[Vector3(-14, 8.7, 120), Vector3(-14, 8.7, 125), "reservoir north"],
	]:
		check(not ray(edge[0], edge[1]).is_empty(), "%s retains its water" % edge[2])
	var rail_count := 0
	for node: Node in level.find_children("*", "Node3D", true, false):
		if node.has_meta("rail_base"):
			var at: Vector3 = node.get_meta("rail_base")
			var hit := ray(at + Vector3.UP * .10, at - Vector3.UP * .18)
			check(not hit.is_empty(), "rail foot supported at %s" % at)
			rail_count += 1
	check(rail_count > 100, "support sweep covers the complete course")
	print("surf geometry: %d/%d checks passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

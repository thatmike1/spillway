extends "test_spillway_access.gd"
## recovery perimeter coverage: outward input from sampled edges, not authored routes.
## native --boundary-views selects representative cases; headless checks every sample.

## r12 / the old low cave under the terrace is filled solid and the basin's exit ramp now stands
## where some of its foot samples were. a sample whose capsule start lies inside one of those
## named r12 solids moves inward to the nearest standing room within 8.5 m and still walks out
## across that floor's edge; with no room that close, the edge is sealed and the check confirms the
## named solid fills it. every other sample keeps its original start. each shift is reported.
const R12_FILL: Array[String] = ["BasinTerraceSubstructure", "ChannelTerraceSubstructure", "BridgeRecoveryRamp"]

func r12_fill_at(at: Vector3) -> String:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .3
	capsule.height = 1.8
	query.shape = capsule
	query.exclude = [player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * .96)
	for hit: Dictionary in player.get_world_3d().direct_space_state.intersect_shape(query, 8):
		var body := str((hit.collider as Node).name)
		if body in R12_FILL:
			return body
	return ""

func standing_room(at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .3
	capsule.height = 1.8
	query.shape = capsule
	query.exclude = [player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * .96)
	return player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func outward(name: String, start: Vector3, target: Vector3, outflow: bool, inward := Vector3.ZERO) -> void:
	var fill := r12_fill_at(start) if inward != Vector3.ZERO else ""
	if not fill.is_empty():
		var sample := start
		start = Vector3.INF
		for step: int in range(1, 86):
			if standing_room(sample + inward * step * .1):
				start = sample + inward * step * .1
				break
		label = name
		if start == Vector3.INF:
			# the fill must reach the terrace's underside: no crawl gap left above it.
			var head := PhysicsPointQueryParameters3D.new()
			head.position = sample + Vector3.UP * 1.72
			var filled := false
			for hit: Dictionary in player.get_world_3d().direct_space_state.intersect_point(head, 8):
				filled = filled or str((hit.collider as Node).name) in R12_FILL
			check(filled, "edge sealed: the old foot %s is inside %s up to the terrace, no standing room within 8.5 m inward" % [sample, fill])
			return
		name += " (old foot %s inside %s; moved %.1f m inward to %s)" % [sample, fill, start.distance_to(sample), start]
	if outflow:
		await roof_fixture(name, start)
	else:
		await fixture(name, start, false)
	await walk(target, 300)
	await ticks(180)
	check(int(game.get("respawn_count")) == 0 and player.global_position.y > start.y - .65,
		"ordinary outward walking stays on solid recovery geometry: %s" % player.global_position)

func run() -> void:
	game = load("res://scripts/spillway_main.gd").new()
	root.add_child(game)
	game.set("_persist", false)
	player = game.get("player")
	var level: Node3D = game.get("level")
	var compact := OS.get_cmdline_user_args().has("--boundary-views")
	for floor_name: String in ["ChannelRecoveryFloor", "SettlingBasinFloor", "OutflowRecoveryFloor"]:
		var floor_node := level.find_child(floor_name, false, false) as StaticBody3D
		var shape := floor_node.get_child(0) as CollisionShape3D
		var size: Vector3 = (shape.shape as BoxShape3D).size
		var top := floor_node.global_position + Vector3.UP * (size.y * .5 + .04)
		for normal: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var compact_fraction := .15 if (floor_name == "ChannelRecoveryFloor" and normal == Vector3.BACK) or (floor_name == "OutflowRecoveryFloor" and normal == Vector3.RIGHT) else .5
			for fraction: float in ([compact_fraction] if compact else [.15, .5, .85]):
				var edge := top
				if normal.x != 0:
					edge.x += normal.x * size.x * .5
					edge.z += (fraction - .5) * size.z
				else:
					edge.z += normal.z * size.z * .5
					edge.x += (fraction - .5) * size.x
				await outward("%s edge%s %.2f" % [floor_name, normal, fraction], edge - normal * .85, edge + normal * 1.2, floor_name == "OutflowRecoveryFloor", -normal)
		if not compact or floor_name == "SettlingBasinFloor":
			for x_sign: float in [-1, 1]:
				for z_sign: float in [-1, 1]:
					if compact and (x_sign != 1 or z_sign != 1):
						continue
					var normal := Vector3(x_sign, 0, z_sign).normalized()
					var corner := top + Vector3(x_sign * size.x * .5, 0, z_sign * size.z * .5)
					await outward("%s corner%s" % [floor_name, normal], corner - normal * 1.2, corner + normal * 1.2, floor_name == "OutflowRecoveryFloor", -normal)
	# turns that looked like exits in the late-miss and ramp-top views.
	for episode: Array in [
		["late miss toward daylight", Vector3(9.9, -5.96, -68), Vector3(16, -6, -60)],
		["exit landing straight ahead", Vector3(-10, -2.96, -63.5), Vector3(-10, -3, -57)],
		["exit landing west", Vector3(-10, -2.96, -63.5), Vector3(-16, -3, -63.5)],
		["front walk diagonal seam", Vector3(4, -2.96, -63.5), Vector3(10, -3, -58)],
	]:
		await outward(episode[0], episode[1], episode[2], true)
	for key: String in ["move_forward", "move_back", "jump", "crouch"]:
		action(key, false)
	print("spillway boundaries: %d/%d checks passed; sampled recovery perimeters, fixture poses and real input; compact=%s" % [checks - failures, checks, compact])
	game.call("request_quit", 1 if failures else 0)

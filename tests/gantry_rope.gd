extends SceneTree
## exercise the actual runner's render transform and Gantry's late visual styling.
const HOST := preload("res://scripts/game.gd")

func _initialize() -> void:
	run.call_deferred()

func diameter(camera: Camera3D, rope: MeshInstance3D, y: float, radius: float) -> float:
	var widest := 0.0
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var a := rope.global_transform * (Vector3(0, y, 0) + axis * radius)
		var b := rope.global_transform * (Vector3(0, y, 0) - axis * radius)
		widest = maxf(widest, camera.unproject_position(a).distance_to(camera.unproject_position(b)))
	return widest

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game := HOST.new()
	game.map_id = "gantry"
	game.motor = "server128"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = "/tmp/r22-03-hop-into-swing/rope-absent.cfg"
	game.ghosts_directory = "/tmp/r22-03-hop-into-swing/rope-ghosts"
	game.ghost_share_storage = "/tmp/r22-03-hop-into-swing/rope-selection.cfg"
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_paused(true)
	var p = game.player
	var camera: Camera3D = p.camera
	var rope: MeshInstance3D = p.get_node("GrappleTether")
	var stroke: Node = game.level.get_node("GantryRopeStroke")
	var ok := true
	for offset: Vector3 in [Vector3(0, 10, -15), Vector3(4, 2, -20), Vector3(-3, 6, -8), Vector3(3, 4, 5)]:
		# a render-only attached fixture avoids changing or depending on acquisition/motor law.
		p.grapple = {"position": camera.global_position + offset}
		var before: Dictionary = p.get_motion_state().duplicate(true)
		p._process(0.0)
		stroke._process(0.0)
		var mesh := rope.mesh as CylinderMesh
		var near_px := diameter(camera, rope, -0.5, mesh.bottom_radius)
		var far_px := diameter(camera, rope, 0.5, mesh.top_radius)
		print("GANTRY_ROPE ", JSON.stringify({"near_px": near_px, "far_px": far_px,
			"near_radius": mesh.bottom_radius, "far_radius": mesh.top_radius,
			"basis_lengths": [rope.global_basis.x.length(), rope.global_basis.y.length(), rope.global_basis.z.length()]}))
		ok = ok and near_px <= 3.0 and far_px <= 3.0 and mesh.top_radius <= 0.00601
		ok = ok and before == p.get_motion_state()
	game.queue_free()
	await process_frame
	print("GANTRY_ROPE_PASS" if ok else "GANTRY_ROPE_FAIL: rope exceeds three pixels at the hand")
	quit(0 if ok else 1)

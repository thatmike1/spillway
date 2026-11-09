extends SceneTree
## collision identity audit and original ghost-loader compatibility; no earned-course claim.
const LEVEL := preload("res://scripts/r19_line_drive_level.gd")
const GHOST := preload("res://scripts/r16_ghost.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
var checks: Array[Dictionary] = []
var opts := {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			opts[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})

func _run() -> void:
	var level := LEVEL.new()
	root.add_child(level)
	level.build()
	var identity: Dictionary = level.geometry_identity()
	var hash_before: String = level.geometry_hash()
	var pieces: Array = []
	for piece: Dictionary in level.manifest:
		var body := level.get_node(str(piece.name)) as StaticBody3D
		var collision := body.get_child(0) as CollisionShape3D
		var actual: Array = []
		var points: PackedVector3Array = (collision.shape as ConvexPolygonShape3D).points
		var bounds := AABB(body.to_global(points[0]), Vector3.ZERO)
		for point: Vector3 in points:
			actual.append(body.to_global(point))
			bounds = bounds.expand(body.to_global(point))
		var matches: bool = actual.size() == piece.points.size()
		for i: int in actual.size():
			matches = matches and (actual[i] as Vector3).distance_to(piece.points[i]) < 0.00002
		check(matches, "actual convex collision matches numeric manifest: " + str(piece.name))
		check(maxf(bounds.size.x, bounds.size.z) <= 32.0, "collision span <=32m: " + str(piece.name))
		pieces.append({"name": piece.name, "vertices": LEVEL.coordinates(actual), "bounds": LEVEL.coordinates(bounds)})
	check(not JSON.stringify(identity).contains("("), "identity contains numeric coordinate arrays, no Variant vector strings")
	# mutations are confined to disposable audit metadata, never runtime course evidence.
	var p: Vector3 = level.manifest[0].points[0]
	level.manifest[0].points[0] = p + Vector3.RIGHT * 0.00001
	check(hash_before != level.geometry_hash(), "tiny vertex revision changes identity")
	level.manifest[0].points[0] = p
	var box: AABB = level.launch_pads[0].bounds
	level.launch_pads[0].bounds.position.x += 0.00001
	check(hash_before != level.geometry_hash(), "tiny pad-bound revision changes identity")
	level.launch_pads[0].bounds = box
	level.launch_pads[0].direction = Vector3.RIGHT
	check(hash_before != level.geometry_hash(), "pad direction changes identity")
	level.launch_pads[0].direction = Vector3.FORWARD
	var pose: Transform3D = level.checkpoints[1].pose
	level.checkpoints[1].pose.basis = Basis(Vector3.UP, 0.00001) * pose.basis
	check(hash_before != level.geometry_hash(), "tiny checkpoint heading changes identity")
	level.checkpoints[1].pose = pose
	var checkpoint: AABB = level.checkpoints[1].bounds
	level.checkpoints[1].bounds.position.x += 0.00001
	check(hash_before != level.geometry_hash(), "tiny checkpoint-bound revision changes identity")
	level.checkpoints[1].bounds = checkpoint
	var spawn: Transform3D = level.spawn
	level.spawn.origin.x += 0.00001
	check(hash_before != level.geometry_hash(), "tiny spawn revision changes identity")
	level.spawn = spawn
	var finish: AABB = level.finish_bounds
	level.finish_bounds.position.x += 0.00001
	check(hash_before != level.geometry_hash(), "tiny finish revision changes identity")
	level.finish_bounds = finish
	var kill: AABB = level.kill_bounds
	level.kill_bounds.position.x += 0.00001
	check(hash_before != level.geometry_hash(), "tiny kill revision changes identity")
	level.kill_bounds = kill
	check(hash_before == level.geometry_hash(), "all disposable metadata restored exactly")
	var run := READER.read(str(opts.recording), true)
	check(run.ok and READER.clean_finish(run).ok, "original Godot reader accepts earned clean file")
	var ghost := GHOST.new()
	root.add_child(ghost)
	var expected: Dictionary = run.header.identity.duplicate(true)
	check(ghost.load_run(str(opts.recording), expected).ok and ghost.loaded, "original ghost accepts matching earned run")
	expected.geometry = hash_before + "-incompatible"
	check(not ghost.load_run(str(opts.recording), expected).ok and not ghost.loaded, "geometry revision rejects and clears ghost")
	expected = run.header.identity.duplicate(true)
	expected.motor += "-incompatible"
	check(not ghost.load_run(str(opts.recording), expected).ok and not ghost.loaded, "launch-law revision rejects and clears ghost")
	var ok := checks.all(func(c: Dictionary) -> bool: return c.ok)
	DirAccess.make_dir_recursive_absolute(str(opts.out))
	var file := FileAccess.open(str(opts.out).path_join("geometry.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": ok, "checks": checks, "hash": hash_before, "identity": identity, "pieces": pieces}, " ", true, true))
	file.close()
	print("line drive geometry ok=", ok, " checks=", checks.size())
	quit(0 if ok else 1)

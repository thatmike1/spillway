extends SceneTree
## independently traverse actual imported scenes: the offset dish and compound hangar must
## land at their requested foot, preserve appearance, and never add an implicit collider.

const ASSETS := preload("res://scripts/r15_assets.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _measure(node: Node3D, local_to: Node3D, collected: Array[AABB], counts: Dictionary) -> void:
	if node is CollisionObject3D or node is CollisionShape3D:
		counts.physics += 1
	if node is MeshInstance3D and node.mesh != null:
		counts.meshes += 1
		for surface: int in node.mesh.get_surface_count():
			if node.get_active_material(surface) == null:
				counts.missing_materials += 1
		collected.append((local_to.global_transform.affine_inverse() * node.global_transform) * node.mesh.get_aabb())
	for child: Node in node.get_children():
		if child is Node3D:
			_measure(child, local_to, collected, counts)

func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	world.position = Vector3(60, 11, -45)
	world.rotation.y = 0.7
	var models := ["kenney-space/models/satelliteDish_large.glb", "kenney-space/models/hangar_smallA.glb", "kenney-castle/models/tower-square-arch.glb", "kenney-train/models/train-electric-subway-a.glb"]
	for model: String in models:
		var foot := Vector3(18, 8, -12)
		var desired_height := 6.0
		var prop := ASSETS.place(world, model, foot, ASSETS.scale_for_height(model, desired_height), deg_to_rad(35))
		var boxes: Array[AABB] = []
		var counts := {"physics": 0, "meshes": 0, "missing_materials": 0}
		_measure(prop, world, boxes, counts)
		var actual := boxes[0]
		for box: AABB in boxes.slice(1):
			actual = actual.merge(box)
		_check(absf(actual.position.y - foot.y) < 0.0001, model + " requested foot")
		_check(absf(actual.get_center().x - foot.x) < 0.0001 and absf(actual.get_center().z - foot.z) < 0.0001, model + " centred after yaw")
		_check(absf(actual.size.y - desired_height) < 0.0001, model + " requested visible height")
		_check(counts.physics == 0 and counts.meshes > 0 and counts.missing_materials == 0, model + " renderable materials, explicit collision ownership")
		_check(str(prop.get_meta("r15_asset")) == model, model + " source identity")
		prop.free()
	world.free()
	print("r15 asset placement: ", models.size() * 5, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

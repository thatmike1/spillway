extends SceneTree
## verify the separate receiver revision against every original solid and the approach sightline.
const ORIGINAL := preload("res://scripts/maps/saltglass.gd")
const SEAWARD := preload("res://scripts/maps/saltglass_seaward.gd")
const HASH := "082ccbc2b6fcadce607bb6c22f4376ca812f14bd928d4b1955f4f8414a59b0dd"
var output := ""

func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func run() -> void:
	var original := ORIGINAL.new()
	root.add_child(original)
	original.build()
	assert(original.geometry_hash() == HASH)
	var before: Dictionary = solids(original)
	await physics_frame
	await physics_frame
	var eye := Vector3(205, 7.2, 52)
	var hidden := hit(original, eye, Vector3(221.5, 5.05, 52))
	assert(hidden == "salt_store", "the original receiver must be hidden by the real store")
	var authored_spawn: Transform3D = original.spawn
	original.free()
	await physics_frame
	var revision := SEAWARD.new()
	root.add_child(revision)
	revision.build()
	var after: Dictionary = solids(revision)
	assert(after.size() == before.size() + 1)
	for name: String in before:
		assert(after.has(name) and after[name] == before[name], "existing solid changed: " + name)
	assert(after.has("seaward_receiver_0_0"))
	assert(revision.level_id != ORIGINAL.LEVEL_ID and SEAWARD.MAP_ID != ORIGINAL.MAP_ID)
	assert(revision.geometry_hash() != HASH)
	assert(revision.spawn == authored_spawn)
	await physics_frame
	await physics_frame
	var visible := hit(revision, eye, Vector3(218, 5.05, 58))
	var receiver := hit(revision, Vector3(218, 7, 58), Vector3(218, 4, 58))
	assert(visible.is_empty(), "receiver top sightline blocked by " + visible)
	assert(receiver == "seaward_receiver_0_0")
	var result := {"ok": true, "original_geometry": HASH, "revision_geometry": revision.geometry_hash(),
		"original_solids": before.size(), "revision_solids": after.size(), "unchanged_original_solids": before.size(),
		"original_receiver_occluder": hidden, "new_receiver_sightline": visible, "new_receiver_support": receiver,
		"limit": "collision sightline and exact solid comparison, not player discovery or enjoyment"}
	if not output.is_empty():
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("PASS saltglass seaward: ", result)
	revision.free()
	quit()

func hit(level: Node3D, start: Vector3, end: Vector3) -> String:
	var query := PhysicsRayQueryParameters3D.create(start, end)
	var result := level.get_world_3d().direct_space_state.intersect_ray(query)
	return "" if result.is_empty() else str(result.collider.name)

func solids(level: Node3D) -> Dictionary:
	var result := {}
	for body: Node in level.find_children("*", "StaticBody3D", true, false):
		for shape: Node in body.get_children():
			if shape is CollisionShape3D:
				result[str(body.name)] = [body.transform, shape.transform, shape.shape.points]
	return result

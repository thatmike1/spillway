extends SceneTree
## production geometry contract: unique identities and physically connected recovery surfaces.
const LEVEL := preload("res://scripts/maps/viaduct.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var level := LEVEL.new()
	root.add_child(level)
	level.build()
	assert(level.checkpoints.size() == 4)
	assert(level.level_id == "r22-viaduct")
	assert(level.variant == "viaduct")
	assert(level.spawn.origin == Vector3(0,4.04,12))
	assert(level.get_node("viaduct_upper_inspection_0_0").get_meta("progress_stage") == 2)
	assert(not level.is_finish_at(LEVEL.UPPER_LANDING.get_center()))
	var yard := preload("res://scripts/maps/tether_yard.gd").new()
	assert(level.geometry_hash() != yard.geometry_hash())
	yard.free()
	var ids: Array = []
	for anchor: Node3D in get_nodes_in_group(level.RUNNER.ANCHOR_GROUP):
		var id: String = anchor.get_meta("r21_anchor_id")
		assert(id.begins_with("viaduct-bay-"))
		assert(not ids.has(id))
		ids.append(id)
	assert(ids.size() == 3)
	for i: int in 4:
		var ramp := false
		var landing := false
		for piece: Dictionary in level.manifest:
			if piece.name == "viaduct_return_%d" % i:
				ramp = piece.points.any(func(p: Vector3) -> bool: return p.y == -5.0) and piece.points.any(func(p: Vector3) -> bool: return p.y == LEVEL.V_HEIGHTS[i])
			if str(piece.name).begins_with("viaduct_return_landing_%d" % i):
				landing = true
		assert(ramp and landing)
	print("VIADUCT GEOMETRY PASS: four checkpoints, three unique rings, four connected returns")
	level.free()
	quit()

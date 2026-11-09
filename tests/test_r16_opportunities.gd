extends SceneTree
## live geometry/rid/order/progress invariance on the frozen r15 map builders.

const MAIN := preload("res://scripts/r15_main.gd")
const OVERLAY := preload("res://scripts/r16_style_opportunities.gd")
var checks: Array = []
var reports: Array = []
var output := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	_run.call_deferred()

func check(title: String, ok: bool) -> void:
	checks.append({"name": title, "ok": ok})
	print("PASS " if ok else "FAIL ", title)

func _run() -> void:
	var off_tree := Node3D.new()
	check("off-tree refusal", OVERLAY.apply(off_tree).reason == "level_not_in_tree")
	check("off-tree refusal leaves retry possible", not off_tree.has_meta(OVERLAY.META))
	off_tree.free()
	for map_id: String in ["breakwater", "whiteout-relay", "sunken-court", "rainline", "night-shift", "experiment", "practice", "overflow"]:
		var game := MAIN.new()
		game.map_id = map_id
		game.seed_from_r14 = false
		game.set_window_title = false
		root.add_child(game)
		var level: Node3D = game.level
		var before := state(level)
		var child_ids := level.get_children().map(func(n: Node) -> int: return n.get_instance_id())
		var progress := var_to_str([level.get("checkpoints"), level.get("spawn"), level.get("finish_position"), level.get("segment_bounds"), level.get("routes"), level.get("jump_gaps"), level.get("kill_bounds")])
		var base_hash: String = level.call("geometry_hash")
		var base_manifest := var_to_str(level.get("manifest"))
		var report := OVERLAY.apply(level)
		var count := level.get_child_count()
		check(map_id + " idempotent detached report", OVERLAY.apply(level) == report and level.get_child_count() == count)
		var copy := OVERLAY.apply(level)
		copy["hash"] = "mutated caller copy"
		check(map_id + " metadata cannot be changed through returned report", OVERLAY.apply(level).hash == report.hash)
		check(map_id + " original nodes, rids, transforms, shapes, metadata unchanged", state(level, true) == before)
		check(map_id + " original child order unchanged", level.get_children().slice(0, child_ids.size()).map(func(n: Node) -> int: return n.get_instance_id()) == child_ids)
		check(map_id + " original geometry hash and manifest unchanged", level.call("geometry_hash") == base_hash and var_to_str(level.get("manifest")) == base_manifest)
		check(map_id + " progress unchanged", progress == var_to_str([level.get("checkpoints"), level.get("spawn"), level.get("finish_position"), level.get("segment_bounds"), level.get("routes"), level.get("jump_gaps"), level.get("kill_bounds")]))
		var target := map_id in ["breakwater", "whiteout-relay"]
		check(map_id + " target policy", bool(report.applied) == target)
		if target:
			var hash_input := report.duplicate(true)
			hash_input.erase("hash")
			check(map_id + " deterministic content hash", JSON.stringify(hash_input).sha256_text() == report.hash)
			var solids := 0
			for opportunity: Dictionary in report.opportunities:
				check(map_id + " support role " + str(opportunity.name), level.has_node(NodePath(str(opportunity.deck_piece))) and str(level.get_node(NodePath(str(opportunity.deck_piece))).get_meta("surface")) == "route")
				for solid: Dictionary in opportunity.solids:
					var body := level.get_node(NodePath(OVERLAY.ROOT_NAME + "/" + str(solid.path))) as StaticBody3D
					var collision := body.get_node("Collision") as CollisionShape3D
					var mesh := body.get_node("SolidMesh") as MeshInstance3D
					check(map_id + " matching opaque visible solid " + str(solid.path), collision.shape is BoxShape3D and mesh.mesh is BoxMesh and (collision.shape as BoxShape3D).size == (mesh.mesh as BoxMesh).size and mesh.visible and (mesh.material_override as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and (mesh.material_override as StandardMaterial3D).albedo_texture != null)
					check(map_id + " reported actual collision " + str(solid.path), solid.size_m == v((collision.shape as BoxShape3D).size) and solid.world_origin_m == v(body.global_position) and not body.has_meta("progress_stage") and body.collision_layer == 1)
					solids += 1
			check(map_id + " small installation count", solids == (6 if map_id == "breakwater" else 4))
		else:
			check(map_id + " non-target reason and no append", report.reason == "non_target_map" and count == child_ids.size())
		reports.append({"map": map_id, "base_hash": base_hash, "report": report})
		game.free()
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.ok)
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "reports": reports, "failed": failed.size()}, "  "))
	file.close()
	quit(0 if failed.is_empty() else 1)

static func state(level: Node3D, omit_overlay := false) -> Array:
	var rows: Array = []
	for node: Node in level.find_children("*", "", true, false):
		if omit_overlay and (node.name == OVERLAY.ROOT_NAME or str(level.get_path_to(node)).begins_with(OVERLAY.ROOT_NAME + "/")):
			continue
		var row := [str(level.get_path_to(node)), node.get_instance_id(), node.get_class(), node.get_meta_list().map(func(key: StringName) -> Array: return [str(key), var_to_str(node.get_meta(key))])]
		if node is Node3D:
			row.append(var_to_str((node as Node3D).global_transform))
		if node is CollisionObject3D:
			row.append((node as CollisionObject3D).get_rid().get_id())
		if node is CollisionShape3D:
			var shape := (node as CollisionShape3D).shape
			row.append(shape.get_rid().get_id())
			for property: Dictionary in shape.get_property_list():
				if int(property.usage) & PROPERTY_USAGE_STORAGE:
					row.append([property.name, var_to_str(shape.get(property.name))])
		rows.append(row)
	return rows

static func v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

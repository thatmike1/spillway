extends SceneTree
## real collision fixtures challenge the auditor, independently of surface labels.
const LEVEL := preload("res://scripts/r20_surf_level.gd")
const GEO := preload("res://scripts/r19_course_geometry.gd")
const AUDIT := preload("res://tests/r20_surf_geometry.gd")
var output := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func run() -> void:
	RenderingServer.render_loop_enabled = false
	DirAccess.make_dir_recursive_absolute(output)
	var checks: Array = []
	for mutation: String in ["none", "unlabelled_under_fin_floor", "inclined_exit", "descending_crescent", "manifest_mismatch", "spawn_stage_three_bridge"]:
		var level := LEVEL.new()
		root.add_child(level)
		level.build()
		if mutation == "unlabelled_under_fin_floor":
			GEO.deck(level, "ordinary_deck", -10, -2, -120, -98, -4, 0)
		elif mutation in ["inclined_exit", "descending_crescent"]:
			var prefix := "west_landing_0_0" if mutation == "inclined_exit" else "crescent_1_0_0"
			for row: Dictionary in level.manifest:
				if row.name != prefix:
					continue
				var body := level.get_node(NodePath(row.name)) as StaticBody3D
				var collision := body.get_child(0) as CollisionShape3D
				var actual := PackedVector3Array()
				for i: int in row.points.size():
					var point: Vector3 = row.points[i]
					if mutation == "descending_crescent":
						point.y -= 2
					elif i in [0, 1]:
						point.y += 1
					row.points[i] = point
					actual.append(point - body.position)
				(collision.shape as ConvexPolygonShape3D).points = actual
		elif mutation == "spawn_stage_three_bridge":
			GEO.deck(level, "stage_three_bridge", -1, 16, 20, 42, 15.5, 3)
		elif mutation == "manifest_mismatch":
			var body := level.get_node("Surf_west_0") as StaticBody3D
			body.position.y += 0.1
		var report := AUDIT.audit(level)
		var ok: bool = report.ok if mutation == "none" else not report.ok
		checks.append({"mutation": mutation, "ok": ok, "errors": report.errors})
		level.free()
	var result := {"ok": checks.all(func(row: Dictionary) -> bool: return row.ok), "checks": checks}
	var file := FileAccess.open(output.path_join("geometry-negative.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("R20 geometry auditor controls: ", result.ok)
	quit(0 if result.ok else 1)

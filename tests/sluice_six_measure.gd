extends SceneTree
## measure built collision and declared gaps rather than estimating from screenshots.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var result := {}
	for path: String in ["r15_breakwater_level", "r15_whiteout_level", "r15_sunken_level"]:
		var level: Node3D = load("res://scripts/" + path + ".gd").new()
		root.add_child(level)
		level.build()
		var rows: Array = []
		for piece: Dictionary in level.manifest:
			if piece.role != "route":
				continue
			var lo := Vector3(INF, INF, INF)
			var hi := -lo
			for p: Vector3 in piece.points:
				lo = lo.min(p)
				hi = hi.max(p)
			rows.append({"name":piece.name,"width_m":hi.x-lo.x,"length_m":hi.z-lo.z,"top_m":hi.y})
		var gaps: Array = []
		for gap: Dictionary in level.jump_gaps:
			gaps.append({"label":gap.label,"horizontal_m":Vector2(gap.land.x-gap.edge.x,gap.land.z-gap.edge.z).length(),"rise_m":gap.land.y-gap.edge.y})
		result[path] = {"route_pieces":rows,"gaps":gaps}
		level.free()
	print("MEASUREMENTS=" + JSON.stringify(result))
	quit()

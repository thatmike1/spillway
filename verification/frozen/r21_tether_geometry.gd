extends SceneTree
## final component collision manifest, flat landings and connected physical return routes.
const LEVEL := preload("res://scripts/r21_tether_level.gd")
const OLD := preload("res://scripts/r20_tether_level.gd")
var output := ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()
func run() -> void:
	var level := LEVEL.new()
	var old := OLD.new()
	root.add_child(level)
	root.add_child(old)
	level.build()
	old.build()
	var checks: Array = []
	for stage: int in 4:
		var top: float = LEVEL.DECK_HEIGHTS[stage]
		var deck := false
		var landing := false
		var ramp := false
		for piece: Dictionary in level.manifest:
			if str(piece.name).begins_with("transfer_%d_" % stage):
				deck = piece.points.all(func(p: Vector3) -> bool: return p.y == top or is_equal_approx(p.y,top-0.8))
			if str(piece.name).begins_with("return_landing_%d_" % stage):
				landing = piece.points.all(func(p: Vector3) -> bool: return p.y == top or is_equal_approx(p.y,top-0.8))
			if str(piece.name) == "return_ramp_%d" % stage:
				ramp = piece.points.any(func(p: Vector3) -> bool: return p.y == top) and piece.points.any(func(p: Vector3) -> bool: return p.y == -5.0)
		checks.append({"ok":deck and landing and ramp,"check":"flat deck and connected recovery top " + str(stage),"top":top})
	checks.append({"ok":level.level_id != old.level_id and level.level_version > old.level_version and level.geometry_hash()!=old.geometry_hash(),"check":"new geometry module version and digest refuse old comparison identity"})
	checks.append({"ok":level.spawn==old.spawn and LEVEL.ANCHORS==old.ANCHORS and level.kill_bounds==old.kill_bounds,"check":"original normal spawn anchors catch bounds unchanged"})
	var ok := checks.all(func(c: Dictionary) -> bool: return c.ok)
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":ok,"checks":checks,"geometry_hash":level.geometry_hash(),"old_geometry_hash":old.geometry_hash(),"level_id":level.level_id,"level_version":level.level_version,"heights":LEVEL.DECK_HEIGHTS},"\t"))
	file.close()
	level.free()
	old.free()
	quit(0 if ok else 1)

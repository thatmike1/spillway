extends SceneTree
## compare actual collision manifests against external, git-extracted wave1 source.
const CURRENT := preload("res://scripts/maps/gantry.gd")
const CHAIN := preload("res://scripts/maps/gantry_chain.gd")
var baseline_map := ""
var baseline_art := ""
var output := "/tmp/r22-03-hop-into-swing/preserved"
var checks: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-map="): baseline_map = arg.trim_prefix("--baseline-map=")
		if arg.begins_with("--baseline-art="): baseline_art = arg.trim_prefix("--baseline-art=")
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	if not ok: push_error(label)

func run() -> void:
	if not FileAccess.file_exists(baseline_map) or not FileAccess.file_exists(baseline_art):
		push_error("supply externally extracted wave1 map and art source")
		quit(1)
		return
	var map_text := FileAccess.get_file_as_string(baseline_map)
	var art_text := FileAccess.get_file_as_string(baseline_art)
	# nest the untouched old art in its old map so no baseline file enters the project.
	var source := map_text.replace("const ART := preload(\"res://scripts/art/gantry_dress.gd\")", "")
	source = source.replace("ART.dress(self)", "OriginalArt.dress(self)")
	source += "\nclass OriginalArt extends RefCounted:\n"
	for line: String in art_text.split("\n").slice(1):
		source += "\t" + line + "\n"
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		quit(1)
		return
	var original: Node3D = script.new()
	original.build()
	var old: Dictionary = {}
	for piece: Dictionary in original.manifest: old[piece.name] = piece
	for model: Node3D in [CURRENT.new(), CHAIN.new()]:
		model.build()
		check(model.checkpoints.size() == (3 if model.variant == CURRENT.MAP_ID else 4), model.level_name + ": complete checkpoint construction")
		check(model.has_node("dispatch_runout") and model.has_node("dispatch_endstop"), model.level_name + ": post-finish court construction complete")
		if model.variant == CHAIN.CHAIN_ID:
			check(model.has_node("Anchor_3"), "Gantry Chain third anchor construction complete")
		var found: Dictionary = {}
		for piece: Dictionary in model.manifest:
			found[piece.name] = piece
			if old.has(piece.name): continue
			var low := Vector3(INF, INF, INF)
			var high := Vector3(-INF, -INF, -INF)
			for point: Vector3 in piece.points:
				low = low.min(point)
				high = high.max(point)
			var overlap_x := minf(high.x, CURRENT.HALF_WIDTH) - maxf(low.x, -CURRENT.HALF_WIDTH)
			var overlap_z := minf(high.z, 24) - maxf(low.z, -108)
			check(overlap_x <= 0.00001 or overlap_z <= 0.00001, model.level_name + ": new solid stays outside timed footprint: " + piece.name)
		for id: String in old:
			check(found.has(id) and found[id] == old[id], model.level_name + ": original solid unchanged: " + id)
		check(model.spawn == original.spawn, model.level_name + ": spawn unchanged")
		for i: int in 2:
			check(model.get_node("Anchor_%d" % (i + 1)).position == original.get_node("Anchor_%d" % (i + 1)).position, model.level_name + ": original anchor position unchanged: " + str(i))
		for i: int in 3:
			check(model.checkpoints[i].pose == original.checkpoints[i].pose and model.checkpoints[i].bounds == original.checkpoints[i].bounds, model.level_name + ": original checkpoint pose/bounds unchanged: " + str(i))
		if model.variant == CURRENT.MAP_ID:
			check(model.finish_bounds == original.finish_bounds, "Gantry original finish box unchanged")
		model.free()
	original.free()
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("preserved.json"), FileAccess.WRITE).store_string(JSON.stringify({"ok": ok, "baseline_map_sha256": map_text.sha256_text(), "baseline_art_sha256": art_text.sha256_text(), "original_solids": old.size(), "checks": checks}, "\t"))
	print("GANTRY_PRESERVED ", ok, " checks=", checks.size(), " original_solids=", old.size())
	quit(0 if ok else 1)

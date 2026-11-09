extends SceneTree
## rendering toggles through real input dispatch preserve r16 geometry, identities and live state.
const MAIN := preload("res://scripts/r17_main.gd")
class DrawnFixture extends Node3D:
	var prisms: Array = []
	var manifest: Array = []
	var jump_gaps: Array = []
var checks := 0
var failures: Array = []
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
func snapshot(game: Node) -> String:
	var rows: Array = [game.level.manifest,game.level.spawn,game.level.checkpoints,game.level.segment_bounds,game.course_geometry,game.overlay_id,game.course_key,game.motion_identity()]
	for node: Node in game.level.find_children("*","CollisionShape3D",true,false):
		rows.append([str(game.level.get_path_to(node.get_parent())),node.global_transform,node.disabled,node.shape.get_debug_mesh().get_faces()])
	return var_to_str(rows).sha256_text()
func check_contours() -> void:
	var fixture := DrawnFixture.new()
	for bounds: Vector2 in [Vector2(0,2),Vector2(1,3)]:
		fixture.prisms.append({"kind":"deck","top":[Vector3(bounds.x,0,0),Vector3(bounds.y,0,0),Vector3(bounds.y,0,2),Vector3(bounds.x,0,2)]})
	# a hidden imported-model proxy must not add a floating silhouette.
	fixture.manifest.append({"kind":"model:wall","shape":"prism","role":"wall","points":[Vector3(0,9,0),Vector3(2,9,0),Vector3(2,9,2),Vector3(0,9,2),Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]})
	var contour := preload("res://scripts/r17_contours.gd").new()
	var shape: Node3D = contour.build(fixture)
	check(contour.line_count == 4,"coplanar overlapping slabs must have only their four outer edges")
	var vertices: PackedVector3Array = shape.get_node("Ink").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var clean := true
	for v: Vector3 in vertices:
		clean = clean and v.y < 0.02 and (absf(v.x)<0.01 or absf(v.x-3)<0.01 or absf(v.z)<0.01 or absf(v.z-2)<0.01)
	check(clean,"ink crossed the landing or floated over an invisible model proxy")
	shape.free()
	fixture.free()
func run() -> void:
	check_contours()
	var maps := ["breakwater","whiteout-relay"]
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--maps="):
			maps = Array(arg.trim_prefix("--maps=").split(","))
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	var contour := preload("res://scripts/r17_contours.gd").new()
	check(contour.LIP_TOP >= 0.30 and contour.LIP_FACE >= 0.14,"jump lips retain a broad top and visible face")
	var reports: Array = []
	for id: String in maps:
		var game := MAIN.new()
		game.map_id = id
		game.seed_from_r15 = false
		root.add_child(game)
		check(game.window_title().contains("EXPERIMENTAL") == game.is_lab(),id+": experiment title marker differs from delivered R16")
		game.set_paused(true)
		await process_frame
		await process_frame
		for field: String in ["lab_tag", "lab_panel", "practice_tag"]:
			var control := game.hud.get(field) as Control
			check(not control.is_visible_in_tree() or not game.look_label.get_global_rect().intersects(control.get_global_rect()),id+": look label covers inherited " + field)
		# inspect the actual replacements, so a cream wash cannot silently erase functional cues.
		for swap: Dictionary in game.look_layer.swaps:
			var key := str(swap.node.name)
			if "paint_yellow" in key or "paint_hazard" in key or key == "ReadabilityNosing":
				check(swap.new is StandardMaterial3D and swap.new.albedo_color == Color("d95b30"),id+": functional edge cue lost its orange contrast")
			if key == "ReadabilityPads":
				check(swap.new.albedo_color != Color(game.look_layer.palette.top),id+": functional take-off pad flattened")
		var before := snapshot(game)
		for i: int in 20:
			var state := var_to_str([game.player.global_transform,game.player.velocity,game.elapsed,game.checkpoint_index,game.attempts,game.finished,game.clean_eligible,game.session.style.snapshot(),game.session.ghost_state])
			for pressed: bool in [true,false]:
				var event := InputEventKey.new()
				event.physical_keycode = KEY_L
				event.pressed = pressed
				Input.parse_input_event(event)
				Input.flush_buffered_events()
			check(state == var_to_str([game.player.global_transform,game.player.velocity,game.elapsed,game.checkpoint_index,game.attempts,game.finished,game.clean_eligible,game.session.style.snapshot(),game.session.ghost_state]),id+": toggle changed live R16 state")
		check(before == snapshot(game),id+": geometry/progress/identity changed")
		game.set_look(false)
		for swap: Dictionary in game.look_layer.swaps:
			var actual: Material = swap.node.get_surface_override_material(swap.surface) if swap.has("surface") else swap.node.material_override
			check(actual == swap.old,id+": original material reference not restored")
		if game.look_layer.world != null:
			check(game.look_layer.world.environment == game.look_layer.old_environment,id+": original environment not restored")
		for state: Dictionary in game.look_layer.light_states:
			check(state.node.rotation == state.rotation and state.node.light_color == state.color and state.node.light_energy == state.energy,id+": original light not restored")
		game.set_paused(false)
		for pressed: bool in [true,false]:
			var event := InputEventKey.new()
			event.physical_keycode = KEY_F
			event.pressed = pressed
			Input.parse_input_event(event)
			Input.flush_buffered_events()
		game.set_paused(true)
		await process_frame
		await process_frame
		check(game.hud.practice_tag.is_visible_in_tree(),id+": F did not exercise the inherited practice banner")
		for field: String in ["lab_tag", "lab_panel", "practice_tag"]:
			var control := game.hud.get(field) as Control
			check(not control.is_visible_in_tree() or not game.look_label.get_global_rect().intersects(control.get_global_rect()),id+": look label covers practice-state " + field)
		reports.append({"map":id,"snapshot":before,"look":game.look_layer.report})
		root.remove_child(game)
		game.free()
	print("R17_VISUAL_INVARIANTS ",JSON.stringify({"checks":checks,"failures":failures,"maps":reports}))
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("summary.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"maps":reports},"  "))
	quit(0 if failures.is_empty() else 1)

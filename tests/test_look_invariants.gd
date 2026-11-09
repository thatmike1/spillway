extends SceneTree
## collision/progress snapshot and live-input pose parity across repeated look toggles.
const MAIN := preload("res://scripts/look_main.gd")
var checks := 0
var passed := true
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		printerr(message)
		passed = false
func snapshot(level: Node3D) -> String:
	var values: Array = [level.get("spawn"),level.get("checkpoints"),level.get("segment_bounds"),level.get("manifest"),level.call("geometry_hash")]
	for node: Node in level.find_children("*","CollisionShape3D",true,false):
		var shape := node as CollisionShape3D
		values.append([shape.get_parent().name,shape.global_transform,shape.disabled,shape.shape.get_debug_mesh().get_faces()])
	return var_to_str(values).sha256_text()
func run() -> void:
	Engine.physics_ticks_per_second = 128
	var game := MAIN.new()
	root.add_child(game)
	var before := snapshot(game.level)
	var materials: Array = []
	game.set_look(false)
	for swap: Dictionary in game.look_layer.swaps:
		materials.append(swap.node.material_override)
	for i: int in 20:
		var p := game.player.global_transform
		var v := game.player.velocity
		var state := [game.elapsed,game.checkpoint_index,game.course_key,game.attempts,game.finished,game.clean_eligible]
		var event := InputEventKey.new()
		event.physical_keycode = KEY_L
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		var release := event.duplicate() as InputEventKey
		release.pressed = false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
		check(game.player.global_transform == p and game.player.velocity == v,"toggle changed body")
		check(state == [game.elapsed,game.checkpoint_index,game.course_key,game.attempts,game.finished,game.clean_eligible],"toggle changed run")
	check(before == snapshot(game.level),"collision/progress changed")
	check(not game.look_enabled,"even toggle count did not restore original")
	for i: int in materials.size():
		check(game.look_layer.swaps[i].node.material_override == materials[i],"original material not restored by reference")
	check(game.look_layer.world.environment == game.look_layer.old_environment,"original environment not restored")
	check(not game.persist and not game.seed_from_r14,"experiment touches old profiles")
	check(game.player.get_script().resource_path == "res://scripts/r15_source_player.gd","runner changed")
	print("LOOK_INVARIANTS ",JSON.stringify({"checks":checks,"geometry":game.course_geometry,"snapshot":before,"cap_triangles":game.look_layer.get_node("BoundaryCaps").mesh.get_faces().size()/3,"ink_segments":game.look_layer.line_count,"material_batches":materials.size()}))
	game.select_map("whiteout-relay")
	check(game.look_layer == null,"look leaked onto another map")
	var other_snapshot := snapshot(game.level)
	game.set_look(false)
	game.set_look(true)
	check(other_snapshot == snapshot(game.level),"other map changed on toggle")
	game.select_map("breakwater")
	check(game.look_layer != null and game.look_layer.enabled,"return to Breakwater lost look")
	check(before == snapshot(game.level),"return changed Breakwater collision")
	print("LOOK_FINAL_CHECKS ", checks," passed=",passed)
	game.request_quit(0 if passed else 1)

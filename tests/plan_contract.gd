extends SceneTree
## exercise canonical identity and rejected placement using real map and runner instances.
const MAP := preload("res://scripts/maps/plan_yard.gd")
const PIECES := preload("res://scripts/plan/pieces.gd")
const HOST := preload("res://scripts/game.gd")
const LAYOUT := preload("res://scripts/plan/layout.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var map := MAP.new()
	root.add_child(map)
	map.build()
	assert(LAYOUT.valid([3],1))
	assert(not LAYOUT.valid([0,3,6],1))
	assert(not map.apply_plan([0,0]))
	assert(not map.apply_plan([0,1,2,3]))
	assert(not map.apply_plan([-1]))
	assert(not map.apply_plan([1.5]))
	assert(map.apply_plan([6,0,3]))
	var first := map.geometry_hash()
	assert(map.apply_plan([3,6,0]))
	assert(first == map.geometry_hash())
	assert(map.apply_plan([2,5,8]))
	assert(first != map.geometry_hash())
	assert(get_nodes_in_group("r15_grapple_anchor").size() == 3)
	assert(not LAYOUT.valid([INF]))
	assert(not LAYOUT.valid([NAN]))
	assert(not map.apply_design([0,3,6],4,-1,3,true,false))
	assert(not map.apply_design([1,4],4,-1,3,false,false))
	assert(not map.apply_design([1],-1,0,3,false,true))
	assert(map.apply_design([3],-1,-1,3,false,false))
	var single := map.geometry_hash()
	assert(map.apply_design([3],-1,-1,1,true,true))
	assert(single == map.geometry_hash())
	assert(map.apply_design([1,4],4,-1,3,true,false))
	await physics_frame
	await physics_frame
	var lift: Vector3 = PIECES.BLOCKS[4]
	var ray := PhysicsRayQueryParameters3D.create(lift+Vector3.UP*2,lift-Vector3.UP*2)
	var hit := map.get_world_3d().direct_space_state.intersect_ray(ray)
	assert(not hit.is_empty() and str(hit.collider.name) == "PlanLift" and absf(hit.position.y-lift.y) < 0.001)
	assert(map.apply_design([1,4],-1,7,3,false,true))
	await physics_frame
	await physics_frame
	var pad: Vector3 = PIECES.PADS[7]
	ray = PhysicsRayQueryParameters3D.create(pad+Vector3.UP*2,pad-Vector3.UP)
	hit = map.get_world_3d().direct_space_state.intersect_ray(ray)
	assert(not hit.is_empty() and hit.collider == map.pad_body and absf(hit.position.y-pad.y-0.08) < 0.001)
	map.free()
	var game := HOST.new()
	game.map_id = "plan-yard"
	game.motor = "server128"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	root.add_child(game)
	var initial: String = game.course_key
	game.player.open_plan()
	assert(not game.session.attempt_live and game.session.pending.is_empty())
	var overlay: Control = game.player.planner
	for index: int in [0,1,2]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = overlay.point(LAYOUT.SOCKETS[index])
		overlay._gui_input(click)
	assert(game.level.plan == [1,3,6])
	for i: int in 4:
		await physics_frame
	assert(game.elapsed == 0 and not game._started)
	assert(game.level.apply_design([],-1,7,1,false,true))
	overlay.toggle_budget()
	assert(game.level.budget == 3 and game.level.pad_slot == 7)
	overlay.toggle_budget()
	assert(game.level.budget == 1 and game.level.pad_slot == 7)
	game.player.close_plan()
	assert(game.session.attempt_live)
	assert(game.course_key != initial)
	assert(game.elapsed == 0 and game.player.global_position.distance_to(game.level.spawn.origin) < 0.001)
	assert(not game.player.planning and not game.player.planner.visible)
	game.request_quit(0)
	print("plan contract: canonical order, distinct plans, duplicate/range/budget/fraction rejection pass")

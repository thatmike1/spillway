extends SceneTree
## exercise canonical identity and rejected placement using real map and runner instances.
const MAP := preload("res://scripts/maps/plan_yard.gd")
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
	game.player.close_plan()
	assert(game.session.attempt_live)
	assert(game.course_key != initial)
	assert(game.elapsed == 0 and game.player.global_position.distance_to(game.level.spawn.origin) < 0.001)
	assert(not game.player.planning and not game.player.planner.visible)
	game.request_quit(0)
	print("plan contract: canonical order, distinct plans, duplicate/range/budget/fraction rejection pass")

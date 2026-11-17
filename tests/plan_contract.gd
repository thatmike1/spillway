extends SceneTree
## exercise canonical identity and rejected placement using real map and runner instances.
const MAP := preload("res://scripts/maps/plan_yard.gd")
const LAYOUT := preload("res://scripts/plan/layout.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var map := MAP.new()
	root.add_child(map)
	map.build()
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
	print("plan contract: canonical order, distinct plans, duplicate/range/budget/fraction rejection pass")
	quit()

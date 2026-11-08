extends RefCounted
## fixture, not courses: labelled stand-in maps of different lengths for the r15 map registry
## tests. each is the loop fixture level with a fixed stage count and its own level id, so a
## registry of eight or twelve of them exercises the chooser, stage picker and record keys at
## future-map sizes. none of these is a real map.

const LEVEL := preload("res://tests/r15_loop_fixture_level.gd")

class Short extends "res://tests/r15_loop_fixture_level.gd":
	func _init() -> void:
		stages = 2
		level_id = "r15-fixture-short"

class Long extends "res://tests/r15_loop_fixture_level.gd":
	func _init() -> void:
		stages = 6
		level_id = "r15-fixture-long"

class Five extends "res://tests/r15_loop_fixture_level.gd":
	func _init() -> void:
		stages = 5
		level_id = "r15-fixture-five"

## a registry of `count` fixture maps named FIXTURE 1..count, cycling through the lengths.
## `default_id` registered first in the default chain when given. extra: id -> entry merged in.
static func registry(count: int, default_chain: Array = [], extra: Dictionary = {}) -> Dictionary:
	var scripts: Array = [LEVEL, Short, Long, Five]
	var catalog := {}
	var order: Array = []
	for i: int in count:
		var id := "fixture-%02d" % (i + 1)
		catalog[id] = {"name": "FIXTURE %d" % (i + 1), "theme": "labelled test map, %s" % ["3 stages", "2 stages", "6 stages", "5 stages"][i % 4], "kind": "lab" if i == 7 else "course", "script": scripts[i % 4]}
		order.append(id)
	for id: String in extra:
		catalog[id] = extra[id]
		if not id in order:
			order.append(id)
	return {"catalog": catalog, "order": order, "default_chain": default_chain if not default_chain.is_empty() else [order[0]]}

extends SceneTree
var checks: int = 0
var failures: int = 0
var vision = preload("res://scripts/runner_vision.gd").new()
var anchor: Node3D

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", message])

func add(offset: Vector3, options: Dictionary = {}) -> int:
	return vision.register(anchor, offset, StandardMaterial3D.new(), options)

func _run() -> void:
	anchor = Node3D.new()
	root.add_child(anchor)
	var normal: int = add(Vector3.ZERO)
	var excluded: int = add(Vector3.ZERO, {"eligible": false})
	vision.step(Vector3(0, 0, 15.1), 1)
	check(vision.objects[normal].level == 0, "outside 15m stays neutral")
	vision.step(Vector3(0, 0, 14.9), .5)
	check(vision.objects[normal].level == .5, "inside proximity fades at 1/s without camera or LOS")
	check(vision.objects[excluded].level == 0, "untagged geometry never activates")
	vision.step(Vector3.ZERO, .5)
	check(vision.objects[normal].level == 1, "full red after one second")
	vision.step(Vector3(0, 0, 30), .75)
	check(vision.objects[normal].level == 1, "effective static duration holds for one second")
	vision.step(Vector3(0, 0, 30), .25)
	check(vision.objects[normal].level == 0, "fade out takes .25s")
	var cone: int = add(Vector3.ZERO, {"angle": 60, "direction": Vector3.BACK})
	vision.step(Vector3(0, 0, -5), 1)
	check(vision.objects[cone].level == 0, "authored cone rejects opposite side")
	vision.step(Vector3(0, 0, 5), 1)
	check(vision.objects[cone].level == 1, "cone uses cosine of half angle")
	var horizontal: int = add(Vector3.ZERO, {"horizontal": true})
	vision.step(Vector3(0, 100, 0), 1)
	check(vision.objects[horizontal].level == 1, "horizontal-only distance ignores height")
	var delayed: int = add(Vector3.ZERO, {"proximity_delay": .5})
	vision.step(Vector3.ZERO, .25)
	check(vision.objects[delayed].level == 0, "proximity timer delays activation")
	vision.step(Vector3.ZERO, .25)
	check(vision.objects[delayed].level > 0, "proximity delay expires")
	var look: int = add(Vector3(100, 0, 0), {"look_delay": .4})
	vision.look_at_attempt(look)
	vision.step(Vector3.ZERO, .2)
	check(vision.objects[look].level == 0, "explicit look attempt has independent delay")
	vision.step(Vector3.ZERO, .2)
	check(vision.objects[look].level > 0, "look attempt activates after its delay")
	var sentinel: int = add(Vector3(100, 0, 0))
	vision.look_at_attempt(sentinel)
	vision.step(Vector3.ZERO, 1)
	check(vision.objects[sentinel].level == 0, "default -1 disables look activation")
	var group_a: int = add(Vector3.ZERO, {"group": "bridge"})
	var group_b: int = add(Vector3(100, 0, 0), {"group": "bridge"})
	vision.step(Vector3.ZERO, 1)
	check(vision.objects[group_a].level == 1 and vision.objects[group_b].level == 1, "group activates associated objects")
	vision.force_group("bridge", false)
	vision.step(Vector3.ZERO, 2)
	check(vision.objects[group_b].level == 0, "sequence can force group off")
	vision.difficulty = 2
	vision.step(Vector3.ZERO, 1)
	check(vision.objects[normal].level == 0, "highest difficulty disables vision")
	vision.tutorial = true
	vision.step(Vector3.ZERO, 1)
	check(vision.objects[normal].level == 1, "tutorial overrides difficulty")
	anchor.position = Vector3(5, 0, 0)
	check(vision.position(normal) == Vector3(5, 0, 0), "activation target follows folding anchor")
	print("runner vision: %d/%d checks passed" % [checks - failures, checks])
	anchor.queue_free()
	quit(1 if failures else 0)

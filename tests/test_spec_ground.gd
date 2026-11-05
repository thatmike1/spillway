extends SceneTree
## real collision-body traces; expected results and tolerances in docs/VERIFICATION.md.

const MAIN = preload("res://scripts/main.gd")
var failures: int = 0
var checks: int = 0
var fixture: Node3D
var player: CharacterBody3D
var csv: FileAccess
var out: String = "user://traces"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--traces="):
			out = arg.trim_prefix("--traces=")
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1

func ticks(n: int) -> void:
	for i: int in n:
		await physics_frame

func fresh() -> void:
	for action: String in ["move_forward", "move_left", "move_right", "move_back", "jump", "crouch"]:
		Input.action_release(action)
	if fixture != null:
		fixture.queue_free()
		await process_frame
	fixture = Node3D.new()
	root.add_child(fixture)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 600)
	shape.shape = box
	floor_body.position = Vector3(0, -.5, -200)
	floor_body.add_child(shape)
	fixture.add_child(floor_body)
	player = load("res://scenes/player.tscn").instantiate()
	fixture.add_child(player)
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(0, .9, 0)))
	await ticks(5)

func trace(name: String) -> void:
	csv = FileAccess.open(out.path_join(name + ".csv"), FileAccess.WRITE)
	csv.store_line("time,x,y,z,vx,vy,vz,speed,state")

func sample(t: float) -> void:
	var p: Vector3 = player.position
	var v: Vector3 = player.velocity
	csv.store_line("%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%s" % [t, p.x, p.y, p.z, v.x, v.y, v.z, player.get_speed(), player.move])

func _run() -> void:
	MAIN.bind_inputs()
	DirAccess.make_dir_recursive_absolute(out)
	await fresh()
	trace("straight")
	Input.action_press("move_forward")
	var targets: Array[float] = [4.0, 6.3, 7.0, 7.19]
	var expected: Array[float] = [.45, 2.67, 5.13, 9.97]
	var times: Array[float] = [-1, -1, -1, -1]
	for i: int in 1320:
		await physics_frame
		var t: float = float(i + 1) / 120
		sample(t)
		for j: int in targets.size():
			if times[j] < 0 and player.get_speed() >= targets[j]:
				times[j] = t
	csv.close()
	for j: int in targets.size():
		check(absf(times[j] - expected[j]) < .08, "%.2f m/s at %.4fs, expected %.2f ± .08s" % [targets[j], times[j], expected[j]])
	Input.action_release("move_forward")
	await ticks(180)
	check(player.get_speed() < .1, "no-input proportional braking reaches stop")
	await fresh()
	player.velocity = Vector3(0, 0, -6.3)
	player.queue_jump()
	await ticks(1)
	var takeoff: Vector3 = player.position
	Input.action_release("move_forward")
	var apex: float = takeoff.y
	var apex_time: float = 0
	var landed_at: float = -1
	trace("jump_coast")
	for i: int in 210:
		await physics_frame
		var t: float = float(i + 1) / 120
		sample(t)
		if player.position.y > apex:
			apex = player.position.y
			apex_time = t
		if player.grounded and t > .1:
			landed_at = t
			break
	csv.close()
	# takeoff sample is after one physics tick. allow one-step timing/height error.
	check(absf(apex - .9 - 1.2403125) < .05, "jump rise %.4fm, expected 1.2403 ± .05m" % (apex - .9))
	check(absf(apex_time - .39375) < .025, "apex %.4fs, expected .39375 ± .025s" % apex_time)
	check(absf(landed_at - .7875) < .04, "return %.4fs, expected .7875 ± .04s" % landed_at)
	var distance: float = absf(player.position.z)
	check(absf(distance - 7.3 * .7875) < .35, "jump distance %.4fm, expected 5.74875 ± .35m" % distance)
	check(absf(player.last_landing_speed - 5.65) < .03, "landing %.4fm/s, expected 5.65 ± .03" % player.last_landing_speed)
	await fresh()
	player.velocity = Vector3(0, 0, -6.3)
	player.queue_jump()
	await ticks(1)
	Input.action_press("move_right")
	await ticks(60)
	check(player.velocity.x > .70 and player.velocity.x < .82, "air control adds %.4fm/s in .5s, expected .768" % player.velocity.x)
	check(player.velocity.z < -7.2, "side input preserves original forward momentum")
	await fresh()
	Input.action_press("move_forward")
	await ticks(700)
	var before: float = player.get_speed()
	player.look(PI * .5, 0)
	await ticks(1)
	check(player.get_speed() < before - .3, "sharp direction change costs speed %.3f -> %.3f" % [before, player.get_speed()])
	check(player.velocity.z < -1, "turning view does not instantly rotate velocity")
	print("spec ground: %d/%d checks passed; CSV %s" % [checks - failures, checks, out])
	fixture.queue_free()
	quit(1 if failures else 0)

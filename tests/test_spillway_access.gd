extends SceneTree
## actual-level input fixtures for admission, edge guarding and optional roof access.
## reset_to supplies each documented starting pose; no episode writes velocity or yaw.
## fixtures marked "seeded" start from a placed pose; progress then comes only from input.
var game: Node3D
var player: CharacterBody3D
var checks := 0
var failures := 0
var label := "setup"
var hardware_views := ""

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, text: String) -> void:
	checks += 1
	print("%s [%s] %s" % ["PASS" if value else "FAIL", label, text])
	if not value:
		failures += 1

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func ticks(count: int) -> void:
	for i: int in count:
		await physics_frame

func aim(at: Vector3) -> void:
	var offset := at - player.global_position
	var target := atan2(-offset.x, -offset.z)
	var delta := angle_difference(float(player.get("yaw")), target)
	var event := InputEventMouseMotion.new()
	event.screen_relative = Vector2(-delta / float(player.get("mouse_sensitivity")), 0)
	event.relative = event.screen_relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func fixture(name: String, at: Vector3, yard: bool = true) -> void:
	label = name
	for key: String in ["move_forward", "move_back", "jump", "crouch"]:
		action(key, false)
	game.call("restart_run")
	if yard:
		var pose: Transform3D = game.get("level").get("checkpoints")[1].pose
		player.call("reset_to", pose)
		await ticks(3)
		check(int(game.get("checkpoint_index")) == 1, "fixture grants yard through its real admission volume")
	player.call("reset_to", Transform3D(Basis.IDENTITY, at))
	await ticks(8)

func walk(at: Vector3, limit: int = 600) -> bool:
	action("move_forward", true)
	for i: int in limit:
		aim(at)
		await ticks(1)
		if Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() < .65:
			action("move_forward", false)
			return true
	action("move_forward", false)
	return false

func approach_roof(x: float, takeoff_z: float) -> bool:
	action("move_forward", true)
	for i: int in 300:
		await ticks(1)
		if player.global_position.z <= takeoff_z:
			break
	action("jump", true)
	for i: int in 180:
		await ticks(1)
		if str(player.get("mode")) == "mantle":
			return true
		if player.global_position.y >= 2.98 and player.global_position.z < -99.5:
			return false
	return false

func roof_fixture(name: String, at: Vector3) -> void:
	await fixture(name, at)
	player.call("reset_to", game.get("level").get("checkpoints")[2].pose)
	await ticks(3)
	check(int(game.get("checkpoint_index")) == 2, "fixture grants Outflow through its real roof region")
	player.call("reset_to", Transform3D(Basis.IDENTITY, at))
	await ticks(8)

func housing_toward_tower() -> void:
	await fixture("housing turns toward tower", Vector3(-21, 1.54, -90))
	var jumps: int = player.get("jump_count")
	action("move_forward", true)
	for i: int in 300:
		await ticks(1)
		if player.global_position.z <= -93.2:
			break
	action("jump", true)
	for i: int in 90:
		await ticks(1)
		if player.global_position.y > 2.6 and player.is_on_floor():
			break
	action("jump", false)
	check(player.global_position.y < 2.85 and int(game.get("checkpoint_index")) == 1,
		"landing on the low housing is still Yard; height alone does not admit Outflow: %s" % player.global_position)
	await walk(Vector3(-16, 2.5, -98.6), 240)
	await walk(Vector3(-6, .1, -95.3), 240)
	check(int(game.get("checkpoint_index")) == 2 and int(game.get("respawn_count")) == 0,
		"turning toward the tower from the housing admits Outflow")
	check(int(player.get("jump_count")) == jumps + 1, "housing-to-run-up line uses only its original jump")
	await fixture("roof bridge turns toward tower", Vector3(-21, 3.05, -98.9))
	jumps = player.get("jump_count")
	await walk(Vector3(-15, 2.4, -98.5), 240)
	check(int(game.get("checkpoint_index")) == 2 and int(game.get("respawn_count")) == 0,
		"walking east from the roof bridge admits Outflow")
	check(int(player.get("jump_count")) == jumps, "bridge approach needs no jump")

func finished_exploration() -> void:
	# start outside the expanded arrival strip, before establishing this fixture's Outflow stage.
	await roof_fixture("exploration preserves finished result", Vector3(24, -2.96, -62))
	await walk(Vector3(24, -3, -66.5), 200)
	check(bool(game.get("finished")), "fixture reaches the wheel through input")
	var time: float = game.get("elapsed")
	var splits: Array = game.get("splits").duplicate()
	var clean: bool = game.get("clean_eligible")
	var fell := false
	var returned := false
	action("move_forward", true)
	for i: int in 600:
		aim(Vector3(33.5, -3, -75))
		await ticks(1)
		fell = fell or player.global_position.y < -7.7
		if fell and player.global_position.y > -3.1:
			returned = true
			break
	action("move_forward", false)
	await ticks(10)
	check(fell and returned, "episode falls out of bounds and returns near the wheel")
	check(bool(game.get("finished")) and is_equal_approx(float(game.get("elapsed")), time) and str(game.get("finish_kind")) != "exploration",
		"a genuine post-finish fall retains the result, its kind and frozen clock")
	check(game.get("splits") == splits and bool(game.get("clean_eligible")) == clean and int(game.get("respawn_count")) == 0,
		"post-finish recovery does not turn the completed run into practice")
	check(not str(game.get("hud").get("finish_label").text).is_empty(), "result remains visible after exploration")

func wheel_guard() -> void:
	# p / ordinary arrivals stop at visible machinery guarding, including crouching.
	var episodes := [
		["front", Vector3(23.8, -2.96, -62), Vector3(23.8, -3, -72), false],
		["front crouched", Vector3(23.8, -2.96, -62), Vector3(23.8, -3, -72), true],
		["west", Vector3(18, -2.96, -66), Vector3(24, -3, -66), false],
		["east", Vector3(30, -2.96, -66), Vector3(24, -3, -66), false],
	]
	for episode: Array in episodes:
		await roof_fixture("wheel guard " + str(episode[0]), episode[1])
		aim(episode[2])
		action("crouch", episode[3])
		action("move_forward", true)
		await ticks(240)
		action("move_forward", false)
		var feet := player.global_position
		var outside: bool = feet.z > -64.25 if str(episode[0]).begins_with("front") else (feet.x < 20.5 if episode[0] == "west" else feet.x > 27.5)
		check(outside and player.is_on_floor() and int(game.get("respawn_count")) == 0,
			"held input stops outside the visible machinery bay: %s" % feet)
		check(bool(game.get("finished")) and str(game.get("finish_kind")) == "clean",
			"the guard never refuses an ordered arrival")
		action("crouch", false)

func hardware_frame(id: String) -> void:
	if hardware_views.is_empty():
		return
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(hardware_views.path_join(id + ".png"))

func hardware_collision() -> void:
	for x: float in [-35, -31]:
		await roof_fixture("reachable roof vent %.0f" % x, Vector3(x, 3.04, -104))
		aim(Vector3(x, 3, -112))
		action("move_forward", true)
		await ticks(110)
		action("move_forward", false)
		check(player.global_position.z > -107.35 and player.is_on_floor(),
			"walking meets the actual shaft instead of crossing its centre: %s" % player.global_position)
		await hardware_frame("vent%.0f" % x)
		var around := await walk(Vector3(x + 1.3, 3, -106.8), 160)
		around = await walk(Vector3(x + 1.3, 3, -109.1), 160) and around
		check(around and player.is_on_floor() and int(game.get("respawn_count")) == 0,
			"the visible space beside the vent remains a usable roof line")
	await fixture("crest valve catch approach", Vector3(-3, 4.04, -42), false)
	var jumps: int = player.get("jump_count")
	var mantles: int = player.get("mantle_count")
	aim(Vector3(-3, 4, -34))
	action("move_forward", true)
	for i: int in 120:
		await ticks(1)
		if player.global_position.z > -40.4:
			break
	action("jump", true)
	await ticks(130)
	action("jump", false)
	action("move_forward", false)
	check(int(player.get("jump_count")) == jumps + 1 and int(player.get("mantle_count")) == mantles + 1 and player.global_position.y > 5.55,
		"the original jump and catch still reach the valve housing")
	check(player.global_position.z < -37.5 and int(game.get("respawn_count")) == 0,
		"the fixed wheel rim stops forward passage through its assembly: %s" % player.global_position)
	await hardware_frame("crest-valve")
	await fixture("yard valve jumping approach", Vector3(-30, 1.54, -76))
	jumps = player.get("jump_count")
	aim(Vector3(-38, 1.5, -76))
	action("move_forward", true)
	for i: int in 240:
		await ticks(1)
		if player.global_position.x < -31.7:
			break
	action("jump", true)
	await ticks(12)
	action("jump", false)
	await ticks(110)
	action("move_forward", false)
	check(int(player.get("jump_count")) == jumps + 1 and player.global_position.y > 2.65,
		"the original single jump still reaches the plinth")
	check(player.global_position.x > -34.1 and int(game.get("respawn_count")) == 0,
		"the plinth wheel remains a physical obstacle: %s" % player.global_position)
	await hardware_frame("yard-valve")

func hop(at: Vector3, toward: Vector3, axis: int, past: float, direction: float) -> void:
	# one ordinary running jump: hold forward, press jump once past a takeoff line, land.
	aim(toward)
	action("move_forward", true)
	for i: int in 240:
		await ticks(1)
		if (player.global_position[axis] - past) * direction > 0:
			break
	action("jump", true)
	await ticks(12)
	action("jump", false)
	for i: int in 240:
		await ticks(1)
		if player.is_on_floor():
			break
	action("move_forward", false)
	# the run loop reads a landing on the physics frame after it happens.
	await ticks(3)

func floor_name() -> String:
	for i: int in player.get_slide_collision_count():
		var contact: KinematicCollision3D = player.get_slide_collision(i)
		if contact.get_normal().y > .6:
			return str((contact.get_collider() as Node).name)
	return "-"

func deck_progress() -> void:
	# r10: the r9 rail-hop repro; progress follows the deck actually reached.
	await fixture("apron rail hop onto the run-up", Vector3(-14, 1.55, -94))
	var jumps: int = player.get("jump_count")
	await hop(Vector3(-14, 1.55, -94), Vector3(-14, 1.5, -102), 2, -94.4, -1)
	check(floor_name() == "OutflowRunup" and int(game.get("checkpoint_index")) == 2 and int(game.get("respawn_count")) == 0,
		"one jump over the apron rail lands on the run-up and admits Outflow: %s on %s" % [player.global_position, floor_name()])
	check(int(player.get("jump_count")) == jumps + 1, "the rail hop is a single ordinary jump")
	for target: Vector3 in [Vector3(-6, .1, -95.3), Vector3(-7, -6, -91), Vector3(-10, -6, -82), Vector3(-10, -3, -63.5), Vector3(15, -3, -65), Vector3(23.8, -3, -68.8)]:
		if bool(game.get("finished")):
			break
		await walk(target, 900)
	check(bool(game.get("finished")) and str(game.get("finish_kind")) == "clean" and game.get("splits").size() == 3 and int(game.get("respawn_count")) == 0,
		"walking on through basin recovery finishes the run as an ordered result")
	check(float(game.get("best_time")) > 0.0 and not "EXPLORATION" in str(game.get("hud").get("finish_label").text), "the ordered rail-hop finish is recorded")
	await fixture("apron corner hop onto the run-up", Vector3(-14, 1.55, -92))
	await hop(Vector3(-14, 1.55, -92), Vector3(-6, 1.5, -97), 0, -12.2, 1)
	check(floor_name() == "OutflowRunup" and int(game.get("checkpoint_index")) == 2, "a diagonal hop off the apron corner also lands on the run-up and admits Outflow")
	# hops from the yard crossing reach finale decks; those stay catches, never entries.
	# the old entry-ramp-to-apron hop is retired: visible screening now guards that drop.
	# terrace_direction checks its physical replacement and the open path into the yard.
	for hop_case: Array in [["crossing hop onto first support", Vector3(2, 4.05, -74), Vector3(2, 4, -90), 2, -76.4, -1.0],
			["crossing hop into basin", Vector3(7, 4.05, -74), Vector3(7, 4, -90), 2, -76.4, -1.0],
			["apron east hop into basin", Vector3(-13.5, 1.55, -82), Vector3(0, 1.5, -82), 0, -11.6, 1.0]]:
		await fixture(hop_case[0], hop_case[1])
		await hop(hop_case[1], hop_case[2], hop_case[3], hop_case[4], hop_case[5])
		check(player.global_position.y < 0.0 and int(game.get("checkpoint_index")) == 1 and int(game.get("respawn_count")) == 0,
			"the hop lands below the yard without claiming Outflow: %s on %s" % [player.global_position, floor_name()])
	# the last hop left the runner in the basin; the wheel still runs, unrecorded.
	var best: float = game.get("best_time")
	var best_splits: Array = game.get("best_splits").duplicate()
	for target: Vector3 in [Vector3(-10, -6, -80), Vector3(-10, -3, -63.5), Vector3(15, -3, -65), Vector3(23.8, -3, -68.8)]:
		if bool(game.get("finished")):
			break
		await walk(target, 900)
	var text: String = game.get("hud").get("finish_label").text
	check(bool(game.get("finished")) and str(game.get("finish_kind")) == "exploration" and bool(game.get("level").get("_wheel_running")),
		"physical arrival after skipping Outflow starts the wheel as an exploration finish")
	check(float(game.get("best_time")) == best and game.get("best_splits") == best_splits and game.get("splits").size() == 1,
		"the exploration finish keeps the earlier best and records only the measured Crest split")
	check("EXPLORATION FINISH" in text and "Skipped Outflow" in text and not "CLEAN BEST" in text, "the result names the skipped Outflow and is not a record")
	action("restart", true)
	await ticks(2)
	action("restart", false)
	await ticks(2)
	check(not bool(game.get("finished")) and str(game.get("finish_kind")).is_empty() and int(game.get("checkpoint_index")) == 0 and bool(game.get("clean_eligible")),
		"R after the exploration finish starts a fresh clean attempt")
	# seeded: decks admit only the next stage, from the crest as well.
	await fixture("seeded crest pose on the run-up", Vector3(-12, 2.4, -98.2), false)
	await ticks(30)
	check(floor_name() == "OutflowRunup" and int(game.get("checkpoint_index")) == 0, "an Outflow deck cannot skip an unvisited yard")
	await fixture("seeded crest pose on the lower yard", Vector3(-25, 1.55, -76), false)
	await ticks(30)
	check(floor_name() == "SluiceYardApron" and int(game.get("checkpoint_index")) == 1 and game.get("splits").size() == 1, "standing on the lower yard apron admits the yard")
	await walk(Vector3(-25, 1.5, -88), 300)
	check(int(game.get("checkpoint_index")) == 1, "walking across the lower yard stays Yard")
	# cached contacts from the last deck cannot grant progress at the reset destination.
	action("restart", true)
	await ticks(1)
	action("restart", false)
	check(int(game.get("checkpoint_index")) == 0, "R from a tagged yard deck keeps Crest progress at spawn")
	await ticks(4)
	check(int(game.get("checkpoint_index")) == 0, "old yard contact cannot advance the fresh run")
	await fixture("restart after tagged Outflow contact", Vector3(-14, 1.55, -94))
	await hop(Vector3(-14, 1.55, -94), Vector3(-14, 1.5, -102), 2, -94.4, -1)
	check(floor_name() == "OutflowRunup" and int(game.get("checkpoint_index")) == 2, "restart starts with a real Outflow floor contact")
	game.call("restart_run")
	await ticks(3)
	check(int(game.get("checkpoint_index")) == 0 and player.global_position.distance_to(game.get("level").get("spawn").origin) < .2, "R from Outflow leaves no stale stage admission")


func terrace_direction() -> void:
	# p / visible maintenance screens keep the direct tower drop from reading as the route.
	for start: Vector3 in [Vector3(15.5, 4.04, -59), Vector3(11, 4.04, -65)]:
		await fixture("terrace tower-facing screen %.1f" % start.z, start, false)
		aim(Vector3(26, 4, -67))
		action("move_forward", true)
		action("jump", true)
		await ticks(180)
		action("jump", false)
		action("move_forward", false)
		check(player.global_position.y > 3.95 and not bool(game.get("finished")),
			"ordinary forward jump meets visible screening instead of dropping straight to the wheel: %s" % player.global_position)
		check(int(game.get("respawn_count")) == 0, "meeting the maintenance screen needs no reset")
	await fixture("terrace continuation to yard", Vector3(10, 4.04, -59), false)
	check(await walk(Vector3(10, 4, -73)), "the broad opening still leads south from the terrace")
	check(await walk(Vector3(-12, 4, -74)), "the unobstructed crossing turns west toward the yard")
	check(int(game.get("checkpoint_index")) == 1 and int(game.get("respawn_count")) == 0,
		"ordinary continuation discovers Yard before the finish")


func wheel_front_strip() -> void:
	# p / walking beside the visible wheel guard is arrival; no jump into machinery is required.
	for x: float in [19.0, 29.0]:
		await roof_fixture("front wheel approach %.0f" % x, Vector3(x, -2.96, -63.17))
		var jumps: int = player.get("jump_count")
		await walk(Vector3(24, -3, -63.17), 300)
		check(bool(game.get("finished")) and str(game.get("finish_kind")) == "clean",
			"ordinary walking along the front strip reaches the wheel from either side")
		check(int(player.get("jump_count")) == jumps and int(game.get("respawn_count")) == 0,
			"the machinery enclosure needs no jump or reset to finish")


func basin_ramp_width() -> void:
	# p / the sol basin player met a pier inside the yellow-railed exit; every lane now climbs.
	for x: float in [-11.9, -10.0, -8.1]:
		await roof_fixture("basin exit ramp lane %.1f" % x, Vector3(x, -5.96, -82.5))
		var jumps: int = player.get("jump_count")
		await walk(Vector3(x, -3, -64.5), 600)
		var feet := player.global_position
		check(feet.z > -65.5 and feet.y > -3.2 and absf(feet.x - x) < 0.25,
			"walking straight up the ramp from the basin reaches the landing in its own lane: %s" % feet)
		check(int(player.get("jump_count")) == jumps and int(game.get("respawn_count")) == 0,
			"the basin exit needs no jump or reset")
	# a standing capsule fits anywhere between the rails along the whole incline.
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.8
	query.shape = shape
	query.exclude = [player.get_rid()]
	var blocked: Array[Vector3] = []
	for step: int in 27:
		var z := -78.5 + step * 0.5
		for lane: float in [-11.9, -11.4, -10.0, -8.6, -8.1]:
			var at := Vector3(lane, -6.0 + 3.0 * (z + 79.0) / 14.0 + 0.95, z)
			query.transform = Transform3D(Basis.IDENTITY, at)
			if not space.intersect_shape(query, 1).is_empty():
				blocked.append(at)
	check(blocked.is_empty(), "no support or hardware occupies the ramp between its rails: %s" % [blocked])


func static_batch_shadows() -> void:
	label = "static batches keep requested shadows"
	# p / batching must not turn the see-through terrace screens back into solid shadow casters.
	var screen_instances := 0
	var screens_cast := false
	for batch: Node in game.get("level").find_children("*", "MultiMeshInstance3D", true, false):
		var shader_material := (batch as MultiMeshInstance3D).material_override as ShaderMaterial
		if shader_material != null and shader_material.shader.resource_path.ends_with("spillway_screen.gdshader"):
			screen_instances += (batch as MultiMeshInstance3D).multimesh.instance_count
			screens_cast = screens_cast or (batch as MultiMeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	check(screen_instances == 4 and not screens_cast, "the four terrace screen panels stay batched without casting shadows")
	# one material with mixed shadow requests splits; moving geometry stays live.
	var fixture: Node3D = load("res://scripts/spillway_level.gd").new()
	root.add_child(fixture)
	var material := StandardMaterial3D.new()
	fixture.get("_materials")["fixture"] = material
	fixture.call("_box", Vector3(-1, 0, 0), Vector3.ONE, "fixture")
	var shadowless: Node3D = fixture.call("_box", Vector3(1, 0, 0), Vector3.ONE, "fixture")
	(shadowless.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var moving := Node3D.new()
	moving.set_meta("moving_geometry", true)
	fixture.add_child(moving)
	var live := MeshInstance3D.new()
	live.mesh = BoxMesh.new()
	live.material_override = material
	moving.add_child(live)
	fixture.call("_batch_static_boxes")
	await process_frame
	var states: Array[String] = []
	for batch: Node in fixture.find_children("*", "MultiMeshInstance3D", true, false):
		states.append("%d:%d" % [(batch as MultiMeshInstance3D).cast_shadow, (batch as MultiMeshInstance3D).multimesh.instance_count])
	states.sort()
	check(states == ["0:1", "1:1"] and is_instance_valid(live), "a shared material batches shadowed and shadowless boxes apart: %s" % [states])
	fixture.queue_free()


func run() -> void:
	game = load("res://scripts/spillway_main.gd").new()
	root.add_child(game)
	game.set("_persist", false)
	player = game.get("player")
	await fixture("west yard corner", Vector3(-9, 4.05, -56.5), false)
	check(await walk(Vector3(7.7, 4, -62.8)), "corner can be reached with ordinary input")
	check(await walk(Vector3(9.9, 4, -69.5)), "entry ramp continues without a reset")
	check(int(game.get("checkpoint_index")) == 1 and int(game.get("respawn_count")) == 0, "cutting the west corner still admits the yard")
	for x: float in [-14, -12.2]:
		await fixture("guarded low apron %.1f" % x, Vector3(x, 1.55, -94))
		aim(Vector3(x, 1.5, -102))
		action("move_forward", true)
		await ticks(300)
		check(player.global_position.z > -97.0 and int(game.get("checkpoint_index")) == 1, "ordinary running cannot step from the low apron onto the finale run-up")
	await fixture("guarded diagonal junction", Vector3(-14, 1.55, -90))
	await walk(Vector3(-12, 1.5, -96.2), 240)
	await walk(Vector3(-5, 0, -95), 300)
	check(player.global_position.x < -11.2 and player.global_position.y >= 1.35 and int(game.get("checkpoint_index")) == 1,
		"the east opening is guarded too; ordinary diagonal running stays on the apron: %s" % player.global_position)
	await fixture("continuous housing line", Vector3(-21, 1.54, -90))
	var jumps: int = player.get("jump_count")
	await approach_roof(-21, -93.2)
	await ticks(80)
	check(player.global_position.y >= 2.98 and player.global_position.z < -99.5 and int(game.get("checkpoint_index")) == 2, "one jump onto the housing runs smoothly onto the roof: %s mode=%s" % [player.global_position, player.get("mode")])
	check(int(player.get("jump_count")) == jumps + 1, "the former slot and curb need no second jump")
	await fixture("actual roof mantle", Vector3(-23.3, 1.54, -90))
	var caught := await approach_roof(-23.3, -96.4)
	check(caught, "held forward and jump catch the actual roof beside the housing")
	await ticks(100)
	check(player.global_position.y >= 2.98 and int(game.get("checkpoint_index")) == 2, "authored mantle lands in the Outflow admission region")
	await fixture("actual roof mantle cancellation", Vector3(-23.3, 1.54, -90))
	caught = await approach_roof(-23.3, -96.4)
	check(caught, "cancellation episode reaches a real catch")
	if caught:
		var count: int = player.get("mantle_count")
		action("move_back", true)
		await ticks(2)
		check(str(player.get("mode")) != "mantle", "backward input cancels the actual roof catch promptly")
		action("move_back", false)
		await ticks(20)
		check(int(player.get("mantle_count")) == count, "the same held jump cannot immediately recatch")
	for start: Vector3 in [Vector3(16, -2.96, -65), Vector3(32, -2.96, -64)]:
		await fixture("direct wheel approach %.0f" % start.x, start)
		var roof: Transform3D = game.get("level").get("checkpoints")[2].pose
		player.call("reset_to", roof)
		await ticks(3)
		check(int(game.get("checkpoint_index")) == 2, "fixture grants Outflow through its real roof region")
		player.call("reset_to", Transform3D(Basis.IDENTITY, start))
		await ticks(8)
		await walk(Vector3(23.8, -3, -68.8))
		check(bool(game.get("finished")), "walking directly to the wheel finishes from either side")
	await housing_toward_tower()
	await deck_progress()
	await wheel_guard()
	await hardware_collision()
	await finished_exploration()
	await terrace_direction()
	await wheel_front_strip()
	await basin_ramp_width()
	await static_batch_shadows()
	for key: String in ["move_forward", "move_back", "jump", "crouch"]:
		action(key, false)
	print("spillway access: %d/%d checks passed; explicit authored-level fixtures, not whole-route proof" % [checks - failures, checks])
	game.call("request_quit", 1 if failures else 0)

extends SceneTree
## p / spillway behavioral acceptance. Every episode below is an isolated fixture,
## not route proof. Only reset_to sets a pose; labelled drop fixtures seed velocity.

const ACTIONS: Array[String] = ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch"]
var checks: int = 0
var failures: int = 0
var fixture: Node3D
var player: CharacterBody3D
var motor: GDScript
var trace: FileAccess
var case_name: String = "setup"
var frame: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("%s [%s] %s" % ["PASS" if ok else "FAIL", case_name, label])
	if not ok:
		failures += 1

func action(name: String, pressed: bool, strength: float = 1.0) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	event.strength = strength if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release_all() -> void:
	for name: String in ACTIONS:
		action(name, false)

func mouse(delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = delta
	event.screen_relative = delta
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func ticks(count: int) -> void:
	for i: int in count:
		await physics_frame
		frame += 1
		if trace != null and is_instance_valid(player):
			trace.store_line(JSON.stringify({"fixture": case_name, "frame": frame,
				"position": vec(player.position), "velocity": vec(player.velocity),
				"mode": player.get("mode"), "grounded": player.is_on_floor()}))

func vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.position = center
	body.add_child(collision)
	fixture.add_child(body)
	return body

func fresh(label: String, floor_size: Vector3 = Vector3(160, 1, 160), floor_center: Vector3 = Vector3(0, -.5, 0)) -> void:
	release_all()
	if is_instance_valid(fixture):
		fixture.queue_free()
		await process_frame
	case_name = label
	fixture = Node3D.new()
	root.add_child(fixture)
	if floor_size != Vector3.ZERO:
		box(floor_center, floor_size)
	player = motor.new() as CharacterBody3D
	fixture.add_child(player)
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(0, .025, 0)))
	await ticks(8)

func _run() -> void:
	var motor_path: String = "res://scripts/spillway_player.gd"
	if not ResourceLoader.exists(motor_path):
		printerr("spillway: motor unavailable at ", motor_path)
		quit(2)
		return
	motor = load(motor_path) as GDScript
	if motor == null or not motor.can_instantiate():
		printerr("spillway: motor could not be parsed/instantiated")
		quit(2)
		return
	var main_path: String = "res://scripts/spillway_main.gd"
	if FileAccess.file_exists(main_path) and FileAccess.file_exists("res://scripts/spillway_level.gd"):
		var main_script: GDScript = load(main_path) as GDScript
		if main_script != null and main_script.has_method("bind_inputs"):
			main_script.call("bind_inputs")
	for name: String in ACTIONS + ["look_left", "look_right", "look_down", "look_up"]:
		if not InputMap.has_action(name):
			InputMap.add_action(name, .1)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			var path: String = arg.trim_prefix("--evidence-dir=").simplify_path()
			if not preload("res://scripts/spillway_driver.gd").evidence_path_allowed(path):
				printerr("spillway: evidence directory must be absolute and outside Git")
				quit(2)
				return
			DirAccess.make_dir_recursive_absolute(path)
			trace = FileAccess.open(path.path_join("movement-fixtures.jsonl"), FileAccess.WRITE)
			if trace == null:
				printerr("spillway: cannot open fixture trace")
				quit(2)
				return
	await responsiveness()
	await braking_intent()
	await jump_grace()
	await air_control()
	await ground_budget_reset()
	await water_recovery()
	await handoffs()
	await crouch_policy()
	await ceiling()
	await late_crouch_eye()
	await ramps()
	await authored_stairs()
	await mantles()
	release_all()
	if trace != null:
		trace.close()
	fixture.queue_free()
	print("spillway: %d/%d checks passed; isolated collision fixtures, route playback separate" % [checks - failures, checks])
	quit(1 if failures else 0)

func responsiveness() -> void:
	await fresh("responsive run / brake / reverse")
	action("move_forward", true)
	await ticks(6)
	check(player.get_speed() > 1.0, "useful motion by 50ms: %.3fm/s" % player.get_speed())
	await ticks(36)
	check(player.get_speed() >= 7.5, "running speed by 350ms: %.3fm/s" % player.get_speed())
	action("move_forward", false)
	await ticks(36)
	check(player.get_speed() < .8, "release brakes within 300ms: %.3fm/s" % player.get_speed())
	action("move_forward", true)
	await ticks(48)
	action("move_forward", false)
	action("move_back", true)
	await ticks(48)
	check(player.velocity.z > 1.0, "reverse becomes backward movement within 400ms: %.3f" % player.velocity.z)

func jump_grace() -> void:
	await fresh("coyote grace", Vector3(12, 1, 8), Vector3(0, -.5, 3))
	action("move_forward", true)
	var departed: bool = false
	for i: int in 100:
		await ticks(1)
		if not player.is_on_floor():
			departed = true
			break
	check(departed, "walked off actual support edge")
	await ticks(6)
	action("jump", true)
	await ticks(2)
	check(int(player.get("jump_count")) == 1 and player.velocity.y > 4, "jump at 50ms after edge launches")
	await fresh("expired coyote", Vector3(12, 1, 8), Vector3(0, -.5, 3))
	action("move_forward", true)
	for i: int in 100:
		await ticks(1)
		if not player.is_on_floor():
			break
	await ticks(20)
	action("jump", true)
	await ticks(2)
	check(int(player.get("jump_count")) == 0 and player.velocity.y < 0, "167ms after edge cannot jump")
	await fresh("buffered jump / drop fixture")
	player.set("autohop", false)
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(0, 2, 0)))
	# fixture: falling seed bypasses the wait to apex, never used by route playback.
	player.velocity = Vector3(0, -3, 0)
	var requested: bool = false
	for i: int in 150:
		await ticks(1)
		if player.position.y < .35 and player.velocity.y < 0 and not requested:
			action("jump", true)
			requested = true
			await ticks(2)
			action("jump", false)
		if int(player.get("jump_count")) > 0:
			break
	check(requested and not Input.is_action_pressed("jump") and int(player.get("jump_count")) == 1 and player.velocity.y > 4, "a released tap just before contact jumps from its buffer with autohop off")
	action("jump", false)
	await ticks(110)
	check(int(player.get("jump_count")) == 1, "one buffered press produces one jump")
	# r12: autohop (on by default) turns a held press into a hop on landing, so buffer
	# expiry is checked with the autohop setting off, and the held hop is checked with it on.
	await fresh("expired buffer, autohop off / drop fixture")
	player.set("autohop", false)
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(0, 3, 0)))
	player.velocity = Vector3(0, -3, 0)
	await ticks(18)
	action("jump", true)
	await ticks(130)
	check(player.is_on_floor() and int(player.get("jump_count")) == 0, "a held press more than 120ms before landing expires")
	await fresh("held autohop / drop fixture")
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(0, 3, 0)))
	player.velocity = Vector3(0, -3, 0)
	await ticks(18)
	action("jump", true)
	var held_jumps: Array[int] = []
	for i: int in 200:
		await ticks(1)
		if int(player.get("jump_count")) > held_jumps.size():
			held_jumps.append(frame)
	check(held_jumps.size() >= 2 and int(player.get("hop_count")) == held_jumps.size(),
		"held jump rehops on each landing tick with autohop on: %d hops" % held_jumps.size())
	action("jump", false)

func air_control() -> void:
	await fresh("standing jump air correction")
	action("jump", true)
	await ticks(2)
	action("jump", false)
	action("move_right", true)
	await ticks(30)
	# r12 retires the r11 vx>1.0 bound: a strafe from standstill reaches only the source-style wish cap.
	check(not player.is_on_floor() and player.velocity.x >= .74 and player.velocity.x <= .76 and player.position.x > .12,
		"zero-speed launch has visible air correction up to the wish cap: x=%.3f vx=%.3f" % [player.position.x, player.velocity.x])
	await fresh("air look independence / excess-speed launch fixture")
	player.velocity = Vector3(0, 0, -11)
	action("jump", true)
	await ticks(2)
	action("jump", false)
	var before: Vector3 = player.velocity
	var yaw_before: float = float(player.get("yaw"))
	var pitch_before: float = float(player.get("pitch"))
	mouse(Vector2(390, -80))
	await ticks(12)
	check(absf(angle_difference(yaw_before, float(player.get("yaw")))) > .4 and absf(float(player.get("pitch")) - pitch_before) > .05,
		"mouse yaw and pitch stay live airborne")
	check(Vector2(player.velocity.x - before.x, player.velocity.z - before.z).length() < .05,
		"looking alone leaves horizontal velocity unchanged")
	# restore the look angle so side input is perpendicular, not intentional braking.
	mouse(Vector2(-390, 80))
	action("move_right", true)
	await ticks(30)
	var launch_speed: float = Vector2(before.x, before.z).length()
	# r12: speed gain needs the mouse turning with the strafe; a held strafe alone adds one wish cap at most.
	check(launch_speed > 9.5 and player.get_speed() >= launch_speed * .99 and player.get_speed() <= launch_speed + .05,
		"held strafe without turning keeps launch speed and adds no pumping: %.3f / %.3f" % [player.get_speed(), launch_speed])

func ground_budget_reset() -> void:
	await fresh("landing and braking discard stale air budget", Vector3(12, 1, 26), Vector3(0, -.5, -3))
	# fixture: a high-speed launch, then ordinary landing/braking and a new edge departure.
	player.velocity = Vector3(0, 0, -16)
	action("jump", true)
	await ticks(2)
	action("jump", false)
	await ticks(170)
	check(player.is_on_floor() and player.get_speed() < .1, "high-speed flight lands and brakes on actual platform")
	action("move_forward", true)
	var departed: bool = false
	for i: int in 180:
		await ticks(1)
		if not player.is_on_floor():
			departed = true
			break
	check(departed, "new run leaves a real edge after the landing")
	action("move_right", true)
	var peak: float = player.get_speed()
	for i: int in 90:
		await ticks(1)
		peak = maxf(peak, player.get_speed())
	check(peak <= 8.7, "unturned air steering after a braked landing cannot recover the old sixteen-metre speed: %.3f" % peak)

func handoffs() -> void:
	await fresh("ordinary landing preserves motion")
	action("move_forward", true)
	await ticks(48)
	action("jump", true)
	await ticks(2)
	action("jump", false)
	var landed: bool = false
	var previous_speed: float = player.get_speed()
	var landing_speed: float = 0
	for i: int in 150:
		await ticks(1)
		if player.is_on_floor():
			landed = true
			landing_speed = player.get_speed()
			break
		previous_speed = player.get_speed()
	check(landed and landing_speed >= previous_speed * .9, "ordinary landing retains >=90%% approach: %.3f / %.3f" % [landing_speed, previous_speed])
	for i: int in 10:
		await ticks(1)
		check(player.get_speed() > 7, "landing +%d has no control freeze" % (i + 1))
	await fresh("slide release / excess-speed fixture")
	# fixture: a fast initial velocity stands in for a downhill run-up.
	player.velocity = Vector3(0, 0, -12)
	action("move_forward", true)
	action("crouch", true)
	await ticks(8)
	check(str(player.get("mode")) == "slide", "fast crouch enters slide")
	var before: float = player.get_speed()
	action("crouch", false)
	await ticks(2)
	check(str(player.get("mode")) != "slide" and player.get_speed() > before * .9,
		"slide release preserves excess speed: %.3f / %.3f" % [player.get_speed(), before])
	await fresh("slide jump interrupts / excess-speed fixture")
	player.velocity = Vector3(0, 0, -12)
	action("move_forward", true)
	action("crouch", true)
	await ticks(8)
	before = player.get_speed()
	action("jump", true)
	await ticks(2)
	check(str(player.get("mode")) == "air" and player.velocity.y > 4 and player.get_speed() > before * .9,
		"slide jump releases with useful launch motion")
	await fresh("flat crouch pumping")
	action("move_forward", true)
	await ticks(60)
	var peak: float = player.get_speed()
	for i: int in 16:
		action("crouch", true)
		await ticks(6)
		peak = maxf(peak, player.get_speed())
		action("crouch", false)
		await ticks(6)
		peak = maxf(peak, player.get_speed())
	check(peak <= 8.7, "16 flat crouch presses create no extra speed: peak %.3f" % peak)

func crouch_policy() -> void:
	await fresh("flat crouch walking never slides")
	action("crouch", true)
	action("move_forward", true)
	var slide_ticks: int = 0
	for i: int in 360:
		await ticks(1)
		if player.get("mode") == "slide":
			slide_ticks += 1
	check(slide_ticks == 0, "three seconds of crouch walking has no slide ownership: %d ticks" % slide_ticks)
	check(player.get_speed() > 3.0 and player.get_speed() < 3.4, "crouch walking remains responsive at its intended speed")
	await fresh("slide backward input brakes")
	action("move_forward", true)
	await ticks(48)
	action("crouch", true)
	await ticks(2)
	action("move_forward", false)
	action("move_back", true)
	await ticks(40)
	check(player.get_speed() < 4.5, "backward input brakes an active slide promptly")
	check(absf(player.velocity.x) < .1, "braking does not curve sideways")

func braking_intent() -> void:
	for speed: float in [8.5, 16.0]:
		var stops: Array[Vector2] = []
		for reverse: bool in [false, true]:
			await fresh("brake %.1f m/s, reverse=%s" % [speed, reverse])
			await ticks(8)
			# labelled momentum fixture: seed the speed of a run or fast slide exit.
			player.velocity = Vector3(0, 0, -speed)
			var origin := player.global_position
			action("move_back", reverse)
			var distance := 0.0
			var seconds := 0.0
			for i: int in 180:
				await ticks(1)
				seconds += 1.0 / 120.0
				distance = maxf(distance, origin.z - player.global_position.z)
				if player.velocity.z >= -0.05:
					break
			stops.append(Vector2(seconds, distance))
		check(stops[1].x <= stops[0].x + 0.009,
			"opposing input stops at least as promptly as releasing: %.3f vs %.3f s" % [stops[1].x, stops[0].x])
		check(stops[1].y <= stops[0].y + 0.025,
			"opposing input never carries farther forward than release: %.3f vs %.3f m" % [stops[1].y, stops[0].y])

func ceiling() -> void:
	await fresh("crouch ceiling clearance")
	box(Vector3(0, 1.45, -4), Vector3(8, .3, 5))
	action("crouch", true)
	action("move_forward", true)
	var entered: bool = false
	for i: int in 150:
		await ticks(1)
		if player.position.z < -2.3:
			entered = true
			break
	check(entered and bool(player.get("crouched")), "low capsule enters real 1.3m passage")
	action("move_forward", false)
	action("crouch", false)
	await ticks(25)
	check(bool(player.get("crouched")) and player.position.y < .12, "release under ceiling stays low without popping body")
	action("move_forward", true)
	for i: int in 360:
		await ticks(1)
		if player.position.z < -7.0:
			break
	check(player.position.z < -7.0 and not bool(player.get("crouched")), "clearance exit restores standing")

func late_crouch_eye() -> void:
	for lead: float in [0.4, 0.6]:
		await fresh("late crouch eye, %.1f m lead" % lead, Vector3.ZERO)
		var level: Node3D = preload("res://scripts/spillway_level.gd").new()
		fixture.add_child(level)
		level.call("build")
		player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(-27.5, 1.525, -76)))
		await ticks(12)
		action("move_forward", true)
		for i: int in 180:
			await ticks(1)
			if player.position.z <= -81.45 + lead:
				break
		action("crouch", true)
		var overlaps: int = 0
		var crossed: bool = false
		var near_volume := SphereShape3D.new()
		near_volume.radius = 0.055
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = near_volume
		query.collision_mask = 1
		for i: int in 60:
			await ticks(1)
			query.transform = Transform3D(Basis.IDENTITY, player.get("camera").global_position)
			for hit: Dictionary in player.get_world_3d().direct_space_state.intersect_shape(query, 8):
				if str(hit.collider.name).begins_with("HalfOpenSluiceGate"):
					overlaps += 1
			crossed = crossed or player.position.z < -82.8
		check(crossed, "the late crouch still passes the actual sluice gate")
		check(overlaps == 0, "the eye and its near volume never enter the gate")
		action("crouch", false)
		await ticks(80)
		var height: float = player.get("camera").global_position.y - player.global_position.y
		check(not bool(player.get("crouched")) and absf(height - 1.63) < 0.03,
			"leaving the gate restores the standing eye smoothly")

func make_ramp() -> void:
	# fixture: continuous collision ramp, decorative stair nosings have no bodies.
	box(Vector3(0, -.5, 6), Vector3(20, 1, 20))
	box(Vector3(0, .75, -24), Vector3(20, 2.5, 20))
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-10, 0, -4), Vector3(10, 0, -4), Vector3(-10, 2, -14), Vector3(10, 2, -14),
		Vector3(-10, -.5, -4), Vector3(10, -.5, -4), Vector3(-10, -.5, -14), Vector3(10, -.5, -14)])
	collision.shape = shape
	body.add_child(collision)
	fixture.add_child(body)

func ramps() -> void:
	for variant: String in ["ascent", "descent", "slow", "diagonal"]:
		await fresh("ramp seams " + variant, Vector3.ZERO)
		make_ramp()
		var reverse: bool = variant == "descent"
		player.call("reset_to", Transform3D(Basis(Vector3.UP, PI if reverse else 0.0),
			Vector3(0, 2.025, -18) if reverse else Vector3(-3 if variant == "diagonal" else 0, .025, 0)))
		await ticks(10)
		action("move_forward", true, .35 if variant == "slow" else 1.0)
		if variant == "diagonal":
			action("move_right", true, .3)
		var residual_min: float = INF
		var residual_max: float = -INF
		var max_jitter: float = 0
		var previous_residual: float = NAN
		var airborne: int = 0
		var crossed: bool = false
		var camera: Camera3D = player.get("camera") as Camera3D
		for i: int in 1800:
			await ticks(1)
			var z: float = player.position.z
			var expected_y: float = clampf((-z - 4) * .2, 0, 2)
			if z < -2 and z > -16:
				var residual: float = camera.global_position.y - expected_y
				residual_min = minf(residual_min, residual)
				residual_max = maxf(residual_max, residual)
				if is_finite(previous_residual):
					max_jitter = maxf(max_jitter, absf(residual - previous_residual))
				previous_residual = residual
				if not player.is_on_floor():
					airborne += 1
			if (reverse and z > -1) or (not reverse and z < -17):
				crossed = true
				break
		check(crossed, "crossed both real ramp/landing seams at %s" % player.position)
		check(airborne <= 3, "continuous support across seams: %d unsupported ticks" % airborne)
		check(max_jitter < .055 and residual_max - residual_min < .20,
			"camera residual against expected slope: step %.4f range %.4f" % [max_jitter, residual_max - residual_min])

func mantle_fixture(label: String) -> void:
	await fresh(label)
	box(Vector3(0, .8, -3.5), Vector3(5, 1.6, 3))
	await ticks(2)

func approach_mantle(hold_jump: bool) -> bool:
	action("move_forward", true)
	await ticks(14)
	if hold_jump:
		action("jump", true)
	for i: int in 110:
		await ticks(1)
		if str(player.get("mode")) == "mantle":
			return true
	return false

func mantles() -> void:
	await mantle_fixture("optional mantle catch")
	var caught: bool = await approach_mantle(true)
	if not caught:
		# mantle may be deliberately cut from spillway; never silently accept a broken enabled catch.
		var explicitly_disabled: bool = false
		for property: Dictionary in player.get_property_list():
			if property.name == "mantle_enabled":
				explicitly_disabled = not bool(player.get("mantle_enabled"))
		if explicitly_disabled:
			print("SKIP optional mantle: motor explicitly disables mantle_enabled")
			return
	check(caught, "airborne held forward+jump catches reachable lip")
	if caught:
		var yaw_before: float = float(player.get("yaw"))
		mouse(Vector2(100, -30))
		await ticks(1)
		check(absf(angle_difference(yaw_before, float(player.get("yaw")))) > .1, "look stays live during catch")
		for i: int in 100:
			await ticks(1)
			if str(player.get("mode")) != "mantle":
				break
		check(player.position.y >= 1.5 and player.position.z < -1.9 and player.get_speed() > 1,
			"successful mantle reaches roof with outgoing motion: %s speed=%.3f" % [player.position, player.get_speed()])
	for cancel: String in ["release", "backward"]:
		await mantle_fixture("mantle cancel " + cancel)
		caught = await approach_mantle(true)
		check(caught, "cancel fixture reached actual catch")
		if not caught:
			continue
		var before: Vector3 = player.position
		if cancel == "release":
			action("jump", false)
		else:
			action("move_back", true)
		await ticks(2)
		check(str(player.get("mode")) == "air" and player.position.distance_to(before) < .5,
			"cancel returns to swept airborne motion within two ticks")
		var catches: int = int(player.get("mantle_count"))
		action("move_back", false)
		await ticks(20)
		check(int(player.get("mantle_count")) == catches, "same held input cannot recatch after cancellation")
	await mantle_fixture("oblique mantle abort preserves momentum")
	player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(-0.8, 0.025, 0)))
	action("move_forward", true)
	action("move_right", true, 0.4)
	await ticks(14)
	action("jump", true)
	caught = false
	for i: int in 110:
		await ticks(1)
		if str(player.get("mode")) == "mantle":
			caught = true
			break
	check(caught, "oblique real-input approach catches the lip")
	if caught:
		var tangent_before: float = player.velocity.x
		action("jump", false)
		await ticks(2)
		check(tangent_before > 1.0 and player.velocity.x > tangent_before * 0.8 and player.velocity.y < 0.0,
			"release keeps lateral carry while resuming the fall: %.3f to %s" % [tangent_before, player.velocity])
	await mantle_fixture("grounded movement never catches")
	await approach_mantle(false)
	check(int(player.get("mantle_count")) == 0, "grounded forward alone never starts mantle")
	await mantle_fixture("nearby jump deliberately avoids catch")
	action("move_forward", true)
	await ticks(14)
	action("jump", true)
	await ticks(2)
	action("jump", false)
	await ticks(100)
	check(int(player.get("jump_count")) == 1 and int(player.get("mantle_count")) == 0,
		"nearby short jump without held intent stays ballistic")

func authored_stairs() -> void:
	var world_path: String = "res://scripts/spillway_level.gd"
	if not ResourceLoader.exists(world_path):
		check(false, "authored stairs require the actual world resource")
		return
	await fresh("authored stair discovery", Vector3.ZERO)
	var world_script: GDScript = load(world_path) as GDScript
	if world_script == null or not world_script.can_instantiate():
		check(false, "authored world must parse before testing its seams")
		return
	var world: Node3D = world_script.new() as Node3D
	fixture.add_child(world)
	world.call("build")
	var terrain_up: bool = true
	var terrain_count: int = 0
	for mesh_node: Node in world.find_children("*", "MeshInstance3D", true, false):
		if not mesh_node.get_meta("terrain_surface", false):
			continue
		terrain_count += 1
		var terrain_mesh: ArrayMesh = mesh_node.mesh
		var normals: PackedVector3Array = terrain_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		for normal: Vector3 in normals:
			terrain_up = terrain_up and normal.y > 0.0
	check(terrain_count >= 3 and terrain_up, "terrain top surfaces face the sun rather than the underside")
	var ramps_found: Array[StaticBody3D] = []
	for child: Node in world.find_children("*", "StaticBody3D", true, false):
		if bool(child.get_meta("smooth_stair_ramp", false)):
			ramps_found.append(child as StaticBody3D)
	check(not ramps_found.is_empty(), "authored stairs expose continuous collision ramps")
	for ramp: StaticBody3D in ramps_found:
		var collision_node: CollisionShape3D = ramp.find_child("*", true, false) as CollisionShape3D
		if collision_node == null or not collision_node.shape is ConvexPolygonShape3D:
			check(false, "stair ramp needs inspectable convex seam endpoints")
			continue
		var points: PackedVector3Array = (collision_node.shape as ConvexPolygonShape3D).points
		if points.size() < 4:
			check(false, "stair ramp must expose both top edges")
			continue
		var a: Vector3 = collision_node.to_global((points[0] + points[1]) * .5)
		var b: Vector3 = collision_node.to_global((points[2] + points[3]) * .5)
		var flat: Vector3 = (b - a).slide(Vector3.UP)
		var length: float = flat.length()
		var forward: Vector3 = flat.normalized()
		var right: Vector3 = forward.cross(Vector3.UP)
		for variant: String in ["descent", "ascent", "slow", "diagonal"]:
			release_all()
			case_name = "authored %s %s" % [ramp.name, variant]
			var reverse: bool = variant == "ascent"
			var direction: Vector3 = -forward if reverse else forward
			var start: Vector3 = (b if reverse else a) - direction * 1.4
			if variant == "diagonal":
				start -= right * .7
			player.call("reset_to", Transform3D(Basis(Vector3.UP, atan2(-direction.x, -direction.z)), start + Vector3.UP * .025))
			await ticks(12)
			action("move_forward", true, .35 if variant == "slow" else 1.0)
			if variant == "diagonal":
				action("move_right", true, .08)
			var previous_residual: float = NAN
			var residual_min: float = INF
			var residual_max: float = -INF
			var max_jitter: float = 0
			var unsupported: int = 0
			var crossed: bool = false
			var eye: Camera3D = player.get("camera") as Camera3D
			for i: int in 2000:
				await ticks(1)
				var along: float = (player.global_position - a).dot(forward)
				var expected_y: float = lerpf(a.y, b.y, clampf(along / length, 0, 1))
				var residual: float = eye.global_position.y - expected_y
				residual_min = minf(residual_min, residual)
				residual_max = maxf(residual_max, residual)
				if is_finite(previous_residual):
					max_jitter = maxf(max_jitter, absf(residual - previous_residual))
				previous_residual = residual
				if not player.is_on_floor():
					unsupported += 1
				if (reverse and along < -1.2) or (not reverse and along > length + 1.2):
					crossed = true
					break
			check(crossed, "crossed actual stair ramp and both landings at %s" % player.global_position)
			check(unsupported <= 3, "authored seams keep continuous support: %d unsupported ticks" % unsupported)
			check(max_jitter < .055 and residual_max - residual_min < .20,
				"authored camera residual against slope: step %.4f range %.4f" % [max_jitter, residual_max - residual_min])

func water_recovery() -> void:
	await fresh("water costs time without a reset")
	player.set("in_water", true)
	# explicit high-speed water-entry fixture, not a route launch.
	player.velocity = Vector3(0, 0, -16)
	action("move_forward", true)
	action("crouch", true)
	await ticks(180)
	# r12 retires the r11 rule "crouching cannot slide through water at dry speed": water now
	# stops walking but barely touches a slide (wet/dry proof lives in test_spillway_surf).
	check(str(player.get("mode")) == "slide" and player.get_speed() > 10.0 and player.get_speed() < 16.0,
		"a slide keeps sliding through shallow water and still slows: %.3f" % player.get_speed())
	action("crouch", false)
	await ticks(120)
	check(absf(player.get_speed() - 3.4) < .08, "standing water recovery reaches its P3.4m/s speed")
	player.set("in_water", false)
	await ticks(48)
	check(player.get_speed() > 8.3, "leaving the water restores responsive dry running")

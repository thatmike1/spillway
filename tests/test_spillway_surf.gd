extends SceneTree
## p / r12 motor proof. each episode places the runner once with reset_to, then drives it
## only with engine input (key actions and mouse motion) through surf_motor_driver.gd.
## no velocity is seeded and no trajectory is teleported. fixtures are isolated collision
## worlds, not the authored course; the water fixture applies main's AABB water rule.

const DRIVER := preload("res://tests/surf_motor_driver.gd")
var checks: int = 0
var failures: int = 0
var fixture: Node3D
var player: CharacterBody3D
var motor: GDScript
var drive: RefCounted
var trace: FileAccess
var case_name: String = "setup"
var results: Dictionary = {}
var water_regions: Array[AABB] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("%s [%s] %s" % ["PASS" if ok else "FAIL", case_name, label])
	if not ok:
		failures += 1

func note(label: String) -> void:
	print("INFO [%s] %s" % [case_name, label])

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

func prism(points: PackedVector3Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	fixture.add_child(body)
	return body

func fresh(label: String, spawn: Vector3, floor_top: float = 0.0, settle_ticks: int = 10) -> void:
	if drive != null:
		drive.call("release_all")
	if is_instance_valid(fixture):
		fixture.queue_free()
		await process_frame
	case_name = label
	water_regions.clear()
	fixture = Node3D.new()
	root.add_child(fixture)
	box(Vector3(0, floor_top - 0.5, -100), Vector3(400, 1, 400))
	player = motor.new() as CharacterBody3D
	fixture.add_child(player)
	# the one explicit placement of the episode.
	player.call("reset_to", Transform3D(Basis.IDENTITY, spawn))
	drive = DRIVER.new(self, player, trace)
	drive.set("label", label)
	drive.set("before_tick", _apply_water)
	await drive.call("step", settle_ticks)

func _apply_water() -> void:
	# the same rule spillway_main applies to its level's water regions.
	var wet := false
	for region: AABB in water_regions:
		wet = wet or region.has_point(player.global_position)
	player.set("in_water", wet)

func speed() -> float:
	return float(player.call("get_speed"))

func run_up(ticks: int) -> void:
	drive.call("keys", ["move_forward"])
	await drive.call("step", ticks)

func _run() -> void:
	motor = load("res://scripts/spillway_player.gd") as GDScript
	if motor == null or not motor.can_instantiate():
		printerr("spillway surf: motor could not be parsed/instantiated")
		quit(2)
		return
	(load("res://scripts/spillway_main.gd") as GDScript).call("bind_inputs")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			var path: String = arg.trim_prefix("--evidence-dir=").simplify_path()
			if not preload("res://scripts/spillway_driver.gd").evidence_path_allowed(path):
				printerr("spillway surf: evidence directory must be absolute and outside Git")
				quit(2)
				return
			DirAccess.make_dir_recursive_absolute(path)
			trace = FileAccess.open(path.path_join("motor-proof.jsonl"), FileAccess.WRITE)
			if trace == null:
				printerr("spillway surf: cannot open motor trace")
				quit(2)
				return
	await hop_gain()
	await recorded_replay()
	await bhop_turn()
	await forward_only()
	await look_only()
	await slope_classes()
	await surf_hold()
	await surf_release()
	for bend: int in [-1, 1]:
		for segments: int in [12, 6]:
			await surf_curve(bend, segments)
	await wet_slide()
	await wet_hop_and_walk()
	await autohop_mantle()
	await speed_cap()
	await surf_ceiling_crease()
	await collision_speed_cap()
	await surf_sidewall_crease()
	await downslope_collision_cap()
	drive.call("release_all")
	if trace != null:
		trace.close()
		var summary := FileAccess.open(trace.get_path().get_base_dir().path_join("motor-proof-summary.json"), FileAccess.WRITE)
		summary.store_string(JSON.stringify(results, "  "))
		summary.close()
	print("spillway surf: %d/%d checks passed; input-only motor fixtures, authored stages separate" % [checks - failures, checks])
	quit(1 if failures else 0)

## run, then hold jump through landings while alternating synced strafes each hop.
func hop_gain() -> void:
	await fresh("five synced strafe hops", Vector3(0, .025, 0))
	await run_up(60)
	var takeoff_speed := speed()
	drive.call("keys", ["move_forward", "jump"])
	await drive.call("step", 1)
	var landings: Array[float] = []
	var side := 1
	var hops_before: int = player.get("hop_count")
	var airborne_ticks := 0
	var floor_ticks := 0
	while int(player.get("hop_count")) - hops_before < 5 and airborne_ticks + floor_ticks < 900:
		var hops: int = int(player.get("hop_count")) - hops_before
		side = 1 if hops % 2 == 0 else -1
		# p / a 2.4 rad/s desired velocity turn; this state-aware helper is not a human recording.
		await drive.call("strafe", side, 2.4, ["jump"])
		if player.is_on_floor():
			floor_ticks += 1
			landings.append(speed())
		else:
			airborne_ticks += 1
	# fly the last hop out to its landing so all five arcs are complete.
	for i: int in 120:
		await drive.call("strafe", -side, 2.4, ["jump"])
		if player.is_on_floor():
			landings.append(speed())
			break
	var gained := landings[-1] if not landings.is_empty() else 0.0
	results["hop_gain"] = {"takeoff": takeoff_speed, "landings": landings, "floor_ticks": floor_ticks}
	note("takeoff %.3f m/s, landing speeds %s" % [takeoff_speed, landings])
	check(int(player.get("hop_count")) - hops_before >= 5, "five landing-tick hops chained by holding jump")
	check(floor_ticks <= 6, "each landing hops on its first ground tick: %d ground ticks over five landings" % floor_ticks)
	check(gained >= takeoff_speed * 1.25, "synced A/D and mouse gain speed over five hops: %.3f from %.3f" % [gained, takeoff_speed])
	var rising := true
	for i: int in range(1, landings.size()):
		rising = rising and landings[i] > landings[i - 1]
	check(rising, "every hop lands faster than the one before")
	drive.call("release_all")

## the closed-loop hop run, recorded as keys and view per tick, replays as plain input.
func recorded_replay() -> void:
	var finals: Array[Vector3] = []
	var recorded: Array[Dictionary] = []
	for replaying: bool in [false, true]:
		await fresh("recorded hop line %s" % ("replayed open-loop" if replaying else "recorded closed-loop"), Vector3(0, .025, 0))
		if replaying:
			await drive.call("replay", recorded)
		else:
			drive.set("keep_samples", true)
			await run_up(60)
			drive.call("keys", ["move_forward", "jump"])
			await drive.call("step", 1)
			for i: int in 300:
				await drive.call("strafe", 1 if int(i / 75.0) % 2 == 0 else -1, 2.4, ["jump"])
			recorded = (drive.get("samples") as Array[Dictionary]).duplicate()
		finals.append(player.global_position)
	case_name = "recorded hop line"
	results["recorded_replay"] = {"recorded_end": [finals[0].x, finals[0].y, finals[0].z], "replayed_end": [finals[1].x, finals[1].y, finals[1].z], "ticks": recorded.size()}
	check(recorded.size() > 300 and finals[0].distance_to(finals[1]) < 0.005,
		"replaying %d recorded ticks of keys and view lands within %.4f m of the original" % [recorded.size(), finals[0].distance_to(finals[1])])

## turn ninety degrees in the air of a bhop with a held strafe and a steady mouse turn.
func bhop_turn() -> void:
	for variant: String in ["strafe", "w_only"]:
		await fresh("90 degree bhop turn, " + variant, Vector3(0, .025, 0))
		await run_up(60)
		drive.call("keys", ["move_forward", "jump"])
		await drive.call("step", 1)
		# one straight hop first so the turn starts from a bhop, not the run.
		drive.call("keys", ["jump"])
		var hops: int = player.get("hop_count")
		for i: int in 200:
			await drive.call("step", 1)
			if int(player.get("hop_count")) > hops:
				break
		var before := speed()
		var start_heading: float = drive.call("velocity_yaw")
		var turned := 0.0
		var ticks := 0
		while ticks < 360:
			ticks += 1
			if variant == "strafe":
				await drive.call("strafe", 1, 2.2, ["jump"])
			else:
				drive.call("keys", ["move_forward", "jump"])
				drive.call("turn", -2.2 / 120.0)
				await drive.call("step", 1)
			turned = -angle_difference(start_heading, float(drive.call("velocity_yaw")))
			if turned >= PI * 0.5:
				break
		var after := speed()
		results["bhop_turn_" + variant] = {"before": before, "after": after, "turned_deg": rad_to_deg(turned), "ticks": ticks}
		if variant == "strafe":
			check(turned >= PI * 0.5 - 0.01, "velocity heading turned 90 degrees in %d ticks" % ticks)
			check(after >= before * 0.9, "the turn keeps at least 90%% of speed: %.3f of %.3f (%.0f%%)" % [after, before, after / before * 100.0])
		else:
			# contrast run: W with the same mouse turn lags far behind the strafe turn.
			var strafe_ticks: int = results["bhop_turn_strafe"]["ticks"]
			check(ticks > strafe_ticks * 1.5, "W with the same mouse turn bends the line far slower: 90 degrees in %d ticks against %d" % [ticks, strafe_ticks])
		drive.call("release_all")

func forward_only() -> void:
	for keys: Array in [["move_forward"], ["move_forward", "move_right"]]:
		await fresh("air hold %s" % "+".join(keys), Vector3(0, .025, 0))
		await run_up(60)
		drive.call("keys", ["move_forward", "jump"])
		await drive.call("step", 1)
		drive.call("keys", keys)
		var launch := speed()
		var peak := launch
		var flight := 0
		for i: int in 200:
			await drive.call("step", 1)
			if player.is_on_floor():
				break
			flight += 1
			peak = maxf(peak, speed())
		results["air_hold_" + "+".join(keys)] = {"launch": launch, "peak": peak, "flight_ticks": flight}
		check(flight > 60 and peak <= launch + 0.001, "%s alone in the air gains nothing: peak %.4f from %.4f over %d ticks" % ["+".join(keys), peak, launch, flight])
		drive.call("release_all")

func look_only() -> void:
	await fresh("mouse look alone in the air", Vector3(0, .025, 0))
	await run_up(60)
	drive.call("keys", ["move_forward", "jump"])
	await drive.call("step", 1)
	drive.call("keys", [])
	var launch := Vector2(player.velocity.x, player.velocity.z)
	var worst := 0.0
	var swept := 0.0
	for i: int in 200:
		# sweeping yaw both ways and pitch, as a player looking around mid-air.
		var yaw_step := 0.06 * sin(i * 0.11)
		drive.call("turn", yaw_step, 0.01 * cos(i * 0.07))
		swept += absf(yaw_step)
		await drive.call("step", 1)
		if player.is_on_floor():
			break
		worst = maxf(worst, (Vector2(player.velocity.x, player.velocity.z) - launch).length())
	results["look_only"] = {"launch": launch.length(), "worst_change": worst, "yaw_swept_rad": swept}
	check(swept > 3.0 and worst < 1e-4, "%.1f rad of mouse look changes horizontal velocity by %.6f m/s" % [swept, worst])

## drop onto real faces of each angle with no input: walkable floor below the limit,
## surf (slid on, never stood on, gravity along the face) from it up to 75 degrees.
func slope_classes() -> void:
	for degrees: float in [44.0, 48.0, 60.0, 74.0]:
		await fresh("drop onto a %.0f degree face" % degrees, Vector3(0, 8.025, 0))
		var height := 6.0
		var run := height / tan(deg_to_rad(degrees))
		prism(PackedVector3Array([Vector3(-3, 0, 0), Vector3(3, 0, 0), Vector3(-3, height, -run), Vector3(3, height, -run),
			Vector3(-3, 0, -run), Vector3(3, 0, -run)]))
		# the explicit spawn is a fall above the face's middle; gravity does the rest.
		player.call("reset_to", Transform3D(Basis.IDENTITY, Vector3(0, height * 0.5 + 0.9, -run * 0.5)))
		var touched := false
		var face_floor := 0
		var face_surf := 0
		var slid := 0.0
		var start_y := 0.0
		for i: int in 240:
			await drive.call("step", 1)
			var on_face: bool = player.global_position.y > 0.3
			if player.get("surf_normal") != Vector3.ZERO or (player.is_on_floor() and on_face):
				if not touched:
					start_y = player.global_position.y
				touched = true
			if touched and on_face:
				if player.is_on_floor():
					face_floor += 1
				if player.get("surf_normal") != Vector3.ZERO:
					face_surf += 1
			if touched:
				slid = maxf(slid, start_y - player.global_position.y)
		results["slope_%d" % degrees] = {"touched": touched, "floor_ticks_on_face": face_floor, "surf_ticks": face_surf, "slid_down": slid}
		if degrees < 46.0:
			check(touched and face_floor > 200 and face_surf == 0 and slid < 0.1, "%.0f degrees is floor: the runner lands and stands, slid %.3f m" % [degrees, slid])
		else:
			check(touched and face_floor == 0 and face_surf > 5 and slid > 1.0,
				"%.0f degrees is surf: %d contact ticks, never floor, slid %.2f m down" % [degrees, face_surf, slid])

func make_surf_ramp() -> void:
	# a 60 degree face rising toward +x, eighty metres long, its foot on the floor.
	var run := 14.0 / tan(deg_to_rad(60.0))
	var points := PackedVector3Array()
	for z: float in [-10.0, -90.0]:
		points.append_array([Vector3(-run, 0, z), Vector3(0, 14, z), Vector3(0, 0, z)])
	prism(points)
	# start deck beside the ramp's near end; its edge leaves a one-metre gap.
	box(Vector3(-5.1, 4.5, -1.5), Vector3(3.8, 9, 15))

## jump from the deck onto the face and hold it with the strafe key into the ramp.
func surf_hold() -> void:
	await surf_run("surf ramp held with strafe", true)

func surf_release() -> void:
	await surf_run("surf ramp without input", false)

func surf_run(label: String, hold: bool) -> void:
	await fresh(label, Vector3(-5.1, 9.025, 5))
	make_surf_ramp()
	await drive.call("step", 4)
	drive.call("keys", ["move_forward"])
	while player.global_position.z > -8.6:
		await drive.call("step", 1)
	drive.call("keys", ["move_forward", "jump"])
	await drive.call("step", 1)
	drive.call("keys", [])
	var entry := -1.0
	var entry_y := 0.0
	var contact_ticks := 0
	var floor_ticks := 0
	var band := true
	var span := 0
	var exit_speed := -1.0
	var exit_y := 0.0
	var first_contact_z := 0.0
	var last_surf_speed := 0.0
	for i: int in 1200:
		if hold and entry >= 0.0:
			# closed-loop surf input along -z with the ramp on the right, sinking on a
			# planned line from the entry height to 2.5 m over the ramp's length.
			var along := clampf((-12.0 - player.global_position.z) / 76.0, 0.0, 1.0)
			await drive.call("surf", 1, 0.0, lerpf(entry_y, 2.5, along))
		else:
			# the negative control holds only jump, so the foot of the ramp meets an autohop.
			if entry >= 0.0:
				drive.call("keys", ["jump"])
			await drive.call("step", 1)
		var surfing: bool = player.get("surf_normal") != Vector3.ZERO
		if surfing:
			last_surf_speed = speed()
			var n: Vector3 = player.get("surf_normal")
			band = band and n.y > cos(deg_to_rad(75.0)) and n.y < cos(player.floor_max_angle)
			if entry < 0.0:
				entry = speed()
				entry_y = player.global_position.y
				first_contact_z = player.global_position.z
			contact_ticks += 1
		if entry >= 0.0 and player.global_position.z > -90.0:
			span += 1
			if player.is_on_floor():
				floor_ticks += 1
		if player.global_position.z < -90.6 or (player.is_on_floor() and player.global_position.y < 0.2):
			exit_speed = speed()
			exit_y = player.global_position.y
			break
	var hop_speed := -1.0
	if not hold:
		var jumps: int = player.get("jump_count")
		for i: int in 4:
			await drive.call("step", 1)
			if int(player.get("jump_count")) > jumps:
				hop_speed = speed()
				break
	drive.call("release_all")
	results[label] = {"entry_speed": entry, "entry_y": entry_y, "last_surf_speed": last_surf_speed, "hop_speed_off_foot": hop_speed, "first_contact_z": first_contact_z, "exit_speed": exit_speed,
		"exit_y": exit_y, "surf_ticks": contact_ticks, "ramp_ticks": span, "floor_ticks": floor_ticks}
	note("entry %.3f m/s at y %.2f, exit %.3f m/s at y %.2f z %.2f, surf %d of %d ramp ticks, floor %d" % [
		entry, entry_y, exit_speed, exit_y, player.global_position.z, contact_ticks, span, floor_ticks])
	check(entry >= 0.0, "the jump lands on the actual ramp collision")
	check(band, "every touched face reads as surf, between the floor limit and 75 degrees, never floor")
	if hold:
		check(player.global_position.z < -90.5 and floor_ticks == 0, "held strafe keeps the runner on the face to the far end, no floor contact")
		check(contact_ticks >= span * 0.6 and contact_ticks > 240, "substantial collision contact: %d of %d ramp ticks" % [contact_ticks, span])
		check(exit_speed > entry * 1.1, "leaves the ramp faster than it entered: %.3f from %.3f" % [exit_speed, entry])
	else:
		# negative control: gravity alone takes the runner down the face to the floor.
		check(floor_ticks > 0 and player.global_position.z > -90.0, "without the strafe the runner slides off the foot of the ramp early")
		check(hop_speed >= last_surf_speed * 0.95, "held jump hops at the foot and carries the ramp's speed: %.3f from %.3f" % [hop_speed, last_surf_speed])

## a 60 degree face swept around a circle from separate convex segments. bend -1 curves
## left with the ramp on the outside (a bowl the face carries you around); +1 curves right
## with the ramp on the inside, so only a synced D and mouse turn holds the line.
func make_curved_ramp(bend: int, segments: int, radius: float, arc: float) -> void:
	var run := 14.0 / tan(deg_to_rad(60.0))
	var top_radius := radius
	var foot_radius := radius + run / bend
	for i: int in segments:
		var points := PackedVector3Array()
		for theta: float in [arc * i / segments, arc * (i + 1) / segments]:
			points.append(curve_point(bend, radius, theta, foot_radius))
			points.append(curve_point(bend, radius, theta, top_radius) + Vector3.UP * 14.0)
			points.append(curve_point(bend, radius, theta, top_radius))
		prism(points)
	box(Vector3(-5.1, 4.5, -1.5), Vector3(3.8, 9, 15))

func curve_point(bend: int, radius: float, theta: float, at_radius: float) -> Vector3:
	var center := Vector3(bend * radius, 0, -10)
	return center + at_radius * Vector3(-bend * cos(theta), 0, -sin(theta))

func curve_angle(bend: int, radius: float) -> float:
	var offset := player.global_position - Vector3(bend * radius, 0, -10)
	return atan2(-offset.z, -bend * offset.x)

func surf_curve(bend: int, segments: int) -> void:
	var label := "curved surf %s, %d segments over 60 degrees" % ["left, ramp outside" if bend < 0 else "right, ramp inside", segments]
	var radius := 60.0
	var arc := deg_to_rad(60.0)
	await fresh(label, Vector3(-5.1, 9.025, 5))
	make_curved_ramp(bend, segments, radius, arc)
	await drive.call("step", 4)
	drive.call("keys", ["move_forward"])
	while player.global_position.z > -8.6:
		await drive.call("step", 1)
	drive.call("keys", ["move_forward", "jump"])
	await drive.call("step", 1)
	drive.call("keys", [])
	var entry := -1.0
	var entry_y := 0.0
	var contact_ticks := 0
	var span := 0
	var floor_ticks := 0
	var worst_drop := 0.0
	var previous := -1.0
	var theta := 0.0
	for i: int in 1500:
		theta = curve_angle(bend, radius)
		if entry >= 0.0:
			# look along the circle's tangent at the runner, sinking on a planned line.
			await drive.call("surf", 1, -bend * theta, lerpf(entry_y, 2.5, clampf(theta / arc, 0.0, 1.0)))
		else:
			await drive.call("step", 1)
		if player.get("surf_normal") != Vector3.ZERO:
			if entry < 0.0:
				entry = speed()
				entry_y = player.global_position.y
			contact_ticks += 1
		if entry >= 0.0:
			span += 1
			if player.is_on_floor():
				floor_ticks += 1
			if previous > 0.0:
				worst_drop = maxf(worst_drop, previous - speed())
			previous = speed()
		if curve_angle(bend, radius) > arc + 0.01 or (player.is_on_floor() and player.global_position.y < 0.2):
			break
	drive.call("release_all")
	var exit_speed := speed()
	results[label] = {"entry_speed": entry, "exit_speed": exit_speed, "exit_y": player.global_position.y, "surf_ticks": contact_ticks,
		"ramp_ticks": span, "floor_ticks": floor_ticks, "worst_one_tick_drop": worst_drop, "end_angle_deg": rad_to_deg(curve_angle(bend, radius))}
	note("entry %.3f, exit %.3f m/s at y %.2f after %.1f degrees; surf %d of %d ticks; worst one-tick speed drop %.3f" % [
		entry, exit_speed, player.global_position.y, rad_to_deg(curve_angle(bend, radius)), contact_ticks, span, worst_drop])
	check(curve_angle(bend, radius) > arc and floor_ticks == 0, "held surf follows the whole curve without touching the floor")
	check(contact_ticks >= span * 0.6, "substantial collision contact around the curve: %d of %d ticks" % [contact_ticks, span])
	check(exit_speed > entry, "leaves the curve faster than it entered: %.3f from %.3f" % [exit_speed, entry])
	check(worst_drop < 0.5, "segment seams cost no sudden speed: worst one-tick drop %.3f m/s" % worst_drop)

func make_chute() -> void:
	# a run-up deck, a 10 degree chute, then a long flat outflow.
	box(Vector3(0, 1.5, 4), Vector3(8, 3, 8))
	var drop := 3.0
	var length := drop / tan(deg_to_rad(10.0))
	prism(PackedVector3Array([Vector3(-4, 3, 0), Vector3(4, 3, 0), Vector3(-4, 0, -length), Vector3(4, 0, -length),
		Vector3(-4, -0.5, 0), Vector3(4, -0.5, 0), Vector3(-4, -0.5, -length), Vector3(4, -0.5, -length)]))

func wet_slide() -> void:
	var finals := {}
	for wet: bool in [false, true]:
		var label := "chute slide %s" % ("through shallow water" if wet else "dry")
		await fresh(label, Vector3(0, 3.025, 7.5))
		make_chute()
		if wet:
			water_regions.append(AABB(Vector3(-4, -1, -45), Vector3(8, 5, 45)))
		await drive.call("step", 4)
		drive.call("keys", ["move_forward"])
		while player.global_position.z > 0.6:
			await drive.call("step", 1)
		drive.call("keys", ["move_forward", "crouch"])
		var slide_ticks := 0
		var wet_ticks := 0
		while player.global_position.z > -36.0 and slide_ticks < 2000:
			await drive.call("step", 1)
			slide_ticks += 1
			if bool(player.get("in_water")):
				wet_ticks += 1
		finals[wet] = speed()
		results[label] = {"speed_at_36m": speed(), "mode": str(player.get("mode")), "ticks": slide_ticks, "wet_ticks": wet_ticks}
		note("%s: %.3f m/s at z -36 after %d ticks, mode %s, %d wet ticks" % [label, speed(), slide_ticks, player.get("mode"), wet_ticks])
		check(str(player.get("mode")) == "slide", "still sliding at the end of the outflow")
		if wet:
			check(wet_ticks >= slide_ticks * 0.8, "the slide actually ran through the water region")
	var ratio: float = finals[true] / maxf(finals[false], 0.001)
	case_name = "chute slide wet / dry"
	results["wet_dry_slide_ratio"] = ratio
	check(ratio >= 0.8, "shallow water keeps a slide at %.0f%% of its dry speed" % (ratio * 100.0))

func wet_hop_and_walk() -> void:
	var finals := {}
	for wet: bool in [false, true]:
		var label := "bhop line %s" % ("through shallow water" if wet else "dry")
		await fresh(label, Vector3(0, .025, 0))
		if wet:
			water_regions.append(AABB(Vector3(-10, -1, -70), Vector3(20, 4, 62)))
		await run_up(60)
		drive.call("keys", ["move_forward", "jump"])
		await drive.call("step", 1)
		drive.call("keys", ["jump"])
		while player.global_position.z > -60.0:
			await drive.call("step", 1)
		finals[wet] = speed()
		results[label] = {"speed_at_60m": speed()}
	case_name = "bhop line wet / dry"
	check(finals[true] >= finals[false] * 0.95, "landing-tick hops through water keep %.0f%% of dry speed" % (finals[true] / finals[false] * 100.0))
	await fresh("walking into shallow water", Vector3(0, .025, 0))
	water_regions.append(AABB(Vector3(-10, -1, -70), Vector3(20, 4, 62)))
	await run_up(240)
	results["walk_in_water"] = {"speed": speed(), "z": player.global_position.z}
	check(bool(player.get("in_water")) and speed() <= 3.45, "walking in the same water still slows to the wading speed: %.3f" % speed())

## a held autohop chain meets a lip it could catch; it must bonk, not mantle.
func autohop_mantle() -> void:
	for fresh_press: bool in [false, true]:
		await fresh("lip during %s" % ("a fresh jump press" if fresh_press else "a held autohop chain"), Vector3(0, .025, 0))
		# the lip meets the second hop of the chain, not the first jump.
		box(Vector3(0, .8, -14.5), Vector3(5, 1.6, 5))
		await drive.call("step", 2)
		await run_up(40)
		drive.call("keys", ["move_forward", "jump"])
		if fresh_press:
			# release after takeoff and press again just before the lip, as a player would.
			await drive.call("step", 3)
			drive.call("keys", ["move_forward"])
			while player.global_position.z > -9.0:
				await drive.call("step", 1)
			drive.call("keys", ["move_forward", "jump"])
		var mantles: int = player.get("mantle_count")
		for i: int in 240:
			await drive.call("step", 1)
			if int(player.get("mantle_count")) > mantles:
				break
		var caught := int(player.get("mantle_count")) > mantles
		results[case_name] = {"mantled": caught, "hops": int(player.get("hop_count")), "z": player.global_position.z}
		if fresh_press:
			check(caught, "a fresh press near the lip still catches it")
		else:
			check(not caught and int(player.get("hop_count")) >= 1, "held jump through landings never steals control into a mantle")
		drive.call("release_all")

## circle with the strongest synced strafe until the P speed cap holds the line.
func speed_cap() -> void:
	await fresh("synced circle against the P speed cap", Vector3(0, .025, -100))
	await run_up(60)
	drive.call("keys", ["move_forward", "jump"])
	await drive.call("step", 1)
	var peak := 0.0
	for i: int in 2400:
		await drive.call("strafe", 1, -1.0, ["jump"])
		peak = maxf(peak, speed())
	results["speed_cap"] = {"peak": peak, "final": speed()}
	note("peak %.3f m/s after 20 s of maximal strafing" % peak)
	check(peak > 25.0 and peak <= 30.001, "maximal strafing climbs toward but never past the 30 m/s cap: %.3f" % peak)
	drive.call("release_all")


## regression: a ceiling/ramp crease has a free -z tangent. fixed D must keep travelling.
func surf_ceiling_crease() -> void:
	await fresh("fixed-input surf under a ceiling", Vector3(-5.1, 9.025, 5))
	make_surf_ramp()
	box(Vector3(-5, 8.15, -80), Vector3(12, .3, 100))
	await drive.call("step", 4)
	drive.call("keys", ["move_forward"])
	while player.global_position.z > -8.6:
		await drive.call("step", 1)
	drive.call("keys", ["move_forward", "jump"])
	await drive.call("step", 1)
	drive.call("keys", [])
	for i: int in 250:
		await drive.call("step", 1)
		if player.get("surf_normal") != Vector3.ZERO:
			break
	drive.call("face", 0.0)
	drive.call("keys", ["move_right"])
	var stalled := 0
	var ceiling_ticks := 0
	for i: int in 1300:
		await drive.call("step", 1)
		var touching_ceiling := false
		for k: int in player.get_slide_collision_count():
			var contact := player.get_slide_collision(k)
			for j: int in contact.get_collision_count():
				touching_ceiling = touching_ceiling or contact.get_normal(j).y < -.7
		if touching_ceiling:
			ceiling_ticks += 1
			if absf(player.get_real_velocity().z) < 1.0:
				stalled += 1
	results["surf_ceiling_crease"] = {"ceiling_ticks": ceiling_ticks, "stalled_ticks": stalled,
		"end_z": player.global_position.z, "keys": "fixed D, yaw zero"}
	check(ceiling_ticks > 100, "the real capsule contacts the ceiling above the surf face")
	check(stalled == 0 and player.global_position.z < -90.0,
		"the unobstructed crease keeps travelling: %d stalled ticks, end z %.2f" % [stalled, player.global_position.z])

## regression: earn cap speed on a static deck, then fall onto a static steep face.
func collision_speed_cap() -> void:
	await fresh("earned cap speed falls onto a surf ramp", Vector3(0, 30.025, -100), -200.0)
	box(Vector3(0, 15, -100), Vector3(40, 30, 40))
	var run := 28.0 / tan(deg_to_rad(60.0))
	prism(PackedVector3Array([Vector3(-run, 0, -125), Vector3(0, 28, -125), Vector3(0, 0, -125),
		Vector3(-run, 0, -240), Vector3(0, 28, -240), Vector3(0, 0, -240)]))
	await drive.call("step", 10)
	# p / this initial view aims the earned circle's exit along the static ramp.
	drive.call("turn", -atan2(27.421, 12.168))
	await run_up(60)
	drive.call("keys", ["move_forward", "jump"])
	await drive.call("step", 1)
	for i: int in 2400:
		await drive.call("strafe", 1, -1.0, ["jump"])
	var earned := speed()
	drive.call("keys", ["jump"])
	var peak := earned
	var peak_real := 0.0
	var contacts_on_face := 0
	for i: int in 700:
		await drive.call("step", 1)
		peak = maxf(peak, speed())
		var real_velocity := player.get_real_velocity()
		peak_real = maxf(peak_real, Vector2(real_velocity.x, real_velocity.z).length())
		if player.get("surf_normal") != Vector3.ZERO:
			contacts_on_face += 1
		if player.global_position.y < 0.0:
			break
	results["collision_speed_cap"] = {"earned": earned, "peak_velocity": peak, "peak_sweep": peak_real,
		"surf_ticks": contacts_on_face, "recovery_margin_m": player.safe_margin}
	check(earned > 29.99 and contacts_on_face > 20, "input earns the cap then actually contacts the ramp")
	check(peak <= 30.001, "collision cannot manufacture authoritative speed above the P cap: %.4f" % peak)
	# real velocity includes the engine's up-to-2mm contact recovery at120Hz.
	check(peak_real <= 30.0 + player.safe_margin * 120.0 + .01,
		"actual swept speed stays within the cap plus contact recovery: %.4f" % peak_real)

## regression: a steep face beside a wall must not invent a walkable aggregate floor.
func surf_sidewall_crease() -> void:
	var run := 14.0 / tan(deg_to_rad(74.0))
	var x := -run * .5
	await fresh("input-earned surf beside a wall", Vector3(x, 9.025, 5), 0.0, 0)
	prism(PackedVector3Array([Vector3(-run, 0, -10), Vector3(0, 14, -10), Vector3(0, 0, -10),
		Vector3(-run, 0, -120), Vector3(0, 14, -120), Vector3(0, 0, -120)]))
	box(Vector3(x, 4.5, -1.5), Vector3(3.8, 9, 15))
	box(Vector3(x - .5, 15, -60), Vector3(.2, 30, 100))
	await drive.call("step", 10)
	drive.call("keys", ["move_forward"])
	for i: int in 350:
		if player.global_position.z <= -8.6:
			break
		await drive.call("step", 1)
	drive.call("keys", ["move_forward", "jump"])
	await drive.call("step", 1)
	drive.call("keys", ["move_forward", "move_right"])
	var stalls := 0
	var crease_contacts := 0
	for i: int in 180:
		await drive.call("step", 1)
		if absf(player.velocity.z) > 3.0 and absf(player.get_real_velocity().z) < .01:
			stalls += 1
		var ramp := false
		var wall := false
		for k: int in player.get_slide_collision_count():
			var contact := player.get_slide_collision(k)
			for j: int in contact.get_collision_count():
				var normal := contact.get_normal(j)
				ramp = ramp or normal.x < -.9
				wall = wall or normal.x > .9
		if ramp and wall:
			crease_contacts += 1
	drive.call("keys", ["move_right"])
	var start_z := player.global_position.z
	var stopped := 0
	for i: int in 900:
		await drive.call("step", 1)
		if absf(player.get_real_velocity().z) < .01:
			stopped += 1
	results["sidewall_crease"] = {"crease_ticks": crease_contacts, "tangent_stalls": stalls,
		"D_stopped_ticks": stopped, "D_travel_m": start_z - player.global_position.z}
	check(crease_contacts > 10, "input actually reaches the wall/ramp crease: %d ticks" % crease_contacts)
	check(stalls == 0 and stopped == 0 and player.global_position.z < start_z - 40,
		"the clear tangent moves instead of reporting stationary speed: %d stalls, %d stopped ticks" % [stalls, stopped])

## regression: a walkable downslope arrival must not bypass the swept-motion cap.
func downslope_collision_cap() -> void:
	await fresh("earned cap speed lands on a walkable downslope", Vector3(0, 30.025, -100), 0.0, 0)
	box(Vector3(0, 15, -100), Vector3(40, 30, 40))
	var run := 30.0 / tan(deg_to_rad(10.0))
	prism(PackedVector3Array([Vector3(-20, 30, -120), Vector3(20, 30, -120), Vector3(-20, 0, -120 - run),
		Vector3(20, 0, -120 - run), Vector3(-20, 0, -120), Vector3(20, 0, -120)]))
	await drive.call("step", 10)
	drive.call("turn", -atan2(27.421, 12.168))
	await run_up(60)
	drive.call("keys", ["move_forward", "jump"])
	await drive.call("step", 1)
	for i: int in 2400:
		await drive.call("strafe", 1, -1.0, ["jump"])
	var earned := speed()
	drive.call("keys", ["jump"])
	var peak_real := 0.0
	var peak_authoritative := 0.0
	var jumps_before: int = player.get("jump_count")
	for i: int in 750:
		await drive.call("step", 1)
		peak_authoritative = maxf(peak_authoritative, speed())
		var real := player.get_real_velocity()
		peak_real = maxf(peak_real, Vector2(real.x, real.z).length())
	results["downslope_cap"] = {"earned": earned, "peak_sweep": peak_real,
		"peak_velocity": peak_authoritative, "rehops": int(player.get("jump_count")) - jumps_before}
	check(earned > 29.99 and int(player.get("jump_count")) > jumps_before, "input earns30m/s and held jump keeps rehopping on the downslope")
	check(peak_authoritative <= 30.001 and peak_real <= 30.0 + player.safe_margin * 120.0 + .01,
		"walkable landings keep the authoritative and swept cap: %.4f / %.4f" % [peak_authoritative, peak_real])

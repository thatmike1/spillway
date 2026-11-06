extends SceneTree
## p / r12 actual-course fast line: one continuous run from the normal spawn, driven only by
## key and mouse input through scripts/spillway_surf_driver.gd. no pose, velocity or stage
## writes. --evidence-dir=<abs> keeps route-fast-*.jsonl; --render-samples=N also saves one still
## every N ticks (render loop off between them; needs a display, e.g. xvfb + opengl3).
## after the run, static physics queries check the outflow's seams and release corridor.
const GEOMETRY := preload("res://scripts/spillway_surf_geometry.gd")
var game: Node3D
var driver: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	run.call_deferred()

func check(value: bool, text: String) -> void:
	checks += 1
	print("%s %s" % ["PASS" if value else "FAIL", text])
	if not value:
		failures += 1

func run() -> void:
	root.size = Vector2i(960, 540)
	var output := ""
	var every := 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			output = arg.trim_prefix("--evidence-dir=")
		elif arg.begins_with("--render-samples="):
			every = int(arg.trim_prefix("--render-samples="))
	if DisplayServer.get_name() == "headless":
		every = 0
	game = load("res://scripts/spillway_main.gd").new()
	root.add_child(game)
	game.set("_persist", false)
	var player: CharacterBody3D = game.get("player")
	var spawn: Vector3 = player.global_position
	driver = preload("res://scripts/spillway_surf_driver.gd").new()
	game.add_child(driver)
	driver.call("attach", game)
	var ticks := 0
	while not bool(driver.get("done")) and ticks < 7200:
		await physics_frame
		ticks += 1
		if every > 0 and ticks % every == 0 and not output.is_empty():
			RenderingServer.render_loop_enabled = true
			await RenderingServer.frame_post_draw
			RenderingServer.render_loop_enabled = false
			root.get_texture().get_image().save_jpg(output.path_join("%04d-%s.jpg" % [ticks, driver.get("phase")]), .88)

	var report: Dictionary = driver.get("surf_report")
	var splits: Array = game.get("splits")
	print("spawn=%s splits=%s time=%.3f jumps=%d surf=%s" % [spawn, splits, game.get("elapsed"), player.get("jump_count"), report])
	check(bool(driver.get("succeeded")), "the fast line finishes by input alone: %s" % driver.get("failure_reason"))
	check(str(game.get("finish_kind")) == "clean" and int(game.get("respawn_count")) == 0, "continuous from spawn: a clean result, no respawn")
	check(splits.size() == 3 and splits[0] < splits[1] and splits[1] < splits[2], "Crest, Yard and Outflow splits arrive in order")
	for label: String in ["CrestSurf", "YardSurf", "OutflowSweep", "OutflowSurf"]:
		var ride: Dictionary = report.get(label, {})
		# p / ridden, not flown over: in contact for at least 0.2 s and 40% of its ride. the
		# outflow's left curve is a 0.6 s piece the berm feeds at its coping, so it sits near both.
		var contact := int(ride.get("contact_ticks", 0))
		check(ride.has("exit_speed") and contact >= 24 and contact >= .4 * int(ride.get("ride_ticks", 1)),
			"%s is ridden end to end on contact: %s" % [label, ride])
	# p / a bank that is entered and left on a held line carries speed through.
	for label: String in ["CrestSurf", "YardSurf"]:
		var ride: Dictionary = report.get(label, {})
		check(float(ride.get("exit_speed", 0)) > float(ride.get("entry_speed", INF)), "%s ends faster than it starts" % label)
	var entry: Dictionary = report.get("OutflowSweep", {})
	var exit: Dictionary = report.get("OutflowSurf", {})
	check(float(entry.get("entry_y", -INF)) > 0.5, "outflow is entered high, near the run-up deck, not from the basin")
	check(float(exit.get("exit_y", -INF)) > -3.0, "outflow releases above the front walk, so the finish needs no climb")
	check(float(exit.get("exit_speed", 0)) > float(entry.get("entry_speed", INF)) * .9, "the outflow S keeps at least 90% of its entry speed")
	var kills: Array = []
	for drop: Dictionary in driver.get("speed_drops"):
		if float(drop.from) - float(drop.to) > 4.0:
			kills.append(drop)
	check(kills.is_empty(), "no single-tick speed kill above 4 m/s anywhere on the line: %s" % [kills])
	outflow_seams()
	release_corridor()
	print("surf course: %d/%d checks passed; one continuous input run, not a fun claim" % [checks - failures, checks])
	quit(1 if failures else 0)

func _section(label: String) -> Dictionary:
	for section: Dictionary in game.get("level").get("surf_sections"):
		if section.name == label:
			return section
	return {}

## the riding face's unit normal at theta, from the authored plane (points away from the solid).
static func _face_normal(section: Dictionary, theta: float) -> Vector3:
	var top_radius := GEOMETRY.coping_radius(section, theta)
	var height := GEOMETRY.coping_height(section, theta)
	var top := GEOMETRY.point(section, theta, top_radius, height)
	var low := GEOMETRY.point(section, theta, top_radius + 1.0 / tan(deg_to_rad(60.0)) * section.side / section.bend, height - 1.0)
	var along := GEOMETRY.point(section, theta + .01, GEOMETRY.coping_radius(section, theta + .01), GEOMETRY.coping_height(section, theta + .01))
	var normal := (low - top).cross(along - top).normalized()
	return normal if normal.y > 0 else -normal

## p / r12: the physical riding faces from the run-up to the release, sampled twice per 3 degree
## face by ray, turn by no more than 5 degrees between samples: no crease like the old lead's
## 22 degree seam (which stopped a 19 m/s arrival dead), and every sample is surf, not floor.
func outflow_seams() -> void:
	var space: PhysicsDirectSpaceState3D = game.get("level").get_world_3d().direct_space_state
	var last := Vector3.ZERO
	var worst := 0.0
	var steepness := Vector2(90, 0)
	var samples := 0
	for label: String in ["OutflowLead", "OutflowSweep", "OutflowSurf"]:
		var section := _section(label)
		for i: int in int(section.segments) * 2:
			var theta: float = section.arc * (i + .5) / (section.segments * 2)
			var normal := _face_normal(section, theta)
			var on := GEOMETRY.point(section, theta, GEOMETRY.coping_radius(section, theta) + 1.0 / tan(deg_to_rad(60.0)) * section.side / section.bend, GEOMETRY.coping_height(section, theta) - 1.0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(on + normal, on - normal))
			if hit.is_empty() or str((hit.collider as Node).get_meta("surf_section", "")) != label:
				check(false, "%s has a riding face at %.1f degrees" % [label, rad_to_deg(theta)])
				return
			var face: Vector3 = hit.normal
			if last != Vector3.ZERO:
				worst = maxf(worst, rad_to_deg(last.angle_to(face)))
			var slope := rad_to_deg(acos(face.y))
			steepness = Vector2(minf(steepness.x, slope), maxf(steepness.y, slope))
			last = face
			samples += 1
	check(worst <= 5.0, "outflow riding faces turn smoothly, no seam: worst %.2f degrees between %d samples" % [worst, samples])
	check(steepness.x > 50.0 and steepness.y < 70.0, "every outflow face is surf (%.1f..%.1f degrees)" % [steepness.x, steepness.y])

## p / r12: a runner leaving the S anywhere from its coping to 3 m below it, at 12-24 m/s and
## falling or still rising, flies clear: the first thing the standing capsule meets is a floor
## (apron, ramp, walk or basin), never a ceiling, rail or wall. the old yard jetty and the
## crossing's fascia sat in this corridor.
func release_corridor() -> void:
	var level: Node3D = game.get("level")
	var space := level.get_world_3d().direct_space_state
	var surf := _section("OutflowSurf")
	var exclude: Array[RID] = []
	for node: Node in level.find_children("*", "StaticBody3D", true, false):
		if str(node.get_meta("surf_section", "")).begins_with("Outflow"):
			exclude.append((node as StaticBody3D).get_rid())
	var capsule := CapsuleShape3D.new()
	capsule.radius = .3
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.exclude = exclude
	query.collision_mask = 1
	var yaw := GEOMETRY.tangent_yaw(surf, surf.arc)
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var normal := _face_normal(surf, surf.arc)
	var bad: Array = []
	var landings := {}
	var cases := 0
	for depth: float in [0.0, 1.0, 2.0, 3.0]:
		var radius: float = GEOMETRY.coping_radius(surf, surf.arc) + depth / tan(deg_to_rad(60.0)) * surf.side / surf.bend
		var feet := GEOMETRY.point(surf, surf.arc, radius, GEOMETRY.coping_height(surf, surf.arc) - depth)
		# the capsule's lower sphere rests on the face; its centre sits 0.9 m above the feet.
		var start := feet + normal * .32 + Vector3.UP * .6
		for speed: float in [12.0, 18.0, 24.0]:
			for rise: float in [-4.0, 0.0, 3.0]:
				cases += 1
				var at := start
				var velocity := forward * speed + Vector3.UP * rise
				var result := "no landing"
				for step: int in 240:
					var motion := velocity / 120.0
					query.transform = Transform3D(Basis.IDENTITY, at)
					query.motion = motion
					var fraction := space.cast_motion(query)
					if fraction.size() == 2 and fraction[1] < 1.0:
						query.transform = Transform3D(Basis.IDENTITY, at + motion * fraction[1])
						query.motion = Vector3.ZERO
						var info := space.get_rest_info(query)
						var body := instance_from_id(int(info.get("collider_id", 0))) as Node
						var name := str(body.name) if body != null else "?"
						if body != null and name.begins_with("@"):
							# a duplicate-named deck (the front walk's east span): name it by height.
							name = "deck at y %.1f" % (info.get("point", Vector3.ZERO) as Vector3).y
						if (info.get("normal", Vector3.ZERO) as Vector3).y >= cos(deg_to_rad(46.0)):
							result = ""
							landings[name] = true
						else:
							result = "%s (normal %s) at %s" % [name, info.get("normal"), at]
						break
					at += motion
					velocity.y -= 20.0 / 120.0
				if not result.is_empty():
					bad.append("depth %.0f speed %.0f vy %.0f: %s" % [depth, speed, rise, result])
	check(bad.is_empty(), "all %d outflow releases land on a floor (%s): %s" % [cases, landings.keys(), bad])

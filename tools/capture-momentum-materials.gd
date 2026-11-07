extends SceneTree
## p / labelled native study of the momentum art kit on an isolated in-memory fixture:
## run-up deck, formwork and old walls, a pitched slope, a yawed slab, a steel bridge with
## ochre rails and brick. it is art evidence only, never the game world or a route proof.
## --evidence-dir=<fresh absolute directory outside Git> --surface=flat|r12|kit
## --mode=stills|motion|normals [--frames=N] [--swap=<set>:<texture id>:<metres>] [--far-fade=F]

const Materials := preload("res://scripts/momentum_materials.gd")
const R12_CONCRETE: Shader = preload("res://shaders/spillway_concrete.gdshader")
const R12_BRICK: Shader = preload("res://shaders/spillway_art_brick.gdshader")
const RUNUP := 48.0
const SLOPE_DEGREES := 18.0
const SLOPE_LENGTH := 24.0
const LOWER := 14.0
const BRIDGE := 14.0
const PIER := 10.0
const WATER_Y := -12.0
# p / fixed views: name, eye, look-at. running views sit at eye height on the line.
const VIEWS := [
	["runup_run", Vector3(0, 1.6, 2), Vector3(0, 0.2, -40)],
	["deck_close", Vector3(1.5, 1.6, -6), Vector3(2.2, 0, -8.4)],
	["deck_mid", Vector3(0, 1.6, -10), Vector3(0, 0, -22)],
	["wall_close", Vector3(6.2, 1.6, -14), Vector3(8, 1.9, -15.6)],
	["wall_run", Vector3(5.5, 1.6, 2), Vector3(8, 2.6, -40)],
	["old_wall", Vector3(5.5, 1.6, -28), Vector3(8, 2, -38)],
	["rail_close", Vector3(-5.5, 1.6, -8), Vector3(-7.9, 0.8, -11)],
	["slope_top", Vector3(0, 1.7, -44), Vector3(0, -7, -72)],
	["slope_side", Vector3(-16, -3, -60), Vector3(0, -4, -60)],
	["bridge_run", Vector3(0, -5.8, -80), Vector3(0, -7.2, -100)],
	["brick_close", Vector3(3.4, -5.8, -88), Vector3(7, -5.2, -91)],
	["yawed_slab", Vector3(-26, 8, -14), Vector3(-34, 0, -30)],
	["overview", Vector3(-30, 16, -10), Vector3(0, -4, -70)],
]
# views rendered twice, the second turned by a quarter pixel, to measure aliasing.
const SHIFT_VIEWS := ["runup_run", "wall_run", "slope_top", "bridge_run"]

var output := ""
var surface := "kit"
var swaps: Dictionary = {}
var far_fade := -1.0
var fixture: Node3D
var _materials: Dictionary = {}


class StudyBody extends CharacterBody3D:
	# p / study body only: plain walk and hop to carry an ordinary camera, not a motor candidate.
	const SPEED := 9.0
	const ACCEL := 40.0
	const AIR_ACCEL := 8.0
	const JUMP := 5.2
	const GRAVITY := 18.0
	const SENSITIVITY := 0.0022
	var camera := Camera3D.new()
	var hops := 0

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.8
		shape.shape = capsule
		shape.position.y = 0.9
		add_child(shape)
		camera.position.y = 1.6
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 90.0
		camera.near = 0.05
		camera.far = 800.0
		add_child(camera)
		camera.make_current()

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			rotation.y -= event.relative.x * SENSITIVITY

	func _physics_process(delta: float) -> void:
		var wish := Vector3.ZERO
		if Input.is_action_pressed("study_forward"):
			wish -= basis.z
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		var rate := ACCEL if is_on_floor() else AIR_ACCEL
		if wish != Vector3.ZERO or is_on_floor():
			horizontal = horizontal.move_toward(wish.normalized() * SPEED, rate * delta)
		velocity = Vector3(horizontal.x, velocity.y, horizontal.z)
		if is_on_floor() and Input.is_action_pressed("study_jump"):
			velocity.y = JUMP
			hops += 1
		else:
			velocity.y -= GRAVITY * delta
		move_and_slide()


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var mode := "stills"
	var frames := 900
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			output = arg.trim_prefix("--evidence-dir=").simplify_path()
		elif arg.begins_with("--surface="):
			surface = arg.trim_prefix("--surface=")
		elif arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--frames="):
			frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--swap="):
			var parts := arg.trim_prefix("--swap=").split(":")
			swaps[StringName(parts[0])] = {"id": parts[1], "metres": float(parts[2])}
		elif arg.begins_with("--far-fade="):
			far_fade = float(arg.trim_prefix("--far-fade="))
	var profile := OS.get_environment("XDG_DATA_HOME").simplify_path()
	var allowed: bool = preload("res://scripts/spillway_driver.gd").evidence_path_allowed(output)
	if DisplayServer.get_name() == "headless" or not allowed or profile.is_empty() \
			or profile == OS.get_environment("HOME").path_join(".local/share") \
			or not surface in ["flat", "r12", "kit"] or not mode in ["stills", "motion", "normals"]:
		printerr("capture-momentum-materials needs a native display, an isolated XDG_DATA_HOME, ",
			"an evidence directory outside Git, --surface=flat|r12|kit and --mode=stills|motion|normals")
		quit(2)
		return
	if FileAccess.file_exists(output.path_join("result.json")):
		printerr("use a fresh evidence directory")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var result: Dictionary
	if mode == "normals":
		result = await normals_probe()
	else:
		build_fixture()
		result = await stills() if mode == "stills" else await motion(frames)
	result.merge({"surface": surface, "mode": mode, "swaps": swaps, "far_fade": far_fade,
		"fixture": "isolated in-memory material study; not the game world, a route or a motor",
		"display": DisplayServer.get_name(), "renderer": RenderingServer.get_video_adapter_name(),
		"renderer_vendor": RenderingServer.get_video_adapter_vendor(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"viewport": [root.size.x, root.size.y], "godot": Engine.get_version_info().string,
		"profile": OS.get_user_data_dir(), "args": OS.get_cmdline_args(),
		"limits": "software rasteriser timings; no GPU frame-rate or feel claim"})
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("momentum materials: ", JSON.stringify({"passed": result.get("passed"), "mode": mode, "surface": surface}))
	quit(0 if result.get("passed", false) else 1)


func material(kind: StringName) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var made: Material
	if surface == "kit":
		var overrides := {}
		var spec: Dictionary = Materials.KINDS[kind]
		for slot: String in ["top", "side"]:
			if swaps.has(spec[slot]):
				overrides[slot] = swaps[spec[slot]]
		if far_fade >= 0.0:
			overrides["far_normal_fade"] = far_fade
		made = Materials.get_material(kind) if overrides.is_empty() else Materials.build(kind, overrides)
	elif surface == "r12" and kind in [&"deck", &"concrete", &"old_concrete"]:
		# r12 art-pass concrete tones; r12 had one concrete for decks and walls.
		var shader := ShaderMaterial.new()
		shader.shader = R12_CONCRETE
		var old := kind == &"old_concrete"
		shader.set_shader_parameter("wall_color", Color("6f7369") if old else Color("837f75"))
		shader.set_shader_parameter("deck_color", Color("838477") if old else Color("958f81"))
		shader.set_shader_parameter("weathering", 0.22 if old else 0.12)
		made = shader
	elif surface == "r12" and kind == &"brick":
		var brick := ShaderMaterial.new()
		brick.shader = R12_BRICK
		brick.set_shader_parameter("brick_color", Color("9a5540"))
		brick.set_shader_parameter("mortar_color", Color("c4b49c"))
		brick.set_shader_parameter("cap_color", Color("9c978a"))
		made = brick
	else:
		# flat baseline: the r12 palette as plain colours.
		var flat := StandardMaterial3D.new()
		var colors := {&"deck": Color("958f81"), &"concrete": Color("837f75"), &"old_concrete": Color("6f7369"),
			&"steel": Color("26363a"), &"ochre": Color("d79a2b"), &"brick": Color("9a5540")}
		flat.albedo_color = colors[kind]
		flat.roughness = {&"steel": 0.48, &"ochre": 0.62}.get(kind, 0.9)
		flat.metallic = {&"steel": 0.6, &"ochre": 0.05}.get(kind, 0.0)
		made = flat
	_materials[kind] = made
	return made


func environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	# r12 art-pass light so surfaces are compared under the dam's established day.
	sky_material.sky_top_color = Color("4f86b0")
	sky_material.sky_horizon_color = Color("cddbdc")
	sky_material.sky_curve = 0.16
	sky_material.ground_horizon_color = Color("b9cccf")
	sky_material.ground_bottom_color = Color("7c8f86")
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9db7cf")
	env.ambient_light_energy = 0.46
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_light_color = Color("bfd0d4")
	env.fog_density = 0.0021
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	world.environment = env
	fixture.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-39.0, -34.0, 0.0)
	sun.light_color = Color("ffe6c2")
	sun.light_energy = 1.32
	sun.shadow_enabled = true
	sun.shadow_blur = 0.6
	sun.directional_shadow_max_distance = 140.0
	fixture.add_child(sun)


func block(kind: StringName, size: Vector3, origin: Vector3, rotation := Basis.IDENTITY, override: Material = null) -> void:
	var body := StaticBody3D.new()
	body.transform = Transform3D(rotation, origin)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = override if override != null else material(kind)
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	body.set_meta("kind", kind)
	fixture.add_child(body)


func rails(from: Vector3, length: float, heading_degrees: float) -> void:
	# sections run along their local +x; heading 90 turns +x to world -z.
	var count := int(length / 2.0)
	var direction := Basis(Vector3.UP, deg_to_rad(heading_degrees)) * Vector3.RIGHT
	for i: int in count + 1:
		var prop: Node3D = Materials.instance_prop(&"rail_post" if i == count else &"rail_section")
		prop.rotation_degrees.y = heading_degrees
		prop.position = from + direction * 2.0 * i
		if surface != "kit":
			for mesh: Node in prop.find_children("*", "MeshInstance3D", true, false):
				(mesh as MeshInstance3D).material_override = material(&"ochre")
		fixture.add_child(prop)


func build_fixture() -> void:
	fixture = Node3D.new()
	fixture.name = "MomentumMaterialStudy"
	root.add_child(fixture)
	current_scene = fixture
	environment()
	# broad run-up deck and the formwork wall beside it; the wall turns old past a monolith joint.
	block(&"deck", Vector3(16, 2, RUNUP + 6), Vector3(0, -1, (6 - RUNUP) / 2))
	block(&"concrete", Vector3(1, 7, 30), Vector3(8.5, 2.5, -9))
	block(&"old_concrete", Vector3(1, 7, RUNUP - 24), Vector3(8.5, 2.5, -(24 + RUNUP) / 2))
	rails(Vector3(-7.9, 0, 4), RUNUP - 2, 90.0)
	# pitched slope down to the lower deck.
	var pitch := Basis(Vector3.RIGHT, deg_to_rad(-SLOPE_DEGREES))
	var down := pitch * Vector3.FORWARD
	var top := Vector3(0, 0, -RUNUP)
	block(&"deck", Vector3(12, 1.5, SLOPE_LENGTH), top + down * SLOPE_LENGTH / 2 - pitch.y * 0.75, pitch)
	var lower := top + down * SLOPE_LENGTH
	block(&"concrete", Vector3(14, 2, LOWER), Vector3(0, lower.y - 1, lower.z - LOWER / 2))
	var damp: Material = material(&"old_concrete")
	if surface == "kit":
		damp = Materials.variant(&"old_concrete", {"waterline": WATER_Y + 1.4})
	block(&"old_concrete", Vector3(14, 5, LOWER), Vector3(0, lower.y - 4.5, lower.z - LOWER / 2), Basis.IDENTITY, damp)
	# flush steel bridge with ochre rails, steel girders and a brick gatehouse beside it.
	var bridge_z := lower.z - LOWER
	block(&"steel", Vector3(5, 0.5, BRIDGE), Vector3(0, lower.y - 0.25, bridge_z - BRIDGE / 2))
	for side: float in [-1.6, 1.6]:
		block(&"steel", Vector3(0.35, 0.9, BRIDGE), Vector3(side, lower.y - 0.95, bridge_z - BRIDGE / 2))
	rails(Vector3(-2.45, lower.y, bridge_z - 0.2), BRIDGE - 0.4, 90.0)
	rails(Vector3(2.45, lower.y, bridge_z - 0.2), BRIDGE - 0.4, 90.0)
	block(&"brick", Vector3(6, 9, 6), Vector3(7, lower.y - 2.5, bridge_z - 7))
	block(&"brick", Vector3(10, 6, PIER), Vector3(0, lower.y - 3, bridge_z - BRIDGE - PIER / 2))
	# a slab yawed and pitched together, to show joints follow the slab's own edges.
	var skew := Basis(Vector3.UP, deg_to_rad(30)) * Basis(Vector3.RIGHT, deg_to_rad(-15))
	block(&"deck", Vector3(8, 1, 20), Vector3(-34, 0, -30), skew)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	water.mesh = plane
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color("2c5f66")
	water_material.roughness = 0.12
	water.material_override = water_material
	water.position.y = WATER_Y
	fixture.add_child(water)
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "MATERIAL STUDY  %s  isolated fixture, not a route" % surface.to_upper()
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	layer.add_child(label)
	fixture.add_child(layer)


func save(name: String) -> bool:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK


func render_info() -> Dictionary:
	return {"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"texture_mem": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		"buffer_mem": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),
		"video_mem": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)}


func stills() -> Dictionary:
	var camera := Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 90.0
	camera.near = 0.05
	camera.far = 800.0
	fixture.add_child(camera)
	camera.make_current()
	var first := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var first_frame_ms := (Time.get_ticks_usec() - first) / 1000.0
	var rows: Array = []
	var saved := true
	# a quarter pixel of yaw at this horizontal fov and width.
	var quarter := 0.25 * 2.0 * tan(deg_to_rad(45.0)) / root.size.x
	for view: Array in VIEWS:
		camera.look_at_from_position(view[1], view[2], Vector3.UP)
		for i: int in 3:
			await RenderingServer.frame_post_draw
		var samples: Array = []
		for i: int in 3:
			var before := Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			samples.append((Time.get_ticks_usec() - before) / 1000.0)
		var info := render_info()
		saved = await save(view[0]) and saved
		if view[0] in SHIFT_VIEWS:
			camera.rotate_object_local(Vector3.UP, -quarter)
			await RenderingServer.frame_post_draw
			saved = await save(view[0] + "_shift") and saved
		rows.append({"name": view[0], "eye": var_to_str(view[1]), "at": var_to_str(view[2]),
			"host_frame_ms": samples, "render": info})
	return {"passed": saved and rows.size() == VIEWS.size(), "first_frame_ms": first_frame_ms,
		"quarter_pixel_yaw_rad": quarter, "views": rows,
		"materials": _materials.keys().map(func(kind: StringName) -> String: return String(kind))}


func mouse(dx: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, 0)
	Input.parse_input_event(event)


func motion(frames: int) -> Dictionary:
	for action: String in ["study_forward", "study_jump"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var body := StudyBody.new()
	body.position = Vector3(0, 0.02, 2)
	fixture.add_child(body)
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	var trace := FileAccess.open(output.path_join("trace.jsonl"), FileAccess.WRITE)
	var saved := 0
	var yaw_was := 0.0
	for frame: int in frames:
		var t := frame / 60.0
		# tape: forward from the start, a gentle mouse weave on the run-up, hops held from 2 s.
		if frame == 6:
			Input.action_press("study_forward")
		if frame == 120:
			Input.action_press("study_jump")
		var yaw := 0.0
		if t > 0.5 and t < 4.5:
			yaw = 0.12 * sin(TAU * (t - 0.5) / 2.0)
		mouse(-(yaw - yaw_was) / StudyBody.SENSITIVITY)
		yaw_was = yaw
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(output.path_join("frames/%05d.png" % frame)) == OK:
			saved += 1
		trace.store_line(JSON.stringify({"frame": frame, "physics_frame": Engine.get_physics_frames(),
			"position": [body.global_position.x, body.global_position.y, body.global_position.z],
			"velocity": [body.velocity.x, body.velocity.y, body.velocity.z],
			"on_floor": body.is_on_floor(), "hops": body.hops, "yaw": body.rotation.y}))
		if body.global_position.z < -RUNUP - SLOPE_LENGTH - LOWER - BRIDGE - PIER + 3.0 or body.global_position.y < WATER_Y + 2.0:
			break
	Input.action_release("study_forward")
	Input.action_release("study_jump")
	trace.close()
	var end := body.global_position
	return {"passed": saved > 60 and end.y > WATER_Y + 2.0, "frames_saved": saved, "end": var_to_str(end),
		"hops": body.hops,
		"method": "fixed-fps 60 frames; body moved by parsed mouse motion and pressed study actions"}


# ---- normal-convention probe -------------------------------------------------------

func dome_texture() -> ImageTexture:
	# open-gl convention hemisphere: green up in the image, red to the right.
	var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y: int in 256:
		for x: int in 256:
			var r := Vector2((x + 0.5) / 128.0 - 1.0, 1.0 - (y + 0.5) / 128.0) / 0.8
			var n := Vector3(0, 0, 1)
			if r.length() < 1.0:
				n = Vector3(r.x, r.y, sqrt(1.0 - r.length_squared()))
			image.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func solid(color: Color) -> ImageTexture:
	var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(color)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func halves(image: Image) -> Dictionary:
	# mean luminance of the left/right and top/bottom halves of the central crop.
	var size := 300
	var x0 := image.get_width() / 2 - size / 2
	var y0 := image.get_height() / 2 - size / 2
	var sums := {"left": 0.0, "right": 0.0, "top": 0.0, "bottom": 0.0}
	for y: int in size:
		for x: int in size:
			var l := image.get_pixel(x0 + x, y0 + y).get_luminance()
			sums["left" if x < size / 2 else "right"] += l
			sums["top" if y < size / 2 else "bottom"] += l
	for key: String in sums:
		sums[key] /= size * size / 2.0
	return sums


func normals_probe() -> Dictionary:
	fixture = Node3D.new()
	root.add_child(fixture)
	current_scene = fixture
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.15
	world.environment = env
	fixture.add_child(world)
	var light := DirectionalLight3D.new()
	fixture.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 40.0
	fixture.add_child(camera)
	camera.make_current()
	var probe := Materials.build(&"concrete", {"top_albedo": solid(Color.WHITE), "side_albedo": solid(Color.WHITE),
		"top_normal": dome_texture(), "side_normal": dome_texture(),
		"top_arm": solid(Color(1, 0.8, 0)), "side_arm": solid(Color(1, 0.8, 0)),
		"top_tile": Vector2.ONE, "side_tile": Vector2.ONE, "top_tint": Vector3.ONE, "side_tint": Vector3.ONE,
		"bay_size": Vector2.ZERO, "side_joint_spacing": 0.0, "macro_strength": 0.0, "far_normal_fade": 0.0})
	var skew := Basis(Vector3.UP, deg_to_rad(35)) * Basis(Vector3.RIGHT, deg_to_rad(-20))
	# each case: surface frame (origin of a dome centre, normal, image right, image up) and box.
	var cases := [
		{"name": "floor", "basis": Basis.IDENTITY, "centre": Vector3(0.5, 0, 0.5), "size": Vector3(4, 0.5, 4), "face": Vector3.UP,
			"right": Vector3.RIGHT, "up": Vector3.FORWARD},
		{"name": "wall", "basis": Basis.IDENTITY, "centre": Vector3(0.5, 0.5, 0), "size": Vector3(4, 4, 0.5), "face": Vector3.BACK,
			"right": Vector3.RIGHT, "up": Vector3.UP},
		{"name": "yawed_pitched_slab", "basis": skew, "centre": skew * Vector3(0.5, 0, 0.5), "size": Vector3(4, 0.5, 4),
			"face": skew * Vector3.UP, "right": skew * Vector3.RIGHT, "up": skew * Vector3.FORWARD},
	]
	var rows: Array = []
	var passed := true
	for item: Dictionary in cases:
		var holder := Node3D.new()
		fixture.add_child(holder)
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = item.size
		body.mesh = box
		body.material_override = probe
		var face: Vector3 = item.face
		# every probe box is 0.5 m thick along its face normal.
		body.transform = Transform3D(item.basis, item.centre - face * 0.25)
		holder.add_child(body)
		camera.look_at_from_position(item.centre + face * 1.2, item.centre, item.up)
		for side: String in ["right", "up"]:
			var toward: Vector3 = (item[side] as Vector3) + face * 0.6
			light.transform = Transform3D(Basis.looking_at(-toward.normalized(), face if side == "right" else item.right), Vector3.ZERO)
			for i: int in 3:
				await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png(output.path_join("normals_%s_light_%s.png" % [item.name, side]))
			var h := halves(image)
			var ok: bool = h.right > h.left * 1.15 if side == "right" else h.top > h.bottom * 1.15
			passed = passed and ok
			rows.append({"surface": item.name, "light_from": side, "halves": h, "brighter_side_correct": ok})
		holder.queue_free()
		await process_frame
	# imported (vram, two-channel) normal map against the same png decoded raw at runtime.
	var path := "res://assets/momentum/textures/%s/%s_nor_gl_1k.png" % [Materials.SETS[&"formwork"].id, Materials.SETS[&"formwork"].id]
	var raw_image := Image.load_from_file(ProjectSettings.globalize_path(path))
	raw_image.generate_mipmaps()
	var raw := ImageTexture.create_from_image(raw_image)
	var wall := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(6, 6, 0.5)
	wall.mesh = wall_box
	wall.position = Vector3(0.5, 0.5, -0.25)
	fixture.add_child(wall)
	camera.look_at_from_position(Vector3(0.5, 0.5, 1.6), Vector3(0.5, 0.5, 0), Vector3.UP)
	light.transform = Transform3D(Basis.looking_at(-Vector3(0.3, 1.0, 0.35).normalized(), Vector3.RIGHT), Vector3.ZERO)
	var compared: Array = []
	for source: String in ["imported", "raw_png"]:
		var plain := Materials.build(&"concrete", {"far_normal_fade": 0.0, "side_albedo": solid(Color(0.6, 0.6, 0.6)),
			"macro_strength": 0.0, "side_joint_spacing": 0.0})
		if source == "raw_png":
			plain.set_shader_parameter("side_normal", raw)
		wall.material_override = plain
		for i: int in 3:
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png(output.path_join("normals_formwork_%s.png" % source))
		compared.append(image)
	var difference := 0.0
	var count := 0
	for y: int in range(60, 660, 3):
		for x: int in range(100, 1180, 3):
			difference += absf(compared[0].get_pixel(x, y).get_luminance() - compared[1].get_pixel(x, y).get_luminance())
			count += 1
	var mean_difference := difference / count
	var import_ok := mean_difference < 0.02
	return {"passed": passed and import_ok, "dome_cases": rows,
		"imported_vs_raw_mean_abs_luma": mean_difference, "imported_matches_raw": import_ok,
		"method": "synthetic open-gl dome normals lit from the image right and image up of each surface; then the imported formwork normal against the same png decoded at runtime"}

extends SceneTree
## presentation lifecycle and bounds, independent of the motor identity tape.
const FX := preload("res://scripts/fx/tether_feedback.gd")
const SOUND := preload("res://scripts/audio/tether_sound.gd")
const LENS := preload("res://scripts/fx/tether_lens.gd")
const RUNNER := preload("res://scripts/movement/grapple_player.gd")
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label_: String) -> void:
	if not ok:
		failures.append(label_)
	print("PASS " if ok else "FAIL ", label_)

func run() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	projection_case()
	var base := Camera3D.new()
	root.add_child(base)
	for angle: float in [45.0, 80.0, 120.0]:
		base.fov = angle
		var projected := base.unproject_position(FX.rope_origin(base, angle))
		check(projected.y > root.get_visible_rect().size.y, "cable termination stays below viewport: " + str(angle))
	base.fov = 80
	base.make_current()
	var lens := LENS.new()
	root.add_child(lens)
	var max_offset := 0.0
	var max_step := 0.0
	for frame: int in 1000:
		var prior := lens.offset_degrees
		lens.update(base, 2000 if frame % 60 < 30 else 0, 1.0 / 60, true)
		max_offset = maxf(max_offset, lens.offset_degrees)
		max_step = maxf(max_step, absf(lens.offset_degrees - prior))
	check(max_offset <= 3.0 and max_step <= 1.5 / 60 + 0.00001, "FOV bound and rate limit")
	check(base.fov == 80 and lens.current, "source camera FOV untouched")
	lens.reset()
	check(base.current and lens.offset_degrees == 0, "lens restores source camera")
	lens.update(base, 1000, 0.1, true)
	base.free()
	var replacement := Camera3D.new()
	root.add_child(replacement)
	lens.reset()
	check(replacement.current, "freed source falls back to replacement camera")
	lens.update(replacement, 1000, 0.1, true)
	root.remove_child(replacement)
	var next := Camera3D.new()
	root.add_child(next)
	lens.reset()
	check(next.current, "detached source falls back without touching detached camera")
	lens.free()
	replacement.free()
	next.free()
	print(JSON.stringify({"ok": failures.is_empty(), "failures": failures}))
	for frame: int in 4:
		await process_frame
	quit(0 if failures.is_empty() else 1)

func projection_case() -> void:
	# a real observer fixture crosses the near plane at an oblique angle, without motor steps.
	var world := Node3D.new()
	root.add_child(world)
	var player := RUNNER.new()
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.input_enabled = true
	var camera: Camera3D = player.camera
	camera.global_transform = Transform3D.IDENTITY
	camera.fov = 90.0
	camera.make_current()
	var endpoint := Vector3(-6, 6, 2)
	player.grapple = {"position": endpoint}
	player.grapple_length_u = player._hull_centre().distance_to(endpoint) / player.U
	var fx := FX.new()
	world.add_child(fx)
	fx.set_process(false)
	fx.attach(player)
	fx.configure({"tether_rope_visual": true})
	fx.observe(1.0 / 60)
	var maximum := 0.0
	var inspected := 0
	for piece: MeshInstance3D in fx._outlines:
		if not piece.visible:
			continue
		var mesh_: CylinderMesh = piece.mesh
		for sign_: float in [-1.0, 1.0]:
			var centre := piece.global_transform * Vector3(0, sign_ * mesh_.height * 0.5, 0)
			var depth := -camera.global_basis.z.dot(centre - camera.global_position)
			if depth < camera.near:
				continue
			var screen := camera.unproject_position(centre)
			if not root.get_visible_rect().has_point(screen):
				continue
			var tangent := camera.unproject_position(centre + piece.global_basis.y.normalized() * 0.001) - screen
			if tangent.length_squared() < 0.000001:
				continue
			var normal := Vector2(-tangent.y, tangent.x).normalized()
			var radius := mesh_.top_radius if sign_ > 0 else mesh_.bottom_radius
			var low := INF
			var high := -INF
			for corner: int in 6:
				var angle := TAU * float(corner) / 6.0
				var edge := centre + (piece.global_basis.x * cos(angle) + piece.global_basis.z * sin(angle)) * radius
				var projected := camera.unproject_position(edge).dot(normal)
				low = minf(low, projected)
				high = maxf(high, projected)
			maximum = maxf(maximum, high - low)
			inspected += 1
	var continuous := true
	for index: int in range(1, fx._outlines.size()):
		var prior: MeshInstance3D = fx._outlines[index - 1]
		var next_: MeshInstance3D = fx._outlines[index]
		if prior.visible and next_.visible:
			continuous = continuous and is_equal_approx((prior.mesh as CylinderMesh).top_radius, (next_.mesh as CylinderMesh).bottom_radius)
	check(continuous, "adjacent cable segments share endpoint radii")
	var clipped := FX.clip_segment(camera, Vector3(0, 0, -1), Vector3(1, 0, 1))
	check(clipped.size() == 2 and is_equal_approx(-clipped[1].z, camera.near), "crossing cable clipped at the near plane")
	check(FX.clip_segment(camera, Vector3(0, 0, 1), Vector3(1, 0, 2)).is_empty(), "fully hidden cable omitted")
	print("near-plane outline maximum pixels=", maximum, " visible endpoints=", inspected)
	check(inspected > 0 and maximum <= 8.0, "oblique foreground cable never becomes a broad strip")
	world.free()

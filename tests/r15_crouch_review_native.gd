extends "res://tests/test_r15_crouch_review.gd"
## p / native confirmation of the settings diagnostic, with actual xtest keys/mouse.
## one setup in _run, then only input events. f7 is a diagnostic settings action, not a
## production binding. f10 closes and flushes compressed observer telemetry.

var observed := PackedStringArray()

func _run() -> void:
	MAIN.bind_inputs()
	DirAccess.make_dir_recursive_absolute(out)
	world = Node3D.new()
	root.add_child(world)
	box("floor", Vector3(0, -32, 0), Vector3(800, 64, 3000))
	box("low_roof", Vector3(0, 78, -600), Vector3(256, 32, 400))
	for body: Node3D in world.get_children():
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = (body.get_child(0).shape as BoxShape3D).size
		mesh.mesh = cube
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("9f7960") if body.name == "low_roof" else Color("597b80")
		mesh.material_override = material
		body.add_child(mesh)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("7c9dab")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	environment.environment = env
	world.add_child(environment)
	player = R15.new()
	twin = R14.new()
	root.add_child(player)
	root.add_child(twin)
	reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0) * U)
	for runner: CharacterBody3D in [player, twin]:
		runner.collision_layer = 2
		runner.collision_mask = 1
		runner.call("apply_settings", cv())
		runner.call("apply_engine_rate")
		runner.call("reset_to", reset_pose)
	for early: bool in [true, false]:
		var p := Probe.new()
		p.suite = self
		p.early = early
		p.process_physics_priority = -1000 if early else 1000
		p.process_priority = 1000
		root.add_child(p)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	running = true

func early_tick() -> void:
	tick += 1

func late_tick() -> void:
	if not running:
		return
	var s: Dictionary = player.call("get_motion_state")
	var row := {"t": tick, "p": arr(s.position / U), "v": arr(s.velocity_u),
		"actual_v": arr(s.actual_velocity / U), "ducked": s.duck.ducked,
		"held": s.duck.held, "blocked": s.duck.stand_blocked, "height": s.hull.height_u,
		"grounded": s.grounded, "yaw": s.yaw, "e": s.events,
		"overlap": overlaps_at(s.position, s.hull.height_u)}
	var line := JSON.stringify(row)
	observed.append(line)
	var f := FileAccess.open(out.path_join("latest.json"), FileAccess.WRITE)
	f.store_string(line)
	f.close()
	if tick > 128 * 40:
		finish()

func frame_tick() -> void:
	pass

func control_input(e: InputEvent) -> void:
	super(e)
	if e is InputEventKey and e.pressed and e.physical_keycode == KEY_F10:
		finish()

func finish() -> void:
	running = false
	LAB.write_gzip(out.path_join("telemetry.jsonl.gz"), observed)
	var f := FileAccess.open(out.path_join("actions.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(settings_actions, "\t"))
	f.close()
	quit()

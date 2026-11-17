extends SceneTree
## deterministic input tape on the real motor; compare serialized motion, not tolerances.
const RUNNER := preload("res://scripts/movement/grapple_player.gd")
const FX := preload("res://scripts/fx/tether_feedback.gd")
var output := "/tmp/r22-04-swing-feel/identity"
var failures: Array[String] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func button(index: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tape(on: bool) -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var player := RUNNER.new()
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.apply_preset("csgo_server")
	player.configure_tether("elastic-arc", false)
	player.input_enabled = true
	player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
	player._input_blocked = false
	var anchor := Node3D.new()
	anchor.set_meta("r21_anchor_id", "identity-anchor")
	anchor.set_meta("anchor_name", "Identity anchor")
	anchor.add_to_group(player.ANCHOR_GROUP)
	world.add_child(anchor)
	anchor.global_position = player._eye() + Vector3(0, 0, -20)
	var fx := FX.new()
	world.add_child(fx)
	fx.set_process(false)
	fx.attach(player)
	var settings := {}
	for key: String in FX.KEYS:
		settings[key] = on
	fx.configure(settings)
	var rows: Array = []
	var attached_ticks := 0
	var reel_ticks := 0
	var slack_ticks := 0
	var identity := player.r21_rules_sha256()
	for tick: int in 384:
		if tick == 4 or tick == 170:
			button(MOUSE_BUTTON_LEFT, true)
		if tick == 120 or tick == 260:
			button(MOUSE_BUTTON_LEFT, false)
		if tick == 20:
			button(MOUSE_BUTTON_RIGHT, true)
		if tick == 95:
			button(MOUSE_BUTTON_RIGHT, false)
		if tick == 140:
			player.block_tether("restart")
			player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
			fx.reset()
		Input.action_press("move_right", 1.0 if tick % 80 < 40 else 0.0)
		player._physics_process(1.0 / 128)
		player._process(1.0 / 128)
		var before := var_to_bytes(player.get_motion_state())
		for frame: int in 3:
			fx.observe(1.0 / 384)
		if before != var_to_bytes(player.get_motion_state()):
			failures.append("observer changed motion at tick " + str(tick))
		if not player.grapple.is_empty():
			attached_ticks += 1
			if player.reel_active():
				reel_ticks += 1
			if player._hull_centre().distance_to(player.grapple.position) < player.grapple_length_u * player.U:
				slack_ticks += 1
		rows.append([player.global_transform, player.velocity, player.get_motion_state(), player.r21_rules_sha256()])
	button(MOUSE_BUTTON_LEFT, false)
	button(MOUSE_BUTTON_RIGHT, false)
	Input.action_release("move_right")
	var bytes := var_to_bytes(rows)
	world.free()
	return {"bytes": bytes, "attached_ticks": attached_ticks, "reel_ticks": reel_ticks, "slack_ticks": slack_ticks, "identity": identity}

func run() -> void:
	root.size = Vector2i(1280, 720)
	for action: String in ["jump", "move_forward", "move_back", "move_left", "move_right", "crouch", "look_left", "look_right", "look_up", "look_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var off := tape(false)
	var on := tape(true)
	if off.bytes != on.bytes:
		failures.append("on/off serialized motion differs")
	if on.attached_ticks == 0 or on.reel_ticks == 0:
		failures.append("tape did not exercise attach and reel")
	DirAccess.make_dir_recursive_absolute(output)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(on.bytes)
	var summary := {"ok": failures.is_empty(), "failures": failures, "motion_sha256": hash.finish().hex_encode(), "bytes_compared": on.bytes.size(), "ticks": 384, "attached_ticks": on.attached_ticks, "reel_ticks": on.reel_ticks, "slack_ticks": on.slack_ticks, "scope": "real runner input tape in empty physics world; not a route or full-host recording acceptance"}
	FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE).store_string(JSON.stringify(summary, "\t"))
	print(JSON.stringify(summary))
	for frame: int in 4:
		await process_frame
	quit(0 if failures.is_empty() else 1)

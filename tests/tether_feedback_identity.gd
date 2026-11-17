extends SceneTree
## deterministic input tape on the real motor; compare serialized motion, not tolerances.
const HOST := preload("res://scripts/game.gd")
const RUNNER := preload("res://scripts/movement/grapple_player.gd")
const RECORDER := preload("res://scripts/recordings/recorder.gd")
const READER := preload("res://scripts/recordings/reader.gd")
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
	var recorder := RECORDER.new()
	var opened := recorder.begin_run({"fixture": "tether-feedback-identity", "identity": {"tether": player.tether_identity()}}, output.path_join("on" if on else "off"))
	if not bool(opened.get("ok", false)):
		failures.append("fixture recorder did not open")
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
		var motion := player.get_motion_state()
		recorder.capture({"tick": tick, "dt": 1.0 / 128, "physics_hz": 128,
			"elapsed": float(tick) / 128, "started": true, "finished": false, "clean": false,
			"checkpoint": 0, "respawns": 0, "p": player.global_position, "reference_p": player.global_position,
			"v": player.velocity, "actual_v": motion.actual_velocity, "yaw": player.yaw, "pitch": player.pitch,
			"grounded": bool(player.state.grounded), "ducked": player.ducked,
			"held": {"move_right": Input.is_action_pressed("move_right"), "mouse_left": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "mouse_right": Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)},
			"input_events": [], "motion": motion})
		rows.append([player.global_transform, player.velocity, player.get_motion_state(), player.r21_rules_sha256()])
	button(MOUSE_BUTTON_LEFT, false)
	button(MOUSE_BUTTON_RIGHT, false)
	Input.action_release("move_right")
	var sealed := recorder.finish({"fixture": true, "finished": false, "clean": false})
	if not bool(sealed.get("ok", false)):
		failures.append("fixture recorder did not seal")
	var decoded := READER.read(recorder.final_path)
	if str(decoded.get("status", "")) != "complete":
		failures.append("fixture recording could not be decoded")
	var recorded_bytes := var_to_bytes(decoded.get("columns", {}))
	var bytes := var_to_bytes(rows)
	world.free()
	return {"recorded_bytes": recorded_bytes, "bytes": bytes, "attached_ticks": attached_ticks, "reel_ticks": reel_ticks, "slack_ticks": slack_ticks, "identity": identity}

func portable_host_checks() -> void:
	RenderingServer.render_loop_enabled = false
	var game := HOST.new()
	game.map_id = "tether-yard"
	game.motor = "server128"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output.path_join("absent-profile.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	var fixture: Dictionary = game.maps.catalog["tether-yard"].duplicate(true)
	fixture["grapple"] = true
	fixture["tether_model"] = "elastic-arc"
	# these ephemeral catalog clones test capability dispatch, not new production maps.
	for id: String in ["feedback-flow-fixture", "feedback-height-fixture", "feedback-hop-fixture"]:
		game.maps.catalog[id] = fixture.duplicate(true)
		game.maps.order.append(id)
		var previous: Node3D = game.tether_feedback
		game.select_map(id)
		game.set_physics_process(false)
		game.player.set_physics_process(false)
		game.set_paused(false)
		if is_instance_valid(previous):
			failures.append("old observer survived map replacement: " + id)
		if not game.map_has_capability("grapple") or not is_instance_valid(game.tether_feedback):
			failures.append("declared grapple map lacks observer: " + id)
			continue
		if game.tether_feedback.runner != game.player:
			failures.append("observer kept stale runner: " + id)
		var motion := var_to_bytes(game.player.get_motion_state())
		var identity: Dictionary = game.motion_identity()
		var attempts: int = game.attempts
		for key: String in FX.KEYS:
			game.change_setting(key, true)
		if var_to_bytes(game.player.get_motion_state()) != motion or game.motion_identity() != identity or game.attempts != attempts:
			failures.append("portable toggle changed motor/attempt/identity: " + id)
		var camera: Camera3D = game.player.camera
		var fov := camera.fov
		game.tether_feedback.observe(0.1)
		if not game.tether_feedback._lens.current or camera.fov != fov:
			failures.append("portable lens changed source or failed takeover: " + id)
		game.set_paused(true)
		if game.tether_feedback._sound.voices.wind.playing or not camera.current:
			failures.append("portable pause failed audio/camera reset: " + id)
		game.set_paused(false)
		print("portable feedback checked: ", id)
	game.select_map("breakwater")
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	if is_instance_valid(game.tether_feedback) or not game.player.camera.current:
		failures.append("original-map handoff left observer or wrong camera")
	game.set_paused(false)
	game.free()

func run() -> void:
	root.size = Vector2i(1280, 720)
	for action: String in ["jump", "move_forward", "move_back", "move_left", "move_right", "crouch", "look_left", "look_right", "look_up", "look_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var off := tape(false)
	var on := tape(true)
	portable_host_checks()
	if off.bytes != on.bytes:
		failures.append("on/off serialized motion differs")
	if off.recorded_bytes != on.recorded_bytes:
		failures.append("production recording motion columns differ")
	if on.attached_ticks == 0 or on.reel_ticks == 0:
		failures.append("tape did not exercise attach and reel")
	DirAccess.make_dir_recursive_absolute(output)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(on.bytes)
	var recorded_hash := HashingContext.new()
	recorded_hash.start(HashingContext.HASH_SHA256)
	recorded_hash.update(on.recorded_bytes)
	var summary := {"ok": failures.is_empty(), "failures": failures, "motion_sha256": hash.finish().hex_encode(), "recorded_motion_sha256": recorded_hash.finish().hex_encode(), "recorded_bytes_compared": on.recorded_bytes.size(), "bytes_compared": on.bytes.size(), "ticks": 384, "attached_ticks": on.attached_ticks, "reel_ticks": on.reel_ticks, "slack_ticks": on.slack_ticks, "scope": "empty-world motor tape and production recording columns; portable full-host capability fixtures; not an earned route"}
	FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE).store_string(JSON.stringify(summary, "\t"))
	print(JSON.stringify(summary))
	for frame: int in 4:
		await process_frame
	quit(0 if failures.is_empty() else 1)

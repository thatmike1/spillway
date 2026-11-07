extends SceneTree
## p / r13 controller lab: the real spillway main, course, hud and audio with a chosen motor.
## godot --path . --script res://scripts/momentum_flow_lab.gd -- [--motor=flow|r12] [--demo]
## lab runs never write records or settings. --demo plays the probe's e5 key/mouse line down
## the dry chute for frame capture, then quits; it sends input events and reads position only.

class LabHUD:
	extends "res://scripts/spillway_hud.gd"

	func attach(main: Node) -> void:
		super(main)
		var selected := str(main.get("motor"))
		subtitle.text = "%s / R13 MOVEMENT EXPERIMENT" % selected.to_upper()
		var instructions := "WASD run. Space jump / hold to hop. Ctrl / C slide.\nW + mouse steers in air. S brakes. A/D into a turn carves.\nR new run    F segment practice    Esc settings"
		if selected == "flow":
			status.text = instructions
		for node: Node in pause_panel.find_children("*", "Label", true, false):
			var label := node as Label
			if label.text == main.BUILD_ID:
				label.text = "spillway-r13-lab / %s / records disabled" % selected
			elif selected == "flow" and label.text.begins_with("Run first, then hold Space"):
				label.text = instructions

class LabMain:
	extends "res://scripts/spillway_main.gd"
	var motor: String = "flow"

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().auto_accept_quit = false
		bind_inputs()
		# both lab motors use the same default settings and no historical records.
		_persist = false
		level = preload("res://scripts/spillway_level.gd").new()
		level.name = "Spillway"
		add_child(level)
		level.call("build")
		player = (preload("res://scripts/momentum_flow_player.gd") if motor == "flow" else preload("res://scripts/spillway_player.gd")).new()
		player.name = "Runner"
		add_child(player)
		player.connect("landed", func(_impact: float) -> void:
			if player.in_water and level.has_method("splash_at"):
				level.call("splash_at", player.global_position))
		hud = LabHUD.new()
		add_child(hud)
		hud.call("attach", self)
		audio = preload("res://scripts/spillway_audio.gd").new()
		add_child(audio)
		audio.call("attach", player, level)
		_apply_settings()
		restart_run()
		if OS.get_cmdline_user_args().has("--no-hud"):
			hud.hide()
		DisplayServer.window_set_title("Spillway R13 movement lab / " + motor.to_upper())
		print("lab: motor=%s; build=spillway-r13-lab; records=disabled; renderer=%s" % [motor, RenderingServer.get_current_rendering_method()])

var game: LabMain

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	game = LabMain.new()
	game.name = "FlowLab"
	game.motor = "r12" if args.has("--motor=r12") else "flow"
	root.add_child(game)
	if args.has("--demo"):
		_demo.call_deferred()

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _mouse(radians: float) -> void:
	# positive radians turn left, as the motor's yaw does.
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-radians / float(game.player.get("mouse_sensitivity")), 0.0)
	event.screen_relative = event.relative
	Input.parse_input_event(event)

func _aim(target: Vector3, rate: float) -> float:
	# aim the view at a point at a limited mouse rate, reading position only, like the probe.
	var to := target - game.player.global_position
	return clampf(angle_difference(float(game.player.get("yaw")), atan2(-to.x, -to.z)), -rate / 120.0, rate / 120.0)

func _demo() -> void:
	var player: CharacterBody3D = game.player
	for i: int in 30:
		await physics_frame
	# the probe's e5 line: aim at the dry chute mouth, slide it, jump at its launch.
	_key(KEY_W, true)
	for i: int in 240:
		if player.global_position.z < 0.5:
			break
		_mouse(_aim(Vector3(-3.5, 12, -1.0), 3.0))
		await physics_frame
	_key(KEY_CTRL, true)
	for i: int in 600:
		if player.global_position.z < -24.3 or player.global_position.y < 3.0:
			break
		_mouse(clampf(angle_difference(float(player.get("yaw")), 0.0), -0.025, 0.025))
		await physics_frame
	print("demo: launch at %s, %.2f m/s" % [player.global_position, player.call("get_speed")])
	_key(KEY_CTRL, false)
	_key(KEY_SPACE, true)
	for i: int in 8:
		await physics_frame
	_key(KEY_SPACE, false)
	for i: int in 240:
		_mouse(_aim(Vector3(-3.0, 4, -46.0), 2.0))
		await physics_frame
	print("demo: end at %s, %.2f m/s" % [player.global_position, player.call("get_speed")])
	_key(KEY_W, false)
	for i: int in 30:
		await physics_frame
	game.request_quit()

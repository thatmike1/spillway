extends "res://tests/r15_breakwater_driver.gd"
## inherited input controller and route. only the presentation host differs.
const LOOK_HOST := preload("res://scripts/look_main.gd")
var toggle_ticks: Array[int] = []
func _start() -> void:
	max_ticks = int(opts.get("max-ticks", "20000"))
	amp = deg_to_rad(float(opts.get("amp", "30")))
	game = LOOK_HOST.new()
	game.name = "R15"
	game.set("motor", str(opts.get("preset", "server128")))
	game.set("map_id", "breakwater")
	game.set("set_window_title", false)
	root.add_child(game)
	# the base controller reads the game through `lab`; r15_main preserves the same run fields.
	lab = game
	level = game.get("level")
	player = game.get("player")
	source = "settings" in player and (player.get("settings") as Dictionary).has("sv_airaccelerate")
	hz = Engine.physics_ticks_per_second
	warmup = int(opts.get("warmup", str(EXECUTOR_ARM_STEP.get(hz, 32))))
	radians_per_count = float(player.get("tape_radians_per_count"))
	turn_cap = deg_to_rad(float(opts.get("turn-cap", "600"))) / hz
	if opts.has("tape"):
		_load_tape(str(opts.tape))
	else:
		var route := str(opts.get("route", "ordinary"))
		assert(bw_routes.has(route), "breakwater driver: unknown route " + route)
		nodes = []
		for node: Dictionary in bw_routes[route]:
			nodes.append(node.duplicate())
	var hook := Hook.new()
	hook.driver = self
	hook.process_physics_priority = 1000
	hook.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hook)
	print("breakwater driver: %s route=%s preset=%s hz=%d geometry=%s turn_cap=%.0f deg/s" % ["OPEN LOOP tape" if not replay.is_empty() else "CLOSED LOOP",
		opts.get("route", replay.get("name", "")), game.get("preset_id"), hz, str(level.call("geometry_hash")).left(12), rad_to_deg(turn_cap * hz)])


func late_step() -> void:
	super.late_step()
	if armed and opts.get("toggles", "off") == "on" and (step-arm_step) % 256 == 128:
		game.set_look(not game.look_enabled)
		toggle_ticks.append(step-arm_step)

func _end(reason: String, tick: int) -> void:
	_write("look.json", {"host":"res://scripts/look_main.gd","look":game.look_enabled,"toggle_ticks":toggle_ticks,"method":"inherited R15 input-only route controller after normal spawn; closed loop unless --tape supplied; not a human playtest"})
	super._end(reason,tick)

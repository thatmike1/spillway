extends SceneTree
## p / the runway's section seams under real key input, not a route proof: for each seam and
## heading, the runner is set down on the runway 6 m (in x) before the seam (a setup write, then
## nothing but keys), holds w (walk) or w and space (hop, once at run speed; on a press-edge
## preset space is pressed on each ground tick and let go in the air) for 2 s, and every tick is checked: a
## grounded hull more than 3 cm below the face under it (sink), any tick below the deck top
## (fell into it), and the horizontal speed either side of the seam. writes seam_probe.json.
## godot --headless --audio-driver Dummy --fixed-fps HZ --path . --script res://tests/r14_practice_seam_probe.gd -- --preset=csgo_server --out=DIR

const LAB := preload("res://scripts/r14_practice_lab.gd")
const LEVEL := preload("res://scripts/r14_practice_level.gd")
const U := 0.0254
## headings in degrees: 0 is +x, 90 is -z, 180 is -x (forward on the runway).
const HEADINGS := [180.0, 0.0, 135.0, 225.0, 160.0, 200.0]
const MODES := ["walk", "hop"]
const Z_LINES := [-92.0, -98.0, -104.0]
## metres in x before the seam the runner is set down: a run-up, then a hop or two.
const LEAD := 6.0

var preset := "csgo_server"
var out := ""
var lab: Node3D
var player: CharacterBody3D
var cases: Array = []
var case_index := -1
var tick := 0
var current := {}
var held := {}
var results: Array = []

class Hook:
	extends Node
	var cb: Callable
	func _physics_process(_d: float) -> void:
		cb.call()

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="):
			preset = arg.trim_prefix("--preset=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	assert(out.is_absolute_path(), "seam probe: pass --out=<absolute directory>")
	for k: int in range(1, LEVEL.RUNWAY_SECTIONS):
		var seam := lerpf(LEVEL.RUNWAY_START, LEVEL.RUNWAY_END, float(k) / LEVEL.RUNWAY_SECTIONS)
		for heading: float in HEADINGS:
			for mode: String in MODES:
				# a 45 degree heading crosses at the middle only, so it stays off the walls.
				for z: float in (Z_LINES if absf(sin(deg_to_rad(heading))) < 0.5 else [-98.0]):
					cases.append({"seam_x": seam, "heading": heading, "mode": mode, "z": z})
	lab = LAB.Lab.new()
	lab.set("set_window_title", false)
	lab.set("motor", preset)
	root.add_child(lab)
	var hook := Hook.new()
	hook.process_physics_priority = 1000
	hook.cb = _step
	root.add_child(hook)

func _step() -> void:
	if player == null:
		player = lab.get("player")
		return
	if case_index < 0 or tick >= 2 * Engine.physics_ticks_per_second:
		if case_index >= 0:
			_finish_case()
		case_index += 1
		if case_index >= cases.size():
			_write()
			return
		_start_case(cases[case_index])
		return
	tick += 1
	var p := player.global_position
	var grounded: bool = player.call("is_grounded")
	var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p + Vector3.DOWN * 0.6))
	var piece := str((hit.collider as Node).name) if not hit.is_empty() else ""
	if grounded and not hit.is_empty():
		current.max_sink_m = maxf(float(current.max_sink_m), float(hit.position.y) - p.y)
	current.min_y = minf(float(current.min_y), p.y)
	var speed := Vector2(player.velocity.x, player.velocity.z).length() / U
	var side := signf(p.x - float(current.seam_x)) * signf(float(current.start_side))
	if side > 0.0:
		current.speed_before = speed
	elif not current.has("speed_after"):
		current.speed_after = speed
		current.crossed_tick = tick
		current.crossed_grounded = grounded
	if grounded and piece.begins_with("s3_runway_") and not (current.pieces as Array).has(piece):
		(current.pieces as Array).append(piece)
	if current.mode == "hop":
		var vanilla := not bool((player.get("settings") as Dictionary).sv_autobunnyhopping)
		# the first jump waits for run speed, as a player's would; later ones go on landing.
		current.running = bool(current.running) or speed >= 240.0
		_key(KEY_SPACE, bool(current.running) and grounded and not (vanilla and held.has(KEY_SPACE) and int(current.space_ticks) > 0))
		current.space_ticks = int(current.space_ticks) + 1 if held.has(KEY_SPACE) else 0

func _start_case(c: Dictionary) -> void:
	for key: int in held.keys():
		_key(key, false)
	var a := deg_to_rad(float(c.heading))
	var dir := Vector3(cos(a), 0.0, -sin(a))
	var start := Vector3(float(c.seam_x), 0.0, float(c.z)) - dir * (LEAD / maxf(absf(dir.x), 0.01))
	player.call("reset_to", Transform3D(Basis.IDENTITY, start + Vector3.UP * 0.05))
	# heading h faces dir: the source view looks along -z at yaw 0, so yaw = h - 90 degrees.
	player.set("yaw", a - PI * 0.5)
	current = c.duplicate()
	current.merge({"start": [start.x, start.z], "start_side": signf(start.x - float(c.seam_x)), "max_sink_m": -1.0, "min_y": 1.0, "pieces": [], "space_ticks": 0, "running": false})
	tick = 0
	_key(KEY_W, true)

func _finish_case() -> void:
	var p := player.global_position
	current.end = [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]
	current.max_sink_m = snappedf(float(current.max_sink_m), 0.0001)
	current.min_y = snappedf(float(current.min_y), 0.0001)
	for key: String in ["speed_before", "speed_after"]:
		if current.has(key):
			current[key] = snappedf(float(current[key]), 0.01)
	current.crossed = current.has("speed_after")
	current.erase("space_ticks")
	current.erase("running")
	current.ok = bool(current.crossed) and float(current.max_sink_m) <= 0.03 and float(current.min_y) > -0.03 and (current.pieces as Array).size() >= 2
	results.append(current)

func _key(code: int, pressed: bool) -> void:
	if pressed == held.has(code):
		return
	var event := InputEventKey.new()
	event.keycode = code as Key
	event.physical_keycode = code as Key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed:
		held[code] = true
	else:
		held.erase(code)

func _write() -> void:
	var bad := results.filter(func(r: Dictionary) -> bool: return not bool(r.ok))
	DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open(out.path_join("seam_probe_%s.json" % preset), FileAccess.WRITE)
	f.store_string(JSON.stringify({"preset": preset, "physics_hz": Engine.physics_ticks_per_second, "geometry_hash": lab.get("level").call("geometry_hash"),
		"player_sha256": FileAccess.get_sha256("res://scripts/r14_source_player.gd"), "cases": results.size(), "failed": bad.size(), "results": results}, "\t"))
	f.close()
	var worst := 0.0
	for r: Dictionary in results:
		worst = maxf(worst, float(r.max_sink_m))
	print("seam probe %s: %d cases, %d failed, worst sink %.4f m" % [preset, results.size(), bad.size(), worst])
	for r: Dictionary in bad:
		print("  failed: ", r)
	quit()

extends SceneTree
## focused adversarial review of aba901ab. geometry and optional velocity seeds are fixtures.
## after the initial reset/seed, only real input events reach the motor; every sample is
## taken after physics via process_frame at --fixed-fps 120. no trajectory writes occur.

const MAIN := preload("res://scripts/spillway_main.gd")
const MOTORS := {"flow": preload("res://scripts/momentum_flow_player.gd"), "r12": preload("res://scripts/spillway_player.gd")}
const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "jump": KEY_SPACE, "crouch": KEY_CTRL}
const DT := 1.0 / 120.0
var out_dir := "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/controller-review-sol/run1"
var world: Node3D
var player: CharacterBody3D
var held: Dictionary = {}
var trace: FileAccess
var previous: Vector3
var tick := 0
var rows: Array[Dictionary] = []
var summary: Array[Dictionary] = []
var before_tick: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	_run.call_deferred()

func _run() -> void:
	MAIN.bind_inputs()
	DirAccess.make_dir_recursive_absolute(out_dir)
	for cadence: int in [120, 60, 30]:
		await episode({"name": "earned_cadence_%d" % cadence, "kind": "earned_air", "cadence": cadence, "gesture": "a"})
	for cadence: int in [60, 30]:
		for phase: int in 120 / cadence:
			await episode({"name": "earned_cadence_%d_phase_%d" % [cadence, phase], "kind": "earned_air", "cadence": cadence, "gesture": "a", "phase": phase})
	for gesture: String in ["w", "d", "offbeat", "a_static", "d_static", "none", "wa", "flick"]:
		await episode({"name": "earned_air_" + gesture, "kind": "earned_air", "cadence": 120, "gesture": gesture})
	for motor: String in MOTORS:
		for pz: float in [-9.15, -9.30, -9.45]:
			await episode({"name": "%s_wall_seed_%.2f" % [motor, pz], "motor": motor, "kind": "wall", "position": Vector3(0, 0.2, pz), "seed": Vector3(0, -4, -12), "ticks": 60})
		await episode({"name": motor + "_corner_seed", "motor": motor, "kind": "corner", "position": Vector3(0.6, 0.2, -9.3), "seed": Vector3(8, -4, -12), "ticks": 60})
		for wall_z: float in [-2.2, -2.5, -2.8, -2.45]:
			await episode({"name": "%s_wall_earned_%.2f" % [motor, wall_z], "motor": motor, "kind": "earned_wall", "wall_z": wall_z, "ticks": 240})
		for wall_z: float in [-3.3, -3.6, -3.9, -4.2]:
			await episode({"name": "%s_slope_wall_earned_%.2f" % [motor, wall_z], "motor": motor, "kind": "earned_slope_wall", "wall_z": wall_z, "ticks": 300})
		for offset: float in [0.0, 0.1, 0.2, 0.3]:
			await episode({"name": "%s_slope_wall_seed_%.1f" % [motor, offset], "motor": motor, "kind": "slope_wall", "position": Vector3(0, -2.5, -9.0 - offset), "seed": Vector3(0, -6, -12), "ticks": 60})
		for kind: String in ["crest", "seam", "stair", "slope_change"]:
			await episode({"name": motor + "_" + kind + "_seed", "motor": motor, "kind": kind, "position": Vector3(0, 0.02, 4), "seed": Vector3(0, 0, -16), "ticks": 200})
			await episode({"name": motor + "_" + kind + "_fast_seed", "motor": motor, "kind": kind, "position": Vector3(0, 0.02, 4), "seed": Vector3(0, 0, -24), "ticks": 200})
		await episode({"name": motor + "_crest_earned", "motor": motor, "kind": "earned_crest", "position": Vector3(0, 0.02, 5), "ticks": 520})
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "physics_hz": Engine.physics_ticks_per_second, "physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine"), "accumulated_input": Input.use_accumulated_input, "cases": summary}, "  "))
	print("review probe finished: " + str(summary.size()) + " episodes; " + out_dir)
	quit()

func box(label: String, center: Vector3, size: Vector3, tilt: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = label
	var shape := CollisionShape3D.new()
	var resource := BoxShape3D.new()
	resource.size = size
	shape.shape = resource
	body.add_child(shape)
	body.transform = Transform3D(Basis(Vector3.RIGHT, tilt), center)
	world.add_child(body)

func ramp(label: String, a: Vector3, b: Vector3) -> void:
	var along := b - a
	var tilt := atan2(along.y, -along.z)
	var normal := Basis(Vector3.RIGHT, tilt) * Vector3.UP
	box(label, (a + b) * 0.5 - normal * 0.5, Vector3(20, 1, along.length()), tilt)

func geometry(cfg: Dictionary) -> void:
	var kind: String = cfg["kind"]
	if kind in ["crest", "seam", "stair", "slope_change", "earned_crest"]:
		box("approach", Vector3(0, -0.5, 6), Vector3(20, 1, 12))
		if kind == "stair":
			for i: int in 20:
				box("stair_%d" % i, Vector3(0, 0.05 * (i + 1) - 0.5, -0.3 * (i + 0.5)), Vector3(20, 1, 0.3))
			box("runout", Vector3(0, 0.5, -56), Vector3(20, 1, 100))
		elif kind == "seam":
			for i: int in 8:
				ramp("seam_%d" % i, Vector3(0, i * 0.5, -i * 2.0), Vector3(0, (i + 1) * 0.5, -(i + 1) * 2.0))
			ramp("seam_runout", Vector3(0, 4, -16), Vector3(0, 14, -56))
		elif kind == "slope_change":
			ramp("rise20", Vector3.ZERO, Vector3(0, 3, -8))
			ramp("rise5", Vector3(0, 3, -8), Vector3(0, 8, -58))
		else:
			if kind == "earned_crest":
				# first descend to earn speed; the crest has continuous, walkable support.
				ramp("downhill", Vector3.ZERO, Vector3(0, -12, -40))
				ramp("climb", Vector3(0, -12, -40), Vector3(0, -9, -48))
				box("crest_deck", Vector3(0, -9.5, -98), Vector3(20, 1, 100))
			else:
				ramp("climb", Vector3.ZERO, Vector3(0, 3, -8))
				box("crest_deck", Vector3(0, 2.5, -58), Vector3(20, 1, 100))
	elif kind in ["slope_wall", "earned_slope_wall"]:
		ramp("downhill", Vector3.ZERO, Vector3(0, -6, -20))
		var front: float = cfg.get("wall_z", -10.0)
		box("wall", Vector3(0, 1, front - 0.5), Vector3(100, 8, 1))
		if kind == "earned_slope_wall":
			box("approach", Vector3(0, -0.5, 6), Vector3(20, 1, 12))
	else:
		box("flat", Vector3(0, -0.5, -30), Vector3(100, 1, 180))
		if kind in ["wall", "corner", "earned_wall"]:
			var front: float = cfg.get("wall_z", -10.0)
			box("wall", Vector3(0, 4, front - 0.5), Vector3(100, 8, 1))
		if kind == "corner":
			box("sidewall", Vector3(1.5, 4, -20), Vector3(1, 8, 100))

func hold(names: Array) -> void:
	for key: String in KEYS:
		var pressed := names.has(key)
		if pressed == held.has(key):
			continue
		var event := InputEventKey.new()
		event.keycode = KEYS[key]
		event.physical_keycode = KEYS[key]
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		if pressed:
			held[key] = true
		else:
			held.erase(key)

func mouse(turn: float) -> void:
	if is_zero_approx(turn):
		return
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-turn / float(player.get("mouse_sensitivity")), 0)
	event.screen_relative = event.relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func episode(cfg: Dictionary) -> void:
	hold([])
	world = Node3D.new()
	root.add_child(world)
	geometry(cfg)
	await physics_frame
	await process_frame
	var motor: String = cfg.get("motor", "flow")
	player = MOTORS[motor].new()
	world.add_child(player)
	player.call("reset_to", Transform3D(Basis.IDENTITY, cfg.get("position", Vector3(0, 0.02, 10))))
	# fixture setup only: this seed precedes the first physics step, never input-earned.
	if cfg.has("seed"):
		player.velocity = cfg["seed"]
	previous = player.global_position
	rows.clear()
	trace = FileAccess.open(out_dir.path_join(cfg["name"] + ".jsonl"), FileAccess.WRITE)
	var count: int = cfg.get("ticks", 198)
	var delivered_turn := 0.0
	for i: int in count:
		tick = i
		var keys: Array = []
		var turn := 0.0
		var kind: String = cfg["kind"]
		if kind in ["earned_air", "earned_wall", "earned_slope_wall"]:
			keys = ["w"]
			if i >= 96 and i < 102:
				keys.append("jump")
			if kind == "earned_air" and i >= 102 and i < 162:
				var g: String = cfg["gesture"]
				keys = ["a"]
				if g in ["w", "d"]:
					keys = [g]
				elif g == "wa":
					keys = ["w", "a"]
				elif g == "offbeat":
					keys = ["a" if (i - 102) / 15 % 2 == 0 else "d"]
				elif g == "a_static":
					keys = ["a"]
				elif g == "d_static":
					keys = ["d"]
				elif g == "none":
					keys = []
				if g not in ["a_static", "d_static", "none"]:
					var period: int = 120 / int(cfg["cadence"])
					if cfg.has("phase"):
						# causal samples plus a final remainder; keep the same total view turn.
						if (i - 102) % period == int(cfg["phase"]) or i == 161:
							var target := 1.8 * DT * float(i - 101)
							turn = target - delivered_turn
							delivered_turn = target
					elif (i - 102) % period == 0:
						turn = 1.8 * DT * period
					if g == "flick":
						turn = 0.9 if i == 102 else 0.0
			if cfg.has("phase") and i >= 162 and i < 166:
				# let the final sampled mouse update settle while the same strafe is held.
				keys = ["a"]
		elif kind == "earned_crest":
			keys = ["w", "crouch"] if i > 96 else ["w"]
		elif kind in ["crest", "seam", "stair", "slope_change"]:
			keys = ["w"]
		before_tick = {"p": vec(player.global_position), "v": vec(player.velocity), "normal": vec(player.get("_ground_normal"))}
		if motor == "flow":
			before_tick["saved_climb"] = player.get("_flow_last_vs")
			before_tick["computed_climb"] = player.call("_surface_climb", player.get("_ground_normal"), Vector3(player.velocity.x, 0, player.velocity.z))
		hold(keys)
		mouse(turn)
		await physics_frame
		await process_frame
		record(turn)
	hold([])
	trace.close()
	var entry: Dictionary = cfg.duplicate()
	for key: String in ["position", "seed"]:
		if entry.has(key):
			entry[key] = vec(entry[key])
	entry["final"] = rows[-1]
	entry["gesture_start"] = rows[101] if rows.size() > 162 else {}
	entry["gesture_end"] = rows[161] if rows.size() > 162 else {}
	summary.append(entry)
	print("episode " + cfg["name"] + " final=" + JSON.stringify(rows[-1]))
	world.queue_free()
	await physics_frame
	await process_frame

func vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func record(turn: float) -> void:
	var p := player.global_position
	var disp := (p - previous) / DT
	var contacts: Array = []
	for i: int in player.get_slide_collision_count():
		var c := player.get_slide_collision(i)
		for j: int in c.get_collision_count():
			var n := c.get_normal(j)
			contacts.append({"body": str(c.get_collider(j).name), "normal": vec(n), "face": vec(player.call("_face_normal", c.get_position(j), n)), "v_dot_normal": player.velocity.dot(n)})
	var entry := {"before": before_tick, "tick": tick, "dt": DT, "physics_frame": Engine.get_physics_frames(), "keys": held.keys(), "mouse_rad": turn,
		"yaw": player.get("yaw"), "p": vec(p), "v": vec(player.velocity), "real_v": vec(player.get_real_velocity()),
		"disp_v": vec(disp), "speed": player.call("get_speed"), "disp_speed": Vector2(disp.x, disp.z).length(),
		"grounded": player.call("is_grounded"), "mode": player.get("mode"), "contacts": contacts,
		"carve": player.get("carve_gain_total") if player.get_script() == MOTORS["flow"] else 0,
		"launches": player.get("launch_count") if player.get_script() == MOTORS["flow"] else 0,
		"jumps": player.get("jump_count"), "lands": player.get("land_count")}
	trace.store_line(JSON.stringify(entry))
	rows.append(entry)
	previous = p

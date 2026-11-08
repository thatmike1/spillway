extends SceneTree
## p / r14 source lab: the source runner alone on a labelled fixture block, for play and for
## open-loop input proofs. records and settings are never written.
## godot --path . --script res://scripts/r14_source_lab.gd -- [--preset=csgo_vanilla|csgo_server]
##   [--station=runway|slopes|corner|seams|lips|gap] [--demo=NAME] [--trace=PATH.jsonl.gz]
##   [--no-overlay]
## keys: wasd, space (scroll wheel too in this lab), mouse look, f1 vanilla, f2 server (both keep
## position, velocity and view), r respawn at the station, esc frees the mouse.
## --demo=planned_N plays the pure module's open-loop plan of N strafed hops for the profile.
## --demo plays a fixed key and relative-mouse tape through ordinary input events, then quits.
## it never reads the runner to choose input and never writes pose or velocity after setup.

const MAIN := preload("res://scripts/spillway_main.gd")
const PLAYER := preload("res://scripts/r14_source_player.gd")
const MOTION := preload("res://scripts/r14_source_motion.gd")
const U: float = MOTION.U

## the fixture block, authored in source units. every floor top is y = 0 u unless named.
class Fixture:
	extends Node3D

	const GRID := "shader_type spatial;\nuniform vec3 base : source_color = vec3(0.6);\nuniform vec3 line : source_color = vec3(0.25);\nvarying vec3 wpos;\nvarying vec3 wnorm;\nvoid vertex() {\n\twpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\twnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);\n}\nfloat grid(vec2 uv, float width) {\n\tvec2 g = abs(fract(uv - 0.5) - 0.5) / max(fwidth(uv), vec2(1e-4));\n\treturn 1.0 - clamp(min(g.x, g.y) / width, 0.0, 1.0);\n}\nvoid fragment() {\n\tvec3 n = abs(wnorm);\n\tvec2 uv = (n.y > 0.5 ? wpos.xz : (n.x > n.z ? wpos.zy : wpos.xy)) / 1.6256;\n\tALBEDO = mix(base, line, max(grid(uv, 1.0) * 0.45, grid(uv * 0.25, 1.6) * 0.85));\n\tROUGHNESS = 0.92;\n}\n"

	## station spawns in u, facing -z unless a yaw is given. a 64 u grid is drawn on every face.
	const STATIONS := {
		"runway": [Vector3(0, 0.5, 2048), 0.0],
		"slopes": [Vector3(12000, 0.5, 640), 0.0],
		"corner": [Vector3(16000, 0.5, 512), 0.0],
		"seams": [Vector3(20000, 0.5, 768), 0.0],
		"lips": [Vector3(24000, 0.5, 512), 0.0],
		"gap": [Vector3(28000, 0.5, 512), 0.0],
	}
	var _shader := Shader.new()
	var spawn: Transform3D

	func build(light := true) -> void:
		_shader.code = GRID
		if light:
			_environment()
		# runway: one 16384 u square slab, room for long strafe arcs.
		_box("runway", Vector3(0, -32, 0), Vector3(16384, 64, 16384), Color("8d939a"))
		# slopes: approach deck, then four lanes rising toward -z at 20, 30, 45 and 50 degrees.
		_box("slopes_deck", Vector3(12000, -32, 256), Vector3(1280, 64, 1024), Color("8d939a"))
		var lane := -480.0
		for degrees: float in [20.0, 30.0, 45.0, 50.0]:
			var run := 512.0
			_ramp("slope_%d" % int(degrees), Vector3(12000 + lane, 0, -256), Vector3(12000 + lane, run * tan(deg_to_rad(degrees)), -256 - run), 256.0, Color("a4927a") if degrees < 46.0 else Color("9c6f5c"))
			lane += 320.0
		# corner: a deck with an inner corner of two 128 u walls and a free-standing pillar.
		_box("corner_deck", Vector3(16000, -32, 0), Vector3(2048, 64, 2048), Color("8d939a"))
		_box("corner_wall_x", Vector3(16000, 64, -512 - 16), Vector3(1024, 128, 32), Color("9c6f5c"))
		_box("corner_wall_z", Vector3(16000 + 512 + 16, 64, -256), Vector3(32, 128, 544), Color("9c6f5c"))
		_box("corner_pillar", Vector3(15600, 64, -200), Vector3(64, 128, 64), Color("9c6f5c"))
		# seams: sixteen separate 128 u slabs in a row, coplanar, after an approach slab.
		_box("seams_approach", Vector3(20000, -32, 512), Vector3(512, 64, 1024), Color("8d939a"))
		for i: int in 16:
			_box("seam_%02d" % i, Vector3(20000, -32, -64 - i * 128), Vector3(512, 64, 128), Color("8d939a") if i % 2 == 0 else Color("858b91"))
		# lips: five lanes, each a raised block of 8, 16, 18, 19 or 24 u from z = -256.
		_box("lips_deck", Vector3(24000, -32, 0), Vector3(1408, 64, 2048), Color("8d939a"))
		var x := 23424.0
		for height: float in [8.0, 16.0, 18.0, 19.0, 24.0]:
			_box("lip_%d" % int(height), Vector3(x, height * 0.5, -256 - 384), Vector3(192, height, 768), Color("a0a6ab"))
			x += 288.0
		# gap: take-off deck ends at z = -1024, a 160 u gap a 250 u/s running jump just clears,
		# the far deck, a catch floor 256 u down.
		_box("gap_near", Vector3(28000, -32, -256), Vector3(512, 64, 1536), Color("8d939a"))
		_box("gap_far", Vector3(28000, -32, -1184 - 768), Vector3(512, 64, 1536), Color("7d9a86"))
		_box("gap_catch", Vector3(28000, -288, -1100), Vector3(1024, 64, 3072), Color("6f757b"))
		var lips := ["8", "16", "18", "19", "24"]
		for i: int in lips.size():
			_sign(lips[i] + " u", Vector3(23424 + i * 288, 48, -200), 0.004)
		_sign("20°", Vector3(11520, 40, -200), 0.004)
		_sign("30°", Vector3(11840, 40, -200), 0.004)
		_sign("45°", Vector3(12160, 40, -200), 0.004)
		_sign("50° (not walkable)", Vector3(12480, 40, -200), 0.004)
		_sign("seams: 16 bodies", Vector3(20000, 64, 0), 0.005)
		_sign("160 u gap", Vector3(28000, 80, -1120), 0.005)
		_sign("R14 SOURCE LAB · fixture, not a course", Vector3(0, 256, 0), 0.012)
		spawn = pose("runway")

	static func pose(station: String) -> Transform3D:
		var entry: Array = STATIONS[station]
		return Transform3D(Basis(Vector3.UP, float(entry[1])), (entry[0] as Vector3) * U)

	func _material(color: Color) -> ShaderMaterial:
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("base", color)
		material.set_shader_parameter("line", color.darkened(0.45))
		return material

	## a box from a centre and size in u, optionally tilted about x.
	func _box(label: String, center_u: Vector3, size_u: Vector3, color: Color, tilt := 0.0) -> StaticBody3D:
		var body := StaticBody3D.new()
		body.name = label
		body.transform = Transform3D(Basis(Vector3.RIGHT, tilt), center_u * U)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size_u * U
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = size_u * U
		mesh.mesh = cube
		mesh.material_override = _material(color)
		body.add_child(mesh)
		add_child(body)
		return body

	## a ramp whose top face runs from a to b (in u) along -z, 64 u thick.
	func _ramp(label: String, a: Vector3, b: Vector3, width: float, color: Color) -> void:
		var along := b - a
		var tilt := atan2(along.y, -along.z)
		var normal := Basis(Vector3.RIGHT, tilt) * Vector3.UP
		_box(label, (a + b) * 0.5 - normal * 32.0, Vector3(width, 64, along.length()), color, tilt)

	func _sign(text: String, at_u: Vector3, pixel: float) -> void:
		var label := Label3D.new()
		label.text = text
		label.pixel_size = pixel
		label.font_size = 64
		label.outline_size = 10
		label.modulate = Color("f4f1dd")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = at_u * U
		add_child(label)

	func _environment() -> void:
		var world := WorldEnvironment.new()
		var environment := Environment.new()
		var sky := Sky.new()
		var atmosphere := ProceduralSkyMaterial.new()
		atmosphere.sky_top_color = Color("6f9fca")
		atmosphere.sky_horizon_color = Color("c9d6dc")
		atmosphere.ground_horizon_color = Color("b9c0bf")
		sky.sky_material = atmosphere
		environment.background_mode = Environment.BG_SKY
		environment.sky = sky
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		environment.ambient_light_energy = 0.35
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.tonemap_exposure = 0.85
		world.environment = environment
		add_child(world)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-35.0), 0.0)
		sun.light_energy = 0.9
		sun.shadow_enabled = true
		add_child(sun)

## a small lab readout, not the r14 hud: profile, tickrate, speed and the last hop.
class Overlay:
	extends CanvasLayer
	var player: Node
	var label := Label.new()

	func _ready() -> void:
		label.position = Vector2(16, 12)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		add_child(label)

	func _process(_delta: float) -> void:
		var s: Dictionary = player.call("get_motion_state")
		var hop: Dictionary = s.last_hop
		var hop_text := "—"
		if not hop.is_empty():
			hop_text = "%+.1f u/s, sync %s, %d air ticks" % [hop.gain, "—" if hop.sync == null else "%d%%" % int(round(float(hop.sync) * 100.0)), hop.air_ticks]
		label.text = "%s · %d Hz (engine %d) · aa %s · %s\n%.1f u/s  (%.2f m/s)\nlast hop: %s\njumps %d · first-tick hops %d · stamina %.1f\nF1 vanilla · F2 server · R respawn · Esc mouse" % [
			s.cvars.label, s.tickrate, s.physics_hz, str(s.cvars.sv_airaccelerate),
			"autohop" if s.cvars.sv_autobunnyhopping else "press each jump",
			s.actual_speed_u, s.actual_speed, hop_text, s.jump_count, s.perfect_count, s.stamina]

## open-loop tapes: [tick, key, pressed] edges and ["mouse", start, ticks, counts] sweeps,
## spread one integer-count event per tick. ticks start after the setup's settle ticks.
const DEMOS := {
	# server: w run-up, release, hold jump, alternate a/d with matched sweeps.
	"server_strafe": [[1, "w", true], [72, "w", false], [72, "space", true], [72, "a", true], ["mouse", 72, 48, -340], [120, "a", false], [120, "d", true], ["mouse", 120, 48, 340], [168, "d", false], [168, "a", true], ["mouse", 168, 48, -300], [216, "a", false], [216, "d", true], ["mouse", 216, 48, 300], [264, "d", false], [264, "a", true], ["mouse", 264, 48, -260], [312, "a", false], [312, "d", true], ["mouse", 312, 48, 260], [360, "d", false], [360, "space", false]],
	# lips: walk straight through the five step heights' lane at 18 u.
	"lips_walk": [[1, "w", true], [240, "w", false]],
}

var player: CharacterBody3D
var fixture: Fixture
var station := "runway"
var _tape: Dictionary = {}
var _tick := 0
var _end_tick := 0
var _settle := 8
var _trace_path := ""
var _trace_lines := PackedStringArray()
var _demo := ""

func _initialize() -> void:
	_setup.call_deferred()

func _setup() -> void:
	MAIN.bind_inputs()
	var args := OS.get_cmdline_user_args()
	var preset := "csgo_server"
	for arg: String in args:
		if arg.begins_with("--preset="):
			preset = arg.trim_prefix("--preset=")
		elif arg.begins_with("--station="):
			station = arg.trim_prefix("--station=")
		elif arg.begins_with("--trace="):
			_trace_path = arg.trim_prefix("--trace=")
		elif arg.begins_with("--demo="):
			_demo = arg.trim_prefix("--demo=")
	fixture = Fixture.new()
	fixture.name = "SourceFixture"
	root.add_child(fixture)
	fixture.build()
	player = PLAYER.new()
	player.name = "SourceRunner"
	root.add_child(player)
	player.call("apply_preset", preset)
	player.call("apply_engine_rate")
	player.call("reset_to", Fixture.pose(station))
	if not args.has("--no-overlay"):
		var overlay := Overlay.new()
		overlay.player = player
		root.add_child(overlay)
	var keys := Node.new()
	keys.set_script(_driver_script("key_input", "_unhandled_input(e: InputEvent) -> void:\n\tget_meta(\"lab\").call(\"key_input\", e)"))
	keys.set_meta("lab", self)
	root.add_child(keys)
	print("r14 source lab: preset=%s; station=%s; physics=%d Hz; engine=%s; physics_server=%s; renderer=%s" % [preset, station, Engine.physics_ticks_per_second, Engine.get_version_info().string, ProjectSettings.get_setting("physics/3d/physics_engine", "<unset>"), RenderingServer.get_current_rendering_method()])
	if _demo.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if DisplayServer.get_name() != "headless" else Input.MOUSE_MODE_VISIBLE
		player.settings["wheel_jump"] = true
	else:
		_load_demo(_demo)

func key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or not _demo.is_empty():
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F1:
			player.call("apply_preset", "csgo_vanilla", {"wheel_jump": true})
			player.call("apply_engine_rate")
		KEY_F2:
			player.call("apply_preset", "csgo_server", {"wheel_jump": true})
			player.call("apply_engine_rate")
		KEY_R:
			player.call("reset_to", Fixture.pose(station))
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _load_demo(name: String) -> void:
	if name.begins_with("planned_"):
		# the pure module's open-loop plan for the active profile, as in the player proofs.
		var preset: String = player.settings.preset
		var hz := int(player.settings.tickrate)
		var plan := plan_strafe(preset, 72 if hz == 128 else 35, int(name.trim_prefix("planned_")), 48 if hz == 128 else 24, "hold" if player.settings.sv_autobunnyhopping else "press", 900)
		var frames: Array = plan.frames
		var held := {}
		for i: int in frames.size():
			var want: Array = frames[i].keys
			for key: String in held.keys():
				if not key in want:
					_add(i + 1, [key, false])
					held.erase(key)
			for key: String in want:
				if not held.has(key):
					_add(i + 1, [key, true])
					held[key] = true
			if int(frames[i].mouse) != 0:
				_add(i + 1, ["mouse", int(frames[i].mouse)])
			if not want.is_empty():
				_end_tick = i + 1
		for key: String in held.keys():
			_add(_end_tick + 1, [key, false])
		print("r14 source lab plan: predicted landings %s" % [plan.predicted_landings])
	else:
		assert(DEMOS.has(name), "source lab: unknown demo " + name)
	for step: Array in DEMOS.get(name, []):
		if step[0] is String:
			var counts := expand_sweep(int(step[3]), int(step[2]))
			for i: int in counts.size():
				_add(int(step[1]) + i, ["mouse", counts[i]])
			_end_tick = maxi(_end_tick, int(step[1]) + int(step[2]))
		else:
			_add(int(step[0]), [step[1], step[2]])
			_end_tick = maxi(_end_tick, int(step[0]))
	_end_tick += 160
	print("r14 source lab demo: %s, %d ticks after %d settle ticks, open loop" % [name, _end_tick, _settle])
	var early := Node.new()
	early.process_physics_priority = -1000
	early.set_script(_driver_script("early_tick", "_physics_process(_d: float) -> void:\n\tget_meta(\"lab\").call(\"early_tick\")"))
	early.set_meta("lab", self)
	var late := Node.new()
	late.process_physics_priority = 1000
	late.set_script(_driver_script("late_tick", "_physics_process(_d: float) -> void:\n\tget_meta(\"lab\").call(\"late_tick\")"))
	late.set_meta("lab", self)
	root.add_child(early)
	root.add_child(late)

## open-loop strafe plan from the pure module on a flat plane: run-up with w, then a/d with
## the ideal wish angle each air tick, switching side every `switch` air ticks. returns the
## frames and the flat-plane prediction of the same frames. `jump`: hold, press (only on the
## predicted first ground tick), late (one tick after it) or scroll (press every other tick).
static func plan_strafe(preset: String, runup: int, hops: int, switch: int, jump: String, total: int, overrides := {}) -> Dictionary:
	var cv := MOTION.preset(preset)
	cv.merge(overrides, true)
	var dt := 1.0 / float(cv.tickrate)
	var rad := deg_to_rad(float(cv.sensitivity) * float(cv.m_yaw))
	var world := MOTION.FlatWorld.new()
	var s := MOTION.new_state()
	s.grounded = true
	s.ground_normal = Vector3.UP
	s.ground_ticks = 100
	var yaw := 0.0
	var side := -1.0
	var air := 0
	var frames := []
	var landings := []
	var pending_late := false
	for t: int in range(1, total + 1):
		var f := {"keys": [], "mouse": 0}
		var cmd := {"yaw": yaw}
		if t <= runup:
			f.keys = ["w"]
			cmd.forward = 1.0
		elif landings.size() < hops or not s.grounded:
			if not s.grounded:
				air += 1
				if air % switch == 0:
					side = -side
			var h := Vector3(s.velocity.x, 0, s.velocity.z)
			var desired := MOTION.yaw_for_side(optimal_dir(h, cv, dt, float(s.surface), side), side)
			var counts := int(round(wrapf(yaw - desired, -PI, PI) / rad))
			yaw -= counts * rad
			f.mouse = counts
			cmd.yaw = yaw
			cmd.side = side
			f.keys = ["a" if side < 0.0 else "d"]
			var press := false
			match jump:
				"hold":
					press = true
				"press":
					press = s.grounded
				"late":
					press = pending_late
					pending_late = s.grounded and t > runup + 1 and not press
					if t == runup + 1:
						press = true
				"scroll":
					press = t % 2 == 0 or t == runup + 1
			if press:
				f.keys.append("space")
			cmd.jump = press
		frames.append(f)
		MOTION.step(s, cmd, cv, dt, world)
		if "land" in s.events:
			landings.append(Vector2(s.velocity.x, s.velocity.z).length())
			air = 0
	return {"frames": frames, "predicted_landings": landings, "predicted_jumps": s.jump_count, "predicted_perfect": s.perfect_count}

static func optimal_dir(h: Vector3, cv: Dictionary, dt: float, surface: float, side: float) -> Vector3:
	var speed := h.length()
	var c := float(cv.sv_air_max_wishspeed)
	var b := minf(MOTION.air_budget(float(cv.player_maxspeed), cv, dt, surface), c)
	if speed < 1e-6:
		return Vector3(0, 0, -1)
	var along := h / speed
	if speed < c - b:
		return along
	return along.rotated(Vector3.UP, -side * acos(clampf((c - b) / speed, -1.0, 1.0)))

## a smoothstep sweep of `total` counts over `ticks`, as whole counts per tick.
static func expand_sweep(total: int, ticks: int) -> Array[int]:
	var out: Array[int] = []
	var sent := 0
	for i: int in ticks:
		var x := float(i + 1) / float(ticks)
		var reach := int(round(float(total) * x * x * (3.0 - 2.0 * x)))
		out.append(reach - sent)
		sent = reach
	return out

func _add(tick: int, event: Array) -> void:
	if not _tape.has(tick):
		_tape[tick] = []
	_tape[tick].append(event)

func _driver_script(_name: String, body: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc " + body + "\n"
	script.reload()
	return script

## before the motor: this tick's key edges and mouse counts, delivered as devices would.
func early_tick() -> void:
	_tick += 1
	var t := _tick - _settle
	for event: Array in _tape.get(t, []):
		send(event)

static func send(event: Array) -> void:
	if event[0] == "mouse":
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(float(event[1]), 0.0)
		motion.screen_relative = motion.relative
		Input.parse_input_event(motion)
	else:
		var key := InputEventKey.new()
		key.physical_keycode = {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL}[event[0]]
		key.pressed = event[1]
		Input.parse_input_event(key)
	Input.flush_buffered_events()

## after the motor: record what it did.
func late_tick() -> void:
	if not _trace_path.is_empty():
		_trace_lines.append(JSON.stringify(row(player.call("get_motion_state"))))
	if _tick - _settle >= _end_tick:
		var s: Dictionary = player.call("get_motion_state")
		print("r14 source lab demo end: tick %d, feet %s u, speed %.2f u/s, jumps %d, first-tick hops %d, last hop %s" % [_tick, (s.position as Vector3) / U, s.actual_speed_u, s.jump_count, s.perfect_count, s.last_hop])
		if not _trace_path.is_empty():
			write_gzip(_trace_path, _trace_lines)
		quit()

## a standard gzip file of json lines, readable with python's gzip module.
static func write_gzip(path: String, lines: PackedStringArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(("\n".join(lines) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()

## a compact trace row in u and u/s.
static func row(s: Dictionary) -> Dictionary:
	var p: Vector3 = (s.position as Vector3) / U
	var v: Vector3 = s.velocity_u
	var d: Vector3 = (s.displacement as Vector3) / U
	var normals := []
	for c: Dictionary in s.contacts:
		var n: Vector3 = c.normal
		normals.append([c.body, c.phase, snappedf(n.x, 0.001), snappedf(n.y, 0.001), snappedf(n.z, 0.001)])
	return {"t": s.tick, "hz": s.physics_hz, "p": [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)], "v": [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)], "d": [snappedf(d.x, 0.0001), snappedf(d.y, 0.0001), snappedf(d.z, 0.0001)], "g": s.grounded, "e": s.events, "yaw": snappedf(float(s.yaw), 0.000001), "side": s.side, "gain": snappedf(float(s.air_gain_u), 0.0001), "surf": s.air_surface, "st": snappedf(float(s.stamina), 0.001), "sync": s.sync_tick, "c": normals}

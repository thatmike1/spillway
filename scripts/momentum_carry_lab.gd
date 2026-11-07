extends SceneTree
## p / r13 carry lab: the carry game with a chosen air law on spillway's course or a small
## neutral calibration block. lab runs never write records or settings.
## godot --path . --script res://scripts/momentum_carry_lab.gd -- [--air=broad|narrow]
##   [--course=calibration|spillway] [--steady-camera] [--no-hud] [--demo=NAME] [--trace=PATH]
## --demo plays a fixed open-loop key and relative-mouse tape through ordinary input events,
## then quits. it never reads the runner to choose input and never writes pose or velocity.

const GAME := preload("res://scripts/momentum_carry_game.gd")

## a neutral jump/turn/contact block for calibrating the motor. it is not the overflow course.
class CalibrationBlock:
	extends Node3D

	const GRID := "shader_type spatial;\nuniform vec3 base : source_color = vec3(0.6);\nuniform vec3 line : source_color = vec3(0.25);\nvarying vec3 wpos;\nvarying vec3 wnorm;\nvoid vertex() {\n\twpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\twnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);\n}\nfloat grid(vec2 uv, float width) {\n\tvec2 g = abs(fract(uv - 0.5) - 0.5) / max(fwidth(uv), vec2(1e-4));\n\treturn 1.0 - clamp(min(g.x, g.y) / width, 0.0, 1.0);\n}\nvoid fragment() {\n\tvec3 n = abs(wnorm);\n\tvec2 uv = n.y > 0.5 ? wpos.xz : (n.x > n.z ? wpos.zy : wpos.xy);\n\tALBEDO = mix(base, line, max(grid(uv, 1.0) * 0.45, grid(uv * 0.25, 1.6) * 0.85));\n\tROUGHNESS = 0.92;\n}\n"

	var spawn: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 10.04, 3.0))
	var checkpoints: Array[Dictionary] = []
	var finish_position: Vector3 = Vector3(0.0, 4.0, -77.0)
	var water_regions: Array[Dictionary] = []
	var water_audio_sources: Array[Vector3] = []
	var _shader := Shader.new()

	func build() -> void:
		_shader.code = GRID
		_environment()
		# p / start deck, a 16 degree descent, a landing deck split by a seam between two
		# bodies, a 3.5 m gap one metre down, a 0.25 m lip, a 12 degree kicker with a real
		# edge, a 5 m gap and the finish deck. a side wall to glance and a catch floor with a
		# walkable ramp back to the landing deck sit under and beside the line.
		_box("start", Vector3(0, 9.5, -2), Vector3(12, 1, 16), Color("8d939a"), 0)
		_ramp("descent", Vector3(0, 10, -10), Vector3(0, 6, -24), 12.0, Color("a4927a"))
		_box("landing_a", Vector3(0, 5.5, -27), Vector3(12, 1, 6), Color("8d939a"), 1)
		_box("landing_b", Vector3(0, 5.5, -33), Vector3(12, 1, 6), Color("858b91"), 1)
		_box("lower", Vector3(0, 4.5, -45.75), Vector3(12, 1, 12.5), Color("8d939a"))
		_box("lip_deck", Vector3(0, 4.75, -55), Vector3(12, 1, 6), Color("a0a6ab"))
		_ramp("kicker", Vector3(0, 5.25, -58), Vector3(0, 5.25 + 5.0 * tan(deg_to_rad(12.0)), -63), 12.0, Color("a4927a"))
		_box("finish", Vector3(0, 3.5, -74), Vector3(12, 1, 12), Color("7d9a86"), 2)
		_box("glance_wall", Vector3(6.25, 6.0, -48.75), Vector3(0.5, 2.0, 18.5), Color("9c6f5c"))
		_box("catch_floor", Vector3(0, -0.5, -38), Vector3(40, 1, 88), Color("6f757b"))
		_ramp("return_ramp", Vector3(-9, 6, -30.5), Vector3(-9, 0, -47), 4.0, Color("a4927a"))
		_box("return_deck", Vector3(-8.5, 5.5, -28.75), Vector3(5, 1, 3.5), Color("8d939a"))
		checkpoints.append({"pose": spawn, "radius": 3.0, "title": "Calibration start"})
		checkpoints.append({"pose": Transform3D(Basis.IDENTITY, Vector3(0, 6.04, -27)), "radius": 4.0, "title": "Landing deck"})
		checkpoints.append({"pose": Transform3D(Basis.IDENTITY, Vector3(0, 4.04, -71)), "radius": 4.0, "title": "Finish deck"})
		# signs stand beside the line, never across it at eye height.
		_sign("CARRY CALIBRATION BLOCK · not the course", Vector3(0, 14.5, -14), 0.012)
		_sign("16° descent", Vector3(-7.5, 10.6, -10.5), 0.006)
		_sign("seam: two bodies", Vector3(-7.5, 6.8, -30.0), 0.006)
		_sign("3.5 m gap, 1 m down", Vector3(7.5, 6.8, -36.5), 0.006)
		_sign("0.25 m lip", Vector3(-7.5, 6.0, -52.0), 0.006)
		_sign("12° kicker, 5 m gap", Vector3(-7.5, 7.0, -58.5), 0.006)
		_sign("finish", Vector3(0, 8.5, -82), 0.010)
		_sign("catch walk back", Vector3(-12.5, 2.0, -46), 0.006)

	func is_finish_at(feet: Vector3) -> bool:
		return AABB(Vector3(-6, 3.7, -80), Vector3(12, 3, 4)).has_point(feet)

	func route_hint(index: int, feet: Vector3) -> String:
		if feet.y < 3.0:
			return "Missed: walk the ramp on the left back to the landing deck."
		return ["Run down the descent and hop the gap.", "Hop the gap; the lip and kicker follow.", "Finish deck reached."][mini(index, 2)]

	func reset_state() -> void:
		pass

	func _material(color: Color) -> ShaderMaterial:
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("base", color)
		material.set_shader_parameter("line", color.darkened(0.45))
		return material

	func _box(label: String, center: Vector3, size: Vector3, color: Color, stage: int = -1, tilt: float = 0.0) -> StaticBody3D:
		var body := StaticBody3D.new()
		body.name = label
		body.transform = Transform3D(Basis(Vector3.RIGHT, tilt), center)
		if stage >= 0:
			body.set_meta("progress_stage", stage)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = size
		mesh.mesh = cube
		mesh.material_override = _material(color)
		body.add_child(mesh)
		add_child(body)
		return body

	func _ramp(label: String, a: Vector3, b: Vector3, width: float, color: Color) -> void:
		# a runs toward b along -z; the box's top face passes through both.
		var along := b - a
		var tilt := atan2(along.y, -along.z)
		var normal := Basis(Vector3.RIGHT, tilt) * Vector3.UP
		_box(label, (a + b) * 0.5 - normal * 0.5, Vector3(width, 1, along.length()), color, -1, tilt)

	func _sign(text: String, at: Vector3, pixel: float) -> void:
		var label := Label3D.new()
		label.text = text
		label.pixel_size = pixel
		label.font_size = 64
		label.outline_size = 10
		label.modulate = Color("f4f1dd")
		label.position = at
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

## the carry game on the calibration block, also loadable by the tape executor as
## --game-script res://scripts/momentum_carry_lab.gd --game-class CalibrationGame.
class CalibrationGame:
	extends "res://scripts/momentum_carry_game.gd"

	func _init() -> void:
		level_script = CalibrationBlock

## open-loop input tapes for the calibration block: [tick, key or "mouse", pressed or pixels].
## mouse pixels are relative x; positive turns right at the default 0.0022 rad per pixel.
const DEMOS := {
	# hold w down the descent, hop the gap, hop the lip and the kicker, coast to the finish.
	"line": [[20, "w", true], [400, "space", true], [408, "space", false], [520, "space", true], [528, "space", false], [610, "space", true], [618, "space", false], [900, "w", false]],
	# the same approach, then side keys with matched mouse sweeps through the flights.
	"strafe": [[20, "w", true], [400, "space", true], [404, "w", false], [404, "a", true], ["sweep", 404, 60, -160.0], [470, "a", false], [470, "d", true], ["sweep", 470, 40, 120.0], [500, "space", false], [520, "d", false], [520, "w", true], [610, "space", true], [618, "space", false], [900, "w", false]],
	# a late, imperfect hop off the landing deck edge into the gap: a miss to recover from.
	"miss": [[20, "w", true], [452, "space", true], [460, "space", false], [470, "w", false], [520, "a", true], ["sweep", 520, 80, -250.0], [600, "a", false], [600, "w", true], [1100, "w", false]],
}

var game
var _tape: Dictionary = {}
var _tick: int = 0
var _end_tick: int = 0
var _trace: FileAccess

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	game = (GAME if args.has("--course=spillway") else CalibrationGame).new()
	game.name = "CarryLab"
	game.air_profile = "narrow" if args.has("--air=narrow") else "broad"
	game.steady_camera = args.has("--steady-camera")
	root.add_child(game)
	for arg: String in args:
		if arg.begins_with("--trace="):
			_trace = FileAccess.open(arg.trim_prefix("--trace="), FileAccess.WRITE)
		elif arg.begins_with("--demo="):
			_load_demo(arg.trim_prefix("--demo="))

func _load_demo(name: String) -> void:
	assert(DEMOS.has(name), "carry lab: unknown demo " + name)
	for step: Array in DEMOS[name]:
		if step[0] is String:
			# a smoothstep mouse stroke over the given ticks, one event per tick.
			var total: float = step[3]
			var previous := 0.0
			for i: int in int(step[2]):
				var x := float(i + 1) / float(step[2])
				var reach := total * x * x * (3.0 - 2.0 * x)
				_add(int(step[1]) + i, ["mouse", reach - previous])
				previous = reach
			_end_tick = maxi(_end_tick, int(step[1]) + int(step[2]))
		else:
			_add(int(step[0]), [step[1], step[2]])
			_end_tick = maxi(_end_tick, int(step[0]))
	_end_tick += 120
	print("carry lab demo: %s, %d ticks, open loop" % [name, _end_tick])
	var early := Node.new()
	early.process_physics_priority = -1000
	early.set_script(_driver_script(true))
	var late := Node.new()
	late.process_physics_priority = 1000
	late.set_script(_driver_script(false))
	root.add_child.call_deferred(early)
	root.add_child.call_deferred(late)
	early.set_meta("lab", self)
	late.set_meta("lab", self)

func _add(tick: int, event: Array) -> void:
	if not _tape.has(tick):
		_tape[tick] = []
	_tape[tick].append(event)

func _driver_script(early: bool) -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc _physics_process(_d: float) -> void:\n\tget_meta(\"lab\").call(\"%s\")\n" % ("early_tick" if early else "late_tick")
	script.reload()
	return script

## before the motor: this tick's mouse motion, delivered as the device would.
func early_tick() -> void:
	for event: Array in _tape.get(_tick, []):
		if event[0] == "mouse":
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(float(event[1]), 0.0)
			motion.screen_relative = motion.relative
			Input.parse_input_event(motion)
			Input.flush_buffered_events()

## after the motor: record what it did, then apply the next tick's key edges between steps.
func late_tick() -> void:
	if _trace != null:
		var state: Dictionary = game.player.call("get_motion_state")
		state.erase("contacts")
		_trace.store_line(JSON.stringify(_numeric(state)))
	_tick += 1
	for event: Array in _tape.get(_tick, []):
		if event[0] != "mouse":
			var key := InputEventKey.new()
			key.physical_keycode = {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL}[event[0]]
			key.pressed = event[1]
			Input.parse_input_event(key)
			Input.flush_buffered_events()
	if _tick == _end_tick:
		print("carry lab demo end: tick %d, feet %s, speed %.2f m/s, checkpoint %d, finished %s" % [_tick, game.player.global_position, game.player.call("get_speed"), game.checkpoint_index, game.finished])
		if _trace != null:
			_trace.close()
			_trace = null
		game.request_quit()

static func _numeric(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = _numeric(value[key])
		return out
	if value is Array:
		var items := []
		for item: Variant in value:
			items.append(_numeric(item))
		return items
	return value

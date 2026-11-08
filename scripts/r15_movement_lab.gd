extends SceneTree
## p / r15 movement lab: the r15 crouch runner alone on a labelled fixture, for play, open-loop
## input proofs and os-input checks. records and settings are never written. it is a fixture,
## not a course, and owns no timing or profile identity.
## godot --path . --script res://scripts/r15_movement_lab.gd -- [--preset=server128|server128_aa1000]
##   [--station=NAME] [--demo=NAME] [--trace=PATH.jsonl.gz] [--observer=DIR] [--view=eye|chase]
##   [--no-overlay] [--sensitivity=SOURCE]
## keys: wasd, space or wheel jump, ctrl or c crouch, mouse look, f2 bhop server, f5 aa 1000
## (both keep pose, velocity and view), r respawn at the station, tab eye/chase view, esc mouse, f10 quit.
## --demo plays a fixed key and relative-mouse tape through ordinary input events, then quits;
## it never reads the runner to choose input and never writes pose or velocity after setup.
## --observer only reads the runner and writes telemetry; it is how os-input checks watch.

const MAIN := preload("res://scripts/spillway_main.gd")
const LAB := preload("res://scripts/r14_source_lab.gd")
const PRESETS := preload("res://scripts/r14_presets.gd")
const PLAYER := preload("res://scripts/r15_source_player.gd")
const MOTION := preload("res://scripts/r14_source_motion.gd")
const U: float = MOTION.U

## r14's fixture block plus the crouch stations, in source units. floor tops are y = 0 u.
class CrouchFixture:
	extends LAB.Fixture

	## crouch stations, facing -z. the r14 stations stay where r14 put them.
	const CROUCH_STATIONS := {
		"tunnel": [Vector3(40000, 0.5, 512), 0.0],
		"ledge": [Vector3(44000, 0.5, 256), 0.0],
		"low_gap": [Vector3(48000, 0.5, 256), 0.0],
		"duck_steps": [Vector3(52000, 0.5, 512), 0.0],
		"heights": [Vector3(56000, 0.5, 256), 0.0],
		"clearances": [Vector3(60000, 0.5, 128), 0.0],
	}
	## the measured layout the tests and docs read, in u.
	const TUNNEL := {"ceiling": 62.0, "front_z": -256.0, "back_z": -768.0, "inner_width": 192.0}
	const LEDGE := {"top": 60.0, "front_z": -256.0, "ceiling_gap": 62.0, "ceiling_back_z": -768.0, "back_z": -1280.0}
	const LOW_GAP := {"ceiling": 100.0, "near_z": -256.0, "far_z": -384.0, "ceiling_front_z": -128.0, "ceiling_back_z": -512.0, "catch": -160.0}
	const DUCK_STEP_LIPS := [8.0, 16.0, 18.0, 19.0, 24.0]
	const DUCK_STEP_GAP := 62.0
	const HEIGHTS := [50.0, 56.0, 60.0, 64.0, 66.0]
	## roof heights over 512 u lanes: valve's cs:go table has a crouched body clear 55 u and a
	## standing one 73 u ("lowest ceiling height will not bump against").
	const CLEARANCES := [54.0, 55.0, 72.0, 73.0]

	func build(light := true) -> void:
		super(light)
		build_crouch()

	func build_crouch() -> void:
		# tunnel: a 512 u corridor whose ceiling is 62 u over the floor, then open deck.
		var t := TUNNEL
		_box("tunnel_deck", Vector3(40000, -32, -256), Vector3(1024, 64, 3072), Color("8d939a"))
		var length := float(t.front_z) - float(t.back_z)
		var mid_z := (float(t.front_z) + float(t.back_z)) * 0.5
		_box("tunnel_ceiling", Vector3(40000, float(t.ceiling) + 16, mid_z), Vector3(float(t.inner_width) + 64, 32, length), Color("9c6f5c"))
		for side: float in [-1.0, 1.0]:
			_box("tunnel_wall_%s" % ("l" if side < 0.0 else "r"), Vector3(40000 + side * (float(t.inner_width) * 0.5 + 16), float(t.ceiling) * 0.5, mid_z), Vector3(32, float(t.ceiling), length), Color("9c6f5c"))
		_sign("tunnel: 62 u ceiling", Vector3(40000, 140, float(t.front_z) + 32), 0.005)
		# ledge: a 60 u block, out of a standing jump's reach, whose first 512 u carry a ceiling
		# 62 u over its top; the rest is open.
		var l := LEDGE
		_box("ledge_deck", Vector3(44000, -32, -256), Vector3(1024, 64, 3072), Color("8d939a"))
		var ledge_len := float(l.front_z) - float(l.back_z)
		_box("ledge_block", Vector3(44000, float(l.top) * 0.5, (float(l.front_z) + float(l.back_z)) * 0.5), Vector3(384, float(l.top), ledge_len), Color("a0a6ab"))
		var roof_len := float(l.front_z) - float(l.ceiling_back_z)
		_box("ledge_ceiling", Vector3(44000, float(l.top) + float(l.ceiling_gap) + 16, (float(l.front_z) + float(l.ceiling_back_z)) * 0.5), Vector3(384, 32, roof_len), Color("9c6f5c"))
		_sign("ledge 60 u · ceiling 62 u over it", Vector3(44000, 190, float(l.front_z) + 64), 0.005)
		# low gap: a 128 u pit under a ceiling 100 u over both decks; a catch floor below.
		var g := LOW_GAP
		_box("low_gap_near", Vector3(48000, -32, (1536 + float(g.near_z)) * 0.5), Vector3(512, 64, 1536 - float(g.near_z)), Color("8d939a"))
		_box("low_gap_far", Vector3(48000, -32, float(g.far_z) - 768), Vector3(512, 64, 1536), Color("7d9a86"))
		_box("low_gap_catch", Vector3(48000, float(g.catch) - 32, (float(g.near_z) + float(g.far_z)) * 0.5), Vector3(1024, 64, 2048), Color("6f757b"))
		var roof := float(g.ceiling_front_z) - float(g.ceiling_back_z)
		_box("low_gap_ceiling", Vector3(48000, float(g.ceiling) + 16, (float(g.ceiling_front_z) + float(g.ceiling_back_z)) * 0.5), Vector3(512, 32, roof), Color("9c6f5c"))
		_sign("128 u pit · 100 u ceiling", Vector3(48000, 150, float(g.ceiling_front_z) + 32), 0.005)
		# duck steps: five lanes, each a lip of 8, 16, 18, 19 or 24 u from z = -256, every lane
		# roofed 62 u over its own raised top from z = -64, so only a ducked body walks it.
		_box("duck_steps_deck", Vector3(52000, -32, 0), Vector3(1408, 64, 2048), Color("8d939a"))
		var x := 51424.0
		for lip: float in DUCK_STEP_LIPS:
			_box("duck_lip_%d" % int(lip), Vector3(x, lip * 0.5, -256 - 384), Vector3(192, lip, 768), Color("a0a6ab"))
			_box("duck_lip_roof_%d" % int(lip), Vector3(x, lip + DUCK_STEP_GAP + 16, -544), Vector3(192, 32, 960), Color("9c6f5c"))
			_sign("%d u lip" % int(lip), Vector3(x, lip + DUCK_STEP_GAP + 64, -32), 0.004)
			x += 288.0
		# heights: open blocks of 50, 56, 60, 64 and 66 u for reach boundaries.
		_box("heights_deck", Vector3(56000, -32, 0), Vector3(1408, 64, 3072), Color("8d939a"))
		x = 55424.0
		for h: float in HEIGHTS:
			_box("height_%d" % int(h), Vector3(x, h * 0.5, -256 - 384), Vector3(192, h, 768), Color("a0a6ab"))
			_sign("%d u" % int(h), Vector3(x, h + 40, -200), 0.004)
			x += 288.0
		# clearances: four roofed lanes, 54, 55, 72 and 73 u from floor to roof.
		_box("clearances_deck", Vector3(60000, -32, 0), Vector3(1408, 64, 3072), Color("8d939a"))
		x = 59568.0
		for h: float in CLEARANCES:
			_box("clearance_roof_%d" % int(h), Vector3(x, h + 16, -512), Vector3(192, 32, 512), Color("9c6f5c"))
			_sign("%d u roof" % int(h), Vector3(x, h + 60, -200), 0.004)
			x += 288.0
		_sign("R15 MOVEMENT LAB · crouch fixture, not a course", Vector3(48000, 320, 1200), 0.012)

	static func crouch_pose(station: String, offset_u := Vector3.ZERO) -> Transform3D:
		if not CROUCH_STATIONS.has(station):
			return LAB.Fixture.pose(station).translated(offset_u * U)
		var entry: Array = CROUCH_STATIONS[station]
		return Transform3D(Basis(Vector3.UP, float(entry[1])), ((entry[0] as Vector3) + offset_u) * U)

	static func lane_x(station: String, index: int) -> float:
		var base := {"duck_steps": 51424.0, "heights": 55424.0, "clearances": 59568.0}
		return float(base[station]) + 288.0 * index

## a lab readout, not the r15 hud: profile, speed, hull and the duck request.
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
		label.text = Overlay.describe(player.call("get_motion_state"))

	static func describe(s: Dictionary) -> String:
		var d: Dictionary = s.duck
		var hull: Dictionary = s.hull
		var hop: Dictionary = s.last_hop
		var hop_text := "—"
		if not hop.is_empty():
			hop_text = "%+.1f u/s, %d air ticks" % [hop.gain, hop.air_ticks]
		var posture := "DUCK %d u" % int(hull.height_u) if hull.ducked else "STAND %d u" % int(hull.height_u)
		if d.stand_blocked:
			posture += " · stand blocked %d ticks" % int(d.blocked_ticks)
		var lift: Vector3 = d.compensation_u
		return "%s · %d Hz · aa %s\n%.1f u/s travel (%.2f m/s)\n%s · crouch %s · eye %.1f u · feet %.1f u\nlift total %.1f u (not travel) · last hop %s\nF2 server · F5 AA 1000 · R respawn · Tab view · Esc mouse · F10 quit" % [
			s.cvars.label, s.tickrate, str(s.cvars.sv_airaccelerate), s.actual_speed_u, s.actual_speed,
			posture, "held" if d.held else "up", d.eye_u, hull.feet_u, lift.y, hop_text]

## a translucent box at the runner's hull, drawn only for the chase view.
class HullView:
	extends MeshInstance3D
	var player: Node3D
	var cube := BoxMesh.new()

	func _ready() -> void:
		mesh = cube
		layers = 1 << 9
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.62, 0.2, 0.45)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material_override = material

	func _process(_delta: float) -> void:
		var s: Dictionary = player.call("get_motion_state")
		var fraction := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
		var feet: Vector3 = (player.get("_previous_position") as Vector3).lerp(player.get("_current_position"), fraction)
		var size := Vector3(float(s.hull.width_u), float(s.hull.height_u), float(s.hull.width_u)) * U
		cube.size = size
		global_position = feet + Vector3.UP * size.y * 0.5

## open-loop tapes: [tick, key, pressed] edges and ["mouse", start, ticks, counts] sweeps.
const DEMOS := {
	# run, crouch hop over the low-ceiling pit, keep hopping ducked on the far deck.
	"low_gap_crouch_hop": [[1, "w", true], [150, "ctrl", true], [150, "space", true], [400, "space", false], [420, "w", false], [430, "ctrl", false]],
	# run, jump, crouch one tick later onto the 60 u ledge, release under its ceiling, walk out.
	"ledge_jump_then_crouch": [[1, "w", true], [101, "space", true], [102, "space", false], [104, "ctrl", true], [260, "ctrl", false], [700, "w", false]],
	# crouch walk into the tunnel, release halfway, keep walking until it opens.
	"tunnel_release_inside": [[1, "ctrl", true], [1, "w", true], [500, "ctrl", false], [1000, "w", false]],
}

var player: CharacterBody3D
var fixture: CrouchFixture
var station := "ledge"
var preset := "server128"
var chase: Camera3D
var hull_view: HullView
var _tape: Dictionary = {}
var _tick := 0
var _end_tick := 0
var _settle := 8
var _trace_path := ""
var _trace_lines := PackedStringArray()
var _demo := ""
var _observer := ""
var _observer_lines := PackedStringArray()
var _sensitivity := 2.5
var _view := "eye"

func _initialize() -> void:
	_setup.call_deferred()

func _setup() -> void:
	MAIN.bind_inputs()
	var args := OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--preset="):
			preset = PRESETS.resolve(arg.trim_prefix("--preset="))
		elif arg.begins_with("--station="):
			station = arg.trim_prefix("--station=")
		elif arg.begins_with("--trace="):
			_trace_path = arg.trim_prefix("--trace=")
		elif arg.begins_with("--demo="):
			_demo = arg.trim_prefix("--demo=")
		elif arg.begins_with("--observer="):
			_observer = arg.trim_prefix("--observer=")
		elif arg.begins_with("--sensitivity="):
			_sensitivity = float(arg.trim_prefix("--sensitivity="))
		elif arg.begins_with("--view="):
			_view = arg.trim_prefix("--view=")
	assert(preset in ["server128", "server128_aa1000"], "r15 lab: the approved source presets only")
	fixture = CrouchFixture.new()
	fixture.name = "CrouchFixture"
	root.add_child(fixture)
	fixture.build()
	player = PLAYER.new()
	player.name = "CrouchRunner"
	root.add_child(player)
	_apply_preset(preset)
	player.call("reset_to", CrouchFixture.crouch_pose(station))
	# the first-person eye never draws the hull box; the chase view does.
	(player.get("camera") as Camera3D).cull_mask &= ~(1 << 9)
	hull_view = HullView.new()
	hull_view.player = player
	root.add_child(hull_view)
	chase = Camera3D.new()
	chase.name = "Chase"
	chase.far = 900.0
	chase.fov = 70.0
	root.add_child(chase)
	var follow := Node.new()
	follow.set_script(_driver_script("_process(_d: float) -> void:\n\tget_meta(\"lab\").call(\"follow\")"))
	follow.set_meta("lab", self)
	root.add_child(follow)
	_set_view(_view)
	if not args.has("--no-overlay"):
		var overlay := Overlay.new()
		overlay.player = player
		root.add_child(overlay)
	var keys := Node.new()
	keys.set_script(_driver_script("_unhandled_input(e: InputEvent) -> void:\n\tget_meta(\"lab\").call(\"key_input\", e)"))
	keys.set_meta("lab", self)
	root.add_child(keys)
	print("r15 movement lab: preset=%s; station=%s; physics=%d Hz; engine=%s; physics_server=%s; renderer=%s; motor=%s" % [preset, station, Engine.physics_ticks_per_second, Engine.get_version_info().string, ProjectSettings.get_setting("physics/3d/physics_engine", "<unset>"), RenderingServer.get_current_rendering_method(), PLAYER.MOTOR_VERSION])
	if not _demo.is_empty():
		_load_demo(_demo)
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not _demo.is_empty() or not _observer.is_empty() or not _trace_path.is_empty():
		_add_ticks()

func _apply_preset(id: String) -> void:
	preset = id
	player.call("apply_settings", PRESETS.source_settings(id, {"sensitivity": _sensitivity, "fov": 90.0}))
	player.call("apply_engine_rate")

func _set_view(view: String) -> void:
	_view = view
	if view == "chase":
		chase.current = true
	else:
		(player.get("camera") as Camera3D).current = true

## the chase view sits behind the runner's heading, above and to the right, looking at the hull.
func follow() -> void:
	if _view != "chase":
		return
	var feet := hull_view.global_position
	var yaw := float(player.get("view_yaw"))
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	chase.global_position = feet + back * 3.4 + right * 1.6 + Vector3.UP * 1.5
	chase.look_at(feet + Vector3.UP * 0.2 - back * 1.5, Vector3.UP)

func key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or not _demo.is_empty():
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F2:
			_apply_preset("server128")
		KEY_F5:
			_apply_preset("server128_aa1000")
		KEY_R:
			player.call("reset_to", CrouchFixture.crouch_pose(station))
		KEY_TAB:
			_set_view("eye" if _view == "chase" else "chase")
		KEY_F10:
			_finish()
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _load_demo(name: String) -> void:
	assert(DEMOS.has(name), "r15 lab: unknown demo " + name)
	for step: Array in DEMOS[name]:
		if step[0] is String:
			var counts := LAB.expand_sweep(int(step[3]), int(step[2]))
			for i: int in counts.size():
				_add(int(step[1]) + i, ["mouse", counts[i]])
			_end_tick = maxi(_end_tick, int(step[1]) + int(step[2]))
		else:
			_add(int(step[0]), [step[1], step[2]])
			_end_tick = maxi(_end_tick, int(step[0]))
	_end_tick += 160
	print("r15 movement lab demo: %s, %d ticks after %d settle ticks, open loop" % [name, _end_tick, _settle])

func _add_ticks() -> void:
	var early := Node.new()
	early.process_physics_priority = -1000
	early.set_script(_driver_script("_physics_process(_d: float) -> void:\n\tget_meta(\"lab\").call(\"early_tick\")"))
	early.set_meta("lab", self)
	var late := Node.new()
	late.process_physics_priority = 1000
	late.set_script(_driver_script("_physics_process(_d: float) -> void:\n\tget_meta(\"lab\").call(\"late_tick\")"))
	late.set_meta("lab", self)
	root.add_child(early)
	root.add_child(late)

func _add(tick: int, event: Array) -> void:
	if not _tape.has(tick):
		_tape[tick] = []
	_tape[tick].append(event)

func _driver_script(body: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc " + body + "\n"
	script.reload()
	return script

func early_tick() -> void:
	_tick += 1
	for event: Array in _tape.get(_tick - _settle, []):
		LAB.send(event)

## after the motor: record what it did; the observer also publishes the latest row.
func late_tick() -> void:
	var s: Dictionary = player.call("get_motion_state")
	if not _trace_path.is_empty() or not _observer.is_empty():
		var r := row(s)
		var line := JSON.stringify(r)
		if not _trace_path.is_empty():
			_trace_lines.append(line)
		if not _observer.is_empty():
			_observer_lines.append(line)
			r["preset"] = preset
			r["station"] = station
			r["view"] = _view
			r["engine_tick"] = _tick
			var latest := FileAccess.open(_observer.path_join("latest.tmp"), FileAccess.WRITE)
			latest.store_string(JSON.stringify(r))
			latest.close()
			DirAccess.rename_absolute(_observer.path_join("latest.tmp"), _observer.path_join("latest.json"))
			if _observer_lines.size() >= 256:
				_flush_observer()
	if not _demo.is_empty() and _tick - _settle >= _end_tick:
		print("r15 movement lab demo end: tick %d, feet %s u, speed %.2f u/s, %s" % [_tick, (s.position as Vector3) / U, s.actual_speed_u, s.duck.counts])
		_finish()

func _flush_observer() -> void:
	var path := _observer.path_join("telemetry.jsonl")
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	file.seek_end()
	file.store_string("\n".join(_observer_lines) + "\n")
	file.close()
	_observer_lines.clear()

func _finish() -> void:
	if not _trace_path.is_empty():
		LAB.write_gzip(_trace_path, _trace_lines)
	if not _observer.is_empty():
		_flush_observer()
	quit()

func _finalize() -> void:
	if not _observer.is_empty() and not _observer_lines.is_empty():
		_flush_observer()

## r14's compact trace row plus the hull and duck fields, in u.
static func row(s: Dictionary) -> Dictionary:
	var r := LAB.row(s)
	var d: Dictionary = s.duck
	var shift: Vector3 = d.shift_u
	var comp: Vector3 = d.compensation_u
	r["duck"] = {"held": d.held, "ducked": d.ducked, "blocked": d.stand_blocked, "bt": d.blocked_ticks, "req": d.request, "shift": snappedf(shift.y, 0.0001), "comp": snappedf(comp.y, 0.0001), "eye": snappedf(float(d.eye_u), 0.001), "clamp": d.eye_clamped, "ev": d.events}
	r["hull"] = [snappedf(float(s.hull.height_u), 0.001), snappedf(float(s.hull.feet_u), 0.001), snappedf(float(s.hull.top_u), 0.001)]
	r["mode"] = s.mode
	return r

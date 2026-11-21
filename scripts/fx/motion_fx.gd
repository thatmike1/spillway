extends Node
## p / speed and moment presentation for every map. it reads the host and its runner each frame
## and never writes them: no motor, camera, recording or identity state changes here. the view
## effects use a separate presentation camera; everything rests at zero below running pace.
const LENS := preload("res://scripts/fx/motion_lens.gd")
const EDGE_SHADER := preload("res://shaders/fx/speed_edge.gdshader")
const MOTE_SHADER := preload("res://shaders/fx/wind_mote.gdshader")
const RING_SHADER := preload("res://shaders/fx/dust_ring.gdshader")

## public host settings. intensity scales every effect; each effect has its own switch.
const DEFAULTS := {
	"motion_fx": true,
	"motion_fx_intensity": 0.6,
	"motion_fx_fov": true,
	"motion_fx_streaks": true,
	"motion_fx_wind": true,
	"motion_fx_moments": true,
}
## capture-only: a fixed speed for calibration frames; never stored in a profile.
const PREVIEW_KEY := "motion_fx_preview_ups"

## the speed band, in source units per second: running pace to the top of a good line.
const SPEED_FLOOR := 300.0
const SPEED_TOP := 1200.0
const FOV_MAX_DEGREES := 8.0
const MOTE_COUNT := 96
const MOTE_BOX := Vector3(11.0, 4.5, 11.0)
const WIND := Vector3(1.1, 0.12, -0.6)
const RINGS := 3
const PALE := Color("e8dfbd")
const INK := Color("09110f")
const VERMILION := Color("d95b30")

var host: Node
var preview_ups := -1.0
var _preview_schedule: Array = []
var _preview_every := 1.0
var _preview_from := 0
var speed01 := 0.0
var _lens: Camera3D
var _layer: CanvasLayer
var _edge: ColorRect
var _edge_material: ShaderMaterial
var _motes: MultiMeshInstance3D
var _mote_material: ShaderMaterial
var _mote_points: PackedVector3Array = PackedVector3Array()
var _rings: Array[MeshInstance3D] = []
var _ring_age: Array[float] = []
var _next_ring := 0
var _clock := 0.0
var _fov := 0.0
var _dip := 0.0
var _dip_velocity := 0.0
var _burst := 0.0
var _wash := 0.0
var _wash_bias := Vector2.ZERO
var _wash_color := PALE
var _frame := 0.0
var _frame_color := VERMILION
var _frame_rate := 1.0
var _seen := {}

func _ready() -> void:
	process_priority = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lens = LENS.new()
	_lens.name = "MotionLens"
	add_child(_lens)
	_layer = CanvasLayer.new()
	_layer.name = "MotionEdge"
	_layer.layer = 1
	add_child(_layer)
	_edge = ColorRect.new()
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge_material = ShaderMaterial.new()
	_edge_material.shader = EDGE_SHADER
	_edge.material = _edge_material
	_layer.add_child(_edge)
	_motes = MultiMeshInstance3D.new()
	_motes.name = "WindMotes"
	_motes.top_level = true
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = QuadMesh.new()
	multimesh.instance_count = MOTE_COUNT
	_motes.multimesh = multimesh
	_mote_material = ShaderMaterial.new()
	_mote_material.shader = MOTE_SHADER
	_motes.material_override = _mote_material
	_motes.extra_cull_margin = 64.0
	add_child(_motes)
	var random := RandomNumberGenerator.new()
	random.seed = 7120
	_mote_points.resize(MOTE_COUNT)
	for i: int in MOTE_COUNT:
		_mote_points[i] = Vector3(random.randf_range(-1, 1), random.randf_range(-1, 1), random.randf_range(-1, 1)) * MOTE_BOX
		multimesh.set_instance_custom_data(i, Color(0, 0, 0, random.randf_range(0.45, 1.0)))
	for i: int in RINGS:
		var ring := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(2, 2)
		ring.mesh = plane
		var material := ShaderMaterial.new()
		material.shader = RING_SHADER
		material.set_shader_parameter("seed", float(i) * 3.7)
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.top_level = true
		ring.visible = false
		add_child(ring)
		_rings.append(ring)
		_ring_age.append(1.0)
	rest()

## true when the host offers what the effects read; anything missing leaves them at rest.
func attach(target: Node) -> bool:
	host = target if target != null and "settings" in target and "player" in target else null
	rest()
	return host != null

## a number holds one speed; {"speeds": [...], "every": s} steps through them on the physics
## clock, one per capture interval, so one static-pose capture can show a calibration strip.
func preview(value: Variant) -> void:
	_preview_schedule = []
	if value is Dictionary:
		_preview_schedule = (value as Dictionary).get("speeds", [])
		_preview_every = maxf(0.05, float((value as Dictionary).get("every", 1.0)))
		_preview_from = Engine.get_physics_frames()
		preview_ups = float(_preview_schedule[0]) if not _preview_schedule.is_empty() else -1.0
		return
	preview_ups = float(value) if value != null and float(value) >= 0.0 else -1.0

func _preview_step() -> void:
	if _preview_schedule.is_empty():
		return
	var seconds := float(Engine.get_physics_frames() - _preview_from) / float(Engine.physics_ticks_per_second)
	var value := float(_preview_schedule[int(seconds / _preview_every) % _preview_schedule.size()])
	preview_ups = value if value >= 0.0 else -1.0

static func clean_setting(key: String, value: Variant) -> Variant:
	if key == "motion_fx_intensity":
		return clampf(float(value), 0.0, 1.0)
	return bool(value)

func setting(key: String) -> Variant:
	var settings: Dictionary = host.get("settings") if is_instance_valid(host) else {}
	return clean_setting(key, settings.get(key, DEFAULTS[key]))

func intensity() -> float:
	return float(setting("motion_fx_intensity")) if bool(setting("motion_fx")) else 0.0

## everything back to zero: lens released, overlay and world flecks hidden, moments cleared.
func rest() -> void:
	if _lens != null:
		_lens.reset()
	if _layer != null:
		_layer.visible = false
	if _motes != null:
		_motes.visible = false
	for ring: MeshInstance3D in _rings:
		ring.visible = false
	for i: int in _ring_age.size():
		_ring_age[i] = 1.0
	speed01 = 0.0
	_fov = 0.0
	_dip = 0.0
	_dip_velocity = 0.0
	_burst = 0.0
	_wash = 0.0
	_frame = 0.0
	_seen = {}

func runner() -> Node3D:
	if not is_instance_valid(host):
		return null
	var body: Variant = host.get("player")
	return body if body is Node3D and is_instance_valid(body) and (body as Node3D).is_inside_tree() else null

func _process(delta: float) -> void:
	var body := runner()
	var camera: Camera3D = body.get("camera") if body != null else null
	var k := intensity()
	if body == null or camera == null or not camera.is_inside_tree() or k <= 0.0 or bool(host.get("paused")) \
			or not bool(host.get("look_enabled") if "look_enabled" in host else true):
		rest()
		return
	# another presentation camera (survey, run review) owns the view: draw nothing at all. the
	# tether speed lens is the one exception; it shows the runner's view, so only our lens yields.
	var view := get_viewport().get_camera_3d()
	if view != camera and view != _lens and not _is_tether_lens(view):
		rest()
		return
	var dt := clampf(delta, 0.0, 0.1)
	_preview_step()
	_clock = fmod(_clock + dt, 1000.0)
	var ups := preview_ups if preview_ups >= 0.0 else (float(host.call("display_speed_u")) if host.has_method("display_speed_u") else 0.0)
	var target := clampf((ups - SPEED_FLOOR) / (SPEED_TOP - SPEED_FLOOR), 0.0, 1.0)
	# slow to rise and slower to fall, so a single hop or a wall brush never pumps the view.
	speed01 = lerpf(speed01, target, 1.0 - exp(-(2.2 if target > speed01 else 1.3) * dt))
	if preview_ups >= 0.0:
		speed01 = target
	_observe_moments(body, camera, k, dt)
	_update_lens(camera, k, dt)
	view = get_viewport().get_camera_3d()
	_update_edge(k, dt)
	_update_motes(body, view if view != null else camera, k, dt)
	_update_rings(dt)

func _is_tether_lens(view: Camera3D) -> bool:
	var feedback: Variant = host.get("tether_feedback") if "tether_feedback" in host else null
	return view != null and feedback is Node and is_instance_valid(feedback) and view.get_parent() == feedback

func _update_lens(camera: Camera3D, k: float, dt: float) -> void:
	var view := get_viewport().get_camera_3d()
	# the tether speed lens already widens this view: step aside so the two never stack.
	if view != camera and view != _lens:
		_lens.reset()
		_fov = 0.0
		return
	var target := 0.0
	if bool(setting("motion_fx_fov")):
		target = FOV_MAX_DEGREES * k * ease_speed(speed01)
	_fov = target if preview_ups >= 0.0 else move_toward(_fov, target, dt * 4.0)
	# a critically damped return keeps the landing settle a single soft dip.
	var spring := 90.0
	_dip_velocity += (-spring * _dip - 2.0 * sqrt(spring) * _dip_velocity) * dt
	_dip += _dip_velocity * dt
	if absf(_dip) < 0.0004 and absf(_dip_velocity) < 0.002:
		_dip = 0.0
		_dip_velocity = 0.0
	_lens.update(camera, _fov, _dip, preview_ups >= 0.0)

static func ease_speed(value: float) -> float:
	# a gentle start above running pace, nearly linear through the fast band.
	return value * value * (3.0 - 2.0 * value) * 0.6 + value * 0.4

func _update_edge(k: float, dt: float) -> void:
	_burst = move_toward(_burst, 0.0, dt * 2.6)
	_wash = move_toward(_wash, 0.0, dt * 1.6)
	_frame = move_toward(_frame, 0.0, dt * _frame_rate)
	var amount := speed01 * k if bool(setting("motion_fx_streaks")) else 0.0
	var burst := _burst * k if bool(setting("motion_fx_streaks")) else 0.0
	var moments := bool(setting("motion_fx_moments"))
	var wash := clampf(_wash, 0.0, 1.0) * (0.4 + 0.6 * k) if moments else 0.0
	var frame := clampf(_frame, 0.0, 1.0) if moments else 0.0
	_layer.visible = amount + burst > 0.01 or wash > 0.005 or frame > 0.005
	if not _layer.visible:
		return
	var size := get_viewport().get_visible_rect().size
	_edge_material.set_shader_parameter("pixels", size)
	_edge_material.set_shader_parameter("amount", amount)
	_edge_material.set_shader_parameter("burst", burst)
	_edge_material.set_shader_parameter("clock", _clock)
	_edge_material.set_shader_parameter("wash", wash)
	_edge_material.set_shader_parameter("wash_color", _wash_color)
	_edge_material.set_shader_parameter("wash_bias", _wash_bias)
	_edge_material.set_shader_parameter("frame", frame)
	_edge_material.set_shader_parameter("frame_color", _frame_color)

func _update_motes(body: Node3D, view: Camera3D, k: float, dt: float) -> void:
	var strength := 0.0
	if bool(setting("motion_fx_wind")):
		strength = k * smoothstep(0.0, 0.25, speed01) * (0.5 + 0.6 * speed01)
	_motes.visible = strength > 0.01
	if not _motes.visible:
		return
	var eye := view.global_position
	var body_velocity: Vector3 = body.get("velocity") if "velocity" in body else Vector3.ZERO
	if preview_ups >= 0.0:
		var unit := float(body.get("U")) if "U" in body else 0.0254
		body_velocity = -view.global_basis.z * preview_ups * unit
	var relative := WIND - body_velocity
	var direction := relative.normalized() if relative.length_squared() > 0.0001 else Vector3.RIGHT
	var stretch := clampf(relative.length() * 0.035, 0.06, 0.9)
	var pixel := 2.0 * tan(deg_to_rad(view.fov) * 0.5) / maxf(1.0, get_viewport().get_visible_rect().size.y)
	var multimesh := _motes.multimesh
	for i: int in MOTE_COUNT:
		# flecks drift with the wind in the world; the box wraps around the eye.
		var point := _mote_points[i] + WIND * dt
		var local := point - eye
		local = Vector3(wrapf(local.x, -MOTE_BOX.x, MOTE_BOX.x), wrapf(local.y, -MOTE_BOX.y, MOTE_BOX.y), wrapf(local.z, -MOTE_BOX.z, MOTE_BOX.z))
		point = eye + local
		_mote_points[i] = point
		var distance := maxf(0.5, local.length())
		var facing := -local / distance
		var across := facing.cross(direction)
		if across.length_squared() < 0.000001:
			across = facing.cross(Vector3.UP)
		across = across.normalized() * maxf(0.005, distance * pixel * 2.0)
		var along := direction * stretch
		multimesh.set_instance_transform(i, Transform3D(Basis(along, across, facing), point))
	_mote_material.set_shader_parameter("strength", strength)
	_mote_material.set_shader_parameter("color", PALE.lightened(0.2))

func _update_rings(dt: float) -> void:
	for i: int in RINGS:
		var ring := _rings[i]
		if not ring.visible:
			continue
		_ring_age[i] = minf(1.0, _ring_age[i] + dt / 0.75)
		var age := _ring_age[i]
		ring.visible = age < 1.0
		# wide enough that its leading arc reaches the bottom of a level first-person view.
		var radius := lerpf(0.8, 2.8, 1.0 - pow(1.0 - age, 3.0))
		ring.scale = Vector3(radius, 1.0, radius)
		(ring.material_override as ShaderMaterial).set_shader_parameter("age", age)
		(ring.material_override as ShaderMaterial).set_shader_parameter("radius_m", radius)

## counters and flags the motor and host already keep; a change since last frame is a moment.
func _observe_moments(body: Node3D, camera: Camera3D, k: float, _dt: float) -> void:
	var state: Variant = body.get("state") if "state" in body else null
	var land := int((state as Dictionary).get("land_count", 0)) if state is Dictionary else 0
	var jumps := int((state as Dictionary).get("jump_count", 0)) if state is Dictionary else 0
	var perfect := int((state as Dictionary).get("perfect_count", 0)) if state is Dictionary else 0
	var fall := float((state as Dictionary).get("fall_speed", 0.0)) if state is Dictionary else 0.0
	var grapple: Variant = body.get("grapple") if "grapple" in body else null
	var attached := grapple is Dictionary and not (grapple as Dictionary).is_empty()
	var now := {
		"body": body.get_instance_id(), "attempts": int(host.get("attempts")), "checkpoint": int(host.get("checkpoint_index")),
		"finished": bool(host.get("finished")), "land": land, "jumps": jumps, "perfect": perfect, "attached": attached,
	}
	var before := _seen
	_seen = now
	if not before.is_empty() and (before.body != now.body or before.attempts != now.attempts):
		# a restart or a new runner starts clean: no dip, ring, frame or speed carried over.
		rest()
		_seen = now
		return
	if before.is_empty() or not bool(setting("motion_fx_moments")):
		return
	if now.land > before.land and fall > 360.0:
		_landing(body, camera, clampf((fall - 360.0) / 600.0, 0.0, 1.0), k)
	# a takeoff after running on a deck, not every link of a hop chain.
	if now.jumps > before.jumps and now.perfect == before.perfect and float(host.call("display_speed_u") if host.has_method("display_speed_u") else 0.0) > 380.0:
		_burst = maxf(_burst, 0.35)
	if now.checkpoint > before.checkpoint and not now.finished:
		_moment_wash(PALE, 0.9, Vector2.ZERO)
		_moment_frame(PALE, 1.0, 1.1)
	if now.finished and not before.finished:
		_moment_wash(PALE, 1.0, Vector2.ZERO)
		_moment_frame(PALE, 1.0, 0.7)
		var flags: Variant = host.get("_finish_flags")
		if flags is Array and not (flags as Array).is_empty() and bool((flags as Array)[0]):
			# a new best keeps a vermilion frame a little longer than any other moment.
			_moment_frame(VERMILION, 1.6, 0.45)
	if attached and not before.attached:
		var anchor: Vector3 = (grapple as Dictionary).get("position", camera.global_position - camera.global_basis.z)
		var bias := Vector2.ZERO
		if not camera.is_position_behind(anchor):
			var size := get_viewport().get_visible_rect().size
			bias = ((camera.unproject_position(anchor) / size - Vector2(0.5, 0.5)) * 2.0).limit_length(1.0)
		_moment_wash(PALE, 0.55, bias)
		_moment_frame(PALE, 0.9, 1.8)
	elif before.attached and not attached and not bool(body.call("is_grounded") if body.has_method("is_grounded") else true):
		_burst = maxf(_burst, 0.45)

func _moment_frame(color: Color, amount: float, fade_per_second: float) -> void:
	_frame_color = color
	_frame = maxf(_frame, amount)
	_frame_rate = fade_per_second

func _moment_wash(color: Color, amount: float, bias: Vector2) -> void:
	_wash_color = color
	_wash = maxf(_wash, amount)
	_wash_bias = bias

func _landing(body: Node3D, camera: Camera3D, hardness: float, k: float) -> void:
	var ring := _rings[_next_ring]
	_next_ring = (_next_ring + 1) % RINGS
	var state: Dictionary = body.get("state")
	var normal: Vector3 = state.get("ground_normal", Vector3.UP)
	if normal.length_squared() < 0.5:
		normal = Vector3.UP
	var tangent := normal.cross(Vector3.FORWARD if absf(normal.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var travel: Vector3 = body.get("velocity") if "velocity" in body else Vector3.ZERO
	# centred a little ahead along the run: a first-person view outruns a ring left at the feet.
	travel = (travel - normal * travel.dot(normal)) * 0.3
	ring.global_transform = Transform3D(Basis(tangent, normal, tangent.cross(normal)), body.global_position + travel.limit_length(3.0) + normal * 0.03)
	ring.visible = true
	_ring_age[_rings.find(ring)] = 0.0
	(ring.material_override as ShaderMaterial).set_shader_parameter("strength", 0.45 + 0.55 * k)
	# only a real drop settles the view; a flat hop lands at about 300 u/s and is left alone.
	if hardness > 0.25 and bool(setting("motion_fx_fov")) and get_viewport().get_camera_3d() in [camera, _lens]:
		_dip_velocity -= (0.6 + 1.6 * hardness) * k

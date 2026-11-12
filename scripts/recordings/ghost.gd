extends Node3D
## p / r16 best-run ghost: a nonphysical replay of one complete, clean, finished recording on the
## course clock. it holds no collision object, never reads or writes the player, and cannot touch
## progress: it only moves its own meshes when set_time is called. root chooses which file is the
## best clean run for the current identity (r16_run_reader.fastest_clean can help) and owns the
## player-facing toggle; `visible` hides it.
##
## load_run(path, expected_identity) refuses anything but a sealed `.r16run` whose header identity
## equals expected_identity exactly (map, preset, geometry, physics, mechanics, as root defines it)
## and whose outcome and last sample are a clean finish. a refusal clears any earlier ghost, so a
## ghost of another map or preset never lingers.
## timing: time 0 is the timer start. set_time(t) places the ghost at the recorded pose whose course
## clock equals t, interpolated between the bracketing ticks; before 0 it stands at the last pose
## before the timer started, after the finish it stays on the finish pose.
## visibility: a translucent, unshaded body that never writes depth, a short trail at the feet,
## and a fade by distance from the active camera, so a ghost on top of the player's eye never
## covers the landing in front of it.

const READER := preload("res://scripts/r16_run_reader.gd")
const BODY_HEIGHT := 1.75
const DUCK_HEIGHT := 1.30
const RADIUS := 0.28

## within this distance of the camera the body is hidden; it reaches full alpha at near_fade_m.
## native check 9 Nov: at 1.2/3.0 m a ghost 2 m ahead still covered the centre view and the floor
## in front of it, so the fade now runs over a longer reach.
var near_hide_m := 1.5
var near_fade_m := 6.0
var trail_seconds := 0.8
var color := Color(0.55, 0.9, 1.0, 0.32)

var loaded := false
var run_id := ""
var run_time := 0.0
var _times := PackedFloat64Array()
var _feet_track := PackedVector3Array()
var _yaw := PackedFloat64Array()
var _pitch := PackedFloat64Array()
var _ducked := PackedByteArray()
var _time := 0.0
var _body: MeshInstance3D
var _visor: MeshInstance3D
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _body_material: StandardMaterial3D
var _trail_material: StandardMaterial3D
var _feet := Vector3.ZERO
var _fade := 1.0

func _init() -> void:
	name = "R16Ghost"
	_body_material = _material(color)
	_trail_material = _material(Color(color.r, color.g, color.b, color.a * 0.8))
	_body = MeshInstance3D.new()
	_body.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.radius = RADIUS
	capsule.height = BODY_HEIGHT
	_body.mesh = capsule
	_body.material_override = _body_material
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)
	_visor = MeshInstance3D.new()
	_visor.name = "Visor"
	var visor := BoxMesh.new()
	visor.size = Vector3(0.34, 0.08, 0.16)
	_visor.mesh = visor
	_visor.material_override = _body_material
	_visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visor)
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.name = "Trail"
	_trail.mesh = _trail_mesh
	_trail.material_override = _trail_material
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	clear()

static func _material(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = tint
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m

func load_run(path: String, expected_identity: Dictionary) -> Dictionary:
	clear()
	if not path.ends_with(READER.SUFFIX):
		return {"ok": false, "error": "only a sealed .r16run file can be a ghost, not %s" % path.get_file()}
	var run := READER.read(path, true)
	if not bool(run.ok):
		return {"ok": false, "error": "recording is %s: %s" % [run.status, str(run.errors).left(300)], "status": run.status}
	var why := READER.identity_matches((run.header as Dictionary).get("identity"), expected_identity)
	if not why.is_empty():
		return {"ok": false, "error": why, "status": run.status}
	var clean := READER.clean_finish(run)
	if not bool(clean.ok):
		return {"ok": false, "error": clean.error, "status": run.status}
	var c: Dictionary = run.columns
	var flags: PackedInt32Array = c.flags
	var start := -1
	var finish := -1
	for i: int in flags.size():
		if start < 0 and flags[i] & 1 != 0:
			start = i
		if start >= 0 and flags[i] & 2 != 0:
			finish = i
			break
	if start < 0 or finish < 0:
		return {"ok": false, "error": "no timer start and finish in the tick stream"}
	var elapsed: PackedFloat64Array = c.elapsed
	var from := maxi(start - 1, 0)
	for i: int in range(from, finish + 1):
		var t := 0.0 if i < start else elapsed[i]
		if not _times.is_empty() and t < _times[_times.size() - 1]:
			clear()
			return {"ok": false, "error": "course clock runs backwards at tick %d" % (c.tick as PackedInt32Array)[i]}
		_times.append(t)
		_feet_track.append((c.p as PackedVector3Array)[i])
		_yaw.append((c.yaw as PackedFloat64Array)[i])
		_pitch.append((c.pitch as PackedFloat64Array)[i])
		_ducked.append(1 if flags[i] & 16 != 0 else 0)
	loaded = true
	run_id = str((run.header as Dictionary).get("run_id", ""))
	run_time = float(clean.time)
	set_time(0.0)
	return {"ok": true, "run_id": run_id, "time": run_time, "ticks": _times.size(), "path": path}

func clear() -> void:
	loaded = false
	run_id = ""
	run_time = 0.0
	_times = PackedFloat64Array()
	_feet_track = PackedVector3Array()
	_yaw = PackedFloat64Array()
	_pitch = PackedFloat64Array()
	_ducked = PackedByteArray()
	_time = 0.0
	if _trail_mesh != null:
		_trail_mesh.clear_surfaces()
	if _body != null:
		_body.visible = false
		_visor.visible = false
		_trail.visible = false

## the recorded pose at course time t: feet, yaw, pitch and ducked, or {} without a run.
func pose_at(t: float) -> Dictionary:
	if not loaded:
		return {}
	var n := _times.size()
	if t <= _times[0]:
		return _pose(0, 0, 0.0)
	if t >= _times[n - 1]:
		return _pose(n - 1, n - 1, 0.0)
	var hi := _times.bsearch(t, false)
	var lo := hi - 1
	var span := _times[hi] - _times[lo]
	return _pose(lo, hi, (t - _times[lo]) / span if span > 0.0 else 1.0)

func _pose(lo: int, hi: int, w: float) -> Dictionary:
	var a := _feet_track[lo]
	var b := _feet_track[hi]
	return {"feet": a.lerp(b, w), "yaw": lerp_angle(_yaw[lo], _yaw[hi], w), "pitch": lerpf(_pitch[lo], _pitch[hi], w), "ducked": _ducked[hi if w >= 0.5 else lo] != 0}

func set_time(elapsed_s: float) -> void:
	if not loaded:
		return
	_time = elapsed_s
	var pose := pose_at(elapsed_s)
	_feet = pose.feet
	var height := DUCK_HEIGHT if bool(pose.ducked) else BODY_HEIGHT
	(_body.mesh as CapsuleMesh).height = height
	_body.position = _feet + Vector3.UP * height * 0.5
	_body.rotation = Vector3(0.0, float(pose.yaw), 0.0)
	var facing := Basis(Vector3.UP, float(pose.yaw)) * Basis(Vector3.RIGHT, float(pose.pitch))
	_visor.transform = Transform3D(facing, _feet + Vector3.UP * (height - 0.18) + facing * Vector3(0, 0, -RADIUS))
	_draw_trail(elapsed_s)
	_apply_fade()

func _draw_trail(t: float) -> void:
	_trail_mesh.clear_surfaces()
	var steps := 24
	var points: Array[Vector3] = []
	for i: int in steps + 1:
		var at := t - trail_seconds * (1.0 - float(i) / steps)
		if at < 0.0:
			continue
		points.append((pose_at(at).feet as Vector3) + Vector3.UP * 0.06)
	if points.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point: Vector3 in points:
		_trail_mesh.surface_add_vertex(point)
	_trail_mesh.surface_end()

func _process(_delta: float) -> void:
	if loaded:
		_apply_fade()

## distance from the active camera to the ghost's eye; the body fades out near it.
func _apply_fade() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	_fade = 1.0
	if camera != null:
		var eye := global_transform * (_feet + Vector3.UP * BODY_HEIGHT * 0.9)
		_fade = smoothstep(near_hide_m, near_fade_m, camera.global_position.distance_to(eye))
	_body_material.albedo_color.a = color.a * _fade
	_body.visible = loaded and _fade > 0.01
	_visor.visible = _body.visible
	_trail.visible = loaded

func fade() -> float:
	return _fade

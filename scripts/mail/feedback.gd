extends Node3D
## local envelope presentation; no global time, audio bus, motor or recording writes.
var _trail: MeshInstance3D
var _points: Array[Vector3] = []
var _cue: AudioStreamPlayer
var _slow: AudioStreamPlayer
var _was_active := false
var _hit := preload("res://scripts/r20_through_player.gd").make_cue()
## look c envelope: unshaded paper, an ink rim that keeps its silhouette at distance and a small
## stamp. it only restyles the runner's existing paper mesh; L off restores the original material.
var _paper_old: Material
var _paper_new: StandardMaterial3D
var _rim: MeshInstance3D
var _stamp: MeshInstance3D
var _look_state := -1

func _ready() -> void:
	_trail = MeshInstance3D.new()
	add_child(_trail)
	_trail.top_level = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("eee9d1")
	_trail.material_override = material
	_cue = AudioStreamPlayer.new()
	_cue.volume_db = -14
	add_child(_cue)
	_slow = AudioStreamPlayer.new()
	_slow.volume_db = -24
	_slow.stream = _tone()
	add_child(_slow)

func reset() -> void:
	_points.clear()
	_was_active = false
	if _slow != null:
		_slow.stop()
	if _cue != null:
		_cue.stop()
	if _trail != null:
		_trail.visible = false

func observe(flight: RefCounted, paused: bool) -> void:
	_style_paper()
	if paused:
		_slow.stream_paused = true
		_cue.stream_paused = true
		return
	_slow.stream_paused = false
	_cue.stream_paused = false
	if flight.active:
		if not _was_active:
			_points.clear()
			_slow.play()
		_points.append(flight.position)
		if _points.size() > 22:
			_points.pop_front()
		var mesh := ImmediateMesh.new()
		if _points.size() > 1:
			mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			for i: int in range(1, _points.size()):
				mesh.surface_add_vertex(_points[i - 1])
				mesh.surface_add_vertex(_points[i])
			mesh.surface_end()
		_trail.mesh = mesh
		_trail.visible = true
	elif _was_active:
		_slow.stop()
		_cue.stream = _hit
		_cue.pitch_scale = 1.4 if flight.result == "hit" else 0.45
		_cue.play()
		_trail.visible = false
	_was_active = flight.active

func _tone() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 2)
	for i: int in 22050:
		var time := float(i) / 22050.0
		var value := sin(TAU * 70 * time) * 0.18 + sin(TAU * 140 * time) * 0.06
		data.encode_s16(i * 2, roundi(value * 32767))
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050
	return stream

func _style_paper() -> void:
	var runner := get_parent()
	var paper: Variant = runner.get("_paper") if runner != null else null
	if not paper is MeshInstance3D:
		return
	var game := runner.get_parent()
	var look: Variant = game.get("look_enabled") if game != null else null
	var state := 1 if look == true else 0
	if state == _look_state:
		return
	_look_state = state
	if _rim == null:
		_paper_old = paper.material_override
		_paper_new = _flat(Color("f6efdc"))
		_rim = MeshInstance3D.new()
		var rim := BoxMesh.new()
		rim.size = Vector3(0.40, 0.27, 0.018)
		_rim.mesh = rim
		_rim.material_override = _flat(Color("18272e"))
		paper.add_child(_rim)
		_stamp = MeshInstance3D.new()
		var stamp := BoxMesh.new()
		stamp.size = Vector3(0.055, 0.065, 0.004)
		_stamp.mesh = stamp
		_stamp.position = Vector3(0.135, 0.06, 0.0135)
		_stamp.material_override = _flat(Color("e15a2b"))
		paper.add_child(_stamp)
	# with L on the trail is an ink thread, which reads against both the pale quay and the pale sky.
	if _trail != null:
		(_trail.material_override as StandardMaterial3D).albedo_color = Color("2c4752") if state == 1 else Color("eee9d1")
	paper.material_override = _paper_new if state == 1 else _paper_old
	_rim.visible = state == 1
	_stamp.visible = state == 1

func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

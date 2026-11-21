extends Node3D
## local envelope presentation; no global time, audio bus, motor or recording writes.
var _trail: MeshInstance3D
var _points: Array[Vector3] = []
var _cue: AudioStreamPlayer
var _slow: AudioStreamPlayer
var _was_active := false
var _hit := preload("res://scripts/r20_through_player.gd").make_cue()

func _ready() -> void:
	_trail = MeshInstance3D.new()
	add_child(_trail)
	_trail.top_level = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# an ink thread reads against both the pale quay and the pale sky.
	material.albedo_color = Color("2c4752")
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

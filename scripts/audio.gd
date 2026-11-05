extends Node
## every sound is synthesised at load time from noise and sine waves: no files,
## no third-party assets. Footsteps, breath on the jump, landings, wind that
## grows with speed, and the low structural groan that announces a fold.

const RATE: int = 22050

var _enabled: bool = true
var _player: CharacterBody3D
var _steps: Array[AudioStreamWAV] = []
var _sounds: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _wind: AudioStreamPlayer
var _rumble: AudioStreamPlayer
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _volume: float = 0.8
var _wind_level: float = 0.0


func attach(player: CharacterBody3D, _level: Node3D) -> void:
	_enabled = DisplayServer.get_name() != "headless"
	_player = player
	_rng.seed = 99
	for variant: int in range(4):
		_steps.append(_wav(_step(variant)))
	_sounds["jump"] = _wav(_breath(0.2, 0.5))
	_sounds["land"] = _wav(_thump(0.32, 62.0, 0.9))
	_sounds["land_soft"] = _wav(_thump(0.16, 90.0, 0.5))
	_sounds["hand"] = _wav(_slap())
	_sounds["slide"] = _wav(_scrape(0.75))
	_sounds["settle"] = _wav(_thump(1.6, 38.0, 1.0))
	_sounds["finish"] = _wav(_chime())
	for index: int in range(8):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(voice)
		_pool.append(voice)
	_wind = AudioStreamPlayer.new()
	_wind.stream = _wav(_wind_loop(3.0), true)
	_wind.volume_db = -80.0
	add_child(_wind)
	_rumble = AudioStreamPlayer.new()
	_rumble.stream = _wav(_groan(5.6))
	add_child(_rumble)
	player.connect("footstep", _on_footstep)
	player.connect("jumped", func() -> void: _play(_sounds["jump"], -9.0, _rng.randf_range(0.92, 1.08)))
	player.connect("landed", _on_landed)
	player.connect("move_started", _on_move)
	if _enabled:
		_wind.play()


func set_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 0.0001)))


func reset() -> void:
	if _rumble != null:
		_rumble.stop()


func fold_started(_fold: Node) -> void:
	if not _enabled:
		return
	_rumble.volume_db = -2.0
	_rumble.play()


func fold_settled(_fold: Node) -> void:
	_play(_sounds["settle"], 0.0, 1.0)


func finish() -> void:
	_play(_sounds["finish"], -6.0, 1.0)


func _process(delta: float) -> void:
	if _player == null or _wind == null:
		return
	var speed: float = _player.velocity.length()
	var target: float = clampf((speed - 3.0) / 14.0, 0.0, 1.0)
	_wind_level = lerpf(_wind_level, target, 1.0 - exp(-3.0 * delta))
	_wind.volume_db = linear_to_db(maxf(_wind_level * _wind_level * 0.5, 0.0001))
	_wind.pitch_scale = 0.8 + _wind_level * 0.5


func _on_footstep(strength: float) -> void:
	_play(_steps[_rng.randi() % _steps.size()], -14.0 + strength * 6.0, _rng.randf_range(0.9, 1.1))


func _on_landed(impact: float) -> void:
	if impact > 7.0:
		_play(_sounds["land"], -6.0 + clampf(impact - 7.0, 0.0, 8.0), _rng.randf_range(0.95, 1.05))
	else:
		_play(_sounds["land_soft"], -10.0, _rng.randf_range(0.95, 1.1))


func _on_move(kind: String) -> void:
	match kind:
		"vault", "climb":
			_play(_sounds["hand"], -8.0, _rng.randf_range(0.9, 1.1))
		"slide":
			_play(_sounds["slide"], -8.0, 1.0)
		"wallrun":
			_play(_steps[0], -8.0, 1.2)


func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if not _enabled:
		return
	for voice: AudioStreamPlayer in _pool:
		if not voice.playing:
			voice.stream = stream
			voice.volume_db = volume_db
			voice.pitch_scale = pitch
			voice.play()
			return


# ---------------------------------------------------------------- synthesis

func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for index: int in range(samples.size()):
		data.encode_s16(index * 2, int(clampf(samples[index], -1.0, 1.0) * 32000.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream


func _buffer(seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples


func _step(variant: int) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(0.12)
	var low: float = 0.0
	var pitch: float = 95.0 + float(variant) * 12.0
	for index: int in range(samples.size()):
		var t: float = float(index) / RATE
		var noise: float = _rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.18
		var grit: float = (noise - low) * exp(-t * 90.0) * 0.35
		var body: float = sin(TAU * pitch * t) * exp(-t * 45.0) * 0.7
		samples[index] = (low * 1.4 * exp(-t * 55.0) + grit + body) * 0.8
	return samples


func _breath(seconds: float, level: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(seconds)
	var band: float = 0.0
	var previous: float = 0.0
	for index: int in range(samples.size()):
		var t: float = float(index) / float(samples.size())
		var noise: float = _rng.randf_range(-1.0, 1.0)
		band += (noise - band) * 0.35
		var high: float = band - previous
		previous = band
		var envelope: float = sin(t * PI) * (1.0 - t * 0.5)
		samples[index] = (band * 0.6 + high * 0.5) * envelope * level
	return samples


func _thump(seconds: float, pitch: float, level: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(seconds)
	var low: float = 0.0
	for index: int in range(samples.size()):
		var t: float = float(index) / RATE
		var noise: float = _rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.06
		var sweep: float = pitch * (1.0 + 0.6 * exp(-t * 30.0))
		var body: float = sin(TAU * sweep * t) * exp(-t * 6.0 / seconds)
		var crunch: float = low * 3.0 * exp(-t * 28.0)
		samples[index] = (body * 0.8 + crunch * 0.6) * level
	return samples


func _slap() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(0.09)
	var band: float = 0.0
	for index: int in range(samples.size()):
		var t: float = float(index) / RATE
		var noise: float = _rng.randf_range(-1.0, 1.0)
		band += (noise - band) * 0.5
		samples[index] = band * exp(-t * 70.0) * 0.9 + sin(TAU * 180.0 * t) * exp(-t * 60.0) * 0.4
	return samples


func _scrape(seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(seconds)
	var band: float = 0.0
	for index: int in range(samples.size()):
		var t: float = float(index) / float(samples.size())
		var noise: float = _rng.randf_range(-1.0, 1.0)
		band += (noise - band) * 0.25
		var envelope: float = minf(t * 12.0, 1.0) * (1.0 - t)
		samples[index] = band * envelope * (0.6 + 0.4 * sin(t * 90.0)) * 0.7
	return samples


func _wind_loop(seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(seconds)
	var low: float = 0.0
	var mid: float = 0.0
	for index: int in range(samples.size()):
		var t: float = float(index) / float(samples.size())
		var noise: float = _rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.02
		mid += (noise - mid) * 0.12
		var gust: float = 0.7 + 0.3 * sin(t * TAU * 2.0) * sin(t * TAU * 3.0)
		samples[index] = (low * 4.0 + mid * 0.6) * gust * 0.5
	# crossfade the ends so the loop has no click
	var fade: int = int(0.08 * RATE)
	for index: int in range(fade):
		var w: float = float(index) / float(fade)
		var end_index: int = samples.size() - fade + index
		samples[end_index] = samples[end_index] * (1.0 - w) + samples[index] * w
	return samples


## the fold's voice: a deep groan that swells through the anticipation, steel
## creaks while the block turns, fading as it lands.
func _groan(seconds: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(seconds)
	var low: float = 0.0
	var lower: float = 0.0
	var creaks: Array[Vector3] = []
	for index: int in range(9):
		creaks.append(Vector3(_rng.randf_range(0.6, seconds - 0.8), _rng.randf_range(160.0, 420.0), _rng.randf_range(0.15, 0.45)))
	for index: int in range(samples.size()):
		var t: float = float(index) / RATE
		var u: float = t / seconds
		var noise: float = _rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.015
		lower += (low - lower) * 0.05
		var swell: float = clampf(t / 1.2, 0.0, 1.0) * clampf((seconds - t) / 1.4, 0.0, 1.0)
		var hum: float = sin(TAU * 36.0 * t + sin(TAU * 0.7 * t) * 2.0) * 0.5 + sin(TAU * 54.0 * t) * 0.2
		var value: float = (lower * 9.0 + hum) * swell * (0.6 + 0.4 * u)
		for creak: Vector3 in creaks:
			var local: float = t - creak.x
			if local > 0.0 and local < creak.z:
				var shape: float = sin(local / creak.z * PI)
				value += sin(TAU * (creak.y + local * 120.0) * local) * shape * 0.18 * (1.0 + sin(TAU * 31.0 * local))
		samples[index] = value * 0.7
	return samples


func _chime() -> PackedFloat32Array:
	var samples: PackedFloat32Array = _buffer(1.6)
	for index: int in range(samples.size()):
		var t: float = float(index) / RATE
		var second: float = maxf(t - 0.14, 0.0)
		samples[index] = sin(TAU * 660.0 * t) * exp(-t * 3.0) * 0.35 + sin(TAU * 990.0 * second) * exp(-second * 2.6) * 0.3 * float(t > 0.14)
	return samples


func stop_all() -> void:
	# release active playback before the audio server tears down.
	for voice: AudioStreamPlayer in _pool:
		voice.stop()
		voice.stream = null
	if _wind != null:
		_wind.stop()
		_wind.stream = null
	if _rumble != null:
		_rumble.stop()
		_rumble.stream = null


func _exit_tree() -> void:
	stop_all()

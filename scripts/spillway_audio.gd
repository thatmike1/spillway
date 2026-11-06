extends "res://scripts/audio.gd"
## p / original synthesis, with quiet water, speed-driven wind and contact scrape.
var _slide_voice: AudioStreamPlayer
var _waters: Array[AudioStreamPlayer3D] = []
var _step_surface: String = "concrete"
var _contact_level: float = 0.0

func attach(player: CharacterBody3D, level: Node3D) -> void:
	_enabled = DisplayServer.get_name() != "headless"
	_player = player
	_rng.seed = 31415
	if not _enabled:
		return
	for variant: int in 4:
		_steps.append(_wav(_step(variant)))
	_sounds["jump"] = _wav(_breath(0.16, 0.15))
	_sounds["land"] = _wav(_thump(0.23, 72.0, 0.65))
	_sounds["land_soft"] = _wav(_thump(0.12, 105.0, 0.38))
	_sounds["hand"] = _wav(_slap())
	_sounds["splash"] = _wav(_splash())
	_sounds["finish"] = _wav(_chime())
	_sounds["slide"] = _wav(_wind_loop(2.0), true)
	for i: int in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_pool.append(voice)
	_wind = AudioStreamPlayer.new()
	_wind.stream = _wav(_wind_loop(3.0), true)
	_wind.volume_db = -70.0
	add_child(_wind)
	_wind.play()
	_slide_voice = AudioStreamPlayer.new()
	_slide_voice.stream = _sounds.slide
	_slide_voice.volume_db = -70.0
	_slide_voice.pitch_scale = 1.9
	add_child(_slide_voice)
	_slide_voice.play()
	var sources: Array = level.get("water_audio_sources").duplicate()
	for region: Dictionary in level.get("water_regions"):
		sources.append((region["bounds"] as AABB).get_center())
	for i: int in mini(sources.size(), 4):
		var water := AudioStreamPlayer3D.new()
		water.stream = _wav(_water_loop(), true)
		water.position = sources[i]
		water.unit_size = 12.0
		water.max_distance = 85.0
		water.volume_db = -17.0
		add_child(water)
		water.play()
		_waters.append(water)
	player.connect("footstep", _on_footstep)
	player.connect("landed", _on_landed)
	player.connect("move_started", _on_move)

func _process(delta: float) -> void:
	if not _enabled or _player == null or _wind == null:
		return
	var speed: float = _player.get_speed()
	# p / wind keeps describing earned speed above 16 m/s, through the motor's 30 cap.
	var target := 0.0 if get_tree().paused else clampf((speed - 4.0) / 26.0, 0.0, 1.0)
	_wind_level = lerpf(_wind_level, target, 1.0 - exp(-4.0 * delta))
	_wind.volume_db = linear_to_db(maxf(_wind_level * 0.12, 0.0001))
	_wind.pitch_scale = 0.8 + sqrt(_wind_level) * 0.6
	var contact := str(_player.mode)
	var scrape := 0.0
	if not get_tree().paused:
		if contact == "slide":
			scrape = clampf(speed / 16.0, 0.0, 1.0) * (0.10 if _player.in_water else 0.15)
		elif contact == "surf":
			# p / a quiet sustained scrape confirms real ramp contact, ending on departure.
			scrape = clampf(speed / 30.0, 0.0, 1.0) * 0.10
	_contact_level = lerpf(_contact_level, scrape, 1.0 - exp(-12.0 * delta))
	_slide_voice.volume_db = linear_to_db(maxf(_contact_level, 0.0001))
	var scrape_pitch := 1.05 + clampf(speed / 30.0, 0.0, 1.0) * 0.45 if contact == "surf" else 1.9
	_slide_voice.pitch_scale = lerpf(_slide_voice.pitch_scale, scrape_pitch, 1.0 - exp(-8.0 * delta))

func _on_landed(impact: float) -> void:
	if not _enabled:
		return
	if _player.in_water:
		_play(_sounds["splash"], -17.0 + minf(impact * 0.3, 4.0), _rng.randf_range(0.9, 1.05))
	else:
		super._on_landed(impact)

func _splash() -> PackedFloat32Array:
	var samples := _buffer(0.45)
	var low: float = 0.0
	var wash: float = 0.0
	for i: int in samples.size():
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.06
		wash += (noise - wash) * 0.35
		var envelope := minf(t * 90.0, 1.0) * exp(-t * 10.0)
		var bubble := sin(TAU * (220.0 - t * 170.0) * t) * exp(-t * 16.0)
		samples[i] = ((wash - low) * 0.8 + low * 2.0 + bubble * 0.12) * envelope
	return samples

func _on_footstep(strength: float) -> void:
	if not _enabled:
		return
	var water: bool = _player.in_water
	var query := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.1, _player.global_position + Vector3.DOWN * 0.4, 1)
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	_step_surface = str(hit.collider.get_meta("surface", "concrete")) if not hit.is_empty() else "concrete"
	var pitch := _rng.randf_range(0.92, 1.08)
	if water:
		_play(_sounds.hand, -24.0 + strength * 3.0, pitch * 0.6)
	elif _step_surface == "metal":
		_play(_steps[_rng.randi() % _steps.size()], -22.0 + strength * 6.0, pitch * 1.45)
	else:
		_play(_steps[_rng.randi() % _steps.size()], -22.0 + strength * 6.0, pitch)

func finish() -> void:
	if _enabled:
		_play(_sounds["finish"], -15.0, 1.0)

func _on_move(kind: String) -> void:
	if not _enabled:
		return
	if kind == "jump":
		_play(_sounds.jump, -20.0, _rng.randf_range(0.95, 1.05))
	elif kind == "mantle":
		_play(_sounds.hand, -20.0, 0.8)

func _water_loop() -> PackedFloat32Array:
	var samples := _buffer(4.0)
	var fade := int(RATE * 0.1)
	samples.resize(samples.size() + fade)
	var low: float = 0.0
	var mid: float = 0.0
	for i: int in samples.size():
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.025
		mid += (noise - mid) * 0.2
		samples[i] = (low * 2.5 + mid * 0.5) * (0.55 + 0.08 * sin(TAU * t * 0.5))
	return _join_loop(samples, fade)

func stop_all() -> void:
	super.stop_all()
	if _slide_voice != null:
		_slide_voice.stop()
		_slide_voice.stream = null
	for water: AudioStreamPlayer3D in _waters:
		water.stop()
		water.stream = null

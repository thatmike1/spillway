extends Node
## original periodic synthesis with a private seed; no imported audio or global RNG.
const RATE := 22050
var voices := {}
var _volume := 0.8
var _levels := {"reel": 0.0, "tension": 0.0, "wind": 0.0}

func _ready() -> void:
	for kind: String in ["attach", "reel", "tension", "wind"]:
		var voice := AudioStreamPlayer.new()
		voice.stream = synthesize(kind)
		voice.volume_db = -80.0
		add_child(voice)
		voices[kind] = voice

func set_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	if _volume == 0.0:
		stop_all()

func attach_cue() -> void:
	if _volume > 0.0:
		voices.attach.volume_db = linear_to_db(_volume * 0.26)
		voices.attach.play()

func update(delta: float, attached: bool, reeling: bool, tension: float, speed_ups: float, options: Dictionary) -> void:
	var targets := {
		"reel": 0.20 if attached and reeling and bool(options.get("tether_reel_audio", false)) else 0.0,
		"tension": tension * 0.16 if attached and bool(options.get("tether_tension_audio", false)) else 0.0,
		"wind": clampf((speed_ups - 250.0) / 750.0, 0.0, 1.0) * 0.22 if bool(options.get("tether_wind_audio", false)) else 0.0}
	for kind: String in _levels:
		# disabling a channel stops immediately; physical changes ease to avoid clicks.
		var key := "tether_" + kind + "_audio"
		var voice: AudioStreamPlayer = voices[kind]
		if not bool(options.get(key, false)) or _volume == 0.0:
			_levels[kind] = 0.0
			voice.stop()
			continue
		_levels[kind] = lerpf(float(_levels[kind]), float(targets[kind]), 1.0 - exp(-8.0 * clampf(delta, 0.0, 0.1)))
		if float(_levels[kind]) < 0.0002:
			voice.stop()
		else:
			voice.volume_db = linear_to_db(maxf(0.00001, float(_levels[kind]) * _volume))
			voice.pitch_scale = 0.9 + tension * 0.18 if kind == "tension" else (0.85 + minf(speed_ups, 1200.0) / 2400.0 if kind == "wind" else 1.0)
			if not voice.playing:
				voice.play()

func stop_all() -> void:
	for kind: String in voices:
		voices[kind].stop()
	for kind: String in _levels:
		_levels[kind] = 0.0

func _exit_tree() -> void:
	stop_all()
	for kind: String in voices:
		voices[kind].stream = null

static func synthesize(kind: String) -> AudioStreamWAV:
	var frames := RATE if kind != "attach" else int(RATE * 0.09)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 220417
	var frequencies: Array[float] = []
	var phases: Array[float] = []
	for i: int in 24:
		frequencies.append(float(rng.randi_range(80, 2600)))
		phases.append(rng.randf_range(0, TAU))
	for i: int in frames:
		var t := float(i) / RATE
		var value := 0.0
		match kind:
			"attach":
				value = (sin(TAU * 520.0 * t) * 0.55 + sin(TAU * 880.0 * t) * 0.25) * sin(PI * float(i) / frames) * exp(-t * 30.0)
			"reel":
				value = sin(TAU * 112.0 * t) * 0.45 + sin(TAU * 336.0 * t) * pow(0.5 + 0.5 * cos(TAU * 16.0 * t), 8.0) * 0.30
			"tension":
				value = sin(TAU * 68.0 * t + sin(TAU * 3.0 * t) * 0.30) * 0.5 + sin(TAU * 136.0 * t) * 0.15
			"wind":
				for j: int in frequencies.size():
					value += sin(TAU * frequencies[j] * t + phases[j]) / 28.0
		data.encode_s16(i * 2, roundi(clampf(value, -1.0, 1.0) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	if kind != "attach":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = frames
	return stream

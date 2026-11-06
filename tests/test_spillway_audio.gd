extends SceneTree
## original loop PCM and real mixer checks; these do not establish listening quality.
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for seed_value: int in [31415, 42, 2718]:
		var sound: Node = preload("res://scripts/spillway_audio.gd").new()
		sound.get("_rng").seed = seed_value
		# match the runtime generation order so the shipped seed stays a regression.
		for variant: int in 4:
			sound.call("_step", variant)
		sound.call("_breath", 0.16, 0.15)
		sound.call("_thump", 0.23, 72.0, 0.65)
		sound.call("_thump", 0.12, 105.0, 0.38)
		sound.call("_slap")
		sound.call("_splash")
		sound.call("_chime")
		measure(sound, "slide", seed_value, sound.call("_wind_loop", 2.0), 2.0)
		measure(sound, "wind", seed_value, sound.call("_wind_loop", 3.0), 3.0)
		for i: int in 4:
			measure(sound, "water%d" % i, seed_value, sound.call("_water_loop"), 4.0)
		sound.free()
	await movement_mix()
	print("spillway audio: %d/%d checks passed; PCM continuity and mixer state, not listening quality" % [checks - failures, checks])
	quit(1 if failures else 0)

func measure(sound: Node, label: String, seed_value: int, samples: PackedFloat32Array, seconds: float) -> void:
	var stream: AudioStreamWAV = sound.call("_wav", samples, true)
	var data := stream.data
	var largest_step := 0
	var peak := 0
	var finite := true
	for i: int in samples.size():
		finite = finite and is_finite(samples[i])
		var sample := data.decode_s16(i * 2)
		peak = maxi(peak, absi(sample))
		if i > 0:
			largest_step = maxi(largest_step, absi(sample - data.decode_s16((i - 1) * 2)))
	var seam := absi(data.decode_s16(0) - data.decode_s16(data.size() - 2))
	var ok := finite and samples.size() == int(seconds * 22050.0) and peak < 32000 and largest_step > 0 and seam <= largest_step
	checks += 1
	failures += 0 if ok else 1
	print("%s [%s seed=%d] PCM wrap=%d, largest interior step=%d, peak=%d, samples=%d" % [
		"PASS" if ok else "FAIL", label, seed_value, seam, largest_step, peak, samples.size()])

func movement_mix() -> void:
	# labelled mixer fixture: actual player and audio objects, no speakers or route claim.
	var player := preload("res://scripts/spillway_player.gd").new()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	var sound := preload("res://scripts/spillway_audio.gd").new()
	root.add_child(sound)
	sound.set_process(false)
	sound.set("_enabled", true)
	sound.set("_player", player)
	var wind := AudioStreamPlayer.new()
	var contact := AudioStreamPlayer.new()
	sound.add_child(wind)
	sound.add_child(contact)
	sound.set("_wind", wind)
	sound.set("_slide_voice", contact)
	var levels: Array[float] = []
	var pitches: Array[float] = []
	for speed: float in [0.0, 8.5, 16.0, 24.0, 30.0]:
		player.velocity = Vector3.FORWARD * speed
		player.mode = "air"
		for i: int in 240:
			sound.call("_process", 1.0 / 120.0)
		levels.append(wind.volume_db)
		pitches.append(wind.pitch_scale)
	mix_check(levels[0] <= -75, "wind is quiet at rest")
	mix_check(levels[2] < levels[3] - 1 and levels[3] < levels[4] - 1, "wind volume distinguishes 16, 24 and 30 m/s")
	mix_check(pitches[3] - pitches[2] > .02 and pitches[4] - pitches[3] > .02, "wind pitch describes higher hop speed")
	player.velocity = Vector3.FORWARD * 16.0
	player.mode = "surf"
	for i: int in 120:
		sound.call("_process", 1.0 / 120.0)
	mix_check(contact.volume_db > -40 and contact.volume_db < -20, "surf contact gives a quiet sustained scrape")
	var surf_db := contact.volume_db
	player.mode = "air"
	for i: int in 60:
		sound.call("_process", 1.0 / 120.0)
	mix_check(contact.volume_db < -65, "scrape fades out after leaving the ramp")
	player.mode = "slide"
	player.in_water = false
	for i: int in 120:
		sound.call("_process", 1.0 / 120.0)
	var dry_db := contact.volume_db
	player.in_water = true
	for i: int in 120:
		sound.call("_process", 1.0 / 120.0)
	mix_check(contact.volume_db < dry_db - 2.5 and contact.volume_db > -25, "wet slide softens scrape while keeping feedback")
	print("mixer fixture wind dB=%s pitch=%s surf=%.2fdB dry slide=%.2fdB wet slide=%.2fdB" % [levels, pitches, surf_db, dry_db, contact.volume_db])
	sound.queue_free()
	player.queue_free()
	await process_frame

func mix_check(ok: bool, label: String) -> void:
	checks += 1
	failures += 0 if ok else 1
	print("%s [mixer] %s" % ["PASS" if ok else "FAIL", label])

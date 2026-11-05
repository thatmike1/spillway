extends SceneTree
## original loop PCM checks; these establish signal continuity, not listening quality.
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
	print("spillway audio: %d/%d loop checks passed; signal continuity only" % [checks - failures, checks])
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

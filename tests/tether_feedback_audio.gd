extends SceneTree
## presentation lifecycle and bounds, independent of the motor identity tape.
const FX := preload("res://scripts/fx/tether_feedback.gd")
const SOUND := preload("res://scripts/audio/tether_sound.gd")
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label_: String) -> void:
	if not ok:
		failures.append(label_)
	print("PASS " if ok else "FAIL ", label_)

func run() -> void:
	var fx := FX.new()
	root.add_child(fx)
	for key: String in FX.KEYS:
		check(not fx.enabled(key), "default off: " + key)
	var unsupported := Node3D.new()
	check(not fx.attach(unsupported), "non-grapple runner refused")
	unsupported.free()
	var start := Vector3.ZERO
	var end := Vector3(0, 0, -20)
	check(FX.rope_point(start, end, 1.8, 0) == start and FX.rope_point(start, end, 1.8, 1) == end, "rope endpoints fixed")
	check(is_equal_approx(FX.rope_point(start, end, 1.8, 0.5).y, -1.8), "slack bounded at midpoint")
	for pixel: float in [0.000001, 0.01, 100.0]:
		var radii := FX.cable_radii(pixel, 1.0)
		check(radii.x > 0 and radii.y > radii.x and radii.y <= 0.104, "cable widths stay nested and bounded")
	for distance: float in [0.001, 0.1, 1.0, 9.0, 30.0]:
		check(FX.cue_scale(distance) <= 1.0 and 1.05 * FX.cue_scale(distance) / distance <= 0.106, "ring angular size bounded")
	for kind: String in ["attach", "reel", "tension", "wind"]:
		var a := SOUND.synthesize(kind)
		var b := SOUND.synthesize(kind)
		check(a.data == b.data and not a.data.is_empty(), "deterministic original PCM: " + kind)
		if kind != "attach":
			check(a.loop_end == a.data.size() / 2, "whole loop: " + kind)
	var sound := SOUND.new()
	root.add_child(sound)
	var opts := {"tether_reel_audio": true, "tether_tension_audio": true, "tether_wind_audio": true}
	sound.update(0.1, true, true, 1.0, 1000.0, opts)
	sound.attach_cue()
	check(sound.voices.values().all(func(v: AudioStreamPlayer) -> bool: return v.playing), "all enabled audio channels start")
	await create_timer(0.12).timeout
	sound.stop_all()
	await create_timer(0.05).timeout
	check(sound.voices.values().all(func(v: AudioStreamPlayer) -> bool: return not v.playing), "boundary stops every audio channel")
	sound.update(0.1, true, true, 1.0, 1000.0, {})
	check(sound.voices.values().all(func(v: AudioStreamPlayer) -> bool: return not v.playing), "disabled channels stay stopped")
	sound.free()
	fx.free()
	print(JSON.stringify({"ok": failures.is_empty(), "failures": failures}))
	for frame: int in 4:
		await process_frame
	quit(0 if failures.is_empty() else 1)

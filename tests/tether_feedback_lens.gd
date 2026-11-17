extends SceneTree
## presentation lifecycle and bounds, independent of the motor identity tape.
const FX := preload("res://scripts/fx/tether_feedback.gd")
const SOUND := preload("res://scripts/audio/tether_sound.gd")
const LENS := preload("res://scripts/fx/tether_lens.gd")
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label_: String) -> void:
	if not ok:
		failures.append(label_)
	print("PASS " if ok else "FAIL ", label_)

func run() -> void:
	var base := Camera3D.new()
	root.add_child(base)
	base.fov = 80
	base.make_current()
	var lens := LENS.new()
	root.add_child(lens)
	var max_offset := 0.0
	var max_step := 0.0
	for frame: int in 1000:
		var prior := lens.offset_degrees
		lens.update(base, 2000 if frame % 60 < 30 else 0, 1.0 / 60, true)
		max_offset = maxf(max_offset, lens.offset_degrees)
		max_step = maxf(max_step, absf(lens.offset_degrees - prior))
	check(max_offset <= 3.0 and max_step <= 1.5 / 60 + 0.00001, "FOV bound and rate limit")
	check(base.fov == 80 and lens.current, "source camera FOV untouched")
	lens.reset()
	check(base.current and lens.offset_degrees == 0, "lens restores source camera")
	lens.update(base, 1000, 0.1, true)
	base.free()
	var replacement := Camera3D.new()
	root.add_child(replacement)
	lens.reset()
	check(replacement.current, "freed source falls back to replacement camera")
	lens.update(replacement, 1000, 0.1, true)
	root.remove_child(replacement)
	var next := Camera3D.new()
	root.add_child(next)
	lens.reset()
	check(next.current, "detached source falls back without touching detached camera")
	lens.free()
	replacement.free()
	next.free()
	print(JSON.stringify({"ok": failures.is_empty(), "failures": failures}))
	for frame: int in 4:
		await process_frame
	quit(0 if failures.is_empty() else 1)

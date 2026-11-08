extends SceneTree
## p / engine diagnostic, not a motor gate: how often a godot 4.7.2 motion cast misses a static
## floor box entirely when the source hull sweeps diagonally into it, by box size. the sweep is
## the one that tunnelled in the review fixture (64 Hz landing, 20000 u floor). a straight-down
## sweep is sampled too. writes probe.json under --out.
## godot --headless --audio-driver Dummy --path . --script res://tests/r14_source_repair_probe.gd -- [--out=DIR]

const P := preload("res://scripts/r14_source_player.gd")
const U := 0.0254
const SIZES := [Vector3(20000, 64, 20000), Vector3(8000, 64, 8000), Vector3(6000, 64, 6000), Vector3(12000, 64, 4000), Vector3(4000, 64, 12000), Vector3(5000, 64, 5000), Vector3(4400, 64, 4000), Vector3(4000, 64, 4000)]

var out := "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/source-repair/probe"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	_run.call_deferred()

func _run() -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.position = Vector3(0, -32, 0) * U
	root.add_child(body)
	var player: CharacterBody3D = P.new()
	player.input_enabled = false
	root.add_child(player)
	# the review fixture's tick-134 sweep at 64 Hz: requested velocity times dt.
	var motion := Vector3(24.8896732, -298.0066223, -299.7286072) * U / 64.0
	var rows: Array = []
	for size: Vector3 in SIZES:
		shape.size = size * U
		await physics_frame
		await physics_frame
		var diagonal := 0
		for i: int in 21:
			for k: int in 21:
				player.global_position = Vector3(-72.0 + i * 0.5, 2.97, -517.0 + k * 0.5) * U
				if player.move_and_collide(motion, true, 0.001, true, 4) == null:
					diagonal += 1
		var down := 0
		for i: int in 40:
			player.global_position = Vector3(-500 + i * 25.0, 3.0, -500 + i * 25.0) * U
			if player.move_and_collide(Vector3(0, -5, 0) * U, true, 0.001, true, 4) == null:
				down += 1
		rows.append({"box_u": [size.x, size.y, size.z], "diagonal_misses": diagonal, "diagonal_sweeps": 441, "straight_down_misses": down, "straight_down_sweeps": 40})
		print("box %s u: diagonal sweeps missed %d/441, straight down %d/40" % [size, diagonal, down])
	DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open(out.path_join("probe.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine": Engine.get_version_info(), "start_y_u": 2.97, "motion_u": [24.8896732 / 64.0, -298.0066223 / 64.0, -299.7286072 / 64.0], "rows": rows}, "\t"))
	f.close()
	quit()

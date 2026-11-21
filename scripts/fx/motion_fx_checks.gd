extends SceneTree
## motion effects are an observer: the same input tape gives the same motor, camera and identity
## with every effect on or off, settings never restart or relabel an attempt, and anything that
## stops the effects (master off, pause, old look, another camera) leaves the runner camera current.
const FX := preload("res://scripts/fx/motion_fx.gd")
var output := ""
var checks: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		push_error(label)

func host(map_id: String) -> Node:
	var game: Node = load("res://scripts/game.gd").new()
	game.map_id = map_id
	game.motor = "server128"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output.path_join("absent.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.set_paused(false)
	return game

## one deterministic tape; returns the serialized motor, camera and identity stream.
func tape(on: bool) -> Dictionary:
	var game := host("breakwater")
	var fx: Node = game.motion_fx
	fx.set_process(false)
	for key: String in FX.DEFAULTS:
		game.change_setting(key, on if FX.DEFAULTS[key] is bool else 1.0)
	var rows: Array = []
	var changed := 0
	var lens_ticks := 0
	var edge_ticks := 0
	var mote_ticks := 0
	var dt := 1.0 / 128.0
	for tick: int in 640:
		if on:
			# the top of the speed band so every effect is drawn during the observed tape.
			fx.preview(1200.0 if tick < 600 else -1.0)
		if tick == 2:
			Input.action_press("move_forward")
		if tick == 300:
			Input.action_press("jump")
		if tick == 310:
			Input.action_release("jump")
		if tick == 420:
			Input.action_press("move_right")
		if tick == 520:
			Input.action_release("move_right")
		game.player._physics_process(dt)
		game._physics_process(dt)
		game.player._process(dt)
		var camera: Camera3D = game.player.camera
		var before := var_to_bytes([game.player.get_motion_state(), camera.global_transform, camera.fov, game.motion_identity(), game.attempts, game.elapsed, game.checkpoint_index])
		for frame: int in 2:
			fx._process(dt * 0.5)
		if tick == 200 and on:
			fx._landing(game.player, camera, 1.0, 1.0)
		var after := var_to_bytes([game.player.get_motion_state(), camera.global_transform, camera.fov, game.motion_identity(), game.attempts, game.elapsed, game.checkpoint_index])
		if before != after:
			changed += 1
		if fx._lens.current:
			lens_ticks += 1
		if fx._layer.visible:
			edge_ticks += 1
		if fx._motes.visible:
			mote_ticks += 1
		rows.append(before)
	Input.action_release("move_forward")
	# below running pace the speed view eases out and hands the view back to the runner camera.
	fx.preview(-1.0)
	for frame: int in 160:
		game.player._physics_process(dt)
		game._physics_process(dt)
		fx._process(0.05)
	var resting: bool = not fx._lens.current and game.player.camera.current
	game.free()
	return {"bytes": var_to_bytes(rows), "changed": changed, "lens": lens_ticks, "edge": edge_ticks, "motes": mote_ticks, "resting": resting}

func host_checks() -> void:
	var game := host("breakwater")
	var fx: Node = game.motion_fx
	check(is_instance_valid(fx) and fx.host == game, "host installs one motion observer")
	for key: String in FX.DEFAULTS:
		check(game.settings.get(key) == FX.DEFAULTS[key], "default present: " + key)
	var identity: Dictionary = game.motion_identity().duplicate(true)
	var attempts: int = game.attempts
	var motion := var_to_bytes(game.player.get_motion_state())
	for key: String in FX.DEFAULTS:
		game.change_setting(key, false if FX.DEFAULTS[key] is bool else 0.3)
		game.change_setting(key, FX.DEFAULTS[key])
	game.change_setting(FX.PREVIEW_KEY, 900.0)
	check(game.motion_identity() == identity and game.attempts == attempts and var_to_bytes(game.player.get_motion_state()) == motion, "settings keep identity, attempt and motor")
	check(not game.settings.has(FX.PREVIEW_KEY), "capture preview is never stored")
	game.change_setting("motion_fx_intensity", 7.0)
	check(is_equal_approx(float(game.settings.motion_fx_intensity), 1.0), "intensity is clamped")
	game.change_setting("motion_fx_intensity", FX.DEFAULTS.motion_fx_intensity)
	fx._process(0.05)
	var camera: Camera3D = game.player.camera
	var fov := camera.fov
	check(fx._lens.current and camera.fov == fov, "lens takes the view without writing the runner camera")
	game.change_setting("motion_fx", false)
	fx._process(0.05)
	check(camera.current and not fx._layer.visible and not fx._motes.visible, "master switch off rests every effect")
	game.change_setting("motion_fx", true)
	fx._process(0.05)
	game.set_paused(true)
	fx._process(0.05)
	check(camera.current and not fx._layer.visible, "pause rests every effect")
	game.set_paused(false)
	game.set_look(false)
	fx._process(0.05)
	check(camera.current and not fx._motes.visible, "old look shows no motion effects")
	game.set_look(true)
	var other := Camera3D.new()
	game.add_child(other)
	other.make_current()
	fx._process(0.05)
	check(other.current and not fx._lens.current and not fx._layer.visible and not fx._motes.visible, "another presentation camera keeps the view and nothing is drawn")
	other.free()
	camera.make_current()
	game.change_setting(FX.PREVIEW_KEY, -1.0)
	for i: int in 200:
		fx._process(0.05)
	check(camera.current and not fx._lens.current and not fx._layer.visible, "effects rest below running pace")
	game.change_setting(FX.PREVIEW_KEY, 900.0)
	fx._process(0.05)
	fx._landing(game.player, camera, 1.0, 1.0)
	fx._moment_frame(FX.PALE, 1.0, 0.1)
	game.select_map("tether-yard")
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.change_setting(FX.PREVIEW_KEY, -1.0)
	fx._process(0.05)
	var rings_clear: bool = fx._rings.all(func(ring: MeshInstance3D) -> bool: return not ring.visible)
	check(game.motion_fx == fx and fx.runner() == game.player, "observer follows the replaced runner")
	check(rings_clear and fx._frame == 0.0 and fx._dip == 0.0 and fx.speed01 == 0.0 and game.player.camera.current, "map change clears every moment and the speed view")
	game.free()

## a real drop onto the spawn deck: the observer must see the landing and lay one ring.
func landing_check() -> void:
	var game := host("breakwater")
	var fx: Node = game.motion_fx
	var spawn: Transform3D = game.level.get("spawn")
	game.player.call("reset_to", Transform3D(spawn.basis, spawn.origin + Vector3.UP * 4.0))
	var dt := 1.0 / 128.0
	var seen := false
	var landed_fall := 0.0
	for tick: int in 384:
		game.player._physics_process(dt)
		game._physics_process(dt)
		game.player._process(dt)
		fx._process(dt)
		if fx._rings.any(func(ring: MeshInstance3D) -> bool: return ring.visible):
			seen = true
		if bool(game.player.call("is_grounded")) and landed_fall == 0.0 and tick > 4:
			landed_fall = float(game.player.state.fall_speed)
	print("landing check: fall_speed_u=", landed_fall, " land_count=", game.player.state.land_count, " ring=", seen)
	check(seen and landed_fall > 360.0, "a four-metre drop lays a landing ring")
	game.free()

func run() -> void:
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	await process_frame
	host_checks()
	landing_check()
	var off := tape(false)
	var on := tape(true)
	check(off.bytes == on.bytes, "on/off tapes give byte-identical motor, camera and identity streams")
	check(on.changed == 0 and off.changed == 0, "observer frames never change state inside a tick")
	check(on.lens > 0 and on.edge > 0 and on.motes > 0, "on tape exercised lens, edge lines and wind flecks")
	check(off.lens == 0 and off.edge == 0 and off.motes == 0, "off tape drew nothing")
	check(on.resting and off.resting, "runner camera current again after the tape")
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	var summary := {"ok": ok, "checks": checks, "bytes_compared": on.bytes.size(), "ticks": 640, "lens_ticks": on.lens, "edge_ticks": on.edge, "mote_ticks": on.motes}
	FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE).store_string(JSON.stringify(summary, "\t"))
	print(JSON.stringify({"ok": ok, "failed": checks.filter(func(row: Dictionary) -> bool: return not row.ok)}))
	for frame: int in 4:
		await process_frame
	quit(0 if ok else 1)

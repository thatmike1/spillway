extends SceneTree
## establish a real grounded pre-takeoff viewpoint with ordinary inputs on the frozen quay.
const HOST := preload("res://scripts/game.gd")
var game: Node3D
var ticks := 0
var phase := 0
var stopped_ticks := 0
var live := false
var output := ""
var pressed := false
var points := [Vector3(213, 0, 53.1), Vector3(214, 0, 53.88)]

class Driver extends Node:
	var suite: SceneTree
	func _physics_process(_dt: float) -> void:
		suite.drive()

func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	Engine.physics_ticks_per_second = 128
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	start.call_deferred()

func start() -> void:
	assert(output.is_absolute_path())
	game = HOST.new()
	game.map_id = "saltglass"
	game.motor = "server128"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output + ".absent.cfg"
	game.ghosts_directory = output + ".ghosts"
	game.ghost_share_storage = output + ".selection.cfg"
	root.add_child(game)
	await process_frame
	await process_frame
	var authored: Transform3D = game.level.spawn
	game.level.spawn = Transform3D(Basis.IDENTITY, Vector3(208, 5.34, 51))
	game.set_paused(false)
	game.restart_run("local-peek-fixture")
	game.level.spawn = authored
	var driver := Driver.new()
	driver.suite = self
	driver.process_physics_priority = -100
	root.add_child(driver)
	live = true

func drive() -> void:
	if not live:
		return
	ticks += 1
	var player: Node3D = game.player
	var p := player.global_position
	if phase < points.size():
		var delta: Vector3 = points[phase] - Vector3(p.x, 0, p.z)
		aim(delta)
		if delta.length() < 0.06:
			phase += 1
			if phase == points.size():
				forward(false)
		else:
			forward(phase == 0 or ticks % 5 == 0)
	else:
		stopped_ticks += 1
		aim(Vector3(221.5, 0, 53.995) - Vector3(p.x, 0, p.z))
	Input.flush_buffered_events()
	if stopped_ticks > 128 or game.respawn_count > 0 or ticks > 128 * 60:
		live = false
		var eye := p + Vector3.UP * float(player.get_motion_state().eye_height_u) * 0.0254
		var target := Vector3(221.5, 5.012, 53.995)
		var ray := PhysicsRayQueryParameters3D.create(eye, target)
		ray.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
		var result := {"ok": phase == points.size() and player.is_grounded() and game.respawn_count == 0 and not hit.is_empty() and str(hit.collider.name) == "salt_store",
			"phase": phase, "feet": [p.x, p.y, p.z], "eye": [eye.x, eye.y, eye.z],
			"grounded": player.is_grounded(), "respawns": game.respawn_count,
			"receiver_edge_target": [target.x, target.y, target.z], "occluder": "" if hit.is_empty() else str(hit.collider.name),
			"yaw_degrees": rad_to_deg(player.yaw), "geometry": game.level.geometry_hash(),
			"limit": "local walk from rest, no jump or body/velocity writes after initial fixture spawn; grounded eye position confirms original receiver remains hidden by salt_store; not visual discovery"}
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
		print("saltglass grounded peek: ", result)
		game.request_quit(0 if result.ok else 1)

func aim(direction: Vector3) -> void:
	var player: Node3D = game.player
	var yaw := atan2(-direction.x, -direction.z)
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(-angle_difference(player.yaw, yaw) / player.mouse_sensitivity, 0)
	mouse.screen_relative = mouse.relative
	Input.parse_input_event(mouse)

func forward(value: bool) -> void:
	if value == pressed:
		return
	var event := InputEventAction.new()
	event.action = "move_forward"
	event.pressed = value
	event.strength = (0.25 if phase == 0 else 1.0) if value else 0.0
	Input.parse_input_event(event)
	pressed = value

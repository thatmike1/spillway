extends SceneTree
## local earned-input comparison, seeded at rest on a real quay pan; not a full course run.
const HOST := preload("res://scripts/game.gd")
var game: Node3D
var case_index := 0
var ticks := 0
var running := false
var jumped := false
var peak_y := 0.0
var held := {}
var results: Array = []
var output := "/tmp/r22-05/outside-proof.json"
var samples: Array = []

class Driver extends Node:
	var suite: SceneTree
	func _physics_process(_dt: float) -> void:
		suite.drive()

func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	Engine.physics_ticks_per_second = 128
	var driver := Driver.new()
	driver.suite = self
	driver.process_physics_priority = -100
	root.add_child.call_deferred(driver)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	start_case.call_deferred()

func start_case() -> void:
	game = HOST.new()
	game.map_id = "saltglass" if case_index == 0 else "saltglass-seaward"
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
	game.set_paused(false)
	# only initial fixture setup changes spawn; the authored spawn is immediately restored.
	var authored: Transform3D = game.level.spawn
	game.level.spawn = Transform3D(Basis.IDENTITY, Vector3(208, 5.34, 51))
	game.restart_run("local-outside-fixture")
	game.level.spawn = authored
	ticks = 0
	jumped = false
	peak_y = game.player.global_position.y
	samples = []
	running = true

func drive() -> void:
	if not running:
		return
	ticks += 1
	var player: CharacterBody3D = game.player
	var p := player.global_position
	peak_y = maxf(peak_y, p.y)
	var yaw := atan2(-10.0, -6.0)
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(-angle_difference(player.yaw, yaw) / player.mouse_sensitivity, 0)
	mouse.screen_relative = mouse.relative
	Input.parse_input_event(mouse)
	key("move_forward", true)
	var launch: bool = not jumped and p.x >= 212.9 and player.is_grounded()
	key("jump", launch)
	if launch:
		jumped = true
	Input.flush_buffered_events()
	if ticks % 16 == 0:
		samples.append({"tick": ticks - 1, "position": [p.x, p.y, p.z], "velocity": str(player.velocity)})
	var support := ""
	if jumped and player.is_grounded() and p.x > 216:
		var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.1, p - Vector3.UP * 0.3)
		ray.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			support = str(hit.collider.name)
	var landed := support.begins_with("seaward_receiver")
	if landed or game.respawn_count > 0 or ticks >= 128 * 4:
		running = false
		var result := {"map": game.map_id, "new_receiver_landed": landed, "support": support,
			"jumped": jumped, "peak_y": peak_y, "respawns": game.respawn_count,
			"last_position": [p.x, p.y, p.z], "samples": samples,
			"limit": "local real-input fixture from rest, not normal-spawn completion or a claim that the original outside line is impossible"}
		end_case.call_deferred(result)
	return

func end_case(result: Dictionary) -> void:
	key("move_forward", false)
	key("jump", false)
	Input.flush_buffered_events()
	results.append(result)
	game.free()
	if case_index == 0:
		case_index = 1
		start_case.call_deferred()
		return
	var ok: bool = not results[0].new_receiver_landed and results[1].new_receiver_landed and results[1].jumped and results[1].peak_y > 6.2
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"ok": ok, "cases": results}, "\t"))
	print("saltglass outside fixture: ", ok, " ", output)
	quit(0 if ok else 1)

func key(action: String, pressed: bool) -> void:
	if bool(held.get(action, false)) == pressed:
		return
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	held[action] = pressed

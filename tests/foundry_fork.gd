extends "res://tests/foundry_routes.gd"
## a real-input moving inspection at the lip, then the gallery route; no camera teleport.
func run() -> void:
	for action: String in ["jump","move_forward","move_back","move_left","move_right","crouch","look_left","look_right","look_up","look_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	Engine.physics_ticks_per_second = 128
	DirAccess.make_dir_recursive_absolute(output)
	level = LEVEL.new()
	root.add_child(level)
	level.build()
	player = PLAYER.new()
	root.add_child(player)
	silence_fixture_audio()
	player.set_physics_process(false)
	player.set_process(false)
	player.apply_settings(PRESETS.source_settings("server128",{}))
	await physics_frame
	await reset()
	tape = []
	await walk(Vector3(0,18,0.7))
	# teaching fades after movement; this idle is visible in the retained capture trace.
	for tick: int in 768:
		await step(player._eye()+Vector3(0,-7,-10),false,false,false)
	var visible_ticks := 0
	var scan_min_y := player.position.y
	var maximum_speed := 0.0
	var observations: Array = []
	for tick: int in 256:
		player.yaw = 0
		player.pitch = deg_to_rad(-35)
		mouse(false)
		Input.action_release("move_forward")
		Input.action_release("jump")
		Input.action_press("move_left")
		tape.append({"yaw":player.yaw,"pitch":player.pitch,"rope":false,"jump":false,"forward":false,"left":true})
		player._physics_process(1.0/128)
		observe_checkpoints()
		scan_min_y = minf(scan_min_y,player.position.y)
		var speed := Vector2(player.velocity.x,player.velocity.z).length()
		maximum_speed = maxf(maximum_speed,speed)
		var visible := true
		for target: Vector3 in [Vector3(-16,16.6,-6),Vector3(0,12.1,-20.1),Vector3(0,-7.9,-19.8)]:
			visible = visible and player._r21_on_screen(target-player._eye()) and player._clear_line(player._eye(),target)
		if visible and speed > 5.5:
			visible_ticks += 1
		if tick % 16 == 0:
			observations.append({"tick":tape.size(),"position":[player.position.x,player.position.y,player.position.z],"speed":speed,"both_routes_and_court":visible})
	Input.action_release("move_left")
	await walk(Vector3(-16,18,1))
	await walk(Vector3(-16,12,-24))
	await walk(Vector3(0,12,-30))
	await walk(Vector3(0,12,-33),1400,true)
	await crossing(LEVEL.FOUNDRY_ANCHORS[2],Vector3(0,2,-56),145)
	var descending_catch := player.position.y > 0
	await walk(level.finish_position)
	var finish: bool = level.is_finish_at(player.position)
	var original := str(player.position)
	FileAccess.open(output.path_join("fork-events.json"),FileAccess.WRITE).store_string(JSON.stringify(event_tape(tape)))
	var replayed := await replay(tape)
	var ok: bool = visible_ticks > 5 and scan_min_y > 17.9 and finish and descending_catch and replayed.finish and replayed.position == original and replayed.checkpoints.size()==3
	var result := {"viewport":[root.size.x,root.size.y],"ok":ok,"visible_at_running_speed_ticks":visible_ticks,"scan_min_y":scan_min_y,"maximum_speed":maximum_speed,"finish":finish,"descending_catch":descending_catch,"replay":replayed,"scan":observations,"geometry_hash":level.geometry_hash()}
	FileAccess.open(output.path_join("summary.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	mouse(false)
	if player.cue_player != null:
		player.cue_player.stop()
	player.free()
	level.free()
	await process_frame
	await process_frame
	quit(0 if ok else 1)

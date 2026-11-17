extends "res://tests/foundry_routes.gd"
## a fixed-input one-hook carry through the existing shaft and descending catch.
var trace: Array = []
var write_ok := true

func write_json(name: String, value: Variant, indent: String = "") -> void:
	# close buffered exports before the fixed-input replay reads them back.
	var file := FileAccess.open(output.path_join(name),FileAccess.WRITE)
	if file == null:
		write_ok = false
		push_error("could not write "+name)
		return
	file.store_string(JSON.stringify(value,indent))
	write_ok = write_ok and file.get_error()==OK
	file.close()

func step(at: Vector3, rope: bool, jump: bool, forward: bool = true) -> void:
	super.step(at,rope,jump,forward)
	trace.append({"position":[player.position.x,player.position.y,player.position.z],"velocity":[player.velocity.x,player.velocity.y,player.velocity.z],"motion":player.get_motion_state()})

func carry(hold_ticks: int) -> Dictionary:
	await reset()
	tape = []
	trace = []
	await walk(Vector3(0,18,3))
	for tick: int in hold_ticks:
		step(LEVEL.FOUNDRY_ANCHORS[0],true,tick < 10)
	var release := {"position":str(player.position),"speed":Vector2(player.velocity.x,player.velocity.z).length()}
	var receiver_hops := 0
	for tick: int in 1200:
		var before: float = player.velocity.y
		step(Vector3(0,player._eye().y-15*tan(deg_to_rad(12.0)),player.position.z-15),false,true)
		if before <= 0 and player.velocity.y > 1 and player.position.z < -20 and player.position.z > -36:
			receiver_hops += 1
		if level.is_finish_at(player.position) or player.position.y < -7.8 or player.position.z < -79:
			break
	return {"hold":hold_ticks,"ticks":tape.size(),"seconds":tape.size()/128.0,"finish":level.is_finish_at(player.position),"checkpoints":reached.duplicate(),"grapples":player.grapple_count,"receiver_hops":receiver_hops,"position":str(player.position),"release":release}

func replay_carry(commands: Array, expected: Array, rope_enabled: bool = true, bunny_enabled: bool = true) -> Dictionary:
	await reset()
	var equal_positions := true
	var equal_velocities := true
	var motor_equal_ticks := 0
	var actual: Array = []
	var first_finish_tick := -1
	var released := false
	var attached := false
	for tick: int in commands.size():
		var cmd: Dictionary = commands[tick]
		var event := InputEventMouseMotion.new()
		event.screen_relative = Vector2(-wrapf(float(cmd.yaw)-player.yaw,-PI,PI),-(float(cmd.pitch)-player.pitch))/deg_to_rad(2.5*0.022)
		player._unhandled_input(event)
		attached = attached or bool(cmd.rope)
		released = released or (attached and not bool(cmd.rope))
		mouse(bool(cmd.rope) and rope_enabled)
		for action: String in ["move_forward","jump","move_left"]:
			var key: String = {"move_forward":"forward","jump":"jump","move_left":"left"}[action]
			var on := bool(cmd.get(key,false)) and (action != "jump" or bunny_enabled or not released)
			if on:
				Input.action_press(action)
			else:
				Input.action_release(action)
		player._physics_process(1.0/128)
		observe_checkpoints()
		if level.is_finish_at(player.position) and first_finish_tick < 0:
			first_finish_tick = tick+1
		var motion: Dictionary = player.get_motion_state()
		if not expected.is_empty():
			var row: Dictionary = expected[tick]
			var at := Vector3(row.position[0],row.position[1],row.position[2])
			var velocity := Vector3(row.velocity[0],row.velocity[1],row.velocity[2])
			equal_positions = equal_positions and player.position == at
			equal_velocities = equal_velocities and player.velocity == velocity
			if JSON.stringify(motion)==JSON.stringify(row.motion):
				motor_equal_ticks += 1
		actual.append({"position":[player.position.x,player.position.y,player.position.z],"velocity":[player.velocity.x,player.velocity.y,player.velocity.z],"motion":motion})
	if rope_enabled and bunny_enabled:
		write_json("carry-native-trace.json" if expected.is_empty() else "carry-fixed-trace.json",actual)
	return {"finish":level.is_finish_at(player.position),"checkpoints":reached.duplicate(),"grapples":player.grapple_count,"position":str(player.position),"ticks":commands.size(),"first_finish_tick":first_finish_tick,"grounded":bool(player.call("is_grounded")),"body_comparison_performed":not expected.is_empty(),"all_body_positions_exact":equal_positions if not expected.is_empty() else null,"all_body_velocities_exact":equal_velocities if not expected.is_empty() else null,"complete_motor_equal_ticks":motor_equal_ticks}

func run() -> void:
	for action: String in ["jump","move_forward","move_back","move_left","move_right","crouch","look_left","look_right","look_up","look_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
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
	player.apply_settings(PRESETS.source_settings("server128", {}))
	await physics_frame
	var gallery: Dictionary = await route(false,0)
	var shaft: Dictionary = await route(true,140)
	var baselines_ok: bool = gallery.finish and gallery.replay.finish and gallery.descending_catch and gallery.checkpoints.size()==3 and gallery.position==gallery.replay.position and gallery.ticks==1810 and shaft.finish and shaft.replay.finish and shaft.descending_catch and shaft.checkpoints.size()==3 and shaft.position==shaft.replay.position and shaft.ticks==1108
	var results: Array = []
	var best: Dictionary = {}
	for hold_ticks: int in [120,130,135,140,145,150,155,160,170]:
		var result := await carry(hold_ticks)
		print(JSON.stringify(result))
		results.append(result)
		if result.finish and result.checkpoints.size()==3 and (best.is_empty() or result.ticks < best.ticks):
			best = result.duplicate(true)
			write_json("carry.json",tape)
			write_json("carry-events.json",event_tape(tape))
			write_json("carry-trace.json",trace)
	var replayed: Dictionary = {}
	var no_rope: Dictionary = {}
	var no_bunny: Dictionary = {}
	var stopping_tail: Dictionary = {}
	if not best.is_empty():
		var commands: Array = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("carry.json")))
		var expected: Array = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("carry-trace.json")))
		replayed = await replay_carry(commands,expected)
		no_rope = await replay_carry(commands,expected,false)
		no_bunny = await replay_carry(commands,expected,true,false)
		var stopped: Array = commands.duplicate(true)
		for tick: int in range(commands.size(),1152):
			var cmd: Dictionary = commands[-1].duplicate()
			cmd.rope = false
			cmd.forward = false
			cmd.jump = false
			cmd.left = false
			stopped.append(cmd)
		stopping_tail = await replay_carry(stopped,[])
		write_json("carry-stopped.json",stopped)
		write_json("carry-stopped-events.json",event_tape(stopped))
	var early_fails: bool = not results[2].finish and results[2].hold==135
	var late_fails: bool = not results[7].finish and results[7].hold==160
	var ok: bool = write_ok and baselines_ok and not best.is_empty() and best.hold==155 and best.ticks==811 and best.ticks<shaft.ticks and best.grapples==1 and best.receiver_hops==2 and replayed.finish and replayed.checkpoints.size()==3 and replayed.grapples==1 and replayed.all_body_positions_exact and replayed.all_body_velocities_exact and not no_rope.finish and no_rope.grapples==0 and not no_bunny.finish and early_fails and late_fails and stopping_tail.first_finish_tick==811 and stopping_tail.finish and stopping_tail.grounded and stopping_tail.grapples==1 and level.geometry_hash()=="544896293f49e30f6cecb277b4cfba5298a820ad662a044ab4418db4a17228f5"
	write_json("summary.json",{"ok":ok,"existing_gallery":gallery,"existing_shaft":shaft,"candidates":results,"best":best,"fixed_replay":replayed,"no_rope_control":no_rope,"no_bunny_control":no_bunny,"early_release_fails":early_fails,"late_release_fails":late_fails,"stopping_tail":stopping_tail,"geometry_hash":level.geometry_hash()},"\t")
	mouse(false)
	player.free()
	level.free()
	await process_frame
	quit(0 if ok and write_ok else 1)

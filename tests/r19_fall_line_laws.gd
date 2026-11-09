extends "res://tests/r19_fall_line_route.gd"
## normal authored spawn, input-earned first landing, deliberate wait/fall and real R/F controls.
var phase := "approach"
var results: Array = []
var pause_running := false
var paused_snapshot: Dictionary
var fall_tick := -1
var observations: Array = []
var phase_tick := 0
var current_tick := 0

func _route_finished(_tick: int) -> bool:
	return false

func _control_source(tick: int) -> void:
	current_tick = tick
	if phase == "approach":
		if opts.has("checkpoint") and game.checkpoint_index == 1:
			_want({},tick)
			var before: Array = level.platform_state()
			_control_key(KEY_F)
			results.append({"check":"earned solid checkpoint F resets prior drops and preserves practice eligibility","ok":game.checkpoint_index == 1 and game.practice_reason == "practice" and not game.clean_eligible and restored() and before.any(func(r: Array) -> bool: return r[3]),"before":before,"after":level.platform_state(),"p":plain(player.position)})
			_end("checkpoint complete",tick+1)
			return
		if not opts.has("checkpoint") and int(level.platforms[0].armed) >= 0:
			phase = "wait"
			phase_tick = tick
			_want({},tick)
		else:
			super._control_source(tick)
		return
	_want({},tick)
	if phase == "wait":
		var row: Dictionary = level.platforms[0]
		if not pause_running and level.clock_tick - int(row.armed) >= 64:
			pause_running = true
			pause_check()
		if row.dropped and player.position.y < 0 and player.is_grounded():
			fall_tick = tick
			results.append({"check":"waited on deck and fell to real lower recovery collision","ok":_support(player.position).begins_with("catch"),"support":_support(player.position),"p":plain(player.position),"platforms":level.platform_state(),"transitions":level.transitions.duplicate(true)})
			if opts.has("return"):
				nodes = [{"p":Vector2(14,-20)},{"p":Vector2(14,20)},{"p":Vector2(0,20)},{"p":Vector2(0,12)}]
				node_index = 0
				node_from = Vector2(player.position.x,player.position.z)
				phase = "return"
				return
			_control_key(KEY_F)
			phase = "practice"
			phase_tick = tick
	elif phase == "return":
		super._control_source(tick)
		if node_index >= nodes.size() and player.is_grounded() and player.position.y > 7.9:
			results.append({"check":"input-earned physical lower ramp return reaches start with deck still dropped","ok":_support(player.position).begins_with("start") and level.platforms[0].dropped,"p":plain(player.position),"support":_support(player.position)})
			_want({},tick)
			_control_key(KEY_R)
			phase = "return_restart"
			phase_tick = tick
	elif phase == "return_restart" and tick > phase_tick+2:
		results.append({"check":"R after real physical return restores every collision","ok":restored() and game.clean_eligible,"p":plain(player.position)})
		_end("physical return complete",tick+1)
	elif phase == "practice" and tick > phase_tick+2:
		results.append({"check":"F checkpoint practice restored every body and visible deck","ok":restored() and game.practice_reason == "practice" and not game.clean_eligible,"platforms":level.platform_state(),"reset_serial":level.reset_serial})
		_control_key(KEY_R)
		phase = "restart"
		phase_tick = tick
	elif phase == "restart" and tick > phase_tick+2:
		results.append({"check":"R normal restart restored every body and clean eligibility","ok":restored() and game.clean_eligible and game.respawn_count == 0,"platforms":level.platform_state(),"reset_serial":level.reset_serial})
		game.select_map("breakwater")
		player = game.player
		level = game.level
		phase = "original"
		phase_tick = tick
	elif phase == "original":
		_want({"w":true},tick)
		if tick > phase_tick+40:
			results.append({"check":"return to original map restores pure F2 and ordinary movement","ok":game.map_id == "breakwater" and game.preset_id == "server128" and player.get_script().resource_path == "res://scripts/r15_source_player.gd" and not game.is_lab() and player.velocity.length() > 1,"runner":player.get_script().resource_path,"identity":game.motion_identity(),"p":plain(player.position)})
			_end("laws complete",tick+1)

func pause_check() -> void:
	paused_snapshot = {"platforms":level.platform_state(),"clock":level.clock_tick,"elapsed":game.elapsed,"p":plain(player.position)}
	_control_key(KEY_ESCAPE)
	for i: int in 32:
		await physics_frame
	var after := {"platforms":level.platform_state(),"clock":level.clock_tick,"elapsed":game.elapsed,"p":plain(player.position)}
	results.append({"check":"Esc pause freezes platform clock, bodies, course clock and position for32 physics-frame signals","ok":game.paused and paused_snapshot == after,"before":paused_snapshot,"after":after})
	_control_key(KEY_ESCAPE)

func restored() -> bool:
	return level.platforms.all(func(r: Dictionary) -> bool: return int(r.armed) == -1 and not r.dropped and r.body.collision_layer == 1 and r.visual.visible and r.visual.position == Vector3.ZERO) and level.platform_state().all(func(r: Array) -> bool: return bool(r[5]))

func _control_key(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _observe(tick: int) -> void:
	if phase != "original":
		observations.append({"tick":tick,"phase":phase,"p":plain(player.position),"platforms":level.platform_state(),"clock":level.clock_tick,"grounded":player.is_grounded(),"motion":plain(player.get_motion_state())})
	if tick > 2500:
		_end("budget",tick+1)

func _end(reason: String, tick: int) -> void:
	if _closing:
		return
	_closing = true
	done = true
	_want({},tick)
	var passed := results.size() == (1 if opts.has("checkpoint") else (4 if opts.has("return") else 5)) and results.all(func(r: Dictionary) -> bool: return r.ok)
	_write("laws.json",{"pass":passed,"reason":reason,"checks":results,"fall_tick":fall_tick,"observations":observations})
	print("fall-line laws pass=",passed," checks=",results.size()," phase=",phase)
	await game.request_quit(0 if passed else 1)

extends SceneTree
## input-only two-body handoff, miss/retry and fresh-host exact tape replay.
const HOST := preload("res://scripts/game.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
var game: Node
var output := ""
var centre_path := ""
var loadout := "anchors"
var centre: Array = []
var tape: Array = []
var rows: Array = []
var tick := 0
var local_tick := 0
var parked_tick := -1
var ready := false
var replay := false
var throw_done := false
var prior_phase := "first"
var normal_identity := {}
var paused_checks := {}
var pause_left := 0
var paused_state := {}
var started_ms := Time.get_ticks_msec()
func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg.begins_with("--centre="):
			centre_path = arg.trim_prefix("--centre=")
		if arg.begins_with("--loadout="):
			loadout = arg.trim_prefix("--loadout=")
	start.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started_ms > 45000:
		push_error("envelope test watchdog")
		quit(1)
	return false
func event(row: Dictionary) -> void:
	if row.has("action") and row.has("strength"):
		row = row.duplicate(true)
		row.strength = clampf(float(row.strength),0.0,1.0)
	if not replay:
		var saved := row.duplicate(true)
		saved.time = tick/128.0
		if saved.has("button"):
			saved.button = int(saved.button)
		tape.append(saved)
	var input: InputEvent
	if row.has("key"):
		var key := InputEventKey.new()
		key.keycode = OS.find_keycode_from_string(row.key)
		key.physical_keycode = key.keycode
		key.pressed = row.pressed
		input = key
	elif row.has("mouse"):
		var mouse := InputEventMouseMotion.new()
		mouse.relative = Vector2(row.mouse[0],row.mouse[1])
		mouse.screen_relative = mouse.relative
		input = mouse
	elif row.has("action"):
		var action := InputEventAction.new()
		action.action = row.action
		action.pressed = row.pressed
		action.strength = row.get("strength",1.0)
		input = action
	else:
		var button := InputEventMouseButton.new()
		button.button_index = int(row.button)
		button.pressed = row.pressed
		input = button
	Input.parse_input_event(input)
	Input.flush_buffered_events()
func key(name: String) -> void:
	event({"key":name,"pressed":true})
	event({"key":name,"pressed":false})
func start() -> void:
	assert(not output.is_empty() and not centre_path.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	centre = JSON.parse_string(FileAccess.get_file_as_string(centre_path))
	game = HOST.new()
	game.map_id = "plan-yard"
	game.motor = "server128"
	game.persist = false
	game.record_runs = true
	game.recordings_dir = output.path_join("replay-runs" if replay else "runs")
	game.seed_from_r15 = false
	game.set_window_title = false
	root.add_child(game)
	await process_frame
	tick = 0
	local_tick = 0
	throw_done = false
	prior_phase = "first"
	paused_checks = {}
	pause_left = 0
	if not replay:
		var setup := ["Tab","Delete","2","5","8","Enter"]
		if loadout == "block":
			setup = ["Tab","Delete","B","5","A","2","5","Enter"]
		for code: String in setup:
			key(code)
		normal_identity = game.motion_identity().duplicate(true)
		for code: String in ["Tab","Q","Enter"]:
			key(code)
	else:
		for row: Dictionary in tape:
			if float(row.time) == 0:
				event(row)
	assert(game.level.envelope_enabled and not game.clean_eligible)
	assert(not game.player.run_review_unavailable_reason().is_empty())
	assert(game.motion_identity() != normal_identity)
	assert(not game.level.is_finish_at(game.level.finish_position))
	ready = true
func baseline(at_tick: int) -> void:
	for row: Dictionary in centre:
		if not row.has("key") and roundi(float(row.time)*128) == at_tick and at_tick > 0:
			event(row)
func aim(at: Vector3) -> void:
	var player: CharacterBody3D = game.player
	var direction: Vector3 = at-player.camera.global_position
	var time := direction.length()/18.0
	direction.y += 4.9*time*time
	var yaw := atan2(-direction.x,-direction.z)
	var pitch := atan2(direction.y,Vector2(direction.x,direction.z).length())
	var meta: Dictionary = game.look_metadata()
	event({"mouse":[-wrapf(yaw-player.yaw,-PI,PI)/float(meta.yaw_rad_per_count),(player.pitch-pitch)/float(meta.pitch_rad_per_count)]})
func finish_first_body() -> void:
	var player: CharacterBody3D = game.player
	var direction := Vector3(-player.global_position.x,0,-49-player.global_position.z)
	var yaw := atan2(-direction.x,-direction.z)
	var meta: Dictionary = game.look_metadata()
	event({"mouse":[-wrapf(yaw-player.yaw,-PI,PI)/float(meta.yaw_rad_per_count),player.pitch/float(meta.pitch_rad_per_count)]})
	for index: int in [1,2]:
		event({"button":index,"pressed":false})
	for id: String in ["move_back","move_left","move_right"]:
		event({"action":id,"pressed":false,"strength":0.0})
	event({"action":"move_forward","pressed":true,"strength":1.0})
	var jump: bool = loadout != "block" or player.global_position.z < -18.0
	event({"action":"jump","pressed":jump,"strength":1.0 if jump else 0.0})
func _physics_process(_delta: float) -> bool:
	if not ready:
		return false
	var relay: Node3D = game.player.envelope
	if pause_left > 0:
		assert(game.paused and relay.snapshot() == paused_state.relay and game.elapsed == paused_state.clock and game.player.global_position == paused_state.position)
		pause_left -= 1
		if pause_left == 0:
			key("Escape")
		tick += 1
		return false
	if game.finished or game.respawn_count > 0 or tick > 128*24:
		finish()
		return false
	if replay:
		for row: Dictionary in tape:
			if roundi(float(row.time)*128) == tick and tick > 0:
				event(row)
	else:
		if relay.phase != prior_phase:
			if relay.phase == "carry":
				local_tick = 0
				key("E")
			elif relay.phase == "resumed":
				local_tick = parked_tick
				finish_first_body()
			prior_phase = relay.phase
		if relay.phase in ["carry","resumed"] and not paused_checks.has(relay.phase):
			paused_checks[relay.phase] = true
			key("Escape")
			paused_state = {"relay":relay.snapshot().duplicate(true),"clock":game.elapsed,"position":game.player.global_position}
			for code: String in ["E","K","Tab"]:
				key(code)
			pause_left = 3
			tick += 1
			return false
		var at: Vector3 = game.player.global_position
		var waiting_zone: bool = at.y > 8.8 and at.z < -21
		if loadout == "block":
			waiting_zone = at.y > 7.8 and at.y < 8.2 and at.z < -13
		if relay.phase == "first" and game.player.is_grounded() and waiting_zone:
			parked_tick = local_tick
			key("K")
			for id: String in ["move_forward","move_back","move_left","move_right","jump"]:
				event({"action":id,"pressed":false,"strength":0.0})
			for index: int in [1,2]:
				event({"button":index,"pressed":false})
		else:
			if relay.phase == "resumed":
				finish_first_body()
			elif relay.phase == "carry" and not throw_done and relay.misses >= 1 and game.player.global_position.distance_to(relay.waiting.position) < 8.0:
				for index: int in [1,2]:
					event({"button":index,"pressed":false})
				aim(relay.waiting.position+Vector3.UP)
				key("E")
				throw_done = true
			elif relay.phase != "carry" or not throw_done:
				baseline(local_tick)
			local_tick += 1
	tick += 1
	return false
func finish() -> void:
	ready = false
	var relay: Node3D = game.player.envelope
	var foot: Vector3 = relay.waiting.get("position",Vector3.ZERO)
	var support: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*0.05,foot-Vector3.UP*0.15,1,[game.player.get_rid()]))
	var support_name := str(support.collider.name) if not support.is_empty() else "<none>"
	var row := {"finished":game.finished,"finish_kind":game.finish_kind,"respawns":game.respawn_count,
		"ticks":tick,"time":game.elapsed,"total":game.elapsed,"position":str(game.player.global_position),
		"identity":game.motion_identity(),"relay":relay.snapshot(),"waiting_support":support_name,"loadout":loadout,"parked_tick":parked_tick,"replay":replay}
	print(JSON.stringify(row))
	if not game.finished or game.respawn_count > 0:
		push_error("envelope route failed before its practice finish")
		game.request_quit(1)
		return
	assert(support_name == ("PlanLift" if loadout == "block" else "caisson_rear"))
	assert(game.finished and game.finish_kind == "practice" and game.respawn_count == 0)
	assert(relay.phase == "resumed" and relay.misses >= 1 and relay.throws >= 2)
	assert(not game.clean_eligible and game.best_time < 0 and game.open_best_time < 0 and not game.session.ghost.loaded)
	assert(game.hud.practice_tag.text == game.level.practice_message())
	assert(game.hud._finish_result.text == game.level.practice_message())
	var finishes := 0
	for name: String in DirAccess.get_files_at(game.recordings_dir):
		var read := READER.read(game.recordings_dir.path_join(name),false)
		assert(read.ok)
		if not READER.identity_matches(read.header.identity,game.motion_identity()).is_empty():
			continue
		assert(not bool(read.header.metadata.clean_at_start))
		if str(read.seal.outcome.get("kind","")) == "finish":
			finishes += 1
			assert(not bool(read.seal.outcome.clean))
	assert(finishes == 1)
	rows.append(row)
	for id: String in ["move_forward","move_back","move_left","move_right","jump"]:
		Input.action_release(id)
	for index: int in [1,2]:
		event({"button":index,"pressed":false})
	if not replay:
		FileAccess.open(output.path_join("envelope-tape.json"),FileAccess.WRITE).store_string(JSON.stringify(tape))
		replay = true
		game.free()
		game = null
		start.call_deferred()
	else:
		for field: String in ["ticks","time","total","position","identity","relay","waiting_support"]:
			assert(rows[0][field] == rows[1][field],field)
		var first_seconds: float = relay.first_seconds
		var recovery_seen := false
		var prior_z: float = game.player.global_position.z
		event({"action":"move_forward","pressed":true,"strength":1.0})
		for i: int in 384:
			await physics_frame
			if game.player.global_position.z > prior_z+5:
				recovery_seen = true
			prior_z = game.player.global_position.z
			assert(relay.phase == "resumed" and relay.first_seconds == first_seconds)
		assert(recovery_seen)
		event({"action":"move_forward","pressed":false,"strength":0.0})
		key("R")
		assert(relay.phase == "first" and relay.waiting.is_empty() and not game.clean_eligible)
		for i: int in 40:
			await physics_frame
		key("K")
		assert(relay.phase == "carry")
		key("R")
		assert(relay.phase == "first" and relay.waiting.is_empty() and not game.clean_eligible)
		for i: int in 40:
			await physics_frame
		key("K")
		assert(relay.phase == "carry")
		key("F")
		assert(relay.phase == "first" and relay.waiting.is_empty() and not game.clean_eligible)
		key("Tab")
		key("Q")
		key("Enter")
		assert(not game.level.envelope_enabled and game.motion_identity() == normal_identity and game.clean_eligible)
		assert(game.player.run_review_unavailable_reason().is_empty())
		FileAccess.open(output.path_join("envelope.json"),FileAccess.WRITE).store_string(JSON.stringify({"ok":true,"runs":rows},"\t"))
		game.request_quit(0)

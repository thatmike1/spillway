extends SceneTree
## independent review of the shared tick and real input/collision adapter.
## seeded episodes declare every state write in setup; subsequent changes are input only.

const M := preload("res://scripts/r14_source_motion.gd")
const P := preload("res://scripts/r14_source_player.gd")
const MAIN := preload("res://scripts/spillway_main.gd")
const U := 0.0254
const KEYS := {"w": KEY_W, "s": KEY_S, "a": KEY_A, "d": KEY_D, "space": KEY_SPACE, "ctrl": KEY_CTRL}
signal finished

class FreeWorld:
	extends RefCounted
	func walk_move(s: Dictionary, dt: float) -> void:
		s.position += s.velocity * dt
	func air_move(s: Dictionary, dt: float) -> void:
		s.position += s.velocity * dt
	func probe_ground(_s: Dictionary) -> Vector3:
		return Vector3.ZERO

class ClockProbe:
	extends Node
	var suite: Object
	var early: bool
	func _physics_process(dt: float) -> void:
		suite.call("before" if early else "after", dt)

var out := "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/source-review"
var player: CharacterBody3D
var world: Node3D
var checks: Array = []
var episodes: Dictionary = {}
var traces: Array = []
var frames: Array = []
var tick := 0
var active := false
var pre_step := 0
var start := Vector3.ZERO
var held: Array = []
var rates: Array = []
var ordering_errors := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	_run.call_deferred()

func check(name: String, pass_: bool, detail: Variant = null) -> void:
	checks.append({"name": name, "pass": pass_, "detail": plain(detail)})
	if not pass_:
		print("FAIL ", name, " ", detail)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out.path_join("traces"))
	MAIN.bind_inputs()
	world = Node3D.new()
	root.add_child(world)
	box("floor", Vector3(0,-32,0), Vector3(20000,64,20000))
	# independent fixtures, in source units; isolated lanes avoid accidental contacts.
	box("step18", Vector3(1000,9,-500), Vector3(256,18,600))
	box("step19", Vector3(1500,9.5,-500), Vector3(256,19,600))
	box("wall", Vector3(2500,128,-250), Vector3(512,256,32))
	box("corner_x", Vector3(3500+200,128,-100), Vector3(32,256,600))
	box("corner_z", Vector3(3500,128,-400), Vector3(600,256,32))
	# a short 50 degree ramp to a coplanar deck; supports two-contact landing probes.
	var a := deg_to_rad(50.0)
	var ramp_normal := Basis(Vector3.RIGHT,a) * Vector3.UP
	box("ramp50", Vector3(5000,128*tan(a),-128)-ramp_normal*32, Vector3(256,64,256/cos(a)), a)
	player = P.new()
	root.add_child(player)
	check("axis_aligned_box_dimensions",player.collision.shape is BoxShape3D and (player.collision.shape.size as Vector3).distance_to(Vector3(32,72,32)*U)<1e-6)
	for early in [true,false]:
		var clock := ClockProbe.new()
		clock.suite = self
		clock.early = early
		clock.process_physics_priority = -1000 if early else 1000
		root.add_child(clock)
	await process_frame
	shared_vectors()
	await live_vectors()
	await ground_cases()
	await input_cases()
	await collision_cases()
	check("one_motor_step_per_physics_tick", ordering_errors == 0, ordering_errors)
	check("actual_delta_and_engine_rate", rates.all(func(r): return absf(r[0]-1.0/r[1])<1e-9 and r[1]==r[2] and r[3]==1.0), rates.size())
	var failed := checks.filter(func(c): return not c.pass)
	var f := FileAccess.open(out.path_join("summary.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(plain({"engine":Engine.get_version_info(),"checks":checks,"failed":failed.size(),"episodes":episodes}),"\t"))
	f.close()
	for key in KEYS:
		send_key(key,false)
	print("source independent review: %d checks, %d failed; %s" % [checks.size(),failed.size(),out])
	quit(0 if failed.is_empty() else 1)

func box(label: String, center: Vector3, size: Vector3, tilt := 0.0) -> void:
	var b := StaticBody3D.new()
	b.name = label
	b.transform = Transform3D(Basis(Vector3.RIGHT,tilt),center*U)
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size*U
	c.shape = shape
	b.add_child(c)
	world.add_child(b)

func shared_vectors() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/r14_source_vectors.json"))
	for i in data.air.size():
		var r: Dictionary = data.air[i]
		var cv := M.preset("csgo_server")
		cv.tickrate = r.hz
		cv.sv_airaccelerate = r.airaccelerate
		var s := M.new_state(Vector3(0,1000,0))
		s.velocity = Vector3(r.velocity_before_u_s[0],300,r.velocity_before_u_s[1])
		s.surface = r.surface_friction
		var dir := Vector3(r.wish_direction[0],0,r.wish_direction[1])
		# right(yaw)=(cos(yaw),0,-sin(yaw)); no production direction helper.
		M.step(s,{"side":1.0,"yaw":atan2(-dir.z,dir.x)},cv,1.0/r.hz,FreeWorld.new())
		var expected := Vector2(r.velocity_after_u_s[0],r.velocity_after_u_s[1])
		check("frozen_shared_tick_%02d"%i,Vector2(s.velocity.x,s.velocity.z).distance_to(expected)<0.00015)
		check("frozen_shared_travel_%02d"%i,Vector2(s.position.x,s.position.z).distance_to(expected/float(r.hz))<0.0001)
	# classification happens before final half gravity, then affects the next tick.
	for hz in [64,128]:
		for aa in [12.0,100.0]:
			for surface in [1.0,0.25]:
				for budget in ["legacy","capped"]:
					var cv := M.preset("csgo_server")
					cv.sv_airaccelerate = aa
					cv.air_budget = budget
					var s := M.new_state(Vector3(0,1000,0))
					s.velocity = Vector3(250,300,0)
					s.surface = surface
					M.step(s,{"side":1.0,"yaw":PI/2},cv,1.0/hz,FreeWorld.new())
					var addition: float = minf(30,aa*(30.0 if budget=="capped" else 250.0)*surface/hz)
					check("shared_cap_budget_%d_aa%d_f%s_%s"%[hz,aa,surface,budget],Vector2(s.velocity.x,s.velocity.z).distance_to(Vector2(250,-addition))<0.0002)
		var cv_jump := M.preset("csgo_server")
		var jump := M.new_state()
		jump.grounded = true
		var apex := 0.0
		var err := 0.0
		for n in range(1,hz):
			M.step(jump,{"jump":n==1},cv_jump,1.0/hz,FreeWorld.new())
			var expected_y: float = 301.993377*n/hz-400.0*n*(n+1)/(hz*hz)
			err = maxf(err,absf(jump.position.y-expected_y))
			apex = maxf(apex,jump.position.y)
		check("shared_standing_gravity_order_%d"%hz,err<0.0002,{"worst_position_error_u":err,"apex_u":apex})
		for categorize_vy in [-0.01,0.0,0.01,140.0,140.01]:
			var cv := M.preset("csgo_server")
			var s := M.new_state(Vector3(0,1000,0))
			s.velocity.y = categorize_vy+400.0/hz
			M.step(s,{},cv,1.0/hz,FreeWorld.new())
			var expected := 0.25 if categorize_vy>0 and categorize_vy<=140 else 1.0
			check("deadstrafe_boundary_%d_%s"%[hz,categorize_vy],s.surface==expected,{"surface":s.surface,"expected":expected})

func run_episode(name: String, hz: int, sequence: Array, pose := Vector3(0,0.5,0), seed := Vector3.ZERO, preset := "csgo_server", overrides := {}, grounded := true) -> Array:
	active = false
	for key in KEYS:
		send_key(key,false)
	held = []
	player.call("apply_preset",preset,overrides)
	player.settings.tickrate = hz
	player.call("apply_engine_rate")
	player.call("reset_to",Transform3D(Basis.IDENTITY,pose*U))
	player.velocity = seed*U
	# labelled setup: grounded start is declared, never adjusted after input begins.
	player.state.grounded = grounded
	player.state.ground_ticks = 100 if grounded else 0
	player.state.ground_normal = Vector3.UP if grounded else Vector3.ZERO
	frames = sequence
	traces = []
	tick = 0
	active = true
	await finished
	var result := traces.duplicate(true)
	var lines := PackedStringArray()
	for row in result:
		lines.append(JSON.stringify(plain(row)))
	var f := FileAccess.open(out.path_join("traces").path_join(name+".jsonl.gz"),FileAccess.WRITE)
	f.store_buffer(("\n".join(lines)+"\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	f.close()
	episodes[name] = {"hz":hz,"preset":preset,"overrides":overrides,"setup":{"position_u":pose,"velocity_u_s":seed,"grounded":grounded,"state_seed":seed!=Vector3.ZERO},"frames":sequence,"final":result[-1]}
	return result

func before(_dt: float) -> void:
	if not active:
		return
	pre_step = player.tape_step_count
	start = player.global_position/U
	var frame: Dictionary = frames[tick]
	var wanted: Array = frame.get("keys",[])
	for key in KEYS:
		if (key in held) != (key in wanted):
			send_key(key,key in wanted)
	held = wanted.duplicate()
	if frame.has("mouse"):
		var mouse := InputEventMouseMotion.new()
		mouse.relative = Vector2(frame.mouse,0)
		mouse.screen_relative = mouse.relative
		Input.parse_input_event(mouse)
	if frame.get("wheel",false):
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		Input.parse_input_event(wheel)
		wheel = wheel.duplicate()
		wheel.pressed = false
		Input.parse_input_event(wheel)
	Input.flush_buffered_events()

func after(dt: float) -> void:
	if not active:
		return
	if player.tape_step_count != pre_step+1:
		ordering_errors += 1
	var s: Dictionary = player.call("get_motion_state")
	var pos := player.global_position/U
	traces.append({"tick":tick,"p":pos,"v":player.velocity/U,"fd":(pos-start)/dt,"d":pos-start,"requested":s.requested_velocity/U,"grounded":s.grounded,"events":s.events,"surface":s.air_surface,"wish":s.wish_dir,"wishspeed":s.wish_speed_u,"contacts":s.contacts,"steps":s.step_ups,"stamina":s.stamina,"jumps":s.jump_count,"perfect":s.perfect_count,"yaw":s.yaw,"body_yaw":player.global_rotation.y,"ledger":s.ledger,"dt":dt,"input":frames[tick]})
	rates.append([dt,int(player.settings.tickrate),Engine.physics_ticks_per_second,Engine.time_scale])
	tick += 1
	if tick == frames.size():
		active = false
		finished.emit()

func send_key(key: String, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEYS[key]
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func live_vectors() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/r14_source_vectors.json"))
	for i in data.air.size():
		var r: Dictionary = data.air[i]
		var dir := Vector2(r.wish_direction[0],r.wish_direction[1])
		var yaw := atan2(-dir.y,dir.x)
		var counts := -yaw/deg_to_rad(5.729578*0.022)
		var seed := Vector3(r.velocity_before_u_s[0],100 if r.surface_friction==0.25 else 300,r.velocity_before_u_s[1])
		var rows := await run_episode("frozen_live_%02d"%i,r.hz,[{}, {"keys":["d"],"mouse":counts}],Vector3(0,1000,0),seed,"csgo_server",{"sv_airaccelerate":r.airaccelerate},false)
		var expected := Vector2(r.velocity_after_u_s[0],r.velocity_after_u_s[1])
		var got: Vector3 = rows[1].v
		check("frozen_live_vector_%02d"%i,Vector2(got.x,got.z).distance_to(expected)<0.001,{"got":got,"expected":expected})
		var fd: Vector3 = rows[1].fd
		check("frozen_live_finite_travel_%02d"%i,Vector2(fd.x,fd.z).distance_to(expected)<0.003,{"fd":fd,"expected":expected})
		check("frozen_live_axis_hull_%02d"%i,absf(rows[1].body_yaw)<1e-7)

func ground_cases() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/r14_source_vectors.json"))
	for i in data.friction.size():
		var r: Dictionary = data.friction[i]
		var seq: Array = []
		for t in maxi(1,int(r.released_ticks)):
			seq.append({})
		var rows := await run_episode("friction_%02d"%i,r.hz,seq,Vector3(0,0.5,0),Vector3(r.initial_speed_u_s,0,0))
		if r.released_ticks>0:
			check("frozen_live_friction_%02d"%i,absf(rows[-1].v.x-float(r.speed_u_s))<0.003,{"got":rows[-1].v.x,"expected":r.speed_u_s})
	for hz in [64,128]:
		for keys in [[],["w"],["s"],["a"],["a","d"]]:
			var rows := await run_episode("overspeed_%d_%s"%[hz,str(keys).replace('"','').replace(' ','')],hz,[{"keys":keys}],Vector3(0,0.5,0),Vector3(0,0,-750))
			var after: float = 750.0*(1.0-5.2/hz)
			var expected := Vector3(0,0,-after)
			if "s" in keys:
				expected.z += 5.5*250.0/hz
			if "a" in keys and not "d" in keys:
				expected.x -= 5.5*250.0/hz
			check("live_ground_projection_%d_%s"%[hz,keys],(rows[0].v as Vector3).distance_to(expected)<0.002,{"got":rows[0].v,"expected":expected})

func input_cases() -> void:
	for hz in [64,128]:
		for mode in ["sync","wrong","reverse","late","overlap","coast"]:
			var seq: Array = []
			var runup := 80 if hz==128 else 40
			for i in runup+int(hz*2):
				var j := i-runup
				var keys: Array = ["w"] if j<0 else ["space"]
				var mouse := 0.0
				if j>=0:
					var side := "a" if (j/(hz/4))%2==0 else "d"
					if mode=="reverse":
						side = "d" if side=="a" else "a"
					if mode!="coast" or j<12:
						keys.append(side)
						if mode=="overlap" and j%17<3:
							keys.append("d" if side=="a" else "a")
					mouse = (-1.0 if (j/(hz/4))%2==0 else 1.0)*(5.0 if hz==128 else 10.0)
					mouse += sin(float(j)*0.7)*0.8
					if mode=="wrong": mouse *= -1.0
					if mode=="late" and j%int(hz/4)<8: mouse = 0
					if mode=="coast" and j>=12: keys = []
				seq.append({"keys":keys,"mouse":mouse})
			var rows := await run_episode("earned_%d_%s"%[hz,mode],hz,seq)
			var worst := 0.0
			var drift := 0.0
			var travel_error := 0.0
			for i in range(1,rows.size()):
				var r: Dictionary = rows[i]
				var prev: Dictionary = rows[i-1]
				if not prev.grounded or "jump" in r.events:
					var expected := Vector2(prev.v.x,prev.v.z)
					var f := (1 if "w" in r.input.keys else 0)-(1 if "s" in r.input.keys else 0)
					var side := (1 if "d" in r.input.keys else 0)-(1 if "a" in r.input.keys else 0)
					var direction := Vector2(-sin(r.yaw)*f+cos(r.yaw)*side,-cos(r.yaw)*f-sin(r.yaw)*side)
					if direction.length()>0:
						direction = direction.normalized()
						expected += direction*maxf(0,minf(100.0*250.0*float(prev.surface)/hz,30.0-expected.dot(direction)))
					worst = maxf(worst,Vector2(r.v.x,r.v.z).distance_to(expected))
					if not r.grounded and r.contacts.is_empty():
						travel_error = maxf(travel_error,Vector2(r.fd.x,r.fd.z).distance_to(expected))
					if mode=="coast" and i>runup+13 and not prev.grounded:
						drift = maxf(drift,Vector2(r.v.x,r.v.z).distance_to(Vector2(prev.v.x,prev.v.z)))
			check("earned_event_equations_%d_%s"%[hz,mode],worst<0.002,{"worst_u_s":worst,"travel_error_u_s":travel_error,"release_drift":drift,"final":rows[-1].v})
			check("earned_free_travel_%d_%s"%[hz,mode],travel_error<0.015,travel_error)
			if mode=="coast": check("release_to_coast_%d"%hz,drift<0.0001,drift)
			if mode=="sync":
				var land_ticks: Array = []
				var jump_ticks: Array = []
				for row in rows:
					if "land" in row.events: land_ticks.append(row.tick)
					if "jump" in row.events: jump_ticks.append(row.tick)
				check("autohop_after_land_before_walk_%d"%hz,land_ticks.size()>=2 and jump_ticks[1]==land_ticks[0]+1 and jump_ticks[2]==land_ticks[1]+1,{"land":land_ticks,"jump":jump_ticks})
		for mode in ["held","wheel","manual","early"]:
			var seq: Array = []
			for i in hz*3:
				var keys: Array = ["w"] if i< hz/2 else []
				if mode=="held" or (mode=="manual" and i%hz==0) or (mode=="early" and i%hz==int(hz/2)):
					keys.append("space")
				seq.append({"keys":keys,"wheel":mode=="wheel" and i%2==0})
			var rows := await run_episode("manual_%d_%s"%[hz,mode],hz,seq,Vector3(0,0.5,0),Vector3.ZERO,"csgo_vanilla",{"wheel_jump":true})
			if mode=="held": check("manual_held_once_%d"%hz,rows[-1].jumps==1,rows[-1].jumps)
			if mode=="wheel": check("manual_wheel_rejumps_%d"%hz,rows[-1].jumps>2,rows[-1].jumps)
			if mode=="manual": check("manual_edges_rejump_%d"%hz,rows[-1].jumps>=3,rows[-1].jumps)
			if mode=="held":
				var landing := -1
				for row in rows:
					if "land" in row.events and landing<0: landing = row.tick
				var early: Array = []
				for i in landing+10:
					early.append({"keys":["space"] if i==0 or (i>=landing-1 and i<=landing+3) or i==landing+5 else []})
				var missed := await run_episode("manual_air_press_not_buffered_%d"%hz,hz,early,Vector3(0,0.5,0),Vector3.ZERO,"csgo_vanilla")
				check("manual_air_press_not_buffered_%d"%hz,missed[landing+3].jumps==1 and missed[-1].jumps==2,{"landing":landing,"at_held":missed[landing+3].jumps,"after_release_repress":missed[-1].jumps})

func collision_cases() -> void:
	for repeat in [1,2]:
		for lane in [1000,1500]:
			var seq: Array = []
			for i in 400: seq.append({"keys":["w"]})
			var rows := await run_episode("step_%d_trial%d"%[lane,repeat],128,seq,Vector3(lane,0.5,150))
			check("step_threshold_%d_trial%d"%[lane,repeat],rows[-1].p.z< -300 if lane==1000 else rows[-1].p.z> -200,rows[-1].p)
			if lane==1000:
				var step_rows := rows.filter(func(r): return "step" in r.events)
				check("step_event_reported_trial%d"%repeat,rows[-1].steps>0 and step_rows.size()>0,{"step_count":rows[-1].steps,"event_rows":step_rows.size()})
		# earned wall approach, held input stop, turn away and jump to recover.
		var seq: Array = []
		for i in 400:
			seq.append({"keys":["w"] if i<240 else (["s","space"] if i==240 else ["s"]),"mouse":15.0 if i>=241 and i<251 else 0.0})
		var rows := await run_episode("wall_approach_recovery_trial%d"%repeat,128,seq,Vector3(2500,0.5,150))
		check("wall_stop_trial%d"%repeat,absf(rows[235].fd.z)<0.1 and absf(rows[235].v.z)<0.1,rows[235])
		check("wall_recovery_trial%d"%repeat,rows[-1].p.z>rows[235].p.z+100 and rows[-1].jumps==1,rows[-1].p)
		var crease: Array = []
		for i in 500: crease.append({"keys":["w","d"] if i<400 else ["s","a"]})
		rows = await run_episode("corner_earned_recovery_trial%d"%repeat,128,crease,Vector3(3500,0.5,0))
		check("corner_stop_trial%d"%repeat,(rows[395].fd as Vector3).length()<0.1 and (rows[395].v as Vector3).length()<0.1,rows[395])
		check("corner_recovery_trial%d"%repeat,rows[-1].p.x<rows[395].p.x-50 and rows[-1].p.z>rows[395].p.z+50)
	# seeded high-speed slope-to-flat transitions: archive all variants, not just a winner.
	for hz in [64,128]:
		for z in [-28.0,-20.0,-12.0,0.0]:
			for y in [8.0,24.0,40.0,64.0]:
				var seq: Array = []
				for i in 4: seq.append({})
				await run_episode("ramp_transition_%d_z%s_y%s"%[hz,z,y],hz,seq,Vector3(5000,y,z),Vector3(0,-2000,2000),"csgo_server",{},false)
	# valid starts above the expanded ramp, repeated with real strafe press/release events.
	for repeat in [1,2]:
		for hz in [64,128]:
			var cap_rows := await run_episode("terminal_cap_%d_trial%d"%[hz,repeat],hz,[{"keys":["d"]},{},{}],Vector3(0,1000,0),Vector3(4000,-4000,4000),"csgo_server",{},false)
			check("post_tick_maxvelocity_%d_trial%d"%[hz,repeat],(cap_rows[0].v as Vector3).abs().max_axis_index()!=1 or absf(cap_rows[0].v.y)<=3500.0,cap_rows[0])
			for speed in [250.0,2000.0]:
				var pose := Vector3(5000,1.3,15) if speed==250 else Vector3(5000,20,0)
				var seed := Vector3(0,-400,250) if speed==250 else Vector3(0,-3000,2000)
				var rows := await run_episode("valid_slope_flat_%d_speed%d_trial%d"%[hz,speed,repeat],hz,[{"keys":["d"]},{},{},{}],pose,seed,"csgo_server",{},false)
				check_slope_flat("seeded_%d_speed%d_trial%d"%[hz,speed,repeat],rows)
		var earned: Array = []
		for i in 320:
			earned.append({"keys":["s"] if i<240 else ["w","space"]})
		var rows := await run_episode("earned_slope_flat_trial%d"%repeat,128,earned,Vector3(5000,140,-100),Vector3.ZERO,"csgo_server",{},false)
		check_slope_flat("earned_trial%d"%repeat,rows)
	# input-earned phase sweep: change the approach height, keep all inputs and geometry.
	for height in [138.5,139.0,139.5,140.5,141.0,142.0,144.0,148.0]:
		var earned: Array = []
		for i in 140: earned.append({"keys":["s"]})
		var rows := await run_episode("earned_slope_phase_y%s"%height,128,earned,Vector3(5000,height,-100),Vector3.ZERO,"csgo_server",{},false)
		check_slope_flat("earned_phase_y%s"%height,rows)
	for repeat in [1,2]:
		for hz in [64,128]:
			var fall: Array = []
			for i in int(hz*4.6):
				fall.append({"keys":["d"] if i<3 else []})
			var rows := await run_episode("earned_terminal_fall_%d_trial%d"%[hz,repeat],hz,fall,Vector3(0,10000,0),Vector3.ZERO,"csgo_server",{},false)
			check("earned_terminal_maxvelocity_%d_trial%d"%[hz,repeat],absf(rows[-1].v.y)<=3500.0,{"post_v":rows[-1].v,"fd":rows[-1].fd,"p":rows[-1].p})
	# surprising uphill travel is an observation, not a defect without a cs runtime reference.
	for hz in [64,128]:
		for aa in [12.0,100.0]:
			var climb: Array = []
			for i in hz*5: climb.append({"keys":["w"]})
			var rows := await run_episode("earned_climb50_%d_aa%d"%[hz,aa],hz,climb,Vector3(5000,0.5,256),Vector3.ZERO,"csgo_server",{"sv_airaccelerate":aa})
			var supported := rows.filter(func(r): return r.p.z< -20 and r.grounded)
			check("steep_face_never_ground_%d_aa%d"%[hz,aa],supported.is_empty())

func check_slope_flat(label: String, rows: Array) -> void:
	var found := false
	for row in rows:
		var ramp := Vector3.ZERO
		var flat := false
		for c in row.contacts:
			if c.body=="ramp50" and c.normal.y>0.6 and c.normal.y<0.7: ramp = c.normal
			if c.body=="floor" and c.normal.y>0.99: flat = true
		if ramp!=Vector3.ZERO and flat:
			found = true
			# two chronological, non-overbounce plane projections retain the first tangent.
			var v: Vector3 = row.requested
			var tangent := v-ramp*v.dot(ramp)
			var expected := Vector2(tangent.x,tangent.z)
			check("sequential_contact_momentum_"+label,Vector2(row.v.x,row.v.z).distance_to(expected)<0.1,{"tick":row.tick,"requested":v,"after":row.v,"sequential_expected":expected,"fd":row.fd,"position":row.p})
	check("slope_flat_probe_contacts_"+label,found)

static func plain(value: Variant) -> Variant:
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Vector2: return [value.x,value.y]
	if value is Dictionary:
		var d := {}
		for k in value: d[str(k)] = plain(value[k])
		return d
	if value is Array:
		var a := []
		for v in value: a.append(plain(v))
		return a
	return value

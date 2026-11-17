extends SceneTree
## two labelled practice probes earn speed from rest; the centre-line run is the negative control.
const LEVEL := preload("res://scripts/maps/sluice_six.gd")
const PLAYER := preload("res://scripts/movement/course_player.gd")
const STYLE := preload("res://scripts/scoring/style.gd")
var output := ""
var level: Node3D
var player: CharacterBody3D
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	call_deferred("run")
func run() -> void:
	var checkout := ProjectSettings.globalize_path("res://").trim_suffix("/")
	if not output.is_absolute_path() or output.simplify_path() == checkout or output.simplify_path().begins_with(checkout+"/"):
		push_error("style evidence needs an absolute --out outside the checkout")
		quit(1)
		return
	Engine.physics_ticks_per_second = 128
	for action: String in ["move_forward","move_back","move_left","move_right","look_left","look_right","look_up","look_down","jump","crouch"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	level = LEVEL.new()
	root.add_child(level)
	level.build()
	player = PLAYER.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.apply_preset("csgo_server", {"sensitivity":2.5,"fov":90.0})
	await physics_frame
	var opening: Dictionary = level.style_opportunities[0]
	var lane: float = opening.center.x
	var rows: Array = []
	for x: float in [lane,0.0]:
		rows.append(await probe(x,opening.center.z))
	var ok: bool = rows[0].safe and rows[0].readonly and rows[0].near.size() > 0 and rows[1].safe and rows[1].readonly and rows[1].near.is_empty()
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("style.json"),FileAccess.WRITE).store_string(JSON.stringify({"ok":ok,"geometry_hash":level.geometry_hash(),"setup":"labelled apron practice, initial velocity zero, no resets during each probe","results":rows},"\t"))
	print("STYLE ",ok," ",JSON.stringify(rows))
	quit(0 if ok else 1)
func probe(lane: float, gate_z: float) -> Dictionary:
	for action: String in ["move_forward","move_left","move_right","jump"]:
		Input.action_release(action)
	var pose: Transform3D = level.spawn
	pose.origin.x = lane
	player.reset_to(pose)
	var style := STYLE.new()
	style.reset({"map":LEVEL.MAP_ID,"preset":"server128","attempt":"labelled-style-probe"})
	var near: Array = []
	var readonly := true
	var safe := true
	var air_tick := 0
	var pair_side := 1.0
	var peak := 0.0
	for tick: int in 1600:
		var p := player.global_position
		var edge := -10000.0
		for d: Dictionary in level.decks:
			if p.z <= d.near+0.4 and p.z >= d.far-0.4:
				edge = d.far
				break
		var jump: bool = (player.is_grounded() and p.z-edge < 1.8) or p.z < gate_z+5.0
		var forward := 1.0
		var side := 0.0
		var yaw := 0.0
		if player.is_grounded():
			air_tick = 0
		if not player.is_grounded() and Vector2(player.velocity.x,player.velocity.z).length() > 3:
			forward = 0.0
			if Vector2(player.velocity.x,player.velocity.z).length() < 10.5 or air_tick % 2 == 1:
				if air_tick % 2 == 0:
					pair_side = -1.0 if p.x > lane else 1.0
				side = pair_side if air_tick % 2 == 0 else -pair_side
				yaw = atan2(-player.velocity.x,-player.velocity.z)
				air_tick += 1
		for action: String in ["move_forward","move_left","move_right","jump"]:
			Input.action_release(action)
		if forward > 0:
			Input.action_press("move_forward")
		if side != 0:
			Input.action_press("move_right" if side > 0 else "move_left")
		if jump:
			Input.action_press("jump")
		var mouse := InputEventMouseMotion.new()
		mouse.screen_relative = Vector2(-wrapf(yaw-player.yaw,-PI,PI)/deg_to_rad(float(player.settings.sensitivity)*float(player.settings.m_yaw)),0)
		player._unhandled_input(mouse)
		player._physics_process(1.0/128)
		var motion: Dictionary = player.get_motion_state()
		var speed := Vector2(player.velocity.x,player.velocity.z).length()/0.0254
		peak = maxf(peak,speed)
		var transform := player.global_transform
		var velocity := player.velocity
		var hull: Vector3 = player.collision.shape.size
		var sample := {"tick":tick,"dt":1.0/128,"physics_hz":128,"elapsed":float(tick)/128,"started":true,"finished":false,"clean":false,"practice_reason":"labelled style probe","checkpoint":0,"respawns":0,"p":player.global_position,"reference_p":player.global_position,"v":player.velocity,"actual_v":motion.actual_velocity,"yaw":player.yaw,"pitch":player.pitch,"grounded":player.is_grounded(),"ducked":false,"motion":motion,"stats":{},"held":{"move_forward":forward>0,"move_right":side>0,"move_left":side<0,"jump":jump,"crouch":false}}
		var events: Array = style.step(sample,player,level)
		readonly = readonly and player.global_transform == transform and player.velocity == velocity and player.collision.shape.size == hull
		for event: Dictionary in events:
			if event.kind == "near_miss" and JSON.stringify(event.geo).contains("inspection"):
				near.append(event)
		if not level.kill_bounds.has_point(player.global_position):
			safe = false
			break
		if player.global_position.z < gate_z-4:
			break
		await physics_frame
	return {"lane_x":lane,"safe":safe,"readonly":readonly,"peak_ups":peak,"feet":str(player.global_position),"near":near,"diagnostics":style.snapshot().diag.near}

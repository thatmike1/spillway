extends "res://scripts/movement/grapple_player.gd"
## isolate planning from the inherited F2 motor and Arc force law.
const OVERLAY := preload("res://scripts/plan/overlay.gd")
const STORE := preload("res://scripts/plan/store.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
const PIECES := preload("res://scripts/plan/pieces.gd")
const ENVELOPE := preload("res://scripts/plan/envelope.gd")
var envelope: Node3D
var plan_store := STORE.new()
var best_plan := {}
var _best_path := ""
var _best_identity := ""
var used_pad := false
var launch_events: Array[Dictionary] = []
var planner: Control
var socket_label: Label3D
var planning := false
func _ready() -> void:
	super()
	# this mesh belongs to this runner; its width never enters rope forces.
	var cable: CylinderMesh = _tether.mesh
	cable.top_radius = 0.004
	cable.bottom_radius = 0.004
	_tether.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tether_material.albedo_color = Color("45636b")
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	planner = OVERLAY.new()
	planner.runner = self
	layer.add_child(planner)
	planner.hide()
	envelope = ENVELOPE.new()
	envelope.runner = self
	add_child(envelope)
	socket_label = Label3D.new()
	socket_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	socket_label.font_size = 32
	socket_label.pixel_size = 0.012
	socket_label.modulate = Color("efe8cf")
	socket_label.outline_modulate = Color("203d45")
	socket_label.outline_size = 5
	add_child(socket_label)
	socket_label.top_level = true
	socket_label.hide()
func _input(event: InputEvent) -> void:
	if bool(get_parent().get("paused")):
		if planning:
			planner.hide()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		if code == KEY_TAB:
			open_plan()
			get_viewport().set_input_as_handled()
		elif planning and code in [KEY_F6,KEY_F7,KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
			if code == KEY_F6:
				planner.save_plan()
			elif code == KEY_F7:
				planner.load_plan()
			else:
				planner.active_slot = posmod(planner.active_slot + (1 if code == KEY_BRACKETRIGHT else -1),3)
				planner.notice = "Slot %d selected." % (planner.active_slot+1)
				planner.queue_redraw()
			get_viewport().set_input_as_handled()
		elif planning and code in [KEY_A,KEY_B,KEY_P]:
			planner.choose_brush({KEY_A:"anchor",KEY_B:"block",KEY_P:"pad"}[code],event.shift_pressed)
			get_viewport().set_input_as_handled()
		elif planning and code == KEY_F8:
			planner.toggle_budget()
			get_viewport().set_input_as_handled()
		elif planning and code == KEY_DELETE:
			planner.clear_pieces()
			get_viewport().set_input_as_handled()
		elif planning and code == KEY_Q:
			var map: Node = get_parent().get("level")
			map.envelope_enabled = not map.envelope_enabled
			map.apply_design(map.plan,map.block_slot,map.pad_slot,map.budget,map.blocks_enabled,map.pads_enabled)
			envelope.reset()
			planner.notice = "K leaves your first body waiting. E delivers; you control it again." if map.envelope_enabled else "Envelope off. Ordinary plan times again."
			planner.queue_redraw()
			get_viewport().set_input_as_handled()
		elif not planning and code in [KEY_K,KEY_E] and envelope != null and envelope.active():
			if code == KEY_K:
				envelope.park()
			else:
				envelope.throw_envelope()
			get_viewport().set_input_as_handled()
		elif planning and code >= KEY_1 and code <= KEY_9:
			planner.toggle_socket(code-KEY_1)
			get_viewport().set_input_as_handled()
		elif planning and code == KEY_ENTER:
			close_plan()
			get_viewport().set_input_as_handled()
func open_plan() -> void:
	var game := get_parent()
	if game.get("level") == null:
		return
	game.restart_run("restart")
	game.session.boundary("restart", {"phase":"planning"})
	planning = true
	block_tether("plan")
	input_enabled = false
	planner.show()
	planner.queue_redraw()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
func close_plan() -> void:
	planning = false
	planner.hide()
	var game := get_parent()
	game.session.boundary("restart", {"phase":"plan_commit"})
	game.course_geometry = game.level.geometry_hash()
	game._refresh_records()
	game.restart_run("restart")
func _physics_process(delta: float) -> void:
	if planning:
		return
	_step_pad()
	super(delta)
	if envelope != null:
		envelope.step(delta)

func reset_to(pose: Transform3D) -> void:
	used_pad = false
	launch_events.clear()
	super(pose)
	if envelope != null:
		envelope.reset()
func _step_pad() -> void:
	if not input_enabled or used_pad or not is_grounded():
		return
	var map: Node = get_parent().get("level")
	if map == null or map.pad_body == null or not map.pad_bounds.has_point(global_position):
		return
	var probe := Vector3.DOWN*float(settings.ground_probe)*U
	var hit := move_and_collide(probe,true,safe_margin,false,4)
	if hit == null:
		var caught := _missed_support(global_position,probe,"probe")
		if not caught.is_empty():
			hit = caught.hit
	if hit == null:
		return
	var support := {}
	for i: int in hit.get_collision_count():
		if hit.get_collider(i) == map.pad_body and hit.get_normal(i).y >= float(settings.sv_walkable_normal):
			support = {"body":str(map.pad_body.name),"normal":hit.get_normal(i),"position":hit.get_position(i)}
	if support.is_empty():
		return
	var impulse: Dictionary = PIECES.LAUNCH.response(velocity/U,Vector3.FORWARD,false)
	if impulse.is_empty():
		return
	used_pad = true
	velocity = (impulse.after_u as Vector3)*U
	state.grounded = false
	state.ground_normal = Vector3.ZERO
	flight = {"takeoff":Vector2(velocity.x,velocity.z).length()/U,"ticks":0,"eligible":0,"good":0,"start_tick":motion_tick+1}
	launch_events.append({"tick":motion_tick+1,"before_u":impulse.before_u,"after_u":impulse.after_u,"position":global_position,"pad":map.pad_slot,"support":support})
func get_motion_state() -> Dictionary:
	var result := super()
	var host := get_parent()
	var map: Node = host.get("level") if host != null else null
	result["plan_yard"] = {"design":map.physical_design() if map != null and map.has_method("physical_design") else {},"pad_used":used_pad,"launches":launch_events.duplicate(true)}
	if envelope != null and envelope.active():
		result["plan_yard"]["envelope"] = envelope.snapshot()
	return result

func experiment_status() -> String:
	var text := super()
	if notice_left_s > 0 and not release_notice.is_empty():
		text = text.replace("\n"+release_notice,"\nPrevious line: "+release_notice)
	return text

func run_review_unavailable_reason() -> String:
	if planning:
		return "Resume the survey and commit with Enter before 3D review or segment practice."
	var host := get_parent()
	var level: Node = host.get("level") if host != null else null
	if level != null and level.get("envelope_enabled") == true:
		return "3D review and segment practice are unavailable in envelope mode. Turn it off in the survey."
	return ""

func _process(delta: float) -> void:
	super(delta)
	sync_ghost_plan()
	var host := get_parent()
	var target := r21_acquisition_snapshot()
	socket_label.visible = not planning and not host.paused and not host.finished and bool(target.ready)
	if socket_label.visible:
		var at: Vector3 = target.position
		socket_label.global_position = at+Vector3.DOWN
		socket_label.text = "%s · +%dm" % [str(target.name).replace("Socket ","A"),roundi(at.y)]
	if planner != null and planning:
		var game := get_parent()
		planner.visible = not game.paused
		input_enabled = false
		if not game.paused:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if game.session.attempt_live:
				game.session.boundary("restart",{"phase":"planning_resume"})
		planner.queue_redraw()
func sync_ghost_plan() -> void:
	var game := get_parent()
	if game == null or game.get("session") == null:
		return
	var session: Node = game.session
	var next_path := str(session.ghost_path) if session.ghost.loaded else ""
	var identity: Dictionary = game.motion_identity()
	var key := JSON.stringify(identity,"",true)
	if next_path == _best_path and key == _best_identity:
		return
	_best_path = next_path
	_best_identity = key
	best_plan = {}
	if next_path.is_empty():
		return
	var read: Dictionary = READER.read(next_path,false)
	if not read.ok or not READER.identity_matches(read.header.get("identity"),identity).is_empty():
		return
	if str(read.header.get("run_id","")) != str(session.ghost.run_id):
		return
	var physics: Dictionary = read.header.get("metadata",{}).get("physics",{})
	for entry: Variant in physics.get("mechanics",[]):
		if entry is Dictionary and entry.get("id") == "plan-yard-design":
			var checked := STORE.from_physical(entry.get("design"))
			if checked.ok:
				best_plan = {"version":PIECES.VERSION,"anchors":checked.design.anchors,"block":checked.design.block,"pad":checked.design.pad}
			return

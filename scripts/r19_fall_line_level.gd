extends Node3D
## contact-triggered falling decks. source motor and inherited scoring stay untouched.
const GEO := preload("res://scripts/r19_course_geometry.gd")
const LEVEL_ID := "r19-fall-line"
const LEVEL_NAME := "Fall Line"
const LEVEL_VERSION := 1
const MAP_ID := "fall-line"
const MAP_ENTRY := {"name": LEVEL_NAME, "theme": "Contact starts the countdown. Keep the next landing in sight.", "kind": "experiment", "experimental": true, "runner": "res://scripts/r15_source_player.gd", "script": "res://scripts/r19_fall_line_level.gd", "instructions": "EXPERIMENTAL · support starts a 2 second countdown. Jump to the next deck or use the wider lower recovery line. R restores all platforms. F practises the last solid checkpoint."}
const LAW := {"version": "fall-line-1", "warning_seconds": 2.0, "support": "grounded plus test-only player-hull support sweep down settings.ground_probe*0.0254, safe_margin, max4 contacts; normal >= 0.7 on this body", "order": "pre-motor priority 0 child after host advances deadline; post-motor priority 10 arms support", "drop": "collision_layer zero at first pre-step whose age reaches ceil(2*physics_hz)", "reset": "R/F reset_state and inherited respawn-count change restore all bodies before motor", "rearm": "once per reset, never on leaving support", "pause": "pausable callbacks; no wall clock", "visual_drop_m": 8.0, "visual_drop_seconds": 0.5}
var level_id := LEVEL_ID
var level_name := LEVEL_NAME
var level_version := LEVEL_VERSION
var variant := MAP_ID
var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 8.04, 12))
var finish_title := "Last solid ground"
var finish_position := Vector3(0, 4.5, -137)
var finish_bounds := AABB(Vector3(-7, 4.2, -152), Vector3(14, 4, 16))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var progress_roles: Array = ["route", "collapse", "recovery"]
var kill_bounds := AABB(Vector3(-24, -12, -162), Vector3(54, 65, 198))
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var mechanics: Array = ["contact-collapse-fall-line-1"]
var manifest: Array[Dictionary] = []
var prisms: Array[Dictionary] = []
var jump_gaps: Array[Dictionary] = []
var platforms: Array[Dictionary] = []
var transitions: Array[Dictionary] = []
var clock_tick := 0
var reset_serial := 0
var _last_respawns := 0
var _built := false

class Deadline:
	extends Node
	var course: Node3D
	func _physics_process(_dt: float) -> void:
		course.advance()

func build() -> void:
	if _built:
		return
	_built = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 10
	var early := Deadline.new()
	early.course = self
	early.process_physics_priority = 0
	add_child(early)
	GEO.deck(self, "start", -7, 7, 0, 18, 8, 0)
	checkpoints.append({"title": "First edge", "pose": spawn, "bounds": AABB(Vector3(-7, 7.8, 0), Vector3(14, 4, 18))})
	for i: int in 10:
		var z := -3.0 - 13.0 * i
		var y := 8.0 - 0.35 * (i + 1)
		var x := [-1.5, 1.5, 0.0][i % 3] as float
		var half := [3.0, 4.0, 5.0][i % 3] as float
		var stage := 0 if i < 3 else (1 if i < 6 else 2)
		var rest := i in [3, 6, 9]
		var id := ("rest_" if rest else "fall_") + str(i)
		GEO.prism(self, id, GEO.rectangle(x-half, x+half, z-10, z, y), y-0.8, stage, "route" if rest else "collapse", "deck")
		if not rest:
			# custom ink travels with the deck; the shared static contour pass omits it.
			prisms[-1].kind = "paint_collapse"
			var visual := Node3D.new()
			visual.name = "FallingVisual_" + str(i)
			add_child(visual)
			get_node("Mesh_deck_" + id).reparent(visual)
			var label := _sign("clock_"+str(i), Vector3(x, y+0.06, z-5), "2.0", -PI/2)
			label.reparent(visual)
			for side: float in [-1.0, 1.0]:
				_paint(visual, "dark", Vector3(x+side*half, y+0.02, z-5), Vector3(0.045, 0.025, 10), Color("263d45"))
			for end: float in [z, z-10]:
				_paint(visual, "lip", Vector3(x, y+0.025, end), Vector3(half*2, 0.05, 0.25), Color("d95b30"))
			platforms.append({"id":id, "body":get_node(id), "visual":visual, "label":label, "probe":Vector3(x,y,z-5), "armed":-1, "drop_tick":-1, "dropped":false})
		else:
			if i != 9:
				checkpoints.append({"title": "Solid rest " + str(stage), "pose":Transform3D(Basis.IDENTITY, Vector3(x, y+0.04, z-2)), "bounds":AABB(Vector3(x-half,y-0.2,z-10),Vector3(half*2,4,10))})
			_sign("rest_"+str(i), Vector3(x,y+0.06,z-5), "SOLID", -PI/2)
		if i > 0:
			segment_bounds.append(AABB(Vector3(-8,y-1,z-10),Vector3(16,6,13)))
	GEO.deck(self, "finish", -7, 7, -152, -130, 4.5, 3)
	# a wide lower line catches missed jumps, then climbs to the finish or returns to start.
	GEO.deck(self, "catch_first", -10, 18, -42, 18, -2, 0, "recovery")
	GEO.deck(self, "catch_middle", -10, 18, -81, -42, -2, 1, "recovery")
	GEO.deck(self, "catch_last", -10, 18, -130, -81, -2, 2, "recovery")
	GEO.prism(self, "return_start", [Vector3(10,-2,-10),Vector3(16,-2,-10),Vector3(16,8,18),Vector3(10,8,18)], -2.8, -1, "recovery", "recovery")
	GEO.deck(self, "start_bridge", -7, 16, 18, 22, 8, 0)
	for half: int in 2:
		var z0 := -110.0-18*half
		var z1 := z0-18
		var y0 := -2.0+3.25*half
		var y1 := y0+3.25
		GEO.prism(self, "finish_return_"+str(half), [Vector3(10,y0,z0),Vector3(16,y0,z0),Vector3(16,y1,z1),Vector3(10,y1,z1)], -2.8, 2, "recovery", "recovery")
	GEO.deck(self, "finish_bridge", 6, 16, -152, -146, 4.5, 3)
	_sign("title", Vector3(0,11,16), "FALL LINE / EXPERIMENTAL\nCONTACT STARTS 2 SECONDS\nR RESTART / F SOLID CHECKPOINT", 0)
	_sign("recovery", Vector3(14,1,-20), "LOWER LINE\nRETURN TO START: +Z\nFINISH: -Z", 0)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("adc5be")
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34,-110,0)
	add_child(light)
	reset_state()

func advance() -> void:
	var host := get_parent()
	if host.get("player") == null:
		return
	if int(host.get("respawn_count")) != _last_respawns:
		reset_state()
	clock_tick += 1
	for row: Dictionary in platforms:
		if int(row.armed) < 0:
			continue
		var age := clock_tick - int(row.armed)
		if not row.dropped and age >= int(row.drop_tick) - int(row.armed):
			row.dropped = true
			(row.body as StaticBody3D).collision_layer = 0
			transitions.append({"tick":clock_tick,"id":row.id,"event":"drop","armed":row.armed})
		if row.dropped:
			(row.visual as Node3D).position.y = -float(LAW.visual_drop_m) * clampf(float(clock_tick-int(row.drop_tick))/Engine.physics_ticks_per_second/float(LAW.visual_drop_seconds),0,1)
			(row.visual as Node3D).visible = clock_tick-int(row.drop_tick) < ceili(float(LAW.visual_drop_seconds)*Engine.physics_ticks_per_second)
		else:
			(row.label as Label3D).text = "%.1f" % (float(int(row.drop_tick)-clock_tick)/Engine.physics_ticks_per_second)
			(row.label as Label3D).modulate = Color("d95b30")

func _physics_process(_dt: float) -> void:
	var player: Node = get_parent().get("player")
	if player == null or not player.call("is_grounded"):
		return
	# the frozen motor's ground probe does not populate get_motion_state().contacts.
	# repeat its test-only hull sweep, never moving the runner or using a route region.
	var distance: float = float(player.get("settings").ground_probe) * 0.0254
	var hit: KinematicCollision3D = player.move_and_collide(Vector3.DOWN*distance,true,player.safe_margin,false,4)
	if hit == null:
		return
	for i: int in hit.get_collision_count():
		if hit.get_normal(i).y < 0.7:
			continue
		for row: Dictionary in platforms:
			if hit.get_collider(i) == row.body and int(row.armed) < 0:
				row.armed = clock_tick
				row.drop_tick = clock_tick + ceili(float(LAW.warning_seconds)*Engine.physics_ticks_per_second)
				transitions.append({"tick":clock_tick,"id":row.id,"event":"support","normal_y":hit.get_normal(i).y,"drop_tick":row.drop_tick,"player_grounded":true,"probe_travel":hit.get_travel().y})

func reset_state() -> void:
	clock_tick = 0
	reset_serial += 1
	_last_respawns = int(get_parent().get("respawn_count")) if get_parent().get("respawn_count") != null else 0
	transitions.clear()
	for row: Dictionary in platforms:
		row.armed = -1
		row.drop_tick = -1
		row.dropped = false
		(row.body as StaticBody3D).collision_layer = 1
		(row.visual as Node3D).position = Vector3.ZERO
		(row.visual as Node3D).visible = true
		(row.label as Label3D).text = "2.0"
		(row.label as Label3D).modulate = Color("263d45")

func platform_state() -> Array:
	var result: Array = []
	for row: Dictionary in platforms:
		var probe: Vector3 = row.probe
		var query := PhysicsRayQueryParameters3D.create(probe+Vector3.UP*0.2,probe+Vector3.DOWN*0.2,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		result.append([row.id,row.armed,row.drop_tick,row.dropped,(row.body as StaticBody3D).collision_layer,not hit.is_empty() and hit.collider == row.body])
	return result

func route_hint(_stage: int, at: Vector3) -> String:
	if at.y < 0:
		return "Lower line: follow the side ramp to the finish, or return uphill to the start."
	return "Contact starts 2 seconds. Orange countdowns show time left. Solid decks are safe."

func is_finish_at(feet: Vector3) -> bool:
	return finish_bounds.has_point(feet)

func geometry_hash() -> String:
	var data: Array = [LEVEL_ID,LEVEL_VERSION,LAW,_identity_value(spawn),_identity_value(finish_bounds),_identity_value(kill_bounds),_identity_value(finish_position),progress_roles,mechanics]
	for piece: Dictionary in manifest:
		data.append([piece.name,piece.stage,piece.role,piece.kind,_identity_value(piece.points)])
	for point: Dictionary in checkpoints:
		data.append([point.title,_identity_value(point.pose),_identity_value(point.bounds)])
	return JSON.stringify(data,"",true,true).sha256_text()

static func _identity_value(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x,value.y,value.z]
	if value is AABB:
		return [_identity_value(value.position),_identity_value(value.size)]
	if value is Transform3D:
		return [_identity_value(value.origin),_identity_value(value.basis.x),_identity_value(value.basis.y),_identity_value(value.basis.z)]
	if value is Array:
		return value.map(func(v: Variant) -> Variant: return _identity_value(v))
	return value

func _sign(id: String, at: Vector3, text: String, tilt: float) -> Label3D:
	var label := Label3D.new()
	label.name = "Sign_"+id
	label.position = at
	label.rotation.x = tilt
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.008
	label.outline_size = 0
	label.modulate = Color("263d45")
	add_child(label)
	return label

func _paint(parent: Node3D, kind: String, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "Art_paint_"+kind
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	mesh.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	parent.add_child(mesh)

extends SceneTree
## labelled isolated coefficient/acquisition fixtures; these are not earned routes.
const RUNNER := preload("res://scripts/r21_tether_player.gd")
const OLD := preload("res://scripts/r20_tether_player.gd")
const MOTION := preload("res://scripts/r14_source_motion.gd")
var output := ""
var checks: Array = []
var identities := {}
var rules_hashes := {}
var identity_hashes := {}
var reel_probes: Array = []
var stresses: Array = []
var player: CharacterBody3D
var world: Node3D
var anchors: Array[Node3D] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func check(ok: bool, name_: String, detail: Variant = null) -> void:
	checks.append({"ok": ok, "check": name_, "detail": detail})
	print("PASS " if ok else "FAIL ", name_, " ", detail if not ok else "")

func button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func step() -> void:
	player._grapple_step(Vector3.ZERO, false, 1.0 / 128)
	player._grapple_press = false

func anchor(id: String, deg: float, distance: float = 20.0) -> Node3D:
	var node := Node3D.new()
	node.name = id
	node.set_meta("r21_anchor_id", id)
	node.set_meta("anchor_name", id)
	node.add_to_group(player.ANCHOR_GROUP)
	world.add_child(node)
	node.global_position = player._eye() + Vector3(sin(deg_to_rad(deg)), 0, -cos(deg_to_rad(deg))) * distance
	anchors.append(node)
	return node

func clear() -> void:
	button(false)
	for node: Node3D in anchors:
		if is_instance_valid(node):
			node.free()
	anchors.clear()
	player.grapple = {}
	player._input_blocked = false
	player._grapple_needs_press = false
	player._clear_r21_candidate()
	player.yaw = 0
	player.pitch = 0
	player.position = Vector3.ZERO

func math_checks() -> void:
	var selected := {"elastic-soft":{"stiffness":90.0,"outward_damping":6.0,"reel_ups":260.0},"elastic-firm":{"stiffness":120.0,"outward_damping":10.0,"reel_ups":260.0},"elastic-arc":{"stiffness":90.0,"outward_damping":10.0,"reel_ups":180.0}}
	check(RUNNER.R21_TUNING==selected,"selected single-axis coefficients exactly match published research")
	check(RUNNER.R21_AIM.acquire_deg==18.0 and RUNNER.R21_AIM.retain_deg==22.0 and RUNNER.R21_AIM.tie_deg==0.1 and RUNNER.R21_AIM.switch_margin_deg==3.0 and RUNNER.R21_AIM.switch_ticks==6,"acquisition law constants match reviewed contract")
	var old := OLD.new()
	var current := RUNNER.new()
	root.add_child(old)
	root.add_child(current)
	old.cue_player.free()
	old.cue_player = null
	current.cue_player.free()
	current.cue_player = null
	old.set_physics_process(false)
	old.set_process(false)
	current.set_physics_process(false)
	current.set_process(false)
	var n := Vector3(0.3, 0.4, -0.8660254).normalized()
	var exact := true
	var comparisons := 0
	var laws: Array = []
	for model_: String in RUNNER.R21_MODELS:
		current.configure_tether(model_, false)
		current.configure_anchor_assist(false)
		identities[model_] = current.tether_identity()
		rules_hashes[model_] = current.r21_law_sha256()
		identity_hashes[model_] = {}
		for assist: bool in [false,true]:
			current.configure_anchor_assist(assist)
			identity_hashes[model_][str(assist)] = current.r21_rules_sha256()
	for model_: String in ["pendulum", "elastic"]:
		old.configure_tether(model_, false)
		current.configure_tether(model_, false)
		for length: float in [96.0, 100.0, 500.0, 1181.0]:
			for extension: float in [-10.0, 0.0, 0.01, 1.0, 10.0, 100.0]:
				for speed: float in [0.0, 300.0, 650.0, 1000.0]:
					for radial: float in [-1.0, 0.0, 1.0]:
						var v := Vector3(speed * 0.8, speed * radial * 0.6, 0)
						old.grapple_length_u = length
						current.grapple_length_u = length
						var distance := length + extension
						var a: Vector3 = old._alternative_step(v, n * distance * old.U, Vector3.ZERO, distance, 1.0 / 128)
						var b: Vector3 = current._alternative_step(v, n * distance * current.U, Vector3.ZERO, distance, 1.0 / 128)
						exact = exact and a == b
						comparisons += 1
	check(exact, "original alternative paths exactly equal independent frozen R20", comparisons)
	old.configure_tether("classic", false)
	current.configure_tether("classic", false)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var classic_exact := true
	for extension: float in [-10.0,0.0,0.1,5.0,100.0]:
		for v: Vector3 in [Vector3.ZERO,Vector3(0,-300,400),Vector3(650,0,0),Vector3(1000,600,-300)]:
			var distance := 200.0 + extension
			for runner: CharacterBody3D in [old,current]:
				runner.grapple = {"name":"math", "position":runner._hull_centre()+n*distance*runner.U}
				runner.grapple_length_u = 200.0
				runner.grapple_ticks = 0
				runner._input_blocked = false
				runner.impulses = {}
			var a: Vector3 = old._grapple_step(v,false,1.0/128)
			var b: Vector3 = current._grapple_step(v,false,1.0/128)
			classic_exact = classic_exact and a == b and old.impulses == current.impulses
	check(classic_exact,"original Classic complete dispatch and cause impulses exactly equal frozen R20")
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	old.grapple = {}
	current.grapple = {}
	# single-axis variants compared with a separately evaluated scalar/vector law.
	for model_: String in ["elastic-soft", "elastic-firm", "elastic-arc"]:
		current.configure_tether(model_, false)
		var tuning: Dictionary = selected[model_]
		for extension: float in [-10.0, 0.0, 0.01, 5.0, 100.0]:
			for v: Vector3 in [Vector3.ZERO, Vector3(3,-2,4), Vector3(0,0,100), Vector3(300, -200, 400), Vector3(650, 0, 0), Vector3(1000, 600, -300)]:
				current.grapple_length_u = 200
				var distance := 200.0 + extension
				var actual: Vector3 = current._alternative_step(v, n * distance * current.U, Vector3.ZERO, distance, 1.0 / 128)
				var expected := Vector3.ZERO
				if extension >= 0:
					# use exactly the same normalized geometric direction as the law, not an idealized n.
					var along := (n * distance * current.U) / (distance * current.U)
					var inward := v.dot(along)
					var acceleration := minf(1800.0, float(tuning.stiffness) * extension + float(tuning.outward_damping) * maxf(-inward, 0))
					expected = along * acceleration / 128.0
					var limit := maxf(v.length(), 650.0)
					if (v + expected).length() > limit:
						var aa := expected.length_squared()
						var bb := v.dot(expected)
						var cc := v.length_squared() - limit * limit
						expected *= clampf((-bb + sqrt(maxf(bb * bb - aa * cc, 0))) / aa, 0, 1) if aa > 0 else 0.0
				laws.append({"model": model_, "extension": extension, "v": [v.x,v.y,v.z], "actual": [actual.x,actual.y,actual.z], "expected": [expected.x,expected.y,expected.z], "ok": actual == expected})
	check(laws.all(func(row: Dictionary) -> bool: return row.ok), "variant force equations exactly equal isolated reference", laws.filter(func(row: Dictionary) -> bool: return not row.ok))
	# arc's pre-step correction is tested at the inherited 260-reel clamp boundary too.
	current.configure_tether("elastic-arc", true)
	for distance: float in [100.0,200.0]:
		for rest: float in [96.0,97.0,97.5,98.0,100.0,200.0]:
			current._r21_attached_before_step = true
			current._r21_rest_before_step = rest
			current.grapple_length_u = maxf(96,minf(rest,distance)-260.0/128)
			var applied: Vector3 = current._alternative_step(Vector3.ZERO,Vector3(0,0,-distance)*current.U,Vector3.ZERO,distance,1.0/128)
			var expected_rest := maxf(96,minf(rest,distance)-180.0/128)
			var expected_pull := Vector3(0,0,-minf(1800,90*(distance-expected_rest))/128)
			reel_probes.append({"model":"elastic-arc","rest_before_u":rest,"distance_u":distance,"inherited_rest_u":maxf(96,minf(rest,distance)-260.0/128),"actual_rest_u":current.grapple_length_u,"expected_rest_u":expected_rest,"actual_pull_u":[applied.x,applied.y,applied.z],"expected_pull_u":[expected_pull.x,expected_pull.y,expected_pull.z],"dt":1.0/128})
			check(current.grapple_length_u==expected_rest and applied==expected_pull,"arc applied reel and force including floor " + str(distance) + "/" + str(rest))
	old.free()
	current.free()
	write_json("LAWS.json", laws)

func acquisition_checks() -> void:
	clear()
	anchor("offset", 10)
	anchor("invalid-centred", 0, 35)
	step()
	check(player.r21_acquisition_snapshot().id == "offset", "eligible-first selection ignores invalid centred anchor")
	var before: Dictionary = player.r21_acquisition_snapshot()
	var internal := [player._r21_candidate.duplicate(true), player._r21_candidate_serial, player._r21_candidate_age, player._r21_press_id, player.grapple.duplicate(true)]
	for i: int in 100:
		var viewed: Dictionary = player.r21_acquisition_snapshot()
		viewed.id = "tamper"
	check(internal == [player._r21_candidate, player._r21_candidate_serial, player._r21_candidate_age, player._r21_press_id, player.grapple], "snapshot observation is pure and isolated")
	button(true)
	step()
	check(player.r21_acquisition_snapshot().attached and player.r21_acquisition_snapshot().id == before.id, "fresh press attaches exact published preview id")
	clear()
	var a := anchor("a", 5, 20)
	anchor("b", 5.08, 19)
	anchor("c", 5.16, 10)
	step()
	check(player.r21_acquisition_snapshot().id == "b", "tie window relative to global minimum excludes chained epsilon candidate")
	anchors.reverse()
	for node: Node3D in anchors:
		node.remove_from_group(player.ANCHOR_GROUP)
		node.add_to_group(player.ANCHOR_GROUP)
	player._clear_r21_candidate()
	step()
	check(player.r21_acquisition_snapshot().id == "b", "group order leaves tie selection unchanged")
	clear()
	anchor("z-id",5,20)
	anchor("a-id",5,20)
	step()
	check(player.r21_acquisition_snapshot().id=="a-id","exact angle and distance ties use stable lexical id")
	clear()
	a = anchor("duplicate", 0)
	var duplicate := anchor("duplicate", 1)
	anchor("unique", 10)
	step()
	check(player.r21_acquisition_snapshot().id == "unique", "duplicate ids refused before ranking")
	clear()
	a = anchor("retained", 5)
	step()
	anchor("challenger", 1)
	for i: int in 5:
		step()
	check(player.r21_acquisition_snapshot().id == "retained", "challenger waits five ticks")
	step()
	check(player.r21_acquisition_snapshot().id == "challenger", "three-degree better challenger switches on sixth tick")
	clear()
	anchor("retained",5)
	step()
	anchor("small-challenger",3.5)
	for tick: int in 12:
		step()
	check(player.r21_acquisition_snapshot().id=="retained","challenger below three-degree margin never accumulates switch ticks")
	clear()
	a = anchor("retained", 17)
	step()
	a.global_position = player._eye() + Vector3(sin(deg_to_rad(21)), 0, -cos(deg_to_rad(21))) * 20
	step()
	check(player.r21_acquisition_snapshot().id == "retained", "retention remains valid at twenty-one degrees")
	a.global_position = player._eye() + Vector3(sin(deg_to_rad(23)), 0, -cos(deg_to_rad(23))) * 20
	step()
	check(not player.r21_acquisition_snapshot().ready, "immediate retention invalidation beyond twenty-two degrees")
	clear()
	a = anchor("prior", 0)
	step()
	button(true)
	a.position = Vector3(0,2,20)
	anchor("replacement", 1)
	step()
	check(player.grapple.is_empty(), "invalid press refuses silent swap to newly ranked replacement")
	step()
	check(player.r21_acquisition_snapshot().attached and player.r21_acquisition_snapshot().id == "replacement", "held retry accepts replacement only after full physics publication")
	for boundary: String in ["pause", "restart", "model", "automatic_reel", "anchor_assist", "practice", "respawn", "map", "preset"]:
		player.block_tether(boundary)
		step()
		check(player.grapple.is_empty() and not player.r21_acquisition_snapshot().ready, "held input boundary guard " + boundary)
		button(false)
		step()
		button(true)
		step()
		check(not player.grapple.is_empty(), "fresh input recovers " + boundary)
	clear()
	anchor("offscreen", 17)
	player.settings.fov = 10
	step()
	check(not player.r21_acquisition_snapshot().ready, "viewport rejects in-cone target outside narrow FOV")
	player.settings.fov = 92
	clear()
	anchor("outside-acquire", 18.5)
	step()
	check(not player.r21_acquisition_snapshot().ready,"acquisition cone rejects eighteen-and-a-half degrees")
	clear()
	anchor("behind", 180)
	step()
	check(not player.r21_acquisition_snapshot().ready, "behind-camera target refused")
	clear()
	anchor("range", 0, 1181.01 * player.U)
	step()
	check(not player.r21_acquisition_snapshot().ready, "range beyond 1181u refused")
	clear()
	a = anchor("occluded", 0)
	var body := StaticBody3D.new()
	body.name = "endpoint_blocker"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1,2,0.05)
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	body.position = a.position + Vector3(0,0,0.1)
	await physics_frame
	await physics_frame
	step()
	check(not player.r21_acquisition_snapshot().ready, "strict LOS refuses blocker inside old 0.3m endpoint grace")
	var offset := anchor("valid-offset",10)
	step()
	check(player.r21_acquisition_snapshot().id=="valid-offset","occluded centred anchor cannot mask valid offset anchor")
	anchors.erase(offset)
	offset.free()
	player._clear_r21_candidate()
	body.position.x = 5
	await physics_frame
	await physics_frame
	step()
	check(player.r21_acquisition_snapshot().ready, "visible target recovers after blocker removal")
	body.position.x = 0
	await physics_frame
	await physics_frame
	step()
	check(not player.r21_acquisition_snapshot().ready, "one-update occlusion immediately invalidates preview")
	body.free()

func stress_checks() -> void:
	for speed: float in [300.0, 650.0, 1000.0]:
		var baseline: Array = []
		for cadence: int in [0,1,3]:
			clear()
			anchor("speed-target", 0)
			var seen: Array = []
			var eligible := 0
			var missed := 0
			var first := -1
			var attached := -1
			var agree := true
			for tick: int in ceili(20.0 / (speed * player.U / 128)) + 1:
				# labelled kinematic acquisition stress: no route/physics momentum claim.
				player.position.x = -10.0 + float(tick) * speed * player.U / 128
				var valid: bool = not player._r21_eligible(anchors[0], 18).is_empty()
				if valid:
					eligible += 1
					if first < 0:
						first = tick
				var prior: Dictionary = player.r21_acquisition_snapshot()
				if prior.ready and player.grapple.is_empty():
					button(true)
				step()
				var snap: Dictionary = player.r21_acquisition_snapshot()
				if valid and not snap.ready:
					missed += 1
				if snap.attached and attached < 0:
					attached = tick
					agree = snap.id == prior.id
				for frame: int in cadence:
					player._process(1.0 / 128 / maxi(cadence,1))
				seen.append([snap.id, snap.ready, snap.attached, snap.serial])
			# serial is monotonic across resets; normalize it for this run.
			var serial_origin: int = seen[0][3]
			for row: Array in seen:
				row[3] -= serial_origin
			if baseline.is_empty():
				baseline = seen
			check(seen == baseline, "render-independent candidate/attachment timeline " + str(speed) + "/" + str(cadence))
			check(eligible > 0 and missed == 0 and attached == first + 1 and agree, "at-speed acquisition opportunity and prior-id press agreement " + str(speed) + "/" + str(cadence), {"eligible":eligible,"missed":missed,"first":first,"attached":attached,"agreement":agree})
			stresses.append({"speed_ups":speed,"render_calls_per_tick":cadence,"eligible_ticks":eligible,"eligible_s":float(eligible)/128,"missed_valid_ticks":missed,"press_latency_ticks":attached-first,"id_agreement":agree})

func write_json(name_: String, value: Variant) -> void:
	var file := FileAccess.open(output.path_join(name_), FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"\t", false, true))
	file.close()

func run() -> void:
	root.size = Vector2i(1280,720)
	for action: String in ["jump", "move_forward", "move_back", "move_left", "move_right", "crouch", "look_left", "look_right", "look_up", "look_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	Engine.physics_ticks_per_second = 128
	DirAccess.make_dir_recursive_absolute(output)
	math_checks()
	world = Node3D.new()
	root.add_child(world)
	player = RUNNER.new()
	world.add_child(player)
	# audio is outside isolated math/acquisition scope; full-host routes retain the real cue path.
	player.cue_player.free()
	player.cue_player = null
	player.set_physics_process(false)
	player.set_process(false)
	player.input_enabled = true
	player.configure_tether("elastic", false)
	player._input_blocked = false
	await acquisition_checks()
	stress_checks()
	clear()
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	write_json("summary.json", {"ok":ok,"scope":"isolated component fixtures; not production-host/UI acceptance", "checks":checks,"identities":identities,"rules_hashes":rules_hashes,"identity_hashes":identity_hashes,"stresses":stresses,"applied_arc_probes":reel_probes})
	world.free()
	await process_frame
	await process_frame
	quit(0 if ok else 1)

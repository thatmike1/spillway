extends "res://scripts/r20_tether_player.gd"
## additive single-axis laws and physics-authoritative acquisition; inherited motors stay frozen.
const R21_VERSION := "r21-tether-elastic-1"
const R21_MODELS := ["classic", "pendulum", "elastic", "elastic-soft", "elastic-firm", "elastic-arc"]
const R21_TUNING := {
	"elastic-soft": {"stiffness": 90.0, "outward_damping": 6.0, "reel_ups": 260.0},
	"elastic-firm": {"stiffness": 120.0, "outward_damping": 10.0, "reel_ups": 260.0},
	"elastic-arc": {"stiffness": 90.0, "outward_damping": 10.0, "reel_ups": 180.0}}
const R21_AIM := {"law": "r21-anchor-assist-1", "acquire_deg": 18.0, "retain_deg": 22.0,
	"tie_deg": 0.1, "switch_margin_deg": 3.0, "switch_ticks": 6,
	"readiness": "one complete physics candidate update; fresh press latches prior candidate id",
	"range_u": 1181.0, "line_of_sight": "strict eye and hull centre; no terminal grace"}
var anchor_assist := true
var _r21_candidate := {}
var _r21_candidate_serial := 0
var _r21_candidate_age := 0
var _r21_challenger := ""
var _r21_challenger_ticks := 0
var _r21_press_id := ""
var _r21_retry_id := ""
var _r21_attach_id := ""
var _r21_rest_before_step := 0.0
var _r21_attached_before_step := false

func movement_version() -> String:
	return R21_VERSION

func configure_tether(next_model: String, automatic: bool) -> void:
	var selected := next_model if next_model in R21_MODELS else "classic"
	if selected != model or automatic != auto_reel:
		block_tether("model" if selected != model else "automatic_reel")
		model = selected
		auto_reel = automatic
		_clear_r21_candidate()

func configure_anchor_assist(on: bool) -> void:
	if anchor_assist != on:
		block_tether("anchor_assist")
		anchor_assist = on
		_clear_r21_candidate()

func r21_assist_active() -> bool:
	return anchor_assist and model not in ["classic", "pendulum"]

func max_attachment_s() -> float:
	return 5.0 if R21_TUNING.has(model) else super()

func tether_identity() -> Dictionary:
	var identity := super()
	identity.version = R21_VERSION
	if R21_TUNING.has(model):
		identity.alternative = ALTERNATIVES.elastic.duplicate(true)
		identity.alternative.law = "r21-" + model + "-1"
		identity.alternative.stiffness = R21_TUNING[model].stiffness
		identity.alternative.outward_damping = R21_TUNING[model].outward_damping
	identity["reel_ups"] = float(R21_TUNING[model].reel_ups) if R21_TUNING.has(model) else float(GRAPPLE.reel_ups)
	identity["acquisition"] = R21_AIM.duplicate(true) if r21_assist_active() else {"law": "r20-original-aim", "aim_cone_deg": GRAPPLE.aim_cone_deg}
	return identity

func r21_law_rules() -> Dictionary:
	# physical force and reel rules only; selection and labels have separate identity.
	var identity := tether_identity()
	return {"classic": GRAPPLE.duplicate(true), "alternative": identity.alternative.duplicate(true),
		"controls": identity.controls, "reel_ups": identity.reel_ups}

func r21_law_sha256() -> String:
	return JSON.stringify(r21_law_rules(), "", false, true).sha256_text()

func r21_rules_sha256() -> String:
	return JSON.stringify(tether_identity(), "", false, true).sha256_text()

func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_r21_press_id = str(_r21_candidate.get("id", "")) if _r21_candidate_age >= 1 else ""
	super(event)

func _grapple_step(v: Vector3, grounded: bool, delta: float) -> Vector3:
	if r21_assist_active() and grapple.is_empty():
		# retries use the previously published physics candidate, exactly like a fresh press.
		_r21_retry_id = str(_r21_candidate.get("id", "")) if _r21_candidate_age >= 1 else ""
		_update_r21_candidate()
	_r21_rest_before_step = grapple_length_u
	_r21_attached_before_step = not grapple.is_empty()
	var change := super(v, grounded, delta)
	if not grapple.is_empty() and not _r21_attached_before_step:
		_r21_attach_id = str(grapple_target.get("id", grapple_target.get("name", "")))
	if r21_assist_active():
		if grapple.is_empty():
			# both the inherited world ring and passive HUD read this published candidate.
			grapple_target = _r21_candidate.duplicate(true) if not _r21_candidate.is_empty() else {"state": "none"}
	return change

func _alternative_step(v: Vector3, anchor: Vector3, centre: Vector3, distance_u: float, delta: float) -> Vector3:
	if not R21_TUNING.has(model):
		return super(v, anchor, centre, distance_u, delta)
	var tuning: Dictionary = R21_TUNING[model]
	if model == "elastic-arc" and reel_active():
		# r20 already reeled before dispatch; derive this variant's exact rest length from its pre-step value.
		var previous := _r21_rest_before_step if _r21_attached_before_step else distance_u
		grapple_length_u = maxf(float(GRAPPLE.min_length_u), minf(previous, distance_u) - float(tuning.reel_ups) * delta)
	if distance_u < grapple_length_u or distance_u < 1e-3:
		return Vector3.ZERO
	var along := (anchor - centre) / (distance_u * U)
	var radial := v.dot(along)
	var reference: Dictionary = ALTERNATIVES.elastic
	var force := minf(float(reference.max_pull_ups2), float(tuning.stiffness) * (distance_u - grapple_length_u) + float(tuning.outward_damping) * maxf(-radial, 0.0))
	var pull := along * force * delta
	var limit := maxf(v.length(), float(reference.speed_cap_ups))
	if (v + pull).length() > limit:
		var a := pull.length_squared()
		var b := v.dot(pull)
		var c := v.length_squared() - limit * limit
		pull *= clampf((-b + sqrt(maxf(b * b - a * c, 0.0))) / a, 0.0, 1.0) if a > 0.0 else 0.0
	_book("grapple_pull", pull)
	return pull

func _clear_line(from: Vector3, to: Vector3) -> bool:
	if not r21_assist_active():
		return super(from, to)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _r21_on_screen(to: Vector3) -> bool:
	# derive projection from physics view angles, rather than the render-interpolated camera pose.
	var aim := _aim()
	var depth := to.dot(aim)
	if depth <= 0.0:
		return false
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var up := right.cross(aim)
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var vertical_tangent := tan(deg_to_rad(float(settings.fov)) * 0.5) * 0.75
	return absf(to.dot(up)) <= depth * vertical_tangent and absf(to.dot(right)) <= depth * vertical_tangent * size.x / size.y

func _r21_eligible(anchor: Node3D, cone: float) -> Dictionary:
	if anchor == null or not anchor.is_inside_tree():
		return {}
	var to := anchor.global_position - _eye()
	var distance := to.length()
	if distance < 1e-3 or distance > float(GRAPPLE.range_u) * U or not _r21_on_screen(to):
		return {}
	var angle := rad_to_deg(_aim().angle_to(to / distance))
	if angle > cone or not _clear_line(_eye(), anchor.global_position) or not _clear_line(_hull_centre(), anchor.global_position):
		return {}
	return {"state": "ok", "id": str(anchor.get_meta("r21_anchor_id", anchor.name)),
		"name": str(anchor.get_meta("anchor_name", anchor.name)), "position": anchor.global_position,
		"distance_m": distance, "angle_deg": angle}

func _r21_lookup(id: String, cone: float) -> Dictionary:
	if id.is_empty():
		return {}
	var found := {}
	var matches := 0
	for node: Node in get_tree().get_nodes_in_group(ANCHOR_GROUP):
		var anchor := node as Node3D
		if anchor != null and str(anchor.get_meta("r21_anchor_id", anchor.name)) == id:
			matches += 1
			found = _r21_eligible(anchor, cone)
	return found if matches == 1 else {}

func _update_r21_candidate() -> void:
	var best := {}
	var candidates: Array[Dictionary] = []
	var counts := {}
	var nearest_angle := INF
	for node: Node in get_tree().get_nodes_in_group(ANCHOR_GROUP):
		var anchor := node as Node3D
		if anchor == null:
			continue
		var id := str(anchor.get_meta("r21_anchor_id", anchor.name))
		counts[id] = int(counts.get(id, 0)) + 1
		var candidate := _r21_eligible(anchor, float(R21_AIM.acquire_deg))
		if not candidate.is_empty():
			candidates.append(candidate)
	for candidate: Dictionary in candidates:
		if int(counts[candidate.id]) == 1:
			nearest_angle = minf(nearest_angle, float(candidate.angle_deg))
	# tie membership is relative to the minimum angle, avoiding a non-transitive pairwise epsilon sort.
	for candidate: Dictionary in candidates:
		if int(counts[candidate.id]) != 1 or float(candidate.angle_deg) > nearest_angle + float(R21_AIM.tie_deg):
			continue
		if best.is_empty() or float(candidate.distance_m) < float(best.distance_m) or (float(candidate.distance_m) == float(best.distance_m) and str(candidate.id) < str(best.id)):
			best = candidate
	var prior_id := str(_r21_candidate.get("id", ""))
	var retained := _r21_lookup(prior_id, float(R21_AIM.retain_deg))
	var next := best
	if not retained.is_empty():
		next = retained
		if not best.is_empty() and str(best.id) != prior_id and float(best.angle_deg) + float(R21_AIM.switch_margin_deg) <= float(retained.angle_deg):
			if _r21_challenger == str(best.id):
				_r21_challenger_ticks += 1
			else:
				_r21_challenger = str(best.id)
				_r21_challenger_ticks = 1
			if _r21_challenger_ticks >= int(R21_AIM.switch_ticks):
				next = best
		else:
			_r21_challenger = ""
			_r21_challenger_ticks = 0
	else:
		_r21_challenger = ""
		_r21_challenger_ticks = 0
	var next_id := str(next.get("id", ""))
	if next_id != prior_id:
		_r21_candidate_serial += 1
		_r21_candidate_age = 1
	else:
		_r21_candidate_age += 1
	_r21_candidate = next

func _find_target() -> Dictionary:
	if not r21_assist_active():
		var original := super()
		# add observation identity without altering the original selector or its eligibility.
		if original.has("position"):
			for node: Node in get_tree().get_nodes_in_group(ANCHOR_GROUP):
				if node is Node3D and node.global_position == original.position and str(node.get_meta("anchor_name",node.name)) == str(original.name):
					original["id"] = str(node.get_meta("r21_anchor_id",node.name))
					break
		return original
	if _grapple_press:
		var latched := _r21_lookup(_r21_press_id, float(R21_AIM.retain_deg))
		return latched if not latched.is_empty() else {"state": "none"}
	var retry := _r21_lookup(_r21_retry_id, float(R21_AIM.retain_deg))
	return retry if not retry.is_empty() else {"state": "none"}

func r21_acquisition_snapshot() -> Dictionary:
	# observational only: no selection, raycasts, readiness advance or gameplay writes.
	var attached := not grapple.is_empty()
	var source: Dictionary = grapple if attached else (_r21_candidate if r21_assist_active() else grapple_target)
	var valid := attached or str(source.get("state", "none")) == "ok"
	return {"state": "ok" if valid else str(source.get("state", "none")),
		"id": _r21_attach_id if attached else str(source.get("id", source.get("name", ""))),
		"name": str(source.get("name", "")), "position": source.get("position", Vector3.ZERO),
		"distance_m": _eye().distance_to(source.position) if source.has("position") else 0.0,
		"serial": _r21_candidate_serial, "attached": attached, "assist": r21_assist_active(),
		"ready": valid and (attached or (not _input_blocked and not _grapple_needs_press and (not r21_assist_active() or _r21_candidate_age >= 1)))}

func _process(delta: float) -> void:
	super(delta)
	if r21_assist_active() and _target_ring != null:
		var snapshot := r21_acquisition_snapshot()
		_target_ring.visible = bool(snapshot.ready)
		if _target_ring.visible:
			_target_ring.global_transform = Transform3D(_facing(camera.global_position - snapshot.position), snapshot.position)

func _clear_r21_candidate() -> void:
	_r21_candidate = {}
	_r21_candidate_age = 0
	_r21_candidate_serial += 1
	_r21_challenger = ""
	_r21_challenger_ticks = 0
	_r21_press_id = ""
	_r21_retry_id = ""
	_r21_attach_id = ""
	grapple_target = {"state": "none"}

func reset_to(pose: Transform3D) -> void:
	super(pose)
	_clear_r21_candidate()

func block_tether(reason: String) -> void:
	super(reason)
	_clear_r21_candidate()

func get_motion_state() -> Dictionary:
	var out := super()
	out.experiment.version = R21_VERSION
	out.experiment.tether["acquisition"] = r21_acquisition_snapshot()
	return out

extends "res://scripts/spillway_player.gd"
## p / r14 source runner: r14_source_motion.gd's tick on real godot collision. the motion
## module owns the order and the velocity law in source units; this adapter is its world:
## collide-and-slide with move_and_collide on an axis-aligned box hull, the 18 u step-up, the
## stay-on-ground snap and the 2 u ground probe. no r12/r13 ground, air, mantle, slide, surf
## or camera assist runs here; only r12's camera node and signals are reused.
## the box never rotates with the view, as source's hull does not.

const MOTION := preload("res://scripts/r14_source_motion.gd")
const U: float = MOTION.U
const BUMPS := 4
const MAX_CLIP_PLANES := 5
## p / the refining drop after the stay-on-ground cast. godot sweeps by eight bisection steps,
## so a 20 u cast can stop up to about 0.1 u short of the floor; a short second cast lands it.
const SNAP_REFINE := 0.5
## godot depenetrates a hull closer to a face than this share of the margin (its 4.7.2
## test-motion minimum contact depth is 5% of the margin).
const RECOVERY_GAP := 0.95
## p / the missed-support guard (see _support_inside): overlap tests use godot 4.7.2's
## minimum test-motion margin, a contact-free sweep must end at least GUARD_DEPTH inside
## geometry to count as a missed cast, a snap whose cast did report the face at least
## LATE_DEPTH (one margin, so a snap resting on the raw face never counts), and the first touch
## is bisected to 2^-GUARD_STEPS of the sweep.
const GUARD_MARGIN := 0.0001
const GUARD_DEPTH := 0.0002
const LATE_DEPTH := 0.001
const GUARD_STEPS := 20

## the active cvars and policies (see r14_source_motion.gd). change with apply_preset() or
## apply_settings(); both keep position, velocity and view.
var settings: Dictionary = MOTION.preset("csgo_server")
## replay declarations use the active source units instead of r13's mouse multiplier.
var physics_hz: int:
	get:
		return int(settings.tickrate)
var tape_radians_per_count: float:
	get:
		return deg_to_rad(float(settings.sensitivity) * float(settings.m_yaw))
var pitch_limit: float:
	get:
		return PITCH_LIMIT
var tape_body_yaw_policy: String = "axis_aligned"
## the tape executor's ordering proof reads this as one increment per motor step.
var tape_step_count: int = 0
var motion_tick: int = 0
var step_up_count: int = 0
var snap_count: int = 0
## p / adapter policy, not a source cvar: catch a sweep that ends inside walkable support with
## no contact reported, or a snap that ends past the face it reported. off reproduces the
## unguarded adapter for comparisons.
var cast_guard: bool = true
## sweeps the guard turned into support contacts, by caller (snap_late: a snap past its reported
## face), and sweeps whose end overlapped geometry but stood as the engine made them because the
## start overlapped or the first touch was not walkable support.
var cast_guards: Dictionary = {"slide": 0, "probe": 0, "snap": 0, "snap_late": 0, "declined": 0}
var view_yaw: float:
	get:
		return yaw
	set(value):
		yaw = value
var view_pitch: float:
	get:
		return pitch
	set(value):
		pitch = clampf(value, -PITCH_LIMIT, PITCH_LIMIT)
## source state in u and u/s; velocity (m/s) on the node is the same vector times U.
var state: Dictionary = MOTION.new_state()
## the jump that ended most recently: takeoff and landing speed (u/s, before any landing
## penalty), air gain, a/d sync over its eligible ticks (null without any) and air ticks.
var last_hop: Dictionary = {}
var flight: Dictionary = {}
const PITCH_LIMIT := 1.5533430 # 89 degrees
var _jump_pulse: bool = false
var _tick_yaw: float = 0.0
var _yaw_delta: float = 0.0
var _side: float = 0.0
var _sync_tick: Variant = null
var _contacts: Array[Dictionary] = []
var _phase: String = ""
var _start_velocity := Vector3.ZERO
var _requested := Vector3.ZERO
var _displacement := Vector3.ZERO
var _actual_velocity := Vector3.ZERO
## godot's depenetration this tick, metres: the kept travel that no swept motion explains.
var _depenetration := Vector3.ZERO
## the standoff moves this tick, metres: the hull stepping one margin back off touched faces.
var _standoff := Vector3.ZERO
var _last_delta: float = 0.0
var _box := BoxShape3D.new()

func _ready() -> void:
	super()
	collision.shape = _box
	_fit_hull()
	floor_max_angle = acos(float(settings.sv_walkable_normal))
	motion_mode = MOTION_MODE_FLOATING
	safe_margin = 0.001
	camera.keep_aspect = Camera3D.KEEP_HEIGHT

func apply_preset(name: String, overrides: Dictionary = {}) -> void:
	var next := MOTION.preset(name)
	next.merge(overrides, true)
	apply_settings(next)

func apply_settings(next: Dictionary) -> void:
	settings = next.duplicate()
	# a profile without stamina starts without any penalty left from the previous one.
	state.stamina = MOTION.add_stamina(float(state.stamina), 0.0, settings)
	state.pending_land = 0.0 if float(settings.sv_staminamax) <= 0.0 else state.pending_land
	floor_max_angle = acos(float(settings.sv_walkable_normal))
	if collision != null:
		_fit_hull()

## set the engine's physics rate to the active profile's tickrate.
func apply_engine_rate() -> void:
	Engine.physics_ticks_per_second = int(settings.tickrate)

func reset_to(pose: Transform3D) -> void:
	super(pose)
	# the hull is axis aligned; only the view takes the pose's heading.
	global_transform = Transform3D(Basis.IDENTITY, pose.origin)
	pitch = 0.0
	state = MOTION.new_state(pose.origin / U)
	last_hop = {}
	flight = {}
	_jump_pulse = false
	_tick_yaw = yaw
	_yaw_delta = 0.0
	_sync_tick = null
	_contacts = []
	_start_velocity = Vector3.ZERO
	_requested = Vector3.ZERO
	_displacement = Vector3.ZERO
	_actual_velocity = Vector3.ZERO
	_depenetration = Vector3.ZERO
	_standoff = Vector3.ZERO
	step_up_count = 0
	snap_count = 0
	cast_guards = {"slide": 0, "probe": 0, "snap": 0, "snap_late": 0, "declined": 0}

func is_grounded() -> bool:
	return bool(state.grounded)

## horizontal speed of actual travel over the last motor step, m/s, for hud and audio.
func get_speed() -> float:
	return Vector2(_actual_velocity.x, _actual_velocity.z).length()

func control_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func tape_requested_velocity() -> Vector3:
	return _requested

func _set_height(_height: float) -> void:
	_fit_hull()

func _fit_hull() -> void:
	var width := float(settings.hull_width) * U
	var height := float(settings.hull_height) * U
	_box.size = Vector3(width, height, width)
	collision.position = Vector3(0.0, height * 0.5, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion:
		# source look: sensitivity × m_yaw degrees per count, right turns right.
		var motion := event as InputEventMouseMotion
		yaw -= motion.screen_relative.x * deg_to_rad(float(settings.sensitivity) * float(settings.m_yaw))
		pitch = clampf(pitch - motion.screen_relative.y * deg_to_rad(float(settings.sensitivity) * float(settings.m_pitch)), -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("jump"):
		# a press that is released before the next tick still reaches that tick's command.
		_jump_pulse = true
	elif bool(settings.wheel_jump) and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var index := (event as InputEventMouseButton).button_index
		if index == MOUSE_BUTTON_WHEEL_UP or index == MOUSE_BUTTON_WHEEL_DOWN:
			_jump_pulse = true

func _physics_process(delta: float) -> void:
	_previous_position = _current_position
	var start := global_position
	_last_delta = delta
	if not input_enabled:
		_current_position = global_position
		_displacement = Vector3.ZERO
		_actual_velocity = Vector3.ZERO
		_depenetration = Vector3.ZERO
		_standoff = Vector3.ZERO
		return
	motion_tick += 1
	tape_step_count = motion_tick
	var look := Input.get_vector("look_left", "look_right", "look_down", "look_up")
	yaw -= look.x * 2.4 * delta
	pitch = clampf(pitch + look.y * 1.8 * delta, -PITCH_LIMIT, PITCH_LIMIT)
	var forward := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	_side = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var jump := Input.is_action_pressed("jump") or _jump_pulse
	_jump_pulse = false
	crouched = Input.is_action_pressed("crouch")
	_yaw_delta = wrapf(yaw - _tick_yaw, -PI, PI)
	_tick_yaw = yaw
	# the node's velocity is authoritative between ticks, so a labelled fixture write holds.
	state.position = global_position / U
	state.velocity = velocity / U
	_start_velocity = velocity
	_contacts = []
	_depenetration = Vector3.ZERO
	_standoff = Vector3.ZERO
	var was_grounded: bool = state.grounded
	var cmd := {"forward": forward, "side": _side, "yaw": yaw, "jump": jump, "ducked": crouched, "in_water": in_water}
	MOTION.step(state, cmd, settings, delta, self)
	_requested = (state.requested as Vector3) * U
	velocity = (state.velocity as Vector3) * U
	_ground_normal = state.ground_normal
	_contacts_valid = true
	_displacement = global_position - start
	_actual_velocity = _displacement / delta
	_update_flight(was_grounded)
	mode = "air" if not state.grounded else ("duck" if crouched else "run")
	if "jump" in state.events:
		jump_count = state.jump_count
		if "perfect" in state.events:
			hop_count += 1
		move_started.emit("jump")
	if "land" in state.events:
		land_count = state.land_count
		last_impact = float(state.fall_speed) * U
		landed.emit(last_impact)
	if state.grounded:
		var travelled := Vector2(_displacement.x, _displacement.z).length()
		_distance += travelled
		if _distance > 2.25:
			_distance = 0.0
			footstep.emit(clampf(get_speed() / (float(settings.player_maxspeed) * U), 0.0, 1.0))
	_last_position = global_position
	_current_position = global_position

## airborne a/d sync: an eligible tick has one side key, a view turn and horizontal speed; it
## is good when the view turns toward the held key. not shavit's angle branches.
func _update_flight(was_grounded: bool) -> void:
	_sync_tick = null
	if "jump" in state.events:
		if not flight.is_empty() and flight.has("takeoff"):
			last_hop["chained_gain"] = float(state.takeoff_speed) - float(flight.takeoff)
		flight = {"takeoff": state.takeoff_speed, "ticks": 0, "eligible": 0, "good": 0, "start_tick": state.tick}
	if flight.is_empty():
		return
	# the landing tick also ran an air update, so it counts as an air tick.
	if not was_grounded or "jump" in state.events:
		flight.ticks += 1
		var speed := Vector2(state.velocity.x, state.velocity.z).length()
		if absf(_side) > 0.5 and absf(_yaw_delta) > 1e-7 and speed > 1.0:
			_sync_tick = (_side < 0.0) == (_yaw_delta > 0.0)
			flight.eligible += 1
			if _sync_tick:
				flight.good += 1
	if "land" in state.events:
		var hop := {"takeoff": flight.takeoff, "landing": state.landing_speed, "gain": float(state.landing_speed) - float(flight.takeoff), "air_ticks": flight.ticks, "eligible": flight.eligible, "sync": float(flight.good) / float(flight.eligible) if flight.eligible > 0 else null, "landing_tick": state.tick}
		if last_hop.has("chained_gain"):
			hop["previous_chained_gain"] = last_hop.chained_gain
		last_hop = hop
		flight = {"takeoff": flight.takeoff}
	elif was_grounded and not "jump" in state.events:
		flight = {}

# --- world for MOTION.step: positions in u on the state, metres on the body -----------------

func air_move(s: Dictionary, dt: float) -> void:
	_phase = "air"
	s.velocity = _slide(s.velocity, dt)
	s.position = global_position / U

## a walking move: the plain slide, or the same slide from one step up when that lands on
## walkable ground and the plain slide went no further, then the stay-on-ground snap.
func walk_move(s: Dictionary, dt: float) -> void:
	var start := global_position
	var wish: Vector3 = s.velocity
	var base_depenetration := _depenetration
	var base_standoff := _standoff
	_phase = "walk"
	var down_velocity := _slide(wish, dt)
	var down_position := global_position
	var down_depenetration := _depenetration
	var down_standoff := _standoff
	var down_contacts := _contacts.size()
	if down_contacts > 0:
		var kept := _contacts.duplicate()
		global_position = start
		_depenetration = base_depenetration
		_standoff = base_standoff
		_phase = "step"
		var stepsize := float(settings.sv_stepsize) * U
		var raised := _move(Vector3.UP * stepsize)
		var lift := stepsize if raised == null else raised.get_travel().y
		var up_velocity := _slide(wish, dt)
		var drop := _move(Vector3.DOWN * (lift + 0.0005), false, 4)
		var walkable := drop != null and _best_up(drop) >= float(settings.sv_walkable_normal)
		var down_distance := Vector2(down_position.x - start.x, down_position.z - start.z).length_squared()
		var up_distance := Vector2(global_position.x - start.x, global_position.z - start.z).length_squared()
		# public stepmove keeps the raised path unless the plain slide went further in 2d; only
		# the height decides whether it was a step, so the slide's standoff cannot veto a climb.
		if walkable and up_distance >= down_distance:
			if global_position.y > down_position.y + 1e-4:
				step_up_count += 1
				s.events.append("step")
			down_velocity = Vector3(up_velocity.x, down_velocity.y, up_velocity.z)
		else:
			global_position = down_position
			_depenetration = down_depenetration
			_standoff = down_standoff
			_contacts = kept
	s.velocity = down_velocity
	_stay_on_ground()
	s.position = global_position / U

## ground probe: a walkable face within the probe distance below. no snap, except that a
## hull which ended inside the face's margin without touching it stands off (see _stand_off).
## a 2 u cast can stop several thousandths short, so a near face is measured again closely.
func probe_ground(_s: Dictionary) -> Vector3:
	var probe := Vector3.DOWN * float(settings.ground_probe) * U
	var hit := move_and_collide(probe, true, safe_margin, false, 4)
	var travel := 0.0 if hit == null else -hit.get_travel().y
	if hit == null:
		var caught := _missed_support(global_position, probe, "probe")
		if caught.is_empty():
			return Vector3.ZERO
		hit = caught.hit
		travel = -probe.y * float(caught.fraction)
	var best := Vector3.ZERO
	for i: int in hit.get_collision_count():
		var n := hit.get_normal(i)
		if n.y >= float(settings.sv_walkable_normal) and n.y > best.y:
			best = n
	if best != Vector3.ZERO and travel < 2.0 * safe_margin:
		var near := move_and_collide(Vector3.DOWN * 3.0 * safe_margin, true, safe_margin, false, 4)
		if near != null and -near.get_travel().y < RECOVERY_GAP * safe_margin:
			_stand_off(Vector3.UP)
	return best

func _stay_on_ground() -> void:
	var here := global_position
	var here_depenetration := _depenetration
	var here_standoff := _standoff
	var probe := 2.0 * U
	var raised := _move(Vector3.UP * probe)
	var lift := probe if raised == null else raised.get_travel().y
	var reach := lift + float(settings.sv_stepsize) * U
	var top := global_position
	var top_depenetration := _depenetration
	var drop := move_and_collide(Vector3.DOWN * reach, true, safe_margin, false, 4)
	var caught := {} if drop != null else _missed_support(top, Vector3.DOWN * reach, "snap")
	if not caught.is_empty():
		# the guard's first touch replaces the missed cast; it has no depenetration to book.
		global_position = top + Vector3.DOWN * reach * float(caught.fraction)
		_stand_off(Vector3.UP)
		if absf(global_position.y - here.y) > 1e-4:
			snap_count += 1
	elif drop != null and drop.get_travel().length() > 1e-6 and _best_up(drop) >= float(settings.sv_walkable_normal):
		_apply_test(Vector3.DOWN * reach, drop)
		# the coarse cast's bisection can stop short; a short cast from there finds the face.
		var settle := move_and_collide(Vector3.DOWN * SNAP_REFINE * U, true, safe_margin, false, 4)
		if settle != null and _best_up(settle) >= float(settings.sv_walkable_normal):
			_apply_test(Vector3.DOWN * SNAP_REFINE * U, settle)
		# a cast can also report the face a few millimetres past it; a snap that ended inside
		# support is redone from the guard's first touch on the same drop.
		var late := _support_inside(top, Vector3.DOWN * reach, global_position, "snap_late", LATE_DEPTH)
		if not late.is_empty():
			global_position = top + Vector3.DOWN * reach * float(late.fraction)
			_depenetration = top_depenetration
		_stand_off(Vector3.UP)
		if absf(global_position.y - here.y) > 1e-4:
			snap_count += 1
	else:
		global_position = here
		_depenetration = here_depenetration
		_standoff = here_standoff

func _best_up(hit: KinematicCollision3D) -> float:
	var best := -1.0
	for i: int in hit.get_collision_count():
		best = maxf(best, hit.get_normal(i).y)
	return best

## a real move that also books godot's depenetration: the travel its swept motion does not
## explain. returns the collision as move_and_collide does.
func _move(motion: Vector3, recovery_as_collision := false, max_collisions := 1) -> KinematicCollision3D:
	var from := global_position
	var hit := move_and_collide(motion, false, safe_margin, recovery_as_collision, max_collisions)
	var swept := motion if hit == null else motion - hit.get_remainder()
	_depenetration += global_position - from - swept
	return hit

## p / step one margin back off a touched face, as a source trace stops 1/32 u short of its
## plane. a hull left inside godot's margin is pushed out by the next move's depenetration,
## which the engine folds into that move's travel along its direction: unreported motion at
## rest and at takeoff. the move is swept, so it cannot enter other geometry; depenetration
## from the same face is trimmed so the hull ends one margin off it, any other is kept.
func _stand_off(direction: Vector3) -> void:
	var from := global_position
	move_and_collide(direction * safe_margin, false, safe_margin)
	var along := (global_position - from).dot(direction)
	if along > safe_margin:
		global_position -= direction * (along - safe_margin)
	_standoff += global_position - from

## apply a test move's result, booking its depenetration the same way.
func _apply_test(motion: Vector3, hit: KinematicCollision3D) -> void:
	_depenetration += hit.get_travel() - (motion - hit.get_remainder())
	global_position += hit.get_travel()

## collide and slide in u/s, after the public source trymove rules: up to four bumps. positive
## swept travel makes the current velocity the working original and clears the plane set, so
## each contact clips the momentum the previous one left (MOTION.clip_to_planes). a move that
## never advances stops. godot specifics: the swept fraction comes from the remainder, since
## get_travel() includes depenetration; one cast may report several faces at once; and a face
## whose margin the body is already inside, moving into it, is a touched plane even when the
## short sweep ends before its raw surface, as a source trace would report it at fraction 0.
func _slide(v: Vector3, dt: float) -> Vector3:
	var time_left := dt
	var primal := v
	var original := v
	var planes: Array[Vector3] = []
	var advanced := 0.0
	var airborne := _phase == "air"
	for bump: int in BUMPS:
		var motion := v * U * time_left
		if motion.length_squared() < 1e-14:
			advanced += 1.0
			break
		var from := global_position
		var before_depenetration := _depenetration
		var hit := _move(motion, true, 4)
		var fraction := 1.0
		var guarded := false
		if hit == null:
			var caught := _missed_support(from, motion, "slide")
			if caught.is_empty():
				advanced += 1.0
				break
			# the sweep stops where it first touched the support, with no depenetration.
			global_position = from + motion * float(caught.fraction)
			_depenetration = before_depenetration
			fraction = caught.fraction
			hit = caught.hit
			guarded = true
		else:
			fraction = clampf(1.0 - hit.get_remainder().length() / motion.length(), 0.0, 1.0)
		advanced += fraction
		if fraction > 0.0:
			original = v
			planes.clear()
		var touched: Array[Vector3] = []
		for i: int in hit.get_collision_count():
			var n := hit.get_normal(i)
			var body := hit.get_collider(i) as Node
			# a face the move heads away from never blocked it; after a full sweep, only a face
			# the move heads into is a touched plane.
			var blocking := v.dot(n) <= 0.0 if fraction < 1.0 else v.dot(n) < -1e-6
			_contacts.append({"phase": _phase, "bump": bump, "body": str(body.name) if body != null else "", "normal": n, "position": hit.get_position(i), "fraction": fraction, "blocking": blocking, "guard": guarded})
			if not blocking:
				continue
			var seen := false
			for face: Vector3 in touched:
				seen = seen or face.dot(n) > 0.9999
			if not seen:
				touched.append(n)
			var known := false
			for plane: Vector3 in planes:
				known = known or plane.dot(n) > 0.9999
			if not known:
				planes.append(n)
		time_left -= time_left * fraction
		# a swept stop ends at the raw faces it reports; step back off each one.
		if fraction < 1.0:
			for face: Vector3 in touched:
				_stand_off(face)
		if touched.is_empty():
			if fraction >= 1.0:
				break
			continue
		if planes.size() > MAX_CLIP_PLANES:
			v = Vector3.ZERO
			break
		var result := MOTION.clip_to_planes(original, primal, planes, airborne)
		v = result.velocity
		original = result.original
		if result.stop or fraction >= 1.0:
			break
	if advanced <= 0.0:
		v = Vector3.ZERO
	return v

## p / godot 4.7.2 sweeps can report no contact for a hull that crosses a convex prism's top
## face (docs/r14/CONTACT-GUARD.md). after a contact-free sweep of `motion` from `from`, see
## _support_inside for its end pose.
func _missed_support(from: Vector3, motion: Vector3, caller: String) -> Dictionary:
	return _support_inside(from, motion, from + motion, caller)

## p / the engine's overlap test checks where a sweep left the hull, `end_at`. when that sits
## more than `depth` inside geometry and the start is clear, the sweep's straight path from
## `from` along `motion` is bisected with the overlap test. a first touch on walkable support
## returns {fraction, hit}: the last clear share of the sweep and the contacts at the touch. a
## clear end, an overlapping start or a first touch on any other face returns {}, and the sweep
## stands as the engine made it.
func _support_inside(from: Vector3, motion: Vector3, end_at: Vector3, caller: String, depth := GUARD_DEPTH) -> Dictionary:
	if not cast_guard:
		return {}
	var walkable := float(settings.sv_walkable_normal)
	var basis := global_transform.basis
	var end := KinematicCollision3D.new()
	if not test_move(Transform3D(basis, end_at), Vector3.ZERO, end, GUARD_MARGIN, true, 4) or end.get_travel().length() < depth:
		return {}
	if test_move(Transform3D(basis, from), Vector3.ZERO, null, GUARD_MARGIN, true, 1):
		cast_guards.declined += 1
		return {}
	var lo := 0.0
	var hi := 1.0
	var first: KinematicCollision3D = end
	for i: int in GUARD_STEPS:
		var mid := (lo + hi) * 0.5
		var touch := KinematicCollision3D.new()
		if test_move(Transform3D(basis, from + motion * mid), Vector3.ZERO, touch, GUARD_MARGIN, true, 4):
			hi = mid
			first = touch
		else:
			lo = mid
	if _best_up(first) < walkable:
		cast_guards.declined += 1
		return {}
	cast_guards[caller] += 1
	return {"fraction": lo, "hit": first}

func _process(delta: float) -> void:
	_update_eye(delta)

## source view: eye at 64 u over the interpolated feet, constant 4:3-referenced fov, no bob,
## no landing dip, no speed fov and no bank.
func _update_eye(_delta: float) -> void:
	if camera == null:
		return
	var fraction := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	var feet := _previous_position.lerp(_current_position, fraction)
	camera.global_position = feet + Vector3.UP * float(settings.eye_height) * U
	camera.global_rotation = Vector3(pitch, yaw, 0.0)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(float(settings.fov)) * 0.5) * 0.75))

## the motor's own report, R13's meanings where they exist plus source units and cvars.
func get_motion_state() -> Dictionary:
	var ledger := {}
	for cause: String in state.ledger:
		ledger[cause] = (state.ledger[cause] as Vector3) * U
	return {
		"tick": motion_tick,
		"motor": "r14_source",
		"preset": settings.get("preset", ""),
		"tickrate": settings.tickrate,
		"physics_hz": Engine.physics_ticks_per_second,
		"delta": _last_delta,
		# the engine property can change before a queued batch of old-delta callbacks finishes.
		"rate_matches": Engine.physics_ticks_per_second == int(settings.tickrate) and absf(_last_delta - 1.0 / float(settings.tickrate)) < 1e-9,
		"mode": mode,
		"grounded": is_grounded(),
		"support_normal": state.ground_normal,
		"position": global_position,
		"previous_position": _previous_position,
		"start_velocity": _start_velocity,
		"requested_velocity": _requested,
		"post_contact_velocity": velocity,
		"displacement": _displacement,
		"actual_velocity": _actual_velocity,
		# godot depenetration inside the displacement, m; zero when travel is all swept motion.
		"depenetration": _depenetration,
		# the margin standoff inside the displacement, m (see _stand_off).
		"standoff": _standoff,
		"actual_speed": get_speed(),
		"control_speed": control_speed(),
		"speed_u": Vector2(state.velocity.x, state.velocity.z).length(),
		"actual_speed_u": get_speed() / U,
		"velocity_u": state.velocity,
		"wish_dir": state.wish_dir,
		"wish_speed_u": state.wish_speed,
		"air_gain_u": state.air_gain,
		"air_surface": state.surface,
		"stamina": state.stamina,
		"events": (state.events as Array).duplicate(),
		"contacts": _describe(),
		"contact_count": _contacts.size(),
		"step_ups": step_up_count,
		"ground_snaps": snap_count,
		"cast_guards": cast_guards.duplicate(),
		"ledger": ledger,
		"side": _side,
		"yaw_delta": _yaw_delta,
		"sync_tick": _sync_tick,
		"flight": flight.duplicate(),
		"last_hop": last_hop.duplicate(),
		"crouched": crouched,
		"yaw": yaw,
		"pitch": pitch,
		"hop_count": hop_count,
		"perfect_count": state.perfect_count,
		"jump_count": state.jump_count,
		"land_count": state.land_count,
		"ground_ticks": state.ground_ticks,
		"fall_speed_u": state.fall_speed,
		"cvars": settings.duplicate(),
	}

func _describe() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for contact: Dictionary in _contacts:
		out.append(contact.duplicate())
	return out

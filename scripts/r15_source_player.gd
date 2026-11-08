extends "res://scripts/r14_source_player.gd"
## p / r15 source runner: the repaired r14 runner with a real duck hull. the box itself shrinks
## from 72 u to 54 u, on the floor and in flight; the camera follows a per-tick eye offset.
## nothing here runs while crouch was never held: the tick is r14's, line for line, plus a duck
## step before the motor that is a no-op for a standing body with crouch up.
## docs/r15/CROUCH.md names every rule's evidence and every game choice.
##
## the duck step, after the public source 2013 CGameMovement::Duck order (before the move):
## - press: the hull becomes the duck hull at once, on the floor and in flight (p: no 0.4 s
##   ground transition; the eye still eases). on the floor the feet stay put, as public
##   FinishDuck does with equal hull mins. in flight the feet rise by the air anchor's lift.
## - release: standing is tested where the standing hull would be, the same feet on the floor,
##   the feet lowered by the same lift in flight. a blocked test keeps the duck hull and is
##   retried every tick with crouch up, as public CanUnduck / "still under something" does.
## - the lift is body-origin compensation, never travel: it is kept out of displacement,
##   actual velocity, speed, footsteps and the interpolated camera, and reported on its own.
## - p / air anchor "center": the box shrinks 9 u from each end, so a crouch in flight lifts
##   the feet 9 u and lowers the head 9 u. valve's cs:go mapper's reference measures 9 u more
##   ledge height for jump-then-crouch (64 vs 55 u at 128 tick), which this reproduces. "head"
##   is public source 2013's FinishDuck (feet +18 u), "feet" lifts nothing. none of the three
##   changes velocity, and a duck/stand pair in flight cancels exactly, so duck spam gains nothing.
## - the 1/3 duck speed crop (here r14's duck_multiplier) applies only to a tick that starts on
##   the floor, as public HandleDuckingSpeedCrop does; air acceleration ducked is unchanged.

## the new motion settings. apply_settings() fills any that a profile leaves out, so they always
## sit in `settings` and therefore in r14_presets.physics_fingerprint(settings).
const DUCK_DEFAULTS := {
	# valve developer community, cs:go mapper's reference: crouching height 54, eye 46.076.
	"duck_hull_height": 54.0,
	# p / 46.076 rounded the way r14 rounds standing 64.094 to 64.
	"duck_eye_height": 46.0,
	# p / "center", "head" (public source 2013) or "feet": where a crouch in flight anchors.
	"duck_air_anchor": "center",
	# p / seconds for the eye to travel the whole standing-to-duck height.
	"duck_eye_time": 0.1,
	# p / under a low face the eye sits no closer than this under the hull top, u.
	"duck_eye_clearance": 2.0,
	# false: the duck crop only on a tick that starts grounded (public source 2013).
	"duck_air_crop": false,
}
const MOTOR_ID := "r15_source_crouch"
const MOTOR_VERSION := "r15-source-crouch-1"

## the hull is the duck hull.
var ducked: bool = false
## crouch was held at this tick's command.
var duck_held: bool = false
## crouch is up while the duck hull stays because standing is blocked.
var stand_blocked: bool = false
var stand_blocked_ticks: int = 0
## cumulative counts since reset_to.
var duck_counts: Dictionary = {}
## this tick's body-origin compensation, metres (a duck or stand lift in flight).
var _duck_shift := Vector3.ZERO
## all compensation since reset_to, u: origin change = sum of physical travel + this.
var _duck_compensation_u := Vector3.ZERO
var _duck_events: Array[String] = []
var _stand_probe: Dictionary = {}
## the eye offset over the feet, u, at this and the previous motor step.
var _eye_u: float = 64.0
var _prev_eye_u: float = 64.0
var _eye_clamped: bool = false

func _init() -> void:
	settings = with_duck(settings)
	_clear_duck()

## a settings dictionary with every duck setting present; existing values win.
static func with_duck(cvars: Dictionary) -> Dictionary:
	var out := cvars.duplicate()
	for key: String in DUCK_DEFAULTS:
		if not out.has(key):
			out[key] = DUCK_DEFAULTS[key]
	return out

func apply_settings(next: Dictionary) -> void:
	super(with_duck(next))

func reset_to(pose: Transform3D) -> void:
	_clear_duck()
	super(pose)
	_eye_u = float(settings.eye_height)
	_prev_eye_u = _eye_u

func _clear_duck() -> void:
	ducked = false
	duck_held = false
	stand_blocked = false
	stand_blocked_ticks = 0
	duck_counts = {"duck": 0, "duck_air": 0, "unduck": 0, "unduck_air": 0, "stand_blocked": 0}
	_duck_shift = Vector3.ZERO
	_duck_compensation_u = Vector3.ZERO
	_duck_events = []
	_stand_probe = {}
	_eye_clamped = false

## the active hull height, u.
func hull_height_u() -> float:
	return float(settings.duck_hull_height) if ducked else float(settings.hull_height)

## how far the feet rise for a crouch in flight (and fall for standing in flight), u.
func air_lift_u() -> float:
	var delta := float(settings.hull_height) - float(settings.duck_hull_height)
	match str(settings.duck_air_anchor):
		"head":
			return delta
		"feet":
			return 0.0
	return delta * 0.5

func _fit_hull() -> void:
	var width := float(settings.hull_width) * U
	var height := hull_height_u() * U
	_box.size = Vector3(width, height, width)
	collision.position = Vector3(0.0, height * 0.5, 0.0)

## r14's tick with the duck step before the motor. while crouch stays up and the hull stands,
## _update_duck returns zero and changes nothing, so the motor sees r14's exact command.
func _physics_process(delta: float) -> void:
	_previous_position = _current_position
	_prev_eye_u = _eye_u
	var start := global_position
	_last_delta = delta
	if not input_enabled:
		_current_position = global_position
		_displacement = Vector3.ZERO
		_actual_velocity = Vector3.ZERO
		_depenetration = Vector3.ZERO
		_standoff = Vector3.ZERO
		_duck_shift = Vector3.ZERO
		_duck_events = []
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
	duck_held = Input.is_action_pressed("crouch")
	_yaw_delta = wrapf(yaw - _tick_yaw, -PI, PI)
	_tick_yaw = yaw
	state.position = global_position / U
	state.velocity = velocity / U
	_start_velocity = velocity
	_contacts = []
	_depenetration = Vector3.ZERO
	_standoff = Vector3.ZERO
	var was_grounded: bool = state.grounded
	_duck_shift = _update_duck(duck_held, was_grounded)
	# the lift is compensation: travel starts from the lifted origin, and the camera's previous
	# pose moves with it so interpolation never draws the lift as motion.
	start += _duck_shift
	_previous_position += _duck_shift
	_prev_eye_u -= _duck_shift.y / U
	_eye_u -= _duck_shift.y / U
	_duck_compensation_u += _duck_shift / U
	state.position = global_position / U
	crouched = ducked
	var crop := ducked and (was_grounded or bool(settings.duck_air_crop))
	var cmd := {"forward": forward, "side": _side, "yaw": yaw, "jump": jump, "ducked": crop, "in_water": in_water}
	MOTION.step(state, cmd, settings, delta, self)
	(state.events as Array).append_array(_duck_events)
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
	_step_eye(delta)

## the duck step. returns the body-origin compensation it applied, metres.
func _update_duck(held: bool, grounded: bool) -> Vector3:
	_duck_events = []
	_stand_probe = {}
	stand_blocked = false
	if held and not ducked:
		var lift := 0.0 if grounded else air_lift_u()
		var shift := Vector3.UP * lift * U
		# the duck hull at the lifted feet lies inside the standing hull it replaces, which was
		# clear, so this needs no test.
		ducked = true
		_fit_hull()
		global_position += shift
		stand_blocked_ticks = 0
		var kind := "duck" if grounded else "duck_air"
		duck_counts[kind] += 1
		_duck_events.append(kind)
		return shift
	if not held and ducked:
		var drop := 0.0 if grounded else air_lift_u()
		var target := global_position + Vector3.DOWN * drop * U
		var clear := _stand_clear(target)
		_stand_probe = {"target_u": target / U, "clear": clear, "grounded": grounded}
		if clear:
			var shift := target - global_position
			ducked = false
			_fit_hull()
			global_position = target
			stand_blocked_ticks = 0
			var kind := "unduck" if grounded else "unduck_air"
			duck_counts[kind] += 1
			_duck_events.append(kind)
			return shift
		stand_blocked = true
		if stand_blocked_ticks == 0:
			duck_counts.stand_blocked += 1
			_duck_events.append("stand_blocked")
		stand_blocked_ticks += 1
	return Vector3.ZERO

## true when the standing hull at `feet` overlaps nothing within godot's minimum test margin.
## the box is resized for the test and restored; the standing hull contains the duck hull at
## the same anchor, so this static test covers every point the change passes through.
func _stand_clear(feet: Vector3) -> bool:
	var width := float(settings.hull_width) * U
	var height := float(settings.hull_height) * U
	var kept_size := _box.size
	var kept_position := collision.position
	_box.size = Vector3(width, height, width)
	collision.position = Vector3(0.0, height * 0.5, 0.0)
	var blocked := test_move(Transform3D(global_transform.basis, feet), Vector3.ZERO, null, GUARD_MARGIN, true, 1)
	_box.size = kept_size
	collision.position = kept_position
	return not blocked

## the eye offset eases toward the active hull's eye. while it is still above the clearance
## under the hull top, it is held there only when the standing hull at these feet would touch
## something: the space a duck gave up was clear when it was given up, so in the open the eye
## eases without a pop, and under a low face the camera never shows above the box.
func _step_eye(delta: float) -> void:
	var stand := float(settings.eye_height)
	var low := float(settings.duck_eye_height)
	var target := low if ducked else stand
	var rate := absf(stand - low) / maxf(float(settings.duck_eye_time), 1e-6)
	_eye_u = move_toward(_eye_u, target, rate * delta)
	var cap := hull_height_u() - float(settings.duck_eye_clearance)
	_eye_clamped = _eye_u > cap and not _stand_clear(global_position)
	if _eye_clamped:
		_eye_u = cap

func _update_eye(_delta: float) -> void:
	if camera == null:
		return
	var fraction := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	var feet := _previous_position.lerp(_current_position, fraction)
	camera.global_position = feet + Vector3.UP * lerpf(_prev_eye_u, _eye_u, fraction) * U
	camera.global_rotation = Vector3(pitch, yaw, 0.0)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(float(settings.fov)) * 0.5) * 0.75))

## r14's report plus the hull, the duck request and the compensation, kept apart from travel:
## `displacement` and `actual_velocity` are physical travel; `origin_delta` adds the lift.
func get_motion_state() -> Dictionary:
	var out := super()
	var feet := global_position / U
	out["motor"] = MOTOR_ID
	out["motor_version"] = MOTOR_VERSION
	out["crouched"] = ducked
	out["hull"] = {"width_u": float(settings.hull_width), "height_u": hull_height_u(), "ducked": ducked, "feet_u": feet.y, "top_u": feet.y + hull_height_u()}
	out["duck"] = {
		"held": duck_held,
		"ducked": ducked,
		# what crouch asks of the hull this tick: "duck", "stand" or "" when they already agree.
		"request": "stand" if ducked and not duck_held else ("duck" if duck_held and not ducked else ""),
		"stand_blocked": stand_blocked,
		"blocked_ticks": stand_blocked_ticks,
		"stand_probe": _stand_probe.duplicate(),
		"anchor": str(settings.duck_air_anchor),
		"air_lift_u": air_lift_u(),
		"shift_u": _duck_shift / U,
		"compensation_u": _duck_compensation_u,
		"eye_u": _eye_u,
		"eye_target_u": float(settings.duck_eye_height) if ducked else float(settings.eye_height),
		"eye_clamped": _eye_clamped,
		"counts": duck_counts.duplicate(),
		"events": _duck_events.duplicate(),
	}
	out["duck_shift"] = _duck_shift
	out["origin_delta"] = _displacement + _duck_shift
	out["eye_height_u"] = _eye_u
	return out

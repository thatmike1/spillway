extends Resource
## tuning in metres, seconds, radians. letters refer to the supplied movement spec.

# ground momentum, speed targets (H), reconstructed acceleration (M).
@export var speed_knots: PackedFloat32Array = [0, .72, 1.44, 2.16, 2.88, 3.60, 4.32, 5.04, 5.76, 6.48, 7.20]
@export var acceleration_knots: PackedFloat32Array = [10, 10, 10, 10, 10, 6.74839, 2, 2, .52, .446154, 0]
# ground momentum, gait and walking targets (H).
@export var base_speed: float = 4.0
@export var maximum_speed: float = 7.2
@export var sprint_input_gate: float = .70
# turning, velocity error gains (M).
@export var forward_gain: float = 7.0
@export var strafe_gain: float = 10.0
@export var sprint_gain: float = 30.0
# turning, energy decay (H numbers, M equation).
@export var energy_decay_time: float = 3.0
@export var energy_decay_exponent: float = .5
# turning, unreal input mapped from yaw radians/second divided by PI (P).
@export var turn_loss: float = 10.0
# turning, no-input braking coefficient and stop threshold (M).
@export var ground_friction: float = 8.0
@export var braking_strength: float = .5
@export var stop_speed: float = .10
# jumping, impulse and conditional forward addition (H).
@export var jump_speed: float = 6.30
@export var jump_forward: float = 1.0
@export var jump_forward_gate: float = .10
# units/player dimensions, gravity and terminal speed (H).
@export var gravity: float = 8.0
@export var terminal_speed: float = 35.0
# jumping, air-control fraction times acceleration limit (M).
@export var acceleration_limit: float = 61.44
@export var air_control: float = .025
# units/player dimensions (H); eye offset above centre is .76.
@export var standing_height: float = 1.80
@export var low_height: float = 1.22
@export var radius: float = .30
@export var standing_eye: float = .76
@export var step_height: float = .35
@export var walkable_normal: float = .71
# landings, ordinary pre-jump speed reduction (H).
@export var landing_reduction: float = .65
# jumping, unproven general assistance: Foldrunner extensions (P, default off).
@export var coyote_time: float = .10
@export var jump_buffer: float = .12

# landings, fall-height selection and roll press windows (H).
@export var roll_height: float = 2.0
@export var hard_height: float = 5.30
@export var death_height: float = 10.0
@export var roll_window: float = .20
@export var roll_retrigger: float = .60
# animation timing/displacement, original resynthesis profile (H totals, P profile).
@export var roll_duration: float = 1.26667
@export var roll_distance: float = 3.13517
@export var hard_duration: float = 2.0
# vaults, clearance and variant saved-speed/timing contracts (H).
@export var vault_clearance: float = .35
@export var vault_reach_time: float = .4
@export var vault_fast_min: float = 4.0
@export var vault_fast_max: float = 7.2
@export var vault_fast_add: float = .8
@export var vault_fast_over: float = .35
@export var vault_fast_down: float = .30
@export var vault_high_min: float = 2.0
@export var vault_high_max: float = 4.0
@export var vault_high_up: float = .28
@export var vault_high_over: float = .30
@export var vault_high_down: float = .45
@export var vault_high_onto_up: float = .27
@export var vault_high_onto_down: float = .60
@export var vault_low_height: float = .64
@export var vault_fast_height: float = 1.48
@export var vault_high_height: float = 1.92
@export var vault_high_gate: float = .50
@export var vault_slow_over: float = .40
@export var vault_slow_down: float = .25
# ledges, alignment, hang offset and pull-up (H, M original clip totals).
@export var grab_speed: float = 3.0
@export var grab_drop: float = .928
@export var grab_reach: float = 2.0
@export var grab_repeat: float = .15
@export var pull_duration: float = 1.53333
@export var pull_look_release: float = .8
@export var pull_collision_release: float = 1.4
@export var pull_forward: float = .67844
# horizontal wall run, contact probes and vertical phases (H/M).
@export var wall_min_speed: float = 2.0
@export var wall_begin_speed: float = 3.0
@export var wall_probe: float = .5
@export var wall_min_height: float = 1.92
@export var wall_height_budget: float = 1.70
@export var wall_up_accel: float = 8.20
@export var wall_down_accel: float = 5.0
@export var wall_friction: float = .05
@export var wall_exit_vertical: float = -5.0
@export var wall_repeat: float = .15
@export var wall_illegal_time: float = 2.0
# wall-run jump, outward/tangent/height equations (H).
@export var wall_push: float = 1.20
@export var wall_push_turned: float = 4.0
@export var wall_tangent_min: float = .10
@export var wall_jump_height: float = 1.0
@export var wall_jump_turned: float = .60
# vertical climb, budget contributions and gravity (H, P native integration).
@export var climb_distance: float = 1.20
@export var climb_angle: float = 33.0
@export var climb_horizontal_height: float = .60
@export var climb_vertical_height: float = 1.30
@export var climb_speed_min: float = 4.0
@export var climb_speed_max: float = 6.50
@export var climb_vertical_max: float = 3.20
@export var climb_friction: float = 6.0
# slide/crouch, entry, lock, friction, exit and look limits (H).
@export var slide_min: float = 3.50
@export var slide_abort: float = 2.50
@export var slide_duration: float = 2.0
@export var slide_lock: float = .50
@export var slide_friction: float = .10
@export var slide_exit: float = .50
@export var slide_look: float = 54.93
@export var crouch_pitch: float = 76.90
# 180 turn, locks, repeat and clip lengths (H).
@export var turn_lock: float = .30
@export var turn_repeat: float = .50
@export var turn_friction: float = .30
@export var turn_run_duration: float = 1.03333
@export var turn_stand_duration: float = .80
@export var turn_air_duration: float = .60
# springboard, paired geometry and ballistic launch (H).
@export var spring_intermediate: float = .64
@export var spring_separation: float = 1.12
@export var spring_tolerance: float = .20
@export var spring_min_height: float = .80
@export var spring_max_height: float = 1.48
@export var spring_launch_y: float = 9.50
@export var spring_min_speed: float = 2.0
@export var spring_launch_min: float = 4.0
@export var spring_launch_cost: float = 1.0
# step-up, special steps and durations from original measurement (H/M).
@export var step_reach: float = .60
@export var step_speed_limit: float = 3.0
@export var step_low: float = .48
@export var step_medium: float = .88
@export var step_high: float = 1.44
@export var step_times: Vector3 = Vector3(.36667, .66667, 1.20)
# precise trajectories: collision margin and original profile shape (P).
@export var contact_margin: float = .035
@export var trajectory_lift_fraction: float = .22

func acceleration(speed: float) -> float:
	for i: int in range(1, speed_knots.size()):
		if speed <= speed_knots[i]:
			return lerpf(acceleration_knots[i - 1], acceleration_knots[i], inverse_lerp(speed_knots[i - 1], speed_knots[i], speed))
	return 0.0

func ground_velocity(old: Vector3, wish: Vector3, forward: Vector3, yaw_rate: float, dt: float, crouched: bool = false) -> Vector3:
	var speed: float = old.length()
	if wish.length() < .01:
		# no duplicate Godot damping; averaged native-style friction substep (M).
		var h: float = minf(dt, .03)
		var next: Vector3 = old * maxf(0.0, 1.0 - 2.0 * ground_friction * braking_strength * h)
		var stopped: Vector3 = (old + next) * .5
		return Vector3.ZERO if stopped.length() < stop_speed else stopped
	var direction: Vector3 = wish.normalized()
	var alignment: float = direction.dot(forward)
	var accel: Vector3
	if alignment > sprint_input_gate and wish.length() > sprint_input_gate and old.dot(wish) >= 0 and not crouched:
		var error: Vector3 = direction * speed - old
		accel = direction * acceleration(speed) + error.limit_length(error.length() / maxf(dt, .00001)) * minf(sprint_gain, 1.0 / dt)
		if speed > .01:
			accel -= old / speed * turn_loss * absf(yaw_rate) / PI
	else:
		var energy: float = maxf(speed - base_speed, 0.0)
		energy = maxf(0.0, energy - (maximum_speed - base_speed) / energy_decay_time * (1.0 - pow(clampf(alignment, 0, .9), energy_decay_exponent)) * dt)
		var target: Vector3 = wish * (base_speed + energy) * (.20 if crouched else 1.0)
		var error: Vector3 = target - old
		var forward_error: Vector3 = forward * error.dot(forward)
		accel = forward_error * forward_gain + (error - forward_error) * strafe_gain
	return old + accel.limit_length(acceleration_limit) * dt

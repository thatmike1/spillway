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

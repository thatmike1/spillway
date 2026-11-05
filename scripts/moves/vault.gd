extends RefCounted
## precise up/over/down owner. saved exit velocity is final-stage displacement/time.
var time: float = 0.0
var duration: float
var saved_speed: float
var variant: String
var points: Array[Vector3] = []
var times: Array[float] = []
var exit_velocity: Vector3
var flowing: bool = false
var approach: float
var path_forward: Vector3
var path_up: Vector3
var rise_distance: float
var clear_distance: float
var onto_surface: bool
var hand: Vector3

func start(p, edge: Dictionary, high: bool, onto: bool = false) -> void:
	var t = p.tuning
	var forward: Vector3 = edge.into
	var top: Vector3 = edge.top
	approach = p.get_speed()
	flowing = not high and approach > 2
	path_forward = forward
	path_up = p.up_direction
	onto_surface = onto
	hand = top
	time = 0
	var up_time: float
	var over_time: float
	var down_time: float
	if high:
		variant = "high_onto" if onto else "high_over"
		saved_speed = clampf(p.get_speed(), t.vault_high_min, t.vault_high_max)
		up_time = t.vault_high_onto_up if onto else t.vault_high_up
		over_time = t.vault_high_over
		down_time = t.vault_high_onto_down if onto else t.vault_high_down
	elif p.get_speed() <= 2:
		variant = "slow_onto"
		saved_speed = clampf(p.get_speed(), 2, 7)
		up_time = 0
		over_time = t.vault_slow_over
		down_time = t.vault_slow_down
	else:
		variant = "fast_onto" if onto else "fast_over"
		saved_speed = clampf(p.get_speed() + t.vault_fast_add, t.vault_fast_min, t.vault_fast_max)
		up_time = 0
		over_time = t.vault_fast_over
		down_time = t.vault_fast_down
	# zero authored up time still needs collision clearance: fold the lift into over.
	var lift: Vector3 = p.global_position + p.up_direction * (top - (p.global_position - p.up_direction * .9)).dot(p.up_direction)
	lift += p.up_direction * t.vault_clearance
	var crest: Vector3 = top + p.up_direction * (.9 + t.vault_clearance) + forward * (float(edge.depth) + t.radius)
	var end: Vector3 = crest + forward * saved_speed * down_time - p.up_direction * t.vault_clearance
	if not onto:
		end -= p.up_direction * float(edge.height)
	points = [p.global_position, lift, crest, end]
	if up_time > 0:
		times = [up_time, over_time, down_time]
	else:
		times = [over_time * t.trajectory_lift_fraction, over_time * (1 - t.trajectory_lift_fraction), down_time]
	duration = times[0] + times[1] + times[2]
	if flowing:
		# port choice (P): lift completes before the capsule front reaches the rail.
		var face_distance: float = maxf(.4, (top - p.global_position).dot(forward))
		rise_distance = maxf(.10, face_distance - t.radius - .12)
		clear_distance = face_distance + (0.0 if onto else float(edge.depth)) + t.radius + .12
		exit_velocity = forward * saved_speed
	else:
		exit_velocity = (end - crest).slide(p.up_direction) / down_time
	p.velocity = Vector3.ZERO
	p.move = p.Move.VAULT
	p.grounded = false
	p._climb_hand = hand
	p.move_started.emit("high_vault" if high else "vault")

func step(p, dt: float) -> void:
	time += dt
	var local: float = time
	var target: Vector3 = points[3]
	for i: int in 3:
		if local <= times[i]:
			target = points[i].lerp(points[i + 1], clampf(local / times[i], 0, 1))
			break
		local -= times[i]
	if flowing:
		var f: float = clampf(time / duration, 0, 1)
		var distance: float = _distance(f)
		var total: float = _distance(1)
		var lift: float = (points[2] - points[0]).dot(path_up)
		var y: float = lift * smoothstep(0, rise_distance, distance)
		var end_y: float = (points[3] - points[0]).dot(path_up)
		y = lerpf(y, end_y, smoothstep(clear_distance, maxf(clear_distance + .1, total), distance))
		target = points[0] + path_forward * distance + path_up * y
	var before: Vector3 = p.global_position
	var hit = p.sweep_motion(target - before)
	if hit != null and hit.get_normal().dot(p.up_direction) < .7:
		p.move = p.Move.AIR
		p.velocity = Vector3.ZERO
		return
	p.velocity = (p.global_position - before) / dt
	if time + .000001 >= duration:
		p.move = p.Move.AIR
		p.velocity = exit_velocity
		p._vault_landing = true
		p._since_jump = .2

# port choice (P): integrate a smooth speed trough, continuous at entry and release.
func _distance(f: float) -> float:
	return duration * (approach * f + .5 * (saved_speed - approach) * f * f - .22 * approach * (.5 * f - sin(TAU * f) / (4 * PI)))

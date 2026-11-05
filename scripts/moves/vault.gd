extends RefCounted
## precise up/over/down owner. saved exit velocity is final-stage displacement/time.
var time: float = 0.0
var duration: float
var saved_speed: float
var variant: String
var points: Array[Vector3] = []
var times: Array[float] = []
var exit_velocity: Vector3
var hand: Vector3

func start(p, edge: Dictionary, high: bool, onto: bool = false) -> void:
	var t = p.tuning
	var forward: Vector3 = edge.into
	var top: Vector3 = edge.top
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
	var hit = p.sweep_motion(target - p.global_position)
	if hit != null and hit.get_normal().dot(p.up_direction) < .7:
		p.move = p.Move.AIR
		p.velocity = Vector3.ZERO
		return
	if time >= duration:
		p.move = p.Move.AIR
		p.velocity = exit_velocity
		p._vault_landing = true
		p._since_jump = .2

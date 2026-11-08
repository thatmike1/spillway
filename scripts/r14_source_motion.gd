extends RefCounted
## p / r14 source motion: an original reimplementation of the public source / cs:go movement
## rules (projection acceleration, friction with stopspeed, the 30 u air cap, gravity and the
## jump impulse). no engine code is copied. everything here is in source units: u, u/s, u/s²,
## seconds, godot axes (y up). the collision adapter converts at its boundary with U.
## the tick order is one function, step(), shared by the flat-plane check world below and the
## real collision adapter, so the order can be checked without godot collision.
## docs/r14/SOURCE-IMPLEMENTATION.md names every constant's evidence and every reconstruction.

## p / 1 u = 0.0254 m, the hammer inch convention (docs/r14/SOURCE-REFERENCE.md).
const U := 0.0254

## shared by both cs:go presets. values are the legacy cs:go reference cvars; the policy keys
## below them are labelled reconstructions or choices, never claims of binary fidelity.
const BASE := {
	"sv_gravity": 800.0,
	"sv_accelerate": 5.5,
	"sv_friction": 5.2,
	"sv_stopspeed": 80.0,
	"sv_maxspeed": 320.0,
	"sv_maxvelocity": 3500.0,
	"sv_air_max_wishspeed": 30.0,
	"sv_jump_impulse": 301.993377,
	"sv_stepsize": 18.0,
	"sv_walkable_normal": 0.7,
	"cl_forwardspeed": 450.0,
	"cl_sidespeed": 450.0,
	# p / knife-like player wishspeed. not sv_maxspeed, and no airborne speed ceiling.
	"player_maxspeed": 250.0,
	# above this upward speed the ground probe is skipped (public source2013 value).
	"non_jump_velocity": 140.0,
	"ground_probe": 2.0,
	# p / duck only scales ground wishspeed here; the hull does not shrink (limitation).
	"duck_multiplier": 0.34,
	"water_multiplier": 0.8,
	# "legacy": budget uses the uncapped wishspeed. "capped": diagnostic comparison only.
	"air_budget": "legacy",
	# "deadstrafe": air surface friction 0.25 while airborne with 0 < vy <= 140, else 1.
	# "constant": always 1, a labelled simplification.
	"air_surface": "deadstrafe",
	# "source2013": impulse added after a half gravity step with another half before the
	# first drift (sampled apex J - g h / 2). "ideal": exact ballistic J. neither is verified
	# against the late-legacy cs:go binary.
	"jump_order": "source2013",
	# p / reconstruction: walking clamps horizontal speed to player_maxspeed, lowered by
	# the stamina penalty. a perfect hop never walks, so it never sees this clamp.
	"ground_speed_clamp": true,
	# p / reconstruction: with sv_enablebunnyhopping 0, takeoff clamps horizontal speed to
	# this factor times player_maxspeed (275 u/s). airborne speed is never clamped.
	"jump_clamp_factor": 1.1,
	# "gokz_fit": p / reconstruction fitted to the gokz authors' published observations
	# (250 -> 183.05 u/s and jump 55 -> 40 u at landcost 0.05; 221.97 u/s at 0.02).
	# "off": no penalty. the exact vanilla stamina equation is unresolved.
	"stamina_model": "gokz_fit",
	# p / opt-in: treat mouse wheel notches as jump press edges, as scroll binds do.
	"wheel_jump": false,
	# camera, in source conventions. sensitivity × m_yaw degrees per mouse count; fov is the
	# 4:3 reference horizontal angle. p / default sensitivity equals r13's 0.0022 rad/count.
	"sensitivity": 5.729578,
	"m_yaw": 0.022,
	"m_pitch": 0.022,
	"fov": 90.0,
	"eye_height": 64.0,
	"hull_width": 32.0,
	"hull_height": 72.0,
}

const PRESETS := {
	# matchmaking-like: 64 Hz, aa12, manual press edges, jump clamp and stamina.
	"csgo_vanilla": {
		"label": "CS:GO vanilla",
		"tickrate": 64,
		"sv_airaccelerate": 12.0,
		"sv_enablebunnyhopping": false,
		"sv_autobunnyhopping": false,
		"sv_staminamax": 80.0,
		"sv_staminajumpcost": 0.08,
		"sv_staminalandcost": 0.05,
		"sv_staminarecoveryrate": 60.0,
	},
	# community bhop-server style: 128 Hz, aa100, held-jump reissue, no clamp, no stamina.
	"csgo_server": {
		"label": "CS:GO bhop server",
		"tickrate": 128,
		"sv_airaccelerate": 100.0,
		"sv_enablebunnyhopping": true,
		"sv_autobunnyhopping": true,
		# the public friction law is the only grounded slowdown in the no-stamina baseline.
		"ground_speed_clamp": false,
		"sv_staminamax": 0.0,
		"sv_staminajumpcost": 0.0,
		"sv_staminalandcost": 0.0,
		"sv_staminarecoveryrate": 0.0,
	},
}

static func preset(name: String) -> Dictionary:
	assert(PRESETS.has(name), "source motion: unknown preset " + name)
	var cvars := BASE.duplicate()
	cvars.merge(PRESETS[name], true)
	cvars["preset"] = name
	return cvars

static func forward_of(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

static func right_of(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))

## the yaw whose side key (side = ±1, no forward) wishes along `direction`.
static func yaw_for_side(direction: Vector3, side: float) -> float:
	var right := direction * signf(side)
	return atan2(-right.z, right.x)

## horizontal wish from key axes in [-1, 1]: forwardmove/sidemove at cl speeds, then the
## player's wishspeed limit. returns {dir, speed}; speed 0 means no wish.
static func wish(forward: float, side: float, yaw: float, cvars: Dictionary, ducked := false, in_water := false) -> Dictionary:
	var vel := forward_of(yaw) * forward * float(cvars.cl_forwardspeed) + right_of(yaw) * side * float(cvars.cl_sidespeed)
	var length := vel.length()
	if length < 1e-6:
		return {"dir": Vector3.ZERO, "speed": 0.0}
	var speed := minf(length, minf(float(cvars.player_maxspeed), float(cvars.sv_maxspeed)))
	if ducked:
		speed *= float(cvars.duck_multiplier)
	if in_water:
		speed *= float(cvars.water_multiplier)
	return {"dir": vel / length, "speed": speed}

## ground friction on horizontal velocity: below stopspeed the drop uses stopspeed.
static func friction(vel: Vector3, cvars: Dictionary, dt: float, surface := 1.0) -> Vector3:
	var speed := vel.length()
	if speed < 0.1:
		return Vector3.ZERO
	var control := maxf(speed, float(cvars.sv_stopspeed))
	var drop := control * float(cvars.sv_friction) * surface * dt
	return vel * (maxf(0.0, speed - drop) / speed)

## ground projection acceleration toward wishspeed along dir.
static func accelerate(vel: Vector3, dir: Vector3, wishspeed: float, accel: float, dt: float, surface := 1.0) -> Vector3:
	var room := wishspeed - vel.dot(dir)
	if room <= 0.0 or wishspeed <= 0.0:
		return vel
	return vel + dir * minf(accel * wishspeed * dt * surface, room)

## air projection acceleration: the 30 u cap limits the projection on the wish direction,
## the budget uses the uncapped wishspeed unless the diagnostic "capped" mode is chosen.
static func air_budget(wishspeed: float, cvars: Dictionary, dt: float, surface := 1.0) -> float:
	var cap := minf(wishspeed, float(cvars.sv_air_max_wishspeed))
	var budget_speed := cap if cvars.air_budget == "capped" else wishspeed
	return float(cvars.sv_airaccelerate) * budget_speed * dt * surface

static func air_accelerate(vel: Vector3, dir: Vector3, wishspeed: float, cvars: Dictionary, dt: float, surface := 1.0) -> Vector3:
	if wishspeed <= 0.0:
		return vel
	var room := minf(wishspeed, float(cvars.sv_air_max_wishspeed)) - vel.dot(dir)
	if room <= 0.0:
		return vel
	return vel + dir * minf(air_budget(wishspeed, cvars, dt, surface), room)

## the surface multiplier the next air update uses, chosen when position is categorized.
static func air_surface_friction(vy: float, cvars: Dictionary) -> float:
	if cvars.air_surface == "deadstrafe" and vy > 0.0 and vy <= float(cvars.non_jump_velocity):
		return 0.25
	return 1.0

## p / stamina reconstruction. s is the penalty in [0, sv_staminamax]; f = 1 - s / 100.
## the jump impulse scales with f and the walking clamp with f², which reproduces both gokz
## observations for one fall speed; it is a fit, not the cs:go equation.
static func stamina_factor(stamina: float, cvars: Dictionary) -> float:
	if cvars.stamina_model == "off":
		return 1.0
	return clampf(1.0 - stamina / 100.0, 0.0, 1.0)

static func add_stamina(stamina: float, amount: float, cvars: Dictionary) -> float:
	if cvars.stamina_model == "off":
		return 0.0
	return clampf(stamina + amount, 0.0, float(cvars.sv_staminamax))

static func new_state(position := Vector3.ZERO) -> Dictionary:
	return {
		"tick": 0, "position": position, "velocity": Vector3.ZERO, "grounded": false,
		"ground_normal": Vector3.ZERO, "stamina": 0.0, "pending_land": 0.0, "surface": 1.0,
		"jump_prev": false, "ground_ticks": 0, "air_ticks": 0, "jump_count": 0,
		"land_count": 0, "perfect_count": 0, "fall_speed": 0.0, "events": [],
		"wish_dir": Vector3.ZERO, "wish_speed": 0.0, "air_gain": 0.0, "requested": Vector3.ZERO,
		"takeoff_speed": 0.0, "landing_speed": 0.0, "ledger": {},
	}

## one movement tick. cmd: {forward, side, yaw, jump, ducked, in_water}. world implements
## walk_move(state, dt), air_move(state, dt) (both move state.position with state.velocity
## and clip it) and probe_ground(state) -> walkable normal or ZERO.
static func step(s: Dictionary, cmd: Dictionary, cvars: Dictionary, dt: float, world: Object) -> void:
	var events: Array = []
	var ledger := {}
	s.tick += 1
	var g := float(cvars.sv_gravity)
	# p / order: recovery first, then a landing's pending cost, so the penalty the first
	# walking tick sees is the full landing cost (the ratio the gokz numbers imply).
	s.stamina = add_stamina(s.stamina, -float(cvars.sv_staminarecoveryrate) * dt, cvars)
	if s.pending_land > 0.0:
		s.stamina = add_stamina(s.stamina, s.pending_land, cvars)
		s.pending_land = 0.0
	var w := wish(float(cmd.get("forward", 0.0)), float(cmd.get("side", 0.0)), float(cmd.get("yaw", 0.0)), cvars, bool(cmd.get("ducked", false)), bool(cmd.get("in_water", false)))
	s.wish_dir = w.dir
	s.wish_speed = w.speed
	var v: Vector3 = s.velocity
	# a landing's fall speed is the descent this tick began with, before contact clips it.
	var descent := maxf(0.0, -v.y)
	# start gravity: half a step before movement.
	v.y -= 0.5 * g * dt
	var grounded: bool = s.grounded
	var jump := bool(cmd.get("jump", false))
	var jumped := false
	# the jump check runs before friction and walking. a held jump from the previous command
	# blocks it unless autobunnyhopping; a press in the air is not remembered.
	if jump and grounded and (bool(cvars.sv_autobunnyhopping) or not s.jump_prev):
		jumped = true
		var h := Vector3(v.x, 0.0, v.z)
		if not bool(cvars.sv_enablebunnyhopping):
			var limit := float(cvars.jump_clamp_factor) * float(cvars.player_maxspeed)
			if h.length() > limit:
				ledger["jump_clamp"] = h.normalized() * limit - h
				h = h.normalized() * limit
		var impulse := float(cvars.sv_jump_impulse) * stamina_factor(s.stamina, cvars)
		if cvars.jump_order == "source2013":
			# impulse on top of the half gravity step, then another half before the drift.
			v.y = v.y + impulse - 0.5 * g * dt
		else:
			v.y = impulse - 0.5 * g * dt
		v.x = h.x
		v.z = h.z
		s.stamina = add_stamina(s.stamina, float(cvars.sv_staminajumpcost) * impulse, cvars)
		if s.ground_ticks == 1:
			s.perfect_count += 1
			events.append("perfect")
		s.takeoff_speed = h.length()
		grounded = false
		s.grounded = false
		s.ground_normal = Vector3.ZERO
		s.jump_count += 1
		events.append("jump")
	var h := Vector3(v.x, 0.0, v.z)
	var before := h
	if grounded:
		v.y = 0.0
		h = friction(h, cvars, dt)
		ledger["friction"] = h - before
		var pushed := accelerate(h, w.dir, w.speed, float(cvars.sv_accelerate), dt)
		ledger["ground_accel"] = pushed - h
		h = pushed
		if bool(cvars.ground_speed_clamp):
			var f := stamina_factor(s.stamina, cvars)
			var limit := float(cvars.player_maxspeed) * f * f
			if h.length() > limit:
				ledger["ground_clamp"] = h.normalized() * limit - h
				h = h.normalized() * limit
		s.air_gain = 0.0
	else:
		var pushed := air_accelerate(h, w.dir, w.speed, cvars, dt, float(s.surface))
		s.air_gain = pushed.length() - h.length()
		ledger["air_accel"] = pushed - h
		h = pushed
	v.x = h.x
	v.z = h.z
	var cap := float(cvars.sv_maxvelocity)
	v = Vector3(clampf(v.x, -cap, cap), clampf(v.y, -cap, cap), clampf(v.z, -cap, cap))
	s.velocity = v
	s.requested = v
	if grounded:
		world.call("walk_move", s, dt)
	else:
		world.call("air_move", s, dt)
	v = s.velocity
	# categorize: fast upward travel skips the probe; otherwise a walkable face within the
	# probe distance below is support. there is no snap here, a hop may leave from 2 u up.
	var normal := Vector3.ZERO
	if v.y <= float(cvars.non_jump_velocity):
		normal = world.call("probe_ground", s)
	if normal != Vector3.ZERO:
		if not grounded:
			s.fall_speed = descent
			s.landing_speed = Vector2(v.x, v.z).length()
			s.pending_land = float(cvars.sv_staminalandcost) * s.fall_speed
			s.land_count += 1
			events.append("land")
		s.grounded = true
		s.ground_normal = normal
		s.surface = 1.0
		v.y = 0.0
	else:
		s.grounded = false
		s.ground_normal = Vector3.ZERO
		s.surface = air_surface_friction(v.y, cvars)
		# finish gravity: the second half step.
		v.y -= 0.5 * g * dt
	s.velocity = v
	s.ground_ticks = s.ground_ticks + 1 if s.grounded else 0
	s.air_ticks = 0 if s.grounded else s.air_ticks + 1
	s.jump_prev = jump
	s.events = events
	s.ledger = ledger

## an infinite walkable plane at y = 0 with no other geometry: the ordering check world.
class FlatWorld:
	extends RefCounted
	var probe := 2.0

	func walk_move(s: Dictionary, dt: float) -> void:
		s.position += s.velocity * dt

	func air_move(s: Dictionary, dt: float) -> void:
		var next: Vector3 = s.position + s.velocity * dt
		if next.y < 0.0:
			# stop on the plane and lose only the component into it.
			next.y = 0.0
			var v: Vector3 = s.velocity
			v.y = maxf(v.y, 0.0)
			s.velocity = v
		s.position = next

	func probe_ground(s: Dictionary) -> Vector3:
		return Vector3.UP if (s.position as Vector3).y <= probe else Vector3.ZERO

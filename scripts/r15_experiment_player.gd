extends "res://scripts/r15_source_player.gd"
## p / r15 movement lab runner: the approved r15 crouch runner with three optional, labelled
## experimental moves layered on top. it plays only on the lab map (r15_main.gd picks it there and
## nowhere else). nothing here clones the source tick: every move is either a velocity impulse
## written to the body before the inherited tick reads it (the node's velocity is authoritative
## between ticks, as r14 documents), or, for the slide, the inherited duck request plus a lower
## ground friction for the ticks the slide lasts. the inherited motor then moves the body with its
## own collide-and-slide, so nothing is ever placed by a move.
##
## off means off: with a move disabled its input is ignored, and with no Shift, no E and no fresh
## Space press in the air within reach of a wall, the tick is r15's exactly (no velocity write, the
## approved settings dictionary, the approved duck request). docs/r15/EXPERIMENT.md has the laws,
## the caps and the evidence.
##
## - slide (Shift): starts on a fresh press while grounded, not holding jump, at 180 u/s or more.
##   it ducks the real hull (on the ground, so no lift) and plays the inherited ground move at
##   sv_friction 0.25 instead of 5.2. the duck crop still limits steering to the 85 u/s crouch wish.
##   it ends on release, after 1.5 s, below 100 u/s or off the ground; a new one needs a fresh
##   press after a 0.5 s cooldown. it never adds speed. the slide's duck is released only on the
##   ground, so a slide never causes an air hull change; standing still waits for room as crouch does.
## - wall jump (Space): a fresh press while airborne with a vertical face within 6 u of the hull.
##   the outward speed off the wall is set to 230 u/s and vertical speed to at least 290 u/s;
##   horizontal speed may rise to 340 u/s at most, and never above what it was when it was higher.
##   three per flight, 0.25 s apart, never off the same face twice in a row; landing resets them.
## - grapple (hold E): latches onto a marked anchor within 30 m and 9 degrees of the view, with a
##   clear line from the eye. rope law: an inelastic rope that reels in at 260 u/s to 96 u; while
##   taut it removes outward speed and adds a spring pull of 30/s² per unit of slack, capped at
##   1300 u/s², and never raises speed above max(speed before, 650 u/s). release coasts. the line
##   breaks when it is blocked, after 3 s, 80 u past range, when the move is turned off or on reset.

const EXPERIMENT_VERSION := "r15-lab-moves-1"
const SLIDE_ACTION := "r15_slide"
const GRAPPLE_ACTION := "r15_grapple"
const ANCHOR_GROUP := "r15_grapple_anchor"
const MOVES := ["slide", "wall_jump", "grapple"]

## p / all tuning, in source units (u, u/s, u/s², s). each table enters the record identity.
const SLIDE := {"law": "r15-lab-slide-1", "friction": 0.25, "min_entry_ups": 180.0, "end_ups": 100.0, "max_s": 1.5, "cooldown_s": 0.5}
const WALL := {"law": "r15-lab-wall-jump-1", "reach_u": 6.0, "max_normal_y": 0.2, "out_ups": 230.0, "up_ups": 290.0, "speed_cap_ups": 340.0,
	"max_per_flight": 3, "cooldown_s": 0.25}
const GRAPPLE := {"law": "r15-lab-grapple-1", "range_u": 1181.0, "aim_cone_deg": 9.0, "reel_ups": 260.0, "min_length_u": 96.0,
	"stiffness": 30.0, "max_pull_ups2": 1300.0, "speed_cap_ups": 650.0, "max_s": 3.0, "stretch_u": 80.0, "anchor_clear_m": 0.3}
## the eight horizontal directions the wall probe sweeps the hull along.
const PROBES := 8

## p / the default lab loadout: every move on. the pause menu and the 1/2/3 keys change it.
var enabled: Dictionary = {"slide": true, "wall_jump": true, "grapple": true}

var slide_active: bool = false
var slide_ticks: int = 0
var slide_cooldown: int = 0
var slide_count: int = 0
var slide_end_reason: String = ""
## the slide holds the duck hull until the body is on the ground with the slide over.
var _slide_duck: bool = false
var _slide_cvars: Dictionary = {}
var _slide_press: bool = false

var wall_jumps_flight: int = 0
var wall_cooldown: int = 0
var wall_jump_count: int = 0
var wall_refusal: String = ""
var _last_wall: String = ""
var _wall_press: bool = false
var _wall_probe: Dictionary = {}

## the anchor in use: {name, position (m)}, or empty.
var grapple: Dictionary = {}
var grapple_length_u: float = 0.0
var grapple_ticks: int = 0
var grapple_count: int = 0
var grapple_release_reason: String = ""
## what the view points at when no line is attached: {state: ok|blocked|far|none, name, distance_m}.
var grapple_target: Dictionary = {"state": "none"}
var _grapple_press: bool = false
var _grapple_needs_press: bool = false

## this tick's events and velocity changes by cause (u/s), and their running totals since reset.
var lab_events: Array[String] = []
var impulses: Dictionary = {}
var impulse_totals: Dictionary = {}
var lab_counts: Dictionary = {}

var _tether: MeshInstance3D
var _target_ring: MeshInstance3D
var _tether_material: StandardMaterial3D
var _ring_material: StandardMaterial3D

## what enters the record identity: each move on or off with its law and tuning.
var mechanics: Array:
	get:
		var out: Array = []
		for id: String in MOVES:
			out.append({"id": id, "on": bool(enabled[id]), "version": EXPERIMENT_VERSION, "tuning": _tuning(id)})
		return out

static func ensure_actions() -> void:
	for pair: Array in [[SLIDE_ACTION, KEY_SHIFT], [GRAPPLE_ACTION, KEY_E]]:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		var event := InputEventKey.new()
		event.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], event)

static func _tuning(id: String) -> Dictionary:
	match id:
		"slide":
			return SLIDE
		"wall_jump":
			return WALL
	return GRAPPLE

func _ready() -> void:
	super()
	ensure_actions()
	_tether_material = _glow_material(Color("ffb347"), 3.0)
	_ring_material = _glow_material(Color("7fe0ff"), 2.0)
	_tether = MeshInstance3D.new()
	_tether.name = "GrappleTether"
	var rope := CylinderMesh.new()
	rope.top_radius = 0.018
	rope.bottom_radius = 0.018
	rope.height = 1.0
	rope.radial_segments = 6
	rope.rings = 1
	_tether.mesh = rope
	_tether.material_override = _tether_material
	_tether.top_level = true
	_tether.visible = false
	add_child(_tether)
	_target_ring = MeshInstance3D.new()
	_target_ring.name = "GrappleTarget"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.52
	ring.rings = 24
	ring.ring_segments = 6
	_target_ring.mesh = ring
	_target_ring.material_override = _ring_material
	_target_ring.top_level = true
	_target_ring.visible = false
	add_child(_target_ring)

static func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.emission_enabled = true
	made.emission = color
	made.emission_energy_multiplier = energy
	made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return made

func reset_to(pose: Transform3D) -> void:
	super(pose)
	_clear_lab()

func _clear_lab() -> void:
	slide_active = false
	slide_ticks = 0
	slide_cooldown = 0
	slide_count = 0
	slide_end_reason = ""
	_slide_duck = false
	_slide_cvars = {}
	_slide_press = false
	wall_jumps_flight = 0
	wall_cooldown = 0
	wall_jump_count = 0
	wall_refusal = ""
	_last_wall = ""
	_wall_press = false
	_wall_probe = {}
	grapple = {}
	grapple_length_u = 0.0
	grapple_ticks = 0
	grapple_count = 0
	grapple_release_reason = ""
	grapple_target = {"state": "none"}
	_grapple_press = false
	_grapple_needs_press = false
	lab_events = []
	impulses = {}
	impulse_totals = {"wall_jump": Vector3.ZERO, "grapple_rope": Vector3.ZERO, "grapple_pull": Vector3.ZERO}
	lab_counts = {"slide": 0, "slide_refused": 0, "wall_jump": 0, "wall_refused": 0, "grapple": 0, "grapple_miss": 0, "grapple_release": 0}
	if _tether != null:
		_tether.visible = false
		_target_ring.visible = false

func mechanic_enabled(id: String) -> bool:
	return bool(enabled.get(id, false))

## turns a move on or off. off ends what it is doing now: a slide stops (its duck stands up
## when there is room, as crouch does) and a line is released.
func set_mechanic(id: String, on: bool) -> void:
	if not enabled.has(id):
		return
	enabled[id] = on
	if on:
		return
	match id:
		"slide":
			if slide_active:
				_end_slide("off")
		"grapple":
			if not grapple.is_empty():
				_release("off")
			grapple_target = {"state": "none"}

func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not input_enabled:
		return
	# fresh presses only: held keys repeat as echoes, which is_action_pressed ignores.
	if event.is_action_pressed("jump"):
		_wall_press = true
	elif event.is_action_pressed(SLIDE_ACTION):
		_slide_press = true
	elif event.is_action_pressed(GRAPPLE_ACTION):
		_grapple_press = true

## the inherited tick, with the moves' impulses on the body before it and the slide's friction
## for its duration. a tick without any move active runs r15's tick on r15's settings.
func _physics_process(delta: float) -> void:
	lab_events = []
	impulses = {}
	if not input_enabled:
		super(delta)
		return
	var grounded := bool(state.grounded)
	var before := velocity
	var change := Vector3.ZERO
	change += _grapple_step(velocity / U + change, grounded, delta)
	change += _wall_step(velocity / U + change, grounded)
	_slide_step(velocity / U + change, grounded)
	_wall_press = false
	_slide_press = false
	_grapple_press = false
	if change != Vector3.ZERO:
		velocity = before + change * U
	var kept := settings
	if slide_active:
		_slide_cvars = settings.duplicate()
		_slide_cvars["sv_friction"] = float(SLIDE.friction)
		settings = _slide_cvars
	super(delta)
	# a settings change inside the tick (a deferred duck geometry) wins over the restore.
	if is_same(settings, _slide_cvars):
		settings = kept
	_slide_cvars = {}
	if slide_active:
		slide_ticks += 1
		if "jump" in state.events:
			_end_slide("jump")
		elif not bool(state.grounded):
			_end_slide("airborne")
	if bool(state.grounded) and not "jump" in state.events:
		wall_jumps_flight = 0
		_last_wall = ""
	slide_cooldown = maxi(0, slide_cooldown - 1)
	wall_cooldown = maxi(0, wall_cooldown - 1)

func _ticks(seconds: float) -> int:
	return roundi(seconds * float(settings.tickrate))

func _book(cause: String, change: Vector3) -> void:
	impulses[cause] = (impulses.get(cause, Vector3.ZERO) as Vector3) + change
	impulse_totals[cause] = (impulse_totals.get(cause, Vector3.ZERO) as Vector3) + change

func _count(kind: String) -> void:
	lab_counts[kind] = int(lab_counts.get(kind, 0)) + 1

# --- slide ----------------------------------------------------------------------------------

## the inherited duck step sees crouch held while the slide holds its duck.
func _update_duck(held: bool, grounded: bool) -> Vector3:
	return super(held or _slide_duck, grounded)

func _slide_step(v: Vector3, grounded: bool) -> void:
	if not slide_active and _slide_duck and grounded:
		_slide_duck = false
	if slide_active:
		var why := ""
		if not mechanic_enabled("slide"):
			why = "off"
		elif not Input.is_action_pressed(SLIDE_ACTION):
			why = "released"
		elif slide_ticks >= _ticks(float(SLIDE.max_s)):
			why = "time"
		elif Vector2(v.x, v.z).length() < float(SLIDE.end_ups):
			why = "slow"
		elif not grounded:
			why = "airborne"
		if not why.is_empty():
			_end_slide(why)
		return
	if not _slide_press or not mechanic_enabled("slide"):
		return
	var refusal := ""
	if not grounded:
		refusal = "airborne"
	elif Input.is_action_pressed("jump") or _jump_pulse:
		refusal = "jump held"
	elif slide_cooldown > 0:
		refusal = "cooldown"
	elif Vector2(v.x, v.z).length() < float(SLIDE.min_entry_ups):
		refusal = "too slow"
	if not refusal.is_empty():
		slide_end_reason = "refused: " + refusal
		lab_events.append("slide_refused")
		_count("slide_refused")
		return
	slide_active = true
	slide_ticks = 0
	slide_end_reason = ""
	_slide_duck = true
	slide_count += 1
	lab_events.append("slide")
	_count("slide")

func _end_slide(why: String) -> void:
	slide_active = false
	slide_end_reason = why
	slide_cooldown = _ticks(float(SLIDE.cooldown_s))
	lab_events.append("slide_end")

# --- wall jump ------------------------------------------------------------------------------

## returns the velocity change (u/s) of a wall jump this tick, or zero.
func _wall_step(v: Vector3, grounded: bool) -> Vector3:
	_wall_probe = {}
	if not _wall_press or not mechanic_enabled("wall_jump") or grounded:
		return Vector3.ZERO
	var refusal := ""
	var wall := _find_wall()
	_wall_probe = wall.duplicate()
	if wall.is_empty():
		refusal = "no wall in reach"
	elif wall_jumps_flight >= int(WALL.max_per_flight):
		refusal = "limit this flight"
	elif wall_cooldown > 0:
		refusal = "cooldown"
	elif str(wall.key) == _last_wall:
		refusal = "same wall"
	if not refusal.is_empty():
		wall_refusal = refusal
		lab_events.append("wall_refused")
		_count("wall_refused")
		return Vector3.ZERO
	var n: Vector3 = wall.normal
	var h := Vector3(v.x, 0.0, v.z)
	var out := float(WALL.out_ups)
	var tangent := h - n * h.dot(n)
	var cap := maxf(h.length(), float(WALL.speed_cap_ups))
	var room := sqrt(maxf(cap * cap - out * out, 0.0))
	if tangent.length() > room:
		tangent = tangent.normalized() * room
	var next := tangent + n * out
	next.y = maxf(v.y, float(WALL.up_ups))
	var change := next - v
	wall_jumps_flight += 1
	wall_jump_count += 1
	wall_cooldown = _ticks(float(WALL.cooldown_s))
	_last_wall = str(wall.key)
	wall_refusal = ""
	lab_events.append("wall_jump")
	_count("wall_jump")
	_book("wall_jump", change)
	return change

## the nearest vertical static face within reach of the hull, swept along eight horizontal
## directions: {key, body, normal (horizontal), distance_u}, or empty.
func _find_wall() -> Dictionary:
	var reach := float(WALL.reach_u) * U
	var best := {}
	for i: int in PROBES:
		var angle := TAU * float(i) / float(PROBES)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var hit := KinematicCollision3D.new()
		if not test_move(global_transform, direction * reach, hit, safe_margin, true, 4):
			continue
		var travel := hit.get_travel().dot(direction)
		for j: int in hit.get_collision_count():
			var n := hit.get_normal(j)
			var body := hit.get_collider(j) as Node
			if absf(n.y) > float(WALL.max_normal_y) or not body is StaticBody3D or n.dot(direction) > -0.3:
				continue
			var flat := Vector3(n.x, 0.0, n.z).normalized()
			if best.is_empty() or travel < float(best.distance_u) * U:
				best = {"key": "%s:%d:%d" % [body.name, roundi(flat.x * 8.0), roundi(flat.z * 8.0)], "body": str(body.name), "normal": flat, "distance_u": maxf(travel, 0.0) / U}
	return best

# --- grapple --------------------------------------------------------------------------------

func _hull_centre() -> Vector3:
	return global_position + Vector3.UP * hull_height_u() * U * 0.5

func _eye() -> Vector3:
	return global_position + Vector3.UP * _eye_u * U

func _aim() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))

func _clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).distance_to(to) <= float(GRAPPLE.anchor_clear_m)

## the anchor the view selects: the one nearest the view's centre inside the aim cone.
func _find_target() -> Dictionary:
	var eye := _eye()
	var aim := _aim()
	var best := {"state": "none"}
	var best_angle := deg_to_rad(float(GRAPPLE.aim_cone_deg))
	for node: Node in get_tree().get_nodes_in_group(ANCHOR_GROUP):
		var anchor := node as Node3D
		if anchor == null or not anchor.is_inside_tree():
			continue
		var to := anchor.global_position - eye
		var distance := to.length()
		if distance < 1e-3:
			continue
		var angle := aim.angle_to(to / distance)
		if angle > best_angle:
			continue
		best_angle = angle
		var named := str(anchor.get_meta("anchor_name", anchor.name))
		var state_name := "ok"
		if distance > float(GRAPPLE.range_u) * U:
			state_name = "far"
		elif not _clear_line(eye, anchor.global_position):
			state_name = "blocked"
		best = {"state": state_name, "name": named, "position": anchor.global_position, "distance_m": distance, "angle_deg": rad_to_deg(angle)}
	return best

## returns the line's velocity change (u/s) this tick, or zero.
func _grapple_step(v: Vector3, _grounded: bool, delta: float) -> Vector3:
	if grapple.is_empty():
		grapple_target = _find_target() if mechanic_enabled("grapple") else {"state": "none"}
		if not mechanic_enabled("grapple") or not Input.is_action_pressed(GRAPPLE_ACTION):
			if not Input.is_action_pressed(GRAPPLE_ACTION):
				_grapple_needs_press = false
			return Vector3.ZERO
		if _grapple_needs_press and not _grapple_press:
			return Vector3.ZERO
		if str(grapple_target.state) != "ok":
			if _grapple_press:
				lab_events.append("grapple_miss")
				_count("grapple_miss")
			return Vector3.ZERO
		grapple = {"name": grapple_target.name, "position": grapple_target.position}
		grapple_length_u = (_hull_centre().distance_to(grapple.position)) / U
		grapple_ticks = 0
		grapple_count += 1
		grapple_release_reason = ""
		_grapple_needs_press = false
		lab_events.append("grapple")
		_count("grapple")
	var anchor: Vector3 = grapple.position
	var centre := _hull_centre()
	var distance_u := centre.distance_to(anchor) / U
	var why := ""
	if not mechanic_enabled("grapple"):
		why = "off"
	elif not Input.is_action_pressed(GRAPPLE_ACTION):
		why = "released"
	elif grapple_ticks >= _ticks(float(GRAPPLE.max_s)):
		why = "time"
	elif distance_u > float(GRAPPLE.range_u) + float(GRAPPLE.stretch_u):
		why = "range"
	elif not _clear_line(centre, anchor):
		why = "obstructed"
	if not why.is_empty():
		_release(why)
		return Vector3.ZERO
	grapple_ticks += 1
	grapple_length_u = maxf(float(GRAPPLE.min_length_u), minf(grapple_length_u, distance_u) - float(GRAPPLE.reel_ups) * delta)
	if distance_u < grapple_length_u or distance_u < 1e-3:
		return Vector3.ZERO
	var along := (anchor - centre) / (distance_u * U)
	var next := v
	var radial := next.dot(along)
	if radial < 0.0:
		var rope := -along * radial
		next += rope
		_book("grapple_rope", rope)
	var pull := along * minf(float(GRAPPLE.stiffness) * (distance_u - grapple_length_u), float(GRAPPLE.max_pull_ups2)) * delta
	var limit := maxf(v.length(), float(GRAPPLE.speed_cap_ups))
	if (next + pull).length() > limit:
		# the share of the pull that keeps |v| at the limit: |next + s pull| = limit.
		var a := pull.length_squared()
		var b := next.dot(pull)
		var c := next.length_squared() - limit * limit
		var share := clampf((-b + sqrt(maxf(b * b - a * c, 0.0))) / a, 0.0, 1.0) if a > 0.0 else 0.0
		pull *= share
	next += pull
	_book("grapple_pull", pull)
	return next - v

func _release(why: String) -> void:
	grapple = {}
	grapple_release_reason = why
	grapple_ticks = 0
	# p / a line the game broke needs a fresh E press; letting go of E is the ordinary release.
	_grapple_needs_press = why != "released"
	lab_events.append("grapple_release")
	_count("grapple_release")

# --- presentation ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	super(delta)
	if _tether == null or camera == null:
		return
	if not grapple.is_empty():
		var hand := camera.global_transform * Vector3(0.22, -0.26, -0.35)
		var anchor: Vector3 = grapple.position
		var span := anchor - hand
		var length := span.length()
		if length > 1e-3:
			var up := span / length
			var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
			var basis := Basis(side, up * length, side.cross(up))
			_tether.global_transform = Transform3D(basis, hand + span * 0.5)
			_tether.visible = true
	else:
		_tether.visible = false
	var target_state := str(grapple_target.get("state", "none"))
	var ring_at: Variant = null
	var color := Color("ffb347")
	if not grapple.is_empty():
		ring_at = grapple.position
	elif mechanic_enabled("grapple") and target_state != "none":
		ring_at = grapple_target.position
		color = Color("7fe0ff") if target_state == "ok" else Color("ff6a5a")
	_target_ring.visible = ring_at != null
	if ring_at != null:
		_ring_material.albedo_color = color
		_ring_material.emission = color
		_target_ring.global_transform = Transform3D(_facing(camera.global_position - (ring_at as Vector3)), ring_at)

## a basis whose y axis (the torus axis) points along `direction`.
static func _facing(direction: Vector3) -> Basis:
	if direction.length_squared() < 1e-8:
		return Basis.IDENTITY
	var y := direction.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.99 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))

## one line per move for the hud: on/off, the control, and what it is doing now.
func experiment_hud() -> Dictionary:
	var slide_text := "off"
	if mechanic_enabled("slide"):
		if slide_active:
			slide_text = "SLIDING %.2f s" % (float(slide_ticks) / float(settings.tickrate))
		elif slide_cooldown > 0:
			slide_text = "cooldown"
		else:
			slide_text = "ready" + ("" if slide_end_reason.is_empty() else "  ·  last: " + slide_end_reason)
	var wall_text := "off"
	if mechanic_enabled("wall_jump"):
		var near := not bool(state.grounded) and not _find_wall().is_empty()
		wall_text = "%d/%d this flight%s%s" % [wall_jumps_flight, int(WALL.max_per_flight), "  ·  WALL IN REACH" if near else "",
			"" if wall_refusal.is_empty() else "  ·  last refused: " + wall_refusal]
	var grapple_text := "off"
	if mechanic_enabled("grapple"):
		if not grapple.is_empty():
			grapple_text = "ON LINE %s  ·  %.1f m  ·  %.1f s left" % [grapple.name, _hull_centre().distance_to(grapple.position),
				float(GRAPPLE.max_s) - float(grapple_ticks) / float(settings.tickrate)]
		else:
			match str(grapple_target.get("state", "none")):
				"ok":
					grapple_text = "E: %s  ·  %.1f m" % [grapple_target.name, float(grapple_target.distance_m)]
				"blocked":
					grapple_text = "%s blocked" % grapple_target.name
				"far":
					grapple_text = "%s too far (%.0f m, max %.0f)" % [grapple_target.name, float(grapple_target.distance_m), float(GRAPPLE.range_u) * U]
				_:
					grapple_text = "no anchor in view" + ("" if grapple_release_reason.is_empty() else "  ·  last: " + grapple_release_reason)
	return {"slide": slide_text, "wall_jump": wall_text, "grapple": grapple_text, "target": str(grapple_target.get("state", "none")),
		"attached": not grapple.is_empty(), "sliding": slide_active}

func get_motion_state() -> Dictionary:
	var out := super()
	var totals := {}
	for cause: String in impulse_totals:
		totals[cause] = impulse_totals[cause]
	out["experiment"] = {
		"version": EXPERIMENT_VERSION,
		"enabled": enabled.duplicate(),
		"events": lab_events.duplicate(),
		"impulses_u": impulses.duplicate(),
		"impulse_totals_u": totals,
		"counts": lab_counts.duplicate(),
		"slide": {"active": slide_active, "ticks": slide_ticks, "cooldown": slide_cooldown, "duck_hold": _slide_duck, "end": slide_end_reason,
			"friction": float(SLIDE.friction) if slide_active else null},
		"wall_jump": {"flight": wall_jumps_flight, "cooldown": wall_cooldown, "last_wall": _last_wall, "refusal": wall_refusal, "probe": _wall_probe.duplicate()},
		"grapple": {"attached": not grapple.is_empty(), "anchor": str(grapple.get("name", "")), "length_u": grapple_length_u if not grapple.is_empty() else null,
			"distance_u": _hull_centre().distance_to(grapple.position) / U if not grapple.is_empty() else null, "ticks": grapple_ticks,
			"release": grapple_release_reason, "target": grapple_target.duplicate()},
	}
	return out

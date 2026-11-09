extends "res://scripts/r15_experiment_player.gd"
## p / r16 movement lab runner: the frozen r15 lab runner with two moves reworked and the grapple
## untouched. it overrides only the r15 hooks the moves own (_wall_step, _slide_step), the r14
## world hook air_move (for the wall push guard) and the reporting; the source tick, the motor and
## every grapple routine, constant, action and group are inherited as they are.
## docs/r16/LAB.md has the laws, the measurements and what each choice is.
##
## off means off, as in r15: with no Shift, no fresh Space press in the air and no wall jump in the
## last 0.25 s, a tick is r15's exactly (no velocity write, no settings swap, no state write).
##
## - wall jump (Space, r16-lab-wall-jump-2): r15's trigger, reach and impulse direction, with
##   * a budget of 2 per landing. only real support refills it (the motor's grounded state after a
##     tick, which needs a walkable face); a wall contact never does.
##   * each wall plane once per flight: walls are keyed by normal and plane offset, so a seam between
##     two coplanar pieces, a stale contact or bouncing back to the face just used is refused.
##   * the push guard: for 0.25 s after a wall jump, a held wish that points into that wall gets no
##     air acceleration. the defect it repairs: at AA 100 a held A or D into the wall cancelled the
##     230 u/s kick within two ticks, so only W (along the wall) kept it. the guard only ever
##     withholds acceleration; a wish along or away from the wall plays the ordinary law.
##   * the along-wall (tangent) speed is kept; horizontal speed may rise to max(340, before + 80).
##   * a fresh press up to 0.1 s before a wall comes within reach still fires on reaching it.
## - slide (Shift, r16-lab-slide-2): r15's grounded slide unchanged, plus the landing slide:
##   * a fresh Shift press in the air arms it while Shift stays held. it lasts until 0.40 s after
##     the later of the press and the apex, so it is pressed on the way down.
##   * the landing then becomes a slide at the landing's own horizontal speed (r15's 180 u/s floor,
##     friction and duck). a fresh press on the tick right after a landing counts as well.
##   * the slide wins over Space on its entry tick, and a Space held into that landing never hops:
##     release and press again (or scroll) to hop out. a fresh press on the entry tick hops on the
##     next tick. a wall jump disarms a pending slide.
## Ctrl and C stay the r15 crouch, and nothing here reads them.

const R16_LAB_VERSION := "r16-lab-moves-1"
## p / the r16 additions to the inherited slide table (SLIDE keeps friction, entry, end and timing).
const R16_SLIDE := {"law": "r16-lab-slide-2", "arm": "fresh Shift press in the air, Shift held", "buffer_s": 0.40,
	"buffer_from": "later of press and apex", "late_press_ticks": 1, "entry_tick_jump": "none; a fresh press on it hops next tick",
	"held_space": "held into the landing never hops; release and press", "wall_jump": "disarms"}
## p / the r16 wall law. reach and the face test are the inherited WALL.reach_u / max_normal_y.
const R16_WALL := {"law": "r16-lab-wall-jump-2", "out_ups": 230.0, "up_ups": 290.0, "speed_cap_ups": 340.0, "gain_cap_ups": 80.0,
	"budget": 2, "refill": "landing on walkable support", "per_wall": "each wall plane once per flight", "same_wall_deg": 20.0,
	"same_wall_u": 8.0, "cooldown_s": 0.25, "press_buffer_s": 0.1, "guard_s": 0.25, "guard": "no air acceleration for a wish into the wall"}

var wall_budget: int = 2
## the wall planes used since the last landing: {key, body, normal, offset_u}.
var walls_used: Array[Dictionary] = []
var _wall_buffer: int = 0
var _guard_ticks: int = 0
var _guard_normal := Vector3.ZERO
var _guard_this_tick := Vector3.ZERO
var last_wall_jump: Dictionary = {}

var slide_armed: bool = false
var _arm_tick: int = 0
var _arm_descent: int = 0
var slide_disarm_reason: String = ""
var _land_pending: bool = false
var _landed_last: bool = false
var slide_kind: String = ""
var _entry_tick: bool = false
var _hop_latch: bool = false
var _hop_deferred: bool = false
var last_landing_slide: Dictionary = {}

var _r16_kept: Dictionary = {}
var _r16_cvars: Dictionary = {}

static func _tuning(id: String) -> Dictionary:
	match id:
		"slide":
			var slide := SLIDE.duplicate()
			slide.merge(R16_SLIDE, true)
			slide["lab_version"] = R16_LAB_VERSION
			return slide
		"wall_jump":
			var wall := {"reach_u": WALL.reach_u, "max_normal_y": WALL.max_normal_y}
			wall.merge(R16_WALL, true)
			wall["lab_version"] = R16_LAB_VERSION
			return wall
	return GRAPPLE

func movement_version() -> String:
	return R16_LAB_VERSION

func _clear_lab() -> void:
	super()
	wall_budget = int(R16_WALL.budget)
	walls_used = []
	_wall_buffer = 0
	_guard_ticks = 0
	_guard_normal = Vector3.ZERO
	_guard_this_tick = Vector3.ZERO
	last_wall_jump = {}
	slide_armed = false
	_arm_tick = 0
	_arm_descent = 0
	slide_disarm_reason = ""
	_land_pending = false
	_landed_last = false
	slide_kind = ""
	_entry_tick = false
	_hop_latch = false
	_hop_deferred = false
	last_landing_slide = {}
	impulse_totals["wall_guard"] = Vector3.ZERO
	for kind: String in ["slide_landing", "slide_armed", "slide_disarmed", "wall_guard_ticks", "hop_held_ignored"]:
		lab_counts[kind] = 0

func set_mechanic(id: String, on: bool) -> void:
	super(id, on)
	if on or not enabled.has(id):
		return
	match id:
		"wall_jump":
			_guard_ticks = 0
			_wall_buffer = 0
		"slide":
			if slide_armed:
				_disarm("off")
			_land_pending = false
			_entry_tick = false
			_hop_latch = false
			_hop_deferred = false

## the inherited lab tick. a settings swap made by a hook below (held Space ignored) lasts this tick
## only; a settings change inside the tick (a deferred duck geometry) wins over the restore.
func _physics_process(delta: float) -> void:
	_r16_kept = settings
	_r16_cvars = {}
	_guard_this_tick = Vector3.ZERO
	super(delta)
	if not _r16_cvars.is_empty() and is_same(settings, _r16_cvars):
		settings = _r16_kept
	_r16_cvars = {}
	_r16_kept = {}
	if input_enabled:
		_after_tick()

func _after_tick() -> void:
	var grounded := bool(state.grounded)
	var events: Array = state.events
	if grounded:
		if wall_budget < int(R16_WALL.budget) or not walls_used.is_empty():
			lab_events.append("wall_refill")
		wall_budget = int(R16_WALL.budget)
		walls_used = []
		_guard_ticks = 0
		_wall_buffer = 0
	else:
		_guard_ticks = maxi(0, _guard_ticks - 1)
		if _wall_buffer > 0:
			_wall_buffer -= 1
			if _wall_buffer == 0:
				lab_events.append("wall_buffer_expired")
		# a held Space ignored on the ground is spent once the body leaves it.
		_hop_latch = false
	if slide_armed:
		if "land" in events:
			slide_armed = false
			_land_pending = true
		elif grounded:
			_disarm("grounded without a landing")
		elif velocity.y <= 0.0:
			_arm_descent += 1
			if _arm_descent > _ticks(float(R16_SLIDE.buffer_s)):
				_disarm("buffer expired")
	_landed_last = "land" in events

func _disarm(why: String) -> void:
	slide_armed = false
	slide_disarm_reason = why
	lab_events.append("slide_disarmed")
	_count("slide_disarmed")

# --- wall jump ------------------------------------------------------------------------------

## returns the velocity change (u/s) of a wall jump this tick, or zero.
func _wall_step(v: Vector3, grounded: bool) -> Vector3:
	_wall_probe = {}
	if not mechanic_enabled("wall_jump") or grounded:
		_wall_buffer = 0
		return Vector3.ZERO
	var pressed := _wall_press
	if not pressed and _wall_buffer <= 0:
		return Vector3.ZERO
	var wall := _find_wall()
	if not wall.is_empty():
		wall["offset_u"] = _plane_offset_u(wall)
	_wall_probe = wall.duplicate()
	var refusal := ""
	if wall.is_empty():
		refusal = "no wall in reach"
	elif wall_budget <= 0:
		refusal = "budget spent"
	elif _used_wall(wall):
		refusal = "same wall"
	elif wall_cooldown > 0:
		refusal = "cooldown"
	if not refusal.is_empty():
		# a buffered press keeps waiting for a wall without a new refusal each tick.
		if not pressed and refusal == "no wall in reach":
			return Vector3.ZERO
		wall_refusal = refusal
		lab_events.append("wall_refused")
		_count("wall_refused")
		_wall_buffer = _ticks(float(R16_WALL.press_buffer_s)) if pressed and refusal == "no wall in reach" else 0
		return Vector3.ZERO
	var n: Vector3 = wall.normal
	var h := Vector3(v.x, 0.0, v.z)
	var into := h.dot(n)
	var tangent := h - n * into
	var out := maxf(into, float(R16_WALL.out_ups))
	var cap := maxf(float(R16_WALL.speed_cap_ups), h.length() + float(R16_WALL.gain_cap_ups))
	var room := sqrt(maxf(cap * cap - out * out, 0.0))
	var kept := tangent
	if kept.length() > room:
		kept = kept.normalized() * room
	var next := kept + n * out
	next.y = maxf(v.y, float(R16_WALL.up_ups))
	var change := next - v
	wall_budget -= 1
	wall_jump_count += 1
	wall_cooldown = _ticks(float(R16_WALL.cooldown_s))
	_last_wall = str(wall.key)
	walls_used.append({"key": str(wall.key), "body": str(wall.body), "normal": n, "offset_u": float(wall.offset_u)})
	wall_refusal = ""
	_wall_buffer = 0
	_guard_ticks = _ticks(float(R16_WALL.guard_s))
	_guard_normal = n
	last_wall_jump = {"tick": motion_tick + 1, "key": str(wall.key), "normal": n, "offset_u": float(wall.offset_u), "distance_u": float(wall.distance_u),
		"buffered": not pressed, "v_before_u": v, "v_after_u": next, "tangent_before_u": tangent.length(), "tangent_after_u": kept.length(),
		"into_before_u": into, "out_after_u": out, "cap_u": cap, "budget_left": wall_budget,
		"actual_tangent_before_u": (_actual_velocity / U - n * (_actual_velocity / U).dot(n)).length()}
	if slide_armed:
		_disarm("wall jump")
	lab_events.append("wall_jump")
	if not pressed:
		lab_events.append("wall_jump_buffered")
	_count("wall_jump")
	_book("wall_jump", change)
	return change

## the wall plane's offset along its normal, u: the hull side the probe touched, pushed out by the
## probe's free travel. two pieces of one flat wall share it.
func _plane_offset_u(wall: Dictionary) -> float:
	var n: Vector3 = wall.normal
	return n.dot(global_position) / U - float(settings.hull_width) * 0.5 - float(wall.distance_u)

func _used_wall(wall: Dictionary) -> bool:
	var n: Vector3 = wall.normal
	var limit := cos(deg_to_rad(float(R16_WALL.same_wall_deg)))
	for used: Dictionary in walls_used:
		if (used.normal as Vector3).dot(n) >= limit and absf(float(used.offset_u) - float(wall.offset_u)) <= float(R16_WALL.same_wall_u):
			return true
	return false

## the push guard: while it lasts, a wish that points into that wall (wish_dir · normal < 0) gets
## no air acceleration this tick. the motor already applied it to s.velocity; the horizontal
## velocity goes back to the tick's start velocity (the command input), and the difference is
## booked as "wall_guard". a wish along or away from the wall plays the ordinary law.
func air_move(s: Dictionary, dt: float) -> void:
	if _guard_ticks > 0 and mechanic_enabled("wall_jump") and (s.wish_dir as Vector3).dot(_guard_normal) < 0.0:
		var start := _start_velocity / U
		var now: Vector3 = s.velocity
		var guarded := Vector3(start.x, now.y, start.z)
		var give := guarded - now
		if give.length_squared() > 1e-12:
			s.velocity = guarded
			s.requested = guarded
			_guard_this_tick = give
			_book("wall_guard", give)
			lab_events.append("wall_guard")
			_count("wall_guard_ticks")
	super(s, dt)

# --- slide ----------------------------------------------------------------------------------

func _slide_step(v: Vector3, grounded: bool) -> void:
	if not mechanic_enabled("slide"):
		super(v, grounded)
		return
	var fresh := _slide_press
	if slide_armed and not Input.is_action_pressed(SLIDE_ACTION):
		_disarm("released")
	if fresh and not grounded and not slide_active:
		slide_armed = true
		_arm_tick = motion_tick + 1
		_arm_descent = 0
		slide_disarm_reason = ""
		lab_events.append("slide_armed")
		_count("slide_armed")
		_slide_press = false
	var late := fresh and grounded and _landed_last and not slide_active
	if (_land_pending or late) and grounded and not slide_active:
		if Input.is_action_pressed(SLIDE_ACTION):
			_start_landing(v, late)
		elif _land_pending:
			slide_disarm_reason = "released"
		_slide_press = false
	_land_pending = false
	super(v, grounded)
	if not slide_active:
		slide_kind = ""
	elif slide_kind.is_empty():
		slide_kind = "ground"
	_hop_policy(grounded)

func _start_landing(v: Vector3, late: bool) -> void:
	var speed := Vector2(v.x, v.z).length()
	var refusal := ""
	if slide_cooldown > 0:
		refusal = "cooldown"
	elif speed < float(SLIDE.min_entry_ups):
		refusal = "too slow"
	last_landing_slide = {"tick": motion_tick + 1, "late": late, "entry_ups": speed, "space_held": Input.is_action_pressed("jump"),
		"fresh_space": _jump_pulse, "refusal": refusal, "arm_tick": _arm_tick}
	if not refusal.is_empty():
		slide_end_reason = "refused: " + refusal
		lab_events.append("slide_refused")
		_count("slide_refused")
		return
	slide_active = true
	slide_ticks = 0
	slide_end_reason = ""
	slide_kind = "landing"
	_slide_duck = true
	slide_count += 1
	_entry_tick = true
	_hop_latch = Input.is_action_pressed("jump") and not _jump_pulse
	lab_events.append("slide")
	lab_events.append("slide_landing")
	_count("slide")
	_count("slide_landing")

## Space against a landing slide: nothing jumps on the entry tick, and a Space held into the
## landing stays ignored until it is released. a fresh press always hops.
func _hop_policy(grounded: bool) -> void:
	var suppress := false
	if _entry_tick:
		_entry_tick = false
		if _jump_pulse:
			_hop_deferred = true
			_jump_pulse = false
			lab_events.append("hop_deferred")
		suppress = true
	elif _hop_deferred:
		_hop_deferred = false
		if grounded:
			_jump_pulse = true
			lab_events.append("hop_out_deferred")
	elif _hop_latch:
		if not Input.is_action_pressed("jump"):
			_hop_latch = false
		elif _jump_pulse:
			_hop_latch = false
		else:
			suppress = true
	if suppress and grounded:
		_r16_cvars = settings.duplicate()
		_r16_cvars["sv_autobunnyhopping"] = false
		settings = _r16_cvars
		state.jump_prev = true
		if Input.is_action_pressed("jump") or _hop_deferred:
			lab_events.append("hop_held_ignored")
			_count("hop_held_ignored")

# --- reporting ------------------------------------------------------------------------------

func experiment_hud() -> Dictionary:
	var out := super()
	if mechanic_enabled("slide"):
		if slide_armed:
			out["slide"] = "ARMED  ·  land holding Shift"
		elif slide_active and slide_kind == "landing":
			out["slide"] = "LANDING SLIDE %.2f s%s" % [float(slide_ticks) / float(settings.tickrate), "  ·  Space: release and press to hop" if _hop_latch else ""]
	if mechanic_enabled("wall_jump"):
		var near := not bool(state.grounded) and not _find_wall().is_empty()
		out["wall_jump"] = "%d/%d left%s%s" % [wall_budget, int(R16_WALL.budget), "  ·  WALL IN REACH" if near else "",
			"" if wall_refusal.is_empty() else "  ·  last refused: " + wall_refusal]
	out["armed"] = slide_armed
	return out

func get_motion_state() -> Dictionary:
	var out := super()
	var lab: Dictionary = out.experiment
	lab["version"] = R16_LAB_VERSION
	lab["base_version"] = EXPERIMENT_VERSION
	var used: Array = []
	for wall: Dictionary in walls_used:
		used.append(wall.duplicate())
	lab["wall_jump"]["budget"] = wall_budget
	lab["wall_jump"]["budget_max"] = int(R16_WALL.budget)
	lab["wall_jump"]["used"] = used
	lab["wall_jump"]["buffer_ticks"] = _wall_buffer
	lab["wall_jump"]["guard_ticks"] = _guard_ticks
	lab["wall_jump"]["guard_normal"] = _guard_normal
	lab["wall_jump"]["guard_u"] = _guard_this_tick
	lab["wall_jump"]["last"] = last_wall_jump.duplicate()
	lab["slide"]["kind"] = slide_kind
	lab["slide"]["armed"] = slide_armed
	lab["slide"]["arm_tick"] = _arm_tick
	lab["slide"]["arm_descent_ticks"] = _arm_descent
	lab["slide"]["disarm"] = slide_disarm_reason
	lab["slide"]["landing_pending"] = _land_pending
	lab["slide"]["held_space_ignored"] = _hop_latch
	lab["slide"]["hop_deferred"] = _hop_deferred
	lab["slide"]["last_landing"] = last_landing_slide.duplicate()
	return out

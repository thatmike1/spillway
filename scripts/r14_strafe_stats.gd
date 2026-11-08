extends Node
## p / r14 strafe statistics: a read-only observer that runs after the runner's physics step
## (process_physics_priority 100, the runner keeps 0) and never writes the body, its input or
## its motor. the same definitions apply to every family, so the hud compares like with like.
## docs/r14/PLAYABLE.md states them; the short version:
##
## - air tick: a step that began airborne, or the step a jump left the ground on (that step
##   also runs an air update). counted from the first airborne step to the landing step.
## - eligible tick: an air tick with exactly one of A/D held (|side| > 0.5), a nonzero view turn
##   since the previous step, and horizontal speed above 1 u/s. good when the view turned
##   toward the held key (A with a left turn, D with a right turn). sync = good / eligible, and
##   null (the hud shows an em dash) when nothing was eligible: coasting is not 0 % sync.
## - takeoff: source reads the motor's own takeoff speed (after any takeoff clamp, before the
##   jump step's air update). other families: horizontal speed at the end of the first air step.
## - landing: horizontal speed at the end of the step that ended grounded, before the next
##   step's ground friction or landing penalty (source: the motor's landing speed).
## - gain = landing - takeoff. contact = the summed change of horizontal speed that collisions
##   made on air ticks (post-contact minus requested), so a wall or a ramp lip shows as contact
##   loss, never as bad sync. air = gain - contact, what the air law itself did.
## - chain = next takeoff - previous takeoff; ground = chain - gain, everything between landing
##   and the next takeoff (friction, clamp, stamina, walking). ground_ticks counts the steps
##   that ended grounded in between (1 = jumped on the first ground step).
## no efficiency or optimal-strafe claim is made: a 100 % sync says the turn direction agreed
## with the key, not that the turn rate was right.

const U := 0.0254
const SIDE_THRESHOLD := 0.5
const TURN_EPSILON := 1e-7
const MIN_SPEED_U := 1.0

## the observed runner; set with watch().
var player: CharacterBody3D
## "motor" when the runner reports its own hops (source), else "observer".
var takeoff_source: String = "observer"
## the flight in progress, or {} on the ground. keys: takeoff, ticks, eligible, good, contact,
## wall_ticks, peak.
var flight: Dictionary = {}
## the hop that ended most recently (see the definitions above), or {}.
var last_hop: Dictionary = {}
var hop_count: int = 0
## per-run totals over every completed hop.
var total_eligible: int = 0
var total_good: int = 0
## the latest tick's verdict: true, false, or null when not eligible.
var tick_sync: Variant = null
var resets: int = 0

var _was_grounded: bool = true
var _prev_yaw: float = 0.0
var _prev_jumps: int = 0
var _ground_ticks: int = 0
var _pending_chain: Dictionary = {}

func _ready() -> void:
	process_physics_priority = 100

func watch(runner: CharacterBody3D) -> void:
	player = runner
	takeoff_source = "motor" if runner != null and "last_hop" in runner and "flight" in runner else "observer"
	reset()

## forget every hop: restart, respawn, map or preset change.
func reset() -> void:
	flight = {}
	last_hop = {}
	hop_count = 0
	total_eligible = 0
	total_good = 0
	tick_sync = null
	_pending_chain = {}
	_ground_ticks = 0
	resets += 1
	if player != null and is_instance_valid(player):
		_prev_yaw = float(player.get("yaw"))
		_prev_jumps = int(player.get("jump_count"))
		_was_grounded = bool(player.call("is_grounded"))

func live_sync() -> Variant:
	if flight.is_empty() or int(flight.eligible) == 0:
		return null
	return float(flight.good) / float(flight.eligible)

func run_sync() -> Variant:
	return float(total_good) / float(total_eligible) if total_eligible > 0 else null

## horizontal speed of the runner's current velocity, u/s.
func speed_u() -> float:
	if player == null:
		return 0.0
	return Vector2(player.velocity.x, player.velocity.z).length() / U

func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return
	if not bool(player.get("input_enabled")) or get_tree().paused:
		return
	var grounded := bool(player.call("is_grounded"))
	var yaw := float(player.get("yaw"))
	var jumps := int(player.get("jump_count"))
	# watch/reset already sampled the baseline; the first callback may contain a real hop.
	var turn := angle_difference(_prev_yaw, yaw)
	_prev_yaw = yaw
	var state: Dictionary = player.call("get_motion_state") if player.has_method("get_motion_state") else {}
	# a motor that reports step events says so directly; otherwise the jump counter moved. the
	# source counter restarts from its own state on a reset, so a change, not a rise, counts.
	var jumped := "jump" in (state.get("events", []) as Array) if state.has("events") else jumps != _prev_jumps
	_prev_jumps = jumps
	var speed := speed_u()
	tick_sync = null
	if jumped:
		_begin_flight(state, speed)
	var air_tick := not flight.is_empty() and (not _was_grounded or jumped)
	if air_tick:
		flight.ticks += 1
		var side := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		if absf(side) > SIDE_THRESHOLD and absf(turn) > TURN_EPSILON and speed > MIN_SPEED_U:
			# yaw grows to the left; A (side < 0) agrees with a left turn.
			tick_sync = (side < 0.0) == (turn > 0.0)
			flight.eligible += 1
			if tick_sync:
				flight.good += 1
		_book_contacts(state)
		flight.peak = maxf(float(flight.peak), speed)
	if not flight.is_empty() and grounded and not _was_grounded and not jumped:
		_land(state, speed)
	elif not flight.is_empty() and grounded and jumped:
		# a jump straight into a landing on the same step (a tiny hop onto a lip).
		_land(state, speed)
	if grounded and flight.is_empty():
		_ground_ticks += 1
	_was_grounded = grounded

func _begin_flight(state: Dictionary, speed: float) -> void:
	var takeoff := speed
	if takeoff_source == "motor" and (state.get("flight", {}) as Dictionary).has("takeoff"):
		takeoff = float((state.flight as Dictionary).takeoff)
	if not _pending_chain.is_empty():
		var chain := takeoff - float(_pending_chain.takeoff)
		last_hop["chain"] = chain
		last_hop["ground"] = chain - float(last_hop.get("gain", 0.0))
		last_hop["ground_ticks"] = _ground_ticks
	_pending_chain = {}
	_ground_ticks = 0
	flight = {"takeoff": takeoff, "ticks": 0, "eligible": 0, "good": 0, "contact": 0.0, "wall_ticks": 0, "peak": takeoff}

func _book_contacts(state: Dictionary) -> void:
	var requested: Vector3 = state.get("requested_velocity", player.velocity)
	var after: Vector3 = state.get("post_contact_velocity", player.velocity)
	var change := (Vector2(after.x, after.z).length() - Vector2(requested.x, requested.z).length()) / U
	if absf(change) > 1e-4:
		flight.contact += change
	for contact: Variant in state.get("contacts", []):
		if contact is Dictionary and (contact as Dictionary).get("normal") is Vector3:
			if absf(((contact as Dictionary).normal as Vector3).y) < 0.7:
				flight.wall_ticks += 1
				break

func _land(state: Dictionary, speed: float) -> void:
	var landing := speed
	var motor_hop: Dictionary = state.get("last_hop", {})
	if takeoff_source == "motor" and motor_hop.has("landing"):
		landing = float(motor_hop.landing)
	var gain := landing - float(flight.takeoff)
	last_hop = {
		"takeoff": flight.takeoff, "landing": landing, "gain": gain,
		"contact": flight.contact, "air": gain - float(flight.contact),
		"air_ticks": flight.ticks, "eligible": flight.eligible, "good": flight.good,
		"sync": float(flight.good) / float(flight.eligible) if int(flight.eligible) > 0 else null,
		"wall_ticks": flight.wall_ticks, "peak": flight.peak, "index": hop_count + 1,
	}
	hop_count += 1
	total_eligible += int(flight.eligible)
	total_good += int(flight.good)
	_pending_chain = {"takeoff": flight.takeoff}
	_ground_ticks = 0
	flight = {}

## a json-safe copy for traces and tests.
func snapshot() -> Dictionary:
	return {"source": takeoff_source, "flight": flight.duplicate(), "last_hop": last_hop.duplicate(),
		"hops": hop_count, "live_sync": live_sync(), "run_sync": run_sync(), "tick_sync": tick_sync, "resets": resets}

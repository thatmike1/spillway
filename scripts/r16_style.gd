extends RefCounted
## p / r16 style service: reads one post-step sample per physics step (docs/r16/INTERFACES.md)
## and the real collision world, and returns scored style events. it never writes the body, its
## velocity, grounding, input or progress: every geometry question is a query (body.test_move
## with the runner's own hull, or a direct space query with a box of the runner's hull size).
## docs/r16/STYLE.md is the player and integration contract; the short version:
##
## - speed: horizontal actual travel at 400 u/s or more, counted only on new ground (a 2 m cell
##   none of whose neighbours this attempt has visited); every 32 m of such travel pays once. loops and idling pay nothing.
## - sync: a completed hop with sync >= 80 % over enough eligible ticks AND positive air gain
##   (the strafe stats' gain minus collision change). high sync without gain pays nothing.
## - gap: a flight whose hull crossed space with no support within 1.25 m under the takeoff
##   level, landing on support no lower than that. the width is the along-track void the hull
##   crossed, its boundaries bisected with hull casts, plus one hull width.
## - edge: after a gap or a climb, how much shorter the flight could have been and still landed:
##   the actual hull shifted back along the flight line until it loses support. 8 u or less pays.
## - near miss: at 380 u/s or more, the hull passes within 8 u of something at its sides (or
##   over its head while standing), entered from and left into open space, within 6 m, with no
##   blocking contact. both sides tight in one passage is a thread.
## - crouch save: while the duck hull is in use, the standing hull the runner itself would test
##   (same feet on the floor, feet lowered by the air lift in flight, so the same centre for the
##   "center" anchor) is swept along the tick's actual travel in the slabs where it differs from
##   the duck hull. a hit on a non-support face, from a clear start, at 200 u/s or more, that the
##   duck hull did not touch and had not just bonked, opens a save; it pays when the standing
##   hull is clear again after at least one hull width of progress along the entry direction.
##
## combos: sync, gap, edge, near miss and crouch save extend a chain; each adds 0.25 to the
## multiplier, up to x3. 2.5 s without one, a stall under 150 u/s for 0.75 s, or a discontinuity
## (respawn, teleport, restart) ends it. speed pays at the current multiplier without extending.
## novelty: a gap pays once per takeoff/landing pair and direction, an edge once per landing
## piece and heading, a near miss and a crouch save once per obstacle, sync only 4 m or more
## from every earlier paid landing, all per attempt. scoring runs only between the timer start and the finish line.

const STYLE_VERSION := "r16-style-2"
const EVENT_FORMAT := 1
const U := 0.0254

## p / every tuning value, in source units (u, u/s) unless the key says _m or _s. the table
## enters identity(), so a style best never mixes rule sets.
const RULES := {
	"combo": {"window_s": 2.5, "step": 0.25, "max_mult": 3.0, "stall_ups": 150.0, "stall_s": 0.75,
		"extends": ["sync", "gap", "edge", "near_miss", "crouch_save"]},
	"speed": {"min_ups": 400.0, "stretch_m": 32.0, "cell_m": 2.0, "cell_y_m": 3.0, "recent_s": 1.0, "base": 20.0, "cap": 80.0},
	"sync": {"min_sync": 0.8, "min_eligible": 10, "min_share": 0.4, "min_air_gain_ups": 8.0, "spacing_m": 4.0,
		"base": 15.0, "per_ups": 1.5, "cap": 150.0},
	"gap": {"drop_m": 1.25, "min_m": 1.5, "min_air_ticks": 8, "bisect": 12, "scale": 25.0, "power": 1.5, "cap": 900.0},
	"edge": {"max_u": 8.0, "scan_u": 34.0, "step_u": 1.0, "bisect": 8, "rise_u": 19.0, "min_flight_m": 0.5,
		"base": 50.0, "bonus": 250.0},
	"near": {"min_ups": 380.0, "gap_u": 8.0, "probe_u": 16.0, "max_track_m": 6.0, "base": 40.0, "bonus": 160.0,
		"speed_cap": 2.0, "thread": 1.5, "lift_u": 1.0, "touch_u": 0.1},
	"crouch": {"min_ups": 200.0, "bonk_ticks": 8, "max_s": 3.0, "base": 600.0, "speed_ref_ups": 300.0,
		"speed_cap": 2.0, "air_bonus": 300.0},
	"limits": {"teleport_m": 0.05},
	"finish": {"sample": "first_finished_inclusive"},
}

## combo-break reasons that keep the chain: nothing moved the body.
const KEEP_COMBO := ["pause", "settings", "loadout"]
const RECENT := 6
const GUARD_MARGIN := 0.0001
const SWEEP_BISECT := 14

var score: int = 0
var combo: int = 0
var multiplier: float = 1.0
var events: Array[Dictionary] = []
var context: Dictionary = {}

var _time: float = 0.0
var _last_combo_time: float = -INF
var _stall_time: float = 0.0
var _last_combo: Dictionary = {}
var _by_kind: Dictionary = {}
var _paid: Dictionary = {}
var _blocked: Dictionary = {}
var _prev: Dictionary = {}
var _body: CharacterBody3D
var _level: Node
var _discontinuities: Array[String] = []
var _auto_breaks: int = 0
var _sealed: bool = false
var _clean: bool = true
var _finished: bool = false
var _started: bool = false

# speed
var _visited: Dictionary = {}
var _cell: Vector3i = Vector3i(2147483647, 0, 0)
var _cell_novel: bool = false
var _stretch_m: float = 0.0
var _stretch_weighted: float = 0.0
var _stale_fast_m: float = 0.0
# sync
var _stats_hops: int = -1
var _sync_last: Dictionary = {}
## landing points of paid sync hops this attempt.
var _sync_spots: Array[Vector3] = []
## verdict counts per detector (sync hops, gap landings, edge checks, near passages).
var _verdicts: Dictionary = {}
# flight
var _flight: Dictionary = {}
var _last_gap: Dictionary = {}
var _last_edge: Dictionary = {}
# near
var _near: Dictionary = {}
var _near_open_before: bool = false
var _near_last: Dictionary = {}
# crouch
var _save: Dictionary = {}
var _crouch_last: Dictionary = {}
var _bonks: Dictionary = {}
var _crouch_counts: Dictionary = {}

## the rule identity a style best is keyed on: version, event format and a hash of RULES.
static func identity() -> Dictionary:
	return {"version": STYLE_VERSION, "event_format": EVENT_FORMAT, "rules_sha256": JSON.stringify(RULES, "", true).sha256_text()}

static func identity_key() -> String:
	var id := identity()
	return "%s/%d/%s" % [id.version, id.event_format, str(id.rules_sha256).substr(0, 16)]

## a new attempt: everything, including the total, starts again. context is kept for snapshot().
func reset(next_context: Dictionary = {}) -> void:
	context = next_context.duplicate(true)
	score = 0
	combo = 0
	multiplier = 1.0
	events = []
	_time = 0.0
	_last_combo_time = -INF
	_stall_time = 0.0
	_last_combo = {}
	_by_kind = {}
	_paid = {}
	_blocked = {}
	_prev = {}
	_discontinuities = []
	_auto_breaks = 0
	_sealed = false
	_clean = true
	_finished = false
	_started = false
	_visited = {}
	_cell = Vector3i(2147483647, 0, 0)
	_cell_novel = false
	_stretch_m = 0.0
	_stretch_weighted = 0.0
	_stale_fast_m = 0.0
	_stats_hops = -1
	_sync_last = {}
	_sync_spots = []
	_verdicts = {}
	_flight = {}
	_last_gap = {}
	_last_edge = {}
	_near = {}
	_near_open_before = false
	_near_last = {}
	_save = {}
	_crouch_last = {}
	_bonks = {}
	_crouch_counts = {"ducked_ticks": 0, "start_overlap": 0, "support": 0, "obstacle": 0, "duck_hit": 0, "bonked": 0, "slow": 0,
		"opened": 0, "paid": 0, "cancelled": 0}

func _init() -> void:
	reset()

## the body was placed, or the world/rules changed under it: no flight, passage, probe or speed
## stretch continues across this. the total is kept (a respawn is inside one attempt); the combo
## ends unless the reason is one of KEEP_COMBO. reset() is the call that clears the total.
func discontinuity(reason: String) -> void:
	_discontinuities.append(reason)
	if _discontinuities.size() > 16:
		_discontinuities.pop_front()
	_flight = {}
	_near = {}
	_near_open_before = false
	if not _save.is_empty():
		_cancel_save("discontinuity:" + reason)
	_cell = Vector3i(2147483647, 0, 0)
	_cell_novel = false
	_prev = {}
	_bonks = {}
	if not reason in KEEP_COMBO:
		_end_combo("discontinuity:" + reason)

## one post-step sample; returns the events it scored (each also kept in `events`).
func step(sample: Dictionary, body: CharacterBody3D, level: Node3D = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _sealed:
		return out
	_body = body
	_level = level
	var dt := float(sample.get("dt", 1.0 / float(sample.get("physics_hz", 128))))
	_time += dt
	_clean = bool(sample.get("clean", true))
	_finished = bool(sample.get("finished", false))
	_started = bool(sample.get("started", false))
	_check_continuity(sample)
	_book_bonks(sample)
	_combo_clock(sample, dt)
	# the first finish sample belongs to the attempt; later samples never score.
	var active := _started and _body != null and _body.is_inside_tree()
	if active:
		_speed(sample, dt, out)
		_sync(sample, out)
		_flight_step(sample, out)
		_near_step(sample, out)
		_crouch_step(sample, out)
	else:
		_stats_hops = int((sample.get("stats", {}) as Dictionary).get("hops", -1))
		_flight = {}
		_near = {}
		if not _save.is_empty():
			_cancel_save("inactive")
	_prev = {"tick": int(sample.get("tick", 0)), "p": sample.get("p", Vector3.ZERO), "grounded": bool(sample.get("grounded", false)),
		"ducked": bool(sample.get("ducked", false)), "reference_p": sample.get("reference_p", sample.get("p", Vector3.ZERO))}
	_sealed = _finished
	return out

## the summary the recorder and the root keep at the end of an attempt.
func summary() -> Dictionary:
	var kinds := {}
	for kind: String in _by_kind:
		kinds[kind] = (_by_kind[kind] as Dictionary).duplicate()
	return {"identity": identity(), "score": score, "events": events.size(), "by_kind": kinds, "clean": _clean,
		"finished": _finished, "best_eligible": _clean and _finished, "farm_blocked": _blocked.duplicate()}

## a json-safe view for the hud, traces and tests.
func snapshot() -> Dictionary:
	var recent: Array = []
	for i: int in range(maxi(0, events.size() - RECENT), events.size()):
		recent.append(events[i].duplicate(true))
	var window := float(RULES.combo.window_s)
	var left := maxf(0.0, window - (_time - _last_combo_time)) if combo > 0 else 0.0
	return {
		"version": STYLE_VERSION, "identity_key": identity_key(), "score": score, "combo": combo, "mult": multiplier,
		"combo_left_s": left, "combo_window_s": window, "last_combo": _last_combo.duplicate(),
		"recent": recent, "last": events[-1].duplicate(true) if not events.is_empty() else {},
		"by_kind": summary().by_kind, "clean": _clean, "finished": _finished, "sealed": _sealed,
		"best_eligible": _clean and _finished, "time_s": _time, "context": context.duplicate(true),
		"diag": {
			"speed": {"visited_cells": _visited.size(), "stretch_m": _stretch_m, "stale_fast_m": _stale_fast_m, "cell_novel": _cell_novel},
			"sync": _sync_last.duplicate(true),
			"flight": _flight_diag(), "gap": _last_gap.duplicate(true), "edge": _last_edge.duplicate(true),
			"near": {"open": _near_diag(), "last": _near_last.duplicate(true)},
			"crouch": {"open": _save_diag(), "last": _crouch_last.duplicate(true), "counts": _crouch_counts.duplicate()},
			"verdicts": _verdicts.duplicate(true), "farm_blocked": _blocked.duplicate(), "discontinuities": _discontinuities.duplicate(), "auto_breaks": _auto_breaks,
		},
	}

# --- scoring core -----------------------------------------------------------------------------

func _award(kind: String, sample: Dictionary, base: float, label: String, measures: Dictionary, geo: Dictionary, out: Array[Dictionary]) -> void:
	var extends_chain := kind in (RULES.combo.extends as Array)
	if extends_chain:
		combo += 1
		_last_combo_time = _time
		multiplier = minf(float(RULES.combo.max_mult), 1.0 + float(RULES.combo.step) * float(combo - 1))
	var mult := multiplier if combo > 0 else 1.0
	var points := roundi(base * mult)
	score += points
	var event := {
		"v": EVENT_FORMAT, "kind": kind, "tick": int(sample.get("tick", 0)), "time_s": snappedf(_time, 1e-6),
		"elapsed": snappedf(float(sample.get("elapsed", 0.0)), 1e-6), "points": points, "base": roundi(base),
		"mult": mult, "combo": combo if extends_chain else 0, "label": label, "m": measures, "geo": geo,
		"p": _arr(sample.get("p", Vector3.ZERO)), "clean": _clean,
	}
	events.append(event)
	var tally: Dictionary = _by_kind.get(kind, {"n": 0, "points": 0})
	tally.n = int(tally.n) + 1
	tally.points = int(tally.points) + points
	_by_kind[kind] = tally
	out.append(event)

func _count(kind: String, verdict: String) -> void:
	var counts: Dictionary = _verdicts.get(kind, {})
	counts[verdict] = int(counts.get(verdict, 0)) + 1
	_verdicts[kind] = counts

## true when `key` of `kind` has not paid this attempt; marks it paid when `mark`.
func _novel(kind: String, key: String, mark := true) -> bool:
	var id := kind + "|" + key
	if _paid.has(id):
		_blocked[kind] = int(_blocked.get(kind, 0)) + 1
		return false
	if mark:
		_paid[id] = _time
	return true

func _combo_clock(sample: Dictionary, dt: float) -> void:
	if combo <= 0:
		_stall_time = 0.0
		return
	if _time - _last_combo_time > float(RULES.combo.window_s):
		_end_combo("expired")
		return
	var speed := _hspeed_u(sample.get("actual_v", Vector3.ZERO))
	_stall_time = _stall_time + dt if speed < float(RULES.combo.stall_ups) else 0.0
	if _stall_time > float(RULES.combo.stall_s):
		_end_combo("stall")

func _end_combo(reason: String) -> void:
	if combo > 0:
		_last_combo = {"combo": combo, "mult": multiplier, "reason": reason, "time_s": _time}
	combo = 0
	multiplier = 1.0
	_stall_time = 0.0

## a body that arrived somewhere its own travel does not explain was placed: treat it as a
## discontinuity even if the host did not say so, so a respawn never reads as a gap or speed.
func _check_continuity(sample: Dictionary) -> void:
	if _prev.is_empty():
		return
	var reason := ""
	var motion: Dictionary = sample.get("motion", {})
	if int(sample.get("tick", 0)) != int(_prev.tick) + 1:
		reason = "tick_gap"
	elif motion.get("origin_delta") is Vector3 and sample.get("p") is Vector3:
		var expected: Vector3 = (_prev.p as Vector3) + (motion.origin_delta as Vector3)
		if expected.distance_to(sample.p as Vector3) > float(RULES.limits.teleport_m):
			reason = "teleport"
	elif motion.get("displacement") is Vector3 and sample.get("p") is Vector3:
		# a runner without a duck lift: its displacement is the whole origin change.
		var expected: Vector3 = (_prev.p as Vector3) + (motion.displacement as Vector3)
		if expected.distance_to(sample.p as Vector3) > float(RULES.limits.teleport_m):
			reason = "teleport"
	if not reason.is_empty():
		_auto_breaks += 1
		discontinuity("auto:" + reason)

func _book_bonks(sample: Dictionary) -> void:
	var tick := int(sample.get("tick", 0))
	for contact: Variant in ((sample.get("motion", {}) as Dictionary).get("contacts", []) as Array):
		if contact is Dictionary and bool((contact as Dictionary).get("blocking", false)):
			var n: Vector3 = (contact as Dictionary).get("normal", Vector3.UP)
			if n.y < _walkable():
				_bonks[str((contact as Dictionary).get("body", ""))] = tick

# --- speed ------------------------------------------------------------------------------------

func _speed(sample: Dictionary, dt: float, out: Array[Dictionary]) -> void:
	var rules: Dictionary = RULES.speed
	var at: Vector3 = sample.get("reference_p", sample.get("p", Vector3.ZERO))
	var cell := Vector3i(floori(at.x / float(rules.cell_m)), floori(at.y / float(rules.cell_y_m)), floori(at.z / float(rules.cell_m)))
	if cell != _cell:
		_cell = cell
		# new ground: neither this cell nor any of its eight horizontal neighbours was visited more
		# than recent_s ago (the runner's own fresh trail does not count), so a rerun of a line a
		# metre or two to the side is still the same ground.
		_cell_novel = true
		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				var seen: Variant = _visited.get(cell + Vector3i(dx, 0, dz))
				if seen != null and _time - float(seen) > float(rules.recent_s):
					_cell_novel = false
	_visited[cell] = _time
	var v: Vector3 = sample.get("actual_v", Vector3.ZERO)
	var speed := _hspeed_u(v)
	if speed < float(rules.min_ups):
		return
	var metres := speed * U * dt
	if not _cell_novel:
		_stale_fast_m += metres
		return
	_stretch_m += metres
	_stretch_weighted += metres * speed
	if _stretch_m >= float(rules.stretch_m):
		var mean := _stretch_weighted / _stretch_m
		var base := clampf(float(rules.base) * pow(mean / float(rules.min_ups), 2.0), float(rules.base), float(rules.cap))
		_award("speed", sample, base, "Speed %d" % roundi(mean), {"mean_ups": snappedf(mean, 0.01), "stretch_m": snappedf(_stretch_m, 0.001),
			"visited_cells": _visited.size()}, {}, out)
		_stretch_m = 0.0
		_stretch_weighted = 0.0

# --- sync -------------------------------------------------------------------------------------

func _sync(sample: Dictionary, out: Array[Dictionary]) -> void:
	var stats: Dictionary = sample.get("stats", {})
	if stats.is_empty():
		return
	var hops := int(stats.get("hops", 0))
	if _stats_hops < 0 or hops < _stats_hops:
		_stats_hops = hops
		return
	if hops == _stats_hops:
		return
	_stats_hops = hops
	var hop: Dictionary = stats.get("last_hop", {})
	var rules: Dictionary = RULES.sync
	var sync: Variant = hop.get("sync")
	var eligible := int(hop.get("eligible", 0))
	var air_ticks := maxi(1, int(hop.get("air_ticks", 1)))
	var air_gain := float(hop.get("air", hop.get("gain", 0.0)))
	var gain := float(hop.get("gain", 0.0))
	var verdict := "paid"
	if sync == null or eligible < int(rules.min_eligible) or float(eligible) / float(air_ticks) < float(rules.min_share):
		verdict = "few_eligible"
	elif float(sync) < float(rules.min_sync):
		verdict = "low_sync"
	elif air_gain < float(rules.min_air_gain_ups) or gain <= 0.0:
		verdict = "no_gain"
	var at: Vector3 = sample.get("reference_p", sample.get("p", Vector3.ZERO))
	var key := "%d,%d,%d" % [roundi(at.x), roundi(at.y), roundi(at.z)]
	if verdict == "paid":
		for spot: Vector3 in _sync_spots:
			if spot.distance_to(at) < float(rules.spacing_m):
				verdict = "repeat_spot"
				_blocked["sync"] = int(_blocked.get("sync", 0)) + 1
				break
	if verdict == "paid":
		_sync_spots.append(at)
	_count("sync", verdict)
	_sync_last = {"verdict": verdict, "sync": sync, "eligible": eligible, "air_ticks": air_ticks, "air_gain_ups": air_gain, "gain_ups": gain, "hop": hops}
	if verdict != "paid":
		return
	var base := minf(float(rules.cap), float(rules.base) + air_gain * float(rules.per_ups))
	_award("sync", sample, base, "Sync %d%%  +%d" % [roundi(float(sync) * 100.0), roundi(air_gain)],
		{"sync": snappedf(float(sync), 0.0001), "eligible": eligible, "air_ticks": air_ticks, "air_gain_ups": snappedf(air_gain, 0.01),
		"gain_ups": snappedf(gain, 0.01), "contact_ups": snappedf(float(hop.get("contact", 0.0)), 0.01), "takeoff_ups": snappedf(float(hop.get("takeoff", 0.0)), 0.01),
		"landing_ups": snappedf(float(hop.get("landing", 0.0)), 0.01)}, {"cell": key}, out)

# --- flight: gap and edge -----------------------------------------------------------------------

func _flight_step(sample: Dictionary, out: Array[Dictionary]) -> void:
	var p: Vector3 = sample.get("p", Vector3.ZERO)
	var grounded := bool(sample.get("grounded", false))
	if _prev.is_empty():
		return
	var was_grounded := bool(_prev.grounded)
	if was_grounded and not grounded:
		var from: Vector3 = _prev.p
		var support := _support_at(from, 2.0)
		_flight = {"takeoff_p": from, "takeoff_y": from.y, "takeoff_tick": int(_prev.tick), "takeoff_geo": support.get("geo", {}),
			"ticks": 0, "void": false, "void_from": Vector3.ZERO, "segments": [], "last_p": from, "ducked_any": false}
	if _flight.is_empty():
		return
	_flight.ticks = int(_flight.ticks) + 1
	_flight.ducked_any = bool(_flight.ducked_any) or bool(sample.get("ducked", false))
	var last: Vector3 = _flight.last_p
	var over := grounded or _flight_supported(p)
	if bool(_flight.void) and over:
		var end := _boundary(last, p, true)
		(_flight.segments as Array).append([_flight.void_from, end])
		_flight.void = false
	elif not bool(_flight.void) and not over:
		_flight.void_from = _boundary(last, p, false)
		_flight.void = true
	_flight.last_p = p
	if grounded:
		_land(sample, out)
		_flight = {}

## support under the hull for the gap rule: a hull cast from the feet down to drop_m below the
## takeoff level (at least the ground probe). a cast that reports nothing but ends overlapping
## geometry counts as support (godot 4.7.2 can miss a prism's top face; docs/r14/CONTACT-GUARD.md).
func _flight_supported(p: Vector3) -> bool:
	var floor_y := float(_flight.takeoff_y) - float(RULES.gap.drop_m)
	var depth := maxf(p.y - floor_y, _probe_u() * U)
	return _down_hit(p, depth)

## bisects the straight segment a -> b for the support boundary. `to_support`: a is void, b is
## supported; else a is supported and b void. returns the point just on the void side.
func _boundary(a: Vector3, b: Vector3, to_support: bool) -> Vector3:
	var lo := 0.0
	var hi := 1.0
	for i: int in int(RULES.gap.bisect):
		var mid := (lo + hi) * 0.5
		var supported := _flight_supported(a.lerp(b, mid))
		if supported == to_support:
			hi = mid
		else:
			lo = mid
	return a.lerp(b, lo if to_support else hi)

func _land(sample: Dictionary, out: Array[Dictionary]) -> void:
	var p: Vector3 = sample.get("p", Vector3.ZERO)
	var takeoff: Vector3 = _flight.takeoff_p
	var line := Vector3(p.x - takeoff.x, 0.0, p.z - takeoff.z)
	var flight_m := line.length()
	var dir := line / flight_m if flight_m > 1e-6 else Vector3.ZERO
	var landing := _support_at(p, 2.0)
	var void_m := 0.0
	var seg_best: Array = []
	for seg: Array in (_flight.segments as Array):
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var length := Vector2(b.x - a.x, b.z - a.z).length()
		if length > void_m:
			void_m = length
			seg_best = [a, b]
	var width_m := _hull_width_u(sample) * U
	var landed_level := p.y >= float(_flight.takeoff_y) - float(RULES.gap.drop_m) - 1e-3
	var rise_u := (p.y - float(_flight.takeoff_y)) / U
	var rules: Dictionary = RULES.gap
	var cleared := void_m + width_m if void_m > 0.0 else 0.0
	_last_gap = {"tick": int(sample.get("tick", 0)), "void_m": snappedf(void_m, 0.0001), "cleared_m": snappedf(cleared, 0.0001), "segments": (_flight.segments as Array).size(),
		"landed_level": landed_level, "air_ticks": int(_flight.ticks), "rise_u": snappedf(rise_u, 0.01), "flight_m": snappedf(flight_m, 0.001),
		"takeoff_geo": _flight.takeoff_geo, "landing_geo": landing.get("geo", {}), "verdict": ""}
	var gap_ok := void_m > 0.0 and landed_level and int(_flight.ticks) >= int(rules.min_air_ticks)
	if gap_ok and cleared >= float(rules.min_m):
		var key := "%s>%s|%s" % [_geo_key(_flight.takeoff_geo), _geo_key(landing.get("geo", {})), _dir_key(dir)]
		if _novel("gap", key):
			var base := minf(float(rules.cap), float(rules.scale) * pow(cleared, float(rules.power)))
			_last_gap.verdict = "paid"
			_count("gap", "paid")
			_award("gap", sample, base, "Gap %.1f m" % cleared, {"cleared_m": snappedf(cleared, 0.0001), "void_m": snappedf(void_m, 0.0001),
				"hull_width_m": snappedf(width_m, 0.0001), "void_from": _arr(seg_best[0]), "void_to": _arr(seg_best[1]), "air_ticks": int(_flight.ticks),
				"rise_u": snappedf(rise_u, 0.01), "takeoff": _arr(takeoff), "ducked_in_flight": bool(_flight.ducked_any)},
				{"from": _flight.takeoff_geo, "to": landing.get("geo", {})}, out)
		else:
			_last_gap.verdict = "repeat"
			_count("gap", "repeat")
	elif void_m > 0.0:
		_last_gap.verdict = "fell" if not landed_level else "short"
		_count("gap", str(_last_gap.verdict))
	# edge: only for a flight that crossed a gap or climbed onto something, along its own line.
	var erules: Dictionary = RULES.edge
	_last_edge = {}
	if (not gap_ok and rise_u < float(erules.rise_u)) or flight_m < float(erules.min_flight_m) or dir == Vector3.ZERO:
		return
	var slack := _slack(p, -dir)
	_last_edge = slack.duplicate()
	_last_edge["tick"] = int(sample.get("tick", 0))
	_last_edge["why"] = "gap" if gap_ok else "climb"
	if bool(slack.get("blocked", false)) or not slack.has("slack_u") or float(slack.slack_u) > float(erules.max_u):
		_last_edge["verdict"] = "blocked" if bool(slack.get("blocked", false)) else "roomy"
		_count("edge", str(_last_edge.verdict))
		return
	var key := "%s|%s" % [_geo_key(landing.get("geo", {})), _dir_key(dir)]
	if not _novel("edge", key):
		_last_edge["verdict"] = "repeat"
		_count("edge", "repeat")
		return
	_last_edge["verdict"] = "paid"
	_count("edge", "paid")
	var share := 1.0 - float(slack.slack_u) / float(erules.max_u)
	var base := float(erules.base) + float(erules.bonus) * share * share
	_award("edge", sample, base, "Edge %d cm" % roundi(float(slack.slack_u) * U * 100.0), {"slack_u": snappedf(float(slack.slack_u), 0.001),
		"slack_m": snappedf(float(slack.slack_u) * U, 0.00001), "line": _arr(dir), "why": _last_edge.why, "rise_u": snappedf(rise_u, 0.01),
		"hull_width_u": _hull_width_u(sample)}, {"landing": landing.get("geo", {})}, out)

## how far the actual hull at `p` can move along `dir` (horizontal unit) and still stand on
## walkable support within the ground probe. {slack_u} when it loses support within scan_u,
## {roomy} when it never does, {blocked} when the shifted hull would overlap something first.
func _slack(p: Vector3, dir: Vector3) -> Dictionary:
	var rules: Dictionary = RULES.edge
	var step := float(rules.step_u)
	var s := 0.0
	var supported_s := 0.0
	while s <= float(rules.scan_u) + 1e-6:
		var at := p + dir * s * U
		if s > 0.0 and _overlaps(at):
			return {"blocked": true, "at_u": s}
		if not _down_hit(at, _probe_u() * U, true):
			var lo := supported_s
			var hi := s
			for i: int in int(rules.bisect):
				var mid := (lo + hi) * 0.5
				if _overlaps(p + dir * mid * U) or _down_hit(p + dir * mid * U, _probe_u() * U, true):
					lo = mid
				else:
					hi = mid
			return {"slack_u": (lo + hi) * 0.5, "resolution_u": hi - lo}
		supported_s = s
		s += step
	return {"roomy": true, "scan_u": float(rules.scan_u)}

# --- near miss --------------------------------------------------------------------------------

func _near_step(sample: Dictionary, out: Array[Dictionary]) -> void:
	var rules: Dictionary = RULES.near
	var v: Vector3 = sample.get("actual_v", Vector3.ZERO)
	var speed := _hspeed_u(v)
	var p: Vector3 = sample.get("p", Vector3.ZERO)
	if speed < float(rules.min_ups):
		if not _near.is_empty():
			_near_last = {"verdict": "slowed", "tick": int(sample.get("tick", 0))}
			_count("near_miss", "slowed")
		_near = {}
		_near_open_before = false
		return
	var forward := Vector3(v.x, 0.0, v.z).normalized()
	# yaw 0 faces -z with +x on the right, so the left of a heading f is (f.z, 0, -f.x).
	var left := Vector3(forward.z, 0.0, -forward.x)
	var sides := {"left": left, "right": -left}
	if not bool(sample.get("ducked", false)):
		sides["up"] = Vector3.UP
	var tight := {}
	for side: String in sides:
		var probe := _clearance(p, sides[side], side != "up")
		if probe.has("clear_u") and float(probe.clear_u) <= float(rules.gap_u):
			tight[side] = probe
	var tick := int(sample.get("tick", 0))
	if tight.is_empty():
		if not _near.is_empty():
			_close_near(sample, out)
		_near = {}
		_near_open_before = true
		return
	if _near.is_empty():
		if not _near_open_before:
			return
		_near = {"start_tick": tick, "start_p": p, "track_m": 0.0, "sides": {}, "scraped": false, "max_ups": speed, "paired": false, "last_p": p}
	_near.track_m = float(_near.track_m) + Vector2(p.x - (_near.last_p as Vector3).x, p.z - (_near.last_p as Vector3).z).length()
	_near.last_p = p
	_near.max_ups = maxf(float(_near.max_ups), speed)
	if tight.size() >= 2:
		_near.paired = true
	for side: String in tight:
		var probe: Dictionary = tight[side]
		var best: Dictionary = (_near.sides as Dictionary).get(side, {})
		if best.is_empty() or float(probe.clear_u) < float(best.clear_u):
			(_near.sides as Dictionary)[side] = probe
	# any touch of a non-floor face during the passage is a scrape, blocking or not, and so is a
	# probe that starts touching (a hull sliding along a face).
	for contact: Variant in ((sample.get("motion", {}) as Dictionary).get("contacts", []) as Array):
		if contact is Dictionary and ((contact as Dictionary).get("normal", Vector3.UP) as Vector3).y < _walkable():
			_near.scraped = true
	for side: String in tight:
		if float((tight[side] as Dictionary).clear_u) < float(rules.touch_u):
			_near.scraped = true
	if float(_near.track_m) > float(rules.max_track_m):
		_near_last = {"verdict": "too_long", "tick": tick, "track_m": snappedf(float(_near.track_m), 0.001)}
		_count("near_miss", "too_long")
		_near = {}
		_near_open_before = false

func _close_near(sample: Dictionary, out: Array[Dictionary]) -> void:
	var rules: Dictionary = RULES.near
	var sides: Dictionary = _near.sides
	var closest := ""
	for side: String in sides:
		if closest.is_empty() or float((sides[side] as Dictionary).clear_u) < float((sides[closest] as Dictionary).clear_u):
			closest = side
	var probe: Dictionary = sides[closest]
	var clear := float(probe.clear_u)
	var geos: Array[String] = []
	for side: String in sides:
		geos.append(_geo_key((sides[side] as Dictionary).get("geo", {})))
	geos.sort()
	_near_last = {"tick": int(sample.get("tick", 0)), "clear_u": snappedf(clear, 0.001), "side": closest, "track_m": snappedf(float(_near.track_m), 0.001),
		"scraped": bool(_near.scraped), "thread": bool(_near.paired), "verdict": ""}
	if bool(_near.scraped):
		_near_last.verdict = "scraped"
		_count("near_miss", "scraped")
		return
	if not _novel("near_miss", ",".join(geos)):
		_near_last.verdict = "repeat"
		_count("near_miss", "repeat")
		return
	_near_last.verdict = "paid"
	_count("near_miss", "paid")
	var share := 1.0 - clear / float(rules.gap_u)
	var speed_factor := clampf(float(_near.max_ups) / float(rules.min_ups), 1.0, float(rules.speed_cap))
	var base := (float(rules.base) + float(rules.bonus) * share * share) * speed_factor
	if bool(_near.paired):
		base *= float(rules.thread)
	var word := "Thread" if bool(_near.paired) else ("Head room" if closest == "up" else "Near miss")
	var side_clear := {}
	for side: String in sides:
		side_clear[side] = snappedf(float((sides[side] as Dictionary).clear_u), 0.001)
	_award("near_miss", sample, base, "%s %d cm" % [word, roundi(clear * U * 100.0)], {"clear_u": snappedf(clear, 0.001), "side": closest,
		"sides_u": side_clear, "thread": bool(_near.paired), "max_ups": snappedf(float(_near.max_ups), 0.01), "track_m": snappedf(float(_near.track_m), 0.001),
		"start_tick": int(_near.start_tick)}, {"obstacle": probe.get("geo", {}), "others": geos}, out)

## free space from the actual hull at `p` along `dir`, u. sideways probes start `lift_u` up so a
## floor the hull rests on is never the answer; a probe that meets a floor or ceiling-like face
## at the side (|n.y| >= walkable) reports nothing, as does an up probe meeting a non-ceiling.
func _clearance(p: Vector3, dir: Vector3, lifted: bool) -> Dictionary:
	var rules: Dictionary = RULES.near
	var from := p + (Vector3.UP * float(rules.lift_u) * U if lifted else Vector3.ZERO)
	if _overlaps(from):
		return {}
	var motion := dir * float(rules.probe_u) * U
	var hit := KinematicCollision3D.new()
	if not _body.test_move(Transform3D(_body.global_transform.basis, from), motion, hit, GUARD_MARGIN, false, 4):
		return {}
	var travelled := (motion.length() - hit.get_remainder().length()) / U
	var n := hit.get_normal(0)
	if lifted and absf(n.y) >= _walkable():
		return {}
	if not lifted and n.y > -_walkable():
		return {}
	return {"clear_u": maxf(0.0, travelled), "normal": _arr(n), "geo": _geo(hit.get_collider(0), n)}

# --- crouch save ------------------------------------------------------------------------------

func _crouch_step(sample: Dictionary, out: Array[Dictionary]) -> void:
	var ducked := bool(sample.get("ducked", false))
	var motion: Dictionary = sample.get("motion", {})
	if not _save.is_empty():
		_follow_save(sample, out)
	if not ducked or not _save.is_empty():
		return
	_crouch_counts.ducked_ticks += 1
	var disp: Vector3 = motion.get("displacement", Vector3.ZERO)
	# the sweep maps the standing hull with the grounding this tick's move started from: a crouch
	# jump whose crossing tick ends on the ledge (the 2 u ground probe) moved through the air.
	var moved_grounded := bool(_prev.get("grounded", sample.get("grounded", false))) if not _prev.is_empty() else bool(sample.get("grounded", false))
	var slabs := _slabs(sample, moved_grounded)
	var verdict := {"tick": int(sample.get("tick", 0)), "slabs": slabs.size(), "class": "none"}
	if slabs.is_empty() or disp.length() < 1e-6:
		verdict["class"] = "still" if disp.length() < 1e-6 else "no_slab"
		_crouch_last = verdict
		return
	for slab: Dictionary in slabs:
		var size: Vector3 = slab.size
		var end: Vector3 = slab.centre
		var start := end - disp
		if not _box_hits(size, start).is_empty():
			_crouch_counts.start_overlap += 1
			verdict["class"] = "start_overlap"
			verdict["slab"] = slab.name
			continue
		var hit := _box_sweep(size, start, disp)
		if hit.is_empty():
			continue
		var n: Vector3 = hit.normal
		verdict["slab"] = slab.name
		verdict["normal"] = _arr(n)
		verdict["geo"] = hit.geo
		if n.y >= _walkable():
			_crouch_counts.support += 1
			verdict["class"] = "support"
			continue
		_crouch_counts.obstacle += 1
		var name := str(hit.name)
		var tick := int(sample.get("tick", 0))
		if _duck_touched(motion, name):
			_crouch_counts.duck_hit += 1
			verdict["class"] = "duck_hit"
			continue
		if _bonks.has(name) and tick - int(_bonks[name]) <= int(RULES.crouch.bonk_ticks) and int(_bonks[name]) < tick:
			_crouch_counts.bonked += 1
			verdict["class"] = "bonked"
			continue
		var speed := _hspeed_u(sample.get("actual_v", Vector3.ZERO))
		if speed < float(RULES.crouch.min_ups):
			_crouch_counts.slow += 1
			verdict["class"] = "slow"
			verdict["speed_ups"] = speed
			continue
		var p: Vector3 = sample.get("p", Vector3.ZERO)
		var dir := Vector3(disp.x, 0.0, disp.z).normalized()
		_save = {"open_tick": tick, "open_time": _time, "entry_p": p, "dir": dir, "entry_ups": speed, "airborne": not moved_grounded,
			"slab": slab.name, "normal": n, "geo": hit.geo, "name": name, "room_u": INF, "intrusion_u": 0.0, "duck_contact": false,
			"lift_u": float(slab.lift_u), "via": _duck_via(motion), "fraction": float(hit.fraction)}
		_measure_room(sample, moved_grounded)
		_crouch_counts.opened += 1
		verdict["class"] = "opened"
		_crouch_last = verdict
		return
	_crouch_last = verdict

## the slabs of the standing counterfactual that the actual duck hull does not occupy, for the
## current pose: [{name, size, centre, lift_u}]. the standing feet are the duck feet on the
## floor, and the duck feet lowered by the runner's air lift in flight: the pose the runner's own
## stand test uses (r15_source_player.gd _update_duck), so for the "center" anchor the standing
## box shares the duck box's centre.
func _slabs(sample: Dictionary, grounded: Variant = null) -> Array[Dictionary]:
	var motion: Dictionary = sample.get("motion", {})
	var cvars: Dictionary = motion.get("cvars", {})
	var hull: Dictionary = motion.get("hull", {})
	var duck: Dictionary = motion.get("duck", {})
	var p: Vector3 = sample.get("p", Vector3.ZERO)
	var width := float(hull.get("width_u", cvars.get("hull_width", 32.0))) * U
	var duck_h := float(hull.get("height_u", cvars.get("duck_hull_height", 54.0))) * U
	var stand_h := float(cvars.get("hull_height", 72.0)) * U
	var on_floor := bool(sample.get("grounded", false)) if grounded == null else bool(grounded)
	var lift_u := 0.0 if on_floor else float(duck.get("air_lift_u", 9.0))
	var stand_feet := p.y - lift_u * U
	var out: Array[Dictionary] = []
	var head_lo := p.y + duck_h
	var head_hi := stand_feet + stand_h
	if head_hi - head_lo > 1e-5:
		out.append({"name": "head", "size": Vector3(width, head_hi - head_lo, width), "centre": Vector3(p.x, (head_lo + head_hi) * 0.5, p.z), "lift_u": lift_u})
	if p.y - stand_feet > 1e-5:
		out.append({"name": "foot", "size": Vector3(width, p.y - stand_feet, width), "centre": Vector3(p.x, (stand_feet + p.y) * 0.5, p.z), "lift_u": lift_u})
	return out

## an open save, each tick until it pays or ends: the standing counterfactual at the current
## pose (the actual hull when standing again) is checked for any non-support overlap.
func _follow_save(sample: Dictionary, out: Array[Dictionary]) -> void:
	var p: Vector3 = sample.get("p", Vector3.ZERO)
	var motion: Dictionary = sample.get("motion", {})
	if _duck_touched(motion, str(_save.name)):
		_save.duck_contact = true
		_crouch_counts.duck_hit += 1
		_cancel_save("duck_contact")
		return
	if _time - float(_save.open_time) > float(RULES.crouch.max_s):
		_cancel_save("timeout")
		return
	var blocked := false
	if bool(sample.get("ducked", false)):
		_measure_room(sample)
		for slab: Dictionary in _slabs(sample):
			if not _box_hits(slab.size, slab.centre).is_empty():
				if str(slab.name) == "head" or not _is_support_overlap(slab):
					blocked = true
	if blocked:
		return
	var progress := (Vector3(p.x, 0.0, p.z) - Vector3((_save.entry_p as Vector3).x, 0.0, (_save.entry_p as Vector3).z)).dot(_save.dir as Vector3)
	var width := _hull_width_u(sample) * U
	# clear but not yet a hull width past the entry: keep waiting; clear and behind it: backed out.
	if progress < -0.5 * width:
		_cancel_save("backed_out")
	elif progress >= width:
		_pay_save(sample, progress, out)

func _pay_save(sample: Dictionary, progress: float, out: Array[Dictionary]) -> void:
	var rules: Dictionary = RULES.crouch
	var key := _geo_key(_save.geo)
	var record := {"tick": int(sample.get("tick", 0)), "verdict": "", "geo": _save.geo, "slab": _save.slab}
	if not _novel("crouch_save", key):
		record.verdict = "repeat"
		_crouch_last = record
		_save = {}
		return
	var speed_factor := clampf(float(_save.entry_ups) / float(rules.speed_ref_ups), 1.0, float(rules.speed_cap))
	var base := float(rules.base) * speed_factor + (float(rules.air_bonus) if bool(_save.airborne) else 0.0)
	var room := float(_save.room_u)
	var label := "Crouch save"
	if room < INF:
		label += " %d cm" % roundi(room * U * 100.0)
	_crouch_counts.paid += 1
	record.verdict = "paid"
	_crouch_last = record
	_award("crouch_save", sample, base, label, {"entry_ups": snappedf(float(_save.entry_ups), 0.01), "airborne": bool(_save.airborne),
		"slab": _save.slab, "normal": _arr(_save.normal), "room_u": snappedf(room, 0.001) if room < INF else null,
		"standing_intrusion_u": snappedf(float(_save.intrusion_u), 0.001), "lift_u": _save.lift_u, "progress_m": snappedf(progress, 0.001),
		"open_tick": int(_save.open_tick), "ticks": int(sample.get("tick", 0)) - int(_save.open_tick), "duck_contact": bool(_save.duck_contact),
		"via": _save.via, "sweep_fraction": snappedf(float(_save.fraction), 0.0001)}, {"obstacle": _save.geo}, out)
	_save = {}

func _cancel_save(reason: String) -> void:
	_crouch_counts.cancelled = int(_crouch_counts.get("cancelled", 0)) + 1
	_crouch_last = {"verdict": "cancelled", "reason": reason, "geo": _save.get("geo", {}), "slab": _save.get("slab", "")}
	_save = {}

## the duck hull's free room toward the obstacle while a save is open: up from the duck top for
## a head save, down from the duck feet for a foot save, with a thin box of hull width. the
## smallest room and the deepest standing intrusion (slab height - room) are kept.
func _measure_room(sample: Dictionary, grounded: Variant = null) -> void:
	for slab: Dictionary in _slabs(sample, grounded):
		if str(slab.name) != str(_save.slab):
			continue
		var size: Vector3 = slab.size
		var thin := Vector3(size.x, 0.25 * U, size.z)
		var up := str(slab.name) == "head"
		var face_y: float = (slab.centre as Vector3).y + (-0.5 if up else 0.5) * size.y
		var start := Vector3((slab.centre as Vector3).x, face_y + (0.5 if up else -0.5) * thin.y + (1.0 if up else -1.0) * 0.0005, (slab.centre as Vector3).z)
		var travel := (Vector3.UP if up else Vector3.DOWN) * (size.y - thin.y)
		var hit := _box_sweep(thin, start, travel)
		if hit.is_empty():
			continue
		var room := (travel.length() * float(hit.fraction) + thin.y + 0.0005) / U
		var slab_u := size.y / U
		if room < float(_save.room_u):
			_save.room_u = room
			_save.intrusion_u = maxf(float(_save.intrusion_u), slab_u - room)

## a foot-slab overlap is support when the actual hull, cast down from the duck feet through the
## slab, meets walkable ground: the standing hull would stand on that top (or be lowered into
## it), not be blocked by its side. a non-walkable top there still blocks.
func _is_support_overlap(slab: Dictionary) -> bool:
	var feet := (slab.centre as Vector3) + Vector3.UP * (slab.size as Vector3).y * 0.5
	return _down_hit(feet, (slab.size as Vector3).y + _probe_u() * U, true)

func _duck_touched(motion: Dictionary, name: String) -> bool:
	for contact: Variant in (motion.get("contacts", []) as Array):
		if contact is Dictionary and bool((contact as Dictionary).get("blocking", false)) and str((contact as Dictionary).get("body", "")) == name:
			# landing on a cleared ledge is support, not a failed passage into its face.
			if ((contact as Dictionary).get("normal", Vector3.UP) as Vector3).y < _walkable():
				return true
	return false

func _duck_via(motion: Dictionary) -> String:
	var lab: Variant = motion.get("experiment")
	if lab is Dictionary and bool((lab as Dictionary).get("slide_active", false)):
		return "slide"
	return "crouch"

# --- geometry queries -------------------------------------------------------------------------

func _space() -> PhysicsDirectSpaceState3D:
	return _body.get_world_3d().direct_space_state

func _query(size: Vector3, centre: Vector3, margin := 0.0) -> PhysicsShapeQueryParameters3D:
	var box := BoxShape3D.new()
	box.size = size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis.IDENTITY, centre)
	q.collision_mask = _body.collision_mask
	q.exclude = [_body.get_rid()]
	q.margin = margin
	return q

## static overlaps of a box: [{name, geo}].
func _box_hits(size: Vector3, centre: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for hit: Dictionary in _space().intersect_shape(_query(size, centre), 8):
		var node := hit.get("collider") as Node
		out.append({"name": str(node.name) if node != null else "", "geo": _geo(node, Vector3.ZERO)})
	return out

## a box swept from `start` along `motion`: {} when clear, else {fraction, normal, name, geo}
## at the first touch. a clear sweep that ends overlapping is reported at its end (the guard).
func _box_sweep(size: Vector3, start: Vector3, motion: Vector3) -> Dictionary:
	var q := _query(size, start)
	q.motion = motion
	var cast := _space().cast_motion(q)
	var lo := 0.0
	var hi := 1.0
	if cast.size() == 2 and float(cast[1]) < 1.0:
		lo = float(cast[0])
		hi = float(cast[1])
	elif _box_hits(size, start + motion).is_empty():
		return {}
	# godot's cast stops within about 1/256 of the motion; the first touch is bisected further
	# with overlap tests (SWEEP_BISECT steps between its safe and unsafe fractions).
	for i: int in SWEEP_BISECT:
		var mid := (lo + hi) * 0.5
		if _box_hits(size, start + motion * mid).is_empty():
			lo = mid
		else:
			hi = mid
	var fraction := hi
	var at := _query(size, start + motion * fraction, 0.002)
	var rest := _space().get_rest_info(at)
	if rest.is_empty():
		return {}
	var node := instance_from_id(int(rest.collider_id)) as Node
	var n: Vector3 = rest.normal
	return {"fraction": fraction, "normal": n, "name": str(node.name) if node != null else "", "geo": _geo(node, n), "point": rest.point}

## true when the actual hull at `p` overlaps anything (godot's minimum test margin).
func _overlaps(p: Vector3) -> bool:
	return _body.test_move(Transform3D(_body.global_transform.basis, p), Vector3.ZERO, null, GUARD_MARGIN, true, 1)

## the actual hull cast down from `p` by `depth` metres meets something; `walkable_only` asks for
## walkable support. a contact-free cast that ends overlapping counts as a hit (missed top face).
func _down_hit(p: Vector3, depth: float, walkable_only := false) -> bool:
	var basis := _body.global_transform.basis
	var hit := KinematicCollision3D.new()
	if _body.test_move(Transform3D(basis, p), Vector3.DOWN * depth, hit, GUARD_MARGIN, false, 4):
		if not walkable_only:
			return true
		for i: int in hit.get_collision_count():
			if hit.get_normal(i).y >= _walkable():
				return true
		return false
	return _overlaps(p + Vector3.DOWN * depth)

## the walkable support under the actual hull at `p` within `probe_u`: {geo, normal} or {}.
func _support_at(p: Vector3, probe_u: float) -> Dictionary:
	var hit := KinematicCollision3D.new()
	if not _body.test_move(Transform3D(_body.global_transform.basis, p), Vector3.DOWN * probe_u * U, hit, GUARD_MARGIN, false, 4):
		return {}
	for i: int in hit.get_collision_count():
		var n := hit.get_normal(i)
		if n.y >= _walkable():
			return {"geo": _geo(hit.get_collider(i), n), "normal": n}
	return {}

# --- small helpers ----------------------------------------------------------------------------

## a stable geometry identity: the collider's path under the level (or its name), and the face
## normal rounded to 0.001 when there is one. never an instance id.
func _geo(collider: Object, normal: Vector3) -> Dictionary:
	var node := collider as Node
	if node == null:
		return {}
	var path := str(node.name)
	if _level != null and is_instance_valid(_level) and _level.is_ancestor_of(node):
		path = str(_level.get_path_to(node))
	var out := {"path": path}
	var surface: Variant = node.get_meta("surface", null)
	if surface != null:
		out["surface"] = str(surface)
	if normal != Vector3.ZERO:
		out["face"] = [snappedf(normal.x, 0.001), snappedf(normal.y, 0.001), snappedf(normal.z, 0.001)]
	return out

static func _geo_key(geo: Variant) -> String:
	return str((geo as Dictionary).get("path", "?")) if geo is Dictionary else "?"

static func _dir_key(dir: Vector3) -> String:
	if dir == Vector3.ZERO:
		return "0"
	return str(wrapi(roundi(rad_to_deg(atan2(dir.x, -dir.z)) / 45.0), 0, 8))

func _walkable() -> float:
	if _body != null and "settings" in _body:
		return float((_body.get("settings") as Dictionary).get("sv_walkable_normal", 0.7))
	return 0.7

func _probe_u() -> float:
	if _body != null and "settings" in _body:
		return float((_body.get("settings") as Dictionary).get("ground_probe", 2.0))
	return 2.0

func _hull_width_u(sample: Dictionary) -> float:
	var hull: Dictionary = (sample.get("motion", {}) as Dictionary).get("hull", {})
	return float(hull.get("width_u", 32.0))

static func _hspeed_u(v: Variant) -> float:
	if not v is Vector3:
		return 0.0
	return Vector2((v as Vector3).x, (v as Vector3).z).length() / U

static func _arr(v: Variant) -> Variant:
	if v is Vector3:
		return [snappedf((v as Vector3).x, 0.0001), snappedf((v as Vector3).y, 0.0001), snappedf((v as Vector3).z, 0.0001)]
	return v

func _flight_diag() -> Dictionary:
	if _flight.is_empty():
		return {}
	return {"ticks": _flight.ticks, "void": _flight.void, "segments": (_flight.segments as Array).size(), "takeoff_y": _flight.takeoff_y}

func _near_diag() -> Dictionary:
	if _near.is_empty():
		return {}
	return {"track_m": _near.track_m, "sides": (_near.sides as Dictionary).keys(), "scraped": _near.scraped, "thread": _near.paired}

func _save_diag() -> Dictionary:
	if _save.is_empty():
		return {}
	return {"slab": _save.slab, "geo": _save.geo, "entry_ups": _save.entry_ups, "airborne": _save.airborne, "room_u": _save.room_u if float(_save.room_u) < INF else null}

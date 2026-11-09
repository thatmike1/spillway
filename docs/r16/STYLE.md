# R16 style scoring

`scripts/r16_style.gd` (service, `STYLE_VERSION = "r16-style-1"`) and `scripts/r16_style_panel.gd` (HUD block). Both only read the game: every geometry question is a query with the runner's own hull (`body.test_move`) or a direct space query with a box of the runner's hull size. Nothing writes position, velocity, grounding, input or progress.

All weights, windows and thresholds below are agent game choices (labelled `p /` in code), not tuned on Mike's play. They live in one `RULES` table whose hash enters the style identity, so changing any of them starts fresh style bests.

## Integration API (for root)

```gdscript
const STYLE := preload("res://scripts/r16_style.gd")
var style := STYLE.new()

style.reset(context)                # new attempt (spawn, R, F, stage practice, map/preset change): clears total
var fresh: Array[Dictionary] = style.step(sample, player, level)   # once per physics step, after the motor
style.discontinuity(reason)         # respawn, teleport, settings, pause, loadout: keeps total, see below
style.snapshot() -> Dictionary      # HUD, traces, tests
style.summary() -> Dictionary       # attempt end: score, by_kind, clean, finished, best_eligible
STYLE.identity() / STYLE.identity_key()   # style-best key part: version, event format, RULES sha256
```

- `step()` takes the INTERFACES post-step sample unchanged. Fields it reads: `tick, dt, elapsed, started, finished, clean, p, reference_p, actual_v, grounded, ducked, motion` (needs `displacement`, `origin_delta`, `contacts`, `hull`, `duck`, `cvars`, optional `experiment`) and `stats` (`hops`, `last_hop`). `held` and `input_events` are not used.
- Scoring runs only while `started and not finished`. The finish seals the total; untimed exploration afterwards scores nothing.
- `discontinuity(reason)` ends any flight, passage, open crouch save, speed stretch and recent-contact memory. It keeps the total, because a respawn stays inside one attempt. The combo ends unless the reason is `pause`, `settings` or `loadout`. `reset()` is the only call that clears the total.
- Self-guard: a sample whose tick is not the previous tick + 1, or whose feet are more than 5 cm from `previous p + motion.origin_delta`, is treated as `discontinuity("auto:tick_gap" | "auto:teleport")`. A respawn the host forgets to report therefore never reads as a gap, an edge or speed.
- Style best (root): save `summary().score` only when `summary().best_eligible` (`clean and finished`) under a key that includes `identity_key()` plus the map/preset/geometry/mechanics identity. Practice shows points but never saves.

Panel:

```gdscript
const PANEL := preload("res://scripts/r16_style_panel.gd")
var panel := PANEL.new()
hud_canvas_layer.add_child(panel)
panel.attach(main, style)           # reads style.snapshot() every frame
# optional fields on main: style_best:int (<0 none), style_new_best:bool, clean_eligible, finished, paused
# or panel.set_best(value) / panel.set_new_best(true) for a host without them
```

It draws one block low on the right, directly above the R15 clock: score (24 px ink), a `×N` multiplier in accent beside it from the second chained event, a 2 px accent bar that drains with the combo window, one dim line (`style best 12 340`, `practice, style not saved`, `new style best`, or nothing before the first point), and one callout above it in accent on the R15 shade (`Crouch save 10 cm  +1 200`). The callout holds 0.9 s and fades over 0.5 s; a lower-ranked event does not replace a higher one during the first 0.6 s (crouch save > gap = edge > near miss > sync > speed). It hides while paused. Identity, speed, crouch tag, strafe panel, clock and the centre stay where R15 put them.

## Event schema (`EVENT_FORMAT = 1`)

Every scored event is a JSON-safe Dictionary:

| key | meaning |
|---|---|
| `v` | event format, 1 |
| `kind` | `speed`, `sync`, `gap`, `edge`, `near_miss`, `crouch_save` |
| `tick` | the sample's attempt tick |
| `time_s` | attempt simulation time (sum of `dt` since `reset`) |
| `elapsed` | course clock at the event |
| `points` | `round(base × mult)` added to the score |
| `base`, `mult`, `combo` | rounded base, multiplier used, chain length after this event (0 for speed) |
| `label` | the player-facing callout, sentence case |
| `m` | measurements, per kind below; lengths say their unit in the key |
| `geo` | geometry identity: `{path, surface, face}`; `path` is the collider's path under the level node (stable piece name on every R15 map), `face` the contact normal rounded to 0.001 |
| `p` | feet at the event, metres |
| `clean` | the attempt was clean at that tick |

Measurements:

- `speed`: `mean_ups`, `stretch_m`, `visited_cells`.
- `sync`: `sync`, `eligible`, `air_ticks`, `air_gain_ups`, `gain_ups`, `contact_ups`, `takeoff_ups`, `landing_ups` (the R14 strafe-stats hop).
- `gap`: `cleared_m`, `void_m`, `hull_width_m`, `void_from`, `void_to` (refined boundary feet), `air_ticks`, `rise_u`, `takeoff`, `ducked_in_flight`; `geo` is `{from, to}`.
- `edge`: `slack_u`, `slack_m`, `line`, `why` (`gap` or `climb`), `rise_u`, `hull_width_u`; `geo` is `{landing}`.
- `near_miss`: `clear_u`, `side` (`left`, `right`, `up`), `sides_u`, `thread`, `max_ups`, `track_m`, `start_tick`; `geo` is `{obstacle, others}`.
- `crouch_save`: `entry_ups`, `airborne`, `slab` (`head` or `foot`), `normal`, `room_u` (smallest free room between the duck hull and the obstacle while passing), `standing_intrusion_u` (how far the standing hull would have been inside it), `lift_u`, `progress_m`, `open_tick`, `ticks`, `duck_contact`, `via` (`crouch` or the lab's `slide`), `sweep_fraction`; `geo` is `{obstacle}`.

## Scoring rules

| kind | pays when | base points |
|---|---|---|
| speed | 32 m of horizontal actual travel at ≥ 400 u/s on new ground: a 2 × 3 × 2 m cell that neither it nor its eight horizontal neighbours were visited more than 1 s earlier this attempt (the runner's own fresh trail does not count) | 20 × (mean / 400)², 20 to 80 |
| sync | a completed hop with sync ≥ 80 %, ≥ 10 eligible ticks that are ≥ 40 % of its air ticks, air gain (strafe-stats gain minus collision change) ≥ 8 u/s and total gain > 0 | 15 + 1.5 × air gain, cap 150 |
| gap | the hull crossed space with no support within 1.25 m below the takeoff level and landed no lower than that, after ≥ 8 air ticks; cleared ≥ 1.5 m | 25 × cleared_m^1.5, cap 900 (2 m 71, 3.5 m 164, 8.5 m 620) |
| edge | after a crossed void or a climb of ≥ 19 u, the landing slack along the flight line is ≤ 8 u (20 cm) | 50 + 250 × (1 − slack/8)² |
| near miss | at ≥ 380 u/s the hull passes ≤ 8 u from a side face (or a ceiling-like face over a standing head), entered from and left into open space, within 6 m of track, with no touch | (40 + 160 × (1 − clear/8)²) × min(speed/380, 2); × 1.5 for a thread (two sides) |
| crouch save | the standing counterfactual would have hit a non-support face the duck hull did not, and the duck hull went through (below) | 600 × min(max(entry/300, 1), 2), + 300 in flight: 600 to 1500 |

Combo: sync, gap, edge, near miss and crouch save each extend a chain; multiplier = 1 + 0.25 × (chain − 1), at most ×3. The chain ends after 2.5 s without one, after 0.75 s under 150 u/s, or at a discontinuity. Speed is paid at the current multiplier without extending the chain.

Anti-farm, all per attempt: a gap pays once per takeoff piece, landing piece and heading (8 sectors); an edge once per landing piece and heading; a near miss once per set of obstacle pieces; a crouch save once per obstacle piece; sync only 4 m or more from every earlier paid landing; speed only on new ground. Waiting earns nothing (nothing pays without travel, and the combo stalls). Oscillating at one edge repeats the same piece and heading. A loop revisits its cells. Blocked repeats are counted in `snapshot().diag.farm_blocked`.

## What each detector proves, and where it is approximate

- **Gap.** Each air tick casts the actual hull straight down from its feet to 1.25 m under the takeoff level. Transitions between supported and unsupported ticks are bisected 12 times on the straight segment between the two ticks' feet, so the void boundaries are within about 0.03 mm of the tick path. `cleared_m` = longest void track + one hull width (32 u). For a crossing perpendicular to the lips this is the gap's width; a diagonal crossing reports the longer along-track span. On Breakwater the six measured box-row, quay and breach gaps match the authored widths within 0.2 mm (perpendicular component). A cast that reports no contact but ends overlapping counts as support (the Godot 4.7.2 prism top-face miss, docs/r14/CONTACT-GUARD.md). A drop of more than 1.25 m into a pit and back out is a fall, not a gap.
- **Edge.** The actual hull at the landing pose is shifted back along the takeoff-to-landing line in 1 u steps and bisected 8 times (1/256 u). The slack is how much shorter the flight could have been and still stood on walkable support within the ground probe (2 u). Support is the union of all pieces, so a seam between coplanar pieces is not an edge. A shifted hull that would overlap a wall first reports `blocked` and pays nothing. Only the lip the flight came over is measured, not side edges.
- **Near miss.** Clearance is a `test_move` of the actual hull perpendicular to its horizontal actual velocity (from 1 u above the feet) and straight up. It is exact for a face parallel to the motion and conservative for a corner. Floors, ramps and the duck-hull headroom are excluded (headroom while ducked belongs to the crouch save).
- **Crouch save.** The standing counterfactual is the box the runner's own stand test would use for this pose: same feet on the floor; in flight the duck feet lowered by `air_lift_u` (9 u for the default `center` anchor, so standing and duck boxes share a centre; 18 u for `head`, 0 for `feet`). Only the slabs where it differs from the duck hull are swept (head: duck top to standing top; foot: standing feet to duck feet), straight along the tick's actual displacement, ending at the current pose. The sweep is a straight line; the actual tick may bend at up to four contacts. A first touch on a walkable face is support (the standing body would have landed or stood there), never a save. A slab that already overlaps at the start never opens a save (stationary ducking, ducking under something, respawns). The duck hull touching the same piece that tick, a non-floor contact with it in the previous 8 ticks (a bonk then a duck), or entry under 200 u/s also never opens one. An open save pays only when the standing counterfactual at the current pose is clear again (foot-slab overlaps with walkable ground under the duck feet count as clear) and the feet are at least one hull width past the entry along the entry direction; backing out half a hull width, a discontinuity, or 3 s cancels it.
- **Sync.** Uses `r14_strafe_stats.gd` per-hop numbers as delivered; `air` gain excludes collision change. No optimal-strafe claim.
- **Speed.** Horizontal actual travel (`actual_v`, which excludes the duck lift).

Not covered: wall runs, surf or slope speed bonuses, side-edge landings, lab grapple or wall-jump style (the lab's slide duck counts for crouch saves, labelled `via: slide`). The service treats every map alike; root decides whether the lab scores at all.

## Evidence

Headless only so far, Godot 4.7.2 on an isolated source copy. Native views are written but not yet run (`tests/r16_style_views.gd` via `tests/r16_style_native.py`). The 9 Nov check found 14.93 GiB free on /home, under the 15 GiB floor. Record: `checkpoints/spillway/r16/style/RESULTS.json`.

- `tests/test_r16_style.gd`: 60 checks, 0 failed. It runs on the actual R15 main hosting `tests/r16_style_fixture_level.gd`, with key and mouse input only. Each scored geometry piece is placed from a calibration run of the same deterministic input. The measured numbers match the designed ones: ground crouch-save headroom 4.000 u (designed 4), gap 4.5365 m (designed 4.5367 m), edge slack 3.002 u (designed 3 u), near miss 2.969 u (designed 3 u). The thread case measured 3.906 u against a designed 4 u; that 2.4 mm difference has not been isolated.
- Negative controls in that suite, all with no payout:
  - standing replay that bonks the beam
  - crawling under the beam and standing still under it
  - bonk, then duck
  - crouch on open floor
  - air duck landing on a floor (support, not a save)
  - standing jump at the high ledge, and crouch-jump onto a low ledge a standing jump would clear
  - shallow trench, 1 m gap, roomy landing
  - same gap again after a respawn (counted as repeat)
  - host respawn mid-flight
  - wide (12 u) pillar, scraped pillar, 12 m wall hug
  - W+A sync at 100 % with 0 air gain
  - idling after the timer starts
  - the same fast line run twice in one attempt: the second pass paid 0 of the first pass's 2151 points
- Two further suite checks: a trace with the style probe off is identical to the trace with it on, and no tick changed the body between the pre-style and post-style reads.
- `tests/test_r16_style_breakwater.gd`: the four R15 Breakwater route tapes, replayed open loop, reproduce their R15 finish ticks. On every route the measured gaps match the authored widths (2.0, 2.5, 3.0, 3.5, 3.0 m and the 8.5 m breach) within 0.2 mm across the line. The alley-miss jump pays nothing, and retried gaps and the harbour respawn produce no false events. Nothing scores after the finish.
- Not shown by any test: how the scores feel, the ceiling near miss ("head room"), and the lab slide's `via: slide` path.

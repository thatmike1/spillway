# R16 Movement Lab: limited A/D wall jumps and the landing slide

Runner: `scripts/r16_experiment_player.gd`, which extends the frozen R15 lab runner
(`r15_experiment_player.gd`) and through it the approved crouch runner. It overrides only the R15
hooks the two reworked moves own (`_wall_step`, `_slide_step`), the R14 world hook `air_move`
(for the push guard), `_physics_process` as a wrapper around the inherited tick, and reporting.
It doesn't clone the Source tick. The grapple (routines, `GRAPPLE` table, `r15_grapple` / E,
`r15_grapple_anchor`) is inherited as is. Every rule below is a game choice (**P**) checked
headless with key and mouse events, not a human playtest, and makes no claim about feel.

**Off means off.** With no Shift, no fresh Space press in the air and no wall jump in the last
0.25 s, a tick is R15's exactly: no velocity write, no settings swap, no motor-state write.

## What was wrong in R15

- **Wall jump only worked with W.** On F2 (AA 100, 128 Hz) the air budget is
  100 × 250 / 128 ≈ 195 u/s per tick. A held A or D that points into the wall cancels R15's
  230 u/s outward kick within about two ticks, so the body stays on the wall (it still rises from
  the 290 u/s vertical). W points along the wall, so the kick survives. Reproduced headless with
  the same events on both runners (table below).
- **No slide out of a bhop.** R15 starts a slide only on a fresh Shift press while grounded with
  Space up. With held-Space autohop the body is grounded for one tick and jumps on it, so a press
  in the air is refused (`airborne`) and a press on the landing tick is refused (`jump held`).

## Wall jump, `r16-lab-wall-jump-2` (Space)

| rule | value | tag |
|---|---|---|
| Trigger | a fresh Space press in the air (OS key repeats and held Space never count), a vertical static face within 6 u (R15's probe, `WALL.reach_u` / `max_normal_y`) | P (R15) |
| Press buffer | a press with no wall in reach waits 0.1 s (13 ticks) and fires on reaching one; other refusals drop it | P |
| Budget | 2 per landing. Only the motor's grounded state after a tick (walkable support) refills it; wall contact never does | P |
| Per wall | each wall **plane** once per flight: same plane = normals within 20° and plane offsets within 8 u, so two coplanar pieces (a seam) count as one wall | P |
| Cooldown | 0.25 s between wall jumps | P (R15) |
| Refusal order | no wall in reach, budget spent, same wall, cooldown | P |
| Impulse | outward speed set to max(current outward, 230 u/s), vertical to at least 290 u/s, **along-wall (tangent) speed kept** | P |
| Speed bound | horizontal speed after ≤ max(340, before + 80) u/s; the tangent shrinks only if needed to fit | P |
| Push guard | for 0.25 s (32 ticks) after a wall jump, a held wish pointing into that wall (`wish_dir · normal < 0`) gets **no** air acceleration that tick. A wish along or away from the wall plays the ordinary law. It only ever withholds acceleration, and is booked per tick as `wall_guard` | P |
| Ends | landing, R / respawn / practice, the move turned off, a new wall jump (new normal) | P |
| Slide | a wall jump disarms an armed landing slide | P |

Guard designs tried and rejected:

1. Removing only the into-wall part of the motor's acceleration. The AA 100 projection keeps
   seeing the kick, so the held key's whole budget goes into its other components and drains the
   along-wall speed.
2. Re-evaluating the law on the velocity without the kick. The tangent still eroded to zero,
   because A's backward component acts on a velocity constrained to the wall.

Limits of the guard: after 0.25 s a still-held key toward the wall plays the ordinary AA 100 law
and pulls the body back within a couple of ticks. With the view turned into the wall, A's
backward component also brakes along-wall speed once the guard ends, exactly as it does on R14/R15
without any wall jump (the "move off" control shows 370 → 59 u/s). Switching to the other side key
after the kick is the ordinary strafe. The mouse wheel hops but does not wall-jump (R15 policy,
unchanged). Speed bound per flight: two kicks of at most +80 u/s each, refilled only by landing.

## Slide, `r16-lab-slide-2` (Shift)

R15's grounded slide is unchanged: a fresh press on the ground with Space up, ≥ 180 u/s, friction
0.25, the real duck hull, end on release / 1.5 s / < 100 u/s / airborne / jump, 0.5 s cooldown.
Added, the **landing slide**:

| rule | value | tag |
|---|---|---|
| Arm | a fresh Shift press in the air, Shift held. Ctrl and C are never read | P |
| Buffer | the arm lasts until 0.40 s (51 ticks) after the later of the press and the apex; descending ticks are counted, so it is a press on the way down. It disarms on Shift release, a wall jump, the move turned off, or a ground tick with no landing | P |
| Entry | the motor's `land` event with the arm alive starts a slide on the next tick, at the landing's own horizontal speed (R15's 180 u/s floor and cooldown apply; refused landings play normally) | P |
| Late press | a fresh Shift press on the tick right after a landing also counts, with Space held | P |
| Entry tick | no jump at all on the slide's first tick; a fresh Space press there hops on the next tick | P |
| Held Space | a Space held into the landing never hops: it stays ignored until Space is released (also after the slide ends by Shift release, time or speed) or the body leaves the ground. A fresh press (or wheel) always hops out | P |
| Mechanism | for an ignored tick only: a per-tick settings copy with `sv_autobunnyhopping` false and `state.jump_prev` true, restored after the tick (a deferred duck geometry inside the tick wins over the restore, as R15's slide swap does) | P |

The hop out is a normal Source jump from the slide's speed. The slide's duck hull is held until
the next ground contact, as R15's slide does, so a slide never changes the hull in the air.

## API for root

- `movement_version() -> String` returns `r16-lab-moves-1` (constant `R16_LAB_VERSION`). Use it
  for record identity; no inherited constant is shadowed.
- `mechanics` (inherited getter) now carries the R16 tables: `slide` = R15 `SLIDE` merged with
  `R16_SLIDE` plus `lab_version`; `wall_jump` = reach/face test + `R16_WALL` plus `lab_version`;
  `grapple` = the exact R15 `GRAPPLE` table. Each entry's own `version` field is still the
  inherited `r15-lab-moves-1` (a GDScript subclass cannot redeclare the property); the laws inside
  the tuning tables and `movement_version()` are what identify R16.
- `get_motion_state().experiment`: `version` = `r16-lab-moves-1`, `base_version`; R15's fields
  plus `wall_jump.{budget, budget_max, used[{key, body, normal, offset_u}], buffer_ticks,
  guard_ticks, guard_normal, guard_u, last{tick, key, normal, offset_u, distance_u, buffered,
  v_before_u, v_after_u, tangent_before_u, tangent_after_u, into_before_u, out_after_u, cap_u,
  budget_left, actual_tangent_before_u}}` and `slide.{kind (ground|landing), armed, arm_tick,
  arm_descent_ticks, disarm, landing_pending, held_space_ignored, hop_deferred,
  last_landing{tick, late, entry_ups, space_held, fresh_space, refusal, arm_tick}}`.
  `impulses_u` / `impulse_totals_u` add `wall_guard`. Events: `wall_jump`, `wall_jump_buffered`,
  `wall_refused`, `wall_buffer_expired`, `wall_guard`, `wall_refill`, `slide`, `slide_landing`,
  `slide_armed`, `slide_disarmed`, `slide_refused`, `slide_end`, `hop_deferred`,
  `hop_out_deferred`, `hop_held_ignored`, plus the grapple's. `counts` add `slide_landing`,
  `slide_armed`, `slide_disarmed`, `wall_guard_ticks`, `hop_held_ignored`.
- `experiment_hud()` replaces the wall line (`N/2 left`) and shows `ARMED` / `LANDING SLIDE`.
- Suggested sign and keys text for root: "Space at a wall: kick off, 2 per landing, each wall once
  (A/D can stay held)". "Shift in the air before landing: slide on landing; release and press
  Space to hop out". Ctrl/C crouch is unchanged.

## Tests

`godot --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/test_r16_lab.gd -- --out=DIR [--only=GROUPS]`

The host is labelled: the real `r15_main.gd` on the real lab map with `source_runner` set to the
R16 script (R15's own runner override). `standin=true` in its log line is that override, not a
different motor. Root replays later through the actual R16 main. Every episode starts from one
labelled setup (fresh game, R, `practise_stage`, and where named, `r16_fixture_*` static bodies
added to the lab hall) and is then played only with key, OS-echo, wheel and relative-mouse events.
R15/R16 comparisons replay the exact recorded event list. Episodes go to `DIR/episodes/*.json`
(per tick: position, velocity, displacement, contacts, motor and lab events, impulses, held keys).

Groups: identity, parity, wall_ad, wall_rules, slide_chain, slide_world, combos, grapple.
Result on the scratch copy of this worktree (Godot 4.7.2, 128 Hz): **167 checks, 0 failed, 27 s**.
Mutation controls (scratch only): guard off → 6 wall_ad failures; held-Space ignore off → 15
slide failures; walls keyed by body → 3 wall_rules failures.

### Measured

A/D drift into a wall. From the spawn standstill a circle strafe builds speed, exits heading −z,
then A (or D) with the mouse turning 4 counts a tick drifts into a fixture wall 3 m to the side
(≈ 21° into it). Space is released and pressed with the key still held. A and D are exact mirrors.

| same events, from the press | speed at wall | peak off wall, 0.25 s | outward travel, 0.25 s | along-wall at +0.25 s |
|---|---|---|---|---|
| R15, A held (the defect) | 398 u/s | 0.10 m | −0.06 m | 65 u/s |
| R15, W instead (the old working case) | 398 | 1.26 m | 1.20 m | 310 |
| R16, A held | 398 | 1.56 m | 1.50 m | 350 |
| R16, W instead | 398 | 1.57 m | 1.51 m | 370 |
| R16, wall jump off | 398 | 0.03 m | −0.06 m | 59 |

R16 kick: tangent 370 → 370 u/s, outward −146 → 230, horizontal 398 → 436 (cap 478), rise
1.33 m in 0.5 s (0.16 m without the kick).

- Wall chamber station, played without W in the air (A held through the first press, D after
  6 ticks, D held at the east press): R16 two wall jumps, ends on the mezzanine (y 3.2 m). R15
  same events: one wall jump, ends on the chamber floor. A third press at the mezzanine face is
  refused `budget spent`; contacts in the air never refill; the landing refills to 2.
- Seam: kick off fixture piece 1, a hard A strafe back to coplanar piece 2 in the same flight:
  R16 refuses `same wall` (probe `r16_fixture_seam_2:8:0`, used `r16_fixture_seam_1:8:0`, which
  R15's body-keyed rule would allow).
- Spam: 1 wall jump, 29 refusals (1 `same wall` while still in reach, then out of reach). Floor
  press = ordinary jump. Held Space plus OS echoes in the air: no wall jump. Open air: refused,
  buffer expires. Buffered press fired 4 ticks after the press. R and key 2 mid-guard clear it.
- Bhop → landing slide → hop, from the spawn standstill (circle strafe, exit, one straight hop,
  Shift at 0.45 m on the descent): land at 392.5 u/s; slide from the next tick, first tick's
  actual travel 391.8 u/s, ducked and grounded for 41 ticks, 362.3 u/s at the fresh press; hop
  takeoff 362.3; hopping continues. Same for a manual entry (Space up on the descent). R15 same
  events: Shift refused `airborne`, held Space hops on the landing's next tick at 392.5 u/s; the
  manual variant never slides.
- Slide lane (roof): a landing slide at 250 u/s with Space held passes under the 60 u rack ducked
  (97 ticks under, no hop), 180 u/s at the run-out, the fresh press hops the trench onto the deck
  (z −32.9). R15 same events: no slide, hops in place at the rack face (z −21.6). Shift released
  under the rack: stand blocked, waits, never embedded.
- Arm buffer on the mezzanine-to-pit drop: armed at the apex, 118 ticks before landing → expires.
  Armed 25 ticks before landing → slide on the pit floor.
- Edge, false floor, stale arm, reset, toggle: slide ends `airborne` off the run-out with no air
  hull change, and held Space hops again in the trench. Armed onto a 60° fixture face: no landing
  and no slide on it. An arm released before landing never carries over. R or key 1 clears arm,
  slide and the held-Space ignore.
- Ctrl crouch hops: every tick equal to the approved runner, no lab event.
- Grapple: three R15 station episodes (swing and coast to the bay, hold to the 3 s break, a short
  hold into the pit) recorded on R16 and replayed on R15: position, velocity, view, line state,
  anchor, release reason and impulses equal on every tick.
- Parity: R16 with ordinary input (strafe hops, crouch hop) equals the approved runner and the R15
  lab runner tick for tick. Moves off with air Space at a wall and air Shift: equal to the approved
  runner, no lab event. `input_enabled` false: no motion, no lab state change.

## Limits

- Headless only. Native private AMD/X11 OS-input and player-camera evidence was **deferred**: HOME
  was just above the 15 GiB floor. Root's later replay through the actual R16 host is still owed.
- The fixture walls and wedge are labelled test geometry added at runtime, not lab map changes.
- An unrelated base observation: on the 60° fixture face, holding W in the air climbs it
  (AA 100 clip, R14 law). The lab code does not touch it.
- Nothing here says how any of it feels; Mike decides.

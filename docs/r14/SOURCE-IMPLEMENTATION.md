# R14 Source motor: implementation

8 November 2026. An original reimplementation of the public Source / legacy CS:GO movement
rules for Spillway R14, in three new scripts. No engine, SDK or plugin code was copied; the
equations were written from the public behaviour and cvars named below and cross-checked
against the separate oracle in SOURCE-REFERENCE.md. Nothing here claims binary fidelity to
any CS:GO build, and nothing here claims the motor feels right: Mike decides that.

| File | Role |
| --- | --- |
| `scripts/r14_source_motion.gd` | pure math and the one shared tick order, in Source units, no collision |
| `scripts/r14_source_player.gd` | the playable runner: that tick on real Godot collision |
| `scripts/r14_source_lab.gd` | standalone lab: labelled fixture block, F1/F2 live switch, open-loop demos and planner |
| `tests/test_r14_source_motion.gd` | pure checks, optionally against the oracle's prediction JSON |
| `tests/test_r14_source_player.gd` | input-event proofs on real collision |
| `tests/r14_source_repair.gd` | collision repair gates on the independent review's fixture (see Collision repair) |
| `tests/r14_source_repair_probe.gd` | engine diagnostic: Godot motion casts that miss very large boxes |

No R13 motor, default main/scene, UI, reference oracle, practice or delivery file was edited.

## Units and constants

P: **1 u = 0.0254 m** (Hammer inch, as SOURCE-REFERENCE). The motion module works only in
u, u/s, u/s² and seconds on Godot axes (y up); the adapter multiplies by `U` at its
boundary. Gravity 800 u/s² = 20.32 m/s², impulse 301.993377 u/s = 7.6706 m/s, wishspeed
250 = 6.35 m/s, air cap 30 = 0.762 m/s, stopspeed 80 = 2.032 m/s, hull 32×32×72 u =
0.8128×0.8128×1.8288 m, step 18 u = 0.4572 m, eye 64 u = 1.6256 m.

Constants were researched independently before the reference landed (GOKZ mode wiki for
the vanilla cvars and the stamina observations; zer0k-z's public CS2 bhop write-up for the
tick-perfect jump check, 64/128 Hz servers and a 1.1× jump clamp) and then compared with
SOURCE-REFERENCE.md. They agree on every cvar value. They differ on one point: zer0k's CS2 text gives
the clamp as 286 (1.1×260, weapon independent), the reference reconstructs 275 (1.1×250).
**275 is used**, as a setting (`jump_clamp_factor` × `player_maxspeed`), labelled a
reconstruction.

| Key | Vanilla `csgo_vanilla` | Server `csgo_server` | Status |
| --- | ---: | ---: | --- |
| tickrate | 64 | 128 | P comparison policy: 64 is matchmaking's native rate, 128 is what community/KZ servers ran (GOKZ requirement); R13 stays 120 |
| sv_accelerate / sv_friction / sv_stopspeed | 5.5 / 5.2 / 80 | same | reference cvars |
| sv_airaccelerate | 12 | 100 | reference / R14 server choice |
| sv_air_max_wishspeed | 30 | 30 | reference |
| sv_gravity / sv_jump_impulse | 800 / 301.993377 | same | reference |
| sv_maxspeed / sv_maxvelocity | 320 / 3500 per axis | same | reference; neither is a run-speed cap |
| player_maxspeed | 250 | 250 | P knife-like wishspeed |
| sv_enablebunnyhopping | 0 (275 takeoff clamp) | 1 | clamp is a reconstruction |
| sv_autobunnyhopping | 0 (press edge needed) | 1 (held jump reissues) | reference |
| stamina max / jump / land / recovery | 80 / 0.08 / 0.05 / 60 | 0 / 0 / 0 / 0 | cvars from reference; the equation is a fit, below |
| air_budget | legacy (uncapped 250 budget) | legacy | settled by reference; `capped` is a diagnostic |
| air_surface | deadstrafe (0.25 while 0 < vy ≤ 140) | deadstrafe | public Source2013 categorisation; `constant` is a labelled simplification |
| jump_order | source2013 | source2013 | standing order, sampled apex `J − g h/2`; not verified for CS:GO; `ideal` available |
| ground_speed_clamp | on | off | vanilla-only reconstruction: walking clamps to 250 × stamina factor²; server uses public friction without an auxiliary cap |
| sv_stepsize / walkable normal / ground probe / non-jump velocity | 18 / 0.7 / 2 u / 140 | same | public Source values |

`wheel_jump` (scroll notches count as jump edges) is opt-in and off by default. Only the lab
turns it on. It is not added to the InputMap, because root owns the bindings.

## The tick (`r14_source_motion.step`)

One function, used unchanged by the flat-plane check world and by the collision adapter:

1. Stamina recovers, then a landing's pending cost is added (P order, explained under Stamina).
2. Wish from key axes: forwardmove/sidemove at cl speeds 450, limited to `player_maxspeed`
   (and `sv_maxspeed`), ×0.34 ducked, ×0.8 in water.
3. Half gravity step.
4. Jump check, before friction or walking: needs ground and either autohop or no jump in the
   previous command. A press in the air is not remembered. With bhop disabled, horizontal
   speed is clamped at takeoff. Impulse × stamina factor is added on top of the half step,
   and another half step follows (Source2013 standing order). A jump on the first ground tick
   is counted as a first-tick ("perfect") hop.
5. Grounded: vy = 0, friction (stopspeed control), projection accelerate, then the optional vanilla-only reconstructed ground clamp.
   Airborne (including the jump tick): air projection accelerate with surface friction.
6. Per-axis `sv_maxvelocity`, then the world moves (walk or air). The world may append its own
   event (`step`) to the tick's fresh event list; nothing from an earlier tick survives.
7. Categorize: above 140 u/s upward the probe is skipped. Otherwise a walkable face within
   2 u below is ground, and **the body is not snapped to it**, so a hop can leave from up to
   2 u above the floor. A landing records the fall speed the tick began with and queues the
   land cost. Air surface friction for the next tick is chosen here.
8. Airborne: second half gravity step, then per-axis `sv_maxvelocity` again, as public
   FinishGravity checks velocity. Grounded: vy = 0.

No input in the air changes nothing horizontally. Turning the view alone changes nothing.
W in the air is the same projection law as A/D; there is no turn assist, overspeed tax or hop gain.

Root integration found the first server prototype also inherited the reconstructed ground
clamp. At 750 u/s, releasing input on the ground reduced it to 250 in one tick instead of
Source friction's 719.53125 at 128 Hz. The server preset now disables that extra clamp.
The shared tick is checked above run speed at both rates, alongside 80 independently
frozen air vectors and 30 released-friction cases. This correction does not resolve the
vanilla stamina equation; that fit remains an explicit fidelity gap.

## Stamina (vanilla), a labelled reconstruction

The reference leaves the exact vanilla equation unresolved, and so does this motor. The
model is a **fit**: penalty `S` in [0, 80], `f = 1 − S/100`. The jump impulse scales with `f`.
The walking clamp scales with `f²`. Jumping adds 0.08 × impulse, landing queues 0.05 ×
fall speed, and recovery is 60/s. One fall speed fits both of the GOKZ authors' published
observations exactly (250 → 183.05 u/s at land cost 0.05, 250 → 221.97 at 0.02). The same fit
gives the reported jump 55 → about 40 u. Measured with this motor at 64 Hz: first walking
tick after a standing jump lands 183.72 u/s, next apex 42.23 u, fall speed 285.5 u/s.
Applying the land cost after the next tick's recovery keeps the 0.05/0.02 ratio the
observations imply. Air acceleration is not scaled by stamina (GOKZ notes an effect only at
raised costs). `stamina_model: "off"` disables it. A switch into a profile without stamina
clears any penalty.

## Collision adapter (`r14_source_player.gd`)

It extends `spillway_player.gd` only for its camera node, signals and fields. Its `_physics_process`, `_unhandled_input`, eye and
hull are replaced. No R12/R13 ground law, air law, mantle, slide, surf or camera assist runs.

- **Hull:** an axis-aligned `BoxShape3D` 32×72×32 u that never rotates with the view.
- **Moves:** `move_and_collide`, not `move_and_slide`, following the public Source2013
  TryPlayerMove rules (original work, no copied code). Up to four bumps. Positive swept travel
  makes the current velocity the working original and clears the plane set, so each contact
  clips the momentum the previous one left. An airborne first plane clips the working
  velocity (overbounce 1, sv_bounce 0) and replaces it; otherwise the first plane whose clip
  satisfies every other touched plane wins, then a two-plane crease, else a stop. A result
  against the tick's velocity before any contact stops dead, and a move that never advances
  stops. The pure plane rule is `MOTION.clip_to_planes`. Godot specifics: the swept fraction
  is `1 − |remainder| / |motion|` (`get_travel()` includes depenetration); one cast may report
  several faces; and a face the hull already sits inside the margin of, heading into it,
  counts as touched even when the short sweep ends before its raw surface.
- **Standoff:** after a blocked sweep, after the stay-on-ground snap and when the probe finds
  a walkable face closer than 0.95 margin, the hull steps one margin (0.001 m = 0.039 u) back
  off the face, as a Source trace stops 1/32 u short of its plane. Without it Godot 4.7.2
  depenetrates the hull on the next move (40 % of the excess, four times) and its
  `move_and_collide` always cancels sliding, projecting that push onto the motion. That
  produced the review's unreported takeoff overtravel (1.0059 × requested at 128 Hz) and,
  with the 8-step cast bisection, the corner and floor jitter. The move is swept, so it cannot
  enter other geometry. Resting height is now 0.044–0.047 u.
- **Walk:** plain slide. If it touched something, the same slide is retried from 18 u up
  and dropped back down. As in public StepMove, the up path is kept when it lands on walkable
  ground and the plain slide went no further in 2D; it counts as a step (event and counter)
  only when it ends higher. Then stay-on-ground: up 2 u, down 20 u, then a 0.5 u second cast
  from there (the first cast's bisection can stop about 0.1 u short), then the standoff.
- **Probe:** a test move 2 u down. Faces with normal y ≥ 0.7 are ground; the most upward wins.
- **Report:** `get_motion_state()` also holds `depenetration` and `standoff` (m), the parts of
  `displacement` that are not swept motion, and each contact's swept `fraction` and whether
  it was `blocking`.
- **Input:** keyboard axes are raw action strengths, so A+D cancels as in CS. A jump press
  released before the next tick still reaches that tick's command. Mouse look uses
  `screen_relative` counts × sensitivity × m_yaw degrees. Default sensitivity 5.729578 equals
  R13's 0.0022 rad/count (P). Pitch is limited to ±89°.
- **Camera:** eye 64 u over interpolated feet, constant 4:3-referenced FOV (90 → 73.74°
  vertical with `KEEP_HEIGHT`), no bob, no landing dip, no speed FOV, no bank.
- **Rate:** `apply_engine_rate()` sets `Engine.physics_ticks_per_second` from the profile.
  The state reports `physics_hz`, the actual `delta` and `rate_matches`.

Public API (INTERFACES.md): `reset_to(Transform3D)`, `view_yaw`, `view_pitch`, `velocity`
(m/s, authoritative between ticks), `settings`, `tape_step_count`, `is_grounded()`,
`get_motion_state()`. Additions: `apply_preset(name, overrides)` and `apply_settings(dict)`,
which keep pose, velocity and view; `apply_engine_rate()`; `get_speed()`, horizontal travel
in m/s as R13 means it; `state` (u units); `last_hop` and `flight`. R13 consumers also find
`yaw`, `pitch`, `mode`, `in_water`, `input_enabled`, `floor_max_angle`, `jump_count`,
`land_count`, and the `footstep`, `landed` and `move_started` signals.

`get_motion_state()` holds the actual displacement and travel velocity, the requested and
post-contact velocity, the contacts with body, phase and normal, the step-up and snap
counts, the support normal, events (`jump`, `perfect`, `land`, `step`), stamina, air
surface, wish, a per-tick air gain, the side input, yaw delta, a per-tick sync verdict, the
flight in progress, `last_hop` (takeoff, landing before penalty, gain, air ticks including
the landing tick, eligible ticks, A/D sync or null, chained gain) and the full cvars.
Sync follows SOURCE-REFERENCE's recommendation, which is not shavit's angle branches. An
eligible tick is airborne, with exactly one of A/D, a nonzero view turn and horizontal
speed. It counts as good when the view turns toward the key.

## Results

Commands, from `projects/foldrunner` with the pinned Godot 4.7.2 (headless, Dummy audio):

```sh
G=~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --script res://tests/test_r14_source_motion.gd -- --out=DIR \
  --oracle=…/checkpoints/spillway/r14/source-reference/oracle-predictions.json
$G --headless --fixed-fps 128 --path . --script res://tests/test_r14_source_player.gd -- --out=DIR
$G --fixed-fps 128 --path . --script res://scripts/r14_source_lab.gd -- --preset=csgo_server --demo=planned_5
```

These are the first implementation's runs; current counts are under Collision repair.

**Pure: 63/63.** These checks match the oracle:

- all eight air rows (best tick by a 36,001-angle sweep, and 16-tick arcs)
- ground run-up of 35/72 ticks, and release at 229.6875 / 239.84375 and after 32 ticks
- sampled apex and crossing tick for both jump orders at both rates
- with the 2 u probe disabled, the oracle's hop-5 maxima exactly: 703.2069 (AA100/128),
  527.7310 (AA12/64), 688.3517 (AA12/128) and 508.3776 (AA12/64 deadstrafe)

Tolerance is 2e-6 relative, because vectors are single precision.

**Real collision, input events only: 61/61.** Highlights (u/s):

- *Standing-start chain, server, ideal open-loop strafes:* landings 384.70, 484.14, 566.37,
  637.39, 701.89. The flat prediction is the same to 3e-4. The **measured air updates per
  hop are 95, 96, 96, 95, 96, not the oracle's conditional 96.** The 2 u probe catches some
  landings a tick early, and the next hop then leaves from up to 1.5 u above the floor
  (apexes 55.86–57.34 u). That moves hop 5 from 703.21 to 701.89.
- *Synced vs mismatched curves (same keys), best landing:*
  - server: synced 566.4, half turn 496.5, double 451.3, opposite 543.9, mouse 8 ticks late
    519.2, keys without mouse 251.8
  - vanilla: synced 329.8, half 314.7, double 218.4, opposite 250.9, late 235.5, no mouse 251.8
  - synced A/D sync is 97.6–99.0%, opposite 1–2.5%. The planner's switch tick counts as bad.
  - the opposite-turn server run still gains: at AA100 the wish projection room refills
    every tick.
- *Release:* all keys released mid-air with the view still turning gives 0.000000 u/s drift
  (server 283.72 over 74 ticks, vanilla 279.49 over 26). W plus turning mints nothing.
- *Ground:* reaches 250 at tick 35 (64 Hz) and 72 (128 Hz), and the real curve stays within
  0.0005 u/s of the pure module.
- *Jump order:*
  - vanilla held space jumps once. Server held space autohops, every rejump on the tick
    straight after its landing.
  - vanilla pressed on each predicted first ground tick gives 4/4 first-tick hops. Landings
    sit at about 329 because the clamp returns each takeoff to 275; apexes 54.68 then about 41.5.
  - one tick late gives 0 first-tick hops and walks at the clamp (about 259–267).
  - scroll every other tick gives 1 first-tick hop, where the flat prediction gives 2. The
    one-tick difference comes from the 0.014 u resting margin.
- *Slopes:*
  - 20/30/45° are walked at 250 u/s horizontal. The 18 u step path wins on every ramp tick
    (263 step-ups), as Source's step move would.
  - 50° is never support, and a drop onto it slides off.
  - **Held W against the 50° face climbs it to 86 u by air alone**, because the projection
    refill plus the clip outpaces gravity at AA100/128. That follows from the rules as
    implemented; it is not checked against CS.
- *Corners:* an inner corner stops at the wall limits with no penetration beyond 0.005 u.
  A 30° airborne glance keeps its 200 u/s tangent and loses the normal part.
- *Seams:* 16 coplanar bodies cost no speed when walked or autohopped, and touched no edge
  normals.
- *Lips:* 8/16/18 u step up, 19/24 u block.
- *Gap:* a 160 u gap is cleared at 250 u/s. In free flight, travel equals the requested
  velocity × dt to within 9e-5 u.
- *Cadence:* exactly one motor step per physics tick, `delta = 1/128` and the rate matches.
  A mid-flight API switch keeps pose, velocity and view, and clears stamina.

Evidence (outside Git):
`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/source-motor/`
holds summaries, logs, compressed per-episode traces, movies, selected frames and hashes.

## Collision repair (independent review P1–P3)

8 November, after `SOURCE-REVIEW.md`. Commands as above, plus:

```sh
$G --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/r14_source_repair.gd -- --out=DIR
$G --headless --audio-driver Dummy --path . --script res://tests/r14_source_repair_probe.gd -- --out=DIR
```

| Suite | Before (HEAD `cb4016f9`) | After |
| --- | --- | --- |
| pure `test_r14_source_motion` | 177/177 | 177/177 |
| real collision `test_r14_source_player` | 63/63 | 63/63 |
| independent `r14_source_review` (unchanged) | 559, 42 fail | 559, 10 fail |
| repair gates `r14_source_repair` | 149, 67 fail | 135/135 |

The 10 review failures left are its earned slope variants whose approach never reaches two
planes in one tick: unsuccessful reproductions, not game defects. The repair suite's check
count differs because its earned-descent checks exist only for trials that reach two planes.

- **P1:** the review's seeds now keep 301.7943 (128 Hz) and 303.3331 (64 Hz) u/s at 250, and
  2305.1025 / 2306.6411 at 2000, equal to the independent chronological projections (were
  250 and 2000). The next released ground tick's friction and finite-difference travel follow
  the stored velocity. Twice per rate, identical. Input-earned: pose-only descents (zero
  velocity, one D tick) onto the ramp base reach ramp-then-floor in one tick in 22 of 72
  variants after the repair (29 of 72 before); every one matches within 3e-5 u/s, and the
  next tick travels it. Before, all 29 kept only the floor clip (for example z 0 instead of 198.5).
- **P2:** stored velocity stays within 3500 per axis after the final half gravity; terminal
  travel is −3500 u/s. Before: −3503.125 (128 Hz) and −3506.25 (64 Hz).
- **P3:** the 18 u step reports `step` on the tick it rises 18 u, once; jump/land/step events
  equal their counters over autohop chains, with no duplicates or stale events.
- **Rest and takeoff:** corner rest ticks 350–399 (review fixture) span 0/0.003/0 u and 0 u/s
  horizontal, from 0.047/0.070/0.072 u and 9.70 u/s. The review's strict free-travel gate
  error fell from 0.74–1.48 u/s to at most 0.010 u/s (float32 position resolution); takeoff
  rows travel exactly the requested velocity. Floor and wall rest are still to 0.003 u.
- **Unchanged:** all 80 frozen live air vectors, released overspeed friction, autohop timing,
  the 18 u pass / 19 u block, wall and corner recoveries, seams, 20/30/45° walks at 250 u/s.
  The 50° W climb peaks at 113.94 u (AA100/128) before and after; no steep-face rule was added.
- **Native:** a private Xvfb run of the repair fixture's visual mode, before and after side by
  side at quarter speed, with selected frames. Its HUD shows the contact tick: 2000.2 → 2305.3
  and 251.8 → 303.3 stored u/s. The practice yard's closed-loop basic route ends the same way
  before and after (10 of 24 nodes, 9 jumps, stage 1 pit), so that stop predates this repair.

Evidence: `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/source-repair/`.

**Engine finding, not repaired.** Godot 4.7.2 motion casts can miss a very large box: the
review fixture's 20000 u floor let a 64 Hz landing sweep end 1.64 u inside it with no contact
(before the repair in 2 of 212 review episodes, after in 3, by position luck). The probe
misses 252/441 diagonal sweeps into a 20000 u box, 125 at 8000 u, 9 at 6000 u and none at
5000 u, and the box's orientation matters (12000×4000 misses, 4000×12000 does not). The
repair fixture therefore splits its floor. Course geometry with single boxes over about
5000 u (127 m) should be checked with the probe.

## Failed trials

- The first lab run called `reset_to` from `_initialize` before the root was live.
  Setup is now deferred.
- Godot's `open_compressed` writes its own container, not gzip. Traces are now
  `PackedByteArray.compress(GZIP)`.
- Fall speed was first read after contact clipping, so landings that crossed the plane
  recorded 0 and skipped the land cost. It is now taken from the velocity the tick began with.
- The corner velocity creep described above. Fixed by counting recovery contacts.
- My first harness bugs: the settle-tick spawn landing was read as a hop, the gap planner
  never fired its jump, and several episodes were too short for their feature. The fixture
  gap was changed from 192 to 160 u so a 250 u/s running jump clears it.
- An initial vanilla gate expected rising landing speeds. That is wrong under the takeoff
  clamp, and the gate is now a positive air gain per hop.
- Repair: chronological clipping alone fixed P1 but kept a 0.0154 u takeoff overtravel with
  an empty contact list, traced to Godot's cancel-sliding projection of depenetration. The
  first standoff overshot to two margins because the same face's depenetration was folded in;
  it is now trimmed to one. A probe standoff on a coarse 2 u cast fired every grounded tick
  and broke the apex and inner-corner gates; it now re-measures closely. The standoff then
  biased the step choice's height test and cost 62.5 u/s at ramp bases and crests; the choice
  now uses public StepMove's 2D rule. The repair suite's first floor exposed the large-box
  cast miss above.

## Limitations

- Duck changes only the wish speed. There is no duck hull (54 u is indexed documentation
  only), no in-air duck lift and no crouch jump. Blocks taller than about 55.8 u are
  unreachable.
- Contacts use Godot's default physics. The hull rests one 0.001 m margin (0.039 u) off faces,
  0.044–0.047 u above a floor, where Source rests 1/32 u off; this can move a landing by one
  tick against the flat model. Godot still depenetrates within a tick when a sweep ends
  inside a margin without touching; that travel is reported as `depenetration`.
- Godot 4.7.2 motion casts can miss very large boxes (Collision repair).
- Step move and stay-on-ground are reimplementations with Godot casts, not Source traces.
- There are no ladders, water, base velocity or moving platforms.
- Jump order, stamina, the takeoff clamp and the ground clamp are labelled reconstructions.
  The exact vanilla N-hop maximum stays unresolved.
- The mouse is `screen_relative` pixels, not raw counts. No native Windows run, real-mouse
  timing, human trial or enjoyment is claimed.

For root: `bind_inputs()` has no wheel binding. Call `apply_engine_rate()` after a profile
switch. The record key should include `jump_order`, `air_surface`, `stamina_model` and
`ground_speed_clamp` along with the cvars.

# R15 crouch: a real duck hull on the approved bhop runner

8 November 2026. Crouch worker deliverable, integrated by root after a fresh-copy fixture rerun. Evidence lives in the
outer `checkpoints/spillway/r15/crouch/` (7.1 MiB).

## Result

`scripts/r15_source_player.gd` extends the repaired `r14_source_player.gd` with a real duck hull.
No R14 file changed and no extension point was needed. With crouch never pressed, it is
bit-identical to R14: 22 fixture episodes and the retained Overflow F2 course tape (6279 ticks)
match tick for tick in position, velocity and yaw.

- **Fixture suite:** `tests/test_r15_crouch.gd` passes 95/95 on real Godot collision, driven only
  by input events.
- **Native OS input:** `tests/r15_crouch_os_input.py` passes 19/19 on the private AMD display.
  XTest key and mouse input took the runner over three crouch-only obstacles, with moving
  native video.

## Rules and where they come from

Sources were read on 8 November 2026:

- Valve's public Source SDK 2013 `gamemovement.cpp` (`Duck`, `FinishDuck`, `CanUnduck`,
  `FinishUnDuck`, `HandleDuckingSpeedCrop`), sha256 `d192edad…5b20`, with `shareddefs.h` and
  `gamerules.cpp`.
- Valve Developer Community, *Counter-Strike: Global Offensive Mapper's Reference*, edited
  13 March 2026. It was read in a browser, which passed the Anubis gate that blocked R14's
  research.

In the tags below, **S** means public Source 2013 code, **V** means Valve's measured CS:GO
table, and **P** means a game choice. Every new value is a setting in the runner's `settings`,
so it enters `r14_presets.physics_fingerprint`.

| rule | value | tag |
|---|---|---|
| Crouched hull | 32×32×54 u (`duck_hull_height`); standing stays 32×32×72 | V |
| Crouched eye | 46 u (`duck_eye_height`). V measures 46.076, rounded the way R14 rounds 64.094 to 64 | V/P |
| Order | The duck step runs before the motor each tick, after the input read | S |
| Ground press | The hull shrinks at once and the feet stay put. S keeps a 0.4 s transition; there is none here | P |
| Air press | The hull shrinks at once. The feet rise by the air anchor's lift | S (instant in air) / P (anchor) |
| Air anchor | `duck_air_anchor` "center": feet +9 u, head −9 u. "head" is S `FinishDuck` (+18 u). "feet" is 0 | P, fitted to V |
| Release | Stand only if the standing box at the target feet overlaps nothing (static `test_move`, 0.0001 m margin). On the ground the feet stay. In air they drop by the same lift | S (`CanUnduck`) |
| Blocked release | Keep the duck hull and retry every tick while crouch is up. One `stand_blocked` event per refusal | S ("still under something") |
| Duck crop | R14's ×0.34 wish crop applies only to a tick that starts grounded (`duck_air_crop` false). R14 crops in flight too | S |
| Eye | Eases at 18 u per 0.1 s (`duck_eye_time`). It is held 2 u under the hull top (`duck_eye_clearance`) only while the standing hull at the feet is blocked | P |
| Duck spam | No penalty. A duck/stand pair in flight cancels exactly | S has none / P |

**Why the centred anchor.** Valve's table gives these heights at 128 tick:

| technique | highest block | lowest ceiling not bumped |
|---|---|---|
| Standing jump | 55 u | 128 u |
| Jump then crouch | 64 u | 119 u |
| Jump while already crouched | 57 u | not used here |

The centred anchor reproduces both 9 u shifts: the feet go 9 u higher and the head 9 u lower.
S's head anchor would give +18 u, a much bigger boost than the CS:GO movement Mike liked.

No anchor touches velocity. The suite shows velocity identical to the no-crouch twin on every
tick.

**Not reproduced.** Valve's "crouch then jump" 66 u comes from jumping mid-transition. This
runner has no ground transition, so jumping while crouched reaches about 56 u, as V's "jump
while crouching" 56/57 u does.

## Lift is not travel

The lift moves the body origin; it is not physical travel.

- The lift is kept out of `displacement`, `actual_velocity`, speed, footsteps and the camera's
  interpolation.
- The previous pose and the eye offset are shifted with it, so the camera does not jump.
- `get_motion_state()` adds these fields:
  - `hull` {width_u, height_u, ducked, feet_u, top_u}
  - `duck` {held, ducked, request, stand_blocked, blocked_ticks, stand_probe, anchor, air_lift_u,
    shift_u, compensation_u, eye_u, eye_target_u, eye_clamped, counts, events}
  - `duck_shift`, and `origin_delta` (travel plus lift)
  - `motor` = `r15_source_crouch`, `motor_version` = `r15-source-crouch-1`
- New events in `events`: `duck`, `duck_air`, `unduck`, `unduck_air`, `stand_blocked`.

On the native ledge run, the duck tick booked 2.02 u of physical travel (vy/128) and a separate
9.0 u shift.

## Evidence

### Fixture suite

`suite/summary.json`, `run.log` and 78 gzip episode traces. Command:

`godot --headless --fixed-fps 128 --path . --script res://tests/test_r15_crouch.gd -- --out=DIR`

The R15 runner and an unchanged R14 twin share one world. They are layer 2, mask 1, so they never
touch each other, and both read the same events. Press ticks come from the pure module's
flat-plane prediction made before each episode.

- **No-crouch parity:** exact (0.0 m, 0.0 u/s, identical events) on these episodes:
  - server128 and AA1000 strafes, and keys-only strafes
  - idle; held jump in place
  - lips 8/16/18/19/24 u; slope lanes 20/30/45/50°
  - corner diagonal, seams hops (AA1000), gap jump
- **Fit:**
  - Standing stops at the 62 u tunnel mouth; ducked passes end to end with no roof contact.
  - Ceiling boundaries match V: standing clears 73 u but not 72 u; ducked clears 55 u but not 54 u.
- **Ground:**
  - Press and release land on their own tick with zero shift.
  - The eye eases 64→46 in 12 ticks and back, with no pop.
  - Crouch walking runs at 85.007 u/s.
  - Idle crouched, horizontal motion is exactly 0. Vertical motion is 5.7e-5 m, identical to the
    standing R14 twin (R14's resting standoff bob).
- **Air** (each anchor):
  - The lift is +9 / +18 / 0 u; the gap to the twin is exact within 4e-6 u (float32).
  - Velocity is identical to the twin, and travel is identical within 6e-8 m.
  - After standing, the body rejoins the twin's path.
- **Spam:**
  - Toggling every tick in flight (39 ducks, 39 stands) changes no velocity, gains no height, and
    peaks at the twin's peak + 9 u.
  - Toggling on the floor while idle or running adds no motion.
- **Landing:**
  - Holding crouch through a landing keeps the duck hull and mode `duck`; speed then slows to 85.
  - Crouch-hop chains (7 jumps, 6 first-tick) match the standing chain exactly in the plane.
  - Strafed crouch hops gain speed exactly as standing ones do. At AA 100 the crop on the jump
    tick is under the 30 u room, so it costs nothing.
- **Low ceilings:**
  - Releasing inside the tunnel is refused on the release tick and stays refused for 457 ticks.
    The body stands on the first tick whose start pose clears the back plane.
  - No standing tick ever overlaps geometry.
  - Idle under the roof, it stays ducked with zero horizontal drift.
- **Ledge** (60 u, roofed 62 u over its top):
  - A standing jump peaks at 55.87 u and fails; a ducked jump also fails.
  - Jump-then-crouch peaks at 64.87 u and lands.
  - A release under the roof is refused; the body stands past the roof at feet 60.045 u.
  - Peak vertical velocity equals the standing jump's.
- **Pit** (128 u, roof 100 u over both decks):
  - A standing jump bonks the roof and falls to the catch floor.
  - A crouch hop crosses.
  - A release over the pit is refused while the standing box would hit the roof, then stands in
    the air with its top at 98.7 u. The hull never rises above 100 u.
- **Steps under roofs:** ducked climbs 8, 16 and 18 u and stops at 19 and 24 u. Standing is
  stopped by the roof at 16 and 18 u.
- **Slopes:**
  - Ducked climbs the 20/30/45° ramps and stands mid-ramp with no refusal.
  - On the 50° face it matches the R14 twin's climb rate (see Findings).
- **Corner:** ducked rests in an inner corner at exactly the standoff and leaves it. Releasing
  while pressed into both walls stands at once.
- **Heights** (open blocks, takeoff 90 u out):
  - Standing reaches 50 u but not 56 u.
  - Jump-then-crouch reaches 56, 60 and 64 u (64 at peak 64.79), but not 66 u.
- **Rendered eye:** at an air duck the camera moves at most 1.41 u per frame beyond physical
  travel, against the 9 u lift. It settles at 46 u.

### Course tape parity

In `tape-parity/`. The retained R14 actual-main Overflow recording is
`r14/overflow-final-source/record-server2/events.tape.json` (sha256 `7427202b…5aff`).

It was replayed by `tools/momentum-tape.py` (headless, warmup 8, 128 Hz) through two game setups:

- `tests/r15_crouch_tape_game.gd`: R14 main with the R15 runner.
- The original setup `game.gd` (`0a5c7c0c…9008`): R14.

`tests/r15_crouch_tape_compare.py` compared both with the retained `replay-server2-normalized`
trace:

- Post-step position, velocity and yaw are equal on all 6279 ticks.
- Delivered inputs are equal once wall-clock fields are removed.
- All three finish clean at 45.9609375 s with 0 respawns and checkpoint 3.

The course key changes (`0d5897a4…` vs `2840913f…`) because the duck settings enter the
fingerprint, as intended.

### Native OS input

In `os-input-02/`: `run.json`, 3 MP4s, 8 JPEGs, compressed telemetry and shortened engine logs.
Godot 4.7.2 official, pinned binary sha256 `8d106cbe…f71e`. The private Weston/Xwayland display
came from `tools/r14_native_display.py` (AMD Radeon renoir, radeonsi).

All control was xdotool key events and `XTestFakeRelativeMotionEvent`, after a labelled setup
(lab launch at the station). The observer only reads the runner. The actor is
coordinate-aware: it waits on telemetry to time a press, as a player watching the screen would.

- **ledge** (eye view):
  - Jump, then crouch in flight: a +9 u lift.
  - Lands on 60 u; the release under the roof is refused.
  - XTest mouse turned the view 144 counts (yaw 0→0.13823→0.0 exactly).
  - Walked out; stood at the roof end.
- **low_gap** (chase view with the hull box): a crouch hop over the pit under the 100 u roof,
  landing on the far deck. It never fell and never rose above the roof.
- **tunnel** (chase, then Tab to eye view):
  - Standing stopped at the mouth; crouched inside under 62 u.
  - The release was refused, then the body stood on leaving.
- Every episode exited 0 with the GPU watch passing. The display was released and scratch
  removed. HOME had 15.37 GiB free before the run.

## Failed trials and corrections

- **Eye cap:** the first design capped the eye under the hull top at all times. An instant ground
  hull would then drop the camera 12 u on every crouch. It was changed before the first run to
  cap only when the standing box at the feet is blocked.
- **First suite run:** 17 of 78 failed. All were harness errors:
  - `%g` is not a GDScript format.
  - Row indices were mistaken for motor ticks.
  - Several episodes ended before reaching their obstacle.
- **Wrong parity claims:** a later pass found four parity episodes that never reached their
  feature (lips, gap, corner, slopes). They were lengthened, and step, contact and jump counts
  are now reported per episode. Ceiling-boundary, wall-release and slope-stand groups were
  added then.
- **Native attempt 01:** the analyzer's "lift never booked as travel" check compared the duck
  tick's ordinary flight travel against 0. It was corrected to compare against vy/128;
  `--rejudge` passes attempt 01's kept telemetry. Attempt 02 is a fresh clean run with the
  fixed analyzer.

## Findings for root

1. **R14, not crouch.** The approved standing R14 body, holding W into the fixture's 50°
   "unwalkable" face, rises airborne at a steady 23.75 u/s indefinitely. Air acceleration
   re-adds 30 u/s along the wish each tick, and the plane clip turns it upward. This repeats for
   R14, R15 standing and R15 ducked. It matters for new maps with steep walls players run into.
   It is unchanged here because uncrouched behaviour is frozen.
2. **R14 law.** Crouched start from rest is slow: the 5.5×85 acceleration nets about 51 u/s²
   against stopspeed-80 friction, so reaching 85 u/s takes about 1.7 s. Entering crouch from
   a run decays to 85 quickly instead. This is the existing R14 crop and friction law.
3. **Integration.**
   - Root's presets build settings without the duck keys. `apply_settings` fills them, so the
     record key should be fingerprinted from the runner's `settings` after apply, or from
     `R15.with_duck(...)`.
   - R14 `FAMILIES.source.version` should not be reused for R15 records; use `MOTOR_VERSION`.
4. **Stray files.** Every Godot import regenerates `.uid` files for three R14 files that have
   none in Git:
   - `tests/r14_os_input_observer.gd.uid`
   - `tools/r14_discovery_delivered.gd.uid`
   - `tools/r14_discovery_readability.gd.uid`

   They were deleted after each import; root decides whether to commit them.

## Limits

- XTest on a private display is OS input, not physical-device latency or feel.
- These are source-checkout runs of uncommitted files, not a pack.
- AA1000 is covered by parity and lab switching, but the native obstacles ran on server128 only.
- The duck eye times, the instant ground hull and the centred anchor are game choices, untested
  with Mike. CS:GO's duck-speed spam limit and partial-duck transition are not modelled.
- No real course uses crouch yet. The Breakwater worker owns that.

## Files

- `scripts/r15_source_player.gd`: the runner.
- `scripts/r15_movement_lab.gd`: the lab.
  - **Command:** `godot --path . --script res://scripts/r15_movement_lab.gd -- --station=ledge|low_gap|tunnel|duck_steps|heights|clearances|runway|...`
  - **Keys:** F2 server, F5 AA 1000, R respawn, Tab eye/chase view with the hull box, F10 quit.
- Tests: `tests/test_r15_crouch.gd`, `tests/r15_crouch_tape_game.gd`,
  `tests/r15_crouch_tape_compare.py` and `tests/r15_crouch_os_input.py`, with generated
  `.uid` files.

## Root integration check

Root verified the returned file hashes, reran all 95 fixture gates in a fresh project/import/profile copy (zero engine errors or warnings), and inspected the airborne-duck and blocked-stand native frames. Receipt: outer `checkpoints/spillway/r15/crouch-integration/`. This accepts the source integration; independent adversarial review and final packed-game checks remain pending. The native runs above remain the worker's source-mode evidence.

Root subsequently replayed all three approved routes on the integrated runner at the original 128 Hz cadence, sensitivity and warmup. F2 Penstock advanced (28.609375 s), F2 Overflow (45.9609375 s) and F5 Overflow (45.9609375 s) finish clean with zero respawns. All 16,356 tape rows match the pinned approved input, position, velocity, yaw and complete game-state fields exactly. Actual engine logs, input delivery, motor order, rate, neutral end and cleanup pass. Receipt: `crouch-integration/routes/RESULTS.json`, with the reproducible supervisor alongside it. This remains the R15 motor in the retained R14 host, not acceptance of the new R15 host or maps.

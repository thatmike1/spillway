# Controller lab: R12 motor vs the FLOW hypothesis

7 November 2026. Lab work for the momentum brief. Nothing here is wired into the game: the
R12 player, main and level are untouched. All values below are P (game choices) under test,
not findings about any reference game.

Files:

- `scripts/momentum_flow_player.gd`: the FLOW motor. It extends `spillway_player.gd` and
  replaces only `_physics_process` control logic; collision classification, air contact
  clipping, mantle, crouch clearance, eye and FOV are inherited unchanged.
- `scripts/momentum_flow_lab.gd`: native launcher. The real main, course, HUD and audio with
  either motor. Records and settings are never written.
- `tests/momentum_flow_probe.gd`: R12 vs FLOW on labelled fixtures and one real-course line.

Traces and captures (outside Git): `checkpoints/spillway/r13/controller-lab/`. `run1` is the
first FLOW air design (rejected, see below), `run2` adds fixtures, `run3` records the original
policy, `native/` holds its frame captures. The adversarial review and subsequent corrections
are in controller-review-sol.md and controller-fixes.md. The old measurements below remain
attributed to their original snapshot rather than silently becoming current-build results.

## 1. What is confirmed

### Engine (Godot 4.7.2-stable source, `scene/3d/physics/character_body_3d.cpp`)

- Grounded mode removes the vertical component of `velocity` whenever the body ends a move
  on floor and was not moving up (`velocity = velocity.slide(up_direction)`, "Reset the
  gravity accumulation"). Climbing a ramp never shows up in `velocity`, and a landing
  discards the whole fall: none of it becomes speed along a downslope.
- Floor contacts slide the *motion*, not the velocity. Walls in grounded mode with
  `floor_block_on_wall` do change velocity (slid along the horizontal wall normal).
- Floor snap runs only when the body was on floor and its velocity does not point up. R12
  writes `velocity.y = -0.4` on every ground tick, so a 0.45 m snap is always armed.
- `real_velocity` is position delta / delta, so it is the honest travel measure.

### R12 policy (`scripts/spillway_player.gd`)

- Ground steering (line 230) is `move_toward` of the whole horizontal vector toward
  `wish * carried` at 28 m/s², braking at 34 m/s² when no key is held *or* the wish points
  more than 90° from the motion (line 229). A turn therefore travels the chord between the
  old and new velocity: speed sags mid-turn, and a strafe key at a landing can count as a brake.
- Above run speed, every ground tick costs 8 m/s² (line 226, `GROUND_OVERSPEED_DECAY`).
- Running on a slope adds nothing: speed is the run target whatever the gradient
  (`floor_constant_speed` and the -0.4 write). Only a crouch slide takes downslope gravity,
  clipped to 16 m/s unless more was carried in (line 216).
- Air (line 290) is the Source-style projection cap: speed is added along the wish only
  until the velocity's projection on it reaches 0.75 m/s. W points along the motion, so W
  plus mouse adds nothing until the view is ~85° off the velocity.
- A hop on the landing tick happens before any ground friction, so a held or buffered jump
  keeps all speed. A late press pays the ground policy above for every tick on the floor.

### Measured (original probe, `run3`, before adversarial corrections)

| fixture | R12 | FLOW |
|---|---|---|
| e1 flat: ms to 90% run / stop after release / reverse to 90% back | 267 / 233 / 517 | 267 / 283 / 442 |
| e2a 16° 50 m ramp, W only: speed at bottom | 8.5 | 14.4 |
| e2b same, crouch slide: speed at bottom | 15.7 | 21.7 |
| e2b then a 90° mouse turn in 0.3 s holding W: in → min | 14.1 → 8.5 | 21.2 → 19.1 |
| e2c fast slide then S: ms to stop / metres | 450 / 3.5 (from 15.5) | 542 / 5.9 (from 21.4) |
| e3a flat, W + jittered presses + mouse wiggle: mean speed | 8.49 | 9.0 |
| e3b off-beat A/D + 1.8 rad/s mouse hops: final speed / net metres in 8 s | 4.9 / 52.5 | 15.9 / 94.8 |
| e3c held space + W: mean speed | 8.5 | 9.0 |
| e3d slide down e2, then casual W hops on the flat: entry → final | 14.9 → 10.5 | 21.4 → 20.1 |
| e6a run, jump, W + mouse 60° left in the air: flight turned | **0.0°** | 60.0° |
| e6b same with A instead of W | 64.7° (+0.6 m/s) | 60.0° (+0.5 m/s) |
| e4a 20° kicker at run speed + jump: vy / airtime / speed after downslope landing | 7.2 / 875 ms / 8.5 | 9.8 / 1208 ms / 12.7 |
| e4b run off the kicker lip without jumping: vy at the lip | 0.0 | 2.1 |
| e5 real course, aim at the dry chute, slide, jump at the launch: speed at launch | 14.8 | 14.9 |

Other measured facts: on a 16° slope with `floor_constant_speed` on, horizontal travel is
0.961 of horizontal velocity (cos 16°), on the 20° kicker 0.939; R12's slide turns that flag
off and travels 1.00. No episode had stall ticks (velocity above 2 m/s while travel was
under half of it). On the real course both motors leave the chute at ~14.9 m/s and land on
the valve housing roof (y 5.6), not the terrace, with the same open-loop aim.

## 2. Hypotheses about the poor momentum feel (not measured on Mike)

Ranked by how directly the code and the probe support them:

1. **The ordinary air input does nothing.** W plus mouse in the air turns the flight 0°
   (e6a). A player who looks where they want to go and holds W gets no response until they
   land, then the ground policy yanks them across. This is the most likely single cause of
   "no control" and of momentum feeling like something that happens to you.
2. **Earned speed is taxed everywhere it touches the ground.** 8 m/s² overspeed decay plus
   chord steering: a fast 90° turn drops 14.1 → 8.5 (e2b), casual hops after a downhill lose
   a third in 8 s (e3d). Only a perfectly timed or held hop escapes it.
3. **Slopes and ramps carry no energy.** Running downhill gains nothing (e2a), a ramp's climb
   is erased so its lip throws nothing (e4b), and a landing never turns a fall into speed.
   Height on the dam is decoration to the motor except inside a crouch slide.
4. **Braking is implicit.** Releasing keys or pressing a strafe key past 90° brakes at
   34 m/s², so speed can vanish without the player asking for it, while there is no
   distinct intentional brake.

Uncertain: whether Mike's dislike is mostly this, or partly the course (surf banks, lines),
camera FOV kick, or audio. The probe cannot tell; only play can.

## 3. The FLOW hypothesis

One rule set: **speed and heading are separate. Input turns the heading at a grip-limited
rate; speed changes only through throttle, drag, gravity along the heading, an explicit
brake and a bounded air carve.** Velocity remains the single authoritative state, so walls
and contacts still change it directly.

Ground (P values in the file header):

- Run 9.0 m/s, reached at 30 m/s². Turning is lateral grip 60 m/s² (≤10 rad/s), so radius
  grows with speed and speed is kept through the turn.
- Above run: 1.6 m/s² while pushing, 6 m/s² coasting, 30 m/s² below run when coasting.
- Brake: a wish more than ~120° from the motion brakes at 38 m/s², then pivots.
- Gravity along the heading feeds speed: 0.55 of it running, all of it sliding. Soft cap
  20 m/s (0.6/s drag above), hard cap 30 inherited.
- Slide: crouch at ≥6 m/s (keeps down to 3), grip 18 m/s², drag 1.2 m/s², no speed clip.

Air:

- With any forward or strafe key, the heading follows the **view** at ≤3.2 rad/s (grip
  18 m/s²) without changing speed. No key keeps the line; S brakes at 5 m/s².
- Carve: a strafe key on the inside of a turn the view is also making adds 1.0 m/s per
  radian, up to 17 m/s. This is the skill channel; plain W keeps speed but never gains.

Contact transitions:

- A jump adds 0.8 of the surface's climb rate. Leaving an edge keeps the surface's vertical
  rate. The original automatic continuous-crest rule is retired: fixing its broken history
  exposed unwanted launches on small stair contacts. No hidden crest threshold remains.
- A downslope landing can keep plane-projected velocity, constrained against every active
  contact plane. This replaces the original floor-only restoration that could report speed
  into a blocking wall. See controller-fixes.md for the exact before/after repros.
- A 67 ms P turn budget now lets the heading consume a mouse update between deliveries.
  Equivalent sweeps earn equivalent carve at 30/60/120 event rates; a lone flick cannot bank
  a whole flight's reward. This fixes the original event-bearing-tick-only gain rule.

Rejected inside the lab: `run1` steered air toward the *key* wish. A held A then pulled the
line left, so the A→D swap of a strafe hop read as a reversal and braked (e3b ended at
4.7 m/s, net 28 m). The view-led rule replaced it. Also not tried: inflating speeds, a hop
timing bonus (it would reward a perfect bot more than a person), surf-specific code.

## 4. Running it

```sh
GODOT=$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
# playable, ordinary controls (WASD, mouse, space, ctrl, R restart, F practice)
$GODOT --path . --script res://scripts/momentum_flow_lab.gd -- --motor=flow
$GODOT --path . --script res://scripts/momentum_flow_lab.gd -- --motor=r12
# probe; exits 1 on a failed check
$GODOT --headless --fixed-fps 120 --path . --script res://tests/momentum_flow_probe.gd -- --out=DIR
```

The probe's checks test the probe's integrity (no stall ticks) and FLOW's own targets; they
say nothing about fun. Two runs of the same build give identical output (`run3`, `run4`).
Root reran the probe in `root-verification/`: 38/38 pass. Ground turn/brake and overspeed-hop
comparisons have different entry speeds because each motor first earns speed on the ramp;
they describe whole-policy outcomes, not matched-speed isolation of turning or braking.
The position-aware steps read exact world coordinates, not pixels. A separate equal-speed,
blind input comparison and adversarial contact review are still needed.

Root's lab presentation now identifies `spillway-r13-lab`, names the selected motor and
disables records. FLOW's visible instructions describe its own controls. Both modes use
the same default settings and ignore historical R12 records/settings. The original worker
movies predate this label correction; their motor comes from the filename and log.

Native frames: `--demo` on a private Xvfb with `--audio-driver Dummy --write-movie`, llvmpipe
software GL, in `native/` with 4x4 contact sheets. The first demo used a blind open-loop turn
and missed the chute into the channel corridor for both motors; it is kept in
`native/blind-turn-miss/`. The current demo aims by position like probe e5. Both motors
slide the chute (HUD 52-54 km/h at the bottom) and launch at ~14.8-15.0 m/s; R12 lands on the
valve roof and runs on, FLOW ends at the basin edge. Movie mode (60 fps, two 120 Hz steps a
frame) lands a few centimetres from the headless run, so native and probe numbers are not
interchangeable. What the frames do not show: how either motor feels.

## 5. Integration requirements

- Swap the preload in `spillway_main.gd` (or adopt the lab's `LabMain` pattern) and give the
  build a new identity and record namespace; FLOW times are not comparable with R12's.
- `spillway_driver.gd` / `spillway_surf_driver.gd` routes and the R12 surf/flow tests assume
  R12 air physics; they will need re-authoring or retirement with reasons.
- HUD and audio read `get_speed()`, `mode`, signals; FLOW keeps those names and adds
  `carve_gain_total`. The retired `launch_count` remains zero for old trace compatibility.
- The HUD's control hint ("Air: release W, hold A or D, turn mouse the same way") teaches
  R12's air. Under FLOW it is wrong: W and the mouse steer, a strafe key into the turn carves.
- The course should be authored around slopes that pay, kickers, and turns taken at speed.
  Today's 14° chute, gaps and surf banks were tuned for R12.

## 6. Remaining weaknesses

- Air steering at 3.2 rad/s may feel floaty or too forgiving; air control this strong lowers
  the ceiling. Carve gain is generous: an off-beat A/D gesture reached 15.9 m/s in 8 s.
- The automatic crest launch is removed. Continuous seams/steps and the real ramp-edge
  carry are separate checks; complete real-course contact behavior remains unverified.
- The FLOW slope term uses the horizontal projection of gravity while travel follows the
  slope; it is a tuning value, not physics.
- Falling into the e4 gap shows both motors catching on the landing slab's front edge; FLOW
  pushes on at 4 m/s, R12 at 0.75. Edge catches on the real course are untested.
- Course line e5 is one open-loop aim; it lands on the valve roof for both motors.
- No human play. Frames are software-rendered on Xvfb with dummy audio; no GPU, timing or
  fun claims.

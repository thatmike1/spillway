# CARRY motor, first implementation

Implementation of BUILD.md's CARRY comparison, 7 November 2026, on base 204470c7. All values
are P hypotheses. Nothing here claims fun, VHOLUME or CS fidelity. Godot 4.7.2 (ed1daf0bf),
120 Hz physics, headless and llvmpipe only. Evidence lives outside Git under
`checkpoints/spillway/r13/carry/` (`STATE.md` there is the resumable log).

| File | Role |
| --- | --- |
| `scripts/momentum_carry_player.gd` | the motor; extends `spillway_player.gd` and reuses its collision helpers |
| `scripts/momentum_carry_game.gd` | Node3D game factory over `spillway_main.gd`: `air_profile`, `motor`, `level_script`, `steady_camera`; records and settings never read or written |
| `scripts/momentum_carry_lab.gd` | SceneTree launcher, a neutral calibration block (`CalibrationBlock`, `CalibrationGame`) and three open-loop demo tapes |
| `tests/test_momentum_carry.gd` | 130 input-driven episodes: 88 gates, plus findings that are reported, not gated |

Default game wiring, the Overflow course, packaging and records remain root's. No existing
file or `project.godot` changed. During integration root added an internal `player_script`
factory hook for an isolated air-policy challenger; its default remains CARRY.

## Commands

From `projects/foldrunner`, with `G=$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`:

```sh
$G --path . --script res://scripts/momentum_carry_lab.gd -- --air=broad      # play the calibration block
$G --path . --script res://scripts/momentum_carry_lab.gd -- --air=narrow --course=spillway
#   options: --steady-camera (labelled comfort camera), --no-hud, --demo=line|strafe|miss, --trace=FILE
$G --headless --fixed-fps 120 --path . --script res://tests/test_momentum_carry.gd -- --out=DIR [--only=GROUPS]
python3 tools/momentum-tape.py run TAPE --out DIR --game-script res://scripts/momentum_carry_game.gd --motor broad
python3 tools/momentum-tape.py run TAPE --out DIR --game-script res://scripts/momentum_carry_lab.gd --game-class CalibrationGame --motor narrow
```

Groups: ground, hop, air, window, contact, slope, cap, cadence, duck, flicker, backend,
integration. The suite exits 1 on any gate failure. Native capture:
`checkpoints/spillway/r13/carry/native/capture.sh NAME LAB-ARGS` (private Xvfb `:155`,
Dummy audio, isolated XDG profile, movie writer at 30 fps, provenance file).

## Motor

**Air profiles**, set before the runner enters the tree: broad (allowance 8.5 m/s,
coefficient 0.468/s) and narrow (0.75 m/s, 12/s). Only the side-key component of the wish
feeds the projection rule. Side-only narrow equals R12's air calculation at 120 Hz; it is
a diagnostic control. Everything else is shared.

**Air, both profiles.** W bends travel toward the full movement wish (so W+A keeps its
sideways meaning) at up to 14 m/s² lateral, weighted by the forward input and faded from
full at 45° to none at 90°. The bend is speed-neutral. Below run speed, W may also bring a
flight up to 8.5 m/s at 6 m/s², never above. No keys keeps the ballistic line. S brakes
the part of travel it opposes at 5 m/s² and never reverses it.

**Ground.** Speed and heading are steered separately. Grip is 60 m/s² at run speed,
blending to 20 m/s² by 2 m/s above it. Below run speed, a push reaches 8.5 m/s at 28 m/s².
Above it, earned speed fades at 2 m/s² while pushing and 3 m/s² while coasting. With no
keys below run speed, the runner stops at 30 m/s². Input more than 120° from travel brakes
at 34 m/s² all the way to rest before the heading flips. Crouch is a plain duck (3.2 m/s,
12 m/s² down to it), never a slide.

**Slopes and edges.** Godot's `floor_constant_speed` moves a grounded body along a slope
at the requested horizontal length as its *surface* length. Measured: 0.96 of it is
horizontal on 16°. So ground speed is speed along the surface:

- Slope pull is gravity along the travelled line, `-g·c/√(1+c²)`, where `c` is the climb
  per metre of heading.
- Take-off (a hop or a real edge) converts to the surface velocity, so speed along the
  surface is kept and the horizontal part shrinks.
- A landing maps the collision-feasible tangent's full length to ground speed.

**Hops.** Each hop adds 7.2 m/s to the support's own vertical rate. There is no per-hop
reward and no crest pop. The 0.12 s buffer, 0.10 s coyote and held autohop are kept. A
landing after at least 50 ms of real air grants 80 ms of grace from overspeed drag. A
support flicker keeps the grace that was already running and never starts a new one.

**Contacts.** Contacts use R12's `move_and_slide` path, with feasible-cone clipping of
airborne contacts and corrected FLOW's complete-plane landing. No surf mode, mantle,
slide, owned sweep or step-up. R12's 30 m/s safety cap is kept, and every intervention is
counted and booked.

## Interface

`get_motion_state() -> Dictionary` returns:

- `tick`, `air_profile`, `mode` (run, duck or air), `grounded`, `support_normal`,
  `steep_contact`, `position` and `previous_position`
- velocities: `start_velocity`, `requested_velocity` (what entered `move_and_slide`),
  `engine_velocity`, `post_contact_velocity` and `real_velocity`
- measured travel: `displacement`, `actual_velocity` and `actual_speed`, plus
  `control_speed` and `specific_energy`
- `contacts`: body name, node path, position, normal, walkable flag, plus `progress_stage`
  and `surface` metadata when present
- `ledger` (this tick's velocity change per cause), `ledger_residual` and `ledger_totals`
  (per cause: horizontal speed, vertical change, turn, ticks)
- `safety_interventions`, `landing_grace`, `grace_count`, `air_time`, `coyote`, `buffer`,
  `crouched`, `yaw`, `pitch` and the hop, jump and land counts

Ledger causes:

- ground: `ground_accel`, `push_drag`, `coast`, `stop`, `brake`, `grip_turn`, `pivot`,
  `slope`, `duck`, `water`, `ground_hold`
- air: `air_projection`, `air_assist`, `air_low_push`, `air_brake`, `gravity`
- take-off and contact: `jump`, `takeoff`, `edge_carry`, `contact_engine`,
  `contact_clip`, `landing_catch`, `safety_cap`

The tests flag any tick whose residual exceeds 1e-4. That proves every velocity write is
booked; it does not prove the energy is physical.

**Speed for presentation.** `get_speed()` now returns horizontal actual travel, which the
HUD, audio and camera FOV read. `control_speed()` and `velocity` are for control.
`reset_to`, `is_grounded`, `input_enabled`, `yaw`, `pitch`, settings, signals,
`_previous_position`/`_current_position` interpolation, eye clearance and free look are
unchanged.

**Tape adapter.** The tape executor needed no change:

- it sets `motor`, and the factory maps `broad`/`narrow` to `air_profile`; any other
  string, including the executor's default `flow`, leaves broad
- the runner exposes `tape_requested_velocity()` and `tape_step_count`

Two runs passed delivery and ordering on all 480 ticks: `tape-adapter/game-broad` and
`tape-adapter/calib-narrow`.

## Verified measurements

Source project, unset backend (Godot Physics, per the council probe). Seeded runs start
from one labelled velocity write; earned runs start from keys only. See
`test/summary.json`; traces are in `test/traces/`.

### Ground

| Case | Result |
| --- | --- |
| Ordinary 90° mouse turn at run speed | No speed loss; heading lag 0 ticks |
| Overspeed turn, seeded 14 m/s | 96°/s peak, 89° in 1 s, lateral 1.00 of grip, no cost beyond pushing drag |
| Overspeed turn, earned 16.2 m/s off a 16° descent | 82°/s, 75° in 1 s, lateral 1.003 of grip |
| From seeded 14 m/s | push 28.9 m, coast 22.4 m, S brake 12.9 m (stops at tick 53, reverses at tick 54) |
| A alone at 14 m/s | bends 23 m sideways without braking |
| Release or S from earned run speed | stop in 33 or 29 ticks (1.17 or 1.03 m) |

### Hops

- Held hops on flat with W, seeded 12 m/s: requested speed stays exactly 12.000 m/s.
  Measured travel reaches 12.027 on take-off ticks (engine recovery, under 1 mm) and dips
  to 10.25 on landing ticks (about 1.5 cm of travel lost per landing).
- Held hops from rest reach 8.5 m/s and never exceed it.
- A second press relative to landing: 200 ms early has expired. 100 ms early through 75 ms
  late keeps all speed. 100 ms late loses 0.033 m/s, 200 ms loses 0.233, 400 ms loses 0.633.
- Coyote presses hop up to 92 ms after leaving the edge and not at 117 ms.

### Air, equal seeded speed

**Fixed view at 13 m/s over 1.5 s:**

| Input | Broad | Narrow |
| --- | --- | --- |
| A | +1.30 m/s, travel turns 24.5° | +0.00 m/s, 0° (1.1 m drift) |
| W+A | +0.32 m/s, 44.5° | +0.004 m/s, 42° |
| W, or no keys | exactly 0 | exactly 0 |
| S | −7.46 m/s, no reversal | −7.46 m/s, no reversal |

- **Fixed-view W+A with held hops for 20 s, seeded 10 m/s:** broad holds 10.42 m/s and
  narrow 10.02, with no growth after the first second.
- **Diagnostic, assist aimed at camera-forward:** grows 10.00 → 10.03 → 10.07 m/s at 1,
  10 and 20 s. The loop is real but second order, because the side push stays at 90°.
  Aiming at the full wish removes it.
- **Angular window at 13 m/s, gain per tick:** broad peaks at 2.56 m/s² and keeps at least
  half of it from 50° to 70°. Narrow peaks at 2.59 m/s² and keeps half only from 88° to
  90°. Peak gain is matched; angular authority is not.
- **Mouse-led strafe from 10 m/s over 1.2 s:**

| View rate | 0.3 rad/s | 0.75 | 1.5 | 3 | 6 |
| --- | --- | --- | --- | --- | --- |
| Broad, A | +0.29 | −1.09 | −3.00 | −2.38 | −0.89 |
| Broad, W+A | +0.55 | +0.98 | −0.93 | −1.84 | −0.93 |
| Narrow, A | +0.26 | +0.64 | +1.22 | +2.19 | +3.27 |

  W with the mouse adds exactly 0 at every rate in both profiles. The W bend turns travel
  27° in 0.5 s with the view 60° off, 9.7° at 80° and none at 100°, identically in both.
- **Mouse delivery at 30, 60 and 120 events per second** (four 30 Hz phases): broad
  0.067–0.082 m/s on its slow sweep; narrow 0.648–1.057 m/s, a 39% spread. Narrow's
  per-tick allowance makes its reward depend on delivery rate.

### Contacts, slopes and safety

- **Glances at 15° into a wall:** no velocity into the wall. In the air, 11.57 m/s against
  11.59 expected; on the ground, 9.63 against 9.72 expected after pushing drag.
- **W into a wall:** the HUD shows 0.00 while the requested speed is 0.23 m/s.
- **16° descent from 8.5 m/s with W:** 15.49 m/s at the bottom, against a frictionless
  bound of 19.81. Coasting from 12 m/s gives 15.66, against 21.54.
- **Frictionless loop** (down 6 m, flat, up 6 m, drags zeroed): 12.000 → 11.999 m/s.
  Specific energy changes −0.07 J/kg under Godot Physics and −0.002 under Jolt.
- **12° kicker edge:** 8.49 m/s along the ramp and 8.49 in the air; vertical 1.76 → 1.69
  m/s (two ticks of gravity).
- **Hop onto a 20° downslope:** the catch books +3.81 m/s and speed goes 8.5 → 11.63 m/s
  while specific energy falls 39.5 J/kg. Height pays; landing loses energy.
- **Steep 40° slope from 20 m/s:** 153 safety-cap interventions, all counted and booked
  (−13.8 m/s).
- **Calibration line,** W with three timed hops, no side keys: both profiles finish clean
  in 7.41 s, peak 13.17 m/s, no safety intervention.

### Body and camera

- Duck under a 1.3 m ceiling: the runner stays low 170 ticks after release, stands at
  z −8.32 (clear), and the eye stays below the ceiling.
- Ducking at 12 m/s only slows.
- Small steps and a flush seam: one short air run, no grace earned, no added speed.

### Ordering

Every row in every episode passes four checks: the motor ran once between the pre and
post samples; `_previous_position` equals the pre sample; every planned press is visible
as just pressed on its tick; and the view equals the planned yaw after delivery.

## Backend lip and seam comparison

`checkpoints/spillway/r13/carry/backend/` holds two throwaway projects. They differ from
the source only in `physics/3d/physics_engine` (and a removed main scene); script hashes are
in `*-manifest.sha256`. The full suite runs in each, with the same motor and geometry.

| Rise at a seam (z −6) | Separate bodies | One body, two shapes | Godot Physics vs Jolt |
| --- | --- | --- | --- |
| 0, 1, 3, 8 cm | crossed, 0 contact loss, no air, clearance under 2 mm | same | same; per-tick travel dips differ (8 cm at 16 m/s: 11.38 vs 12.40 m/s minimum) |
| 15 cm | dead stop, 14.6 or 34.1 m/s booked as contact loss | same | same |

Grouping abutting shapes changed nothing on either backend.

**Double hop on Godot Physics only.** After a landing that ended 4 mm into the floor, the
take-off tick still reported the floor, so a held hop fired again on the next tick: a
duplicate jump event and a +0.17 m/s vertical gift. CARRY now ignores the floor on a tick
that hops upward. The before-fix repro, `backend/repro-double-hop-godot/`, fails its
"one hop per landing" gate. Jolt never showed it. R12's and FLOW's hop code has the same
structure and is unchanged.

With the fix, both backends pass all 88 gates. The remaining relevant catch is the 15 cm
front face. Root should decide between course geometry (no running lips above about 8 cm,
or ramps under them) and an owned step. I added no step, and no sweep or backend change.

## Native evidence

`native/{line-broad,strafe-broad,strafe-narrow,miss-broad,line-broad-steady}/` each
contain:

- `movie.avi` at 30 fps and a contact sheet
- the per-tick motion trace, the Godot log and `provenance.txt`: arguments, engine hash,
  git HEAD and status, and script hashes (the working tree is dirty with these uncommitted
  files)

The bodies are driven by open-loop key and relative-mouse tapes, rendered on Mesa
llvmpipe under Xvfb `:155` with Dummy audio.

Inspected:

- approach, descent and the speed shown (31 → 46 km/h)
- landing deck, gap, lip and kicker contact, and the finish panel
- `miss-broad` ends on the landing deck after the catch walk
- `strafe-broad` ends 0.4 m short of the finish box

The first capture had a blown-out palette, signs across the line at eye height and
Spillway's split names. All three are fixed in the current captures. Software rendering
says nothing about GPU pacing, display latency or enjoyment.

## Choices and rejections

- **Coast drag 3, not 6.** At 6 m/s² it cancelled the 16° slope pull of 5.5 m/s², so
  coasting downhill paid nothing.
- **Brake to rest, then pivot at 0.5 m/s.** With a 1.2 m/s pivot, S flipped velocity by
  2.4 m/s in a single tick.
- **W in the air lifts a flight to run speed.** At the earlier 3 m/s floor, held hops from
  rest never got past 3 m/s, because each hop leaves on its only ground tick.
- **Landing logic keys off the tick's starting support.** Treating the take-off tick as a
  landing once turned the jump into +2 m/s of horizontal speed (12 → 14.02, retained in
  `dev/t2`).
- **Physical take-off rather than R12's fixed 7.2 vertical.** The fixed impulse would add
  vertical energy on every downhill hop.
- **Rejected:** a turn tax, an owned sweep, a step-up, a 0.35 m step and a Jolt switch,
  per BUILD.

## Open faults and questions

- **Broad's side key follows only slow view turns.** At 0.75 rad/s and faster it loses
  speed (−3.0 m/s at 1.5 rad/s); narrow keeps gaining up to 6 rad/s. A player trying a
  CS-style strafe in broad is punished. This is the main question for broad against
  narrow; the slice must test it with imperfect tapes.
- **Narrow's strafe reward varies 39% with mouse delivery rate.**
- **Running into a lip of 15 cm or more is a dead stop.** Lips up to 8 cm are crossed.
- **Small tick-level travel artifacts** (landing dips, recovery) show in the HUD's travel
  speed for one tick at a time.
- **The old Spillway course does not suit CARRY.** One tape stopped dead against an
  unnamed `@StaticBody3D`, because that course assumes mantles, and its unnamed bodies
  give no stable contact names. Overflow should name its bodies.
- **Unverified:** GPU and display pacing, real mouse hardware, native Windows, and
  whether either profile is fun.

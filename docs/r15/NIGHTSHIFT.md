# R15 Night Shift

The fifth R15 course: an original neon transit-depot bhop course at night, built 8 November
2026. Out of a station platform under parked trains, through a signal throat, round a tram
turning loop, through a wash-bay shed, up a flyover ramp and back over the start platform to a
terminus across a canal. It is registered as the named map `night-shift` and played on the
actual R15 main with the real crouch runner (`r15-source-crouch-2`). The ordinary route needs no
crouch; one optional shortcut does. Every layout and art choice here is a proposal, not a claim
about anyone's taste, and no human has played it.

## Files

| file | what |
|---|---|
| `scripts/r15_nightshift_level.gd` | geometry, progress, routes, gaps, manifest and hash, the common level interface |
| `scripts/r15_nightshift_art.gd` | dressing (night sky, moon, canal water, surfaces, trains, rails, lamps, props, signs), called from `build()` |
| `scripts/r15_nightshift_lab.gd` | standalone launcher: the real R15 main on the named map |
| `tests/test_r15_nightshift.gd` | headless interface, geometry, headroom, hatch and hosting checks |
| `tests/r15_nightshift_driver.gd` | closed-loop route driver and open-loop tape replay (extends `r14_practice_driver.gd`) |
| `tests/r15_nightshift_views.gd` | 16 fixed authored cameras (not the player's) |
| `tests/r15_nightshift_native.py` | native AMD/X11 views and player-camera movies |

No new assets. Trains, rails and props come from `assets/r15/library/kenney-train`, `kenney-city`
and the other shared library packs through `r15_assets.gd` (measured pivots, original
textures). Surfaces reuse the Breakwater and momentum kit textures in `momentum_surface.gdshader`.

## Host interface

The R15 main hosts `map_id = "night-shift"`: 6 stages, default preset `server128`.

- Identity: `level_id` `r15-night-shift`, `level_name` `Night Shift`, `level_version` 1,
  `variant` `nightshift`. The map dresses itself.
- Fields: `spawn`, `checkpoints` (radius 0: each collected by standing on a deck whose
  `progress_stage` meta matches), `segment_bounds`, `finish_position`, `finish_radius` 4,
  `finish_title` `Terminus`, `material_mode` `kit`, `kill_bounds`, `progress_roles` `["route"]`, `routes`, `jump_gaps`, `manifest`,
  `trains`, `water_regions`, `water_audio_sources`.
- Methods: `build()`, `is_finish_at(feet)`, `segment_at(pos)`, `route_hint(stage, feet)`,
  `geometry_hash()`, `geometry_manifest()`, `course_manifest()`, `reset_state()`,
  `start_wheel()`.
- Geometry hash `cb6cc0c00a76be15be81f7f505163620f966ef81f89a2597cd7b11d33e3628ad`; course
  key on the R15 `server128` runner `bbbf75358d4cec52`.
  Bump `LEVEL_VERSION` with any change to geometry, progress or timing.

## Layout

Forward is -z down the platform, round the loop to +z through the shed, then -x along the
flyover, which crosses over platform 1 at 5 m.

| stage | checkpoint | section |
|---|---|---|
| 0 | Platform 1 (0, 0, 20) | a 12 m platform under the station canopy between two rows of ten parked subway cars, the flyover overhead; the forgiving opening |
| 1 | Throat (-1.5, 0, -49) | three signal cabinets over the trackbed, alternating 1.5 m either side of the line (centre gaps 2.5, 3.9, 4.2 m, then 3.5 m onto the loop approach) |
| 2 | Turning loop (1, 0, -80) | a 20 m approach, then a 180° right sweep 10 m wide round the loop pit, twelve trams parked outside its fence. Inside edge open |
| 3 | Wash bays (43, 0, -86) | a three-bay shed. A train with work stands blocks the middle bay; the ordinary line goes right through door 1, up the west bay and out its open north end |
| 4 | Flyover ramp (49, 0, -37) | a forecourt the shed wide, left along it, right up a 9° ramp to 5 m, a tight right knuckle round the signal box |
| 5 | Flyover (34, 5, 6.5) | 70 m of flyover with glass parapets, back over platform 1, then three step-down hops over the canal (3.0, 2.5, 2.0 m; 1.6, 1.6, 1.8 m down) to the terminus concourse |

The height relationship: the flyover crosses directly over the start platform, so the platform
reads the flyover from below at the start and the flyover looks down through glass on the
trains at the end. The two corner rhythms are the open-edged 180° sweep at run speed (stage 2)
and the walled square detour of door, bay, forecourt and ramp turns (stages 3 and 4), closed by
the tight knuckle.

Lines:

- **Ordinary** (`basic`): everything above at run speed, with autohop. No crouch.
- **Earned** (`advanced`): strafe for speed down the platform, chain the throat, then jump the
  6 m pit gap from the approach's east lip onto the traverser bridge, cutting the sweep.
  Screened `server` tier: clear at 339 u/s, comfortable at 391.
- **Crouch shortcut**: run the sweep's last third on the outside lane, then crouch-jump the east
  bay's road door. The door is a half-raised shutter over a splash wall: sill 1.30 m, shutter
  edge 3.05 m, an opening of 69 u. The 72 u standing hull does not fit at any height a jump
  reaches. The 54 u duck hull fits with its feet between 1.30 and 1.68 m, which holds the
  jump-then-crouch apex (64 u). Air ducking keeps full speed. The east bay's lane then runs
  straight across the forecourt onto the ramp. The sign on the splash wall says JUMP + CROUCH.

Recoveries are physical or a labelled respawn:

- A throat miss lands on the trackbed 1.2 m down and walks up the return ramp to the apron.
- A fall into the loop pit (1.2 m down) walks up the pit ramp at the loop's mouth.
- The canal is the only kill volume (y < -3): a fall off the flyover's end or the steps respawns
  at the last checkpoint, and the host marks the run practice.

Collision: 201 convex prisms, each a named static body with `surface` role and stage meta. No
walkable piece is longer than 32 m. Grounded decks reach at least 5 m under their tops and
catches 2.5 m; the flyover and knuckle are the declared 1 m elevated decks (0.6 m floor). Each
of the 43 parked cars is one prism over its drawn footprint and height. The shed's doors, the
west bay's open end and the hatch are real openings, not filled bounding boxes. Nothing hangs
lower over a deck than a standing hull plus a jump, except the declared shutter.

Art: one prism-batch commit after every authored solid, prop support and lamp support (the
Breakwater floating-lamp lesson); the test fails if anything is pending. 27 lights, inside the
Compatibility renderer's budget. Night readability: lamps over every landing (canopy, posts,
bay lamps, masts, flood, flyover arms, terminus), a moon at low energy for dark side faces, lit
deck tops on `momentum_surface`, emissive neon for edges and doors.

## Commands

All run from `projects/foldrunner` with the pinned Godot 4.7.2
(`$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`) and `XDG_*`
pointed at scratch.

```
# play it
godot --path . --script res://scripts/r15_nightshift_lab.gd [-- --r15-preset=server128_aa1000]
# checks
godot --headless --audio-driver Dummy --path . --script res://tests/test_r15_nightshift.gd
# a route: ordinary | earned | crouch | pit_recovery | canal_recovery
godot --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/r15_nightshift_driver.gd -- --out=DIR --route=ordinary [--preset=server128_aa1000]
# replay a tape open loop
godot --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/r15_nightshift_driver.gd -- --out=DIR --tape=events.tape.json [--preset=...]
# native AMD evidence (refuses below 15 GiB free on /home; AVI in /dev/shm)
python3 -I tests/r15_nightshift_native.py views --evidence DIR
python3 -I tests/r15_nightshift_native.py movie --evidence DIR --tape TAPE --frames 3,12,30
```

## Evidence

Under `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/nightshift/`.

`routes/` comes from `run_routes.py`: a fresh `git archive` of HEAD `650346af` plus the seven
uncommitted Night Shift files, imported on a RAM profile. The geometry test ran there with 6257
checks and 0 failures. Each case then had three runs on the actual R15 main, from the normal
named-map spawn with a 33-step warmup at 128 Hz and the default Source sensitivity 2.5
(0.000959931088596881 rad/count):

1. A closed-loop driver run, the state-aware execution proof.
2. Its strict version 2 tape replayed open loop through the same driver.
3. The tape through the standard executor (`tools/momentum-tape.py run --headless --archive
   --render-fps 128 --warmup 33`).

All three agree on the finish tick, time, kind and respawns. The driver's closed-loop and
open-loop traces are rounded samples, kept separate from the executor's full-precision trace.
They match on every state field; the only difference is the controller's node index
(`driver-closed-vs-open.json`).

| preset | route | outcome | time | notes |
|---|---|---|---|---|
| F2 server128 | ordinary | clean | 57.55 s | max 326 u/s, no crouch, 0 wall contacts; checkpoints 11.10 / 15.34 / 27.41 / 35.12 / 44.15 s |
| F2 server128 | earned | clean | 42.68 s | strafe to about 480 u/s, throat chained, traverser jump taken off at 504 u/s; max 528 u/s |
| F2 server128 | crouch | clean | 57.20 s | the hatch: crouch pressed in flight 0.7 s after a take-off at 250 u/s, 66 ducked ticks, no wall contact; 0.34 s ahead of ordinary overall, about 1.3 s ahead between the loop exit and the ramp |
| F2 server128 | pit_recovery | clean | 69.02 s | deliberate fall off the sweep's open inside into the pit, walk up the pit ramp, sweep again; no respawn |
| F2 server128 | canal_recovery | practice | 71.02 s | deliberate walk off the flyover's end into the canal; 1 respawn at Flyover, marked practice by the host; 1 wall-contact tick on the canal wall during the fall |
| F5 server128_aa1000 | ordinary | clean | 57.55 s | tick-identical to F2 |
| F5 server128_aa1000 | earned | clean | 42.68 s | tick-identical to F2 |
| F5 server128_aa1000 | crouch | clean | 57.20 s | tick-identical to F2 |

The F5 runs reproduce F2 exactly. On 128 Hz the per-tick air acceleration cap is already about
195 u/s at AA 100, far over the 30 u/s wish limit, so AA 1000 changes only sharp air turns. These
lines never make one. That proves the lines on F5; it does not show the two profiles agree in
general. The strict executor counter-verifies every tape tick, except the canal run's respawn
row, which its evaluator excludes (9154 of 9155), as in Breakwater's harbour case. No case
has an engine error or warning, an integrity flag or an unclean process cleanup.

`retained-failures/` holds three failed earned attempts on earlier geometry and the superseded
crouch-shortcut designs, with what each showed.

`native/` holds the player-camera movies: the tape replayed open loop on the actual R15 main
with its HUD, on the private AMD/X11 display (`tools/r14_native_display.py`, displays 190-199),
Mesa radeonsi through Compatibility, 1280×720 at 32 fps, Dummy audio, isolated profiles, records
off. Each native trace matches its headless replay tick for tick at the driver's precision. This
is not frame-pacing or latency evidence.

- `server128-ordinary`: clean 57.55 s, 7430 ticks identical. Frames at the platform, throat,
  loop, west bay, ramp, flyover and canal.
- `server128-crouch`: clean 57.20 s, 7385 ticks identical. The hatch and its sign read from the
  loop exit; the HUD's CROUCH tag shows mid-hatch at 27.87 s; then the east lane by the train.
- `server128-canal_recovery`: practice 71.02 s, 9155 ticks identical. The fall shows the canal
  water, then "Back to Flyover · practice" and the PRACTICE (respawned) flag to the finish.

The only engine warnings are the two known platform ones root classified for Breakwater: no
XIM on the private X11, and MovieWriter's low-space note about the `/dev/shm` tmpfs. The
first launches of the crouch and canal movies were refused because HOME was under the
15 GiB floor (14.99 GiB, others writing to `/home`). Those refusals are kept in
`native/refused-home-floor/`, and the movies ran once HOME was back over the floor.

`views/` holds the 16 fixed authored cameras: art and readability frames only, not the player's
view.

## Weaknesses

- No human has played it. Every route proof is a controller, so feel, the first 30 s and the
  corners are unjudged.
- The ordinary line is 57.5 s for the controller, inside the 45-120 s aim. A human time is
  unmeasured.
- The crouch shortcut's margin is small for the controller (0.34 s). It saves about 1.3 s
  through the shed but gives most of it back on the slower outside lane of the sweep. Its
  value to a player who hops into the hatch at speed is unmeasured.
- The earned line's traverser landing is marginal for the controller. It took off early on a
  diagonal at 504 u/s and landed with the hull's edge on the bridge lip, its centre 0.22 m
  short. That is a legitimate box-hull landing in this motor, and the next hop carried on at
  516 u/s, but a cleaner proof would take off at the lip.
- There is no F-key stage-practice proof, because the strict tape executor carries only w, a, s,
  d, space and ctrl. The checkpoint-practice evidence is the canal respawn, which the host marks
  practice.
- The JUMP + CROUCH label on the splash wall runs slightly past its end onto the door pillar.
- The throat sign is partly hidden in the moving view ("OAT · SIGNALS N1-N3" at 13 s).
- The middle bay's north end is a dead-end pocket behind the parked train. It is readable as a
  shed bay but serves no line.
- The F5 runs are trajectory-identical to F2 (see above), so F5 is shown to carry these lines,
  not to differ.
- Art adds about 0.3-0.45 s to level build (headless).

## Root integration (9 November)

The actual integrated host passes all 6257 geometry checks. Root replayed all eight final tapes through the strict executor after adding the isolated lab runner: 58,737 sequential ticks exactly match the worker's earlier full-precision executor traces, including positions, velocity, yaw, clock, progress and results. Input delivery/order/rate, neutral input, nested engine logs and cleanup pass. The canal return is practice with one respawn; its reset tick remains explicitly excluded from the aggregate order claim.

Root decoded and hashed the three 1280×720 AMD movies, checked GPU/kernel and cleanup receipts, and compared every complete finite sequential native driver sample with its retained headless replay. Course, driver and movement hashes match; those movies predate the lab-only host integration, which is bridged by the fresh full-precision replays above. Driver samples are rounded to 0.001 m / 0.001 u/s / 0.000001 rad. Ten direct native-helper sample/cancellation controls pass. No new renderer or performance measurement was run for this audit.

Evidence: outer `checkpoints/spillway/r15/last-modules-integration/REPLAY-RESULTS.json`, `native-review/RESULTS.json` and `nightshift-owner/RESULTS.json`. The independent final challenge and actual release runtime remain separate.

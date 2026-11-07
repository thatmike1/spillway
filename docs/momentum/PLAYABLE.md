# Overflow within Spillway: the R13 game loop

The playable R13 product around the current Overflow course and the provisional air
challenger, 7 November 2026. Nothing here claims fun, desktop GPU pacing, latency or
native Windows behavior. Godot 4.7.2, 120 Hz physics, headless and llvmpipe only.
Evidence lives outside Git under `checkpoints/spillway/r13/product-loop/`; `STATE.md` there
is the resumable log.

| File | Role |
| --- | --- |
| `scripts/momentum_overflow_main.gd` | the game: course, runner, run lifecycle, records, settings, pause and quit |
| `scripts/momentum_overflow_hud.gd` | speed, clock, splits, route reminder, finish card, pause and settings panel |
| `scripts/momentum_overflow_audio.gd` | Spillway's synthesis plus support-surface footsteps and a ground-brake skid |
| `scenes/momentum_overflow.tscn` | launch scene; the only place records are switched on (`persist = true`) |
| `scripts/momentum_overflow_launch.gd` | SceneTree launcher for the same scene, before `project.godot` points at it |
| `tests/test_momentum_overflow_loop.gd` | lifecycle, labels, speed, records and settings across fresh processes |

The main is self-contained rather than extending `spillway_main.gd`, so R12's `BUILD_ID`,
`SAVE_PATH` and record namespace cannot leak into this build. It borrows only R12's static
key bindings, so every control is the same key. The runner is
`momentum_carry_air_candidate.gd` with CARRY's ground, jump, contact and camera, unchanged.
No existing file changed.

## Commands

From `projects/foldrunner`, with `G=$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`:

```sh
$G --path . --script res://scripts/momentum_overflow_launch.gd            # play, records on
$G --path . res://scenes/momentum_overflow.tscn                          # the same scene directly
$G --path . res://scenes/momentum_overflow.tscn -- --no-records          # play without reading or writing a profile
$G --headless --audio-driver Dummy --fixed-fps 120 --path . \
   --script res://tests/test_momentum_overflow_loop.gd -- --out=DIR [--only=GROUPS] [--course-level=PATH]
```

Run the test with an isolated `XDG_DATA_HOME`/`XDG_CONFIG_HOME`/`XDG_CACHE_HOME`; its
persistence phases make their own isolated profiles under `DIR/profiles/`. It exits 1 on any
failed check and writes `DIR/summary.json`. Groups: identity, clean, retry, practice, respawn,
open, explore, pause, hint, speed, driver, course, persist.

To make this the default game, root sets `run/main_scene="res://scenes/momentum_overflow.tscn"`
in `project.godot`. The scene needs nothing else.

Game arguments: `--no-records`, `--r13-profile=PATH` (an explicit, isolated profile; the only
way a headless run persists), `--overflow-level=PATH` (a level script, such as a frozen
copy for captures), `--overflow-world=` (the level's own variants), `--no-hud`,
`--verify-startup`.

## Identity

`BUILD_ID` is `spillway-2026.11.07-r13-overflow`. The window title is `Spillway R13 ·
Overflow`. The launch shows SPILLWAY, `OVERFLOW · R13` and three lines of controls. The
pause panel heading is `SPILLWAY R13 · OVERFLOW`, followed by the build id, the first eight
characters of the course key and the profile state. The startup line prints build, course,
stage count, course key, records state, runner policy and renderer. The test rejects any
HUD text containing R12, surf, slide, broad, narrow, CARRY, "records disabled" or
"experiment" words. The controls describe the candidate's actual air rule: keys bend the
flight where they point, no keys keep the line, S brakes, A/D turned with the mouse carve a
little speed.

## Run lifecycle

- **Start.** The clock starts when the runner moves 0.5 m from the spawn.
- **Stages.** Split names come from the level's checkpoint titles; the last segment is the
  level's `finish_title` or "Finish". The course at f3e33ebf has four segments (Pier, Pier
  deck, Sill, Finish). The in-progress revision seen on 7 November names them Pier, Chute,
  Tail race, Finish and got a new course key with no change here.
- **Checkpoints.** A stage counts when the runner is inside its bounds, or stands on a deck
  with its `progress_stage` metadata. Any later stage reached physically counts too. Stages
  passed over keep no time; nothing is interpolated.
- **Finish kinds.** Arrival at the finish always finishes and starts the level's wheel.
  - *Clean:* every stage measured, no practice or respawn. It may set the full-course best,
    best splits and best segments.
  - *Open:* clean, but a stage was skipped. It may set the open-line best only. The card
    lists the skipped stage as "skipped" and the next one as "reached at", never as a segment.
  - *Practice:* after F, or after a fall. It records nothing.
- **R** restarts a clean run at once from anywhere, paused or finished, with W still
  working on the next tick. There is no start menu.
- **F** practises from the last stage reached, with a segment clock. Its segment is compared
  with the best segment but not recorded.
- **Falling out** of the course (below y −8.3 or outside the inherited x/z envelope; a level
  may publish `kill_bounds`) returns the runner to the last stage as practice.
- **After a finish** the runner can keep moving and look round. Falling out then puts it
  back on the finish, keeping the result.
- **Esc** pauses and freezes the run; physics, clock and runner input stop. The panel has
  Resume, Restart, Practise (naming the stage), Quit, mouse sensitivity, horizontal FOV,
  volume, comfort camera and autohop. Settings apply at once.

## HUD

The course stays in view. Bottom left: speed in m/s, the run clock, and the best (or "first
run", "open line …", "practice · not recorded"). A split appears briefly mid-screen with the
run time at that stage and its difference from the best run's split, coloured ahead or
behind. The finish card sits beside the course on the left, about a third of the width.

The route reminder comes from the level's `route_hint`. It appears for a first clear, in
practice, or when the level's hint for where the runner stands differs from its hint at
the stage's checkpoint, which is how a recovery shows without the HUD knowing any
coordinates. The intro holds until the first move plus 4 s, then fades. Once a clean time
exists, R does not bring it back.

**Speed is measured travel.** The number is the mean of the runner's last 12
finite-difference horizontal steps (0.1 s): `get_speed()`, which the CARRY runner computes
from actual displacement. It is not the requested or control velocity. The test measures
positions itself and requires agreement to 1e-3 m/s on the flat and on the course descent,
where slopes make the control speed differ.

## Records and settings

- **Separate profile.** `user://spillway_r13.cfg` holds only this build's settings and
  records. R12's `spillway_r12.cfg` is never opened for writing. On the first R13 launch
  only, its `[settings]` seed R13's mouse, FOV, volume, comfort and autohop. Its records
  are never read. On a machine without R12, R13 creates no R12 or R11 file, so R12's own
  first launch behaves as before.
- **Course key.** Records sit under `course_<key>`. The key is a hash of the timing rules
  version, the level's `geometry_hash()`, the segment titles and the runner's policy and
  tuning. Each section also stores the geometry hash and stage count, checked on load. A
  changed course, stage list or runner tuning starts a fresh record set, and the old section
  stays in the file, so reverting restores it. Loaded settings are clamped to the panel's
  ranges.
- **When it writes.** Only on a clean or open finish and on a settings change, and only if
  persistence is on. Persistence is on only when the launch scene asks for it, it is not
  `--no-records`, and the display is not headless unless `--r13-profile=` names a profile.
  A driver, tape executor or comparison that builds the main with `new()` neither reads nor
  writes any profile, and starts from default settings.

## Audio

The base is Spillway's original synthesis: footsteps from the runner's gait, the hop
breath, landing thumps scaled by impact, wind from actual travel speed, and water beds at
the level's `water_audio_sources`. Two additions describe real motion:

- **Footsteps follow the support material.** The kind is looked up from the level's
  geometry manifest for the body the runner is standing on: steel and rails ring higher,
  old concrete is lower, brick slightly lower. A steel landing adds a ring over the thump.
- **Ground-brake skid.** It plays only while the runner's own ledger books a ground
  `brake` (S, or input reversing the travel), scaled by the booked deceleration and the
  speed. Air braking gets no sound; its speed loss is heard as the wind falling.

Nothing shakes or turns the camera. Audio was checked only as values and logged levels
under the Dummy driver. Nobody listened to it.

## Level interface used

`build()`, `spawn`, `checkpoints` (`pose`, `title`, optional `bounds` or `radius`),
`water_regions`, `water_audio_sources`, `finish_position`, `is_finish_at(feet)`,
`route_hint(stage, feet)`, `reset_state()`, `start_wheel()`, `geometry_hash()` (else a
hash of the progress layout), `manifest` (optional, for footstep kinds), `finish_title`
and `kill_bounds` (optional), and `progress_stage`/`surface` body metadata. `segment_bounds`
and `segment_at` are not needed. A course revision with other stages, titles or
coordinates needs no change here; its records start fresh under a new key.

## Verification

The lifecycle runs on a labelled FIXTURE level in the test file: a straight deck with
stage boxes, a finish box and a void. It has parameters for stage count, titles, a skipped
pocket and a geometry tag. Every run is driven by key and relative-mouse events through
`Input`. Pause buttons are clicked through the viewport's GUI picking: the headless window
is 0×0, so the click is given in viewport coordinates. The native capture clicks in window
coordinates through `Input`. No test calls the finish or writes the runner's pose or
velocity.

- **Persistence.** Six fresh processes with isolated XDG profiles: first launch seeding
  from an R12 file, reload, changed geometry, revert, `--no-records`, and a bare machine.
  Each quits by clicking Quit. The R12 file's hash and mtime are checked unchanged.
- **Negative controls.** In a scratch copy, six deliberate breaks are each rejected:
  - saving to R12's path
  - a course key without the geometry
  - practice finishes recording
  - showing control speed instead of travel
  - fabricating times for skipped stages
  - writing while records are off

  The control-speed break passed the first version of the suite, because on the flat
  fixture the two speeds agree. The course descent check was added for it.
- **Course.** The course group builds the current course, or `--course-level=` a frozen
  copy. It checks only interface, names, key, a first-clear reminder, W descent speed and
  speed honesty, never coordinates.
- **Full route.** The recorded ordinary-line tape from the Overflow course work, replayed
  with `tools/momentum-tape.py` through this game on a frozen copy of the course at
  f3e33ebf, finishes clean: four stages in order, 16.292 s, zero respawns. That is one
  recorded W/mouse/jump line on the frozen source, not a proof for the revised course and
  not imperfect play.

## Limitations

Root integration: all 12 delivered file hashes matched the handoff. Root reran the full
147 checks and the current shared-course 10 checks with no failures or script errors,
and inspected launch, pause/settings, open-line and frozen-course split/finish frames.
See `checkpoints/spillway/r13/product-loop/ROOT-REVIEW.md` outside Git for exact scope.
The default project remains on R12 pending the revised course and movement review.

- The course is being revised by another worker. Every course capture here uses a frozen
  copy of the f3e33ebf source, labelled. The revision needs its own complete native movies.
- No ghost. The core loop came first.
- `geometry_hash()` covers solids, not materials or scenery, and the runner fingerprint
  covers tuning dictionaries, not code. A logic change in the motor that keeps its tuning
  keeps the records. `TIMING_RULES` and the profile `format` are manual version bumps.
- Practice resets the level's wheel state but not other level state the interface does not
  expose.
- Controller bindings are R12's. Pad navigation of the pause panel was not tested.
- Frames come from llvmpipe on Xvfb. Desktop GPU pacing, latency, Windows and whether any
  of this is fun are unverified.

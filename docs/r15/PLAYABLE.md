# R15 playable shell: maps, presets, checkpoints, records

8 November 2026. The R15 game host is `scenes/r15.tscn` (`scripts/r15_main.gd`). It runs the
approved R14 bhop movement with the real crouch runner. `project.godot` now launches R15
Breakwater. The delivered R14 game and its approved motion modules remain unchanged.

Standalone launch with explicit options:
`godot --path . --script res://scripts/r15_launch.gd [-- --r15-map=ID] [-- --r15-preset=ID] [-- --no-records]`

## What the player gets

| key | does |
|---|---|
| F2 | CS:GO bhop server: AA 100, 128 Hz, autohop. The default |
| F5 | Bhop server AA 1000: the same server at AA 1000 |
| F4, F3 | Advanced comparisons, folded in the menu: Quake III-inspired, unchanged R13 |
| F1 | Says vanilla is not part of R15. The R14 build keeps it |
| Ctrl or C | Real crouch (`r15_source_player.gd`), on the ground and in the air |
| R | Clean restart at the map's spawn |
| F | Practice from the last checkpoint reached. Never recorded |
| Esc | Menu: records, Resume/Restart/Checkpoint/Quit, map chooser, checkpoint picker, presets, look |

The HUD always shows the map (with "R14 map", "Experiment · not a course" or "development
stand-in" where that applies), the F key and preset, the rate and AA. A CROUCH tag sits above the
speed; it reads "CROUCH · no room to stand" while a release is deferred under a ceiling.

The speed readout is still the horizontal actual travel over 0.1 s. The air duck's 9 u lift is
origin compensation that the runner keeps out of `get_speed()`. The native run measured the HUD
speed at 247.61169 u/s on both sides of the duck tick. Hop gain, contact loss and directional
sync are R14's `r14_strafe_stats.gd`, unchanged.

**Map chooser.** It lays map cards out in a grid. The grid has as many columns as the menu panel
fits: 3 at 1280×720 and at 4:3, 4 on ultrawide. The menu scrolls, so any number of maps fit.
Twelve fixture maps were reached with the wheel. A card loads its map at the spawn and keeps the
active preset. The Movement Lab accepts F2/F5 only; entering it from F3/F4 switches to F2 with a notice.

**Default map.** Breakwater is the default. Penstock Yard and Overflow remain available in the
map grid. A deliberately incomplete development tree falls back to Penstock with an explicit
stand-in label; a final release must contain all five themed courses and the separate lab.

## Maps: `scripts/r15_maps.gd`

The `CATALOG` holds eight registered ids, in menu order:

- `breakwater` → `r15_breakwater_level.gd`
- `whiteout-relay` → `r15_whiteout_level.gd`
- `sunken-court` → `r15_sunken_level.gd`
- `rainline` → `r15_rainline_level.gd`
- `night-shift` → `r15_nightshift_level.gd`
- `practice` (Penstock Yard) and `overflow`: the R14 maps
- `experiment` → `r15_experiment_level.gd`, kind `lab`

A map is playable only when its script exists, loads and is a `Node3D`. The menu never lists the
others, so a planned map never looks finished. **Adding a map** means writing the level script.
The catalog entry is already there; for a new id, add one `CATALOG` entry and one `ORDER` slot.

New levels use the R14 level interface, read by the host:

- `build()`
- `spawn`
- `checkpoints` (`pose`, `title`, optional `bounds` or `radius`)
- `finish_title`, `finish_position`, `is_finish_at(feet)`
- `water_regions`, `water_audio_sources`
- `level_id`, `level_version`, optional `variant`
- `geometry_hash()`, optional `route_hint`, `reset_state`, `start_wheel`

Bodies carry `progress_stage` and `surface` metadata, as in R14. Optional new fields:

- `kill_bounds`: without it, a non-R14 map derives a box from its own solids, with the floor 12 m
  under the lowest one. The dam-sized R14 box is never assumed.
- `progress_roles`: the surface roles that count as stage decks. Empty means any tagged deck.
- `mechanics`: an Array the lab declares, such as slide, wall jump or grapple. It enters the
  record identity.

Only the two R14 maps get the R14 art and readability passes. New maps own their art.

## Runner policy

The source family is built from `res://scripts/r15_source_player.gd`. If that module is missing
or does not load, the game shows why, does not start, and exits 3 under `--verify-startup`. It
never falls back to another runner.

`--r15-standin-runner=r14` (`source_runner = "standin-r14"`) plays the delivered R14 runner on
purpose. The HUD, title and menu then say STAND-IN, and its record identity differs. Tests may
also pass a Script.

The host reads from the runner:

- R14's interface: `reset_to`, `settings`/`apply_settings`, `get_speed`, `is_grounded`,
  `probe_ground`, `state`, `jump_count`, `yaw`, `pitch`, `pitch_limit`, `input_enabled`,
  `camera`, `tape_step_count` and the interpolation fields.
- From the R15 runner: `ducked`, `stand_blocked`, `MOTOR_VERSION` and `_duck_compensation_u`.

**Timing and progress reference.** The clock start, point and box checkpoint triggers, and the
finish read `body_reference()`: the feet minus the runner's duck compensation since it last stood
on the ground. A duck or stand in flight therefore never starts the clock, enters a trigger or
crosses a finish by itself. Landing makes the real feet the reference again. Stage decks still
need real ground support.

Without crouch the compensation is zero, so R14's rules hold exactly. **For root:**
`_duck_compensation_u` is a leading-underscore field. A public accessor on the runner would be
cleaner; the host reads it in one place, `_compensation_total()`.

**Hull fits and pending switches.** A switch on the same source body (F2/F4/F5) applies at once.
It keeps feet, velocity, view and the duck hull.

A switch to a different body (F3) needs that body's standing hull to fit at the feet. Until it
fits, it waits with a message. This covers a crouched runner under a roof. Each of these cancels
a waiting switch:

- pressing the active key
- F, or the checkpoint picker
- a map change

R applies a waiting switch at the spawn only if it fits there.

## Records: `user://spillway_r15.cfg`

Settings plus one section per record identity. The identity is:

- the timing rules (`r15-timing-1`)
- map id, kind, level id, version and variant
- the geometry hash and the stage titles
- the preset, family and motor version (`r15-source-crouch-2`, or `r14-source-motion-3` for the
  stand-in)
- the runner path and the rate
- the running body's full physics fingerprint (the six duck settings included)
- the hull (standing and duck heights, air anchor)
- the mechanics

Each section stores its identity text. A load needs that text to match exactly. Times are stored
only as integer ticks; floats are readable copies. A section is refused whole for any of these:

- a type or range error
- an incomplete or out-of-order split list
- a last split that is not the best
- a segment longer than its split
- segments summing past the best
- an open line slower than the clean best
- another rate or tick version
- a changed identity

Refusal leaves every best empty, and the menu says it was ignored.

Practice, respawned and mixed-preset finishes never save a best. So does a switch after early
movement or a jump before the timer. Crouching in place at the spawn does not count as movement.

On first launch only, the look settings are read from `spillway_r14.cfg`. That file is read-only
here, and no R14 best is imported. Once an R15 profile exists, R14 is never read again.

## Verification (8 Nov 2026, Godot 4.7.2 official, worktree at a37636bb plus these files)

**Headless loop: 186/186 checks in 26 s.**
`godot --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/test_r15_loop.gd -- --out=DIR`

It has 18 groups: default, standin, missing, crouch, registry, chooser, legacy, hook, switch,
purity, hull, offset, kill, lifecycle, stages, rapid, persist and quit.

Everything is played with key, wheel and relative-mouse events, plus viewport clicks and wheel
scrolls. Five ERROR lines in the log are expected: they come from deliberate negative checks
(missing runner, unbuilt map, vanilla aliases).

The checks include:

- **Real crouch** under a fixture roof: blocked standing, a ducked pass, a deferred stand-up, F3
  waiting under the roof, F5 keeping the duck hull, F from under the roof.
- **Air duck:** it lifts the raw feet into a trigger the plain hop misses, and no checkpoint
  counts. The HUD speed series is identical tick for tick to the uncrouched hop.
- **Map chooser:** 8 fixture maps at four window shapes, 12 by scroll.
- **Rapid churn:** 48 preset switches and 8 map changes.
- **Persistence and quit:** separate processes with isolated XDG profiles, including 12
  malformed-section refusals and a control. The menu's Quit exits the process with code 0.

**Mutations: control passes, 11/11 caught.**
`python3 tests/test_r15_loop_mutations.py --out DIR` breaks one rule per run in a scratch copy:

- the duck lift counts as travel
- the identity is not checked
- a mid-run switch stays clean
- practice finishes save
- the fingerprint is taken from the preset table
- a missing runner falls back
- a map change keeps the pending switch
- missing modules are listed
- vanilla becomes a preset
- the map cards sit in one row
- the HUD ignores the deferred stand-up

**Route equality: exact.** The three approved locked128 tapes (F2 Penstock advanced, F2 Overflow,
F5 Overflow) replay through `r15_main.gd` with the original warmup, the sensitivity and fixed-fps
128. Both the R15 runner and the stand-in were run. The tool command, exactly as
`approved-base/locked128/RESULTS.json` records it:

`tools/momentum-tape.py run TAPE --headless --archive --render-fps 128 --wall-budget 100 --deadline 160 --warmup 33|8 --game-script ROUTE_GAME --game-class '' --motor ID`

Against the approved runs, all 3,814, 6,271 and 6,271 ticks are equal in post-step position,
velocity, yaw and game state (respawns, checkpoint, elapsed, finished, kind, paused). All six
finish clean at 28.609375, 45.9609375 and 45.9609375 s. Engine logs are error-free.

**Native: 21/21 checks.**
`python3 tests/test_r15_loop_native.py --out DIR`

It ran through `tools/r14_native_display.py`: private Weston and Xwayland on :190–199, AMD
Radeon renoir (radeonsi). The GPU watch proved gfx work on renderD128.

The real scene ran under the observer `tests/test_r15_loop_tour.gd`, which only reads it. All
control was xdotool keys and clicks plus XTest relative mouse:

- the default map and its stand-in label
- a run-up past 240 u/s and held-Space autohop
- a ground crouch with the CROUCH tag
- R
- an air crouch: 0.2280 m lift beyond travel, HUD speed unchanged
- F5
- the menu's grid chooser, then a click to Overflow that kept F5
- F checkpoint practice
- the Quit click: exit 0, no engine errors

It recorded an MP4, 8 JPEGs and gzipped telemetry. No profile was written, since nothing
finished. HOME had 16.34 GB free before.

Evidence is in the outer `checkpoints/spillway/r15/product-loop/` (23 MB): `route-equality/`,
`mutations/`, `native-04/`, and the failed attempts below.

## Failed trials

- **Native 01:** the scripted mouse turn steered the runner into Penstock's wall, so the second
  run-up timed out. The script now presses R first.
- **Native 02:** every behaviour check passed, but it caught a real engine error. My first audio
  rebuild took the old audio node out of the tree while it still listened for the runner's
  landing signal. It is now freed at once. Headless runs never land in that window.
- **Native 03:** the Overflow click used card positions from the first paused frame, before the
  grid laid out. Clicks now wait for two telemetry rows that agree.
- **Headless, early:** wrong test assumptions, since fixed. The loaded map's card stays in the
  menu by design. Penstock has its own kill box. Ticks come back from JSON as floats.

## What is stand-in or fixture, and what remains

- **Fixtures.** Every lifecycle, chooser, crouch and record check runs on labelled fixture levels
  (`tests/r15_loop_fixture_level.gd`, `tests/r15_loop_fixture_maps.gd`). They say nothing about a
  real course.
- **Current maps.** All five themed courses, Penstock Yard, Overflow and the Movement Lab are available. Breakwater remains the actual default.
- **Root, after the maps land:**
  - rerun this suite
  - add per-map route proofs
  - challenge new contacts, recovery and map discovery
  - decide whether to make `_duck_compensation_u` public
  - verify the final portable pack outside the checkout
- **Not measured.** Speed or feel with Mike; physical-device input; a packed build.
- **Stray files.** A Godot import regenerates `.uid` files for three R14 scripts (see
  docs/r15/CROUCH.md). It also generates `.import` files for the asset library. They were not
  kept here.

## Root source integration

Root verified the returned source hashes and reran all 186 headless gates in a fresh imported copy with the real crouch runner. The outer log scan first rejected five intentional refusal-control errors; the receipt now classifies exactly those five expected messages and rejects every other error. Root inspected the native map chooser and airborne-crouch frames. Evidence: outer `checkpoints/spillway/r15/product-integration/`. The original shell check predates the first map. The project now defaults to R15 Breakwater. This does not certify future map routes or a final package.

Breakwater is now integrated as the actual default and the project launches the R15 scene. The first integration rerun passes the real default/registry groups on the Breakwater module. This supersedes the two-legacy-map/development-stand-in state recorded earlier; all five new courses and the optional lab have since been integrated as recorded below.

The real R15 host and crouch motor version 2 now replay all three approved F2/F5 routes with exact position, velocity, yaw, applied input and game state across 16,356 ticks (`crouch-harness/approved-routes/RESULTS.json` outside Git). Five Breakwater tapes also pass the standard executor, including physical recovery and a deliberate checkpoint respawn; see BREAKWATER.md for their times and evidence precision. No final R15 package has been accepted yet.

The registry's absent-module refusal control now uses an explicitly nonexistent fixture, rather than a future real course. Fresh source shell verification on the Breakwater default passes 184 checks, with exactly five labelled refusal errors and no unexpected errors (`product-integration/available-map-control/RESULTS.json`). The earlier 186-check total included two missing-module/stand-in checks that no longer apply once Breakwater exists; none was retired to hide a failure.

## Complete source integration (9 November)

The map grid now contains all eight entries. See BREAKWATER.md, WHITEOUT.md, SUNKEN.md, RAINLINE.md and NIGHTSHIFT.md for route proofs, licensed assets and limitations. The Movement Lab is separate: Shift slides, a fresh Space near a wall jumps off it, and holding E on a ring grapples. Keys 1/2/3 or menu switches toggle these experiments; changing a move during an attempt makes it practice, and every loadout has separate records. Its HUD says EXPERIMENTAL. Leaving it restores the approved course runner. The lab's current wall jump needs the key pushing toward the wall released before the tap; AA100 otherwise cancels its outward push. See EXPERIMENT.md for the labelled tuning and actual input proofs.

The full source wrapper now passes every map, the 179-check current loop and both unchanged R13 controls. All 16,356 approved F2/F5 ticks still match after lab integration. New map recovery and crouch proofs are source-mode evidence; final packed delivery and player-view discovery are still required. No human feel is inferred from the check counts.

# Sunken Court

An R15 course map, built 8 November 2026: an original sunlit overgrown ruin. The run goes through a gatehouse and down three falling steps. It hops across arch pavilions standing in a sunken water court, rounds a curved aqueduct, crosses a walled cloister over a sunken cistern, and climbs to a hilltop sanctuary. It is hosted by the actual R15 main as map `sunken-court` and played by the real crouch runner (motor `r15-source-crouch-2`).

Integrated into the R15 source host. Release-pack acceptance remains separate.

## Files

| file | what |
|---|---|
| `scripts/r15_sunken_level.gd` | geometry, progress, routes, gaps, the common level interface |
| `scripts/r15_sunken_art.gd` | dressing: stone and water shaders, sky and sun, course models, scenery, labels, finish light; called from `build()` |
| `tests/test_r15_sunken.gd` | headless interface, geometry, headroom, arch-void and hosting checks |
| `tests/r15_sunken_driver.gd` | closed-loop route driver and open-loop tape replay (extends `r14_practice_driver.gd`) |
| `tests/r15_sunken_tape_game.gd` | setup only: the R15 main on `sunken-court`, for `tools/momentum-tape.py --game-script` |
| `tests/r15_sunken_views.gd` | 13 fixed authored cameras, JPEG |
| `tests/r15_sunken_native.py` | views and player-camera movies on the private AMD display |
| `tests/r15_sunken_cast_probe.gd` | the R14 cast probe pointed at this level |

No new assets. Everything placed comes from the shared Kenney Castle and Nature kits through `r15_assets.gd`. Placed course models get tinted copies of their own materials at runtime: the bridge's near-white walk clips in full sun. The files stay as imported.

## Host interface

`r15_main.gd` with `map_id = "sunken-court"`: "Sunken Court", kind `course`, 5 stages, default preset `server128` (F2), F5 `server128_aa1000`.

- Identity: `level_id` `r15-sunken-court`, `level_name` `Sunken Court`, `level_version` 1, `variant` `sunken` (deliberately not `course`), `material_mode` `kit`.
- Interface: `spawn`, `checkpoints` (stages 1 to 4 have radius 0, so a checkpoint is collected by standing on a deck of that stage), `segment_bounds`, `finish_position`, `is_finish_at()`, `segment_at()`, `water_regions` (empty: no water changes movement), `water_audio_sources`, `routes`, `jump_gaps`, `kill_bounds`, `progress_roles` `["route"]`, `route_hint()`, `geometry_hash()`, `geometry_manifest()`, `course_manifest()`, `reset_state()`, `start_wheel()`.
- Bodies carry `progress_stage` and `surface` metadata. Names are stable (`s<stage>_<thing>`; model pieces `<model>_<part>`).
- Geometry hash `13d01970ab4753627811c25a621a3f900ff979c9eda6c0eac2abe7f4cf6b094e`. Course key `7b98855578653cc0` on F2 and `ec3af1c61f9d9afc` on F5. Bump `LEVEL_VERSION` with any change to geometry, progress or timing.

## Layout

The run goes forward along -z through the gate and court, sweeps round the aqueduct, then returns along +z on the leg, cloister and climb. Piece names use x for east and z for north; route hints never use compass words.

| stage | checkpoint | section |
|---|---|---|
| 0 | Gatehouse (0, 8, 10) | a 16 m terrace under a great arch tower, then three falling steps 1.2 m down each, with gaps of 2.0, 2.5 and 3.0 m |
| 1 | Sunken court (0, 4.4, -44.5) | a 44 m balcony over a water court 6.4 m down; six arch pavilions alternate 0.6 to 0.8 m up and down, with gaps of 2.5 to 3.9 m, then onto the aqueduct head |
| 2 | Aqueduct (0, 5, -102.5) | 12 bridge spans in a 20 m radius bend over the river to the castellum, then 7 spans of the leg back to the cloister |
| 3 | Cloister (40, 5, -59.5) | 5 m walks round a sunken cistern garth 2.5 m down; out at the far corner |
| 4 | Sanctuary steps (53.5, 5, -31) | five rising steps 0.8 m each with moss-bed catches, then through the sanctuary to the finish arch |

The basic route takes 47.5 s for the controller.

**Recoveries.** All visible, none needing a respawn except the river:

- A short step hop lands in a moss bed one step below the next deck and steps back up.
- A fall into the court pool wades to a stair ramp up the side wall to the balcony.
- A fall into the cistern walks up a stair ramp back to the south walk.
- A fall off the aqueduct into the river leaves the kill envelope and respawns at the Aqueduct checkpoint. This is the only use of the kill envelope.

**Earned line: the chord.** Four slim cistern towers (2.9 m tops) run on a gentle curve across the inside of the bend, about 8 m centre to centre, to the castellum. A hop on landing at about 450 u/s chains them; at 250 u/s each is a near-maximum standing jump after stopping. The controller carries speed out of the court (300 to 420 u/s strafe targets) and finishes in 35.5 s against 47.5 s.

**Crouch line: the fallen architrave.** A causeway lies diagonally across the cistern garth, from the south lip by the leg to the north lip by the exit. Its top is 60 u (1.52 m) over the walks. A standing jump reaches 50 u but not 56 u. Jump then crouch reaches 64 u. A floor sign on the approach says "FALLEN ARCHITRAVE · 1.52 m up / jump, then crouch (Ctrl or C) in the air", and a yellow lip marks the edge. Open sky over its whole length is the stand-up room. The ordinary alternative is the walks round, signed "walks: left and round". The architrave path is about 29 m against the walks' 34 m. A missed crouch jump lands back on the walk, and a fall off its sides lands in the cistern with its ramps.

**Declared gaps** (`jump_gaps`, vanilla figures, feet centre to feet centre):

- The steps, pavilions, court-to-head and rises are all `vanilla_run` or `vanilla_strafe`: clear at 111 to 274 u/s, comfortable at 125 to 326.
- The chord hops are `server` tier: clear at 340 to 463 u/s, comfortable at 392 to 534, intended 450.

**Collision.** Every solid is a convex prism with a planar top and bottom over one outline. No walkable piece is longer than 32 m (longest 28.0 m). Every walkable piece reaches at least 1.277 m below its top. The library models' collision is authored from their measured vertices, below, so arch passages and the spaces under bridge spans stay open. 231 rays through those voids hit none of their model's pieces. Nothing hangs lower over a walkable deck than a standing hull plus a jump (3.277 m).

**Measured model profiles** (unscaled, from the imported meshes):

- `tower-square-arch`: corner piers at |x|, |z| 0.255 to 0.465, 0 to 1.01 tall. A roof over the inner 0.419 square from the crown at 0.802 to 1.01. The arch runs through both axes: (0.255, 0.547), (0.246, 0.613), (0.221, 0.674), (0.18, 0.727), (0.127, 0.768), (0.066, 0.793), (0, 0.802).
- `bridge-straight` (traffic along local x): walk |z| < 0.269 at 1.04, curb to 0.35 at 1.06, parapet to 0.465 at 1.12. Merlons at |x| < 0.116 and 0.349 to 0.465 rise to 1.176. Piers at |x| 0.349 to 0.465 and z ±0.39 rise to the slab underside at 0.735. The arch: (0.349, 0.347), (0.337, 0.437), (0.302, 0.521), (0.247, 0.594), (0.174, 0.649), (0.09, 0.684), (0, 0.696).
- `wall-pillar`: a ±0.5 block, 1.31 tall.

## Commands

All run from `projects/foldrunner` with the pinned Godot 4.7.2 (`$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`) in a copy of the project with its imports.

```
# checks (6990 checks, 0 failures)
godot --headless --audio-driver Dummy --path . --script res://tests/test_r15_sunken.gd
# a route, closed loop: ordinary | earned | causeway | causeway_hop | causeway_chain
#   | court_recovery | river_recovery | cistern_recovery
godot --headless --audio-driver Dummy --path . --script res://tests/r15_sunken_driver.gd -- \
  --out=DIR --route=NAME [--preset=server128_aa1000]
# a tape, open loop through the same driver
godot --headless --audio-driver Dummy --path . --script res://tests/r15_sunken_driver.gd -- \
  --out=DIR --tape=DIR/events.tape.json [--preset=server128_aa1000]
# a tape through the standard executor (needs root's e98848f9 momentum-tape.gd/.py)
python3 -I tools/momentum-tape.py run TAPE --out DIR --headless --archive --render-fps 128 \
  --wall-budget 150 --deadline 220 --warmup 33 --game-script res://tests/r15_sunken_tape_game.gd \
  --game-class '' --motor server128|server128_aa1000
# cast probe
godot --headless --audio-driver Dummy --path . --script res://tests/r15_sunken_cast_probe.gd -- --out=DIR
# native, private AMD display 190-199; refuses below 15 GiB free on /home
python3 -I tests/r15_sunken_native.py views --evidence DIR [--weston-root DIR]
python3 -I tests/r15_sunken_native.py movie --evidence DIR --tape TAPE --frames 3,9,14 [--preset ID] [--weston-root DIR]
```

The driver writes `summary.json`, `events.tape.json` (strict version 2: key edges `w a s d space ctrl` and mouse counts after the labelled spawn; the mouse scale is in `description` and the summary only) and `trace.jsonl.gz` (raw feet `p`, duck compensation `comp` in u, and the main's timing reference `ref`, kept apart).

## Evidence

Under `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/sunken/`; `README.md` there indexes it.

Headless, actual R15 main, 128 Hz, keys and mouse only after the main's labelled spawn:

| preset | route | result | time | notes |
|---|---|---|---|---|
| F2 | ordinary | clean | 47.53 s | splits 8.42, 17.53, 33.24, 37.49; max 372 u/s; 0 wall ticks |
| F2 | earned | clean | 35.50 s | chord take-offs at 426 to 458 u/s; max 589 u/s |
| F2 | causeway | clean | 49.25 s | taught line: stops, lines up, crouch jump from a run |
| F2 | causeway_hop | clean | 47.04 s | crouch jump out of a hop, speed strafed back on top; beats the walks by 0.49 s |
| F2 | causeway_chain | **missed** | | chained straight out of the leg landing, takes off about 4.9 m short of the lip and falls back onto the walk |
| F2 | court_recovery | clean | 68.78 s | deliberate short hop into the court pool, wades to the ramp, back up, on; 1 wall-contact tick on a pavilion arch haunch |
| F2 | river_recovery | practice | 48.95 s | runs off the aqueduct head into the river, 1 respawn at Aqueduct, on to the finish |
| F2 | cistern_recovery | clean | 56.19 s | walks off the south walk into the cistern, up the ramp, round the walks |
| F5 | ordinary, earned, causeway_hop | clean | 47.53, 35.50, 47.04 s | identical to F2; the runner's settings confirm sv_airaccelerate 1000; the 30 u wish cap saturates on these lines |

Cross-checks (`CROSSCHECK.json`):

- **Driver replay.** Every tape replays open loop through the driver with zero differing fields on every shared tick.
- **Standard executor.** All ten successful tapes (seven F2, three F5) pass e98848f9 `momentum-tape.py`. Each executor ends without delivery/integrity flags, with order and rate ok. The river reset tick is excluded from the aggregate motor-order claim; its practice result is retained. Each reaches the same finish time, kind and respawns. Positions agree with the driver to its 0.5 mm rounding.
- **Air duck.** Both crouch lines' air duck is accepted as a valid hull-origin compensation, with no invalid ones.

Native, player camera with the HUD: `native/movie-<route>/movie.mp4`, JPEG frames and `run.json`. These are open-loop replays of the same tapes on the AMD display (Mesa radeonsi renoir, Compatibility). Each complete native driver sample equals its headless replay. These samples round position to 0.001 m, velocity to 0.001 u/s and yaw to 0.000001 rad; this is not full-precision equality. The seven MP4s are encoded at 960×540 from the 1280×720 game window. `native/views/` holds the 13 authored cameras, for art and readability only.

Cast probe: 524 misses in 233,406 casts (0.225%) over 101 sampled pieces. Breakwater measured 0.228% and Penstock 0.154%. The misses concentrate on the long walks and the balcony, all of which are at least 1.277 m deep against a drop of 6 cm or less per tick, so the approved end-overlap guard can catch them.

## Notes for root

- Historical capture note (root has since restored the current pinned path): the pinned Weston package the native helper expects under `r14/hardware-render/weston` was gone, removed by the 21:43 storage retirement. I fetched the same `weston-15.0.1-3-x86_64.pkg.tar.zst` from archive.archlinux.org. Its sha256 matched the pin and `verify_weston` passed 29 files. I extracted it to my scratch and passed it as `weston_root`, which is why the native runner takes `--weston-root`. Nothing in the helper changed.
- The standard-executor runs used only e98848f9's `tools/momentum-tape.gd` and `.py`, laid over a scratch copy of 367c57fc.
- The executor knows the crouch key as `ctrl`, so the driver presses Control. C is bound to the same action.

## Weaknesses

- No human has played it. Every route proof is a controller, so feel, readability at speed and corner flow are unjudged.
- The crouch line saves 0.49 s for the controller, and only when the crouch jump comes out of a hop and speed is strafed back on top. The taught stop-and-jump line is 1.7 s slower than the walks. The chained variant failed.
- The earned chord's towers are slim (2.9 m tops). At 250 u/s each is a near-maximum jump, so it is a speed line, not an ordinary one. The controller proves it with take-offs at 426 to 458 u/s only.
- The F5 runs follow the same lines as F2 and match them exactly. That shows the map holds on F5 for these lines, not that the profiles always agree.
- The court recovery touches a pavilion arch haunch for one tick.
- The land beyond the course is a flat green slab in a sea plane. From the overview it reads as an island, and the far edge shows from high places.
- Pavilion and tower roofs share the kit's cream palette with the decks, so tops can read flat against each other in full sun.
- The cast-miss rate is 1.5 times Penstock's. The guard covers it.

## Root integration checks (9 November)

The actual current host passes 6990 geometry checks. All ten successful tapes pass the strict executor again: delivery, motor order, rate, neutral input, nested engine logs and cleanup. Finish times, kinds, checkpoints and respawns agree with the worker; every worker-observed tick agrees at its declared sample precision. The executor retains one extra neutral tail tick, with no event edits.

Normal-based contact accounting finds 39 side-contact ticks on the court return, 67 on the cistern return and two on the river-return attempt. The worker's role-tag counter above counts one arch contact; it misses side faces on route/step bodies. A contact tick includes the collision probes and does not alone establish a stall or speed loss.

Root decoded and hashed all seven AMD movies, checked device/kernel and cleanup receipts, matched actor source hashes, and compared every complete finite sequential sample with the corresponding headless replay. Root inspected the raised causeway, actual CROUCH frame, clean finish and checkpoint feedback. The capture helper now uses owned-process cleanup and strict complete-sample comparison; ten direct helper controls pass. These controls did not rerender the game.

Evidence: `checkpoints/spillway/r15/new-map-integration/RESULTS.json`, `native-review/RESULTS.json` and `sunken-owner/`, outside Git. This is source evidence; no exported runtime, Windows, performance or human feel claim.

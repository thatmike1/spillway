# R15 Rainline

An original rainy-night rooftop bhop course, built 8 November 2026. It crosses a tannery
roof, a steel gantry over the first street, the scaffold round a 22 m tower, a lit lamp room,
a cold store with a crouch duct, and a runway to a second street; it ends on the antenna deck
of a communications roof. It is hosted by the actual R15 main as map `rainline` (already in
`r15_maps.gd`) and played by the R15 Source runner with real crouch. The ordinary route needs no crouch; the optional duct requires it.

Integrated into the R15 source host. The map uses the approved runner and shared asset library. Release-pack acceptance remains separate.

## Files

| file | what |
|---|---|
| `scripts/r15_rainline_level.gd` | geometry, progress, routes, gaps, crouch passage, the R14 level interface |
| `scripts/r15_rainline_art.gd` | dressing (night sky, moon, rain, wet surfaces, lit windows, scaffold, streets, skyline, mast, lamps, signs), called from `build()` |
| `tests/test_r15_rainline.gd` | headless interface, geometry, headroom, duct fit, lamp, gap and R15 hosting checks |
| `tests/r15_rainline_driver.gd` | closed-loop route driver on the R15 main and open-loop tape replay (extends `r14_practice_driver.gd`) |
| `tests/r15_rainline_cast_probe.gd` | the R14 cast probe on Rainline's pieces with the R15 runner's standing hull |
| `tests/r15_rainline_views.gd` | ten fixed authored cameras (not the player's) |
| `tests/r15_rainline_native.py` | native AMD/X11 views and player-camera movies, run against an imported scratch copy |

No lab script: the R15 launcher selects the map (`--script res://scripts/r15_launch.gd -- --r15-map=rainline`).
No map-owned assets: everything comes from `assets/r15/library/` and the momentum textures.

## Host interface

`r15_main.gd` with `map_id = "rainline"` builds the level through `r15_maps.gd`; the map
dresses itself from `build()`.

- Identity: `level_id` `r15-rainline`, `level_name` `Rainline`, `level_version` 1, `variant`
  `rainline`.
- Fields: `spawn`, `checkpoints` (pose, title, radius; radius 0 on stages 1 to 4, collected by
  standing on a deck whose `progress_stage` meta matches), `progress_roles` `["route"]`,
  `segment_bounds`, `finish_position`, `finish_title`, `water_regions` (none), `water_audio_sources`
  (street gutters), `routes` (`ordinary`, `duct`, `earned`, plus `basic` and `advanced`
  aliases), `jump_gaps`, `crouch_passages`, `kill_bounds`, `manifest`, `prisms`, `props`.
- Methods: `build()`, `is_finish_at(feet)`, `segment_at(pos)`, `route_hint(stage, feet)`,
  `geometry_hash()`, `geometry_manifest()`, `course_manifest()`, `reset_state()`.
- Geometry hash `c1e006309af68112507d151187a1c0c53247157e0df90ca3523190b62c2e90ab`; record key
  `dc93e4ccffc1b8c7` on `server128`, `c354213915b17324` on `server128_aa1000`. Bump
  `LEVEL_VERSION` with any change to geometry, progress or timing.

## Layout

Forward is -z over the tannery, +x across the gantry, -z down the scaffold's west side, +x along
its south side, +z up its east side, then +z to the finish.

| stage | checkpoint | section |
|---|---|---|
| 0 | Tannery roof, spawn (0, 0, 11) | 32 m of flat roof, then three 1 m terrace steps down to a lower roof at -3 m |
| 1 | Gantry (2, -3, -49) | a steel gantry over the first street with two missing panels (1.6 m and 2.2 m, clear at 110 and 141 u/s), onto the print works roof |
| 2 | Scaffold (27.5, -3, -62) | netted scaffold lifts round the tower: down the west side to -4.5 m, along the south face, back up the east side |
| 3 | Lamp room (51.5, -3, -61) | a warm lit room (3.8 m ceiling). North door into the cold store: right round the plant room (ordinary), or the crouch duct straight under it |
| 4 | Signal runway (52, -3, -29) | a 32 m runway to the second street. Ordinary: the east strip's ramp down to a footbridge, up onto the comms roof, up a ramp to the antenna deck. Earned: jump 8.5 m over the street from the runway lip, 2 m down onto the comms roof |

The finish line crosses the antenna deck short of the mast (z 36).

- Recoveries: any fall from the gantry, the scaffold edges or the runway lip drops into a
  street 15 m down, leaves the kill envelope (y < -9.5) and respawns at the last checkpoint.
  `F` is the main's checkpoint practice.
- Crouch duct: `s3_duct_floor`, 12 m long, 1.6 m clear (between the 1.37 m duck hull and the
  1.83 m standing hull). A sloped hood over its approach falls from 3.35 m to 1.6 m over 6 m, so
  a hop into the duct meets a slope, not a lip. Standing room before and after it, and a jump's
  headroom after it.
- Gaps (`jump_gaps`): gantry_1 and gantry_2 are ordinary. signal_street is `server` tier: an
  8.5 m clear with a 2 m drop, clears at 369 u/s, comfortable at 412.
- Wet roofs are appearance only: no piece sets a physics material, so traction is the
  approved runner's everywhere.
- Collision: every solid is a convex prism or hull. No route piece is longer than 32 m
  (longest 28 m). Decks reach at least 5 m below their tops; the gantry panels, the scaffold
  lifts and the footbridge are the declared thin pieces at 0.8 m. Reachable props have box collision; the
  scaffold frames, boards and poles stand outside the netting or above the headroom and have none.

## Commands

All run from `projects/foldrunner` with the pinned Godot 4.7.2
(`$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`) and `XDG_*`
pointed at scratch. The evidence runs used an rsync copy in `/dev/shm`, so no `.godot/` import
cache was written into git.

```
# play it
godot --path . --script res://scripts/r15_launch.gd -- --r15-map=rainline
# checks (5362 checks, 0 failures)
godot --headless --audio-driver Dummy --path . --script res://tests/test_r15_rainline.gd
# a route: ordinary | duct | earned | gantry_recovery | practice | duct_earned (fails, kept)
godot --headless --audio-driver Dummy --path . --script res://tests/r15_rainline_driver.gd -- --out=DIR --route=ordinary [--preset=server128_aa1000]
# replay a tape open loop
godot --headless --audio-driver Dummy --path . --script res://tests/r15_rainline_driver.gd -- --out=DIR --route=ordinary --tape=events.tape.json [--preset=server128_aa1000]
# tape schema check
python3 -I tools/momentum-tape.py expand events.tape.json
# cast probe
godot --headless --audio-driver Dummy --path . --script res://tests/r15_rainline_cast_probe.gd -- --out=DIR
# native AMD evidence (refuses below 15 GiB free on /home; AVI in /dev/shm)
python3 -I tests/r15_rainline_native.py views --project COPY --evidence DIR
python3 -I tests/r15_rainline_native.py movie --project COPY --evidence DIR --tape TAPE --crf 32 --frames 3,12,22,30,38
```

## Evidence

Under `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/rainline/`, 34 MiB,
from base `367c57fc` with these sources (sha256 prefixes in every `summary.json`): level
`2e66f8b38c5f`, art `b9196ca5e624`, driver `9dcfc5eff4ed`, r15_main `dc5621ffcf08`, r15_maps
`7888262ccf92`, r15_source_player `e06a545d610d`, r14_practice_driver `85cba9a32be7`.

Routes are closed-loop controller runs on the actual R15 main, headless at 128 Hz, from the
main's labelled spawn: after it the driver writes only key edges and mouse counts, never pose,
velocity or progress. Each has `summary.json`, `events.tape.json` and a gzipped trace (raw feet
in `p`, the main's body reference in `ref`, duck compensation in `comp_u`). `replays/` holds
the same tapes played open loop: every shared tick matches in position, velocity, yaw, ground,
duck, checkpoint and respawn count.

| route | preset | result | time | respawns | notes |
|---|---|---|---|---|---|
| ordinary | F2 `server128` | clean | 38.219 s | 0 | max 528 u/s, no wall contact, no contact guard |
| ordinary | F5 `server128_aa1000` | clean | 38.219 s | 0 | identical to F2 tick for tick (below) |
| earned | F2 | clean | 37.070 s | 0 | the street jump at 694 u/s from the round path, max 733 u/s |
| duct | F2 | clean | 43.180 s | 0 | one crouch press and release, both on ground ticks; one blocked stand while still under the lid |
| gantry_recovery | F2 | finished (practice kind) | 45.953 s | 1 | walks off the second gantry gap, falls to the street, respawns at the gantry checkpoint, crosses |
| practice | F2 | finished (practice kind) | 19.391 s from the practice start | 0 | `F` on the east strip: the main's checkpoint practice from the lamp room, then the duct |
| duct_earned | F2 | **failed**: budget, 19 respawns | none | 19 | kept as a recorded attempt (below) |

- `checks/test_r15_rainline.log`: 5362 checks, 0 failures.
- `checks/tape-expand.txt`: `momentum-tape.py expand` passes six tapes; practice fails because
  the strict schema has no key for `F`.
- `checks/cast_probe.json`: route decks 143 misses in about 197,000 casts (0.07%), scattered
  over 17 pieces with no piece above 39; scenery blocks 857; walls and ceilings 63. No final
  route run triggered any contact guard.
- `native/views/`: ten fixed authored cameras on the AMD GPU (not the player's camera).
- `native/movie-{ordinary,gantry_recovery,earned,duct}/`: each tape replayed open loop on the
  actual R15 main from the player's own camera with the HUD, on the private AMD display
  (radeonsi, Compatibility). Each complete native driver sample equals its headless replay, at 0.001 m / 0.001 u/s / 0.000001 rad sample precision. MP4 at
  1280x720, 32 fps, CRF 32, 5.8 to 6.9 MB, and five JPEG frames each. I watched all four.

F2 and F5 agree exactly because at AA 100 the controller's air gain per tick is already capped
by the 30 u/s air wish speed, so AA 1000 adds nothing on this line. The record keys still differ.

## Assets

Nothing new was acquired. Everything is from the shared library (`assets/r15/library/`, CC0,
provenance in its `MANIFEST.json` and `NOTICE.md`) placed through `r15_assets.gd`, plus the
existing momentum textures. Models are drawn as sourced; the scaffold multimeshes take the
map's own steel and board looks over the kit's pale palette.

- Textures (1k diffuse and ARM, world-mapped in one inline shader): `red_brick`,
  `concrete_layers_02`, `brushed_concrete`, `metal_plate_02`.
- Retro Urban: `scaffolding-structure`, `scaffolding-floor`, `scaffolding-poles`,
  `balcony-type-a`, `balcony-ladder-bottom`, `detail-awning-small`, `detail-cables-type-a`,
  `detail-dumpster-closed`, `detail-light-single`, `roof-metal-type-b`.
- Industrial: `building-a/c/e/m/t` (skyline), `chimney-medium`, `detail-tank-large`,
  `shipping-container-a`, `solar-panel-landscape`, `water-tower`.
- Factory: `box-large`, `hopper-square`, `hopper-high-square`, `machine`, `pipe-large-bend`,
  `pipe-large-long`.
- Space: `satelliteDish`, `satelliteDish_large`, `satelliteDish_detailed`, `machine_wireless`,
  `machine_generatorLarge`.
- Train: `train-tram-modern` (two trams in the streets).

## Weaknesses

- No human has played it. Every route proof is a controller, so feel, the first 30 s and
  corner flow are unjudged.
- The ordinary route is 38.2 s for the controller, under the 45 s floor. It strafe-hops at
  339 u/s on average; the line is 333 m, about 52 s at the 250 u/s run speed. Human time is
  unmeasured.
- The duct is a taught crouch line, not a shortcut. From the lamp room it covers the same
  108 m as the ordinary line (the runway sends you back east to the same ramp), and the
  controller is 5 s slower through it.
- The duct does not feed the earned jump. It leaves the runner at 240 u/s; the 32 m runway
  brings the controller to about 412 u/s, and its fit hop to the lip brakes and lands 3.6 m
  short, so the jump falls (`duct_earned`, 19 respawns). The earned jump is proven only from
  the round path, which arrives at 634 u/s.
- The earned line saves the controller 1.15 s (it skips the ramp down, the footbridge and the
  ramp up). It is not shorter in distance.
- F5 is shown on the ordinary route only.
- The practice tape uses `F`, which the strict tape schema rejects. The other six pass.
- The original worker did not run the full standard executor; root has now run the five successful locomotion tapes as described below. `F` remains a separate utility-input proof.
- Night readability: the scaffold walkways still have dark stretches between work lights, and
  on the upper east lift a hung light fills the screen at jump apex. The duct approach under
  the hood is dark until the duct's own lights.
- From high above, rain streaks show as small squares, and splashes read as specks in still
  frames. Only the overview camera sees the first.
- 47 omni lights and about 1400 placed models; frame time is unmeasured.
- `respawn_events` stays empty in open-loop replay summaries. The `respawns` count is right.

## Root integration checks (9 November)

The current host passes 5362 geometry checks. Five successful locomotion tapes now pass the full standard executor: F2 ordinary 38.21875 s, earned 37.0703125 s, duct 43.1796875 s, Gantry return 45.953125 s (practice, one respawn), and F5 ordinary 38.21875 s. Delivery, motor order, rate, neutral input, nested engine logs and cleanup pass. Every worker-observed tick agrees at its declared sample precision; one extra neutral executor tail tick is retained without event edits.

The separate real-input `F` controller run finishes as practice at 19.390625 s, with clean eligibility false and the Lamp room practice event recorded. Its supervisor initially requested a nonexistent `finished` summary key after all actors completed. Root retained that supervisor failure and rejudged the unchanged summary using `reason=finished`, `finish_tick`, kind, eligibility and practice events. No game rerun or tolerance change rescued it.

Root decoded and hashed all four 1280×720 AMD movies, checked device/kernel and cleanup receipts, matched actor source hashes, and compared all complete finite sequential driver samples against their headless replays. Root inspected the lit scaffold, actual CROUCH tag inside the duct, checkpoint return and finish. The native helper now has owned-process cleanup and strict complete-sample comparison, with ten direct helper controls passing. This did not rerender the game or measure frame time.

Evidence: `checkpoints/spillway/r15/new-map-integration/RESULTS.json`, `REJUDGE.json`, `native-review/RESULTS.json` and `rainline-owner/`, outside Git. Source/native evidence does not certify the release pack, Windows, physical latency or feel.

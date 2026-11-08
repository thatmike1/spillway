# R15 Whiteout Relay

An original checkpoint bhop course at a snowbound radar relay station in late-afternoon sun,
built 8 November 2026. It runs out of a warm service hangar, along a berm road, up a pylon
ridge over a catch basin and round a broad half-ring deck circling a big dish pit. From there it
goes through a cable works shed and down the relay road to the relay house. The actual R15 main
hosts it as registry map `whiteout-relay`, and the real crouch runner plays it
(`r15_source_player.gd`, motor `r15-source-crouch-2`). The basic route never needs crouch; one
optional shortcut is a taught duck-jump.

Integrated as the second new R15 course. The map module makes it selectable through the existing registry; main, HUD, presets, motors and the shared asset library are unchanged. Final packed acceptance remains separate.

## Files

| file | what |
|---|---|
| `scripts/r15_whiteout_level.gd` | geometry, collision, progress, routes, gaps, hints and the level interface |
| `scripts/r15_whiteout_art.gd` | dressing called from `build()`: sky, sun, fog, surfaces, mountains, cloud sea, snowfall, lights, labels, placed models |
| `scripts/r15_whiteout_lab.gd` | standalone launcher: the R15 main with `map_id = "whiteout-relay"`, records off |
| `assets/r15/whiteout/` | the extra Poly Haven kit, `MANIFEST.json`, `build_manifest.py`, CC0 text |
| `tests/test_r15_whiteout.gd` | headless interface, geometry, headroom, stair, gantry and R15-hosting checks |
| `tests/r15_whiteout_driver.gd` | closed-loop route driver on the R15 main and open-loop tape replay (extends `r14_practice_driver.gd`) |
| `tests/r15_whiteout_views.gd` | 13 fixed authored cameras (not the player's) |
| `tests/r15_whiteout_native.py` | native AMD/X11 views and player-camera movies |

## Host interface

`r15_maps.gd` already lists `whiteout-relay` as a playable course backed by
`scripts/r15_whiteout_level.gd`; the main loads it from the registry, unchanged.

- Identity: `level_id` `r15-whiteout-relay`, `level_name` `Whiteout Relay`, `level_version`
  1, `variant` `whiteout` (not `course`, so the R14 overflow art pass leaves it alone),
  `finish_title` `Relay house`, `progress_roles` `["route"]`. `--whiteout-neutral` switches
  `material_mode` to `neutral` (grey surfaces, same geometry).
- Fields: `spawn`, `checkpoints` (radius 0 on stages 1 to 4: collected by standing on a deck
  whose `progress_stage` meta matches), `segment_bounds`, `finish_position`, `finish_radius`,
  `water_regions` (empty), `water_audio_sources`, `routes`, `jump_gaps`, `kill_bounds`,
  `manifest`.
- Methods: `build()`, `is_finish_at(feet)`, `segment_at(pos)`, `route_hint(stage, feet)`,
  `geometry_hash()`, `geometry_manifest()`, `course_manifest()`, `reset_state()`,
  `start_wheel()`.
- Every body has a stable name, a `surface` meta equal to its manifest role (`route`, `catch`,
  `recovery`, `wall`, `scenery`) and a `progress_stage` meta (-1 off the route).
- Geometry hash `bc8cb15c21ecad7efb702ff21f70431db28d350e031461849efb1e915267bfef`; course key
  `4b84f6b1caaea0b6` on `server128`, `68f7633c39ffb60b` on `server128_aa1000`. Bump
  `LEVEL_VERSION` with any change to geometry, progress or timing.

## Layout

Forward is -z from the hangar, round the receiver half ring, then +z back along x 45.

| stage | checkpoint | section |
|---|---|---|
| 0 | Hangar (0, 0, 8) | enclosed warm service hangar, apron, then the berm road: two 0.55 m cable-tray hurdles and two shallow cable trenches (2 m and 3 m) that you can jump out of |
| 1 | Ridge (0, 0, -115) | ridge foot, then four pylon tops climbing 0.4 m each in a zigzag (gaps 2.1 to 3.1 m) over a snow catch basin 3.8 m down, onto the saddle |
| 2 | Saddle (0, 2, -165.5) | decision point. Left: the walled service catwalk round the chasm (ordinary). Ahead: the 6.5 m chasm, 1 m down onto the receiver deck (earned) |
| 3 | Receiver deck (ring r 23 at 8 degrees) | a 14 m wide half ring (r 16 to 30) round the dish pit, pit wall 2.2 m, outer edge open to the cloud |
| 4 | Cable works (46.5, 1, -180.5) | shed floor weaving east-west-east round three blocks of cable drums. Optional: the 1.5 m gantry along the west wall (duck-jump). Then the relay road over a 3 m cable cut, two 0.8 m terraces up to the relay house porch; the finish box is z -82 to -76 |

Declared gaps (`jump_gaps`): the trenches, the five pylon hops and the cable cut are
`vanilla_run` (clear at 130 to 202 u/s, comfortable at 236 or less), so there is no
first-minute 250 u/s trap. The chasm is `vanilla_strafe`: it clears at 317 u/s and is
comfortable at 359, beyond any run-speed jump.

Recovery:

- A trench or the cable cut: 0.9 m and 1.2 m deep, so you jump straight back out.
- The basin: a missed pylon lands on snow 3.8 m down. A lit nine-step stair on the east side
  (each rise under 18 u) walks back to the ridge foot, with no respawn.
- The saddle, catwalk, chasm and the deck's open outer edge drop into the cloud sea. Below
  y -6 the main respawns the runner at the last checkpoint ("practice" for that run).

Crouch shortcut: the gantry top is 1.5 m (59.1 u), between the measured standing-jump peak
(55.87 u) and jump-then-crouch peak (64.87 u). The face carries the label
"DUCK-JUMP / jump, then / crouch (C)". The shed roof is 4.5 m above the gantry top, so you can
stand up anywhere on it; the far end steps back down to the shed floor. Crouch is optional
everywhere.

Snow is appearance only: no body carries a physics material, and every surface moves with
the approved settings.

Collision: every solid is a convex prism (the drums are 16-sided prisms, the reachable
generators use their measured model bounds). No walkable piece is longer than 32 m (longest
28.0 m). Every walkable piece is at least 0.9 m deep: the pylon tops are the thinnest, and
everything else is 1.05 m or more. No solid hangs lower over a deck than a standing hull plus
a jump. Visible snow beside reachable tops is either collidable or sits far below the kill
plane's reach.

## Commands

All run from `projects/foldrunner` with the pinned Godot 4.7.2
(`$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`) and `XDG_*`
pointed at scratch. I ran them from a tmpfs copy of the project so the import cache stayed
off HOME.

```
# play it
godot --path . --script res://scripts/r15_whiteout_lab.gd [-- --r15-preset=server128_aa1000]
# checks (2382 checks, 0 failures)
godot --headless --audio-driver Dummy --path . --script res://tests/test_r15_whiteout.gd
# a route: ordinary | earned | gantry | basin_recovery | cloud_recovery
godot --headless --fixed-fps 128 --audio-driver Dummy --path . --script res://tests/r15_whiteout_driver.gd -- --out=DIR --route=ordinary [--preset=server128_aa1000]
# replay a tape open loop
godot --headless --fixed-fps 128 --audio-driver Dummy --path . --script res://tests/r15_whiteout_driver.gd -- --out=DIR --tape=events.tape.json
# native AMD evidence (refuses below 15 GiB free on /home; AVI in /dev/shm)
python3 -I tests/r15_whiteout_native.py views --evidence DIR [--weston-root DIR]
python3 -I tests/r15_whiteout_native.py movie --evidence DIR --tape TAPE --frames 3,12,20 [--weston-root DIR]
# rebuild the asset manifest from the saved api records
python3 -I assets/r15/whiteout/build_manifest.py --api DIR
```

`--weston-root` points the private display helper at an extracted pinned Weston. I needed it
because `r14/hardware-render` was gone from the outer checkpoints (see Weaknesses).

## Evidence

Under `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/whiteout/`,
under 50 MiB.

`routes/<case>/` holds closed-loop controller runs on the actual R15 main, headless at 128 Hz
from the labelled hangar spawn. Each has `summary.json` (preset, motor version, the air
settings in force, radians per count, sensitivity 2.5, record key, source sha256s, checkpoint
times, ducks), `events.tape.json` and a gzipped trace. The tape is version 2: key edges
(w a s d space ctrl) and mouse counts only, with no top-level `radians_per_count`, and every
one passes `tools/momentum-tape.py expand`. Each trace row keeps raw feet (`p`), the runner's
cumulative duck compensation (`comp`, u) and the main's body reference (`ref`) apart.

| preset | route | outcome | time | notes |
|---|---|---|---|---|
| F2 server128 | ordinary | clean | 62.30 s | catwalk; max 331 u/s; checkpoints 18.84 / 26.91 / 37.26 / 45.48 s |
| F2 server128 | earned | clean | 51.45 s | strafed pylons, two line-up hops on the saddle, chasm at 357 u/s, receiver deck at 429; max 486 u/s |
| F2 server128 | gantry | clean | 61.98 s | duck-jump 2.78 m before the face at 250 u/s, Ctrl held in flight, lands on the gantry |
| F2 server128 | basin_recovery | clean | 71.38 s | deliberately short off pylon 1 into the basin, walks the stair, no respawn |
| F2 server128 | cloud_recovery | practice | 67.72 s | runs off the deck's open edge; 1 respawn at Receiver deck |
| F5 server128_aa1000 | ordinary | clean | 62.30 s | identical trace to F2 |
| F5 server128_aa1000 | earned | clean | 51.45 s | identical trace to F2 |

All runs: 0 contacts with bodies tagged `surface=wall`; this inherited driver counter does not count a route platform’s vertical face. Root’s normal-based audit finds 10 side-contact ticks on `basin_recovery` against pylon 2 during the deliberate miss, and none on the other six tapes. No route except gantry presses crouch, so none of them has an
air duck. The F5 summaries record `sv_airaccelerate` 1000 against 100 on F2. The traces are
still identical, because the controller's strafe meets the 30 u/s air wish cap on every air tick
under either setting.

`routes/replay-ordinary` and `routes/replay-f5-earned` are retained open-loop worker attempts. The second directory is named for the F5 tape, but its summary says `server128`, so it is not an F5 runtime proof. Root separately replayed both F5 tapes with the actual AA1000 settings through the standard executor (below).

`native/<case>/` holds `movie.mp4`, JPEG frames and logs for each case. The tapes are replayed
open loop through the same driver on the actual R15 main, from the player's own camera with the
HUD. They were rendered on the private Weston/Xwayland display with Mesa radeonsi (renoir)
through Compatibility, and each native trace matches a headless replay of the same tape tick for
tick. I inspected the frames:

- `ordinary`: hangar door, the berm road and hurdles, the Ridge banner over the pylons, the
  receiver deck.
- `earned`: the saddle lip and its hazard band at 349 u/s, then the receiver deck landing at
  429 u/s.
- `cloud_recovery`: the fall off the open edge over the cloud sea, then "PRACTICE (respawned)"
  back on the receiver deck.
- `basin_recovery`: the snow catch basin and the return stair.
- `gantry`: the crouch indicator on, over the drums along the gantry inside the shed.

`gantry` was rendered from the final sources. `ordinary`, `earned`, `basin_recovery`,
`cloud_recovery` and `views/` came from the sources just before three edits that move
nothing: a comment in the level, the gantry face label's wrap and size, and the driver's
crouch key name (`c` to `ctrl`, which only the gantry route presses) plus two summary fields.
The final sources reproduce those four tapes event for event and their traces byte for byte
(`routes/`).

`views/` holds the 13 fixed authored cameras. They are art and readability frames only, not
the player's view.

`checks/` holds the test log and the tape schema result. `provenance/` holds the Poly Haven API records and URL list that
`build_manifest.py` needs.

## Assets

Extra kit: Poly Haven, CC0-1.0, from the primary publisher. 3 assets, 8,858,926 bytes
(8.45 MiB). Every file is the unmodified upstream download. Its md5 was checked against the
API at download and again by `build_manifest.py`, and `MANIFEST.json` records sha256, URL,
authors, use and in-game changes.

- `corrugated_iron_02` (1k diffuse, normal GL, ARM): cladding of the hangar, cable works shed,
  shelters and relay house, tinted oxide red, signal orange and slate in the shader.
- `metal_plate` (1k): the tread on every route deck, dark against the snow.
- `qwantani_late_afternoon_puresky` (2k HDR): the sky panorama. Its sun sits about 19 degrees
  up, and the scene sun is lit from the same bearing and height.

From the shared library, placed through `scripts/r15_assets.gd`: Kenney Space Kit (dishes,
hangars, generators, wireless machine, supports), Kenney Nature Kit (pines, tall rocks) and
Poly Haven Snow 02 maps. Their provenance is the library's `MANIFEST.json`. Four placed
machines are reachable and get collision from their measured bounds. Every other model is out
of reach.

## Weaknesses

- No human has played it. Every route is a controller run; I make no claim about feel, the
  first minute or corner flow.
- The gantry shortcut saves the controller 0.31 s (61.98 against 62.30 s). It teaches the
  duck-jump more than it pays.
- I shortened the chasm from 7.5 to 6.5 m to make the earned line provable. It is now
  `vanilla_strafe` tier (clears at 317 u/s, comfortable at 359), not `server` tier. The
  earned line still saves about 11 s.
- F5 is verified, but it does not exercise a difference from F2 on these routes (see above).
- The dish in the receiver pit shows a large dark backside from the start of the deck. The
  corrugated shed walls shimmer (moire) at grazing angles. The mountains are flat-shaded
  low-poly facets, which is a different look from the scanned textures.
- No cast probe was run for this map. Every walkable piece is at least 0.9 m deep.
- The art pass adds about 320 ms to level load (headless).
- Root's storage retirement deleted `r14/hardware-render`, which held the pinned Weston that
  `tools/r14_native_display.py` uses by default. I fetched the official Arch
  `weston-15.0.1-3-x86_64.pkg.tar.zst` from archive.archlinux.org into scratch. Its sha256
  (92fe0bfe...) matches the pin, and `verify_weston` passed all 29 files. I passed it with
  `--weston-root`, an option of this map's native script only. That scratch copy was deleted. Root has since restored the identical pinned default package and verified all executable/library files; `whiteout-integration/WESTON.json` records the current check. This blocker is closed.

## Returned worker source hashes (sha256)

```
9af9d87e5d54d6585175900fb3c750c426de8e20c19c0c24196234290acdafa2  scripts/r15_whiteout_level.gd
26c5ec62e472e24f9963e7f3e617d26089ad9d47860ab0f5a12c54c76f7620e1  scripts/r15_whiteout_art.gd
f55f229e1e7e6eada1e32ce766743b4a7be01e6cb06534d9703bc275a13f57f3  scripts/r15_whiteout_lab.gd
f27993a5a4a1758529aa61c312058d9aa84ff9a4363df7067b3c9cdf4daf85ac  tests/r15_whiteout_driver.gd
189b3fa4d3f081faeef78952aa3ae72ba8e077c62678cc4002cfe6937319d25d  tests/r15_whiteout_views.gd
fe13d55e9dc6651219306f96eea56931ff9984eb37b2d168dfe6511048670da6  tests/r15_whiteout_native.py
ca1b70dbbfbba2785942cf49a2d62d457debb040dd4f5c4000c1d9df0e54aa97  tests/test_r15_whiteout.gd
f9fa092fd2a70aa92fabf5b9af3feec818cfa1428495eb8c2a8164123e9e3ef1  assets/r15/whiteout/build_manifest.py
daaa95f650448588bfeb26c62e47e850234e18ece9f8dfcb795aa0e76ea9945a  assets/r15/whiteout/MANIFEST.json
```

Unchanged shared files they ran against (base 367c57fc): `r15_main.gd` dc5621ff,
`r15_presets.gd` 44a70c76, `r15_maps.gd` 7888262c, `r15_source_player.gd` e06a545d,
`r15_assets.gd` 9842f654, `r14_practice_driver.gd` 85cba9a3, `r14_native_display.py`
7a6f6cae.

## Root integration and current source evidence

Outer `checkpoints/spillway/r15/whiteout-integration/RESULTS.json` records fresh standard-executor replays through the actual named R15 map, with the approved crouch motor 2, sensitivity 2.5, warmup 33 and 128 Hz. All seven tapes pass delivery, rate, ordering, neutral input, cleanup and nested engine-log checks. Ordinary and earned finish at 62.296875 and 51.4453125 s under both actual F2/AA100 and F5/AA1000 settings. Gantry is 61.984375 s; the basin return is 71.3828125 s clean; cloud recovery is 67.71875 s practice with one respawn. The 55,298 executor ticks are retained in full-precision compressed traces.

The worker’s custom samples round position to 0.001 m, velocity to 0.001 u/s and yaw to 1e-6 rad. Every recorded worker sample agrees within that quantization; this is not unrounded equality. Each tape also declares one extra neutral tail tick after the custom driver stops sampling. Root retains and checks that tick separately, with no new input and the same finished game state, rather than trimming or retiming the tape. The gantry replay has one independently observed airborne hull-origin transition. Geometry/interface checks pass 2382/2382. The current R15 lifecycle suite passes 183 checks and exactly its five intentional refusal errors; the denominator varies with which planned modules now exist.

`upstream/RESULTS.json` matches all seven new source files’ exact URL, size andMD5 tuples against freshly fetched primary Poly Haven API records, as well as local SHA-256/MD5/size checks. `native-review/RESULTS.json` independently verifies the five retained MP4 hashes, 1280×720 dimensions, complete decode and retained AMD/kernel/cleanup evidence. Root inspected the hangar, chasm approach, crouched gantry, finish card and recovery views. Four movies precede the harmless comment/label edits described above; none is a final exported-pack proof.

Root’s first comparison incorrectly expected the custom driver to include the tape’s extra tail sample. The next supervisor attempt reused a lifecycle fixture profile, producing 18 persistence-only fixture failures. Both attempts remain labelled in `ROOT-NOTES.txt`/`ATTEMPT1.json`/`ATTEMPT2.json`; a fresh profile passes and no actor events or physics changed. This is supervisor correction, not a game repair.

The returned native helper had timeout-only engine ownership and a narrow vector comparison. Root changed only that helper to reuse the checked process-group owner and compare complete finite samples. The generic helper controls now pass 10/10 for both Whiteout and Breakwater: identical/missing/changed/malformed traces, normal exit, deadline and wrapper-only SIGINT/SIGTERM cleanup. The existing movies used the older helper; these controls do not claim a new renderer run. Human feel, first-run discovery, final packed play and native Windows remain unverified.

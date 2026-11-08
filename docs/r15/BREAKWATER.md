# R15 Breakwater

The first R15 map slice: an original dusk container-port bhop course, built 8 November 2026.
It runs through a container yard, past a crane-line quay and out along a breakwater to a
lighthouse. It is the default named map in the actual R15 host, played by the real crouch runner. No part of the basic route needs crouch.

## Files

| file | what |
|---|---|
| `scripts/r15_breakwater_level.gd` | geometry, progress, routes, gaps, the common level interface |
| `scripts/r15_breakwater_art.gd` | dressing (sky, sun, water, surfaces, containers, scenery, props, labels), called from `build()` |
| `scripts/r15_breakwater_lab.gd` | standalone launcher: real R15 main on the named map |
| `assets/r15/breakwater/` | sourced kit, `MANIFEST.json`, `build_manifest.py`, CC0 text |
| `tests/test_r15_breakwater.gd` | headless interface, geometry, headroom and hosting checks |
| `tests/r15_breakwater_driver.gd` | closed-loop route driver and open-loop tape replay (extends `r14_practice_driver.gd`) |
| `tests/r15_breakwater_cast_probe.gd` | the R14 cast probe pointed at Breakwater |
| `tests/r15_breakwater_views.gd` | nine fixed authored cameras (not the player's) |
| `tests/r15_breakwater_native.py` | native AMD/X11 views and player-camera movies |

## Host interface

The R15 main selects `map_id = "breakwater"`: 5 stages, default preset `server128`.
The map also implements the common level interface for labelled fixture hosts.

- Identity: `level_id` `r15-breakwater`, `level_name` `Breakwater`, `level_version` 1,
  `variant` `breakwater`, `material_mode` `kit`. The variant is deliberately not `course`:
  `momentum_overflow_art` dresses any `course` level, and Penstock's readability pass keys
  on its own script, so neither touches this map. The map dresses itself.
- Fields: `spawn`, `checkpoints` (pose, title, radius; radius 0 on stages 1 to 4, collected
  by standing on a deck whose `progress_stage` meta matches), `segment_bounds`,
  `finish_position`, `finish_radius` 4, `finish_title` `Lighthouse`, `water_regions`,
  `water_audio_sources`, `routes`, `jump_gaps`, `kill_bounds`, `manifest`.
- Methods: `build()`, `is_finish_at(feet)`, `segment_at(pos)`, `route_hint(stage, feet)`,
  `geometry_hash()`, `geometry_manifest()`, `course_manifest()`, `reset_state()`,
  `start_wheel()`.
- Geometry hash `231b7675ad7dde95f4cf9afbf5a2a25eadf400fc08d232d522a6a7c8952058d3`; course
  key on the current R15 `server128` runner `63f231d3f9641506` (the worker's earlier R14-host key was `70fd0c2f3938bc78`). Bump `LEVEL_VERSION` with any change to geometry,
  progress or timing.

## Layout

Forward is -z through the yard, -x along the quay, then -z out along the breakwater.

| stage | checkpoint | section |
|---|---|---|
| 0 | Gate (0, 0, 4) | gate deck under the gatehouse canopy, 17 m wide, broad and flat |
| 1 | Box rows (-1, 0, -22) | four blocks of container roofs over the yard alleys, gaps 2.0, 2.5, 3.0, 3.5 m, the last block offset left; a 3.0 m hop onto the quay corner |
| 2 | Crane line (ring point) | a walled left bend, a 40 m quay under two ship-to-shore cranes with a two-stack chicane (8 m passages), a right bend whose inside edge is open harbour |
| 3 | Breakwater (-75, 0, -111) | 128 m pale runway in four 32 m pieces beside a 2.2 m crown wall marked every 16 m |
| 4 | The breach (-75, 0, -207) | an 8.5 m gap with a 1 m drop onto the lighthouse roundhead (earned), or a 3.5 m gangway on the harbour side (ordinary); finish band on the lighthouse's seaward side |

Recoveries: a missed box-rows jump lands in an asphalt alley 2.6 m down, which walks back up the
return ramp along the gate's right column. Any fall into the harbour leaves the kill envelope
(y < -3.3) and respawns at the last checkpoint. That is the only use of the kill envelope.

Declared gaps (`jump_gaps`): block_1 to block_4 and block_to_quay are `vanilla_run` (clear at
130 to 209 u/s). The breach is `server` tier: clears at 408 u/s, comfortable at 461.

Collision: every solid is a convex prism. No walkable piece is longer than 32 m (longest
32.000 m). Decks reach at least 5 m below their tops and alley catches 2.5 m; the gangway and
its parapet are the declared thin pieces at 0.6 m. The crane legs and the ship hull are
scenery bodies (`scenery_crane_*`, `scenery_ship_hull`). Nothing hangs lower over a deck than
a standing hull plus a jump.

## Commands

All run from `projects/foldrunner` with the pinned Godot 4.7.2
(`$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`) and `XDG_*`
pointed at scratch.

```
# play it
godot --path . --script res://scripts/r15_breakwater_lab.gd [-- --r15-preset=server128_aa1000]
# checks (1712 checks, 0 failures)
godot --headless --audio-driver Dummy --path . --script res://tests/test_r15_breakwater.gd
# a route: ordinary | earned | earned_lip | alley_recovery | harbour_recovery
godot --headless --audio-driver Dummy --path . --script res://tests/r15_breakwater_driver.gd -- --out=DIR --route=ordinary [--preset=server128_aa1000]
# replay a tape open loop
godot --headless --audio-driver Dummy --path . --script res://tests/r15_breakwater_driver.gd -- --out=DIR --tape=events.tape.json
# cast probe
godot --headless --audio-driver Dummy --path . --script res://tests/r15_breakwater_cast_probe.gd -- --out=DIR
# native AMD evidence (refuses below 15 GiB free on /home; AVI in /dev/shm)
python3 -I tests/r15_breakwater_native.py views --evidence DIR
python3 -I tests/r15_breakwater_native.py movie --evidence DIR --tape TAPE --frames 3,9,16
# rebuild the asset manifest from the saved api records
python3 -I assets/r15/breakwater/build_manifest.py --api DIR
```

## Evidence

Under `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/breakwater/`, 26 MiB.

The original worker routes below are closed-loop controller runs in a labelled R14 host, headless at 128 Hz. Each one has its
`summary.json`, its `events.tape.json` (key edges and mouse counts after the labelled spawn)
and a gzipped trace.

| preset | route | outcome | time | notes |
|---|---|---|---|---|
| F2 server128 | ordinary | clean | 44.60 s | gangway; max 360 u/s; checkpoints 5.74 / 12.27 / 24.99 / 35.45 s |
| F2 server128 | earned | clean | 35.82 s | breach jumped at about 755 u/s; max 895 u/s |
| F2 server128 | alley_recovery | clean | 55.48 s | deliberate box-rows miss, walks back up the ramp, no respawn |
| F2 server128 | harbour_recovery | practice | 58.64 s | deliberately leaves bend two into the harbour; 1 respawn at Crane line |
| F5 server128_aa1000 | ordinary | clean | 44.60 s | same ordinary line as F2; not a claim that the profiles always agree |
| F5 server128_aa1000 | earned | **failed** | budget | reaches 899 u/s, falls short of the breach 23 times |
| F5 server128_aa1000 | earned_lip | **failed** | budget | later takeoff variant, 7 respawns |

The successful runs have zero wall-contact ticks and no recorded sinks. The F5 earned failure is the inherited
controller, not shown to be the map. Its fitted hop brakes in the air and takes off about 6 m
early at 498 u/s, so it lands about 2 m short. I did not tune it further, so the breach on F5
is unproven either way.

Native player-camera movies (`native/<case>/movie.mp4` plus JPEG frames) replay those tapes
open loop on the actual R14 main with the HUD, on the private AMD display. They were rendered
on Mesa radeonsi (renoir) through Compatibility, and each native trace matches its headless
replay tick for tick.

- `server128-ordinary`: clean 44.60 s
- `server128-harbour_recovery`: the fall at bend two, "Back to Crane line · practice", then on
  to the finish
- `server128-earned`: the breach jump

`views/` holds the nine fixed authored cameras. They are art and readability frames only, not
the player's view.

`checks/` holds the test log and both cast-probe results. Breakwater missed 487 of 213,642
casts (0.228%), against Penstock's 300 of 195,480 (0.154%) under the same probe. The misses
include container roofs. Every walkable piece is at least 0.6 m deep against a drop of at most
6 cm per tick, so the approved end-overlap guard can catch every one. Higher than Penstock, but
in the same class.

`provenance/` holds the Poly Haven API records and download log that `build_manifest.py`
needs, plus the fetch script.

## Assets

Poly Haven only, CC0-1.0, from the primary publisher. They are scanned PBR to match the existing
momentum kit. The Kenney packs from the separate research are a fallback I did not use: their
low-poly look would clash with the scanned kit. 15 assets, 61 files, 32.54 MiB, all
byte-identical to the upstream downloads. The md5 of each file was checked against the API at
download, and the sha256 is recorded in `MANIFEST.json` with URL, authors, use and in-game
changes. Every change is in shaders and placement, never in the files.

- Textures (1k diffuse, normal GL, ARM): `container_side` (all containers, re-tinted in six
  paints), `box_profile_metal_sheet` (cladding), `rusty_painted_metal` (cranes, ship, frames,
  posts), `asphalt_02` (alleys, crane line, bends, apron), `square_concrete_pavers` (gate deck,
  runway, roundhead), `white_plaster_rough_02` (lighthouse).
- Models (1k glTF): `lateral_sea_marker`, `ocean_buoy`, `lifebuoy`, `old_tyre`,
  `street_lamp_02`, `Barrel_01`, `rollershutter_door` (graffiti node hidden),
  `concrete_road_barrier`. All are out of reach and have no collision.
- Sky: `industrial_sunset_02_puresky` 2k HDR at energy 0.55. The HDR's own sun is about
  2 degrees up. The scene sun is lit at about 9 degrees from the same bearing, so decks still
  read.
- The gangway uses the existing momentum kit's `metal_plate_02`, and walls and crown use its
  `concrete_layers_02`.

## Weaknesses

- No human has played it. Every route proof is a controller, so feel, the first 30 s and
  corner flow are unjudged.
- The ordinary route is 44.6 s for the controller, just under the 45 to 90 s target. Human completion time is unmeasured; the course is on the short side.
- The F5 breach is unproven (see above). The earned line is shown on F2 only.
- The cast-miss rate is 1.5 times Penstock's. The guard covers it, but it is still the highest
  measured.
- The crane line reads darkish under the cranes, and the far land is a flat slab with simple
  boxes.
- The lighthouse beam is a plain additive cone, and the lamp heads on the crown poles are small
  and read as floating from a distance.
- The tyre fenders sit on the quay and breakwater faces below the deck edge with no collision.
  They are cosmetic, and inside the respawn band.
- Box-rows gaps are all vanilla tier. The challenge sits in the bends, the chicane and the
  breach.
- The art pass adds about 650 ms to level load (headless).
- The `respawn_events` list stays empty in open-loop replay summaries. The `respawns` count
  is right (1 on harbour_recovery), and the closed-loop summary lists the event.

## Root integration

Root verified every one of the 61 upstream file MD5s and SHA-256s before copying the 15-asset kit, reran the 1712 geometry/interface checks in a fresh source/import/profile copy, and exercised the real R15 default/registry groups (32 checks, zero failures). The R15 host selects Breakwater automatically, so `project.godot` now launches `scenes/r15.tscn`. Root inspected the worker's ordinary-route, runway and breach native frames. Receipt: outer `checkpoints/spillway/r15/breakwater-integration/`.

The worker's routes and AMD movies above use its labelled R14 host. Root has now replayed all five retained successful tapes through the actual R15 named-map main and motor version 2. Ordinary F2/F5, F2 earned, physical alley return and harbour checkpoint respawn retain their exact finish times and outcomes. Source evidence: outer `checkpoints/spillway/r15/breakwater-r15-host/final-port/RESULTS.json`.

All five also run through the strict standard executor: 30,952 ticks, correct rate and delivered events, no engine warnings/errors or integrity flags, neutral input and clean process cleanup. The harbour run deliberately respawns at tick 3075; the evaluator excludes that row from its counter-verified total, while the raw counter still advances once on every tick. The custom driver's position, velocity and yaw samples are rounded, so cross-tool agreement is checked within their documented half-quantum after reproducing float32 unit division. This is not an unrounded bit-identity claim.

The old driver added an unsupported top-level `radians_per_count` annotation. The new exporter puts look information in `description`; root's normalized input copies remove only that extra annotation and preserve every event, tick and rate. The actual Source sensitivity is 2.5, not the old approved-golden override of 5.7296. Header normalization and source hashes are recorded beside the runs. Both early audit assertion failures are retained and explained; no actor was changed to repair them.

Native R15 views, independent contact/discovery review and final packed acceptance remain pending. The AA1000 earned attempt remains failed, not promoted as a pass.

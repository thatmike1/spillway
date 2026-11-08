# R14 practice map: Penstock Yard

An original bhop and air-strafe training course on the bench beside the dam, separate from
Overflow. Version 3 (`LEVEL_VERSION := 3`, geometry hash `8475d8a82763…`, 141 pieces) is
proven with the R14 Source runner at both presets from the normal spawn with real A/D input,
and keeps R13 as a playable comparison.

Files: `scripts/r14_practice_level.gd` (level), `scripts/r14_practice_lab.gd` (standalone lab),
`tests/test_r14_practice_level.gd` (geometry and interface), `tests/r14_practice_driver.gd`
(closed-loop driver and open-loop tape replay), `tests/r14_practice_perturb.py` (tape
perturbation), `tests/r14_practice_cast_probe.gd` (floor cast diagnostic),
`tests/r14_practice_seam_probe.gd` (runway seams under key input),
`tests/r14_practice_overview.gd` (stills).
Evidence: `checkpoints/spillway/r14/practice-source/` (`EVIDENCE.md` there lists every run).

## Versions

- **1**: runway first, then stop logs, valve bend, weir, pump bend, tail race. The first
  Source runs (trial 1) showed the order was wrong: the server preset reached 899 u/s at the
  runway's end and had to walk it off before 3 m blocks, and both presets fell short at zig
  block 7 (a 1.6 m deck after a corner landing).
- **2**: course order gatehouse (20 m run-in) → stop logs → valve bend → runway → weir gauges →
  pump bend → tail race, so speed is built where it is spent. Stop-log decks 4.5 m (4 m zig),
  valve bend r 10-26 with islands [0,26] [42,58] [68,90] (the second gap 10°, so its outside
  is a 4 m rhythm gap, declared basic), runway 128 m along -x, weir middle deck lengthened 18 m
  so a fast line can re-phase between g1 and g2 (trial 8 clipped the north wall on the old
  diagonal), ring pieces cut every 10° and at each island or notch edge so neighbours share
  chords (this closed a pit sliver).
- **3**: the runway's collision is four coplanar 32 m prisms on exact shared edges, its two
  training walls split at the same seams. Walk and runway dimensions, marks and labels are
  unchanged. Reason: Godot 4.7.2 motion casts miss some diagonal landings on long convex
  prisms (below).

## Units and gaps

1 u = 0.0254 m. Vanilla CS:GO figures: 250 u/s run, 301.993 u/s jump, gravity 800 u/s²,
flat jump 0.755 s. Gap figures are screening arithmetic, feet centre to feet centre with no
hull credit and a 0.5 m landing margin; the runs below are the proof.

| gap | line | m / u | drop m | clears u/s | intended u/s | tier |
|---|---|---|---|---|---|---|
| block 1-5 | basic | 2.0 / 2.5 / 3.0 / 3.5 / 4.0 | 0 | 130-235 | 250 | vanilla_run (block 5 tight) |
| block 6, zig 7-8 | basic | 2.50, 2.69 | 0 | 156, 166 | 250 | vanilla_run |
| block to bend | basic | 3.00 | 0 | 183 | 250 | vanilla_run |
| bend 1 / 2 inside | basic | 3.34 / 2.09 | 0 | 200 / 135 | 250 | vanilla_run |
| bend 1 outside | advanced | 6.40 / 252 | 0 | 360 | 420 | server |
| bend 2 outside | basic | 4.01 / 158 | 0 | 235 | 250 | vanilla_run_tight |
| g1 north / south | basic / advanced | 3.31 / 7.69 | 0 | 199 / 427 | 250 / 540 | vanilla_run / server |
| g2 south / north | basic / advanced | 3.56 / 11.44 | 0 | 212 / 623 | 250 / 720 | vanilla_run / fast |
| notch middle / outer | advanced | 8.28 / 10.09 | 0 | 458 / 552 | 580 / 680 | server / fast |
| g3 east / west | basic / advanced | 4.16 / 13.34 | 1.5 | 200 / 595 | 250 / 700 | vanilla_run / fast |

Gauge edges are slanted, so a gauge's width depends on where the line crosses it.

## Results (v3, repaired Source f0e4b6c7)

Player `a8fc4873…`, motion `6c529b2c…`. Closed loop: the driver reads state to choose real
key and mouse events (W on the ground only, A/D with the mouse at the best wish angle in the
air, W released in the air, space held on autohop or pressed per landing on vanilla, a 600°/s
turn cap). It never writes pose, velocity, camera or progress after setup. Every run starts at
the normal spawn; 0 respawns and 0 wall-contact ticks in every run.

| run | result |
|---|---|
| server basic | clean 56.328 s |
| vanilla basic | clean 57.719 s |
| R13 basic (stand-in policy, not Source) | clean 42.875 s |
| server advanced | clean 28.609 s, max 1100 u/s |
| vanilla advanced attempt | falls into the valve bend pit at bend 1 outside (records the limit) |
| block miss, both presets | block 4 pressed early, pit, walk the return lane and ramp back to the run-in, blocks 1-5 again |
| g1 miss, both presets | g1 south at run speed, pit, south lane and ramp back, then g1 north |
| g3 miss, both presets | g3 west at run speed, tail pit, lane and ramp, then g3 east and the finish (server 67.008 s, vanilla 68.406 s) |

Server advanced, flight by flight (support piece to support piece): bend 1 outside 6.4 m at
364 → 454 u/s, bend 2 outside at 454 → 524, runway hops across all three seams at 728, 837 and
933 u/s, g1 south (about 7.6 m where it crosses) at 937, g2 near the north end (about 9.1 m)
at 974, the pump bend's inside band at 1016, g3 (about 8.1 m where it crosses, 1.5 m down) in a
23.6 m flight at 1057 → 1100 u/s. Every gap's speed is earned from input on the course.

### Limits of what is proven

- **Vanilla has no advanced line.** Ground speed clamps at 250 u/s and take-off at 275 u/s;
  the best attempt took off at 247 u/s, strafed to 305 u/s in the air and landed 0.7 m short of
  bend 1 outside (about 5.9 m of flight past the hull asked, about 5.3 m reachable). Every other
  advanced gap asks 540-720 u/s. Whether that split suits the vanilla preset is a design call:
  the stamina and clamp fit is unresolved, and no high-speed vanilla chain is claimed.
- **The notch line is unproven.** The advanced route takes the pump bend's inside band; the
  notch (8.3-10.1 m) has had no clean run.
- The bend 2 outside and some gauge landings are hull-edge landings: legal in Source (any box
  overlap holds), but tight.

## Tapes

Every driver run writes a version 2 momentum tape at the native rate (128 Hz server, 64 Hz
vanilla, never relabelled 120) with full-precision applied events and integer header and tick
fields. The driver's `--tape=` replays one open loop. `momentum-tape.py run` replays agree with
the driver on all six checked tapes (both bases): velocity within 0.0005 u/s, yaw within
5e-7 rad, grounded state identical every tick, same jump count, positions within the driver
trace's 0.5 mm rounding.

The executor arms on the first process frame at or after `--warmup` steps under its
`--fixed-fps 30`: tick 0 lands one step later at 128 Hz (step 33) than at 64 Hz (step 32). The
driver's default warmup matches it per rate (`EXECUTOR_ARM_STEP`). Off by one, the resting
hull's 2 mm ground bob starts in the other phase and replays drift by millimetres (up to 0.33 m
on one tick at a slanted edge on the pre-repair base).

### Perturbation (open loop, no feedback)

`r14_practice_perturb.py` moves every space edge ±1/±2 ticks, every A/D edge ±1/±2, jitters
every key edge by -1/0/+1 (3 seeds), scales mouse counts 0.95/1.05, and adds 3% plus 0.02-count
mouse noise (3 seeds). Each variant is replayed open loop. It survives only when it finishes
clean with no pit, return lane or wall contact.

| tape | survives |
|---|---|
| server basic | space -1 |
| vanilla basic | none |
| server advanced | space -2, -1, +1 |

The tapes drift 0.25 m off their unperturbed run within 5-17 s, almost always in the stop
logs or the valve bend, and nothing corrects the drift. These are execution proofs. They are
not evidence of how forgiving the course is to a human, who steers by feedback. A closed-loop
noise test would measure that; none has been run.

## Recovery

Every pit walks back to where its missed jump started. Nothing in a pit leads forward, and
there is no teleport or respawn. The pump bend's notch is the exception: its catch slopes up to
the inside band, which is that section's basic line anyway.

## Source and engine findings

- **Pre-repair base** (player `eda00676…`, motion `2a53fef2…`), kept separate under
  `frozen-base/`. A grounded hull whose front overhangs a slanted gauge edge sank up to 0.34 m
  into the deck for 1-4 ticks before take-off (g1 north, g3 east). Walking up the 14° g1 return
  ramp (`s4_lane_ramp_e`) along z -108, the hull snagged near x -151: it sank 0.2 m and stalled
  for 3.6 s on the server preset, and for the whole 12000-tick budget on vanilla (trial 35).
  The repaired runner shows neither: no sink in any run, and the z -108 line climbs in 1.6-1.9 s
  (trial 37).
- **Floor casts**: Godot 4.7.2's `move_and_collide` sometimes returns no collision for a hull
  landing diagonally on a convex prism it ends inside. `r14_practice_cast_probe.gd` sweeps every
  walkable piece with 18 landing motions: two of the review fixture's, plus eight horizontal
  directions at 300 u/s / 64 Hz and at 1100 u/s / 128 Hz. Misses on the runway:

  | runway collision | runway misses (18 motions) | root probe, its one motion |
  |---|---|---|
  | 1 × 128 m (v2) | 389 of 11016 | 2 of 441 |
  | 2 × 64 m | 229 of 20952 | 0 of 882 |
  | 4 × 32 m (v3) | 62 of 40698 | 0 of 1764 |

  Four sections bring the runway down to the rate the map's small pieces show anyway (about
  0.15-0.25% of casts: 19 on the 16 × 8 m pad, 57 on the weir middle deck). That remaining rate
  is engine-wide and no split removes it. Root's probe on v1 found 13 of 441 on the -z runway;
  orientation matters. No run in any batch fell through a floor. The seam probe walks and hops
  across each seam in six headings on both presets (168 cases): 0 failures, no sink, no speed
  change at any seam.

## Commands

```sh
G=~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
# level checks (1599 checks)
$G --headless --path . --script res://tests/test_r14_practice_level.gd -- --out=DIR
# closed loop: --fixed-fps must equal the preset rate (128 server, 64 vanilla, 120 R13)
$G --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/r14_practice_driver.gd -- \
  --out=DIR --route=basic|advanced|advanced_vanilla|block_miss|g1_miss|g3_miss --preset=csgo_server|csgo_vanilla
# R13: --runner=res://scripts/momentum_carry_air_candidate.gd instead of --preset (120 Hz)
# open-loop replay of a tape
$G ... --script res://tests/r14_practice_driver.gd -- --out=DIR --preset=P --tape=DIR/events.tape.json
# strict executor replay (headless, or --resolution 640x360 --mp4 --actor-limit 16 for a movie)
python3 tools/momentum-tape.py run TAPE --out DIR --headless --archive \
  --game-script res://scripts/r14_practice_lab.gd --game-class Lab --motor csgo_server --warmup 32 --wall-budget 600
python3 tests/r14_practice_perturb.py run TAPE --preset csgo_server --out DIR --jobs 8
$G --headless --audio-driver Dummy --path . --script res://tests/r14_practice_cast_probe.gd -- --out=DIR
$G --headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/r14_practice_seam_probe.gd -- --preset=csgo_server --out=DIR
```

Lab: `godot --path . --script res://scripts/r14_practice_lab.gd -- [--r14-runner=…]`. R restarts
from the gatehouse (the only run that can finish clean), F restarts the stage, 1-7 practise a
stage, Esc pauses. The HUD shows speed from actual travel and each jump's distance, air time,
speeds and the declared gap it crossed. The lab's `motor` property selects a Source preset,
and `physics_hz` reports the runner's rate for the executor.

## Interface

Unchanged from version 1: Overflow's public fields and methods (`spawn`, `checkpoints` with
`radius: 0`, `segment_bounds`, `segment_at()`, `finish_*`, `is_finish_at()`, `kill_bounds`,
`routes`, `jump_gaps`, `route_hint()`, `start_wheel()`, `reset_state()`, `manifest`,
`geometry_manifest()`, `geometry_hash()`, `material_mode`, `variant`), plus `level_id`,
`level_name`, `level_version`, `markings`, `course_manifest()`. Solids are named
`s<stage>_<piece>`; version 3 renamed `s3_runway*` to `s3_runway_1..4` and
`s3_runway_{north,south}_1..4`, which is why the hash moved. Stages are collected by standing on
a stage's deck. The Source runner reports no slide collisions, so the lab finds the deck with a
hull-sized slab query.

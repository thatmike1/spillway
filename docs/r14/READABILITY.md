# R14 practice readability

8 November 2026. A visual-only pass over Penstock Yard, in answer to the screenshot-only
discovery run (outer `checkpoints/spillway/r14/discovery-source/REVIEW.md`). That run crossed
the 2.0 to 3.5 m stop-log gaps and then hit the 4.0 m landing face. In its frame 32 the runner
was in the air while the view showed a top that looked like a platform; frame 33 was the face.
Tops, faces and pits were the same grey concrete, and nothing showed whether a short hop had
left too early or too slow. On the valve bend, the inside line only became readable after
turning left.

No collision defect was found and difficulty is unchanged. This pass changes only what is
drawn: `scripts/r14_practice_readability.gd`, one static `apply(level)`.

## What it draws

| layer | what | reason |
|---|---|---|
| deck faces | landing and track kinds keep their top finish; the formwork side tint drops from 1.05 to 0.45 | a lit top over a dark face makes the lip one hard line. Mid-air, a face visible under the lip means the feet are below it |
| pits | catch floors darker (top tint 0.6 → 0.38), with the kit's damp band below y −2.1 on catch floors and training walls | the drop reads as wet and low, not as another deck. The finish platform (−1.5) stays dry |
| landing nosing | a pale precast angle, 7 cm on the top and 14 cm down the face, on the 14 landing lips that face a declared gap | the edge to land past is the brightest line in view |
| take-off pad | red-oxide pigmented concrete on each take-off deck, plus a 10 cm pale start bar on its open side | where a run-speed jump reaches the next deck (below) |

All four use variants of the kit's own `momentum_surface` shader (`Materials.variant`), so no
new shader compiles on first sight. There is no dedicated shader. The new meshes are three
`MeshInstance3D`s (`ReadabilityPads`, `ReadabilityBars`, `ReadabilityNosing`) without shadows
or physics. Pads sit 2 mm over their deck, under the existing 4 mm strips and 10 mm labels.
The nosing stands 5 mm over the top and 6 mm proud of the face. Applying takes about 6 ms.

### The take-off pad

The pad is every point of the take-off deck from which a flat vanilla jump at 250 u/s
carries the feet onto the next deck. It uses the level's own `flight_time(drop)`: jump
301.993 u/s, gravity 800 u/s², measured feet centre to the landing edge, with no hull credit.
In the plan it is the take-off deck intersected with the landing deck grown by that reach:
4.794 m on the level, 5.817 m for the tail race's 1.5 m drop. The pad therefore shrinks as
the gaps grow, curves toward the next deck on the zig blocks, and is empty where run speed
cannot clear the gap.

| take-off → landing | gap (m) | pad |
|---|---|---|
| run-in → block 1 | 2.0 | 2.79 m deep across the run-in |
| block 1 → 2 / 2 → 3 / 3 → 4 / 4 → 5 | 2.5 / 3.0 / 3.5 / 4.0 | 2.29 / 1.79 / 1.29 / 0.79 m deep |
| block 5 → 6 | 2.5 | 2.29 m, rounded to block 6's width |
| block 6 → 7, 7 → 8 (zig) | 2.69 corner to corner | a rounded corner pointing at the next block (4.35 m² each) |
| block 8 → valve bend | 3.0 | 1.79 m |
| bend island 1 → 2 | 3.3 inside … 6.4 outside | a wedge on the inside: present to r ≈ 17.2, where the gap passes 4.79 m. The 4.9 m label sits just beyond its tip |
| bend island 2 → 3 | 1.7 … 4.2 | across the whole island, deepest inside |
| weir g1 / g2 | 3 → 8 / 12 → 3 | a triangle at the narrow end only (north for g1, south for g2) |
| tail race g3 | 3.5 → 14, 1.5 m down | a triangle on the east (right) end |
| pump bend notch | 8.3 – 10.1 | none: run speed reaches no part of it |

How it reads: a hop that lands short after leaving **from behind the bar** left too early.
One that lands short after leaving **from on the pad** had less than run speed along the line,
or bled it in the air. On the 4.5 m blocks, an autohop held through a landing leaves where it
lands, which is behind the next pad from block 2 on. That shows what the discovery run found
first: release Space before landing.

The real window is wider than the pad. Source keeps a hull on a deck while any part of its
32 u box overlaps, which adds up to about 0.4 m at each end. Air strafing also changes the
speed along the line. So "on the pad" means "clears at run speed with margin", not "the only
place that works".

Preset fit: F1 vanilla is the pad's own reference. Its stamina can leave a hop below 250 u/s,
and the pad then reads "slow", which is what happened. F2 and F5 share the jump and gravity and
can take off faster, so the pad is conservative for them. F4 (Q3-inspired: 320 u/s run, 270 u/s
jump, gravity 800) reaches 5.49 m, so its pad is also conservative. F3 is the R13 runner and
its own jump law: the pad is not calibrated for it.

## Integration (root owns it)

In `scripts/r14_main.gd`:

```gdscript
const READABILITY := preload("res://scripts/r14_practice_readability.gd")
...
	level.call("build")
	ART.apply(level)
	READABILITY.apply(level)
```

`apply` returns a report (version, `applied`, `retinted`, per-pair `pads` with reach and area,
`lips`, `apply_ms`) and stores it as the level's `practice_readability` meta. A second call
returns that report and changes nothing. On Overflow, a fixture, or the `--practice-neutral`
material mode it returns `applied: false` with a reason and touches nothing. A map switch
builds a new level, so the pass runs again there.

### Proposed route hints (root owns the wording and wiring)

| stage | current | proposed |
|---|---|---|
| 0 | Run in and line up on the first block. R restarts here. | Run in and line up on the first block. Jump from the red pad. R restarts here. |
| 1 | Hop the stop logs. Each gap is half a metre wider; the last three zig left and right. | Jump from the red pads. Short from behind a pad: you jumped early. Short from on it: too little speed. |
| 2 | Strafe left round the bend. Inside gaps are short; the outside keeps speed and needs it. | Strafe left round the bend. The red pads mark the inside line, which run speed clears; the outside needs more. |
| 4 | Pick a width at each gauge: the paint says what it needs. The wide ends alternate sides. | Pick a width at each gauge: the red pad clears at run speed, the paint says what the rest needs. |
| 6 | Last gauge, 1.5 m down: 3.5 m on the right, 14 m on the left. Finish on the platform. | Last gauge, 1.5 m down: the red pad on the right clears at run speed; the left is 14 m. Finish on the platform. |

## Found while doing this (existing level, not changed here)

- **Stop-log take-off strips and gap labels sit past the lip, over the gap.** `_stop_logs`
  draws `s1_nose_<n>` with width −0.25 and `s0_runin_edge` with −0.35. In `_strip_x`,
  negative means toward −z, which is the gap side, so each strip is a 5 cm ochre slab
  hanging 25 to 35 cm past the collision edge. Native still `10_block1_edge_side_before.jpg`
  shows it from the pit. The `s1_gap_<n>` and `s1_gap_bend` labels are placed at
  `previous - 0.6`, 0.6 m past the take-off edge, so they float at deck height over the void.
  The weir, tail-race and bend marks are on the correct side. In the stage where the
  discovery run failed, the yellow edge reads 25 cm further than the real lip. Proposed fix:
  `+0.25`, `+0.35` and `previous + 0.9`. Marks are not hashed, so the geometry hash stays as
  it is. With that fix the ochre lands on the last 25 cm of each pad, 2 mm above it.
- The practice toast covered the stage-2 route hint at spawn (discovery frame 52). That is a
  HUD layout issue and outside this pass.

## Rejected

- **Floating arrows, skip paths, teleport help**: excluded by the brief, and not needed once
  the pad shows the line.
- **A dedicated shader** (hatching, distance stripes, a feet-height datum): every surface
  above is a variant of the existing kit shader. A new program would compile when it was
  first seen. The finish beacon was moved off its own shader for that reason, after a cold
  AMD stall.
- **Chipped paint for the pad and nosing** (first native round): the kit's paint chips read as
  speckle at eye height. Pigmented concrete with the deck's own bays, and a plain pale
  precast tone, read calmer.
- **A dark anti-slip take-off band**: next to the lip it merged with the gap from a distance,
  which makes gaps look wider.
- **Steel stop-log faces** (plate set): a second material language for no gain, since the
  value split already separates face from top.
- **A pad for advanced lines** (for example "540 u/s here"): one reference speed keeps the
  pad's meaning single. The existing gauge ticks already print the speed for every width.

## Verification (8 November)

Source a91c993d plus the two new files, scratch copy, Godot 4.7.2, isolated XDG profiles.
Evidence is in the outer `checkpoints/spillway/r14/practice-readability/`.

- **Identity, headless.** One built level, before and after `apply`: geometry hash
  `f510bbaee695017e930723d7d633b6fb74be32993c5a2428d0ea4a4cfee88311` both times. All 282
  physics nodes are equal (path, class, global transform, layer, mask, metas, shape points,
  disabled). Spawn, checkpoints, segment bounds, finish, routes, jump gaps, kill bounds,
  markings and `course_manifest()` are equal. 141 pieces. The pass adds no physics node, and
  a second call is a no-op. The same holds against an untouched second build.
- **Native, AMD** (private Weston/Xwayland on :193 through `NativeDisplay`, GpuWatch ok,
  device `AMD Radeon Graphics (radeonsi, renoir, ACO …)`). Nine eye-height views (64 u eye,
  90° at 4:3) plus a side view, before and after, in one process: run-in, block-4 approach,
  low in the air over the 4.0 m gap, zig block 6, valve-bend practice spawn, the bend's
  inside approach, low over the bend's inside gap, weir g1, tail race g3.
- **Actual main, input tapes.** The six authored practice tapes (`practice-source/v3/final`:
  server basic and advanced, vanilla basic, both g3 misses, R13 basic), warmup 32, were
  replayed through `tools/momentum-tape.py` twice from the same copy: once with root's replay
  setup `practice-root/game.gd`, once with a scratch subclass that calls `apply` after
  `_build_level`. Results below.

  | tape | rows | with pass | finish (both) |
  |---|---|---|---|
  | server basic | 7316 | identical | clean 56.3515625 s, 0 respawns |
  | server advanced | 3847 | identical | clean 28.609375 s |
  | vanilla basic | 3764 | identical | clean 57.78125 s |
  | server g3 miss | 8684 | identical | clean 67.03125 s |
  | vanilla g3 miss | 4447 | identical | clean 68.40625 s |
  | R13 basic | 5235 | identical | clean 42.875 s |

  "Identical" means every trace row is equal once the wall-clock fields are removed: pose,
  velocity, yaw, grounded state, keys, mouse, motion state and game counters. Report outcomes,
  delivery and order checks are equal too. The pass logged `applied true` with the unchanged
  hash in each run, and the motion also equals the recorded `tail-return/map4-warmup32` runs.

## Limits

- The pass is intended to make the map easier to read. It does not make any gap shorter, and nobody has
  played it yet. This is no discovery, enjoyment or teaching claim. A fresh discovery run
  would decide whether the pad is understood without the route hint.
- The views are level-only stills without the HUD, plus the headless main replays. The
  pass has not been seen inside a packed build.
- The pad's reach is screening arithmetic, the same model as the manifest's gap tiers. It
  is conservative, not a measured landing envelope for each preset, and F3 is not covered.
- Root subsequently moved the stop-log/run-in strips onto their solid decks and the gap
  labels 0.9 m behind the lip, and wired the new route hints. The before/after worker
  stills above predate that correction. Root also separated the practice toast from the
  route hint so the hint can appear immediately. These edits add no collision and do
  not change the geometry hash; final native/packed evidence must use the integrated tree.

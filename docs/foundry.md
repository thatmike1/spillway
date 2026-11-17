# Foundry

Foundry is a coastal pump hall with an open shaft between two working galleries.
Its landmark is the supported crane spanning the shaft, with a ring suspended over the void.
From the high entry, the player can inspect the continuous left gallery and the lower far landing from the front crosswalk.
A released swing takes the direct line while a wide descending gallery provides the forgiving alternative.
Beyond their meeting point, the tailrace drops another ten metres into a broad catch above the recovery court.

## Routes and anchors

```text
                              gallery x=-16        shaft x=0
entry y18 z12 ---------------------+-------------------+
front crosswalk y18 z0..3 ---------+-------------------+
                                  |                   |
                   gallery ring (-16,25,-12)    shaft ring (0,29,-8)
                                  |                   | 20 m gap
rejoin y12 z-20..-36 --------------+-------------------+
                                      right-side preview opening
                                                      |
                                           ring (0,21,-44)
                                                      | 14 m gap / 10 m drop
catch y2 z-50..-78 -----------------------------------+
finish y2 z-70
court y-8: full recovery floor; left wall ramp returns to entry
```

LMB holds, RMB reels, release LMB to coast. Foundry fixes the model to
`elastic-arc` through its catalog entry and uses
`scripts/movement/grapple_player.gd` unchanged. The normal tapes use explicit
LMB/RMB input, not an automatic-reel preference. Rope forces are not tuned here.

The gallery stays connected. The front crosswalk also lets a player inspect the
shaft and still walk to the gallery without jumping. Both routes share the
rejoin and Tailrace checkpoints; no gallery-only scored checkpoint invalidates
the shortcut. Each shared checkpoint supplies a practice pose. Falling into the
court does not require restart: the left ramp spans x=-27..-23, from y=-8 at
z=-78 to y=18 at z=18, then joins the entry apron. A separate right ramp can
recover a missed final catch into Tailrace. Kill bounds cover these routes.

## Geometry, identity and look

Map ID: `foundry`. Level ID: `r22-foundry`, version 4. Stable anchor IDs:
`foundry-0`, `foundry-1`, `foundry-2`, in the order listed in
`FOUNDRY_ANCHORS`. The geometry digest includes the current level ID/version,
actual collision manifests and authored anchors. Old map identities do not mix.

Large walls, piers and gantries have collision matching their visible prism
bounds. Piers stop at deck undersides, avoiding coplanar top faces. The return
ramp runs in the clear corridor beside the supports. Orange paint and text are
visual and add no motion impulse, landing bridge or progress trigger.

The map declares `own_look` so the inherited experiment palette cannot replace
its authored materials. Pale slab tops, darker weathered sides, restrained ink
and orange lips use original procedural shaders. The painted sky reuses the
existing practice-sky resource. Rights and source paths are recorded in
`assets/maps/foundry/MANIFEST.md`; private concept/reference pixels are absent.
Joint-edge chips, short seam runoff and lower waterline stains weather vertical
concrete while keeping large faces and landing tops quiet. Pale level bands on the existing tailrace pipe drops
compare the high handoff, midpoint and low catch. The catch itself is a flat
landing ten metres below the takeoff, not a ramp.

## Spacing check

The final 17 November lane-12 measured sheet separates performed SourceJump
rank-one jumps from adjacent-pad spacing. Its Fury 2 flat-hop sample has a
6.502 m median support gap and 1.626 m median landing short side; Duster's are
7.315 m and 6.502 m. Those AA1000/100 Hz runs do not prescribe F2 difficulty or
rope geometry. The earlier Eazy tour gap recommendations were withdrawn.

Foundry deliberately retains a continuous 12 m gallery, broad shared landings,
a 20 m shaft crossing and a 14 m descending catch. The reference establishes no
comparable rope-law/anchor-spacing prescription. These rope gaps are justified
by earned Arc input tapes and recovery checks, rather than by transplanting
ordinary-hop distances. The sequence changes elevation, contact and recovery
instead of repeating a flat chain of pads. Nothing downloaded is redistributed.

## Verification

```sh
python3 tools/play.py --headless --audio-driver Dummy --script res://tests/foundry_routes.gd -- --out=/tmp/foundry-routes
python3 tools/play.py --headless --audio-driver Dummy --script res://tests/foundry_fork.gd -- --out=/tmp/foundry-fork
python3 tools/test.py --out /tmp/foundry-fast
```

The fast gate needs a new output directory. The route fixtures construct command
tapes from normal spawn with the production runner at server128/128 Hz, then
replay mouse/buttons without steering position or velocity. The gallery takes
1810 ticks (14.140625 s); the shaft takes 1108 (8.65625 s), saving 702 ticks
(5.484375 s). Both collect every shared checkpoint and earn the descending catch.
The chosen tape releases the first ring after 140 held ticks and the final ring
after 145. These are measured examples, not required human timings or enjoyment
claims. A no-rope replay is a negative control for that earned shortcut.

The fork fixture uses a real-input approach, a visible pause after movement to
let teaching clear, then a lateral running inspection from the front crosswalk.
At 1280x720 it tests projection and physics line of sight to both route surfaces
and the court before any jump, then finishes/replays the gallery. Static camera
supplements are labelled separately and do not prove traversal.

Original-map slow parity remains the integration lane's gate under the r22 run
brief. The current material transform follows the official
[Godot spatial-shader contract](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).

Movement fixtures silence only the auxiliary release-cue playback, following the
existing component-test boundary; native host captures retain the real cue path.

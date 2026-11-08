# Tail-return corner repair

P geometry choice, Penstock Yard version4. The east side of `s6_runin` now tapers
0.8 m towards its nose instead of ending in a square corner beside the return ramp.
The top return landing extends west by the same amount so it still meets the deck.
No new collision body is added. The declared narrow/wide jump samples stay on the
same slanted takeoff edge. Overflow geometry is unchanged.

The independent review reached the old corner from normal spawn after deliberately
missing the last gauge. A walker near x−227.8 hit the deck's nose at z−134.9 and
needed a sideways input to escape. This was an avoidable obstacle in a recovery lane.

## What was rejected

Four added guide shapes are retained in outer `checkpoints/spillway/r14/tail-return/`.
The first passed the local forward tests but obstructed the actual approach from the
pit. Shortening or narrowing it either left some forward approaches blocked or let
the review controller push perpendicularly into the new guide. Those trials were
not promoted. Removing the obstructing corner gives a glancing face without adding
another obstacle.

## Checks

`tests/test_r14_tail_return.gd` starts each episode once on clear pit floor, at five
x positions spanning the affected join, then sends only held W for seven seconds.
The old geometry failed six of ten cases; the tapered geometry with the final
Source contact guard passes all ten across 64/128 Hz. Every episode logs its initial
hull-overlap query and complete input/position trace. A misspelled `--only` filter
fails rather than silently running zero cases.

The original review's special stall probe deliberately keeps targeting its corner
node until it performs a sideways rescue. For the full-route regression, the
external `product-followthrough.gd` lets its unchanged itinerary resume only after
the runner has physically climbed to the top. It adds no pose, velocity or input
rescue. With the contact guard it finishes cleanly in 66.6171875 s from normal spawn,
all 30 nodes reached, zero respawns. This remains a coordinate-aware execution proof,
not discovery or human play.

The layout suite passes 1599/1599. Its 0.5 m walking grid initially rounded the exact
`g3_east` takeoff anchor to a cell whose centre was 26 mm outside the tapered edge.
The anchor itself was on the deck. `_anchor_key` now requires an exact ray hit on a
walkable route/catch/recovery face, then selects a grid sample on that same named
body within 0.375 m. Adjustments are recorded. Gap dimensions, collision rays,
walking flood, no-forward recovery and no-walkaround checks are retained.

Evidence root: outer `checkpoints/spillway/r14/tail-return/`. `guard3/CHECKS.json`
contains the ten local cases; `product-guard3/` the full approach; `geometry5/`
retains the coarse-grid failure and `geometry-guard3/` the corrected check.
`map4-routes/` replays the unchanged authored tapes with the executor's default
warmup, recorded explicitly in ACCEPTANCE.json. `map4-warmup32/` repeats the authored
warmup. Neither is an enjoyment or exact CS:GO-runtime claim.

Native before/after fixtures in `native-final/` use the identical guarded player and
identical W-only test, with only the map changed. Both 211-frame, 640×360 MP4s decode
cleanly and match their raw AVI frame counts. Root inspected `before-after.png`:
the old run remains at the nose; the new run climbs onto the return deck. These are
local fixture views, not full-course movies. The first render's unexpected 1280×720
viewport was rejected and retained in `native/`; fixture-only viewport overrides
make the accepted pair explicit. All owned Xvfb/game processes and scratch were cleaned.

The map's geometry hash is
`f510bbaee695017e930723d7d633b6fb74be32993c5a2428d0ea4a4cfee88311`.
Versioning separates old map records; Source family version 3 also separates the
landing-guard timings. Final packed evidence must name both current identities.

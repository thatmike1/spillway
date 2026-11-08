# Actual runway casts and a Jolt comparison

8 November 2026, source `3b88472a`. R14's current backend is Godot Physics, confirmed
by `GodotPhysicsDirectSpaceState3D`. An isolated file snapshot changed only the
project's backend setting. It reported `JoltPhysicsDirectSpaceState3D`. All 138
script, scene and shader hashes matched before its scratch snapshot was removed.

The version 1 practice runway was a single 16 × 6 × 128 m convex prism. A 21 × 21 grid of
diagonal landing casts uses the real Source hull and actual map collider. A ray
first confirms the runway below each start. The cast begins 2.97 u above its top
and would end below it if no collision stopped it.

| Same actual runway, same 441 eligible casts | Misses |
| --- | ---: |
| Godot Physics | 13 |
| Jolt, default settings | 0 |

This is a test-motion diagnostic, not 13 observed player falls. Overflow's largest
collider is 89.6 m; it has no floor in this probe's 120 m and larger selection.
The first probe mistakenly selected only `BoxShape3D`; the route uses convex
prisms. That incomplete attempt is retained and does not count as a pass.

Jolt is not a transparent setting change for the current adapter:

- The existing 63-check live-movement suite passes 62. One measured apex is
  57.389 u, just outside its existing bound. This is a changed outcome, not proof
  that Jolt's jump is intrinsically wrong.
- The repair suite runs 97 assertions with ten failures. Four approaches no longer
  reach its two-plane fixture condition, two step-event cases no longer take the
  expected step, and four strict rest checks detect small drift. The suite's
  denominator depends on which approaches reach two planes, so its 97 assertions
  cannot be compared as a pass rate with Godot's 135.
- The margin handling was calibrated for Godot Physics. Godot's own documentation
  explains that Jolt rounds convex edges using collision margins, whereas Godot
  Physics ignores the shape-margin property. A Jolt-specific adapter needs further
  testing. [Official Jolt differences](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html#collision-margins).

P decision: keep the validated backend and use four 32 m coplanar runway sections
in Penstock Yard version 3. The map also moved the runway after the blocks, turning
it along −x, so the version 1 row above is not a controlled before/after of splitting.
On the revised orientation the worker measured 389 missed casts in 11,016 for a
single runway, 229/20,952 for two sections, and 62/40,698 for four. Root reran the
18-motion probe on the integrated v3: the runway has the same 62 misses in 40,698;
across all eligible floors, 307/195,066 casts miss. Small pieces also have misses.
Splitting mitigates the large-shape fault; it does not eliminate the engine fault.
These casts are diagnostics, not observed player falls.

The worker's 168 input-driven seam cases and root's full basic, advanced and
recovery replays did not fall through a floor. Both Source presets finish the basic
line; server strafing earns the advanced line. Actual-game results and limits are
in PRACTICE-ACCEPTANCE.md. Retain the remaining cast fault as a risk, and reopen
contact handling if play reaches it. A global backend change would still require
rechecking the required R13 comparison; that Jolt run was not performed here.

Evidence: outer `checkpoints/spillway/r14/backend-comparison/RESULTS.json`, both
floor results, player/repair logs and compressed traces, `SOURCE.json`,
`runtime-sources.json`, the modified project config and scratch-removal manifest.
The actual-map probe and its incomplete first attempt are in
`checkpoints/spillway/r14/course-floor-casts/`. No renderer, latency, Windows or
enjoyment claim is made by these headless checks.

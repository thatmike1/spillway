# Actual runway casts and a Jolt comparison

8 November 2026, source `3b88472a`. R14's current backend is Godot Physics, confirmed
by `GodotPhysicsDirectSpaceState3D`. An isolated file snapshot changed only the
project's backend setting. It reported `JoltPhysicsDirectSpaceState3D`. All 138
script, scene and shader hashes matched before its scratch snapshot was removed.

The practice runway is a single 16 × 6 × 128 m convex prism. A 21 × 21 grid of
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

P decision: keep the validated backend while the map worker splits the runway into
shorter coplanar prisms and checks the new seam and landing casts. The split is
not accepted by this report; its after evidence is still pending. If it fails,
revisit the collision approach. A global backend change would also require
rechecking the required R13 comparison; that run was not performed here.

Evidence: outer `checkpoints/spillway/r14/backend-comparison/RESULTS.json`, both
floor results, player/repair logs and compressed traces, `SOURCE.json`,
`runtime-sources.json`, the modified project config and scratch-removal manifest.
The actual-map probe and its incomplete first attempt are in
`checkpoints/spillway/r14/course-floor-casts/`. No renderer, latency, Windows or
enjoyment claim is made by these headless checks.

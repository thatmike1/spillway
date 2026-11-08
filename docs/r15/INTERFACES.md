# R15 work boundaries and integration

The delivered R14 remains the reference. New R15 runtime/scripts live beside it. Root owns `r15_main.gd`, HUD, registry, default scene, timing/profile identity and final delivery. Preserve reusable R14 pure Source math and harnesses. Read BRIEF.md before choosing new mechanics.

## Crouch work

Own new `scripts/r15_source_player.gd`, a standalone `scripts/r15_movement_lab.gd`, dedicated `tests/r15_crouch_*` / `test_r15_crouch*` and `docs/r15/CROUCH.md`, with generated UIDs. Prefer extending the repaired R14 runner. Existing R14 files remain unchanged unless a small extension point is demonstrably necessary; root must review any proposed change. Use the R14 interface: `reset_to`, `view_yaw`, `view_pitch`, `velocity`, `settings`, `physics_hz`, `tape_step_count`, `get_motion_state`, `is_grounded`, interpolation fields and actual-travel reporting.

Expose real hull dimensions, duck transition/request, blocked stand-up, foot/eye policy and new events in motion state. Crouch modifies a collision box, not just the camera. No-input/no-crouch motor traces must match the approved base in controlled comparisons. Record every new setting that changes motion. Do not add wall jump or grappling in this pass.

## First map work

Own new `scripts/r15_breakwater_level.gd`, `scripts/r15_breakwater_lab.gd`, `scripts/r15_breakwater_art.gd` if useful, `assets/r15/breakwater/`, map-specific tests/drivers and `docs/r15/BREAKWATER.md`. Use the R14 level interface so `level_script` can host it without changing R14 main/HUD: spawn, checkpoints, stage names/bounds, kill bounds, finish, route hint, geometry manifest/hash and course identity. Stable names on every solid; a geometry manifest identifies roles, stage and material. All accessible visible solids have intentional collision, all route-collision surfaces are visibly drawn.

The first slice uses the approved R14 Source runner until R15 crouch is integrated. No waiting for the crouch worker. Do not include mandatory crouch-only access until a real crouch runner proves it. External props carry source URLs, exact licence and modification/hash provenance. Keep textures and meshes bounded; don't add a large asset pack solely for one prop. First native inspection must show the actual run from its own camera, not just an overview.

## Common checks

Use the pinned Godot 4.7.2 and existing version2 rate-aware tapes. New routes at128 Hz state warmup and sensitivity. One setup at episode start is allowed; no state rescue during route proof. Use private checked AMD/X11 when native output is needed, with HOME >= 15 GiB and explicit free displays. Keep output in outer `checkpoints/spillway/r15/<workstream>/`; target <= 100 MiB per workstream initially, prefer gzip/MP4/JPEG. Root will integrate returned source, not workers' `.godot` caches. Leave source uncommitted for root review and coherent integration.

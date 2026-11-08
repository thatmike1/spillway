# Spillway

Before movement, level, presentation or delivery changes, read docs/r14/BRIEF.md and docs/r14/INTERFACES.md. Mike rejected R13 on 8 November: he wants real CS:GO A/D air strafing, a faithful Source baseline, switchable presets and a practice map. R13 stays unchanged as a comparison. docs/momentum/BRIEF.md, docs/surf/BRIEF.md and STATUS.md are historical contracts. R14 owns current acceptance.

R12's baseline uses Godot 4.7.2, GDScript, Compatibility rendering and 120 Hz physics, with spillway_player.gd owning collision and velocity. These are baseline facts, not a requirement to retain this engine or architecture in the new work. In current Godot experiments use metres/seconds/radians, label new tuning P / game choices, and have camera/audio present actual motion. Historical runtime ownership and verification are in docs/reboot/RUNTIME.md and docs/reboot/VERIFICATION.md.

Use original work or external assets with redistribution rights and recorded provenance. Keep private references/specs and captures outside Git. Check physical behavior with tools/check-spillway.sh and actual input routes. Inspect native rendered sequences for landing visibility, material/lighting, recovery and legibility. Scripted completion is evidence of one line, not enjoyment.

Static box batching changes rendering only; physics remains separate and wheel geometry moves independently. Verify native frames when changing batching or procedural winding. Deliver with the pinned runtime, visible build identity and source manifest; native Windows execution must be labelled honestly when unavailable.

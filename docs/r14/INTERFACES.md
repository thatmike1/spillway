# R14 first experiments

P decisions, subject to measured comparisons. The settled target is Source/CS:GO air
strafing. R13 is a comparison mode, not the chosen assistance policy. The default intended
play mode is the bhop-server preset; vanilla is the faithful unmodified comparison.

## Independent work

The Source experiment owns new `r14_source_motion.gd`, `r14_source_player.gd` and
`r14_source_lab.gd`, their dedicated tests/drivers, UIDs and SOURCE-IMPLEMENTATION.md.
The numerical researcher owns SOURCE-REFERENCE.md and tests/r14_source_oracle.py. The
practice course owns r14_practice_level.gd, its standalone lab, test and PRACTICE.md.
A later independent Quake/CPMA experiment can add a distinct motor. Root owns the preset
registry, actual R14 main/HUD, integration, default scene, record namespaces and delivery.

Each motor has an isolated playable lab and input-driven fixture. Source equations live
in a small pure module that can be checked independently of collision. The playable
adapter uses real collision and exposes `reset_to(Transform3D)`, `view_yaw`, `view_pitch`,
`velocity`, `settings`, `tape_step_count`, `is_grounded()` and `get_motion_state()` using
R13's existing meanings where relevant. Include actual resolved travel, current contact,
jump/landing counters and active cvars in the state. Input actions come from the existing
spillway_main.gd bindings. Map new tuning/settings explicitly rather than depending on
R13's air steering or overspeed tax. Existing R13 motor files remain byte-identical.

Provisional reference timing is vanilla 64 Hz and server bhop 128 Hz, with R13's original
120 Hz retained. The Source researcher/implementer must distinguish tick effects and
justify these choices against primary sources. UI shows tickrate and profile. The runtime
may change physics rate with its preset; tapes declare their rate. New tests cannot
silently assume the R13 executor's fixed 120 Hz validation supports the new rates.

Preset switching preserves physical position, velocity and free look, starts no new game
process, and marks an active attempt as practice to keep records comparable. A clean R
starts a record-eligible attempt in that map/preset. All records use a new R14 namespace
keyed by map, preset and tuning; R12/R13 records stay unchanged. Record this as a P policy.

The practice level implements the current Overflow level's public fields and methods
(see momentum_overflow_level.gd and consumers), including spawn/checkpoints/bounds,
progress/finish, manifest and level identity. Its original industrial layout has a long
runway, hop blocks, corners, speed-demanding gaps, a forgiving return and measurable
landings. Use units in both Source u and metres. Basic routes must work at vanilla speed;
advanced lines earn distance from strafing. Keep the existing Overflow geometry unchanged
until an actual cross-preset contact problem justifies a specific labelled amendment.

## Checks and evidence

The external reference is primary cvar/algorithm evidence with independent mathematical
predictions or actual external observations, clearly distinguished. A Python oracle may
use closed forms and original equations; it imports no game implementation. Exact gain
and hop tests state input, tickrate, cap mode, maxspeed/weapon, stamina and autohop. The
uncapped/capped wishspeed distinction must be resolved, not guessed from a familiar name.
No copied engine code enters the project.

No run is called fun or CS-identical merely because its fixtures pass. Include imperfect
A/D/mouse input, no-input airborne retention and actual movement. Event cadence, contact,
landing order and real displacement remain separate checks. Headless tests can begin
with small bounded output; large renders/exports require at least 15 GiB free first.
R14 actor evidence keeps a movie plus selected frames, not thousands of PNGs. Traces are
compressed. Final packed checks run from empty directories outside the checkout.

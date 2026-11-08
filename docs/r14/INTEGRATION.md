# R14 comparison integration

P product decisions, 8 November. The Source equations and reference constants are
settled by SOURCE-REFERENCE and the independent oracle, not this interface note.

## One sitting, several actual movement laws

Start on the practice map with the CS bhop-server profile. Keep Overflow available
from a map selector. F1 selects vanilla, F2 the bhop-server profile, F3 the unchanged
R13 runner. F4 offers a labelled Quake III-inspired full-wish projection, using the
same Source body. F5 raises Source air acceleration to 1000 as a P server config.
The pause menu provides the same choices with their air acceleration, tickrate,
jump policy and short control description. The active map and preset stay visible.

Changing a preset keeps position, velocity and look direction. It makes the current
attempt practice; R immediately starts a comparable clean attempt. A new hull that
cannot fit at the current position should wait for clear space with an explicit
message, rather than silently moving the runner. Map changes start at that map's
normal spawn. Neither operation launches another process.

Use a new R14 main/scene and profile. Keep R13's main, motor, collision adapter,
camera and level byte-identical. The R13 control is recorded in the outer
`checkpoints/spillway/r14/r13-control/BASELINE.json`: its ordinary input tape still
finishes clean in 24.8916667 seconds at 120 Hz. Reusing our own lifecycle code is
fine; inheriting R13 build/save constants into a new release is not.

The record key includes map geometry/progress, preset, actual tickrate and movement
configuration/version. Separate clean, open and practice outcomes as R13 does.
Switches cannot load a different preset's best into the current comparison.

## Mouse and camera are part of the comparison

The original R13 default is 0.0022 radians per mouse count and 90 degrees of literal
horizontal FOV, plus its existing speed response. Keep that interpretation in R13.

The Source family should expose Source sensitivity units and m_yaw/m_pitch, rather
than label an unrelated multiplier as CS sensitivity. Valve's public SDK declares
m_yaw 0.022 and multiplies the scaled mouse count by that degree factor. Therefore
the original R13 default corresponds to about 5.73 Source sensitivity units at that
yaw factor. This is a measured conversion, not proof of Mike's personal settings.
The exact CS:GO default still needs the legacy cvar reference. A starting sensitivity
chosen for our build is P and must be labelled accordingly.

Source's FOV convention uses a 4:3 reference and widens the horizontal view with
aspect ratio. For a chosen 90-degree reference, the vertical angle is 73.739795
degrees and the 16:9 horizontal angle is 106.260205 degrees. Godot KEEP_HEIGHT can
express that as a constant vertical FOV. Do not accidentally offer R13's literal
90-degree horizontal angle under the same label. Source camera response should
avoid an unlabelled R13 speed-FOV/bank assist. Direct mouse look and body presentation
can be checked independently from movement.

Primary references: [Valve input implementation](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/client/in_mouse.cpp),
[Valve aspect/FOV implementation](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/client/view.cpp),
[Godot Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html).
These SDK observations are not claims about CS:GO-specific cvar defaults. Research
source hashes are in outer `checkpoints/spillway/r14/input-reference/SOURCES.json`.

## Existing consumers that need deliberate adapters

R13 lifecycle reads feet-position origins, `get_speed()`, `is_grounded()`,
`floor_max_angle`, native contact manifolds, `reset_to()`, `yaw`, `pitch`,
`input_enabled` and `in_water`. Its audio also reads `mode`, motion `ledger`,
`footstep(strength)`, `landed(impact)` and `move_started(kind)`. A new Source motor
does not become compatible merely by exposing a velocity vector. Add a narrow
adapter or change the new R14 consumer, without changing the old R13 implementation.

HUD speed is measured horizontal travel in u/s, with metres/second as an optional
secondary value. Show hop gain/loss and a precisely defined airborne sync measure.
Distinguish no eligible strafe samples from zero sync. Reset statistics on restart,
respawn, map and preset changes. Collisions/ground friction must not masquerade as
bad mouse synchronization. Leave enough view clear to judge the landing.

Manual vanilla jumping needs press edges, including scroll-wheel pulses. Holding
jump cannot secretly enable server autohop in the vanilla preset. A server option
that changes physics belongs in the record fingerprint. Ordinary UI settings do not.

## Replay timing must be real

R13's original tape protocol accepts only 120 Hz; its tick120 and render30 labels are
not valid descriptions of a 64/128 Hz Source run. The integrated v2 protocol now
declares 64, 120 or 128 Hz, sets that rate before world construction and rejects a
game/rate mismatch. Every trace records actual delta and motor ordering. Version 1
remains unchanged. Do not retime an old tick tape by changing its header. See REPLAY.md.

Native evidence keeps a bounded movie, selected frames and compressed input/physics.
Source, imperfect-input, view-only discovery, hardware timing and human enjoyment
remain separate claims. All final packed checks run outside the source checkout.

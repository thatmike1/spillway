# Spillway R14: CS:GO bhop and air strafing

Spillway R14: real CS:GO-style bhop and air strafing, explored wide. Mike played R13 Overflow. His verdict: he is still expecting CS:GO movement and air strafing, and what he gets is momentum he cannot control or keep when he strafes in the air. Bounded W/mouse steering is not the feel he wants. He is going off to play actual CS bhop servers to scratch the itch, so that is the reference he will judge against when he comes back. This round is for experimenting wildly and spreading wide: budget is not a concern, delegate freely, run parallel variants in their own worktrees, be bold, have fun.

What he wants to end up with:
1. A faithful Source/CS:GO movement model as the baseline, reimplemented from the public cvars and the well-known PM_Accelerate / PM_AirAccelerate / PM_Friction behaviour (no copied engine code): ground accelerate and friction with stopspeed, the 30-unit air wishspeed cap, sv_airaccelerate, gravity 800 and the CS:GO jump impulse, converted to Godot units with the conversion written down. Strafing with A/D while turning the mouse the same way must hold and build speed exactly the way a CS player expects, and letting go must keep the line. Check it against known CS numbers (for example the gain per well-synced strafe at a given airaccelerate, and max speed from a standing start after N hops), not only internal tests.
2. Several movement presets switchable in game without restarting, so Mike can compare in one sitting: at least CS:GO vanilla (airaccelerate 12), CS:GO bhop server (airaccelerate 100, autohop, no stamina), and R13 Overflow as it is; add any others you think are worth his time (Quake/CPMA air control, a VHOLUME-inspired one, your own). Show the active preset on screen.
3. A strafe HUD like bhop servers have: speed, gain or loss per jump, strafe sync percentage, so he can tell whether a bad hop was him or the physics.
4. An original bhop practice map beside the dam course: blocks, strafe-around corners, gaps that need real speed, a long straight to build speed. Original layout, not a copy of any existing map. The Spillway course stays playable with every preset.

Keep everything else from the R13 workflow: honest evidence, scripted input traces, packed checks run outside the source checkout, portable Linux and Windows ZIPs in delivery/spillway-r14/, REPORT.md telling him how to play and switch presets, commits pushed to feat/foldrunner-me-build with (ccChat-general-rowb) in the subject. Do not claim it feels right; he decides that. Work until at least 20:00 Europe/Prague today, Sunday 8 Nov 2026, and keep improving what is actually playable rather than stopping at a test count. Mike is away: decide everything yourself and label it, never stop to ask.

## Storage steering, 8 November

Before large rendering or export, require at least 15 GiB free on /home. Check free space
before every large run and remove its scratch afterwards. Mike confirms a full desktop
backup of the outer build workspace except wt/ and delivery/work/, taken around 11:00.
Old checkpoints and historical packages that R14 does not need may be removed, with a
removal record. Keep the final R12 and R13 downloads locally. Current R14 evidence is
bounded and compressed; final movies, selected frames, raw input/physics and hashes remain
reviewable. Earlier captures are history, not a reason to fill the laptop again.

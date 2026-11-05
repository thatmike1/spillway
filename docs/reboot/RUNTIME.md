# Spillway runtime

The active contract is BRIEF.md. The default scene loads `spillway_main.gd`; the earlier controller/world scripts remain historical fixtures and are excluded from the portable game pack.

`spillway_player.gd` is the one CharacterBody3D collision owner. Origin is at the feet, with separate standing/low capsule heights. Ground velocity, jump grace, air correction, downhill slide and the brief intentional mantle all use collision sweeps. Standing clearance is checked before capsule growth. Slide entry/exit hysteresis keeps crouch walking separate; backward slide input brakes. Ground contact resets the air-speed budget. Camera interpolation, a small impact dip and optional vertical gait motion do not move the collision body or take over free look. Tuning constants are P / game choices, not recovered source targets.

`spillway_level.gd` builds Crest, materials, lighting, landscape, water and original industrial hardware. `spillway_course.gd` adds Sluice yard and Outflow, the ordered checkpoint poses and finish. Visible stairs use one continuous collision ramp. Static boxes are grouped by material for instanced rendering; their physics bodies remain separate. Wheel parents are marked as moving geometry and stay outside the static batches. The water and concrete shaders use world scale. Dry concrete has no global wet band; local wet materials own waterline shading.

`spillway_main.gd` owns input bindings, run provenance, pause/settings, checkpoints, recovery and records. R resets the whole attempt; F and out-of-bounds respawn invalidate clean eligibility. Only an ordered three-segment clean finish updates clean full-run and segment bests. Bot and headless runs never persist. The fresh profile is `user://spillway_v1.cfg`, under the OS Godot data directory for Spillway. The quiet HUD keeps movement visible; the pause menu shows build identity. Audio loops stop and release before native exit.

`spillway_audio.gd` uses original synthesis helpers from `audio.gd`, with material footfalls, slide scrape, impact/splash, speed wind and spatial water. No downloaded audiovisual assets are in the game. Running arms are intentionally absent.

`spillway_driver.gd` injects ordinary action/mouse events and writes traces outside Git. It never owns player position, velocity, camera pose or run state. The `--crest` switch retains the developer slice. `--no-batch` supports a bounded native rendering comparison, not a different controller. See VERIFICATION.md for the retired suites and current test boundaries.

`tools/package-spillway.py` packs an explicit active resource list, checks packed startup, and bundles pinned official native runtimes plus their licence notices. BUILD.json and archive checksums record exact source/runtime identity. The portable pack is native; the included tools-enabled runtime is larger than a stripped export template. Native Windows play remains a separate unverified platform check on this Linux host.

Overnight r11-dev: a small upward sphere sweep keeps the animated eye outside geometry during a late crouch, independently of the low body capsule. Wind and water loops blend into a discarded pre-roll, retaining exact loop durations and continuous PCM wrap boundaries. Signal checks do not establish listening quality.

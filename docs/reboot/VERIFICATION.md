# Spillway verification

The active acceptance contract is BRIEF.md beside this file. Source reconstruction and all-moves coverage are retired. The old `test_spec_*`, `test_body`, `test_runner_vision`, `test_player`, `test_yard`, `test_yard_run`, `test_feel`, `test_presentation`, `test_integration`, `test_traversal` and old render fixtures remain historical developer material. They test a different controller/world and are not Spillway gates. `scripts/main.gd`, `player.gd`, `moves/`, `level.gd` and `yard.gd` likewise remain inactive historical fixtures. The default scene uses `spillway_main.gd`.

`tools/check-spillway.sh` runs new behavioral checks through native CharacterBody3D collision. These are isolated fixtures: run/brake/reverse, jump grace and expiry, standing air control, look independence, ordinary landing continuity, slide release/jump, flat-ground crouch pumping, real ceiling clearance, ramp/landing seams in four directions/speeds and optional mantle intent/cancellation. Fixture setup may seed a labelled pose/velocity; it is not route proof.

`tests/spillway_driver.gd` supplies ordinary input events through the native game. It never writes position or velocity. Route traces record the seed, input changes, progress, resets, maximum per-tick displacement and a result denominator. Native screenshots/video establish the rendered view. A precise scripted line is evidence of executability, not discoverability or fun.

Input timing/aim perturbations and failures remain in the checkpoint. Normal-speed uninterrupted safe, fast and missed-jump recovery playback, representative approach/airborne/recovery frames, and an independent critique are separate required evidence. Machine rendering performance must name hardware and renderer. No agent can certify Mike's enjoyment or comfort from automated counts.

Clean records require all three ordered segments and no practice restart/checkpoint respawn since R. Shallow-water recovery is a valid slower clean line. Bot runs never persist personal records or settings. The game uses a fresh `user://spillway_v1.cfg`, not the old feel profile.

Results will be added after the actual runs; this document defines checks and makes no preemptive pass claim.

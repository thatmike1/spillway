# Spillway

Spillway is a first-person downhill parkour game in Godot4.7.2. The default build contains the complete Crest, Sluice yard and Outflow course. The current contract and checkpoint are [BRIEF.md](docs/reboot/BRIEF.md) and [STATUS.md](docs/reboot/STATUS.md).

Run, jump, slide down the dry chute, carry speed across the channel, or take the switchback stairs. A missed shortcut lands in shallow water with a walking way out. The new motor always enables jump buffering/coyote time, keeps ordinary landing momentum, and lets you correct in the air. An optional airborne mantle requires held forward+jump and cancels on jump release or backward input.

## Play

Linux, from this folder: `./tools/play.sh`. It uses the pinned engine at `~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`; set `GODOT` for another engine path.

Windows: double-click `Play Foldrunner.cmd`. The launcher installs the pinned official engine into `%LOCALAPPDATA%\Foldrunner\tools\godot-4.7.2` if needed, imports this project and starts Spillway. Native Windows gameplay remains untested.

WASD runs. Mouse looks. Space jumps. Ctrl/C crouches and slides. R starts a clean run. F restarts the segment for practice. Esc opens pause/settings. F11 toggles fullscreen. Clicking captures the mouse. Left/right gamepad sticks move/look; A jumps and LB crouches. Physical gamepad hardware is untested.

Settings include sensitivity, horizontal FOV, volume and comfort camera. The fresh profile is `user://spillway_v1.cfg`. Practice and checkpoint respawn cannot overwrite clean full-run records. Bot runs never persist settings/records.

## Verify

`./tools/check.sh` runs the new behavioral collision suite. `./tools/check-spillway.sh --play-routes --seed=0 --evidence-dir=/absolute/path/outside/git` also plays the authored safe, fast and recovery routes using real input events. Windows uses `tools/check.ps1` with the pinned engine. [VERIFICATION.md](docs/reboot/VERIFICATION.md) explicitly records which old reconstruction tests are retired.

Captures, original private reference material and external game specs stay outside Git. All current geometry, shaders and synthesized audio are original. Passing tests and scripted runs do not establish that a human enjoys the game.

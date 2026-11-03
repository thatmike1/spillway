# Foldrunner

Original first-person parkour slice in Godot 4.7.2 (Compatibility renderer). You run across evening rooftops; a tower ahead tips over and its facade becomes your road; the front wall of the next building falls toward you across the street and lands as a bridge; then the roof bends up into a second tower, you run up its face with the city turned on its side, crest over the top and finish under a beam of light. About 25 to 30 seconds for a clean run.

All code, geometry and sound are original and generated at load time from primitive meshes and synthesised waveforms. No third-party assets.

## Play (Linux)

```bash
./tools/play.sh
```

It imports the project on first run, then starts the game maximised. `GODOT=/path/to/godot ./tools/play.sh` picks another engine binary; extra arguments go to Godot (for example `--fullscreen`, or `--display-driver wayland` to use Godot's native Wayland backend instead of XWayland).

The game starts running at once: mouse look is live from the first frame, the mouse is captured as soon as the window has focus, and any click recaptures it. The timer starts on your first step.

| Input | Keyboard and mouse | Gamepad |
|---|---|---|
| Look | Mouse, or arrow keys | Right stick |
| Run | W A S D (speed builds while you keep running forward) | Left stick |
| Jump | Space | A / Cross, or RB |
| Slide (at speed), crouch | Ctrl or C | B / Circle, LB or LT |
| Vault and climb | Automatic: run at a low obstacle, or jump at a ledge | |
| Wall-run | Jump along a wall while holding forward | |
| Restart | R | Back / Select |
| Pause and settings | Esc | Start |
| Fullscreen | F11 | |

Pause holds mouse sensitivity, field of view (80 to 105, set at 16:9; wider screens see more to the sides), camera bank on wall-runs, view widening at speed, head bob (off by default), invert look and volume. Settings and the best time are kept in Godot's user folder.

## Checks

```bash
./tools/check.sh
```

Three headless suites with real physics:

- `test_player`: momentum, jump height, coyote time, mouse look without mouse capture, arrow-key look, pitch clamp, vault, climb, slide, wall-run, gravity surfaces, FOV maths for 16:9 and 21:9.
- `test_integration`: the assembled game starts unpaused with look live, the timer waits for the first step, the fold lands level with the roof, falls respawn at the last checkpoint with the fold intact, restart, pause, finish.
- `test_traversal`: a scripted runner completes the whole route using only held W, mouse-motion events and Space, with default comfort settings and again with camera bank off. It fails on any respawn or any per-tick jump in position over 0.35 m (no teleports).

Headless results say nothing about feel. Those need a person playing.

## Recording a run

`main.gd` reads a few user arguments after `--`: `--bot` lets the scripted runner play, `--bot-quit` quits two seconds after the finish, `--no-bank` turns camera bank off, `--from=N` starts at checkpoint N. Movie Maker turns that into frames, for example:

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy --rendering-driver opengl3 \
  --write-movie /tmp/run/f.png --fixed-fps 30 -- --bot --bot-quit
```

`--audio-driver Dummy` matters: without it the process can hang after the last frame.

## Layout

- `scripts/main.gd`: run state, input map (keyboard and gamepad), mouse capture, checkpoints, falls, cues, settings.
- `scripts/player.gd`: movement, gravity surfaces, the camera rig.
- `scripts/arms.gd`: first-person arms drawn in their own viewport over the scene.
- `scripts/level.gd`: the route, the city around it and the distant impossible blocks.
- `scripts/fold_block.gd`: a rigid block that turns about a hinge in three beats (tremble, turn, settle).
- `scripts/audio.gd`: synthesised footsteps, breath, landings, wind and the fold's groan.
- `scripts/bot.gd`: the scripted runner used by the traversal test and for recordings.
- `shaders/facade.gdshader`: procedural window bays laid out in the mesh's own space, so they turn with a fold.

`tools/*.ps1` and `Play Foldrunner.cmd` are the earlier Windows helpers; `check.ps1` runs the same three suites.

# Foldrunner

**Reboot planned, runtime unchanged:** Mike's Linux playtest rejected this build's feel. The current design is [Spillway](docs/reboot/BRIEF.md), a new controller and one finished dam-descent level. [The council](docs/reboot/COUNCIL.md) explains the decision; [the goal prompt](docs/reboot/GOAL.txt) starts the autonomous build. Everything below describes the pre-reboot game, not a completed Spillway build.

A first-person parkour game in Godot 4.7.2. It opens in an original training yard; Tab switches to the folding-city route, whose clean scripted run takes about 84 seconds. Speed builds quickly into a run, then slowly toward 7.2m/s. Footage-first jumps take about .79 seconds and rise 1.27 metres. Landings, vaults, grabs, rolls and wall jumps have separate momentum contracts. All geometry, body animation, materials and synthesized sound are original.

## Play on Windows

From this folder, double-click **Play Foldrunner.cmd**, or run it from PowerShell:

```powershell
.\Play Foldrunner.cmd
```

The launcher installs the pinned official Windows engine into `%LOCALAPPDATA%\Foldrunner\tools\godot-4.7.2` if needed, checks the release checksum when supplied, imports the project, then launches it. Git and PowerShell are the only checkout prerequisites. First setup downloads about 86MB. To use an existing engine:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run.ps1 -Godot C:\Godot\Godot_v4.7.2-stable_win64_console.exe
```

## Play on Linux

```bash
./tools/play.sh
```

The helper expects the pinned engine at `~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`. Set `GODOT` to use another location. Add `--display-driver wayland` to use native Wayland, or `--fullscreen`; F11 also toggles fullscreen.

The training yard opens unpaused, with free look immediately. It has a 1m grid, a 2.1m doorway, dimensioned obstacles/gaps/drops, a 75m sprint lane and a chain loop. Every obstacle has a bypass. Tab switches to the city; F3 toggles speed, state and landing metrics. Clicking recaptures the mouse. The timer waits for your first step. R restarts; falls return to the last reached roof with completed folds preserved.

| Action | Keyboard/mouse | Gamepad |
|---|---|---|
| Look | Mouse / arrow keys | Right stick |
| Run | WASD, continuous forward input earns speed | Left stick |
| Jump / contextual springboard | Space | A / Cross or RB |
| Slide / crouch; fresh press before landing to roll | Ctrl / C | B / Circle, LB or LT |
| 180 turn | Q | Y / Triangle |
| Restart | R | Back / Select |
| Pause and settings | Esc | Start |
| Switch yard / city | Tab | |
| Movement metrics | F3 | |
| Fullscreen | F11 | |

Vaults, grabs/pull-ups and wall climbs select from suitable geometry and forward intent. Jump along a wall to wall-run, then press jump to leave it. A roll needs a fresh crouch press within .2s before impact after a fall greater than 2m; holding crouch does not refresh it. Step toward taller steps slowly to step up, or carry speed to vault them.

## The route

Low roof vault; a connected block folds into a road; slide under its gantry; drop onto the second roof and choose either side of the stair housing; cross a falling facade; run the gravity bend and crest; climb/grab/pull onto the upper district; high vault; paired springboard into a roll; wall run and jump across a street; turn at the water tank; take the east cross street; slow terrace step; finish shelter. Small red hardware marks usable rails, lips, pipes and footplants through proximity/direction/fade rules. A street district turns its road toward the upper route; a continuous mirrored city spans overhead.

Pause settings include sensitivity, FOV, bank, volume and runner vision. Gait motion, up to +5° speed FOV, peripheral streaks and audible wind default on. One comfort option reduces camera motion and streaks. General jump grace remains a Foldrunner extension, off by default. Settings/best time are in Godot's `user://settings_feel.cfg`; scripted runs do not save them.

## Verify

```bash
./tools/check.sh
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\check.ps1
```

The twelve headless suites cover numeric traces, per-tick move handoffs and release frames, displacement-driven presentation, camera/body contact, runner vision, yard geometry/input and chain lap, controls/gravity surfaces, integration and two full city traversals. `tests/test_interface.gd` separately checks real UI input/layout in a rendered engine. Measured feel results are in [docs/FEEL-RESULTS.md](docs/FEEL-RESULTS.md). Predictions, tolerances and port choices are in [docs/VERIFICATION.md](docs/VERIFICATION.md). Runtime ownership is in [docs/CONTRACT.md](docs/CONTRACT.md). Tuning is SI in `data/movement.tres` and its script.

## Record

From this folder:

```bash
GODOT="$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"
xvfb-run -a -s '-screen 0 1280x720x24' "$GODOT" --path . --audio-driver Dummy --rendering-driver opengl3 \
  --write-movie /tmp/foldrunner/run.png --fixed-fps 10 -- --city --bot --bot-quit
```

Create the output folder first. Keep the virtual display at 1280×720: a taller maximized window causes Movie Maker to crop the foreground body. `--audio-driver Dummy` permits clean capture shutdown. Movie Maker's frame rate changes recording/input delivery, not the movement constants; 10fps permits all twelve 120Hz physics ticks per recorded frame. Captures and spec/reference files stay outside Git. Omit `--city` to record the yard chain. Useful user arguments: `--city`, `--no-hud`, `--no-bank`, `--detour`, `--from=N`, `--trace-run=/absolute/run.csv`. The bot supplies ordinary held inputs, mouse motion and action presses, flushing injected actions before the next physics substep; it never assigns route positions or velocity. `tests/render_moves.gd`, `tests/render_review.gd` and `tests/render_folds.gd` are labelled visual fixtures that reset between episodes, separate from route proof.

Windows script flow was tested in PowerShell on Linux with official archive/checksum validation and Linux Godot for execution. Native Windows gameplay and real controller hardware remain untested. Automated targets and two self-review render passes are evidence for this build, not a claim that a person has accepted its feel.

# Foldrunner

A first-person parkour run through a folding city, built in Godot 4.7.2. The clean scripted route takes about 84 seconds. Speed builds quickly into a run, then slowly toward 7.2m/s. Jump trajectory, landing costs, vaults, grabs, rolls and wall jumps have separate momentum contracts. All geometry, body animation, materials and synthesized sound are original.

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

The game starts unpaused, with free look immediately. Clicking recaptures the mouse. The timer waits for your first step. R restarts; falls return to the last reached roof with completed folds preserved.

| Action | Keyboard/mouse | Gamepad |
|---|---|---|
| Look | Mouse / arrow keys | Right stick |
| Run | WASD, continuous forward input earns speed | Left stick |
| Jump / contextual springboard | Space | A / Cross or RB |
| Slide / crouch; fresh press before landing to roll | Ctrl / C | B / Circle, LB or LT |
| 180 turn | Q | Y / Triangle |
| Restart | R | Back / Select |
| Pause and settings | Esc | Start |
| Fullscreen | F11 | |

Vaults, grabs/pull-ups and wall climbs select from suitable geometry and forward intent. Jump along a wall to wall-run, then press jump to leave it. A roll needs a fresh crouch press within .2s before impact after a fall greater than 2m; holding crouch does not refresh it. Step toward taller steps slowly to step up, or carry speed to vault them.

## The route

Low roof vault; a connected block folds into a road; slide under its gantry; drop onto the second roof and choose either side of the stair housing; cross a falling facade; run the gravity bend and crest; climb/grab/pull onto the upper district; high vault; paired springboard into a roll; wall run and jump across a street; turn at the water tank; take the east cross street; slow terrace step; finish beam. Red geometry marks authored traversal objects through proximity/direction/fade rules. A whole street district folds beside the upper route.

Pause settings include sensitivity, FOV, bank, volume and runner vision. Head bob defaults off. Speed FOV and general jump grace are explicitly labelled Foldrunner extensions and default off. Settings/best time are in Godot's `user://settings_me.cfg`; scripted runs do not save them.

## Verify

```bash
./tools/check.sh
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\check.ps1
```

The seven headless suites cover spec traces, move contracts, camera, runner vision, controls/gravity surfaces, integration and two full traversals. `tests/test_interface.gd` separately checks real UI input/layout in a rendered engine. Predictions, tolerances and port choices are in [docs/VERIFICATION.md](docs/VERIFICATION.md). Runtime ownership is in [docs/CONTRACT.md](docs/CONTRACT.md). Tuning is SI in `data/movement.tres` and its script.

## Record

From this folder:

```bash
GODOT="$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"
xvfb-run -a -s '-screen 0 1280x720x24' "$GODOT" --path . --audio-driver Dummy --rendering-driver opengl3 \
  --write-movie /tmp/foldrunner/run.png --fixed-fps 10 -- --bot --bot-quit
```

Create the output folder first. `--audio-driver Dummy` permits clean capture shutdown. Movie Maker's frame rate changes recording/input delivery, not the movement constants; 10fps permits all twelve 120Hz physics ticks per recorded frame. Captures and spec/reference files stay outside Git. Useful user arguments: `--no-bank`, `--detour`, `--from=N`, `--trace-run=/absolute/run.csv`. The bot supplies ordinary held inputs, mouse motion and action presses; it never assigns route positions or velocity. `tests/render_moves.gd` and `tests/render_folds.gd` are labelled visual fixtures that reset between episodes, separate from route proof.

Windows script flow was tested in PowerShell on Linux with official archive/checksum validation and Linux Godot for execution. Native Windows gameplay, real controller hardware and subjective feel still need a person playing.

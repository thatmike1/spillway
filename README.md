# Spillway: Overflow

Overflow is a downhill momentum game set in a working dam. Carry speed from the crest,
hop the pier's diagonal shortcut, and spend your momentum on the climb to the sluice.
Missed jumps lead into a bay or plunge pool with ramps that reconnect ahead.

The default scene is the R13 game. Its movement keeps earned speed, steers jumps with
W and mouse, and offers side-key carving for extra speed. All tuning is original P / game
choices. Surf, slide and automatic mantle are absent from this course. The design and
comparison evidence are in [BRIEF.md](docs/momentum/BRIEF.md),
[BUILD.md](docs/momentum/BUILD.md) and [OVERFLOW.md](docs/momentum/OVERFLOW.md).

## Play from source

Linux, from this folder: `./tools/play.sh`. It uses the pinned Godot 4.7.2 at
`~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`.
Set `GODOT` to use another engine path.

Windows: double-click `Play Spillway.cmd`. Its PowerShell launcher installs the pinned
official engine into `%LOCALAPPDATA%/Foldrunner/tools/godot-4.7.2` if needed, imports
the project and starts the default scene. Native Windows gameplay remains untested.

WASD moves and the mouse looks. Space jumps; holding it keeps hopping when autohop is
enabled. S brakes. Ctrl/C ducks. R immediately starts a clean run; F practises from the
last stage. Esc opens pause/settings, F11 toggles fullscreen, and clicking captures the
mouse. Gamepad sticks, A for jump and LB for duck are bound; physical gamepad play is
unverified.

Pause settings include sensitivity, horizontal FOV, volume, comfort camera and autohop.
Records and settings use `user://spillway_r13.cfg`. A clean ordered finish can set a full
course best. A physical skip can set an open-line best; practice and respawns record
neither. Records are separated by course geometry and tuning. R12 settings can seed the
first R13 start, but its records are untouched. Details are in
[PLAYABLE.md](docs/momentum/PLAYABLE.md).

The outer build workspace's `REPORT.md` identifies the last verified portable delivery.
Source changes do not automatically promote an older package to R13.

## Verification and assets

[TAPE.md](docs/momentum/TAPE.md) describes relative-input replay and moving evidence.
[CARRY.md](docs/momentum/CARRY.md) covers the shared controller and diagnostic profiles;
[OVERFLOW.md](docs/momentum/OVERFLOW.md) records actual route results and retained
failures. `./tools/check-spillway.sh` explicitly checks the historical R12 motor and
course, including its old scene when `--play-routes` is supplied. It is not R13 acceptance.

The licensed material kit uses four Poly Haven CC0 texture sets and original props.
[MANIFEST.json](assets/momentum/MANIFEST.json) records sources, licences, hashes and
modifications. See [ART.md](docs/momentum/ART.md). Private references, captures and game
specifications stay outside Git.

Scripted completion does not establish enjoyment. Native Windows play, physical input
and display latency, and Mike's satisfaction still need their own evidence.

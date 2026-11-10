# Through Line

R20 item 5 is a production Experiments entry. Two new segments exist together in one scene: **First Run**, a 60 m bhop runway, and **Second Run**, a raised landing court with an outflow run. The original eight maps, their finishes and the inherited F2 motor are unchanged. Revised Saltglass and Tether remain; Line Drive and Fall Line remain shelved.

The transfer is continuous in the tested simulation. There is no loading, menu, teleport, scene switch, replacement runner, clock reset or horizontal velocity assignment at launch or landing. Whether it *feels* seamless remains a native playtest decision. Headless routes and Dummy audio activation do not establish appearance, listening quality, discoverability or enjoyment.

## The experimental law

The trusted runner is `scripts/r20_through_player.gd`, extending the unchanged R15 Source runner. Its movement identity is `r20-through-launch-1`; map identity is `r20-through-line`, version 1. `mechanics()` exposes the complete law, which enters the ordinary timing/course key and ghost identity alongside geometry, runner, motor, preset and rate. Existing ghost validation refuses a different map, preset or mechanics law.

After each inherited motor step, reference feet must cross the gate's z=-40 m plane in the forward direction. The crossing interpolates between actual pre/post positions, subtracting duck origin compensation. Full hull width must fit inside x=-5..5 m, reference feet must be at y=3.8..8 m, horizontal speed must be at least 230 u/s, and velocity must align with world -Z by dot >=0.94. Ground support is deliberately unnecessary: the volume accepts actual airborne bhops. Reverse travel, a lateral/vertical near miss, low speed, poor alignment and another level identity refuse it.

At that crossing, with velocities in Source units:

```text
s = length(vx, vz)
vy_after = max(vy_before, 420 + 0.7*s)
vx_after = vx_before
vz_after = vz_before
1u = 0.0254m
```

Only vertical velocity is assigned. There is no normalization, horizontal gain, horizontal cap or continuing force. All later acceleration, gravity, air strafing, friction, collision, crouch and jump behavior is the inherited motor. Its existing component velocity bounds still apply. The tested entries are ordinary movement inputs from the authored spawn, far below those bounds. Increasing speed at the gate increases lift and ballistic range in these exercised entries; this does not promise every arbitrary mid-flight vertical initial condition has the same ordering.

One launch is consumed per `reset_to`. Remaining inside or recrossing the gate cannot pay out again. R, F and respawn use public reset paths and rearm it. Same-body preset changes retain the consumed state and clear feedback/transition monitoring. Map replacement removes the component. Pause preserves physical velocity, position, clock and consumed state; it stops the cue and resumes the same ballistic flight. There are no stored experimental forces to resume. Restart, practice, respawn, map, preset and quit clear feedback; non-pause boundaries also end transition monitoring.

## Route and feedback

First Run's cream deck is x=-8..8, z=-42..18, y=4. The fork is a tall pair of orange posts with outward rising fins and heavy feet; these meshes never obstruct its open aperture. Second Run starts at x=-24..24, z=-110..-47, y=7, and continues to the finish at z=-131..-140. Its paired towers, roof and `02 / SECOND RUN` sign establish the destination above the gap. Both segments' colliders exist from the initial build.

Dotted 3D arcs show ideal 250 and 500 u/s examples from the gate at floor height. They are static teaching marks, not a live prediction, force or aiming assist. Airborne entry height, incoming vertical speed, steering and discrete collision can move the actual landing. Orange example landing strokes sit on the receiving court.

Activation plays an original generated 0.38 s, 22050 Hz, mono signed-16-bit rising whistle/soft impact, through a real `AudioStreamPlayer` using the game's volume setting. It also shows a brief R18 cream/ink `RISE / SECOND RUN` strip and an inherited toast. The HUD then distinguishes flight from the second run. All new geometry, labels, arc marks and PCM are made in code for this component. No concept image or external asset is shipped by it; the existing project's licensed Look C/UI assets are inherited.

## Evidence and exact commands

From this project, the complete sequential proof is:

```bash
python3 -I tests/r20_through_check.py --out=/tmp/r20-through/accepted04 --scratch=/tmp/r20-through --keep-source
```

Use a new `--out` for another run. The helper keeps failed runs, bounds all owned scratch below 350 MiB, checks /home free space against 15,000,000,000 bytes, and uses only the pinned engine:

```text
/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
```

It creates an isolated source/import/profile snapshot and never redirects or modifies the live `.godot` symlink. It runs physical gate/lifecycle fixtures, current-map selection and L/F9 checks, actual matching/mismatched ghosts, paired ordinary F2 inputs on all original maps, two complete input-earned routes and exact open-loop replays, a complete moving-L route comparison, the native seam headlessly, the original movement/crouch suites, and both original recording readers and format suites. Negative/lifecycle fixtures are explicitly labelled and may set initial pose/velocity; accepted whole routes never write pose, velocity, view, score or progress after the normal authored spawn. Every key/button/action/mouse input column is compared, in order.

The compact acceptance contract lives outside Git at outer `look/evidence/r20-through-component/CONTRACT.json`. It links exact source hashes, executed commands, route measurements, all raw accepted and failed attempts, preservation receipts and limits. Raw evidence is `/tmp/r20-through`. The whole-goal release/parity/package gates belong to the parent.

## Native observational seam

`tests/r20_through_native.gd` inherits the same input-only route driver. The parent can run it in its own verified private AMD/X11 environment with Dummy audio. This component does not open a display or speakers. For the actual saved fast recording inputs, with an isolated source snapshot at `/tmp/r20-through/source`, the command is:

```bash
/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 128 --path /tmp/r20-through/source --script res://tests/r20_through_native.gd -- --out=/tmp/r20-through/parent-native-fast --tape=/tmp/r20-through/accepted04/fast-recorded.tape.json --size=1280x720
```

The parent's private display environment supplies the display. After component cleanup the source snapshot is removed; the parent can recreate it by rerunning the proof with a fresh output and `--keep-source`, then point the tape argument at that proof's saved tape. A source checkout with matching contract hashes also works as `--path`.

The seam saves a `frames.json` receipt with observation ticks, readback pose and image hashes, plus `first-run.png`, `launch.png`, `flight.png`, `apex.png`, `landing.png` and `continued-run.png` using viewport readback, together with the exact route telemetry, sealed recording and `launch-cue.wav`. Headless mode exercises the same code but intentionally makes no screenshot or rendering claim. The accepted cue WAV is also copied into the compact evidence folder for later private listening.

Recorder diagnostics use the existing arbitrary event channel `through`, with ordered `launch`, `apex`, `landing`, `continued` payloads. They award no points. Launch carries exact pre/post horizontal vectors and actual AudioStreamPlayer activation; landing carries the real grounded named support ray. `event()` timestamps the previous captured row under the frozen recorder's convention. Each payload therefore also names its exact post-step `motor_tick`, which the read-only full precision trace observes. The recording format and both readers are untouched.

Consulted project contracts: `docs/r16/BRIEF.md`, `docs/r16/INTERFACES.md`, the outer `R20-SPEC.md` and `playtest-r19/ANALYSIS.md`, and the R19 host/geometry/experiment patterns. External API checks used the official Godot 4.7 references for [AudioStreamWAV](https://docs.godotengine.org/en/4.7/classes/class_audiostreamwav.html) and [PhysicsRayQueryParameters3D.create](https://docs.godotengine.org/en/4.7/classes/class_physicsrayqueryparameters3d.html#class-physicsrayqueryparameters3d-method-create).

# R14 private AMD rendering checks

8 November 2026. These are real AMD rendering runs on the laptop, through a private
headless Weston compositor. They measure virtual draw intervals, not physical display or
mouse latency. Most other native evidence remains llvmpipe software rendering.

## A first-use beacon hitch was removed

Committed source `379d8f9f`, Godot 4.7.2 Compatibility, AMD Radeon Graphics / radeonsi,
1280×720, live 128 Hz physics and isolated cold profiles. No movie writer or fixed-fps mode
was used for the uncaptured timing runs. The engine held `/dev/dri/renderD128` open.

The ordinary practice-map finish beacon used a unique emissive StandardMaterial3D. Its
first appearance, about 2.85 seconds into the advanced input tape, compiled a new scene
shader and stopped drawing for about half a second. It is visible from well before the
finish. The original full run had a 509.9 ms interval; an exact six-second prefix reproduced
539 ms. Hiding the labels, water or shadows, changing the sky update mode, or replacing
course surfaces did not remove it. Hiding only the beacon did.

The repair gives the beacon a variant of the ochre kit material already drawn elsewhere.
It brightens its paint after a finish. This is a P presentation choice. No geometry, map
version, collision, physics, progress or record-key field changes.

| same input, same first-appearance window | largest draw interval |
|---|---:|
| original full route | 509.9 ms |
| repaired full route, no readbacks | 25.1 ms |
| repaired route with selected frame readbacks | 22.3 ms |

Both repaired full routes finish clean in 28.609375 seconds with zero respawns, as before.
Across the original 3,814 input ticks, stored velocity agrees exactly; position differs by
at most 0.330 mm. The difference starts with resting height at tick zero, and the executor
armed a different initial step. This is **not** a bit-identical trajectory claim. Geometry
checks still pass 1,599/1,599 with the same `8475d8a82763` hash. Root inspected the repaired
running and finish frames. The shader-cache entry associated with the original hitch is
absent in the repaired runs.

The original uncaptured practice run's median/p99 draw intervals were 16.66/33.10 ms.
The Overflow server run was 17.17/48.95 ms and finished clean in 45.8203125 seconds.
Another verification process was using substantial CPU, so these are observations under
contention. Readback captures deliberately stall drawing and are not timing benchmarks.
Other occasional long intervals remain; removing this reproducible hitch does not establish
uniform frame pacing.

## Shutdown was traced to Wayland teardown

The first four repaired-material runs completed their tapes, but two processes remained
alive after Quit and had to be terminated. A subsequent alternating six-run check had one
hang on the **unchanged baseline** and none in its three repaired-material repeats. Thus
this is not established as a regression from the material repair, and it is not fixed.
The tape executor uses the game's real `request_quit()` path, including its audio stop and
eight-frame wait. Records, when enabled, are saved on finishing before Quit.

The hang's thread wait channels were retained. A gdb attach was refused by the kernel's
ptrace policy; its zero exit status is not a successful backtrace. No system policy was
changed. All owned game/compositor processes and sockets were cleaned up.

A later bounded investigation on `1d7fe13d` reached every game-owned cleanup marker and
then found the main thread waiting for the Wayland events thread, which was polling an
idle socket forever. Godot's teardown code explains a possible lost wake-up. Forced
private Wayland/AMD hung in 5/7 tape runs; private X11/AMD exited in all 9 tape/menu runs.
These are small private-compositor samples, not a desktop or Windows guarantee. Future
private GPU checks use explicit free X11 display numbers. See [QUIT-REVIEW.md](QUIT-REVIEW.md)
for stacks, commands, the inference and the practical workaround. No game quit code changed.

The first diagnostic Xwayland briefly removed the desktop's X0 socket path. It was repaired
with a symlink to the desktop server's second listening socket; root independently verified
`DISPLAY=:0 xdpyinfo` answered afterwards. The symlink remains until logout or restart.
The corrected diagnostic helper never auto-selects a display and checks the desktop socket
before and after its private runs. The full incident is retained in the review evidence.

## Evidence and reproduction

The outer workspace's `checkpoints/spillway/r14/hardware-render/` holds the helpers,
frozen-source manifests, every diagnostic variant, gzipped traces, selected PNGs and logs:

- `run.py`, `hitch-probe.py`, `candidate-run.py`, `quit-diagnostic.py` preserve the commands.
- `RESULTS-initial.json` and `CANDIDATE-ANALYSIS.json` are root analyses of retained traces.
- `candidate-full/` and `candidate-frames/` include the repaired full route and finish.
- `QUIT-REPEAT.json` indexes the alternating shutdown checks, including the failed attach.
- `download.json` and bootstrap logs record the verified official Arch Weston package and
  the rejected initial signature/module-loading attempts. No desktop setup was changed.

Fresh checks must use the current committed game and final pack. These observations do not
establish native Windows behavior, physical input latency, or whether Mike likes the feel.

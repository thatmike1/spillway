# R14 shipped Linux pack: OS input

8 November 2026. **22/22 checks pass. No actual input delivery issue was observed.**
The exact candidate release runtime and pack received X11 OS input on a private
AMD-backed display. Production gameplay was unchanged.

Evidence root:
`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/os-input/`.
`analysis.json` judges attempt 04. `attempt-04/run.json` contains every xdotool
command, each XTest relative request, runtime command, hashes, GPU evidence and
cleanup. Each attempt retains compressed event/physics telemetry. Seven selected
JPEGs are from attempts 02 and 03; attempt 04 deliberately captures none. Total
evidence is approximately 1.02 MiB, with no movies or PNGs.

## Identity and method

Candidate: outer `delivery/work/r14-candidate-5484f10d`.

| item | exact identity |
| --- | --- |
| source commit | `5484f10d1c1ef009fd22de76651431db7e1e065e` |
| source project tree | `0ab183720b1088a36b2f60db1a5bfe94130286de` |
| source archive SHA-256 | `447ab44d96127079d4edcca587e1d20548e2e3606fe875589b98c29937b597ea` |
| 486-file source manifest SHA-256 | `3a1a48480f29479eb708f0f0fc3a151781649093f8dfef4f691e7035d2c07013` |
| Linux ZIP SHA-256 | `b849ce5ebb177b95a7b1c1a7683869d87e515142048542b41b2579d85593c7b4` |
| shipped PCK SHA-256 | `4e6446043e8f17c07673cead946e06e4c1f9e3473e73604bdef81cc5cf0654a8` |
| release executable SHA-256 | `d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63` |
| observer SHA-256 | `0f5f2d93b5dff2e092558d81588ed1be61a575e57a9676e8337eb03c69a29530` |
| final driver SHA-256 | `19cda593ec258eb3cd0a43b244f019e264202352ea514e6a59c1bfb7d896c4f2` |
| analyzer SHA-256 | `0eb63ed87bdb5d939992a8a9ccb15cbc20ce39e69a9e5ac4b0fee5c36aba13c5` |
| NativeDisplay helper SHA-256 | `7a6f6cae8c8d81532aba4746c8b0511cd4a46dd723f4e67f834428f71ae34b8e` |

The analyzer independently reconstructs the source archive with the commit's
timestamp and hashes every regular file. Tree, archive, manifest and count match
the candidate BUILD.json. Executable and pack hashes match before and after each
run; the executable also matches the official 4.7.2 Linux release template digest
recorded in BUILD.json. This checks the recorded source/package identity without
claiming an independent reproducible re-export.

The ZIP was extracted to a private `/dev/shm/r14-os-input-*` directory. A
harness-only `override.cfg` adds `r14_os_input_observer.gd` as an autoload. The
pack's own `res://scenes/r14.tscn` remains the main scene. The observer confirms
`template_release=true`, editor/debug false, no loose `res://` root, the real
`r14_main.gd` and `r14_source_player.gd`, Godot 4.7.2 official
`ed1daf0bf001b61586d9930840f2f1394092c079`, and records off. It only reads game
state, observes input and writes telemetry. It never calls a game control API or
writes player position, velocity, camera, progress or movement state.

All control comes through xdotool's normal XTest path without `--window` event
delivery, or `libXtst.XTestFakeRelativeMotionEvent`. `mousemove --window` is used
only to locate ordinary pause-menu clicks. There is no `Input.parse_input_event`,
action injection, tape executor or observer teleport. Penstock straight is reached
through Esc, the native stage-picker popup and its Practise here button. Later F
presses use the production practice restart.

The API reads were NATIVE-DISPLAY.md, INTERFACES.md, the native-display helper and
existing native test, the package override implementation, player/HUD source, and
the installed xdotool manpage and XTest header/manpage.

## Observed results

| control | actual result in attempt 04 |
| --- | --- |
| default W + held Space | 4 jumps; physical W/Space read as held |
| F2, stage 3, W + held Space | 3 jumps |
| F1 held Space, 1.65 s | exactly 1 jump; landed with Space still held |
| release + fresh Space | jump count 2 |
| wheel up | jump count 3, airborne; OS button 4 observed |
| F1/F2/F3/F4/F5 | vanilla64 / server128 / R13 / Q3-inspired / AA1000 and their matching HUD identities |
| physics | observed 64, 128, 120, 128, 128 Hz with their exact deltas; zero rate mismatch ticks |
| stage picker | `3  Penstock straight` selected; practice stage 3 started through the UI |
| D + rightward mouse | airborne 250.0000 to 255.0593 u/s, view turned right 6.6 degrees |
| A + leftward mouse | airborne 250.0000 to 255.0593 u/s, view turned left 6.6 degrees |
| no keys in flight | 24 samples, 23 intervals / 0.1796875 simulated seconds, 1.1641 m horizontal travel; zero horizontal velocity drift |
| Escape | pause, resume, pause all observed |
| pointer click Quit | exit 0, 0.5114 s after the click sequence began |

For strafing, W establishes 250 u/s on the ground, Space starts the flight, W is
released, then A or D is held with ten same-direction 12-unit XTest relative moves.
Simultaneously starting W and Space at rest produces repeated hops at about 30
u/s here: the jump enters the air before a ground run builds 250 u/s. Those two
checks exercise different starting inputs; neither lost its W/Space events.

Mouse calibration requested XTest relative `(100, 0)` and the read-only observer
received a summed `screen_relative` of `(100, 0)`. At Source sensitivity 2.5 and
`m_yaw=0.022`, the expected yaw change is `-5.5` degrees, or
`-0.09599310885968812` radians. The observed change was
`-0.09599310885968992`, error `-1.8041124150158794e-15` radians. Each strafe's
ten requests likewise arrived as summed +120 or -120 screen units. These are
established synthetic delivered deltas, not measurements of physical mouse counts.

## AMD and isolation

The helper selected :190 for attempts 01–03 and :191 for attempt 04, avoiding the
then-occupied :190. Only the explicit 190–199 range was offered, without displayfd.
Attempt 04's executable PID and PGID were both 1358595. GpuWatch sampled its actual
amdgpu renderD128 client 2913, PCI `0000:03:00.0`, in 78/80 samples, with
`4,933,800,723` ns of kernel gfx engine work. Godot independently reported:

```
OpenGL API 4.6 (Core Profile) Mesa 26.2.5-arch1.1 - Compatibility - Using Device: AMD - AMD Radeon Graphics (radeonsi, renoir, ACO, DRM 3.64, 7.2.8-9-omarchy)
```

HOME free space was checked before each native launch: 15.0458, 15.1097, 15.1015,
and 15.0806 GiB respectively. Each run uses `--no-records` with separate XDG
data/config/cache/state directories. No record configuration was created.

The final driver has a 240 s action deadline, 260 s outer alarm, bounded command
timeouts, a private game process group and parent-death termination. Finally blocks
release keys/buttons on the private display, stop the game and GPU watcher, and
remove the profile and extraction. NativeDisplay owns compositor/Xwayland cleanup.
Every attempt's retained cleanup record reports no owned processes, X sockets,
runtime directory or RAM scratch left. Desktop :0 answered before and after every
attempt; no desktop input, desktop configuration or system configuration was changed.

## Retained failed attempts and limits

- Attempt 01: unsupported global `xdotool --display` argument. Corrected to the
  private child environment's DISPLAY. The packed game and AMD rendering had
  started, but no control test had run.
- Attempt 02: Home and three Down presses in the native popup selected stage 2,
  not stage 3. The first Down establishes the popup's keyboard selection. Home
  and four Down presses reached stage 3 in attempts 03 and 04. This was a harness
  navigation expectation, with actual OS events retained, not lost game input.
- Attempt 03 passed the complete control sequence. Review then caught that the
  wrapper lacked a private game process group. Earlier forced-stop paths finished
  when the private X server closed, leaving shutdown diagnostics in their logs.
  The driver now creates its own session/group; attempt 04 repeats the successful
  sequence with that fix, and exits through the real Quit button. Both successful
  runs have no engine ERROR lines. The XIM-not-started warning remains.
- The first analyzer invocation ran git archive from the project subdirectory,
  accidentally filtering the subtree archive to zero files. Its failed result is
  preserved as `analysis-attempt-01.json`. Running from the checkout root proves
  the exact 486-file source identity; final `analysis.json` passes all 22 checks.

This is short OS-input-path evidence on Linux Xwayland. XTest is synthetic OS
input, not a physical-device latency, feel, performance, Windows, whole-route or
discovery result. The coast window is intentionally short. The read-only observer
adds logging work and the private compositor has its own refresh cadence.

## Commands

From the checkout root, the native attempts were:

```bash
python3 -I projects/foldrunner/tests/r14_os_input_native.py --evidence /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/os-input/attempt-01
python3 -I projects/foldrunner/tests/r14_os_input_native.py --evidence /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/os-input/attempt-02
python3 -I projects/foldrunner/tests/r14_os_input_native.py --evidence /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/os-input/attempt-03 --shots 05-penstock-straight,06-strafe-coast,07-quit-menu
python3 -I projects/foldrunner/tests/r14_os_input_native.py --evidence /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/os-input/attempt-04 --shots none
python3 -I projects/foldrunner/tests/r14_os_input_analyze.py --evidence /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/os-input --attempt attempt-04
```

The first two commands ran the earlier harness versions described above. A fresh
reproduction needs a new empty evidence path. Do not overwrite retained attempts.
The source identity command, also run by the analyzer from the checkout root, is:

```bash
git archive --format=tar --mtime=@1794159301 5484f10d1c1ef009fd22de76651431db7e1e065e:projects/foldrunner
```

Attempt 04's actual release process command was:

```bash
/dev/shm/r14-os-input-g2n3jwfb/release/SpillwayR14-linux-x86_64/SpillwayR14.x86_64 --verbose --audio-driver Dummy --display-driver x11 --rendering-driver opengl3 --windowed --resolution 1280x720 -- --no-records --os-observer=/dev/shm/r14-os-input-g2n3jwfb/observer
```

That scratch directory is removed. The driver recreates it with a fresh name,
checks the same runtime and pack bytes, and assigns a free private display through
NativeDisplay. No exports, production edits, delegated agents or commits were made by this task.

## Root repeat on the final helper-pinned pack

The driver and analyzer now accept `--package DIR`, so reproductions can select an
immutable package explicitly. Root repeated the complete XTest sequence on source
`65d205be`, pack `fc77461baa5387549ce7ec2b5c2796d656b83aaf2a8fd1e8674d614a7b0b0067`,
using the exact ZIP copy that the fresh package refusal tests used. Evidence is outer
`checkpoints/spillway/r14/os-input-final/analysis.json`: **22/22**, no input delivery
issue, both strafes250to255.0593u/s,100deliveredpixels=5.5degrees, zero velocity drift
over0.1796875simulatedseconds, correct manual/held/wheel behavior, allpresetkeys,
stagepicker and error-free Quit0. Three selected JPEGs and compressed telemetry total
less than0.5MiB. No physical-device, latency or feel claim follows.

From `projects/foldrunner`, the verified repeat commands were:

```sh
python3 tests/r14_os_input_native.py --package /tmp/r14-negative-base-65d205be --evidence /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/os-input-final/attempt-01 --shots 05-penstock-straight,06-strafe-coast,07-quit-menu
python3 tests/r14_os_input_analyze.py --package /tmp/r14-negative-base-65d205be --evidence /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/os-input-final --attempt attempt-01
```

The temporary baseline copy will be removed after promotion. For a fresh reproduction,
pass the final outer `delivery/spillway-r14/` package and a new evidence directory.

The current helper default is the promoted `delivery/spillway-r14/`. Historical attempt commands above ran before that default changed; use `--package` to select any other retained package explicitly.

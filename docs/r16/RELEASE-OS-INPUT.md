# R16 normal Linux launch and OS input

The normal Linux ZIP from source `67e608a0f2b9dbb31b31ff8f63bdc3fd8491a1e3` passes 12/12 smoke checks. It launches the official release runtime with its shipped pack, default scene, default recording flag and ordinary frame scheduling. There is no `override.cfg`, injected game script, probe, `--fixed-fps` or edited profile. This is a short synthetic OS-input check, not a complete course or a physical-device latency test.

Run from `projects/foldrunner` with a new evidence directory:

```sh
python3 -I tests/r16_release_os_smoke.py \
  --candidate /tmp/r16-negative-base-67e608a0 \
  --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/release-os-smoke-new
```

The candidate directory must hold its BUILD.json and Linux ZIP. The helper verifies the source manifest, pack digest and independently pinned official Linux runtime digest before play. It extracts to a unique RAM directory, uses isolated HOME/XDG data and Dummy audio, and reserves the checked private AMD/X11 display range 196–199. It checks the 15 GiB HOME floor before launching. The game is stopped before the compositor on an exception; owned profiles and extraction are removed afterward.

The input journal records `xdotool` XTest key/mouse commands. It waits for actual recorded physics before sending W, Space, A, mouse motion and C. It then restarts with R, runs another hop, sends G, opens Esc and reaches the production Quit button with keyboard focus. No coordinates or game-state observer steer the movement. Reading the recording prefix is used only for startup readiness.

## Executed result

Evidence: outer `checkpoints/spillway/r16/release-os-smoke4/`.

- `RESULTS.json`: 12/12 checks, no exception, exit 0, correct default R16/Breakwater/F2 title, error-free engine log, previous-round profiles unchanged and private display released.
- `recordings/`: two sealed default attempt files, a 475-tick restart and a 193-tick Quit. The first has 22 airborne-crouch ticks. OS key edges, mouse input and changed yaw are present.
- `BOTH-READERS.json`: a separate post-exit harness uses the exact official runtime and current Godot reader. Both recordings agree with Python on every binary tick column and input field. JSON event/seal numbers agree under the existing parser representation rule. This post-exit reader harness is separate from the unmodified player launch.
- `gpu.json` and the display record: Godot reports AMD and the kernel attributes 3,322,920,086 ns of graphics work to the release process. This proves GPU use, not a performance or latency measurement.
- `pause.jpg`: the actual menu shows the local recording path and copy-back instruction. The command journal, engine log and display ownership record remain beside it.

Executed identities:

| Item | SHA-256 |
| --- | --- |
| Linux ZIP | `f8ae42da4c55d9675056033a462310642519bba194001ecfa92c03058a841320` |
| Shared game pack | `845d727694efee6bbbf143d770db7a9971ecd2e69124949064945265701493f1` |
| Smoke script | `4958dc32ce022dbca3d01f138cdb7902d15a43f2669d6cb8cfb6c28f9c16d373` |
| Post-exit reader probe | `1a9e1ce7a55f446b49cb33587f073932a7d89bc934387eb810759a9a2a8322fe` |

## Retained failed attempts

`release-os-smoke/` could not open the temporarily truncated negative-test baseline ZIP; no game launched. The independent positive export remained unchanged, and root restored and rehashed the negative copy before further work.

`release-os-smoke2/` waited for buffered stdout as readiness and timed out before sending controls. Its error cleanup closed the display before stopping the game, producing X connection/resource errors. Root corrected ownership ordering in the harness; these are retained diagnostic errors, not an accepted player shutdown.

`release-os-smoke3/` treated the window title as readiness. Controls arrived during startup, before sustained physics; three movement checks failed, although the input edges remained in boundary events and Quit exited 0 with no engine error. The final harness waits for a captured physics prefix and the fourth attempt passes. No production code changed for these harness repairs.

Windows execution, physical keyboard/mouse latency, gamepad, audible audio and Mike's verdict remain outside this result. The full packed route/record/style/ghost checks have their own acceptance record.

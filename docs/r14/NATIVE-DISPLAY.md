# R14 private AMD/X11 display for native checks

8 November 2026. `tools/r14_native_display.py` is an optional verification backend. It
gives final native and packed checks a real AMD renderer instead of llvmpipe on Xvfb. It
changes no game, motor, tape, cadence or tolerance. Nothing uses it yet: root wires it into
the package tools once their owner is back.

## What it does

`NativeDisplay(evidence)` is a context manager that owns two processes:

- a private headless Weston 15.0.1 using the GL renderer on `/dev/dri/renderD128`. This is
  the signature-verified Arch package already in `r14/hardware-render/weston`, and every
  binary and library is checked against the package's own `.MTREE` digests on each start;
- a rootful `/usr/bin/Xwayland` as a client of that Weston, on an explicit display number
  from :190 to :199.

It yields `number`, `display`, `env` (only `DISPLAY`) and `child_env(base)`. `child_env`
returns a copy of `base` without forced software or Mesa routing (`LIBGL_ALWAYS_SOFTWARE`,
`GALLIUM_DRIVER`, `MESA_LOADER_DRIVER_OVERRIDE`, `EGL_PLATFORM`, ...), without the parent's
`WAYLAND_DISPLAY`, `WAYLAND_SOCKET` or `XAUTHORITY`, and with `DISPLAY` set to the private
server. The source environment is never changed. The caller owns the game process.

`GpuWatch` samples a process tree's open render-node fds and the kernel's drm fdinfo. Use it
as a `run_engine` watch, or call `follow(pid)`. `require()` passes only if a process in the
tree held the node on `amdgpu` and the kernel counted gfx engine time for that client. In
other words, the GPU drew for the game, not just opened. `require_amd_log(text)` checks
Godot's own `Using Device:` line as well. `combine(a, b)` runs two watches on one process.

## Refusals: it never falls back

Each of these raises `NativeDisplayError`, and cleanup is recorded:

- /home has less than 15 GiB free;
- the render node is missing, is not `amdgpu`, or is not accessible;
- the Weston files differ from the package manifest, or a stray module is present;
- Xwayland is missing;
- the desktop `:0` does not answer `xdpyinfo` before the session starts;
- every requested display is held. A display counts as held if it has a lock file (stale
  ones included), a socket path (dangling symlinks included, such as the desktop's
  `X0 -> X0_`), an abstract `@/tmp/.X11-unix/XN` listener, a bound path, or a per-number
  flock taken by another `NativeDisplay`;
- Weston exits early, offers no socket, or reports a software renderer. A forced
  `LIBGL_ALWAYS_SOFTWARE` Weston reports llvmpipe and is refused, not used;
- Xwayland exits early, its lock belongs to another pid, it never answers, or it holds no
  amdgpu render node (glamor not on the GPU);
- the evidence directory is not empty. Weston appends to its log, so an old renderer line
  could otherwise pass for the current one.

Xwayland `-displayfd` is never used. With it, an earlier probe took the desktop's :0
(QUIT-REVIEW.md, "Incident"). The desktop is only ever queried with `xdpyinfo`. Its socket,
the `X0` symlink, its configuration and system policy are never touched.

## Cleanup

On success, on an exception, on SIGINT or SIGTERM inside the `with` block (raised as
`Cancelled`, a `KeyboardInterrupt`), and on any launch failure, cleanup does the following:

1. stop Xwayland, then Weston: SIGTERM to each process group, then SIGKILL;
2. kill anything left in their sessions;
3. remove a lock and socket only if this session's own dead Xwayland wrote them. Files that
   belong to another server are reported as `foreign` and left alone;
4. delete the private runtime directory, release the flock, and query `:0` again.

Signals that arrive during cleanup, or while a child is being spawned, are held until
cleanup is finished. Signal handlers are restored afterwards. Children also get a
parent-death SIGTERM, so a SIGKILLed wrapper does not leave a compositor running; its
`/tmp/r14nd-*` runtime directory is the only thing left. If cleanup is incomplete after a
successful body, it raises. The full record goes to `<evidence>/native-display.json`:
commands, pids, the Weston GL strings and render fds, the display checks, the desktop
before and after, and the cleanup result.

Root integration caught a launch-boundary cancellation gap: a signal just before
`Popen` returned could abort the caller's process assignment. Ownership is now recorded
inside `_spawn` before deferred signals are raised. A no-display regression uses a
disposable sleeping child and reproduces the leak before the fix for both SIGINT and
SIGTERM; both children are cleaned after it. Root also pinned `.MTREE` itself to the
digest extracted from the already pinned package, so a changed manifest cannot attest
to changed binaries. Original worker evidence predates these verification-only fixes.
Root's offline run passes 11 tests (12 live/game tests explicitly skipped), and a fresh
real AMD display start/release passes with desktop :0 answering before and after.

A later independent cancellation test found the same allocation-before-assignment gap
for an empty runtime directory. Runtime allocation now shares the deferred-signal guard
with process launch. All seven independent ownership/refusal tests pass after the fix;
see [RECORD-DISPLAY-REVIEW.md](RECORD-DISPLAY-REVIEW.md). No renderer or game behavior changes.

The root window is 1296×736, one size up from the 1280×720 game window. At exactly the
window's size, Xwayland flips the game's buffers directly to Weston, and a capture of the X
root kept showing a stale frame (the pause menu was missing). One size larger keeps
captures live. Godot centres the window at (8, 8).

## Fitting `tools/package-r14.py` (not edited; owned by the delivery worker)

That tool's `Display(number, log)` owns an Xvfb, and the rest of the tool passes the number
on. The swap keeps that shape:

```python
with NativeDisplay(evidence / 'runs/native-display') as display:     # instead of Display(args.display, log)
    env = display.child_env(engine_env(profile, display.number))
    gpu = display.gpu_watch()
    code, text = run_engine(cmd, cwd, env, log, deadline, combine(window_titles(display.number, titles), gpu))
    record('native: rendered on amdgpu', gpu.verdict()['ok'] and godot_device(text) ...)
runs['display_released'] = display.released
```

A packed run with this backend is AMD evidence only if it records `gpu.verdict()` and the
device line. Xvfb remains the portable path.

## Verification, 8 November

Source copy of `731fe1b1` (`git archive` sha256 `b2215969…d070`, imported with exit 0),
Godot 4.7.2 official, Compatibility, Dummy audio, isolated XDG profiles. Evidence is in the
outer `checkpoints/spillway/r14/native-display/`.

- **Unit and live checks**, `tests/test_r14_native_display.py`, 22/22. Offline: env copy,
  every busy-display signal (including a real abstract listener), flock separation, the
  render-node driver, a tampered or extra Weston file, the device line, a watch on a
  process that never opens the node. Live: a GL client renders on amdgpu even with
  `LIBGL_ALWAYS_SOFTWARE=1` in its base env; body exception; SIGTERM inside the block;
  SIGINT to a wrapper process; SIGKILL of a wrapper (children die, X files gone); Weston
  and Xwayland launch failures; missing Xwayland; a software Weston refused; a held
  display refused without launching; two concurrent sessions on different numbers. Every
  run left no owned process, X file or abstract socket, and `:0` answered afterwards.
- **Real R14 scene and Quit through X11 input.** The real `scenes/r14.tscn` ran under a
  read-only observer (`OBSERVER` in the test), with `--no-records`. XTEST `Escape` (via
  `xdotool`) opened the pause menu. A pointer click on the Quit button position the
  observer reported reached the production `request_quit`, and the game exited 0 about
  0.5 s after the click. The game held renderD128 on amdgpu with about 3 s of gfx engine
  time. The device line was `AMD Radeon Graphics (radeonsi, renoir, ACO, DRM 3.64)`.
  Running and paused captures differ.
- **Full Overflow F2 tape.** The current actual-main recording
  `r14/overflow-final-source/record-server2/events.tape.json` (sha256 `7427202b…5aff`,
  unchanged afterwards), setup-only `game.gd` (`0a5c7c0c…9008`), `server128`, 128 Hz,
  warmup 8. The tape executor ran first headless, then on this display, with
  `--fixed-fps 128` and `--frames=none`:

  | | headless | native AMD |
  |---|---|---|
  | finish | clean 45.9609375 s | clean 45.9609375 s |
  | stages seen / respawns | 0–3 / 0 | 0–3 / 0 |
  | delivery, order, rate | ok | ok |
  | draws per physics step | 0 | 1.0 (6279/6279) |
  | executor wall time | 13.6 s | 111.5 s |
  | exit | 0 | 0 (the tape's production `request_quit`) |

  Native exactness was measured, not assumed. All 6271 tape ticks are equal to the headless
  run: maximum position, velocity and yaw differences are 0.0, and the applied events are
  identical. GpuWatch saw renderD128 in 411 of 414 samples, with about 72 s of amdgpu gfx
  time. Three live captures at 20, 60 and 100 s wall time are kept.

## What this does not establish

This is a source-mode backend proof on one tape and one scene. It is not release-pack
acceptance and not a performance, frame-pacing or latency measurement: 111.5 s is about
56 draws a second against Weston's 60 Hz private refresh, under other agents' load, and a
higher `refresh_mhz` is untested. The X11 Quit route was clean 1/1 here and 9/9 in the quit
investigation. That is a small sample, not an immunity claim. It says nothing about the
desktop compositor, Windows, physical input or feel. The private X server runs without an
auth cookie (the proven command), so any local process of this user can connect to it
while it runs.

## Reproduction

```
python3 -I tools/r14_native_display.py status
python3 -I tools/r14_native_display.py probe --evidence DIR
python3 -I tests/test_r14_native_display.py prepare 731fe1b1 SRC
R14_NATIVE_SOURCE=SRC R14_NATIVE_KEEP=DIR python3 -I tests/test_r14_native_display.py
python3 -I tests/test_r14_native_display.py overflow --source SRC --tape TAPE --game GAME --evidence DIR
```

# R14 private AMD shutdown hang

8 November 2026. Committed source `1d7fe13d` (git archive sha256 `8e84c163…cc7d`), Godot
4.7.2 official `ed1daf0bf` (binary sha256 `8d106cbe…f71e`), Compatibility, AMD Radeon
Graphics / radeonsi, private headless Weston 15.0.1 from `hardware-render/weston`, Dummy audio,
isolated tmpfs profiles. No desktop output, configuration or ptrace policy was changed. One
desktop side effect happened and was repaired. It is described below under "Incident".

## Finding

The hang is an engine race in Godot's Wayland display server teardown. It is not in the
game, the GPU driver or the material repair. **Production is unchanged**: no safe game-side
fix exists, because every line of game script has already returned when the process sticks.

Each hung process got through every game-owned stage: `request_quit`, all eight production
wait frames, `SceneTree.quit`, the main node's `_exit_tree` and predelete, and the main loop's
`_finalize`. After that, script code no longer runs. Stacks were taken with gdb, which the
disposable game child allowed by calling `prctl(PR_SET_PTRACER, harness pid)` before exec.
They were identical in all five hangs and unchanged 5 s later:

- the main thread is in `pthread_join` (libc offset `0x99e8d`, inside `pthread_join`), called
  from Godot's `Thread::wait_to_finish`;
- the `Wayland Events` thread is in `poll(fds, 1, -1)`, which waits forever. In
  `c-wl-amd-pollfd-1`, gdb read its pollfd as fd 8 with POLLIN. `ss` shows fd 8 is the game's
  connected socket to the private Weston (`r14-quit`), with nothing queued;
- worker, mesa (`cs0`, `gdrv0`, `gl0`, `sh*`, `disk$*`) and glib threads are idle in condition
  waits. The Dummy audio thread is still sleeping in its loop. Weston stays alive.

Godot 4.7.2 `WaylandThread::destroy()` sets `thread_done`, then calls
`wl_display_roundtrip()` "to unblock the polling thread", then joins it. The events thread
checks `thread_done` only after its `poll(-1)` returns. `~DisplayServerWayland` destroys the
windows just before that, so compositor events are in flight. If the events thread is busy
dispatching when the roundtrip reply arrives, the main thread's own roundtrip consumes the
reply. The events thread then re-enters `poll(-1)` on an idle socket, and the join never
returns. Line-numbered excerpts are in `godot-source-excerpts.txt`. The same `destroy()` and
`poll(&poll_fd, 1, -1)` are still on Godot `master` as fetched today.

## Bounded alternating reproduction

Same committed game, same 6 s practice prefix tape (`tape-practice-prefix.json`, sha256
`412c48b0…54a5`), `server128`, 1280×720, on the same private Weston. A run counts as hung
when it is still alive 20 s after the tape's `end.json`.

| display | GL | quit route | map | hung / runs |
|---|---|---|---|---:|
| Wayland | AMD | tape `request_quit` | practice | **5 / 7** |
| X11 (private rootful Xwayland) | AMD | tape `request_quit` | practice | 0 / 6 |
| Wayland | AMD | Escape, then a click on the menu's Quit button | Overflow | 0 / 2 |
| X11 | AMD | Escape, then a click on the menu's Quit button | Overflow | 0 / 3 |
| Wayland | llvmpipe | tape | practice | 0 / 3 |
| X11 | llvmpipe | tape | practice | 0 / 2 |

The series alternated Wayland and X11 runs pair by pair (`series.sh`). Every clean run exited 0
within 0.35–0.81 s of the tape end on AMD, and within 3.4–3.8 s on llvmpipe. No clean run
logged an error, a leaked RID or a texture leak. The menu route sends real pause and mouse
input events: the click on Quit reached production `request_quit` while paused. Records
were off in these runs. Since production is unchanged, saving on finish before Quit has not
been retested here.

What this does **not** establish: the Wayland menu-route and llvmpipe zeros are small
samples. They do not show that those paths are immune, since the race only depends on
Wayland event timing. It was not run on Mike's desktop compositor or on Windows. The R13
4/~35 hangs were not re-run. They used the same private Wayland route, so they are probably
this race, but that is unverified. Nothing here is a latency or feel observation.

## Who is affected and the practical workaround

- **Players.** Godot's `default` display driver is index 0, which is X11 (`os_linuxbsd.cpp`
  registers X11 first). Wayland is only a fallback, and the project sets no Wayland
  preference. Inside Hyprland with XWayland and `DISPLAY` set, the shipped game therefore
  uses X11, which did not hang in 0/9 AMD runs. The race applies only when the game is
  started with `--display-driver wayland` or without a usable X display. This comes from
  the source and the series above, not from a desktop run.
- **Private hardware checks.** Use the X11 route: a private rootful Xwayland with an
  explicit, verified-free display number (`probe.py ... x11 amd`). It keeps the actual AMD
  render node (`/dev/dri/renderD128` held in every run) and exits cleanly. If a Wayland
  run is still wanted, a process that is alive after the `main loop finalize` marker, with
  the signature above, is this engine teardown hang. Terminate it and label it, never count
  it as a pass.
- **Engine.** A real fix belongs in Godot: wake the events thread with its own eventfd in the
  poll set, or poll with a timeout and recheck `thread_done`. Patching Godot is outside this
  round. Process killing, exit bypasses and longer delays were not used.

## Incident: desktop X socket path

The first private Xwayland attempt let `-displayfd` pick a display number. Hyprland's :0 has
a lock file but no abstract socket, and with `-displayfd` Xwayland binds sockets before it
checks the lock. It therefore unlinked and rebound `/tmp/.X11-unix/X0`. The harness refused
to start the game on :0 and stopped that Xwayland, whose exit removed the path. For about a
minute, new X11 clients on :0 could not connect. Existing ones were unaffected. The path
was restored as a symlink to the desktop Xwayland's second listening socket, `X0 -> X0_`
(owned by thatmike1). After that, `DISPLAY=:0 xdpyinfo` answered. A logout/login restores
Hyprland's own socket. Details are in `INCIDENT-desktop-x0-socket.md`. The harness now uses
explicit free numbers only (:190–199, here :190) and checks that :0 answers before and
after every run. It answered after all 22 later runs.

## Cleanup

Hung games were PIDs 1138638, 1147673, 1149068, 1150035 and 1159427. Each was stopped by the
harness with SIGTERM (exit −15) after the stacks were taken. Every run ended with no owned
process left, no Wayland socket, and no X socket or lock. The exception is the rejected
Weston-XWM attempt: Weston asserted under kiosk-shell, and its leftover
`/tmp/.X11-unix/X1` and `/tmp/.X1-lock` (lock PID dead, created by that run) were removed.
The scratch source, imports, profiles and fetched Godot files on tmpfs were deleted. /home
stayed above 15 GiB before every native run. The lowest reading was 16.12 GB (about 16 MB
above the floor), mostly from concurrent work. The evidence directory is 8.6 MB.

## Files and reproduction

Evidence is in the outer workspace at `checkpoints/spillway/r14/quit-investigation/`:
`probe.py` (setup and run, sha256 `1daec564…f0b9`), `series.sh`, `analyze.py`,
`QUIT-SERIES.json`, `runs/*` (run.json with markers, threads, wchan/syscall and sockets,
`gdb-*.txt`, logs, gzipped traces), `source-base.json`, `overlay-probe/`, Godot source hashes
and excerpts, and the incident note.

```
probe.py setup base 1d7fe13d overlay-probe
probe.py run base <label> practice server128 tape-practice-prefix.json tape wayland amd
probe.py run base <label> overflow server128 tape-practice-prefix.json menu x11 amd
```

Diagnostics stay out of player flows. `tests/r14_quit_probe_main.gd` extends the real
`r14_main.gd`, runs production `request_quit` through `super`, writes stage markers, and can
replace the tape's quit with real Escape and Quit-click input.
`tests/r14_quit_probe_tape.gd` extends the unchanged tape executor only to mark `_finalize`.
`t01-base` ran before the menu route was added; its probe file differs from the final one
only by that route.

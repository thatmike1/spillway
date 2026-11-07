# Overflow presentation and hardware audit

7 November 2026. **The build host can render the actual Overflow game and licensed kit on its AMD GPU. This audit found no measured Godot disqualifier.** Real-display pacing, physical input latency and native-resolution Forward+ performance remain open. The isolated 1280×720 Compatibility result does not decide those questions.

Evidence root, outside Git: `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/presentation-hardware/` (182 MB at handoff). Machine-readable results are `summary.json`, `supplemental.json`, `attempts.json`, `source-manifest.json`, `method-sha256.json` and `cleanup-proof.json` there. No existing project file was edited and no commit was made.

Root integration check: all 317 original snapshot file hashes match. Root recomputed the
three uncaptured runs' median/p99 draw intervals from metrics.jsonl, checked AMD device
identity and render-node FDs, confirmed exact per-tick positions/yaw and clean finishes
across GPU/software/repeat, and checked their cleanup records. Root inspected the AMD
descent frame. Results are in `root-spot-check.json`; this is an artifact check, not a
fresh hardware run. The later air correction and course revision are outside this snapshot.

## Frozen identity and successful route

- Source commit: `459e5051eaaac43b54dd2be9f14aa2f68db4dea8`; project Git tree: `3868665c59c3dc538a47582fc4bb412fadf03c8b`. `git archive` extracted only the committed `projects/foldrunner` subtree to external `source/`. All 317 original files still match their committed bytes after import. Ongoing course/air edits were excluded.
- Product: `momentum_overflow_main.gd`, course `momentum_overflow_level.gd`, original `momentum_carry_air_candidate.gd`, kit `momentum_materials.gd`. Build `spillway-2026.11.07-r13-overflow`, four stages, course key `c9886a1b96cb7484`. The finite executor builds the product main at normal spawn with records off. It does not use the historical R12 main or replace the course with a fixture.
- Godot: `4.7.2-stable`, engine commit `ed1daf0bf001b61586d9930840f2f1394092c079`. The official [4.7.2 tag API](https://api.github.com/repos/godotengine/godot/git/ref/tags/4.7.2-stable) matched the installed binary's reported commit. Compatibility, `opengl3`, Wayland, 120 Hz physics, maximum 12 physics steps per rendered frame, default VSync.
- Device: PCI `0000:03:00.0`, `1002:164c`, kernel driver `amdgpu`. Both Weston and Godot logged `AMD Radeon Graphics (radeonsi, renoir, ACO, DRM 3.64, 7.2.8-9-omarchy)`. Godot's RenderingServer API independently reported AMD; its process had three open FDs to `/dev/dri/renderD128`. Sysfs identity, FDs and package versions are retained. Mesa `26.2.5`, Wayland `1.26.0`.
- Route: extracted Weston `15.0.1-3`, official Arch mirror, **headless backend + GL renderer + kiosk shell + fake seat**, private 0700 runtime and socket. Weston explicitly logged `Using rendering device: /dev/dri/renderD128`. No DRM/KMS backend, physical seat, X11 server or parent desktop connection was used. The fake seat supplies protocol objects, not physical devices.

[Weston's official backend documentation](https://wayland.pages.freedesktop.org/weston/toc/running-weston.html) describes headless as having no input or output. The installed package's `--help` verified all selected options. Its MIT licence is retained under `packages/weston/usr/share/licenses/weston/COPYING`; exact upstream [15.0.1 source](https://gitlab.freedesktop.org/wayland/weston/-/archive/15.0.1/weston-15.0.1.tar.gz) and the extracted package are retained and hashed. No package was installed persistently. Asset licences and all adopted texture/prop hashes remain in the committed kit's `assets/momentum/MANIFEST.json` and licence directory.

## Matched real-time measurement

The existing ordinary tape came from `overflow-course/root-post-fd38b1e9/ordinary/events.tape.json`. It was recorded by a **state-aware closed-loop driver**; this audit replays its fixed events open loop. It is neither discovery by vision nor imperfect human play. The verified `momentum-tape.py expand` command supplied the executor's required expanded metadata. It contains 2,340 ticks (19.5 simulation seconds); key and relative-mouse events are engine-injected at the existing executor's documented sampling boundaries.

`gpu-ready` and `software-ready` use the same committed source, imported assets, input, defaults, normal spawn, actual 1280×720 viewport and window, and the same hardware-rendered private compositor. Only the game's `LIBGL_ALWAYS_SOFTWARE=true` differs. Godot's log/API identifies llvmpipe in the software run. `gpu-repeat` repeats the hardware run. No fixed-FPS setting or movie writer was used.

A scratch-only observer extends the committed tape executor. It never writes motor, camera, pose, velocity, tuning or course state. It records monotonic wall clocks, rendering signals, viewport CPU/GPU timers, physics work, interpolation and camera values. Physics timing brackets the early-input observer through the completed motor step, excluding subsequent trace serialization. Viewport timers use the documented [RenderingServer measurement API](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu). The [pinned GLES3 implementation](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/storage/utilities.cpp) uses GL timestamp queries and retrieves older query results; these are renderer execution times, not full input/display latency.

Warm-up: at least 240 physics ticks before arming at the next process boundary (240 on GPU, 251 on software), then the first 120 tape ticks excluded from distributions. Startup and shader work are retained in the raw logs. First tape input occurred after 3.19 s wall on GPU and 10.84 s on software. Percentiles below are per rendered sample over the remaining tape, so slow and fast runs sample scene positions at different densities. They are not independent trials or a general hardware benchmark.

| Measurement, milliseconds (p50 / p95 / p99) | AMD first, n=1,109 | llvmpipe, n=184 | AMD repeat, n=1,109 |
| --- | --- | --- | --- |
| Consecutive `frame_post_draw` wall interval | 16.692 / 17.373 / 17.979 | 213.880 / 267.977 / 285.460 | 16.679 / 17.554 / 18.571 |
| Viewport CPU timer | 0.602 / 0.767 / 0.879 | 190.022 / 241.797 / 260.132 | 0.626 / 0.867 / 1.451 |
| Viewport GL execution timer | 3.456 / 4.777 / 5.453 | 192.412 / 244.247 / 262.917 | 3.821 / 7.343 / 11.530 |
| `frame_pre_draw` to `frame_post_draw` | 0.910 / 1.123 / 1.262 | 194.475 / 249.163 / 265.703 | 0.961 / 1.304 / 2.220 |
| Physics work accumulated per draw | 0.624 / 0.927 / 1.057 | 2.086 / 3.247 / 4.016 | 0.658 / 0.945 / 1.091 |

The software GL execution timer measures llvmpipe's renderer, not AMD work. Timer rows overlap and must not be added. The host was shared with other activity; GPU frequency, thermal state and unrelated workloads were not controlled. The repeat's GPU tail rose while draw cadence remained similar, so report both runs.

- **Simulation:** the tape's measured wall span was 19.487 s on GPU, 19.485 s on repeat, and 42.120 s on software. Effective simulation rates were 120.08, 120.09 and 55.56 ticks/wall-second. Slightly above 120 comes from timing between the first tick's beginning and last tick's end. Software repeatedly reached 12 steps/draw and ran at 0.463 simulation seconds/wall-second. GPU's median and p99 were two steps/draw.
- **Actual movement:** all runs, including capture, had exactly identical positions and yaw on every tape tick: maximum difference 0.0 m / 0.0 rad. Each tick ran the motor once. Horizontal distance was 219.590 m; maximum finite-difference horizontal speed 16.949 m/s. `get_speed()` agreed with independently differenced positions within 0.00000158 m/s. Each finished clean at 16.291667 simulation seconds with zero respawns. This establishes one line on this frozen course only.
- **Presentation:** draw signals are not presentation feedback. A separate Wayland protocol trace saw virtual-output frame callbacks at 17 ms median/p95/p99 using their integer-millisecond timestamps; it includes startup/capture outliers, maximum 1,587 ms. Godot's [pinned Wayland source](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/linuxbsd/wayland/wayland_thread.cpp) requests `wl_surface.frame`; those callbacks are scheduling notifications. Weston's retained headless source arms a frame timer and finishes from that timer. **Actual buffer presentation intervals on a physical monitor were not measured.** No input-to-photon claim follows.
- **Capture cost:** `gpu-capture-protocol` read back and PNG-encoded five frames. Each operation took 333–381 ms, causing a 389.504 ms draw interval and reducing the tape's simulation/wall ratio to 0.940. Its sparse-capture p99 still looked healthy (17.667 ms), hiding those few outliers. Use capture for images and the uncaptured runs for pacing. Protocol logging also adds overhead.

## Mouse and camera findings

The product inherits `_unhandled_input` and `_update_eye` from `spillway_player.gd` through the CARRY runner. Mouse `screen_relative` directly changes yaw/pitch with sensitivity 0.0022 rad/pixel by default; there is no yaw spring, filter or interpolation. Physics consumes yaw at its tick. `_process` sets camera rotation directly and manually interpolates previous/current physics positions. The overlay ignores mouse input while playing; pause intentionally disables runner input. Bob, landing dip and a maximum 5° speed FOV remain presentation choices.

In the ordinary GPU runs, rendered camera yaw differed from current input yaw by at most 0.000000118 rad. Camera horizontal position matched the stated interpolation formula within 0.0000076 m. These exclude an accidental rotation smoother or failed position interpolation on this path. Manual interpolation deliberately follows the last completed physics states; its inherent interpolation delay and bob/FOV are game choices, not defects. This separation agrees with [Godot's camera interpolation guidance](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html#mouse-look).

`Input.use_accumulated_input` remains **true** in production. The [4.7 Input contract](https://docs.godotengine.org/en/4.7/classes/class_input.html#class-input-property-use-accumulated-input) merges similar events and documents a render-rate effect. The [pinned Input implementation](https://github.com/godotengine/godot/blob/4.7.2-stable/core/input/input.cpp) also has agile buffering, so disabling accumulation alone does not guarantee immediate per-device-sample delivery.

A separate scratch diagnostic sent 240 bursts of eight fresh 0.125-pixel events, with explicit flushes, on a stationary normal-spawn game:

| Engine-injected diagnostic | Events received per burst | Rotation applied | Camera at that draw |
| --- | --- | --- | --- |
| Before camera `_process`, accumulation on | 1 | full −0.0022 rad | matches yaw, error <0.000000072 rad |
| Before camera `_process`, accumulation off | 8 | same full −0.0022 rad | same bound |
| After camera `_process`, accumulation on | 1 | same full −0.0022 rad | behind by one burst (0.0022 rad) |

Accumulation did not erase rotation. Late arrival can defer its visual application until the next camera update, which is plausible frame-dependent responsiveness, not an observed production defect. These timings use engine injection and explicit flushes: **they do not test OS delivery, physical polling, focus, hardware capture or device latency**. Turning accumulation off was diagnostic only. W steering, carve policy and interpolation were left unchanged.

One source-level caveat deserves a real input check: the pinned Wayland relative-pointer callback consumes `dx/dy`, not the separately supplied `dx_unaccel/dy_unaccel`; the pinned X11 implementation reads `XI_RawMotion.raw_values`. The [official relative-pointer protocol](https://gitlab.freedesktop.org/wayland/wayland-protocols/-/blob/main/unstable/relative-pointer/relative-pointer-unstable-v1.xml) distinguishes these deltas and warns even unaccelerated values are not necessarily raw hardware data. `screen_relative` is not proof of unaccelerated physical input on every backend. The actual delivery backend, compositor acceleration and device cadence of Mike's earlier play were not observed, so this is a specific open hypothesis, not a diagnosis of that play.

## Attempts, reproduction and cleanup

Retained failures, in order: extracted Weston initially lacked its private `libexec_weston.so.0` search directory; then its long runtime path exceeded Unix socket's 108-byte limit, **after AMD initialization succeeded**. The first actual-game smoke run lacked imported textures/rails and had no fake seat for capture. Scratch import and `--fake-seat` fixed those. The executor next rejected the unexpanded tape; its verified expansion fixed that. The successful runs contain no `ERROR` or `SCRIPT ERROR`. Missing optional decoration/icon/activation protocols remain harmless logged warnings.

One diagnostic name accidentally matched “late” inside “unaccumulated”. Its JSON correctly records the late phase; it is retained as an extra late control. `gpu-diagnostic-early-unaccumulated2` is the corrected early comparison. An upstream tar.xz URL returned 404; the official GitLab source archive succeeded. These are setup/method failures, not engine disqualifiers.

Verified commands, run from the external evidence directory:

```sh
python3 source/tools/momentum-tape.py expand ordinary-original.tape.json
python3 run.py gpu-ready
python3 run.py software-ready
python3 run.py gpu-capture-protocol
python3 run.py gpu-diagnostic-early
python3 run.py gpu-diagnostic-early-unaccumulated2
python3 run.py gpu-diagnostic-late
python3 run.py gpu-repeat
python3 analyze.py
python3 supplemental.py
```

`run.py` intentionally refuses an existing run directory; use a fresh name preserving the relevant words to reproduce. Every `run.json` holds exact Godot/Weston commands. Weston uses `--backend=headless --fake-seat --renderer=gl --shell=kiosk --no-config --width=1280 --height=720 --refresh-rate=60000`; the runner supplies extracted module paths, removes parent display variables, and gives Godot only its private Wayland socket, isolated XDG paths and Dummy audio. The verified Godot import was `--headless --audio-driver Dummy --path source --import` with isolated XDG paths.

Every owned compositor and game process was waited for. `cleanup-proof.json` records ten engine attempts, no surviving PIDs, no socket after exit, and all `/tmp/ov-pres-*` runtimes removed. The first compositor-only failed attempt is covered separately. A final `/proc` scan found no owned game or compositor. The extracted tools, source, logs and five frames remain as evidence. No desktop window, cursor, physical input, speakers, persistent graphics package, desktop config or system service was changed.

Rendered AMD frames: [descent](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/presentation-hardware/gpu-capture-protocol/frames/draw_000240.png), [pier deck](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/presentation-hardware/gpu-capture-protocol/frames/draw_000720.png), [finish](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/presentation-hardware/gpu-capture-protocol/frames/draw_001200.png). Texture scale, rail geometry, lighting and product HUD are visible. Five stills cannot establish temporal aliasing or enjoyment.

## Engine decision and next action

Against the council's actual gates: **D1 is unresolved**, because it requires the real display and attribution after renderer/tick/interpolation comparisons. This virtual 60 Hz result does not trigger it. **D2 belongs to the independent contact audit**; this one clean line neither proves nor disproves adversarial contact behavior. **D3 is unresolved**, because it specifies native resolution, Forward+ and target visuals, whereas this run is 720p Compatibility. **D4 remains untested** on native Windows. GPU access and practical native-rendering automation are established; no port is justified by this audit.

**Next action:** after the revised Overflow course is committed, rerun this private AMD method on that exact snapshot, retaining uncaptured timing separately from sparse frames. That supplies relevant GPU evidence for the actual delivery candidate without changing Mike's desktop. Keep physical-input/backend and real-display checks explicitly open for an authorized desktop play session.

## Key SHA-256 identities

Full per-file source and method hashes are in the manifests. These identify the measured game and method without relying on a mutable checkout:

| Object | SHA-256 |
| --- | --- |
| Committed project `git archive` tar stream | `c437b2bcf743cfd725b79282142ba1d0051816ba881bceab0cd2fcf426d3addd` |
| Installed Godot executable | `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e` |
| Weston Arch package | `92fe0bfe2cf1ae02105b0e6573f6695c6bbd4637c9a6b20299a6fea8c3d23b4d` |
| Weston upstream source archive | `dbcedc27f880d1f10a9edc010a9ea044a6a2861269f2aa3c8647cc557a3fd73a` |
| Product main | `b2ce44bd58e0344607cdfb1307655bd9ccc7798bb377f43109e83384ce422231` |
| Frozen course | `49ef72e7c7700239cce5861c0a4c5f4a523df1b96a1b0d80c6b951d444f8d2d7` |
| Original air candidate | `71d6dc5c7aac18c8234a54bfe72a1df86e1830dc7c5aac2a5e60a3d78d313dc0` |
| Licensed asset manifest | `7539628711d8fdaad1e7c8f21703b2bbbb0ab3ed7a19e852ca1db79be07c0fcb` |
| Original ordinary tape | `e0577bfd60544454255ad39851b975e242f6dec5f5939939e079ff71917dfeec` |
| Expanded applied tape | `59d1db00781607e7400b581b89cf00969df01a137c0789cc3c128eab22c30202` |
| Read-only observer | `3409185eb59390c05300c332de1cfe27c3592db69d879f88957dc876f68dbb1b` |
| Input diagnostic | `6f3de48a8cce13946a162ca7e6fb557a61862626db17de9fc0690be2db33106a` |
| Owned-process runner | `da35cfee5104016af2c38ee3a557103ec9076d50b90dcf91f0c7e7d3a88a147f` |

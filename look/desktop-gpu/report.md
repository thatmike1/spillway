# Desktop GPU verification: Spillway Look C

Completed on thatmike1-MS-7B86, 9 November 2026. Exact delivered release startup passed on real NVIDIA hardware. The rendering comparison passed at actual 1280x720 and 2560x1440 viewport pixels, with lower new-look median GPU time in all four fixed views at both resolutions. This proves fixed-view rendering performance only, not gameplay, movement, input latency, every map, or Mike's visual preference.

## Hardware and identity

NVIDIA GeForce RTX 2070 SUPER, PCI 0000:26:00.0, proprietary nvidia kernel driver, NVIDIA 595.99.02. Godot reports OpenGL 3.3.0 NVIDIA 595.99.02 / Compatibility on that device. Native process file descriptors hold /dev/nvidia0 and /dev/dri/renderD128; nvidia-smi pmon registers the exact release/editor PIDs as graphics clients. Weston 14.0.2 headless GL and rootful Xwayland use hardware NVIDIA, independently checked by compositor log and private glxinfo. No software renderer accepted.

Live xrandr: primary HDMI-1 2560x1440 at 119.95 Hz; secondary DP-3 2560x1080 at 59.98 Hz. The combined 2560x2520 desktop is not a game resolution. 2560x1440 is the tested ordinary primary-monitor resolution.

- ZIP 109648354 bytes, SHA256 962cf93d63e5372ecb8d5b3e6b64630ff780adc30b548bdef9e4cd768d2febfc.
- Release runtime SHA256 d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63.
- Adjacent PCK SHA256 9180812f4ea3ad87b136f0c45faf19d79e712fcbd13a9b5562e228fc8d637441.
- BUILD.json source commit 76c025facc6e0a937fb2f31dd763dcc5438aa2b5. All 986 manifest files match SHA256 of read-only git objects at that commit, including assets/scripts/shaders. No source snapshot or checkout is used by the benchmark. Laptop experiment HEAD read as baef45c93eaf5764f1dfe821435f90ae635aedab; no branch was changed.
- Benchmark editor: preinstalled 4.7.2.stable.official.ed1daf0bf, SHA256 8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e. This is a different binary from the release runtime. Both exact hashes are in identity.json.

## Method and exact commands

Original laptop helpers were read and copied unmodified into helpers/: look-profile.gd, look-views.gd, look-native.py, r14_native_display.py, check-look-package.py. desktop-profile.gd adapts only the external fixture: truthful metadata, canvas scaling disabled to produce actual target viewport pixels, and the four fixed camera definitions inlined. MAIN remains the packed res://scripts/look_main.gd. Project scripts/assets/shaders and PCK are unchanged. Both looks share the same viewport, camera and paused game instance.

Two rounds, order old/new then new/old at each view; 40 warmup and 120 measured frames per look/view/round. 16 segments per resolution, 1920 samples each, 3840 accepted samples overall. GPU/CPU milliseconds from RenderingServer viewport measurements; frame intervals from Time.get_ticks_usec at consecutive frame_post_draw callbacks. GPU measurement enabled with viewport_set_measure_render_time. FOV 73.739795, far 1500. Camera positions/targets exactly as requested. HUD and look label hidden, game paused, physics 128 Hz, vsync disabled (reported 0), Engine.max_fps 0. __GL_SYNC_TO_VBLANK=0 only in child environment. No OS power or clock changes.

Each target gets its own private Weston output and Xwayland :190 at exactly target size. Inherited safety logic checks filesystem lock, filesystem socket, /proc/net/unix abstract/filesystem listeners, then locks ownership. Never -displayfd. Only headless Weston is used; no DRM/KMS seat takeover. Actual window and root texture pixels are asserted, not inferred from --resolution. Accepted metadata confirms 1280x720 and 2560x1440.

Reproduction entry point (after extracting the exact ZIP into scratch/package):

```sh
python3 SCRATCH/evidence/helpers/desktop-run.py
python3 SCRATCH/evidence/helpers/summarize.py
```

The runner is intentionally fail-closed on existing output folders. Use fresh scratch. It resolves SCRATCH from its location. It needs installed Weston/Xwayland/glxinfo/xdpyinfo/nvidia-smi and the existing editor path stated above. Full launch commands, cwd, exit codes and per-process hardware samples are in each run.json, compositor commands in display-*/native-display.json. Exact benchmark command shape:

```sh
/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 --main-pack SCRATCH/package/SpillwayLookC-linux-x86_64/SpillwayLookC.pck --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --windowed --position 0,0 --resolution WIDTHxHEIGHT --script SCRATCH/evidence/helpers/desktop-profile.gd -- --out=SCRATCH/evidence/editor-WIDTHxHEIGHT
```

All launches use an empty external cwd, isolated XDG app state, no loose project files, no source fallback. The release executable runs with its adjacent PCK from that same empty cwd and --quit-after 180; accepted startup exits 0 and logs the correct build on hardware. No --main-pack override is passed to release. External --script attempt on release did not produce samples and was terminated; release --help does not advertise --script or --main-pack. Do not describe release as benchmarked: only editor+exact PCK was benchmarked.

## Accepted measurements

Values below combine the two rounds (240 samples per row). summary.json also contains means, min/max, CPU data and per-round medians. Raw unrounded measurements are editor-*/performance.json.

| resolution | view | look | GPU median / p95 ms | frame median / p95 ms |
|---|---|---|---:|---:|
| 1280x720 | concept | old | 0.6940 / 0.7120 | 0.9485 / 1.4810 |
| 1280x720 | concept | new | 0.3845 / 0.4120 | 0.7310 / 0.9830 |
| 1280x720 | breakwater | old | 0.5410 / 0.5750 | 0.7660 / 1.1280 |
| 1280x720 | breakwater | new | 0.3520 / 0.3590 | 0.6660 / 0.8060 |
| 1280x720 | box-rows | old | 1.2980 / 1.6480 | 1.3650 / 1.8960 |
| 1280x720 | box-rows | new | 0.6380 / 0.6530 | 0.8660 / 1.2640 |
| 1280x720 | breach | old | 0.5830 / 0.6220 | 0.8455 / 1.2770 |
| 1280x720 | breach | new | 0.3350 / 0.3440 | 0.5770 / 0.8760 |
| 2560x1440 | concept | old | 1.6815 / 2.0350 | 1.9215 / 2.2810 |
| 2560x1440 | concept | new | 0.7940 / 0.8310 | 1.1775 / 1.4690 |
| 2560x1440 | breakwater | old | 1.4530 / 1.8390 | 1.5845 / 2.0780 |
| 2560x1440 | breakwater | new | 0.7370 / 0.7650 | 1.1205 / 1.4870 |
| 2560x1440 | box-rows | old | 2.5180 / 2.9850 | 2.7530 / 3.3400 |
| 2560x1440 | box-rows | new | 1.4190 / 1.7650 | 1.5490 / 2.1810 |
| 2560x1440 | breach | old | 1.6090 / 1.8730 | 1.8180 / 2.2140 |
| 2560x1440 | breach | new | 0.7450 / 0.7780 | 1.1310 / 1.4920 |

## Failures and limits

attempt1-wrong-size retains the complete first attempt, logs and samples. Kiosk shell forced both window sizes to the 2576x1456 output; these are rejected for the requested-resolution comparison. The corrected helper uses separate exact-size outputs and asserts actual dimensions. The first helper revision was corrected in place; commands for the failed attempt are preserved in its run/display receipts. The final helper reproduces accepted runs.

The release external-fixture attempt was stopped with SIGTERM after no performance output appeared; its run.json records exit -15. This is a failed fixture attempt, not a game crash. The first attempt's normal release startup also exits 0. Godot emits XIM setup warnings and 12 ObjectDB leaks at fixture exit, also present in release shutdown logs. These are recorded, not fixed by this test. No script/shader ERROR was observed in accepted runs. No performance regression was observed in these fixed views. Frame intervals are uncapped private compositor/host intervals, not physical presentation or input latency. Concurrent normal desktop apps remain active; GPU power/clocks are not locked, so do not infer isolated laboratory throughput from these values. No compositor-rate plateau is evident in the accepted median intervals (0.577–2.753 ms).

## Safety, transfer and cleanup

Initial desktop /home free: 33,781,653,504 bytes; all recorded later checks remain above 15,000,000,000 bytes. Laptop pre-evidence transfer free: 16,804,675,584 bytes. Evidence is about 2.4 MB. No installs, sudo, desktop configuration edits, source changes, checkout operations, staging, commits, or messages to the R16 thread. Only the separate experiment git objects were read over ssh laptop. All new helper scripts are included here.

Private compositor/Xwayland sessions exited cleanly. Their receipts show no owned processes, lock/socket leftovers or Wayland runtime directories. safety-final.json checks the whole 190–199 range by filesystem and /proc/net/unix. xrandr before/after is byte-for-byte unchanged; original GNOME Shell, desktop Xwayland, Handy, EasyEffects, Chrome and Firefox process IDs remain alive with the same names. This supports desktop-session preservation; it does not claim to inspect every application document. Initial release briefly acquired a screensaver inhibition cookie, released at exit; final helper removes the desktop session bus from child environments. No physical input was sent.

Evidence destination: laptop /home/thatmike1/foldrunner-build-2026-11-05/look/evidence/desktop-gpu/. SHA256SUMS verifies the transferred evidence. cleanup.json, uploaded last, records removal of this test's desktop scratch after transfer. Failure logs are retained on the laptop. Parent owns RESULTS edits, bead disposition and commit/push.

Official references read: https://wayland.pages.freedesktop.org/weston/toc/running-weston.html (headless and GL renderer), https://docs.godotengine.org/en/latest/classes/class_renderingserver.html (GPU measurements are milliseconds and require viewport measurement enabling), plus installed weston --help, Xwayland -help and exact release --help. The installed 4.7.2 API calls were exercised by the accepted runs.
